class_name KeyboardInputAdapter
extends InputGateway
## Adapter de producao da capacidade "ler intencoes do jogador": teclado.
##
## Traduz teclas em comandos abstratos (o mesmo enum do contrato), sem conhecer o
## dominio. Nenhum estado de jogo mora aqui: apenas o que esta pressionado agora.
## Por padrao liga WASD/setas a movimento, Shift a defesa, J/K/L a
## leve/pesado/agarrao e U ao Golpe Especial.
##
## O remap entra por `apply_bindings`, chaveado por NOME de acao em ingles -- e o
## mesmo nome que o menu de opcoes mostra e grava. Comandos de menu (confirmar,
## cancelar) ficam FORA do remap: sao as teclas de navegacao de toda tela.

## Acoes remapeaveis, na ordem em que o menu de opcoes as apresenta.
const ACTION_ORDER := [
	"move_left",
	"move_right",
	"crouch",
	"block",
	"light",
	"heavy",
	"grab",
	"special",
]

## Comando abstrato de cada acao remapeavel.
const ACTION_COMMANDS := {
	"move_left": InputGateway.Command.MOVE_LEFT,
	"move_right": InputGateway.Command.MOVE_RIGHT,
	"crouch": InputGateway.Command.CROUCH,
	"block": InputGateway.Command.BLOCK,
	"light": InputGateway.Command.LIGHT,
	"heavy": InputGateway.Command.HEAVY,
	"grab": InputGateway.Command.GRAB,
	"special": InputGateway.Command.SPECIAL,
}

## Teclas padrao de cada acao (mais de uma tecla por acao e permitido).
const DEFAULT_ACTION_KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"crouch": [KEY_S, KEY_DOWN],
	"block": [KEY_SHIFT],
	"light": [KEY_J],
	"heavy": [KEY_K],
	"grab": [KEY_L],
	"special": [KEY_U],
}

## Teclas de menu, fixas: confirmar e cancelar valem em toda tela e nunca sao
## remapeadas (o jogador nao se tranca fora do menu).
const MENU_KEYS := {
	InputGateway.Command.CONFIRM: [KEY_ENTER, KEY_SPACE],
	InputGateway.Command.CANCEL: [KEY_ESCAPE],
}

## Comandos repetidos enquanto a tecla segue pressionada.
const HELD_COMMANDS := [
	InputGateway.Command.MOVE_LEFT,
	InputGateway.Command.MOVE_RIGHT,
	InputGateway.Command.CROUCH,
	InputGateway.Command.BLOCK,
]

var _key_map: Dictionary = {}
var _was_down: Dictionary = {}
var _pending: Array = []


func _init() -> void:
	_key_map = DEFAULT_ACTION_KEYS.duplicate(true)


func action_names() -> PackedStringArray:
	var names := PackedStringArray()
	for action in ACTION_ORDER:
		names.append(action)
	return names


func bindings() -> Dictionary:
	return _key_map.duplicate(true)


## Aplica um remap. Acao fora do conjunto remapeavel ou lista vazia sao ignoradas:
## o mapa nunca fica sem tecla para uma acao.
func apply_bindings(bindings: Dictionary) -> void:
	for action in bindings.keys():
		if not _key_map.has(action):
			continue
		var keys: Array = bindings[action]
		if keys.is_empty():
			continue
		_key_map[action] = _int_keys(keys)


func poll() -> Array:
	_sync()
	var drained: Array = _pending.duplicate()
	_pending.clear()
	return drained


func clear() -> void:
	_pending.clear()


## Le o teclado agora e acumula os comandos ainda nao consumidos.
func _sync() -> void:
	for action in ACTION_ORDER:
		var command: int = ACTION_COMMANDS[action]
		_accumulate(command, _key_map[action])
	for command in MENU_KEYS.keys():
		_accumulate(command, MENU_KEYS[command])


func _accumulate(command: int, keys: Array) -> void:
	var down := _any_key_down(keys)
	var was := bool(_was_down.get(command, false))
	_was_down[command] = down
	if not down:
		return
	if was and not HELD_COMMANDS.has(command):
		return
	_pending.append(command)


func _any_key_down(keys: Array) -> bool:
	for key in keys:
		if Input.is_key_pressed(int(key)):
			return true
	return false


func _int_keys(keys: Array) -> Array:
	var converted: Array = []
	for key in keys:
		converted.append(int(key))
	return converted
