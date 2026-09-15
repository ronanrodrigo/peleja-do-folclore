extends Node
## Ferramenta de evidencia (fora das camadas do jogo): abre a tela de titulo,
## espera o primeiro frame desenhado e grava um PNG. Usada para anexar print ao
## PR, conforme a regra de evidencia do ADR 0006.
##
## Uso: godot --path . tools/capture_title_screen.tscn -- <caminho-de-saida>

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const DEFAULT_OUTPUT := "res://build/title_screen.png"

var _output_path := DEFAULT_OUTPUT


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		_output_path = arguments[0]
	add_child(load(TITLE_SCENE).instantiate())
	# 0.25s cai na fase visivel do aviso piscante (BLINK_INTERVAL = 0.55).
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("falha ao gravar %s (erro %d)" % [absolute_path, error])
		get_tree().quit(1)
		return
	print("screenshot: %s (%dx%d)" % [absolute_path, image.get_width(), image.get_height()])
	get_tree().quit(0)