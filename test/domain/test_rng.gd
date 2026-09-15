extends GutTest
## RNG semeado: deterministico, sem nada da engine.

func test_same_seed_gives_the_same_sequence() -> void:
	var first := Rng.new(20260915)
	var second := Rng.new(20260915)
	for draw in 12:
		assert_eq(second.next_uint(), first.next_uint(), "sorteio %d igual" % draw)


func test_different_seeds_give_different_sequences() -> void:
	var first := Rng.new(1)
	var second := Rng.new(2)
	var differences := 0
	for draw in 8:
		if first.next_uint() != second.next_uint():
			differences += 1
	assert_eq(differences, 8, "sementes vizinhas nao produzem a mesma sequencia")


func test_zero_seed_does_not_lock_the_generator() -> void:
	var rng := Rng.new(0)
	var first := rng.next_uint()
	assert_ne(first, 0)
	assert_ne(rng.next_uint(), first, "a sequencia avanca a partir da semente zero")


func test_reset_restarts_the_same_sequence() -> void:
	var rng := Rng.new(777)
	var reference := Rng.new(777)
	var before := [rng.next_uint(), rng.next_uint(), rng.next_uint()]
	rng.reset()
	assert_eq(rng.state(), reference.state(), "reset volta ao estado inicial da semente")
	assert_eq([rng.next_uint(), rng.next_uint(), rng.next_uint()], before)


func test_integers_stay_inside_the_requested_range() -> void:
	var rng := Rng.new(4242)
	for draw in 400:
		var value := rng.next_int(-3, 3)
		assert_between(value, -3, 3, "next_int respeita os limites")


func test_integer_range_with_a_single_value() -> void:
	var rng := Rng.new(9)
	assert_eq(rng.next_int(5, 5), 5)
	assert_eq(rng.next_int(5, 2), 5, "intervalo invertido devolve o minimo")


func test_floats_stay_in_unit_interval() -> void:
	var rng := Rng.new(31337)
	for draw in 200:
		var value := rng.next_float()
		assert_true(value >= 0.0 and value < 1.0, "next_float em [0, 1)")


func test_chance_bounds() -> void:
	var rng := Rng.new(11)
	for draw in 50:
		assert_false(rng.chance(0.0), "probabilidade zero nunca acontece")
		assert_true(rng.chance(1.0), "probabilidade um sempre acontece")


func test_both_integer_outcomes_appear() -> void:
	var rng := Rng.new(2024)
	var seen := {}
	for draw in 200:
		seen[rng.next_int(0, 1)] = true
	assert_eq(seen.size(), 2, "a moeda cai para os dois lados")


func test_default_seed_is_stable() -> void:
	var first := Rng.new()
	var second := Rng.new(Rng.DEFAULT_SEED)
	assert_eq(first.next_uint(), second.next_uint())
