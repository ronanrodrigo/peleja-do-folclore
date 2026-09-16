class_name SpriteRenderAdapter
extends RenderGateway
## Renderer de producao da capacidade "desenhar um frame".
##
## Desenha a resolucao base (426x240) num `Image` RGBA8 e apresenta essa
## superficie num `TextureRect` com filtro **nearest** e escala **inteira**, com
## letterbox: a janela nunca estica a pixel art por fator fracionario (ADR 0002).
## Os spritesheets entram aqui ja decodificados (`Spritesheet`), sempre em escala
## inteira -- escala invalida e recusada e registrada, jamais desenhada borrada.
##
## O adapter e instanciado apenas pelo composition root (`autoloads/app_container.gd`).
## Sem `mount()`, ele desenha so na superficie (uso headless/testes).

## Cor de fundo da superficie antes de cada frame. Opaca de proposito: o frame
## apresentado nao carrega o que estava atras.
const CLEAR_COLOR := Color8(18, 18, 42)
## Nome do no de apresentacao, para a cena e os testes encontrarem o display.
const DISPLAY_NAME := "SpriteDisplay"

var rejected_scales: Array = []
var sprites_drawn: int = 0
var frames_presented: int = 0
var frames_begun: int = 0

var _image: Image
var _texture: ImageTexture
var _display: TextureRect = null
var _palette: PackedColorArray = PackedColorArray()


func _init() -> void:
	_image = Image.create_empty(BASE_SIZE.x, BASE_SIZE.y, false, Image.FORMAT_RGBA8)
	_image.fill(CLEAR_COLOR)
	_texture = ImageTexture.create_from_image(_image)


## Monta a apresentacao dentro de um Control: o display e filho do host e o
## letterbox e calculado no tamanho do host a cada `present()`.
func mount(host: Control) -> TextureRect:
	_display = TextureRect.new()
	_display.name = DISPLAY_NAME
	_display.texture = _texture
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(_display)
	apply_layout(Vector2i(host.size))
	return _display


## Superficie desenhada, na resolucao base.
func surface() -> Image:
	return _image


func texture() -> ImageTexture:
	return _texture


func display() -> TextureRect:
	return _display


## Paleta usada por `draw_pixels` (os pixels crus sao indices dela).
func set_palette(palette: PackedColorArray) -> void:
	_palette = palette


func clear() -> void:
	frames_begun += 1
	_image.fill(CLEAR_COLOR)


func draw_rect(rect: Rect2i, color: Color) -> void:
	var clipped := _clamp_rect(rect)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	_image.fill_rect(clipped, color)


## Bloco de pixels por indice de paleta, sem escala (1 pixel = 1 pixel).
func draw_pixels(origin: Vector2i, size: Vector2i, pixels: PackedByteArray) -> void:
	for y in size.y:
		for x in size.x:
			var offset := y * size.x + x
			if offset >= pixels.size():
				return
			_blit(origin.x + x, origin.y + y, pixels[offset])


## Desenha um frame codificado em escala inteira. Escala invalida, spritesheet
## ausente ou animacao/frame inexistente devolvem falso sem desenhar nada.
func draw_sprite(
	sheet: Spritesheet,
	animation_name: String,
	frame_index: int,
	origin: Vector2i,
	pixel_scale: int = RenderGateway.DEFAULT_PIXEL_SCALE,
	flip: bool = false
) -> bool:
	if not is_pixel_scale_valid(pixel_scale):
		rejected_scales.append(pixel_scale)
		return false
	if sheet == null or sheet.frame_at(animation_name, frame_index).is_empty():
		return false
	if sheet.palette.is_empty():
		return false
	var size := sheet.frame_size(animation_name, frame_index)
	for y in size.y:
		var row := sheet.row_pixels(animation_name, frame_index, y)
		for x in size.x:
			var index := row[x] if x < row.size() else Spritesheet.TRANSPARENT_INDEX
			if index == Spritesheet.TRANSPARENT_INDEX:
				continue
			var column := (size.x - 1 - x) if flip else x
			_fill_block(
				origin.x + column * pixel_scale,
				origin.y + y * pixel_scale,
				pixel_scale,
				sheet.color_of(index)
			)
	sprites_drawn += 1
	return true


## Escala inteira com que a resolucao base cabe no espaco disponivel, no minimo
## 1x. E a regra do letterbox: a sobra vira faixa preta, nunca esticamento.
func display_scale(available: Vector2i) -> int:
	var horizontal := available.x / BASE_SIZE.x
	var vertical := available.y / BASE_SIZE.y
	return maxi(MIN_PIXEL_SCALE, mini(horizontal, vertical))


## Retangulo do display dentro do espaco disponivel: escala inteira acima,
## centralizado (letterbox nas sobras).
func letterbox_rect(available: Vector2i) -> Rect2i:
	var scale := display_scale(available)
	var size := BASE_SIZE * scale
	return Rect2i(
		(available.x - size.x) / 2,
		(available.y - size.y) / 2,
		size.x,
		size.y
	)


## Posiciona o display conforme o espaco disponivel (silencio sem mount).
func apply_layout(available: Vector2i) -> void:
	if _display == null:
		return
	var rect := letterbox_rect(available)
	_display.position = Vector2(rect.position)
	_display.size = Vector2(rect.size)


func present() -> void:
	frames_presented += 1
	_texture.update(_image)
	if _display != null and _display.is_inside_tree():
		apply_layout(Vector2i(_display.get_parent_area_size()))


func _fill_block(x: int, y: int, size: int, color: Color) -> void:
	for offset_y in size:
		for offset_x in size:
			_image.set_pixel(x + offset_x, y + offset_y, color)


func _blit(x: int, y: int, palette_index: int) -> void:
	if palette_index == Spritesheet.TRANSPARENT_INDEX:
		return
	if _palette.is_empty():
		_image.set_pixel(x, y, Color8(palette_index, palette_index, palette_index))
		return
	if palette_index < _palette.size():
		_image.set_pixel(x, y, _palette[palette_index])


func _clamp_rect(rect: Rect2i) -> Rect2i:
	var left := clampi(rect.position.x, 0, BASE_SIZE.x)
	var top := clampi(rect.position.y, 0, BASE_SIZE.y)
	var right := clampi(rect.position.x + rect.size.x, 0, BASE_SIZE.x)
	var bottom := clampi(rect.position.y + rect.size.y, 0, BASE_SIZE.y)
	return Rect2i(left, top, maxi(right - left, 0), maxi(bottom - top, 0))
