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


## --- Polimento: HUD final, sprites na cena e arcade (ticket 10) ---

func _production_container() -> bool:
	if _container == null or not _container.has_method("wire"):
		return false
	OS.set_environment("PELEJA_ADAPTERS", "live")
	_container.wire()
	return true


func _release_container() -> void:
	OS.set_environment("PELEJA_ADAPTERS", "sample")
	if _container != null and _container.has_method("wire"):
		_container.wire()


func test_the_hud_final_shows_names_bars_meter_rounds_and_clock() -> void:
	var model: Dictionary = _screen.hud_model()
	assert_eq(model["left"]["name"], GuardianStats.SACI, "nome do Guardiao na tela")
	assert_eq(str(model["right"]["name"]).is_empty(), false, "nome do Oponente na tela")
	assert_almost_eq(float(model["left"]["bar"]), 1.0, 0.01, "vida cheia no inicio")
	assert_true(model.has("left") and model["left"].has("meter"), "barra de Especial no HUD")
	assert_eq(int(model["rounds_to_win"]), MatchRules.ROUNDS_TO_WIN, "pips de round")
	assert_eq(model["clock_text"], "1:00", "relogio do round")
	assert_false(
		HudAdapter.new().discloses_hidden_advantage(model),
		"o HUD final nao revela a Vantagem Oculta"
	)


func test_the_hud_is_drawn_as_labels_over_the_surface() -> void:
	_screen.draw_frame()
	var count := 0
	for child in _screen.get_children():
		if child is TextureRect and str(child.name).begins_with("HudLabel"):
			count += 1
	assert_true(count >= 3, "nome dos dois lutadores e o relogio na tela")


func test_the_arcade_hud_appears_when_the_fight_comes_from_the_arcade() -> void:
	var arcade := ArcadeService.new(
		SampleInputGateway.new(),
		SampleRenderGateway.new(),
		InMemoryAssetGateway.new(),
		SilentAudioGateway.new()
	)
	assert_true(arcade.execute([], GuardianStats.CURUPIRA, 31, 41))
	_screen.attach_arcade(arcade)
	_screen.draw_frame()
	assert_eq(_screen.arcade_hud_model()["fight_text"], "PELEJA 1/7")
	assert_eq(_screen.hud_model()["arcade_text"], "PELEJA 1/7", "a linha do arcade no HUD")
	assert_eq(_screen.guardian_name, GuardianStats.CURUPIRA, "o Guardiao veio do arcade")


func test_the_animation_comes_from_the_domain_state_and_move() -> void:
	var guardian: Fighter = _screen.match_service.guardian
	guardian.stand()
	assert_eq(_screen.animation_for(guardian), "idle")
	guardian.walk(1)
	assert_eq(_screen.animation_for(guardian), "walk")
	guardian.crouch()
	assert_eq(_screen.animation_for(guardian), "crouch")
	guardian.block()
	assert_eq(_screen.animation_for(guardian), "block")
	guardian.current_move = null
	guardian.state = FighterState.State.IDLE
	guardian.start_move(Move.special("Redemoinho"))
	assert_eq(_screen.animation_for(guardian), "special")
	guardian.current_move = null
	guardian.state = FighterState.State.IDLE
	guardian.start_move(Move.grab())
	assert_eq(_screen.animation_for(guardian), "grab")
	guardian.state = FighterState.State.HURT
	assert_eq(_screen.animation_for(guardian), "hurt")
	guardian.state = FighterState.State.KNOCKED_DOWN
	assert_eq(_screen.animation_for(guardian), "ko")


func test_the_production_renderer_composes_both_spritesheets_and_the_hud() -> void:
	if not _production_container():
		return
	var screen: Variant = load(FIGHT_SCENE).instantiate()
	screen.auto_run = false
	add_child_autofree(screen)
	await wait_process_frames(1)
	screen.draw_frame()
	var report: Dictionary = screen.sprite_report()
	assert_true(bool(report["surface"]), "o renderer de producao montou a superficie")
	assert_gt(int(report["sprites_drawn"]), 0, "os lutadores sao desenhados pelos spritesheets")
	assert_gt(int(report["labels"]), 0, "o HUD final esta na tela")
	_release_container()
