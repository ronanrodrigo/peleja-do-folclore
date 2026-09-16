class_name MatchService
extends RefCounted
## Caso de uso "uma Peleja": orquestra os dois lutadores, o relogio, as regras de
## melhor de tres e a IA do Oponente.
##
## Nao guarda estado em singleton nem le engine: recebe os gateways por injecao
## (o composition root e o unico lugar que instancia adapters) e todo o estado da
## partida vive aqui. A cena de luta apenas monta o servico, conecta sinais e
## delega -- nenhuma regra de combate mora na cena.

enum Phase {
	IDLE,
	ROUND_ACTIVE,
	ROUND_OVER,
	MATCH_OVER,
}

## Ticks de simulacao por segundo. O relogio do round e contado em ticks.
const TICKS_PER_SECOND := 60
const ROUND_SECONDS := 60
## Ticks de pausa entre o fim de um round e o comeco do proximo.
const ROUND_PAUSE_TICKS := 45
const DEFAULT_DIFFICULTY := OpponentAi.Difficulty.NORMAL
const GUARDIAN_SPAWN_X := 120
const OPPONENT_SPAWN_X := 306

const PHASE_NAMES := {
	Phase.IDLE: "idle",
	Phase.ROUND_ACTIVE: "round_active",
	Phase.ROUND_OVER: "round_over",
	Phase.MATCH_OVER: "match_over",
}

## Paleta usada pelo render model quando o asset-gateway nao entrega cores.
const COLOR_SKY := Color8(18, 18, 42)
const COLOR_GROUND := Color8(34, 26, 46)
const COLOR_BAR_BACK := Color8(42, 42, 64)
const COLOR_HEALTH := Color8(120, 220, 120)
const COLOR_METER := Color8(90, 150, 255)
const COLOR_PIP_LOST := Color8(60, 60, 84)

const STAGE_WIDTH := 426
const STAGE_HEIGHT := 240
## Linha do chao da arena, em pixels. O dominio posiciona os pes em y=0; a
## apresentacao mapeia y=0 para esta linha.
const GROUND_Y := 216
const BAR_WIDTH := 180
const BAR_HEIGHT := 6
const BAR_MARGIN := 8
const METER_HEIGHT := 4
const PIP_SIZE := 5
## Turbilhao do Golpe Especial (Redemoinho): aneis deterministicos em volta do
## Guardiao, sem nenhuma aleatoriedade -- o desenho e funcao da janela do golpe.
const COLOR_WHIRLWIND := Color8(143, 224, 208)
const COLOR_WHIRLWIND_DARK := Color8(47, 143, 134)
const WHIRLWIND_TIERS := 4
const WHIRLWIND_WIDTH := 64
const WHIRLWIND_TIER_HEIGHT := 3
const WHIRLWIND_TIER_STEP := 9

var guardian: Fighter
var opponent: Fighter
var clock: RoundClock
var rules: MatchRules
var ai: OpponentAi
var special_move: Move
var opponent_special_move: Move
## Oponente do arcade: perfil do Arquetipo (aparencia, golpe proprio, IA) e o
## golpe-assinatura que ele usa alem dos tres golpes comuns e do Especial.
var opponent_profile: OpponentProfile
var opponent_signature: Move
## Golpe que rouba a Barra de Especial do Guardiao (Banqueiro e Falso Pastor).
var meter_steal: MeterStealMove
## Unidades de Barra de Especial efetivamente roubadas nesta Peleja.
var meter_stolen: int = 0
## Efeito proprio do Golpe Especial do Guardiao (o Redemoinho do Saci puxa).
var special_effect: SpecialMove
## Relatorio do ultimo tick de efeito do Especial (puxao, drenagem, status).
var special_report: Dictionary = {}
var phase: int = Phase.IDLE
var last_round_result: int = MatchRules.RoundResult.UNRESOLVED

var _input_gateway: InputGateway
var _render_gateway: RenderGateway
var _asset_gateway: AssetGateway
var _audio_gateway: AudioGateway
var _round_pause_ticks: int = 0
var _colors: Array = []


func _init(
	p_input_gateway: InputGateway,
	p_render_gateway: RenderGateway,
	p_asset_gateway: AssetGateway,
	p_audio_gateway: AudioGateway
) -> void:
	_input_gateway = p_input_gateway
	_render_gateway = p_render_gateway
	_asset_gateway = p_asset_gateway
	_audio_gateway = p_audio_gateway


