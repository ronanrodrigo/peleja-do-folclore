extends Control
## Tela de selecao de personagem (camada app).
##
## Fina de proposito: monta o no de desenho, pega os gateways ja injetados pelo
## composition root, delega a regra ao `CharacterSelectService` e o layout ao
## `HudAdapter`. Nenhuma regra de selecao, nenhum estado de elenco e nenhuma
## leitura de engine moram aqui -- so o passo de polling dos comandos e a pintura
## do modelo que o adapter entrega.
##
## O retrato de cada Guardiao e o spritesheet codificado (dado versionado,
## ADR 0005) desenhado pelo renderer de producao em escala inteira. Sem o
## renderer de producao (modo `sample`), a tela desenha o fundo do modelo em
## codigo e mantem os rotulos: o teste roda headless sem adapter de imagem.

signal guardian_selected(guardian_name)

const BASE_WIDTH := 426
const BASE_HEIGHT := 240
const COLOR_CLEAR := Color8(18, 18, 42)

## Servico de selecao e adapter de HUD da cena (o estado vive no servico).
var service: CharacterSelectService
var hud: HudAdapter

var _renderer: Variant = null
var _asset: Variant = null
var _input: Variant = null
var _mounts_gateway_surface: bool = false

var _image: Image
var _texture: ImageTexture
var _display: TextureRect
var _labels: Array = []
var _sheets: Dictionary = {}
var _model_signature: String = ""


func _ready() -> void:
	service = CharacterSelectService.new()
	hud = HudAdapter.new()
	_apply_root_layout()
	_build_display()
	_resolve_gateways()
	# Com o renderer de producao montado, o desenho sai pela superficie dele; a
	# superficie de fallback da cena fica escondida.
	_display.visible = not _mounts_gateway_surface
	_redraw()


func _process(_delta: float) -> void:
	if service == null or service.is_confirmed():
		return
	_poll_commands()


## Selecao atual, como dado. Nunca inclui numero de combate.
func selection() -> Dictionary:
	if service == null:
		return {}
	return service.snapshot()


func current_guardian() -> String:
	return service.guardian_name() if service != null else ""


## Rotulos que a tela esta mostrando (nome e Golpe Especial de cada Guardiao),
## na ordem das colunas. Existe para o teste conferir o que o jogador le.
func visible_labels() -> PackedStringArray:
	var texts := PackedStringArray()
	if service == null:
		return texts
	var model := hud.character_select_model(service.rows())
	texts.append(str(model["title"]))
	for column in model["columns"]:
		texts.append(str(column["name"]))
		texts.append(str(column["special_name"]))
	texts.append(str(model["prompt"]))
	return texts


## --- API de automacao (cena, teste de tela e ferramenta de evidencia) ---

func select_index(index: int) -> bool:
	var changed := service.select(index)
	if changed:
		_redraw()
	return changed


func move_selection(step: int) -> bool:
	var changed := service.move_cursor(step)
	if changed:
		_redraw()
	return changed


## Fecha a escolha e anuncia o Guardiao escolhido (dado que o arcade consome).
func confirm_selection() -> String:
	var guardian_name := service.confirm()
	_redraw()
	guardian_selected.emit(guardian_name)
	return guardian_name


## Gateway de entrada efetivamente usado pela cena (teclado, toque ou sample).
func input_gateway() -> InputGateway:
	return _input


func _poll_commands() -> void:
	if _input == null:
		return
	var commands: Array = _input.poll()
	if commands.is_empty():
		return
	if service.handle_commands(commands):
		_redraw()
	if service.is_confirmed():
		guardian_selected.emit(service.confirmed_guardian)


## Gateways injetados pelo composition root; nenhum adapter e instanciado aqui.
func _resolve_gateways() -> void:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null:
		push_error("scenes/character_select.tscn exige o composition root app_container")
		return
	_asset = container.asset_gateway()
	_renderer = container.render_gateway()
	_input = container.input_gateway()
	_mounts_gateway_surface = _renderer != null and _renderer.has_method("mount")
	if _mounts_gateway_surface:
		_renderer.mount(self)


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


