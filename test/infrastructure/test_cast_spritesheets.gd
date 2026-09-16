extends GutTest
## A arte codificada do elenco completo, exercitada contra os ARQUIVOS reais.
##
## Curupira, Iara e Cuca sao lidos pelo `godot-asset-gateway` de producao,
## decodificados no dominio e validados como o Saci do ticket 4: e o mesmo dado
## versionado que a tela de selecao desenha e que a evidencia imprime.

const SPRITESHEET_DIR := "res://assets/spritesheets"
const FORMAT_DOC := "res://docs/spritesheet-format.md"
const NEW_SLUGS := ["curupira", "iara", "cuca"]

## Quadro por animacao do elenco (mesmo esquema do Saci, documentado no formato).
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


func test_the_roster_matches_the_spritesheet_files() -> void:
	assert_eq(
		GuardianStats.slugs(),
		PackedStringArray(["saci", "curupira", "iara", "cuca"]),
		"um arquivo de arte por Guardiao do elenco"
	)
	for slug in GuardianStats.slugs():
		assert_true(FileAccess.file_exists("%s/%s.json" % [SPRITESHEET_DIR, slug]), "arte de %s" % slug)


func test_every_new_guardian_decodes_and_passes_the_format() -> void:
	for slug in NEW_SLUGS:
		var data: Dictionary = _gateway.load_spritesheet(slug)
		assert_false(data.is_empty(), "o JSON codificado de %s foi lido" % slug)
		assert_true(_gateway.has_spritesheet(slug))
		assert_true(_gateway.exists(slug))
		var sheet := Spritesheet.decode(data)
		assert_eq(sheet.slug, slug)
		assert_true(sheet.is_valid(), "%s sem problemas de formato: %s" % [slug, sheet.errors()])


func test_every_new_guardian_has_the_ten_required_animations() -> void:
	for slug in NEW_SLUGS:
		var sheet := _sheet(slug)
		assert_eq(sheet.animation_names().size(), FRAME_SIZES.size(), "%s tem dez animacoes" % slug)
		for animation_name in Spritesheet.REQUIRED_ANIMATIONS:
			assert_true(sheet.has_animation(animation_name), "%s: %s" % [slug, animation_name])
			assert_eq(
				sheet.frame_count(animation_name),
				FRAME_COUNTS[animation_name],
				"%s: frames de %s" % [slug, animation_name]
			)
			for frame_index in sheet.frame_count(animation_name):
				assert_eq(
					sheet.frame_size(animation_name, frame_index),
					FRAME_SIZES[animation_name],
					"%s: quadro de %s[%d]" % [slug, animation_name, frame_index]
				)


func test_every_pixel_of_the_new_art_is_inside_the_palette() -> void:
	for slug in NEW_SLUGS:
		var sheet := _sheet(slug)
		assert_gt(sheet.palette.size(), 1)
		assert_true(sheet.palette.size() <= Spritesheet.MAX_PALETTE_SIZE)
		assert_eq(sheet.color_of(Spritesheet.TRANSPARENT_INDEX).a, 0.0, "indice 0 transparente")
		var used := {}
		for animation_name in sheet.animation_names():
			for frame_index in sheet.frame_count(animation_name):
				var pixels := sheet.frame_pixels(animation_name, frame_index)
				assert_eq(
					pixels.size(),
					sheet.frame_size(animation_name, frame_index).x
					* sheet.frame_size(animation_name, frame_index).y,
					"%s: matriz completa em %s[%d]" % [slug, animation_name, frame_index]
				)
				for pixel in pixels:
					assert_true(pixel < sheet.palette.size(), "%s: indice dentro da paleta" % slug)
					used[pixel] = true
		assert_gt(used.size(), 5, "a arte de %s usa as cores da paleta" % slug)


func test_the_new_guardians_have_no_binary_sprite_committed() -> void:
	var directory := DirAccess.open(SPRITESHEET_DIR)
	assert_not_null(directory)
	for file_name in directory.get_files():
		assert_false(
			file_name.ends_with(".png") or file_name.ends_with(".jpg"),
			"nenhuma imagem binaria de lutador versionada: %s" % file_name
		)


func test_each_new_special_is_drawn_in_a_wider_frame() -> void:
	for slug in NEW_SLUGS:
		var sheet := _sheet(slug)
		assert_gt(
			sheet.frame_size("special", 2).x,
			sheet.frame_size("idle", 0).x,
			"o quadro do Golpe Especial de %s e maior que o do corpo parado" % slug
		)


func test_the_format_document_lists_the_whole_cast() -> void:
	var doc := FileAccess.get_file_as_string(FORMAT_DOC)
	for slug in NEW_SLUGS:
		assert_true(doc.contains(slug), "docs/spritesheet-format.md documenta %s" % slug)
	assert_true(doc.contains("Pés Invertidos"), "e o Golpe Especial do Curupira")


func _sheet(slug: String) -> Spritesheet:
	return Spritesheet.decode(_gateway.load_spritesheet(slug))