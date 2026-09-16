#!/usr/bin/env python3
"""Gera os SFX e a musica chiptune do projeto em `assets/audio/`.

Fronteira de autoria (fora das camadas do jogo, no espirito de
`tools/art/build_saci_spritesheet.py`): sintetiza cada efeito e cada trilha a
partir de osciladores escritos aqui mesmo -- nenhuma amostra, nenhum banco de
sons, nenhuma fonte de terceiros. Os WAV gerados sao commitados como artefato do
projeto e a origem e a licenca ficam registradas em `assets/audio/CREDITS.md`.

Determinismo: o mesmo codigo gera exatamente os mesmos bytes (nenhuma
aleatoriedade real, nenhuma dependencia externa). `--verify` re-sintetiza em
memoria e compara com os arquivos do repositorio.

Uso:
  python3 tools/audio/build_chiptune.py             # grava os WAV
  python3 tools/audio/build_chiptune.py --verify    # confere bytes contra o repo
  python3 tools/audio/build_chiptune.py --stats     # resume sem gravar
"""

from __future__ import annotations

import argparse
import hashlib
import math
import struct
import sys
import wave
from pathlib import Path
from typing import Callable, Union

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SFX_DIRECTORY = Path("assets/audio/sfx")
MUSIC_DIRECTORY = Path("assets/audio/music")

# O chiptune e lo-fi de proposito: 11025 Hz e a taxa de um console de 8 bits e
# mantem o repositorio leve; os SFX usam 22050 Hz para o transiente ficar nitido.
SFX_RATE = 22050
MUSIC_RATE = 11025
HARDWARE_BITS = 16
CHANNELS = 1

NOTE_NAMES = {
    "C": 0,
    "C#": 1,
    "D": 2,
    "D#": 3,
    "E": 4,
    "F": 5,
    "F#": 6,
    "G": 7,
    "G#": 8,
    "A": 9,
    "A#": 10,
    "B": 11,
}


def note_frequency(note: str) -> float:
    """Frequencia em Hz de uma nota como "A4" (temperamento igual, A4 = 440)."""
    name = note[:-1]
    octave = int(note[-1])
    if name not in NOTE_NAMES:
        raise ValueError(f"nota desconhecida: {note}")
    midi = NOTE_NAMES[name] + 12 * (octave + 1)
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


class LfsrNoise:
    """Ruido deterministico (registrador de deslocamento de 15 bits)."""

    def __init__(self, seed: int = 1) -> None:
        self.register = seed & 0x7FFF or 1

    def next(self) -> float:
        bit = (self.register ^ (self.register >> 1)) & 1
        self.register = (self.register >> 1) | (bit << 14)
        return 1.0 if self.register & 1 else -1.0


def _waveform(kind: str, phase: float, duty: float, noise: LfsrNoise) -> float:
    if kind == "square":
        return 1.0 if (phase % 1.0) < duty else -1.0
    if kind == "triangle":
        position = (phase % 1.0) * 4.0
        if position < 1.0:
            return position * 2.0 - 1.0
        if position < 3.0:
            return 1.0 - (position - 1.0)
        return -1.0 + (position - 3.0) * 2.0
    if kind == "saw":
        return 2.0 * (phase % 1.0) - 1.0
    if kind == "noise":
        return noise.next()
    raise ValueError(f"oscilador desconhecido: {kind}")


def _envelope(
    elapsed: float,
    duration: float,
    attack: float,
    release: float,
    decay: float,
    sustain: float,
) -> float:
    if elapsed < attack:
        return elapsed / attack if attack > 0.0 else 1.0
    if elapsed > duration - release:
        remaining = max(duration - elapsed, 0.0)
        return remaining / release if release > 0.0 else 1.0
    if decay > 0.0:
        position = min((elapsed - attack) / decay, 1.0)
        return 1.0 + (sustain - 1.0) * position
    return 1.0


