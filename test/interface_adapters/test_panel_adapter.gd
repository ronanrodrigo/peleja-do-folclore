extends GutTest
## O painel da Reviravolta: copy pt-BR em caixa alta, posicionada na resolucao
## base 426x240 e desenhada pela fonte bitmap (com glifo proprio para cada
## caractere). A cena nao tem interacao -- a unica acao e pular.

var _adapter: PanelAdapter


func before_each() -> void:
	_adapter = PanelAdapter.new()


func test_the_script_is_four_short_lines_in_portuguese() -> void:
	assert_eq(_adapter.line_count(), 4)
	assert_eq(_adapter.lines().size(), 4)
	assert_eq(_adapter.line_text(0), "A MATA RESPONDE.")
	assert_eq(_adapter.line_text(3), "O BRASIL PROFUNDO O DISSOLVE.")
	assert_eq(_adapter.line_text(-1), "", "fora da sequencia devolve vazio")
	assert_eq(_adapter.line_text(4), "")
	assert_eq(_adapter.line_text(0), PanelAdapter.LINES[0], "a copy e dado do adapter")


func test_the_force_and_the_title_are_named() -> void:
	assert_eq(_adapter.title_text(), "REVIRAVOLTA")
	assert_eq(_adapter.force_text(), "FORÇA SOBRENATURAL")
	assert_eq(_adapter.skip_hint(), "ESPAÇO PULA A CENA")


func test_the_copy_uses_uppercase_portuguese_with_accents() -> void:
	for line in _adapter.lines():
		assert_eq(line, line.to_upper(), "a copy da cena e em caixa alta")
	assert_true(_adapter.force_text().contains("Ç"), "a Forca tem cedilha")
	assert_eq(
		_adapter.force_text(),
		_adapter.force_text().to_upper(),
		"nome da entidade tambem em caixa alta"
	)


func test_every_character_of_the_copy_has_a_glyph_in_the_bitmap_font() -> void:
	var texts := [_adapter.title_text(), _adapter.force_text(), _adapter.skip_hint()]
	texts.append_array(_adapter.lines())
	for text in texts:
		for index in text.length():
			var character: String = text.substr(index, 1)
			assert_true(
				BitmapFont.FONT_GLYPHS.has(character),
				"glifo proprio para '%s' em '%s'" % [character, text]
			)


func test_the_view_model_fits_inside_the_base_resolution() -> void:
	var model := _adapter.view_model(0)
	for prefix in ["title", "force", "line", "hint"]:
		var text: String = model["%s_text" % prefix]
		var scale := int(model["%s_scale" % prefix])
		var position: Vector2i = model["%s_position" % prefix]
		var width := BitmapFont.text_width(text) * scale
		assert_true(position.x >= 0, "%s comeca dentro da tela" % prefix)
		assert_true(
			position.x + width <= PanelAdapter.BASE_SIZE.x,
			"%s cabe na largura base (%d px)" % [prefix, width]
		)
		assert_true(scale >= 1, "escala inteira apenas")
	var band: Rect2i = model["band_rect"]
	assert_true(band.position.x >= 0 and band.end.x <= PanelAdapter.BASE_SIZE.x)
	assert_true(band.end.y <= PanelAdapter.BASE_SIZE.y)
	assert_true(int(model["hint_scale"]) >= 1)


func test_the_band_holds_the_line_and_the_hint_stays_below() -> void:
	var model := _adapter.view_model(2)
	var band: Rect2i = model["band_rect"]
	var line_position: Vector2i = model["line_position"]
	assert_true(line_position.y >= band.position.y, "a fala entra na faixa escura")
	assert_true(
		line_position.y + BitmapFont.GLYPH_HEIGHT * int(model["line_scale"]) <= band.end.y,
		"a fala nao escapa por baixo da faixa"
	)
	assert_eq(model["line_text"], _adapter.line_text(2), "o modelo mostra a linha pedida")
	assert_gt(int(model["hint_position"].y), band.end.y, "o comando de pular fica abaixo")


func test_the_current_line_follows_the_progress_and_never_goes_blank() -> void:
	for index in _adapter.line_count():
		assert_eq(_adapter.view_model(index)["line_text"], _adapter.line_text(index))
	assert_eq(
		_adapter.view_model(-1)["line_text"],
		_adapter.line_text(_adapter.line_count() - 1),
		"passada a voz, a ultima fala fica na tela em vez de sumir"
	)
	assert_eq(_adapter.view_model(99)["line_text"], _adapter.line_text(_adapter.line_count() - 1))


func test_the_panel_model_never_carries_a_hidden_advantage_number() -> void:
	var model := _adapter.view_model(1)
	for forbidden in HudAdapter.FORBIDDEN_KEYS:
		assert_false(model.has(forbidden), "o painel nao expoe %s" % forbidden)
	assert_false(HudAdapter.new().discloses_hidden_advantage(model), "sem numeros de vida ou dano")
