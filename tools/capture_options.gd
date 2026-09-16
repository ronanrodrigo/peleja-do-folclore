extends Control
## Ferramenta de evidencia (fora das camadas do jogo): abre a tela de opcoes de
## producao, mexe no volume e no mudo PELO CASO DE USO real (`OptionsService`,
## pelos gateways injetados pelo composition root) e grava um PNG 426x240 por
## estado em `docs/evidence/ticket-08-<estado>.png` (regra de evidencia do ADR 0006).
##
## O gesto do jogador e declarado explicitamente porque e ele que destrava o audio
## no navegador: a ferramenta faz o papel do primeiro clique.
##
## Uso: godot --path . tools/capture_options.tscn -- [diretorio-de-saida]

const OPTIONS_SCENE := "res://scenes/options_screen.tscn"
const DEFAULT_OUTPUT_DIR := "res://docs/evidence"
const FILE_PREFIX := "ticket-08-"
const READY_FRAMES := 2
const VOLUME_PERCENT := 70

var _output_dir := DEFAULT_OUTPUT_DIR


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		_output_dir = arguments[0]
	anchor_right = 1.0
	anchor_bottom = 1.0
	var screen: Control = load(OPTIONS_SCENE).instantiate()
	add_child(screen)
	for _frame in READY_FRAMES:
		await get_tree().process_frame
	screen.declare_gesture()
	screen.set_volume_percent(VOLUME_PERCENT)
	screen.refresh()
	await _capture(screen, "options-volume-%d" % VOLUME_PERCENT)
	screen.toggle_mute()
	screen.refresh()
	await _capture(screen, "options-muted")
	screen.toggle_mute()
	screen.set_volume_percent(VOLUME_PERCENT)
	screen.refresh()
	print(
		"options volume=%d%% mudo=%s servico=%s"
		% [screen.volume_percent(), screen.is_muted(), screen.options_service != null]
	)
	get_tree().quit(0)


## Grava o frame corrente do viewport (426x240) em PNG.
func _capture(screen: Control, state_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var relative := _output_dir.path_join("%s%s.png" % [FILE_PREFIX, state_name])
	var absolute := ProjectSettings.globalize_path(relative)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error := image.save_png(absolute)
	if error != OK:
		push_error("falha ao gravar %s (erro %d)" % [absolute, error])
		get_tree().quit(1)
		return
	print(
		"screenshot: %s (%dx%d) volume=%d%% mudo=%s"
		% [
			absolute,
			image.get_width(),
			image.get_height(),
			screen.volume_percent(),
			screen.is_muted(),
		]
	)