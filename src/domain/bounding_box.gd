class_name BoundingBox
extends RefCounted
## Retangulo puro de colisao: hitbox de golpe e hurtbox de corpo.
##
## Coordenadas no espaco da resolucao base (426x240, ADR 0002), sem qualquer
## dependencia de cena ou de fisica da engine: a colisao e resolvida aqui, por
## sobreposicao de retangulos, de forma determinista.

## Canto superior esquerdo da caixa.
var position: Vector2i
## Largura e altura em pixels, nunca negativas.
var size: Vector2i


func _init(box_position: Vector2i = Vector2i.ZERO, box_size: Vector2i = Vector2i.ZERO) -> void:
	position = box_position
	size = Vector2i(maxi(box_size.x, 0), maxi(box_size.y, 0))


static func from_size(box_size: Vector2i, box_position: Vector2i = Vector2i.ZERO) -> BoundingBox:
	return BoundingBox.new(box_position, box_size)


## Caixa vazia: nunca colide, usada quando nao ha golpe ativo.
static func empty() -> BoundingBox:
	return BoundingBox.new()


func rect() -> Rect2i:
	return Rect2i(position, size)


## Caixa sem area (largura ou altura zero) nao representa contato.
func is_empty() -> bool:
	return size.x == 0 or size.y == 0


func translated(offset: Vector2i) -> BoundingBox:
	return BoundingBox.new(position + offset, size)


## Sobreposicao com area: caixas que apenas encostam na borda nao contam como
## contato, senao um golpe de alcance exato acertaria por um pixel de borda.
func intersects(other: BoundingBox) -> bool:
	if other == null or is_empty() or other.is_empty():
		return false
	return rect().intersects(other.rect())


## Distancia horizontal entre os centros das caixas; negativa quando se sobrepoem.
func horizontal_distance_to(other: BoundingBox) -> int:
	var self_center := position.x + size.x / 2
	var other_center := other.position.x + other.size.x / 2
	return absi(self_center - other_center) - (size.x + other.size.x) / 2
