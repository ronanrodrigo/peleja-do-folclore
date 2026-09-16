extends GutTest
## Adapter de producao da capacidade "tocar som e musica".
##
## Prova o que o contrato promete: cada capacidade fechada tem exatamente um
## arquivo sintetizado no projeto, capacidade desconhecida nao vira som, o mudo e
## o volume chegam no barramento `Master`, e nada toca antes do gesto do jogador
## (politica de autoplay do navegador).

var _host: Node
var _gateway: GodotAudioGateway


func before_each() -> void:
	_host = Node.new()
	_host.name = "audio_host"
	add_child_autofree(_host)
	_gateway = GodotAudioGateway.new()
	_gateway.mount(_host)


func after_each() -> void:
	# Devolve o barramento ao estado de fabrica: o proximo teste nao herda mudo.
	var index := AudioServer.get_bus_index(GodotAudioGateway.MASTER_BUS)
	if index >= 0:
		AudioServer.set_bus_mute(index, false)
		AudioServer.set_bus_volume_db(index, 0.0)


func test_every_sfx_of_the_contract_has_an_audio_file_in_the_project() -> void:
	assert_eq(
		_sorted(GodotAudioGateway.SFX_FILES.keys()),
		_sorted(AudioGateway.SFX_KINDS),
		"SFX_FILES cobre o contrato"
	)
	for kind in AudioGateway.SFX_KINDS:
		var path := _gateway.sfx_path(kind)
		assert_true(path.begins_with("res://assets/audio/sfx/"), "caminho do projeto: %s" % path)
		assert_true(
			ResourceLoader.exists(path),
			"o WAV do efeito %s foi importado" % kind
		)


func test_every_music_context_of_the_contract_has_an_audio_file_in_the_project() -> void:
	assert_eq(
		_sorted(GodotAudioGateway.MUSIC_FILES.keys()),
		_sorted(AudioGateway.MUSIC_CONTEXTS),
		"MUSIC_FILES cobre o contrato"
	)
	for context in AudioGateway.MUSIC_CONTEXTS:
		var path := _gateway.music_path(context)
		assert_true(
			path.begins_with("res://assets/audio/music/"), "caminho do projeto: %s" % path
		)
		assert_true(
			ResourceLoader.exists(path), "o WAV da trilha %s foi importado" % context
		)


func test_music_streams_are_looping_wav_with_samples() -> void:
	for context in AudioGateway.MUSIC_CONTEXTS:
		var stream: Variant = load(_gateway.music_path(context))
		assert_true(stream is AudioStreamWAV, "%s e um WAV carregado" % context)
		assert_gt(stream.data.size(), 1000, "%s tem amostras (nao e arquivo vazio)" % context)


func test_unknown_sfx_and_music_are_ignored() -> void:
	_gateway.play_sfx("nao_existe")
	_gateway.play_music("nao_existe")
	assert_eq(_gateway.sfx_played(), [], "SFX fora do contrato nao vira intencao")
	assert_eq(_gateway.music_requested(), [], "contexto fora do contrato nao vira intencao")
	assert_eq(_gateway.sfx_path("nao_existe"), "", "sem capacidade, sem caminho")
	assert_eq(_gateway.music_path("nao_existe"), "")


func test_audio_stays_locked_until_the_player_gesture() -> void:
	assert_false(_gateway.is_audio_unlocked(), "audio comeca travado")
	_gateway.play_music(AudioGateway.MUSIC_TITLE)
	assert_eq(_gateway.current_music(), AudioGateway.MUSIC_TITLE, "a intencao e registrada")
	assert_eq(
		_gateway.queued_music(),
		AudioGateway.MUSIC_TITLE,
		"sem gesto a trilha fica guardada (o navegador recusaria o play)"
	)
	_gateway.notify_user_gesture()
	assert_true(_gateway.is_audio_unlocked(), "o gesto destrava a saida")
	assert_eq(_gateway.queued_music(), "", "a fila esvazia no gesto")
	var music: AudioStreamPlayer = _host.get_node_or_null("MusicPlayer")
	assert_not_null(music, "o player da musica foi montado no hospedeiro")
	assert_not_null(music.stream, "a trilha guardada comeca a tocar no gesto")
	assert_true(music.playing, "o player esta tocando")


