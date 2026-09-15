extends GutTest
## A tela de titulo monta sem asset externo, desenha o nome do jogo e responde
## ao comando de comeco vindo do input-gateway injetado.

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
	_screen = load(TITLE_SCENE).instantiate()
	add_child_autofree(_screen)
	await wait_process_frames(1)


func after_each() -> void:
	if _owns_container and is_instance_valid(_container):
		_container.queue_free()
	OS.set_environment("PELEJA_ADAPTERS", "")


func test_scene_builds_without_external_asset() -> void:
	assert_not_null(_screen.get_node_or_null("Backdrop"), "fundo em dados, sem PNG externo")
	assert_not_null(_screen.get_node_or_null("TitleText"), "titulo pela fonte bitmap")
	assert_not_null(_screen.get_node_or_null("PromptText"), "aviso de comeco presente")


func test_title_is_the_game_name() -> void:
	assert_eq(_screen.TITLE_TEXT, "PELEJA DO FOLCLORE")


func test_prompt_asks_the_player_to_start() -> void:
	assert_eq(_screen.prompt_text(), "PRESSIONE PARA COMEÇAR")
	assert_false(_screen.has_started(), "a tela comeca sem ter comecado")


func test_confirm_command_from_wired_gateway_starts_the_game() -> void:
	var gateway: InputGateway = _container.input_gateway()
	gateway.script_commands([InputGateway.Command.CONFIRM])
	await wait_process_frames(2)
	assert_true(_screen.has_started(), "comando CONFIRM do input-gateway inicia a peleja")
	assert_eq(_screen.prompt_text(), "LUTA EM BREVE")


func test_every_texture_uses_nearest_filter() -> void:
	for node in _screen.get_children():
		if node is TextureRect:
			assert_eq(
				node.texture_filter,
				CanvasItem.TEXTURE_FILTER_NEAREST,
				"%s usa filtro nearest" % node.name
			)


func test_backdrop_asks_for_the_generated_art_by_slug() -> void:
	assert_eq(_screen.BACKDROP_SLUG, "forest-arena", "fundo pede a arte gerada pelo slug")
	assert_true(
		_screen.backdrop_source() in [_screen.BACKDROP_SOURCE_GENERATED, _screen.BACKDROP_SOURCE_CODE],
		"fundo declara de onde veio (arte gerada ou codigo)"
	)


func test_missing_generated_art_still_builds_a_backdrop_from_code() -> void:
	var gateway := InMemoryAssetGateway.new()
	assert_eq(
		gateway.load_panel(_screen.BACKDROP_SLUG, PackedByteArray()).size(),
		0,
		"sem arte gerada no gateway, o fundo em codigo assume"
	)
	assert_not_null(_screen.get_node_or_null("Backdrop"), "a tela monta o fundo mesmo sem arte gerada")

