class_name InputGateway
extends RefCounted
## Contrato da capacidade "ler intencoes do jogador".
##
## Uma capacidade, um arquivo. Nome de capacidade em ingles; nunca de tecnologia
## ou provedor. Nenhuma implementacao aqui: adapters concretos vivem em
## src/interface-adapters/ (producao) e src/infrastructure/sample/ (testes).

## Comandos abstratos reconhecidos pelo jogo. O estado do jogador nao vive aqui:
## o gateway apenas traduz entrada bruta em comandos.
enum Command {
	MOVE_LEFT,
	MOVE_RIGHT,
	CROUCH,
	JUMP,
	LIGHT,
	HEAVY,
	GRAB,
	SPECIAL,
	CONFIRM,
	CANCEL,
}


## Devolve e consome os comandos acumulados desde a ultima chamada.
func poll() -> Array:
	return []


## Descarta comandos pendentes (transicao de cena, pausa).
func clear() -> void:
	pass