extends GutTest
## Smoke do composition root: o esqueleto sobe, injeta as cinco capacidades e
## nao guarda estado de jogo. Usa explicitamente o modo `sample`.

const CONTAINER_SCRIPT := "res://autoloads/app_container.gd"
const SAMPLE_ENV := "sample"
const CAPABILITIES := ["input", "render", "asset", "audio", "persistence"]
const GAME_STATE_PROPERTIES := ["health", "round", "selection", "progress"]

var _container: Variant


func before_each() -> void:
	OS.set_environment("PELEJA_ADAPTERS", SAMPLE_ENV)
	_container = load(CONTAINER_SCRIPT).new()
	_container.name = "smoke_app_container"
	add_child_autofree(_container)


func after_each() -> void:
	OS.set_environment("PELEJA_ADAPTERS", "")


func test_container_boots_and_is_wired() -> void:
	assert_not_null(_container, "composition root instanciou")
	assert_true(_container.is_wired(), "as cinco capacidades estao injetadas")


func test_sample_mode_is_selected_by_explicit_configuration() -> void:
	assert_eq(_container.mode(), SAMPLE_ENV, "modo vem de configuracao explicita")


func test_every_gateway_satisfies_its_contract() -> void:
	assert_true(_container.input_gateway() is InputGateway, "input-gateway")
	assert_true(_container.render_gateway() is RenderGateway, "render-gateway")
	assert_true(_container.asset_gateway() is AssetGateway, "asset-gateway")
	assert_true(_container.audio_gateway() is AudioGateway, "audio-gateway")
	assert_true(_container.persistence_gateway() is PersistenceGateway, "persistence-gateway")


func test_autoload_is_registered_in_project_settings() -> void:
	assert_true(
		ProjectSettings.has_setting("autoload/app_container"),
		"app_container declarado como autoload"
	)


func test_container_holds_no_game_state() -> void:
	for property in _container.get_property_list():
		var property_name: String = property["name"]
		assert_false(
			property_name in GAME_STATE_PROPERTIES,
			"composition root nao guarda estado de jogo (%s)" % property_name
		)


func test_capabilities_without_production_adapter_are_reported() -> void:
	var missing: Array = _container.missing_production()
	for capability in CAPABILITIES:
		assert_true(
			capability in missing,
			"capacidade ainda sem adapter de producao: %s" % capability
		)


func test_live_mode_falls_back_to_sample_while_production_is_missing() -> void:
	OS.set_environment("PELEJA_ADAPTERS", "live")
	var live_container: Variant = load(CONTAINER_SCRIPT).new()
	live_container.name = "live_app_container"
	add_child_autofree(live_container)
	assert_eq(live_container.mode(), "live", "modo live e explicito")
	assert_true(live_container.is_wired(), "modo live ainda injeta as cinco capacidades")
	assert_eq(
		live_container.origin("asset"),
		SAMPLE_ENV,
		"sem adapter de producao, a origem registrada e sample"
	)
	OS.set_environment("PELEJA_ADAPTERS", SAMPLE_ENV)