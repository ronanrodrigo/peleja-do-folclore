class_name ControlBindings
extends RefCounted
## Remap de controles: mapa acao -> teclas, persistido entre sessoes (ticket 10).
##
## Classe de apoio do `OptionsService`: o remap tem superficie propria (iniciar,
## avancar acao a acao, cancelar) e nao caberia no caso de uso sem estourar o
## limite de metodos publicos por classe. Nao conhece engine nem cena: os codigos
## de tecla sao INTEIROS OPACOS, exatamente como o `input-gateway` os entrega --
## quem sabe o que e uma tecla e o adapter de interface, nao este arquivo.
##
## Cada acao e gravada na persistencia pela chave `controls/<acao>`; sem nada
## gravado, valem as teclas do adapter de entrada injetado (os padroes do teclado).
## Toda mudanca e aplicada no adapter E gravada na mesma chamada.

const KEY_PREFIX := "controls."

var _persistence: PersistenceGateway
var _input: InputGateway
## Teclas padrao do adapter, capturadas na construcao -- ANTES de qualquer remap
## ser aplicado. Sem isso, `reset_bindings` devolveria o mapa ja remapeado.
var _defaults: Dictionary = {}
var _bindings: Dictionary = {}
var _remapping: bool = false
var _remap_index: int = 0


func _init(p_persistence: PersistenceGateway, p_input: InputGateway = null) -> void:
	_persistence = p_persistence
	_input = p_input
	_defaults = _input.bindings().duplicate(true) if _input != null else {}


## Carrega o remap gravado; o que faltar vem do adapter de entrada injetado. Sem
## adapter, o mapa fica vazio e nenhuma acao e remapeavel.
func load_bindings() -> void:
	_bindings = _default_bindings()
	for action in actions():
		var stored: Variant = _load(action)
		if stored is Array and not (stored as Array).is_empty():
			_bindings[action] = _int_keys(stored)
	_apply_and_persist()


## Acoes remapeaveis, na ordem de apresentacao do menu.
func actions() -> PackedStringArray:
	if _input == null:
		return PackedStringArray()
	return _input.action_names()


## Tecla primaria de uma acao; 0 quando a acao nao existe.
func key_for(action: String) -> int:
	var keys: Array = _bindings.get(action, [])
	return int(keys[0]) if not keys.is_empty() else 0


## Teclas de uma acao (copia: o chamador nao mexe no mapa).
func binding(action: String) -> Array:
	var keys: Array = _bindings.get(action, [])
	return keys.duplicate()


## Novo mapa de teclas de uma acao. Acao desconhecida ou lista vazia sao recusadas.
func set_binding(action: String, keys: Array) -> bool:
	if not _bindings.has(action) or keys.is_empty():
		return false
	_bindings[action] = _int_keys(keys)
	_apply_and_persist()
	return true


## Volta aos padroes do adapter de entrada e regrava.
func reset_bindings() -> bool:
	_bindings = _default_bindings()
	if _bindings.is_empty():
		return false
	_apply_and_persist()
	return true


## Verdadeiro quando alguma acao ja tem tecla diferente do padrao do adapter.
func has_custom_binding() -> bool:
	for action in _bindings.keys():
		if _bindings[action] != _defaults.get(action, []):
			return true
	return false


## Verdadeiro quando o menu esta capturando uma tecla nova.
func is_remapping() -> bool:
	return _remapping


## Acao que esta sendo remapeada agora (vazia quando nao ha remap em curso).
func remap_action() -> String:
	if not _remapping:
		return ""
	var names := actions()
	if _remap_index < 0 or _remap_index >= names.size():
		return ""
	return str(names[_remap_index])


## Posicao base zero da acao em remap.
func remap_index() -> int:
	return _remap_index


## Inicia o remap pela primeira acao. Recusa quando nao ha acao remapeavel.
func begin_remap() -> bool:
	if actions().is_empty():
		return false
	_remapping = true
	_remap_index = 0
	return true


## Aplica a tecla apertada na acao corrente e avanca para a proxima; depois da
## ultima, o remap fecha sozinho.
func bind_key(keycode: int) -> bool:
	if not _remapping:
		return false
	var action := remap_action()
	if action.is_empty():
		cancel_remap()
		return false
	set_binding(action, [keycode])
	_remap_index += 1
	if _remap_index >= actions().size():
		cancel_remap()
	return true


func cancel_remap() -> void:
	_remapping = false
	_remap_index = 0


func _default_bindings() -> Dictionary:
	return _defaults.duplicate(true)


func _apply_and_persist() -> void:
	if _input != null:
		_input.apply_bindings(_bindings)
	for action in _bindings.keys():
		_persistence.save(KEY_PREFIX + str(action), _bindings[action])


func _load(action: String) -> Variant:
	return _persistence.load_value(KEY_PREFIX + action, [])


func _int_keys(keys: Array) -> Array:
	var converted: Array = []
	for key in keys:
		converted.append(int(key))
	return converted
