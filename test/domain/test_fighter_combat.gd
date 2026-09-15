extends GutTest
## Combate de um lutador contra outro: dano por golpe, defesa, barra de especial
## e nocaute. Espelha src/domain/fighter.gd junto de test_fighter.gd.

const ATTACKER_X := 100
const DEFENDER_X := 120


func test_hit_lands_only_in_the_active_window() -> void:
	var pair := _pair()
	var attacker: Fighter = pair["attacker"]
	var defender: Fighter = pair["defender"]
	attacker.start_move(Move.light())
	assert_eq(attacker.resolve_hit(defender), 0, "inicio do golpe nao conecta")
	for tick in Move.LIGHT_STARTUP:
		attacker.advance_tick()
	assert_eq(attacker.resolve_hit(defender), Move.LIGHT_DAMAGE)
	assert_eq(defender.health.current, 1000 - Move.LIGHT_DAMAGE)
	assert_eq(defender.state, FighterState.State.HURT)
	assert_eq(attacker.meter.current, 10, "a barra do atacante enche ao bater")
	assert_eq(defender.meter.current, 10, "a barra do defensor enche ao apanhar")
	assert_eq(attacker.resolve_hit(defender), 0, "o mesmo golpe conta uma vez so")


func test_hit_that_is_too_far_away_misses() -> void:
	var pair := _pair()
	var attacker: Fighter = pair["attacker"]
	var defender: Fighter = pair["defender"]
	defender.position.x = 400
	attacker.start_move(Move.heavy())
	for tick in Move.HEAVY_STARTUP:
		attacker.advance_tick()
	assert_eq(attacker.resolve_hit(defender), 0, "longe demais nao conecta")
	assert_eq(defender.health.current, 1000)
	assert_eq(defender.state, FighterState.State.IDLE)


func test_every_move_has_its_own_damage() -> void:
	assert_eq(_hit_damage(Move.light()), Move.LIGHT_DAMAGE)
	assert_eq(_hit_damage(Move.heavy()), Move.HEAVY_DAMAGE)
	assert_eq(_hit_damage(Move.grab()), Move.GRAB_DAMAGE)
	assert_gt(_hit_damage(Move.heavy()), _hit_damage(Move.light()))


func test_defending_reduces_the_damage() -> void:
	var damage := _hit_damage(Move.light(), true)
	assert_eq(damage, roundi(Move.LIGHT_DAMAGE * 0.5), "defesa reduz o dano recebido")
	assert_lt(damage, Move.LIGHT_DAMAGE)
	assert_gt(damage, 0, "defender nao zera o dano")


func test_grab_pierces_the_guard() -> void:
	var damage := _hit_damage(Move.grab(), true)
	assert_eq(damage, Move.GRAB_DAMAGE, "agarrão ignora a defesa")


func test_defender_is_not_stunned_when_the_hit_is_blocked() -> void:
	var pair := _pair()
	var attacker: Fighter = pair["attacker"]
	var defender: Fighter = pair["defender"]
	assert_true(defender.block())
	attacker.start_move(Move.light())
	for tick in Move.LIGHT_STARTUP:
		attacker.advance_tick()
	assert_gt(attacker.resolve_hit(defender), 0)
	assert_eq(defender.state, FighterState.State.BLOCK, "quem defende continua defendendo")


func test_taking_a_hit_interrupts_the_attack() -> void:
	var pair := _pair()
	var attacker: Fighter = pair["attacker"]
	var defender: Fighter = pair["defender"]
	assert_true(defender.start_move(Move.heavy()))
	attacker.start_move(Move.light())
	for tick in Move.LIGHT_STARTUP:
		attacker.advance_tick()
	assert_gt(attacker.resolve_hit(defender), 0)
	assert_false(defender.is_attacking(), "o golpe de quem apanha e interrompido")
	assert_null(defender.current_move)


func test_hurt_stun_expires() -> void:
	var pair := _pair()
	var attacker: Fighter = pair["attacker"]
	var defender: Fighter = pair["defender"]
	attacker.start_move(Move.light())
	for tick in Move.LIGHT_STARTUP:
		attacker.advance_tick()
	attacker.resolve_hit(defender)
	assert_eq(defender.state, FighterState.State.HURT)
	defender.advance_tick()
	assert_eq(defender.state, FighterState.State.HURT, "o travamento dura alguns ticks")
	for tick in Fighter.HURT_FRAMES:
		defender.advance_tick()
	assert_eq(defender.state, FighterState.State.IDLE)
	assert_true(defender.can_act())


