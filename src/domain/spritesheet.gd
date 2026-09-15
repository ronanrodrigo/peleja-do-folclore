class_name Spritesheet
extends RefCounted
## Modelo e validacao do formato de spritesheet codificado.
##
## A arte de lutador e dado versionado no repositorio, nunca PNG binario opaco:
## uma paleta de cores e uma lista de frames por animacao, cada frame sendo uma
## matriz de indices da paleta. Este arquivo apenas modela e valida o formato --
## desenhar e do sprite-render-adapter (ticket 4), e nenhuma imagem e lida aqui.
##
## Formato de entrada (o mesmo que o asset-gateway entrega decodificado do JSON):
##   {
##     "slug": "saci",
##     "version": 1,
##     "palette": ["#00000000", "#1b2a3aff", ...],
##     "animations": {
##       "idle": [{"width": 24, "height": 34, "pixels": [0, 1, 1, 0, ...]}, ...],
##     }
##   }
## `pixels` aceita lista plana de indices ou lista de linhas, na ordem de leitura.

const FORMAT_VERSION := 1
const MAX_PALETTE_SIZE := 256
const MAX_FRAME_WIDTH := 426
const MAX_FRAME_HEIGHT := 240
## Indice de paleta reservado para pixel transparente, por convencao do formato.
const TRANSPARENT_INDEX := 0
## Animacoes que todo lutador precisa ter para entrar numa Peleja.
const REQUIRED_ANIMATIONS := [
	"idle",
	"walk",
	"crouch",
	"block",
	"light",
	"heavy",
	"grab",
	"special",
	"hurt",
	"ko",
]

var slug: String
var version: int
var palette: PackedColorArray
## Nome da animacao -> Array de frames, cada frame um Dictionary com
## "width", "height" e "pixels" (PackedByteArray de indices da paleta).
var animations: Dictionary


func _init(
	p_slug: String = "",
	p_palette: PackedColorArray = PackedColorArray(),
	p_animations: Dictionary = {}
) -> void:
	slug = p_slug
	version = FORMAT_VERSION
	palette = p_palette
	animations = p_animations


## Decodifica o formato codificado. Nunca falha na leitura: problemas de conteudo
## aparecem em `errors()`, para que a validacao fique num lugar so.
static func decode(data: Dictionary) -> Spritesheet:
	var sheet := Spritesheet.new()
	if data.is_empty():
		sheet.version = 0
		return sheet
	sheet.slug = str(data.get("slug", ""))
	sheet.version = int(data.get("version", 0))
	sheet.palette = _decode_palette(data.get("palette", []))
	sheet.animations = _decode_animations(data.get("animations", {}))
	return sheet


static func _decode_palette(raw: Variant) -> PackedColorArray:
	var colors := PackedColorArray()
	if not (raw is Array):
		return colors
	for entry in raw:
		if entry is Color:
			colors.append(entry)
		elif entry is String:
			colors.append(Color.html(entry))
	return colors


