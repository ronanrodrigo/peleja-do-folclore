extends GutTest
## Vantagem Oculta: o Guardiao sempre tem mais vida e mais dano que o Oponente.

func test_apply_boosts_health_and_damage() -> void:
	var base := GuardianStats.new(GuardianStats.SACI)
	var advantaged := HiddenAdvantage.apply(base)
	assert_eq(advantaged.max_health, roundi(base.max_health * HiddenAdvantage.HEALTH_FACTOR))
	assert_almost_eq(
		advantaged.damage_multiplier, base.damage_multiplier * HiddenAdvantage.DAMAGE_FACTOR, 0.0001
	)
	assert_gt(advantaged.max_health, base.max_health)
	assert_gt(advantaged.damage_multiplier, base.damage_multiplier)


func test_guardian_beats_every_archetype_on_health_and_damage() -> void:
	for guardian_name in [GuardianStats.SACI, GuardianStats.CURUPIRA, GuardianStats.IARA]:
		var guardian := GuardianStats.advantaged(guardian_name)
		for archetype in Archetype.ALL:
			var opponent := OpponentStats.for_archetype(archetype)
			assert_true(
				HiddenAdvantage.has_advantage(guardian, opponent),
				"%s tem Vantagem Oculta contra %s" % [guardian_name, opponent.display_name]
			)
			assert_gt(HiddenAdvantage.health_margin(guardian, opponent), 0)
			assert_gt(HiddenAdvantage.damage_margin(guardian, opponent), 0.0)


func test_no_advantage_when_the_numbers_are_equal() -> void:
	var one := GuardianStats.new()
	var other := GuardianStats.new()
	assert_false(HiddenAdvantage.has_advantage(one, other), "numeros iguais nao tem vantagem")
	assert_eq(HiddenAdvantage.health_margin(one, other), 0)
	assert_eq(HiddenAdvantage.damage_margin(one, other), 0.0)


func test_advantage_requires_both_health_and_damage() -> void:
	var guardian := FighterStats.new("Guardião", 2000, 0.5, 0.5)
	var opponent := FighterStats.new("Oponente", 1000, 1.0, 0.5)
	assert_true(HiddenAdvantage.health_margin(guardian, opponent) > 0)
	assert_true(HiddenAdvantage.damage_margin(guardian, opponent) < 0.0)
	assert_false(HiddenAdvantage.has_advantage(guardian, opponent), "so vida nao basta")


func test_advantage_is_proportional_and_not_visible_in_a_bar() -> void:
	var guardian := GuardianStats.advantaged(GuardianStats.SACI)
	var opponent := OpponentStats.for_archetype(Archetype.Id.CAPATAZ)
	var guardian_health := Health.new(guardian.max_health)
	var opponent_health := Health.new(opponent.max_health)
	assert_eq(guardian_health.ratio(), opponent_health.ratio(), "as duas barras comecam cheias")
