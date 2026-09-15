class_name PersistenceGateway
extends RefCounted
## Contrato da capacidade "guardar e restaurar preferencias e progresso".
##
## Uma capacidade, um arquivo. O que persiste sao preferencias (volume, mudo,
## remap) e progresso do arcade -- nunca estado de jogo em andamento.

## Grava um valor. Devolve true quando a gravacao foi aceita.
func save(_key: String, _value: Variant) -> bool:
	return false


## Le um valor; devolve default_value quando a chave nao existe.
func load_value(_key: String, default_value: Variant) -> Variant:
	return default_value


## A chave existe no armazenamento?
func has(_key: String) -> bool:
	return false


## Remove a chave.
func erase(_key: String) -> void:
	pass