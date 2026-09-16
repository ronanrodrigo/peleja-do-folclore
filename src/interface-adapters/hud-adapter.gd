class_name HudAdapter
extends RefCounted
## Liga o estado de jogo a um MODELO de HUD, sem desenhar e sem guardar estado.
##
## Este adapter traduz o dado que o caso de uso devolve (a selecao dos Guardioes)
## em posicoes e copias de tela na resolucao base 426x240: o retrato de cada
## Guardiao (o slug do spritesheet codificado, nunca um PNG binario), o nome e o
## nome do Golpe Especial, mais o titulo e o comando de confirmacao.
##
## Invariante: a HUD nunca revela a Vantagem Oculta (ADR 0003). Os numeros de
## vida e de dano nao existem neste modelo -- `discloses_hidden_advantage()`
## existe justamente para o teste provar isso.

const BASE_SIZE := Vector2i(426, 240)

## Colunas: os 4 Guardioes lado a lado, na ordem do elenco.
const COLUMN_COUNT := 4
const COLUMN_WIDTH := 106
const COLUMN_GAP := 2
const PORTRAIT_SCALE := 2
## Retrato do Guardiao: primeiro quadro do idle do spritesheet codificado.
const PORTRAIT_ANIMATION := "idle"
const PORTRAIT_FRAME := 0
const PORTRAIT_TOP := 44
const LABEL_SCALE := 1
const NAME_Y := 128
const SPECIAL_Y := 142
const BAND_TOP := 30
const BAND_HEIGHT := 170

const TITLE_TEXT := "ESCOLHA SEU GUARDIÃO"
const TITLE_SCALE := 2
const TITLE_Y := 12
const PROMPT_TEXT := "PRESSIONE PARA LUTAR"
const PROMPT_SCALE := 1
const PROMPT_Y := 216

const COLOR_BACKGROUND := Color8(18, 18, 42)
const COLOR_BAND := Color8(24, 24, 52)
const COLOR_BAND_SELECTED := Color8(46, 38, 74)
const COLOR_FLOOR := Color8(34, 26, 46)
const COLOR_TITLE := Color8(255, 211, 92)
const COLOR_NAME := Color8(220, 220, 240)
const COLOR_NAME_SELECTED := Color8(255, 211, 92)
const COLOR_SPECIAL := Color8(143, 224, 208)
const COLOR_PROMPT := Color8(255, 255, 255)

## Chaves que revelariam a Vantagem Oculta: nenhuma pode aparecer no modelo.
const FORBIDDEN_KEYS := [
	"health",
	"max_health",
	"health_ratio",
	"damage",
	"damage_multiplier",
	"hidden_advantage",
]

## --- HUD de luta (426x240) ---
##
## Topo da tela = informacao: nome, vida, barra de especial, pips de round e
## relogio. A faixa superior e reservada (o layout de toque nunca monta botao
## aqui). A vida entra so como PROPORCAO de barra; nenhum numero de vida, dano ou
## Vantagem Oculta existe neste modelo (ADR 0003).
const FIGHT_BAR_WIDTH := 180
const FIGHT_BAR_HEIGHT := 6
const FIGHT_METER_HEIGHT := 4
const FIGHT_PIP_SIZE := 5
const FIGHT_PIP_GAP := 2
const FIGHT_MARGIN := 8
const FIGHT_NAME_Y := 8
const FIGHT_CLOCK_Y := 6
const FIGHT_BAR_Y := 20
const FIGHT_METER_Y := 30
const FIGHT_PIP_Y := 38
const FIGHT_NAME_SCALE := 1
const FIGHT_CLOCK_SCALE := 1
const FIGHT_LABEL_SCALE := 1
const FIGHT_ARCADE_Y := 48
const COLOR_BAR_BACK := Color8(42, 42, 64)
const COLOR_HEALTH_FILL := Color8(120, 220, 120)
const COLOR_METER_FILL := Color8(90, 150, 255)
const COLOR_PIP_LOST := Color8(60, 60, 84)
const COLOR_NAME_TEXT := Color8(240, 240, 255)
const COLOR_CLOCK_TEXT := Color8(255, 211, 92)
const COLOR_PROGRESS_TEXT := Color8(200, 200, 230)

## Status ativos dos dois lutadores como copy pt-BR no modelo (`statuses`).
const STATUS_LABELS := {
	"sleep": "SONO",
	"invert_controls": "COMANDOS INVERTIDOS",
}

