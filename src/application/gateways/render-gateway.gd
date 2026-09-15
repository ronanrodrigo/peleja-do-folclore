class_name RenderGateway
extends RefCounted
## Contrato da capacidade "desenhar um frame".
##
## Uma capacidade, um arquivo. A renderizacao e sempre em escala inteira e
## filtro nearest (invariante de pixel art); escala fracionaria e rejeitada pelo
## proprio contrato, nao pelo chamador.

## Menor multiplicador inteiro aceito para desenhar pixel art.
const MIN_PIXEL_SCALE := 1


## Comeca um frame limpo.
func clear() -> void:
	pass


## Desenha um retangulo solido no espaco da resolucao base (426x240).
func draw_rect(_rect: Rect2i, _color: Color) -> void:
	pass


## Desenha um bloco de pixels ja decodificado em escala inteira.
func draw_pixels(_origin: Vector2i, _size: Vector2i, _pixels: PackedByteArray) -> void:
	pass


## Fecha o frame.
func present() -> void:
	pass


## Regra publica de aceitacao: a escala tem de ser um inteiro >= 1.
func is_pixel_scale_valid(pixel_scale: int) -> bool:
	return pixel_scale >= MIN_PIXEL_SCALE