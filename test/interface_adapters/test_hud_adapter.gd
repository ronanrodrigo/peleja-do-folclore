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
	var accented := BitmapFont.make_image("FORÇA", Color8(255, 255, 255))
	assert_eq(accented.get_height(), 8, "a imagem acompanha o glifo mais alto (cedilha)")
	assert_eq(accented.get_width(), BitmapFont.text_width("FORÇA"), "largura do texto em pixels")


## Peleja de verdade com adapters `sample`, so para o HUD ler o retrato real.
func _fight_service() -> MatchService:
	var service := MatchService.new(
		SampleInputGateway.new(),
		SampleRenderGateway.new(),
		InMemoryAssetGateway.new(),
		SilentAudioGateway.new()
	)
	service.configure(GuardianStats.SACI, Archetype.Id.CAPATAZ, 11, 22)
	return service


## Procura uma chave proibida em qualquer nivel do modelo (dicionario ou lista).
func _leaks(value: Variant, key: String) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		var record: Dictionary = value
		for candidate in record.keys():
			if str(candidate) == key or _leaks(record[candidate], key):
				return true
		return false
	if typeof(value) == TYPE_ARRAY:
		for item in value as Array:
			if _leaks(item, key):
				return true
	return false


func test_the_fight_hud_shows_names_bars_and_rounds_of_a_real_match() -> void:
	var service := _fight_service()
	var model := _adapter.fight_model(service.snapshot(), GuardianStats.SACI, "Oponente")
	assert_eq(model["left"]["name"], GuardianStats.SACI)
	assert_eq(model["right"]["name"], "Oponente")
	assert_almost_eq(float(model["left"]["bar"]), 1.0, 0.01, "barra cheia no inicio do round")
	assert_eq(int(model["left"]["rounds_won"]), 0)
	assert_eq(int(model["left"]["rounds_left"]), MatchRules.ROUNDS_TO_WIN)
	assert_eq(int(model["rounds_to_win"]), MatchRules.ROUNDS_TO_WIN)
	assert_eq(model["phase"], "round_active")
	assert_eq(model["clock_text"], "1:00")


func test_the_fight_hud_never_discloses_the_hidden_advantage() -> void:
	var service := _fight_service()
	# A Vantagem Oculta e verdadeira: o Guardiao tem mais vida e mais dano.
	assert_gt(
		service.guardian.stats.max_health,
		service.opponent.stats.max_health,
		"o Guardiao tem mais vida que o Oponente"
	)
	assert_gt(
		service.guardian.stats.damage_multiplier,
		service.opponent.stats.damage_multiplier,
		"e mais dano"
	)
	var model := _adapter.fight_model(service.snapshot(), GuardianStats.SACI, "Oponente")
	assert_false(
		_adapter.discloses_hidden_advantage(model),
		"o HUD da luta nao expoe vida, dano nem a vantagem"
	)
	for forbidden in HudAdapter.FORBIDDEN_KEYS:
		assert_false(_leaks(model, forbidden), "%s nao aparece em nivel nenhum" % forbidden)
	var updated := service.snapshot()
	updated["guardian_health_ratio"] = 0.42
	var partial := _adapter.fight_model(updated, GuardianStats.SACI, "Oponente")
	assert_almost_eq(float(partial["left"]["bar"]), 0.42, 0.001, "a barra so mostra a proporcao")
	assert_false(_adapter.discloses_hidden_advantage(partial))


func test_the_fight_hud_labels_the_special_statuses_in_portuguese() -> void:
	var state := {
		"guardian_status": [{"name": "invert_controls", "ticks": 120}],
		"opponent_status": [{"name": "sleep", "ticks": 40}],
	}
	var model := _adapter.fight_model(state, GuardianStats.SACI, "Oponente")
	assert_eq(model["statuses"], ["COMANDOS INVERTIDOS", "SONO"])
	assert_false(_adapter.discloses_hidden_advantage(model))


func test_the_clock_and_the_status_copy_have_glyphs_in_the_bitmap_font() -> void:
	assert_eq(HudAdapter.clock_text(60), "1:00")
	assert_eq(HudAdapter.clock_text(0), "0:00")
	assert_eq(HudAdapter.clock_text(-4), "0:00", "relogio nunca fica negativo")
	var texts := [HudAdapter.clock_text(125), HudAdapter.STATUS_LABELS["sleep"]]
	texts.append(HudAdapter.STATUS_LABELS["invert_controls"])
	for text in texts:
		for index in text.length():
			assert_true(
				BitmapFont.FONT_GLYPHS.has(text.substr(index, 1)),
				"glifo proprio para todo caractere de '%s'" % text
			)

## --- HUD final de luta e do arcade (ticket 10) ---

func _fight_state() -> Dictionary:
	var service := _fight_service()
	var state := service.snapshot()
	state["guardian_health_ratio"] = 0.75
	state["opponent_health_ratio"] = 0.25
	state["guardian_meter_ratio"] = 1.0
	state["opponent_meter_ratio"] = 0.5
	state["guardian_rounds"] = 1
	return state


