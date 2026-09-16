class_name StatusEffect
extends RefCounted
## Efeito de status que um Golpe Especial deixa no alvo, como dado puro.
##
## O status e um par (tipo, ticks restantes). Nada aqui conhece cena, no de UI ou
## temporizador de engine: quem aplica o status e o Golpe Especial
## (`SpecialMove`), quem guarda e o `Fighter` e quem avanca e o tick de
## simulacao. A duracao e sempre em ticks (60 por segundo), nunca em segundos.
##
## Os Pes Invertidos do Curupira trocam o lado do movimento (esquerda vira
## direita); o Sono do Canto do Rio e do Nana Nenem tira o controle do alvo
## enquanto durar. Traduzir isso em tecla e trabalho da camada de aplicacao, que
## conhece os comandos do jogador; aqui e so o estado.

enum Kind {
	## Troca o lado dos comandos de movimento do alvo enquanto durar.
	INVERT_CONTROLS,
	## Adormece o alvo: ele nao aceita comando nenhum enquanto durar.
	SLEEP,
}

const NAMES := {
	Kind.INVERT_CONTROLS: "invert_controls",
	Kind.SLEEP: "sleep",
}

var kind: int
## Ticks de simulacao que ainda restam do efeito.
var ticks_remaining: int


func _init(p_kind: int = Kind.SLEEP, p_ticks: int = 0) -> void:
	kind = p_kind
	ticks_remaining = maxi(p_ticks, 0)


## Nome em ingles do tipo de status (chave de configuracao e de relatorio).
static func name_of(kind_id: int) -> String:
	return NAMES.get(kind_id, "unknown")


static func known_kinds() -> Array:
	return NAMES.keys()


## Verdadeiro enquanto o efeito ainda tem ticks para durar.
func is_active() -> bool:
	return ticks_remaining > 0


func is_sleep() -> bool:
	return kind == Kind.SLEEP


func is_control_inversion() -> bool:
	return kind == Kind.INVERT_CONTROLS


## Avanca um tick e devolve verdadeiro quando o efeito terminou neste tick.
func advance_tick() -> bool:
	if ticks_remaining <= 0:
		return true
	ticks_remaining -= 1
	return ticks_remaining <= 0


## Recarrega a duracao (o mesmo golpe batendo de novo renova o status).
func refresh(ticks: int) -> void:
	ticks_remaining = maxi(ticks, ticks_remaining)


## Espelha um sentido de movimento: pedir um lado anda para o outro. E o efeito
## dos Pes Invertidos do Curupira, aplicado pelo `Fighter.walk` -- a mesma regra
## inverte o comando do jogador e a decisao de avancar/recuar da IA do Oponente.
static func invert_direction(step: int) -> int:
	return -step