static func _decode_animations(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (raw is Dictionary):
		return result
	for animation_name in raw.keys():
		var frames: Array = []
		var raw_frames: Variant = raw[animation_name]
		if raw_frames is Array:
			for raw_frame in raw_frames:
				frames.append(_decode_frame(raw_frame))
		result[str(animation_name)] = frames
	return result


static func _decode_frame(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {"width": 0, "height": 0, "pixels": PackedByteArray()}
	var pixels := PackedByteArray()
	var raw_pixels: Variant = raw.get("pixels", [])
	if raw_pixels is PackedByteArray:
		pixels = raw_pixels
	elif raw_pixels is Array:
		for entry in raw_pixels:
			if entry is Array:
				for value in entry:
					pixels.append(int(value) & 0xFF)
			else:
				pixels.append(int(entry) & 0xFF)
	return {
		"width": int(raw.get("width", 0)),
		"height": int(raw.get("height", 0)),
		"pixels": pixels,
	}


func animation_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key in animations.keys():
		names.append(str(key))
	names.sort()
	return names


func has_animation(animation_name: String) -> bool:
	return animations.has(animation_name)


func frame_count(animation_name: String) -> int:
	var frames: Variant = animations.get(animation_name, [])
	return frames.size() if frames is Array else 0


## Frame pedido, ou dicionario vazio quando a animacao ou o indice nao existem.
func frame_at(animation_name: String, frame_index: int) -> Dictionary:
	var frames: Variant = animations.get(animation_name, [])
	if not (frames is Array) or frame_index < 0 or frame_index >= frames.size():
		return {}
	return frames[frame_index]


func frame_size(animation_name: String, frame_index: int) -> Vector2i:
	var frame := frame_at(animation_name, frame_index)
	if frame.is_empty():
		return Vector2i.ZERO
	return Vector2i(int(frame.get("width", 0)), int(frame.get("height", 0)))


func frame_pixels(animation_name: String, frame_index: int) -> PackedByteArray:
	var frame := frame_at(animation_name, frame_index)
	if frame.is_empty():
		return PackedByteArray()
	return frame.get("pixels", PackedByteArray())


func color_of(pixel_index: int) -> Color:
	if pixel_index < 0 or pixel_index >= palette.size():
		return Color(0, 0, 0, 0)
	return palette[pixel_index]


## Lista de problemas do formato; vazia quando a spritesheet esta valida.
func errors() -> PackedStringArray:
	var problems := PackedStringArray()
	if slug.is_empty():
		problems.append("slug ausente")
	if version != FORMAT_VERSION:
		problems.append("versao %d nao suportada (esperado %d)" % [version, FORMAT_VERSION])
	problems.append_array(_palette_errors())
	for animation_name in REQUIRED_ANIMATIONS:
		if not animations.has(animation_name):
			problems.append("animacao obrigatoria ausente: %s" % animation_name)
	for animation_name in animations.keys():
		problems.append_array(_animation_errors(str(animation_name)))
	return problems


func is_valid() -> bool:
	return errors().is_empty()


func _palette_errors() -> PackedStringArray:
	var problems := PackedStringArray()
	if palette.is_empty():
		problems.append("paleta vazia")
	elif palette.size() > MAX_PALETTE_SIZE:
		problems.append(
			"paleta com %d cores excede o maximo de %d" % [palette.size(), MAX_PALETTE_SIZE]
		)
	return problems


func _animation_errors(animation_name: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var frames: Variant = animations[animation_name]
	if not (frames is Array):
		problems.append("animacao %s nao e uma lista de frames" % animation_name)
		return problems
	if frames.is_empty():
		problems.append("animacao %s sem frames" % animation_name)
		return problems
	var expected := Vector2i.ZERO
	for frame_index in frames.size():
		var frame: Dictionary = frames[frame_index]
		var width := int(frame.get("width", 0))
		var height := int(frame.get("height", 0))
		var label := "%s[%d]" % [animation_name, frame_index]
		if width <= 0 or height <= 0:
			problems.append("frame %s sem dimensoes" % label)
			continue
		if width > MAX_FRAME_WIDTH or height > MAX_FRAME_HEIGHT:
			problems.append("frame %s (%dx%d) excede a resolucao base" % [label, width, height])
		if expected == Vector2i.ZERO:
			expected = Vector2i(width, height)
		elif expected != Vector2i(width, height):
			problems.append(
				"frame %s (%dx%d) difere do resto da animacao (%dx%d)"
				% [label, width, height, expected.x, expected.y]
			)
		var pixels: PackedByteArray = frame.get("pixels", PackedByteArray())
		if pixels.size() != width * height:
			problems.append(
				"frame %s tem %d pixels, esperado %d" % [label, pixels.size(), width * height]
			)
		elif not palette.is_empty():
			for pixel in pixels:
				if pixel >= palette.size():
					problems.append(
						"frame %s usa indice %d fora da paleta de %d cores"
						% [label, pixel, palette.size()]
					)
					break
	return problems
