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

## Ticket 4 — Spritesheet codificado e Saci

**Estado:** fechado.

**Entregue**

- `docs/spritesheet-format.md`: o formato codificado fixado e documentado —
  caminho, chaves de topo, codificacao de `pixels` (lista plana, lista de linhas
  e linhas em texto compacto na base 36), regras de validacao, regra de escala
  inteira/nearest/letterbox, a tabela do Saci (frames e quadros por animacao) e
  como adicionar um lutador novo.
- `src/domain/spritesheet.gd` (extensao por adicao): `PIXEL_CHARS` e
  `TRANSPARENT_CHAR` (linha compacta, um caractere por pixel), `decode_problems`
  (caractere invalido vira problema reportado, nao pixel silencioso),
  `pixel_at`, `row_pixels` e `pixel_color` para o renderer ler a matriz. O
  contrato anterior nao mudou: `decode`, `errors()` e `REQUIRED_ANIMATIONS`
  seguem os mesmos.
- `assets/spritesheets/saci.json`: a arte do Saci como **dado versionado** (12
  cores de paleta, 10 animacoes, 23 frames, 29455 bytes de JSON) — nenhum PNG
  binario de lutador no repositorio.
- `src/interface-adapters/sprite-render-adapter.gd`: renderer de producao.
  Desenha a resolucao base 426x240 num `Image` RGBA8 e apresenta num `TextureRect`
  com filtro **nearest** e escala **inteira** (3x), com letterbox calculado por
  `display_scale()`/`letterbox_rect()`; escala invalida e recusada e registrada
  em `rejected_scales`, nunca desenhada borrada.
- `src/application/gateways/render-gateway.gd`: contrato ganha
  `draw_sprite(sheet, animacao, frame, origem, escala, flip)`,
  `DEFAULT_PIXEL_SCALE` (3) e `BASE_SIZE` (426x240), por adicao.
- `src/infrastructure/godot-asset-gateway.gd`: `load_spritesheet(slug)` deixa de
  devolver vazio e passa a ler `assets/spritesheets/<slug>.json`
  (`spritesheet_path`, `has_spritesheet`, `exists` reconhece o slug).
- `src/domain/special_move.gd` + `special_move_table.gd`: o efeito proprio do
  Golpe Especial como dado puro. O **Redemoinho** do Saci puxa o Oponente 3
  pixels por tick de janela ativa, num alcance de 72 pixels.
- `src/domain/fighter.gd`: `pull_towards(alvo, pixels)` — o puxao nunca passa do
  alvo nem sai da arena.
- `src/application/services/match-service.gd`: aplica o puxao na janela ativa do
  Especial, desenha o turbilhao em `render_model()` e expoe `special_active` e
  `special_name` no `snapshot()`.
- `tools/art/build_saci_spritesheet.py`: fronteira de autoria (fora das camadas do
  jogo) que desenha o Saci com primitivas e emite o JSON; `--preview` gera um PNG
  de inspecao.
- `tools/capture_saci.gd` + `.tscn` e o alvo `make capture-saci`: ferramenta de
  evidencia que desenha cada animacao pelo renderer de producao e grava um PNG em
  `docs/evidence/`.
- Testes: `test/domain/test_spritesheet_encoding.gd`,
  `test/domain/test_special_move.gd`, `test/infrastructure/test_spritesheet_asset.gd`,
  `test/interface_adapters/test_sprite_render_adapter.gd`, dois casos novos em
  `test/application/test_match_service.gd` e os ajustes de `test/smoke/test_app_container.gd`
  (a capacidade `render` agora tem adapter de producao e cai para `sample` se e
  somente se o arquivo nao existir).

**Evidencia de fechamento**

- `make verify` sai com codigo 0: gdlint `Success: no problems found`; GUT
  headless `239/239` testes e `23132` asserts com `-gexit` (eram 197 testes no
  ticket 3: esta fatia acrescenta 42); export web gerou `index.html`, `index.js`,
  `index.pck` e `index.wasm` (`39514754` bytes, a variante single-threaded).
- `make capture-saci` sai com codigo 0 e grava 10 prints 426x240 em
  `docs/evidence/ticket-04-saci-<animacao>.png` (23 frames, escala 3x), um por
  animacao exigida: o Saci de uma perna, gorro vermelho e cachimbo, e o
  Redemoinho com o Saci dentro do turbilhao.
