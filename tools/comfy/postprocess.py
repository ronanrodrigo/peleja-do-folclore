#!/usr/bin/env python3
"""Pos-processamento obrigatorio da arte gerada por IA (fase D de docs/plans/comfyui.md).

Faz, nesta ordem, e nada mais:

1. reduz para a resolucao base do jogo (426x240) com **nearest-neighbor**,
   preservando a proporcao e recortando o centro (o modelo gera quadrado);
2. quantiza a paleta para no maximo 32 cores, alinhada a paleta do jogo
   (`assets/palettes/peleja.json`);
3. grava o PNG na resolucao base -- nunca uma versao ampliada com filtro suave
   (a ampliacao 3x acontece so na renderizacao, por escala inteira).

O mapeamento de cor e deterministico: cada pixel vai para a cor mais proxima da
paleta alvo (distancia euclidiana em RGB), sem dithering e sem aleatoriedade.
Rodar duas vezes sobre a mesma entrada produz bytes identicos.

Uso:
    python3 tools/comfy/postprocess.py --input raw.png --output assets/generated/backgrounds/forest-arena.png
    python3 tools/comfy/postprocess.py --verify assets/generated/backgrounds/forest-arena.png
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import sys
from typing import Any, cast

from PIL import Image

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_PALETTE = REPO_ROOT / "assets" / "palettes" / "peleja.json"

BASE_WIDTH = 426
BASE_HEIGHT = 240
MAX_COLORS = 32
# Escala de ampliacao permitida apenas na renderizacao (ADR 0002). O arquivo
# salvo nunca sai ampliado.
RENDER_SCALE = 3


def _pixels(image: Image.Image) -> list[tuple[int, int, int]]:
    """Pixels RGB em ordem de varredura (Pillow devolve um core opaco)."""
    return [tuple(pixel) for pixel in cast(Any, image.convert("RGB").getdata())]


def load_palette(path: pathlib.Path = DEFAULT_PALETTE) -> list[tuple[int, int, int]]:
    """Le a paleta do jogo (lista de cores RGB, sem duplicatas)."""
    document = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    entries = document["colors"] if isinstance(document, dict) else document
    colors: list[tuple[int, int, int]] = []
    for entry in entries:
        rgb = entry["rgb"] if isinstance(entry, dict) else entry
        color = tuple(int(channel) for channel in rgb)
        if len(color) != 3:
            raise ValueError(f"cor invalida na paleta {path}: {entry!r}")
        if color not in colors:
            colors.append(color)
    if not colors:
        raise ValueError(f"paleta vazia: {path}")
    return colors


def _distance(left: tuple[int, int, int], right: tuple[int, int, int]) -> int:
    return sum((a - b) ** 2 for a, b in zip(left, right))


def nearest_color(
    color: tuple[int, int, int], palette: list[tuple[int, int, int]]
) -> tuple[int, int, int]:
    """Cor mais proxima da paleta alvo (empate resolvido pela ordem da paleta)."""
    return min(palette, key=lambda candidate: _distance(color, candidate))


def _adaptive_colors(image: Image.Image, wanted: int) -> list[tuple[int, int, int]]:
    """Cores dominantes da imagem, via mediana (deterministico no Pillow)."""
    if wanted <= 0:
        return []
    reduced = image.convert("RGB").quantize(colors=wanted, method=Image.Quantize.MEDIANCUT)
    raw: list[int] = [int(channel) for channel in cast(Any, reduced.getpalette()) or []]
    used = sorted(reduced.getcolors(maxcolors=1 << 24) or [], key=lambda item: -item[0])
    colors: list[tuple[int, int, int]] = []
    for entry in used:
        start = int(cast(Any, entry[1])) * 3
        color = (raw[start], raw[start + 1], raw[start + 2])
        if len(color) == 3 and color not in colors:
            colors.append(color)
    return colors


def build_target_palette(
    image: Image.Image,
    game_palette: list[tuple[int, int, int]],
    max_colors: int = MAX_COLORS,
) -> list[tuple[int, int, int]]:
    """Paleta alvo: as cores do jogo primeiro, completadas pelas dominantes da imagem.

    As cores da identidade visual entram sempre; o resto das 32 vagas e
    preenchido com as cores dominantes da propria arte, na ordem da mediana.
    """
    target = list(game_palette[:max_colors])
    for color in _adaptive_colors(image, max_colors):
        if len(target) >= max_colors:
            break
        if color not in target:
            target.append(color)
    return target


def quantize(
    image: Image.Image,
    target: list[tuple[int, int, int]],
) -> Image.Image:
    """Remapeia cada pixel para a cor mais proxima da paleta alvo."""
    source = image.convert("RGB")
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    mapped: list[tuple[int, int, int]] = []
    for pixel in _pixels(source):
        if pixel not in cache:
            cache[pixel] = nearest_color(pixel, target)
        mapped.append(cache[pixel])
    out = Image.new("RGB", source.size, target[0])
    out.putdata(mapped)
    return out


def count_colors(image: Image.Image) -> int:
    return len(set(_pixels(image)))


def fit_to_base(
    image: Image.Image, size: tuple[int, int] = (BASE_WIDTH, BASE_HEIGHT)
) -> Image.Image:
    """Ajusta a imagem a resolucao base: nearest-neighbor + recorte central.

    O modelo gera quadrado (512x512) e a resolucao base e 16:9. Primeiro
    reduzimos por escala preservando a proporcao (sempre nearest), depois
    recortamos o centro na proporcao da resolucao base. Nada de filtro suave e
    nada de escala fracionaria aplicada ao arquivo final.
    """
    target_width, target_height = size
    source_width, source_height = image.size
    scale = max(target_width / source_width, target_height / source_height)
    resized = image.resize(
        (max(1, round(source_width * scale)), max(1, round(source_height * scale))),
        Image.Resampling.NEAREST,
    )
    left = (resized.size[0] - target_width) // 2
    top = (resized.size[1] - target_height) // 2
    return resized.crop((left, top, left + target_width, top + target_height))


def postprocess(
    input_path: pathlib.Path,
    output_path: pathlib.Path,
    palette_path: pathlib.Path = DEFAULT_PALETTE,
    size: tuple[int, int] = (BASE_WIDTH, BASE_HEIGHT),
    max_colors: int = MAX_COLORS,
) -> dict:
    """Executa o pipeline e devolve as medidas do arquivo salvo."""
    game_palette = load_palette(palette_path)
    with Image.open(input_path) as source:
        # 1. resolucao base: nearest-neighbor preservando proporcao + recorte central.
        reduced = fit_to_base(source.convert("RGB"), size)
    # 2. quantizacao: paleta do jogo + dominantes da arte, no maximo 32 cores.
    target = build_target_palette(reduced, game_palette, max_colors)
    quantized = quantize(reduced, target)
    colors = count_colors(quantized)
    if colors > max_colors:
        raise SystemExit(f"quantizacao falhou: {colors} cores > {max_colors}")
    if quantized.size != size:
        raise SystemExit(f"tamanho errado: {quantized.size} != {size}")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    quantized.save(output_path, format="PNG", optimize=True)
    return {
        "input": str(input_path),
        "output": str(output_path),
        "size": [quantized.size[0], quantized.size[1]],
        "colors": colors,
        "palette_size": len(target),
        "game_colors_kept": sum(1 for color in game_palette if color in set(_pixels(quantized))),
        "max_colors": max_colors,
        "resample": "NEAREST",
        "crop": "center",
        "render_scale": RENDER_SCALE,
        "bytes": output_path.stat().st_size,
        "sha256": hashlib.sha256(output_path.read_bytes()).hexdigest(),
    }


def verify(path: pathlib.Path, max_colors: int = MAX_COLORS) -> bool:
    """Confere um PNG ja publicado: 426x240 e no maximo 32 cores."""
    with Image.open(path) as image:
        size = image.size
        colors = count_colors(image)
    ok = size == (BASE_WIDTH, BASE_HEIGHT) and colors <= max_colors
    print(
        f"{'ok  ' if ok else 'FALHA'} {path} {size[0]}x{size[1]} cores={colors} "
        f"(limite {max_colors})"
    )
    return ok


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=pathlib.Path, help="PNG cru saído do ComfyUI")
    parser.add_argument("--output", type=pathlib.Path, help="PNG final em assets/generated/")
    parser.add_argument("--palette", type=pathlib.Path, default=DEFAULT_PALETTE)
    parser.add_argument("--max-colors", type=int, default=MAX_COLORS)
    parser.add_argument("--verify", type=pathlib.Path, nargs="+", help="valida PNGs ja salvos")
    args = parser.parse_args(argv)

    if args.verify:
        return 0 if all(verify(path, args.max_colors) for path in args.verify) else 1
    if not args.input or not args.output:
        parser.error("--input e --output sao obrigatorios sem --verify")
    report = postprocess(args.input, args.output, args.palette, max_colors=args.max_colors)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
