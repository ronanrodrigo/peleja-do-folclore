extends GutTest
## O `game-flow-service` (ticket 10): o encadeamento das telas e a campanha do
## arcade. Titulo -> selecao -> Peleja -> (vitoria | Reviravolta -> derrota) ->
## proxima Peleja, com o fim de arcade depois das sete. Adapters `sample`.

const MAX_TICKS := 6000


func _flow() -> Dictionary:
	var input := SampleInputGateway.new()
	var flow := GameFlowService.new(
		input,
		SampleRenderGateway.new(),
		InMemoryAssetGateway.new(),
		SilentAudioGateway.new(),
		InMemoryPersistenceGateway.new()
	)
	return {"flow": flow, "input": input}


## Fecha a Peleja corrente zerando a vida de quem deve perder, pela API publica
## do dominio (nocaute e a via rapida do round).
func _finish_current_fight(flow: GameFlowService, guardian_loses: bool) -> int:
	var match_service := flow.match_service()
	var ticks := 0
	while not match_service.is_match_over() and ticks < MAX_TICKS:
		if match_service.phase == MatchService.Phase.ROUND_ACTIVE:
			var loser := match_service.guardian if guardian_loses else match_service.opponent
			loser.health.apply_damage(loser.health.current)
		flow.arcade().advance_tick()
		ticks += 1
	assert_lt(ticks, MAX_TICKS, "a Peleja fecha em numero finito de ticks")
	return match_service.winner()


func _win(flow: GameFlowService) -> void:
	flow.report_match_finished(_finish_current_fight(flow, false))


func _lose(flow: GameFlowService) -> void:
	flow.report_match_finished(_finish_current_fight(flow, true))


func test_the_game_starts_on_the_title_and_goes_to_the_roster() -> void:
	var fx := _flow()
	var flow: GameFlowService = fx["flow"]
	assert_eq(flow.current_screen(), GameFlowService.Screen.TITLE)
	assert_eq(flow.screen_name(), "title")
	assert_eq(flow.start(), GameFlowService.Screen.CHARACTER_SELECT)
	assert_eq(flow.screen_name(), "character_select")


func test_the_chosen_guardian_mounts_the_arcade_and_the_first_fight() -> void:
	var fx := _flow()
	var flow: GameFlowService = fx["flow"]
	flow.start()
	assert_eq(flow.select_guardian(GuardianStats.CURUPIRA), GameFlowService.Screen.FIGHT)
	assert_eq(flow.screen_name(), "fight")
	assert_eq(flow.fight_number(), 1)
	assert_eq(flow.fight_count(), 7)
	assert_eq(flow.match_service().guardian.stats.display_name, GuardianStats.CURUPIRA)
	assert_true(flow.match_service().is_active(), "a Peleja comeca ativa")


func test_an_empty_guardian_never_mounts_a_fight() -> void:
	var fx := _flow()
	var flow: GameFlowService = fx["flow"]
	flow.start()
	assert_eq(flow.select_guardian(""), GameFlowService.Screen.CHARACTER_SELECT)
	assert_null(flow.match_service(), "o jogo nao inventa lutador")


func test_winning_takes_the_player_to_the_victory_and_then_to_the_next_fight() -> void:
	var fx := _flow()
	var flow: GameFlowService = fx["flow"]
	flow.start()
	flow.select_guardian(GuardianStats.SACI)
	_win(flow)
	assert_eq(flow.screen_name(), "victory")
	assert_eq(flow.last_winner, MatchRules.Winner.GUARDIAN)
	assert_eq(flow.continue_campaign(), GameFlowService.Screen.FIGHT)
	assert_eq(flow.fight_number(), 2, "a campanha avancou uma Peleja")
	assert_eq(flow.result_summary()["guardian_rounds"], MatchRules.ROUNDS_TO_WIN)


