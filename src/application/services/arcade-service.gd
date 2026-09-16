class_name ArcadeService
extends RefCounted
## Caso de uso do Arcade (ADR 0007): as 7 Pelejas, uma por Arquetipo, em ordem
## FIXA e dificuldade crescente, sem chefe final e sem modo versus.
##
## A ordem chega como DADO do chamador, nunca de uma constante escondida aqui:
## `execute(order, guardian_name)` recebe a sequencia e o Guardiao escolhido. O
## Guardiao tambem pode chegar como comando, por `select_guardian`: quem decide a
## selecao e o character-select-service (ticket 5) e esta camada apenas RECEBE o
## resultado. Nao ha import de um servico no outro -- a comunicacao e por dado --
## e o Oponente NUNCA e escolhido pelo jogador (invariante 3 de
## docs/architecture.md).
##
## Nenhum estado em singleton: a Peleja corrente vive no `MatchService`, que
## recebe os gateways do composition root por injecao.

const DEFAULT_GUARDIAN := GuardianStats.SACI
const DEFAULT_GUARDIAN_SEED := 20260915
const DEFAULT_OPPONENT_SEED := 7
## Passo da semente do Oponente por posicao: cada Peleja do arcade e reproduzivel
## sozinha, e duas Pelejas vizinhas nao compartilham a mesma sequencia.
const OPPONENT_SEED_STEP := 17
## Nivel de IA por posicao no arcade: dado, nunca um `if` espalhado. A escada sobe
## (easy -> normal -> hard) junto com a vida e o dano de `OpponentStats`.
const DIFFICULTY_LADDER := [
	OpponentAi.Difficulty.EASY,
	OpponentAi.Difficulty.EASY,
	OpponentAi.Difficulty.NORMAL,
	OpponentAi.Difficulty.NORMAL,
	OpponentAi.Difficulty.NORMAL,
	OpponentAi.Difficulty.HARD,
	OpponentAi.Difficulty.HARD,
]

## Ordem fixa como dado de referencia; o chamador pode injetar outra (teste).
var order: Array = []
var guardian_name: String = DEFAULT_GUARDIAN
var guardian_seed: int = DEFAULT_GUARDIAN_SEED
var opponent_seed: int = DEFAULT_OPPONENT_SEED
## Posicao (base zero) da Peleja corrente na ordem.
var index: int = 0
## Peleja corrente; null antes do `execute` e quando ele recusa a ordem.
var match_service: MatchService
## Resultado de cada Peleja fechada, na ordem em que aconteceram.
var results: Array = []

var _input_gateway: InputGateway
var _render_gateway: RenderGateway
var _asset_gateway: AssetGateway
var _audio_gateway: AudioGateway
var _result_recorded: bool = false


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


## Entrada do caso de uso: a ordem (dado) e o Guardiao escolhido (dado). Lista
## vazia usa a ordem fixa do ADR 0007. Devolve falso sem comecar quando a ordem
## nao cobre cada um dos 7 Arquetipos exatamente uma vez.
func execute(
	order_data: Array = [],
	p_guardian_name: String = DEFAULT_GUARDIAN,
	p_guardian_seed: int = DEFAULT_GUARDIAN_SEED,
	p_opponent_seed: int = DEFAULT_OPPONENT_SEED
) -> bool:
	var data: Array = order_data if not order_data.is_empty() else ArcadeOrder.ORDER
	if not is_valid_order(data):
		order = []
		match_service = null
		index = 0
		results.clear()
		return false
	order = data.duplicate()
	guardian_name = p_guardian_name
	guardian_seed = p_guardian_seed
	opponent_seed = p_opponent_seed
	index = 0
	results.clear()
	return _start_current_fight()


## Desmonta o arcade: nenhuma Peleja corrente, ordem vazia e resultados limpos.
## E o que a volta ao titulo faz (ticket 10) -- a proxima campanha comeca do zero.
func reset() -> void:
	order = []
	match_service = null
	index = 0
	results.clear()
	_result_recorded = false


## Comando de selecao de Guardiao: a escolha chega como DADO de quem chama (o
## character-select-service devolve exatamente este nome). Vale para a proxima
## Peleja montada, nunca para a que ja esta em andamento.
func select_guardian(p_guardian_name: String) -> bool:
	if p_guardian_name.is_empty():
		return false
	guardian_name = p_guardian_name
	return true


## Ordem valida: 7 posicoes, cada Arquetipo exatamente uma vez.
func is_valid_order(data: Array) -> bool:
	if data.size() != Archetype.count():
		return false
	for archetype in Archetype.ALL:
		if data.count(archetype) != 1:
			return false
	return true


func fight_count() -> int:
	return order.size()


