#!/usr/bin/env python3
"""Cliente minimo do ComfyUI (formato API) para gerar a arte do projeto.

Nao depende de pacote nenhum alem da biblioteca padrao: fala direto com o
ComfyUI local em `http://127.0.0.1:8188` via HTTP. Faz quatro coisas:

1. carrega um workflow em formato **API** (nao o formato do editor);
2. injeta prompt, prompt negativo, seed, tamanho e checkpoint nos nos certos
   (descobertos pelo papel: quem alimenta o KSampler e o EmptyLatentImage);
3. enfileira e espera o `prompt_id` aparecer no `/history`;
4. baixa cada imagem produzida para o diretorio de saida e imprime um resumo
   JSON com o `prompt_id`, os arquivos e a seed efetiva.

Sem ComfyUI no ar, o script falha com mensagem clara -- nunca inventa arquivo.

Uso:
    python3 tools/comfy/scripts/run_workflow.py \\
      --workflow tools/comfy/workflows/pixelart_bg.json \\
      --prompt "..." --negative "..." --seed 426240 \\
      --width 512 --height 288 \\
      --output-dir /tmp/peleja-raw
"""

from __future__ import annotations

import argparse
import copy
import json
import pathlib
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_HOST = "http://127.0.0.1:8188"
DEFAULT_TIMEOUT = 900


class ComfyError(RuntimeError):
    """ComfyUI respondeu com erro ou nao respondeu."""


def _request(url: str, payload: dict | None = None, timeout: int = 60) -> bytes:
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    request = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}, method="POST" if data else "GET"
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        raise ComfyError(f"HTTP {error.code} em {url}: {detail}") from error
    except urllib.error.URLError as error:
        raise ComfyError(
            f"ComfyUI inacessivel em {url} ({error.reason}); rode 'comfy launch --background'"
        ) from error


def health(host: str = DEFAULT_HOST) -> dict:
    return json.loads(_request(f"{host.rstrip('/')}/system_stats", timeout=10).decode("utf-8"))


def load_api_workflow(path: pathlib.Path) -> dict:
    """Le o workflow em formato API, descartando chaves que o ComfyUI recusaria.

    O ComfyUI valida **todo** top-level como no do grafo: uma chave de
    documentacao como `"_comment"` (convencao dos exemplos da skill `comfyui`)
    derruba o `/prompt` com HTTP 500 -- `validate_prompt` faz
    `node_data.get('_meta', {})` e recebe uma `str`. Por isso o runner normaliza
    a entrada: chaves com `_` e valores que nao sejam objeto saem, e a
    documentacao do workflow vive em `tools/comfy/README.md`.
    """
    raw = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    workflow = {
        key: value
        for key, value in raw.items()
        if isinstance(value, dict) and not (isinstance(key, str) and key.startswith("_"))
    }
    if not workflow:
        raise ComfyError(f"workflow sem nos: {path}")
    return workflow


def _node_of_type(workflow: dict, class_type: str) -> tuple[str, dict]:
    for node_id, node in workflow.items():
        if isinstance(node, dict) and node.get("class_type") == class_type:
            return node_id, node
    raise ComfyError(f"workflow nao tem no do tipo {class_type}")


def patch_workflow(
    workflow: dict,
    prompt: str | None = None,
    negative: str | None = None,
    seed: int | None = None,
    width: int | None = None,
    height: int | None = None,
    steps: int | None = None,
    cfg: float | None = None,
    checkpoint: str | None = None,
    filename_prefix: str | None = None,
) -> tuple[dict, int]:
    """Injeta os parametros nos nos por papel e devolve (workflow, seed efetiva)."""
    patched = copy.deepcopy(workflow)
    sampler_id, sampler = _node_of_type(patched, "KSampler")
    effective_seed = int(sampler["inputs"].get("seed", 0))
    if seed is not None:
        effective_seed = seed if seed >= 0 else random.randint(0, 2**31 - 1)
        sampler["inputs"]["seed"] = effective_seed
    if steps is not None:
        sampler["inputs"]["steps"] = steps
    if cfg is not None:
        sampler["inputs"]["cfg"] = cfg

    if prompt is not None:
        positive_id = sampler["inputs"]["positive"][0]
        patched[positive_id]["inputs"]["text"] = prompt
    if negative is not None:
        negative_id = sampler["inputs"]["negative"][0]
        patched[negative_id]["inputs"]["text"] = negative

    if width is not None or height is not None:
        latent_id = sampler["inputs"]["latent_image"][0]
        latent = patched[latent_id]["inputs"]
        if width is not None:
            latent["width"] = width
        if height is not None:
            latent["height"] = height

    if checkpoint is not None:
        _checkpoint_id, loader = _node_of_type(patched, "CheckpointLoaderSimple")
        loader["inputs"]["ckpt_name"] = checkpoint

    if filename_prefix is not None:
        try:
            _save_id, save = _node_of_type(patched, "SaveImage")
            save["inputs"]["filename_prefix"] = filename_prefix
        except ComfyError:
            pass

    _ = sampler_id
    return patched, effective_seed


