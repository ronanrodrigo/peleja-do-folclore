extends GutTest
## Os adapters `sample` sao deterministicos e nao fazem I/O. Se um deles passar
## a tocar disco, rede, AudioServer ou o singleton Input, este teste falha.

const SAMPLE_DIRECTORY := "res://src/infrastructure/sample"
const EXPECTED_ADAPTERS := [
	"sample-input-gateway.gd",
	"sample-render-gateway.gd",
	"in-memory-asset-gateway.gd",
	"silent-audio-gateway.gd",
	"in-memory-persistence-gateway.gd",
]
const FORBIDDEN_TOKENS := [
	"FileAccess",
	"DirAccess",
	"AudioServer",
	"HTTPRequest",
	"HTTPClient",
	"ResourceLoader",
	"OS.",
	"user://",
	"res://",
]


func test_every_sample_adapter_exists() -> void:
	var directory := DirAccess.open(SAMPLE_DIRECTORY)
	assert_not_null(directory, "diretorio de adapters sample existe")
	for adapter in EXPECTED_ADAPTERS:
		assert_true(directory.file_exists(adapter), "adapter presente: %s" % adapter)


func test_sample_adapters_do_not_perform_io() -> void:
	for adapter in EXPECTED_ADAPTERS:
		var source := _source_of(SAMPLE_DIRECTORY + "/" + adapter)
		assert_ne(source, "", "codigo-fonte lido: %s" % adapter)
		for token in FORBIDDEN_TOKENS:
			assert_false(
				source.contains(token),
				"%s nao pode conter '%s': I/O proibido em adapter sample" % [adapter, token]
			)


func test_sample_input_gateway_is_deterministic() -> void:
	var gateway := SampleInputGateway.new()
	var scripted := [InputGateway.Command.CONFIRM, InputGateway.Command.LIGHT]
	gateway.script_commands(scripted)
	assert_eq(gateway.poll(), scripted, "a fila preserva a ordem programada")
	assert_eq(gateway.poll(), [], "a fila e consumida uma unica vez")
	assert_eq(gateway.pending(), 0)


func test_sample_render_gateway_accepts_only_integer_scale() -> void:
	var gateway := SampleRenderGateway.new()
	var pixels := PackedByteArray()
	assert_true(gateway.is_pixel_scale_valid(3), "3x e escala inteira valida")
	assert_false(gateway.is_pixel_scale_valid(0), "escala 0 nao e escala de pixel")
	assert_true(gateway.draw_pixels_scaled(Vector2i.ZERO, Vector2i(2, 2), pixels, 3))
	assert_eq(gateway.rejected_scales, [], "nenhuma escala valida foi recusada")


func test_sample_persistence_gateway_round_trips_in_memory() -> void:
	var gateway := InMemoryPersistenceGateway.new()
	assert_true(gateway.save("volume", 0.5), "gravacao em memoria aceita")
	assert_eq(gateway.load_value("volume", 1.0), 0.5, "valor lido e o gravado")
	assert_eq(gateway.load_value("ausente", 1.0), 1.0, "chave ausente devolve o default")
	assert_false(gateway.save("", 1), "chave vazia e recusada")


func test_sample_audio_gateway_never_touches_audio_server() -> void:
	var gateway := SilentAudioGateway.new()
	gateway.play_sfx("confirm")
	gateway.set_master_volume(0.25)
	assert_eq(gateway.sfx_calls, ["confirm"], "audio sample apenas registra a intencao")
	assert_eq(gateway.master_volume, 0.25)


func test_sample_asset_gateway_serves_seeded_content_and_fallback() -> void:
	var gateway := InMemoryAssetGateway.new()
	assert_true(gateway.exists("placeholder"), "paleta placeholder pre-carregada")
	assert_eq(gateway.load_spritesheet("saci"), {}, "sem spritesheet o adapter devolve vazio")
	assert_eq(
		gateway.load_panel("reviravolta", PackedByteArray([9])),
		PackedByteArray([9]),
		"painel ausente devolve o fallback recebido"
	)


func _source_of(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()