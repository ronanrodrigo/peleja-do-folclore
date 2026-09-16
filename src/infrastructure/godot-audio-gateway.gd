class_name GodotAudioGateway
extends AudioGateway
## Adapter de producao da capacidade "tocar som e musica".
##
## Toca os WAV sintetizados no proprio projeto (`assets/audio/`), em dois
## barramentos logicos: um `AudioStreamPlayer` para a musica (com loop) e um
## pequeno pool de vozes para os SFX, para que dois golpes no mesmo tick nao
## cortem um ao outro. O volume mestre e o mudo sao aplicados no barramento
## `Master` do `AudioServer`, nunca multiplicando amostra por amostra.
##
## Autoplay no navegador: o audio so comeca depois de um gesto do jogador
## (`notify_user_gesture`). Antes disso a ultima musica pedida fica guardada e
## toca no primeiro gesto -- o jogo nunca fica mudo por causa da politica de
## autoplay, e nenhum som e pedido antes de existir gesto.
##
## O adapter e instanciado apenas pelo composition root (`autoloads/app_container.gd`).
## Sem `mount()`, ele nao toca nada e serve apenas de observacao (testes headless).

const AUDIO_ROOT := "res://assets/audio"
const SFX_DIRECTORY := "sfx"
const MUSIC_DIRECTORY := "music"
const MASTER_BUS := "Master"
## Vozes simultaneas de SFX: um golpe pesado mais o dano no mesmo tick cabem.
const SFX_VOICES := 4
## Volume minimo em decibeis (0.0 em escala linear nao tem representacao em dB).
const MIN_VOLUME_DB := -80.0

## Arquivo de cada efeito do contrato, por capacidade -- nunca por nome de arquivo
## no chamador. O valor e o nome do WAV dentro de `assets/audio/sfx/`.
const SFX_FILES := {
	AudioGateway.SFX_IMPACT_LIGHT: "impact_light",
	AudioGateway.SFX_IMPACT_HEAVY: "impact_heavy",
	AudioGateway.SFX_SPECIAL: "special",
	AudioGateway.SFX_DAMAGE: "damage",
	AudioGateway.SFX_KNOCKOUT: "knockout",
	AudioGateway.SFX_SELECT: "select",
	AudioGateway.SFX_NAVIGATE: "navigate",
	AudioGateway.SFX_ROUND_END: "round_end",
}

## Arquivo de cada contexto musical do contrato.
const MUSIC_FILES := {
	AudioGateway.MUSIC_TITLE: "title",
	AudioGateway.MUSIC_SELECT: "select",
	AudioGateway.MUSIC_FIGHT: "fight",
	AudioGateway.MUSIC_REVIRAVOLTA: "reviravolta",
	AudioGateway.MUSIC_RESULT: "result",
}

var _host: Node = null
var _music_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _streams: Dictionary = {}
var _sfx_played: Array = []
var _music_requested: Array = []
var _current_music: String = ""
var _queued_music: String = ""
var _master_volume: float = 1.0
var _muted: bool = false
var _unlocked: bool = false


## Cria os players dentro do no hospedeiro. Idempotente: montar duas vezes nao
## duplica vozes nem reinicia a musica.
func mount(host: Node) -> void:
	if host == null or _host == host:
		return
	_host = host
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	host.add_child(_music_player)
	for index in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "SfxVoice%d" % index
		host.add_child(player)
		_sfx_players.append(player)
	_apply_mix()


func is_mounted() -> bool:
	return _host != null and is_instance_valid(_host)


func play_sfx(kind: String) -> void:
	if not SFX_FILES.has(kind):
		# Capacidade desconhecida nao vira som: o contrato e a lista fechada.
		return
	_sfx_played.append(kind)
	if not _can_play():
		return
	var stream := _load_stream(sfx_path(kind))
	if stream == null:
		return
	var player := _next_voice()
	player.stream = stream
	player.play()


func play_music(context: String) -> void:
	if not MUSIC_FILES.has(context):
		return
	_music_requested.append(context)
	if context == _current_music and _queued_music.is_empty():
		return
	_current_music = context
	if not _can_play():
		# Sem gesto do jogador (ou sem mount) a intencao fica guardada: no web o
		# navegador recusaria o play, e o jogo perderia a trilha.
		_queued_music = context
		return
	_start_music(context)


func stop_music() -> void:
	_current_music = ""
	_queued_music = ""
	if _music_player != null:
		_music_player.stop()


