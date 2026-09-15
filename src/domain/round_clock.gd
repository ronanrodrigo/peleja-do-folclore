class_name RoundClock
extends RefCounted
## Relogio do round, contado em ticks de simulacao.
##
## Nao usa temporizador nem relogio de engine: o chamador entrega o delta em
## ticks e o relogio desconta. O determinismo vem da contagem de ticks, nunca do
## relogio de parede.

const TICKS_PER_SECOND := 60
const DEFAULT_DURATION_SECONDS := 60

var duration_ticks: int
var remaining_ticks: int


func _init(p_duration_seconds: int = DEFAULT_DURATION_SECONDS) -> void:
	duration_ticks = maxi(p_duration_seconds, 1) * TICKS_PER_SECOND
	remaining_ticks = duration_ticks


## Desconta ticks e devolve quantos foram efetivamente descontados.
func advance(ticks: int) -> int:
	if ticks <= 0:
		return 0
	var before := remaining_ticks
	remaining_ticks = maxi(remaining_ticks - ticks, 0)
	return before - remaining_ticks


func is_expired() -> bool:
	return remaining_ticks <= 0


## Segundos restantes arredondados para cima, para a HUD nunca mostrar 0 com o
## round ainda vivo.
func remaining_seconds() -> int:
	return ceili(float(remaining_ticks) / float(TICKS_PER_SECOND))


func ratio() -> float:
	return float(remaining_ticks) / float(duration_ticks)


func reset() -> void:
	remaining_ticks = duration_ticks
