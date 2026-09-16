class_name GameFlowService
extends RefCounted
## Maquina de navegacao do jogo (ticket 10): qual tela esta em cena e como a
## campanha do arcade anda de uma para a outra.
##
## Estado puro e sem engine: nao conhece cena, caminho de arquivo, tecla nem
## `Node`. Recebe os gateways por injecao (o composition root e o unico lugar que
## instancia adapters) e devolve a PROXIMA tela como DADO -- quem monta e troca a
## cena e a camada app (`scenes/game.gd`).
##
## O encadeamento e o do produto: titulo -> selecao -> Peleja -> (vitoria |
## Reviravolta -> derrota) -> proxima Peleja, e o fim de arcade quando as sete
## terminam. Perder uma Peleja NUNCA encerra a campanha (invariante do ADR 0003).

enum Screen {
	TITLE,
	CHARACTER_SELECT,
	FIGHT,
	REVIRAVOLTA,
	VICTORY,
	DEFEAT,
	ARCADE_END,
	OPTIONS,
}

const SCREEN_NAMES := {
	Screen.TITLE: "title",
	Screen.CHARACTER_SELECT: "character_select",
	Screen.FIGHT: "fight",
	Screen.REVIRAVOLTA: "reviravolta",
	Screen.VICTORY: "victory",
	Screen.DEFEAT: "defeat",
	Screen.ARCADE_END: "arcade_end",
	Screen.OPTIONS: "options",
}

## Chave do progresso da campanha na persistencia (a mesma familia de chave que a
## Reviravolta grava).
const CAMPAIGN_KEY := "arcade/progress"
## Tela para onde o titulo leva ao comecar, e para onde o fim do arcade volta.
const FIRST_SCREEN := Screen.CHARACTER_SELECT
const HOME_SCREEN := Screen.TITLE

var screen: int = Screen.TITLE
var last_winner: int = MatchRules.Winner.NONE
var last_skipped: bool = false

var _arcade: ArcadeService
var _select: CharacterSelectService
var _persistence: PersistenceGateway
## Tela que estava em cena antes das opcoes: fechar devolve o jogador a ela.
var _before_options: int = Screen.TITLE
## Resumo da ULTIMA Peleja fechada. Fica guardado aqui porque, quando o jogador
## segue a campanha, a proxima Peleja ja esta montada e nao pode sobrescrever o
## que a tela de fim esta mostrando.
var _last_summary: Dictionary = {}


func _init(
	p_input: InputGateway,
	p_render: RenderGateway,
	p_asset: AssetGateway,
	p_audio: AudioGateway,
	p_persistence: PersistenceGateway = null
) -> void:
	_arcade = ArcadeService.new(p_input, p_render, p_asset, p_audio)
	_select = CharacterSelectService.new()
	_persistence = p_persistence


func current_screen() -> int:
	return screen


func screen_name() -> String:
	return str(SCREEN_NAMES.get(screen, "title"))


## Tela inicial do arcade: a selecao de Guardiao.
func start() -> int:
	_select.reset()
	screen = FIRST_SCREEN
	return screen


## Abre/feche as opcoes como tela sobre a atual (o `Esc` de qualquer tela).
func open_options() -> int:
	_before_options = screen
	screen = Screen.OPTIONS
	return screen


func close_options() -> int:
	screen = _before_options
	return screen


## A escolha do Guardiao chega como DADO (o resultado do character-select-service)
## e monta o arcade. Guardiao vazio nao muda nada: o jogo nao inventa lutador.
func select_guardian(guardian_name: String) -> int:
	if guardian_name.is_empty():
		return screen
	_select.select(0)
	if not _arcade.execute(ArcadeOrder.ORDER, guardian_name):
		return screen
	screen = Screen.FIGHT
	return screen


