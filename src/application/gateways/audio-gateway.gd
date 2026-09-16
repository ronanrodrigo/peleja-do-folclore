class_name AudioGateway
extends RefCounted
## Contrato da capacidade "tocar som e musica".
##
## Uma capacidade, um arquivo. O audio no web exige gesto do usuario antes de
## tocar; o contrato nao decide isso, apenas descreve a capacidade -- quem
## implementa e quem decide onde a porta destrava.
##
## Os nomes de efeito e de contexto musical descrevem a CAPACIDADE, nunca o
## arquivo nem o formato: trocar a sintese por outra nao muda esta lista.

## Efeito sonoro pontual, identificado por capacidade e nao por arquivo.
const SFX_IMPACT_LIGHT := "impact_light"
const SFX_IMPACT_HEAVY := "impact_heavy"
const SFX_SPECIAL := "special"
const SFX_DAMAGE := "damage"
const SFX_KNOCKOUT := "knockout"
const SFX_SELECT := "select"
const SFX_NAVIGATE := "navigate"
const SFX_ROUND_END := "round_end"

## Todos os efeitos que o jogo pede. Pedido fora desta lista e ignorado.
const SFX_KINDS: Array[String] = [
	SFX_IMPACT_LIGHT,
	SFX_IMPACT_HEAVY,
	SFX_SPECIAL,
	SFX_DAMAGE,
	SFX_KNOCKOUT,
	SFX_SELECT,
	SFX_NAVIGATE,
	SFX_ROUND_END,
]

## Contexto musical: a musica toca por momento do jogo, nao por cena.
const MUSIC_TITLE := "title"
const MUSIC_SELECT := "select"
const MUSIC_FIGHT := "fight"
const MUSIC_REVIRAVOLTA := "reviravolta"
const MUSIC_RESULT := "result"

## Todos os contextos musicais. Contexto fora desta lista e ignorado.
const MUSIC_CONTEXTS: Array[String] = [
	MUSIC_TITLE,
	MUSIC_SELECT,
	MUSIC_FIGHT,
	MUSIC_REVIRAVOLTA,
	MUSIC_RESULT,
]


## Toca um efeito sonoro pontual (`SFX_*`).
func play_sfx(_kind: String) -> void:
	pass


## Troca o contexto musical (`MUSIC_*`).
func play_music(_context: String) -> void:
	pass


## Para a musica em execucao.
func stop_music() -> void:
	pass


## Volume mestre normalizado em [0, 1].
func set_master_volume(_value: float) -> void:
	pass


## Liga/desliga todo o audio.
func set_mute(_muted: bool) -> void:
	pass


## Declara que o jogador interagiu com a pagina/janela.
##
## No navegador o audio so pode comecar depois de um gesto do usuario (politica
## de autoplay): antes disso a implementacao de producao apenas guarda a ultima
## musica pedida e a toca quando o gesto chega. Nao ha gesto em ambiente headless
## nem em teste -- o adapter `sample` nao toca nada de qualquer forma.
func notify_user_gesture() -> void:
	pass


## Verdadeiro quando um gesto do jogador ja destravou a saida de audio.
func is_audio_unlocked() -> bool:
	return false
