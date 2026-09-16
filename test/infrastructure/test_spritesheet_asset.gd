extends GutTest
## O formato codificado, exercitado contra a ARTE REAL do Saci.
##
## Aqui nao ha mock de arquivo: `assets/spritesheets/saci.json` e lido pelo
## `godot-asset-gateway` de producao, decodificado no dominio e validado. E o
## dado que a evidencia do ticket 4 imprime tela por tela.

const SPRITESHEET_SLUG := "saci"
const SPRITESHEET_PATH := "res://assets/spritesheets/saci.json"
const SPRITESHEET_DIR := "res://assets/spritesheets"
const FORMAT_DOC := "res://docs/spritesheet-format.md"
const MISSING_SLUG := "lutador-que-nao-existe"

## Tamanho de quadro por animacao do Saci, como documentado em
## docs/spritesheet-format.md. Mudar a arte exige mudar o contrato de proposito.
const FRAME_SIZES := {
	"idle": Vector2i(24, 34),
	"walk": Vector2i(24, 34),
	"crouch": Vector2i(26, 20),
	"block": Vector2i(24, 34),
	"light": Vector2i(24, 34),
	"heavy": Vector2i(32, 34),
	"grab": Vector2i(24, 34),
	"special": Vector2i(40, 40),
	"hurt": Vector2i(24, 34),
	"ko": Vector2i(34, 20),
}

const FRAME_COUNTS := {
	"idle": 2,
	"walk": 4,
	"crouch": 2,
	"block": 2,
	"light": 2,
	"heavy": 2,
	"grab": 2,
	"special": 3,
	"hurt": 2,
	"ko": 2,
}

var _gateway: GodotAssetGateway


func before_each() -> void:
	_gateway = GodotAssetGateway.new()


func test_the_gateway_loads_the_coded_spritesheet_by_slug() -> void:
	var data: Dictionary = _gateway.load_spritesheet(SPRITESHEET_SLUG)
	assert_false(data.is_empty(), "o JSON codificado foi lido de %s" % SPRITESHEET_PATH)
	assert_true(_gateway.has_spritesheet(SPRITESHEET_SLUG), "o gateway reconhece o slug")
	assert_eq(_gateway.spritesheet_path(SPRITESHEET_SLUG), SPRITESHEET_PATH)
	assert_true(_gateway.exists(SPRITESHEET_SLUG), "e o slug conta como existente")


func test_an_unknown_slug_has_no_spritesheet() -> void:
	assert_true(_gateway.load_spritesheet(MISSING_SLUG).is_empty())
	assert_false(_gateway.has_spritesheet(MISSING_SLUG))
	assert_true(_gateway.load_spritesheet("").is_empty(), "slug vazio nao le arquivo")


func test_the_saci_passes_the_whole_format_validation() -> void:
	var sheet := _sheet()
	assert_eq(sheet.slug, SPRITESHEET_SLUG)
	assert_eq(sheet.version, Spritesheet.FORMAT_VERSION)
	assert_true(sheet.is_valid(), "sem problemas de formato: %s" % [sheet.errors()])


func test_the_saci_has_every_required_animation() -> void:
	var sheet := _sheet()
	for animation_name in Spritesheet.REQUIRED_ANIMATIONS:
		assert_true(sheet.has_animation(animation_name), "animacao %s" % animation_name)
		assert_gt(sheet.frame_count(animation_name), 0, "%s tem frames" % animation_name)


func test_every_animation_has_the_documented_frame_count_and_size() -> void:
	var sheet := _sheet()
	assert_eq(sheet.animation_names().size(), FRAME_SIZES.size(), "o Saci tem as dez animacoes")
	for animation_name in FRAME_SIZES:
		var expected_size: Vector2i = FRAME_SIZES[animation_name]
		assert_eq(
			sheet.frame_count(animation_name),
			FRAME_COUNTS[animation_name],
			"frames de %s" % animation_name
		)
		for frame_index in sheet.frame_count(animation_name):
			assert_eq(
				sheet.frame_size(animation_name, frame_index),
				expected_size,
				"quadro de %s[%d]" % [animation_name, frame_index]
			)


func test_the_palette_is_small_and_every_pixel_is_inside_it() -> void:
	var sheet := _sheet()
	assert_gt(sheet.palette.size(), 1, "a paleta tem as cores da arte")
	assert_true(sheet.palette.size() <= Spritesheet.MAX_PALETTE_SIZE, "dentro do maximo do formato")
	assert_eq(sheet.color_of(Spritesheet.TRANSPARENT_INDEX).a, 0.0, "o indice 0 e transparente")
	var used := {}
	for animation_name in sheet.animation_names():
		for frame_index in sheet.frame_count(animation_name):
			var pixels := sheet.frame_pixels(animation_name, frame_index)
			assert_eq(
				pixels.size(),
				sheet.frame_size(animation_name, frame_index).x
				* sheet.frame_size(animation_name, frame_index).y,
				"matriz completa em %s[%d]" % [animation_name, frame_index]
			)
			for pixel in pixels:
				assert_true(pixel < sheet.palette.size(), "indice dentro da paleta")
				used[pixel] = true
	assert_gt(used.size(), 5, "a arte usa as cores da paleta de verdade")


func test_the_saci_is_drawn_from_data_and_not_from_a_binary_sprite() -> void:
	var directory := DirAccess.open(SPRITESHEET_DIR)
	assert_not_null(directory, "o diretorio de spritesheets existe")
	for file_name in directory.get_files():
		assert_false(
			file_name.ends_with(".png") or file_name.ends_with(".jpg"),
			"nenhuma imagem binaria de lutador versionada: %s" % file_name
		)
	assert_true(FileAccess.file_exists(SPRITESHEET_PATH), "a arte e o JSON versionado")
	var sheet := _sheet()
	assert_gt(sheet.frame_pixels("idle", 0).size(), 0, "os pixels vem do arquivo, nao de imagem")


func test_the_frame_of_the_special_is_the_redemoinho() -> void:
	var sheet := _sheet()
	assert_eq(sheet.frame_count("special"), 3, "o turbilhao cresce em tres quadros")
	var effect := SpecialMoveTable.for_guardian(GuardianStats.SACI)
	assert_eq(effect.display_name, SpecialMove.REDEMOINHO)
	assert_true(effect.has_pull(), "e o golpe puxa o Oponente")
	assert_true(
		sheet.frame_size("special", 2).x > sheet.frame_size("idle", 0).x,
		"o quadro do turbilhao e maior que o do corpo parado"
	)


func test_the_format_is_documented_in_docs() -> void:
	var doc := FileAccess.get_file_as_string(FORMAT_DOC)
	assert_ne(doc, "", "docs/spritesheet-format.md existe")
	for animation_name in Spritesheet.REQUIRED_ANIMATIONS:
		assert_true(doc.contains(animation_name), "o formato documenta %s" % animation_name)
	assert_true(doc.contains("assets/spritesheets/<slug>.json"), "documenta o caminho do arquivo")
	assert_true(doc.contains("escala inteira"), "documenta a escala inteira")
	assert_true(doc.contains("PIXEL_CHARS"), "documenta a codificacao compacta")


func _sheet() -> Spritesheet:
	return Spritesheet.decode(_gateway.load_spritesheet(SPRITESHEET_SLUG))
