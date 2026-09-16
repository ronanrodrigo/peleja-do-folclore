class_name LocalPersistenceGateway
extends PersistenceGateway
## Adapter de producao da capacidade "guardar e restaurar preferencias e progresso".
##
## Um unico JSON em `user://` guarda os pares chave/valor (volume, mudo, remap e
## progresso do arcade). No export web o Godot mapeia `user://` para o
## armazenamento do navegador, entao as preferencias sobrevivem ao recarregar a
## pagina sem nenhum codigo especifico de plataforma aqui.
##
## Arquivo ausente ou ilegivel nao quebra o jogo: o adapter comeca com o
## armazenamento vazio e regrava na proxima gravacao (mesma politica do
## asset-gateway: dado ausente nunca derruba a experiencia).
##
## O adapter e instanciado apenas pelo composition root (`autoloads/app_container.gd`);
## nos testes de dominio e aplicacao quem esta no lugar e o
## `InMemoryPersistenceGateway` (sem I/O).

const DEFAULT_STORE_PATH := "user://peleja/preferences.json"
const JSON_INDENT := "\t"

var _store_path: String
var _values: Dictionary = {}
var _loaded: bool = false


func _init(p_store_path: String = DEFAULT_STORE_PATH) -> void:
	_store_path = p_store_path if not p_store_path.is_empty() else DEFAULT_STORE_PATH


## Caminho efetivo do arquivo de preferencias (observavel por teste).
func store_path() -> String:
	return _store_path


func save(key: String, value: Variant) -> bool:
	if key.is_empty() or not _is_storable(value):
		return false
	_ensure_loaded()
	_values[key] = value
	return _flush()


func load_value(key: String, default_value: Variant) -> Variant:
	if key.is_empty():
		return default_value
	_ensure_loaded()
	return _values.get(key, default_value)


func has(key: String) -> bool:
	if key.is_empty():
		return false
	_ensure_loaded()
	return _values.has(key)


func erase(key: String) -> void:
	if key.is_empty():
		return
	_ensure_loaded()
	if _values.erase(key):
		_flush()


## Todas as chaves gravadas, em ordem (observavel por teste e por ferramenta).
func keys() -> Array:
	_ensure_loaded()
	var stored: Array = _values.keys()
	stored.sort()
	return stored


## Descarta o cache e rele do arquivo -- usado quando outra sessao gravou.
func reload() -> void:
	_loaded = false
	_values.clear()
	_ensure_loaded()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_values = _read()
	if _values.is_empty():
		# Convencao do contrato (`has`/`load_value`): chave ausente e default.
		_values = {}


func _read() -> Dictionary:
	if not FileAccess.file_exists(_store_path):
		return {}
	var file := FileAccess.open(_store_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _flush() -> bool:
	var directory := _store_path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(_store_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_values, JSON_INDENT))
	file.close()
	return true


## Tipos que o JSON do armazenamento aceita. Fora disso a gravacao e recusada em
## vez de virar lixo silencioso no arquivo.
func _is_storable(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_ARRAY, TYPE_DICTIONARY:
			return true
		_:
			return false