extends GutTest
## Politica de IA do Oponente: tres niveis de dificuldade parametrizados,
## determinismo por semente e cobertura das acoes (atacar, defender, recuar e
## gastar o Especial).

const SEED := 4242
const CLOSE_DISTANCE := 18
const FAR_DISTANCE := 200


func _pair(distance: int = CLOSE_DISTANCE) -> Dictionary:
	var duel := Fighter.duel(GuardianStats.SACI, Archetype.Id.CAPATAZ, 11, 22)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	opponent.position.x = guardian.position.x + distance
	guardian.face_towards(opponent.position.x)
	opponent.face_towards(guardian.position.x)
	return {"guardian": guardian, "opponent": opponent}


func _collect(
	ai: OpponentAi,
	rng: Rng,
	iterations: int,
	distance: int,
	guardian_attacks: bool,
	full_meter: bool
) -> Dictionary:
	var seen: Dictionary = {}
	for index in iterations:
		var pair := _pair(distance)
		var guardian: Fighter = pair["guardian"]
		var opponent: Fighter = pair["opponent"]
		if full_meter:
			opponent.meter.gain(SpecialMeter.MAX_UNITS)
		if guardian_attacks and index % 2 == 0:
			guardian.start_move(Move.light())
		seen[ai.decide(opponent, guardian, rng)] = true
	return seen


func _sequence(difficulty: int, seed_value: int) -> Array:
	var ai := OpponentAi.new(difficulty)
	var rng := Rng.new(seed_value)
	var actions: Array = []
	for index in 300:
		var pair := _pair(CLOSE_DISTANCE)
		actions.append(ai.decide(pair["opponent"], pair["guardian"], rng))
	return actions


func test_three_difficulty_levels_are_parameterized() -> void:
	assert_eq(OpponentAi.level_count(), 3, "sao tres niveis")
	assert_eq(
		OpponentAi.levels(),
		[OpponentAi.Difficulty.EASY, OpponentAi.Difficulty.NORMAL, OpponentAi.Difficulty.HARD]
	)
	var easy := OpponentAi.new(OpponentAi.Difficulty.EASY)
	var normal := OpponentAi.new(OpponentAi.Difficulty.NORMAL)
	var hard := OpponentAi.new(OpponentAi.Difficulty.HARD)
	assert_lt(easy.value_of("aggression"), normal.value_of("aggression"))
	assert_lt(normal.value_of("aggression"), hard.value_of("aggression"))
	assert_lt(easy.value_of("block_chance"), hard.value_of("block_chance"))
	assert_lt(easy.value_of("special_chance"), hard.value_of("special_chance"))
	assert_gt(easy.reaction_ticks(), hard.reaction_ticks(), "dificil reage mais rapido")


func test_unknown_difficulty_falls_back_to_normal() -> void:
	var ai := OpponentAi.new(99)
	assert_eq(ai.difficulty, OpponentAi.Difficulty.NORMAL)
	assert_eq(OpponentAi.difficulty_name(OpponentAi.Difficulty.HARD), "hard")
	assert_eq(OpponentAi.level_count(), 3, "niveis nomeados em ingles")


func test_ai_attacks_retreats_and_defends_at_close_range() -> void:
	var ai := OpponentAi.new(OpponentAi.Difficulty.EASY)
	var seen := _collect(ai, Rng.new(SEED), 600, CLOSE_DISTANCE, false, false)
	assert_true(_has_attack(seen), "a IA ataca quando esta no alcance")
	assert_true(seen.has(OpponentAi.Action.RETREAT), "a IA recua")
	assert_true(seen.has(OpponentAi.Action.BLOCK), "a IA defende")


func test_ai_blocks_when_the_guardian_attacks() -> void:
	var ai := OpponentAi.new(OpponentAi.Difficulty.HARD)
	var seen := _collect(ai, Rng.new(SEED), 300, CLOSE_DISTANCE, true, false)
	assert_true(
		seen.has(OpponentAi.Action.BLOCK),
		"com o Guardiao golpeando, a IA defende com a chance do perfil"
	)


func test_ai_uses_the_special_with_a_full_meter() -> void:
	var ai := OpponentAi.new(OpponentAi.Difficulty.HARD)
	var seen := _collect(ai, Rng.new(SEED), 400, CLOSE_DISTANCE, false, true)
	assert_true(seen.has(OpponentAi.Action.SPECIAL), "com a barra cheia a IA usa o Especial")


func test_ai_advances_when_out_of_range() -> void:
	var ai := OpponentAi.new(OpponentAi.Difficulty.NORMAL)
	var seen := _collect(ai, Rng.new(SEED), 60, FAR_DISTANCE, false, false)
	assert_eq(seen.keys(), [OpponentAi.Action.ADVANCE], "longe, a IA so se aproxima")


func test_decisions_are_deterministic_for_the_same_seed() -> void:
	var first := _sequence(OpponentAi.Difficulty.NORMAL, SEED)
	var second := _sequence(OpponentAi.Difficulty.NORMAL, SEED)
	assert_gt(first.size(), 0)
	assert_eq(first, second, "mesma semente e mesmo estado -> mesmas decisoes")


func test_a_different_seed_changes_the_decisions() -> void:
	var first := _sequence(OpponentAi.Difficulty.NORMAL, SEED)
	var other := _sequence(OpponentAi.Difficulty.NORMAL, SEED + 1)
	assert_ne(first, other, "sementes diferentes produzem sequencias diferentes")


func test_ai_waits_and_does_not_roll_when_it_cannot_act() -> void:
	var ai := OpponentAi.new(OpponentAi.Difficulty.NORMAL)
	var rng := Rng.new(SEED)
	var pair := _pair(CLOSE_DISTANCE)
	var opponent: Fighter = pair["opponent"]
	opponent.state = FighterState.State.HURT
	var before := rng.state()
	assert_eq(
		ai.decide(opponent, pair["guardian"], rng),
		OpponentAi.Action.WAIT,
		"quem nao pode agir devolve WAIT"
	)
	assert_eq(rng.state(), before, "WAIT nao consome o Rng (determinismo intacto)")


func test_action_names_and_attack_classification_are_stable() -> void:
	assert_eq(OpponentAi.action_name(OpponentAi.Action.GRAB), "grab")
	assert_eq(OpponentAi.action_name(OpponentAi.Action.WAIT), "wait")
	assert_true(OpponentAi.is_attack(OpponentAi.Action.SPECIAL))
	assert_true(OpponentAi.is_attack(OpponentAi.Action.LIGHT))
	assert_false(OpponentAi.is_attack(OpponentAi.Action.BLOCK))
	assert_false(OpponentAi.is_attack(OpponentAi.Action.RETREAT))


func _has_attack(seen: Dictionary) -> bool:
	for action in seen.keys():
		if OpponentAi.is_attack(action):
			return true
	return false