func _find_entry(entries: Array, color: Color, position: int) -> Rect2i:
	var found: Array = []
	for entry in entries:
		if entry["color"] == color:
			found.append(entry["rect"])
	return found[position]


func test_the_fight_hud_has_entries_for_both_bars_meters_and_round_pips() -> void:
	var model := _adapter.fight_model(_fight_state(), GuardianStats.SACI, "O Capeto")
	var entries: Array = _adapter.fight_hud_entries(model)
	var expected := 6 + MatchRules.ROUNDS_TO_WIN * 2
	assert_eq(entries.size(), expected, "um retangulo por elemento do HUD")
	for entry in entries:
		var rect: Rect2i = entry["rect"]
		assert_true(rect.position.x >= 0 and rect.position.y >= 0, "dentro da tela")
		assert_true(rect.end.x <= BASE_SIZE.x, "nao passa da borda direita")
		assert_true(rect.end.y <= BASE_SIZE.y, "nao passa da borda de baixo")
	var left_health := _find_entry(entries, HudAdapter.COLOR_HEALTH_FILL, 0)
	assert_eq(left_health.size.x, roundi(HudAdapter.FIGHT_BAR_WIDTH * 0.75), "vida em proporcao")
	var left_meter := _find_entry(entries, HudAdapter.COLOR_METER_FILL, 0)
	assert_eq(left_meter.size.x, HudAdapter.FIGHT_BAR_WIDTH, "barra de Especial cheia")
	var right_meter := _find_entry(entries, HudAdapter.COLOR_METER_FILL, 1)
	assert_eq(right_meter.size.x, HudAdapter.FIGHT_BAR_WIDTH / 2, "metade da barra do Oponente")


func test_the_fight_hud_labels_are_the_two_names_and_the_clock() -> void:
	var model := _adapter.fight_model(_fight_state(), GuardianStats.SACI, "O Capeto")
	var labels: Array = _adapter.fight_hud_labels(model)
	assert_eq(labels.size(), 3, "nome a esquerda, nome a direita e relogio")
	assert_eq(labels[0]["text"], GuardianStats.SACI)
	assert_eq(labels[1]["text"], "O Capeto")
	assert_eq(labels[2]["text"], "1:00")
	var right: Vector2i = labels[1]["position"]
	var right_width: int = BitmapFont.text_width("O Capeto") * int(labels[1]["scale"])
	assert_true(right.x + right_width <= BASE_SIZE.x, "o nome do Oponente cabe na tela")


func test_the_arcade_line_joins_the_fight_hud_when_requested() -> void:
	var model := _adapter.fight_model(_fight_state(), GuardianStats.SACI, "O Capeto")
	assert_eq(_adapter.fight_hud_labels(model).size(), 3, "sem arcade, so tres rotulos")
	model["arcade_text"] = "PELEJA 3/7"
	var labels: Array = _adapter.fight_hud_labels(model)
	assert_eq(labels.size(), 4, "a linha do arcade entra por ultimo")
	assert_eq(labels[3]["text"], "PELEJA 3/7")


func test_the_arcade_hud_shows_the_position_the_opponent_and_the_difficulty() -> void:
	var model := _adapter.arcade_model({
		"fight": 3,
		"fights": 7,
		"opponent_name": "O Camisa-Verde",
		"opponent_signature": "Gaita de Marcha",
		"difficulty": "normal",
		"complete": false,
	})
	assert_eq(model["fight_text"], "PELEJA 3/7")
	assert_eq(model["opponent_text"], "O Camisa-Verde")
	assert_eq(model["signature_text"], "GOLPE: Gaita de Marcha")
	assert_eq(model["difficulty_text"], "MÉDIO", "dificuldade em pt-BR")
	assert_almost_eq(float(model["progress"]), 3.0 / 7.0, 0.001)
	assert_false(model["complete"])


func test_the_arcade_hud_never_discloses_the_hidden_advantage() -> void:
	var service := _fight_service()
	var model := _adapter.arcade_model({
		"fight": 1,
		"fights": 7,
		"guardian_health_ratio": service.guardian.health.ratio(),
	})
	assert_false(_adapter.discloses_hidden_advantage(model))


func test_the_arcade_copy_has_glyphs_in_the_bitmap_font() -> void:
	var model := _adapter.arcade_model({
		"fight": 1,
		"fights": 7,
		"opponent_name": "O Doutor Pureza",
		"opponent_signature": "Teoria Drenante",
		"difficulty": "hard",
	})
	for text in [
		str(model["fight_text"]),
		str(model["difficulty_text"]),
		str(model["signature_text"]),
	]:
		text = text.to_upper()
		for index in text.length():
			assert_true(
				BitmapFont.FONT_GLYPHS.has(text.substr(index, 1)),
				"glifo proprio para todo caractere de '%s'" % text
			)
