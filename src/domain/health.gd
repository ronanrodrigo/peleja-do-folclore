class_name Health
extends RefCounted
## Pontos de vida de um lutador.
##
## A vida so cai por dano aplicado; o estouro de dano e limitado ao que restava,
## para que o valor nunca fique negativo e a HUD nunca desenhe barra invertida.

var max_value: int
var current: int


func _init(p_max_value: int = 1) -> void:
	max_value = maxi(p_max_value, 1)
	current = max_value


## Aplica dano e devolve quanto foi realmente descontado.
func apply_damage(amount: int) -> int:
	if amount <= 0 or is_empty():
		return 0
	var applied := mini(amount, current)
	current -= applied
	return applied


func is_empty() -> bool:
	return current <= 0


## Recupera vida (o dreno de um Golpe Especial devolve ao atacante o que tirou).
## Devolve quanto foi recuperado de verdade; o excedente e descartado.
func heal(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := current
	current = mini(current + amount, max_value)
	return current - before


## Fracao da barra, de 0.0 (zerada) a 1.0 (cheia).
func ratio() -> float:
	return float(current) / float(max_value)


func reset() -> void:
	current = max_value
