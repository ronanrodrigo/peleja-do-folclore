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

## Ticket 9 — Arte de cenarios, paineis e retratos por ComfyUI

**Estado:** fechado.

**Entregue**

- `tools/comfy/` (ferramentaria, fora das camadas do jogo):
  `workflows/pixelart_bg.json` (SD 1.5 em formato **API**: 512x288, 28 passos,
  cfg 7.0, `dpmpp_2m`/`karras`), `scripts/run_workflow.py` (cliente HTTP do
  ComfyUI feito so com a stdlib: injeta prompt/negativo/seed/tamanho por papel,
  enfileira, espera e baixa), `postprocess.py` (426x240 com **nearest** +
  quantizacao em **ate 32 cores** alinhada a paleta do jogo),
  `generate.py` (as tres artes, metadados e `CREDITS.md`),
  `extract_palette.py`, `test_postprocess.py` e `README.md`.
- `assets/palettes/peleja.json`: paleta extraida das constantes `COLOR_*` da
  tela de titulo (7 cores) -- o pos-processamento nao inventa cor.
- `assets/generated/`: `backgrounds/forest-arena.png`,
  `panels/reviravolta-panel.png` e `portraits/saci-portrait.png`, cada uma com o
  `.json` de metadados ao lado (prompt, prompt negativo, seed, workflow,
  `prompt_id`, modelo, licenca, URL de origem e sha256 do PNG), mais
  `CREDITS.md` com modelo, licenca e URL de origem.
- `src/infrastructure/godot-asset-gateway.gd`: adapter de producao do
  `asset-gateway`. Carrega arte por slug, le os metadados e, quando o arquivo nao
  existe, devolve o fallback do chamador -- ou o **fallback em codigo** (426x240
  deterministico por slug) se o chamador nao passar nenhum.
- `scenes/title_screen.gd`: o fundo vem da arte gerada pelo slug `forest-arena`
  via asset-gateway; sem arte, o desenho em codigo assume (`backdrop_source()`).
- `test/infrastructure/asset_gateway_fallback_test.gd` (slug, metadados,
  fallback, CREDITS) e ajustes em `test/smoke/` para o modo `live` com o adapter
  de producao no lugar.
- `tools/capture_generated_art.gd` (+ `.tscn`) para o print de evidencia e o
  alvo `make test-art` no Makefile.

**Evidencia de fechamento**

- `curl -s http://127.0.0.1:8188/system_stats` responde JSON (ComfyUI 0.36.0) e
  `comfy model list` mostra `v1-5-pruned-emaonly.safetensors` (4165181 KB).
- Modo `live` passou a usar producao no asset: `origin("asset") == "live"`
  (antes caia para `sample`), coberto por
  `test_live_mode_uses_the_production_adapter_where_it_exists`.
- `make verify` sai com codigo 0: gdlint `Success: no problems found`; GUT
  headless `22/22` testes, `136` asserts, com `-gexit`; export gerou
  `index.html`, `index.js`, `index.pck` e `index.wasm` (single-threaded,
  `39514754` bytes).
- `make test-art` sai com codigo 0: `21` verificacoes do pos-processamento
  (426x240, <= 32 cores, nearest sem suavizacao num xadrez 2x2 e determinismo
  por sha256) mais as tres artes publicadas validadas, com o sha256 do `.json`
  conferido contra o PNG.
- Prints em `docs/evidence/ticket-09-*.png`: a tela de titulo usando a arte
  gerada e as tres artes desenhadas pelo motor via asset-gateway (o capturador
  registra `fonte=generated pixels=408960`).
- Arte final: `forest-arena` (seed 42, `prompt_id` `b5df59e5-8e82-4325-9a81-4ec4abb80617`),
  `reviravolta-panel` (seed 7, `921fc2ad-afc6-4c31-a20f-bc09acc612ac`) e
  `saci-portrait` (seed 42, `978332d3-7187-4d0c-9cc8-dcf2c9507c56`).

**Dividas assumidas nesta fatia**

- Painel de Reviravolta e retrato ainda nao sao exibidos por um caso de uso:
  entram na tela de Reviravolta e no retrato do arcade (tickets 7 e 10).
- Lutadores e oponentes nao passam por aqui: sao spritesheets codificados como
  dados (ADR 0005).
- A seed de cada arte foi fixada por sweep visual e esta registrada no `.json`;
  reproduzir o mesmo PNG depende do mesmo checkpoint e do mesmo backend (MPS).
