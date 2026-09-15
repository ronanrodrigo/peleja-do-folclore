# Arcade fixo de 7 Pelejas, uma por Arquétipo, sem modo versus

## Contexto

Era preciso decidir a estrutura do modo principal: ordem fixa, sorteio, número de lutas e existência
de modo versus avulso.

## Decisão

Arcade de **7 Pelejas em ordem fixa**, uma por Arquétipo, na ordem dos ADR 0004, com dificuldade
crescente e **sem chefe final**. Não há modo versus avulso no v1.

## Alternativas consideradas

- 3 lutas sorteadas por partida (mais rejogabilidade, menos narrativa).
- 7 lutas em ordem aleatória (quebra a curva de dificuldade).
- Versus avulso além do arcade (escopo extra sem requisito).

## Consequências

- A progressão é determinística e testável: o `arcade-service` recebe a ordem como dado.
- Rejogabilidade vem de escolher outro Guardião, não de sorteio.
