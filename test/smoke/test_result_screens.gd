extends GutTest
## As telas de fim (ticket 10) sao finas: montam a superficie 426x240, desenham o
## modelo do `ResultAdapter` e avisam o fluxo pelo sinal `confirmed`.

const CONTAINER_SCRIPT := "res://autoloads/app_container.gd"
const SCENES := {
	ResultAdapter.KIND_VICTORY: "res://scenes/victory_screen.tscn",
	ResultAdapter.KIND_DEFEAT: "res://scenes/defeat_screen.tscn",
	ResultAdapter.KIND_ARCADE_END: "res://scenes/arcade_end_screen.tscn",
}

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
	if _owns_container and is_instance_valid(_container):
		_container.queue_free()
	OS.set_environment("PELEJA_ADAPTERS", "")


func _fight_summary() -> Dictionary:
	return {
		"guardian": GuardianStats.SACI,
		"opponent": "O Capataz",
		"fight": 4,
		"fights": 7,
		"winner": MatchRules.Winner.GUARDIAN,
		"guardian_rounds": 2,
		"opponent_rounds": 1,
		"skipped": false,
		"arcade_complete": false,
		"results": [],
	}


func _open(kind: String) -> Variant:
	var screen: Variant = load(SCENES[kind]).instantiate()
	add_child_autofree(screen)
	await wait_process_frames(1)
	screen.configure(_fight_summary())
	return screen


func test_each_screen_builds_in_the_base_resolution_with_nearest_filter() -> void:
	for kind in SCENES.keys():
		var screen: Variant = await _open(kind)
		var display: TextureRect = screen.get_node_or_null("ResultDisplay")
		assert_not_null(display, "superficie de desenho da tela de %s" % kind)
		assert_eq(display.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "pixel art")
		assert_eq(display.texture.get_width(), 426, "largura da resolucao base")
		assert_eq(display.texture.get_height(), 240, "altura da resolucao base")
		assert_eq(screen.result_kind(), kind, "a cena responde o proprio tipo")


func test_confirming_announces_the_result_to_the_flow() -> void:
	var screen: Variant = await _open(ResultAdapter.KIND_VICTORY)
	var received: Array = []
	screen.confirmed.connect(func() -> void: received.append(true))
	assert_false(screen.has_confirmed(), "a tela comeca sem confirmacao")
	screen.confirm()
	screen.confirm()
	assert_eq(received.size(), 1, "o sinal sai uma vez so")
	assert_true(screen.has_confirmed())


func test_the_input_gateway_command_confirms_the_screen() -> void:
	var screen: Variant = await _open(ResultAdapter.KIND_ARCADE_END)
	var gateway: SampleInputGateway = _container.input_gateway()
	gateway.script_commands([InputGateway.Command.CONFIRM])
	await wait_process_frames(2)
	assert_true(screen.has_confirmed(), "o comando do input-gateway confirma")


func test_the_defeat_screen_offers_the_continuation_and_the_arcade_end_the_title() -> void:
	var defeat: Variant = await _open(ResultAdapter.KIND_DEFEAT)
	assert_eq(defeat.result_adapter.hint_for(ResultAdapter.KIND_DEFEAT), "ENTER CONTINUA")
	var end_screen: Variant = await _open(ResultAdapter.KIND_ARCADE_END)
	assert_eq(
		end_screen.result_adapter.hint_for(ResultAdapter.KIND_ARCADE_END),
		"ENTER VOLTA AO TÍTULO",
		"o fim do arcade tem caminho de volta ao titulo"
	)


func test_drawing_a_frame_works_even_without_a_summary() -> void:
	var screen: Variant = await _open(ResultAdapter.KIND_VICTORY)
	screen.summary = {}
	screen.draw_frame()
	assert_true(true, "a tela desenha mesmo sem resumo (fluxo nunca deixa vazio)")