func test_losing_still_ends_the_fight_in_the_reviravolta_and_the_campaign_goes_on() -> void:
	var fx := _flow()
	var flow: GameFlowService = fx["flow"]
	flow.start()
	flow.select_guardian(GuardianStats.SACI)
	_lose(flow)
	assert_eq(flow.last_winner, MatchRules.Winner.OPPONENT)
	assert_eq(flow.screen_name(), "reviravolta", "o Oponente venceu: a Forca entra em cena")
	assert_eq(flow.report_reviravolta_finished(false), GameFlowService.Screen.DEFEAT)
	assert_eq(flow.screen_name(), "defeat")
	assert_eq(flow.continue_campaign(), GameFlowService.Screen.FIGHT, "perder nao encerra a campanha")
	assert_eq(flow.fight_number(), 2)


func test_the_defeat_is_recorded_as_a_campaign_that_continues() -> void:
	var fx := _flow()
	var flow: GameFlowService = fx["flow"]
	flow.start()
	flow.select_guardian(GuardianStats.SACI)
	_lose(flow)
	var progress := flow.campaign_progress()
	assert_false(bool(progress["campaign_over"]), "a derrota nunca encerra o arcade")
	assert_eq(progress["fights"], 7)
	assert_eq(progress["fight"], 1)


func test_the_whole_arcade_runs_seven_fights_and_closes_at_the_end() -> void:
	var fx := _flow()
	var flow: GameFlowService = fx["flow"]
	flow.start()
	flow.select_guardian(GuardianStats.SACI)
	for position in 7:
		assert_eq(flow.fight_number(), position + 1, "Peleja %d de 7" % (position + 1))
		_win(flow)
		assert_eq(flow.screen_name(), "victory")
		if position < 6:
			assert_false(flow.is_arcade_complete())
			assert_eq(flow.continue_campaign(), GameFlowService.Screen.FIGHT)
		else:
			assert_true(flow.is_arcade_complete(), "as sete Pelejas foram jogadas")
			assert_eq(flow.continue_campaign(), GameFlowService.Screen.ARCADE_END)
	assert_eq(flow.screen_name(), "arcade_end")
	assert_eq(flow.arcade().results.size(), 7, "cada Peleja entrou uma vez")
	assert_eq(flow.result_summary()["results"].size(), 7)


func test_the_end_of_the_arcade_reaches_the_arcade_end_screen_after_a_loss_too() -> void:
	var fx := _flow()
	var flow: GameFlowService = fx["flow"]
	flow.start()
	flow.select_guardian(GuardianStats.SACI)
	for position in 7:
		if position < 6:
			_win(flow)
			flow.continue_campaign()
		else:
			_lose(flow)
			flow.report_reviravolta_finished(true)
			assert_eq(flow.screen_name(), "defeat")
			assert_eq(flow.continue_campaign(), GameFlowService.Screen.ARCADE_END)


func test_the_arcade_end_returns_to_the_title_and_clears_the_campaign() -> void:
	var fx := _flow()
	var flow: GameFlowService = fx["flow"]
	flow.start()
	flow.select_guardian(GuardianStats.SACI)
	for position in 7:
		_win(flow)
		flow.continue_campaign()
	assert_eq(flow.screen_name(), "arcade_end")
	assert_eq(flow.back_to_title(), GameFlowService.Screen.TITLE)
	assert_eq(flow.fight_count(), 0, "a campanha foi desmontada")
	assert_null(flow.match_service())


func test_the_options_are_a_screen_over_the_current_one_and_return_to_it() -> void:
	var fx := _flow()
	var flow: GameFlowService = fx["flow"]
	flow.start()
	flow.select_guardian(GuardianStats.SACI)
	assert_eq(flow.open_options(), GameFlowService.Screen.OPTIONS)
	assert_eq(flow.screen_name(), "options")
	assert_eq(flow.close_options(), GameFlowService.Screen.FIGHT, "fechar volta para a Peleja")
