extends GutTest
## O HUD da selecao: retrato (slug da spritesheet), nome e nome do Golpe Especial
## dos 4 Guardioes, posicionados na resolucao base 426x240.
##
## Invariante de produto (ADR 0003): a HUD NUNCA revela a Vantagem Oculta. O
## modelo e conferido por `discloses_hidden_advantage()`.

const BASE_SIZE := Vector2i(426, 240)

var _adapter: HudAdapter


func before_each() -> void:
	_adapter = HudAdapter.new()


func _model() -> Dictionary:
	return _adapter.character_select_model(CharacterSelectService.new().rows())


func test_the_hud_shows_the_four_guardians_with_portrait_name_and_special() -> void:
	var model := _model()
	var columns: Array = model["columns"]
	assert_eq(columns.size(), GuardianStats.count(), "uma coluna por Guardiao")
	for index in columns.size():
		var column: Dictionary = columns[index]
		assert_eq(column["slug"], GuardianStats.slugs()[index], "o retrato vem pelo slug do dado")
		assert_eq(column["name"], GuardianStats.all()[index])
		assert_eq(column["portrait_animation"], "idle", "retrato do quadro parado da spritesheet")
		assert_eq(column["portrait_frame"], 0)
		assert_gt(int(column["portrait_scale"]), 0, "escala inteira apenas")
		assert_false(str(column["special_name"]).is_empty())


func test_the_special_name_of_each_guardian_is_the_legend_one() -> void:
	var columns: Array = _model()["columns"]
	assert_eq(columns[0]["special_name"], SpecialMove.REDEMOINHO)
	assert_eq(columns[1]["special_name"], SpecialMove.PES_INVERTIDOS)
	assert_eq(columns[2]["special_name"], SpecialMove.CANTO_DO_RIO)
	assert_eq(columns[3]["special_name"], SpecialMove.NANA_NENEM)
	assert_false(HudAdapter.special_label(GuardianStats.IARA).is_empty())
	assert_true(HudAdapter.special_available(GuardianStats.IARA))
	assert_false(HudAdapter.special_available("Guardião de Fora do Elenco"))


func test_the_selected_guardian_is_highlighted() -> void:
	var columns: Array = _model()["columns"]
	assert_true(columns[0]["selected"])
	assert_false(columns[1]["selected"])
	assert_ne(
		columns[0]["band_color"], columns[1]["band_color"], "a coluna selecionada se destaca"
	)
	assert_ne(columns[0]["name_color"], columns[1]["name_color"])


func test_everything_stays_inside_the_base_resolution() -> void:
	var model := _model()
	for column in model["columns"]:
		var band: Rect2i = column["band"]
		assert_true(band.position.x >= 0 and band.position.y >= 0)
		assert_true(band.end.x <= BASE_SIZE.x, "a coluna cabe na resolucao base")
		assert_true(band.end.y <= BASE_SIZE.y)
	var title: Vector2i = model["title_position"]
	assert_gt(title.x, 0, "o titulo e centralizado, nao colado na borda")
	assert_lt(title.x + BitmapFont.text_width(model["title"]) * int(model["title_scale"]), BASE_SIZE.x)
	assert_false(str(model["prompt"]).is_empty(), "a tela diz como confirmar")


func test_the_hud_never_discloses_the_hidden_advantage() -> void:
	var model := _model()
	assert_false(_adapter.discloses_hidden_advantage(model), "sem vida, dano ou vantagem no modelo")
	for column in model["columns"]:
		for forbidden in HudAdapter.FORBIDDEN_KEYS:
			assert_false(column.has(forbidden), "coluna sem %s" % forbidden)
			assert_false(model.has(forbidden), "modelo sem %s" % forbidden)


func test_titles_and_names_are_uppercase_copy_in_portuguese() -> void:
	var model := _model()
	assert_eq(model["title"], "ESCOLHA SEU GUARDIÃO")
	assert_eq(model["prompt"], "PRESSIONE PARA LUTAR")


func test_the_bitmap_font_covers_the_accented_uppercase_copy() -> void:
	var fallback := BitmapFont.glyph_rows("~")
	for character in ["Ã", "É", "Ç", "Í", "Ó"]:
		assert_ne(
			BitmapFont.glyph_rows(character),
			fallback,
			"glifo proprio para %s" % character
		)
	assert_eq(BitmapFont.glyph_rows("Ç").size(), 8, "o cedilha tem a linha extra embaixo")
	assert_true(BitmapFont.text_width("SACI") > 0)
	var image := BitmapFont.make_image("PEs", Color8(255, 255, 255))
	assert_eq(image.get_height(), BitmapFont.GLYPH_HEIGHT)
	assert_gt(image.get_width(), 0)