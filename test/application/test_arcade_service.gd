extends GutTest
## O `arcade-service`: as 7 Pelejas, uma por Arquetipo, em ordem FIXA (dado
## injetado, ADR 0007) e dificuldade crescente, com o Guardiao chegando como
## dado/comando do chamador. Adapters `sample`: nenhum I/O.

const MAX_TICKS_PER_FIGHT := 600
const GUARDIAN_SEED := 31
const OPPONENT_SEED := 41


func _service() -> Dictionary:
	var input := SampleInputGateway.new()
	var render := SampleRenderGateway.new()
	var asset := InMemoryAssetGateway.new()
	var audio := SilentAudioGateway.new()
	return {
		"arcade": ArcadeService.new(input, render, asset, audio),
		"input": input,
		"render": render,
		"audio": audio,
	}


## Fecha a Peleja corrente derrubando o Oponente duas vezes (nocaute e a via
## rapida do round); usa so a API publica do dominio.
func _win_current_fight(arcade: ArcadeService) -> int:
	var ticks := 0
	while not arcade.match_service.is_match_over() and ticks < MAX_TICKS_PER_FIGHT:
		var fight := arcade.match_service
		if fight.phase == MatchService.Phase.ROUND_ACTIVE:
			fight.opponent.health.apply_damage(fight.opponent.health.current)
		arcade.advance_tick()
		ticks += 1
	return ticks


func test_the_order_comes_from_the_caller_as_data() -> void:
	var fx := _service()
	var arcade: ArcadeService = fx["arcade"]
	assert_true(arcade.execute(), "a ordem fixa do ADR 0007 entra por padrao")
	assert_eq(arcade.order, ArcadeOrder.ORDER, "e o dado do ADR, nao uma copia no servico")
	assert_eq(arcade.fight_count(), 7)
	assert_eq(arcade.fight_number(), 1, "comeca na primeira Peleja")


func test_the_sequence_of_seven_is_verified_against_the_data() -> void:
	var fx := _service()
	var arcade: ArcadeService = fx["arcade"]
	arcade.execute()
	assert_eq(arcade.fight_count(), ArcadeOrder.count())
	for position in 7:
		assert_eq(arcade.index, position, "posicao base zero")
		assert_eq(arcade.current_archetype(), ArcadeOrder.archetype_at(position))
		assert_eq(arcade.opponent_slug(), ArcadeOrder.slugs()[position])
		assert_eq(arcade.current_profile().slug, arcade.opponent_slug())
		assert_eq(
			arcade.match_service.opponent_profile.archetype,
			ArcadeOrder.archetype_at(position),
			"a Peleja montada e a do dado"
		)
		if position < 6:
			_win_current_fight(arcade)
			assert_true(arcade.advance(), "monta a proxima Peleja da sequencia")
	assert_eq(arcade.opponent_slugs().size(), 7)


func test_an_injected_order_is_followed_instead_of_a_hardcoded_one() -> void:
	var fx := _service()
	var arcade: ArcadeService = fx["arcade"]
	var reversed: Array = ArcadeOrder.ORDER.duplicate()
	reversed.reverse()
	assert_true(arcade.execute(reversed), "a ordem do chamador e aceita")
	assert_eq(arcade.order, reversed, "e usada como veio")
	assert_eq(arcade.current_archetype(), Archetype.Id.FALSO_PASTOR, "primeira Peleja trocada")
	assert_eq(arcade.fight_count(), 7)
	assert_eq(arcade.difficulty_for(0), OpponentAi.Difficulty.EASY)


func test_an_order_that_does_not_cover_the_seven_is_refused() -> void:
	var fx := _service()
	var arcade: ArcadeService = fx["arcade"]
	assert_false(arcade.execute([Archetype.Id.CAPATAZ]), "faltam Oponentes")
	var repeated: Array = [
		Archetype.Id.CAPATAZ,
		Archetype.Id.CAPATAZ,
		Archetype.Id.REDPILL,
		Archetype.Id.CAMISA_VERDE,
		Archetype.Id.DOUTOR_PUREZA,
		Archetype.Id.FANTASMA_DO_REICH,
		Archetype.Id.FALSO_PASTOR,
	]
	assert_false(arcade.execute(repeated), "Arquetipo repetido nao passa")
	assert_eq(arcade.fight_count(), 0, "o servico fica desmontado")
	assert_eq(arcade.fight_number(), 0)
	assert_eq(arcade.current_archetype(), -1)
	assert_true(arcade.is_valid_order(ArcadeOrder.ORDER))


