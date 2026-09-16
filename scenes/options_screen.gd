extends Control
## Tela de opcoes (camada app).
##
## Fina: monta a superficie de desenho, pega os gateways ja injetados pelo
## composition root, delega ao `OptionsService`, traduz o estado com o
## `OptionsViewAdapter` (a copy pt-BR vive la) e desenha na resolucao base
## 426x240 com a fonte bitmap, em escala inteira e filtro nearest.
##
## Nenhuma regra de opcao mora aqui: a cena so transforma tecla/comando abstrato
## em chamada do caso de uso e desenha o modelo devolvido.

signal closed

const BASE_WIDTH := 426
const BASE_HEIGHT := 240
const TITLE_PIXEL_SCALE := 3
const ROW_PIXEL_SCALE := 2
const HINT_PIXEL_SCALE := 2
const PANEL_RECT := Rect2i(28, 18, 370, 204)

const TITLE_Y := 32
const SEPARATOR_Y := 66
const FIRST_ROW_Y := 88
const ROW_HEIGHT := 52
const LABEL_X := 52
const RIGHT_X := 374
const BAR_HEIGHT := 10
const BAR_OFFSET_Y := 30
const BAR_WIDTH := 322
const MARKER_SIZE := Vector2i(4, 14)
const MARKER_X := 38
const HINT_Y := 196

const COLOR_BACKGROUND := Color8(8, 8, 25)
const COLOR_PANEL := Color8(18, 18, 42)
const COLOR_BORDER := Color8(255, 211, 92)
const COLOR_SEPARATOR := Color8(90, 90, 130)
const COLOR_LABEL := Color8(240, 240, 255)
const COLOR_VALUE := Color8(255, 211, 92)
const COLOR_MARKER := Color8(255, 211, 92)
const COLOR_BAR_BACKGROUND := Color8(42, 42, 64)
const COLOR_BAR_VOLUME := Color8(90, 150, 255)
const COLOR_BAR_ON := Color8(120, 220, 120)
const COLOR_BAR_OFF := Color8(72, 72, 96)
const COLOR_HINT := Color8(150, 150, 190)

var options_service: OptionsService
var view_adapter: OptionsViewAdapter

var _image: Image
var _display: TextureRect
var _closed: bool = false


func _ready() -> void:
	_apply_root_layout()
	_build_display()
	_setup_options()
	refresh()


func _process(_delta: float) -> void:
	_poll_scripted_input()


func _unhandled_input(event: InputEvent) -> void:
	if _closed:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_toggle_mute()
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_increase_volume()
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_decrease_volume()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_handle_key(event.keycode)
	elif event is InputEventMouseButton and event.pressed:
		# Toque/clique: no dispositivo movel nao ha teclado, e o clique tambem e o
		# gesto que destrava o audio no navegador.
		get_viewport().set_input_as_handled()
		_declare_gesture()
		_toggle_mute()


## Estado corrente das opcoes (observavel por teste e ferramenta de evidencia).
func volume_percent() -> int:
	if options_service == null:
		return 0
	return options_service.volume_percent()


func is_muted() -> bool:
	if options_service == null:
		return false
	return options_service.is_muted()


func increase_volume() -> bool:
	return options_service.increase_volume() if options_service != null else false


func decrease_volume() -> bool:
	return options_service.decrease_volume() if options_service != null else false


func toggle_mute() -> bool:
	return options_service.toggle_mute() if options_service != null else false


## Move o volume direto para um percentual -- usado pela ferramenta de evidencia.
func set_volume_percent(percent: int) -> bool:
	if options_service == null:
		return false
	return options_service.set_volume_percent(percent)


## Declara o gesto do jogador no gateway de audio injetado (autoplay no web).
func declare_gesture() -> void:
	_declare_gesture()


## Redesenha a tela a partir do estado do caso de uso.
func refresh() -> void:
	if _image == null or options_service == null:
		return
	var model := view_adapter.view_model(
		options_service.volume_percent(), options_service.is_muted()
	)
	var title: String = model["title"]
	var hint: String = model["hint"]
	_image.fill(COLOR_BACKGROUND)
	_draw_panel()
	_draw_text(title, TITLE_PIXEL_SCALE, COLOR_VALUE, Vector2i(0, TITLE_Y), true)
	_image.fill_rect(Rect2i(151, SEPARATOR_Y, 124, 1), COLOR_SEPARATOR)
	var rows: Array = model["rows"]
	for index in rows.size():
		_draw_row(rows[index], FIRST_ROW_Y + index * ROW_HEIGHT)
	_draw_text(hint, HINT_PIXEL_SCALE, COLOR_HINT, Vector2i(0, HINT_Y), true)
	_display.texture.update(_image)


func close() -> void:
	if _closed:
		return
	_closed = true
	visible = false
	closed.emit()


func _setup_options() -> void:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null:
		push_error("options_screen exige o composition root app_container")
		return
	view_adapter = OptionsViewAdapter.new()
	options_service = OptionsService.new(
		container.persistence_gateway(), container.audio_gateway()
	)
	options_service.load_preferences()
	# Contexto musical do menu; no web ele fica guardado ate o primeiro gesto.
	container.audio_gateway().play_music(AudioGateway.MUSIC_SELECT)


