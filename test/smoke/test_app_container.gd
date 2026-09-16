extends GutTest
## Smoke do composition root: o esqueleto sobe, injeta as cinco capacidades e
## nao guarda estado de jogo. Usa explicitamente o modo `sample`.

const CONTAINER_SCRIPT := "res://autoloads/app_container.gd"
const CONTAINER := preload("res://autoloads/app_container.gd")
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
	for capability in missing:
		assert_false(
			ResourceLoader.exists(CONTAINER.PRODUCTION_ADAPTERS[capability]),
			"capacidade reportada sem producao realmente nao tem adapter: %s" % capability
		)
	for capability in CAPABILITIES:
		if not missing.has(capability):
			assert_true(
				ResourceLoader.exists(CONTAINER.PRODUCTION_ADAPTERS[capability]),
				"capacidade fora da lista de faltantes tem adapter de producao: %s" % capability
			)


func test_asset_capability_already_has_a_production_adapter() -> void:
	assert_false(
		_container.missing_production().has("asset"),
		"o asset-gateway de producao existe desde o ticket 9"
	)


func test_input_capability_now_has_a_production_adapter() -> void:
	assert_false(
		_container.missing_production().has("input"),
		"o teclado de producao existe desde o ticket 3"
	)


func test_render_capability_now_has_a_production_adapter() -> void:
	assert_false(
		_container.missing_production().has("render"),
		"o sprite-render-adapter de producao existe desde o ticket 4"
	)


func test_render_capability_falls_back_to_sample_only_when_production_is_missing() -> void:
	var reported_missing: bool = _container.missing_production().has("render")
	var production_missing: bool = not ResourceLoader.exists(
		CONTAINER.PRODUCTION_ADAPTERS["render"]
	)
	assert_eq(
		reported_missing,
		production_missing,
		"render cai para sample se e somente se nao tem adapter de producao"
	)


func test_input_capability_falls_back_to_sample_only_when_production_is_missing() -> void:
	var reported_missing: bool = _container.missing_production().has("input")
	var production_missing: bool = not ResourceLoader.exists(
		CONTAINER.PRODUCTION_ADAPTERS["input"]
	)
	assert_eq(
		reported_missing,
		production_missing,
		"input cai para sample se e somente se nao tem adapter de producao"
	)


func test_live_mode_uses_the_production_adapter_where_it_exists() -> void:
	OS.set_environment("PELEJA_ADAPTERS", "live")
	var live_container: Variant = load(CONTAINER_SCRIPT).new()
	live_container.name = "live_app_container"
	add_child_autofree(live_container)
	assert_eq(live_container.mode(), "live", "modo live e explicito")
	assert_true(live_container.is_wired(), "modo live ainda injeta as cinco capacidades")
	var missing: Array = live_container.missing_production()
	for capability in CAPABILITIES:
		var expected: String = SAMPLE_ENV if missing.has(capability) else "live"
		assert_eq(
			live_container.origin(capability),
			expected,
			"origem do adapter de %s segue a existencia do adapter de producao" % capability
		)
	assert_eq(live_container.origin("asset"), "live", "asset usa o adapter de producao")
	assert_eq(live_container.origin("input"), "live", "input usa o teclado de producao")
	assert_eq(live_container.origin("render"), "live", "render usa o sprite-render-adapter")
	assert_true(live_container.asset_gateway() is AssetGateway, "gateway de asset injetado")
	assert_true(live_container.render_gateway() is RenderGateway, "gateway de render injetado")
	assert_true(
		live_container.touch_input_gateway() is InputGateway,
		"o toque tambem e instanciado pelo composition root"
	)
	assert_eq(live_container.origin("audio"), "live", "audio usa o godot-audio-gateway")
	assert_eq(
		live_container.origin("persistence"), "live", "persistence usa o local-persistence-gateway"
	)
	assert_true(live_container.audio_gateway() is AudioGateway, "gateway de audio injetado")
	assert_true(
		live_container.persistence_gateway() is PersistenceGateway,
		"gateway de persistencia injetado"
	)
	OS.set_environment("PELEJA_ADAPTERS", SAMPLE_ENV)


func test_audio_capability_now_has_a_production_adapter() -> void:
	assert_false(
		_container.missing_production().has("audio"),
		"o godot-audio-gateway de producao existe desde o ticket 8"
	)


func test_persistence_capability_now_has_a_production_adapter() -> void:
	assert_false(
		_container.missing_production().has("persistence"),
		"o local-persistence-gateway de producao existe desde o ticket 8"
	)


func test_audio_capability_falls_back_to_sample_only_when_production_is_missing() -> void:
	var reported_missing: bool = _container.missing_production().has("audio")
	var production_missing: bool = not ResourceLoader.exists(
		CONTAINER.PRODUCTION_ADAPTERS["audio"]
	)
	assert_eq(
		reported_missing,
		production_missing,
		"audio cai para sample se e somente se nao tem adapter de producao"
	)


func test_persistence_capability_falls_back_to_sample_only_when_production_is_missing() -> void:
	var reported_missing: bool = _container.missing_production().has("persistence")
	var production_missing: bool = not ResourceLoader.exists(
		CONTAINER.PRODUCTION_ADAPTERS["persistence"]
	)
	assert_eq(
		reported_missing,
		production_missing,
		"persistence cai para sample se e somente se nao tem adapter de producao"
	)