- O formato e validado contra a arte real: paleta dentro do maximo, matriz
  completa em todos os 23 frames, indice de pixel sempre dentro da paleta,
  dimensoes e contagem de frames por animacao iguais ao documentado, e nenhuma
  imagem binaria em `assets/spritesheets/`.
- Escala: `display_scale` e testada com varias janelas (1278x720 -> 3x,
  900x500 -> 2x, 400x300 -> 1x) e o letterbox centraliza a sobra; escala 0 ou
  negativa e recusada pela render-gateway (o fator fracionario nao existe na API,
  que so aceita inteiro).
- O Redemoinho consome a Barra de Especial inteira e so dispara com a barra
  cheia, no dominio (`Fighter.start_special`) e no caso de uso (`match-service`).

**Dividas assumidas nesta fatia**

- O desenho dos lutadores na cena de luta ainda e o `render_model()` de
  retangulos: o `sprite-render-adapter` desenha spritesheets quando chamado
  (`draw_sprite`) e a cena passa a compor os dois no polimento (ticket 10).
- Os efeitos proprios dos outros tres Guardioes entram no ticket 5 por adicao em
  `SpecialMoveTable` (o Saci e o unico com efeito cadastrado aqui).
- `heavy` usa um quadro mais largo (32x34) que as demais animacoes de corpo: e o
  formato permitindo quadro por animacao, nao um caso especial no renderer.

## Ticket 5 — Elenco folclorico completo

**Estado:** fechado.

**Entregue**

- `src/domain/status_effect.gd`: o status de Golpe Especial como dado puro —
  `INVERT_CONTROLS` e `SLEEP`, duracao em ticks de simulacao (60 por segundo),
  `advance_tick`/`refresh` e `invert_direction` (o espelho do lado). Nada de
  temporizador, cena ou no de UI.
- `src/domain/fighter_status.gd`: o conjunto de status num objeto proprio, para o
  `Fighter` manter a mesma superficie publica de antes (`add`, `has`,
  `remaining`, `is_asleep`, `inverts_controls`, `advance`, `names`).
- `src/domain/special_move.gd` + `special_move_table.gd` (adicao no fim do
  arquivo): **Pes Invertidos** (Curupira: 180 ticks = 3 s de comandos invertidos
  e queda de 24 px por tick para o lado contrario ao que o alvo defende),
  **Canto do Rio** (Iara: sono de 120 ticks e dreno de 3 de vida por tick,
  devolvido a ela) e **Nana Nenem** (Cuca: sono de 120 ticks e mordida de jacare
  de 4 de dano por tick), aplicados por `apply_active_tick` na janela ativa do
  golpe. O Saci/Redemoinho e a funcao `for_guardian` seguem intactos; o novo
  `_effect_for_roster` cobre o resto do elenco e um nome fora dele segue sem
  efeito.
- `src/domain/fighter.gd` (adicao por dentro, sem metodo publico novo): os status
  avancam a cada tick, o sono tira o controle (`can_act`) e o lado trocado e
  aplicado no `walk` — vale igual para o comando do jogador e para a decisao de
  avancar/recuar da IA. `health.gd` ganha `heal()` para o dreno.
- `src/domain/guardian_stats.gd` (adicao): `ROSTER`/`SLUGS` com os 4 Guardioes e
  os identificadores em ingles (`saci`, `curupira`, `iara`, `cuca`).
- `src/application/services/character-select-service.gd`: a selecao como
  comando-e-estado puro — `rows()` (nome, slug e nome do Golpe Especial por
  Guardiao), navegacao com volta no elenco, confirmar/cancelar e `result()`
  devolvendo o Guardiao escolhido como **dado**. Nenhum estado global escondido:
  duas instancias nao se enxergam (coberto por teste).
- `src/application/services/match-service.gd` (adicao): aplica o efeito da lenda
  por tick de janela ativa (`special_report`) e expoe `guardian_status` e
  `opponent_status` no `snapshot()`.
