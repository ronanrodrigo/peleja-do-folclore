#!/usr/bin/env python3
"""Maquinaria compartilhada dos geradores de spritesheet codificado.

A arte de lutador do jogo nao e PNG binario opaco (ADR 0005): e dado versionado
(paleta + matrizes de pixel) em JSON. Este modulo e a fronteira de ferramentaria
comum a todos os lutadores -- matriz de caracteres, contorno por silhueta,
codificacao compacta e previa em PNG. Os scripts de cada Guardiao trazem apenas o
desenho, e o JSON commitado segue sendo a fonte de verdade validada por teste.

    python3 tools/art/build_saci_spritesheet.py --preview /tmp/saci.png
    python3 tools/art/build_cast_spritesheets.py --preview /tmp/elenco.png
"""

from __future__ import annotations

import json
import pathlib

TRANSPARENT = "."
ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"


class Grid:
    """Matriz de caracteres: cada caractere e um indice da paleta."""

    def __init__(self, width: int, height: int, fill: str = TRANSPARENT) -> None:
        self.width = width
        self.height = height
        self.rows = [[fill] * width for _ in range(height)]

    def pixel(self, x: int, y: int, char: str) -> None:
        if 0 <= x < self.width and 0 <= y < self.height:
            self.rows[y][x] = char

    def rect(self, x: int, y: int, width: int, height: int, char: str) -> None:
        for row in range(y, y + height):
            for column in range(x, x + width):
                self.pixel(column, row, char)

    def line(self, x0: int, x1: int, y: int, char: str) -> None:
        for column in range(min(x0, x1), max(x0, x1) + 1):
            self.pixel(column, y, char)

    def column(self, x: int, y0: int, y1: int, char: str) -> None:
        for row in range(min(y0, y1), max(y0, y1) + 1):
            self.pixel(x, row, char)

    def paste(self, other: "Grid", x: int, y: int) -> None:
        for row in range(other.height):
            for column in range(other.width):
                char = other.rows[row][column]
                if char != TRANSPARENT:
                    self.pixel(x + column, y + row, char)

    def to_text(self) -> list[str]:
        return ["".join(row) for row in self.rows]

    def dump(self) -> str:
        return "\n".join(self.to_text())


def outline(grid: Grid) -> None:
    """Contorno por silhueta: so os pixels vazios que encostam no corpo.

    Desenhar cada membro com contorno proprio transforma o lutador num bloco
    escuro; contornar a silhueta inteira mantem a leitura de braco, perna e
    adorno separados.
    """
    body = [row[:] for row in grid.rows]
    for y in range(grid.height):
        for x in range(grid.width):
            if body[y][x] != TRANSPARENT:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < grid.width and 0 <= ny < grid.height:
                    if body[ny][nx] != TRANSPARENT and body[ny][nx] != "k":
                        grid.pixel(x, y, "k")
                        break


def encode_rows(grid: Grid) -> list[str]:
    """Linhas na codificacao compacta do formato (um caractere por pixel)."""
    return [
        "".join(
            TRANSPARENT if char == TRANSPARENT else ALPHABET[CHAR_INDEX[char]]
            for char in row
        )
        for row in grid.to_text()
    ]


# Preenchido por `bind_palette`: caractere -> indice da paleta do lutador.
CHAR_INDEX: dict[str, int] = {}


def bind_palette(char_index: dict[str, int]) -> None:
    """Fixa a tabela caractere -> indice usada por `encode_rows`."""
    global CHAR_INDEX
    CHAR_INDEX = dict(char_index)


def build_spritesheet(slug: str, palette: list[str], animations: dict[str, list[Grid]]) -> dict:
    """Monta o dicionario do formato a partir das matrizes desenhadas."""
    encoded: dict[str, list[dict]] = {}
    for name, frames in animations.items():
        for frame in frames:
            for row in frame.to_text():
                assert len(row) == frame.width, f"{name}: linha com largura errada"
        encoded[name] = [
            {"width": frame.width, "height": frame.height, "pixels": encode_rows(frame)}
            for frame in frames
        ]
    return {"slug": slug, "version": 1, "palette": palette, "animations": encoded}


def write_spritesheet(data: dict, output: pathlib.Path) -> int:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    frames = sum(len(items) for items in data["animations"].values())
    print(
        f"spritesheet: {output} -- {len(data['animations'])} animacoes, "
        f"{frames} frames, paleta de {len(data['palette'])} cores"
    )
    return frames


def parse_hex(value: str) -> tuple[int, int, int, int]:
    value = value.lstrip("#")
    return (
        int(value[0:2], 16),
        int(value[2:4], 16),
        int(value[4:6], 16),
        int(value[6:8], 16),
    )


def decode_frame(data: dict, frame: dict):
    from PIL import Image

    palette = [parse_hex(color) for color in data["palette"]]
    image = Image.new("RGBA", (frame["width"], frame["height"]), (0, 0, 0, 0))
    pixels = image.load()
    for y, row in enumerate(frame["pixels"]):
        for x, char in enumerate(row):
            index = 0 if char == TRANSPARENT else ALPHABET.index(char)
            pixels[x, y] = palette[index]
    return image


def render_preview(data: dict, path: pathlib.Path, scale: int = 3) -> None:
    from PIL import Image, ImageDraw

    animations = data["animations"]
    columns = max(len(frames) for frames in animations.values())
    cell_width = max(frame["width"] for frames in animations.values() for frame in frames)
    cell_height = max(frame["height"] for frames in animations.values() for frame in frames)
    padding = 4
    label_height = 10
    sheet = Image.new(
        "RGBA",
        (
            (cell_width + padding) * columns + padding,
            (cell_height + padding + label_height) * len(animations) + padding,
        ),
        (18, 18, 42, 255),
    )
    draw = ImageDraw.Draw(sheet)
    for row_index, (name, frames) in enumerate(animations.items()):
        y = padding + row_index * (cell_height + padding + label_height) + label_height
        for column, frame in enumerate(frames):
            image = decode_frame(data, frame)
            x = padding + column * (cell_width + padding)
            sheet.paste(image, (x, y), image)
        draw.text((padding, y - label_height + 1), name, fill=(255, 211, 92, 255))
    sheet = sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
    print(f"preview: {path} ({sheet.width}x{sheet.height})")