# Stack: Godot 4.7 com export web single-threaded e deploy estático no Vercel

## Contexto

Precisávamos de um jogo de luta 2D com controle fino de pixel art, animação por spritesheet e
input de teclado e toque, publicado numa URL pública.

## Decisão

Godot 4.7.2 (versão instalada e travada no repositório), GDScript, export web **single-threaded**,
build estático publicado no Vercel em `peleja.ronanrodrigo.dev`.

## Alternativas consideradas

- **Canvas 2D + TypeScript**: controle total do grid de pixel, mas exige escrever motor de física,
  animação e input do zero.
- **Phaser 3**: engine web madura, porém menos controle do grid de pixel e dependência de ecossistema JS.

## Consequências

- Export com threads exigiria `SharedArrayBuffer` e headers COOP/COEP, que o Vercel não serve por
  padrão; single-threaded evita o problema ao custo de não usar threads.
- Export templates precisam ser instalados na máquina e no CI (imagem `barichello/godot-ci`).
- O jogo roda no navegador, inclusive em toque; o alvo desktop continua sendo teclado/gamepad.