- `src/interface-adapters/hud-adapter.gd`: modelo de HUD da selecao — retrato
  pelo slug da spritesheet codificada, nome e nome do Golpe Especial, coluna
  selecionada destacada — com `discloses_hidden_advantage()` como invariante da
  Vantagem Oculta. `src/interface-adapters/bitmap-font.gd`: a fonte bitmap 5x7
  com glifos acentuados (Á, Ã, Ç, É, Ê, Í, Ó, Ô, Õ, Ú) para a copy pt-BR.
- `scenes/character_select.tscn` + `.gd`: cena fina (monta o no, delega ao
  servico e ao adapter, drena o input-gateway e emite `guardian_selected`);
  `scenes/fight.gd` passa a aceitar `guardian_name`, com o Saci como padrao — e o
  ponto em que o arcade entrega a escolha do jogador.
- `assets/spritesheets/curupira.json`, `iara.json` e `cuca.json`: 10 animacoes e
  23 frames cada, no mesmo esquema de quadros do Saci (corpo 24x34, agachado
  26x20, pesado 32x34, especial 40x40, nocaute 34x20), como **dado versionado**
  (paleta + matrizes de pixel). Nenhum PNG binario de lutador.
- `tools/art/pixel_grid.py` (maquinaria comum: matriz, contorno por silhueta,
  codificacao compacta e previa), `tools/art/build_cast_spritesheets.py` (os tres
  novos Guardioes) e o gerador do Saci passando a usar a maquinaria — reproduz
  `assets/spritesheets/saci.json` byte a byte.
- `tools/capture_cast.gd` + `.tscn` e o alvo `make capture-cast`: a tela de
  selecao de verdade (cursor em cada Guardiao) e uma Peleja de verdade por
  Guardiao, com a arte desenhada pelo `sprite-render-adapter` de producao.
- `docs/spritesheet-format.md`: secao do elenco completo, com golpe e efeito de
  cada Guardiao.
- Testes: `test/domain/test_status_effect.gd`, `test/domain/test_fighter_status.gd`,
  `test/domain/test_special_moves.gd`, `test/application/test_special_effects_in_match.gd`,
  `test/application/test_character_select_service.gd`,
  `test/interface_adapters/test_hud_adapter.gd`,
  `test/smoke/test_character_select_screen.gd` e
  `test/infrastructure/test_cast_spritesheets.gd`, mais o ajuste do
  `test/domain/test_special_move.gd` (o Curupira deixou de ser o "sem efeito").

**Evidencia de fechamento**

- `make verify` sai com codigo 0: gdlint `Success: no problems found`; GUT
  headless `297/297` testes e `86286` asserts com `-gexit` (eram 239 testes no
  ticket 4: esta fatia acrescenta 58); export web gerou `index.html`, `index.js`,
  `index.pck` e `index.wasm` (`39514754` bytes, a variante single-threaded).
- `make capture-cast` sai com codigo 0 e grava 8 prints 426x240 em
  `docs/evidence/ticket-05-*`: a tela de selecao com o cursor em cada um dos 4
  Guardioes (`ticket-05-select-{saci,curupira,iara,cuca}.png`) e cada Guardiao em
  luta na janela ativa do proprio Golpe Especial
  (`ticket-05-fight-{saci,curupira,iara,cuca}.png`, escala 3x, com o relatorio
  `golpe=... janela_ativa=true` no log).
- Cada especial tem teste proprio: inversao de comandos (o comando do jogador
  espelhado no `match-service` e a duracao de 3 s), drenagem de vida (o que sai
  do Oponente volta para a Iara, sem vida negativa) e sono (o Oponente deixa de
  aceitar comando e a IA nao anda enquanto durar), com o determinismo por semente
  reafirmado para os efeitos.

**Dividas assumidas nesta fatia**

- O `arcade-service` (ticket 6) consome `CharacterSelectService.result()`
  (`{"guardian", "slug", "special_name"}`) e passa o Guardiao para
  `scenes/fight.gd` por `guardian_name`; nesta fatia nenhum servico de arcade e
  importado ou instanciado.
- O Oponente segue um retangulo colorido na arena: a arte dos 7 Arquetipos e o
  roubo de barra sao do ticket 6, e a composicao dos sprites na cena de luta
  (hoje o print compoe) entra no polimento do ticket 10.
