extends GutTest
## Estado do lutador: movimento, hitbox/hurtbox, olhar e montagem da Peleja.
## O combate em si (dano, defesa, barra, nocaute) fica em test_fighter_combat.gd.

const ATTACKER_X := 100
const DEFENDER_X := 120


func test_starts_idle_and_full() -> void:
	var fighter := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	assert_eq(fighter.state, FighterState.State.IDLE)
	assert_eq(fighter.position, Vector2i(ATTACKER_X, 0))
	assert_eq(fighter.health.current, 1000)
	assert_eq(fighter.meter.current, 0)
	assert_true(fighter.can_act())
	assert_false(fighter.is_attacking())
	assert_false(fighter.is_knocked_out())


func test_hurtbox_ends_at_the_feet() -> void:
	var fighter := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	var body := fighter.hurtbox()
	assert_eq(body.size, Fighter.STANDING_SIZE)
	assert_eq(body.position.y + body.size.y, fighter.position.y, "a hurtbox termina nos pes")
	assert_eq(body.size.x / 2, fighter.position.x - body.position.x, "corpo centrado nos pes")


func test_crouch_shrinks_the_hurtbox_without_moving_the_feet() -> void:
	var fighter := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	var standing := fighter.hurtbox()
	assert_true(fighter.crouch(), "agachar e aceito")
	assert_eq(fighter.state, FighterState.State.CROUCH)
	var crouching := fighter.hurtbox()
	assert_eq(crouching.size, Fighter.CROUCH_SIZE)
	assert_lt(crouching.size.y, standing.size.y, "agachado o corpo fica mais baixo")
	assert_gt(crouching.position.y, standing.position.y, "a cabeca desce")
	assert_eq(crouching.position.y + crouching.size.y, fighter.position.y, "os pes nao saem do lugar")
	assert_eq(fighter.position.x, ATTACKER_X)
	assert_true(fighter.stand())
	assert_eq(fighter.hurtbox().size, Fighter.STANDING_SIZE, "levantar volta a hurtbox antiga")


func test_hitbox_is_empty_when_not_attacking() -> void:
	var fighter := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	assert_true(fighter.hitbox().is_empty())
	assert_false(fighter.is_move_active())


func test_hitbox_exists_only_during_the_active_window() -> void:
	var fighter := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	assert_true(fighter.start_move(Move.light()))
	for tick in Move.LIGHT_STARTUP:
		assert_true(fighter.hitbox().is_empty(), "inicio nao tem hitbox (tick %d)" % tick)
		fighter.advance_tick()
	assert_eq(fighter.move_frame, Move.LIGHT_STARTUP)
	assert_true(fighter.is_move_active(), "janela ativa")
	assert_eq(fighter.hitbox().size, Vector2i(Move.LIGHT_REACH, Fighter.HITBOX_HEIGHT))
	for tick in Move.LIGHT_ACTIVE + Move.LIGHT_RECOVERY:
		fighter.advance_tick()
	assert_null(fighter.current_move, "o golpe terminou")
	assert_true(fighter.hitbox().is_empty(), "recuperacao nao tem hitbox")


func test_hitbox_follows_facing() -> void:
	var fighter := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, -1)
	fighter.start_move(Move.light())
	for tick in Move.LIGHT_STARTUP:
		fighter.advance_tick()
	var box := fighter.hitbox()
	assert_eq(box.position.x, ATTACKER_X - Move.LIGHT_REACH, "olhando para a esquerda")
	assert_eq(box.position.x + box.size.x, ATTACKER_X)
	fighter.face_towards(400)
	var flipped := fighter.hitbox()
	assert_eq(flipped.position.x, ATTACKER_X)
	assert_eq(flipped.size.x, Move.LIGHT_REACH)


func test_facing_only_changes_towards_a_different_position() -> void:
	var fighter := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	fighter.face_towards(ATTACKER_X)
	assert_eq(fighter.facing, 1, "mesma posicao nao inverte o olhar")
	fighter.face_towards(0)
	assert_eq(fighter.facing, -1)
	fighter.face_towards(400)
	assert_eq(fighter.facing, 1)


func test_walking_moves_and_clamps_to_the_stage() -> void:
	var fighter := Fighter.new(_stats(), Rng.new(1), 200, 1)
	assert_true(fighter.walk(1))
	assert_eq(fighter.position.x, 200 + fighter.stats.walk_speed)
	assert_eq(fighter.state, FighterState.State.WALK)
	assert_true(fighter.walk(0))
	assert_eq(fighter.state, FighterState.State.IDLE, "parar de andar volta ao idle")
	for step in 200:
		fighter.walk(1)
	assert_eq(fighter.position.x, Fighter.STAGE_MAX_X, "barrado na borda direita")
	for step in 200:
		fighter.walk(-1)
	assert_eq(fighter.position.x, Fighter.STAGE_MIN_X, "barrado na borda esquerda")


func test_move_is_refused_while_another_move_is_running() -> void:
	var fighter := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	assert_true(fighter.start_move(Move.light()))
	assert_false(fighter.start_move(Move.heavy()), "nao encadeia golpe")
	assert_false(fighter.walk(1), "atacando nao anda")
	assert_false(fighter.crouch(), "atacando nao agacha")
	var light := Move.light()
	var finished := false
	for tick in light.total_frames():
		finished = fighter.advance_tick()
	assert_true(finished, "o ultimo tick fecha o golpe")
	assert_false(fighter.is_attacking())
	assert_true(fighter.can_start_move())
	assert_true(fighter.start_move(Move.heavy()))


func test_reset_for_round_restores_everything() -> void:
	var pair := _pair()
	var attacker: Fighter = pair["attacker"]
	var defender: Fighter = pair["defender"]
	attacker.start_move(Move.light())
	for tick in Move.LIGHT_STARTUP:
		attacker.advance_tick()
	attacker.resolve_hit(defender)
	assert_lt(defender.health.current, defender.health.max_value)
	defender.reset_for_round(DEFENDER_X)
	assert_eq(defender.health.current, defender.health.max_value, "vida cheia no proximo round")
	assert_eq(defender.meter.current, 0, "barra zerada no proximo round")
	assert_eq(defender.state, FighterState.State.IDLE)
	assert_eq(defender.position.x, DEFENDER_X)
	assert_null(defender.current_move)


func test_duel_builds_the_guardian_with_the_hidden_advantage() -> void:
	var duel := Fighter.duel(GuardianStats.SACI, Archetype.Id.CAPATAZ, 7, 8)
	assert_eq(duel.size(), 2)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	assert_true(
		HiddenAdvantage.has_advantage(guardian.stats, opponent.stats),
		"o Guardiao entra com mais vida e mais dano"
	)
	assert_gt(guardian.health.max_value, opponent.health.max_value)
	assert_eq(guardian.facing, 1, "o Guardiao encara o Oponente")
	assert_eq(opponent.facing, -1)
	assert_eq(
		Fighter.duel(GuardianStats.SACI, 99, 1, 2), {}, "Arquetipo desconhecido nao monta Peleja"
	)


func _stats(p_health: int = 1000) -> FighterStats:
	return FighterStats.new("teste", p_health, 1.0, 0.5, 3, 10, 10)


func _pair() -> Dictionary:
	var attacker := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	var defender := Fighter.new(_stats(), Rng.new(2), DEFENDER_X, -1)
	attacker.damage_variance = 0
	return {"attacker": attacker, "defender": defender}