extends Control
## Cena de luta (camada app).
##
## Fina de proposito: monta o no de desenho, pega os gateways ja injetados pelo
## composition root, delega para o `MatchService` e conecta o sinal de fim de
## Peleja. Nenhuma regra de combate, nenhum estado de partida e nenhuma leitura
## de engine moram aqui -- so o passo de simulacao e a pintura dos retangulos que
## o servico entrega em `render_model()`.

signal match_finished(winner)

const BASE_WIDTH := 426
const BASE_HEIGHT := 240
const TICKS_PER_SECOND := 60
const TICK_SECONDS := 1.0 / float(TICKS_PER_SECOND)
## Sementes fixas: a Peleja e reproduzivel pela semente (invariante 2). A variacao
## por Arquetipo/dificuldade e do arcade (tickets 6 e 7), nao da cena.
const GUARDIAN_SEED := 20260915
const OPPONENT_SEED := 7
const GUARDIAN_NAME := GuardianStats.SACI
const OPPONENT_ARCHETYPE := Archetype.Id.CAPATAZ
const DIFFICULTY := OpponentAi.Difficulty.NORMAL

const COLOR_CLEAR := Color8(18, 18, 42)

## Verdadeiro por padrao: a cena roda sozinha. A ferramenta de evidencia desliga
## e dirige os ticks para um print determinista.
var auto_run := true
var match_service: MatchService

var _accumulator: float = 0.0
var _finished_emitted: bool = false
var _display: TextureRect
var _image: Image


func _ready() -> void:
	_apply_root_layout()
	_build_display()
	_setup_match()


func _process(delta: float) -> void:
	if auto_run:
		_accumulate(delta)
	draw_frame()


## Avanca a simulacao um unico tick e devolve o retrato do estado.
func simulate_tick() -> Dictionary:
	if match_service == null:
		return {}
	var was_over := match_service.is_match_over()
	var state := match_service.advance_tick()
	if not was_over and match_service.is_match_over() and not _finished_emitted:
		_finished_emitted = true
		match_finished.emit(match_service.winner())
	return state


## Reconstroi o frame: delega ao render-gateway e pinta o modelo devolvido.
func draw_frame() -> void:
	if match_service == null or _image == null:
		return
	match_service.render_frame()
	_paint(match_service.render_model())


func match_state() -> Dictionary:
	if match_service == null:
		return {}
	return match_service.snapshot()


## Gateway de entrada efetivamente usado pela cena (teclado, toque ou sample).
func input_gateway() -> InputGateway:
	if match_service == null:
		return null
	return match_service.input_gateway()


func _accumulate(delta: float) -> void:
	_accumulator += delta
	var guard := 0
	while _accumulator >= TICK_SECONDS and guard < TICKS_PER_SECOND:
		_accumulator -= TICK_SECONDS
		guard += 1
		simulate_tick()
		if match_service != null and match_service.is_match_over():
			break


func _setup_match() -> void:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null:
		push_error("fight scene exige o composition root app_container")
		return
	match_service = MatchService.new(
		_resolve_input_gateway(container),
		container.render_gateway(),
		container.asset_gateway(),
		container.audio_gateway()
	)
	match_service.configure(
		GUARDIAN_NAME, OPPONENT_ARCHETYPE, GUARDIAN_SEED, OPPONENT_SEED, DIFFICULTY
	)


## Escolhe teclado ou toque: o toque so entra em dispositivo com tela sensivel.
## Nenhum adapter e instanciado aqui -- os dois vem do composition root.
func _resolve_input_gateway(container: Variant) -> InputGateway:
	var touch: Variant = container.touch_input_gateway()
	if touch != null and DisplayServer.is_touchscreen_available():
		if touch.has_method("mount"):
			touch.mount(self)
		return touch
	return container.input_gateway()


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
	_display = TextureRect.new()
	_display.name = "FightDisplay"
	_display.texture = ImageTexture.create_from_image(_image)
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.position = Vector2.ZERO
	_display.size = Vector2(BASE_WIDTH, BASE_HEIGHT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)


## Pinta o modelo do servico num Image de 426x240 (resolucao base, ADR 0002).
func _paint(model: Array) -> void:
	_image.fill(COLOR_CLEAR)
	for entry in model:
		var rect: Rect2i = entry["rect"]
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		_image.fill_rect(rect, entry["color"])
	_display.texture.update(_image)