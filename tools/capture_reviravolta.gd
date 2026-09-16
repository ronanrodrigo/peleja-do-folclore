extends Control
## Ferramenta de evidencia do ticket 7 (fora das camadas do jogo).
##
## Faz a Reviravolta acontecer de verdade e grava os prints em `docs/evidence/`,
## conforme a regra de evidencia do ADR 0006:
##
## 1. monta o arcade pelo composition root e PERDE a primeira Peleja pela API
##    publica do dominio (em vez de esperar a sorte da IA);
## 2. imprime os numeros da Vantagem Oculta que o balanceamento usa (vida e dano
##    do Guardiao contra cada um dos 7 Oponentes);
## 3. abre a cena de Reviravolta com o vencedor real daquela Peleja e um print por
##    fase: voz (a sequencia de texto), vento, raiz e dissolucao;
## 4. pula a cena (opcao de pular), abre de novo e deixa a segunda passagem
##    terminar SOZINHA, sem nenhuma interacao;
## 5. avanca o arcade e imprime que a campanha CONTINUA -- perder a Peleja nunca
##    e game over de campanha.
##
## A cena nao precisa de entrada para avancar o texto: ela rola sozinha. Nao ha
## teclado sintetico em lugar nenhum deste arquivo.
##
## Uso: godot --path . tools/capture_reviravolta.tscn -- <diretorio-de-saida>

const PANEL_SCENE := "res://scenes/reviravolta_panel.tscn"
const CONTAINER_PATH := "/root/app_container"
const DEFAULT_OUTPUT_DIR := "res://docs/evidence"
const FILE_PREFIX := "ticket-07-"
const GUARDIAN_SEED := 20260915
const OPPONENT_SEED := 7
const MAX_TICKS_PER_FIGHT := 600
const READY_FRAMES := 2
const CAPTURE_TICKS := 900
## Linha da voz que entra no print (a terceira fala, prova que a sequencia anda).
const VOICE_LINE := 2

var _output_dir := DEFAULT_OUTPUT_DIR


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		_output_dir = arguments[0]
	_apply_root_layout()
	var container: Variant = get_node_or_null(CONTAINER_PATH)
	if container == null:
		push_error("captura exige o composition root app_container")
		get_tree().quit(1)
		return
	var arcade := ArcadeService.new(
		container.input_gateway(),
		container.render_gateway(),
		container.asset_gateway(),
		container.audio_gateway()
	)
	_report_hidden_advantage()
	if not arcade.execute([], GuardianStats.SACI, GUARDIAN_SEED, OPPONENT_SEED):
		push_error("o arcade nao montou a primeira Peleja")
		get_tree().quit(1)
		return
	print("arcade: peleja 1 de %d contra %s" % [arcade.fight_count(), arcade.opponent_slug()])
	var ticks := _lose_current_fight(arcade)
	print(
		"peleja perdida em %d ticks: vencedor=%d rounds=%s"
		% [ticks, arcade.match_service.winner(), arcade.match_service.rules.results()]
	)
	print("requires_reviravolta=%s" % arcade.requires_reviravolta())
	var panel: Variant = await _open_panel(container, arcade, "primeira passagem")
	await _advance_to_line(panel, VOICE_LINE)
	await _save(panel, "reviravolta-voice")
	for phase in ["wind", "root", "dissolve"]:
		await _advance_to_phase(panel, phase)
		await _save(panel, "reviravolta-%s" % phase)
	print(await _skip(panel))
	var natural: Variant = await _open_panel(container, arcade, "segunda passagem (sem interacao)")
	await _advance_to_phase(natural, "done")
	await _save(natural, "reviravolta-end")
	print(
		"fim pelo tempo: ticks=%d dissolvido=%s terminada=%s pulada=%s"
		% [
			natural.snapshot()["ticks"],
			natural.snapshot()["opponent_dissolved"],
			natural.is_finished(),
			natural.snapshot()["skipped"],
		]
	)
	_report_campaign_continues(container, arcade)
	get_tree().quit(0)


## Numeros da Vantagem Oculta, direto do dominio: e a calibragem registrada em
## docs/balance.md.
func _report_hidden_advantage() -> void:
	var guardian := GuardianStats.advantaged(GuardianStats.SACI)
	print(
		"vantagem oculta: Guardiao vida=%d dano=%.3f"
		% [guardian.max_health, guardian.damage_multiplier]
	)
	for opponent in OpponentStats.arcade_roster():
		print(
			"  %-16s vida=%d dano=%.3f margem_vida=+%d margem_dano=+%.3f"
			% [
				opponent.display_name,
				opponent.max_health,
				opponent.damage_multiplier,
				HiddenAdvantage.health_margin(guardian, opponent),
				HiddenAdvantage.damage_margin(guardian, opponent),
			]
		)


