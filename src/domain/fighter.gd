class_name Fighter
extends RefCounted
## Estado puro de um lutador durante um round.
##
## Avancado por tick de simulacao: nenhum sinal de engine, nenhum temporizador,
## nenhuma leitura de entrada. O chamador entrega comandos e a variacao
## aleatoria de dano sai do `rng` injetado, entao a mesma semente com os mesmos
## comandos chega ao mesmo estado (invariante 2 de docs/architecture.md).

const STAGE_MIN_X := 0
## A arena ocupa a largura da resolucao base (426x240, ADR 0002).
const STAGE_MAX_X := 426
const STANDING_SIZE := Vector2i(24, 34)
## Agachar encolhe a hurtbox: o corpo fica mais baixo e mais largo.
const CROUCH_SIZE := Vector2i(26, 20)
const HITBOX_HEIGHT := 18
const HITBOX_OFFSET_Y := 16
## Ticks em que o lutador fica travado depois de apanhar.
const HURT_FRAMES := 14
## Variacao de dano padrao, em unidades, para cima e para baixo.
const DEFAULT_DAMAGE_VARIANCE := 1

var stats: FighterStats
var rng: Rng
var health: Health
var meter: SpecialMeter
var state: int = FighterState.State.IDLE
## 1 olhando para a direita, -1 olhando para a esquerda.
var facing: int = 1
## Posicao dos pes no chao da arena, em pixels da resolucao base.
var position: Vector2i = Vector2i.ZERO
var current_move: Move = null
var move_frame: int = 0
## Verdadeiro quando o golpe atual ja conectou; evita contar o mesmo golpe duas vezes.
var hit_registered: bool = false
var hurt_frames: int = 0
var damage_variance: int = DEFAULT_DAMAGE_VARIANCE


func _init(
	p_stats: FighterStats,
	p_rng: Rng = null,
	p_x: int = STAGE_MIN_X,
	p_facing: int = 1
) -> void:
	stats = p_stats if p_stats != null else FighterStats.new()
	rng = p_rng if p_rng != null else Rng.new()
	health = Health.new(stats.max_health)
	meter = SpecialMeter.new()
	facing = 1 if p_facing >= 0 else -1
	position = Vector2i(clampi(p_x, STAGE_MIN_X, STAGE_MAX_X), 0)


## Os dois lutadores de uma Peleja, ja com a Vantagem Oculta do lado do Guardiao:
## e o unico caminho previsto para montar um confronto com os numeros corretos.
static func duel(
	guardian_name: String,
	archetype: int,
	guardian_seed: int,
	opponent_seed: int
) -> Dictionary:
	var opponent_stats := OpponentStats.for_archetype(archetype)
	if opponent_stats == null:
		return {}
	var guardian := Fighter.new(
		GuardianStats.advantaged(guardian_name), Rng.new(guardian_seed), 120, 1
	)
	var opponent := Fighter.new(opponent_stats, Rng.new(opponent_seed), 306, -1)
	guardian.face_towards(opponent.position.x)
	opponent.face_towards(guardian.position.x)
	return {"guardian": guardian, "opponent": opponent}


## Tamanho do corpo: agachado, mais baixo e mais largo.
func _body_size() -> Vector2i:
	if state == FighterState.State.CROUCH:
		return CROUCH_SIZE
	return STANDING_SIZE


## Caixa que pode ser acertada. Agachado o corpo fica mais baixo, sem deslocar
## os pes: golpes altos passam por cima.
func hurtbox() -> BoundingBox:
	var size := _body_size()
	return BoundingBox.new(position + Vector2i(-size.x / 2, -size.y), size)


## Caixa do golpe em andamento, do lado para o qual o lutador olha. Vazia quando
## nao ha golpe ou quando a janela ativa ainda nao chegou (inicio/recuperacao).
func hitbox() -> BoundingBox:
	if current_move == null or not is_move_active():
		return BoundingBox.empty()
	var width := current_move.reach
	var origin_x := position.x if facing > 0 else position.x - width
	var top := position.y - HITBOX_OFFSET_Y - HITBOX_HEIGHT
	return BoundingBox.new(Vector2i(origin_x, top), Vector2i(width, HITBOX_HEIGHT))


func is_move_active() -> bool:
	return current_move != null and current_move.is_active_at(move_frame)


func is_attacking() -> bool:
	return FighterState.is_attacking(state)


func is_knocked_out() -> bool:
	return health.is_empty() or state == FighterState.State.KNOCKED_DOWN


## Verdadeiro quando o lutador aceita um comando novo agora.
func can_act() -> bool:
	return FighterState.accepts_command(state) and current_move == null


