extends GutTest
## A raiz de navegacao (ticket 10) e fina: so troca a tela em cena e entrega o
## dado; quem decide a proxima tela e o `game-flow-service`.

const GAME_SCENE := "res://scenes/game.tscn"
const CONTAINER_SCRIPT := "res://autoloads/app_container.gd"
const MAX_TICKS := 6000

var _game: Variant
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
	_game = load(GAME_SCENE).instantiate()
	add_child_autofree(_game)
	await wait_process_frames(2)


func after_each() -> void:
	if _owns_container and is_instance_valid(_container):
		_container.queue_free()
	else:
		_container.wire()
	OS.set_environment("PELEJA_ADAPTERS", "")


func _gateway() -> SampleInputGateway:
	return _container.input_gateway()


func _fight() -> Variant:
	return _game.current_screen


## Fecha a Peleja zerando a vida de quem deve perder (nocaute pela API do dominio).
func _finish_fight(guardian_loses: bool) -> void:
	var fight: Variant = _game.current_screen
	var service: MatchService = fight.match_service
	var ticks := 0
	while not service.is_match_over() and ticks < MAX_TICKS:
		if service.phase == MatchService.Phase.ROUND_ACTIVE:
			var loser := service.guardian if guardian_loses else service.opponent
			loser.health.apply_damage(loser.health.current)
		fight.simulate_tick()
		ticks += 1


func test_the_game_opens_on_the_title() -> void:
	assert_eq(_game.screen_name(), "title", "o jogo comeca no titulo")
	assert_not_null(_game.current_screen, "a tela inicial esta em cena")


func test_the_title_leads_to_the_roster() -> void:
	_gateway().script_commands([InputGateway.Command.CONFIRM])
	await wait_process_frames(2)
	assert_eq(_game.screen_name(), "character_select", "confirmar abre a selecao")


func test_choosing_a_guardian_mounts_the_arcade_fight() -> void:
	_gateway().script_commands([InputGateway.Command.CONFIRM])
	await wait_process_frames(2)
	_gateway().script_commands([InputGateway.Command.MOVE_RIGHT, InputGateway.Command.CONFIRM])
	await wait_process_frames(2)
	assert_eq(_game.screen_name(), "fight")
	var fight: Variant = _game.current_screen
	assert_not_null(fight.match_service, "a cena delega ao match-service")
	assert_not_null(fight.arcade, "e a Peleja e a do arcade")
	assert_eq(fight.guardian_name, GuardianStats.CURUPIRA, "o Guardiao escolhido chegou como dado")
	assert_eq(fight.arcade.fight_number(), 1, "primeira Peleja do arcade")


func test_winning_shows_the_victory_and_continues_the_campaign() -> void:
	await _reach_fight()
	_finish_fight(false)
	await wait_process_frames(1)
	assert_eq(_game.screen_name(), "victory", "vitoria do Guardiao")
	_game.current_screen.confirm()
	await wait_process_frames(1)
	assert_eq(_game.screen_name(), "fight", "a campanha segue para a proxima Peleja")
	assert_eq(_game.current_screen.arcade.fight_number(), 2)


func test_losing_goes_through_the_reviravolta_to_the_defeat_and_the_campaign_continues() -> void:
	await _reach_fight()
	_finish_fight(true)
	await wait_process_frames(1)
	assert_eq(_game.screen_name(), "reviravolta", "o Oponente venceu: a Forca entra em cena")
	var panel: Variant = _game.current_screen
	panel.auto_run = false
	assert_true(panel.skip(), "a cena da Reviravolta pode ser pulada")
	await wait_process_frames(1)
	assert_eq(_game.screen_name(), "defeat", "a tela de derrota fecha a Peleja perdida")
	_game.current_screen.confirm()
	await wait_process_frames(1)
	assert_eq(_game.screen_name(), "fight", "perder nao encerra a campanha")
	assert_eq(_game.current_screen.arcade.fight_number(), 2)


func test_the_escape_opens_the_options_over_the_fight_and_returns_to_it() -> void:
	await _reach_fight()
	assert_eq(_game.screen_name(), "fight")
	_game.open_options()
	await wait_process_frames(1)
	assert_eq(_game.screen_name(), "options", "as opcoes abrem sobre a Peleja")
	_game.current_screen.close()
	await wait_process_frames(1)
	assert_eq(_game.screen_name(), "fight", "fechar as opcoes volta para a Peleja")
	assert_eq(_game.current_screen.arcade.fight_number(), 1, "a Peleja foi retomada")


func _reach_fight() -> void:
	_gateway().script_commands([InputGateway.Command.CONFIRM])
	await wait_process_frames(2)
	_gateway().script_commands([InputGateway.Command.CONFIRM])
	await wait_process_frames(2)
	assert_eq(_game.screen_name(), "fight")