- A inversao de comandos do Oponente vale pela IA (nao ha jogador humano do outro
  lado); o caminho do Guardiao invertido esta implementado e testado.
- `match-service.gd` e `special_move_table.gd` foram alterados de forma aditiva e
  localizada (efeito no fim da funcao, `_effect_for_roster` no fim do arquivo)
  porque os tickets 6 e 8 rodam em paralelo sobre esses mesmos arquivos.

## Ticket 6 — Os 7 arquetipos do poder

**Estado:** fechado.

**Entregue**

- `tools/art/build_opponent_spritesheets.py`: gerador (fronteira de autoria, fora
  das camadas do jogo) que estende o padrao do gerador do Saci e emite os sete
  spritesheets codificados. Cada Oponente tem paleta de 11 a 15 cores, silhueta e
  trejeito proprios e as dez animacoes obrigatorias (23 frames, mesmo contrato de
  quadro do ticket 4).
- `assets/spritesheets/{capataz,banqueiro,redpill,camisa-verde,doutor-pureza,fantasma-do-reich,falso-pastor}.json`:
  a arte dos 7 Oponentes como **dado versionado** (nenhum PNG binario de lutador),
  validada por teste contra o arquivo real.
- `src/domain/opponent_profile.gd`: o perfil de cada Arquetipo como dado -- slug
  da aparencia, golpe-assinatura (Chicote Largo, Juros Compostos, Spray de Pilula,
  Gaita de Marcha, Teoria Drenante, Vento de Cinzas e Dizimo), a janela do golpe
  e o ajuste de IA que distingue um Oponente do outro.
- `src/domain/meter_steal_move.gd`: os golpes que roubam a Barra de Especial
  (Banqueiro e Falso Pastor). Como o Golpe Especial exige a barra **cheia**, o
  roubo adia o Especial do Guardiao sem regra nova no `Fighter`.
- `src/domain/opponent_ai.gd`: a acao `SIGNATURE` e `apply_overrides`, que mescla
  o ajuste do Arquetipo sobre uma **copia** do perfil do nivel (o dado
  compartilhado de dificuldade fica intacto, coberto por teste).
- `src/domain/special_meter.gd`: `drain()`, por adicao, para a barra ceder
  unidades ao roubo.
- `src/application/services/arcade-service.gd`: as 7 Pelejas em ordem **fixa que
  chega como dado** do chamador (ADR 0007), escada de dificuldade como dado e o
  Guardiao recebido por parametro/comando (`select_guardian`) -- sem depender do
  `character-select-service` (ticket 5); a comunicacao e por dado.
- `src/application/services/match-service.gd`: aplica o golpe-assinatura da IA,
  resolve o roubo de barra no contato e expoe perfil, slug e golpe proprio no
  `snapshot()` (mudancas aditivas e localizadas).
- Testes novos: `test/domain/test_opponent_profile.gd` (13),
  `test/domain/test_meter_steal.gd` (7), `test/application/test_arcade_service.gd`
  (10) e `test/infrastructure/test_opponent_spritesheets.gd` (9) -- 39 testes.
- `tools/capture_opponents.gd` + `.tscn` e o alvo `make capture-opponents`:
  ferramenta de evidencia que desenha os 7 pelo renderer de producao.

**Evidencia de fechamento**

- `make verify` sai com codigo **0**: gdlint `Success: no problems found`; GUT
  headless `278/278` testes e `170221` asserts com `-gexit` (eram 239 testes no
  ticket 4: esta fatia acrescenta 39); export web gerou `index.html`, `index.js`,
  `index.pck` e `index.wasm` (`39514754` bytes, a variante single-threaded).
- `make capture-opponents` sai com codigo 0 e grava 7 prints 426x240 em
  `docs/evidence/ticket-06-<slug>.png`, um por Oponente, cada um com o corpo
  parado, o passo, a guarda, o golpe pesado, o **golpe proprio** e o nocaute
  desenhados em escala inteira 3x.
- Ordem fixa verificada contra o dado: o teste compara a sequencia enfrentada com
  `ArcadeOrder`/`Archetype.slugs()` posicao a posicao, prova que a ordem injetada
  pelo chamador e obedecida (e recusa ordem incompleta ou com repeticao) e que a
  dificuldade nao desce e a vida do Oponente cresce ao longo das 7 Pelejas.
