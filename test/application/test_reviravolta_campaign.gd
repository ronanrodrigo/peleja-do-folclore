extends GutTest
## Reviravolta e campanha: quando o Oponente vence uma Peleja do arcade, a cena
## da Reviravolta entra em cena -- e o arcade SEGUE para a proxima Peleja. Nunca
## ha game over de campanha por derrota (ADR 0003).
##
## Adapters `sample`: nenhum I/O, nenhum teclado sintetico; a vitoria de cada lado
## e forcada pela API publica do dominio (zerar a vida do perdedor).

const MAX_TICKS_PER_FIGHT := 600
const GUARDIAN_SEED := 31
const OPPONENT_SEED := 41


func _fixture() -> Dictionary:
	var asset := InMemoryAssetGateway.new()
	var render := SampleRenderGateway.new()
	var audio := SilentAudioGateway.new()
	var persistence := InMemoryPersistenceGateway.new()
	var arcade := ArcadeService.new(SampleInputGateway.new(), render, asset, audio)
	return {
		"arcade": arcade,
		"reviravolta": ReviravoltaService.new(asset, render, audio, persistence),
		"persistence": persistence,
	}


## Fecha a Peleja corrente com um lado perdendo os rounds (nocaute e o caminho
## mais curto e nao depende da sorte da IA).
func _finish_current_fight(arcade: ArcadeService, loser: Fighter) -> int:
	var ticks := 0
	while not arcade.match_service.is_match_over() and ticks < MAX_TICKS_PER_FIGHT:
		var fight: MatchService = arcade.match_service
		if fight.phase == MatchService.Phase.ROUND_ACTIVE:
			loser.health.apply_damage(loser.health.max_value)
		arcade.advance_tick()
		ticks += 1
	return ticks


func test_the_opponent_winning_a_fight_asks_for_the_reviravolta() -> void:
	var fx := _fixture()
	var arcade: ArcadeService = fx["arcade"]
	assert_true(arcade.execute([], GuardianStats.SACI, GUARDIAN_SEED, OPPONENT_SEED))
	assert_false(arcade.requires_reviravolta(), "Peleja em andamento nao pede Reviravolta")
	_finish_current_fight(arcade, arcade.match_service.guardian)
	assert_eq(arcade.match_service.winner(), MatchRules.Winner.OPPONENT, "o Oponente venceu")
	assert_true(arcade.requires_reviravolta(), "Peleja perdida: a Reviravolta entra em cena")
	assert_eq(arcade.results.size(), 1)
	assert_eq(arcade.results[0]["winner"], MatchRules.Winner.OPPONENT)
	assert_eq(arcade.results[0]["slug"], arcade.opponent_slug(), "o resultado e o do Arquetipo")


func test_the_guardian_winning_never_asks_for_the_reviravolta() -> void:
	var fx := _fixture()
	var arcade: ArcadeService = fx["arcade"]
	assert_true(arcade.execute([], GuardianStats.CURUPIRA, GUARDIAN_SEED, OPPONENT_SEED))
	_finish_current_fight(arcade, arcade.match_service.opponent)
	assert_eq(arcade.match_service.winner(), MatchRules.Winner.GUARDIAN)
	assert_false(arcade.requires_reviravolta(), "Guardião vencendo, nao ha Reviravolta")
	assert_eq(arcade.results[0]["winner"], MatchRules.Winner.GUARDIAN)


func test_after_the_reviravolta_the_arcade_goes_on_to_the_next_fight() -> void:
	var fx := _fixture()
	var arcade: ArcadeService = fx["arcade"]
	var reviravolta: ReviravoltaService = fx["reviravolta"]
	assert_true(arcade.execute([], GuardianStats.SACI, GUARDIAN_SEED, OPPONENT_SEED))
	_finish_current_fight(arcade, arcade.match_service.guardian)
	assert_eq(arcade.fight_number(), 1)
	var winner := arcade.match_service.winner()
	assert_true(
		reviravolta.execute(winner, PanelAdapter.LINES.size(), arcade.fight_number()),
		"a Reviravolta entra em cena na Peleja perdida"
	)
	reviravolta.skip()
	assert_true(reviravolta.is_finished(), "a cena terminou")
	assert_true(reviravolta.snapshot()["campaign_continues"], "a campanha segue viva")
	assert_false(arcade.is_arcade_complete(), "perder uma Peleja nao encerra o arcade")
	assert_true(arcade.advance(), "o arcade segue para a proxima Peleja")
	assert_eq(arcade.fight_number(), 2, "a segunda Peleja comeca depois da Reviravolta")
	assert_false(arcade.requires_reviravolta(), "Peleja nova em andamento")
	assert_eq(arcade.results.size(), 1, "a Peleja perdida ficou registrada")
	assert_eq(fx["persistence"].load_value(ReviravoltaService.CAMPAIGN_KEY, {})["fight"], 1)


func test_the_arcade_runs_all_seven_fights_even_after_losing_the_first() -> void:
	var fx := _fixture()
	var arcade: ArcadeService = fx["arcade"]
	var reviravolta: ReviravoltaService = fx["reviravolta"]
	assert_true(arcade.execute([], GuardianStats.IARA, GUARDIAN_SEED, OPPONENT_SEED))
	for position in 7:
		var fight: MatchService = arcade.match_service
		if position == 0:
			_finish_current_fight(arcade, fight.guardian)
			assert_true(arcade.requires_reviravolta(), "a primeira Peleja foi perdida")
			assert_true(
				reviravolta.execute(
					fight.winner(), PanelAdapter.LINES.size(), arcade.fight_number()
				)
			)
		else:
			_finish_current_fight(arcade, fight.opponent)
			assert_false(arcade.requires_reviravolta(), "as outras Pelejas foram ganhas")
		if position < 6:
			assert_true(arcade.advance(), "o arcade avanca apos a Peleja %d" % (position + 1))
			assert_false(arcade.is_arcade_complete())
	assert_true(arcade.is_arcade_complete(), "as sete Pelejas foram jogadas")
	assert_eq(arcade.results.size(), 7)
	assert_eq(arcade.results[0]["winner"], MatchRules.Winner.OPPONENT, "a primeira foi perdida")
	assert_false(arcade.advance(), "nao ha oitava Peleja")
	assert_true(arcade.snapshot()["complete"])
