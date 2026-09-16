extends Control
## Ferramenta de evidencia (fora das camadas do jogo): desenha CADA animacao do
## Saci com o renderer de producao injetado pelo composition root -- o mesmo
## `sprite-render-adapter` que o jogo usa -- e grava um PNG por animacao em
## `docs/evidence/ticket-04-saci-<animacao>.png` (regra de evidencia do ADR 0006).
##
## A arte vem do spritesheet codificado, pelo asset-gateway, e nao de imagem
## binaria: o print mostra o dado versionado desenhado em escala inteira 3x.
##
## Uso: godot --path . tools/capture_saci.tscn -- [diretorio-de-saida]

const SPRITESHEET_SLUG := "saci"
const DEFAULT_OUTPUT_DIR := "res://docs/evidence"
const PIXEL_SCALE := RenderGateway.DEFAULT_PIXEL_SCALE
const BASE_SIZE := Vector2i(426, 240)
const GAP := 6
const FILE_PREFIX := "ticket-04-saci-"

var _output_dir := DEFAULT_OUTPUT_DIR


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		_output_dir = arguments[0]
	var sheet := _sheet()
	if sheet == null or not sheet.is_valid():
		get_tree().quit(1)
		return
	var renderer: Variant = _production_renderer()
	if renderer == null:
		push_error("captura exige o sprite-render-adapter de producao injetado pelo app_container")
		get_tree().quit(1)
		return
	anchor_right = 1.0
	anchor_bottom = 1.0
	renderer.mount(self)
	var written := 0
	for animation_name in sheet.animation_names():
		await _capture(renderer, sheet, animation_name)
		written += 1
	print(
		"spritesheet=%s animacoes=%d escala=%dx frames=%d"
		% [SPRITESHEET_SLUG, written, PIXEL_SCALE, _total_frames(sheet)]
	)
	get_tree().quit(0)


## Desenha todos os quadros da animacao, lado a lado, no centro da resolucao base.
func _capture(renderer: Variant, sheet: Spritesheet, animation_name: String) -> void:
	var count := sheet.frame_count(animation_name)
	var frame_size := sheet.frame_size(animation_name, 0)
	var drawn := frame_size * PIXEL_SCALE
	var total_width := count * drawn.x + (count - 1) * GAP
	var origin := Vector2i(
		(BASE_SIZE.x - total_width) / 2,
		(BASE_SIZE.y - drawn.y) / 2
	)
	renderer.clear()
	renderer.draw_rect(Rect2i(0, BASE_SIZE.y - 24, BASE_SIZE.x, 24), Color8(34, 26, 46))
	for frame_index in count:
		var position := origin + Vector2i(frame_index * (drawn.x + GAP), 0)
		if not renderer.draw_sprite(sheet, animation_name, frame_index, position, PIXEL_SCALE):
			push_error("frame %s[%d] nao desenhou" % [animation_name, frame_index])
	renderer.present()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var relative := _output_dir.path_join("%s%s.png" % [FILE_PREFIX, animation_name])
	var absolute := ProjectSettings.globalize_path(relative)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error := image.save_png(absolute)
	if error != OK:
		push_error("falha ao gravar %s (erro %d)" % [absolute, error])
		get_tree().quit(1)
		return
	print(
		"screenshot: %s (%dx%d) %s frames=%d quadro=%dx%d"
		% [
			absolute,
			image.get_width(),
			image.get_height(),
			animation_name,
			count,
			frame_size.x,
			frame_size.y,
		]
	)


## Spritesheet pelo asset-gateway injetado (o mesmo caminho do jogo).
func _sheet() -> Spritesheet:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null:
		push_error("captura exige o composition root app_container")
		return null
	var gateway: Variant = container.asset_gateway()
	if gateway == null:
		push_error("asset-gateway indisponivel")
		return null
	var data: Dictionary = gateway.load_spritesheet(SPRITESHEET_SLUG)
	if data.is_empty():
		push_error("spritesheet codificado ausente para o slug %s" % SPRITESHEET_SLUG)
		return null
	var sheet := Spritesheet.decode(data)
	if not sheet.is_valid():
		push_error("spritesheet invalido: %s" % [sheet.errors()])
	return sheet


## Renderer de producao injetado pelo composition root (nunca instanciado aqui).
func _production_renderer() -> Variant:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null:
		return null
	var renderer: Variant = container.render_gateway()
	if renderer == null or not renderer.has_method("mount"):
		return null
	return renderer


func _total_frames(sheet: Spritesheet) -> int:
	var total := 0
	for animation_name in sheet.animation_names():
		total += sheet.frame_count(animation_name)
	return total
