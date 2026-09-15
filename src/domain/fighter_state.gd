class_name FighterState
extends RefCounted
## Estados possiveis de um lutador.
##
## Dado puro de dominio: nenhum estado aqui conhece cena, no de engine ou
## temporizador. O estado e avancado por tick de simulacao.

enum State {
	IDLE,
	WALK,
	CROUCH,
	BLOCK,
	ATTACK,
	HURT,
	KNOCKED_DOWN,
}

const NAMES := {
	State.IDLE: "idle",
	State.WALK: "walk",
	State.CROUCH: "crouch",
	State.BLOCK: "block",
	State.ATTACK: "attack",
	State.HURT: "hurt",
	State.KNOCKED_DOWN: "knocked_down",
}

## Estados em que o lutador aceita um comando novo.
const FREE_STATES := [
	State.IDLE,
	State.WALK,
	State.CROUCH,
	State.BLOCK,
]


static func name_of(state: int) -> String:
	return NAMES.get(state, "unknown")


## Verdadeiro quando o lutador pode comecar a andar, agachar, defender ou atacar.
static func accepts_command(state: int) -> bool:
	return FREE_STATES.has(state)


## Verdadeiro quando o lutador ainda responde a comandos (nao esta em hurt nem nocauteado).
static func is_controlled(state: int) -> bool:
	return state != State.HURT and state != State.KNOCKED_DOWN


## Verdadeiro quando o estado e o de um golpe em andamento.
static func is_attacking(state: int) -> bool:
	return state == State.ATTACK
