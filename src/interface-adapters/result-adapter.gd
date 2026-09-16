class_name ResultAdapter
extends RefCounted
## Copy pt-BR e modelo de apresentacao das telas de fim (ticket 10): vitoria,
## derrota e fim de arcade.
##
## O adapter so guarda o que e COPY e o que e POSICAO -- nunca regra. Quem decide
## se a Peleja foi vencida, se a campanha segue e se o arcade acabou e o dominio
## (`MatchRules`, `ReviravoltaRule`) via `GameFlowService`. Nada aqui revela a
## Vantagem Oculta (ADR 0003): nao existe vida, dano nem vantagem nesta copy.
##
## Tudo em pt-BR, desenhado pela fonte bitmap 5x7 na resolucao base 426x240, em
## escala inteira.

const BASE_SIZE := Vector2i(426, 240)

## Tipos de tela de fim.
const KIND_VICTORY := "victory"
const KIND_DEFEAT := "defeat"
const KIND_ARCADE_END := "arcade_end"

const VICTORY_TITLE := "VITÓRIA"
const DEFEAT_TITLE := "DERROTA"
const ARCADE_END_TITLE := "ARCADE COMPLETO"

const VICTORY_LINE := "VOCÊ VENCEU A PELEJA"
const DEFEAT_LINE_ONE := "A FORÇA SOBRENATURAL VENCEU"
const DEFEAT_LINE_TWO := "A CAMPANHA CONTINUA"
const ARCADE_END_LINE := "AS SETE PELEJAS FORAM JOGADAS"
const ARCADE_END_LINE_TWO := "A MATA AGRADECE"
const CONTINUE_HINT := "ENTER CONTINUA"
const TITLE_HINT := "ENTER VOLTA AO TÍTULO"

const TITLE_SCALE := 3
const LINE_SCALE := 2
const HINT_SCALE := 1
const TITLE_Y := 42
const FIRST_LINE_Y := 92
const LINE_HEIGHT := 22
const HINT_Y := 208
const BAND_RECT := Rect2i(16, 28, 394, 158)
const BAND_PADDING := 3
const BAR_RECT := Rect2i(63, 176, 300, 6)

const COLOR_BACKGROUND := Color8(10, 10, 28)
const COLOR_TITLE_VICTORY := Color8(255, 211, 92)
const COLOR_TITLE_DEFEAT := Color8(190, 190, 210)
const COLOR_TITLE_ARCADE := Color8(143, 224, 208)
const COLOR_LINE := Color8(240, 240, 255)
const COLOR_HINT := Color8(150, 150, 190)
const COLOR_BAR_BACK := Color8(42, 42, 64)
const COLOR_BAR_FILL := Color8(120, 220, 120)
const COLOR_BORDER := Color8(255, 211, 92)
const COLOR_BAND := Color(6.0 / 255.0, 10.0 / 255.0, 18.0 / 255.0, 0.82)


## Titulo da tela de um tipo de fim.
func title_for(kind: String) -> String:
	match kind:
		KIND_DEFEAT:
			return DEFEAT_TITLE
		KIND_ARCADE_END:
			return ARCADE_END_TITLE
		_:
			return VICTORY_TITLE


## Cor do titulo por tipo (vitoria em amarelo, derrota em cinza frio, arcade em
## verde da mata).
func title_color_for(kind: String) -> Color:
	match kind:
		KIND_DEFEAT:
			return COLOR_TITLE_DEFEAT
		KIND_ARCADE_END:
			return COLOR_TITLE_ARCADE
		_:
			return COLOR_TITLE_VICTORY


## Dica do rodape: as telas de Peleja continuam a campanha; o fim do arcade
## devolve ao titulo.
func hint_for(kind: String) -> String:
	return TITLE_HINT if kind == KIND_ARCADE_END else CONTINUE_HINT