- Roubo de barra no dominio com teste: os dois Arquetipos da cobranca tiram a
  barra no contato (25 e 20 unidades), o roubo so leva o que existia, nunca
  inverte a barra, passa o valor para quem cobrou e adia o Especial do Guardiao;
  os outros cinco nao roubam nada.
- Politica do ADR 0004 revisada no dado, com teste: nenhum nome de Arquetipo ou de
  golpe cita pessoa real, simbolo real ou religiao (lista de termos proibidos), e
  toda arte segue a mesma regra.

**Dividas assumidas nesta fatia**

- O `arcade-service` esta completo no dominio/aplicacao, mas a navegacao
  titulo -> arcade -> Reviravolta e o HUD do arcade entram nos tickets 7 e 10.
- O `character-select-service` (ticket 5) entrega a escolha como dado; aqui ela
  entra por `execute(order, guardian_name)`/`select_guardian` -- a ligacao das
  cenas fica no polimento.
- A arte dos Oponentes e autoral e determinIstica (ticket 4/ADR 0005); o Golpe
  Especial deles continua usando a moldura comum (`Move.special`), com o efeito
  proprio do Guardiao no `SpecialMoveTable`.
- `src/domain/archetype.gd` e `src/domain/special_move_table.gd` NAO foram
  tocados nesta fatia: os dados dos Oponentes vivem nos arquivos novos
  (`opponent_profile.gd`, `meter_steal_move.gd`), o que evita conflito com os
  tickets 5 e 8, que rodam em paralelo e tambem escrevem nesses arquivos.

## Ticket 8 — Audio: SFX e chiptune

**Estado:** fechado.

**Entregue**

- `tools/audio/build_chiptune.py` (fronteira de autoria, fora das camadas do
  jogo): sintetiza TODO o audio do projeto com so a stdlib do Python --
  osciladores quadrado/triangular/serra, ruido por LFSR e um sequenciador
  chiptune em grade de notas. Deterministico (`--verify` confere byte a byte) e
  sem dependencia externa. `make audio` regera; `make test-audio` confere.
- `assets/audio/sfx/` (8 WAV, 22050 Hz mono): `impact_light`, `impact_heavy`,
  `special`, `damage`, `knockout`, `select`, `navigate`, `round_end`.
- `assets/audio/music/` (5 WAV, 11025 Hz mono, com loop no playback): `title`,
  `select`, `fight`, `reviravolta`, `result`.
- `assets/audio/CREDITS.md`: origem (sintetizado no projeto pelo gerador, nenhuma
  amostra, nenhum banco de sons, nada baixado da internet) e licenca (obra do
  proprio repositorio, sem obrigacao de atribuicao a terceiros).
- `src/application/gateways/audio-gateway.gd` (extensao por adicao): capacidades
  fechadas em ingles -- `SFX_KINDS` e `MUSIC_CONTEXTS` -- e o gesto do jogador
  (`notify_user_gesture`, `is_audio_unlocked`), que e como o jogo trata a
  politica de autoplay do navegador.
- `src/infrastructure/godot-audio-gateway.gd`: adapter de producao. Um
  `AudioStreamPlayer` para a musica (com loop calculado do WAV), 4 vozes de SFX,
  volume mudo no barramento `Master` do `AudioServer`, capacidade desconhecida
  ignorada e nenhum som antes do gesto (a trilha fica guardada e toca no gesto).
- `src/infrastructure/local-persistence-gateway.gd`: adapter de producao. JSON em
  `user://peleja/preferences.json` (no web, o armazenamento do navegador);
  arquivo ausente ou com payload estranho nao derruba o jogo.
- `src/application/services/options-service.gd`: caso de uso das opcoes de audio.
  Cada mudanca de volume/mudo e aplicada no audio E gravada na mesma chamada, em
  10 passos de volume; os efeitos de menu do contrato (`navigate` ao mexer no
  volume, `select` ao alternar o mudo e ao confirmar) saem daqui.
- `src/interface-adapters/options-view-adapter.gd`: copy pt-BR na borda de
  apresentacao (`OPÇÕES`, `VOLUME`, `SOM`, `LIGADO`/`MUDO`, dica de teclas) e o
  modelo que a cena desenha.
