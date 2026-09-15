extends GutTest
## Golpes: alcance, dano e janela de frames.

func test_light_heavy_and_grab_have_distinct_weights() -> void:
	var light := Move.light()
	var grab := Move.grab()
	var heavy := Move.heavy()
	assert_lt(light.damage, grab.damage, "leve machuca menos que agarrão")
	assert_lt(grab.damage, heavy.damage, "agarrão machuca menos que pesado")
	assert_lt(grab.reach, light.reach, "agarrão tem o menor alcance")
	assert_lt(light.reach, heavy.reach, "pesado alcanca mais que leve")


func test_grab_ignores_guard() -> void:
	var grab := Move.grab()
	assert_true(grab.is_grab(), "agarrão e reconhecido como agarrão")
	assert_true(grab.is_unblockable(), "agarrão passa pela defesa")
	assert_false(grab.blockable)
	var light := Move.light()
	assert_true(light.blockable, "golpe leve pode ser defendido")
	assert_false(light.is_unblockable())


func test_special_is_marked_and_named() -> void:
	var special := Move.special("Redemoinho")
	assert_true(special.is_special())
	assert_false(special.is_grab())
	assert_eq(special.display_name, "Redemoinho")
	assert_gt(special.damage, Move.heavy().damage, "especial e o golpe mais forte")
	assert_gt(special.reach, Move.heavy().reach, "especial tem o maior alcance")


func test_active_window_is_exactly_startup_plus_active() -> void:
	var light := Move.light()
	assert_eq(light.first_active_frame(), Move.LIGHT_STARTUP)
	assert_eq(light.last_active_frame(), Move.LIGHT_STARTUP + Move.LIGHT_ACTIVE - 1)
	assert_false(light.is_active_at(Move.LIGHT_STARTUP - 1), "inicio nao conecta")
	assert_true(light.is_active_at(Move.LIGHT_STARTUP), "primeiro frame ativo conecta")
	assert_true(light.is_active_at(light.last_active_frame()), "ultimo frame ativo conecta")
	assert_false(light.is_active_at(light.last_active_frame() + 1), "recuperacao nao conecta")


func test_total_frames_sums_the_three_windows() -> void:
	var heavy := Move.heavy()
	assert_eq(heavy.total_frames(), Move.HEAVY_STARTUP + Move.HEAVY_ACTIVE + Move.HEAVY_RECOVERY)
	assert_false(heavy.is_finished_at(heavy.total_frames() - 1))
	assert_true(heavy.is_finished_at(heavy.total_frames()))


func test_invalid_numbers_are_clamped() -> void:
	var move := Move.new(Move.Kind.LIGHT, -5, 0, -3, 0, -7)
	assert_eq(move.damage, 0, "dano negativo vira zero")
	assert_eq(move.reach, 1, "alcance nunca e nulo")
	assert_eq(move.startup_frames, 0)
	assert_eq(move.active_frames, 1, "todo golpe tem ao menos um frame ativo")
	assert_eq(move.recovery_frames, 0)


func test_kind_names_are_stable() -> void:
	assert_eq(Move.light().kind_name(), "light")
	assert_eq(Move.heavy().kind_name(), "heavy")
	assert_eq(Move.grab().kind_name(), "grab")
	assert_eq(Move.special("X").kind_name(), "special")


func test_default_display_name_falls_back_to_kind() -> void:
	assert_eq(Move.light().display_name, "light")
