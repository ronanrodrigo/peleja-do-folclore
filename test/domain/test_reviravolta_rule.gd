extends GutTest
## A regra da Reviravolta no dominio (ADR 0003): dispara SE E SOMENTE SE o
## Oponente vence a Peleja; nunca quando o Guardiao vence; a campanha nunca acaba
## por derrota. Tudo regra pura -- nenhum adapter, nenhum I/O.

const LINES := 4


func test_the_reviravolta_triggers_when_the_opponent_wins_the_match() -> void:
	assert_true(
		ReviravoltaRule.triggers(MatchRules.Winner.OPPONENT),
		"Oponente vencendo a Peleja, a Reviravolta entra em cena"
	)


func test_the_reviravolta_never_triggers_when_the_guardian_wins() -> void:
	assert_false(
		ReviravoltaRule.triggers(MatchRules.Winner.GUARDIAN),
		"Guardião vencendo, a Forca Sobrenatural nao tem o que resolver"
	)


func test_it_never_triggers_without_a_winner() -> void:
	assert_false(ReviravoltaRule.triggers(MatchRules.Winner.NONE), "Peleja em andamento")
	assert_false(ReviravoltaRule.triggers(MatchRules.Winner.DRAW), "Peleja empatada")


func test_the_trigger_reads_the_match_winner_field_by_field() -> void:
	var winners := [
		MatchRules.Winner.NONE,
		MatchRules.Winner.GUARDIAN,
		MatchRules.Winner.OPPONENT,
		MatchRules.Winner.DRAW,
	]
	for winner in winners:
		assert_eq(
			ReviravoltaRule.triggers(winner),
			winner == MatchRules.Winner.OPPONENT,
			"so a vitoria do Oponente dispara (winner %d)" % winner
		)


func test_the_campaign_never_ends_by_losing_a_fight() -> void:
	for winner in [MatchRules.Winner.GUARDIAN, MatchRules.Winner.OPPONENT, MatchRules.Winner.DRAW]:
		assert_true(
			ReviravoltaRule.keeps_campaign_alive(winner),
			"a derrota de uma Peleja nao encerra a campanha (winner %d)" % winner
		)
	assert_false(ReviravoltaRule.triggers(MatchRules.Winner.GUARDIAN))


func test_the_scene_can_always_be_skipped() -> void:
	assert_true(ReviravoltaRule.can_skip(), "a cena nao pede interacao, mas pode ser pulada")
	assert_true(ReviravoltaRule.SKIPPABLE)


func test_the_voice_advances_one_line_per_second_of_ticks() -> void:
	assert_eq(ReviravoltaRule.line_index_for(0, LINES), 0, "a primeira linha aparece de cara")
	assert_eq(ReviravoltaRule.line_index_for(ReviravoltaRule.TICKS_PER_LINE - 1, LINES), 0)
	assert_eq(ReviravoltaRule.line_index_for(ReviravoltaRule.TICKS_PER_LINE, LINES), 1)
	assert_eq(ReviravoltaRule.line_index_for(ReviravoltaRule.TICKS_PER_LINE * 3, LINES), 3)
	assert_eq(
		ReviravoltaRule.line_index_for(ReviravoltaRule.TICKS_PER_LINE * LINES, LINES),
		-1,
		"passada a voz, a sequencia de texto acabou"
	)
	assert_eq(ReviravoltaRule.line_index_for(0, 0), -1, "sem linhas, nao ha texto")
	assert_eq(ReviravoltaRule.line_index_for(-5, LINES), -1, "cena parada nao mostra linha")


func test_the_phases_run_voice_wind_root_dissolve_and_done() -> void:
	var voice := ReviravoltaRule.TICKS_PER_LINE * LINES
	var third := ReviravoltaRule.DISSOLVE_TICKS / 3
	assert_eq(ReviravoltaRule.phase_for(-1, LINES), ReviravoltaRule.Phase.IDLE)
	assert_eq(ReviravoltaRule.phase_for(0, LINES), ReviravoltaRule.Phase.VOICE)
	assert_eq(ReviravoltaRule.phase_for(voice - 1, LINES), ReviravoltaRule.Phase.VOICE)
	assert_eq(ReviravoltaRule.phase_for(voice, LINES), ReviravoltaRule.Phase.WIND)
	assert_eq(ReviravoltaRule.phase_for(voice + third, LINES), ReviravoltaRule.Phase.ROOT)
	assert_eq(ReviravoltaRule.phase_for(voice + third * 2, LINES), ReviravoltaRule.Phase.DISSOLVE)
	assert_eq(ReviravoltaRule.phase_for(voice + ReviravoltaRule.DISSOLVE_TICKS, LINES), ReviravoltaRule.Phase.DONE)
	assert_eq(ReviravoltaRule.total_ticks(LINES), voice + ReviravoltaRule.DISSOLVE_TICKS)
	assert_eq(ReviravoltaRule.phase_name(ReviravoltaRule.Phase.ROOT), "root")
	assert_eq(ReviravoltaRule.phase_name(ReviravoltaRule.Phase.DONE), "done")


func test_the_scene_finishes_only_after_the_dissolve() -> void:
	var total := ReviravoltaRule.total_ticks(LINES)
	assert_false(ReviravoltaRule.is_finished(total - 1, LINES))
	assert_true(ReviravoltaRule.is_finished(total, LINES))
	assert_true(ReviravoltaRule.is_finished(total + 60, LINES), "depois do fim, continua acabada")
	assert_eq(ReviravoltaRule.total_ticks(0), ReviravoltaRule.DISSOLVE_TICKS, "sem texto, so o efeito")


func test_the_opponent_is_dissolved_only_at_the_end() -> void:
	assert_false(ReviravoltaRule.opponent_dissolved(0, LINES), "na voz ainda nao")
	assert_false(
		ReviravoltaRule.opponent_dissolved(
			ReviravoltaRule.TICKS_PER_LINE * LINES + 1, LINES
		),
		"no vento ainda nao"
	)
	var voice := ReviravoltaRule.TICKS_PER_LINE * LINES
	var third := ReviravoltaRule.DISSOLVE_TICKS / 3
	assert_true(ReviravoltaRule.opponent_dissolved(voice + third * 2 + 1, LINES))
	assert_true(ReviravoltaRule.opponent_dissolved(ReviravoltaRule.total_ticks(LINES), LINES))
