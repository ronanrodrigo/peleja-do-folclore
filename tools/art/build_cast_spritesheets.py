#!/usr/bin/env python3
"""Gera as spritesheets codificadas do elenco folclorico: Curupira, Iara e Cuca.

Mesmo padrao do Saci (tools/art/build_saci_spritesheet.py): a arte de lutador e
DADO versionado em JSON (paleta + matrizes de pixel, ADR 0005), desenhada com
primitivas e validada por `src/domain/spritesheet.gd`. A maquinaria comum
(matriz, contorno por silhueta, codificacao compacta e previa) vive em
`tools/art/pixel_grid.py`.

    python3 tools/art/build_cast_spritesheets.py                    # grava os tres JSON
    python3 tools/art/build_cast_spritesheets.py --preview P.png    # previa da arte

Os tres lutadores cobrem as dez animacoes obrigatorias do formato, no mesmo
esquema de quadros do Saci (corpo 24x34, agachado 26x20, pesado 32x34,
especial 40x40, nocaute 34x20), e cada um traz o desenho do proprio Golpe
Especial: os Pes Invertidos do Curupira, o Canto do Rio da Iara e o Nana Nenem
da Cuca (que vira jacare).
"""

from __future__ import annotations

import argparse
import pathlib

from pixel_grid import (
    TRANSPARENT,
    Grid,
    bind_palette,
    outline,
    render_preview,
    write_spritesheet,
)

# ---------------------------------------------------------------------------
# Curupira: cabelo de fogo, pele de mata e os PES INVERTIDOS da lenda (o calcanhar
# fica na frente, o pe aponta para tras). Golpe Especial: Pes Invertidos.
# ---------------------------------------------------------------------------
CURUPIRA_PALETTE = [
    "#00000000",  # 0  .  transparente
    "#14100fff",  # 1  k  contorno
    "#8a5a30ff",  # 2  d  pele em sombra
    "#cf8f4eff",  # 3  s  pele (base)
    "#d8331fff",  # 4  R  fogo vermelho
    "#ff8a1eff",  # 5  O  fogo laranja
    "#ffcf42ff",  # 6  y  fogo amarelo
    "#4f8f3aff",  # 7  g  folha verde
    "#2f6423ff",  # 8  G  folha escura
    "#f5efe0ff",  # 9  w  branco (olho e dente)
    "#1b1420ff",  # 10 e  pupila
]

CURUPIRA_CHARS = {
    TRANSPARENT: 0,
    "k": 1,
    "d": 2,
    "s": 3,
    "R": 4,
    "O": 5,
    "y": 6,
    "g": 7,
    "G": 8,
    "w": 9,
    "e": 10,
}

# ---------------------------------------------------------------------------
# Iara: cabelo longo de rio, concha e escamas. Golpe Especial: Canto do Rio
# (encanta, paralisa e drena vida no abraco d'agua).
# ---------------------------------------------------------------------------
IARA_PALETTE = [
    "#00000000",  # 0  .  transparente
    "#101820ff",  # 1  k  contorno
    "#1d2a44ff",  # 2  H  cabelo escuro
    "#33507aff",  # 3  h  cabelo com luz
    "#e8b98aff",  # 4  s  pele (base)
    "#b98a5eff",  # 5  d  pele em sombra
    "#35a08aff",  # 6  t  escama
    "#1f6b5cff",  # 7  T  escama escura
    "#8fe0d0ff",  # 8  a  agua clara
    "#2f8f86ff",  # 9  b  agua escura
    "#f5efe0ff",  # 10 w  branco
    "#101828ff",  # 11 e  pupila
    "#e08aa0ff",  # 12 p  concha
]

IARA_CHARS = {
    TRANSPARENT: 0,
    "k": 1,
    "H": 2,
    "h": 3,
    "s": 4,
    "d": 5,
    "t": 6,
    "T": 7,
    "a": 8,
    "b": 9,
    "w": 10,
    "e": 11,
    "p": 12,
}

