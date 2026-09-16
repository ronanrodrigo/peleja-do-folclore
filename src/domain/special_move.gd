class_name SpecialMove
extends RefCounted
## Golpe Especial de um Guardiao: identidade e efeito proprio.
##
## O nome do golpe e a copy do jogo (pt-BR, resolvida na borda de apresentacao);
## o efeito e regra pura. O Redemoinho do Saci e um turbilhao que puxa o Oponente
## para dentro dele enquanto a janela ativa do golpe dura. O puxao e medido em
## pixels por tick de simulacao, nunca em segundos nem por temporizador, e o
## gasto da Barra de Especial e do `Fighter` (`start_special`), nao daqui.
##
## Formato dos dados (`SpecialMoveTable`), para os proximos Guardioes entrarem por
## adicao: nome do golpe mais os parametros do efeito. Sem efeito proprio, um
## Guardiao tem um `SpecialMove` sem puxao.

## Nome do Golpe Especial do Saci: turbilhao que puxa o Oponente para dentro.
const REDEMOINHO := "Redemoinho"

var display_name: String
## Pixels que o alvo e puxado a cada tick de janela ativa. Zero = sem puxao.
var pull_per_tick: int
## Distancia maxima, em pixels, em que o puxao ainda alcanca o alvo.
var pull_reach: int


func _init(p_display_name: String = "", p_pull_per_tick: int = 0, p_pull_reach: int = 0) -> void:
	display_name = p_display_name
	pull_per_tick = maxi(p_pull_per_tick, 0)
	pull_reach = maxi(p_pull_reach, 0)


func has_pull() -> bool:
	return pull_per_tick > 0 and pull_reach > 0


func is_named(other_name: String) -> bool:
	return display_name == other_name


## Puxa o alvo para dentro do turbilhao. So age dentro do alcance do efeito;
## devolve quantos pixels o alvo andou de verdade.
func pull_target(attacker: Fighter, defender: Fighter) -> int:
	if attacker == null or defender == null or not has_pull():
		return 0
	if absi(defender.position.x - attacker.position.x) > pull_reach:
		return 0
	return defender.pull_towards(attacker.position.x, pull_per_tick)
