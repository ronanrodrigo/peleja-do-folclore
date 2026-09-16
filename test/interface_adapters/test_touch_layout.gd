extends GutTest
## Layout de toque revisado para tela pequena (ticket 10): botoes com tamanho
## minimo, dentro da resolucao base, fora da faixa do HUD e sem sobreposicao.

const BASE := Vector2i(426, 240)


func _adapter() -> TouchInputAdapter:
	return TouchInputAdapter.new()


func test_every_button_has_the_minimum_size_and_fits_the_base_resolution() -> void:
	for entry in _adapter().layout():
		var rect: Rect2i = entry["rect"]
		assert_eq(rect.size, Vector2i(TouchInputAdapter.BUTTON_SIZE, TouchInputAdapter.BUTTON_SIZE))
		assert_true(rect.size.x >= 40, "alvo de toque grande o bastante")
		assert_true(rect.position.x >= 0 and rect.position.y >= 0, "dentro da tela")
		assert_true(rect.end.x <= BASE.x, "nao passa da borda direita")
		assert_true(rect.end.y <= BASE.y, "nao passa da borda de baixo")


func test_no_button_invades_the_hud_band_at_the_top() -> void:
	for entry in _adapter().layout():
		var rect: Rect2i = entry["rect"]
		assert_true(
			rect.position.y >= TouchInputAdapter.HUD_BAND_HEIGHT,
			"o topo da tela e informacao (HUD), nunca botao"
		)


func test_no_two_buttons_overlap() -> void:
	var entries: Array = _adapter().layout()
	for first in entries.size():
		for second in range(first + 1, entries.size()):
			var a: Rect2i = entries[first]["rect"]
			var b: Rect2i = entries[second]["rect"]
			assert_false(a.intersects(b), "botoes %d e %d nao se sobrepoem" % [first, second])


func test_the_two_families_are_on_opposite_sides_of_the_screen() -> void:
	var left_commands := [InputGateway.Command.MOVE_LEFT, InputGateway.Command.MOVE_RIGHT]
	var right_commands := [InputGateway.Command.LIGHT, InputGateway.Command.HEAVY]
	for entry in _adapter().layout():
		var rect: Rect2i = entry["rect"]
		if left_commands.has(entry["command"]):
			assert_lt(rect.end.x, BASE.x / 2, "mover fica na metade esquerda")
		if right_commands.has(entry["command"]):
			assert_gt(rect.position.x, BASE.x / 2, "golpear fica na metade direita")


func test_the_two_adapters_emit_the_same_command_enum() -> void:
	var touch := _adapter()
	var commands: Array = []
	for entry in touch.layout():
		commands.append(entry["command"])
	for command in [
		InputGateway.Command.MOVE_LEFT,
		InputGateway.Command.MOVE_RIGHT,
		InputGateway.Command.CROUCH,
		InputGateway.Command.BLOCK,
		InputGateway.Command.LIGHT,
		InputGateway.Command.HEAVY,
		InputGateway.Command.GRAB,
		InputGateway.Command.SPECIAL,
	]:
		assert_true(commands.has(command), "o toque cobre o comando do teclado: %d" % command)
