class_name MatchRules
extends RefCounted
## Regras de uma Peleja: melhor de tres rounds.
##
## O resultado de cada round vem de `resolve_round()` (nocaute ou tempo
## esgotado); a Peleja fecha em 2 rounds vencidos pelo mesmo lado. A Peleja pode
## terminar empatada (1-1 com um round empatado, ou 1-1-1), e quem decide o que
## fazer com isso e a Reviravolta (ticket 7), nao este arquivo.

enum RoundResult {
	UNRESOLVED = -1,
	GUARDIAN = 0,
	OPPONENT = 1,
	DRAW = 2,
}

enum Winner {
	NONE,
	GUARDIAN,
	OPPONENT,
	DRAW,
}

const ROUNDS_TO_WIN := 2
const MAX_ROUNDS := 3

var _results: Array = []


## Registra o resultado de um round. Recusa quando a Peleja ja esta decidida ou
## quando os tres rounds ja foram jogados.
func register_round(result: int) -> bool:
	if is_decided():
		return false
	if result != RoundResult.GUARDIAN and result != RoundResult.OPPONENT:
		if result != RoundResult.DRAW:
			return false
	_results.append(result)
	return true


func rounds_played() -> int:
	return _results.size()


func round_result(index: int) -> int:
	if index < 0 or index >= _results.size():
		return RoundResult.UNRESOLVED
	return _results[index]


func results() -> Array:
	return _results.duplicate()


func guardian_rounds() -> int:
	return _results.count(RoundResult.GUARDIAN)


func opponent_rounds() -> int:
	return _results.count(RoundResult.OPPONENT)


func draw_rounds() -> int:
	return _results.count(RoundResult.DRAW)


func is_decided() -> bool:
	if guardian_rounds() >= ROUNDS_TO_WIN or opponent_rounds() >= ROUNDS_TO_WIN:
		return true
	return rounds_played() >= MAX_ROUNDS


## Vencedor da Peleja: GUARDIAN ou OPPONENT em 2-0 e 2-1; DRAW quando ninguem
## chegou a dois rounds vencidos; NONE enquanto a Peleja nao terminou.
func winner() -> int:
	if guardian_rounds() >= ROUNDS_TO_WIN:
		return Winner.GUARDIAN
	if opponent_rounds() >= ROUNDS_TO_WIN:
		return Winner.OPPONENT
	if is_decided():
		return Winner.DRAW
	return Winner.NONE


func reset() -> void:
	_results.clear()


## Resultado de um round a partir do estado dos dois lutadores e do relogio:
## nocaute vence sempre; com o tempo esgotado vence quem tem mais vida, e vida
## igual empata o round.
static func resolve_round(guardian: Fighter, opponent: Fighter, clock: RoundClock) -> int:
	if guardian == null or opponent == null or clock == null:
		return RoundResult.UNRESOLVED
	var guardian_down := guardian.is_knocked_out()
	var opponent_down := opponent.is_knocked_out()
	if guardian_down and opponent_down:
		return RoundResult.DRAW
	if opponent_down:
		return RoundResult.GUARDIAN
	if guardian_down:
		return RoundResult.OPPONENT
	if not clock.is_expired():
		return RoundResult.UNRESOLVED
	var guardian_ratio := guardian.health.ratio()
	var opponent_ratio := opponent.health.ratio()
	if is_equal_approx(guardian_ratio, opponent_ratio):
		return RoundResult.DRAW
	return RoundResult.GUARDIAN if guardian_ratio > opponent_ratio else RoundResult.OPPONENT
