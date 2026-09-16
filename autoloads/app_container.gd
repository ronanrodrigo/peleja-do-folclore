extends Node
## Composition root.
##
## Unico lugar do projeto que instancia adapters concretos e os injeta. Nao
## guarda estado de jogo: nenhuma variavel aqui representa vida, round, selecao
## ou progresso. O modo de adapters e escolhido por configuracao explicita
## (variavel de ambiente, argumento de CLI ou project setting) -- nenhum caso de
## uso decide isso, e nenhum caso de uso checa provedor.
##
## Enquanto uma capacidade nao tem adapter de producao, o modo `live` cai para o
## adapter `sample` correspondente e registra isso em `missing_production()`.
## Assim o esqueleto roda antes de cada ticket e passa a usar producao sozinho
## quando o adapter real aparece no caminho declarado (foi o caso de input,
## render, asset, audio e persistencia).

const MODE_SAMPLE := "sample"
const MODE_LIVE := "live"

const ENV_KEY := "PELEJA_ADAPTERS"
const SETTING_KEY := "peleja/adapters/mode"

const CAPABILITY_INPUT := "input"
const CAPABILITY_RENDER := "render"
const CAPABILITY_ASSET := "asset"
const CAPABILITY_AUDIO := "audio"
const CAPABILITY_PERSISTENCE := "persistence"

## Caminhos dos adapters de producao, por capacidade. Podem ainda nao existir.
const PRODUCTION_ADAPTERS := {
	CAPABILITY_INPUT: "res://src/interface-adapters/keyboard-input-adapter.gd",
	CAPABILITY_RENDER: "res://src/interface-adapters/sprite-render-adapter.gd",
	CAPABILITY_ASSET: "res://src/infrastructure/godot-asset-gateway.gd",
	CAPABILITY_AUDIO: "res://src/infrastructure/godot-audio-gateway.gd",
	CAPABILITY_PERSISTENCE: "res://src/infrastructure/local-persistence-gateway.gd",
}

## Adapters determinísticos em memoria, usados em testes e como fallback.
const SAMPLE_ADAPTERS := {
	CAPABILITY_INPUT: "res://src/infrastructure/sample/sample-input-gateway.gd",
	CAPABILITY_RENDER: "res://src/infrastructure/sample/sample-render-gateway.gd",
	CAPABILITY_ASSET: "res://src/infrastructure/sample/in-memory-asset-gateway.gd",
	CAPABILITY_AUDIO: "res://src/infrastructure/sample/silent-audio-gateway.gd",
	CAPABILITY_PERSISTENCE: "res://src/infrastructure/sample/in-memory-persistence-gateway.gd",
}

## A capacidade de entrada tem dois adapters de producao (teclado e toque). O
## caminho acima e o do teclado; o de toque e instanciado junto e exposto por
## `touch_input_gateway()`. Continua sendo o composition root o unico lugar que
## instancia adapter concreto.
const PRODUCTION_TOUCH_ADAPTER := "res://src/interface-adapters/touch-input-adapter.gd"

const _ALL_CAPABILITIES := [
	CAPABILITY_INPUT,
	CAPABILITY_RENDER,
	CAPABILITY_ASSET,
	CAPABILITY_AUDIO,
	CAPABILITY_PERSISTENCE,
]

var _mode: String = MODE_LIVE
var _gateways: Dictionary = {}
var _origins: Dictionary = {}
var _touch_gateway: InputGateway = null


func _enter_tree() -> void:
	wire()


## Instancia e injeta os adapters. Idempotente: chamar de novo reconstroi.
func wire() -> void:
	_mode = _resolve_mode()
	_gateways.clear()
	_origins.clear()
	for capability in _ALL_CAPABILITIES:
		var origin := _resolve_origin(capability)
		_origins[capability] = origin
		var script_path: String = (
			SAMPLE_ADAPTERS[capability] if origin == MODE_SAMPLE else PRODUCTION_ADAPTERS[capability]
		)
		_gateways[capability] = (load(script_path) as GDScript).new()
	_wire_audio_output()
	_wire_touch()


## O adapter de audio de producao precisa de um no hospedeiro para os players, e
## quem sobrevive a troca de cena e este autoload -- a musica atravessa as cenas.
## O adapter `sample` (silencioso) nao tem `mount`: nada e montado em teste.
func _wire_audio_output() -> void:
	var adapter: Variant = _gateways.get(CAPABILITY_AUDIO)
	if adapter == null or not adapter.has_method("mount"):
		return
	adapter.mount(self)


## O adapter de toque so existe quando a entrada esta em producao e o arquivo ja
## foi implementado; em modo `sample` a cena usa o input-gateway injetado.
func _wire_touch() -> void:
	_touch_gateway = null
	if _origins.get(CAPABILITY_INPUT) != MODE_LIVE:
		return
	if not ResourceLoader.exists(PRODUCTION_TOUCH_ADAPTER):
		return
	_touch_gateway = (load(PRODUCTION_TOUCH_ADAPTER) as GDScript).new()


func mode() -> String:
	return _mode


## Origem do adapter efetivamente instanciado ("sample" ou "live").
func origin(capability: String) -> String:
	return _origins.get(capability, "")


## Capacidades que ainda nao tem adapter de producao implementado.
func missing_production() -> Array:
	var missing: Array = []
	for capability in _ALL_CAPABILITIES:
		if not ResourceLoader.exists(PRODUCTION_ADAPTERS[capability]):
			missing.append(capability)
	return missing


func input_gateway() -> InputGateway:
	return _gateways.get(CAPABILITY_INPUT)


## Adapter de toque, quando a entrada esta em producao. Nulo em modo `sample` ou
## enquanto o arquivo nao existir -- a cena cai para `input_gateway()`.
func touch_input_gateway() -> InputGateway:
	return _touch_gateway


func render_gateway() -> RenderGateway:
	return _gateways.get(CAPABILITY_RENDER)


func asset_gateway() -> AssetGateway:
	return _gateways.get(CAPABILITY_ASSET)


func audio_gateway() -> AudioGateway:
	return _gateways.get(CAPABILITY_AUDIO)


func persistence_gateway() -> PersistenceGateway:
	return _gateways.get(CAPABILITY_PERSISTENCE)


## Verdadeiro quando todas as cinco capacidades estao injetadas.
func is_wired() -> bool:
	for capability in _ALL_CAPABILITIES:
		if _gateways.get(capability) == null:
			return false
	return true


func _resolve_mode() -> String:
	var configured := _configured_mode()
	return MODE_SAMPLE if configured == MODE_SAMPLE else MODE_LIVE


func _resolve_origin(capability: String) -> String:
	if _mode == MODE_SAMPLE:
		return MODE_SAMPLE
	if ResourceLoader.exists(PRODUCTION_ADAPTERS[capability]):
		return MODE_LIVE
	return MODE_SAMPLE


func _configured_mode() -> String:
	var from_env := OS.get_environment(ENV_KEY).strip_edges().to_lower()
	if not from_env.is_empty():
		return from_env
	for argument in OS.get_cmdline_user_args():
		var value := argument.strip_edges().to_lower()
		if value == "--adapters=" + MODE_SAMPLE:
			return MODE_SAMPLE
		if value == "--adapters=" + MODE_LIVE:
			return MODE_LIVE
	return str(ProjectSettings.get_setting(SETTING_KEY, MODE_LIVE))