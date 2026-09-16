class_name ReviravoltaService
extends RefCounted
## Caso de uso da Reviravolta (ADR 0003): a cena em painel de tela cheia em que a
## Forca Sobrenatural dissolve o Oponente que venceu a Peleja.
##
## Recebe os gateways por injecao (asset, render, audio e persistence) e nao
## instancia adapter nenhum: quem monta os concretos e o composition root. Todo o
## estado da cena vive aqui -- a cena Godot apenas monta, delega e desenha.
##
## Quem decide SE a cena dispara e o dominio (`ReviravoltaRule`), e nao este
## servico: vitoria do Guardiao devolve falso sem tocar em arte, som ou disco. A
## arte do painel vem do asset-gateway pelo slug, com fallback obrigatorio; o
## progresso do arcade e mantido no persistence-gateway -- a derrota perde a
## Peleja, nunca a campanha.

## Slug da arte de painel: arte gerada (ticket 9), com fallback em codigo quando o
## arquivo nao existe. Nunca um PNG binario de lutador.
const PANEL_SLUG := "reviravolta-panel"
const BASE_SIZE := Vector2i(426, 240)
const PANEL_BYTES := 426 * 240 * 4

## Linhas da cena quando o chamador nao informa o tamanho da sequencia de texto.
const DEFAULT_LINE_COUNT := 4

## Chave do progresso do arcade: gravada quando a Reviravolta resolve a Peleja,
## sempre dizendo que a campanha NAO acabou.
const CAMPAIGN_KEY := "arcade/progress"

## Origem dos pixels do painel. `gateway` quando o asset-gateway devolveu um
## painel inteiro; `blank` quando nao havia arte nenhuma (fallback em codigo).
const SOURCE_GATEWAY := "gateway"
const SOURCE_BLANK := "blank"
const SOURCE_NONE := "none"

const COLOR_WIND := Color8(200, 226, 214)
const COLOR_WIND_DARK := Color8(120, 168, 150)
const COLOR_ROOT := Color8(58, 34, 24)
const COLOR_ROOT_LIGHT := Color8(126, 82, 50)
const COLOR_SILHOUETTE := Color8(20, 18, 30)
const COLOR_SILHOUETTE_HEAD := Color8(36, 30, 44)

## Silhueta do Oponente dissolvido, no espaco da resolucao base. A silhueta e
## desenhada em codigo: o painel e a mata, nao ha sprite de Oponente aqui.
const SILHOUETTE_RECT := Rect2i(190, 96, 26, 46)
const HEAD_RECT := Rect2i(196, 82, 14, 14)
const SILHOUETTE_SLICES := 4

## Efeitos deterministicos: nenhum sorteio, tudo funcao da fase e do tick.
const WIND_STREAKS := 14
const ROOT_COUNT := 7

var _asset_gateway: AssetGateway
var _render_gateway: RenderGateway
var _audio_gateway: AudioGateway
var _persistence_gateway: PersistenceGateway

var _pixels: PackedByteArray = PackedByteArray()
var _source := SOURCE_NONE
var _ticks := -1
var _line_count := 0
var _winner := MatchRules.Winner.NONE
var _fight_number := 0
var _active := false
var _finished := false
var _skipped := false
var _last_phase := ReviravoltaRule.Phase.IDLE


func _init(
	p_asset_gateway: AssetGateway,
	p_render_gateway: RenderGateway,
	p_audio_gateway: AudioGateway,
	p_persistence_gateway: PersistenceGateway
) -> void:
	_asset_gateway = p_asset_gateway
	_render_gateway = p_render_gateway
	_audio_gateway = p_audio_gateway
	_persistence_gateway = p_persistence_gateway


## Entrada do caso de uso: quem venceu a Peleja (dado do dominio), quantas linhas
## a sequencia de texto tem e em que Peleja do arcade isso aconteceu. Devolve
## falso -- sem carregar arte, sem tocar som, sem gravar nada -- quando a regra
## nao dispara (vitoria do Guardiao, empate ou Peleja em andamento).
func execute(
	winner: int,
	line_count: int = DEFAULT_LINE_COUNT,
	fight_number: int = 1
) -> bool:
	_ticks = 0
	_line_count = maxi(line_count, 0)
	_winner = winner
	_fight_number = maxi(fight_number, 1)
	_finished = false
	_skipped = false
	_last_phase = ReviravoltaRule.Phase.IDLE
	_pixels = PackedByteArray()
	_source = SOURCE_NONE
	_active = ReviravoltaRule.triggers(winner)
	if not _active:
		return false
	_pixels = _load_panel()
	# A campanha continua: a Peleja foi perdida, o arcade nao.
	record_campaign_progress(_fight_number)
	_sfx(AudioGateway.SFX_SPECIAL)
	_music(AudioGateway.MUSIC_REVIRAVOLTA)
	_play_phase_cues()
	return true


func is_active() -> bool:
	return _active


func is_finished() -> bool:
	return _finished