- `src/interface-adapters/pixel-font.gd`: fonte bitmap 5x7 extraida da tela de
  titulo e compartilhada (ganhou `Õ`, `%` e `:`), com `supports()` para o teste
  garantir que a copy tem glifo.
- `scenes/options_screen.tscn` + `.gd`: tela fina em 426x240, escala inteira,
  filtro nearest. `MOVE_LEFT`/`A` abaixa o volume, `MOVE_RIGHT`/`D` sobe,
  `CONFIRM`/`Enter` alterna o mudo, `CANCEL`/`Esc` volta; ela pede a trilha de
  menu e declara o gesto do jogador.
- `scenes/title_screen.gd`: passou a usar a `PixelFont` compartilhada, pede a
  trilha de titulo e abre a tela de opcoes no `Esc` (o menu completo e do ticket
  10); o primeiro comando do jogador e o gesto que destrava o audio.
- `autoloads/app_container.gd`: no modo `live`, monta o adapter de audio no
  proprio autoload -- a trilha atravessa a troca de cenas. O modo `sample`
  continua sem montar nada (o adapter silencioso nao toca nada).
- `src/application/services/match-service.gd`: efeitos do contrato a partir da
  Peleja -- impacto leve/pesado pelo golpe que conectou, `damage` quando o
  Guardiao apanha, `knockout` no nocaute e `special` ao armar o Golpe Especial.
  O fim da Peleja troca o contexto musical: vitoria do Oponente ->
  `reviravolta` (a Reviravolta entra em cena), vitoria do Guardiao -> `result`
  (`final_music_context()`).
- `tools/capture_options.gd` + `.tscn` e o alvo `make capture-options`:
  ferramenta de evidencia que mexe no volume e no mudo pelo caso de uso real e
  grava print 426x240.
- `docs/audio.md`: capacidades, camadas, preferencias, autoplay e evidencia.
- Testes: `test/application/test_match_audio.gd`,
  `test/application/test_options_service.gd`,
  `test/infrastructure/test_godot_audio_gateway.gd`,
  `test/infrastructure/test_local_persistence_gateway.gd`,
  `test/interface_adapters/test_options_view_adapter.gd`,
  `test/smoke/test_options_screen.gd`, um caso novo em
  `test/smoke/test_sample_adapters.gd` (contrato + gesto no adapter silencioso) e
  os ajustes de `test/smoke/test_app_container.gd` (audio e persistencia agora
  tem adapter de producao e caem para `sample` se e somente se o arquivo nao
  existir).

**Evidencia de fechamento**

- `make verify` sai com codigo 0: gdlint `Success: no problems found`; GUT
  headless `291/291` testes e `23656` asserts com `-gexit` (eram 239 testes e
  23132 asserts no ticket 4: esta fatia acrescenta 52 testes); export web gerou
  `index.html`, `index.js`, `index.pck` (`482256` bytes) e `index.wasm`
  (`39514754` bytes, a variante single-threaded de sempre).
- `python3 tools/audio/build_chiptune.py --verify` -> `13 artefatos conferem byte
  a byte com o gerador` (8 SFX + 5 trilhas, ~1,0 MB em `assets/audio/`).
- Adapter sample silencioso usado nos testes sem I/O: GUT
  `test_sample_adapters.gd` -> `8/8 passed`, incluindo
  `test_sample_adapters_do_not_perform_io` (nenhum dos cinco adapters sample
  contem `FileAccess`, `DirAccess`, `AudioServer`, `HTTPRequest`, `res://` ou
  `user://`) e `test_sample_audio_gateway_covers_the_contract_and_the_player_gesture`.
- Volume e mudo persistidos (gravar, recarregar e ler de volta):
  `test_options_service.gd` -> `8/8 passed`
  (`test_preferences_survive_a_new_session` restaura 0.3 e mudo numa nova
  instancia do caso de uso) e `test_local_persistence_gateway.gd` -> `8/8 passed`
  (`test_values_survive_a_new_gateway_instance` faz o mesmo por uma nova
  instancia do adapter de producao, lendo o arquivo de verdade).
