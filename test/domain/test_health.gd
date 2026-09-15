extends GutTest
## Vida: dano, estouro de dano e barra.

func test_starts_full() -> void:
	var health := Health.new(100)
	assert_eq(health.max_value, 100)
	assert_eq(health.current, 100)
	assert_false(health.is_empty())
	assert_eq(health.ratio(), 1.0)


func test_max_value_never_below_one() -> void:
	assert_eq(Health.new(0).max_value, 1)
	assert_eq(Health.new(-50).max_value, 1)


func test_damage_reduces_current() -> void:
	var health := Health.new(100)
	assert_eq(health.apply_damage(30), 30, "dano aplicado e devolvido")
	assert_eq(health.current, 70)
	assert_eq(health.ratio(), 0.7)


func test_overkill_is_capped_at_remaining_health() -> void:
	var health := Health.new(20)
	assert_eq(health.apply_damage(999), 20, "so desconta o que restava")
	assert_eq(health.current, 0)
	assert_true(health.is_empty())


func test_ignored_damage() -> void:
	var health := Health.new(50)
	assert_eq(health.apply_damage(0), 0)
	assert_eq(health.apply_damage(-10), 0)
	assert_eq(health.current, 50)
	health.apply_damage(50)
	assert_eq(health.apply_damage(10), 0, "vida zerada nao fica negativa")
	assert_eq(health.current, 0)


func test_reset_restores_full_health() -> void:
	var health := Health.new(80)
	health.apply_damage(80)
	health.reset()
	assert_eq(health.current, 80)
	assert_false(health.is_empty())
