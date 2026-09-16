extends GutTest
## A tela de opcoes e fina: monta a superficie, delega ao `OptionsService` com os
## gateways injetados pelo composition root e desenha o modelo do
## `OptionsViewAdapter`. Volume e mudo sao persistidos no gateway de persistencia
## e o comando de menu (incluindo o gesto que destrava o audio) vem do
## input-gateway injetado.

const OPTIONS_SCENE := "res://scenes/options_screen.tscn"
const TITLE_SCENE := "res://scenes/title_screen.tscn"
const CONTAINER_SCRIPT := "res://autoloads/app_container.gd"

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
	_screen = load(OPTIONS_SCENE).instantiate()
	add_child_autofree(_screen)
	await wait_process_frames(2)


func after_each() -> void:
	if _owns_container and is_instance_valid(_container):
		_container.queue_free()
	OS.set_environment("PELEJA_ADAPTERS", "")


func test_screen_builds_the_display_in_the_base_resolution_with_nearest_filter() -> void:
	var display: TextureRect = _screen.get_node_or_null("OptionsDisplay")
	assert_not_null(display, "superficie de desenho presente")
	assert_eq(
		display.texture_filter,
		CanvasItem.TEXTURE_FILTER_NEAREST,
		"filtro nearest (pixel art sem suavizacao)"
	)
	assert_eq(display.texture.get_width(), 426, "largura da resolucao base")
	assert_eq(display.texture.get_height(), 240, "altura da resolucao base")
	assert_not_null(_screen.options_service, "a tela delegou ao caso de uso")
	assert_not_null(_screen.view_adapter, "a copy vem do adapter de apresentacao")


func test_the_screen_asks_for_the_menu_music_context() -> void:
	var audio: SilentAudioGateway = _container.audio_gateway()
	assert_true(
		audio.music_calls.has(AudioGateway.MUSIC_SELECT), "o menu pede a trilha de menu"
	)


func test_scripted_command_changes_the_volume_and_plays_navigate() -> void:
	var audio: SilentAudioGateway = _container.audio_gateway()
	audio.sfx_calls.clear()
	var before: int = _screen.volume_percent()
	var gateway: SampleInputGateway = _container.input_gateway()
	gateway.script_commands([InputGateway.Command.MOVE_LEFT])
	await wait_process_frames(2)
	assert_lt(_screen.volume_percent(), before, "MOVE_LEFT desce o volume")
	assert_true(
		audio.sfx_calls.has(AudioGateway.SFX_NAVIGATE), "o passo de volume faz o clique"
	)


func test_confirm_command_toggles_the_mute_and_plays_select() -> void:
	var audio: SilentAudioGateway = _container.audio_gateway()
	audio.sfx_calls.clear()
	var before: bool = _screen.is_muted()
	var gateway: SampleInputGateway = _container.input_gateway()
	gateway.script_commands([InputGateway.Command.CONFIRM])
	await wait_process_frames(2)
	assert_ne(_screen.is_muted(), before, "CONFIRM alterna o mudo")
	assert_true(audio.sfx_calls.has(AudioGateway.SFX_SELECT), "alternar faz o som de selecao")


func test_cancel_command_closes_the_screen() -> void:
	watch_signals(_screen)
	var gateway: SampleInputGateway = _container.input_gateway()
	gateway.script_commands([InputGateway.Command.CANCEL])
	await wait_process_frames(2)
	assert_signal_emitted(_screen, "closed", "CANCEL fecha a tela de opcoes")
	assert_false(_screen.visible, "a tela sai de cena")


func test_volume_and_mute_are_persisted_by_the_wired_gateway() -> void:
	var persistence: Variant = _container.persistence_gateway()
	var muted_before: bool = _screen.is_muted()
	_screen.set_volume_percent(40)
	_screen.toggle_mute()
	assert_almost_eq(
		float(persistence.load_value(OptionsService.KEY_MASTER_VOLUME, -1.0)),
		0.4,
		0.001,
		"volume gravado pelo gateway de persistencia injetado"
	)
	assert_eq(
		persistence.load_value(OptionsService.KEY_MUTED, "ausente"),
		not muted_before,
		"mudo gravado pelo gateway de persistencia injetado"
	)


func test_volume_and_mute_come_back_in_a_new_session() -> void:
	var persistence: Variant = _container.persistence_gateway()
	_screen.set_volume_percent(60)
	if not _screen.is_muted():
		_screen.toggle_mute()
	var restored := OptionsService.new(persistence, SilentAudioGateway.new())
	restored.load_preferences()
	assert_eq(restored.volume_percent(), 60, "volume restaurado na sessao seguinte")
	assert_true(restored.is_muted(), "mudo restaurado na sessao seguinte")


func test_declaring_the_gesture_unlocks_the_audio() -> void:
	var audio: SilentAudioGateway = _container.audio_gateway()
	_screen.declare_gesture()
	assert_true(audio.is_audio_unlocked(), "o gesto do jogador destrava o audio (autoplay)")
	assert_gt(audio.gesture_count, 0, "o gesto foi contado pelo gateway")


func test_title_screen_opens_and_closes_the_options() -> void:
	var title: Variant = load(TITLE_SCENE).instantiate()
	add_child_autofree(title)
	await wait_process_frames(1)
	assert_false(title.options_open(), "as opcoes comecam fechadas")
	title.open_options()
	await wait_process_frames(2)
	assert_true(title.options_open(), "o titulo abre a tela de opcoes")
	var options := _find_options_child(title)
	assert_not_null(options, "a tela de opcoes entrou como filha do titulo")
	options.call("close")
	await wait_process_frames(2)
	assert_false(title.options_open(), "fechar as opcoes devolve o titulo ao estado inicial")


func _find_options_child(node: Node) -> Node:
	for child in node.get_children():
		if child.get("options_service") != null:
			return child
	return null