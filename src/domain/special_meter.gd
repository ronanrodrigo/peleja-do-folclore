class_name SpecialMeter
extends RefCounted
## Barra de Especial: enche batendo e apanhando.
##
## O Golpe Especial consome a barra inteira e so dispara com a barra cheia
## (regra de produto do ticket 2, derivada de CONTEXT.md). O ganho por golpe vem
## do `FighterStats` de quem bate e de quem apanha, nao daqui.

const MAX_UNITS := 100

var current: int


func _init(p_current: int = 0) -> void:
	current = clampi(p_current, 0, MAX_UNITS)


## Soma unidades e devolve quanto foi realmente somado (o excedente e descartado).
func gain(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := current
	current = mini(current + amount, MAX_UNITS)
	return current - before


func is_full() -> bool:
	return current >= MAX_UNITS


func is_empty() -> bool:
	return current <= 0


func ratio() -> float:
	return float(current) / float(MAX_UNITS)


## Consome a barra inteira. Recusa e nao gasta nada quando a barra nao esta cheia.
func consume() -> bool:
	if not is_full():
		return false
	current = 0
	return true


func reset() -> void:
	current = 0
