class_name SampleInputGateway
extends InputGateway
## Adapter de entrada deterministico usado em testes.
##
## Sem I/O, sem `Input`, sem engine: a fila de comandos e programada pelo teste
## e consumida na mesma ordem. Mesma programacao produz sempre o mesmo poll().
##
## Tambem carrega um mapa de teclas deterministico (codigos ASCII escritos a mao,
## sem constante de engine): e o que o caso de uso de opcoes le como padrao e o
## que o menu de remap mostra quando o jogo roda no modo `sample`.

## Acoes remapeaveis, na mesma ordem (em ingles) do teclado de producao.
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

## Teclas padrao do adapter: um codigo ASCII por acao (a=97, d=100, s=115,
## w=119, j=106, k=107, l=108, u=117). Deterministico e sem constante de engine.
const DEFAULT_BINDINGS := {
	"move_left": [97, 119],
	"move_right": [100],
	"crouch": [115],
	"block": [106],
	"light": [106],
	"heavy": [107],
	"grab": [108],
	"special": [117],
}

## Remaps aplicados, na ordem (observavel por teste).
var applied_bindings: Array = []

var _queue: Array = []
var _bindings: Dictionary = {}


func _init() -> void:
	_bindings = DEFAULT_BINDINGS.duplicate(true)


## Enfileira um ou mais comandos na ordem em que serao consumidos.
func script_commands(commands: Array) -> void:
	for command in commands:
		_queue.append(command)


func poll() -> Array:
	var drained: Array = _queue.duplicate()
	_queue.clear()
	return drained


func clear() -> void:
	_queue.clear()


## Quantidade de comandos ainda pendentes (observavel sem consumir a fila).
func pending() -> int:
	return _queue.size()


func action_names() -> PackedStringArray:
	var names := PackedStringArray()
	for action in ACTION_ORDER:
		names.append(action)
	return names


func bindings() -> Dictionary:
	return _bindings.duplicate(true)


## Registra o remap aplicado. Acao desconhecida ou lista vazia sao ignoradas,
## como no adapter de teclado.
func apply_bindings(bindings: Dictionary) -> void:
	var accepted: Dictionary = {}
	for action in bindings.keys():
		if not _bindings.has(action):
			continue
		var keys: Array = bindings[action]
		if keys.is_empty():
			continue
		_bindings[action] = keys.duplicate()
		accepted[str(action)] = keys.duplicate()
	if not accepted.is_empty():
		applied_bindings.append(accepted)
