extends GutTest
## Os sete Oponentes do arcade, exercitados contra a ARTE REAL.
##
## Nao ha mock de arquivo: cada `assets/spritesheets/<slug>.json` e lido pelo
## `godot-asset-gateway` de producao, decodificado no dominio e validado. E o dado
## que a evidencia do ticket 6 imprime, um print por Oponente.

const SPRITESHEET_DIR := "res://assets/spritesheets"
const SPRITESHEET_SLUGS := [
	"capataz",
	"banqueiro",
	"redpill",
	"camisa-verde",
	"doutor-pureza",
	"fantasma-do-reich",
	"falso-pastor",
]

## Contrato de quadro por animacao, o mesmo do Saci: os Oponentes reusam o
## formato fixado no ticket 4, nao um formato proprio.
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


func test_the_seven_opponents_are_the_arcade_order() -> void:
	assert_eq(SPRITESHEET_SLUGS, Array(ArcadeOrder.slugs()), "um Oponente por Arquetipo")
	assert_eq(SPRITESHEET_SLUGS, Array(OpponentProfile.roster().map(_slug_of)))


func test_every_opponent_has_a_coded_spritesheet_by_slug() -> void:
	for slug in SPRITESHEET_SLUGS:
		var data: Dictionary = _gateway.load_spritesheet(slug)
		assert_false(data.is_empty(), "spritesheet codificado de %s" % slug)
		assert_true(_gateway.has_spritesheet(slug), "o gateway reconhece %s" % slug)
		assert_eq(_gateway.spritesheet_path(slug), "%s/%s.json" % [SPRITESHEET_DIR, slug])
		assert_true(_gateway.exists(slug), "o slug conta como existente")


func test_every_opponent_passes_the_whole_format_validation() -> void:
	for slug in SPRITESHEET_SLUGS:
		var sheet := _sheet(slug)
		assert_eq(sheet.slug, slug)
		assert_eq(sheet.version, Spritesheet.FORMAT_VERSION)
		assert_true(sheet.is_valid(), "%s sem problemas: %s" % [slug, sheet.errors()])
		for animation_name in Spritesheet.REQUIRED_ANIMATIONS:
			assert_true(sheet.has_animation(animation_name), "%s/%s" % [slug, animation_name])


func test_every_animation_has_the_documented_frame_count_and_size() -> void:
	for slug in SPRITESHEET_SLUGS:
		var sheet := _sheet(slug)
		assert_eq(
			sheet.animation_names().size(),
			FRAME_SIZES.size(),
			"%s tem as dez animacoes" % slug
		)
		for animation_name in FRAME_SIZES:
			assert_eq(
				sheet.frame_count(animation_name),
				FRAME_COUNTS[animation_name],
				"frames de %s/%s" % [slug, animation_name]
			)
			for frame_index in sheet.frame_count(animation_name):
				assert_eq(
					sheet.frame_size(animation_name, frame_index),
					FRAME_SIZES[animation_name],
					"quadro de %s/%s[%d]" % [slug, animation_name, frame_index]
				)


func test_every_palette_is_small_and_every_pixel_is_inside_it() -> void:
	for slug in SPRITESHEET_SLUGS:
		var sheet := _sheet(slug)
		assert_gt(sheet.palette.size(), 5, "a paleta de %s tem cores de verdade" % slug)
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
					"matriz completa em %s/%s[%d]" % [slug, animation_name, frame_index]
				)
				for pixel in pixels:
					assert_true(pixel < sheet.palette.size(), "indice dentro da paleta de %s" % slug)
					used[pixel] = true
		assert_gt(used.size(), 6, "a arte de %s usa as cores da paleta" % slug)


