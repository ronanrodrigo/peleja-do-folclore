class_name SampleInputGateway
extends InputGateway
## Adapter de entrada deterministico usado em testes.
##
## Sem I/O, sem `Input`, sem engine: a fila de comandos e programada pelo teste
## e consumida na mesma ordem. Mesma programacao produz sempre o mesmo poll().

var _queue: Array = []


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