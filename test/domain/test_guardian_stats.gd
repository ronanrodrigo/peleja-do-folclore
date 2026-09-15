extends GutTest
## Numeros do Guardiao, antes e depois da Vantagem Oculta.

func test_default_guardian_is_the_saci() -> void:
	var guardian := GuardianStats.new()
	assert_eq(guardian.display_name, GuardianStats.SACI)
	assert_eq(guardian.max_health, GuardianStats.BASE_HEALTH)
	assert_almost_eq(guardian.damage_multiplier, GuardianStats.BASE_DAMAGE_MULTIPLIER, 0.0001)


func test_named_guardian_keeps_the_same_numbers() -> void:
	var curupira := GuardianStats.for_guardian(GuardianStats.CURUPIRA)
	assert_eq(curupira.display_name, GuardianStats.CURUPIRA)
	assert_eq(curupira.max_health, GuardianStats.BASE_HEALTH)


func test_advantaged_guardian_has_hidden_bonus_applied() -> void:
	var advantaged := GuardianStats.advantaged(GuardianStats.SACI)
	assert_eq(advantaged.max_health, roundi(GuardianStats.BASE_HEALTH * HiddenAdvantage.HEALTH_FACTOR))
	assert_almost_eq(
		advantaged.damage_multiplier,
		GuardianStats.BASE_DAMAGE_MULTIPLIER * HiddenAdvantage.DAMAGE_FACTOR,
		0.0001
	)
	assert_eq(advantaged.display_name, GuardianStats.SACI)


func test_guardian_hits_harder_than_the_opponent() -> void:
	var guardian := GuardianStats.new()
	for archetype in Archetype.ALL:
		var opponent := OpponentStats.for_archetype(archetype)
		assert_gt(
			guardian.damage_for(Move.heavy()),
			opponent.damage_for(Move.heavy()),
			"Guardião machuca mais que %s" % opponent.display_name
		)