func test_knockout_when_health_reaches_zero() -> void:
	var attacker := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	var fragile := FighterStats.new("fraco", 5, 1.0, 0.0, 3, 10, 10)
	var defender := Fighter.new(fragile, Rng.new(2), DEFENDER_X, -1)
	attacker.start_move(Move.heavy())
	for tick in Move.HEAVY_STARTUP:
		attacker.advance_tick()
	assert_eq(attacker.resolve_hit(defender), 5, "so desconta o que restava")
	assert_eq(defender.health.current, 0)
	assert_true(defender.is_knocked_out())
	assert_eq(defender.state, FighterState.State.KNOCKED_DOWN)
	assert_false(defender.walk(1), "nocauteado nao anda")
	assert_false(defender.crouch(), "nocauteado nao agacha")
	assert_false(defender.block(), "nocauteado nao defende")
	assert_false(defender.start_move(Move.light()), "nocauteado nao ataca")
	assert_eq(defender.receive_hit(Move.light(), attacker), 0, "nocauteado nao apanha de novo")


func test_damage_variance_comes_from_the_injected_rng() -> void:
	var pair := _pair()
	var attacker: Fighter = pair["attacker"]
	var defender: Fighter = pair["defender"]
	attacker.damage_variance = 3
	attacker.start_move(Move.light())
	for tick in Move.LIGHT_STARTUP:
		attacker.advance_tick()
	var dealt := attacker.resolve_hit(defender)
	assert_between(dealt, Move.LIGHT_DAMAGE - 3, Move.LIGHT_DAMAGE + 3, "variacao do rng injetado")


func test_special_needs_a_full_meter_and_consumes_it_all() -> void:
	var fighter := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	var special := Move.special("Redemoinho")
	fighter.meter.gain(SpecialMeter.MAX_UNITS - 1)
	assert_false(fighter.can_use_special(), "barra incompleta nao libera o especial")
	assert_false(fighter.start_special(special), "especial bloqueado com a barra incompleta")
	assert_eq(fighter.meter.current, SpecialMeter.MAX_UNITS - 1, "a recusa nao gasta barra")
	assert_false(fighter.is_attacking())
	fighter.meter.gain(1)
	assert_true(fighter.can_use_special())
	assert_true(fighter.start_special(special))
	assert_eq(fighter.meter.current, 0, "o especial consome a barra inteira")
	assert_eq(fighter.current_move, special)
	assert_true(fighter.is_attacking())


func test_special_cannot_be_triggered_by_a_common_golpe() -> void:
	var fighter := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	fighter.meter.gain(SpecialMeter.MAX_UNITS)
	assert_false(fighter.start_special(Move.heavy()), "so o Golpe Especial usa a barra")
	assert_eq(fighter.meter.current, SpecialMeter.MAX_UNITS, "a barra fica intacta")


func test_meter_fills_while_fighting_until_the_special_opens() -> void:
	var pair := _pair()
	var attacker: Fighter = pair["attacker"]
	var defender: Fighter = pair["defender"]
	for round_trip in 10:
		attacker.start_move(Move.light())
		for tick in Move.LIGHT_STARTUP:
			attacker.advance_tick()
		attacker.resolve_hit(defender)
		while attacker.current_move != null:
			attacker.advance_tick()
	assert_true(attacker.meter.is_full(), "a barra enche batendo")
	assert_true(defender.meter.is_full(), "a barra enche apanhando")
	assert_true(attacker.can_use_special(), "com a barra cheia o especial abre")


func test_meter_gain_never_exceeds_the_bar() -> void:
	var pair := _pair()
	var attacker: Fighter = pair["attacker"]
	var defender: Fighter = pair["defender"]
	for round_trip in 30:
		attacker.start_move(Move.heavy())
		for tick in Move.HEAVY_STARTUP:
			attacker.advance_tick()
		attacker.resolve_hit(defender)
		while attacker.current_move != null:
			attacker.advance_tick()
	assert_eq(attacker.meter.current, SpecialMeter.MAX_UNITS, "a barra para cheia")


func _stats(p_health: int = 1000) -> FighterStats:
	return FighterStats.new("teste", p_health, 1.0, 0.5, 3, 10, 10)


func _pair() -> Dictionary:
	var attacker := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	var defender := Fighter.new(_stats(), Rng.new(2), DEFENDER_X, -1)
	attacker.damage_variance = 0
	return {"attacker": attacker, "defender": defender}


## Dano real de um golpe contra um defensor parado no alcance.
func _hit_damage(move: Move, p_defending: bool = false) -> int:
	var attacker := Fighter.new(_stats(), Rng.new(1), ATTACKER_X, 1)
	var defender := Fighter.new(_stats(), Rng.new(2), DEFENDER_X, -1)
	attacker.damage_variance = 0
	attacker.start_move(move)
	if p_defending:
		defender.block()
	for tick in move.first_active_frame():
		attacker.advance_tick()
	return attacker.resolve_hit(defender)