## Monta uma Peleja do Guardiao contra um Arquetipo. Devolve falso (sem comecar)
## quando o Arquetipo e desconhecido.
func configure(
	guardian_name: String = GuardianStats.SACI,
	archetype: int = Archetype.Id.CAPATAZ,
	guardian_seed: int = 20260915,
	opponent_seed: int = 7,
	difficulty: int = DEFAULT_DIFFICULTY
) -> bool:
	var duel := Fighter.duel(guardian_name, archetype, guardian_seed, opponent_seed)
	if duel.is_empty():
		return false
	guardian = duel["guardian"]
	opponent = duel["opponent"]
	special_move = Move.special(guardian_name)
	special_effect = SpecialMoveTable.for_guardian(guardian_name)
	opponent_special_move = Move.special(opponent.stats.display_name)
	ai = OpponentAi.new(difficulty)
	opponent_profile = OpponentProfile.for_archetype(archetype)
	opponent_signature = null
	meter_steal = null
	meter_stolen = 0
	if opponent_profile != null:
		ai.apply_overrides(opponent_profile.ai_overrides)
		opponent_signature = opponent_profile.signature_move()
		meter_steal = opponent_profile.meter_steal
	rules = MatchRules.new()
	clock = RoundClock.new(ROUND_SECONDS)
	_colors = _load_palette()
	_begin_round()
	return true


func is_active() -> bool:
	return phase == Phase.ROUND_ACTIVE


## Gateway de entrada injetado (a cena o expoe para automacao e teste).
func input_gateway() -> InputGateway:
	return _input_gateway


func is_match_over() -> bool:
	return phase == Phase.MATCH_OVER


## Vencedor da Peleja quando ela acabou; NONE enquanto nao acabou.
func winner() -> int:
	if rules == null:
		return MatchRules.Winner.NONE
	return rules.winner()


func phase_name() -> String:
	return PHASE_NAMES.get(phase, "idle")


## Round atual, base um (0 enquanto a Peleja nao comecou).
func round_number() -> int:
	if rules == null:
		return 0
	return rules.rounds_played() + 1 if phase == Phase.ROUND_ACTIVE else rules.rounds_played()


## Avanca um tick de simulacao e devolve o retrato do estado.
##
## Ordem do tick: comandos do jogador -> decisao da IA -> avanco dos lutadores ->
## resolucao dos golpes -> relogio -> fim de round. E a mesma ordem em toda a
## Peleja, o que mantem a partida reproduzivel pela semente.
func advance_tick() -> Dictionary:
	match phase:
		Phase.ROUND_ACTIVE:
			_simulate_round_tick()
		Phase.ROUND_OVER:
			_round_pause_ticks -= 1
			if _round_pause_ticks <= 0:
				_begin_round()
		_:
			pass
	return snapshot()


func _simulate_round_tick() -> void:
	var commands: Array = _input_gateway.poll() if _input_gateway != null else []
	_apply_player_commands(commands)
	_apply_opponent_ai()
	guardian.advance_tick()
	opponent.advance_tick()
	_resolve_combat()
	_apply_special_effect()
	clock.advance(1)
	_face_each_other()
	_resolve_round_end()


## Efeito proprio do Golpe Especial do Guardiao: enquanto a janela ativa do
## Redemoinho dura, o turbilhao suga o Oponente para dentro dele. Cada lenda
## aplica o proprio efeito no mesmo ponto do tick -- Pes Invertidos troca o lado
## dos comandos do Oponente, Canto do Rio adormece e drena, Nana Nenem adormece
## e morde. O efeito e regra pura do dominio (`SpecialMove`), nao desenho.
func _apply_special_effect() -> void:
	if special_effect == null or guardian == null or opponent == null:
		return
	if guardian.current_move == null or not guardian.current_move.is_special():
		return
	if not guardian.is_move_active():
		return
	special_report = special_effect.apply_active_tick(guardian, opponent)


## Retrato dos status ativos de um lutador (nome em ingles + ticks restantes).
## A HUD so mostra que ha status; os numeros da Vantagem Oculta nunca entram aqui.
func _status_report(fighter: Fighter) -> Array:
	var report: Array = []
	if fighter == null or fighter.statuses == null:
		return report
	for status in fighter.statuses.active:
		if not status.is_active():
			continue
		report.append(
			{
				"name": StatusEffect.name_of(status.kind),
				"ticks": status.ticks_remaining,
			}
		)
	return report


