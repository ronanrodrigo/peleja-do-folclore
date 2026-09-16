#!/usr/bin/env python3
"""Gera assets/spritesheets/<slug>.json dos 7 Oponentes como DADO versionado.

Arte de lutador do Peleja do Folclore nao e PNG binario opaco (ADR 0005): e uma
paleta mais matrizes de pixel, versionadas em JSON. Este script estende o padrao
de `tools/art/build_saci_spritesheet.py` (a mesma `Grid`, os mesmos auxiliares de
retangulo/linha/contorno) para os sete Arquetipos satiricos do ADR 0004:

    capataz, banqueiro, redpill, camisa-verde, doutor-pureza,
    fantasma-do-reich, falso-pastor

Cada Oponente tem silhueta, paleta e trejeitos proprios -- o suficiente para ser
reconhecido num print de evidencia em 426x240, escala 2x/3x, filtro nearest.

Politica do ADR 0004, checada no gerador:
  * nenhum Oponente e pessoa real;
  * nenhuma braçadeira/roupa/emblema usa simbolo real de organizacao historica ou
    criminosa -- a braçadeira do Camisa-Verde e uma faixa LISA, sem marca;
  * nenhuma referencia a religiao: o Falso Pastor e um charlatao de terno com
    microfone, prato de coleta e uma auréola falsa -- o alvo e o golpe, nunca a fe.

Uso:

    python3 tools/art/build_opponent_spritesheets.py              # regrava os 7 JSON
    python3 tools/art/build_opponent_spritesheets.py --preview /tmp/x.png --slug capataz
    python3 tools/art/build_opponent_spritesheets.py --preview-all /tmp/opponents

O JSON e commitado; o script existe para reproduzir e ajustar a arte.
"""

from __future__ import annotations

import argparse
import json
import pathlib

TRANSPARENT = "."
ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"

OUTPUT_DIR = pathlib.Path("assets/spritesheets")

## Ordem fixa do arcade (ADR 0007): a mesma de `src/domain/arcade_order.gd`.
SLUGS = [
    "capataz",
    "banqueiro",
    "redpill",
    "camisa-verde",
    "doutor-pureza",
    "fantasma-do-reich",
    "falso-pastor",
]


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


def outline(grid: Grid, out: str) -> None:
    """Contorno por silhueta: so os pixels vazios que encostam no corpo."""
    body = [row[:] for row in grid.rows]
    for y in range(grid.height):
        for x in range(grid.width):
            if body[y][x] != TRANSPARENT:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < grid.width and 0 <= ny < grid.height:
                    if body[ny][nx] != TRANSPARENT and body[ny][nx] != out:
                        grid.pixel(x, y, out)
                        break


# --------------------------------------------------------------------------- #
# Corpo humano generico (24x34), do qual saem quase todas as animacoes.
# --------------------------------------------------------------------------- #


def draw_head(grid: Grid, c: dict, x: int, y: int, eyes: bool = True, mouth: str = "closed") -> None:
    """Cabeca 8x7 com o tom de pele do Oponente."""
    grid.rect(x, y, 8, 7, c["skin_l"])
    grid.column(x + 7, y, y + 6, c["skin"])
    grid.line(x, x + 7, y, c["skin"])
    if eyes:
        for eye_x in (x + 1, x + 4):
            grid.rect(eye_x, y + 2, 2, 2, c["white"])
            grid.line(eye_x, eye_x + 1, y + 3, c["eye"])
    if mouth == "open":
        grid.rect(x + 2, y + 5, 4, 2, c["out"])
    elif mouth == "grit":
        grid.rect(x + 3, y + 5, 2, 2, c["out"])
    elif mouth != "none":
        grid.line(x + 2, x + 5, y + 5, c["out"])
    grid.rect(x + 8, y + 1, 1, 3, c["out"])  # orelha


