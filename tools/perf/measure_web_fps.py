#!/usr/bin/env python3
"""Mede o custo de quadro do jogo publicado via CDP, sem limite de taxa de quadro.

Ferramenta de evidencia (fora das camadas do jogo): abre o jogo publicado num
Chrome headless proprio, com o limite de taxa de quadro desligado
(--disable-frame-rate-limit), e mede o intervalo entre quadros de
requestAnimationFrame. Sem o limite, o intervalo reflete o CUSTO do quadro do
motor: contra o orcamento de 16,7 ms de 60 fps, ele diz se a cena cabe em 60 fps.

Uso: python3 tools/perf/measure_web_fps.py <url> [segundos]
"""

import base64
import json
import os
import socket
import statistics
import struct
import subprocess
import sys
import time

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PORT = 9333
PROFILE = "/tmp/chrome-peleja-perf"


def recv_exact(sock, count):
    data = b""
    while len(data) < count:
        chunk = sock.recv(count - len(data))
        if not chunk:
            raise ConnectionError("socket fechado")
        data += chunk
    return data


class Ws:
    """Cliente WebSocket minimo (RFC 6455) o bastante para o CDP."""

    def __init__(self, url):
        _, rest = url.split("://", 1)
        host_port, path = rest.split("/", 1)
        host, port = host_port.split(":")
        self.sock = socket.create_connection((host, int(port)))
        key = base64.b64encode(os.urandom(16)).decode()
        request = (
            "GET /%s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\n"
            "Connection: Upgrade\r\nSec-WebSocket-Key: %s\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n" % (path, host_port, key)
        )
        self.sock.settimeout(120)
        self.sock.sendall(request.encode())
        header = b""
        while b"\r\n\r\n" not in header:
            header += self.sock.recv(1)
        self.next_id = 0

    def call(self, method, params=None, timeout=60.0):
        self.next_id += 1
        message = json.dumps({"id": self.next_id, "method": method, "params": params or {}})
        self._send(message)
        deadline = time.time() + timeout
        while time.time() < deadline:
            payload = self._recv()
            if payload is None:
                continue
            data = json.loads(payload)
            if data.get("id") == self.next_id:
                return data.get("result", {})
        raise TimeoutError(method)

    def _send(self, text):
        payload = text.encode()
        mask = os.urandom(4)
        header = bytearray([0x81])
        length = len(payload)
        if length < 126:
            header.append(0x80 | length)
        elif length < 65536:
            header.append(0x80 | 126)
            header += struct.pack(">H", length)
        else:
            header.append(0x80 | 127)
            header += struct.pack(">Q", length)
        header += mask
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.sock.sendall(bytes(header) + masked)

    def _recv(self):
        first = recv_exact(self.sock, 2)
        opcode = first[0] & 0x0F
        length = first[1] & 0x7F
        if length == 126:
            length = struct.unpack(">H", recv_exact(self.sock, 2))[0]
        elif length == 127:
            length = struct.unpack(">Q", recv_exact(self.sock, 8))[0]
        payload = recv_exact(self.sock, length) if length else b""
        if opcode == 0x8:
            raise ConnectionError("websocket fechado")
        if opcode in (0x9,):
            return None
        return payload.decode(errors="replace")


def http_json(path):
    request = "GET %s HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n" % path
    sock = socket.create_connection(("127.0.0.1", PORT), timeout=20)
    sock.settimeout(20)
    sock.sendall(request.encode())
    data = b""
    while True:
        chunk = sock.recv(65536)
        if not chunk:
            break
        data += chunk
    sock.close()
    return json.loads(data.split(b"\r\n\r\n", 1)[1])


def main():
    url = sys.argv[1]
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 8.0
    subprocess.run(["pkill", "-f", PROFILE], check=False)
    chrome = subprocess.Popen(
        [
            CHROME,
            "--headless=new",
            "--remote-debugging-port=%d" % PORT,
            "--user-data-dir=%s" % PROFILE,
            "--disable-frame-rate-limit",
            "--disable-gpu-vsync",
            "--no-first-run",
            "--no-default-browser-check",
            "--window-size=1280,720",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        target = None
        for _ in range(60):
            try:
                targets = http_json("/json/list")
                pages = [item for item in targets if item.get("type") == "page"]
                if pages:
                    target = pages[0]
                    break
            except Exception:
                pass
            time.sleep(0.5)
        if target is None:
            print("FAIL: nao consegui abrir um alvo no Chrome")
            return 1
        ws = Ws(target["webSocketDebuggerUrl"])
        ws.call("Page.enable")
        ws.call("Page.navigate", {"url": url})
        print("url:", url)
        sys.stdout.flush()
        time.sleep(15)
        size = ws.call(
            "Runtime.evaluate",
            {"expression": "(() => { const c=document.querySelector('canvas'); return c ? c.width+'x'+c.height : 'sem canvas'; })()", "returnByValue": True},
        )["result"]["value"]
        print("canvas:", size)
        ws.call(
            "Runtime.evaluate",
            {
                "expression": """(() => { window.__f = { times: [], started: performance.now() };
                    const loop = (t) => { window.__f.times.push(t);
                      if (performance.now() - window.__f.started < %d) requestAnimationFrame(loop);
                      else window.__f.done = true; };
                    requestAnimationFrame(loop); return true; })()""" % int(seconds * 1000),
                "returnByValue": True,
            },
        )
        time.sleep(seconds + 3)
        times = ws.call(
            "Runtime.evaluate",
            {"expression": "window.__f ? window.__f.times : []", "returnByValue": True},
        )["result"]["value"]
        if not times or len(times) < 5:
            print("FAIL: nenhum quadro medido (%d)" % len(times or []))
            return 1
        intervals = sorted(times[i + 1] - times[i] for i in range(len(times) - 1))
        median = statistics.median(intervals)
        p95 = intervals[int(len(intervals) * 0.95) - 1]
        print(
            "frames=%d janela=%.1fs intervalo_mediano=%.3f ms custo_mediano=%.2f ms "
            "p95=%.3f ms melhor=%.3f ms pior=%.3f ms"
            % (len(times), seconds, median, median, p95, intervals[0], intervals[-1])
        )
        print(
            "orcamento_60fps=16.667 ms -> mediano %.0f%% do orcamento, p95 %.0f%%"
            % (median / 16.667 * 100.0, p95 / 16.667 * 100.0)
        )
        shot = ws.call("Page.captureScreenshot", {"format": "png"})
        out = sys.argv[3] if len(sys.argv) > 3 else ""
        if out:
            with open(out, "wb") as handle:
                handle.write(base64.b64decode(shot["data"]))
            print("screenshot:", out)
        return 0
    finally:
        chrome.terminate()
        subprocess.run(["pkill", "-f", PROFILE], check=False)


if __name__ == "__main__":
    sys.exit(main())