## Superficie de fallback da cena, usada quando nao ha renderer de producao.
func _build_display() -> void:
	_image = Image.create_empty(BASE_WIDTH, BASE_HEIGHT, false, Image.FORMAT_RGBA8)
	_image.fill(COLOR_CLEAR)
	_texture = ImageTexture.create_from_image(_image)
	_display = TextureRect.new()
	_display.name = "SelectDisplay"
	_display.texture = _texture
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.position = Vector2.ZERO
	_display.size = Vector2(BASE_WIDTH, BASE_HEIGHT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.visible = not _mounts_gateway_surface
	add_child(_display)


func _redraw() -> void:
	if service == null or hud == null:
		return
	var model := hud.character_select_model(service.rows())
	var signature := str(model)
	if signature == _model_signature:
		return
	_model_signature = signature
	_draw_background(model)
	_draw_portraits(model)
	_apply_labels(model)


func _draw_background(model: Dictionary) -> void:
	if _mounts_gateway_surface:
		_renderer.clear()
		_renderer.draw_rect(Rect2i(0, 0, BASE_WIDTH, BASE_HEIGHT), model["background"])
		for column in model["columns"]:
			_renderer.draw_rect(column["band"], column["band_color"])
		_renderer.draw_rect(model["floor"], model["floor_color"])
		return
	_image.fill(model["background"])
	for column in model["columns"]:
		_image.fill_rect(column["band"], column["band_color"])
	_image.fill_rect(model["floor"], model["floor_color"])
	_texture.update(_image)


func _draw_portraits(model: Dictionary) -> void:
	if not _mounts_gateway_surface:
		return
	for column in model["columns"]:
		var sheet := _sheet(str(column["slug"]))
		if sheet == null:
			continue
		var scale := int(column["portrait_scale"])
		var frame_size := sheet.frame_size(
			str(column["portrait_animation"]), int(column["portrait_frame"])
		)
		var center: Vector2i = column["portrait_position"]
		var origin := Vector2i(center.x - frame_size.x * scale / 2, center.y)
		_renderer.draw_sprite(
			sheet,
			str(column["portrait_animation"]),
			int(column["portrait_frame"]),
			origin,
			scale
		)
	_renderer.present()


## Spritesheet codificado do Guardiao, pelo asset-gateway (o mesmo caminho do
## jogo). Sem arquivo, devolve nulo e a coluna fica so com nome e especial.
func _sheet(slug: String) -> Spritesheet:
	if _asset == null or slug.is_empty():
		return null
	if _sheets.has(slug):
		return _sheets[slug]
	var data: Dictionary = _asset.load_spritesheet(slug)
	var sheet: Spritesheet = null
	if not data.is_empty():
		var decoded := Spritesheet.decode(data)
		if decoded.is_valid():
			sheet = decoded
	_sheets[slug] = sheet
	return sheet


func _apply_labels(model: Dictionary) -> void:
	for node in _labels:
		node.queue_free()
	_labels = []
	_add_label(
		str(model["title"]), model["title_position"], int(model["title_scale"]), model["title_color"]
	)
	_add_label(
		str(model["prompt"]), model["prompt_position"], int(model["prompt_scale"]), model["prompt_color"]
	)
	for column in model["columns"]:
		_add_label(
			str(column["name"]), column["name_position"], int(column["name_scale"]), column["name_color"]
		)
		_add_label(
			str(column["special_name"]),
			column["special_position"],
			int(column["special_scale"]),
			column["special_color"]
		)


func _add_label(text: String, position: Vector2i, pixel_scale: int, color: Color) -> void:
	if text.is_empty():
		return
	var node := TextureRect.new()
	node.name = "Label"
	node.texture = BitmapFont.make_texture(text, color, pixel_scale)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.size = Vector2(node.texture.get_size())
	node.position = Vector2(position)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	_labels.append(node)