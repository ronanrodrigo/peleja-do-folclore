extends GutTest
## A tela de selecao e fina: monta o no, delega ao `character-select-service` e ao
## `hud-adapter` e deixa os comandos do input-gateway injetado escolherem o
## Guardiao. Nenhuma regra de selecao mora na cena.

const SELECT_SCENE := "res://scenes/character_select.tscn"
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
	_screen = load(SELECT_SCENE).instantiate()
	add_child_autofree(_screen)
	await wait_process_frames(1)


func after_each() -> void:
	if _owns_container and is_instance_valid(_container):
		_container.queue_free()
	OS.set_environment("PELEJA_ADAPTERS", "")


func test_the_scene_builds_the_service_and_the_hud() -> void:
	assert_not_null(_screen.service, "a cena delega ao character-select-service")
	assert_not_null(_screen.hud, "e ao hud-adapter")
	assert_eq(_screen.service.count(), 4, "os 4 Guardioes do elenco")
	assert_eq(_screen.current_guardian(), GuardianStats.SACI)


func test_the_screen_shows_every_guardian_with_name_and_special() -> void:
	var labels: PackedStringArray = _screen.visible_labels()
	for guardian_name in GuardianStats.all():
		assert_true(labels.has(str(guardian_name)), "a tela mostra %s" % guardian_name)
	assert_true(labels.has(SpecialMove.PES_INVERTIDOS), "e o Golpe Especial do Curupira")
	assert_true(labels.has(SpecialMove.CANTO_DO_RIO))
	assert_true(labels.has(SpecialMove.NANA_NENEM))
	assert_true(labels.has(SpecialMove.REDEMOINHO))
	assert_eq(
		_screen.service.rows().size(), GuardianStats.count(), "um retrato por Guardiao"
	)


func test_scripted_commands_move_the_selection() -> void:
	var gateway: SampleInputGateway = _screen.input_gateway()
	gateway.script_commands([InputGateway.Command.MOVE_RIGHT])
	await wait_process_frames(1)
	assert_eq(_screen.current_guardian(), GuardianStats.CURUPIRA, "a cena drena o input-gateway")
	assert_eq(_screen.selection()["slug"], "curupira")
	_screen.move_selection(-1)
	assert_eq(_screen.current_guardian(), GuardianStats.SACI)


func test_confirming_announces_the_chosen_guardian_as_data() -> void:
	var received: Array = []
	_screen.guardian_selected.connect(
		func(guardian_name: String) -> void: received.append(guardian_name)
	)
	_screen.select_index(3)
	var chosen: String = _screen.confirm_selection()
	assert_eq(chosen, GuardianStats.CUCA)
	assert_eq(received, [GuardianStats.CUCA], "o sinal leva o Guardiao escolhido")
	assert_eq(_screen.selection()["confirmed_guardian"], GuardianStats.CUCA)
	var gateway: SampleInputGateway = _screen.input_gateway()
	gateway.script_commands([InputGateway.Command.MOVE_RIGHT])
	await wait_process_frames(1)
	assert_eq(_screen.current_guardian(), GuardianStats.CUCA, "confirmado, a selecao congela")


func test_the_scene_holds_no_combat_state() -> void:
	for property in _screen.get_property_list():
		var property_name: String = property["name"]
		assert_false(
			property_name in ["health", "damage", "rounds", "last_round_result"],
			"a cena nao guarda estado de combate (%s)" % property_name
		)


func test_the_display_uses_nearest_pixel_art_filter() -> void:
	var display: Variant = _screen.get_node_or_null("SelectDisplay")
	if display == null:
		return
	assert_eq(
		display.texture_filter,
		CanvasItem.TEXTURE_FILTER_NEAREST,
		"pixel art sem suavizacao"
	)