- Troca de contexto musical ao entrar na luta e na Reviravolta:
  `test_match_audio.gd` -> `6/6 passed`, com
  `test_entering_the_fight_switches_the_music_context` (contexto `fight` no
  inicio da Peleja) e
  `test_reviravolta_context_when_the_opponent_wins_the_match` (o Oponente vence e
  o contexto passa a `reviravolta`), mais
  `test_result_context_when_the_guardian_wins_the_match` (vitoria do Guardiao
  fecha em `result`).
- `make capture-options` sai com codigo 0 e grava dois prints 426x240 em
  `docs/evidence/`: `ticket-08-options-volume-70.png` (volume 70% e som LIGADO) e
  `ticket-08-options-muted.png` (som MUDO). O estado vem do `OptionsService`
  pelos gateways injetados pelo composition root, nao de valor fixo na cena.
- Direcao de dependencia preservada: nenhum caso de uso instancia adapter
  concreto; o pool de players e o barramento `Master` vivem no adapter de
  producao; `src/domain/` continua sem tocar em audio, arquivo ou engine.

**Dividas assumidas nesta fatia**

- O menu de opcoes entra no escopo pelo `Esc` da tela de titulo; o menu completo
  (com remap de controles e navegacao entre telas) fica no ticket 10.
- A tela de Reviravolta do ticket 7 nao existe nesta onda: o contexto musical
  `reviravolta` ja e escolhido e testado no fim da Peleja vencida pelo Oponente,
  e a cena do ticket 7 so precisa pedir a trilha ao entrar (o gateway ja a tem em
  loop).
- Os WAV sao commitados como artefato (o gerador documenta como foram feitos);
  nenhuma dependencia externa de audio foi adicionada.

## Ticket 7 — Vantagem Oculta e Reviravolta sobrenatural

**Estado:** fechado.

**Entregue**

- `src/domain/reviravolta_rule.gd`: a regra da Reviravolta como dado puro -- dispara
  se e somente se o Oponente vence a Peleja, nunca com o Guardiao vencedor (nem em
  empate ou Peleja em andamento); fases `voice`/`wind`/`root`/`dissolve`/`done` em
  ticks (60 por linha, 90 de efeito), cena pulavel e a garantia de que a derrota
  nunca encerra a campanha. A copy pt-BR nao mora no dominio.
- `src/application/services/reviravolta-service.gd`: caso de uso da cena. Painel de
  tela cheia pelo slug `reviravolta-panel` no asset-gateway com fallback (sem arte
  o jogo nao quebra: painel neutro 426x240 em dado puro), trilha `reviravolta` e um
  cue do contrato por fase (vento, raiz, dissolucao), efeitos deterministas no
  render-gateway, opcao de pular e o progresso do arcade gravado no
  persistence-gateway (`{"fight", "campaign_over": false, "reviravolta": true}`).
- `src/interface-adapters/panel-adapter.gd`: copy pt-BR da Forca Sobrenatural
  (`REVIRAVOLTA`, `FORÇA SOBRENATURAL`, quatro falas e `ESPAÇO PULA A CENA`) com
  posicionamento na resolucao base 426x240 e faixa escura para o texto.
- `scenes/reviravolta_panel.tscn` + `.gd`: cena fina 426x240 (filtro nearest) que
  delega ao servico, desenha painel + efeitos + copy e drena o comando de pular do
  input-gateway injetado (nenhum teclado sintetico).
- `src/interface-adapters/hud-adapter.gd`: `fight_model` monta o HUD de uma Peleja a
  partir do retrato do `match-service` -- vida so como PROPORCAO de barra (`"bar"`),
  nomes, pips de round, relogio e status dos Especiais em pt-BR -- e
  `discloses_hidden_advantage()` passou a ser recursivo (invariante da Vantagem
  Oculta em qualquer nivel do modelo).
- `src/application/services/arcade-service.gd`: `requires_reviravolta()` (a partir da
  regra do dominio) sem mudar a progressao: `advance()` segue valendo e a campanha
  nunca acaba por derrota.
- `src/interface-adapters/bitmap-font.gd`: glifo `:` (relogio do HUD) e altura da
  imagem acompanhando o glifo mais alto do texto -- `make_image` estourava ao
  desenhar `Ç`/`Õ`, o que quebrava a copy acentuada.
