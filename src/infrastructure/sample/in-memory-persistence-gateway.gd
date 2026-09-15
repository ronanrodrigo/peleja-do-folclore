class_name InMemoryPersistenceGateway
extends PersistenceGateway
## Adapter de persistencia deterministico usado em testes.
##
## Dicionario em memoria; nada e gravado em disco nem no armazenamento do navegador.

var _values: Dictionary = {}


func save(key: String, value: Variant) -> bool:
	if key.is_empty():
		return false
	_values[key] = value
	return true


func load_value(key: String, default_value: Variant) -> Variant:
	if _values.has(key):
		return _values[key]
	return default_value


func has(key: String) -> bool:
	return _values.has(key)


func erase(key: String) -> void:
	_values.erase(key)


## Snapshot das chaves gravadas (observavel pelo teste).
func keys() -> Array:
	var sorted_keys: Array = _values.keys()
	sorted_keys.sort()
	return sorted_keys