- Ate o ticket 7, o unico lugar do jogo que consome arte gerada e a tela de
  titulo; o resto segue no fallback em codigo.

## Ticket 3 — Lutador jogavel e IA

**Estado:** fechado.

**Entregue**

- `src/domain/opponent_ai.gd`: politica pura da IA do Oponente, parametrizada
  por tres niveis (`easy`/`normal`/`hard`) em `PROFILES` (agressao, defesa,
  recuo, uso do Especial e distancia de engajamento, mais `reaction_ticks`) e
  decisao deterministica pela semente injetada; `WAIT` nao consome o `Rng`.
- `src/application/services/match-service.gd`: caso de uso de uma Peleja.
  Orquestra os dois lutadores, o relogio em ticks, a melhor de tres e a IA:
  drena os comandos do jogador do `input-gateway`, decide e executa a acao do
  Oponente, avanca os lutadores, resolve os golpes e fecha o round/mata. Entrega
  um `render_model()` (retangulos no espaco 426x240) como unica fonte visual e um
  `snapshot()`. Nenhum estado em singleton.
- `src/interface-adapters/keyboard-input-adapter.gd`: teclado (WASD/setas,
  Shift defende, J/K/L leve/pesado/agarrao, U especial), com `poll()`/`clear()`
  e teclas de repeticao para movimento/defesa.
- `src/interface-adapters/touch-input-adapter.gd`: botoes na tela produzindo os
  mesmos comandos do teclado; `mount()` monta os botoes e alimenta a mesma fila.
- `src/application/gateways/input-gateway.gd`: `Command` ganha `BLOCK` (a defesa
  e um comando de primeira classe, como o agachar).
- `autoloads/app_container.gd`: continua o unico lugar que instancia adapter
  concreto; passa a instanciar o adapter de toque junto do de teclado e o expoe
  por `touch_input_gateway()` (a cena escolhe teclado ou toque, sem instanciar).
- `scenes/fight.tscn` + `scenes/fight.gd`: cena fina -- monta o `FightDisplay`,
  delega ao `MatchService`, conecta o sinal `match_finished` e pinta os
  retangulos do `render_model()` num `Image` 426x240 com filtro nearest.
- `tools/capture_fight.gd` + `.tscn`: ferramenta de evidencia fora das camadas do
  jogo; joga a Peleja com o `input-gateway` `sample` (sem teclado sintetico) e
  grava os prints.
- `test/domain/test_opponent_ai.gd`, `test/application/test_match_service.gd`,
  `test/smoke/test_fight_screen.gd` e ajustes em `test/smoke/test_app_container.gd`.

**Evidencia de fechamento**

- `make verify` sai com codigo 0: gdlint `Success: no problems found`; GUT
  headless `197/197` testes e `2057` asserts com `-gexit` (eram 171 testes no
  ticket 9: esta fatia acrescenta 26); export web gerou `index.html`, `index.js`,
  `index.pck` e `index.wasm` (`39514754` bytes, a variante single-threaded).
- IA deterministica por semente e coberta por teste (`mesma semente -> mesmas
  decisoes`) e o `match-service` reproduz a Peleja inteira com comandos iguais.
- Print de uma Peleja completa em `docs/evidence/ticket-03-fight-*.png`
  (`round1`, `round2`, `result`, 426x240): o Guardiao vence 2-0 (`rounds [0,0]`),
  Peleja encerrada em 6823 ticks de simulacao, com os corpos no chao, as duas
  barras de vida, as barras de Especial e os pips de round.

**Dividas assumidas nesta fatia**

- Os lutadores sao retangulos placeholder pintados a partir do `render_model()`:
  o `sprite-render-adapter` de producao e os spritesheets codificados chegam no
  ticket 4; ate la a `render-gateway` de producao ainda nao existe (o modo `live`
  cai para `sample` em `render`, `audio` e `persistence`).
- O Golpe Especial usa a moldura comum (`Move.special`); o efeito proprio de cada
  Guardiao e a tabela de especiais entram no ticket 5.
- A IA tem tres niveis com uma unica escada de dificuldade; a variacao por
  Arquetipo (ataques que roubam barra, perfis distintos) entra no ticket 6.
- A cena de luta roda sozinha (`godot --path . scenes/fight.tscn`); a navegacao
  titulo -> luta e o retorno de vitoria/derrota entram no polimento (ticket 10).