## Nivel de IA (`OpponentAi.difficulty_name`) para a copy pt-BR do HUD do arcade.
const DIFFICULTY_LABELS := {
	"easy": "FÁCIL",
	"normal": "MÉDIO",
	"hard": "DIFÍCIL",
}


## Modelo completo da tela de selecao a partir das linhas do
## `character-select-service`: fundo, titulo, uma coluna por Guardiao (retrato,
## nome, nome do Golpe Especial) e o comando de confirmacao.
func character_select_model(rows: Array) -> Dictionary:
	var columns: Array = []
	for row in rows:
		columns.append(_column(row))
	return {
		"background": Color8(18, 18, 42),
		"floor": Rect2i(0, BAND_TOP + BAND_HEIGHT, BASE_SIZE.x, BASE_SIZE.y - BAND_TOP - BAND_HEIGHT),
		"floor_color": COLOR_FLOOR,
		"title": TITLE_TEXT,
		"title_position": _centered(TITLE_TEXT, TITLE_SCALE, 0, BASE_SIZE.x, TITLE_Y),
		"title_scale": TITLE_SCALE,
		"title_color": COLOR_TITLE,
		"prompt": PROMPT_TEXT,
		"prompt_position": _centered(PROMPT_TEXT, PROMPT_SCALE, 0, BASE_SIZE.x, PROMPT_Y),
		"prompt_scale": PROMPT_SCALE,
		"prompt_color": COLOR_PROMPT,
		"columns": columns,
		"selected_index": _selected_index(rows),
	}


func _column(row: Dictionary) -> Dictionary:
	var index := int(row.get("index", 0))
	var selected := bool(row.get("selected", false))
	var left := index * COLUMN_WIDTH + COLUMN_GAP / 2
	var name_text := str(row.get("name", ""))
	var special_text := str(row.get("special_name", ""))
	return {
		"index": index,
		"slug": str(row.get("slug", "")),
		"selected": selected,
		"band": Rect2i(left, BAND_TOP, COLUMN_WIDTH - COLUMN_GAP, BAND_HEIGHT),
		"band_color": COLOR_BAND_SELECTED if selected else COLOR_BAND,
		## Retrato: centro horizontal da coluna e topo da faixa (o desenho alinha
		## pela base depois, com a altura real do quadro da spritesheet).
		"portrait_position": Vector2i(left + (COLUMN_WIDTH - COLUMN_GAP) / 2, PORTRAIT_TOP),
		"portrait_scale": PORTRAIT_SCALE,
		"portrait_animation": PORTRAIT_ANIMATION,
		"portrait_frame": PORTRAIT_FRAME,
		"name": name_text,
		"name_position": _centered(name_text, LABEL_SCALE, left, COLUMN_WIDTH - COLUMN_GAP, NAME_Y),
		"name_scale": LABEL_SCALE,
		"name_color": COLOR_NAME_SELECTED if selected else COLOR_NAME,
		"special_name": special_text,
		"special_position": _centered(
			special_text, LABEL_SCALE, left, COLUMN_WIDTH - COLUMN_GAP, SPECIAL_Y
		),
		"special_scale": LABEL_SCALE,
		"special_color": COLOR_SPECIAL,
	}


## Modelo do HUD de uma Peleja em andamento, montado a partir do retrato do
## `match-service`. A vida entra apenas como PROPORCAO de barra (`"bar"`), nunca
## como numero: e o invariante da Vantagem Oculta (ADR 0003) -- o HUD mostra a
## barra caindo, nao os numeros que a Vantagem Oculta inflou.
func fight_model(
	state: Dictionary, guardian_name: String, opponent_name: String
) -> Dictionary:
	var guardian_rounds := int(state.get("guardian_rounds", 0))
	var opponent_rounds := int(state.get("opponent_rounds", 0))
	return {
		"left": _side_model(
			guardian_name,
			float(state.get("guardian_health_ratio", 0.0)),
			float(state.get("guardian_meter_ratio", 0.0)),
			guardian_rounds
		),
		"right": _side_model(
			opponent_name,
			float(state.get("opponent_health_ratio", 0.0)),
			float(state.get("opponent_meter_ratio", 0.0)),
			opponent_rounds
		),
		"round": int(state.get("round", 0)),
		"rounds_to_win": MatchRules.ROUNDS_TO_WIN,
		"clock_text": clock_text(int(state.get("clock_seconds", 0))),
		"phase": str(state.get("phase", "")),
		"special_active": bool(state.get("special_active", false)),
		"statuses": _status_labels(state),
	}


