extends Node
## Ferramenta de evidencia do ticket 10 (fora das camadas do jogo): monta as
## telas de verdade -- titulo, selecao, a Peleja do arcade com os spritesheets
## desenhados pelo renderer de producao e o HUD final, o Golpe Especial, as tres
## telas de fim e as opcoes com o remap de controles -- e grava um PNG 426x240
## por tela em `docs/evidence/ticket-10-*.png`.
##
## Roda no modo `live`: e a arte de producao (asset-gateway + sprite-render-
## adapter) que precisa aparecer na evidencia. O estado do jogo e dirigido pela
## API publica do dominio/servicos, nunca por teclado sintetico.
##
## Uso: PELEJA_ADAPTERS=live godot --path . tools/capture_release.tscn -- <dir>

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const SELECT_SCENE := "res://scenes/character_select.tscn"
const FIGHT_SCENE := "res://scenes/fight.tscn"
const OPTIONS_SCENE := "res://scenes/options_screen.tscn"
const VICTORY_SCENE := "res://scenes/victory_screen.tscn"
const DEFEAT_SCENE := "res://scenes/defeat_screen.tscn"
const ARCADE_END_SCENE := "res://scenes/arcade_end_screen.tscn"
const CONTAINER_PATH := "/root/app_container"
const DEFAULT_OUTPUT_DIR := "res://docs/evidence"
const FILE_PREFIX := "ticket-10-"
const MAX_TICKS := 6000
const GUARDIAN_SEED := 31
const OPPONENT_SEED := 41

var _output_dir := DEFAULT_OUTPUT_DIR
var _flow: GameFlowService


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		_output_dir = arguments[0]
	OS.set_environment("PELEJA_ADAPTERS", "live")
	var container: Variant = get_node_or_null(CONTAINER_PATH)
	if container == null:
		push_error("captura exige o composition root app_container")
		get_tree().quit(1)
		return
	container.wire()
	_flow = GameFlowService.new(
		container.input_gateway(),
		container.render_gateway(),
		container.asset_gateway(),
		container.audio_gateway(),
		container.persistence_gateway()
	)
	await _capture_title()
	await _capture_select()
	await _capture_fight()
	await _capture_end_screens()
	await _capture_options()
	print("captura do ticket 10 concluida em %s" % _output_dir)
	get_tree().quit(0)


## Tela de titulo com a arte gerada pelo asset-gateway.
func _capture_title() -> void:
	var screen: Control = load(TITLE_SCENE).instantiate()
	add_child(screen)
	await _settle()
	await _save(screen, "title")
	remove_child(screen)
	screen.queue_free()


## Tela de selecao com o cursor no terceiro Guardiao.
func _capture_select() -> void:
	var screen: Variant = load(SELECT_SCENE).instantiate()
	add_child(screen)
	await _settle()
	screen.select_index(2)
	await _settle()
	await _save(screen, "select")
	remove_child(screen)
	screen.queue_free()


## A Peleja do arcade: spritesheets dos dois lutadores desenhados em escala 3x,
## o HUD final (vida, barra de Especial, rounds, relogio, nomes) e a linha do
## arcade. Depois, o Golpe Especial do Guardiao na janela ativa.
func _capture_fight() -> void:
	_flow.start()
	_flow.select_guardian(GuardianStats.SACI)
	var fight: Variant = load(FIGHT_SCENE).instantiate()
	fight.arcade = _flow.arcade()
	fight.auto_run = false
	add_child(fight)
	await _settle()
	for _tick in 90:
		fight.simulate_tick()
	fight.draw_frame()
	var report: Dictionary = fight.sprite_report()
	print(
		"peleja: hud=%s superficie=%s sprites=%d rotulos=%d arcade=%s"
		% [
			fight.hud_model()["left"]["name"],
			report["surface"],
			report["sprites_drawn"],
			report["labels"],
			fight.arcade_hud_model()["fight_text"],
		]
	)
	await _save(fight, "fight-hud")
	var service: MatchService = fight.match_service
	var special := _start_special(fight, service)
	fight.draw_frame()
	print(
		"golpe especial: iniciou=%s ativo=%s barra=%s"
		% [special, service.snapshot()["special_active"], fight.hud_model()["left"]["meter"]]
	)
	await _save(fight, "fight-special")
	_finish_fight(fight, true)
	_flow.report_match_finished(MatchRules.Winner.GUARDIAN)
	remove_child(fight)
	fight.queue_free()


