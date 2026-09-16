class_name ResultScreen
extends Control
## Base das telas de fim de Peleja (ticket 10): vitoria, derrota e fim de arcade.
##
## Fina de proposito: monta a superficie de desenho na resolucao base 426x240
## (escala inteira, filtro nearest), delega toda a copy e o layout ao
## `ResultAdapter` e drena o comando do input-gateway injetado. Nenhuma regra de
## campanha mora aqui -- quem decide se a Peleja foi vencida e se o arcade acabou
## e o `GameFlowService`, e o resumo chega como DADO por `configure`.
##
## As tres telas concretas so respondem o proprio tipo (`result_kind()`).

signal confirmed

const BASE_WIDTH := 426
const BASE_HEIGHT := 240
const BLINK_INTERVAL := 0.55

## Resumo da Peleja fechada, entregue pelo fluxo do jogo como dado.
var summary: Dictionary = {}
var result_adapter: ResultAdapter

var _image: Image
var _display: TextureRect
var _blink_elapsed: float = 0.0
var _hint_visible: bool = true
var _confirmed_emitted: bool = false


func _ready() -> void:
	result_adapter = ResultAdapter.new()
	_apply_root_layout()
	_build_display()
	draw_frame()


func _process(delta: float) -> void:
	_blink_elapsed += delta
	_poll_scripted_input()
	_update_blink()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		confirm()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		confirm()
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		confirm()
	elif event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
		confirm()


## Tipo da tela; cada cena concreta responde o seu.
func result_kind() -> String:
	return ResultAdapter.KIND_VICTORY


## Recebe o resumo da Peleja (dado do fluxo) e redesenha.
func configure(p_summary: Dictionary) -> void:
	summary = p_summary
	draw_frame()


## Confirma e avisa o fluxo uma vez so (a cena nao decide a proxima tela).
func confirm() -> void:
	if _confirmed_emitted:
		return
	_confirmed_emitted = true
	confirmed.emit()


func has_confirmed() -> bool:
	return _confirmed_emitted


## Redesenha a tela inteira a partir do modelo do adapter.
func draw_frame() -> void:
	if _image == null or result_adapter == null:
		return
	var model := result_adapter.model_for(result_kind(), summary)
	_image.fill(model["background"])
	_blend_band(model["band_rect"], model["band_color"])
	_paint_border(model["band_rect"], model["border_color"])
	_blend_band(model["title_band_rect"], model["title_band_color"])
	_blend_band(model["hint_band_rect"], model["hint_band_color"])
	_image.fill_rect(model["bar_back_rect"], model["bar_back_color"])
	_image.fill_rect(model["bar_fill_rect"], model["bar_fill_color"])
	_paint_label(
		model["title"], int(model["title_scale"]), model["title_color"], model["title_position"]
	)
	for line in model["lines"]:
		_paint_label(
			str(line["text"]), int(line["scale"]), line["color"], line["position"]
		)
	if _hint_visible:
		_paint_label(
			str(model["hint"]),
			int(model["hint_scale"]),
			model["hint_color"],
			model["hint_position"]
		)
	_display.texture.update(_image)


## Pisca a dica do rodape sem redesenhar em todo quadro.
func _update_blink() -> void:
	var visible_now := fmod(_blink_elapsed, BLINK_INTERVAL * 2.0) < BLINK_INTERVAL
	if visible_now == _hint_visible:
		return
	_hint_visible = visible_now
	draw_frame()


func _poll_scripted_input() -> void:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null or not container.has_method("input_gateway"):
		return
	var gateway: Variant = container.input_gateway()
	if gateway == null:
		return
	for command in gateway.poll():
		match command:
			InputGateway.Command.CONFIRM, InputGateway.Command.CANCEL, InputGateway.Command.JUMP:
				confirm()
				return
			_:
				pass


func _blend_band(rect: Rect2i, color: Color) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var band := Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	band.fill(color)
	_image.blend_rect(band, Rect2i(Vector2i.ZERO, rect.size), rect.position)


func _paint_border(rect: Rect2i, color: Color) -> void:
	_image.fill_rect(Rect2i(rect.position, Vector2i(rect.size.x, 1)), color)
	_image.fill_rect(Rect2i(rect.position.x, rect.end.y - 1, rect.size.x, 1), color)
	_image.fill_rect(Rect2i(rect.position.x, rect.position.y, 1, rect.size.y), color)
	_image.fill_rect(Rect2i(rect.end.x - 1, rect.position.y, 1, rect.size.y), color)


func _paint_label(text: String, pixel_scale: int, color: Color, position: Vector2i) -> void:
	if text.is_empty():
		return
	var stamp := BitmapFont.make_image(text, color)
	if pixel_scale > 1:
		stamp.resize(
			stamp.get_width() * pixel_scale,
			stamp.get_height() * pixel_scale,
			Image.INTERPOLATE_NEAREST
		)
	_image.blend_rect(stamp, Rect2i(Vector2i.ZERO, stamp.get_size()), position)


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
	_image.fill(Color8(10, 10, 28))
	_display = TextureRect.new()
	_display.name = "ResultDisplay"
	_display.texture = ImageTexture.create_from_image(_image)
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.position = Vector2.ZERO
	_display.size = Vector2(BASE_WIDTH, BASE_HEIGHT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)
