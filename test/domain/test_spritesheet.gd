extends GutTest
## Spritesheet codificado: paleta + matrizes de pixel, sem renderizar nada.

const FRAME_WIDTH := 2
const FRAME_HEIGHT := 2


func test_valid_sheet_passes_every_check() -> void:
	var sheet := Spritesheet.decode(_valid_data())
	assert_true(sheet.is_valid(), "nenhum problema: %s" % [sheet.errors()])
	assert_eq(sheet.errors().size(), 0)
	assert_eq(sheet.slug, "saci")
	assert_eq(sheet.version, Spritesheet.FORMAT_VERSION)
	assert_eq(sheet.palette.size(), 2)
	assert_eq(sheet.animation_names().size(), Spritesheet.REQUIRED_ANIMATIONS.size())


func test_frames_are_readable_after_decoding() -> void:
	var sheet := Spritesheet.decode(_valid_data())
	assert_true(sheet.has_animation("idle"))
	assert_eq(sheet.frame_count("idle"), 1)
	assert_eq(sheet.frame_size("idle", 0), Vector2i(FRAME_WIDTH, FRAME_HEIGHT))
	assert_eq(sheet.frame_pixels("idle", 0).size(), FRAME_WIDTH * FRAME_HEIGHT)
	assert_eq(sheet.color_of(1), Color.html("#1b2a3a"))
	assert_eq(sheet.color_of(99), Color(0, 0, 0, 0), "indice fora da paleta e transparente")


func test_missing_frame_returns_empty_values() -> void:
	var sheet := Spritesheet.decode(_valid_data())
	assert_eq(sheet.frame_at("idle", 7), {})
	assert_eq(sheet.frame_size("idle", 7), Vector2i.ZERO)
	assert_eq(sheet.frame_pixels("idle", 7), PackedByteArray())
	assert_eq(sheet.frame_count("voando"), 0)


func test_row_encoded_pixels_are_flattened() -> void:
	var data := _valid_data()
	data["animations"]["idle"] = [{"width": 2, "height": 2, "pixels": [[0, 1], [1, 0]]}]
	var sheet := Spritesheet.decode(data)
	assert_true(sheet.is_valid(), "linhas viram pixels na ordem de leitura")
	assert_eq(sheet.frame_pixels("idle", 0), PackedByteArray([0, 1, 1, 0]))


func test_empty_dictionary_is_invalid() -> void:
	var sheet := Spritesheet.decode({})
	assert_false(sheet.is_valid())
	assert_true(_has_error(sheet, "slug ausente"))
	assert_true(_has_error(sheet, "versao"))


func test_unsupported_version_is_rejected() -> void:
	var data := _valid_data()
	data["version"] = 99
	assert_true(_has_error(Spritesheet.decode(data), "versao 99 nao suportada"))


func test_missing_required_animation_is_rejected() -> void:
	var data := _valid_data()
	data["animations"].erase("grab")
	assert_true(_has_error(Spritesheet.decode(data), "animacao obrigatoria ausente: grab"))


func test_empty_palette_is_rejected() -> void:
	var data := _valid_data()
	data["palette"] = []
	assert_true(_has_error(Spritesheet.decode(data), "paleta vazia"))


func test_palette_larger_than_256_colors_is_rejected() -> void:
	var data := _valid_data()
	var palette: Array = []
	for index in Spritesheet.MAX_PALETTE_SIZE + 1:
		palette.append("#000000")
	data["palette"] = palette
	assert_true(_has_error(Spritesheet.decode(data), "excede o maximo de 256"))


func test_pixel_index_outside_the_palette_is_rejected() -> void:
	var data := _valid_data()
	data["animations"]["idle"] = [{"width": 2, "height": 2, "pixels": [0, 1, 2, 0]}]
	assert_true(_has_error(Spritesheet.decode(data), "fora da paleta"))


func test_pixel_count_must_match_the_frame_size() -> void:
	var data := _valid_data()
	data["animations"]["idle"] = [{"width": 2, "height": 2, "pixels": [0, 1, 1]}]
	assert_true(_has_error(Spritesheet.decode(data), "esperado 4"))


func test_frames_of_one_animation_must_share_dimensions() -> void:
	var data := _valid_data()
	data["animations"]["idle"] = [
		{"width": 2, "height": 2, "pixels": [0, 1, 1, 0]},
		{"width": 2, "height": 3, "pixels": [0, 1, 1, 0, 1, 0]},
	]
	assert_true(_has_error(Spritesheet.decode(data), "difere do resto da animacao"))


func test_frame_without_dimensions_is_rejected() -> void:
	var data := _valid_data()
	data["animations"]["idle"] = [{"width": 0, "height": 0, "pixels": []}]
	assert_true(_has_error(Spritesheet.decode(data), "sem dimensoes"))


func test_frame_bigger_than_the_base_resolution_is_rejected() -> void:
	var data := _valid_data()
	var width := Spritesheet.MAX_FRAME_WIDTH + 1
	var pixels: Array = []
	for index in width:
		pixels.append(0)
	data["animations"]["idle"] = [{"width": width, "height": 1, "pixels": pixels}]
	assert_true(_has_error(Spritesheet.decode(data), "excede a resolucao base"))


func test_animation_without_frames_is_rejected() -> void:
	var data := _valid_data()
	data["animations"]["idle"] = []
	assert_true(_has_error(Spritesheet.decode(data), "sem frames"))


func test_animation_that_is_not_a_frame_list_is_rejected() -> void:
	var sheet := Spritesheet.new("saci", PackedColorArray([Color.WHITE]), {"idle": "voando"})
	assert_true(_has_error(sheet, "nao e uma lista de frames"))


func test_missing_slug_is_rejected() -> void:
	var data := _valid_data()
	data["slug"] = ""
	assert_true(_has_error(Spritesheet.decode(data), "slug ausente"))


func test_container_never_has_a_binary_sprite() -> void:
	var sheet := Spritesheet.decode(_valid_data())
	assert_eq(sheet.frame_pixels("idle", 0).size(), FRAME_WIDTH * FRAME_HEIGHT)
	assert_true(sheet.color_of(sheet.frame_pixels("idle", 0)[1]).a > 0.0, "pixels vem da paleta")


func _valid_data() -> Dictionary:
	var animations := {}
	for animation_name in Spritesheet.REQUIRED_ANIMATIONS:
		animations[animation_name] = [
			{"width": FRAME_WIDTH, "height": FRAME_HEIGHT, "pixels": [0, 1, 1, 0]},
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
