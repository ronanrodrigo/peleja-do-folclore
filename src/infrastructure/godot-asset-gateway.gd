class_name GodotAssetGateway
extends AssetGateway
## Adapter de producao da capacidade "obter arte e dados por identificador".
##
## A arte gerada por IA (cenarios, paineis de Reviravolta e retratos) vive em
## `assets/generated/<tipo>/<slug>.png`, com os metadados no `.json` ao lado e a
## paleta do jogo em `assets/palettes/<id>.json`. Este adapter carrega por slug.
##
## Arte ausente nunca quebra o jogo: quando o PNG nao existe, `load_panel`
## devolve o fallback que o chamador passou; sem fallback do chamador, devolve o
## fallback em codigo -- 426x240 determinIstico a partir do slug (ADR 0005).
## Spritesheet de lutador nao passa por aqui: e dado versionado, nao PNG.

const GENERATED_ROOT := "res://assets/generated"
const PALETTE_ROOT := "res://assets/palettes"
## Spritesheets codificados dos lutadores (dado versionado, ADR 0005).
const SPRITESHEET_ROOT := "res://assets/spritesheets"
const IMAGE_SUFFIX := ".png"
const JSON_SUFFIX := ".json"

## Tipos de arte gerada aceitos, na ordem em que o slug e procurado.
const ART_KINDS: Array[String] = ["backgrounds", "panels", "portraits"]

## Resolucao base do jogo (ADR 0002): o fallback em codigo tem exatamente este tamanho.
const BASE_SIZE := Vector2i(426, 240)

## Cores do fallback em codigo -- as mesmas constantes da tela de titulo.
const FALLBACK_SKY := Color8(18, 18, 42)
const FALLBACK_HILLS := Color8(22, 22, 52)
const FALLBACK_GROUND := Color8(34, 26, 46)
const FALLBACK_ACCENT := Color8(255, 211, 92)
const FALLBACK_HORIZON_Y := 196


## O identificador existe: spritesheet codificado, paleta versionada ou arte
## gerada com este slug.
func exists(id: String) -> bool:
	return has_spritesheet(id) or not load_palette(id).is_empty() or has_art(id)


## Paleta de cores por identificador, lida de `assets/palettes/<id>.json`.
func load_palette(id: String) -> PackedColorArray:
	var colors := PackedColorArray()
	if id.is_empty():
		return colors
	var entries: Variant = _read_json("%s/%s%s" % [PALETTE_ROOT, id, JSON_SUFFIX]).get("colors", [])
	if typeof(entries) != TYPE_ARRAY:
		return colors
	for entry in entries:
		var color := _color_from_entry(entry)
		if color.a > 0.0 or color.r + color.g + color.b > 0.0:
			colors.append(color)
	return colors


## Spritesheet de lutador por slug: dado versionado (ADR 0005), nao arte gerada.
## Lido de `assets/spritesheets/<slug>.json` e devolvido como dicionario; quem
## valida e quem desenha e o dominio (`Spritesheet.decode`) e o render adapter.
## Slug sem arquivo volta vazio, sem tocar na engine.
func load_spritesheet(slug: String) -> Dictionary:
	if not has_spritesheet(slug):
		return {}
	return _read_json(spritesheet_path(slug))


## Caminho do JSON codificado de um lutador.
func spritesheet_path(slug: String) -> String:
	if slug.is_empty():
		return ""
	return "%s/%s%s" % [SPRITESHEET_ROOT, slug, JSON_SUFFIX]


## Existe spritesheet codificado versionado para este slug. Vale tanto o arquivo
## no disco (dev e build) quanto o recurso empacotado no export web.
func has_spritesheet(slug: String) -> bool:
	var path := spritesheet_path(slug)
	if path.is_empty():
		return false
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)


## Painel de tela cheia por slug: pixels RGBA8 da arte gerada, ou fallback.
func load_panel(slug: String, fallback: PackedByteArray) -> PackedByteArray:
	var image := load_art_image(slug)
	if image != null:
		return _rgba8_pixels(image)
	if not fallback.is_empty():
		return fallback
	return code_fallback(slug)


## Existe arte gerada para este slug em algum dos tipos aceitos.
func has_art(slug: String) -> bool:
	return not art_path(slug).is_empty()


## Caminho do PNG da arte, ou string vazia quando o slug nao existe.
func art_path(slug: String) -> String:
	if slug.is_empty():
		return ""
	for kind in ART_KINDS:
		var candidate := "%s/%s/%s%s" % [GENERATED_ROOT, kind, slug, IMAGE_SUFFIX]
		if ResourceLoader.exists(candidate):
			return candidate
	return ""


## Metadados versionados da arte (prompt, seed, workflow, modelo e licenca).
## Dicionario vazio quando o slug nao existe ou o arquivo esta ilegivel.
func metadata(slug: String) -> Dictionary:
	var path := art_path(slug)
	if path.is_empty():
		return {}
	return _read_json(path.get_basename() + JSON_SUFFIX)


## Imagem da arte gerada, ou null quando o slug nao tem PNG.
func load_art_image(slug: String) -> Image:
	var path := art_path(slug)
	if path.is_empty():
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	return texture.get_image()


## Fallback em codigo: 426x240 deterministico derivado do slug, na paleta do jogo.
func code_fallback(slug: String) -> PackedByteArray:
	var seed_value := _slug_seed(slug)
	var image := Image.create_empty(BASE_SIZE.x, BASE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(FALLBACK_SKY)
	image.fill_rect(
		Rect2i(0, FALLBACK_HORIZON_Y, BASE_SIZE.x, BASE_SIZE.y - FALLBACK_HORIZON_Y),
		FALLBACK_GROUND
	)
	image.fill_rect(Rect2i(0, FALLBACK_HORIZON_Y - 24, BASE_SIZE.x, 24), FALLBACK_HILLS)
	for index in 32:
		var x := (index * 61 + seed_value) % BASE_SIZE.x
		var y := (index * 37 + seed_value / 7) % (FALLBACK_HORIZON_Y - 96)
		image.set_pixel(x, y, FALLBACK_ACCENT)
	return image.get_data()


## Pixels RGBA8 da imagem. No Godot 4 a conversao de formato e in-place e devolve
## void, entao ela nao pode aparecer numa expressao.
func _rgba8_pixels(image: Image) -> PackedByteArray:
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image.get_data()


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		# Sem arquivo no disco, o JSON ainda pode existir como recurso importado.
		if not ResourceLoader.exists(path):
			return {}
		var resource: Variant = load(path)
		if resource is JSON:
			var data: Variant = (resource as JSON).data
			return data if typeof(data) == TYPE_DICTIONARY else {}
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _color_from_entry(entry: Variant) -> Color:
	if typeof(entry) == TYPE_DICTIONARY:
		var record: Dictionary = entry
		if record.has("rgb"):
			var rgb: Variant = record["rgb"]
			if typeof(rgb) == TYPE_ARRAY and (rgb as Array).size() >= 3:
				return Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))
		if record.has("hex"):
			return Color(str(record["hex"]))
		return Color(0, 0, 0, 0)
	if typeof(entry) == TYPE_ARRAY and (entry as Array).size() >= 3:
		return Color8(int(entry[0]), int(entry[1]), int(entry[2]))
	return Color(0, 0, 0, 0)


## Valor estavel por slug (sem aleatoriedade): mesma arte, mesmo fallback.
func _slug_seed(slug: String) -> int:
	var value := 0
	for index in slug.length():
		value = (value * 31 + slug.unicode_at(index)) % 4093
	return value
