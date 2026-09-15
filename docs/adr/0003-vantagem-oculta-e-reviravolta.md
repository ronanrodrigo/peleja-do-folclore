# Vantagem Oculta do folclore e Reviravolta sobrenatural

## Contexto

Requisito de produto: os lutadores do folclore são sempre mais fortes e, se um Oponente vencer,
ele ainda é derrotado por uma força sobrenatural.

## Decisão

Duas camadas, ambas explícitas no código e invisíveis na interface:

1. **Vantagem Oculta** — o Guardião recebe mais vida e mais dano que o Oponente, sem indicação na HUD.
2. **Reviravolta** — se o Oponente vencer a melhor de três, o jogo entra numa cena de painel pixel art
   de tela cheia, sem interação, em que a Força Sobrenatural (a mata / o Brasil profundo, entidade sem
   forma: voz, vento, raiz) dissolve o Oponente. O resultado da campanha nunca é a derrota do folclore;
   o jogador perde a Peleja, não o arcade.

## Alternativas consideradas

- Sem vantagem de stats (só o Golpe Especial diferenciaria) — mais justo, porém contraria o requisito.
- Comeback progressivo ("fúria da mata") — mais interessante de jogar, mais difícil de balancear e de testar.
- Garantir vitória sempre (o Oponente nunca pode vencer) — tira o sentido de jogar.

## Consequências

- O balanceamento tem dois números a calibrar (vida e dano) e um teste de domínio que garante que a
  Reviravolta sempre dispara quando o Oponente vence.
- A Reviravolta precisa de arte de painel e texto, o que entra no orçamento de arte.
