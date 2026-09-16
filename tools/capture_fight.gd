extends Node
## Ferramenta de evidencia (fora das camadas do jogo): abre a cena de luta,
## joga uma Peleja inteira com o input-gateway `sample` e grava prints em
## docs/evidence/. Conforme a regra de evidencia do ADR 0006.
##
## Uso: godot --path . tools/capture_fight.tscn -- <diretorio-de-saida>
##
## A entrada e automatizada pelo proprio gateway (scripts de comando), nunca por
## teclado sintetico: o comportamento e reproduzivel pela semente.

const FIGHT_SCENE := "res://scenes/fight.tscn"
const CONTAINER_PATH := "/root/app_container"
const DEFAULT_OUTPUT_DIR := "res://docs/evidence"
const SAMPLE_ENV := "sample"
const MAX_TICKS := 14000
const ROUND_CAPTURE_MIN_TICK := 360
const ATTACK_RANGE := 22
const SPECIAL_RANGE := 40

var _output_dir := DEFAULT_OUTPUT_DIR
var _beat := 0


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		_output_dir = arguments[0]
	OS.set_environment("PELEJA_ADAPTERS", SAMPLE_ENV)
	var container: Variant = get_node_or_null(CONTAINER_PATH)
	if container == null:
		push_error("captura exige o composition root app_container")
		get_tree().quit(1)
		return
	container.wire()
	var scene: Variant = load(FIGHT_SCENE).instantiate()
	add_child(scene)
	scene.auto_run = false
	var gateway: Variant = scene.input_gateway()
	await get_tree().process_frame
	var captured_round_one := false
	var captured_round_two := false
	var tick := 0
	while tick < MAX_TICKS:
		gateway.script_commands([_command_for(scene)])
		var state: Dictionary = scene.simulate_tick()
		_beat += 1
		if not captured_round_one and state["round"] == 1 and tick >= ROUND_CAPTURE_MIN_TICK:
			await _save(scene, "round1")
			captured_round_one = true
		if not captured_round_two and state["round"] == 2:
			await _save(scene, "round2")
			captured_round_two = true
		if scene.match_service.is_match_over():
			break
		tick += 1
	await _save(scene, "result")
	print("peleja encerrada em %d ticks (vencedor=%d)" % [tick, scene.match_service.winner()])
	print("resultados dos rounds: %s" % [scene.match_service.rules.results()])
	get_tree().quit(0)


## Guardiao automatizado: fecha a distancia, golpeia e usa o Especial quando a
## barra enche. Deterministico, sem tocar no teclado real.
func _command_for(scene: Variant) -> int:
	var service: MatchService = scene.match_service
	var gap := service.opponent.hurtbox().horizontal_distance_to(service.guardian.hurtbox())
	if service.guardian.meter.is_full() and gap <= SPECIAL_RANGE:
		return InputGateway.Command.SPECIAL
	if gap > ATTACK_RANGE:
		return InputGateway.Command.MOVE_RIGHT
	return InputGateway.Command.HEAVY if _beat % 8 == 0 else InputGateway.Command.LIGHT


func _save(scene: Variant, label: String) -> void:
	scene.draw_frame()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var relative := _output_dir.path_join("ticket-03-fight-%s.png" % label)
	var absolute := ProjectSettings.globalize_path(relative)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error := image.save_png(absolute)
	if error != OK:
		push_error("falha ao gravar %s (erro %d)" % [absolute, error])
		get_tree().quit(1)
		return
	print("screenshot: %s (%dx%d)" % [absolute, image.get_width(), image.get_height()])
