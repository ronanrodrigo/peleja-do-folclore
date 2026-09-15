# Pipeline de arte misto: sprites codificados e cenários/UI por ComfyUI

## Contexto

Animação de luta exige frames coerentes entre si; geração por IA varia entre frames e quebra a
continuidade. O ComfyUI local estava fora do ar no momento do kickoff (porta 8188 recusando conexão).

## Decisão

- **Lutadores e oponentes**: spritesheets **codificados como dados** (paleta + matrizes de pixel) em
  JSON versionado, renderizados em escala inteira. Determinístico, revisável em diff, sem dependência de IA.
- **Cenários, painéis de Reviravolta, retratos e UI**: pixel art gerada no **ComfyUI local** com
  checkpoint SD1.5 de pixel art (o Mac é um M4 com 16 GB unificados: SDXL/Flux ficam apertados).
- **v1 não bloqueia no ComfyUI**: as artes geradas entram quando o backend estiver de pé, com fallback
  de arte em código para não travar o jogo. O plano de instalação e uso vive em `docs/plans/comfyui.md`.

## Alternativas consideradas

- Tudo por IA, inclusive frames de animação — inconsistência entre frames e risco de licença.
- Tudo em código — cenários de tela cheia ficariam pobres para o esforço.

## Consequências

- O repositório carrega dados de sprite em vez de PNGs grandes: diffs legíveis e zero asset binário opaco.
- O pipeline de IA precisa de pós-processamento obrigatório: quantizar a paleta, reduzir para a
  resolução base e ampliar com nearest-neighbor.
