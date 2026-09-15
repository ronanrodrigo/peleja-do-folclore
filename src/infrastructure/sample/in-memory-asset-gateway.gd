class_name InMemoryAssetGateway
extends AssetGateway
## Adapter de arte deterministico usado em testes.
##
## Todo o conteudo e pre-carregado em memoria a partir de um dicionario passado
## no construtor; nada e lido do disco nem da rede.

const DEFAULT_PALETTE_ID := "placeholder"

var _palettes: Dictionary = {}
var _spritesheets: Dictionary = {}
var _panels: Dictionary = {}


func _init(seed_content: Dictionary = {}) -> void:
	_palettes = {
		"placeholder": PackedColorArray(
			[Color8(18, 18, 42), Color8(255, 211, 92), Color8(255, 255, 255)]
		),
	}
	for key in seed_content.keys():
		var value: Variant = seed_content[key]
		if typeof(value) == TYPE_DICTIONARY:
			_spritesheets[key] = value
		else:
			_panels[key] = value


func exists(id: String) -> bool:
	return _palettes.has(id) or _spritesheets.has(id) or _panels.has(id)


func load_palette(id: String) -> PackedColorArray:
	if _palettes.has(id):
		return _palettes[id]
	return PackedColorArray()


func load_spritesheet(slug: String) -> Dictionary:
	if _spritesheets.has(slug):
		return _spritesheets[slug]
	return {}


func load_panel(slug: String, fallback: PackedByteArray) -> PackedByteArray:
	if _panels.has(slug):
		return _panels[slug]
	return fallback


## Registra uma paleta em memoria (usado pelos testes para preparar cenarios).
func put_palette(id: String, colors: PackedColorArray) -> void:
	_palettes[id] = colors