## Executa ate o primeiro comando que muda alguma coisa; depois solta o que ficou
## pressionado sem comando neste tick (defesa e agachar nao grudam sozinhos).
func _apply_player_commands(commands: Array) -> void:
	var seen: Dictionary = {}
	for command in commands:
		if _apply_player_command(command):
			seen[command] = true
	if guardian.state == FighterState.State.WALK and not _has_movement(seen):
		guardian.walk(0)
	if guardian.state == FighterState.State.BLOCK and not seen.has(InputGateway.Command.BLOCK):
		guardian.stand()
	if guardian.state == FighterState.State.CROUCH and not seen.has(InputGateway.Command.CROUCH):
		guardian.stand()


func _apply_player_command(command: int) -> bool:
	match command:
		InputGateway.Command.MOVE_LEFT:
			return guardian.walk(-1)
		InputGateway.Command.MOVE_RIGHT:
			return guardian.walk(1)
		InputGateway.Command.CROUCH:
			return guardian.crouch()
		InputGateway.Command.BLOCK:
			return guardian.block()
		_:
			return _apply_attack_command(command)


func _apply_attack_command(command: int) -> bool:
	var move := _move_for(command)
	if move != null:
		return guardian.start_move(move)
	if command == InputGateway.Command.SPECIAL:
		return guardian.start_special(special_move)
	return false


func _move_for(command: int) -> Move:
	match command:
		InputGateway.Command.LIGHT:
			return Move.light()
		InputGateway.Command.HEAVY:
			return Move.heavy()
		InputGateway.Command.GRAB:
			return Move.grab()
		_:
			return null


func _has_movement(seen: Dictionary) -> bool:
	return seen.has(InputGateway.Command.MOVE_LEFT) or seen.has(InputGateway.Command.MOVE_RIGHT)


func _apply_opponent_ai() -> void:
	if ai == null:
		return
	var action := ai.decide(opponent, guardian, opponent.rng)
	match action:
		OpponentAi.Action.ADVANCE:
			opponent.walk(_towards(opponent, guardian))
		OpponentAi.Action.RETREAT:
			opponent.walk(-_towards(opponent, guardian))
		OpponentAi.Action.BLOCK:
			opponent.block()
		OpponentAi.Action.LIGHT:
			opponent.start_move(Move.light())
		OpponentAi.Action.HEAVY:
			opponent.start_move(Move.heavy())
		OpponentAi.Action.GRAB:
			opponent.start_move(Move.grab())
		OpponentAi.Action.SIGNATURE:
			opponent.start_move(opponent_signature)
		OpponentAi.Action.SPECIAL:
			opponent.start_special(opponent_special_move)
		_:
			pass


func _resolve_combat() -> void:
	# O golpe do Oponente e lido ANTES da resolucao: quem apanha perde o golpe em
	# andamento, e o roubo de barra precisa saber qual golpe conectou.
	var opponent_move := opponent.current_move
	var guardian_damage := guardian.resolve_hit(opponent)
	var opponent_damage := opponent.resolve_hit(guardian)
	if guardian_damage > 0 or opponent_damage > 0:
		_sfx("hit")
	if opponent_damage > 0:
		_apply_meter_steal(opponent_move)


## O golpe-assinatura de quem cobra (Banqueiro e Falso Pastor) tira Barra de
## Especial do Guardiao no contato -- "Juros Compostos" e "Dizimo". Como o Golpe
## Especial exige a barra cheia, o roubo adia o Especial dele: o efeito de jogo do
## Arquetipo, sem regra nova no `Fighter`.
func _apply_meter_steal(move: Move) -> void:
	if meter_steal == null or move == null:
		return
	if not meter_steal.is_named(move.display_name):
		return
	meter_stolen += meter_steal.steal_from(guardian, opponent)


func _face_each_other() -> void:
	guardian.face_towards(opponent.position.x)
	opponent.face_towards(guardian.position.x)


func _resolve_round_end() -> void:
	if not clock.is_expired() and not guardian.is_knocked_out() and not opponent.is_knocked_out():
		return
	var result := MatchRules.resolve_round(guardian, opponent, clock)
	if result == MatchRules.RoundResult.UNRESOLVED:
		return
	last_round_result = result
	rules.register_round(result)
	_sfx("round_end")
	if rules.is_decided():
		phase = Phase.MATCH_OVER
		_music("result")
		return
	phase = Phase.ROUND_OVER
	_round_pause_ticks = ROUND_PAUSE_TICKS


