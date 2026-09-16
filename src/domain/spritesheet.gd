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
## `pixels` aceita tres codificacoes equivalentes, na ordem de leitura:
## lista plana de indices, lista de linhas (cada linha uma lista de indices) e
## lista de linhas em texto compacto (um caractere por pixel: `PIXEL_CHARS`,
## com `.` para pixel transparente). As tres chegam na mesma matriz de pixels.

const FORMAT_VERSION := 1
const MAX_PALETTE_SIZE := 256
const MAX_FRAME_WIDTH := 426
const MAX_FRAME_HEIGHT := 240
## Indice de paleta reservado para pixel transparente, por convencao do formato.
const TRANSPARENT_INDEX := 0
## Alfabeto da codificacao compacta de linha: um caractere por pixel, na base 36.
## O indice `i` da paleta escreve-se com o caractere `PIXEL_CHARS[i]`.
const PIXEL_CHARS := "0123456789abcdefghijklmnopqrstuvwxyz"
## Caractere que representa o pixel transparente na codificacao compacta.
const TRANSPARENT_CHAR := "."
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
## Problemas encontrados na decodificacao (caractere invalido na codificacao
## compacta, por exemplo). Entram em `errors()` junto das regras de conteudo.
var decode_problems: PackedStringArray = PackedStringArray()


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
	var problems: Array = []
	sheet.slug = str(data.get("slug", ""))
	sheet.version = int(data.get("version", 0))
	sheet.palette = _decode_palette(data.get("palette", []))
	sheet.animations = _decode_animations(data.get("animations", {}), problems)
	sheet.decode_problems = PackedStringArray(problems)
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


static func _decode_animations(raw: Variant, problems: Array) -> Dictionary:
	var result: Dictionary = {}
	if not (raw is Dictionary):
		return result
	for animation_name in raw.keys():
		var frames: Array = []
		var raw_frames: Variant = raw[animation_name]
		if raw_frames is Array:
			var frame_index := 0
			for raw_frame in raw_frames:
				var label := "%s[%d]" % [str(animation_name), frame_index]
				frames.append(_decode_frame(raw_frame, label, problems))
				frame_index += 1
		result[str(animation_name)] = frames
	return result


static func _decode_frame(raw: Variant, label: String, problems: Array) -> Dictionary:
	if not (raw is Dictionary):
		return {"width": 0, "height": 0, "pixels": PackedByteArray()}
	var pixels := PackedByteArray()
	var raw_pixels: Variant = raw.get("pixels", [])
	if raw_pixels is PackedByteArray:
		pixels = raw_pixels
	elif raw_pixels is Array:
		var row_index := 0
		for entry in raw_pixels:
			if entry is Array:
				for value in entry:
					pixels.append(int(value) & 0xFF)
			elif entry is String:
				pixels.append_array(_decode_row(entry, label, row_index, problems))
			else:
				pixels.append(int(entry) & 0xFF)
			row_index += 1
	return {
		"width": int(raw.get("width", 0)),
		"height": int(raw.get("height", 0)),
		"pixels": pixels,
	}


## Linha em texto compacto: um caractere por pixel, na base `PIXEL_CHARS`, com
## `.` para o pixel transparente. Caractere fora do alfabeto nao passa em
## silencio: vira problema de decodificacao, que `errors()` reporta.
static func _decode_row(
	row: String, label: String, row_index: int, problems: Array
) -> PackedByteArray:
	var decoded := PackedByteArray()
	for column in row.length():
		var character := row[column]
		if character == TRANSPARENT_CHAR:
			decoded.append(TRANSPARENT_INDEX)
			continue
		var index := PIXEL_CHARS.find(character)
		if index < 0:
			problems.append(
				"frame %s tem caractere invalido '%s' na linha %d" % [label, character, row_index]
			)
			index = TRANSPARENT_INDEX
		decoded.append(index)
	return decoded


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


## Matriz de uma linha do frame (o renderer desenha linha a linha). Linha fora do
## frame volta vazia, como o resto da leitura.
func row_pixels(animation_name: String, frame_index: int, y: int) -> PackedByteArray:
	var size := frame_size(animation_name, frame_index)
	if y < 0 or y >= size.y:
		return PackedByteArray()
	var pixels := frame_pixels(animation_name, frame_index)
	return pixels.slice(y * size.x, y * size.x + size.x)


## Indice de paleta de um pixel do frame, em coordenadas do frame. Fora do frame
## devolve o indice transparente -- o renderer nao precisa de caso especial.
func pixel_at(animation_name: String, frame_index: int, x: int, y: int) -> int:
	var size := frame_size(animation_name, frame_index)
	if x < 0 or y < 0 or x >= size.x or y >= size.y:
		return TRANSPARENT_INDEX
	var pixels := frame_pixels(animation_name, frame_index)
	if y * size.x + x >= pixels.size():
		return TRANSPARENT_INDEX
	return pixels[y * size.x + x]


## Cor de um pixel do frame. Transparente quando o pixel nao existe ou e o
## indice reservado de transparencia.
func pixel_color(animation_name: String, frame_index: int, x: int, y: int) -> Color:
	var index := pixel_at(animation_name, frame_index, x, y)
	if index == TRANSPARENT_INDEX:
		return Color(0, 0, 0, 0)
	return color_of(index)


## Lista de problemas do formato; vazia quando a spritesheet esta valida.
func errors() -> PackedStringArray:
	var problems := PackedStringArray()
	if slug.is_empty():
		problems.append("slug ausente")
	if version != FORMAT_VERSION:
		problems.append("versao %d nao suportada (esperado %d)" % [version, FORMAT_VERSION])
	problems.append_array(_palette_errors())
	problems.append_array(decode_problems)
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
