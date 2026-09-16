class_name OpponentAi
extends RefCounted
## Politica pura de decisao do Oponente, parametrizada por tres niveis de
## dificuldade.
##
## Nao le entrada do jogador, nao desenha e nao consulta relogio: recebe os dois
## lutadores do round e o `Rng` injetado e devolve a acao do tick. Como toda a
## aleatoriedade vem desse `Rng`, a mesma semente com o mesmo estado produz
## sempre a mesma sequencia de decisoes (invariante 2 de docs/architecture.md).
##
## Subir a dificuldade e mexer apenas nos perfis `PROFILES`: nenhum numero de
## balanceamento fica espalhado pelo codigo.

## Acoes que o Oponente pode tomar num tick. Sao intencoes de dominio, nunca
## comandos de engine: quem as executa e o `match-service`.
enum Action {
	WAIT,
	ADVANCE,
	RETREAT,
	BLOCK,
	LIGHT,
	HEAVY,
	GRAB,
	SPECIAL,
}

enum Difficulty {
	EASY,
	NORMAL,
	HARD,
}

const DIFFICULTY_NAMES := {
	Difficulty.EASY: "easy",
	Difficulty.NORMAL: "normal",
	Difficulty.HARD: "hard",
}

const ACTION_NAMES := {
	Action.WAIT: "wait",
	Action.ADVANCE: "advance",
	Action.RETREAT: "retreat",
	Action.BLOCK: "block",
	Action.LIGHT: "light",
	Action.HEAVY: "heavy",
	Action.GRAB: "grab",
	Action.SPECIAL: "special",
}

## Perfis de dificuldade: numero explicito, nunca ajuste implicito.
##
## `aggression` e a chance de atacar no alcance, `block_chance` a de defender
## quando o Guardiao golpeia, `retreat_chance` a de recuar, `special_chance` a de
## gastar o Especial com a barra cheia e `engage_distance` a distancia (em pixels
## da resolucao base) em que o Oponente considera que esta no alcance. Maior
## dificuldade: mais agressao, mais defesa, especial com mais frequencia e menos
## ticks entre uma decisao e a seguinte.
const PROFILES := {
	Difficulty.EASY: {
		"aggression": 0.35,
		"block_chance": 0.15,
		"retreat_chance": 0.30,
		"special_chance": 0.05,
		"grab_chance": 0.10,
		"heavy_chance": 0.20,
		"engage_distance": 26,
		"reaction_ticks": 12,
	},
	Difficulty.NORMAL: {
		"aggression": 0.60,
		"block_chance": 0.35,
		"retreat_chance": 0.18,
		"special_chance": 0.25,
		"grab_chance": 0.18,
		"heavy_chance": 0.30,
		"engage_distance": 30,
		"reaction_ticks": 8,
	},
	Difficulty.HARD: {
		"aggression": 0.85,
		"block_chance": 0.55,
		"retreat_chance": 0.10,
		"special_chance": 0.55,
		"grab_chance": 0.22,
		"heavy_chance": 0.45,
		"engage_distance": 34,
		"reaction_ticks": 5,
	},
}

var difficulty: int
var _profile: Dictionary
var _ticks_until_decision: int = 0
var _last_action: int = Action.WAIT


func _init(p_difficulty: int = Difficulty.NORMAL) -> void:
	set_difficulty(p_difficulty)


## Troca o nivel de dificuldade. Nivel desconhecido cai para NORMAL.
func set_difficulty(p_difficulty: int) -> void:
	difficulty = p_difficulty if PROFILES.has(p_difficulty) else Difficulty.NORMAL
	_profile = PROFILES[difficulty]
	_ticks_until_decision = 0
	_last_action = Action.WAIT


## Perfil numerico do nivel atual (dado, nao copia mutavel).
func profile() -> Dictionary:
	return _profile.duplicate()


func value_of(key: String) -> float:
	return float(_profile.get(key, 0.0))


func reaction_ticks() -> int:
	return int(_profile["reaction_ticks"])


## Decide a acao deste tick.
##
## O Oponente so reavalia a cada `reaction_ticks`; nos ticks do meio repete a
## decisao anterior para que o movimento nao trema. Quando nao pode agir (em
## hurt, nocauteado ou no meio de um golpe) devolve WAIT sem gastar o `Rng`,
## senao a sequencia deixaria de depender so da semente e dos comandos.
func decide(opponent: Fighter, guardian: Fighter, rng: Rng) -> int:
	if opponent == null or guardian == null or rng == null:
		return Action.WAIT
	if not opponent.can_start_move():
		return Action.WAIT
	if _ticks_until_decision > 0:
		_ticks_until_decision -= 1
		return _last_action
	_ticks_until_decision = reaction_ticks()
	_last_action = _choose(opponent, guardian, rng)
	return _last_action


func _choose(opponent: Fighter, guardian: Fighter, rng: Rng) -> int:
	var gap := _gap(opponent, guardian)
	var engage := int(_profile["engage_distance"])
	if opponent.can_use_special() and rng.chance(value_of("special_chance")):
		return Action.SPECIAL
	if gap > engage:
		return Action.ADVANCE
	if guardian.is_attacking() and rng.chance(value_of("block_chance")):
		return Action.BLOCK
	if rng.chance(value_of("aggression")):
		return _pick_attack(rng)
	if rng.chance(value_of("retreat_chance")):
		return Action.RETREAT
	return Action.BLOCK


func _pick_attack(rng: Rng) -> int:
	if rng.chance(value_of("grab_chance")):
		return Action.GRAB
	if rng.chance(value_of("heavy_chance")):
		return Action.HEAVY
	return Action.LIGHT


## Distancia horizontal entre os corpos, nunca negativa.
func _gap(opponent: Fighter, guardian: Fighter) -> int:
	return maxi(opponent.hurtbox().horizontal_distance_to(guardian.hurtbox()), 0)


static func difficulty_name(p_difficulty: int) -> String:
	return DIFFICULTY_NAMES.get(p_difficulty, "normal")


static func action_name(action: int) -> String:
	return ACTION_NAMES.get(action, "unknown")


static func level_count() -> int:
	return PROFILES.size()


static func levels() -> Array:
	return [Difficulty.EASY, Difficulty.NORMAL, Difficulty.HARD]


## Verdadeiro quando a acao e um golpe (leve, pesado, agarrao ou especial).
static func is_attack(action: int) -> bool:
	return action in [Action.LIGHT, Action.HEAVY, Action.GRAB, Action.SPECIAL]
