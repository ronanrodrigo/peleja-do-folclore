extends GutTest
## A cena de Reviravolta e fina: monta a superficie 426x240, delega ao
## `ReviravoltaService` com os gateways injetados pelo composition root, desenha
## a copy pt-BR do `PanelAdapter` e drena o comando de pular do input-gateway.
##
## Adapters `sample` (a tela roda no modo sample): nenhum teclado sintetico.

const PANEL_SCENE := "res://scenes/reviravolta_panel.tscn"
const CONTAINER_SCRIPT := "res://autoloads/app_container.gd"
const PANEL_BYTES := 426 * 240 * 4

var _screen: Variant
var _container: Variant
var _owns_container: bool = false


func before_each() -> void:
	OS.set_environment("PELEJA_ADAPTERS", "sample")
	_container = get_tree().root.get_node_or_null("app_container")
	if _container == null:
		_container = load(CONTAINER_SCRIPT).new()
		_container.name = "app_container"
		get_tree().root.add_child(_container)
		_owns_container = true


func after_each() -> void:
	OS.set_environment("PELEJA_ADAPTERS", "")
	if _owns_container and is_instance_valid(_container):
		_container.queue_free()


## Sobe a cena com o resultado pedido e sem rodar sozinha (a ferramenta de
## evidencia e o teste dirigem os ticks).
func _open(winner: int, fight_number: int, auto_run: bool = false) -> void:
	_screen = load(PANEL_SCENE).instantiate()
	_screen.winner_result = winner
	_screen.fight_number = fight_number
	_screen.auto_run = auto_run
	add_child_autofree(_screen)
	await wait_process_frames(2)


func test_the_scene_builds_the_display_in_the_base_resolution_with_nearest_filter() -> void:
	await _open(MatchRules.Winner.OPPONENT, 1)
	var display: TextureRect = _screen.get_node_or_null("ReviravoltaDisplay")
	assert_not_null(display, "superficie de desenho presente")
	assert_eq(display.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "filtro nearest")
	assert_eq(display.texture.get_width(), 426, "largura da resolucao base")
	assert_eq(display.texture.get_height(), 240, "altura da resolucao base")
	assert_not_null(_screen.reviravolta_service, "a cena delegou ao caso de uso")
	assert_not_null(_screen.panel_adapter, "a copy vem do adapter de apresentacao")


func test_the_panel_is_a_full_bleed_426x240_from_the_asset_gateway() -> void:
	await _open(MatchRules.Winner.OPPONENT, 3)
	assert_true(_screen.panel_started(), "o Oponente venceu: a Reviravolta entrou em cena")
	assert_eq(_screen.panel_pixels().size(), PANEL_BYTES, "painel de tela cheia RGBA8")
	assert_eq(_screen.snapshot()["panel_bytes"], PANEL_BYTES)
	assert_eq(_screen.snapshot()["fight_number"], 3, "a Peleja em que a Reviravolta aconteceu")
	var audio: SilentAudioGateway = _container.audio_gateway()
	assert_eq(audio.last_music(), AudioGateway.MUSIC_REVIRAVOLTA, "trilha da Reviravolta")


func test_the_scene_never_plays_when_the_guardian_wins() -> void:
	var audio: SilentAudioGateway = _container.audio_gateway()
	audio.music_calls.clear()
	await _open(MatchRules.Winner.GUARDIAN, 2)
	assert_false(_screen.panel_started(), "Guardião vencendo, a cena nao entra")
	assert_false(_screen.is_finished(), "nao ha cena para terminar")
	assert_eq(_screen.snapshot()["active"], false)
	assert_false(
		audio.music_calls.has(AudioGateway.MUSIC_REVIRAVOLTA),
		"sem Reviravolta, a trilha dela nunca toca"
	)


func test_the_scene_advances_alone_and_finishes_with_the_opponent_dissolved() -> void:
	await _open(MatchRules.Winner.OPPONENT, 1)
	var phases: Array = []
	var ticks := 0
	while not _screen.is_finished() and ticks < 900:
		var state: Dictionary = _screen.simulate_tick()
		if not phases.has(state["phase"]):
			phases.append(state["phase"])
		ticks += 1
	assert_eq(phases, ["voice", "wind", "root", "dissolve", "done"], "a cena rola sozinha")
	assert_true(_screen.snapshot()["opponent_dissolved"], "o Oponente foi dissolvido")
	assert_false(_screen.snapshot()["skipped"], "terminou pelo tempo")


func test_the_confirm_command_from_the_gateway_skips_the_scene() -> void:
	await _open(MatchRules.Winner.OPPONENT, 1)
	watch_signals(_screen)
	var gateway: SampleInputGateway = _container.input_gateway()
	gateway.script_commands([InputGateway.Command.CONFIRM])
	await wait_process_frames(2)
	assert_signal_emitted(_screen, "panel_finished", "o comando de pular fecha a cena")
	assert_true(_screen.is_finished(), "a cena terminou pelo comando")
	assert_true(_screen.snapshot()["skipped"], "e marcada como pulada")
	assert_false(gateway.pending() > 0, "o comando foi consumido")


func test_the_arcade_progress_survives_the_reviravolta() -> void:
	await _open(MatchRules.Winner.OPPONENT, 5)
	var persistence: Variant = _container.persistence_gateway()
	var stored: Dictionary = persistence.load_value(ReviravoltaService.CAMPAIGN_KEY, {})
	assert_eq(stored["fight"], 5, "a Peleja perdida ficou registrada")
	assert_false(stored["campaign_over"], "a campanha continua depois da Reviravolta")
	assert_true(_screen.snapshot()["campaign_continues"])
