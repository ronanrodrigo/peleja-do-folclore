class_name OptionsService
extends RefCounted
## Caso de uso "opcoes de audio": volume mestre e mudo, persistidos entre sessoes.
##
## Nao conhece cena, tecla nem arquivo: recebe os gateways por injecao (o
## composition root e o unico lugar que instancia adapters) e guarda o estado das
## preferencias aqui. Cada mudanca e aplicada no audio E gravada na persistencia
## na mesma chamada -- o jogador nunca perde o ajuste por fechar o jogo.
##
## Os efeitos de menu saem daqui (navegacao ao mexer no volume, selecao ao
## alternar o mudo) porque sao politica do caso de uso, nao da cena.

const KEY_MASTER_VOLUME := "audio.master_volume"
const KEY_MUTED := "audio.muted"

## Passos de volume: 0 (mudo) a VOLUME_STEPS (volume cheio).
const VOLUME_STEPS := 10
const DEFAULT_MASTER_VOLUME := 0.8
const DEFAULT_MUTED := false

var _persistence: PersistenceGateway
var _audio: AudioGateway
var _input: InputGateway
var _controls: ControlBindings
var _volume: float = DEFAULT_MASTER_VOLUME
var _muted: bool = DEFAULT_MUTED


func _init(
	p_persistence: PersistenceGateway,
	p_audio: AudioGateway,
	p_input: InputGateway = null
) -> void:
	_persistence = p_persistence
	_audio = p_audio
	_input = p_input
	_controls = ControlBindings.new(_persistence, _input)


## Restaura as preferencias gravadas (volume, mudo e remap) e aplica no audio. Sem
## nada gravado, valem os padroes (o jogo nunca comeca mudo nem no volume zero).
func load_preferences() -> void:
	_volume = clampf(
		float(_persistence.load_value(KEY_MASTER_VOLUME, DEFAULT_MASTER_VOLUME)), 0.0, 1.0
	)
	_muted = bool(_persistence.load_value(KEY_MUTED, DEFAULT_MUTED))
	_apply()
	_controls.load_bindings()


## Remap de controles do jogador (classe de apoio: acoes, teclas e o passo a passo
## do remap). O caso de uso so empresta a superficie que a tela precisa.
func controls() -> ControlBindings:
	return _controls


func volume() -> float:
	return _volume


func volume_percent() -> int:
	return roundi(_volume * 100.0)


## Passo atual de volume, de 0 a VOLUME_STEPS.
func volume_step() -> int:
	return roundi(_volume * float(VOLUME_STEPS))


func is_muted() -> bool:
	return _muted


func has_stored_preferences() -> bool:
	return _persistence.has(KEY_MASTER_VOLUME) and _persistence.has(KEY_MUTED)


## Sobe um passo de volume. Pedido no teto devolve falso e nao faz som.
func increase_volume() -> bool:
	return _set_step(volume_step() + 1)


## Desce um passo de volume. Pedido no piso devolve falso e nao faz som.
func decrease_volume() -> bool:
	return _set_step(volume_step() - 1)


## Move o volume direto para um percentual (0 a 100). Usado pela tela e pela
## ferramenta de evidencia; tambem grava e faz o som de navegacao.
func set_volume_percent(percent: int) -> bool:
	return _set_step(roundi(clampf(float(percent), 0.0, 100.0) / 100.0 * float(VOLUME_STEPS)))


## Alterna o mudo: sempre acao aceita (e o som de selecao).
func toggle_mute() -> bool:
	_muted = not _muted
	_apply()
	_persist()
	_select_sfx()
	return true


## Confirmacao do menu (o som de selecao sem mudar estado).
func confirm() -> void:
	_select_sfx()


func _set_step(step: int) -> bool:
	var clamped := clampi(step, 0, VOLUME_STEPS)
	var next := float(clamped) / float(VOLUME_STEPS)
	if is_equal_approx(next, _volume):
		return false
	_volume = next
	_apply()
	_persist()
	# Navegacao de menu: mexer no volume faz um clique curto por passo.
	_audio.play_sfx(AudioGateway.SFX_NAVIGATE)
	return true


func _select_sfx() -> void:
	_audio.play_sfx(AudioGateway.SFX_SELECT)


func _apply() -> void:
	_audio.set_master_volume(_volume)
	_audio.set_mute(_muted)


func _persist() -> void:
	_persistence.save(KEY_MASTER_VOLUME, _volume)
	_persistence.save(KEY_MUTED, _muted)