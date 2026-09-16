extends GutTest
## Adapter de producao da capacidade "guardar e restaurar preferencias".
##
## Este teste faz I/O de verdade, de proposito: ele prova o que o adapter
## promete (sobreviver a uma nova sessao) num caminho de teste em `user://`, nunca
## no arquivo de preferencias do jogo.

const TEST_STORE := "user://peleja-test/preferences.json"

var _gateway: LocalPersistenceGateway


func before_each() -> void:
	_remove_store()
	_gateway = LocalPersistenceGateway.new(TEST_STORE)


func after_each() -> void:
	_remove_store()


func test_store_path_is_the_configured_one() -> void:
	assert_eq(_gateway.store_path(), TEST_STORE, "o caminho e injetado, nao fixo")
	assert_eq(
		LocalPersistenceGateway.DEFAULT_STORE_PATH,
		"user://peleja/preferences.json",
		"o jogo usa o caminho padrao em user:// (localStorage no web)"
	)


func test_save_writes_and_load_reads_back() -> void:
	assert_true(_gateway.save("audio.master_volume", 0.4), "gravacao aceita")
	assert_true(_gateway.has("audio.master_volume"), "a chave existe depois de gravar")
	assert_almost_eq(
		_gateway.load_value("audio.master_volume", 1.0), 0.4, 0.001, "valor lido e o gravado"
	)
	assert_true(FileAccess.file_exists(TEST_STORE), "o arquivo de preferencias foi criado")
	assert_eq(_gateway.keys(), ["audio.master_volume"], "chaves gravadas")


func test_values_survive_a_new_gateway_instance() -> void:
	_gateway.save("audio.master_volume", 0.3)
	_gateway.save("audio.muted", true)
	var restarted := LocalPersistenceGateway.new(TEST_STORE)
	assert_almost_eq(
		restarted.load_value("audio.master_volume", 1.0), 0.3, 0.001, "volume da sessao anterior"
	)
	assert_eq(restarted.load_value("audio.muted", false), true, "mudo da sessao anterior")
	assert_true(restarted.has("audio.muted"))
	assert_eq(restarted.keys(), ["audio.master_volume", "audio.muted"], "as duas chaves")


func test_missing_key_returns_the_default() -> void:
	assert_eq(_gateway.load_value("ausente", 0.8), 0.8, "chave ausente devolve o default")
	assert_false(_gateway.has("ausente"), "chave ausente nao existe")


func test_erase_removes_the_key() -> void:
	_gateway.save("progress", 3)
	assert_true(_gateway.has("progress"))
	_gateway.erase("progress")
	assert_false(_gateway.has("progress"), "a chave foi removida")
	var restarted := LocalPersistenceGateway.new(TEST_STORE)
	assert_false(restarted.has("progress"), "a remocao tambem chegou ao arquivo")


func test_empty_key_and_unsupported_value_are_refused() -> void:
	assert_false(_gateway.save("", 1.0), "chave vazia e recusada")
	assert_eq(_gateway.load_value("", 7), 7, "chave vazia devolve o default")
	assert_false(_gateway.has(""), "chave vazia nunca existe")
	assert_false(
		_gateway.save("audio", RefCounted.new()), "valor nao serializavel e recusado"
	)
	assert_false(_gateway.has("audio"), "nada foi gravado pela metade")


func test_foreign_json_payload_is_treated_as_empty_storage() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_STORE.get_base_dir())
	var file := FileAccess.open(TEST_STORE, FileAccess.WRITE)
	# JSON valido que nao e um objeto de chave/valor (arquivo de outra versao).
	file.store_string("[1, 2, 3]")
	file.close()
	assert_eq(
		_gateway.load_value("audio.master_volume", 0.8), 0.8, "payload estranho nao derruba o jogo"
	)
	assert_eq(_gateway.keys(), [], "armazenamento comeca vazio")
	assert_true(_gateway.save("audio.master_volume", 0.5), "e a gravacao seguinte funciona")
	var restarted := LocalPersistenceGateway.new(TEST_STORE)
	assert_almost_eq(restarted.load_value("audio.master_volume", 1.0), 0.5, 0.001, "arquivo limpo")


func test_reload_picks_up_what_another_session_wrote() -> void:
	_gateway.save("audio.master_volume", 0.2)
	var other := LocalPersistenceGateway.new(TEST_STORE)
	other.save("audio.master_volume", 0.6)
	assert_almost_eq(
		_gateway.load_value("audio.master_volume", 1.0), 0.2, 0.001, "cache da instancia"
	)
	_gateway.reload()
	assert_almost_eq(
		_gateway.load_value("audio.master_volume", 1.0), 0.6, 0.001, "valor recarregado do arquivo"
	)


func _remove_store() -> void:
	if FileAccess.file_exists(TEST_STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STORE))