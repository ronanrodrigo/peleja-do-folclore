# Modelo arquitetural (Fase 4 — skillfold)

Modelo produzido por subagente skillfold isolado antes da execução, anexado aos 10 tickets.

## Resumo

Modelo arquitetural da Fase 4 (skillfold) para 'Peleja do Folclore', adaptado de Clean Architecture/TypeScript para Godot 4.7.2 + GDScript. A estrutura de camadas de docs/architecture.md e AGENTS.md é preservada integralmente e apenas traduzida para a linguagem de um projeto Godot: scenes/ + autoloads/ são a camada app (composition root), src/interface-adapters/ traduz input e liga estado a nós de UI, src/application/gateways/ declara uma capacidade por arquivo, src/application/services/ orquestra casos de uso com execute(...), src/domain/ contém regras puras de combate sem Node/SceneTree/Input/IO, e src/infrastructure/ implementa os gateways (godot-*) com uma pasta sample/ determinística em memória. A direção de dependência é para dentro: scenes/autoloads -> interface-adapters -> application -> domain, com infrastructure apontando para application (implementando seus gateways). Como Godot não tem injeção de dependência nativa, o composition root é materializado em autoloads/ (app_container.gd), único lugar que instancia adapters concretos; estado de jogo vive nos serviços, nunca em singletons autoload. Cada um dos 10 tickets é modelado como uma fatia vertical que toca o menor conjunto de camadas que entrega o Acceptance criteria, cria arquivos em nome inglês, usa os gateways existentes (input/render/asset/audio/persistence) e exige testes GUT headless (-gexit) mais o gate make verify = gdlint + test + export. Invariantes verificáveis e riscos arquiteturais cobrem pureza do domínio, determinismo por semente injetada, escala inteira/nearest em 426x240, export web single-threaded, política de oponentes (ADR 0004), fallback de arte quando o ComfyUI está fora do ar (ADR 0005) e o gate de evidência (ADR 0006). Nada foi implementado, nenhum arquivo foi criado no repositório e nenhum PR foi aberto; a entrega é exclusivamente este modelo em texto, pronto para ser anexado aos 10 tickets.

## Camadas

Estrutura de camadas (espelha src/ de skillfold; nomes de pasta já fixados por architecture.md/AGENTS.md):

1) src/domain/ — regras puras de combate. Herda apenas RefCounted/Resource e tipos puros de GDScript; proibido Node, SceneTree, Input, FileAccess, DirAccess, OS, AudioServer, HTTPRequest, Timer e qualquer nó de cena. Arquivos previstos: fighter_state.gd (enum de estados: idle, walk, crouch, attack, block, hurt, ko), bounding_box.gd (hitbox/hurtbox como retângulos puros), move.gd (leve/pesado/agarrão: alcance, dano, quadro de início/recuperação), fighter.gd (vida, dano, barra de especial, posição), health.gd, special_meter.gd (enche batendo e apanhando; especial consome a barra inteira), round_clock.gd (relógio por delta em ticks, sem Timer), match_rules.gd (melhor de três, vitória por vida zerada ou por tempo), guardian_stats.gd + opponent_stats.gd + hidden_advantage.gd (Vantagem Oculta), rng.gd (semente injetada), opponent_ai.gd (política pura de decisão por dificuldade, recebe estado + rng), special_move.gd + special_move_table.gd (Redemoinho, Pés Invertidos, Canto do Rio, Nana Neném e efeitos de status: invert_controls, drain, sleep, meter_steal), spritesheet.gd (modelo de dados paleta + matrizes de pixel, validação pura), archetype.gd (enum dos 7 arquétipos), arcade_order.gd (ordem fixa como dado).

2) src/application/gateways/ — contratos de capacidade, um por arquivo: input-gateway.gd, render-gateway.gd, audio-gateway.gd, asset-gateway.gd, persistence-gateway.gd. Nomes de capacidade em inglês, nunca de tecnologia/provedor.

