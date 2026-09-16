extends GutTest
## O caso de uso "opcoes de audio" aplica volume e mudo no audio-gateway e grava
## os dois na persistencia, para a proxima sessao. Nos testes os dois adapters sao
## `sample`: nada de disco e nada de AudioServer.

const KEY_VOLUME := OptionsService.KEY_MASTER_VOLUME
const KEY_MUTED := OptionsService.KEY_MUTED


func _fixture() -> Dictionary:
	var persistence := InMemoryPersistenceGateway.new()
	var audio := SilentAudioGateway.new()
	var service := OptionsService.new(persistence, audio)
	service.load_preferences()
	return {"service": service, "persistence": persistence, "audio": audio}


func test_defaults_when_nothing_was_stored() -> void:
	var fx := _fixture()
	var service: OptionsService = fx["service"]
	assert_almost_eq(service.volume(), OptionsService.DEFAULT_MASTER_VOLUME, 0.001, "volume padrao")
	assert_false(service.is_muted(), "o jogo nao comeca mudo")
	assert_false(service.has_stored_preferences(), "nada gravado ainda")


func test_increasing_volume_applies_to_the_audio_gateway_and_plays_navigate() -> void:
	var fx := _fixture()
	var service: OptionsService = fx["service"]
	var audio: SilentAudioGateway = fx["audio"]
	assert_true(service.increase_volume(), "um passo para cima e aceito")
	assert_almost_eq(service.volume(), 0.9, 0.001, "volume sobe um passo")
	assert_almost_eq(audio.master_volume, 0.9, 0.001, "o gateway de audio recebeu o volume")
	assert_eq(
		audio.sfx_calls,
		[AudioGateway.SFX_NAVIGATE],
		"o passo de volume faz o clique de navegacao"
	)


func test_volume_at_the_bounds_does_not_change_and_does_not_click() -> void:
	var fx := _fixture()
	var service: OptionsService = fx["service"]
	var audio: SilentAudioGateway = fx["audio"]
	service.set_volume_percent(100)
	audio.sfx_calls.clear()
	assert_false(service.increase_volume(), "no teto o passo para cima e recusado")
	assert_almost_eq(service.volume(), 1.0, 0.001)
	assert_eq(audio.sfx_calls, [], "pedido que nao muda nada nao faz som")
	service.set_volume_percent(0)
	assert_false(service.decrease_volume(), "no piso o passo para baixo e recusado")
	assert_almost_eq(service.volume(), 0.0, 0.001)
	assert_almost_eq(audio.master_volume, 0.0, 0.001, "volume zero chega no gateway")


func test_mute_toggle_applies_plays_select_and_persists() -> void:
	var fx := _fixture()
	var service: OptionsService = fx["service"]
	var persistence: InMemoryPersistenceGateway = fx["persistence"]
	var audio: SilentAudioGateway = fx["audio"]
	assert_true(service.toggle_mute(), "alternar o mudo e sempre aceito")
	assert_true(service.is_muted())
	assert_true(audio.muted, "o gateway de audio ficou mudo")
	assert_eq(audio.sfx_calls, [AudioGateway.SFX_SELECT], "alternar faz o som de selecao")
	assert_eq(persistence.load_value(KEY_MUTED, false), true, "mudo gravado")
	assert_true(service.toggle_mute(), "alternar de volta")
	assert_false(service.is_muted())
	assert_false(audio.muted)
	assert_eq(persistence.load_value(KEY_MUTED, true), false)


func test_preferences_survive_a_new_session() -> void:
	var fx := _fixture()
	var service: OptionsService = fx["service"]
	var persistence: InMemoryPersistenceGateway = fx["persistence"]
	service.set_volume_percent(30)
	service.toggle_mute()

	# Nova "sessao": outra instancia do caso de uso sobre o mesmo armazenamento.
	var restarted_audio := SilentAudioGateway.new()
	var restarted := OptionsService.new(persistence, restarted_audio)
	restarted.load_preferences()
	assert_true(restarted.has_stored_preferences(), "as duas chaves estao gravadas")
	assert_almost_eq(restarted.volume(), 0.3, 0.001, "volume restaurado")
	assert_true(restarted.is_muted(), "mudo restaurado")
	assert_almost_eq(
		restarted_audio.master_volume, 0.3, 0.001, "volume restaurado chega no audio"
	)
	assert_true(restarted_audio.muted, "mudo restaurado chega no audio")
	assert_eq(persistence.keys(), [KEY_VOLUME, KEY_MUTED], "as chaves sao as do contrato")


func test_stored_volume_out_of_range_is_clamped_on_load() -> void:
	var fx := _fixture()
	var persistence: InMemoryPersistenceGateway = fx["persistence"]
	persistence.save(KEY_VOLUME, 7.0)
	persistence.save(KEY_MUTED, true)
	var service := OptionsService.new(persistence, SilentAudioGateway.new())
	service.load_preferences()
	assert_almost_eq(service.volume(), 1.0, 0.001, "volume gravado fora da faixa e limitado")


func test_confirm_plays_select_without_changing_state() -> void:
	var fx := _fixture()
	var service: OptionsService = fx["service"]
	var audio: SilentAudioGateway = fx["audio"]
	var volume := service.volume()
	service.confirm()
	assert_eq(audio.sfx_calls, [AudioGateway.SFX_SELECT], "confirmar toca o som de selecao")
	assert_almost_eq(service.volume(), volume, 0.001, "confirmar nao muda o volume")
	assert_false(service.is_muted(), "confirmar nao muda o mudo")


func test_volume_percent_and_step_are_consistent() -> void:
	var fx := _fixture()
	var service: OptionsService = fx["service"]
	service.set_volume_percent(70)
	assert_eq(service.volume_percent(), 70, "percentual devolvido como pedido")
	assert_eq(service.volume_step(), 7, "sete passos de dez")