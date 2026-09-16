class_name InputGateway
extends RefCounted
## Contrato da capacidade "ler intencoes do jogador".
##
## Uma capacidade, um arquivo. Nome de capacidade em ingles; nunca de tecnologia
## ou provedor. Nenhuma implementacao aqui: adapters concretos vivem em
## src/interface-adapters/ (producao) e src/infrastructure/sample/ (testes).
##
## O remap de controles entra por `apply_bindings`: o mapa e chaveado por NOME de
## acao em ingles (nunca por indice de comando), porque e esse dado que o menu de
## opcoes le e grava na persistencia -- nomes sobrevivem ao JSON, indices nao.

## Comandos abstratos reconhecidos pelo jogo. O estado do jogador nao vive aqui:
## o gateway apenas traduz entrada bruta em comandos.
enum Command {
	MOVE_LEFT,
	MOVE_RIGHT,
	CROUCH,
	BLOCK,
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


## Acoes remapeaveis deste adaptador, na ordem de apresentacao do menu. Vazio
## quando o adaptador nao tem teclas (toque, adapter `sample` de teste).
func action_names() -> PackedStringArray:
	return PackedStringArray()


## Mapa acao -> lista de codigos de tecla. Vazio quando o adaptador nao tem teclas.
## Os codigos sao inteiros opacos para a camada de aplicacao: quem sabe traduzir
## um codigo em tecla e o adapter de interface, nunca o caso de uso.
func bindings() -> Dictionary:
	return {}


## Aplica um remap vindo do caso de uso de opcoes. Acao desconhecida ou lista
## vazia nao mexem no mapa atual: o adaptador nunca fica sem tecla.
func apply_bindings(_bindings: Dictionary) -> void:
	pass