3) src/application/services/ — caso de uso por arquivo, entrada execute(...): match-service.gd (uma Peleja), arcade-service.gd (as 7 Pelejas, ordem fixa, progressão), reviravolta-service.gd (cena final quando o Oponente vence), character-select-service.gd (seleção dos 4 Guardiões), options-service.gd (volume/mudo/remap).

4) src/interface-adapters/ — keyboard-input-adapter.gd, touch-input-adapter.gd (ambos implementando input-gateway), hud-adapter.gd (liga estado de jogo a nós de UI sem revelar a Vantagem Oculta), panel-adapter.gd (painéis de Reviravolta/finais), sprite-render-adapter.gd (desenha spritesheet decodificado em escala inteira 3x, filtro nearest, letterbox).

5) src/infrastructure/ — godot-asset-gateway.gd (carrega spritesheet JSON, paletas, arte gerada por slug), godot-audio-gateway.gd, local-persistence-gateway.gd; sample/ com sample-input-gateway.gd, sample-render-gateway.gd, silent-audio-gateway.gd, in-memory-asset-gateway.gd, in-memory-persistence-gateway.gd (determinísticos, zero I/O). Cada arquivo implementa uma capacidade.

6) scenes/ (camada app; finas, só montam nós, conectam sinais e delegam a serviços): title_screen.tscn, character_select.tscn, fight.tscn, reviravolta_panel.tscn, victory_screen.tscn, defeat_screen.tscn, arcade_end_screen.tscn, options_screen.tscn. Scripts .gd correspondentes contêm apenas bootstrap/wiring local.

7) autoloads/ — composition root: app_container.gd (instancia adapters concretos conforme configuração/ambiente, injeta nos serviços; suporta modo sample). Não guarda estado de jogo.

8) assets/ — spritesheets/<slug>.json, palettes/, generated/<tipo>/<slug>.png + .json de metadados, audio/, CREDITS.md. 9) test/ — espelha src/ e scenes/, colado ao comportamento. 10) tools/comfy/ — fronteira de ferramentaria (workflows API, scripts de geração/pós-processamento), fora das camadas do jogo. 11) docs/ — architecture.md, adr/, plans/, implementation-progress.md.

## Gateways e adapters

Cinco capacidades, uma por arquivo em src/application/gateways/, cada uma com adapter de produção em src/infrastructure/ e adapter determinístico em src/infrastructure/sample/:

1) input-gateway — capacidade 'ler intenções do jogador'. Contrato: poll()/dequeue de comandos abstratos (mover, agachar, leve, pesado, agarrão, especial, pular cena, confirmar, voltar). Produção: keyboard-input-adapter.gd (WASD/setas + 3 botões) e touch-input-adapter.gd (botões na tela). Sample: sample-input-gateway.gd (fila de comandos programada pelo teste).

2) render-gateway — capacidade 'desenhar um frame'. Contrato: draw_spritesheet(decoded_sheet, anim, frame, position, scale_int, flip), draw_panel(art_or_fallback), clear(); nunca aceita escala fracionária. Produção: implementado pelo sprite-render-adapter.gd sobre CanvasItem/Texture (o adapter vive em interface-adapters por ser tradução de saída para nós/Canvas). Sample: sample-render-gateway.gd (registra chamadas em memória, sem desenhar).

3) asset-gateway — capacidade 'obter arte e dados por slug'. Contrato: load_spritesheet(slug) -> Spritesheet, load_palette(id), load_panel(slug, fallback), exists(slug). Produção: godot-asset-gateway.gd lê spritesheets codificados em JSON e arte gerada por slug; se o arquivo não existe (ComfyUI fora do ar), devolve o fallback em código. Sample: in-memory-asset-gateway.gd com sheets/painéis pré-carregados.

4) audio-gateway — capacidade 'tocar som e música'. Contrato: play_sfx(kind), play_music(context), set_master_volume(v), set_mute(b). Produção: godot-audio-gateway.gd. Sample: silent-audio-gateway.gd (no-op silencioso, sem I/O, usado em todos os testes).

