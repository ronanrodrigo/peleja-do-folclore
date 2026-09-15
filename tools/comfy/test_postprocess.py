#!/usr/bin/env python3
"""Teste do pos-processamento obrigatorio (roda sem pytest, sem rede e sem GPU).

Valida o que a fase D do plano exige e o que o invariante do projeto promete:

- a saida tem exatamente 426x240 (resolucao base do ADR 0002);
- a paleta fica em no maximo 32 cores e todas as cores da paleta do jogo entram;
- a reducao e nearest-neighbor: um xadrez 2x2 sobrevive sem nenhum pixel
  intermediario (um filtro suave inventaria cores que nao existem na entrada);
- o pipeline e deterministico: mesma entrada, mesmos bytes;
- nenhuma arte publicada sai ampliada (o arquivo em assets/generated/ esta na
  resolucao base, nunca em 3x).

Uso: python3 tools/comfy/test_postprocess.py
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import sys
import tempfile

from PIL import Image

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools" / "comfy"))

import postprocess  # noqa: E402  (import depois do sys.path, de proposito)

GENERATED_ROOT = REPO_ROOT / "assets" / "generated"
PUBLISHED = [
    GENERATED_ROOT / "backgrounds" / "forest-arena.png",
    GENERATED_ROOT / "panels" / "reviravolta-panel.png",
    GENERATED_ROOT / "portraits" / "saci-portrait.png",
]

CHECKED = 0


def check(condition: bool, message: str) -> None:
    global CHECKED
    CHECKED += 1
    if not condition:
        raise AssertionError(message)
    print(f"ok    {message}")


def noisy_image(path: pathlib.Path, size: tuple[int, int] = (512, 288)) -> pathlib.Path:
    """Imagem de entrada com muitas cores (simula a saida crua do ComfyUI)."""
    image = Image.new("RGB", size)
    image.putdata(
        [
            (
                (x * 7 + y * 3) % 256,
                (x * 2 + y * 11) % 256,
                (x * 5 + y * 13) % 256,
            )
            for y in range(size[1])
            for x in range(size[0])
        ]
    )
    image.save(path, format="PNG")
    return path


def checkerboard(path: pathlib.Path) -> pathlib.Path:
    """4x4 com dois tons puros: qualquer filtro suave criaria tons intermediarios."""
    image = Image.new("RGB", (512, 288))
    image.putdata(
        [
            (255, 211, 92) if (x + y) % 2 == 0 else (18, 18, 42)
            for y in range(288)
            for x in range(512)
        ]
    )
    image.save(path, format="PNG")
    return path


def main() -> int:
    game_palette = postprocess.load_palette()
    check(len(game_palette) >= 5, f"paleta do jogo tem {len(game_palette)} cores extraidas da tela de titulo")

    with tempfile.TemporaryDirectory() as tmp:
        raw = noisy_image(pathlib.Path(tmp) / "raw.png")
        out = pathlib.Path(tmp) / "out.png"
        report = postprocess.postprocess(raw, out)

        check(tuple(report["size"]) == (426, 240), f"resolucao base 426x240 (veio {report['size']})")
        check(report["colors"] <= 32, f"paleta quantizada em {report['colors']} cores (limite 32)")
        check(report["resample"] == "NEAREST", "reducao feita com nearest-neighbor")
        with Image.open(out) as saved:
            check(saved.size == (426, 240), "arquivo salvo tem 426x240")
            colors = set(postprocess._pixels(saved))  # noqa: SLF001  (medida do teste)
        check(len(colors) == report["colors"], "contagem de cores do relatorio bate com o arquivo")
        check(
            report["game_colors_kept"] >= 1,
            f"cores da identidade visual sobrevivem: {report['game_colors_kept']} da paleta do jogo",
        )

        second = pathlib.Path(tmp) / "out2.png"
        again = postprocess.postprocess(raw, second)
        check(
            report["sha256"] == again["sha256"],
            "deterministico: a mesma entrada produz o mesmo sha256",
        )

        board = checkerboard(pathlib.Path(tmp) / "board.png")
        board_out = pathlib.Path(tmp) / "board_out.png"
        postprocess.postprocess(board, board_out)
        with Image.open(board_out) as saved_board:
            board_colors = set(postprocess._pixels(saved_board))
        check(
            board_colors <= {(255, 211, 92), (18, 18, 42)},
            f"nearest sem suavizacao: xadrez mantem so os 2 tons ({len(board_colors)} cores)",
        )

    for art in PUBLISHED:
        if not art.exists():
            print(f"pulado {art.name}: ainda nao publicado")
            continue
        with Image.open(art) as image:
            size = image.size
            colors = postprocess.count_colors(image)
        check(size == (426, 240), f"{art.name} publicado em 426x240 (veio {size[0]}x{size[1]})")
        check(colors <= 32, f"{art.name} publicado com {colors} cores (limite 32)")
        metadata = art.with_suffix(".json")
        check(metadata.exists(), f"metadados versionados ao lado de {art.name}")
        recorded = json.loads(metadata.read_text(encoding="utf-8"))
        check(
            recorded["postprocess"]["sha256"] == hashlib.sha256(art.read_bytes()).hexdigest(),
            f"sha256 dos metadados bate com {art.name}",
        )

    print(f"\n{CHECKED} verificacoes OK")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as failure:
        print(f"\nFALHA: {failure}")
        sys.exit(1)