func can_start_move() -> bool:
	return can_act() and hurt_frames == 0


## Encara um alvo: o Guardiao sempre olha para o Oponente, nunca para tras.
func face_towards(target_x: int) -> void:
	if target_x > position.x:
		facing = 1
	elif target_x < position.x:
		facing = -1


func walk(direction: int) -> bool:
	if not can_act():
		return false
	if direction == 0:
		state = FighterState.State.IDLE
		return true
	var step := 1 if direction > 0 else -1
	state = FighterState.State.WALK
	position.x = clampi(position.x + step * stats.walk_speed, STAGE_MIN_X, STAGE_MAX_X)
	return true


func crouch() -> bool:
	if not can_act():
		return false
	state = FighterState.State.CROUCH
	return true


func stand() -> bool:
	if not can_act():
		return false
	state = FighterState.State.IDLE
	return true


func block() -> bool:
	if not can_act():
		return false
	state = FighterState.State.BLOCK
	return true


## Inicia um golpe. Recusa enquanto o golpe anterior nao terminou, durante o hurt
## e com o lutador nocauteado.
func start_move(move: Move) -> bool:
	if move == null or not can_start_move():
		return false
	current_move = move
	move_frame = 0
	hit_registered = false
	state = FighterState.State.ATTACK
	return true


## O Golpe Especial so dispara com a Barra de Especial cheia e consumindo a barra
## inteira (regra de produto do ticket 2, derivada de CONTEXT.md).
func can_use_special() -> bool:
	return can_start_move() and meter.is_full()


func start_special(move: Move) -> bool:
	if move == null or not move.is_special() or not can_use_special():
		return false
	if not meter.consume():
		return false
	return start_move(move)


## Avanca um tick de simulacao. Devolve verdadeiro quando o golpe em andamento
## terminou neste tick.
func advance_tick() -> bool:
	if current_move != null:
		move_frame += 1
		if current_move.is_finished_at(move_frame):
			current_move = null
			move_frame = 0
			hit_registered = false
			state = FighterState.State.IDLE
			return true
		return false
	if hurt_frames > 0:
		hurt_frames -= 1
		if hurt_frames == 0:
			state = FighterState.State.IDLE
		return false
	return false


## Resolve o contato do golpe em andamento contra o defensor e devolve o dano
## aplicado (0 quando nao houve contato). Conecta no maximo uma vez por golpe e
## somente durante a janela ativa, com as caixas sobrepostas.
func resolve_hit(defender: Fighter) -> int:
	if defender == null or current_move == null or hit_registered:
		return 0
	if not is_move_active() or is_knocked_out() or defender.is_knocked_out():
		return 0
	if not hitbox().intersects(defender.hurtbox()):
		return 0
	hit_registered = true
	return defender.receive_hit(current_move, self, _roll_variance())


## Recebe um golpe: a defesa reduz o dano dos golpes bloqueaveis (o agarrao
## ignora a guarda), a vida cai, a barra enche nos dois lados e o lutador entra
## em hurt -- ou em nocaute quando a vida zera. O golpe em andamento e
## interrompido.
func receive_hit(move: Move, attacker: Fighter, p_damage_variance: int = 0) -> int:
	if move == null or is_knocked_out():
		return 0
	var blocking := state == FighterState.State.BLOCK and move.blockable
	var incoming := stats.damage_taken(move, blocking) + p_damage_variance
	var applied := health.apply_damage(maxi(incoming, 1))
	meter.gain(stats.meter_gain_on_hurt)
	if attacker != null:
		attacker.meter.gain(attacker.stats.meter_gain_on_hit)
	current_move = null
	move_frame = 0
	hit_registered = false
	if health.is_empty():
		state = FighterState.State.KNOCKED_DOWN
		hurt_frames = 0
	elif not blocking:
		state = FighterState.State.HURT
		hurt_frames = HURT_FRAMES
	return applied


## Zera vida, barra, golpe e travamento para o proximo round. Reposiciona quando
## um x de nascimento e informado.
func reset_for_round(spawn_x: int = -1) -> void:
	health.reset()
	meter.reset()
	current_move = null
	move_frame = 0
	hit_registered = false
	hurt_frames = 0
	state = FighterState.State.IDLE
	if spawn_x >= 0:
		position.x = clampi(spawn_x, STAGE_MIN_X, STAGE_MAX_X)


func _roll_variance() -> int:
	if damage_variance <= 0 or rng == null:
		return 0
	return rng.next_int(-damage_variance, damage_variance)
