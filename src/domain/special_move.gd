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
## Cada efeito da lenda e um parametro do golpe, aplicado na janela ativa por
## `apply_active_tick`:
##
## - puxao (`pull_per_tick`/`pull_reach`): o Redemoinho do Saci suga o alvo;
## - inversao de comandos (`invert_ticks`): os Pes Invertidos do Curupira trocam
##   o lado do movimento do alvo e o derrubam para o lado contrario ao que ele
##   defende (`knockback_pixels`);
## - sono (`sleep_ticks`): o Canto do Rio da Iara encanta e paralisa, drenando
##   vida no abraco d'agua (`drain_per_tick`); o Nana Nenem da Cuca adormece o
##   Oponente e a Cuca vira jacare e morde (`bite_per_tick`).
##
## Formato dos dados (`SpecialMoveTable`), para os proximos Guardioes entrarem por
## adicao: nome do golpe mais os parametros do efeito. Sem efeito proprio, um
## Guardiao tem um `SpecialMove` sem puxao e sem status.

## Nome do Golpe Especial do Saci: turbilhao que puxa o Oponente para dentro.
const REDEMOINHO := "Redemoinho"
## Nome do Golpe Especial do Curupira: inverte o lado dos comandos do alvo.
const PES_INVERTIDOS := "Pés Invertidos"
## Nome do Golpe Especial da Iara: encanta, paralisa e drena vida.
const CANTO_DO_RIO := "Canto do Rio"
## Nome do Golpe Especial da Cuca: adormece e morde como jacare.
const NANA_NENEM := "Nana Neném"

var display_name: String
## Pixels que o alvo e puxado a cada tick de janela ativa. Zero = sem puxao.
var pull_per_tick: int
## Distancia maxima, em pixels, em que o puxao ainda alcanca o alvo.
var pull_reach: int
## Ticks em que o alvo fica com os comandos de movimento invertidos.
var invert_ticks: int
## Ticks em que o alvo fica adormecido (sem aceitar comando nenhum).
var sleep_ticks: int
## Vida drenada do alvo a cada tick de janela ativa (e devolvida ao atacante).
var drain_per_tick: int
## Dano extra da mordida (a Cuca vira jacare) a cada tick de janela ativa.
var bite_per_tick: int
## Pixels que o alvo e derrubado, no sentido contrario ao que ele defende.
var knockback_pixels: int


func _init(
	p_display_name: String = "",
	p_pull_per_tick: int = 0,
	p_pull_reach: int = 0,
	p_invert_ticks: int = 0,
	p_sleep_ticks: int = 0,
	p_drain_per_tick: int = 0,
	p_bite_per_tick: int = 0,
	p_knockback_pixels: int = 0
) -> void:
	display_name = p_display_name
	pull_per_tick = maxi(p_pull_per_tick, 0)
	pull_reach = maxi(p_pull_reach, 0)
	invert_ticks = maxi(p_invert_ticks, 0)
	sleep_ticks = maxi(p_sleep_ticks, 0)
	drain_per_tick = maxi(p_drain_per_tick, 0)
	bite_per_tick = maxi(p_bite_per_tick, 0)
	knockback_pixels = maxi(p_knockback_pixels, 0)


func has_effect() -> bool:
	return (
		has_pull()
		or has_inversion()
		or has_sleep()
		or has_drain()
		or has_bite()
		or has_knockback()
	)


func has_pull() -> bool:
	return pull_per_tick > 0 and pull_reach > 0


func has_inversion() -> bool:
	return invert_ticks > 0


func has_sleep() -> bool:
	return sleep_ticks > 0


func has_drain() -> bool:
	return drain_per_tick > 0


func has_bite() -> bool:
	return bite_per_tick > 0


func has_knockback() -> bool:
	return knockback_pixels > 0


func is_named(other_name: String) -> bool:
	return display_name == other_name


## Status que este golpe deixa no alvo, como dado (sem aplicar nada).
func status_effects() -> Array:
	var effects: Array = []
	if has_inversion():
		effects.append(StatusEffect.new(StatusEffect.Kind.INVERT_CONTROLS, invert_ticks))
	if has_sleep():
		effects.append(StatusEffect.new(StatusEffect.Kind.SLEEP, sleep_ticks))
	return effects


## Puxa o alvo para dentro do turbilhao. So age dentro do alcance do efeito;
## devolve quantos pixels o alvo andou de verdade.
func pull_target(attacker: Fighter, defender: Fighter) -> int:
	if attacker == null or defender == null or not has_pull():
		return 0
	if absi(defender.position.x - attacker.position.x) > pull_reach:
		return 0
	return defender.pull_towards(attacker.position.x, pull_per_tick)


## Derruba o alvo para o lado contrario ao que ele defende: a queda segue o lado
## oposto da guarda dele, nunca o lado para onde ele olha. Devolve quantos pixels
## o alvo andou de verdade.
func knock_target(attacker: Fighter, defender: Fighter) -> int:
	if attacker == null or defender == null or not has_knockback():
		return 0
	var away := -defender.facing
	return defender.pull_towards(defender.position.x + away * knockback_pixels, knockback_pixels)


## Aplica o efeito da lenda durante a janela ativa do golpe, uma vez por tick.
## Devolve o relatorio do que aconteceu no tick (puxao, drenagem, mordida, queda,
## status aplicados) -- dado puro, sem desenho e sem leitura de engine.
func apply_active_tick(attacker: Fighter, defender: Fighter) -> Dictionary:
	var report := {
		"pull": 0,
		"drain": 0,
		"bite": 0,
		"knockback": 0,
		"inverted": false,
		"sleeping": false,
	}
	if attacker == null or defender == null:
		return report
	report["pull"] = pull_target(attacker, defender)
	for effect in status_effects():
		defender.statuses.add(effect)
		if effect.is_control_inversion():
			report["inverted"] = true
		elif effect.is_sleep():
			report["sleeping"] = true
	report["drain"] = drain_target(attacker, defender)
	report["bite"] = bite_target(attacker, defender)
	report["knockback"] = knock_target(attacker, defender)
	return report


## Abraco d'agua do Canto do Rio: tira vida do alvo e devolve o mesmo tanto para
## quem canta. Devolve quanto foi drenado de verdade.
func drain_target(attacker: Fighter, defender: Fighter) -> int:
	if not has_drain():
		return 0
	var drained := defender.receive_hit(_effect_move(drain_per_tick), attacker)
	if drained <= 0:
		return 0
	attacker.health.heal(drained)
	return drained


## Mordida de jacare do Nana Nenem: dano direto do efeito, pela mesma moldura de
## golpe do resto do combate (defesa reduz, nocaute ao zerar a vida).
func bite_target(attacker: Fighter, defender: Fighter) -> int:
	if not has_bite():
		return 0
	return defender.receive_hit(_effect_move(bite_per_tick), attacker)


## Golpe curto que materializa um efeito em dano, para o efeito reusar
## `receive_hit` em vez de mexer na vida por fora das regras de combate.
func _effect_move(damage: int) -> Move:
	return Move.new(
		Move.Kind.SPECIAL, damage, Move.SPECIAL_REACH, 0, 1, 0, true, display_name
	)
