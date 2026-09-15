extends GutTest
## Reprodutibilidade: mesma semente + mesmos comandos = mesmo resultado.
##
## A simulacao abaixo e o roteiro de comandos; nada nela consulta relogio,
## semente global ou estado escondido. Se algo aleatorio deixar de passar pelo
## `Rng` injetado, a comparacao entre as duas execucoes falha.

const GUARDIAN_SEED := 4242
const OPPONENT_SEED := 2424
const COMMANDS := [
	Move.Kind.LIGHT,
	Move.Kind.HEAVY,
	Move.Kind.LIGHT,
	Move.Kind.LIGHT,
	Move.Kind.HEAVY,
	Move.Kind.LIGHT,
	Move.Kind.HEAVY,
	Move.Kind.LIGHT,
]


func test_same_seed_and_same_commands_give_the_same_result() -> void:
	var first := _run(GUARDIAN_SEED, OPPONENT_SEED)
	var second := _run(GUARDIAN_SEED, OPPONENT_SEED)
	assert_eq(first, second, "duas execucoes identicas terminam no mesmo estado")
	assert_eq(first["damage_log"].size(), COMMANDS.size(), "todos os golpes conectaram")
	assert_gt(first["rolled_damage"], 0, "houve dano sorteado no roteiro")


func test_different_seed_changes_the_rolled_damage() -> void:
	var first := _run(GUARDIAN_SEED, OPPONENT_SEED)
	var other := _run(GUARDIAN_SEED + 1, OPPONENT_SEED)
	assert_eq(first["commands"], other["commands"], "os comandos foram os mesmos")
	assert_ne(
		[first["damage_log"], first["guardian_rng"]],
		[other["damage_log"], other["guardian_rng"]],
		"a semente muda o que e sorteado"
	)


func test_shuffled_command_order_changes_the_result() -> void:
	var first := _run(GUARDIAN_SEED, OPPONENT_SEED)
	var shuffled := _run_with(GUARDIAN_SEED, OPPONENT_SEED, [
		Move.Kind.HEAVY,
		Move.Kind.LIGHT,
		Move.Kind.HEAVY,
		Move.Kind.HEAVY,
		Move.Kind.LIGHT,
		Move.Kind.HEAVY,
		Move.Kind.LIGHT,
		Move.Kind.HEAVY,
	])
	assert_ne(first["damage_log"], shuffled["damage_log"], "outro roteiro, outro resultado")


func test_replay_from_the_same_seed_is_stable_tick_by_tick() -> void:
	var first := _run(GUARDIAN_SEED, OPPONENT_SEED)
	var second := _run(GUARDIAN_SEED, OPPONENT_SEED)
	assert_eq(first["opponent_health_end"], second["opponent_health_end"])
	assert_eq(first["guardian_meter"], second["guardian_meter"])
	assert_eq(first["opponent_meter"], second["opponent_meter"])
	assert_eq(first["opponent_state"], second["opponent_state"])
	assert_eq(first["guardian_rng"], second["guardian_rng"], "o rng do Guardiao para no mesmo ponto")


func _run(p_guardian_seed: int, p_opponent_seed: int) -> Dictionary:
	return _run_with(p_guardian_seed, p_opponent_seed, COMMANDS)


func _run_with(p_guardian_seed: int, p_opponent_seed: int, commands: Array) -> Dictionary:
	var duel := Fighter.duel(
		GuardianStats.SACI, Archetype.Id.CAPATAZ, p_guardian_seed, p_opponent_seed
	)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	opponent.position.x = guardian.position.x + 20
	var damage_log: Array = []
	var rolled_damage := 0
	for kind in commands:
		var move := _move_of(kind)
		guardian.start_move(move)
		for tick in move.total_frames():
			if move.is_active_at(guardian.move_frame):
				var dealt := guardian.resolve_hit(opponent)
				if dealt > 0:
					damage_log.append(dealt)
					rolled_damage += dealt
			guardian.advance_tick()
			opponent.advance_tick()
	return {
		"commands": commands.duplicate(),
		"damage_log": damage_log,
		"rolled_damage": rolled_damage,
		"opponent_health_end": opponent.health.current,
		"guardian_meter": guardian.meter.current,
		"opponent_meter": opponent.meter.current,
		"opponent_state": opponent.state,
		"guardian_rng": guardian.rng.state(),
		"opponent_rng": opponent.rng.state(),
	}


func _move_of(kind: int) -> Move:
	match kind:
		Move.Kind.HEAVY:
			return Move.heavy()
		Move.Kind.GRAB:
			return Move.grab()
		_:
			return Move.light()
