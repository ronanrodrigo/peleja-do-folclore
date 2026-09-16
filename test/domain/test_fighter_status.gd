extends GutTest
## O conjunto de status do lutador (`FighterStatus`): sono tira o controle e o
## lado trocado espelha o movimento.
##
## O lutador mantem a mesma superficie publica de antes; o estado dos status vive
## no objeto proprio, avancado por tick de simulacao.

const SEED := 20260915


func _fighter(x: int = 100) -> Fighter:
	return Fighter.new(GuardianStats.advantaged(GuardianStats.SACI), Rng.new(SEED), x, 1)


func test_a_new_fighter_has_no_status() -> void:
	var fighter := _fighter()
	assert_eq(fighter.statuses.count(), 0)
	assert_false(fighter.statuses.is_asleep())
	assert_false(fighter.statuses.inverts_controls())
	assert_true(fighter.can_act(), "sem status o lutador age normalmente")


func test_sleep_takes_the_control_away_until_it_ends() -> void:
	var fighter := _fighter()
	fighter.statuses.add(StatusEffect.new(StatusEffect.Kind.SLEEP, 2))
	assert_true(fighter.statuses.is_asleep())
	assert_true(fighter.statuses.has(StatusEffect.Kind.SLEEP))
	assert_eq(fighter.statuses.remaining(StatusEffect.Kind.SLEEP), 2)
	assert_false(fighter.can_act(), "adormecido nao aceita comando nenhum")
	assert_false(fighter.walk(1), "e nao anda")
	assert_false(fighter.block(), "nem defende")
	assert_false(fighter.start_move(Move.light()), "nem ataca")
	fighter.advance_tick()
	fighter.advance_tick()
	assert_false(fighter.statuses.is_asleep(), "o sono acaba em ticks de simulacao")
	assert_true(fighter.can_act(), "e o lutador volta a responder")


func test_a_status_at_zero_ticks_is_not_added() -> void:
	var fighter := _fighter()
	fighter.statuses.add(StatusEffect.new(StatusEffect.Kind.SLEEP, 0))
	assert_eq(fighter.statuses.count(), 0, "duracao zero nao cria status")


func test_the_same_status_refreshes_instead_of_stacking() -> void:
	var fighter := _fighter()
	fighter.statuses.add(StatusEffect.new(StatusEffect.Kind.INVERT_CONTROLS, 10))
	fighter.advance_tick()
	fighter.statuses.add(StatusEffect.new(StatusEffect.Kind.INVERT_CONTROLS, 10))
	assert_eq(fighter.statuses.count(), 1, "dois golpes iguais nao empilham")
	assert_eq(fighter.statuses.remaining(StatusEffect.Kind.INVERT_CONTROLS), 10, "e renovam")
	fighter.statuses.add(StatusEffect.new(StatusEffect.Kind.SLEEP, 5))
	assert_eq(fighter.statuses.count(), 2, "status de tipos diferentes convivem")
	assert_eq(fighter.statuses.names().size(), 2)


func test_the_inverted_side_mirrors_walking() -> void:
	var fighter := _fighter(100)
	assert_true(fighter.walk(1))
	assert_eq(fighter.position.x, 100 + fighter.stats.walk_speed, "sem status, anda para a direita")
	fighter.statuses.add(StatusEffect.new(StatusEffect.Kind.INVERT_CONTROLS, 30))
	var before := fighter.position.x
	assert_true(fighter.walk(1))
	assert_eq(
		fighter.position.x,
		before - fighter.stats.walk_speed,
		"com os Pes Invertidos, pedir direita anda para a esquerda"
	)
	assert_true(fighter.walk(-1))
	assert_eq(
		fighter.position.x,
		before,
		"e pedir esquerda anda para a direita (o movimento e espelhado)"
	)


func test_clear_and_reset_drop_every_status() -> void:
	var fighter := _fighter()
	fighter.statuses.add(StatusEffect.new(StatusEffect.Kind.SLEEP, 30))
	fighter.statuses.add(StatusEffect.new(StatusEffect.Kind.INVERT_CONTROLS, 30))
	assert_eq(fighter.statuses.count(), 2)
	fighter.reset_for_round()
	assert_eq(fighter.statuses.count(), 0, "o proximo round comeca limpo")
	assert_true(fighter.can_act())


func test_statuses_are_advanced_even_during_a_move() -> void:
	var fighter := _fighter()
	fighter.statuses.add(StatusEffect.new(StatusEffect.Kind.SLEEP, 2))
	fighter.start_move(Move.heavy())
	fighter.advance_tick()
	fighter.advance_tick()
	assert_false(fighter.statuses.is_asleep(), "o status corre enquanto o golpe anda")