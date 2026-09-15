class_name AudioGateway
extends RefCounted
## Contrato da capacidade "tocar som e musica".
##
## Uma capacidade, um arquivo. O audio no web exige gesto do usuario antes de
## tocar; o contrato nao decide isso, apenas descreve a capacidade.

## Efeito sonoro pontual, identificado por capacidade e nao por arquivo.
func play_sfx(_kind: String) -> void:
	pass


## Troca o contexto musical (titulo, luta, reviravolta, final).
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