## A Peleja terminou. Vitoria do Guardiao leva ao resumo; vitoria do Oponente
## entra na Reviravolta (a regra do dominio decide, nao este servico).
func report_match_finished(winner: int) -> int:
	last_winner = winner
	_last_summary = _build_summary(winner)
	_record_progress(false)
	if winner == MatchRules.Winner.OPPONENT:
		screen = Screen.REVIRAVOLTA
	else:
		screen = Screen.VICTORY
	return screen


## A Reviravolta terminou (com ou sem pulo): a Peleja foi perdida, a campanha
## segue -- a tela de derrota mostra isso e devolve ao encadeamento.
func report_reviravolta_finished(skipped: bool) -> int:
	last_skipped = skipped
	screen = Screen.DEFEAT
	return screen


## Segue a campanha a partir da vitoria ou da derrota: monta a proxima Peleja ou
## fecha o arcade quando as sete terminaram.
func continue_campaign() -> int:
	if _arcade.is_arcade_complete():
		screen = Screen.ARCADE_END
		_record_progress(true)
		return screen
	if _arcade.advance():
		screen = Screen.FIGHT
		return screen
	screen = Screen.ARCADE_END
	_record_progress(true)
	return screen


## Volta ao titulo e desmonta a campanha (a proxima selecao comeca outra).
func back_to_title() -> int:
	_arcade.reset()
	_select.reset()
	last_winner = MatchRules.Winner.NONE
	last_skipped = false
	_last_summary = {}
	screen = HOME_SCREEN
	return screen


func arcade() -> ArcadeService:
	return _arcade


## Peleja corrente do arcade (null fora de uma Peleja montada).
func match_service() -> MatchService:
	return _arcade.match_service


func fight_number() -> int:
	return _arcade.fight_number()


func fight_count() -> int:
	return _arcade.fight_count()


func is_arcade_complete() -> bool:
	return _arcade.is_arcade_complete()


## Resumo da ultima Peleja fechada, para as telas de fim. Nunca inclui os numeros
## da Vantagem Oculta: so o que o jogador le (quem, em que Peleja, por quantos
## rounds).
func result_summary() -> Dictionary:
	if _last_summary.is_empty():
		_last_summary = _build_summary(last_winner)
	return _last_summary.duplicate(true)


## Monta o resumo no momento em que a Peleja fecha -- antes de a proxima ser
## montada.
func _build_summary(winner: int) -> Dictionary:
	var match_service := _arcade.match_service
	return {
		"guardian": _arcade.guardian_name,
		"opponent": _arcade.snapshot()["opponent_name"],
		"opponent_slug": _arcade.opponent_slug(),
		"fight": _arcade.fight_number(),
		"fights": _arcade.fight_count(),
		"winner": winner,
		"guardian_rounds": match_service.rules.guardian_rounds() if match_service != null else 0,
		"opponent_rounds": match_service.rules.opponent_rounds() if match_service != null else 0,
		"skipped": last_skipped,
		"arcade_complete": _arcade.is_arcade_complete(),
		"results": _arcade.results.duplicate(),
	}


## Verdadeiro quando a tela de fim tem uma proxima Peleja para oferecer.
func has_next_fight() -> bool:
	return not _arcade.is_arcade_complete() and _arcade.fight_number() < _arcade.fight_count()


## Grava o progresso da campanha na persistencia. A derrota sempre grava
## `campaign_over: false`: perder a Peleja nunca encerra o arcade.
func _record_progress(complete: bool) -> void:
	if _persistence == null:
		return
	_persistence.save(
		CAMPAIGN_KEY,
		{
			"fight": _arcade.fight_number(),
			"fights": _arcade.fight_count(),
			"campaign_over": complete,
			"last_winner": last_winner,
		}
	)


## Progresso gravado da campanha (vazio quando nunca houve Peleja fechada).
func campaign_progress() -> Dictionary:
	if _persistence == null:
		return {}
	var stored: Variant = _persistence.load_value(CAMPAIGN_KEY, {})
	return stored if typeof(stored) == TYPE_DICTIONARY else {}
