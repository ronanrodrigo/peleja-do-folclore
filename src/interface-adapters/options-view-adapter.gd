class_name OptionsViewAdapter
extends RefCounted
## Traducao do estado das opcoes para a apresentacao.
##
## A copy do jogo e pt-BR e vive AQUI, na borda de apresentacao -- o
## `OptionsService` trabalha so com volume, mudo e codigos de tecla, sem texto. O
## modelo devolvido por `view_model` e o que a cena desenha: nenhuma regra de
## opcoes mora na cena.
##
## O rodape e uma dica CURTA, desenhada dentro da largura do painel: a copy longa
## de teclas encostava na borda direita da tela (polimento do ticket 10).

const TITLE_TEXT := "OPÇÕES"
const VOLUME_LABEL := "VOLUME"
const MUTE_LABEL := "SOM"
const MUTE_ON_TEXT := "LIGADO"
const MUTE_OFF_TEXT := "MUDO"
const HINT_TEXT := "SETAS VOLUME  ENTER MUDO  ESC VOLTA"
const CONTROLS_LABEL := "CONTROLES"
const CONTROLS_DEFAULT_TEXT := "PADRÃO"
const CONTROLS_CUSTOM_TEXT := "AJUSTADO"
const REMAP_HINT := "PRESSIONE UMA TECLA"
const REMAP_DONE_TEXT := "REMAPEADO"

## Chaves das linhas (ingles, como todo identificador do jogo).
const ROW_VOLUME := "volume"
const ROW_MUTE := "mute"
const ROW_CONTROLS := "controls"

## Nome pt-BR de cada acao remapeavel (`InputGateway` fala em ingles).
const ACTION_LABELS := {
	"move_left": "ESQUERDA",
	"move_right": "DIREITA",
	"crouch": "AGACHAR",
	"block": "DEFENDER",
	"light": "LEVE",
	"heavy": "PESADO",
	"grab": "AGARRÃO",
	"special": "ESPECIAL",
}

## Rotulo das teclas que nao tem glifo imprimivel proprio.
const SPECIAL_KEY_LABELS := {
	KEY_ESCAPE: "ESC",
	KEY_TAB: "TAB",
	KEY_BACKSPACE: "BKSP",
	KEY_ENTER: "ENTER",
	KEY_KP_ENTER: "ENTER",
	KEY_SHIFT: "SHIFT",
	KEY_LEFT: "ESQ",
	KEY_UP: "CIMA",
	KEY_RIGHT: "DIR",
	KEY_DOWN: "BAIXO",
	KEY_SPACE: "ESPAÇO",
}
const ASCII_PRINTABLE_MIN := 33
const ASCII_PRINTABLE_MAX := 126


func title_text() -> String:
	return TITLE_TEXT


func hint_text() -> String:
	return HINT_TEXT


func mute_text(muted: bool) -> String:
	return MUTE_OFF_TEXT if muted else MUTE_ON_TEXT


func controls_text(custom: bool) -> String:
	return CONTROLS_CUSTOM_TEXT if custom else CONTROLS_DEFAULT_TEXT


func volume_text(percent: int) -> String:
	return "%d%%" % clampi(percent, 0, 100)


## Preenchimento da barra de volume, de 0.0 a 1.0.
func volume_ratio(percent: int) -> float:
	return clampf(float(percent) / 100.0, 0.0, 1.0)


## Preenchimento do indicador de mudo: cheio quando o som esta ligado.
func mute_ratio(muted: bool) -> float:
	return 0.0 if muted else 1.0


## Preenchimento do indicador de controles: cheio quando o remap foi ajustado.
func controls_ratio(custom: bool) -> float:
	return 1.0 if custom else 0.0


## Nome pt-BR de uma acao remapeavel; acao desconhecida cai no proprio nome.
func action_label(action: String) -> String:
	return str(ACTION_LABELS.get(action, action.to_upper()))


## Tecla como o jogador le o mapa ("A", "DIR", "ESC", "ESPAÇO").
func key_label(keycode: int) -> String:
	if SPECIAL_KEY_LABELS.has(keycode):
		return str(SPECIAL_KEY_LABELS[keycode])
	if keycode >= ASCII_PRINTABLE_MIN and keycode <= ASCII_PRINTABLE_MAX:
		return char(keycode).to_upper()
	return "-"


## Linha do remap em curso: a acao e a tecla que ela tem agora.
func remap_text(action: String, keycode: int) -> String:
	return "%s: %s" % [action_label(action), key_label(keycode)]


## Dica do rodape: muda enquanto o remap esta em curso.
func hint_for(remapping: bool) -> String:
	return REMAP_HINT if remapping else HINT_TEXT


## Modelo de apresentacao das opcoes: titulo, tres linhas e a dica de teclas.
func view_model(
	volume_percent: int, muted: bool, controls_custom: bool = false
) -> Dictionary:
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
			{
				"key": ROW_CONTROLS,
				"label": CONTROLS_LABEL,
				"value": controls_text(controls_custom),
				"bar": controls_ratio(controls_custom),
			},
		],
	}


## Todas as strings de apresentacao (usado por teste para conferir a fonte).
func copy_strings() -> Array:
	var texts: Array = [
		TITLE_TEXT,
		VOLUME_LABEL,
		MUTE_LABEL,
		MUTE_ON_TEXT,
		MUTE_OFF_TEXT,
		HINT_TEXT,
		CONTROLS_LABEL,
		CONTROLS_DEFAULT_TEXT,
		CONTROLS_CUSTOM_TEXT,
		REMAP_HINT,
		REMAP_DONE_TEXT,
	]
	for label in ACTION_LABELS.values():
		texts.append(str(label))
	for label in SPECIAL_KEY_LABELS.values():
		texts.append(str(label))
	return texts
