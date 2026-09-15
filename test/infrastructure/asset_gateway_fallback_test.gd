extends GutTest
## O `godot-asset-gateway` (adapter de producao) carrega arte gerada por slug e
## cai no fallback quando o arquivo nao existe: o jogo nunca quebra por arte
## ausente (ADR 0005). A arte real e os metadados versionados sao exercitados de
## verdade aqui -- nao ha mock de arquivo.

const GENERATED_KINDS := {
	"forest-arena": "backgrounds",
	"reviravolta-panel": "panels",
	"saci-portrait": "portraits",
}
const MISSING_SLUG := "slug-que-nao-existe"
const PALETTE_ID := "peleja"
const BASE_WIDTH := 426
const BASE_HEIGHT := 240
const RGBA8_BYTES := BASE_WIDTH * BASE_HEIGHT * 4
const MAX_COLORS := 32
const CREDITS_PATH := "res://assets/generated/CREDITS.md"
const METADATA_KEYS := [
	"prompt",
	"negative_prompt",
	"seed",
	"model",
	"model_license",
	"model_source_url",
]

var _gateway: GodotAssetGateway


func before_each() -> void:
	_gateway = GodotAssetGateway.new()


func test_adapter_satisfies_the_asset_gateway_contract() -> void:
	assert_true(_gateway is AssetGateway, "o adapter de producao implementa o contrato asset-gateway")


func test_generated_art_is_loaded_by_slug() -> void:
	for slug in GENERATED_KINDS:
		var path: String = "res://assets/generated/%s/%s.png" % [GENERATED_KINDS[slug], slug]
		assert_true(ResourceLoader.exists(path), "arte versionada presente: %s" % path)
		assert_true(_gateway.has_art(slug), "gateway encontra a arte pelo slug %s" % slug)
		var pixels: PackedByteArray = _gateway.load_panel(slug, PackedByteArray())
		assert_eq(pixels.size(), RGBA8_BYTES, "%s devolve 426x240 RGBA8" % slug)
		assert_ne(
			pixels,
			_gateway.code_fallback(slug),
			"%s e a arte gerada, nao o fallback em codigo" % slug
		)


func test_unknown_slug_returns_the_caller_fallback() -> void:
	var fallback := PackedByteArray([9, 9, 9])
	assert_false(_gateway.has_art(MISSING_SLUG), "slug inexistente nao tem arte")
	assert_eq(
		_gateway.load_panel(MISSING_SLUG, fallback),
		fallback,
		"sem arquivo, o fallback do chamador volta intacto"
	)


func test_unknown_slug_without_caller_fallback_returns_code_fallback() -> void:
	var pixels: PackedByteArray = _gateway.load_panel(MISSING_SLUG, PackedByteArray())
	assert_eq(pixels.size(), RGBA8_BYTES, "o fallback em codigo tem a resolucao base 426x240")
	assert_eq(
		pixels, _gateway.code_fallback(MISSING_SLUG), "mesmo slug, mesmo fallback (deterministico)"
	)
	assert_ne(
		pixels, _gateway.code_fallback("outro-slug"), "slug diferente produz fallback diferente"
	)


func test_metadata_carries_prompt_seed_model_and_license() -> void:
	for slug in GENERATED_KINDS:
		var metadata: Dictionary = _gateway.metadata(slug)
		assert_false(metadata.is_empty(), "metadados versionados de %s" % slug)
		for key in METADATA_KEYS:
			assert_true(
				metadata.has(key) and str(metadata[key]) != "",
				"%s registra %s nos metadados" % [slug, key]
			)
		assert_true(metadata.has("postprocess"), "%s registra o pos-processamento" % slug)
		assert_eq(
			metadata["postprocess"]["size"],
			[BASE_WIDTH * 1.0, BASE_HEIGHT * 1.0],
			"%s saiu na resolucao base" % slug
		)
		assert_true(
			int(metadata["postprocess"]["colors"]) <= MAX_COLORS,
			"%s saiu com no maximo %d cores" % [slug, MAX_COLORS]
		)


func test_metadata_is_empty_for_unknown_slug() -> void:
	assert_true(_gateway.metadata(MISSING_SLUG).is_empty(), "slug ausente nao tem metadados")


func test_game_palette_comes_from_the_versioned_file() -> void:
	var palette: PackedColorArray = _gateway.load_palette(PALETTE_ID)
	assert_true(palette.size() >= 5, "a paleta do jogo tem as cores da tela de titulo")
	assert_true(palette.has(Color8(255, 211, 92)), "o amarelo da tela de titulo esta na paleta")
	assert_true(_gateway.exists(PALETTE_ID), "a paleta conta como identificador existente")
	assert_true(_gateway.load_palette(MISSING_SLUG).is_empty(), "paleta ausente volta vazia")


func test_credits_registers_model_license_and_origin_url() -> void:
	var credits: String = FileAccess.get_file_as_string(CREDITS_PATH)
	assert_ne(credits, "", "CREDITS.md existe e tem conteudo")
	assert_true(credits.contains("v1-5-pruned-emaonly.safetensors"), "CREDITS cita o checkpoint")
	assert_true(credits.contains("CreativeML Open RAIL-M"), "CREDITS cita a licenca")
	assert_true(credits.contains("huggingface.co/stable-diffusion-v1-5"), "CREDITS cita a origem")
	for slug in GENERATED_KINDS:
		assert_true(credits.contains(slug), "CREDITS cita a arte %s" % slug)
