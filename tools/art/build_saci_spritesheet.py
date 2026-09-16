#!/usr/bin/env python3
"""Gera assets/spritesheets/saci.json: a arte do Saci como DADO versionado.

A arte de lutador do jogo nao e PNG binario opaco (ADR 0005): e uma paleta mais
matrizes de pixel, versionadas em JSON. Este script e a fronteira de autoria --
ele desenha o Saci com primitivas e emite o formato que
`src/domain/spritesheet.gd` valida. Rode:

    python3 tools/art/build_saci_spritesheet.py            # escreve o JSON
    python3 tools/art/build_saci_spritesheet.py --preview P.png

O JSON e commitado; este script existe para reproduzir e ajustar a arte.
"""

from __future__ import annotations

import argparse
import json
import pathlib

from pixel_grid import (
    ALPHABET,
    Grid,
    TRANSPARENT,
    bind_palette,
    build_spritesheet as build_data,
    outline,
    parse_hex,
    render_preview,
    write_spritesheet,
)

# Paleta do Saci, indexada pela ordem abaixo (o indice 0 e o transparente).
PALETTE = [
    "#00000000",  # 0  .  transparente
    "#14121aff",  # 1  k  contorno
    "#6b3f22ff",  # 2  d  pele em sombra
    "#c87f3cff",  # 3  s  pele (base)
    "#d02b26ff",  # 4  R  gorro vermelho
    "#8f1f1cff",  # 5  r  vermelho escuro (aba e sombra)
    "#f5efe0ff",  # 6  w  branco (olho, fumaca, dente)
    "#7a4a24ff",  # 7  b  cachimbo
    "#8fe0d0ff",  # 8  c  vento claro
    "#2f8f86ff",  # 9  C  vento escuro
    "#ffd35cff",  # 10 y  amarelo do folclore (cinto/brilho)
    "#20182aff",  # 11 e  pupila
]

OUT = "k"
SKIN = "d"
SKIN_L = "s"
RED = "R"
RED_D = "r"
WHITE = "w"
PIPE = "b"
WIND = "c"
WIND_D = "C"
GOLD = "y"
EYE = "e"
## Linha de sombra dos antebracos cruzados (a mesma sombra da pele).
SHADE_LINE = SKIN

CHAR_INDEX = {
    TRANSPARENT: 0,
    "k": 1,
    "d": 2,
    "s": 3,
    "R": 4,
    "r": 5,
    "w": 6,
    "b": 7,
    "c": 8,
    "C": 9,
    "y": 10,
    "e": 11,
}
assert CHAR_INDEX[OUT] == 1 and CHAR_INDEX[EYE] == 11 and len(CHAR_INDEX) == len(PALETTE)