5) persistence-gateway — capacidade 'guardar e restaurar preferências/progresso'. Contrato: save(key, value)/load(key)/has(key) para volume, mudo, remap de controles e progresso do arcade. Produção: local-persistence-gateway.gd (User:// / localStorage no web). Sample: in-memory-persistence-gateway.gd (dicionário em memória).

Regra de fronteira: nenhum serviço da application importa godot-asset-gateway/godot-audio-gateway/local-persistence-gateway diretamente; recebem os contratos por injeção. Somente autoloads/app_container.gd instancia os adapters concretos. Adaptadores sample nunca fazem I/O.

## Modelo por ticket

TICKET 1 — Esqueleto jogável e deploy.
Camadas afetadas: scenes/ (título), autoloads/ (composition root bootstrap), infrastructure/ sample, CI/deploy (fora das camadas). Domínio ainda não existe.
Arquivos novos: project.godot; export_presets.cfg (preset 'Web', single-threaded, 426x240, nearest); scenes/title_screen.tscn + title_screen.gd; autoloads/app_container.gd; src/application/gateways/{input,render,asset,audio,persistence}-gateway.gd (contratos vazios mínimos); src/infrastructure/sample/* (5 adapters determinísticos); test/smoke/title_screen_test.gd; .github/workflows/ci.yml (barichello/godot-ci:4.7, make verify); vercel.json. Makefile/AGENTS.md/architecture.md já existem.
Gateways usados: input-gateway, render-gateway, asset-gateway (sample na fatia inicial); audio e persistence só declarados.
Testes exigidos: GUT headless smoke (bootstrap do composition root sem erro; adapters sample sem I/O); CI executando make verify end-to-end.
Risco: export templates 4.7 ausentes na máquina/CI (export falha) e export web com threads exigindo COOP/COEP que o Vercel não serve. Mitigar: fixar preset single-threaded e pré-checar templates.

TICKET 2 — Núcleo de combate no domínio.
Camadas afetadas: domain/ (única camada tocada) + test/.
Arquivos novos: src/domain/{fighter_state,bounding_box,move,fighter,health,special_meter,round_clock,match_rules,guardian_stats,opponent_stats,hidden_advantage,rng}.gd; test/domain/* espelhando cada arquivo.
Gateways usados: nenhum (regras puras); rng.gd é dependência injetada, não gateway.
Testes exigidos: dano por golpe (leve/pesado/agarrão); morte por vida zerada; vitória por tempo esgotado; barra de especial enchendo e consumida; melhor de três (2-0, 2-1, empate de rounds); Vantagem Oculta (Guardião com mais vida e mais dano); reprodutibilidade (mesma semente + mesmos comandos -> mesmo resultado). Verificação de que o domínio não importa Node/SceneTree/Input/IO.
Risco: vazamento de engine no domínio destruindo a testagem headless; aleatoriedade espalhada quebrando determinismo. Mitigar: só RefCounted, RNG injetado único, regra de lint/grep no CI.

TICKET 3 — Lutador jogável e IA.
Camadas afetadas: domain/ (política de IA), application/services (match-service) e gateways/input-gateway, interface-adapters/, infrastructure/sample, scenes/fight.tscn.
Arquivos novos: src/domain/opponent_ai.gd (política pura parametrizada por 3 níveis); src/application/services/match-service.gd; src/application/gateways/input-gateway.gd; src/interface-adapters/{keyboard-input-adapter,touch-input-adapter}.gd; src/infrastructure/sample/sample-input-gateway.gd; scenes/fight.tscn + fight.gd; test/application/match_service_test.gd; test/domain/opponent_ai_test.gd.
Gateways usados: input-gateway, render-gateway (sample), asset-gateway (sample), audio-gateway (silent).
Testes exigidos: match-service orquestrando uma Peleja com adapters sample; leve/pesado/agarrão com alcance/dano/recuperação distintos; defesa reduz dano e agachar muda a hurtbox; IA ataca/defende/recua/usa especial com 3 níveis; IA determinística por semente. Evidência: print/vídeo curto.
Risco: estado global escondido e lógica de engine vazando para o serviço/cena. Mitigar: cena fina (só monta/sinais/delega), estado nos serviços, sem singletons de estado.

TICKET 4 — Spritesheet codificado e Saci.
Camadas afetadas: domain/ (modelo e validação do formato), infrastructure/ (asset-gateway), interface-adapters/ (renderer), assets/, docs/.
Arquivos novos: src/domain/spritesheet.gd (paleta + matrizes, validação); src/application/gateways/render-gateway.gd; src/interface-adapters/sprite-render-adapter.gd; src/infrastructure/godot-asset-gateway.gd (JSON); src/infrastructure/sample/in-memory-asset-gateway.gd; assets/spritesheets/saci.json; docs/spritesheet-format.md; test/domain/spritesheet_test.gd; test/interface_adapters/sprite_render_scale_test.gd.
Gateways usados: asset-gateway, render-gateway.
Testes exigidos: validação de formato (paleta, dimensões, frames por animação); escala inteira 3x e nearest (rejeitar fator fracionário); especial Redemoinho consome a barra inteira e só dispara com barra cheia; ausência de sprite binário opaco.
Risco: formato rígido/impreciso que trave os 10 lutadores seguintes; escala fracionária destruindo o grid de pixel. Mitigar: fixar e documentar o formato neste ticket, validar por teste antes de reusar, render-gateway só aceitar inteiro.

TICKET 5 — Elenco folclórico completo.
Camadas afetadas: domain/ (efeitos especiais e status), application/services (character-select), interface-adapters/, scenes/, assets/.
Arquivos novos: src/domain/special_move.gd + special_move_table.gd (Pés Invertidos: invert_controls 3s; Canto do Rio: sleep + drain; Nana Neném: sleep + jacaré); src/application/services/character-select-service.gd; src/application/gateways/input-gateway.gd (confirmação de seleção); src/interface-adapters/hud-adapter.gd (retratos/nome/nome do especial); scenes/character_select.tscn + .gd; assets/spritesheets/{curupira,iara,cuca}.json; test/domain/special_moves_test.gd; test/application/character_select_service_test.gd.
Gateways usados: asset-gateway, render-gateway, input-gateway, audio-gateway.
Testes exigidos: cada especial com teste próprio (inversão de comandos, drenagem de vida, sono); retratos/nomes vindos do asset-gateway; seleção alimenta o arcade-service como comando, sem estado global escondido.
Risco: status effects acoplando-se a estado de UI; especiais alterando o domínio do ticket 2 de forma incompatível. Mitigar: efeitos como dados/estado puro no domínio; alterar só por adição de campos, nunca mudando contratos existentes.

TICKET 6 — Os 7 arquétipos do poder.
Camadas afetadas: domain/ (perfis de oponente, ataques que roubam barra, variações de IA), application/services (arcade-service), assets/, test/.
Arquivos novos: src/domain/archetype.gd (enum), src/domain/opponent_profile.gd, src/domain/meter_steal_move.gd (Banqueiro/Falso Pastor), assets/spritesheets/{capataz,banqueiro,redpill,camisa-verde,doutor-pureza,fantasma-do-reich,falso-pastor}.json; src/application/services/arcade-service.gd; test/domain/arcade_order_test.gd; test/domain/meter_steal_test.gd.
Gateways usados: asset-gateway, render-gateway, input-gateway (player), audio-gateway.
Testes exigidos: sequência fixa de 7 verificada contra arcade_order.gd (dado, não código escondido); golpes que roubam a Barra de Especial (domínio); IA distinta por oponente; revisão de política (nenhum símbolo real/nome de pessoa real/referência religiosa — checagem explícita no PR).
Risco: deriva para ataque a identidade real/símbolos; ordem fixa virando código espalhado. Mitigar: ADR 0004 como constraint checado; ordem como dado injetado no arcade-service (ADR 0007).

TICKET 7 — Vantagem Oculta e Reviravolta sobrenatural.
Camadas afetadas: domain/ (regra da Reviravolta e calibragem), application/services (reviravolta-service), interface-adapters/panel + hud, scenes/, docs/.
Arquivos novos: src/domain/reviravolta_rule.gd (dispara se e somente se o Oponente vence a Peleja); src/domain/hidden_advantage.gd (calibragem vida/dano); src/application/services/reviravolta-service.gd; src/interface-adapters/panel-adapter.gd; scenes/reviravolta_panel.tscn + .gd; assets/panels/reviravolta.json (fallback); test/domain/reviravolta_test.gd; test/application/reviravolta_service_test.gd; docs/balance.md (números usados).
Gateways usados: asset-gateway (painel por slug + fallback), render-gateway, audio-gateway, persistence-gateway (progresso do arcade mantido).
Testes exigidos: Reviravolta sempre dispara quando o Oponente vence; nunca quando o Guardião vence; arcade continua na próxima Peleja após a Reviravolta (sem game over de campanha); HUD não expõe a Vantagem Oculta.
Risco: HUD vazar a Vantagem Oculta; Reviravolta bloquear a progressão. Mitigar: teste de invariante no hud-adapter e regra de domínio explícita e testada.

TICKET 8 — Áudio: SFX e chiptune.
Camadas afetadas: application/gateways (audio-gateway), infrastructure/, application/services (options), interface-adapters/, scenes/options, assets/audio/.
Arquivos novos: src/application/gateways/audio-gateway.gd; src/application/gateways/persistence-gateway.gd (volume/mudo); src/infrastructure/godot-audio-gateway.gd; src/infrastructure/sample/silent-audio-gateway.gd; src/infrastructure/local-persistence-gateway.gd; src/application/services/options-service.gd; src/interface-adapters/hud-adapter.gd (bind opcional); scenes/options_screen.tscn + .gd; assets/audio/*; assets/audio/CREDITS.md.
Gateways usados: audio-gateway, persistence-gateway.
Testes exigidos: audio-gateway com adapter sample silencioso usado nos testes (sem I/O); volume/mudo persistidos entre sessões via persistence sample; contexto musical trocado ao entrar na luta e na Reviravolta.
Risco: áudio de terceiros com licença incompatível; autoplay bloqueado no navegador. Mitigar: SFX/música sintetizados no projeto + CREDITS.md; exigir gesto do usuário antes de tocar no web.

TICKET 9 — Arte de cenários, painéis e retratos por ComfyUI.
Camadas afetadas: infrastructure/ (asset-gateway), tools/comfy/ (ferramentaria, fora das camadas do jogo), assets/generated/.
Arquivos novos: tools/comfy/workflows/pixelart_bg.json (formato API); tools/comfy/scripts/run_workflow.py (geração + pós-processamento: quantizar paleta, reduzir para 426x240, nunca ampliar com filtro suave); src/infrastructure/godot-asset-gateway.gd (extensão: carrega por slug e cai no fallback em código); assets/generated/<tipo>/<slug>.png + .json; assets/generated/CREDITS.md; test/infrastructure/asset_gateway_fallback_test.gd.
Gateways usados: asset-gateway (slug + fallback), render-gateway.
Testes exigidos: gateway carrega por slug e cai no fallback quando o arquivo não existe (adapter sample); CREDITS.md com modelo, licença e URL de origem.
Risco: ComfyUI fora do ar (porta 8188 recusando), hardware marginal (M4 16 GB) e licença de checkpoint incompatível. Mitigar: fallback em código obrigatório (o jogo nunca quebra), SD 1.5, licença registrada antes de integrar.

TICKET 10 — Polimento e lançamento.
Camadas afetadas: interface-adapters/ (hud, touch), scenes/ (vitória/derrota/fim de arcade/options), application/services (options remap), infrastructure/ (perf), deploy.
Arquivos novos: src/interface-adapters/hud-adapter.gd (completo: vida, barra, rounds, relógio, nomes — sem Vantagem Oculta); scenes/{victory_screen,defeat_screen,arcade_end_screen}.tscn + .gd; src/application/services/options-service.gd (remap de controles); src/infrastructure/local-persistence-gateway.gd (remap); test/interface_adapters/hud_adapter_test.gd; test/application/options_service_test.gd; docs/implementation-progress.md (entrada de fechamento).
Gateways usados: persistence-gateway, render-gateway, audio-gateway, input-gateway.
Testes exigidos: HUD não revela a Vantagem Oculta (invariante testado); telas de vitória/derrota/fim de arcade com retorno ao título; remap e volume persistidos; make verify verde; verificação de 60 fps no jogo publicado.
Risco: performance abaixo de 60 fps no mobile; regressão de invariantes já garantidos (domínio puro, escala inteira). Mitigar: orçamento de draw calls/atlas, sem shaders pesados, e make verify como gate final obrigatório.

## Invariantes

- O domínio (src/domain/) nunca importa Node, SceneTree, Input, FileAccess, DirAccess, OS, AudioServer, HTTPRequest, Timer nem qualquer módulo de I/O ou de cena — verificável por lint (gdlint) e grep no CI.
- Direção de dependência é sempre para dentro: scenes/autoloads -> interface-adapters -> application -> domain; infrastructure implementa gateways da application. Nenhum import atravessa de camada interna para externa.
- Toda aleatoriedade do domínio passa por um único RNG injetado (semente); mesma semente somada à mesma sequência de comandos produz sempre o mesmo resultado — verificado por teste de reprodutibilidade.
- Cada capacidade externa tem exatamente um gateway em src/application/gateways/<capability>-gateway.gd, nomeado por capacidade em inglês, nunca por tecnologia, provedor, SDK ou protocolo.
- Adapters concretos e configuração são instanciados apenas no composition root (autoloads/app_container.gd); nenhum serviço de application/domain instancia godot-asset-gateway, godot-audio-gateway ou local-persistence-gateway diretamente.
- Adapters em src/infrastructure/sample/ são determinísticos e não fazem I/O (sem FileAccess, AudioServer, HTTPRequest, rede); são os únicos usados nos testes de domínio e aplicação.
- O modo sample é selecionado por configuração/ambiente explícito, nunca por checagem de provedor dentro dos casos de uso.
- A Vantagem Oculta é sempre verdadeira: o Guardião tem mais vida e mais dano que o Oponente; a HUD nunca exibe esses números.
- A Reviravolta dispara se e somente se o Oponente vence a Peleja; nunca dispara quando o Guardião vence; nunca gera game over de campanha — o arcade continua na próxima Peleja.
- O Oponente nunca é escolhido pelo jogador; o arcade-service decide a ordem fixa de 7 Pelejas (uma por Arquétipo, dificuldade crescente) a partir de dado injetado.
- O Golpe Especial consome a Barra de Especial inteira e só dispara com a barra cheia.
- A renderização usa exclusivamente escala inteira (múltiplo de 3x), texture_filter nearest, sem suavização; escala fracionária é rejeitada pela render-gateway.
- A resolução base é 426x240, preservada com letterbox em qualquer tamanho de janela.
- Sprites de lutadores e oponentes são dados JSON versionados (paleta + matrizes de pixel); nenhum PNG binário opaco de lutador é commitado.
- Nenhum arquétipo usa símbolo real de organização histórica/criminosa, nome de pessoa real ou referência a religião (política do ADR 0004, checada no PR).
- Nenhum arquivo de arte ou áudio de terceiros entra sem origem e licença compatível registradas em assets/generated/CREDITS.md ou assets/audio/CREDITS.md.
- O export web é sempre single-threaded (sem dependência de SharedArrayBuffer/COOP-COEP) e o deploy é estático em peleja.ronanrodrigo.dev.
- Código, nomes de arquivo, classes, sinais e chaves de configuração são em inglês; a copy do jogo é em pt-BR, resolvida apenas na borda de apresentação, nunca como estado de domínio.
- make verify (gdlint + GUT headless com -gexit + export) é o gate obrigatório de PR e deve sair com código 0; a CI fixa barichello/godot-ci na versão 4.7.
- Nenhum segredo é commitado; credenciais entram apenas por configuração de ambiente/secrets.
- Fechamento de ticket ou PR exige evidência executável (saída de teste, log de export, print do jogo), nunca 'pronto' declarado (regra de evidência do ADR 0006).

## Riscos e mitigação

- Vazamento de engine no domínio (Node, SceneTree, Input, Timer) quebra a testagem headless e a pureza das regras: mitigar aceitando apenas RefCounted/tipos puros em src/domain/, com regra de gdlint e passo de grep no CI que falha o PR.
- Determinismo frágil: aleatoriedade espalhada pelo código impede reprodutibilidade dos testes: mitigar com um único rng.gd injetado e teste de mesma-semente.
- Export templates da versão 4.7 ausentes na máquina local ou no CI fazem --export-release falhar: mitigar fixando a versão, pré-checando templates e documentando a instalação; CI usa a imagem barichello/godot-ci:4.7.
- Export web multi-thread exige SharedArrayBuffer e headers COOP/COEP que o Vercel não serve por padrão, quebrando o jogo publicado: mitigar fixando o preset Web em single-threaded no export_presets.cfg e testando o build.
- ComfyUI local fora do ar (porta 8188 recusando) ou hardware marginal (M4, 16 GB) travando a arte no ticket 9: mitigar com fallback de arte em código obrigatório no asset-gateway — o jogo nunca quebra por arte ausente.
- Arte gerada por IA com licença incompatível ou inconsistência visual entre assets: mitigar com pós-processamento obrigatório (quantizar, reduzir para 426x240, ampliar só em render) e CREDITS.md com modelo/licença/URL, revisado no PR.
- Formato de spritesheet codificado em JSON mal definido no ticket 4 trava todos os lutadores e oponentes seguintes: mitigar fixando o formato em docs/ e validando-o por teste antes de reusá-lo nos tickets 5 e 6.
- Escala fracionária ou filtro suave destruindo o grid de pixel: mitigar fazendo a render-gateway aceitar apenas fator inteiro e cobrir isso com teste unitário de escala.
- Acoplamento por singleton/autoload de estado do Godot cria dependência global escondida e quebra a direção de dependência: mitigar mantendo autoloads/ apenas como composition root (wiring) e o estado nos serviços, passando seleção e progresso como comandos.
- Sprites codificados como dados têm custo de autoria alto e risco de arte pobre em volume: mitigar definindo o formato cedo, reusando componentes (paleta/base de corpo) e tratando os tickets 4-6 como incrementos do mesmo formato, não reescritas.
- A calibragem da Vantagem Oculta (vida/dano) pode desbalancear a melhor de três e tornar o jogo trivial: mitigar separando os números em hidden_advantage.gd, expondo-os em docs/balance.md e cobrindo-os por teste.
- HUD ou código de apresentação vazando a Vantagem Oculta ou a escolha do Oponente: mitigar com teste de invariante no hud-adapter e regra de domínio explícita.
- Representação dos oponentes derivando para ataque a identidade real, símbolo histórico ou religião, com risco jurídico e de plataforma: mitigar tratando o ADR 0004 como constraint verificável e exigindo revisão explícita no PR de cada asset/fala.
- Performance abaixo de 60 fps no navegador (sobretudo mobile) por draw calls e shaders pesados: mitigar com atlas, orçamento de draw calls, ausência de shaders pesados e verificação no ticket 10 sobre o jogo publicado.
- GUT headless sem -gexit não termina e trava o CI: mitigar mantendo -gexit fixo no Makefile e no workflow, nunca removendo o flag.
- Dependências reais entre tickets (2<-1, 3<-2, 4<-3, 5<-4, 6<-4, 7<-6, 8<-4, 9<-1, 10<-7,8,9) quebradas por paralelização precoce: mitigar respeitando o 'Blocked by' de cada issue e tratando cada ticket como fatia vertical isolada (worktree + PR via gh), sem iniciar ticket bloqueado.
