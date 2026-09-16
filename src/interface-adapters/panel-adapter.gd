class_name PanelAdapter
extends RefCounted
## Copy pt-BR e modelo de apresentacao do painel da Reviravolta (ADR 0003).
##
## A cena de Reviravolta nao tem interacao: a Forca Sobrenatural (a mata, o
## Brasil profundo) fala em uma sequencia de linhas e dissolve o Oponente. Este
## adapter guarda o que e COPY e o que e POSICAO -- nunca regra: quando a cena
## dispara, quanto dura e como termina e `ReviravoltaRule`, no dominio.
##
## Tudo em pt-BR, em caixa alta, desenhado pela fonte bitmap 5x7 na resolucao
## base 426x240, em escala inteira.

const BASE_SIZE := Vector2i(426, 240)

const TITLE_TEXT := "REVIRAVOLTA"
## Nome da entidade que resolve a Peleja: a mata / o Brasil profundo.
const FORCE_TEXT := "FORÇA SOBRENATURAL"
## As falas da Forca Sobrenatural, na ordem em que a cena mostra. Voz, vento e
## raiz em quatro linhas curtas: a cena nao pede leitura, pede assombro.
const LINES: Array[String] = [
	"A MATA RESPONDE.",
	"O VENTO ARRANCA O PODER.",
	"A RAIZ SEGURA O OPONENTE.",
	"O BRASIL PROFUNDO O DISSOLVE.",
]
## Opcao de pular: a cena nunca prende quem ja entendeu (regra em
## `ReviravoltaRule.can_skip()`).
const SKIP_HINT := "ESPAÇO PULA A CENA"

const TITLE_SCALE := 3
const FORCE_SCALE := 2
const LINE_SCALE := 2
const HINT_SCALE := 1

const TITLE_Y := 16
const FORCE_Y := 44
## Faixa escura semitransparente para a fala ficar legivel sobre a arte.
const BAND_RECT := Rect2i(23, 116, 380, 62)
const LINE_Y := 139
const HINT_Y := 214

const COLOR_TITLE := Color8(255, 211, 92)
const COLOR_FORCE := Color8(143, 224, 208)
const COLOR_LINE := Color8(240, 240, 255)
const COLOR_HINT := Color8(150, 150, 190)
const COLOR_BAND := Color8(6, 10, 18, 0.72)
const COLOR_BORDER := Color8(255, 211, 92)


## As falas da cena (copia da lista: o chamador nao mexe no dado do adapter).
func lines() -> Array:
	return LINES.duplicate()


func line_count() -> int:
	return LINES.size()


## Fala de uma linha; fora da sequencia devolve vazio (nunca a ultima por engano).
func line_text(index: int) -> String:
	if index < 0 or index >= LINES.size():
		return ""
	return LINES[index]


func title_text() -> String:
	return TITLE_TEXT


func force_text() -> String:
	return FORCE_TEXT


func skip_hint() -> String:
	return SKIP_HINT


## Modelo de apresentacao da cena no instante pedido: titulo, nome da Forca, a
## fala corrente e o comando de pular, tudo ja posicionado na resolucao base.
## `line_index` negativo (voz terminada) mostra a ultima fala em vez de nada.
func view_model(line_index: int) -> Dictionary:
	var shown := clampi(line_index, 0, LINES.size() - 1)
	return {
		"line_count": LINES.size(),
		"line_index": line_index,
		"title_text": TITLE_TEXT,
		"title_position": centered(TITLE_TEXT, TITLE_SCALE, 0, BASE_SIZE.x, TITLE_Y),
		"title_scale": TITLE_SCALE,
		"title_color": COLOR_TITLE,
		"force_text": FORCE_TEXT,
		"force_position": centered(FORCE_TEXT, FORCE_SCALE, 0, BASE_SIZE.x, FORCE_Y),
		"force_scale": FORCE_SCALE,
		"force_color": COLOR_FORCE,
		"line_text": LINES[shown],
		"line_position": centered(LINES[shown], LINE_SCALE, 0, BASE_SIZE.x, LINE_Y),
		"line_scale": LINE_SCALE,
		"line_color": COLOR_LINE,
		"band_rect": BAND_RECT,
		"band_color": COLOR_BAND,
		"border_color": COLOR_BORDER,
		"hint_text": SKIP_HINT,
		"hint_position": centered(SKIP_HINT, HINT_SCALE, 0, BASE_SIZE.x, HINT_Y),
		"hint_scale": HINT_SCALE,
		"hint_color": COLOR_HINT,
	}


## Posicao que centraliza um texto (fonte bitmap 5x7) numa faixa horizontal.
static func centered(
	text: String, pixel_scale: int, left: int, width: int, y: int
) -> Vector2i:
	var text_width := BitmapFont.text_width(text) * pixel_scale
	return Vector2i(left + (width - text_width) / 2, y)
