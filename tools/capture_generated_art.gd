extends Control
## Ferramenta de evidencia (fora das camadas do jogo): desenha a arte gerada de
## um slug exatamente como o jogo carrega -- via asset-gateway, na resolucao base
## 426x240 e em escala inteira (3x na janela) -- e grava um PNG para anexar ao PR
## (regra de evidencia do ADR 0006).
##
## Uso: godot --path . tools/capture_generated_art.tscn -- <slug> <saida.png>

const BASE_WIDTH := 426
const BASE_HEIGHT := 240
const DEFAULT_SLUG := "forest-arena"
const DEFAULT_OUTPUT := "res://build/generated_art.png"
const EXPECTED_BYTES := BASE_WIDTH * BASE_HEIGHT * 4


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	var slug: String = arguments[0] if arguments.size() > 0 else DEFAULT_SLUG
	var output: String = arguments[1] if arguments.size() > 1 else DEFAULT_OUTPUT
	anchor_right = 1.0
	anchor_bottom = 1.0
	var pixels: PackedByteArray = _gateway_pixels(slug)
	if pixels.size() != EXPECTED_BYTES:
		push_error("arte indisponivel para o slug %s (%d bytes)" % [slug, pixels.size()])
		get_tree().quit(1)
		return
	var image := Image.create_from_data(
		BASE_WIDTH, BASE_HEIGHT, false, Image.FORMAT_RGBA8, pixels
	)
	var rect := TextureRect.new()
	rect.name = "GeneratedArt"
	rect.texture = ImageTexture.create_from_image(image)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = Vector2(BASE_WIDTH, BASE_HEIGHT)
	add_child(rect)
	print("slug=%s fonte=%s pixels=%d" % [slug, _source(slug), pixels.size()])
	await RenderingServer.frame_post_draw
	var captured := get_viewport().get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := captured.save_png(absolute_path)
	if error != OK:
		push_error("falha ao gravar %s (erro %d)" % [absolute_path, error])
		get_tree().quit(1)
		return
	print("screenshot: %s (%dx%d)" % [absolute_path, captured.get_width(), captured.get_height()])
	get_tree().quit(0)


## Pixels pelo asset-gateway injetado: arte gerada ou fallback em codigo.
func _gateway_pixels(slug: String) -> PackedByteArray:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null or not container.has_method("asset_gateway"):
		return PackedByteArray()
	var gateway: Variant = container.asset_gateway()
	if gateway == null:
		return PackedByteArray()
	return gateway.load_panel(slug, PackedByteArray())


func _source(slug: String) -> String:
	var container: Variant = get_node_or_null("/root/app_container")
	if container != null and container.has_method("asset_gateway"):
		var gateway: Variant = container.asset_gateway()
		if gateway != null and gateway.has_art(slug):
			return "generated"
	return "code-fallback"