## Destrava a saida de audio e toca a musica que ficou esperando o gesto.
func notify_user_gesture() -> void:
	if _unlocked:
		return
	_unlocked = true
	var pending := _queued_music
	_queued_music = ""
	if not pending.is_empty():
		_start_music(pending)


func is_audio_unlocked() -> bool:
	return _unlocked


func set_master_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_apply_mix()


func set_mute(muted: bool) -> void:
	_muted = muted
	_apply_mix()


## Caminho do WAV de um efeito (vazio quando a capacidade nao existe).
func sfx_path(kind: String) -> String:
	if not SFX_FILES.has(kind):
		return ""
	return "%s/%s/%s.wav" % [AUDIO_ROOT, SFX_DIRECTORY, SFX_FILES[kind]]


## Caminho do WAV de um contexto musical (vazio quando o contexto nao existe).
func music_path(context: String) -> String:
	if not MUSIC_FILES.has(context):
		return ""
	return "%s/%s/%s.wav" % [AUDIO_ROOT, MUSIC_DIRECTORY, MUSIC_FILES[context]]


## Capacidades de SFX que o adapter sabe tocar (observavel por teste).
func known_sfx() -> Array:
	var kinds: Array = SFX_FILES.keys()
	kinds.sort()
	return kinds


## Contextos musicais que o adapter sabe tocar (observavel por teste).
func known_music() -> Array:
	var contexts: Array = MUSIC_FILES.keys()
	contexts.sort()
	return contexts


## Intencoes de SFX recebidas, na ordem -- inclusive as que nao tocaram.
func sfx_played() -> Array:
	return _sfx_played.duplicate()


## Intencoes musicais recebidas, na ordem.
func music_requested() -> Array:
	return _music_requested.duplicate()


## Contexto musical corrente (o ultimo pedido, tocando ou esperando gesto).
func current_music() -> String:
	return _current_music


## Contexto guardado esperando o gesto do jogador (vazio quando nao ha).
func queued_music() -> String:
	return _queued_music


func master_volume() -> float:
	return _master_volume


func is_muted() -> bool:
	return _muted


## Volume efetivo do barramento `Master`, em decibeis (observavel por teste).
func bus_volume_db() -> float:
	var index := AudioServer.get_bus_index(MASTER_BUS)
	if index < 0:
		return 0.0
	return AudioServer.get_bus_volume_db(index)


## Mudo efetivo do barramento `Master`.
func bus_muted() -> bool:
	var index := AudioServer.get_bus_index(MASTER_BUS)
	if index < 0:
		return false
	return AudioServer.is_bus_mute(index)


func _can_play() -> bool:
	return is_mounted() and _unlocked and _music_player != null


func _next_voice() -> AudioStreamPlayer:
	if _sfx_players.is_empty():
		return _music_player
	var player := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	return player


func _start_music(context: String) -> void:
	var stream := _load_stream(music_path(context))
	if stream == null or _music_player == null:
		return
	_make_looping(stream)
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()


## Musica em loop: a trilha continua tocando enquanto o contexto durar.
func _make_looping(stream: AudioStream) -> void:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return
	var frames := _frame_count(wav)
	if frames <= 0:
		return
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames


func _frame_count(wav: AudioStreamWAV) -> int:
	var bytes_per_sample := 1
	if wav.format == AudioStreamWAV.FORMAT_16_BITS:
		bytes_per_sample = 2
	var channels := 2 if wav.stereo else 1
	return wav.data.size() / (bytes_per_sample * channels)


## Carrega o stream do disco (ou do pacote exportado) uma unica vez por caminho.
func _load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if _streams.has(path):
		return _streams[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	elif FileAccess.file_exists(path):
		# Sem importacao (clone novo, por exemplo) o WAV e lido pelo proprio
		# adapter: o jogo nunca fica mudo por falta do `.import`.
		stream = _load_wav_from_disk(path)
	_streams[path] = stream
	return stream


func _load_wav_from_disk(path: String) -> AudioStream:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	wav.data = bytes
	return wav


## Aplica volume e mudo no barramento `Master`, uma vez por mudanca de estado.
func _apply_mix() -> void:
	var index := AudioServer.get_bus_index(MASTER_BUS)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, _muted)
	var db := linear_to_db(_master_volume) if _master_volume > 0.0 else MIN_VOLUME_DB
	AudioServer.set_bus_volume_db(index, maxf(db, MIN_VOLUME_DB))