def queue_prompt(workflow: dict, host: str = DEFAULT_HOST) -> str:
    payload = {"prompt": workflow, "client_id": "peleja-comfy-tools"}
    response = json.loads(_request(f"{host.rstrip('/')}/prompt", payload).decode("utf-8"))
    if "prompt_id" not in response:
        raise ComfyError(f"resposta sem prompt_id: {response}")
    return response["prompt_id"]


def wait_for_result(
    prompt_id: str, host: str = DEFAULT_HOST, timeout: float = DEFAULT_TIMEOUT, interval: float = 2.0
) -> dict:
    """Espera o historico e devolve a entrada do prompt concluido."""
    base = host.rstrip("/")
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        history = json.loads(_request(f"{base}/history/{prompt_id}", timeout=30).decode("utf-8"))
        entry = history.get(prompt_id)
        if entry:
            status = entry.get("status", {})
            if status.get("status_str") == "error" or not status.get("completed", True):
                raise ComfyError(f"execucao falhou: {json.dumps(status, ensure_ascii=False)}")
            return entry
        time.sleep(interval)
    raise ComfyError(f"timeout de {timeout:.0f}s esperando o prompt {prompt_id}")


def download_images(entry: dict, output_dir: pathlib.Path, host: str = DEFAULT_HOST) -> list[pathlib.Path]:
    base = host.rstrip("/")
    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[pathlib.Path] = []
    for node_output in entry.get("outputs", {}).values():
        for image in node_output.get("images", []):
            query = urllib.parse.urlencode(
                {
                    "filename": image["filename"],
                    "subfolder": image.get("subfolder", ""),
                    "type": image.get("type", "output"),
                }
            )
            blob = _request(f"{base}/view?{query}", timeout=120)
            target = output_dir / pathlib.Path(image["filename"]).name
            target.write_bytes(blob)
            written.append(target)
    return written


def run_workflow(
    workflow_path: pathlib.Path,
    output_dir: pathlib.Path,
    host: str = DEFAULT_HOST,
    timeout: float = DEFAULT_TIMEOUT,
    **overrides: object,
) -> dict:
    """Executa o workflow completo e devolve o resumo (prompt_id, seed, arquivos)."""
    workflow = load_api_workflow(workflow_path)
    patched, effective_seed = patch_workflow(workflow, **overrides)  # type: ignore[arg-type]
    prompt_id = queue_prompt(patched, host)
    entry = wait_for_result(prompt_id, host, timeout)
    files = download_images(entry, pathlib.Path(output_dir), host)
    latent = patched[_node_of_type(patched, "KSampler")[1]["inputs"]["latent_image"][0]]["inputs"]
    sampler_inputs = _node_of_type(patched, "KSampler")[1]["inputs"]
    return {
        "prompt_id": prompt_id,
        "host": host,
        "workflow": str(workflow_path),
        "seed": effective_seed,
        "width": latent["width"],
        "height": latent["height"],
        "steps": sampler_inputs["steps"],
        "cfg": sampler_inputs["cfg"],
        "sampler_name": sampler_inputs["sampler_name"],
        "scheduler": sampler_inputs["scheduler"],
        "checkpoint": _node_of_type(patched, "CheckpointLoaderSimple")[1]["inputs"]["ckpt_name"],
        "files": [str(path) for path in files],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workflow", type=pathlib.Path, required=True)
    parser.add_argument("--output-dir", type=pathlib.Path, required=True)
    parser.add_argument("--prompt")
    parser.add_argument("--negative")
    parser.add_argument("--seed", type=int, default=None, help="-1 sorteia uma seed")
    parser.add_argument("--width", type=int)
    parser.add_argument("--height", type=int)
    parser.add_argument("--steps", type=int)
    parser.add_argument("--cfg", type=float)
    parser.add_argument("--checkpoint")
    parser.add_argument("--filename-prefix")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT)
    parser.add_argument("--health-check", action="store_true", help="so confere o /system_stats")
    args = parser.parse_args(argv)

    if args.health_check:
        stats = health(args.host)
        print(json.dumps(stats.get("system", stats), indent=2, ensure_ascii=False))
        return 0

    summary = run_workflow(
        args.workflow,
        args.output_dir,
        host=args.host,
        timeout=args.timeout,
        prompt=args.prompt,
        negative=args.negative,
        seed=args.seed,
        width=args.width,
        height=args.height,
        steps=args.steps,
        cfg=args.cfg,
        checkpoint=args.checkpoint,
        filename_prefix=args.filename_prefix,
    )
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