func test_sfx_only_reach_a_voice_after_the_gesture() -> void:
	_gateway.play_sfx(AudioGateway.SFX_SELECT)
	assert_eq(
		int(_gateway.voice_state()["loaded"]),
		0,
		"sem gesto nenhum stream e carregado (nada de som)"
	)
	assert_eq(_gateway.sfx_played(), [AudioGateway.SFX_SELECT], "a intencao fica registrada")
	_gateway.notify_user_gesture()
	_gateway.play_sfx(AudioGateway.SFX_SELECT)
	assert_eq(int(_gateway.voice_state()["loaded"]), 1, "com gesto o efeito ocupa uma voz")
	assert_gt(int(_gateway.voice_state()["voices"]), 1, "ha mais de uma voz para golpes simultaneos")


func test_music_does_not_restart_on_the_same_context() -> void:
	_gateway.notify_user_gesture()
	_gateway.play_music(AudioGateway.MUSIC_FIGHT)
	var music: AudioStreamPlayer = _host.get_node_or_null("MusicPlayer")
	var stream: AudioStream = music.stream
	_gateway.play_music(AudioGateway.MUSIC_FIGHT)
	assert_eq(music.stream, stream, "repetir o contexto nao recarrega a trilha")


func test_music_switches_context_and_stops() -> void:
	_gateway.notify_user_gesture()
	_gateway.play_music(AudioGateway.MUSIC_FIGHT)
	_gateway.play_music(AudioGateway.MUSIC_REVIRAVOLTA)
	assert_eq(_gateway.current_music(), AudioGateway.MUSIC_REVIRAVOLTA, "troca de contexto")
	assert_eq(
		_gateway.music_requested(),
		[AudioGateway.MUSIC_FIGHT, AudioGateway.MUSIC_REVIRAVOLTA],
		"a ordem dos contextos pedidos fica registrada"
	)
	_gateway.stop_music()
	assert_eq(_gateway.current_music(), "", "parar limpa o contexto corrente")


func test_volume_and_mute_reach_the_master_bus() -> void:
	_gateway.set_master_volume(0.5)
	assert_almost_eq(
		float(_gateway.bus_state()["volume_db"]),
		linear_to_db(0.5),
		0.01,
		"volume aplicado no barramento"
	)
	assert_almost_eq(_gateway.master_volume(), 0.5, 0.001)
	assert_false(bool(_gateway.bus_state()["muted"]), "sem mudo por padrao")
	_gateway.set_mute(true)
	assert_true(bool(_gateway.bus_state()["muted"]), "mudo aplicado no barramento")
	assert_true(_gateway.is_muted())
	_gateway.set_mute(false)
	assert_false(bool(_gateway.bus_state()["muted"]))
	assert_false(_gateway.is_muted())


func test_volume_is_clamped_and_zero_does_not_break_the_bus() -> void:
	_gateway.set_master_volume(4.0)
	assert_almost_eq(_gateway.master_volume(), 1.0, 0.001, "volume acima de 1 e limitado")
	_gateway.set_master_volume(-3.0)
	assert_almost_eq(_gateway.master_volume(), 0.0, 0.001, "volume negativo e limitado a 0")
	assert_almost_eq(
		float(_gateway.bus_state()["volume_db"]),
		GodotAudioGateway.MIN_VOLUME_DB,
		0.01,
		"0.0 tem dB finito"
	)


func test_mount_is_idempotent() -> void:
	var children := _host.get_child_count()
	_gateway.mount(_host)
	assert_eq(_host.get_child_count(), children, "montar de novo nao duplica players")
	assert_true(_gateway.is_mounted(), "o adapter continua montado")


func _sorted(values: Array) -> Array:
	var copy: Array = values.duplicate()
	copy.sort()
	return copy