func _begin_round() -> void:
	guardian.reset_for_round(GUARDIAN_SPAWN_X)
	opponent.reset_for_round(OPPONENT_SPAWN_X)
	special_report = {}
	clock.reset()
	_face_each_other()
	_round_pause_ticks = 0
	phase = Phase.ROUND_ACTIVE
	_music("fight")


## Desenha o frame pelo render-gateway injetado (escala inteira, sem suavizacao).
func render_frame() -> void:
	if _render_gateway == null:
		return
	_render_gateway.clear()
	for entry in render_model():
		_render_gateway.draw_rect(entry["rect"], entry["color"])
	_render_gateway.present()


## Modelo de desenho: lista de retangulos no espaco da resolucao base (426x240).
## E a unica fonte de verdade visual -- a cena apenas pinta estes retangulos, sem
## recalcular posicao nenhuma.
func render_model() -> Array:
	var model: Array = []
	if guardian == null or opponent == null:
		return model
	model.append(_entry(Rect2i(0, 0, STAGE_WIDTH, STAGE_HEIGHT), COLOR_SKY))
	model.append(_entry(Rect2i(0, GROUND_Y, STAGE_WIDTH, STAGE_HEIGHT - GROUND_Y), COLOR_GROUND))
	model.append(_entry(_body_rect(guardian), _fighter_color(0)))
	model.append(_entry(_body_rect(opponent), _fighter_color(1)))
	_append_special_effect(model)
	_append_bars(model)
	_append_round_pips(model)
	return model


## Turbilhao do Redemoinho em volta do Guardiao enquanto a janela ativa do Golpe
## Especial dura. Deterministico: a mesma janela desenha o mesmo turbilhao.
func _append_special_effect(model: Array) -> void:
	if guardian == null or guardian.current_move == null:
		return
	if not guardian.current_move.is_special() or not guardian.is_move_active():
		return
	var box := guardian.hurtbox()
	var center_x := box.position.x + box.size.x / 2
	var baseline := box.position.y + GROUND_Y
	for tier in WHIRLWIND_TIERS:
		var width := WHIRLWIND_WIDTH - tier * 12
		var color := COLOR_WHIRLWIND if tier % 2 == 0 else COLOR_WHIRLWIND_DARK
		var y := baseline + tier * WHIRLWIND_TIER_STEP
		var rect := Rect2i(center_x - width / 2, y, width, WHIRLWIND_TIER_HEIGHT)
		model.append(_entry(rect, color))


func _append_bars(model: Array) -> void:
	var left := BAR_MARGIN
	var right := STAGE_WIDTH - BAR_MARGIN - BAR_WIDTH
	model.append(_entry(Rect2i(left, BAR_MARGIN, BAR_WIDTH, BAR_HEIGHT), COLOR_BAR_BACK))
	model.append(_entry(Rect2i(right, BAR_MARGIN, BAR_WIDTH, BAR_HEIGHT), COLOR_BAR_BACK))
	model.append(_entry(_health_rect(left, guardian.health.ratio()), COLOR_HEALTH))
	model.append(_entry(_health_rect(right, opponent.health.ratio(), true), COLOR_HEALTH))
	var meter_y := BAR_MARGIN + BAR_HEIGHT + 3
	model.append(_entry(_meter_rect(left, guardian.meter.ratio(), meter_y), COLOR_METER))
	model.append(_entry(_meter_rect(right, opponent.meter.ratio(), meter_y, true), COLOR_METER))


func _append_round_pips(model: Array) -> void:
	if rules == null:
		return
	var y := BAR_MARGIN + BAR_HEIGHT + METER_HEIGHT + 6
	for index in MatchRules.ROUNDS_TO_WIN:
		var guardian_won := index < rules.guardian_rounds()
		var opponent_won := index < rules.opponent_rounds()
		var guardian_color := COLOR_HEALTH if guardian_won else COLOR_PIP_LOST
		var opponent_color := COLOR_HEALTH if opponent_won else COLOR_PIP_LOST
		var guardian_x := BAR_MARGIN + index * (PIP_SIZE + 2)
		model.append(_entry(Rect2i(guardian_x, y, PIP_SIZE, PIP_SIZE), guardian_color))
		var opponent_x := STAGE_WIDTH - BAR_MARGIN - PIP_SIZE - index * (PIP_SIZE + 2)
		model.append(_entry(Rect2i(opponent_x, y, PIP_SIZE, PIP_SIZE), opponent_color))


