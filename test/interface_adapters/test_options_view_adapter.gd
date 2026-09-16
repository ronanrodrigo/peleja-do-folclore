extends GutTest
## O adapter de apresentacao das opcoes traduz estado (volume, mudo) em copy
## pt-BR e num modelo que a cena desenha. Nada de engine aqui: e a borda de
## apresentacao, onde a copy do jogo vive.

var _adapter: OptionsViewAdapter


func before_each() -> void:
	_adapter = OptionsViewAdapter.new()


func test_copy_is_portuguese_and_lives_in_the_presentation_edge() -> void:
	assert_eq(_adapter.title_text(), "OPÇÕES", "titulo em pt-BR, com acento")
	assert_eq(_adapter.hint_text(), "SETAS VOLUME  ENTER MUDO  ESC VOLTA", "dica de teclas")
	assert_eq(_adapter.mute_text(false), "LIGADO", "som ligado")
	assert_eq(_adapter.mute_text(true), "MUDO", "som mudo")
	assert_eq(_adapter.volume_text(70), "70%", "percentual do volume")
	assert_eq(_adapter.volume_text(0), "0%")
	assert_eq(_adapter.volume_text(200), "100%", "percentual fora da faixa e limitado")


func test_every_copy_string_has_a_glyph_in_the_bitmap_font() -> void:
	var font := PixelFont.new()
	for text in _adapter.copy_strings():
		assert_true(font.supports(text), "fonte cobre a copy: %s" % text)
	for percent in [0, 5, 12, 40, 70, 100]:
		assert_true(
			font.supports(_adapter.volume_text(percent)),
			"fonte cobre o percentual %d%%" % percent
		)


func test_view_model_for_volume_and_sound_on() -> void:
	var model := _adapter.view_model(70, false)
	assert_eq(model["title"], "OPÇÕES")
	var rows: Array = model["rows"]
	assert_eq(rows.size(), 3, "tres linhas: volume, som e controles")
	assert_eq(rows[0]["key"], OptionsViewAdapter.ROW_VOLUME)
	assert_eq(rows[0]["label"], "VOLUME")
	assert_eq(rows[0]["value"], "70%")
	assert_almost_eq(float(rows[0]["bar"]), 0.7, 0.001, "barra do volume na proporcao")
	assert_eq(rows[1]["key"], OptionsViewAdapter.ROW_MUTE)
	assert_eq(rows[1]["label"], "SOM")
	assert_eq(rows[1]["value"], "LIGADO")
	assert_almost_eq(float(rows[1]["bar"]), 1.0, 0.001, "som ligado, indicador cheio")
	assert_eq(rows[2]["key"], OptionsViewAdapter.ROW_CONTROLS, "a linha do remap")
	assert_eq(rows[2]["value"], "PADRÃO", "controles no padrao")
	assert_almost_eq(float(rows[2]["bar"]), 0.0, 0.001, "indicador vazio no padrao")


func test_view_model_for_muted_sound() -> void:
	var model := _adapter.view_model(20, true)
	var rows: Array = model["rows"]
	assert_eq(rows[1]["value"], "MUDO", "copy do mudo")
	assert_almost_eq(float(rows[1]["bar"]), 0.0, 0.001, "mudo, indicador vazio")


func test_ratios_are_clamped() -> void:
	assert_almost_eq(_adapter.volume_ratio(-10), 0.0, 0.001, "volume negativo vira 0")
	assert_almost_eq(_adapter.volume_ratio(150), 1.0, 0.001, "volume acima de 100 vira 1")
	assert_almost_eq(_adapter.mute_ratio(false), 1.0, 0.001)
	assert_almost_eq(_adapter.mute_ratio(true), 0.0, 0.001)

func test_the_remap_copy_names_the_actions_and_the_keys_in_portuguese() -> void:
	assert_eq(_adapter.controls_text(false), "PADRÃO")
	assert_eq(_adapter.controls_text(true), "AJUSTADO")
	assert_eq(_adapter.action_label("move_left"), "ESQUERDA")
	assert_eq(_adapter.action_label("grab"), "AGARRÃO")
	assert_eq(_adapter.key_label(KEY_J), "J")
	assert_eq(_adapter.key_label(KEY_RIGHT), "DIR")
	assert_eq(_adapter.key_label(KEY_ESCAPE), "ESC")
	assert_eq(_adapter.remap_text("special", KEY_U), "ESPECIAL: U")
	assert_eq(_adapter.hint_for(true), "PRESSIONE UMA TECLA")
	assert_eq(_adapter.hint_for(false), "SETAS VOLUME  ENTER MUDO  ESC VOLTA")


func test_the_footer_fits_inside_the_panel_width() -> void:
	var font := PixelFont.new()
	var width: int = font.text_size(_adapter.hint_text(), 1).x
	var panel := Rect2i(16, 14, 394, 212)
	var centered_x: int = (426 - width) / 2
	assert_true(centered_x >= panel.position.x, "a dica comeca dentro do painel")
	assert_true(
		centered_x + width <= panel.end.x,
		"a dica nao encosta na borda direita (nit do ticket 10)"
	)
