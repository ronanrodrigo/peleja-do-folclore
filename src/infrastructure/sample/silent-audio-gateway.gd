class_name SilentAudioGateway
extends AudioGateway
## Adapter de audio deterministico usado em testes.
##
## No-op silencioso: nao produz som e nao toca no servidor de audio do engine.
## Apenas registra a ultima intencao para que o teste possa observa-la.

var sfx_calls: Array = []
var music_calls: Array = []
var master_volume: float = 1.0
var muted: bool = false


func play_sfx(kind: String) -> void:
	sfx_calls.append(kind)


func play_music(context: String) -> void:
	music_calls.append(context)


func stop_music() -> void:
	music_calls.clear()


func set_master_volume(value: float) -> void:
	master_volume = value


func set_mute(value: bool) -> void:
	muted = value