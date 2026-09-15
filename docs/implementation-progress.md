# Progresso de implementacao

Registro por fatia fechada. Cada entrada exige evidencia executavel (regra de
evidencia do ADR 0006) -- nunca "pronto" declarado.

## Ticket 1 — Esqueleto jogavel e deploy

**Estado:** fechado.

**Entregue**

- `project.godot`: resolucao base 426x240, `default_texture_filter` nearest,
  autoload `app_container`, renderizador `gl_compatibility` (o melhor alvo web).
- `export_presets.cfg`: preset `Web` **single-threaded**
  (`variant/thread_support=false`), saida `build/web/index.html`, com
  `test/`, `addons/gut/` e `docs/` fora do pacote publicado.
- `scenes/title_screen.tscn` + `scenes/title_screen.gd`: tela de titulo em pixel
  art codificada em dados (fonte bitmap 5x7 escrita a mao + silhuetas
  deterministicas). Nenhum asset externo, nenhuma fonte de terceiros.
- `autoloads/app_container.gd`: composition root. Unico lugar que instancia
  adapters; modo `sample`/`live` por configuracao explicita (env
  `PELEJA_ADAPTERS`, argumento `--adapters=`, project setting
  `peleja/adapters/mode`); nenhum estado de jogo.
- `src/application/gateways/`: os cinco contratos de capacidade, um por arquivo.
- `src/infrastructure/sample/`: cinco adapters deterministicos, sem I/O.
- `addons/gut/`: GUT 9.7.1 (`bitwes/Gut`, tag `v9.7.1`, commit
  `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`), vendorizado.
- `test/smoke/`: testes GUT de bootstrap, de contrato dos adapters sample e da
  tela de titulo.
- `.github/workflows/ci.yml`: `barichello/godot-ci:4.7.2` rodando `make verify`
  em PR e push na `main`.
- `vercel.json`: deploy estatico de `build/web`.

**Evidencia de fechamento**

- `make verify` sai com codigo 0: gdlint `Success: no problems found`; GUT
  headless `19/19` testes, `125` asserts, com `-gexit`; export gerou
  `index.html`, `index.js`, `index.pck` e `index.wasm`.
- Export comprovadamente single-threaded: `build/web/index.wasm` tem
  `39514754` bytes, exatamente o `godot.wasm` de `web_nothreads_release.zip`
  (a variante com threads mede `38820072`).
- Build servido localmente responde 200 e o jogo publicado aparece na URL do
  Vercel (print anexado ao PR).

**Dividas assumidas nesta fatia**

- Modo `live` ainda cai para os adapters `sample` nas cinco capacidades, porque
  nenhum adapter de producao existe: `keyboard-input-adapter` e
  `sprite-render-adapter` chegam no ticket 3/4, `godot-asset-gateway` no ticket
  4, `godot-audio-gateway` e `local-persistence-gateway` no ticket 8.
  `app_container.missing_production()` reporta o que falta, e o teste cobre o
  fallback.
- A tela de titulo desenha o proprio placeholder; ela passa a delegar ao
  `render-gateway` de producao quando o `sprite-render-adapter` existir.
## Ticket 2 — Nucleo de combate no dominio

**Estado:** fechado.

**Entregue**

- `src/domain/`: 16 arquivos puros, todos `RefCounted`, sem `Node`, cena,
  entrada, arquivo, audio, rede ou temporizador — `fighter_state`, `bounding_box`,
  `move`, `fighter_stats`, `guardian_stats`, `opponent_stats`, `fighter`,
  `health`, `special_meter`, `round_clock`, `match_rules`, `hidden_advantage`,
  `rng`, `spritesheet`, `archetype`, `arcade_order`.
- Golpes leve/pesado/agarrão com alcance, dano e janelas de inicio/ativo/
  recuperacao em ticks; hitbox/hurtbox retangulares puras, com agachar
  encolhendo a hurtbox sem deslocar os pes.
- Dano por golpe com defesa reduzindo golpes bloqueaveis (o agarrão passa pela
  guarda), estouro de dano limitado a vida restante e nocaute ao zerar a vida.
- Barra de Especial enchendo ao bater e ao apanhar; o Golpe Especial consome a
  barra inteira e so dispara com ela cheia.
- Relogio do round em ticks (60 ticks por segundo, 60 s) e melhor de tres em
  `match_rules` (2-0, 2-1 e empate de rounds), com nocaute e tempo esgotado
  resolvidos em funcao pura (`resolve_round`).
- Vantagem Oculta explicita em `hidden_advantage.gd` (vida x1.6 e dano x1.4 sobre
  o Guardiao, invisivel na HUD) e Oponentes em dificuldade crescente por
  Arquetipo, todos abaixo do Guardiao mesmo na setima Peleja.
- `rng.gd`: xorshift32 puro com semente injetada; nenhum outro ponto do dominio
  sorteia, o que torna a partida reproduzivel.
- `spritesheet.gd`: modelo e validacao do formato codificado (paleta + matrizes
  de pixel, dimensoes, frames por animacao), sem ler nem desenhar imagem.
- `archetype.gd` e `arcade_order.gd`: os 7 Arquetipos e a ordem fixa do arcade
  como dado, prontos para o ticket 6 consumir.
- `test/domain/`: 15 arquivos GUT espelhando o dominio, incluindo
  `test_domain_purity.gd`, que recusa token de engine em `src/domain/` e roda
  dentro do `make test` (portanto no CI).

**Evidencia de fechamento**

- `make verify` sai com codigo 0: gdlint `Success: no problems found`; GUT
  headless `168/168` testes e `1798` asserts com `-gexit` (eram 19 testes no
  ticket 1: esta fatia acrescenta 149); export web gerou `index.html`,
  `index.js`, `index.pck` e `index.wasm` (39514754 bytes, a variante
  single-threaded).
- Pureza do dominio: `grep -rn` dos tokens proibidos (`Node`, `SceneTree`,
  `Input`, `Timer`, `FileAccess`, `OS.`, `res://`, `@export`, ...) em
  `src/domain/` nao retorna nenhuma ocorrencia.

**Dividas assumidas nesta fatia**

- `docs/spritesheet-format.md` (formato formal) e o renderizador ficam no
  ticket 4; aqui entra apenas o modelo e a validacao do formato.
- A IA do Oponente e o `match-service` ficam no ticket 3; o dominio ja expoe a
  interface necessaria (`Fighter.advance_tick`, `Fighter.resolve_hit`,
  `MatchRules.resolve_round`, `Rng` injetado).
- `archetype.gd`, `arcade_order.gd` e `spritesheet.gd` sao dado estavel
  introduzido aqui; os tickets 4 e 6 acrescentam campos, sem mudar contratos.