def draw_torso(
    grid: Grid, c: dict, x: int, y: int, arms: str = "down", sleeve: str = "main"
) -> None:
    """Tronco 8x8 com o paleto/camisa na cor principal e os bracos na pose pedida."""
    shirt = c[sleeve]
    grid.line(x + 2, x + 5, y - 1, c["skin"])  # pescoco
    grid.rect(x, y, 8, 8, shirt)
    grid.column(x + 7, y, y + 6, c["main_d"])
    grid.line(x, x + 7, y + 7, c["accent"])  # cinto
    if arms == "down":
        grid.rect(x - 2, y + 1, 2, 6, c["skin_l"])
        grid.rect(x + 8, y + 1, 2, 6, c["skin_l"])
    elif arms == "swing":
        grid.rect(x - 3, y + 2, 3, 5, c["skin_l"])
        grid.rect(x + 8, y - 1, 3, 5, c["skin_l"])
    elif arms == "guard":
        grid.rect(x - 3, y + 2, 4, 5, c["skin_l"])
        grid.rect(x + 7, y + 2, 4, 5, c["skin_l"])
        grid.rect(x, y + 1, 8, 3, c["skin"])  # antebracos cruzados
        grid.line(x, x + 7, y, c["out"])
    elif arms == "punch":
        grid.rect(x + 8, y + 1, 7, 3, c["skin_l"])
        grid.rect(x + 13, y + 1, 2, 3, c["skin"])
        grid.rect(x - 3, y + 2, 3, 5, c["skin_l"])
    elif arms == "front":
        grid.rect(x + 8, y + 2, 5, 3, c["skin_l"])
        grid.rect(x - 3, y + 2, 4, 4, c["skin_l"])
    elif arms == "back":
        grid.rect(x - 4, y + 1, 3, 5, c["skin_l"])
        grid.rect(x + 8, y + 1, 4, 5, c["skin_l"])
    elif arms == "up":
        grid.rect(x - 2, y - 5, 3, 7, c["skin_l"])
        grid.rect(x + 7, y - 6, 3, 8, c["skin_l"])
    elif arms == "raise":
        grid.rect(x + 8, y - 5, 3, 7, c["skin_l"])
        grid.rect(x - 2, y + 1, 3, 6, c["skin_l"])


def draw_legs(grid: Grid, c: dict, cx: int, y: int, phase: int = 0, pants: str = "main_d") -> None:
    """Duas pernas com botas: o passo desloca uma perna para cima."""
    left_offset = -1 if phase < 0 else 0
    right_offset = -1 if phase > 0 else 0
    grid.rect(cx - 4 + left_offset, y, 3, 6, c[pants])
    grid.rect(cx + 1 + right_offset, y, 3, 6, c[pants])
    grid.rect(cx - 5 + left_offset, y + 6, 4, 2, c["out"])
    grid.rect(cx + 1 + right_offset, y + 6, 4, 2, c["out"])


