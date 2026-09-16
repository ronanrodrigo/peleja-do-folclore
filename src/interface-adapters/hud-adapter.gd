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


## Rotulos pt-BR dos status de Golpe Especial: o dominio conhece o nome em
## ingles, a copy vive aqui, na borda de apresentacao.
const STATUS_LABELS := {
	"sleep": "SONO",
	"invert_controls": "COMANDOS INVERTIDOS",
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
			guardian_name, float(state.get("guardian_health_ratio", 0.0)), guardian_rounds
		),
		"right": _side_model(
			opponent_name, float(state.get("opponent_health_ratio", 0.0)), opponent_rounds
		),
		"round": int(state.get("round", 0)),
		"rounds_to_win": MatchRules.ROUNDS_TO_WIN,
		"clock_text": clock_text(int(state.get("clock_seconds", 0))),
		"phase": str(state.get("phase", "")),
		"special_active": bool(state.get("special_active", false)),
		"statuses": _status_labels(state),
	}


## Texto do relogio do round (minutos e segundos), desenhado pela fonte bitmap.
static func clock_text(seconds: int) -> String:
	var remaining := maxi(seconds, 0)
	return "%d:%02d" % [remaining / 60, remaining % 60]


func _side_model(name_text: String, bar: float, rounds_won: int) -> Dictionary:
	return {
		"name": name_text,
		"bar": clampf(bar, 0.0, 1.0),
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