## Modelo do HUD de arcade: em que Peleja o jogador esta, contra quem, com que
## dificuldade e quanto falta. Dado de apresentacao, sem numero de Vantagem Oculta.
func arcade_model(state: Dictionary) -> Dictionary:
	var fight_number := maxi(int(state.get("fight", 0)), 0)
	var fight_count := maxi(int(state.get("fights", 0)), 0)
	var difficulty := str(state.get("difficulty", ""))
	var signature := str(state.get("opponent_signature", ""))
	return {
		"fight_text": "PELEJA %d/%d" % [fight_number, fight_count],
		"opponent_text": str(state.get("opponent_name", "")),
		"signature_text": ("GOLPE: " + signature) if not signature.is_empty() else "",
		"difficulty_text": str(DIFFICULTY_LABELS.get(difficulty, difficulty.to_upper())),
		"progress": (float(fight_number) / float(fight_count)) if fight_count > 0 else 0.0,
		"complete": bool(state.get("complete", false)),
	}


## Retangulos do HUD de luta, ja posicionados na resolucao base: fundo e
## preenchimento das duas barras de vida, das duas barras de Especial e os pips
## de round. A cena so pinta o que vem daqui -- nenhum calculo de layout na cena.
func fight_hud_entries(model: Dictionary) -> Array:
	var left_x := FIGHT_MARGIN
	var right_x := BASE_SIZE.x - FIGHT_MARGIN - FIGHT_BAR_WIDTH
	var entries: Array = []
	entries.append_array(_side_bars(left_x, model["left"], false))
	entries.append_array(_side_bars(right_x, model["right"], true))
	entries.append_array(_pip_entries(left_x, int(model["left"]["rounds_won"]), false, model))
	entries.append_array(_pip_entries(right_x, int(model["right"]["rounds_won"]), true, model))
	return entries


## Vida e Especial de um lado: fundo, preenchimento de vida e do Especial, na
## mesma coluna do HUD.
func _side_bars(x: int, side: Dictionary, right_aligned: bool) -> Array:
	var height := FIGHT_BAR_HEIGHT
	var meter_height := FIGHT_METER_HEIGHT
	var health := _fill(x, FIGHT_BAR_Y, float(side["bar"]), height, right_aligned)
	var meter := _fill(x, FIGHT_METER_Y, float(side["meter"]), meter_height, right_aligned)
	return [_entry(Rect2i(x, FIGHT_BAR_Y, FIGHT_BAR_WIDTH, height), COLOR_BAR_BACK), health, meter]


## Rotulos do HUD de luta: nome do Guardiao (esquerda), nome do Oponente
## (direita), relogio do round (centro) e a linha do arcade. Texto e posicao --
## a cena so desenha pela fonte bitmap.
func fight_hud_labels(model: Dictionary) -> Array:
	var labels: Array = []
	var left_name := str(model["left"]["name"])
	var right_name := str(model["right"]["name"])
	var clock := str(model["clock_text"])
	labels.append({
		"text": left_name,
		"position": Vector2i(FIGHT_MARGIN, FIGHT_NAME_Y),
		"scale": FIGHT_NAME_SCALE,
		"color": COLOR_NAME_TEXT,
	})
	labels.append({
		"text": right_name,
		"position": Vector2i(
			BASE_SIZE.x - FIGHT_MARGIN - BitmapFont.text_width(right_name) * FIGHT_NAME_SCALE,
			FIGHT_NAME_Y
		),
		"scale": FIGHT_NAME_SCALE,
		"color": COLOR_NAME_TEXT,
	})
	labels.append({
		"text": clock,
		"position": _centered(clock, FIGHT_CLOCK_SCALE, 0, BASE_SIZE.x, FIGHT_CLOCK_Y),
		"scale": FIGHT_CLOCK_SCALE,
		"color": COLOR_CLOCK_TEXT,
	})
	var arcade_text := str(model.get("arcade_text", ""))
	if not arcade_text.is_empty():
		labels.append({
			"text": arcade_text,
			"position": _centered(arcade_text, FIGHT_LABEL_SCALE, 0, BASE_SIZE.x, FIGHT_ARCADE_Y),
			"scale": FIGHT_LABEL_SCALE,
			"color": COLOR_PROGRESS_TEXT,
		})
	return labels


