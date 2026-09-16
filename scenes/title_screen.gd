extends Control
## Tela de titulo (camada app).
##
## Fina: monta nos, conecta sinais e delega. A arte e placeholder e vive em
## dados dentro desta cena -- nenhum asset externo, nenhum PNG, nenhuma fonte
## de terceiros. O desenho acontece na resolucao base 426x240 e sobe em escala
## inteira (3x no titulo, 2x no aviso), com filtro nearest; o texto sai da fonte
## bitmap compartilhada (`PixelFont`), a mesma da tela de opcoes.
##
## O audio entra por dois gestos explicitos: a trilha de titulo e pedida aqui (no
## web ela fica guardada ate o primeiro gesto, por causa da politica de autoplay
## do navegador) e o primeiro comando do jogador destrava a saida.
##
## Nao guarda estado de jogo: apenas se o jogador ja mandou comecar, se as opcoes
## estao abertas e se a trilha ja foi pedida.

signal started

const BASE_WIDTH := 426
const BASE_HEIGHT := 240
const TITLE_PIXEL_SCALE := 3
const PROMPT_PIXEL_SCALE := 2
const BLINK_INTERVAL := 0.55
const HORIZON_Y := 196

## Slug da arte gerada usada como fundo (assets/generated/backgrounds/forest-arena.png).
const BACKDROP_SLUG := "forest-arena"

const BACKDROP_SOURCE_GENERATED := "generated"
const BACKDROP_SOURCE_CODE := "code"

## Tela de opcoes aberta pelo `Esc` (o menu completo entra no polimento).
const OPTIONS_SCENE := "res://scenes/options_screen.tscn"

const TITLE_TEXT := "PELEJA DO FOLCLORE"
const PROMPT_TEXT := "PRESSIONE PARA COMEÇAR"
const STARTED_TEXT := "LUTA EM BREVE"

const COLOR_SKY := Color8(18, 18, 42)
const COLOR_HILLS_BACK := Color8(11, 11, 28)
const COLOR_HILLS_FRONT := Color8(22, 22, 52)
const COLOR_GROUND := Color8(34, 26, 46)
const COLOR_STAR := Color8(120, 130, 190)
const COLOR_TITLE := Color8(255, 211, 92)
const COLOR_PROMPT := Color8(255, 255, 255)

const TITLE_Y := 58
const SEPARATOR_Y := 92
const PROMPT_Y := 150

var _started: bool = false
var _options_open: bool = false
var _blink_elapsed: float = 0.0
var _backdrop_source: String = BACKDROP_SOURCE_CODE

var _title_texture: TextureRect
var _prompt_text: TextureRect
var _options_screen: Control = null


func _ready() -> void:
	_apply_root_layout()
	_build_backdrop()
	_build_separator()
	_title_texture = _build_text_node(TITLE_TEXT, TITLE_PIXEL_SCALE, COLOR_TITLE, TITLE_Y)
	_prompt_text = _build_text_node(PROMPT_TEXT, PROMPT_PIXEL_SCALE, COLOR_PROMPT, PROMPT_Y)
	_start_audio()


func _process(delta: float) -> void:
	_poll_scripted_input()
	if _started or _options_open:
		return
	_blink_elapsed += delta
	_prompt_text.visible = fmod(_blink_elapsed, BLINK_INTERVAL * 2.0) < BLINK_INTERVAL


func _unhandled_input(event: InputEvent) -> void:
	if _started or _options_open:
		return
	if event.is_action_pressed("ui_cancel"):
		open_options()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_start()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_start()
	elif event is InputEventMouseButton and event.pressed:
		_start()
	elif event is InputEventScreenTouch and event.pressed:
		_start()


## Copia de texto usada pela tela -- exposta para o teste conferir o contrato.
func prompt_text() -> String:
	return PROMPT_TEXT if not _started else STARTED_TEXT


func has_started() -> bool:
	return _started


func options_open() -> bool:
	return _options_open


## Abre a tela de opcoes como filha (o menu completo e do polimento, ticket 10).
func open_options() -> void:
	if _options_open:
		return
	var scene: PackedScene = load(OPTIONS_SCENE)
	if scene == null:
		return
	_options_open = true
	_options_screen = scene.instantiate()
	_options_screen.closed.connect(_on_options_closed)
	add_child(_options_screen)


func _on_options_closed() -> void:
	_options_open = false
	if _options_screen != null and is_instance_valid(_options_screen):
		_options_screen.queue_free()
	_options_screen = null
	if not _started:
		_prompt_text.visible = true


func _start() -> void:
	_started = true
	_declare_gesture()
	_prompt_text.texture = PixelFont.new().text_texture(
		STARTED_TEXT, PROMPT_PIXEL_SCALE, COLOR_PROMPT
	)
	_prompt_text.size = _prompt_text.texture.get_size()
	_center_horizontally(_prompt_text)
	_prompt_text.visible = true
	started.emit()