## Corpo do lutador no chao da arena: a hurtbox do dominio com os pes na linha
## do chao (o dominio usa y=0 como os pes).
func _body_rect(fighter: Fighter) -> Rect2i:
	var box := fighter.hurtbox()
	return Rect2i(box.position.x, box.position.y + GROUND_Y, box.size.x, box.size.y)


func _health_rect(x: int, ratio: float, right_aligned: bool = false) -> Rect2i:
	var filled := roundi(BAR_WIDTH * clampf(ratio, 0.0, 1.0))
	if right_aligned:
		return Rect2i(x + BAR_WIDTH - filled, BAR_MARGIN, filled, BAR_HEIGHT)
	return Rect2i(x, BAR_MARGIN, filled, BAR_HEIGHT)


func _meter_rect(x: int, ratio: float, y: int, right_aligned: bool = false) -> Rect2i:
	var filled := roundi(BAR_WIDTH * clampf(ratio, 0.0, 1.0))
	if right_aligned:
		return Rect2i(x + BAR_WIDTH - filled, y, filled, METER_HEIGHT)
	return Rect2i(x, y, filled, METER_HEIGHT)


## Retrato do estado atual, consumido por testes, HUD e ferramenta de evidencia.
## Nunca inclui os numeros escondidos da Vantagem Oculta.
func snapshot() -> Dictionary:
	return {
		"phase": phase_name(),
		"round": round_number(),
		"rounds_played": rules.rounds_played() if rules != null else 0,
		"guardian_rounds": rules.guardian_rounds() if rules != null else 0,
		"opponent_rounds": rules.opponent_rounds() if rules != null else 0,
		"last_round_result": last_round_result,
		"winner": winner(),
		"guardian_health_ratio": guardian.health.ratio() if guardian != null else 0.0,
		"opponent_health_ratio": opponent.health.ratio() if opponent != null else 0.0,
		"guardian_x": guardian.position.x if guardian != null else 0,
		"opponent_x": opponent.position.x if opponent != null else 0,
		"clock_seconds": clock.remaining_seconds() if clock != null else 0,
		"special_active": _is_special_active(),
		"special_name": special_effect.display_name if special_effect != null else "",
		"special_report": special_report,
		"guardian_status": _status_report(guardian),
		"opponent_status": _status_report(opponent),
		"opponent_slug": opponent_profile.slug if opponent_profile != null else "",
		"opponent_signature": (
			opponent_profile.signature_name if opponent_profile != null else ""
		),
		"opponent_steals_meter": meter_steal != null,
		"meter_stolen": meter_stolen,
		"ai_signature_chance": ai.signature_chance if ai != null else 0.0,
	}


## Verdadeiro enquanto a janela ativa do Golpe Especial do Guardiao dura (e o
## efeito proprio, como o puxao do Redemoinho, esta agindo).
func _is_special_active() -> bool:
	if guardian == null or guardian.current_move == null:
		return false
	return guardian.current_move.is_special() and guardian.is_move_active()


func _load_palette() -> Array:
	if _asset_gateway == null:
		return []
	return _asset_gateway.load_palette("placeholder")


## Cor do corpo: o Guardiao usa a segunda cor da paleta do asset-gateway (o
## amarelo do folclore); sem paleta, cai na constante. O Oponente tem cor fixa.
func _fighter_color(index: int) -> Color:
	if index == 0:
		return _colors[1] if _colors.size() > 1 else Color8(255, 211, 92)
	return Color8(214, 72, 72)


func _entry(rect: Rect2i, color: Color) -> Dictionary:
	return {"rect": rect, "color": color}


func _towards(from: Fighter, to: Fighter) -> int:
	if to.position.x > from.position.x:
		return 1
	if to.position.x < from.position.x:
		return -1
	return 0


func _sfx(kind: String) -> void:
	if _audio_gateway != null:
		_audio_gateway.play_sfx(kind)


func _music(context: String) -> void:
	if _audio_gateway != null:
		_audio_gateway.play_music(context)
