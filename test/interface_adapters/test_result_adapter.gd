extends GutTest
## As telas de fim (ticket 10): copy pt-BR de vitoria, derrota e fim de arcade,
## posicionada na resolucao base. Invariante do ADR 0003: nenhum numero da
## Vantagem Oculta aparece no modelo.

const BASE_SIZE := Vector2i(426, 240)
const KINDS := [
	ResultAdapter.KIND_VICTORY,
	ResultAdapter.KIND_DEFEAT,
	ResultAdapter.KIND_ARCADE_END,
]

var _adapter: ResultAdapter


func before_each() -> void:
	_adapter = ResultAdapter.new()


func _fight_summary() -> Dictionary:
	return {
		"guardian": GuardianStats.SACI,
		"opponent": "O Capataz",
		"fight": 3,
		"fights": 7,
		"winner": MatchRules.Winner.OPPONENT,
		"guardian_rounds": 1,
		"opponent_rounds": 2,
		"skipped": false,
		"arcade_complete": false,
		"results": [],
	}


func test_every_kind_has_its_own_title_in_portuguese() -> void:
	assert_eq(_adapter.title_for(ResultAdapter.KIND_VICTORY), "VITÓRIA")
	assert_eq(_adapter.title_for(ResultAdapter.KIND_DEFEAT), "DERROTA")
	assert_eq(_adapter.title_for(ResultAdapter.KIND_ARCADE_END), "ARCADE COMPLETO")


func test_the_defeat_screen_says_the_campaign_continues() -> void:
	var lines: Array = _adapter.lines_for(ResultAdapter.KIND_DEFEAT, _fight_summary())
	assert_true(lines.has("A CAMPANHA CONTINUA"), "a derrota nao encerra a campanha")
	assert_false(lines.has("VOCÊ VENCEU A PELEJA"), "e nao se diz vitoria onde houve derrota")


func test_the_arcade_end_screen_offers_the_way_back_to_the_title() -> void:
	var model := _adapter.arcade_end_model(_fight_summary())
	assert_eq(model["hint"], "ENTER VOLTA AO TÍTULO")
	assert_eq(_adapter.victory_model(_fight_summary())["hint"], "ENTER CONTINUA")


func test_every_copy_string_has_a_glyph_in_the_bitmap_font() -> void:
	for kind in KINDS:
		var model := _adapter.model_for(kind, _fight_summary())
		var texts: Array = [model["title"], model["hint"]]
		for line in model["lines"]:
			texts.append(str(line["text"]))
		for text in texts:
			for index in str(text).length():
				assert_true(
					BitmapFont.FONT_GLYPHS.has(str(text).substr(index, 1)),
					"glifo proprio para todo caractere de '%s'" % text
				)


func test_everything_stays_inside_the_base_resolution() -> void:
	for kind in KINDS:
		var model := _adapter.model_for(kind, _fight_summary())
		var title: Vector2i = model["title_position"]
		assert_gt(title.x, 0, "titulo centralizado, nao colado na borda")
		var title_width: int = BitmapFont.text_width(model["title"]) * int(model["title_scale"])
		assert_lt(title.x + title_width, BASE_SIZE.x, "titulo dentro da resolucao base")
		for line in model["lines"]:
			var position: Vector2i = line["position"]
			var width: int = BitmapFont.text_width(str(line["text"])) * int(line["scale"])
			assert_true(position.x >= 0 and position.x + width <= BASE_SIZE.x, "linha dentro da tela")
		var bar: Rect2i = model["bar_fill_rect"]
		assert_true(bar.end.x <= BASE_SIZE.x, "barra de progresso dentro da tela")


func test_the_progress_bar_follows_the_arcade_position() -> void:
	var early := _adapter.victory_model(_fight_summary())
	var late_summary := _fight_summary()
	late_summary["fight"] = 7
	var late := _adapter.arcade_end_model(late_summary)
	assert_almost_eq(float(early["progress"]), 3.0 / 7.0, 0.01, "Peleja 3 de 7")
	assert_almost_eq(float(late["progress"]), 1.0, 0.01, "fim do arcade, barra cheia")
	assert_gt(late["bar_fill_rect"].size.x, early["bar_fill_rect"].size.x)


func test_the_result_model_never_discloses_the_hidden_advantage() -> void:
	var hud := HudAdapter.new()
	for kind in KINDS:
		var model := _adapter.model_for(kind, _fight_summary())
		assert_false(
			hud.discloses_hidden_advantage(model),
			"a tela de fim de %s nao expoe vida, dano nem vantagem" % kind
		)
