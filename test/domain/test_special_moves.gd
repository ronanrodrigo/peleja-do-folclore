extends GutTest
## Os Golpes Especiais dos tres Guardioes novos, derivados da lenda:
## Pes Invertidos (Curupira), Canto do Rio (Iara) e Nana Nenem (Cuca).
##
## Cada especial tem o proprio teste: inversao de comandos, drenagem de vida e
## sono. O efeito e dado puro da `SpecialMoveTable` e a aplicacao acontece na
## janela ativa do golpe, por tick de simulacao.

const SEED_GUARDIAN := 5
const SEED_OPPONENT := 6


func _duel(guardian_name: String) -> Dictionary:
	return Fighter.duel(guardian_name, Archetype.Id.CAPATAZ, SEED_GUARDIAN, SEED_OPPONENT)


func test_the_roster_has_one_special_per_guardian_with_the_legend_name() -> void:
	assert_eq(SpecialMoveTable.display_name_for(GuardianStats.SACI), SpecialMove.REDEMOINHO)
	assert_eq(
		SpecialMoveTable.display_name_for(GuardianStats.CURUPIRA), SpecialMove.PES_INVERTIDOS
	)
	assert_eq(SpecialMoveTable.display_name_for(GuardianStats.IARA), SpecialMove.CANTO_DO_RIO)
	assert_eq(SpecialMoveTable.display_name_for(GuardianStats.CUCA), SpecialMove.NANA_NENEM)
	var names := {}
	for guardian_name in GuardianStats.all():
		var effect := SpecialMoveTable.for_guardian(guardian_name)
		assert_true(effect.has_effect(), "%s tem efeito proprio" % guardian_name)
		names[effect.display_name] = true
	assert_eq(names.size(), GuardianStats.count(), "cada Guardiao tem um golpe distinto")


func test_the_saci_still_has_his_redemoinho_untouched() -> void:
	var saci := SpecialMoveTable.for_guardian(GuardianStats.SACI)
	assert_true(saci.has_pull())
	assert_false(saci.has_inversion(), "o Saci nao inverte comandos")
	assert_false(saci.has_sleep())


## Pes Invertidos: o alvo fica com o lado dos comandos trocado e com o sono zero.
func test_the_pes_invertidos_invert_the_commands_of_the_target() -> void:
	var effect := SpecialMoveTable.for_guardian(GuardianStats.CURUPIRA)
	assert_true(effect.has_inversion())
	assert_false(effect.has_sleep())
	var duel := _duel(GuardianStats.CURUPIRA)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	var report := effect.apply_active_tick(guardian, opponent)
	assert_true(report["inverted"], "o relatorio do tick diz que o alvo ficou invertido")
	assert_true(opponent.statuses.inverts_controls())
	assert_eq(
		opponent.statuses.remaining(StatusEffect.Kind.INVERT_CONTROLS),
		effect.invert_ticks,
		"e dura os 3 s do golpe"
	)


## "Derruba para o lado contrario do que ele defende": a queda segue o lado
## oposto da guarda do alvo, nunca o lado para onde ele olha.
func test_the_pes_invertidos_knock_the_target_to_the_opposite_side_of_the_guard() -> void:
	var effect := SpecialMoveTable.for_guardian(GuardianStats.CURUPIRA)
	var duel := _duel(GuardianStats.CURUPIRA)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	guardian.position.x = 100
	opponent.position.x = 200
	opponent.facing = 1
	effect.apply_active_tick(guardian, opponent)
	assert_eq(
		opponent.position.x,
		200 - effect.knockback_pixels,
		"defendendo para a direita, a queda vai para a esquerda"
	)
	opponent.position.x = 200
	opponent.facing = -1
	effect.apply_active_tick(guardian, opponent)
	assert_eq(
		opponent.position.x,
		200 + effect.knockback_pixels,
		"defendendo para a esquerda, a queda vai para a direita"
	)