## Verdadeiro quando a cena terminou pelo comando de pular, nao pelo tempo.
func was_skipped() -> bool:
	return _skipped


## Fase corrente da cena (`ReviravoltaRule.Phase`).
func phase() -> int:
	return ReviravoltaRule.phase_for(_ticks, _line_count)


func phase_name() -> String:
	return ReviravoltaRule.phase_name(phase())


## Avanca um tick de apresentacao e devolve o retrato da cena. A cena rola
## sozinha: nenhuma interacao e exigida para a Reviravolta acontecer.
func advance_tick() -> Dictionary:
	if not _active:
		return snapshot()
	_ticks += 1
	_play_phase_cues()
	if ReviravoltaRule.is_finished(_ticks, _line_count):
		_active = false
		_finished = true
	return snapshot()


## Opcao de pular: leva a cena ao fim de uma vez. Recusa quando a cena ja
## terminou ou quando o dominio diz que ela nao e pulavel.
func skip() -> bool:
	if not _active or not ReviravoltaRule.can_skip():
		return false
	_ticks = ReviravoltaRule.total_ticks(_line_count)
	_skipped = true
	_play_phase_cues()
	_active = false
	_finished = true
	return true


## Pixels RGBA8 426x240 do painel: a arte de tela cheia vinda do asset-gateway.
func panel_pixels() -> PackedByteArray:
	return _pixels


## De onde vieram os pixels: `gateway` (arte ou fallback do gateway) ou `blank`
## (nenhuma arte disponivel -- o jogo nunca quebra, desenha um painel neutro).
func panel_source() -> String:
	return _source


## Modelo de desenho dos efeitos da Forca Sobrenatural: lista de retangulos no
## espaco da resolucao base. Deterministico -- a mesma fase, o mesmo tick e a
## mesma maos de retangulos.
func render_model() -> Array:
	var model: Array = []
	if _source == SOURCE_NONE:
		return model
	var current := phase()
	if current == ReviravoltaRule.Phase.IDLE or current == ReviravoltaRule.Phase.DONE:
		return model
	_append_wind(model, current)
	_append_roots(model, current)
	_append_silhouette(model, current)
	return model


## Desenha um frame pelo render-gateway injetado (escala inteira, sem
## suavizacao). O painel em si e blitado pela cena; aqui vao os efeitos.
func render_frame() -> void:
	if _render_gateway == null:
		return
	_render_gateway.clear()
	for entry in render_model():
		_render_gateway.draw_rect(entry["rect"], entry["color"])
	_render_gateway.present()


## Retrato da cena, consumido por testes, HUD e ferramenta de evidencia. Nao
## inclui nenhum numero da Vantagem Oculta.
func snapshot() -> Dictionary:
	return {
		"active": _active,
		"finished": _finished,
		"skipped": _skipped,
		"phase": phase_name(),
		"phase_index": phase(),
		"ticks": maxi(_ticks, 0),
		"total_ticks": ReviravoltaRule.total_ticks(_line_count),
		"line_index": ReviravoltaRule.line_index_for(_ticks, _line_count),
		"line_count": _line_count,
		"winner": _winner,
		"fight_number": _fight_number,
		"panel_source": _source,
		"panel_bytes": _pixels.size(),
		"skippable": ReviravoltaRule.can_skip(),
		"opponent_dissolved": ReviravoltaRule.opponent_dissolved(_ticks, _line_count),
		"campaign_continues": ReviravoltaRule.keeps_campaign_alive(_winner),
	}


## Grava o progresso do arcade: qual Peleja entrou na Reviravolta e que a
## campanha segue viva. E o unico ponto do ticket que toca o persistence-gateway.
func record_campaign_progress(fight_number: int) -> bool:
	if _persistence_gateway == null:
		return false
	return _persistence_gateway.save(
		CAMPAIGN_KEY,
		{
			"fight": maxi(fight_number, 1),
			"campaign_over": false,
			"reviravolta": true,
		}
	)


## Progresso do arcade guardado (vazio quando nunca houve Reviravolta).
func campaign_progress() -> Dictionary:
	if _persistence_gateway == null:
		return {}
	var stored: Variant = _persistence_gateway.load_value(CAMPAIGN_KEY, {})
	if typeof(stored) != TYPE_DICTIONARY:
		return {}
	return stored


## Efeitos sonoros do contrato, um por fase: o vento arranca, a raiz aperta e a
## Forca dissolve (nocaute). Fase sem cue proprio nao toca nada, e cada cue sai
## uma vez so.
func _play_phase_cues() -> void:
	var current := phase()
	if current == _last_phase:
		return
	_last_phase = current
	match current:
		ReviravoltaRule.Phase.WIND:
			_sfx(AudioGateway.SFX_IMPACT_HEAVY)
		ReviravoltaRule.Phase.ROOT:
			_sfx(AudioGateway.SFX_DAMAGE)
		ReviravoltaRule.Phase.DISSOLVE:
			_sfx(AudioGateway.SFX_KNOCKOUT)
		_:
			pass


