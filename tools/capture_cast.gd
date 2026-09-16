extends Control
## Ferramenta de evidencia do ticket 5 (fora das camadas do jogo): imprime a tela
## de selecao dos 4 Guardioes e cada Guardiao EM LUTA, com a arte do spritesheet
## codificado desenhada pelo `sprite-render-adapter` de producao -- o mesmo que o
## jogo usa --, em escala inteira 3x (regra de evidencia do ADR 0006).
##
## A Peleja de cada print e a de verdade: o `match-service` orquestra os dois
## lutadores, o Guardiao aproxima, enche a Barra de Especial e solta o Golpe
## Especial da lenda; o print sai na janela ativa do golpe. Os retangulos do
## `render_model()` sao pintados como no jogo e o sprite entra por cima, do mesmo
## dado JSON versionado.
##
## Uso: godot --path . tools/capture_cast.tscn -- [diretorio-de-saida]

const SELECT_SCENE := "res://scenes/character_select.tscn"
const DEFAULT_OUTPUT_DIR := "res://docs/evidence"
const PIXEL_SCALE := 3
const SELECT_PREFIX := "ticket-05-select-"
const FIGHT_PREFIX := "ticket-05-fight-"
const SEED_GUARDIAN := 15
const SEED_OPPONENT := 21
const MAX_TICKS := 2400
const HEAVY_RANGE := 30
const GROUND_Y := MatchService.GROUND_Y
const CAPTION_Y := 226
const COLOR_CAPTION := Color8(255, 255, 255)

var _output_dir := DEFAULT_OUTPUT_DIR
var _container: Variant = null
var _renderer: Variant = null
var _asset: Variant = null
var _audio: Variant = null
var _caption: TextureRect = null


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		_output_dir = arguments[0]
	anchor_right = 1.0
	anchor_bottom = 1.0
	_container = get_node_or_null("/root/app_container")
	if _container == null:
		push_error("captura exige o composition root app_container")
		get_tree().quit(1)
		return
	_renderer = _container.render_gateway()
	_asset = _container.asset_gateway()
	_audio = _container.audio_gateway()
	if _renderer == null or not _renderer.has_method("mount"):
		push_error("captura exige o sprite-render-adapter de producao injetado pelo app_container")
		get_tree().quit(1)
		return
	await _capture_selection()
	_renderer.mount(self)
	await _capture_fights()
	get_tree().quit(0)


## A tela de selecao de verdade, com o cursor em cada um dos 4 Guardioes.
func _capture_selection() -> void:
	var screen: Variant = load(SELECT_SCENE).instantiate()
	add_child(screen)
	await get_tree().process_frame
	for index in GuardianStats.count():
		screen.select_index(index)
		await get_tree().process_frame
		var slug: String = str(screen.selection()["slug"])
		await _save("%s%s.png" % [SELECT_PREFIX, slug], "selecao cursor=%d" % index)
	screen.queue_free()
	await get_tree().process_frame


## Uma Peleja de verdade por Guardiao, com o print na janela ativa do Especial.
func _capture_fights() -> void:
	for guardian_name in GuardianStats.all():
		var slug := GuardianStats.slug_for(guardian_name)
		var service := MatchService.new(
			SampleInputGateway.new(), _renderer, _asset, _audio
		)
		service.configure(guardian_name, Archetype.Id.CAPATAZ, SEED_GUARDIAN, SEED_OPPONENT)
		_drive_to_special(service)
		_draw_fight(service, slug)
		_set_caption("%s - %s" % [guardian_name, service.special_effect.display_name])
		var state := service.snapshot()
		await _save(
			"%s%s.png" % [FIGHT_PREFIX, slug],
			"golpe=%s janela_ativa=%s vida_guardiao=%d vida_oponente=%d"
			% [
				service.special_effect.display_name,
				state["special_active"],
				service.guardian.health.current,
				service.opponent.health.current,
			]
		)


## Joga a Peleja pelo input-gateway sample ate a janela ativa do Golpe Especial.
func _drive_to_special(service: MatchService) -> void:
	var gateway: SampleInputGateway = service.input_gateway()
	service.guardian.meter.gain(SpecialMeter.MAX_UNITS)
	var ticks := 0
	while ticks < MAX_TICKS and not service.guardian.is_move_active():
		gateway.script_commands([_command_for(service)])
		service.advance_tick()
		ticks += 1


## O comando que o jogador daria neste tick: fechar a distancia e, com a barra
## cheia, soltar o Golpe Especial.
func _command_for(service: MatchService) -> int:
	if service.guardian.meter.is_full():
		return InputGateway.Command.SPECIAL
	var gap := service.opponent.hurtbox().horizontal_distance_to(service.guardian.hurtbox())
	if gap > HEAVY_RANGE:
		return InputGateway.Command.MOVE_RIGHT
	return InputGateway.Command.HEAVY


## Arena do `render_model()` mais o sprite do Guardiao no chao, escala 3x.
func _draw_fight(service: MatchService, slug: String) -> void:
	_renderer.clear()
	for entry in service.render_model():
		_renderer.draw_rect(entry["rect"], entry["color"])
	var sheet := _sheet(slug)
	if sheet != null:
		var animation_name := _animation_of(service)
		var frame_index := sheet.frame_count(animation_name) - 1
		var size := sheet.frame_size(animation_name, frame_index)
		var origin := Vector2i(
			service.guardian.position.x - size.x * PIXEL_SCALE / 2,
			GROUND_Y - size.y * PIXEL_SCALE
		)
		if not _renderer.draw_sprite(sheet, animation_name, frame_index, origin, PIXEL_SCALE):
			push_error("frame %s[%d] nao desenhou" % [animation_name, frame_index])
	_renderer.present()


## Animacao do print: a do Golpe Especial na janela ativa, senao a do estado.
func _animation_of(service: MatchService) -> String:
	if service.guardian.is_move_active() and service.guardian.current_move.is_special():
		return "special"
	if service.guardian.is_attacking():
		return "heavy"
	return "idle"


func _sheet(slug: String) -> Spritesheet:
	var data: Dictionary = _asset.load_spritesheet(slug)
	if data.is_empty():
		push_error("spritesheet codificado ausente para o slug %s" % slug)
		return null
	var sheet := Spritesheet.decode(data)
	if not sheet.is_valid():
		push_error("spritesheet invalido: %s" % [sheet.errors()])
	return sheet


## Legenda do print (nome e Golpe Especial), em caixa alta pela fonte bitmap.
func _set_caption(text: String) -> void:
	if _caption != null:
		_caption.queue_free()
	_caption = TextureRect.new()
	_caption.name = "Caption"
	_caption.texture = BitmapFont.make_texture(text, COLOR_CAPTION, 1)
	_caption.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_caption.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_caption.position = Vector2(4, CAPTION_Y)
	_caption.size = Vector2(_caption.texture.get_size())
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)


## Grava o frame atual como PNG em `docs/evidence/` (426x240).
func _save(file_name: String, note: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var relative := _output_dir.path_join(file_name)
	var absolute := ProjectSettings.globalize_path(relative)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error := image.save_png(absolute)
	if error != OK:
		push_error("falha ao gravar %s (erro %d)" % [absolute, error])
		get_tree().quit(1)
		return
	print(
		"screenshot: %s (%dx%d) %s"
		% [absolute, image.get_width(), image.get_height(), note]
	)