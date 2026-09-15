extends GutTest
## Relogio do round: ticks de simulacao, nunca temporizador de engine.

func test_default_round_lasts_sixty_seconds() -> void:
	var clock := RoundClock.new()
	assert_eq(clock.duration_ticks, 60 * RoundClock.TICKS_PER_SECOND)
	assert_eq(clock.remaining_ticks, clock.duration_ticks)
	assert_eq(clock.remaining_seconds(), 60)
	assert_false(clock.is_expired())


func test_advance_returns_ticks_actually_consumed() -> void:
	var clock := RoundClock.new(2)
	assert_eq(clock.advance(30), 30)
	assert_eq(clock.remaining_ticks, 2 * RoundClock.TICKS_PER_SECOND - 30)
	assert_eq(clock.advance(0), 0, "delta zero nao muda nada")
	assert_eq(clock.advance(-5), 0, "delta negativo e ignorado")


func test_advance_beyond_the_end_is_capped() -> void:
	var clock := RoundClock.new(1)
	assert_eq(clock.advance(999), RoundClock.TICKS_PER_SECOND)
	assert_eq(clock.remaining_ticks, 0)
	assert_true(clock.is_expired())


func test_seconds_are_rounded_up_for_the_display() -> void:
	var clock := RoundClock.new(10)
	assert_eq(clock.remaining_seconds(), 10)
	clock.advance(1)
	assert_eq(clock.remaining_seconds(), 10, "1 tick a menos ainda mostra 10")
	clock.advance(59)
	assert_eq(clock.remaining_seconds(), 9)
	assert_eq(clock.ratio(), 0.9)


func test_duration_never_below_one_second() -> void:
	var clock := RoundClock.new(0)
	assert_eq(clock.duration_ticks, RoundClock.TICKS_PER_SECOND)


func test_reset_restarts_the_round() -> void:
	var clock := RoundClock.new(1)
	clock.advance(60)
	clock.reset()
	assert_eq(clock.remaining_ticks, clock.duration_ticks)
	assert_false(clock.is_expired())