def mix_tone(
    buffer: list[float],
    rate: int,
    start: float,
    duration: float,
    frequency: Union[float, Callable[[float], float]],
    amplitude: float = 0.5,
    kind: str = "square",
    duty: float = 0.5,
    attack: float = 0.004,
    release: float = 0.03,
    decay: float = 0.0,
    sustain: float = 1.0,
    vibrato_depth: float = 0.0,
    vibrato_rate: float = 0.0,
    noise_seed: int = 1,
) -> None:
    """Soma uma voz no buffer (em segundos). `frequency` pode ser um numero ou
    uma funcao do tempo, o que permite sweeps de pitch."""
    noise = LfsrNoise(noise_seed)
    first = int(round(start * rate))
    length = int(round(duration * rate))
    phase = 0.0
    for index in range(length):
        position = first + index
        if position < 0 or position >= len(buffer):
            continue
        elapsed = index / rate
        current = frequency(elapsed) if callable(frequency) else float(frequency)
        if vibrato_depth > 0.0:
            current *= 1.0 + vibrato_depth * math.sin(2.0 * math.pi * vibrato_rate * elapsed)
        phase += current / rate
        envelope = _envelope(elapsed, duration, attack, release, decay, sustain)
        buffer[position] += amplitude * envelope * _waveform(kind, phase, duty, noise)


def silence(seconds: float, rate: int) -> list[float]:
    return [0.0] * int(round(seconds * rate))


def normalize(buffer: list[float], peak: float = 0.85) -> list[float]:
    highest = max((abs(sample) for sample in buffer), default=0.0)
    if highest == 0.0:
        return buffer
    scale = peak / highest
    return [sample * scale for sample in buffer]


def to_pcm_bytes(buffer: list[float]) -> bytes:
    frames = bytearray()
    for sample in buffer:
        clipped = max(-1.0, min(1.0, sample))
        frames += struct.pack("<h", int(round(clipped * 32767)))
    return bytes(frames)


