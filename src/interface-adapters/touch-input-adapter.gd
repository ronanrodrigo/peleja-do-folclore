class_name TouchInputAdapter
extends InputGateway
## Adapter de producao da capacidade "ler intencoes do jogador": toque na tela.
##
## Monta botoes sobre a cena (`mount`) e traduz cada toque no mesmo comando
## abstrato do teclado -- os dois adapters produzem exatamente o mesmo enum de
## comando, so mudam o meio fisico. Nenhum estado de jogo mora aqui.
##
## Layout revisado para tela pequena (ticket 10): os botoes sao desenhados no
## espaco da resolucao base (426x240), entao o tamanho minimo de 40 px de base
## vira, no celular, o mesmo alvo de toque que a tela cheia escala. Duas
## familias: a esquerda move/defende, a direita golpeia. Nenhum botao invade a
## faixa do HUD (topo) e todos ficam dentro da resolucao base, sem sobreposicao.

## Tamanho minimo de um botao de toque, na resolucao base. Abaixo disso o alvo
## fica pequeno demais no celular.
const BUTTON_SIZE := 40
## Folga entre botoes vizinhos, na resolucao base.
const BUTTON_GAP := 4
## Margem ate a borda da resolucao base.
const MARGIN := 8
## Altura reservada ao HUD (nome, vida, barra de especial, relogio). Nenhum
## botao entra nessa faixa: o topo da tela e informacao, nunca botao.
const HUD_BAND_HEIGHT := 44
const BUTTON_ALPHA := 0.34
const COLOR_BUTTON := Color(1, 1, 1, BUTTON_ALPHA)
const COLOR_HELD := Color(1, 1, 1, 0.58)

## Comandos repetidos enquanto o botao segue pressionado.
const HELD_COMMANDS := [
	InputGateway.Command.MOVE_LEFT,
	InputGateway.Command.MOVE_RIGHT,
	InputGateway.Command.CROUCH,
	InputGateway.Command.BLOCK,
]

## Layout como dado: cada botao tem comando, coluna e linha na grade da familia
## (linha 0 e a de baixo). A esquerda move/defende, a direita golpeia.
const LEFT_CLUSTER := [
	{"command": InputGateway.Command.MOVE_LEFT, "column": 0, "row": 0, "label": "<"},
	{"command": InputGateway.Command.CROUCH, "column": 1, "row": 0, "label": "v"},
	{"command": InputGateway.Command.MOVE_RIGHT, "column": 2, "row": 0, "label": ">"},
	{"command": InputGateway.Command.BLOCK, "column": 0, "row": 1, "label": "BLK"},
]
const RIGHT_CLUSTER := [
	{"command": InputGateway.Command.LIGHT, "column": 0, "row": 0, "label": "LEV"},
	{"command": InputGateway.Command.HEAVY, "column": 1, "row": 0, "label": "PES"},
	{"command": InputGateway.Command.GRAB, "column": 2, "row": 0, "label": "AGR"},
	{"command": InputGateway.Command.SPECIAL, "column": 0, "row": 1, "label": "ESP"},
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
	for rect in layout():
		parent.add_child(_make_button(rect))


## Posicao de um botao na resolucao base, a partir da grade da familia. A coluna
## cresce para o lado de dentro da tela e a linha para cima.
func button_rect(cluster: int, column: int, row: int) -> Rect2i:
	var column_step := BUTTON_SIZE + BUTTON_GAP
	var row_step := BUTTON_SIZE + BUTTON_GAP
	var x := MARGIN + column * column_step
	if cluster == 1:
		x = 426 - MARGIN - BUTTON_SIZE - column * column_step
	var y := 240 - MARGIN - BUTTON_SIZE - row * row_step
	return Rect2i(x, y, BUTTON_SIZE, BUTTON_SIZE)


## Todos os botoes montados, com comando e retangulo, na resolucao base.
func layout() -> Array:
	var entries: Array = []
	for entry in LEFT_CLUSTER:
		entries.append(_entry(entry, 0))
	for entry in RIGHT_CLUSTER:
		entries.append(_entry(entry, 1))
	return entries


func _entry(source: Dictionary, cluster: int) -> Dictionary:
	return {
		"command": source["command"],
		"label": source["label"],
		"rect": button_rect(cluster, int(source["column"]), int(source["row"])),
	}


func _make_button(entry: Dictionary) -> Button:
	var command: int = entry["command"]
	var rect: Rect2i = entry["rect"]
	var button := Button.new()
	button.name = "TouchButton" + str(command)
	button.text = entry["label"]
	button.focus_mode = Control.FOCUS_NONE
	button.position = Vector2(rect.position)
	button.size = Vector2(rect.size)
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