## Vento: rajadas horizontais que atravessam a cena e rareiam conforme a Forca
## resolve -- mais no vento, menos na raiz, poucas na dissolucao.
func _append_wind(model: Array, current: int) -> void:
	var count := WIND_STREAKS
	if current == ReviravoltaRule.Phase.ROOT:
		count = WIND_STREAKS * 2 / 3
	elif current == ReviravoltaRule.Phase.DISSOLVE:
		count = WIND_STREAKS / 3
	for index in count:
		var x := (_ticks * 5 + index * 31) % BASE_SIZE.x
		var y := 24 + (index * 13) % 186
		var width := 18 + (index % 3) * 9
		var color := COLOR_WIND if index % 2 == 0 else COLOR_WIND_DARK
		model.append(_entry(Rect2i(x, y, width, 1), color))


## Raiz: hastes que sobem do chao em volta do Oponente e crescem a cada tick --
## primeira metade na raiz, segunda na dissolucao.
func _append_roots(model: Array, current: int) -> void:
	if current != ReviravoltaRule.Phase.ROOT and current != ReviravoltaRule.Phase.DISSOLVE:
		return
	var growth := _effect_progress(current)
	var center := SILHOUETTE_RECT.position.x + SILHOUETTE_RECT.size.x / 2
	for index in ROOT_COUNT:
		var x := center + (index - ROOT_COUNT / 2) * 8
		var height := mini(22 + (index % 3) * 9 + growth * 30, BASE_SIZE.y)
		var y := BASE_SIZE.y - height
		var color := COLOR_ROOT_LIGHT if index % 2 == 0 else COLOR_ROOT
		model.append(_entry(Rect2i(x, y, 3, height), color))


## Silhueta do Oponente: inteira na voz e no vento, presa pelas raizes na raiz e
## em fatias alternadas na dissolucao (a carne se desfazendo). No fim, nada sobra.
func _append_silhouette(model: Array, current: int) -> void:
	if current == ReviravoltaRule.Phase.VOICE or current == ReviravoltaRule.Phase.WIND:
		model.append(_entry(SILHOUETTE_RECT, COLOR_SILHOUETTE))
		model.append(_entry(HEAD_RECT, COLOR_SILHOUETTE_HEAD))
		return
	if current == ReviravoltaRule.Phase.ROOT:
		model.append(_entry(SILHOUETTE_RECT, COLOR_SILHOUETTE_HEAD))
		model.append(_entry(HEAD_RECT, COLOR_SILHOUETTE))
		return
	var slice_height := SILHOUETTE_RECT.size.y / SILHOUETTE_SLICES
	for index in SILHOUETTE_SLICES:
		if index % 2 != _ticks % 2:
			continue
		model.append(
			_entry(
				Rect2i(
					SILHOUETTE_RECT.position.x,
					SILHOUETTE_RECT.position.y + index * slice_height,
					SILHOUETTE_RECT.size.x,
					slice_height
				),
				COLOR_SILHOUETTE
			)
		)


## Progresso dentro da fase do efeito final, de 0 a 2 (terco da dissolucao).
func _effect_progress(current: int) -> int:
	var voice := maxi(_line_count, 0) * ReviravoltaRule.TICKS_PER_LINE
	var third := ReviravoltaRule.DISSOLVE_TICKS / 3
	if current == ReviravoltaRule.Phase.ROOT:
		return clampi((_ticks - voice) / third, 0, 2)
	return clampi((_ticks - voice - third) / third, 0, 2)


## Painel pelo slug, com fallback obrigatorio: o gateway devolve a arte gerada
## ou um fallback em codigo. Sem pixels utilizaveis, o servico desenha um painel
## neutro de 426x240 em vez de quebrar a cena.
func _load_panel() -> PackedByteArray:
	if _asset_gateway == null:
		_source = SOURCE_BLANK
		return _blank_panel()
	var loaded: PackedByteArray = _asset_gateway.load_panel(PANEL_SLUG, PackedByteArray())
	if loaded.size() == PANEL_BYTES:
		_source = SOURCE_GATEWAY
		return loaded
	_source = SOURCE_BLANK
	return _blank_panel()


## Painel neutro em dado puro: 240 linhas de 426 pixels RGBA8 na cor da noite.
func _blank_panel() -> PackedByteArray:
	var row := PackedByteArray()
	row.resize(PANEL_BYTES / BASE_SIZE.y)
	for index in range(0, row.size(), 4):
		row[index] = 12
		row[index + 1] = 20
		row[index + 2] = 14
		row[index + 3] = 255
	var pixels := PackedByteArray()
	for _line in BASE_SIZE.y:
		pixels.append_array(row)
	return pixels


func _entry(rect: Rect2i, color: Color) -> Dictionary:
	return {"rect": rect, "color": color}


func _sfx(kind: String) -> void:
	if _audio_gateway != null:
		_audio_gateway.play_sfx(kind)


func _music(context: String) -> void:
	if _audio_gateway != null:
		_audio_gateway.play_music(context)
