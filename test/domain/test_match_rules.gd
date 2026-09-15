extends GutTest
## Melhor de tres: nocaute, tempo esgotado, 2-0, 2-1 e empate de rounds.

func test_register_refuses_invalid_results() -> void:
	var rules := MatchRules.new()
	assert_false(rules.register_round(MatchRules.RoundResult.UNRESOLVED))
	assert_false(rules.register_round(99))
	assert_eq(rules.rounds_played(), 0)


func test_two_zero() -> void:
	var rules := MatchRules.new()
	assert_true(rules.register_round(MatchRules.RoundResult.GUARDIAN))
	assert_false(rules.is_decided(), "um round nao fecha a Peleja")
	assert_eq(rules.winner(), MatchRules.Winner.NONE)
	assert_true(rules.register_round(MatchRules.RoundResult.GUARDIAN))
	assert_true(rules.is_decided())
	assert_eq(rules.winner(), MatchRules.Winner.GUARDIAN)
	assert_eq(rules.rounds_played(), 2, "2-0 fecha em dois rounds")
	assert_eq(rules.opponent_rounds(), 0)
	assert_false(
		rules.register_round(MatchRules.RoundResult.GUARDIAN), "Peleja decidida nao aceita round"
	)


func test_two_one() -> void:
	var rules := MatchRules.new()
	rules.register_round(MatchRules.RoundResult.GUARDIAN)
	rules.register_round(MatchRules.RoundResult.OPPONENT)
	assert_false(rules.is_decided())
	assert_true(rules.register_round(MatchRules.RoundResult.GUARDIAN))
	assert_eq(rules.rounds_played(), 3, "2-1 usa os tres rounds")
	assert_eq(rules.winner(), MatchRules.Winner.GUARDIAN)
	assert_eq(rules.guardian_rounds(), 2)
	assert_eq(rules.opponent_rounds(), 1)


func test_opponent_can_win_two_zero() -> void:
	var rules := MatchRules.new()
	rules.register_round(MatchRules.RoundResult.OPPONENT)
	rules.register_round(MatchRules.RoundResult.OPPONENT)
	assert_true(rules.is_decided())
	assert_eq(
		rules.winner(), MatchRules.Winner.OPPONENT, "a Peleja pode ser perdida (Reviravolta decide)"
	)


func test_drawn_match() -> void:
	var rules := MatchRules.new()
	rules.register_round(MatchRules.RoundResult.GUARDIAN)
	rules.register_round(MatchRules.RoundResult.OPPONENT)
	rules.register_round(MatchRules.RoundResult.DRAW)
	assert_true(rules.is_decided(), "três rounds sem dois vencedores fecha empatado")
	assert_eq(rules.winner(), MatchRules.Winner.DRAW)
	assert_eq(rules.draw_rounds(), 1)
	assert_eq(rules.guardian_rounds(), 1)
	assert_eq(rules.opponent_rounds(), 1)


func test_rounds_are_readable_by_index() -> void:
	var rules := MatchRules.new()
	rules.register_round(MatchRules.RoundResult.OPPONENT)
	rules.register_round(MatchRules.RoundResult.GUARDIAN)
	assert_eq(rules.round_result(0), MatchRules.RoundResult.OPPONENT)
	assert_eq(rules.round_result(1), MatchRules.RoundResult.GUARDIAN)
	assert_eq(rules.round_result(7), MatchRules.RoundResult.UNRESOLVED)
	assert_eq(rules.results().size(), 2)
	var copy := rules.results()
	copy.append(MatchRules.RoundResult.DRAW)
	assert_eq(rules.rounds_played(), 2, "a copia nao altera a Peleja")


func test_reset_clears_the_match() -> void:
	var rules := MatchRules.new()
	rules.register_round(MatchRules.RoundResult.GUARDIAN)
	rules.register_round(MatchRules.RoundResult.GUARDIAN)
	rules.reset()
	assert_eq(rules.rounds_played(), 0)
	assert_false(rules.is_decided())
	assert_eq(rules.winner(), MatchRules.Winner.NONE)


func test_knockout_decides_the_round() -> void:
	var guardian := _fighter(300)
	var opponent := _fighter(300)
	var clock := RoundClock.new(1)
	assert_eq(
		MatchRules.resolve_round(guardian, opponent, clock),
		MatchRules.RoundResult.UNRESOLVED,
		"round em andamento nao tem resultado"
	)
	opponent.health.apply_damage(300)
	assert_eq(
		MatchRules.resolve_round(guardian, opponent, clock),
		MatchRules.RoundResult.GUARDIAN,
		"zerar a vida do Oponente vence o round"
	)


func test_double_knockout_draws_the_round() -> void:
	var guardian := _fighter(300)
	var opponent := _fighter(300)
	guardian.health.apply_damage(300)
	opponent.health.apply_damage(300)
	assert_eq(
		MatchRules.resolve_round(guardian, opponent, RoundClock.new(1)),
		MatchRules.RoundResult.DRAW
	)


func test_time_out_decides_by_remaining_health() -> void:
	var clock := RoundClock.new(1)
	clock.advance(RoundClock.TICKS_PER_SECOND)
	var guardian := _fighter(300)
	var opponent := _fighter(300)
	opponent.health.apply_damage(120)
	assert_eq(MatchRules.resolve_round(guardian, opponent, clock), MatchRules.RoundResult.GUARDIAN)
	assert_eq(MatchRules.resolve_round(opponent, guardian, clock), MatchRules.RoundResult.OPPONENT)


func test_time_out_with_equal_health_draws() -> void:
	var clock := RoundClock.new(1)
	clock.advance(RoundClock.TICKS_PER_SECOND)
	var guardian := _fighter(300)
	var opponent := _fighter(300)
	guardian.health.apply_damage(50)
	opponent.health.apply_damage(50)
	assert_true(clock.is_expired())
	assert_eq(MatchRules.resolve_round(guardian, opponent, clock), MatchRules.RoundResult.DRAW)


func test_resolving_a_drawn_round_without_time_out() -> void:
	var clock := RoundClock.new(1)
	var guardian := _fighter(300)
	var opponent := _fighter(300)
	guardian.health.apply_damage(50)
	opponent.health.apply_damage(50)
	assert_eq(
		MatchRules.resolve_round(guardian, opponent, clock),
		MatchRules.RoundResult.UNRESOLVED,
		"vida igual com o tempo correndo ainda nao e empate"
	)


func test_resolve_round_refuses_empty_input() -> void:
	var guardian := _fighter(300)
	assert_eq(
		MatchRules.resolve_round(guardian, null, RoundClock.new(1)),
		MatchRules.RoundResult.UNRESOLVED
	)
	assert_eq(MatchRules.resolve_round(null, guardian, null), MatchRules.RoundResult.UNRESOLVED)


func test_a_round_result_feeds_the_match() -> void:
	var rules := MatchRules.new()
	var clock := RoundClock.new(1)
	var guardian := _fighter(300)
	var opponent := _fighter(300)
	opponent.health.apply_damage(80)
	clock.advance(RoundClock.TICKS_PER_SECOND)
	assert_true(rules.register_round(MatchRules.resolve_round(guardian, opponent, clock)))
	assert_eq(rules.guardian_rounds(), 1)


func _fighter(p_health: int) -> Fighter:
	var stats := FighterStats.new("teste", p_health, 1.0, 0.5, 3, 10, 10)
	return Fighter.new(stats, Rng.new(1), 200, 1)
