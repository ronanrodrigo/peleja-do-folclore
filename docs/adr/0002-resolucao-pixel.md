# Resolução base 426x240 com escala inteira 3x

## Contexto

A resolução base define o custo de cada frame de arte e a legibilidade dos sprites de luta.

## Decisão

Resolução base **426x240**, renderizada em escala inteira **3x** (1278x720), filtro nearest,
sprites de lutador com cerca de 90-110 px de altura.

## Alternativas consideradas

- 320x180 @4x (visual SNES puro, sprites menores, menos detalhe nos golpes).
- 384x216 @3-4x (meio-termo).
- 256x144 @5x (mais retrô, sprites simples).

## Consequências

- Mais pixels por sprite significa mais trabalho por frame, o que reforça a decisão de codificar
  os spritesheets como dados versionados em vez de desenhá-los à mão em editor de imagem.
- Escala fracionária é proibida: qualquer zoom precisa ser múltiplo inteiro.
