class_name SilentAudioGateway
extends AudioGateway
## Adapter de audio deterministico usado em testes.
##
## No-op silencioso: nao produz som e nao toca no servidor de audio do engine.
## Apenas registra a ultima intencao para que o teste possa observa-la. Zero I/O:
## nenhum arquivo, nenhum diretorio, nenhuma rede, nenhum provedor de recurso.

var sfx_calls: Array = []
var music_calls: Array = []
var master_volume: float = 1.0
var muted: bool = false
## Quantos gestos do jogador foram declarados (o jogo destrava o audio com um).
var gesture_count: int = 0
var unlocked: bool = false


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


func notify_user_gesture() -> void:
	gesture_count += 1
	unlocked = true


func is_audio_unlocked() -> bool:
	return unlocked


## Ultimo contexto musical pedido (vazio enquanto nenhum foi pedido).
func last_music() -> String:
	return music_calls[-1] if not music_calls.is_empty() else ""