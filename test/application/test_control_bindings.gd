extends GutTest
## Remap de controles (ticket 10): o mapa acao -> teclas e persistido, aplicado no
## input-gateway injetado e restaurado na sessao seguinte. Adapters `sample`.

var _bindings: ControlBindings
var _persistence: InMemoryPersistenceGateway
var _input: SampleInputGateway


func before_each() -> void:
	_persistence = InMemoryPersistenceGateway.new()
	_input = SampleInputGateway.new()
	_bindings = ControlBindings.new(_persistence, _input)
	_bindings.load_bindings()


func test_the_actions_come_from_the_injected_input_gateway() -> void:
	assert_eq(_bindings.actions(), _input.action_names(), "as acoes sao as do teclado")
	assert_eq(_bindings.actions().size(), 8, "oito acoes remapeaveis")


func test_without_stored_keys_the_defaults_are_the_gateway_ones() -> void:
	for action in _bindings.actions():
		assert_eq(
			_bindings.binding(action), _input.DEFAULT_BINDINGS[action],
			"padrao do teclado para %s" % action
		)
	assert_false(_bindings.has_custom_binding(), "nada remapeado ainda")


func test_setting_a_binding_applies_to_the_gateway_and_persists() -> void:
	assert_true(_bindings.set_binding("special", [KEY_Q]))
	assert_eq(_bindings.key_for("special"), KEY_Q)
	assert_eq(
		_input.bindings()["special"], [KEY_Q], "o remap chegou no input-gateway injetado"
	)
	assert_true(_bindings.has_custom_binding(), "ha remap ajustado")
	assert_eq(
		_persistence.load_value("controls.special", []), [KEY_Q], "a tecla foi gravada"
	)


func test_the_remap_survives_a_new_session() -> void:
	_bindings.set_binding("light", [KEY_Z])
	var restarted := ControlBindings.new(_persistence, SampleInputGateway.new())
	restarted.load_bindings()
	assert_eq(restarted.key_for("light"), KEY_Z, "tecla restaurada na sessao seguinte")
	assert_eq(restarted.key_for("heavy"), 107, "o resto continua no padrao")


func test_reset_returns_every_action_to_the_teclado_default() -> void:
	_bindings.set_binding("grab", [KEY_Q])
	_bindings.set_binding("crouch", [KEY_W])
	assert_true(_bindings.reset_bindings())
	assert_false(_bindings.has_custom_binding(), "tudo de volta ao padrao")
	assert_eq(_bindings.binding("grab"), _input.DEFAULT_BINDINGS["grab"])


func test_an_unknown_action_or_an_empty_binding_is_refused() -> void:
	assert_false(_bindings.set_binding("nao_existe", [KEY_Q]), "acao desconhecida")
	assert_false(_bindings.set_binding("light", []), "lista vazia nao deixa acao sem tecla")
	assert_eq(_bindings.binding("light"), _input.DEFAULT_BINDINGS["light"])


func test_the_remap_walks_every_action_once_and_then_closes() -> void:
	assert_true(_bindings.begin_remap(), "o remap comeca pela primeira acao")
	var seen: Array = []
	var guard := 0
	while _bindings.is_remapping() and guard < 20:
		seen.append(_bindings.remap_action())
		assert_true(_bindings.bind_key(KEY_Q), "a tecla e aceita")
		guard += 1
	assert_eq(seen, Array(_bindings.actions()), "uma tecla por acao, na ordem do menu")
	assert_false(_bindings.is_remapping(), "o remap fecha sozinho na ultima")
	for action in _bindings.actions():
		assert_eq(_bindings.key_for(action), KEY_Q, "todas as acoes foram remapeadas")


func test_cancelling_the_remap_keeps_the_map_untouched() -> void:
	_bindings.begin_remap()
	_bindings.bind_key(KEY_Q)
	_bindings.cancel_remap()
	assert_false(_bindings.is_remapping())
	assert_eq(_bindings.key_for("move_left"), KEY_Q, "o que ja foi remapeado fica")
	assert_eq(_bindings.remap_action(), "", "sem remap em curso nao ha acao corrente")
