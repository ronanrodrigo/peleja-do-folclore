# Arquitetura — Peleja do Folclore

## Camadas e direção de dependência

```text
scenes/ + autoloads/  ->  interface-adapters/  ->  application/  ->  domain/
infrastructure/       ------------------------->  application/ (implementa gateways)
```

- `src/domain/` — regras puras de combate: estado do lutador, hitbox/hurtbox, dano, vida, barra de
  especial, relógio do round, resolução de melhor de três, Vantagem Oculta, tabela de Golpes Especiais.
  Não conhece `Node`, `SceneTree`, `Input`, arquivo, áudio nem cena. Testável sem engine rodando.
- `src/application/gateways/` — uma capacidade por arquivo: `input-gateway`, `render-gateway`,
  `audio-gateway`, `asset-gateway`, `persistence-gateway`.
- `src/application/services/` — casos de uso com `execute(...)`: `match-service` (uma Peleja),
  `arcade-service` (as 7 Pelejas e a progressão), `reviravolta-service` (a cena final).
- `src/interface-adapters/` — `keyboard-input-adapter`, `touch-input-adapter`, `hud-adapter`,
  `panel-adapter`: traduzem input e ligam estado de jogo a nós de UI.
- `src/infrastructure/` — `godot-asset-gateway` (carrega spritesheets JSON e paletas),
  `godot-audio-gateway`, `local-persistence-gateway`, e `sample/` com adapters determinísticos em memória.
- `scenes/` — cenas finas: montam nós, conectam sinais, delegam para serviços.
- `autoloads/` — composition root: único lugar que instancia adapters concretos.

## Invariantes

1. O domínio nunca lê input nem desenha: recebe comandos e devolve estado.
2. Toda aleatoriedade do domínio passa por uma semente injetada (reprodutibilidade dos testes).
3. O Oponente nunca é escolhido pelo jogador; o `arcade-service` decide a ordem fixa.
4. O Guardião sempre tem Vantagem Oculta; a Reviravolta é irreversível e sempre termina com o
   Oponente derrotado.
5. Nenhum arquétipo usa símbolo real, nome de pessoa real ou referência a religião.
6. Renderização em escala inteira, filtro nearest, resolução base 426x240.

## Testes e gate

- GUT em `test/`, espelhando `src/`. Domínio e aplicação testados com adapters `sample/` (sem I/O).
- `make verify` = gdlint + GUT headless + export web. É o gate obrigatório do PR.
- CI no GitHub Actions com imagem `barichello/godot-ci` (headless), rodando testes e export.
- Deploy: export estático publicado no Vercel em `peleja.ronanrodrigo.dev`.