func _draw_panel() -> void:
	_image.fill_rect(PANEL_RECT, COLOR_PANEL)
	_image.fill_rect(Rect2i(PANEL_RECT.position, Vector2i(PANEL_RECT.size.x, 1)), COLOR_BORDER)
	_image.fill_rect(
		Rect2i(
			PANEL_RECT.position.x, PANEL_RECT.position.y + PANEL_RECT.size.y - 1,
			PANEL_RECT.size.x, 1
		),
		COLOR_BORDER
	)
	_image.fill_rect(
		Rect2i(PANEL_RECT.position.x, PANEL_RECT.position.y, 1, PANEL_RECT.size.y),
		COLOR_BORDER
	)
	_image.fill_rect(
		Rect2i(
			PANEL_RECT.position.x + PANEL_RECT.size.x - 1, PANEL_RECT.position.y,
			1, PANEL_RECT.size.y
		),
		COLOR_BORDER
	)


func _draw_row(row: Dictionary, y: int) -> void:
	_image.fill_rect(Rect2i(MARKER_X, y, MARKER_SIZE.x, MARKER_SIZE.y), COLOR_MARKER)
	var label: String = row["label"]
	var key: String = row["key"]
	_draw_text(label, ROW_PIXEL_SCALE, COLOR_LABEL, Vector2i(LABEL_X, y), false)
	var value: String = row["value"]
	_draw_text(
		value,
		ROW_PIXEL_SCALE,
		COLOR_VALUE,
		Vector2i(RIGHT_X - _text_width(value, ROW_PIXEL_SCALE), y),
		false
	)
	var bar_y := y + BAR_OFFSET_Y
	_image.fill_rect(Rect2i(LABEL_X, bar_y, BAR_WIDTH, BAR_HEIGHT), COLOR_BAR_BACKGROUND)
	var filled := roundi(BAR_WIDTH * float(row["bar"]))
	if filled > 0:
		_image.fill_rect(Rect2i(LABEL_X, bar_y, filled, BAR_HEIGHT), _bar_color(key))


## Cor da barra: volume em azul, som ligado em verde, mudo em cinza.
func _bar_color(key: String) -> Color:
	if key == OptionsViewAdapter.ROW_MUTE:
		return COLOR_BAR_ON if not is_muted() else COLOR_BAR_OFF
	return COLOR_BAR_VOLUME


## Desenha texto pela fonte bitmap; `centered` centraliza na resolucao base.
func _draw_text(
	text: String, pixel_scale: int, color: Color, position: Vector2i, centered: bool
) -> void:
	var font := PixelFont.new()
	var stamp := font.text_image(text, pixel_scale, color)
	var x := position.x
	if centered:
		x = (BASE_WIDTH - stamp.get_width()) / 2
	_image.blend_rect(stamp, Rect2i(Vector2i.ZERO, stamp.get_size()), Vector2i(x, position.y))


func _text_width(text: String, pixel_scale: int) -> int:
	return PixelFont.new().text_size(text, pixel_scale).x


func _handle_key(keycode: int) -> void:
	_declare_gesture()
	match keycode:
		KEY_D, KEY_W, KEY_RIGHT, KEY_UP:
			_increase_volume()
		KEY_A, KEY_S, KEY_LEFT, KEY_DOWN:
			_decrease_volume()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_toggle_mute()
		KEY_ESCAPE:
			close()
		_:
			pass


func _increase_volume() -> void:
	_declare_gesture()
	if options_service != null and options_service.increase_volume():
		refresh()


func _decrease_volume() -> void:
	_declare_gesture()
	if options_service != null and options_service.decrease_volume():
		refresh()


func _toggle_mute() -> void:
	_declare_gesture()
	if options_service != null and options_service.toggle_mute():
		refresh()


## Drena comandos do input-gateway injetado, para automacao e testes. Nenhum caso
## de uso checa provedor: o gateway e simplesmente o que foi injetado.
func _poll_scripted_input() -> void:
	if options_service == null or _closed:
		return
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null or not container.has_method("input_gateway"):
		return
	var gateway: Variant = container.input_gateway()
	if gateway == null:
		return
	for command in gateway.poll():
		match command:
			InputGateway.Command.MOVE_RIGHT:
				_increase_volume()
			InputGateway.Command.MOVE_LEFT:
				_decrease_volume()
			InputGateway.Command.CONFIRM:
				_toggle_mute()
			InputGateway.Command.CANCEL:
				close()
			_:
				pass


## O audio so toca depois do primeiro gesto do jogador (politica de autoplay do
## navegador). Aqui o gesto e qualquer tecla, clique ou comando da tela.
func _declare_gesture() -> void:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null or not container.has_method("audio_gateway"):
		return
	var audio: Variant = container.audio_gateway()
	if audio == null:
		return
	if not audio.is_audio_unlocked():
		audio.notify_user_gesture()


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


func _build_display() -> void:
	_image = Image.create_empty(BASE_WIDTH, BASE_HEIGHT, false, Image.FORMAT_RGBA8)
	_image.fill(COLOR_BACKGROUND)
	_display = TextureRect.new()
	_display.name = "OptionsDisplay"
	_display.texture = ImageTexture.create_from_image(_image)
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.position = Vector2.ZERO
	_display.size = Vector2(BASE_WIDTH, BASE_HEIGHT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)