func test_the_knockback_never_leaves_the_stage() -> void:
	var effect := SpecialMoveTable.for_guardian(GuardianStats.CURUPIRA)
	var duel := _duel(GuardianStats.CURUPIRA)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	guardian.position.x = 300
	opponent.position.x = Fighter.STAGE_MAX_X
	opponent.facing = -1
	effect.knock_target(guardian, opponent)
	assert_eq(opponent.position.x, Fighter.STAGE_MAX_X, "no limite da arena nao ha para onde cair")


## Canto do Rio: encanta (sono) e drena vida no abraco d'agua.
func test_the_canto_do_rio_sleeps_and_drains_life_into_the_iara() -> void:
	var effect := SpecialMoveTable.for_guardian(GuardianStats.IARA)
	assert_true(effect.has_sleep())
	assert_true(effect.has_drain())
	assert_false(effect.has_pull())
	var duel := _duel(GuardianStats.IARA)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	guardian.health.apply_damage(200)
	var guardian_before := guardian.health.current
	var opponent_before := opponent.health.current
	var report := effect.apply_active_tick(guardian, opponent)
	var drained: int = report["drain"]
	assert_gt(drained, 0, "o abraco d'agua tira vida do Oponente")
	assert_eq(opponent.health.current, opponent_before - drained, "e a vida do Oponente cai")
	assert_eq(guardian.health.current, guardian_before + drained, "e volta para a Iara")
	assert_true(report["sleeping"])
	assert_true(opponent.statuses.is_asleep(), "o Canto do Rio encanta e paralisa")


func test_the_drain_never_takes_more_life_than_the_target_has() -> void:
	var effect := SpecialMoveTable.for_guardian(GuardianStats.IARA)
	var duel := _duel(GuardianStats.IARA)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	opponent.health.current = 1
	var drained := effect.drain_target(guardian, opponent)
	assert_eq(drained, 1, "nao ha vida negativa")
	assert_eq(opponent.health.current, 0)
	assert_true(opponent.is_knocked_out(), "zerar a vida e nocaute")


## Nana Nenem: adormece o Oponente e a Cuca vira jacare e morde.
func test_the_nana_nenem_sleeps_and_bites_as_a_crocodile() -> void:
	var effect := SpecialMoveTable.for_guardian(GuardianStats.CUCA)
	assert_true(effect.has_sleep())
	assert_true(effect.has_bite())
	assert_false(effect.has_drain())
	var duel := _duel(GuardianStats.CUCA)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	var opponent_before := opponent.health.current
	var report := effect.apply_active_tick(guardian, opponent)
	assert_true(report["sleeping"])
	assert_true(opponent.statuses.is_asleep())
	var bite: int = report["bite"]
	assert_gt(bite, 0, "a mordida de jacare machuca")
	assert_eq(opponent.health.current, opponent_before - bite)
	assert_false(guardian.statuses.is_asleep(), "quem dorme e o alvo, nao a Cuca")


func test_the_effects_refuse_missing_fighters() -> void:
	var effect := SpecialMoveTable.for_guardian(GuardianStats.CUCA)
	var report := effect.apply_active_tick(null, null)
	assert_eq(report["bite"], 0)
	assert_eq(report["drain"], 0)
	assert_eq(report["knockback"], 0)
	assert_false(report["sleeping"])
	var duel := _duel(GuardianStats.CUCA)
	assert_eq(effect.drain_target(duel["guardian"], duel["opponent"]), 0, "Cuca nao drena")
	assert_eq(effect.pull_target(duel["guardian"], duel["opponent"]), 0, "nem puxa")


func test_the_effects_are_deterministic_for_the_same_seed() -> void:
	var first := _run_effect(GuardianStats.CURUPIRA)
	var second := _run_effect(GuardianStats.CURUPIRA)
	assert_eq(first, second, "mesma semente e mesmos golpes -> mesmo resultado")


func _run_effect(guardian_name: String) -> Array:
	var duel := _duel(guardian_name)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	var effect := SpecialMoveTable.for_guardian(guardian_name)
	var log: Array = []
	for tick in 4:
		log.append(effect.apply_active_tick(guardian, opponent))
	return log