def write_artifact(path: Path, payload: bytes, rate: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(CHANNELS)
        handle.setsampwidth(HARDWARE_BITS // 8)
        handle.setframerate(rate)
        handle.writeframes(payload)


# ---------------------------------------------------------------------------
# Efeitos sonoros
# ---------------------------------------------------------------------------


def sfx_impact_light(rate: int) -> list[float]:
    """Impacto leve: estalo curto e agudo."""
    buffer = silence(0.11, rate)
    mix_tone(buffer, rate, 0.0, 0.05, 660.0, amplitude=0.6, kind="square", duty=0.25)
    mix_tone(
        buffer,
        rate,
        0.0,
        0.09,
        lambda t: 900.0 - 4200.0 * t,
        amplitude=0.35,
        kind="noise",
        release=0.05,
        noise_seed=0x2A1,
    )
    return normalize(buffer, 0.8)


def sfx_impact_heavy(rate: int) -> list[float]:
    """Impacto pesado: corpo grave com queda de pitch."""
    buffer = silence(0.24, rate)
    mix_tone(
        buffer,
        rate,
        0.0,
        0.22,
        lambda t: 180.0 - 520.0 * t,
        amplitude=0.9,
        kind="square",
        duty=0.5,
        release=0.1,
    )
    mix_tone(
        buffer,
        rate,
        0.0,
        0.16,
        lambda t: 420.0 - 1800.0 * t,
        amplitude=0.5,
        kind="noise",
        release=0.08,
        noise_seed=0x5C3,
    )
    return normalize(buffer, 0.9)


def sfx_special(rate: int) -> list[float]:
    """Golpe Especial: subida de pitch com vibrato (o redemoinho armando)."""
    buffer = silence(0.55, rate)
    mix_tone(
        buffer,
        rate,
        0.0,
        0.52,
        lambda t: 220.0 + 1400.0 * min(t / 0.5, 1.0),
        amplitude=0.65,
        kind="square",
        duty=0.35,
        vibrato_depth=0.02,
        vibrato_rate=18.0,
        release=0.12,
    )
    mix_tone(buffer, rate, 0.42, 0.12, 880.0, amplitude=0.4, kind="triangle", release=0.06)
    return normalize(buffer, 0.9)


def sfx_damage(rate: int) -> list[float]:
    """Dano: queda de pitch curta (o Guardiao apanhou)."""
    buffer = silence(0.22, rate)
    mix_tone(
        buffer,
        rate,
        0.0,
        0.2,
        lambda t: 520.0 - 1600.0 * t,
        amplitude=0.7,
        kind="saw",
        release=0.1,
    )
    mix_tone(
        buffer,
        rate,
        0.0,
        0.12,
        lambda t: 700.0 - 3000.0 * t,
        amplitude=0.25,
        kind="noise",
        release=0.06,
        noise_seed=0x7F1,
    )
    return normalize(buffer, 0.85)


def sfx_knockout(rate: int) -> list[float]:
    """Nocaute: queda longa e grave, terminando no chao."""
    buffer = silence(0.75, rate)
    mix_tone(
        buffer,
        rate,
        0.0,
        0.7,
        lambda t: 320.0 - 400.0 * t,
        amplitude=0.85,
        kind="square",
        duty=0.5,
        release=0.3,
    )
    mix_tone(
        buffer,
        rate,
        0.05,
        0.6,
        lambda t: 240.0 - 300.0 * t,
        amplitude=0.4,
        kind="triangle",
        release=0.25,
    )
    mix_tone(
        buffer,
        rate,
        0.0,
        0.3,
        lambda t: 900.0 - 2500.0 * t,
        amplitude=0.3,
        kind="noise",
        release=0.15,
        noise_seed=0x1B7,
    )
    return normalize(buffer, 0.9)


def sfx_select(rate: int) -> list[float]:
    """Selecao: confirmacao de dois tons subindo."""
    buffer = silence(0.16, rate)
    mix_tone(buffer, rate, 0.0, 0.07, 784.0, amplitude=0.5, kind="square", duty=0.5)
    mix_tone(buffer, rate, 0.06, 0.1, 1175.0, amplitude=0.5, kind="square", duty=0.5)
    return normalize(buffer, 0.85)


def sfx_navigate(rate: int) -> list[float]:
    """Navegacao: clique curto de menu."""
    buffer = silence(0.07, rate)
    mix_tone(buffer, rate, 0.0, 0.05, 523.0, amplitude=0.45, kind="square", duty=0.25)
    return normalize(buffer, 0.8)


def sfx_round_end(rate: int) -> list[float]:
    """Fim de round: arpejo curto de tres notas."""
    buffer = silence(0.45, rate)
    for index, note in enumerate(("A4", "C5", "E5")):
        mix_tone(
            buffer,
            rate,
            index * 0.09,
            0.3,
            note_frequency(note),
            amplitude=0.45,
            kind="square",
            duty=0.5,
            release=0.12,
        )
    return normalize(buffer, 0.85)


SFX_BUILDERS = {
    "impact_light": sfx_impact_light,
    "impact_heavy": sfx_impact_heavy,
    "special": sfx_special,
    "damage": sfx_damage,
    "knockout": sfx_knockout,
    "select": sfx_select,
    "navigate": sfx_navigate,
    "round_end": sfx_round_end,
}


# ---------------------------------------------------------------------------
# Musica: grade de notas por compasso
# ---------------------------------------------------------------------------


def parse_grid(pattern: str, bars: int, slots_per_bar: int) -> list[tuple[str, float]]:
    """Converte uma grade de notas em pares (nota, duracao em beats).

    Cada slot vale `4 / slots_per_bar` beats. "." sustenta a nota anterior e "r"
    e silencio. A grade tem de preencher exatamente `bars` compassos.
    """
    slots = pattern.split()
    expected = bars * slots_per_bar
    if len(slots) != expected:
        raise ValueError(f"grade com {len(slots)} slots; esperado {expected}")
    step = 4.0 / slots_per_bar
    notes: list[tuple[str, float]] = []
    for slot in slots:
        if slot == "." and notes:
            note, duration = notes[-1]
            notes[-1] = (note, duration + step)
            continue
        if slot in (".", "r"):
            note = ""
        else:
            note_frequency(slot)
            note = slot
        if notes and notes[-1][0] == note and note == "":
            notes[-1] = ("", notes[-1][1] + step)
            continue
        notes.append((note, step))
    return notes


def parse_drums(pattern: str, bars: int) -> list[str]:
    steps = pattern.replace(" ", "")
    expected = bars * 16
    if len(steps) != expected:
        raise ValueError(f"bateria com {len(steps)} passos; esperado {expected}")
    return list(steps)


def render_track(track: dict) -> list[float]:
    bars = track["bars"]
    bpm = track["bpm"]
    beat = 60.0 / bpm
    total_beats = bars * 4
    melody = parse_grid(track["melody"], bars, 8)
    bass = parse_grid(track["bass"], bars, 8)
    drums = parse_drums(track["drums"], bars)
    rate = MUSIC_RATE
    buffer = silence(total_beats * beat, rate)

    def play(notes: list[tuple[str, float]], kind: str, amplitude: float, duty: float, **kwargs) -> None:
        cursor = 0.0
        for note, duration in notes:
            length = duration * beat
            if note:
                mix_tone(
                    buffer,
                    rate,
                    cursor,
                    length * 0.96,
                    note_frequency(note),
                    amplitude=amplitude,
                    kind=kind,
                    duty=duty,
                    attack=0.008,
                    release=min(0.05, length * 0.3),
                    **kwargs,
                )
            cursor += length

    play(melody, "square", 0.42, track["duty"], decay=0.15, sustain=0.85)
    play(bass, "triangle", 0.55, 0.5)

    step = total_beats * beat / len(drums)
    for index, hit in enumerate(drums):
        start = index * step
        if hit == "k":
            mix_tone(
                buffer,
                rate,
                start,
                0.12,
                lambda t: 150.0 - 500.0 * t,
                amplitude=0.75,
                kind="square",
                duty=0.5,
                release=0.05,
            )
        elif hit == "s":
            mix_tone(
                buffer,
                rate,
                start,
                0.09,
                1000.0,
                amplitude=0.35,
                kind="noise",
                release=0.06,
                noise_seed=0x3C9,
            )
        elif hit == "h":
            mix_tone(
                buffer,
                rate,
                start,
                0.03,
                2000.0,
                amplitude=0.16,
                kind="noise",
                release=0.02,
                noise_seed=0x77A,
            )
    return normalize(buffer, 0.85)


# Contextos musicais do jogo: os mesmos nomes do contrato `AudioGateway`
# (`MUSIC_TITLE`, `MUSIC_SELECT`, `MUSIC_FIGHT`, `MUSIC_REVIRAVOLTA`, `MUSIC_RESULT`).
TRACKS = {
    "title": {
        "bpm": 96,
        "bars": 4,
        "duty": 0.5,
        "melody": (
            "A4 . C5 . E5 . . . "
            "D5 . C5 . B4 . . . "
            "C5 . E5 . A5 . . . "
            "G5 . E5 . D5 . C5 ."
        ),
        "bass": (
            "A2 . . . E3 . . . "
            "F2 . . . C3 . . . "
            "C3 . . . G3 . . . "
            "D3 . . . E3 . . ."
        ),
        "drums": "k.......s......." * 4,
    },
    "select": {
        "bpm": 132,
        "bars": 4,
        "duty": 0.25,
        "melody": (
            "G4 . A4 . B4 . C5 . "
            "D5 . C5 . B4 . G4 . "
            "E5 . D5 . C5 . B4 . "
            "C5 . . . G4 . . ."
        ),
        "bass": (
            "C3 . G2 . C3 . G2 . "
            "G2 . D3 . G2 . D3 . "
            "A2 . E3 . A2 . E3 . "
            "C3 . G2 . C3 . . ."
        ),
        "drums": "k.h.s.h.k.h.s.h." * 4,
    },
    "fight": {
        "bpm": 150,
        "bars": 4,
        "duty": 0.5,
        "melody": (
            "A4 . A4 C5 E5 . D5 . "
            "C5 . B4 . A4 . G4 . "
            "A4 . E5 . D5 . C5 . "
            "B4 . C5 . A4 . . ."
        ),
        "bass": (
            "A2 . A2 . E2 . E2 . "
            "F2 . F2 . C3 . C3 . "
            "A2 . A2 . E2 . E2 . "
            "G2 . G2 . A2 . . ."
        ),
        "drums": "k.h.s.h.k.h.s.h." * 4,
    },
    "reviravolta": {
        "bpm": 84,
        "bars": 4,
        "duty": 0.125,
        "melody": (
            "D4 . F4 . A4 . . . "
            "G4 . F4 . E4 . . . "
            "D4 . A4 . D5 . . . "
            "C5 . A4 . F4 . D4 ."
        ),
        "bass": (
            "D2 . . . A2 . . . "
            "B1 . . . F2 . . . "
            "D2 . . . A2 . . . "
            "G2 . . . D2 . . ."
        ),
        "drums": "k.......h...s..." * 4,
    },
    "result": {
        "bpm": 120,
        "bars": 2,
        "duty": 0.5,
        "melody": ("G4 . B4 . D5 . G5 . " "G5 . D5 . B4 . D5 ."),
        "bass": ("G2 . . . D3 . . . " "G3 . . . G2 . . ."),
        "drums": "k...s...k...s..." * 2,
    },
}


def synthesize() -> dict[str, tuple[bytes, int, Path]]:
    """Todos os artefatos: nome -> (bytes PCM, taxa, caminho relativo)."""
    artifacts: dict[str, tuple[bytes, int, Path]] = {}
    for name, builder in sorted(SFX_BUILDERS.items()):
        buffer = builder(SFX_RATE)
        artifacts[name] = (to_pcm_bytes(buffer), SFX_RATE, SFX_DIRECTORY / f"{name}.wav")
    for name, track in sorted(TRACKS.items()):
        buffer = render_track(track)
        artifacts[name] = (to_pcm_bytes(buffer), MUSIC_RATE, MUSIC_DIRECTORY / f"{name}.wav")
    return artifacts


def report(artifacts: dict[str, tuple[bytes, int, Path]]) -> None:
    print(f"{'arquivo':<34} {'taxa':>6} {'segundos':>9} {'bytes':>9}  sha256")
    for name, (payload, rate, path) in artifacts.items():
        seconds = len(payload) / 2 / rate
        digest = hashlib.sha256(payload).hexdigest()[:12]
        print(f"{str(path):<34} {rate:>6} {seconds:>9.2f} {len(payload):>9}  {digest}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="confere contra o repositorio")
    parser.add_argument("--stats", action="store_true", help="apenas resume")
    arguments = parser.parse_args()

    artifacts = synthesize()
    if arguments.stats:
        report(artifacts)
        return 0

    if arguments.verify:
        problems = 0
        for _name, (payload, _rate, path) in artifacts.items():
            absolute = REPOSITORY_ROOT / path
            if not absolute.exists():
                print(f"ausente: {path}", file=sys.stderr)
                problems += 1
                continue
            on_disk = absolute.read_bytes()
            with wave.open(str(absolute), "rb") as handle:
                stored = handle.readframes(handle.getnframes())
            if stored != payload:
                print(f"divergente: {path}", file=sys.stderr)
                problems += 1
        report(artifacts)
        if problems:
            print(f"{problems} artefato(s) divergentes: rode o gerador", file=sys.stderr)
            return 1
        print(f"{len(artifacts)} artefatos conferem byte a byte com o gerador")
        return 0

    for _name, (payload, rate, path) in artifacts.items():
        write_artifact(REPOSITORY_ROOT / path, payload, rate)
    report(artifacts)
    print(f"{len(artifacts)} artefatos gravados em assets/audio/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())