func test_the_difficulty_grows_along_the_arcade() -> void:
	var fx := _service()
	var arcade: ArcadeService = fx["arcade"]
	arcade.execute()
	var previous_difficulty := -1
	var previous_health := 0
	for position in 7:
		var difficulty := arcade.difficulty_for(position)
		assert_true(
			difficulty >= previous_difficulty,
			"a escada de IA nunca desce (posicao %d)" % position
		)
		previous_difficulty = difficulty
		var stats := OpponentStats.for_archetype(ArcadeOrder.archetype_at(position))
		assert_gt(
			stats.max_health,
			previous_health,
			"a vida do Oponente cresce (posicao %d)" % position
		)
		previous_health = stats.max_health
	assert_eq(arcade.difficulty_for(0), OpponentAi.Difficulty.EASY)
	assert_eq(arcade.difficulty_for(6), OpponentAi.Difficulty.HARD)
	assert_eq(arcade.difficulty_for(99), OpponentAi.Difficulty.NORMAL, "fora da escada: normal")


func test_each_fight_brings_the_profile_and_the_ai_of_its_archetype() -> void:
	var fx := _service()
	var arcade: ArcadeService = fx["arcade"]
	arcade.execute()
	var slugs: Array = []
	var signatures: Array = []
	for position in 7:
		var fight := arcade.match_service
		var profile := arcade.current_profile()
		assert_eq(fight.opponent_profile.archetype, ArcadeOrder.archetype_at(position))
		assert_eq(fight.opponent_signature.display_name, profile.signature_name)
		assert_eq(fight.snapshot()["opponent_slug"], profile.slug)
		assert_eq(fight.ai.value_of("aggression"), profile.ai_value("aggression"))
		slugs.append(profile.slug)
		signatures.append(profile.signature_name)
		if position < 6:
			_win_current_fight(arcade)
			assert_true(arcade.advance(), "avanca para a proxima Peleja")
	assert_eq(slugs.size(), 7)
	assert_eq(signatures.size(), 7)


func test_the_guardian_arrives_as_data_and_as_a_command() -> void:
	var fx := _service()
	var arcade: ArcadeService = fx["arcade"]
	assert_true(arcade.select_guardian(GuardianStats.CURUPIRA), "comando de selecao")
	assert_true(arcade.execute([], GuardianStats.CURUPIRA))
	assert_eq(arcade.guardian_name, GuardianStats.CURUPIRA, "o Guardiao escolhido e dado")
	assert_eq(arcade.match_service.guardian.stats.display_name, GuardianStats.CURUPIRA)
	assert_false(arcade.select_guardian(""), "selecao vazia nao muda nada")
	assert_eq(arcade.snapshot()["guardian"], GuardianStats.CURUPIRA)


func test_a_full_arcade_runs_all_seven_fights_and_records_each_result() -> void:
	var fx := _service()
	var arcade: ArcadeService = fx["arcade"]
	assert_true(arcade.execute([], GuardianStats.SACI, GUARDIAN_SEED, OPPONENT_SEED))
	for position in 7:
		assert_eq(arcade.fight_number(), position + 1, "Peleja numero %d" % (position + 1))
		assert_false(arcade.is_arcade_complete())
		_win_current_fight(arcade)
		assert_eq(arcade.results.size(), position + 1, "o resultado entra uma vez so")
		assert_eq(arcade.results[position]["slug"], ArcadeOrder.slugs()[position])
		assert_eq(arcade.results[position]["winner"], MatchRules.Winner.GUARDIAN)
		if position < 6:
			assert_false(arcade.is_arcade_complete())
			assert_true(arcade.advance(), "o arcade segue para a proxima Peleja")
	assert_true(arcade.is_arcade_complete(), "as sete Pelejas foram jogadas")
	assert_eq(arcade.results.size(), 7)
	assert_false(arcade.advance(), "nao ha oitava Peleja: o arcade tem sete")
	var render: SampleRenderGateway = fx["render"]
	arcade.render_frame()
	assert_gt(render.frames_presented, 0, "o arcade desenha pelo render-gateway")
	var audio: SilentAudioGateway = fx["audio"]
	assert_true(audio.music_calls.has("fight"), "a musica da Peleja tocou")


func test_advance_refuses_while_the_fight_is_running() -> void:
	var fx := _service()
	var arcade: ArcadeService = fx["arcade"]
	arcade.execute()
	assert_false(arcade.advance(), "Peleja em andamento nao pula de fase")
	assert_eq(arcade.fight_number(), 1)
	var input: SampleInputGateway = fx["input"]
	input.script_commands([InputGateway.Command.HEAVY])
	arcade.advance_tick()
	assert_true(arcade.snapshot()["match"].has("phase"), "o retrato traz a Peleja corrente")


func test_the_arcade_is_deterministic_for_the_same_seeds() -> void:
	var first := _scripted_run()
	var second := _scripted_run()
	assert_gt(first.size(), 0)
	assert_eq(first, second, "mesmas sementes e mesmos comandos -> mesmo arcade")


func _scripted_run() -> Array:
	var fx := _service()
	var arcade: ArcadeService = fx["arcade"]
	var input: SampleInputGateway = fx["input"]
	arcade.execute([], GuardianStats.SACI, GUARDIAN_SEED, OPPONENT_SEED)
	var log: Array = []
	for tick in 400:
		input.script_commands([InputGateway.Command.HEAVY])
		log.append(arcade.advance_tick())
	return log