## Arma o Golpe Especial do Guardiao e avanca ate a janela ativa, sem deixar o
## hurt do round cancelar o golpe. Reintenta porque a IA pode acertar no meio.
func _start_special(fight: Variant, service: MatchService) -> bool:
	for _attempt in 3:
		service.guardian.meter.gain(9999)
		service.guardian.hurt_frames = 0
		service.guardian.current_move = null
		service.guardian.state = FighterState.State.IDLE
		if not service.guardian.start_special(service.special_move):
			continue
		for _tick in 18:
			fight.simulate_tick()
			if bool(service.snapshot()["special_active"]):
				return true
	return false


## Fecha a Peleja corrente zerando a vida do Oponente (nocaute pela API publica
## do dominio), para o resumo de vitoria ser o de uma Peleja de verdade.
func _finish_fight(fight: Variant, guardian_wins: bool) -> void:
	var service: MatchService = fight.match_service
	var ticks := 0
	while not service.is_match_over() and ticks < MAX_TICKS:
		if service.phase == MatchService.Phase.ROUND_ACTIVE:
			var loser := service.opponent if guardian_wins else service.guardian
			loser.health.apply_damage(loser.health.current)
		fight.simulate_tick()
		ticks += 1
	print("peleja fechada em %d ticks (vencedor=%d)" % [ticks, service.winner()])


## As tres telas de fim: vitoria (Peleja vencida), derrota (Peleja perdida, com a
## campanha continuando) e fim de arcade.
func _capture_end_screens() -> void:
	await _save_result(VICTORY_SCENE, _flow.result_summary(), "victory")
	_flow.report_match_finished(MatchRules.Winner.OPPONENT)
	_flow.report_reviravolta_finished(true)
	await _save_result(DEFEAT_SCENE, _flow.result_summary(), "defeat")
	var arcade_summary := _run_full_arcade()
	await _save_result(ARCADE_END_SCENE, arcade_summary, "arcade-end")


func _save_result(scene_path: String, summary: Dictionary, label: String) -> void:
	var screen: Variant = load(scene_path).instantiate()
	add_child(screen)
	await _settle()
	screen.configure(summary)
	screen.draw_frame()
	print(
		"%s: titulo=%s pelea=%d/%d"
		% [
			label,
			screen.result_adapter.title_for(screen.result_kind()),
			int(summary.get("fight", 0)),
			int(summary.get("fights", 0)),
		]
	)
	await _save(screen, label)
	remove_child(screen)
	screen.queue_free()


## Roda o arcade inteiro vencendo as sete Pelejas, pela API publica, e devolve o
## resumo final (as sete Pelejas terminadas).
func _run_full_arcade() -> Dictionary:
	_flow.start()
	_flow.select_guardian(GuardianStats.SACI)
	var arcade := _flow.arcade()
	for position in 7:
		var match_service: MatchService = arcade.match_service
		var ticks := 0
		while not match_service.is_match_over() and ticks < MAX_TICKS:
			if match_service.phase == MatchService.Phase.ROUND_ACTIVE:
				match_service.opponent.health.apply_damage(match_service.opponent.health.current)
			arcade.advance_tick()
			ticks += 1
		_flow.report_match_finished(MatchRules.Winner.GUARDIAN)
		if position < 6:
			_flow.continue_campaign()
	print(
		"arcade: pelejas=%d completo=%s"
		% [arcade.results.size(), _flow.result_summary()["arcade_complete"]]
	)
	return _flow.result_summary()


## Opcoes com o remap de controles em curso: a linha CONTROLES mostra AJUSTADO e o
## rodape pede a tecla, sem encostar na borda.
func _capture_options() -> void:
	var screen: Variant = load(OPTIONS_SCENE).instantiate()
	add_child(screen)
	await _settle()
	screen.declare_gesture()
	screen.set_volume_percent(70)
	screen.begin_remap()
	for _step in 3:
		screen.bind_key(KEY_Q + _step)
	screen.refresh()
	print(
		"opcoes: remap=%s acao=%s tecla=%s controles=%s"
		% [
			screen.is_remapping(),
			screen.remap_action(),
			screen.options_service.controls().key_for(screen.remap_action()),
			screen.is_controls_custom(),
		]
	)
	await _save(screen, "options-remap")
	remove_child(screen)
	screen.queue_free()


func _settle() -> void:
	for _frame in 3:
		await get_tree().process_frame


## Grava o frame corrente do viewport (426x240) em PNG.
func _save(node: Node, label: String) -> void:
	if node is Control and node.has_method("draw_frame"):
		node.draw_frame()
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
	print("screenshot: %s (%dx%d)" % [absolute, image.get_width(), image.get_height()])
