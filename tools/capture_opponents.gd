extends Control
## Ferramenta de evidencia do ticket 6 (fora das camadas do jogo): desenha CADA UM
## DOS 7 Oponentes do arcade com o renderer de producao injetado pelo composition
## root -- o mesmo `sprite-render-adapter` que o jogo usa -- e grava um PNG por
## Oponente em `docs/evidence/ticket-06-<slug>.png` (regra de evidencia do ADR 0006).
##
## A arte vem dos spritesheets codificados, pelo asset-gateway, e nao de imagem
## binaria: cada print mostra o dado versionado desenhado em escala inteira 3x,
## com o corpo parado, o passo, a guarda, o golpe pesado, o GOLPE PROPRIO do
## Arquetipo e o nocaute -- o suficiente para distinguir os sete a olho.
##
## Uso: godot --path . tools/capture_opponents.tscn -- [diretorio-de-saida]

const DEFAULT_OUTPUT_DIR := "res://docs/evidence"
const PIXEL_SCALE := RenderGateway.DEFAULT_PIXEL_SCALE
const BASE_SIZE := Vector2i(426, 240)
const COLUMN_GAP := 10
const ROW_GAP := 6
const FILE_PREFIX := "ticket-06-"
## Dois andares de tres quadros: o de cima e o corpo, o de baixo e o golpe.
const ROWS := [
	[["idle", 0], ["walk", 2], ["block", 0]],
	[["heavy", 1], ["special", 2], ["ko", 0]],
]
const GROUND_COLOR := Color8(34, 26, 46)
const BACKDROP_COLOR := Color8(18, 18, 42)

var _output_dir := DEFAULT_OUTPUT_DIR


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		_output_dir = arguments[0]
	var renderer: Variant = _production_renderer()
	if renderer == null:
		push_error("captura exige o sprite-render-adapter de producao injetado pelo app_container")
		get_tree().quit(1)
		return
	anchor_right = 1.0
	anchor_bottom = 1.0
	renderer.mount(self)
	var gateway: Variant = _asset_gateway()
	if gateway == null:
		get_tree().quit(1)
		return
	var written := 0
	for archetype in ArcadeOrder.ORDER:
		var profile := OpponentProfile.for_archetype(archetype)
		var sheet := _sheet(gateway, profile.slug)
		if sheet == null or not sheet.is_valid():
			push_error("spritesheet invalido para %s" % profile.slug)
			get_tree().quit(1)
			return
		await _capture(renderer, sheet, profile)
		written += 1
	print("oponentes=%d prontos=%d escala=%dx" % [ArcadeOrder.count(), written, PIXEL_SCALE])
	get_tree().quit(0)


## Desenha os seis quadros-chave do Oponente em dois andares, no centro da
## resolucao base, e grava o print.
func _capture(renderer: Variant, sheet: Spritesheet, profile: OpponentProfile) -> void:
	renderer.clear()
	renderer.draw_rect(Rect2i(0, 0, BASE_SIZE.x, BASE_SIZE.y), BACKDROP_COLOR)
	var heights := _row_heights(sheet)
	var total := 0
	for height in heights:
		total += height
	total += ROW_GAP * (heights.size() - 1)
	var y := (BASE_SIZE.y - total) / 2
	for row_index in ROWS.size():
		_draw_row(renderer, sheet, ROWS[row_index], y, heights[row_index])
		renderer.draw_rect(Rect2i(0, y + heights[row_index], BASE_SIZE.x, 2), GROUND_COLOR)
		y += heights[row_index] + ROW_GAP
	renderer.present()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var relative := _output_dir.path_join("%s%s.png" % [FILE_PREFIX, profile.slug])
	var absolute := ProjectSettings.globalize_path(relative)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error := image.save_png(absolute)
	if error != OK:
		push_error("falha ao gravar %s (erro %d)" % [absolute, error])
		get_tree().quit(1)
		return
	print(
		"print: %s (%dx%d) oponente=%s nome=%s golpe=%s cobra_barra=%s ai_signature=%.2f"
		% [
			absolute,
			image.get_width(),
			image.get_height(),
			profile.slug,
			profile.display_name,
			profile.signature_name,
			profile.steals_meter(),
			profile.signature_chance(),
		]
	)


func _draw_row(renderer: Variant, sheet: Spritesheet, row: Array, y: int, height: int) -> void:
	var width := 0
	for frame in row:
		width += _frame_size(sheet, frame).x * PIXEL_SCALE
	width += COLUMN_GAP * (row.size() - 1)
	var x := (BASE_SIZE.x - width) / 2
	for frame in row:
		var size := _frame_size(sheet, frame)
		var position := Vector2i(x, y + height - size.y * PIXEL_SCALE)
		var animation_name: String = str(frame[0])
		var frame_index: int = int(frame[1])
		if not renderer.draw_sprite(sheet, animation_name, frame_index, position, PIXEL_SCALE):
			push_error("quadro %s[%d] nao desenhou" % [animation_name, frame_index])
		x += size.x * PIXEL_SCALE + COLUMN_GAP


func _frame_size(sheet: Spritesheet, frame: Array) -> Vector2i:
	return sheet.frame_size(str(frame[0]), int(frame[1]))


## Altura de cada andar: o quadro mais alto da linha, em escala inteira.
func _row_heights(sheet: Spritesheet) -> Array:
	var heights: Array = []
	for row in ROWS:
		var tallest := 0
		for frame in row:
			tallest = maxi(tallest, _frame_size(sheet, frame).y * PIXEL_SCALE)
		heights.append(tallest)
	return heights


## Spritesheet pelo asset-gateway injetado (o mesmo caminho do jogo).
func _sheet(gateway: Variant, slug: String) -> Spritesheet:
	var data: Dictionary = gateway.load_spritesheet(slug)
	if data.is_empty():
		push_error("spritesheet codificado ausente para o slug %s" % slug)
		return null
	var sheet := Spritesheet.decode(data)
	if not sheet.is_valid():
		push_error("spritesheet invalido (%s): %s" % [slug, sheet.errors()])
	return sheet


func _asset_gateway() -> Variant:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null:
		push_error("captura exige o composition root app_container")
		return null
	return container.asset_gateway()


## Renderer de producao injetado pelo composition root (nunca instanciado aqui).
func _production_renderer() -> Variant:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null:
		return null
	var renderer: Variant = container.render_gateway()
	if renderer == null or not renderer.has_method("mount"):
		return null
	return renderer
