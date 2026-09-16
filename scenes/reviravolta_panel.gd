extends Control
## Cena da Reviravolta (camada app).
##
## Fina de proposito: monta a superficie de desenho, pega os gateways ja
## injetados pelo composition root, delega tudo ao `ReviravoltaService` (quem
## decide se a cena dispara e o dominio, `ReviravoltaRule`) e desenha o que os
## dois devolvem -- o painel de tela cheia do asset-gateway, os efeitos de
## vento/raiz do render-gateway e a copy pt-BR do `PanelAdapter`.
##
## Nenhuma regra de campanha, nenhum estado de partida e nenhuma leitura de
## engine moram aqui. A cena nao pede interacao: ela rola sozinha e aceita ser
## pulada (comando drenado do input-gateway injetado).

signal panel_finished(skipped)

const BASE_WIDTH := 426
const BASE_HEIGHT := 240
const PANEL_BYTES := BASE_WIDTH * BASE_HEIGHT * 4
const TICKS_PER_SECOND := 60
const TICK_SECONDS := 1.0 / float(TICKS_PER_SECOND)
const COLOR_CLEAR := Color8(12, 20, 14)

## Quem venceu a Peleja que levou a Reviravolta e em que Peleja do arcade isso
## aconteceu. O padrao (Oponente, primeira Peleja) deixa a cena rodavel sozinha
## para a ferramenta de evidencia; o arcade passa os valores reais antes de a
## cena subir.
var winner_result: int = MatchRules.Winner.OPPONENT
var fight_number: int = 1
## Verdadeiro por padrao: a cena avanca sozinha. A ferramenta de evidencia
## desliga e dirige os ticks para um print determinsta.
var auto_run := true

var reviravolta_service: ReviravoltaService
var panel_adapter: PanelAdapter

var _accumulator: float = 0.0
var _finished_emitted: bool = false
var _started: bool = false
var _display: TextureRect
var _image: Image
var _band_image: Image


func _ready() -> void:
	_apply_root_layout()
	_build_display()
	_setup_scene()
	draw_frame()


func _process(delta: float) -> void:
	if auto_run:
		_accumulate(delta)
	_poll_scripted_input()
	draw_frame()


## Avanca um unico tick de apresentacao e devolve o retrato da cena.
func simulate_tick() -> Dictionary:
	if reviravolta_service == null:
		return {}
	var level := reviravolta_service.advance_tick()
	if reviravolta_service.is_finished() and not _finished_emitted:
		_finished_emitted = true
		panel_finished.emit(reviravolta_service.was_skipped())
	return level


## Opcao de pular a cena: leva ao fim e emite o sinal uma vez so.
func skip() -> bool:
	if reviravolta_service == null:
		return false
	if not reviravolta_service.skip():
		return false
	if not _finished_emitted:
		_finished_emitted = true
		panel_finished.emit(true)
	return true


func is_finished() -> bool:
	return reviravolta_service != null and reviravolta_service.is_finished()


## Verdadeiro quando a Reviravolta realmente entrou em cena (Oponente venceu).
func panel_started() -> bool:
	return _started


func snapshot() -> Dictionary:
	if reviravolta_service == null:
		return {}
	return reviravolta_service.snapshot()


## Pixels RGBA8 426x240 do painel, como o asset-gateway os entregou.
func panel_pixels() -> PackedByteArray:
	if reviravolta_service == null:
		return PackedByteArray()
	return reviravolta_service.panel_pixels()


## Reconstroi o frame: painel de tela cheia, efeitos da Forca e copy pt-BR.
func draw_frame() -> void:
	if reviravolta_service == null or _image == null:
		return
	reviravolta_service.render_frame()
	var pixels := reviravolta_service.panel_pixels()
	if pixels.size() == PANEL_BYTES:
		_image.set_data(BASE_WIDTH, BASE_HEIGHT, false, Image.FORMAT_RGBA8, pixels)
	else:
		_image.fill(COLOR_CLEAR)
	for entry in reviravolta_service.render_model():
		_paint_rect(entry["rect"], entry["color"])
	_paint_copy()
	_display.texture.update(_image)


func _setup_scene() -> void:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null:
		push_error("reviravolta_panel exige o composition root app_container")
		return
	panel_adapter = PanelAdapter.new()
	reviravolta_service = ReviravoltaService.new(
		container.asset_gateway(),
		container.render_gateway(),
		container.audio_gateway(),
		container.persistence_gateway()
	)
	_started = reviravolta_service.execute(
		winner_result, panel_adapter.line_count(), fight_number
	)


func _accumulate(delta: float) -> void:
	_accumulator += delta
	var guard := 0
	while _accumulator >= TICK_SECONDS and guard < TICKS_PER_SECOND:
		_accumulator -= TICK_SECONDS
		guard += 1
		simulate_tick()
		if is_finished():
			break


## Drena comandos do input-gateway injetado (nunca teclado sintetico): a cena
## nao pede interacao, mas confirmar ou cancelar pula a Reviravolta.
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
				if skip():
					return
			_:
				pass


## Desenha a copy da cena: faixa escura, titulo, nome da Forca, a fala corrente
## e o comando de pular -- tudo pela fonte bitmap, em escala inteira.
func _paint_copy() -> void:
	if panel_adapter == null or reviravolta_service == null:
		return
	var model := panel_adapter.view_model(int(reviravolta_service.snapshot()["line_index"]))
	var band: Rect2i = model["band_rect"]
	if band.size.x > 0 and band.size.y > 0:
		_image.blend_rect(
			_band_image, Rect2i(Vector2i.ZERO, band.size), band.position
		)
		_paint_border(band, model["border_color"])
	for prefix in ["title", "force", "line", "hint"]:
		_paint_label(
			str(model["%s_text" % prefix]),
			int(model["%s_scale" % prefix]),
			model["%s_color" % prefix],
			model["%s_position" % prefix]
		)


## Contorno de 1 pixel da faixa (escrito a mao: a faixa e dado, nao um no).
func _paint_border(rect: Rect2i, color: Color) -> void:
	_image.fill_rect(Rect2i(rect.position, Vector2i(rect.size.x, 1)), color)
	_image.fill_rect(
		Rect2i(rect.position.x, rect.end.y - 1, rect.size.x, 1), color
	)
	_image.fill_rect(Rect2i(rect.position.x, rect.position.y, 1, rect.size.y), color)
	_image.fill_rect(
		Rect2i(rect.end.x - 1, rect.position.y, 1, rect.size.y), color
	)


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


func _paint_rect(rect: Rect2i, color: Color) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	_image.fill_rect(rect, color)


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
	_image.fill(COLOR_CLEAR)
	_band_image = Image.create_empty(
		PanelAdapter.BAND_RECT.size.x, PanelAdapter.BAND_RECT.size.y, false, Image.FORMAT_RGBA8
	)
	_band_image.fill(PanelAdapter.COLOR_BAND)
	_display = TextureRect.new()
	_display.name = "ReviravoltaDisplay"
	_display.texture = ImageTexture.create_from_image(_image)
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.position = Vector2.ZERO
	_display.size = Vector2(BASE_WIDTH, BASE_HEIGHT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)
