extends GutTest
## Golpe Especial do Saci: o Redemoinho e o efeito de puxao no Oponente.
##
## A regra de produto e a do CONTEXT.md: o Golpe Especial consome a Barra de
## Especial inteira e so dispara com a barra cheia. O Redemoinho acrescenta o
## efeito proprio da lenda -- o turbilhao suga o Oponente para dentro dele.


func test_the_table_gives_the_saci_the_redemoinho_with_pull() -> void:
	var effect := SpecialMoveTable.for_guardian(GuardianStats.SACI)
	assert_eq(effect.display_name, SpecialMove.REDEMOINHO)
	assert_true(effect.has_pull(), "o Redemoinho puxa o Oponente")
	assert_gt(effect.pull_reach, 0)


func test_a_guardian_outside_the_roster_has_no_registered_effect() -> void:
	var effect := SpecialMoveTable.for_guardian("Guardião de Fora do Elenco")
	assert_false(effect.has_effect())
	assert_eq(effect.display_name, "", "nome fora do elenco nao tem Golpe Especial cadastrado")
	assert_eq(
		SpecialMoveTable.display_name_for(GuardianStats.CURUPIRA),
		SpecialMove.PES_INVERTIDOS,
		"e o Curupira ja tem o efeito proprio dele (ticket 5)"
	)


func test_the_special_only_fires_with_a_full_meter_and_consumes_it_whole() -> void:
	var fighter := Fighter.new(GuardianStats.advantaged(GuardianStats.SACI))
	var move := Move.special(SpecialMoveTable.display_name_for(GuardianStats.SACI))
	assert_true(move.is_special())
	assert_false(fighter.start_special(move), "barra vazia nao dispara")
	assert_eq(fighter.meter.current, 0)
	fighter.meter.gain(SpecialMeter.MAX_UNITS - 1)
	assert_false(fighter.start_special(move), "quase cheia tambem nao dispara")
	fighter.meter.gain(1)
	assert_true(fighter.meter.is_full())
	assert_true(fighter.start_special(move), "com a barra cheia o Especial entra")
	assert_true(fighter.meter.is_empty(), "o Especial consome a Barra inteira")


func test_a_common_move_cannot_take_the_special_slot() -> void:
	var fighter := Fighter.new(GuardianStats.advantaged(GuardianStats.SACI))
	fighter.meter.gain(SpecialMeter.MAX_UNITS)
	assert_false(fighter.start_special(Move.light()), "golpe comum nao e Especial")
	assert_true(fighter.meter.is_full(), "e nao gasta a barra")


func test_the_redemoinho_pulls_the_opponent_into_the_vortex() -> void:
	var duel := Fighter.duel(GuardianStats.SACI, Archetype.Id.CAPATAZ, 5, 6)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	guardian.position.x = 100
	opponent.position.x = 140
	var effect := SpecialMoveTable.for_guardian(GuardianStats.SACI)
	var moved := effect.pull_target(guardian, opponent)
	assert_eq(moved, effect.pull_per_tick, "o alvo anda o puxao do tick")
	assert_eq(opponent.position.x, 140 - effect.pull_per_tick, "puxado para dentro do turbilhao")


func test_the_pull_does_not_reach_beyond_its_range() -> void:
	var duel := Fighter.duel(GuardianStats.SACI, Archetype.Id.CAPATAZ, 5, 6)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	guardian.position.x = 100
	opponent.position.x = 100 + effect_reach() + 1
	assert_eq(effect_reach_pull(guardian, opponent), 0, "fora do alcance o turbilhao nao puxa")
	assert_eq(opponent.position.x, 100 + effect_reach() + 1, "e o alvo nao se move")


func test_the_pull_never_drags_the_opponent_past_the_vortex() -> void:
	var duel := Fighter.duel(GuardianStats.SACI, Archetype.Id.CAPATAZ, 5, 6)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	guardian.position.x = 100
	opponent.position.x = 104
	var effect := SpecialMoveTable.for_guardian(GuardianStats.SACI)
	for tick in 20:
		effect.pull_target(guardian, opponent)
	assert_eq(opponent.position.x, 100, "o Oponente para no centro do turbilhao")


func test_a_guardian_without_effect_never_pulls() -> void:
	var duel := Fighter.duel(GuardianStats.SACI, Archetype.Id.CAPATAZ, 5, 6)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	guardian.position.x = 100
	opponent.position.x = 120
	var effect := SpecialMoveTable.for_guardian(GuardianStats.CURUPIRA)
	assert_eq(effect.pull_target(guardian, opponent), 0)
	assert_eq(opponent.position.x, 120, "o alvo nao se move")
	assert_eq(effect.pull_target(null, opponent), 0, "sem atacante nao ha puxao")


func test_pull_towards_clamps_the_fighter_to_the_stage() -> void:
	var duel := Fighter.duel(GuardianStats.SACI, Archetype.Id.CAPATAZ, 5, 6)
	var opponent: Fighter = duel["opponent"]
	opponent.position.x = Fighter.STAGE_MAX_X
	assert_eq(opponent.pull_towards(0, 3), 3, "puxado para dentro da arena")
	assert_eq(opponent.position.x, Fighter.STAGE_MAX_X - 3)
	assert_eq(opponent.pull_towards(opponent.position.x, 3), 0, "sem direcao nao anda")
	assert_eq(opponent.pull_towards(0, 0), 0, "puxao zero nao anda")
	opponent.position.x = Fighter.STAGE_MIN_X
	assert_eq(opponent.pull_towards(0, 5), 0, "no limite da arena nao ha para onde puxar")


func effect_reach() -> int:
	return SpecialMoveTable.for_guardian(GuardianStats.SACI).pull_reach


func effect_reach_pull(guardian: Fighter, opponent: Fighter) -> int:
	return SpecialMoveTable.for_guardian(GuardianStats.SACI).pull_target(guardian, opponent)
