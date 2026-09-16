class_name KeyboardInputAdapter
extends InputGateway
## Adapter de producao da capacidade "ler intencoes do jogador": teclado.
##
## Traduz teclas em comandos abstratos (o mesmo enum do contrato), sem conhecer o
## dominio. Nenhum estado de jogo mora aqui: apenas o que esta pressionado agora.
## WASD/setas para mover, Shift para defender, J/K/L para leve/pesado/agarrao e U
## para o Golpe Especial.

## Comandos repetidos enquanto a tecla segue pressionada.
const HELD_COMMANDS := [
	InputGateway.Command.MOVE_LEFT,
	InputGateway.Command.MOVE_RIGHT,
	InputGateway.Command.CROUCH,
	InputGateway.Command.BLOCK,
]

## Teclas de cada comando. Mais de uma tecla por comando e permitido.
const ACTION_KEYS := {
	InputGateway.Command.MOVE_LEFT: [KEY_A, KEY_LEFT],
	InputGateway.Command.MOVE_RIGHT: [KEY_D, KEY_RIGHT],
	InputGateway.Command.CROUCH: [KEY_S, KEY_DOWN],
	InputGateway.Command.BLOCK: [KEY_SHIFT],
	InputGateway.Command.LIGHT: [KEY_J],
	InputGateway.Command.HEAVY: [KEY_K],
	InputGateway.Command.GRAB: [KEY_L],
	InputGateway.Command.SPECIAL: [KEY_U],
	InputGateway.Command.CONFIRM: [KEY_ENTER, KEY_SPACE],
	InputGateway.Command.CANCEL: [KEY_ESCAPE],
}

var _was_down: Dictionary = {}
var _pending: Array = []


func poll() -> Array:
	_sync()
	var drained: Array = _pending.duplicate()
	_pending.clear()
	return drained


func clear() -> void:
	_pending.clear()


## Le o teclado agora e acumula os comandos ainda nao consumidos.
func _sync() -> void:
	for command in ACTION_KEYS.keys():
		var down := _any_key_down(ACTION_KEYS[command])
		var was := bool(_was_down.get(command, false))
		_was_down[command] = down
		if not down:
			continue
		if was and not HELD_COMMANDS.has(command):
			continue
		_pending.append(command)


func _any_key_down(keys: Array) -> bool:
	for key in keys:
		if Input.is_key_pressed(key):
			return true
	return false