func _fill(x: int, y: int, ratio: float, height: int, right_aligned: bool) -> Dictionary:
	var filled := roundi(FIGHT_BAR_WIDTH * clampf(ratio, 0.0, 1.0))
	var left := x + FIGHT_BAR_WIDTH - filled if right_aligned else x
	var color := COLOR_METER_FILL if height == FIGHT_METER_HEIGHT else COLOR_HEALTH_FILL
	return _entry(Rect2i(left, y, filled, height), color)


func _pip_entries(x: int, won: int, right_aligned: bool, model: Dictionary) -> Array:
	var entries: Array = []
	var total := int(model.get("rounds_to_win", MatchRules.ROUNDS_TO_WIN))
	for index in total:
		var offset := index * (FIGHT_PIP_SIZE + FIGHT_PIP_GAP)
		var pip_x := x + FIGHT_BAR_WIDTH - FIGHT_PIP_SIZE - offset if right_aligned else x + offset
		var color := COLOR_HEALTH_FILL if index < won else COLOR_PIP_LOST
		entries.append(_entry(Rect2i(pip_x, FIGHT_PIP_Y, FIGHT_PIP_SIZE, FIGHT_PIP_SIZE), color))
	return entries


func _entry(rect: Rect2i, color: Color) -> Dictionary:
	return {"rect": rect, "color": color}


## Texto do relogio do round (minutos e segundos), desenhado pela fonte bitmap.
static func clock_text(seconds: int) -> String:
	var remaining := maxi(seconds, 0)
	return "%d:%02d" % [remaining / 60, remaining % 60]


func _side_model(
	name_text: String, bar: float, meter: float, rounds_won: int
) -> Dictionary:
	return {
		"name": name_text,
		"bar": clampf(bar, 0.0, 1.0),
		"meter": clampf(meter, 0.0, 1.0),
		"rounds_won": rounds_won,
		"rounds_left": maxi(MatchRules.ROUNDS_TO_WIN - rounds_won, 0),
	}


## Status ativos dos dois lutadores como copy pt-BR; status desconhecido cai no
## proprio nome em caixa alta, nunca some da tela em silencio.
func _status_labels(state: Dictionary) -> Array:
	var labels: Array = []
	for report_key in ["guardian_status", "opponent_status"]:
		for status in state.get(report_key, []):
			var name_text := str(status.get("name", ""))
			if name_text.is_empty():
				continue
			labels.append(str(STATUS_LABELS.get(name_text, name_text.to_upper())))
	return labels


## Nome do Golpe Especial do Guardiao sob o cursor, como a HUD de luta mostra
## (copy pt-BR); vazio quando o Guardiao nao tem efeito cadastrado.
static func special_label(guardian_name: String) -> String:
	return SpecialMoveTable.display_name_for(guardian_name)


## Simbolo de Golpe Especial da linha de luta: o nome do golpe do Guardiao.
static func special_available(guardian_name: String) -> bool:
	return not SpecialMoveTable.display_name_for(guardian_name).is_empty()


## Verdadeiro quando o modelo vaza numero da Vantagem Oculta. A HUD nunca pode
## vazar (ADR 0003): o teste usa esta funcao como invariante. A verificacao e
## recursiva -- vale para o dicionario inteiro, nao so para as chaves de topo.
func discloses_hidden_advantage(model: Dictionary) -> bool:
	return _leaks_forbidden_key(model)


func _leaks_forbidden_key(value: Variant) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		var record: Dictionary = value
		for key in record.keys():
			if FORBIDDEN_KEYS.has(str(key)):
				return true
			if _leaks_forbidden_key(record[key]):
				return true
		return false
	if typeof(value) == TYPE_ARRAY:
		for item in value as Array:
			if _leaks_forbidden_key(item):
				return true
	return false


## Posicao que centraliza um texto (fonte bitmap 5x7) dentro de uma faixa.
func _centered(
	text: String, pixel_scale: int, left: int, width: int, y: int
) -> Vector2i:
	var text_width := BitmapFont.text_width(text) * pixel_scale
	return Vector2i(left + (width - text_width) / 2, y)


func _selected_index(rows: Array) -> int:
	for row in rows:
		if bool(row.get("selected", false)):
			return int(row.get("index", -1))
	return -1
