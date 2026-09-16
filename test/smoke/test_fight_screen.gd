extends GutTest
## A cena de luta e fina: monta o no de desenho, delega ao match-service e deixa
## os comandos do input-gateway injetado controlarem o Guardiao. Nenhuma regra de
## combate mora na cena.

const FIGHT_SCENE := "res://scenes/fight.tscn"
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
	_screen = load(FIGHT_SCENE).instantiate()
	_screen.auto_run = false
	add_child_autofree(_screen)
	await wait_process_frames(1)


func after_each() -> void:
	if _owns_container and is_instance_valid(_container):
		_container.queue_free()
	OS.set_environment("PELEJA_ADAPTERS", "")


func test_scene_builds_a_thin_view_and_a_match_service() -> void:
	assert_not_null(_screen.get_node_or_null("FightDisplay"), "no de desenho presente")
	assert_not_null(_screen.match_service, "a cena delega ao match-service")
	assert_true(_screen.match_service.is_active(), "a Peleja comeca ativa")
	assert_eq(
		_screen.get_node("FightDisplay").texture_filter,
		CanvasItem.TEXTURE_FILTER_NEAREST,
		"filtro nearest (pixel art sem suavizacao)"
	)


func test_the_assembled_match_keeps_the_hidden_advantage() -> void:
	var service: MatchService = _screen.match_service
	assert_gt(
		service.guardian.health.max_value,
		service.opponent.health.max_value,
		"o Guardiao entra com mais vida (Vantagem Oculta)"
	)
	assert_gt(
		service.guardian.stats.damage_multiplier,
		service.opponent.stats.damage_multiplier,
		"e com mais dano"
	)


func test_rendering_is_delegated_to_the_render_gateway() -> void:
	var render: SampleRenderGateway = _container.render_gateway()
	var before: int = render.frames_presented
	_screen.draw_frame()
	assert_gt(render.frames_presented, before, "a cena pediu um frame ao render-gateway")


func test_scripted_command_controls_the_guardian() -> void:
	var gateway: SampleInputGateway = _screen.input_gateway()
	var start_x: int = _screen.match_service.guardian.position.x
	gateway.script_commands([InputGateway.Command.MOVE_RIGHT])
	_screen.simulate_tick()
	assert_gt(_screen.match_service.guardian.position.x, start_x, "o comando move o Guardiao")


func test_the_scene_holds_no_combat_rules() -> void:
	for property in _screen.get_property_list():
		var property_name: String = property["name"]
		assert_false(
			property_name in ["health", "damage", "rounds", "last_round_result"],
			"a cena nao guarda estado de combate (%s)" % property_name
		)
