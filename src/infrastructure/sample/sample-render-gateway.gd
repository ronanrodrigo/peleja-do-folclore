class_name SampleRenderGateway
extends RenderGateway
## Adapter de renderizacao deterministico usado em testes.
##
## Nao desenha nada: registra as chamadas em memoria para que o teste possa
## afirmar o que foi pedido. Zero I/O.

var frames_begun: int = 0
var frames_presented: int = 0
var rects: Array = []
var pixel_blocks: Array = []
var rejected_scales: Array = []
var sprites_drawn: Array = []


func clear() -> void:
	frames_begun += 1
	rects.clear()
	pixel_blocks.clear()
	sprites_drawn.clear()


func draw_rect(rect: Rect2i, color: Color) -> void:
	rects.append({"rect": rect, "color": color})


func draw_pixels(origin: Vector2i, size: Vector2i, pixels: PackedByteArray) -> void:
	pixel_blocks.append({"origin": origin, "size": size, "byte_count": pixels.size()})


func present() -> void:
	frames_presented += 1


## Recusa escala fracionaria em vez de desenhar borrado (invariante de pixel art).
func draw_pixels_scaled(
	origin: Vector2i, size: Vector2i, pixels: PackedByteArray, pixel_scale: int
) -> bool:
	if not is_pixel_scale_valid(pixel_scale):
		rejected_scales.append(pixel_scale)
		return false
	draw_pixels(origin, size * pixel_scale, pixels)
	return true


## Registra o frame de spritesheet pedido, sem desenhar. Escala invalida e
## recusada e anotada em `rejected_scales`, como no renderer de producao.
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
	sprites_drawn.append({
		"slug": sheet.slug,
		"animation": animation_name,
		"frame": frame_index,
		"origin": origin,
		"scale": pixel_scale,
		"flip": flip,
		"size": sheet.frame_size(animation_name, frame_index),
	})
	return true