- `tools/capture_reviravolta.gd` + `.tscn` e o alvo `make capture-reviravolta`:
  perde a primeira Peleja do arcade pela API publica do dominio, imprime os numeros
  da Vantagem Oculta e grava um print por fase, mais o pulo e o fim sem interacao.
- `docs/balance.md`: os dois numeros da calibragem (vida x1.6 e dano x1.4), a tabela
  de margens contra os 7 Oponentes medida na captura e como recalibrar.
- Testes novos (42): `test/domain/test_reviravolta_rule.gd` (10),
  `test/application/test_reviravolta_service.gd` (10),
  `test/application/test_reviravolta_campaign.gd` (4),
  `test/interface_adapters/test_panel_adapter.gd` (8),
  `test/smoke/test_reviravolta_panel_screen.gd` (6) e 4 casos novos em
  `test/interface_adapters/test_hud_adapter.gd`, mais `reviravolta_rule.gd` na lista
  de arquivos esperados do `test/domain/test_domain_purity.gd`.

**Evidencia de fechamento**

- `make verify` sai com codigo 0: gdlint `Success: no problems found`; GUT headless
  `430/430` testes e `234157` asserts com `-gexit` (eram 388 testes e 233726 asserts
  em `474244c`: esta fatia acrescenta 42 testes); export web gerou `index.html`,
  `index.js`, `index.pck` (`859164` bytes) e `index.wasm` (`39514754` bytes, a
  variante single-threaded de sempre).
- `make capture-reviravolta` sai com codigo 0 e grava 6 prints 426x240 em
  `docs/evidence/ticket-07-reviravolta-{voice,wind,root,dissolve,skipped,end}.png`.
  Saida real da ferramenta: `cena: ativa=true painel=gateway pixels=408960
  arte_gerada=true` (a arte de tela cheia vem do asset-gateway pelo slug), as fases
  `voice` -> `wind` -> `root` -> `dissolve` -> `done` em `330` ticks,
  `dissolvido=true` sem nenhuma interacao, `pular: aceito=true ... pulada=true`,
  `progresso do arcade: { "fight": 1, "campaign_over": false, "reviravolta": true }`
  e `arcade segue: avancou=true peleja=2/7 completa=false`.
- Reviravolta sempre dispara com o Oponente vencedor e nunca com o Guardiao vencedor:
  provado no dominio (todos os quatro `MatchRules.Winner`), no caso de uso e na cena
  (`panel_started()` falso com o Guardiao vencendo, sem tocar a trilha dela).
- Perder a Peleja nao e game over de campanha: `requires_reviravolta()` verdadeiro na
  Peleja perdida, `advance()` montando a Peleja 2, e o arcade correndo as 7 Pelejas
  mesmo com a primeira perdida.
- HUD nao expoe a Vantagem Oculta: o teste monta uma Peleja de verdade, confirma que
  o Guardiao tem mais vida (`1600 > 620`) e mais dano (`1.750 > 0.720`) e prova que
  nenhuma chave proibida aparece em nivel nenhum do modelo.
- Numeros da calibragem medidos na captura (`vantagem oculta: Guardiao vida=1600
  dano=1.750`): Oponentes de `620/0.720` (Capataz) a `890/0.900` (Falso Pastor), com
  margem de vida de `+980` a `+710` e de dano de `+1.030` a `+0.850`; no fim do
  arcade o Guardiao ainda tem `1.80x` a vida e `1.94x` o dano do Oponente.

**Dividas assumidas nesta fatia**

- A navegacao titulo -> arcade -> Reviravolta -> proxima Peleja ainda nao esta ligada
  nas cenas: a cena da Reviravolta existe, roda com o vencedor real e prova a
  continuacao da campanha, mas quem encadeia as telas e o polimento (ticket 10).
- O Oponente dissolvido na cena e uma silhueta desenhada em codigo (retangulos) sobre
  a arte de painel; nao ha spritesheet codificado dele, e o painel da Reviravolta e
  arte gerada (ticket 9) com fallback em codigo, sem variacao por Arquetipo.
- O comando de pular da cena usa a moldura ja existente do HUD (`MOVE_*`, `CONFIRM`,
  `CANCEL`, `JUMP` no input-gateway); o remap de controles fica no ticket 10.
