extends GutTest
## Barra de Especial: enche batendo e apanhando, e o especial consome tudo.

func test_starts_empty() -> void:
	var meter := SpecialMeter.new()
	assert_eq(meter.current, 0)
	assert_true(meter.is_empty())
	assert_false(meter.is_full())
	assert_eq(meter.ratio(), 0.0)


func test_gain_reports_what_was_added() -> void:
	var meter := SpecialMeter.new()
	assert_eq(meter.gain(30), 30)
	assert_eq(meter.current, 30)
	assert_eq(meter.gain(0), 0)
	assert_eq(meter.gain(-5), 0)
	assert_eq(meter.current, 30)


func test_gain_is_capped_at_full() -> void:
	var meter := SpecialMeter.new()
	assert_eq(meter.gain(80), 80)
	assert_eq(meter.gain(50), SpecialMeter.MAX_UNITS - 80, "o excedente e descartado")
	assert_true(meter.is_full())
	assert_eq(meter.current, SpecialMeter.MAX_UNITS)
	assert_eq(meter.ratio(), 1.0)


func test_consume_refuses_while_incomplete() -> void:
	var meter := SpecialMeter.new()
	meter.gain(99)
	assert_false(meter.is_full())
	assert_false(meter.consume(), "especial nao dispara com a barra incompleta")
	assert_eq(meter.current, 99, "a recusa nao gasta nada")


func test_consume_empties_the_whole_bar() -> void:
	var meter := SpecialMeter.new()
	meter.gain(SpecialMeter.MAX_UNITS)
	assert_true(meter.consume())
	assert_eq(meter.current, 0, "a barra inteira e consumida")
	assert_true(meter.is_empty())


func test_reset_clears_the_bar() -> void:
	var meter := SpecialMeter.new()
	meter.gain(70)
	meter.reset()
	assert_eq(meter.current, 0)


func test_initial_units_are_clamped() -> void:
	assert_eq(SpecialMeter.new(-10).current, 0)
	assert_eq(SpecialMeter.new(999).current, SpecialMeter.MAX_UNITS)