## Pede a trilha de titulo. No navegador ela so toca depois do primeiro gesto.
func _start_audio() -> void:
	var audio: Variant = _audio_gateway()
	if audio == null:
		return
	audio.play_music(AudioGateway.MUSIC_TITLE)


## Declara o gesto do jogador: e o que destrava o audio no web (autoplay).
func _declare_gesture() -> void:
	var audio: Variant = _audio_gateway()
	if audio == null:
		return
	if not audio.is_audio_unlocked():
		audio.notify_user_gesture()


func _audio_gateway() -> Variant:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null or not container.has_method("audio_gateway"):
		return null
	return container.audio_gateway()


## Drena comandos do input-gateway injetado, para automacao e testes. Nenhum
## caso de uso checa provedor: o gateway e simplesmente o que foi injetado.
func _poll_scripted_input() -> void:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null or not container.has_method("input_gateway"):
		return
	var gateway: Variant = container.input_gateway()
	if gateway == null:
		return
	for command in gateway.poll():
		if command == InputGateway.Command.CONFIRM:
			_start()
			return


func _apply_root_layout() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Fundo da tela de titulo.
##
## A arte gerada por ComfyUI (slug `forest-arena`, carregada pelo asset-gateway)
## entra quando existe; sem ela, o desenho em codigo assume. O jogo nunca quebra
## por arte ausente (ADR 0005).
func _build_backdrop() -> void:
	var image := _load_generated_backdrop()
	if image == null:
		image = _build_code_backdrop()
		_backdrop_source = BACKDROP_SOURCE_CODE
	else:
		_backdrop_source = BACKDROP_SOURCE_GENERATED
	var node := TextureRect.new()
	node.name = "Backdrop"
	node.texture = ImageTexture.create_from_image(image)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.size = Vector2(BASE_WIDTH, BASE_HEIGHT)
	node.position = Vector2.ZERO
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)


## De onde veio o fundo ("generated" ou "code") -- usado por teste e evidencia.
func backdrop_source() -> String:
	return _backdrop_source


## Arte gerada por slug, via asset-gateway injetado. Null quando nao existe.
func _load_generated_backdrop() -> Image:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null or not container.has_method("asset_gateway"):
		return null
	var gateway: Variant = container.asset_gateway()
	if gateway == null:
		return null
	var pixels: PackedByteArray = gateway.load_panel(BACKDROP_SLUG, PackedByteArray())
	if pixels.size() != BASE_WIDTH * BASE_HEIGHT * 4:
		return null
	return Image.create_from_data(BASE_WIDTH, BASE_HEIGHT, false, Image.FORMAT_RGBA8, pixels)


## Fallback em codigo: ceu, mata em silhueta e chao. Layout 100% deterministico.
func _build_code_backdrop() -> Image:
	var image := Image.create_empty(BASE_WIDTH, BASE_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(COLOR_SKY)
	_paint_stars(image)
	_paint_hills(image, 26, COLOR_HILLS_BACK)
	_paint_hills(image, 14, COLOR_HILLS_FRONT)
	image.fill_rect(Rect2i(0, HORIZON_Y, BASE_WIDTH, BASE_HEIGHT - HORIZON_Y), COLOR_GROUND)
	return image


## Cielo estrelado deterministico -- nada de aleatoriedade, o layout e dado.
func _paint_stars(image: Image) -> void:
	for index in 40:
		var x := (index * 67 + 11) % BASE_WIDTH
		var y := (index * 29 + 7) % (HORIZON_Y - 90)
		image.set_pixel(x, y, COLOR_STAR)


## Silhuetas de mata: altura de cada coluna vem de uma formula fixa.
func _paint_hills(image: Image, base_height: int, color: Color) -> void:
	for x in BASE_WIDTH:
		var wave := (x * 7 + (x / 5) * 13 + base_height * 3) % 22
		var height := base_height + wave
		var top := HORIZON_Y - height
		image.fill_rect(Rect2i(x, top, 1, height), color)


func _build_separator() -> void:
	var separator := ColorRect.new()
	separator.name = "Separator"
	separator.color = COLOR_TITLE
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	separator.position = Vector2(52, SEPARATOR_Y)
	separator.size = Vector2(BASE_WIDTH - 104, 1)
	add_child(separator)


func _build_text_node(text: String, pixel_scale: int, color: Color, y: int) -> TextureRect:
	var node := TextureRect.new()
	node.name = "TitleText" if pixel_scale == TITLE_PIXEL_SCALE else "PromptText"
	node.texture = PixelFont.new().text_texture(text, pixel_scale, color)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.size = node.texture.get_size()
	node.position = Vector2(0, y)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	_center_horizontally(node)
	return node


func _center_horizontally(node: Control) -> void:
	node.position = Vector2((BASE_WIDTH - int(node.size.x)) / 2, node.position.y)