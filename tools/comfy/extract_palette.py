#!/usr/bin/env python3
"""Extrai a paleta do jogo a partir das cores da tela de titulo.

A identidade visual do projeto vive hoje em `scenes/title_screen.gd` (constantes
`COLOR_*` escritas com `Color8`). Este script le essas constantes e materializa
`assets/palettes/peleja.json`, que e a paleta de referencia usada pelo
pos-processamento da arte gerada por IA (`tools/comfy/postprocess.py`).

Nao inventa cor: toda entrada vem de uma constante da tela de titulo. Se a tela
de titulo ganhar uma cor nova, rode este script de novo e o diff mostra a
mudanca.

Uso:
    python3 tools/comfy/extract_palette.py            # regenera assets/palettes/peleja.json
    python3 tools/comfy/extract_palette.py --check     # falha (exit 1) se o arquivo estiver defasado
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = REPO_ROOT / "scenes" / "title_screen.gd"
OUTPUT = REPO_ROOT / "assets" / "palettes" / "peleja.json"

COLOR_PATTERN = re.compile(
    r"const\s+COLOR_([A-Z0-9_]+)\s*:=\s*Color8\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)"
)

MAX_COLORS = 32


def extract(source_path: pathlib.Path = SOURCE) -> dict:
    """Le as constantes COLOR_* da tela de titulo e devolve o documento da paleta."""
    if not source_path.exists():
        raise SystemExit(f"tela de titulo nao encontrada: {source_path}")
    text = source_path.read_text(encoding="utf-8")
    colors = []
    seen = set()
    for name, red, green, blue in COLOR_PATTERN.findall(text):
        rgb = (int(red), int(green), int(blue))
        if rgb in seen:
            continue
        seen.add(rgb)
        colors.append(
            {
                "name": name.lower().replace("_", "-"),
                "rgb": list(rgb),
                "hex": "#%02x%02x%02x" % rgb,
            }
        )
    if not colors:
        raise SystemExit(f"nenhuma constante COLOR_* encontrada em {source_path}")
    return {
        "id": "peleja",
        "source": str(source_path.relative_to(REPO_ROOT)),
        "generated_by": "tools/comfy/extract_palette.py",
        "max_colors": MAX_COLORS,
        "colors": colors,
    }


def render(document: dict) -> str:
    """JSON legivel: um objeto de cor por linha (o arquivo e revisado em PR)."""
    header = {key: document[key] for key in ("id", "source", "generated_by", "max_colors")}
    lines = ["{"]
    for key, value in header.items():
        lines.append(f'  {json.dumps(key)}: {json.dumps(value, ensure_ascii=False)},')
    lines.append('  "colors": [')
    for index, color in enumerate(document["colors"]):
        comma = "," if index < len(document["colors"]) - 1 else ""
        lines.append(f"    {json.dumps(color, ensure_ascii=False)}{comma}")
    lines.append("  ]")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="nao escreve: apenas verifica se assets/palettes/peleja.json esta atualizado",
    )
    args = parser.parse_args(argv)
    document = extract()
    rendered = render(document)
    if args.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != rendered:
            print(f"paleta defasada: rode python3 tools/comfy/extract_palette.py ({OUTPUT})")
            return 1
        print(f"paleta atualizada: {OUTPUT} ({len(document['colors'])} cores)")
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(rendered, encoding="utf-8")
    print(f"paleta escrita: {OUTPUT} ({len(document['colors'])} cores)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