func test_the_seven_are_visually_distinct_from_each_other() -> void:
	var signatures := {}
	for slug in SPRITESHEET_SLUGS:
		var sheet := _sheet(slug)
		var signature := "%s|%d" % [_palette_key(sheet), sheet.frame_pixels("idle", 0).size()]
		assert_false(signatures.has(signature), "%s tem paleta propria" % slug)
		signatures[signature] = slug
		assert_eq(_silhouette(sheet, "idle", 0).is_empty(), false, "%s tem silhueta" % slug)
	assert_eq(signatures.size(), 7)
	var silhouettes := {}
	for slug in SPRITESHEET_SLUGS:
		silhouettes[_silhouette(_sheet(slug), "idle", 0)] = slug
	assert_gt(silhouettes.size(), 4, "as silhuetas nao sao todas a mesma")


func test_the_special_frame_of_every_opponent_is_the_signature_one() -> void:
	for slug in SPRITESHEET_SLUGS:
		var sheet := _sheet(slug)
		assert_eq(sheet.frame_count("special"), 3, "o golpe proprio tem tres quadros")
		assert_gt(
			sheet.frame_size("special", 2).x,
			sheet.frame_size("idle", 0).x,
			"%s: o quadro do golpe proprio e maior que o corpo parado" % slug
		)
		var used_in_special := {}
		for pixel in sheet.frame_pixels("special", 2):
			used_in_special[pixel] = true
		assert_gt(used_in_special.size(), 2, "%s desenha algo no quadro do golpe" % slug)


func test_the_opponents_are_data_and_not_binary_sprites() -> void:
	var directory := DirAccess.open(SPRITESHEET_DIR)
	assert_not_null(directory, "o diretorio de spritesheets existe")
	for file_name in directory.get_files():
		assert_false(
			file_name.ends_with(".png") or file_name.ends_with(".jpg"),
			"nenhuma imagem binaria de lutador versionada: %s" % file_name
		)
	for slug in SPRITESHEET_SLUGS:
		assert_true(FileAccess.file_exists("%s/%s.json" % [SPRITESHEET_DIR, slug]))
		assert_gt(_sheet(slug).frame_pixels("idle", 0).size(), 0, "os pixels vem do arquivo")


## A aparencia do Oponente que o arcade enfrenta e a mesma arte validada aqui.
func test_the_arcade_faces_the_sprite_of_its_archetype() -> void:
	var arcade := ArcadeService.new(
		SampleInputGateway.new(),
		SampleRenderGateway.new(),
		InMemoryAssetGateway.new(),
		SilentAudioGateway.new()
	)
	assert_true(arcade.execute())
	var slugs := Array(arcade.opponent_slugs())
	assert_eq(slugs, SPRITESHEET_SLUGS, "as sete Pelejas, na ordem fixa")
	for slug in slugs:
		assert_true(_gateway.has_spritesheet(slug), "a arte de %s existe no repositorio" % slug)
	assert_eq(
		arcade.opponent_slug(),
		_spawned_slug(arcade),
		"a primeira Peleja enfrenta o Oponente do primeiro Arquetipo"
	)


## Slug do perfil que a Peleja corrente realmente montou.
func _spawned_slug(arcade: ArcadeService) -> String:
	return arcade.match_service.opponent_profile.slug


func _sheet(slug: String) -> Spritesheet:
	return Spritesheet.decode(_gateway.load_spritesheet(slug))


func _slug_of(profile: OpponentProfile) -> String:
	return profile.slug


## Chave estavel da paleta: duas artes com as mesmas cores nao sao distintas.
func _palette_key(sheet: Spritesheet) -> String:
	var key := ""
	for index in sheet.palette.size():
		key += sheet.palette[index].to_html()
	return key


## Silhueta do quadro: onde ha pixel opaco. Serve para provar que os Oponentes
## nao sao o mesmo boneco pintado de outra cor.
func _silhouette(sheet: Spritesheet, animation_name: String, frame_index: int) -> String:
	var rows := PackedStringArray()
	var size := sheet.frame_size(animation_name, frame_index)
	for y in size.y:
		var line := ""
		for x in size.x:
			var opaque := sheet.pixel_at(animation_name, frame_index, x, y) != 0
			line += "#" if opaque else "."
		rows.append(line)
	return "\n".join(rows)