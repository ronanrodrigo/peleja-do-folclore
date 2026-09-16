class_name OptionsViewAdapter
extends RefCounted
## Traducao do estado das opcoes para a apresentacao.
##
## A copy do jogo e pt-BR e vive AQUI, na borda de apresentacao -- o
## `OptionsService` trabalha so com volume e mudo, sem texto. O modelo devolvido
## por `view_model` e o que a cena desenha: nenhuma regra de opcoes mora na cena.

const TITLE_TEXT := "OPÇÕES"
const VOLUME_LABEL := "VOLUME"
const MUTE_LABEL := "SOM"
const MUTE_ON_TEXT := "LIGADO"
const MUTE_OFF_TEXT := "MUDO"
const HINT_TEXT := "SETAS VOLUME  ENTER MUDO  ESC VOLTA"

## Chaves das linhas (ingles, como todo identificador do jogo).
const ROW_VOLUME := "volume"
const ROW_MUTE := "mute"


func title_text() -> String:
	return TITLE_TEXT


func hint_text() -> String:
	return HINT_TEXT


func mute_text(muted: bool) -> String:
	return MUTE_OFF_TEXT if muted else MUTE_ON_TEXT


func volume_text(percent: int) -> String:
	return "%d%%" % clampi(percent, 0, 100)


## Preenchimento da barra de volume, de 0.0 a 1.0.
func volume_ratio(percent: int) -> float:
	return clampf(float(percent) / 100.0, 0.0, 1.0)


## Preenchimento do indicador de mudo: cheio quando o som esta ligado.
func mute_ratio(muted: bool) -> float:
	return 0.0 if muted else 1.0


## Modelo de apresentacao das opcoes: titulo, duas linhas e a dica de teclas.
func view_model(volume_percent: int, muted: bool) -> Dictionary:
	return {
		"title": TITLE_TEXT,
		"hint": HINT_TEXT,
		"rows": [
			{
				"key": ROW_VOLUME,
				"label": VOLUME_LABEL,
				"value": volume_text(volume_percent),
				"bar": volume_ratio(volume_percent),
			},
			{
				"key": ROW_MUTE,
				"label": MUTE_LABEL,
				"value": mute_text(muted),
				"bar": mute_ratio(muted),
			},
		],
	}


## Todas as strings de apresentacao (usado por teste para conferir a fonte).
func copy_strings() -> Array:
	return [TITLE_TEXT, VOLUME_LABEL, MUTE_LABEL, MUTE_ON_TEXT, MUTE_OFF_TEXT, HINT_TEXT]