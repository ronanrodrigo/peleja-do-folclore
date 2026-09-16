class_name TouchInputAdapter
extends InputGateway
## Adapter de producao da capacidade "ler intencoes do jogador": toque na tela.
##
## Monta botoes sobre a cena (`mount`) e traduz cada toque no mesmo comando
## abstrato do teclado -- os dois adapters produzem exatamente o mesmo enum de
## comando, so mudam o meio fisico. Nenhum estado de jogo mora aqui.

const BUTTON_SIZE := 36
const BUTTON_ALPHA := 0.30
const COLOR_BUTTON := Color(1, 1, 1, BUTTON_ALPHA)
const COLOR_HELD := Color(1, 1, 1, 0.55)

## Comandos repetidos enquanto o botao segue pressionado.
const HELD_COMMANDS := [
	InputGateway.Command.MOVE_LEFT,
	InputGateway.Command.MOVE_RIGHT,
	InputGateway.Command.CROUCH,
	InputGateway.Command.BLOCK,
]

## Layout dos botoes no espaco da resolucao base (426x240): comando, retangulo e
## rotulo curto em ASCII. Esquerda move, direita golpeia.
const LAYOUT := [
	{"command": InputGateway.Command.MOVE_LEFT, "x": 10, "y": 194, "label": "<"},
	{"command": InputGateway.Command.CROUCH, "x": 54, "y": 194, "label": "v"},
	{"command": InputGateway.Command.MOVE_RIGHT, "x": 98, "y": 194, "label": ">"},
	{"command": InputGateway.Command.BLOCK, "x": 10, "y": 150, "label": "BLK"},
	{"command": InputGateway.Command.SPECIAL, "x": 54, "y": 150, "label": "ESP"},
	{"command": InputGateway.Command.LIGHT, "x": 300, "y": 194, "label": "LEV"},
	{"command": InputGateway.Command.HEAVY, "x": 344, "y": 194, "label": "PES"},
	{"command": InputGateway.Command.GRAB, "x": 388, "y": 194, "label": "AGR"},
]

var _queue: Array = []
var _held: Dictionary = {}


func poll() -> Array:
	var drained: Array = _queue.duplicate()
	for command in _held.keys():
		drained.append(command)
	_queue.clear()
	return drained


func clear() -> void:
	_queue.clear()
	_held.clear()


## Cria os botoes de toque como filhos de `parent` (a cena de luta). Chamado pelo
## composition root/cena apenas em dispositivo com toque.
func mount(parent: Node) -> void:
	if parent == null:
		return
	for entry in LAYOUT:
		parent.add_child(_make_button(entry))


func _make_button(entry: Dictionary) -> Button:
	var command: int = entry["command"]
	var button := Button.new()
	button.name = "TouchButton" + str(command)
	button.text = entry["label"]
	button.focus_mode = Control.FOCUS_NONE
	button.position = Vector2(entry["x"], entry["y"])
	button.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.modulate = COLOR_BUTTON
	button.button_down.connect(_on_button_down.bind(command, button))
	button.button_up.connect(_on_button_up.bind(command, button))
	return button


func _on_button_down(command: int, button: Button) -> void:
	button.modulate = COLOR_HELD
	if HELD_COMMANDS.has(command):
		_held[command] = true
	else:
		_queue.append(command)


func _on_button_up(command: int, button: Button) -> void:
	button.modulate = COLOR_BUTTON
	_held.erase(command)