# ---------------------------------------------------------------------------
# Cuca: bruxa jacare -- focinho de crocodilo, dentes e cabelo de fogo. Golpe
# Especial: Nana Nenem (adormece o Oponente e a Cuca vira jacare e morde).
# ---------------------------------------------------------------------------
CUCA_PALETTE = [
    "#00000000",  # 0  .  transparente
    "#101a10ff",  # 1  k  contorno
    "#5f9a3cff",  # 2  s  pele verde (base)
    "#3c6b26ff",  # 3  d  pele em sombra
    "#a8cc55ff",  # 4  y  escama com luz
    "#c02a1eff",  # 5  R  cabelo vermelho
    "#e8761fff",  # 6  O  cabelo laranja
    "#f5efe0ff",  # 7  w  dente
    "#ffd35cff",  # 8  g  olho amarelo
    "#2a1414ff",  # 9  b  fauce escura
    "#d06278ff",  # 10 t  lingua
]

CUCA_CHARS = {
    TRANSPARENT: 0,
    "k": 1,
    "s": 2,
    "d": 3,
    "y": 4,
    "R": 5,
    "O": 6,
    "w": 7,
    "g": 8,
    "b": 9,
    "t": 10,
}


class FighterArt:
    """Corpo comum do elenco: cabeca, tronco, bracos e pernas parametricos.

    Cada Guardiao subclasse e acrescenta o que e so dele (cabelo de fogo, focinho
    de jacare, cabelo de rio e pe virado). As proporcoes sao as mesmas do Saci,
    para o elenco ler como um jogo so.
    """

    name = ""
    slug = ""
    palette: list[str] = []
    chars: dict[str, int] = {}
    # O Saci tem uma perna so (a lenda); o resto do elenco tem duas.
    two_legs = True
    # Caracteres da paleta usados pelo corpo.
    skin = "s"
    skin_dark = "d"
    cloth = "g"
    cloth_dark = "G"
    white = "w"
    eye = "e"
    outline_char = "k"

    # --- adornos que cada Guardiao desenha por conta propria ---
    def hair(self, grid: Grid, center_x: int, head_top: int) -> None:
        pass

    def hair_flow(self, grid: Grid, center_x: int, head_top: int) -> None:
        """Mechas que caem ao lado do corpo, desenhadas depois do tronco."""
        pass

    def chest(self, grid: Grid, x: int, y: int) -> None:
        pass

    def hips(self, grid: Grid, x: int, y: int) -> None:
        pass

    def foot(self, grid: Grid, center_x: int, y: int, offset: int) -> None:
        """Pe padrao: bico de pe para a frente (para a direita)."""
        grid.rect(center_x - 2 + offset, y, 4, 1, self.skin)
        grid.rect(center_x + 2 + offset, y, 2, 1, self.skin_dark)

    # --- primitivas ---
    def head(self, grid: Grid, x: int, y: int, eyes: bool = True, mouth: str = "fechada") -> None:
        grid.rect(x, y, 8, 7, self.skin)
        grid.column(x + 7, y, y + 6, self.skin_dark)
        if eyes:
            for eye_x in (x + 1, x + 4):
                grid.rect(eye_x, y + 2, 2, 2, self.white)
                grid.line(eye_x, eye_x + 1, y + 3, self.eye)
        if mouth == "aberta":
            grid.rect(x + 2, y + 5, 4, 2, self.outline_char)
            grid.line(x + 3, x + 4, y + 5, self.white)
        elif mouth != "sem":
            grid.line(x + 2, x + 5, y + 5, self.outline_char)

    def torso(self, grid: Grid, x: int, y: int, arms: str = "baixo") -> None:
        grid.line(x + 2, x + 5, y - 1, self.skin)  # pescoco
        grid.rect(x, y, 8, 8, self.skin)
        grid.column(x + 7, y, y + 6, self.skin_dark)
        if arms == "baixo":
            grid.rect(x - 2, y + 1, 2, 6, self.skin)
            grid.rect(x + 8, y + 1, 2, 6, self.skin)
        elif arms == "frente":
            grid.rect(x + 8, y + 1, 7, 3, self.skin)
            grid.rect(x + 13, y + 1, 2, 3, self.skin_dark)
            grid.rect(x - 3, y + 2, 3, 5, self.skin)
        elif arms == "golpe":
            grid.rect(x + 8, y, 7, 4, self.skin)
            grid.rect(x + 13, y, 3, 4, self.skin_dark)
            grid.rect(x - 3, y + 2, 3, 5, self.skin)
        elif arms == "guarda":
            grid.rect(x - 4, y + 3, 4, 5, self.skin)
            grid.rect(x + 8, y + 3, 4, 5, self.skin)
            grid.rect(x - 1, y - 1, 10, 4, self.skin_dark)
            grid.line(x - 1, x + 8, y - 2, self.outline_char)
        elif arms == "cruzados":
            grid.rect(x - 1, y + 1, 10, 3, self.skin)
            grid.line(x - 1, x + 8, y + 3, self.outline_char)
            grid.rect(x - 1, y + 4, 10, 3, self.skin_dark)
            grid.line(x - 1, x + 8, y + 4, self.outline_char)
        elif arms == "swing":
            grid.rect(x - 3, y + 1, 3, 5, self.skin)
            grid.rect(x + 8, y - 1, 3, 5, self.skin)
        elif arms == "para_cima":
            grid.rect(x - 2, y - 5, 3, 7, self.skin)
            grid.rect(x + 7, y - 5, 3, 7, self.skin)
        elif arms == "tras":
            grid.rect(x - 4, y + 1, 3, 5, self.skin)
            grid.rect(x + 9, y + 1, 3, 5, self.skin)
        self.chest(grid, x, y)

    def shorts(self, grid: Grid, x: int, y: int) -> None:
        grid.rect(x - 1, y, 10, 3, self.cloth)
        grid.line(x - 1, x + 8, y + 1, self.cloth_dark)

    def leg(self, grid: Grid, center_x: int, y: int, offset: int = 0, length: int = 4) -> None:
        grid.rect(center_x - 2 + offset, y, 4, length, self.skin)
        grid.column(center_x + 1 + offset, y, y + length - 1, self.skin_dark)
        self.foot(grid, center_x, y + length - 1, offset)

    # --- poses ---
    def standing(
        self,
        bob: int = 0,
        arms: str = "baixo",
        leg_offset: int = 0,
        mirror_offset: int = 0,
        eyes: bool = True,
        mouth: str = "fechada",
        body_shift: int = 0,
        hair_shift: int = 0,
        lean: int = 0,
    ) -> Grid:
        grid = Grid(24, 34)
        center = 11 + body_shift
        self.hair(grid, center + 1 + lean, 2 + hair_shift)
        self.head(grid, center - 3 + lean, 10 + hair_shift + bob, eyes, mouth)
        self.torso(grid, center - 3 + lean // 2, 18 + bob, arms)
        self.hips(grid, center - 3, 26 + bob)
        length = max(4 - bob, 2)
        if self.two_legs:
            spread = 3
            self.leg(grid, center - spread, 29, leg_offset, length)
            self.leg(grid, center + spread, 29, mirror_offset, length)
        else:
            self.leg(grid, center, 29, leg_offset, length)
        self.hair_flow(grid, center + 1 + lean, 2 + hair_shift)
        outline(grid)
        return grid

    def crouching(self, bob: int = 0) -> Grid:
        grid = Grid(26, 20)
        self.hair(grid, 13, 0)
        self.head(grid, 9, 7 + bob)
        grid.rect(9, 13 + bob, 8, 5, self.skin)
        grid.column(16, 13 + bob, 17 + bob, self.skin_dark)
        self.chest(grid, 9, 13 + bob)
        grid.rect(6, 12 + bob, 3, 5, self.skin)
        grid.rect(17, 12 + bob, 3, 5, self.skin)
        self.hips(grid, 9, 17)
        self.foot(grid, 11, 19, 0)
        self.foot(grid, 16, 19, 0)
        outline(grid)
        return grid

    def punch(self, frame: int) -> Grid:
        grid = self.standing(arms="golpe" if frame == 1 else "guarda")
        if frame == 0:
            grid.rect(16, 19, 5, 4, self.skin)
        return grid

    def kick(self, frame: int) -> Grid:
        grid = Grid(32, 34)
        center = 13
        self.hair(grid, center + 2, 2)
        self.head(grid, center - 2, 10)
        self.torso(grid, center - 1, 18, "guarda")
        self.hips(grid, center - 1, 26)
        length = 13 if frame == 1 else 8
        grid.rect(center + 3, 22, length, 4, self.skin)
        grid.rect(center + 3 + length - 3, 22, 3, 4, self.skin_dark)
        grid.rect(center - 4, 22, 5, 5, self.skin)
        outline(grid)
        return grid

    def grabbing(self, frame: int) -> Grid:
        return self.standing(arms="frente", leg_offset=1 if frame == 1 else 0)

    def blocking(self, bob: int) -> Grid:
        return self.standing(arms="cruzados", bob=bob)

    def hurting(self, frame: int) -> Grid:
        return self.standing(
            arms="tras",
            mouth="aberta",
            body_shift=-1 if frame == 0 else -2,
            hair_shift=1,
            lean=-3 if frame == 0 else -5,
        )

    def knocked_out(self, frame: int) -> Grid:
        grid = Grid(34, 20)
        if frame == 0:
            grid.rect(11, 3, 12, 4, self.skin)
            grid.rect(8, 6, 12, 4, self.skin)
            grid.rect(5, 9, 12, 4, self.skin)
            grid.rect(2, 12, 6, 6, self.skin)
            grid.rect(3, 15, 2, 1, self.outline_char)
            grid.rect(14, 1, 5, 4, self.skin)
            outline(grid)
            return grid
        grid.rect(6, 13, 16, 6, self.skin)
        grid.rect(2, 12, 7, 7, self.skin)
        grid.rect(3, 14, 2, 2, self.outline_char)
        grid.rect(21, 14, 11, 4, self.skin)
        grid.rect(7, 18, 6, 2, self.cloth)
        outline(grid)
        return grid

    def special(self, frame: int) -> Grid:
        raise NotImplementedError

    def animations(self) -> dict[str, list[Grid]]:
        return {
            "idle": [self.standing(), self.standing(bob=1)],
            "walk": [
                self.standing(arms="swing", leg_offset=2),
                self.standing(arms="baixo", bob=1),
                self.standing(arms="swing", leg_offset=-2),
                self.standing(arms="baixo", bob=1),
            ],
            "crouch": [self.crouching(0), self.crouching(1)],
            "block": [self.blocking(0), self.blocking(1)],
            "light": [self.punch(0), self.punch(1)],
            "heavy": [self.kick(0), self.kick(1)],
            "grab": [self.grabbing(0), self.grabbing(1)],
            "special": [self.special(0), self.special(1), self.special(2)],
            "hurt": [self.hurting(0), self.hurting(1)],
            "ko": [self.knocked_out(0), self.knocked_out(1)],
        }


class Curupira(FighterArt):
    """Guardiao da mata: cabelo de fogo e os pes virados para tras."""

    name = "Curupira"
    chars = CURUPIRA_CHARS
    slug = "curupira"
    palette = CURUPIRA_PALETTE
    skin = "s"
    skin_dark = "d"
    cloth = "g"
    cloth_dark = "G"
    white = "w"
    eye = "e"

    def hair(self, grid: Grid, center_x: int, head_top: int) -> None:
        """Chamas: labaredas pontudas alternando vermelho, laranja e amarelo."""
        flames = [
            (0, "R", 3),
            (1, "O", 5),
            (2, "R", 7),
            (3, "R", 3),
        ]
        for offset, color, width in flames:
            grid.rect(center_x - width // 2, head_top + offset * 2, width, 2, color)
        grid.rect(center_x - 3, head_top + 7, 7, 2, "R")
        grid.rect(center_x - 2, head_top + 6, 2, 2, "y")
        grid.rect(center_x + 2, head_top + 4, 1, 3, "O")
        grid.rect(center_x - 1, head_top + 2, 2, 1, "y")

    def chest(self, grid: Grid, x: int, y: int) -> None:
        grid.line(x, x + 7, y + 6, "G")  # cipo/cinto de folhas

    def hips(self, grid: Grid, x: int, y: int) -> None:
        grid.rect(x - 1, y, 10, 3, "g")
        grid.rect(x - 1, y + 2, 3, 1, "G")
        grid.rect(x + 5, y + 2, 3, 1, "G")

    def foot(self, grid: Grid, center_x: int, y: int, offset: int) -> None:
        """Pe virado: o calcanhar fica na frente e os dedos apontam para TRAS."""
        grid.rect(center_x - 2 + offset, y, 4, 1, self.skin_dark)
        grid.rect(center_x - 4 + offset, y, 2, 1, self.skin)  # dedos para tras
        grid.rect(center_x - 4 + offset, y + 1, 2, 1, "w")

    def special(self, frame: int) -> Grid:
        """Pes Invertidos: as pegadas do Curupira correm ao contrario."""
        grid = Grid(40, 40)
        if frame == 0:
            grid.paste(self.standing(), 8, 5)
            outline(grid)
            return grid
        # pegadas invertidas correndo para tras, em duas colunas
        for index in range(4):
            x = 8 + index * 4
            y = 30 - index * 6
            grid.rect(x, y, 3, 2, "y")
            grid.rect(x + 3, y, 2, 2, "O")  # dedos apontando para a esquerda
            grid.rect(x + 6, y - 5, 3, 2, "O")
            grid.rect(x + 9, y - 5, 2, 2, "R")
        if frame == 1:
            self._fighting_pose(grid, 10, 4)
            grid.rect(4, 26, 12, 2, "R")
            grid.rect(2, 28, 20, 2, "O")
            outline(grid)
            return grid
        self._fighting_pose(grid, 12, 2)
        for tier in range(4):
            width = 34 - tier * 6
            color = "y" if tier % 2 == 0 else "O"
            grid.rect(20 - width // 2, 24 + tier * 4, width, 2, color)
        outline(grid)
        return grid

    def _fighting_pose(self, grid: Grid, x: int, y: int) -> None:
        self.hair(grid, x + 4, y)
        self.head(grid, x, y + 8)
        grid.rect(x, y + 16, 8, 7, self.skin)
        grid.rect(x + 1, y + 21, 6, 1, "G")
        grid.rect(x - 3, y + 16, 3, 5, self.skin)
        grid.rect(x + 8, y + 16, 3, 5, self.skin)
        grid.rect(x + 1, y + 23, 6, 4, self.skin)
        grid.rect(x - 1, y + 27, 4, 1, "y")


class Iara(FighterArt):
    """Sereia do rio: cabelo longo, concha e cauda de escamas."""

    name = "Iara"
    chars = IARA_CHARS
    slug = "iara"
    palette = IARA_PALETTE
    skin = "s"
    skin_dark = "d"
    cloth = "t"
    cloth_dark = "T"
    white = "w"
    eye = "e"

    def hair(self, grid: Grid, center_x: int, head_top: int) -> None:
        """Cabelo de rio: calota escura sobre a cabeca, com mecha de luz."""
        grid.rect(center_x - 4, head_top, 9, 4, "H")
        grid.rect(center_x - 3, head_top + 1, 7, 2, "h")
        grid.column(center_x - 4, head_top + 4, head_top + 7, "H")
        grid.column(center_x + 3, head_top + 4, head_top + 7, "H")

    def hair_flow(self, grid: Grid, center_x: int, head_top: int) -> None:
        """O cabelo desce pelos dois lados, fora do tronco, ate a altura do quadril."""
        grid.column(center_x - 6, head_top + 8, head_top + 18, "H")
        grid.column(center_x + 5, head_top + 8, head_top + 18, "H")
        grid.column(center_x - 5, head_top + 10, head_top + 16, "h")
        grid.column(center_x + 4, head_top + 10, head_top + 16, "h")
        grid.rect(center_x - 6, head_top + 19, 2, 1, "H")
        grid.rect(center_x + 5, head_top + 19, 2, 1, "H")

    def chest(self, grid: Grid, x: int, y: int) -> None:
        grid.rect(x + 2, y + 1, 4, 3, "p")  # concha
        grid.line(x + 2, x + 5, y + 3, "d")

    def hips(self, grid: Grid, x: int, y: int) -> None:
        """Cauda de escamas no lugar dos shorts."""
        grid.rect(x - 1, y, 10, 3, "t")
        grid.line(x - 1, x + 8, y + 1, "T")
        grid.rect(x + 1, y + 2, 3, 1, "a")
        grid.rect(x + 5, y + 2, 3, 1, "T")

    def foot(self, grid: Grid, center_x: int, y: int, offset: int) -> None:
        """Nadadeira: a ponta segue para a frente, com brilho de agua."""
        grid.rect(center_x - 2 + offset, y, 5, 1, "t")
        grid.rect(center_x + 3 + offset, y, 2, 1, "a")

    def special(self, frame: int) -> Grid:
        """Canto do Rio: ondas, notas e o abraco d'agua."""
        grid = Grid(40, 40)
        if frame == 0:
            grid.paste(self.standing(), 8, 5)
            outline(grid)
            return grid
        if frame == 1:
            self._siren_pose(grid, 12, 6)
            for tier, width in ((0, 20), (1, 28), (2, 34)):
                color = "a" if tier % 2 == 0 else "b"
                grid.line(20 - width // 2, 20 + width // 2, 32 + tier * 3, color)
            self._note(grid, 5, 10, "a")
            self._note(grid, 31, 14, "w")
            outline(grid)
            return grid
        self._siren_pose(grid, 13, 4)
        for tier in range(3):
            grid.rect(4, 26 + tier * 4, 32 - tier * 6, 2, "b" if tier % 2 else "a")
        # bracos d'agua fechando o abraco
        grid.column(2, 12, 30, "a")
        grid.column(37, 12, 30, "a")
        grid.rect(2, 12, 4, 2, "w")
        grid.rect(34, 12, 4, 2, "w")
        self._note(grid, 6, 4, "w")
        self._note(grid, 32, 6, "a")
        outline(grid)
        return grid

    def _siren_pose(self, grid: Grid, x: int, y: int) -> None:
        self.hair(grid, x + 4, y)
        self.head(grid, x, y + 4)
        grid.rect(x, y + 12, 8, 7, self.skin)
        grid.rect(x + 2, y + 13, 4, 3, "p")
        grid.rect(x - 3, y + 12, 3, 5, self.skin)
        grid.rect(x + 8, y + 12, 3, 5, self.skin)
        grid.rect(x, y + 19, 8, 3, "t")
        grid.line(x, x + 7, y + 20, "T")
        grid.rect(x + 1, y + 22, 6, 4, self.skin)
        grid.rect(x - 1, y + 26, 5, 1, "t")

    def _note(self, grid: Grid, x: int, y: int, color: str) -> None:
        grid.rect(x, y, 3, 3, color)
        grid.column(x + 2, y - 5, y, color)
        grid.rect(x + 2, y - 5, 2, 1, color)


class Cuca(FighterArt):
    """Bruxa jacare: focinho de crocodilo, dentes e cabelo de fogo."""

    name = "Cuca"
    chars = CUCA_CHARS
    slug = "cuca"
    palette = CUCA_PALETTE
    skin = "s"
    skin_dark = "d"
    cloth = "R"
    cloth_dark = "O"
    white = "w"
    eye = "g"

    def hair(self, grid: Grid, center_x: int, head_top: int) -> None:
        """Cabelo de fogo: calota larga sobre a cabeca do jacare."""
        for offset, width in ((0, 7), (1, 10), (2, 11), (3, 10), (4, 9), (5, 6)):
            color = "R" if offset % 2 == 0 else "O"
            grid.rect(center_x - width // 2 - 1, head_top + offset, width, 1, color)
        grid.rect(center_x - 1, head_top - 1, 3, 1, "R")

    def hair_flow(self, grid: Grid, center_x: int, head_top: int) -> None:
        """Mechas de fogo descendo pelas costas, ao lado do tronco."""
        grid.column(center_x - 5, head_top + 6, head_top + 17, "R")
        grid.column(center_x - 6, head_top + 9, head_top + 13, "O")
        grid.rect(center_x - 5, head_top + 18, 3, 1, "R")

    def head(self, grid: Grid, x: int, y: int, eyes: bool = True, mouth: str = "fechada") -> None:
        """Cabeca de jacare: focinho para a frente, dentes e olho amarelo."""
        grid.rect(x, y, 7, 7, self.skin)
        grid.column(x + 6, y, y + 6, self.skin_dark)
        grid.rect(x + 7, y + 2, 6, 3, self.skin)  # focinho
        grid.line(x + 7, x + 12, y + 2, self.skin_dark)
        grid.line(x + 7, x + 12, y + 4, self.outline_char)
        for tooth_x in (x + 8, x + 11):
            grid.rect(tooth_x, y + 3, 1, 1, self.white)
        if eyes:
            grid.rect(x + 2, y + 1, 2, 2, self.white)
            grid.rect(x + 2, y + 1, 1, 2, self.eye)
            grid.rect(x + 4, y, 2, 2, self.white)
            grid.rect(x + 4, y, 1, 2, self.eye)
        if mouth == "aberta":
            grid.rect(x + 7, y + 3, 5, 2, self.outline_char)
            grid.rect(x + 8, y + 4, 3, 1, "t")

    def special(self, frame: int) -> Grid:
        """Nana Nenem: a Cuca vira jacare e morde."""
        grid = Grid(40, 40)
        if frame == 0:
            grid.paste(self.standing(), 8, 5)
            outline(grid)
            return grid
        if frame == 1:
            self._witch_pose(grid, 6, 8)
            self._croc_head(grid, 16, 16, jaws_open=True)
            outline(grid)
            return grid
        self._croc_head(grid, 6, 10, jaws_open=True)
        self._croc_head(grid, 6, 24, jaws_open=False)
        for tier in range(3):
            grid.rect(30, 8 + tier * 8, 6 - tier, 2, "O" if tier % 2 else "R")
        outline(grid)
        return grid

    def _witch_pose(self, grid: Grid, x: int, y: int) -> None:
        self.hair(grid, x + 4, y)
        grid.rect(x, y + 10, 7, 6, self.skin)
        grid.rect(x + 1, y + 11, 2, 2, self.white)
        grid.rect(x + 4, y + 10, 2, 2, self.white)
        grid.rect(x + 7, y + 12, 5, 2, self.skin)
        grid.rect(x - 2, y + 16, 3, 5, self.skin)
        grid.rect(x + 7, y + 16, 3, 5, self.skin)
        grid.rect(x, y + 16, 8, 6, self.skin)
        grid.rect(x + 1, y + 22, 6, 4, self.skin)
        grid.rect(x + 6, y + 22, 2, 4, self.skin_dark)

    def _croc_head(self, grid: Grid, x: int, y: int, jaws_open: bool) -> None:
        """Cabeca inteira de jacare, virada para a esquerda e mordendo."""
        grid.rect(x + 6, y, 10, 6, self.skin)  # craneo
        grid.rect(x + 6, y + 5, 10, 2, self.skin_dark)
        grid.rect(x + 12, y + 1, 3, 2, self.white)
        grid.rect(x + 12, y + 1, 1, 2, self.eye)
        if jaws_open:
            grid.rect(x, y + 2, 7, 3, self.skin)  # mandibula de cima
            grid.rect(x, y + 3, 6, 1, self.outline_char)
            grid.rect(x + 1, y + 5, 2, 1, self.white)
            grid.rect(x + 5, y + 5, 2, 1, self.white)
            grid.rect(x, y + 8, 7, 3, self.skin_dark)  # mandibula de baixo
            grid.rect(x, y + 7, 6, 1, self.outline_char)
            grid.rect(x + 2, y + 8, 4, 1, "t")
        else:
            grid.rect(x, y + 3, 7, 4, self.skin)
            grid.line(x, x + 6, y + 4, self.outline_char)
            grid.rect(x + 1, y + 4, 2, 1, self.white)
            grid.rect(x + 5, y + 5, 2, 1, self.white)
        grid.rect(x + 4, y - 3, 8, 3, "R")  # cabelo caindo por cima


FIGHTERS = [Curupira, Iara, Cuca]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        default="assets/spritesheets",
        help="diretorio dos JSON de saida",
    )
    parser.add_argument("--preview", help="grava um PNG de inspecao da arte")
    arguments = parser.parse_args()

    output_dir = pathlib.Path(arguments.output_dir)
    for fighter_class in FIGHTERS:
        art = fighter_class()
        bind_palette(fighter_class.chars)
        data = _sheet_of(art)
        write_spritesheet(data, output_dir / f"{art.slug}.json")
        if arguments.preview:
            render_preview(data, pathlib.Path(f"{arguments.preview}.{art.slug}.png"))
    return 0


def _sheet_of(art: FighterArt) -> dict:
    from pixel_grid import build_spritesheet

    return build_spritesheet(art.slug, art.palette, art.animations())


if __name__ == "__main__":
    raise SystemExit(main())