## Fecha a Peleja com o Guardiao perdendo os rounds: zerar a vida dele no comeco
## de cada round e o caminho curto e nao depende da sorte da IA.
func _lose_current_fight(arcade: ArcadeService) -> int:
	var ticks := 0
	while not arcade.match_service.is_match_over() and ticks < MAX_TICKS_PER_FIGHT:
		var fight: MatchService = arcade.match_service
		if fight.phase == MatchService.Phase.ROUND_ACTIVE:
			fight.guardian.health.apply_damage(fight.guardian.health.max_value)
		arcade.advance_tick()
		ticks += 1
	return ticks


## Abre a cena da Reviravolta com o vencedor real da Peleja que acabou de ser
## perdida, sem rodar sozinha (os ticks sao dirigidos aqui).
func _open_panel(container: Variant, arcade: ArcadeService, stage: String) -> Variant:
	# Gesto do jogador: no web o audio so toca depois do primeiro clique.
	if container.audio_gateway().has_method("notify_user_gesture"):
		container.audio_gateway().notify_user_gesture()
	var panel: Variant = load(PANEL_SCENE).instantiate()
	panel.winner_result = arcade.match_service.winner()
	panel.fight_number = arcade.fight_number()
	panel.auto_run = false
	add_child(panel)
	for _frame in READY_FRAMES:
		await get_tree().process_frame
	panel.draw_frame()
	print(
		"cena (%s): ativa=%s painel=%s pixels=%d arte_gerada=%s fase=%s linha=%s"
		% [
			stage,
			panel.panel_started(),
			panel.snapshot()["panel_source"],
			panel.panel_pixels().size(),
			_generated_art(container),
			panel.snapshot()["phase"],
			panel.snapshot()["line_index"],
		]
	)
	return panel


## Verdadeiro quando o painel da Reviravolta veio mesmo da arte gerada (ticket 9)
## e nao do fallback em codigo.
func _generated_art(container: Variant) -> bool:
	var asset: Variant = container.asset_gateway()
	if asset == null or not asset.has_method("has_art"):
		return false
	return bool(asset.has_art(ReviravoltaService.PANEL_SLUG))


## Opcao de pular: a cena nunca prende quem ja entendeu. O gateway da vez no modo
## de producao e o teclado (nao aceita comando programado), entao o pulo e pedido
## direto a cena aqui; o caminho pelo input-gateway injetado esta coberto por
## test/smoke/test_reviravolta_panel_screen.gd.
func _skip(panel: Variant) -> String:
	var accepted: bool = panel.skip()
	var line: String = (
		"pular: aceito=%s terminada=%s fase=%s pulada=%s (o caminho pelo input-gateway"
		% [accepted, panel.is_finished(), panel.snapshot()["phase"], panel.snapshot()["skipped"]]
		+ " e coberto por test/smoke/test_reviravolta_panel_screen.gd)"
	)
	await _save(panel, "reviravolta-skipped")
	return line


## A Reviravolta nao encerra a campanha: o arcade segue para a proxima Peleja.
func _report_campaign_continues(container: Variant, arcade: ArcadeService) -> void:
	var persistence: Variant = container.persistence_gateway()
	print(
		"progresso do arcade: %s"
		% [persistence.load_value(ReviravoltaService.CAMPAIGN_KEY, {})]
	)
	var advanced: bool = arcade.advance()
	print(
		"arcade segue: avancou=%s peleja=%d/%d completa=%s requer_reviravolta=%s"
		% [
			advanced,
			arcade.fight_number(),
			arcade.fight_count(),
			arcade.is_arcade_complete(),
			arcade.requires_reviravolta(),
		]
	)


## Avanca a cena ate a voz mostrar a linha pedida.
func _advance_to_line(panel: Variant, line_index: int) -> void:
	var ticks := 0
	while int(panel.snapshot()["line_index"]) < line_index and ticks < CAPTURE_TICKS:
		panel.simulate_tick()
		ticks += 1
	panel.draw_frame()


## Avanca a cena ate a fase pedida.
func _advance_to_phase(panel: Variant, phase: String) -> void:
	var ticks := 0
	while str(panel.snapshot()["phase"]) != phase and ticks < CAPTURE_TICKS:
		panel.simulate_tick()
		ticks += 1
	panel.draw_frame()


func _save(panel: Variant, label: String) -> void:
	panel.draw_frame()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var relative := _output_dir.path_join("%s%s.png" % [FILE_PREFIX, label])
	var absolute := ProjectSettings.globalize_path(relative)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error := image.save_png(absolute)
	if error != OK:
		push_error("falha ao gravar %s (erro %d)" % [absolute, error])
		get_tree().quit(1)
		return
	print(
		"screenshot: %s (%dx%d) fase=%s linha=%s"
		% [
			absolute,
			image.get_width(),
			image.get_height(),
			panel.snapshot()["phase"],
			panel.snapshot()["line_index"],
		]
	)


func _apply_root_layout() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
