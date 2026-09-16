extends GutTest
## Codificacao compacta do formato de spritesheet (ticket 4): um caractere por
## pixel, na base `PIXEL_CHARS`, e a leitura da matriz pelo renderer.
##
## O arquivo base (paleta, dimensoes, frames por animacao) fica em
## test_spritesheet.gd; aqui esta o que a fatia do ticket 4 acrescentou ao
## formato -- sem mudar o contrato existente.

const FRAME_SIZE := 2


func test_row_strings_are_decoded_as_pixels() -> void:
	var sheet := Spritesheet.decode(_data_with_rows(["01", "10"]))
	assert_true(sheet.is_valid(), "linhas compactas passam na validacao: %s" % [sheet.errors()])
	assert_eq(sheet.frame_pixels("idle", 0), PackedByteArray([0, 1, 1, 0]))
	assert_eq(sheet.frame_size("idle", 0), Vector2i(FRAME_SIZE, FRAME_SIZE))


func test_row_strings_equal_the_index_row_encoding() -> void:
	var rows_sheet := Spritesheet.decode(_data_with_rows(["01", "10"]))
	var lists_sheet := Spritesheet.decode(_data_with_rows([[0, 1], [1, 0]]))
	assert_eq(
		rows_sheet.frame_pixels("idle", 0),
		lists_sheet.frame_pixels("idle", 0),
		"as tres codificacoes chegam na mesma matriz"
	)


func test_transparent_char_maps_to_the_reserved_index() -> void:
	var sheet := Spritesheet.decode(_data_with_rows([".1", "1."]))
	assert_true(sheet.is_valid(), "transparente e um pixel como outro qualquer")
	assert_eq(sheet.frame_pixels("idle", 0)[0], Spritesheet.TRANSPARENT_INDEX)
	assert_eq(sheet.pixel_color("idle", 0, 0, 0).a, 0.0, "pixel transparente nao tem cor")


func test_index_follows_the_pixel_alphabet_order() -> void:
	assert_eq(Spritesheet.PIXEL_CHARS[0], "0")
	assert_eq(Spritesheet.PIXEL_CHARS[1], "1")
	assert_eq(Spritesheet.TRANSPARENT_CHAR, ".")
	var sheet := Spritesheet.decode(_data_with_rows(["01", "10"]))
	assert_eq(sheet.pixel_at("idle", 0, 1, 0), 1, "o caractere e o indice da paleta")


func test_unknown_char_in_a_row_is_reported() -> void:
	var sheet := Spritesheet.decode(_data_with_rows(["0!", "10"]))
	assert_false(sheet.is_valid(), "caractere fora do alfabeto nao passa")
	assert_true(_has_error(sheet, "caractere invalido '!'"))
	assert_true(_has_error(sheet, "linha 0"), "o problema aponta a linha")


func test_a_short_row_is_caught_by_the_pixel_count() -> void:
	var sheet := Spritesheet.decode(_data_with_rows(["01", "1"]))
	assert_false(sheet.is_valid(), "linha curta vira contagem de pixels errada")
	assert_true(_has_error(sheet, "esperado 4"))


func test_pixel_at_reads_the_frame_matrix() -> void:
	var sheet := Spritesheet.decode(_data_with_rows(["01", "10"]))
	assert_eq(sheet.pixel_at("idle", 0, 0, 0), 0)
	assert_eq(sheet.pixel_at("idle", 0, 1, 0), 1)
	assert_eq(sheet.pixel_at("idle", 0, 1, 1), 0)
	assert_eq(sheet.row_pixels("idle", 0, 0), PackedByteArray([0, 1]))
	assert_true(sheet.row_pixels("idle", 0, 9).is_empty(), "linha fora do frame volta vazia")
	assert_eq(sheet.row_pixels("idle", 0, -1), PackedByteArray())


func test_pixel_at_outside_the_frame_is_transparent() -> void:
	var sheet := Spritesheet.decode(_data_with_rows(["01", "10"]))
	assert_eq(sheet.pixel_at("idle", 0, -1, 0), Spritesheet.TRANSPARENT_INDEX)
	assert_eq(sheet.pixel_at("idle", 0, 9, 9), Spritesheet.TRANSPARENT_INDEX)
	assert_eq(sheet.pixel_at("voando", 0, 0, 0), Spritesheet.TRANSPARENT_INDEX)


func test_pixel_color_comes_from_the_palette() -> void:
	var sheet := Spritesheet.decode(_data_with_rows(["01", "10"]))
	assert_eq(sheet.pixel_color("idle", 0, 1, 0), Color.html("#1b2a3a"))
	assert_eq(
		sheet.pixel_color("idle", 0, 0, 0),
		Color(0, 0, 0, 0),
		"o indice transparente nao tem cor"
	)


func _data_with_rows(rows: Array) -> Dictionary:
	var animations := {}
	for animation_name in Spritesheet.REQUIRED_ANIMATIONS:
		animations[animation_name] = [
			{"width": FRAME_SIZE, "height": FRAME_SIZE, "pixels": rows},
		]
	return {
		"slug": "saci",
		"version": Spritesheet.FORMAT_VERSION,
		"palette": ["#00000000", "#1b2a3aff"],
		"animations": animations,
	}


func _has_error(sheet: Spritesheet, fragment: String) -> bool:
	for problem in sheet.errors():
		if problem.contains(fragment):
			return true
	push_error("erro esperado nao encontrado: %s -- %s" % [fragment, sheet.errors()])
	return false
