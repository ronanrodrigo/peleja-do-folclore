extends Control
## Raiz de navegacao do jogo (camada app) -- a tela principal do projeto.
##
## Unico lugar do jogo que conhece os CAMINHOS das cenas e o unico que troca a
## tela em cena. Nenhuma regra de campanha mora aqui: a decisao de qual tela vem
## depois e do `GameFlowService` (aplicacao), que devolve a proxima tela como
## DADO. Aqui so se monta a cena pedida, se ligam os sinais e se entrega o dado
## (o arcade, o resumo da Peleja).
##
## Nenhum adapter concreto e instanciado nesta cena: os gateways vem do
## composition root `app_container`, e o estado da campanha vive no servico, que
## sobrevive a troca de tela -- voltar a Peleja retoma a mesma partida.

const SCENES := {
	GameFlowService.Screen.TITLE: "res://scenes/title_screen.tscn",
	GameFlowService.Screen.CHARACTER_SELECT: "res://scenes/character_select.tscn",
	GameFlowService.Screen.FIGHT: "res://scenes/fight.tscn",
	GameFlowService.Screen.REVIRAVOLTA: "res://scenes/reviravolta_panel.tscn",
	GameFlowService.Screen.VICTORY: "res://scenes/victory_screen.tscn",
	GameFlowService.Screen.DEFEAT: "res://scenes/defeat_screen.tscn",
	GameFlowService.Screen.ARCADE_END: "res://scenes/arcade_end_screen.tscn",
	GameFlowService.Screen.OPTIONS: "res://scenes/options_screen.tscn",
}

## Telas que abrem as opcoes pelo proprio comando de cancelar (a tela de titulo
## ja monta o menu como filha; a de opcoes fecha a si mesma).
const SELF_HANDLES_CANCEL := [
	GameFlowService.Screen.TITLE,
	GameFlowService.Screen.OPTIONS,
]

var flow: GameFlowService
var current_screen: Control = null


func _ready() -> void:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null:
		push_error("scenes/game.tscn exige o composition root app_container")
		return
	flow = GameFlowService.new(
		container.input_gateway(),
		container.render_gateway(),
		container.asset_gateway(),
		container.audio_gateway(),
		container.persistence_gateway()
	)
	show_screen(flow.current_screen())


## Nome da tela em cena (`GameFlowService.SCREEN_NAMES`).
func screen_name() -> String:
	return flow.screen_name() if flow != null else ""


## Troca a tela em cena pela tela pedida, entregando o dado que ela precisa.
func show_screen(screen: int) -> void:
	if flow == null:
		return
	var path := str(SCENES.get(screen, ""))
	if path.is_empty():
		return
	_clear_current()
	var scene: Control = (load(path) as PackedScene).instantiate()
	current_screen = scene
	_configure_scene(scene, screen)
	add_child(scene)
	flow.screen = screen


## Abre as opcoes sobre a tela atual (o `Esc` das telas de jogo).
func open_options() -> void:
	show_screen(flow.open_options())


## `_unhandled_input` da raiz: o `Esc` de qualquer tela de jogo abre as opcoes. A
## cena em cena recebe o evento antes desta raiz; quem trata o cancelar sozinha
## nao cai aqui.
func _unhandled_input(event: InputEvent) -> void:
	if flow == null or not event.is_action_pressed("ui_cancel"):
		return
	if SELF_HANDLES_CANCEL.has(flow.current_screen()):
		return
	get_viewport().set_input_as_handled()
	open_options()


func _clear_current() -> void:
	if current_screen != null and is_instance_valid(current_screen):
		remove_child(current_screen)
		current_screen.queue_free()
	current_screen = null


## Liga a cena ao fluxo: entrega o dado que ela precisa e conecta o sinal que ela
## emite ao proximo passo do fluxo.
func _configure_scene(scene: Control, screen: int) -> void:
	match screen:
		GameFlowService.Screen.TITLE:
			scene.started.connect(_on_title_started)
		GameFlowService.Screen.CHARACTER_SELECT:
			scene.guardian_selected.connect(_on_guardian_selected)
		GameFlowService.Screen.FIGHT:
			scene.set("arcade", flow.arcade())
			scene.match_finished.connect(_on_match_finished)
		GameFlowService.Screen.REVIRAVOLTA:
			scene.winner_result = flow.last_winner
			scene.fight_number = maxi(flow.fight_number(), 1)
			scene.panel_finished.connect(_on_panel_finished)
		GameFlowService.Screen.VICTORY, GameFlowService.Screen.DEFEAT:
			scene.configure(flow.result_summary())
			scene.confirmed.connect(_on_result_confirmed)
		GameFlowService.Screen.ARCADE_END:
			scene.configure(flow.result_summary())
			scene.confirmed.connect(_on_arcade_end_confirmed)
		GameFlowService.Screen.OPTIONS:
			scene.closed.connect(_on_options_closed)


func _on_title_started() -> void:
	show_screen(flow.start())


func _on_guardian_selected(guardian_name: String) -> void:
	show_screen(flow.select_guardian(guardian_name))


func _on_match_finished(winner: int) -> void:
	show_screen(flow.report_match_finished(winner))


func _on_panel_finished(skipped: bool) -> void:
	show_screen(flow.report_reviravolta_finished(skipped))


func _on_result_confirmed() -> void:
	show_screen(flow.continue_campaign())


func _on_arcade_end_confirmed() -> void:
	show_screen(flow.back_to_title())


func _on_options_closed() -> void:
	show_screen(flow.close_options())
