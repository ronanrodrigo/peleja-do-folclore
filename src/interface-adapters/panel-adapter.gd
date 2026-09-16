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
## Folga em volta do texto dentro de uma faixa escura.
const BAND_PADDING := 3
const LINE_Y := 139
const HINT_Y := 214

const COLOR_TITLE := Color8(255, 211, 92)
const COLOR_FORCE := Color8(143, 224, 208)
const COLOR_LINE := Color8(240, 240, 255)
const COLOR_HINT := Color8(150, 150, 190)
## Faixa escura semitransparente: nao e `Color8` porque a faixa tem alfa. O alfa
## subiu no polimento do ticket 10: o titulo e o nome da Forca ficavam com baixo
## contraste sobre a arte de painel (fundo claro em alguns quadros).
const COLOR_BAND := Color(6.0 / 255.0, 10.0 / 255.0, 18.0 / 255.0, 0.82)
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
	# `line_index` negativo significa voz terminada (o efeito da Forca esta na
	# tela): a ultima fala fica, em vez de a cena ficar muda.
	var shown := LINES.size() - 1
	if line_index >= 0:
		shown = clampi(line_index, 0, LINES.size() - 1)
	var hint_position := centered(SKIP_HINT, HINT_SCALE, 0, BASE_SIZE.x, HINT_Y)
	var title_position := centered(TITLE_TEXT, TITLE_SCALE, 0, BASE_SIZE.x, TITLE_Y)
	var force_position := centered(FORCE_TEXT, FORCE_SCALE, 0, BASE_SIZE.x, FORCE_Y)
	return {
		"line_count": LINES.size(),
		"line_index": line_index,
		"title_text": TITLE_TEXT,
		"title_position": title_position,
		"title_scale": TITLE_SCALE,
		"title_color": COLOR_TITLE,
		"force_text": FORCE_TEXT,
		"force_position": force_position,
		"force_scale": FORCE_SCALE,
		"force_color": COLOR_FORCE,
		"line_text": LINES[shown],
		"line_position": centered(LINES[shown], LINE_SCALE, 0, BASE_SIZE.x, LINE_Y),
		"line_scale": LINE_SCALE,
		"line_color": COLOR_LINE,
		"band_rect": BAND_RECT,
		"band_color": COLOR_BAND,
		"border_color": COLOR_BORDER,
		## Titulo e nome da Forca tambem ganham faixa escura: sobre a arte clara
		## eles ficavam ilegiveis (nit de contraste do ticket 10).
		"title_band_rect": band_around(title_position, TITLE_TEXT, TITLE_SCALE),
		"title_band_color": COLOR_BAND,
		"force_band_rect": band_around(force_position, FORCE_TEXT, FORCE_SCALE),
		"force_band_color": COLOR_BAND,
		"hint_text": SKIP_HINT,
		"hint_position": hint_position,
		"hint_scale": HINT_SCALE,
		"hint_color": COLOR_HINT,
		## Faixa propria do comando de pular: a copy fica legivel sobre a arte.
		"hint_band_rect": band_around(hint_position, SKIP_HINT, HINT_SCALE),
		"hint_band_color": COLOR_BAND,
	}


## Faixa escura com folga em volta de um texto ja posicionado.
static func band_around(position: Vector2i, text: String, pixel_scale: int) -> Rect2i:
	var width := BitmapFont.text_width(text) * pixel_scale
	var height := BitmapFont.GLYPH_HEIGHT * pixel_scale
	return Rect2i(
		position.x - BAND_PADDING,
		position.y - BAND_PADDING,
		width + BAND_PADDING * 2,
		height + BAND_PADDING * 2
	)


## Posicao que centraliza um texto (fonte bitmap 5x7) numa faixa horizontal.
static func centered(
	text: String, pixel_scale: int, left: int, width: int, y: int
) -> Vector2i:
	var text_width := BitmapFont.text_width(text) * pixel_scale
	return Vector2i(left + (width - text_width) / 2, y)