def draw_ghost_tail(grid: Grid, c: dict, cx: int, y: int, level: int = 1) -> None:
    """Cauda espectral: o Fantasma nao pisa no chao como os vivos."""
    for index in range(7):
        width = 10 - index
        color = c["main"] if index % 2 == 0 else c["main_d"]
        if index > 4 and level < 2:
            break
        grid.line(cx - width // 2, cx - width // 2 + width - 1, y + index, color)
    grid.rect(cx - 3, y + 7, 6, 1, c["accent"])


def draw_crouch(grid: Grid, c: dict, bob: int, tail: bool = False) -> None:
    """Agachado 26x20: corpo encolhido, hurtbox mais baixa e mais larga."""
    grid.rect(9, 13 + bob, 8, 5, c["skin_l"])
    grid.column(16, 13 + bob, 17 + bob, c["skin"])
    grid.line(9, 16, 15 + bob, c["accent"])
    grid.rect(6, 12 + bob, 3, 5, c["skin_l"])
    grid.rect(17, 12 + bob, 3, 5, c["skin_l"])
    grid.rect(8, 18, 10, 2, c["main"])
    grid.line(8, 17, 19, c["main_d"])
    if tail:
        draw_ghost_tail(grid, c, 13, 17, 1)


def build_style(slug: str, roles: list[tuple[str, str]]) -> dict:
    """Monta paleta e mapa de caracteres: `roles[i]` vira o indice `i + 1`."""
    palette = ["#00000000"]
    chars = {TRANSPARENT: TRANSPARENT}
    for index, (role, color) in enumerate(roles, start=1):
        palette.append(color)
        chars[role] = ALPHABET[index]
    return {"slug": slug, "palette": palette, "ch": chars}


# --------------------------------------------------------------------------- #
# Os 7 Oponentes: paleta, trejeitos e o quadro do Golpe Especial.
# --------------------------------------------------------------------------- #


class Opponent:
    """Um Arquetipo: corpo humano (ou espectral) mais a assinatura visual dele."""

    def __init__(self, slug: str, roles: list[tuple[str, str]], tail: bool = False) -> None:
        self.slug = slug
        self.roles = roles
        self.tail = tail

    # -- corpo ------------------------------------------------------------ #

    def standing(
        self,
        *,
        bob: int = 0,
        arms: str = "down",
        phase: int = 0,
        eyes: bool = True,
        mouth: str = "closed",
        shift: int = 0,
        lean: int = 0,
    ) -> Grid:
        style = build_style(self.slug, self.roles)
        c = style["ch"]
        grid = Grid(24, 34)
        cx = 11 + shift
        head_y = 10 + bob + lean
        self.decorate(grid, c, cx, head_y)
        draw_head(grid, c, cx - 3, head_y, eyes, mouth)
        draw_torso(grid, c, cx - 3, head_y + 8, arms)
        if self.tail:
            draw_ghost_tail(grid, c, cx, head_y + 16, 1)
        else:
            draw_legs(grid, c, cx, head_y + 16, phase)
        self.detail(grid, c, cx, head_y)
        outline(grid, c["out"])
        return grid

    def crouching(self, bob: int) -> Grid:
        style = build_style(self.slug, self.roles)
        c = style["ch"]
        grid = Grid(26, 20)
        head_y = 7 + bob
        self.decorate(grid, c, 13, head_y)
        draw_head(grid, c, 9, head_y, True, "closed")
        draw_crouch(grid, c, bob, self.tail)
        self.detail(grid, c, 13, head_y)
        outline(grid, c["out"])
        return grid

    # -- poses de animacao ------------------------------------------------- #

    def light(self, frame: int) -> Grid:
        grid = self.standing(arms="punch" if frame == 1 else "front")
        return grid

    def heavy(self, frame: int) -> Grid:
        """Golpe pesado 32x34: o Oponente da o golpe com a arma/trejeito proprio."""
        style = build_style(self.slug, self.roles)
        c = style["ch"]
        grid = Grid(32, 34)
        cx = 13
        head_y = 10
        self.decorate(grid, c, cx, head_y)
        draw_head(grid, c, cx - 3, head_y, True, "grit" if frame == 1 else "closed")
        draw_torso(grid, c, cx - 3, head_y + 8, "punch" if frame == 1 else "guard")
        if self.tail:
            draw_ghost_tail(grid, c, cx, head_y + 16, 1)
        else:
            draw_legs(grid, c, cx, head_y + 16, 1 if frame == 1 else 0)
        self.detail(grid, c, cx, head_y)
        self.weapon(grid, c, cx, head_y, frame)
        outline(grid, c["out"])
        return grid

    def grab(self, frame: int) -> Grid:
        return self.standing(arms="front", phase=1 if frame == 1 else 0)

    def block(self, bob: int) -> Grid:
        return self.standing(arms="guard", bob=bob)

    def hurt(self, frame: int) -> Grid:
        style = build_style(self.slug, self.roles)
        c = style["ch"]
        grid = Grid(24, 34)
        cx = 11 - (1 if frame == 0 else 2)
        head_y = 11 + (1 if frame == 0 else 2)
        self.decorate(grid, c, cx, head_y)
        draw_head(grid, c, cx - 3, head_y, True, "open")
        draw_torso(grid, c, cx - 3, head_y + 8, "back")
        if self.tail:
            draw_ghost_tail(grid, c, cx, head_y + 16, 2)
        else:
            draw_legs(grid, c, cx, head_y + 16, 0)
        self.detail(grid, c, cx, head_y)
        grid.rect(cx - 4, 31, 5, 2, c["out"])
        outline(grid, c["out"])
        return grid

    def ko(self, frame: int) -> Grid:
        """Nocaute 34x20: tombando e depois caido, com o apetrecho no chao."""
        style = build_style(self.slug, self.roles)
        c = style["ch"]
        grid = Grid(34, 20)
        if frame == 0:
            grid.rect(11, 3, 12, 4, c["main"])
            grid.rect(8, 6, 12, 4, c["main"])
            grid.rect(5, 9, 12, 4, c["main"])
            grid.rect(2, 12, 6, 6, c["skin_l"])
            grid.rect(3, 15, 2, 1, c["out"])
            grid.rect(14, 1, 5, 4, c["skin_l"])
            self.ko_prop(grid, c, 12, 2)
            self.detail(grid, c, 8, 8)
        else:
            grid.rect(6, 13, 16, 6, c["main"])
            grid.rect(2, 12, 7, 7, c["skin_l"])
            grid.rect(3, 14, 2, 2, c["out"])
            grid.rect(21, 14, 11, 4, c["main_d"])
            grid.rect(7, 18, 6, 2, c["accent"])
            self.ko_prop(grid, c, 12, 3)
            self.detail(grid, c, 6, 13)
        outline(grid, c["out"])
        return grid

    # -- ganchos do Arquetipo (sobrescritos) ------------------------------- #

    def decorate(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        """Chapeu/cabelo/oculos, desenhado ANTES do contorno (entra na silhueta)."""

    def detail(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        """Detalhe de roupa desenhado DEPOIS do corpo (gravata, cracha, faixa)."""

    def weapon(self, grid: Grid, c: dict, cx: int, head_y: int, frame: int) -> None:
        """A arma/trejeito que sai no golpe pesado."""

    def ko_prop(self, grid: Grid, c: dict, x: int, y: int) -> None:
        """O que cai no chao no nocaute."""

    def special_frame(self, frame: int) -> Grid:
        raise NotImplementedError


class Capataz(Opponent):
    """O Capataz: chapeu de aba larga, bigode, chicote e capangas ao fundo."""

    def decorate(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        brim = head_y - 2
        grid.line(cx - 7, cx + 6, brim, c["hat"])
        grid.line(cx - 7, cx + 6, brim + 1, c["extra"])
        grid.rect(cx - 3, head_y - 5, 7, 3, c["hat"])  # copa
        grid.line(cx - 3, cx + 3, head_y - 2, c["extra"])

    def detail(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        grid.line(cx - 2, cx + 3, head_y + 5, c["eye"])  # bigode
        grid.rect(cx - 3, head_y + 8, 8, 1, c["extra"])  # colarinho de couro

    def weapon(self, grid: Grid, c: dict, cx: int, head_y: int, frame: int) -> None:
        length = 13 if frame == 1 else 8
        grid.line(cx + 10, cx + 10 + length, head_y + 6, c["whip"])
        grid.line(cx + 10, cx + 10 + length, head_y + 7, c["whip_d"])
        grid.pixel(cx + 10 + length, head_y + 4, c["whip"])

    def ko_prop(self, grid: Grid, c: dict, x: int, y: int) -> None:
        grid.line(x, x + 9, y, c["whip"])
        grid.line(x - 6, x - 5, y + 3, c["hat"])

    def special_frame(self, frame: int) -> Grid:
        style = build_style(self.slug, self.roles)
        c = style["ch"]
        grid = Grid(40, 40)
        body = self.standing(arms="raise" if frame > 0 else "down")
        grid.paste(body, 8, 5)
        if frame == 0:
            grid.line(22, 30, 17, c["whip"])
            return grid
        # chicote estalando numa curva larga + os capangas
        for step in range(14):
            x = 24 + step
            y = 14 - (step * step) // 26
            grid.pixel(x, y, c["whip"])
            grid.pixel(x, y + 1, c["whip_d"])
        grid.line(37, 39, 15, c["whip"])
        size = 6 if frame == 1 else 8
        for base_x in (1, 31):
            cap_y = 40 - size - 2
            grid.rect(base_x + 1, cap_y, size, size, c["extra"])
            grid.rect(base_x + 2, cap_y - 2, 3, 3, c["skin"])  # cabeca do capanga
            grid.rect(base_x, cap_y + size, size + 2, 2, c["out"])
        return grid


class Banqueiro(Opponent):
    """O Banqueiro: cartola, gravata, colete e moedas -- os juros compostos."""

    def decorate(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        grid.rect(cx - 3, head_y - 7, 7, 5, c["hat"])  # copa alta
        grid.line(cx - 3, cx + 3, head_y - 7, c["hat_l"])
        grid.line(cx - 5, cx + 4, head_y - 2, c["hat_l"])  # aba

    def detail(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        grid.column(cx - 1, head_y + 8, head_y + 14, c["white"])  # camisa
        grid.rect(cx, head_y + 9, 1, 5, c["accent"])  # gravata
        grid.rect(cx - 3, head_y + 8, 8, 1, c["hat_l"])  # lapela

    def weapon(self, grid: Grid, c: dict, cx: int, head_y: int, frame: int) -> None:
        count = 4 if frame == 1 else 2
        for index in range(count):
            grid.rect(cx + 11 + index * 2, head_y + 7 - index, 2, 2, c["accent"])
            grid.pixel(cx + 11 + index * 2, head_y + 7 - index, c["white"])

    def ko_prop(self, grid: Grid, c: dict, x: int, y: int) -> None:
        grid.rect(x, y, 7, 3, c["hat"])
        grid.rect(x + 4, y + 3, 3, 2, c["accent"])

    def special_frame(self, frame: int) -> Grid:
        style = build_style(self.slug, self.roles)
        c = style["ch"]
        grid = Grid(40, 40)
        body = self.standing(arms="raise" if frame == 0 else "guard")
        grid.paste(body, 6, 5)
        # "juros compostos": a barra sobe e as moedas se empilham
        heights = [4, 9, 15] if frame == 2 else [3, 6, 10]
        for column, height in enumerate(heights):
            x = 31 + column * 3
            grid.rect(x, 34 - height, 2, height, c["main_d"])
            grid.line(x, x + 1, 34 - height, c["accent"])
        coins = 6 if frame == 2 else 3
        for index in range(coins):
            x = 28 + (index % 3) * 4
            y = 12 - index * 2
            grid.rect(x, y, 3, 3, c["accent"])
            grid.pixel(x + 1, y + 1, c["white"])
        if frame == 2:
            grid.line(28, 38, 6, c["hat_l"])
        return grid


class Redpill(Opponent):
    """O Redpill: bone, oculos escuros, capuz e o spray de pilula vermelha."""

    def decorate(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        grid.rect(cx - 4, head_y - 3, 9, 3, c["hat"])  # bone (aba para tras)
        grid.rect(cx - 4, head_y - 1, 3, 2, c["hat_l"])
        grid.rect(cx - 5, head_y - 4, 5, 2, c["hat_l"])

    def detail(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        grid.rect(cx - 3, head_y + 1, 8, 3, c["eye"])  # oculos escuros
        grid.rect(cx - 3, head_y + 7, 8, 3, c["extra"])  # capuz aberto

    def weapon(self, grid: Grid, c: dict, cx: int, head_y: int, frame: int) -> None:
        grid.rect(cx + 10, head_y + 6, 4, 3, c["metal"])
        pills = 3 if frame == 1 else 1
        for index in range(pills):
            grid.pixel(cx + 14 + index * 2, head_y + 5 - index, c["pill"])

    def ko_prop(self, grid: Grid, c: dict, x: int, y: int) -> None:
        grid.rect(x, y, 6, 2, c["hat"])
        grid.pixel(x + 8, y + 2, c["pill"])

    def special_frame(self, frame: int) -> Grid:
        style = build_style(self.slug, self.roles)
        c = style["ch"]
        grid = Grid(40, 40)
        body = self.standing(arms="raise" if frame > 0 else "down")
        grid.paste(body, 5, 5)
        spread = 4 + frame * 3
        for index in range(9 + frame * 4):
            x = 26 + (index * 3) % spread
            y = 12 + ((index * 5) % (8 + frame * 5))
            grid.pixel(x, y, c["pill"])
            if index % 3 == 0:
                grid.pixel(x + 1, y, c["pill_d"])
        for index in range(3 + frame):
            grid.line(25, 25 + 4 + frame * 2, 9 + index * 3, c["extra"])
        if frame == 2:
            grid.line(24, 38, 34, c["hat_l"])
        return grid


class CamisaVerde(Opponent):
    """O Camisa-Verde: camisa verde e uma bracadeira LISA (sem simbolo real)."""

    def decorate(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        grid.rect(cx - 3, head_y - 2, 7, 2, c["hat"])  # cabelo curto

    def detail(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        # Bracadeira: faixa solida e lisa. Nenhum emblema, nenhum simbolo real.
        grid.rect(cx - 3, head_y + 9, 8, 2, c["band"])
        grid.rect(cx + 7, head_y + 9, 3, 2, c["band"])

    def weapon(self, grid: Grid, c: dict, cx: int, head_y: int, frame: int) -> None:
        # Gaita de marcha: gaita na mao, com a onda do som.
        grid.rect(cx + 11, head_y + 6, 6, 3, c["metal"])
        grid.line(cx + 17, cx + 17 + (6 if frame == 1 else 3), head_y + 7, c["out"])
        for index in range(2 + frame):
            grid.pixel(cx + 19 + index * 2, head_y + 4 - index, c["white"])

    def ko_prop(self, grid: Grid, c: dict, x: int, y: int) -> None:
        grid.rect(x, y, 5, 2, c["metal"])
        grid.rect(x + 7, y + 1, 3, 1, c["band"])

    def special_frame(self, frame: int) -> Grid:
        style = build_style(self.slug, self.roles)
        c = style["ch"]
        grid = Grid(40, 40)
        body = self.standing(arms="raise" if frame == 0 else "guard")
        grid.paste(body, 6, 5)
        grid.rect(22, 16, 8, 4, c["metal"])  # gaita na boca
        for band in range(1 + frame * 2):
            width = 4 + band * 3
            grid.line(30 + band, 30 + band + width, 14 + band, c["white"])
            grid.line(30 + band, 30 + band + width, 16 + band, c["band"])
        # botas marchando, com a poeira do desfile
        for step in range(2 + frame):
            x = 2 + step * 3
            grid.rect(x, 34 - step % 2, 4, 3, c["out"])
        grid.line(0, 39, 38, c["band"])
        return grid


class DoutorPureza(Opponent):
    """O Doutor Pureza: jaleco, oculos e a teoria que DRENA e enfraquece.

    A critica e ao comportamento (a doutrina que suga o outro), nunca a um povo
    nem a uma identidade: o alvo do dreno e uma silhueta neutra e cinza.
    """

    def decorate(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        grid.rect(cx - 3, head_y - 2, 7, 2, c["eye"])  # cabelo penteado

    def detail(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        grid.rect(cx + 1, head_y + 2, 2, 2, c["metal"])  # oculos redondo
        grid.rect(cx + 5, head_y + 2, 2, 2, c["metal"])
        grid.column(cx - 1, head_y + 8, head_y + 15, c["main"])  # jaleco aberto

    def weapon(self, grid: Grid, c: dict, cx: int, head_y: int, frame: int) -> None:
        grid.line(cx + 11, cx + 11 + (9 if frame == 1 else 5), head_y + 6, c["metal"])

    def ko_prop(self, grid: Grid, c: dict, x: int, y: int) -> None:
        grid.line(x, x + 6, y, c["metal"])
        grid.rect(x + 8, y + 1, 3, 2, c["white"])

    def special_frame(self, frame: int) -> Grid:
        style = build_style(self.slug, self.roles)
        c = style["ch"]
        grid = Grid(40, 40)
        body = self.standing(arms="raise" if frame == 0 else "guard")
        grid.paste(body, 2, 5)
        # a silhueta cinza perde tamanho e cor enquanto a teoria drena
        size = 10 - frame * 2
        base_y = 40 - size
        grid.rect(28, base_y, size, size, c["extra"])
        grid.rect(29, base_y + 2, size - 2, 2, c["white"])
        for index in range(3 + frame * 3):
            x = 26 - index
            y = base_y + 2 + (index * 3) % (size + 4)
            if x > 16:
                grid.pixel(x, y, c["accent"])
        if frame == 2:
            grid.line(24, 39, 36, c["metal"])
        return grid


class FantasmaDoReich(Opponent):
    """O Fantasma do Reich: espectro cinza sem pernas, uniforme esfarrapado.

    Nenhuma insignia, nenhum simbolo: a silhueta e lisa, e o que assombra e a
    ideia derrotada -- nunca um emblema real.
    """

    def __init__(self) -> None:
        super().__init__(
            "fantasma-do-reich",
            [
                ("out", "#141820ff"),
                ("skin", "#9fb0a8ff"),
                ("skin_l", "#c6d2caff"),
                ("main", "#5c6a68ff"),
                ("main_d", "#3c4846ff"),
                ("accent", "#8fe0d0ff"),
                ("white", "#e8f2ecff"),
                ("metal", "#7f8c86ff"),
                ("eye", "#1a2228ff"),
                ("extra", "#6f7d78ff"),
            ],
            tail=True,
        )

    def decorate(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        grid.rect(cx - 4, head_y - 3, 9, 3, c["main_d"])  # capuz espectral
        grid.line(cx - 5, cx + 4, head_y - 1, c["metal"])

    def detail(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        grid.rect(cx - 3, head_y + 2, 3, 2, c["eye"])  # olhos vazios
        grid.rect(cx + 1, head_y + 2, 3, 2, c["eye"])
        grid.line(cx - 3, cx + 4, head_y + 10, c["main_d"])  # uniforme rasgado

    def weapon(self, grid: Grid, c: dict, cx: int, head_y: int, frame: int) -> None:
        grid.line(cx + 10, cx + 10 + (8 if frame == 1 else 4), head_y + 5, c["accent"])

    def ko_prop(self, grid: Grid, c: dict, x: int, y: int) -> None:
        grid.rect(x, y, 9, 3, c["main_d"])
        grid.line(x + 2, x + 8, y - 1, c["accent"])

    def special_frame(self, frame: int) -> Grid:
        style = build_style(self.slug, self.roles)
        c = style["ch"]
        grid = Grid(40, 40)
        body = self.standing(arms="raise" if frame > 0 else "down", eyes=True)
        grid.paste(body, 8, 3)
        radius = 7 + frame * 4
        for index in range(10 + frame * 6):
            x = 20 + (index * 7) % (radius * 2) - radius
            y = 18 + (index * 5) % (radius * 2 + 4) - radius
            if 0 <= x < 40 and 0 <= y < 40:
                grid.pixel(x, y, c["accent"] if index % 2 == 0 else c["white"])
        for index in range(3 + frame):
            grid.line(20 - radius, 20 + radius, 34 + index, c["main_d"])
        return grid


class FalsoPastor(Opponent):
    """O Falso Pastor: charlatao de terno com microfone, prato e aureola falsa.

    O alvo e o golpe do charlatao -- dizimo que rouba a Barra de Especial e o
    "milagre" comprado. Nenhuma cruz, nenhum templo, nenhuma referencia a fe.
    """

    def decorate(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        grid.rect(cx - 3, head_y - 2, 7, 2, c["eye"])  # cabelo engomado

    def detail(self, grid: Grid, c: dict, cx: int, head_y: int) -> None:
        grid.column(cx, head_y + 8, head_y + 15, c["white"])  # camisa
        grid.rect(cx + 1, head_y + 9, 2, 5, c["accent"])  # gravata larga
        grid.rect(cx - 3, head_y + 8, 8, 1, c["main_d"])

    def weapon(self, grid: Grid, c: dict, cx: int, head_y: int, frame: int) -> None:
        grid.rect(cx + 10, head_y + 6, 3, 4, c["metal"])  # microfone
        grid.column(cx + 11, head_y + 10, head_y + 12, c["metal"])

    def ko_prop(self, grid: Grid, c: dict, x: int, y: int) -> None:
        grid.rect(x, y, 4, 3, c["metal"])
        grid.rect(x + 6, y + 1, 6, 2, c["accent"])

    def special_frame(self, frame: int) -> Grid:
        style = build_style(self.slug, self.roles)
        c = style["ch"]
        grid = Grid(40, 40)
        body = self.standing(arms="raise", eyes=True)
        grid.paste(body, 6, 5)
        # o "milagre" comprado: aureola desenhada e dinheiro subindo
        radius = 6 + frame * 3
        for index in range(8 + frame * 6):
            angle_x = 10 + (index * 5) % (radius * 2)
            grid.pixel(angle_x, 4 + index % 2, c["accent"])
        grid.rect(20, 2, radius, 2, c["white"])
        grid.rect(22, 18, 10, 4, c["white"])  # prato de coleta
        grid.rect(24, 19, 6, 2, c["accent"])
        for index in range(2 + frame * 2):
            x = 24 + (index % 3) * 3
            y = 14 - index * 3
            grid.rect(x, y, 4, 3, c["extra"])
            grid.line(x, x + 3, y + 1, c["white"])
        return grid


def opponent_for(slug: str) -> Opponent:
    if slug == "capataz":
        return Capataz(
            "capataz",
            [
                ("out", "#141018ff"),
                ("skin", "#9a5f33ff"),
                ("skin_l", "#c98a4bff"),
                ("main", "#6d4a2cff"),
                ("main_d", "#47301cff"),
                ("accent", "#ffd35cff"),
                ("white", "#f2ead8ff"),
                ("metal", "#8f8f7cff"),
                ("eye", "#2a1c12ff"),
                ("hat", "#c2a45aff"),
                ("hat_l", "#8a7338ff"),
                ("extra", "#5d4630ff"),
                ("whip", "#d8b48aff"),
                ("whip_d", "#7a4a24ff"),
            ],
        )
    if slug == "banqueiro":
        return Banqueiro(
            "banqueiro",
            [
                ("out", "#0f1420ff"),
                ("skin", "#c9a07aff"),
                ("skin_l", "#e8c39cff"),
                ("main", "#1f4d3aff"),
                ("main_d", "#143026ff"),
                ("accent", "#ffd35cff"),
                ("white", "#f3f6f0ff"),
                ("metal", "#b9c2c6ff"),
                ("eye", "#241a12ff"),
                ("hat", "#1a222cff"),
                ("hat_l", "#3a4652ff"),
                ("extra", "#8a949aff"),
            ],
        )
    if slug == "redpill":
        return Redpill(
            "redpill",
            [
                ("out", "#121220ff"),
                ("skin", "#d9a878ff"),
                ("skin_l", "#f0c79aff"),
                ("main", "#2b3350ff"),
                ("main_d", "#1b2138ff"),
                ("accent", "#ffd35cff"),
                ("white", "#f2f2f2ff"),
                ("metal", "#9aa4b0ff"),
                ("eye", "#101018ff"),
                ("hat", "#d02b26ff"),
                ("hat_l", "#8f1f1cff"),
                ("extra", "#3f4a6bff"),
                ("pill", "#e8443cff"),
                ("pill_d", "#9c1f1aff"),
            ],
        )
    if slug == "camisa-verde":
        return CamisaVerde(
            "camisa-verde",
            [
                ("out", "#101a14ff"),
                ("skin", "#d2a172ff"),
                ("skin_l", "#eec394ff"),
                ("main", "#2e7d47ff"),
                ("main_d", "#1c5230ff"),
                ("accent", "#f2c14eff"),
                ("white", "#f2f2f2ff"),
                ("metal", "#b8c0c4ff"),
                ("eye", "#241a12ff"),
                ("hat", "#4a3524ff"),
                ("hat_l", "#6f5238ff"),
                ("band", "#7ec850ff"),
                ("extra", "#3b4a3fff"),
            ],
        )
    if slug == "doutor-pureza":
        return DoutorPureza(
            "doutor-pureza",
            [
                ("out", "#101822ff"),
                ("skin", "#d8b090ff"),
                ("skin_l", "#f0d0b0ff"),
                ("main", "#e8eef2ff"),
                ("main_d", "#b8c6d0ff"),
                ("accent", "#6fb7d8ff"),
                ("white", "#ffffffff"),
                ("metal", "#8fa0acff"),
                ("eye", "#22303aff"),
                ("extra", "#6a747cff"),
            ],
        )
    if slug == "fantasma-do-reich":
        return FantasmaDoReich()
    if slug == "falso-pastor":
        return FalsoPastor(
            "falso-pastor",
            [
                ("out", "#150f20ff"),
                ("skin", "#c08a5aff"),
                ("skin_l", "#e0ac79ff"),
                ("main", "#f0e6d0ff"),
                ("main_d", "#c9bda0ff"),
                ("accent", "#c9a227ff"),
                ("white", "#ffffffff"),
                ("metal", "#b0b6bcff"),
                ("eye", "#2a1c12ff"),
                ("extra", "#7a8f5aff"),
            ],
        )
    raise KeyError(f"Oponente desconhecido: {slug}")


# --------------------------------------------------------------------------- #
# Animacoes e codificacao
# --------------------------------------------------------------------------- #


def build_animations(opponent: Opponent) -> dict[str, list[Grid]]:
    stand = opponent.standing
    return {
        "idle": [stand(arms="down"), stand(arms="down", bob=1)],
        "walk": [
            stand(arms="swing", phase=1),
            stand(arms="swing", bob=1),
            stand(arms="swing", phase=-1),
            stand(arms="swing", bob=1),
        ],
        "crouch": [opponent.crouching(0), opponent.crouching(1)],
        "block": [opponent.block(0), opponent.block(1)],
        "light": [opponent.light(0), opponent.light(1)],
        "heavy": [opponent.heavy(0), opponent.heavy(1)],
        "grab": [opponent.grab(0), opponent.grab(1)],
        "special": [opponent.special_frame(0), opponent.special_frame(1), opponent.special_frame(2)],
        "hurt": [opponent.hurt(0), opponent.hurt(1)],
        "ko": [opponent.ko(0), opponent.ko(1)],
    }


def encode_rows(grid: Grid, chars: dict) -> list[str]:
    """Linha compacta: o caractere role mapeia direto o indice da paleta."""
    decoded = []
    for row in grid.to_text():
        decoded.append("".join(row))
    return decoded


def build_spritesheet(slug: str) -> dict:
    opponent = opponent_for(slug)
    style = build_style(slug, opponent.roles)
    chars = style["ch"]
    animations = {}
    for name, frames in build_animations(opponent).items():
        for frame in frames:
            for row in frame.to_text():
                assert len(row) == frame.width, f"{slug}/{name}: linha com largura errada"
                for char in row:
                    assert char == TRANSPARENT or char in chars.values(), (
                        f"{slug}/{name}: char {char!r}"
                    )
        animations[name] = [
            {"width": frame.width, "height": frame.height, "pixels": encode_rows(frame, chars)}
            for frame in frames
        ]
    return {"slug": slug, "version": 1, "palette": style["palette"], "animations": animations}


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
    from PIL import Image

    animations = data["animations"]
    columns = max(len(frames) for frames in animations.values())
    cell_width = max(frame["width"] for frames in animations.values() for frame in frames)
    cell_height = max(frame["height"] for frames in animations.values() for frame in frames)
    padding = 3
    sheet = Image.new(
        "RGBA",
        (
            (cell_width + padding) * columns + padding,
            (cell_height + padding) * len(animations) + padding,
        ),
        (18, 18, 42, 255),
    )
    for row_index, frames in enumerate(animations.values()):
        y = padding + row_index * (cell_height + padding)
        for column, frame in enumerate(frames):
            image = decode_frame(data, frame)
            x = padding + column * (cell_width + padding)
            sheet.paste(image, (x, y), image)
    sheet = sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
    print(f"preview: {path} ({sheet.width}x{sheet.height})")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--slug", action="append", help="slug a gerar (padrao: os sete)")
    parser.add_argument("--output-dir", default=str(OUTPUT_DIR), help="diretorio de saida")
    parser.add_argument("--preview", help="grava um PNG de inspecao do slug pedido")
    parser.add_argument("--preview-all", help="grava um PNG de inspecao por slug neste diretorio")
    parser.add_argument("--dump", action="store_true", help="imprime a arte do idle em texto")
    arguments = parser.parse_args()

    slugs = arguments.slug or SLUGS
    output_dir = pathlib.Path(arguments.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    for slug in slugs:
        data = build_spritesheet(slug)
        output = output_dir / f"{slug}.json"
        output.write_text(
            json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        frames = sum(len(items) for items in data["animations"].values())
        print(
            f"spritesheet: {output} -- {len(data['animations'])} animacoes, "
            f"{frames} frames, paleta de {len(data['palette'])} cores"
        )
        if arguments.preview:
            render_preview(data, pathlib.Path(arguments.preview))
        if arguments.preview_all:
            render_preview(data, pathlib.Path(arguments.preview_all) / f"{slug}.png")
        if arguments.dump:
            print(build_animations(opponent_for(slug))["idle"][0].dump())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
