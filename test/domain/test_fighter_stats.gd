extends GutTest
## Numeros base do lutador: dano por golpe e defesa.

func test_damage_scales_with_the_multiplier() -> void:
	var plain := FighterStats.new("plain", 1000, 1.0, 0.0)
	assert_eq(plain.damage_for(Move.light()), Move.LIGHT_DAMAGE)
	var strong := FighterStats.new("strong", 1000, 1.5, 0.0)
	assert_eq(strong.damage_for(Move.light()), roundi(Move.LIGHT_DAMAGE * 1.5))


func test_golpe_sem_dano_continua_zero() -> void:
	var stats := FighterStats.new("plain", 1000, 2.0, 0.0)
	assert_eq(stats.damage_for(null), 0)
	assert_eq(stats.damage_for(Move.new(Move.Kind.LIGHT, 0, 10, 1, 1, 1)), 0)


func test_weak_multiplier_still_costs_one_point() -> void:
	var stats := FighterStats.new("weak", 1000, 0.01, 0.0)
	assert_eq(stats.damage_for(Move.light()), 1, "dano nunca cai para zero por arredondamento")
	assert_eq(stats.damage_taken(Move.light(), false), 1)


func test_blocking_reduces_damage_of_blockable_moves() -> void:
	var stats := FighterStats.new("plain", 1000, 1.0, 0.5)
	var light := Move.light()
	assert_eq(stats.damage_taken(light, false), Move.LIGHT_DAMAGE)
	assert_eq(stats.damage_taken(light, true), roundi(Move.LIGHT_DAMAGE * 0.5))
	assert_lt(stats.damage_taken(light, true), stats.damage_taken(light, false))


func test_defesa_nao_para_golpes_inbloqueaveis() -> void:
	var stats := FighterStats.new("plain", 1000, 1.0, 0.9)
	assert_eq(
		stats.damage_taken(Move.grab(), true),
		stats.damage_for(Move.grab()),
		"agarrão ignora a guarda"
	)


func test_block_reduction_is_clamped() -> void:
	assert_eq(FighterStats.new("x", 100, 1.0, -1.0).block_damage_reduction, 0.0)
	assert_eq(FighterStats.new("x", 100, 1.0, 5.0).block_damage_reduction, 1.0)
	var full_guard := FighterStats.new("x", 100, 1.0, 1.0)
	assert_eq(full_guard.damage_taken(Move.light(), true), 1, "defesa perfeita ainda custa 1")


func test_with_advantage_copies_without_touching_the_original() -> void:
	var base := FighterStats.new("Guardião", 1000, 1.0, 0.6, 3, 12, 8)
	var boosted := base.with_advantage(1.6, 1.4)
	assert_eq(boosted.max_health, 1600)
	assert_almost_eq(boosted.damage_multiplier, 1.4, 0.0001)
	assert_eq(boosted.display_name, "Guardião")
	assert_eq(boosted.block_damage_reduction, base.block_damage_reduction)
	assert_eq(boosted.walk_speed, base.walk_speed)
	assert_eq(boosted.meter_gain_on_hit, base.meter_gain_on_hit)
	assert_eq(boosted.meter_gain_on_hurt, base.meter_gain_on_hurt)
	assert_eq(base.max_health, 1000, "os numeros originais nao mudam")
	assert_almost_eq(base.damage_multiplier, 1.0, 0.0001)