def draw_cap(grid: Grid, center_x: int, top: int, scale: int = 1) -> int:
    """Gorro vermelho pontudo, com aba escura. Devolve a linha abaixo da aba."""
    widths = [2, 4, 4, 6, 6, 8]
    for offset, width in enumerate(widths):
        grid.line(center_x - width // 2, center_x - width // 2 + width - 1, top + offset, RED)
    grid.line(center_x - 1, center_x, top + 1, WHITE)  # brilho da ponta
    brim = top + len(widths)
    for offset in range(2 * scale):
        half = 6 - offset
        char = RED_D if offset == 0 else RED
        grid.line(center_x - half, center_x + half - 1, brim + offset, char)
    return brim + 2 * scale


def draw_head(
    grid: Grid, x: int, y: int, eyes: bool = True, mouth: str = "fechada", shade: str = SKIN
) -> None:
    """Cabeca 8x7 com olhos e boca."""
    grid.rect(x, y, 8, 7, SKIN_L)
    grid.column(x + 7, y, y + 6, shade)
    if eyes:
        for eye_x in (x + 1, x + 4):
            grid.rect(eye_x, y + 2, 2, 2, WHITE)
            grid.line(eye_x, eye_x + 1, y + 3, EYE)
    if mouth == "aberta":
        grid.rect(x + 2, y + 5, 4, 2, OUT)
        grid.line(x + 3, x + 4, y + 5, WHITE)
    elif mouth != "sem":
        grid.line(x + 2, x + 5, y + 5, OUT)


def draw_pipe(grid: Grid, x: int, y: int, scale: int = 1) -> None:
    """Cachimbo: haste curta, fornilho aceso e fumaca subindo."""
    grid.rect(x, y, 5 * scale, 1, PIPE)
    grid.rect(x + 4 * scale, y - 2 * scale, 3, 3 * scale, PIPE)
    grid.rect(x + 5 * scale, y - 2 * scale, 1, 1, GOLD)
    grid.rect(x + 8 * scale, y - 5 * scale, 2, 1, WHITE)
    grid.rect(x + 9 * scale, y - 7 * scale, 2, 1, WHITE)


def draw_torso(grid: Grid, x: int, y: int, arms: str = "baixo", shade: str = SKIN) -> None:
    """Tronco 8x8 (pescoco acima, cinto abaixo) com bracos na pose pedida."""
    grid.line(x + 2, x + 5, y - 1, SKIN)  # pescoco
    grid.rect(x, y, 8, 8, SKIN_L)
    grid.column(x + 7, y, y + 6, shade)
    if arms == "baixo":
        grid.rect(x - 2, y + 1, 2, 6, SKIN_L)
        grid.rect(x + 8, y + 1, 2, 6, SKIN_L)
    elif arms == "frente":
        grid.rect(x + 8, y + 1, 7, 3, SKIN_L)
        grid.rect(x + 13, y + 1, 2, 3, SKIN)
        grid.rect(x - 3, y + 2, 3, 5, SKIN_L)
    elif arms == "golpe":
        grid.rect(x + 8, y, 7, 4, SKIN_L)
        grid.rect(x + 13, y, 3, 4, SKIN)
        grid.rect(x - 3, y + 2, 3, 5, SKIN_L)
    elif arms == "guarda":
        # antebracos na frente do peito, num tom escuro: leitura imediata de defesa
        grid.rect(x - 4, y + 3, 4, 5, SKIN_L)
        grid.rect(x + 8, y + 3, 4, 5, SKIN_L)
        grid.rect(x - 1, y - 1, 10, 4, SKIN)
        grid.line(x - 1, x + 8, y - 2, OUT)
    elif arms == "cruzados":
        grid.rect(x - 1, y + 1, 10, 3, SKIN_L)
        grid.line(x - 1, x + 8, y + 3, OUT)
        grid.rect(x - 1, y + 4, 10, 3, SKIN_L)
        grid.line(x - 1, x + 8, y + 4, OUT)
    elif arms == "swing":
        grid.rect(x - 3, y + 1, 3, 5, SKIN_L)
        grid.rect(x + 8, y - 1, 3, 5, SKIN_L)
    elif arms == "para_cima":
        grid.rect(x - 2, y - 5, 3, 7, SKIN_L)
        grid.rect(x + 7, y - 5, 3, 7, SKIN_L)
    elif arms == "tras":
        grid.rect(x - 4, y + 1, 3, 5, SKIN_L)
        grid.rect(x + 9, y + 1, 3, 5, SKIN_L)
    grid.line(x, x + 7, y + 7, GOLD)  # cinto


def draw_shorts(grid: Grid, x: int, y: int) -> None:
    grid.rect(x - 1, y, 10, 3, RED)
    grid.line(x - 1, x + 8, y + 1, RED_D)


def draw_leg(grid: Grid, center_x: int, y: int, offset: int = 0, length: int = 4) -> None:
    """Uma perna so: o quadro da lenda."""
    grid.rect(center_x - 2 + offset, y, 4, length, SKIN_L)
    grid.column(center_x + 1 + offset, y, y + length - 1, SKIN)
    grid.rect(center_x - 3 + offset, y + length - 1, 6, 2, SKIN_L)
    grid.line(center_x - 3 + offset, center_x + 2 + offset, y + length, SKIN)


def draw_wind(grid: Grid, center_x: int, y: int, level: int) -> None:
    """Redemoinho de folhas ao redor do pe, do chao para cima."""
    if level <= 0:
        return
    grid.line(center_x - 9, center_x - 4, y + 3, WIND_D)
    grid.line(center_x + 5, center_x + 10, y + 2, WIND)
    if level > 1:
        grid.line(center_x - 12, center_x - 6, y + 1, WIND)
        grid.line(center_x + 7, center_x + 12, y, WIND_D)
    if level > 2:
        grid.line(center_x - 8, center_x - 5, y + 5, WIND)
        grid.line(center_x + 6, center_x + 9, y + 4, WIND_D)
        grid.line(center_x - 14, center_x - 8, y - 1, WIND_D)


def standing_pose(
    *,
    bob: int = 0,
    arms: str = "baixo",
    leg_offset: int = 0,
    eyes: bool = True,
    mouth: str = "fechada",
    wind: int = 1,
    body_shift: int = 0,
    cap_shift: int = 0,
    cap_tilt: int = 0,
    lean: int = 0,
) -> Grid:
    """Corpo padrao 24x34, do qual saem quase todas as animacoes.

    `lean` inclina a parte de cima para tras (cabeca, gorro, cachimbo e ombros),
    como num golpe recebido; `body_shift` desloca o corpo inteiro.
    """
    grid = Grid(24, 34)
    center = 11 + body_shift
    draw_cap(grid, center + 1 + cap_tilt + lean, 2 + cap_shift)
    draw_head(grid, center - 3 + lean, 10 + cap_shift + bob, eyes, mouth)
    draw_pipe(grid, center + 5 + lean, 15 + cap_shift + bob)
    draw_torso(grid, center - 3 + lean // 2, 18 + bob, arms)
    draw_shorts(grid, center - 3, 26 + bob)
    draw_leg(grid, center, 29, leg_offset, max(4 - bob, 2))
    draw_wind(grid, center, 30, wind)
    outline(grid)
    return grid


def crouch_pose(bob: int = 0) -> Grid:
    """Agachado 26x20: corpo encolhido, hurtbox mais baixa e mais larga."""
    grid = Grid(26, 20)
    draw_cap(grid, 13, 0)
    draw_head(grid, 9, 7 + bob, mouth="fechada")
    draw_pipe(grid, 17, 10 + bob)
    grid.rect(9, 13 + bob, 8, 5, SKIN_L)
    grid.column(16, 13 + bob, 17 + bob, SKIN)
    grid.line(9, 16, 15 + bob, GOLD)
    grid.rect(6, 12 + bob, 3, 5, SKIN_L)  # braco apoiado
    grid.rect(17, 12 + bob, 3, 5, SKIN_L)
    grid.rect(8, 18, 10, 2, RED)
    grid.line(8, 17, 19, RED_D)
    draw_wind(grid, 13, 16, 2)
    outline(grid)
    return grid


def punch_pose(frame: int) -> Grid:
    grid = standing_pose(arms="golpe" if frame == 1 else "guarda", wind=0)
    if frame == 0:
        # meio golpe: o braco ainda esta no meio do caminho
        grid.rect(16, 19, 5, 4, SKIN_L)
        grid.rect(16, 18, 2, 5, TRANSPARENT)
        outline(grid)
    return grid


def kick_pose(frame: int) -> Grid:
    """Voadora de uma perna so: o corpo inclina e a perna unica sai na altura do
    quadril. O quadro e mais largo para o chute caber inteiro (nada de membro
    cortado pela borda). `frame` 1 e o chute esticado, 0 e a partida."""
    grid = Grid(32, 34)
    center = 13
    draw_cap(grid, center + 2, 2)
    draw_head(grid, center - 2, 10)
    draw_pipe(grid, center + 6, 15)
    draw_torso(grid, center - 1, 18, "guarda")
    draw_shorts(grid, center - 1, 26)
    length = 13 if frame == 1 else 8
    grid.rect(center + 3, 22, length, 4, SKIN_L)  # a perna unica, esticada
    grid.rect(center + 3 + length - 3, 22, 3, 4, SKIN)
    grid.rect(center - 4, 22, 5, 5, SKIN_L)  # tronco apoiado para tras
    draw_wind(grid, center - 4, 30, 2)
    outline(grid)
    return grid


def grab_pose(frame: int) -> Grid:
    return standing_pose(arms="frente", leg_offset=1 if frame == 1 else 0, wind=0)


def block_pose(bob: int) -> Grid:
    return standing_pose(arms="cruzados", wind=0, bob=bob)


def hurt_pose(frame: int) -> Grid:
    grid = standing_pose(
        arms="tras",
        mouth="aberta",
        wind=0,
        body_shift=-1 if frame == 0 else -2,
        cap_shift=1,
        cap_tilt=-1,
        lean=-3 if frame == 0 else -5,
    )
    # o pe de apoio recua: o corpo foi jogado para tras
    grid.rect(8, 31, 5, 2, OUT)
    outline(grid)
    return grid


def ko_pose(frame: int) -> Grid:
    """Nocaute 34x20: caindo de lado e depois caido, com o gorro no chao."""
    grid = Grid(34, 20)
    if frame == 0:
        # corpo ja tombando: blocos em diagonal, cabeca para baixo
        grid.rect(11, 3, 12, 4, SKIN_L)
        grid.rect(8, 6, 12, 4, SKIN_L)
        grid.rect(5, 9, 12, 4, SKIN_L)
        grid.rect(2, 12, 6, 6, SKIN_L)  # cabeca no chao
        grid.rect(3, 15, 2, 1, OUT)  # olho fechado
        draw_cap(grid, 9, 0, scale=1)
        grid.rect(14, 1, 5, 4, SKIN_L)  # braco para tras
        draw_wind(grid, 24, 14, 2)
        outline(grid)
        return grid
    grid.rect(6, 13, 16, 6, SKIN_L)  # tronco caido
    grid.rect(2, 12, 7, 7, SKIN_L)  # cabeca
    grid.rect(3, 14, 2, 2, OUT)  # olho fechado
    grid.rect(21, 14, 11, 4, SKIN_L)  # a perna unica, esticada
    grid.rect(7, 18, 6, 2, RED)  # cinto no chao
    grid.rect(14, 7, 7, 6, RED)  # gorro caido
    grid.line(14, 20, 7, RED_D)
    grid.rect(13, 12, 9, 2, RED_D)
    draw_wind(grid, 31, 15, 3)
    outline(grid)
    return grid


def draw_tornado(grid: Grid, center_x: int, top: int, bottom: int, width: int) -> None:
    """Turbilhao: faixas que estreitam para cima, alternando cor, deslocamento e
    falhas -- o desenho e deterministico, mas nao geometrico."""
    height = max(bottom - top, 1)
    for index in range(height):
        progress = index / max(height - 1, 1)
        band = int(width * (1.0 - progress * 0.82))
        band = max(band - band % 2, 4)
        y = bottom - index
        color = WIND if index % 2 == 0 else WIND_D
        left = center_x - band // 2 + (index % 3) - 1
        if index % 5 == 2:  # falha: o turbilhao respira
            grid.line(left, left + band // 3, y, color)
            grid.line(left + band // 2, left + band - 1, y, color)
        else:
            grid.line(left, left + band - 1, y, color)
        if index % 3 == 0:
            grid.pixel(left - 3, y, WIND_D)  # folhas soltas girando
            grid.pixel(left + band + 2, y, WIND)
    grid.line(center_x - 3, center_x + 2, top - 1, WIND)
    grid.line(center_x - 6, center_x + 5, top - 2, WIND_D)


def special_pose(frame: int) -> Grid:
    """Redemoinho 40x40: o turbilhao cresce e o Saci reaparece dentro dele."""
    grid = Grid(40, 40)
    if frame == 0:
        grid.paste(standing_pose(wind=3), 8, 5)
        outline(grid)
        return grid
    if frame == 1:
        draw_tornado(grid, 20, 13, 39, 32)
        # o Saci e levantado por cima do turbilhao, com os bracos abertos
        draw_cap(grid, 21, 0)
        draw_head(grid, 16, 8)
        draw_pipe(grid, 25, 12)
        grid.rect(13, 15, 3, 5, SKIN_L)
        grid.rect(24, 15, 3, 5, SKIN_L)
        outline(grid)
        return grid
    draw_tornado(grid, 20, 3, 39, 36)
    # dentro do turbilhao: o Saci inteiro, com o vento cruzando na frente dele
    draw_cap(grid, 21, 1)
    grid.rect(16, 9, 8, 7, SKIN_L)
    grid.column(23, 9, 15, SKIN)
    for eye_x in (17, 20):
        grid.rect(eye_x, 11, 2, 2, WHITE)
        grid.line(eye_x, eye_x + 1, 12, EYE)
    grid.line(22, 25, 14, PIPE)
    grid.rect(26, 12, 3, 3, PIPE)
    grid.rect(16, 16, 8, 6, SKIN_L)
    grid.column(23, 16, 21, SKIN)
    grid.line(16, 23, 21, GOLD)
    grid.rect(12, 17, 4, 5, SKIN_L)  # bracos abertos dentro do vento
    grid.rect(24, 17, 4, 5, SKIN_L)
    grid.rect(17, 22, 4, 6, SKIN_L)  # a perna unica
    grid.rect(15, 28, 8, 2, SKIN_L)
    outline(grid)
    for y, band in ((18, 30), (24, 34), (30, 36)):  # o vento passa na frente
        grid.line(20 - band // 2, 20 + band // 2, y, WIND if y % 3 == 0 else WIND_D)
    return grid


def build_animations() -> dict[str, list[Grid]]:
    return {
        "idle": [standing_pose(wind=1), standing_pose(bob=1, wind=1)],
        "walk": [
            standing_pose(arms="swing", leg_offset=2, wind=1),
            standing_pose(arms="baixo", bob=1, wind=1),
            standing_pose(arms="swing", leg_offset=-2, wind=1),
            standing_pose(arms="baixo", bob=1, wind=1),
        ],
        "crouch": [crouch_pose(0), crouch_pose(1)],
        "block": [block_pose(0), block_pose(1)],
        "light": [punch_pose(0), punch_pose(1)],
        "heavy": [kick_pose(0), kick_pose(1)],
        "grab": [grab_pose(0), grab_pose(1)],
        "special": [special_pose(0), special_pose(1), special_pose(2)],
        "hurt": [hurt_pose(0), hurt_pose(1)],
        "ko": [ko_pose(0), ko_pose(1)],
    }



def build_spritesheet() -> dict:
    """Dicionario do formato do Saci, a partir das matrizes desenhadas."""
    bind_palette(CHAR_INDEX)
    return build_data("saci", PALETTE, build_animations())

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        default="assets/spritesheets/saci.json",
        help="caminho do JSON de saida",
    )
    parser.add_argument("--preview", help="grava um PNG de inspecao da arte")
    parser.add_argument("--dump", action="store_true", help="imprime a arte do idle em texto")
    arguments = parser.parse_args()

    data = build_spritesheet()
    output = pathlib.Path(arguments.output)
    write_spritesheet(data, output)
    if arguments.preview:
        render_preview(data, pathlib.Path(arguments.preview))
    if arguments.dump:
        print(build_animations()["idle"][0].dump())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
