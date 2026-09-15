extends GutTest
## Oponentes do arcade: um perfil por Arquetipo, em dificuldade crescente.

func test_every_archetype_has_an_opponent() -> void:
	for archetype in Archetype.ALL:
		var opponent := OpponentStats.for_archetype(archetype)
		assert_not_null(opponent, "Oponente de %s existe" % Archetype.slug(archetype))
		assert_eq(opponent.display_name, Archetype.display_name(archetype))
		assert_eq(opponent.arcade_index, Archetype.index_of(archetype))


func test_unknown_archetype_has_no_opponent() -> void:
	assert_null(OpponentStats.for_archetype(-1), "Arquetipo invalido nao gera Oponente")
	assert_null(OpponentStats.for_archetype(99))


func test_difficulty_grows_along_the_arcade() -> void:
	var roster := OpponentStats.arcade_roster()
	assert_eq(roster.size(), ArcadeOrder.count())
	for index in range(1, roster.size()):
		var previous: FighterStats = roster[index - 1]
		var current: FighterStats = roster[index]
		assert_gt(current.max_health, previous.max_health, "round %d aguenta mais" % index)
		assert_gt(current.damage_multiplier, previous.damage_multiplier)


func test_first_and_last_opponent_numbers_come_from_the_steps() -> void:
	var first := OpponentStats.for_archetype(Archetype.Id.CAPATAZ)
	var last := OpponentStats.for_archetype(Archetype.Id.FALSO_PASTOR)
	assert_eq(first.max_health, OpponentStats.BASE_HEALTH)
	assert_eq(last.max_health, OpponentStats.BASE_HEALTH + OpponentStats.HEALTH_STEP * 6)
	var expected_multiplier := OpponentStats.BASE_DAMAGE_MULTIPLIER + OpponentStats.DAMAGE_STEP * 6.0
	assert_almost_eq(last.damage_multiplier, expected_multiplier, 0.0001)


func test_even_the_last_opponent_is_weaker_than_the_guardian() -> void:
	var guardian := GuardianStats.new()
	var last := OpponentStats.for_archetype(Archetype.Id.FALSO_PASTOR)
	assert_lt(last.max_health, guardian.max_health, "nenhum Oponente alcanca o Guardiao")


func test_arcade_roster_follows_the_fixed_order() -> void:
	var roster := OpponentStats.arcade_roster()
	for index in range(roster.size()):
		var opponent: FighterStats = roster[index]
		assert_eq(
			opponent.display_name,
			Archetype.display_name(ArcadeOrder.archetype_at(index)),
			"posicao %d do arcade" % index
		)