## Numero da Peleja corrente, base um (0 antes do `execute`).
func fight_number() -> int:
	return index + 1 if match_service != null else 0


## Arquetipo da Peleja corrente, ou -1 quando o arcade nao esta montado.
func current_archetype() -> int:
	if order.is_empty() or index >= order.size():
		return -1
	return order[index]


## Perfil do Oponente da Peleja corrente (aparencia, golpe proprio e IA).
func current_profile() -> OpponentProfile:
	return OpponentProfile.for_archetype(current_archetype())


## Numeros do Oponente da Peleja corrente, na dificuldade da posicao dele.
func current_opponent_stats() -> OpponentStats:
	return OpponentStats.for_archetype(current_archetype())


func opponent_slug() -> String:
	return Archetype.slug(current_archetype())


## Nivel de IA da posicao pedida no arcade. Fora da escada, NORMAL.
func difficulty_for(position: int) -> int:
	if position < 0 or position >= DIFFICULTY_LADDER.size():
		return OpponentAi.Difficulty.NORMAL
	return DIFFICULTY_LADDER[position]


func current_difficulty() -> int:
	return difficulty_for(index)


func is_active() -> bool:
	return match_service != null and match_service.is_active()


## Verdadeiro quando a ultima Peleja do arcade terminou.
func is_arcade_complete() -> bool:
	if match_service == null or not match_service.is_match_over():
		return false
	return index + 1 >= order.size()


## Verdadeiro quando a Reviravolta entra em cena: a Peleja fechada foi vencida
## pelo Oponente (regra pura em `ReviravoltaRule`). Nao encerra nada -- `advance()`
## continua valendo e a campanha nunca acaba por derrota: quem perde uma Peleja
## perde a Peleja, nao o arcade.
func requires_reviravolta() -> bool:
	if match_service == null or not match_service.is_match_over():
		return false
	return ReviravoltaRule.triggers(match_service.winner())


## Avanca um tick da Peleja corrente e devolve o retrato do arcade.
func advance_tick() -> Dictionary:
	if match_service != null:
		match_service.advance_tick()
		if match_service.is_match_over() and not _result_recorded:
			_record_current_result()
	return snapshot()


## Fecha a Peleja vencida/empatada e comeca a proxima. Recusa enquanto a Peleja
## atual nao acabou e quando nao ha proxima: e assim que o arcade avanca, uma
## Peleja por Arquetipo, sem sorteio e sem game over de campanha.
func advance() -> bool:
	if match_service == null or not match_service.is_match_over():
		return false
	if index + 1 >= order.size():
		return false
	index += 1
	return _start_current_fight()


func render_frame() -> void:
	if match_service != null:
		match_service.render_frame()


## Retrato do arcade: posicao, Arquetipo, perfil do Oponente, dificuldade e a
## Peleja corrente. Nao inclui os numeros da Vantagem Oculta.
func snapshot() -> Dictionary:
	var profile := current_profile()
	return {
		"fight": fight_number(),
		"fights": fight_count(),
		"archetype": current_archetype(),
		"opponent_slug": profile.slug if profile != null else "",
		"opponent_name": profile.display_name if profile != null else "",
		"opponent_signature": profile.signature_name if profile != null else "",
		"opponent_steals_meter": profile.steals_meter() if profile != null else false,
		"difficulty": OpponentAi.difficulty_name(current_difficulty()),
		"guardian": guardian_name,
		"order": order.duplicate(),
		"results": results.duplicate(),
		"complete": is_arcade_complete(),
		"match": match_service.snapshot() if match_service != null else {},
	}


## Slugs dos Oponentes na ordem em que o arcade vai enfrenta-los.
func opponent_slugs() -> PackedStringArray:
	var slugs := PackedStringArray()
	for archetype in order:
		slugs.append(Archetype.slug(archetype))
	return slugs


func _start_current_fight() -> bool:
	var archetype := current_archetype()
	if archetype < 0:
		return false
	var service := MatchService.new(
		_input_gateway, _render_gateway, _asset_gateway, _audio_gateway
	)
	var configured := service.configure(
		guardian_name,
		archetype,
		guardian_seed + index,
		opponent_seed + index * OPPONENT_SEED_STEP,
		difficulty_for(index)
	)
	if not configured:
		match_service = null
		return false
	match_service = service
	_result_recorded = false
	return true


## Guarda o resultado da Peleja fechada. Uma Peleja entra uma vez so na lista.
func _record_current_result() -> void:
	_result_recorded = true
	results.append(
		{
			"index": index,
			"archetype": current_archetype(),
			"slug": opponent_slug(),
			"winner": match_service.winner(),
			"guardian_rounds": match_service.rules.guardian_rounds(),
			"opponent_rounds": match_service.rules.opponent_rounds(),
		}
	)