## Linhas de apoio da tela, ja em pt-BR e na ordem de leitura.
func lines_for(kind: String, summary: Dictionary) -> Array:
	var progress := "PELEJA %d DE %d" % [
		int(summary.get("fight", 0)), int(summary.get("fights", 0))
	]
	var rounds := "ROUNDS %d A %d" % [
		int(summary.get("guardian_rounds", 0)), int(summary.get("opponent_rounds", 0))
	]
	match kind:
		KIND_DEFEAT:
			return [DEFEAT_LINE_ONE, DEFEAT_LINE_TWO, progress]
		KIND_ARCADE_END:
			return [ARCADE_END_LINE, ARCADE_END_LINE_TWO, progress, rounds]
		_:
			return [VICTORY_LINE, progress, rounds]


## Modelo de apresentacao de uma tela de fim: titulo, linhas e dica, tudo ja
## posicionado na resolucao base, mais a barra de progresso do arcade.
func model_for(kind: String, summary: Dictionary) -> Dictionary:
	var title := title_for(kind)
	var lines: Array = []
	var line_texts := lines_for(kind, summary)
	for index in line_texts.size():
		var text := str(line_texts[index])
		lines.append({
			"text": text,
			"position": centered(text, LINE_SCALE, 0, BASE_SIZE.x, FIRST_LINE_Y + index * LINE_HEIGHT),
			"scale": LINE_SCALE,
			"color": COLOR_LINE,
		})
	var hint := hint_for(kind)
	return {
		"kind": kind,
		"background": COLOR_BACKGROUND,
		"band_rect": BAND_RECT,
		"band_color": COLOR_BAND,
		"border_color": COLOR_BORDER,
		"title": title,
		"title_position": centered(title, TITLE_SCALE, 0, BASE_SIZE.x, TITLE_Y),
		"title_scale": TITLE_SCALE,
		"title_color": title_color_for(kind),
		"title_band_rect": band_around(
			centered(title, TITLE_SCALE, 0, BASE_SIZE.x, TITLE_Y), title, TITLE_SCALE
		),
		"title_band_color": COLOR_BAND,
		"lines": lines,
		"progress": progress_ratio(summary),
		"bar_back_rect": BAR_RECT,
		"bar_fill_rect": bar_fill_rect(summary),
		"bar_back_color": COLOR_BAR_BACK,
		"bar_fill_color": COLOR_BAR_FILL,
		"hint": hint,
		"hint_position": centered(hint, HINT_SCALE, 0, BASE_SIZE.x, HINT_Y),
		"hint_scale": HINT_SCALE,
		"hint_color": COLOR_HINT,
		"hint_band_rect": band_around(
			centered(hint, HINT_SCALE, 0, BASE_SIZE.x, HINT_Y), hint, HINT_SCALE
		),
		"hint_band_color": COLOR_BAND,
	}


## Quanto do arcade ja foi jogado (0 a 1).
func progress_ratio(summary: Dictionary) -> float:
	var fights := int(summary.get("fights", 0))
	if fights <= 0:
		return 0.0
	return clampf(float(summary.get("fight", 0)) / float(fights), 0.0, 1.0)


func bar_fill_rect(summary: Dictionary) -> Rect2i:
	var filled := roundi(BAR_RECT.size.x * progress_ratio(summary))
	return Rect2i(BAR_RECT.position, Vector2i(filled, BAR_RECT.size.y))


## Modelo de vitoria (a Peleja foi vencida pelo Guardiao).
func victory_model(summary: Dictionary) -> Dictionary:
	return model_for(KIND_VICTORY, summary)


## Modelo de derrota (o Oponente venceu e a Forca Sobrenatural resolveu -- a
## campanha continua).
func defeat_model(summary: Dictionary) -> Dictionary:
	return model_for(KIND_DEFEAT, summary)


## Modelo de fim de arcade (as sete Pelejas terminaram).
func arcade_end_model(summary: Dictionary) -> Dictionary:
	return model_for(KIND_ARCADE_END, summary)


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
