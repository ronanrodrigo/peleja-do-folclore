extends Control
## Cena de luta (camada app).
##
## Fina de proposito: monta os nos de desenho, pega os gateways ja injetados pelo
## composition root, delega a regra ao `MatchService` (ou ao `ArcadeService`,
## quando a Peleja vem do arcade) e o layout ao `HudAdapter`. Nenhuma regra de
## combate, nenhum estado de partida e nenhuma leitura de engine moram aqui.
##
## A composicao da arte entra no polimento (ticket 10): com o renderer de producao
## montado, a cena desenha ceu, chao, o turbilhao do Golpe Especial e os DOIS
## lutadores pelos spritesheets codificados (slug do Guardiao e do Oponente do
## arcade), em escala inteira 3x. O HUD final (nome, vida em barra, barra de
## Especial, pips de round e relogio) vem do `HudAdapter` e nunca revela a
## Vantagem Oculta.

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

## Escala inteira da pixel art (ADR 0002) e linha do chao da arena.
const SPRITE_SCALE := 3
const GROUND_Y := 216
## Ticks por quadro de animacao (passo) e por quadro de golpe.
const WALK_FRAME_TICKS := 7
const ATTACK_FRAME_TICKS := 5

## Animacao do spritesheet para cada estado do dominio. O ataque tem animacao
## propria por golpe (`_attack_animation`).
const STATE_ANIMATIONS := {
	FighterState.State.IDLE: "idle",
	FighterState.State.WALK: "walk",
	FighterState.State.CROUCH: "crouch",
	FighterState.State.BLOCK: "block",
	FighterState.State.HURT: "hurt",
	FighterState.State.KNOCKED_DOWN: "ko",
}

const COLOR_CLEAR := Color8(18, 18, 42)
const COLOR_SKY := Color8(18, 18, 42)
const COLOR_GROUND := Color8(34, 26, 46)
const COLOR_GUARDIAN_FALLBACK := Color8(255, 211, 92)
const COLOR_OPPONENT_FALLBACK := Color8(214, 72, 72)

## Verdadeiro por padrao: a cena roda sozinha. A ferramenta de evidencia desliga
## e dirige os ticks para um print determinista.
var auto_run := true
## Guardiao que entra na Peleja. Padrao do Saci; a tela de selecao/arcade troca
## aqui antes de a cena subir.
var guardian_name: String = GUARDIAN_NAME
var match_service: MatchService
## Arcade injetado pela camada app: quando existe, a Peleja e a do arcade (o
## Oponente, a dificuldade e o avanco vem dele) e o HUD mostra o progresso.
var arcade: ArcadeService = null
var hud: HudAdapter

var _accumulator: float = 0.0
var _finished_emitted: bool = false
var _ticks: int = 0
var _display: TextureRect
var _image: Image
var _texture: ImageTexture
var _renderer: Variant = null
var _asset: Variant = null
var _input: Variant = null
var _uses_surface: bool = false
var _sheets: Dictionary = {}
var _hud_labels: Array = []
var _hud_signature: String = ""


func _ready() -> void:
	hud = HudAdapter.new()
	_apply_root_layout()
	_build_display()
	_resolve_gateways()
	_setup_match()
	_display.visible = not _uses_surface
	draw_frame()


func _process(delta: float) -> void:
	if auto_run:
		_accumulate(delta)
	draw_frame()


## Injeta o arcade (a Peleja passa a ser a do arcade). Recarrega a Peleja
## corrente e redesenha -- usado pela camada app antes de subir a cena.
func attach_arcade(service: ArcadeService) -> void:
	arcade = service
	_finished_emitted = false
	_hud_signature = ""
	_setup_match()
	draw_frame()


## Avanca a simulacao um unico tick e devolve o retrato do estado.
func simulate_tick() -> Dictionary:
	if match_service == null:
		return {}
	var was_over := match_service.is_match_over()
	var state := arcade.advance_tick() if arcade != null else match_service.advance_tick()
	_ticks += 1
	if not was_over and match_service.is_match_over() and not _finished_emitted:
		_finished_emitted = true
		match_finished.emit(match_service.winner())
	return state


## Reconstroi o frame: compoe ceu, sprites e HUD (renderer de producao) ou pinta o
## modelo de retangulos (modo `sample`, sem superficie de imagem).
func draw_frame() -> void:
	if match_service == null or _image == null:
		return
	if _uses_surface:
		_compose_surface()
	else:
		match_service.render_frame()
		_paint(match_service.render_model())
	_update_hud()


func match_state() -> Dictionary:
	if match_service == null:
		return {}
	return match_service.snapshot()


## Modelo do HUD de luta (nome, barra de vida, barra de Especial, pips, relogio e
## a linha do arcade). Nunca inclui numero da Vantagem Oculta.
func hud_model() -> Dictionary:
	if hud == null or match_service == null:
		return {}
	var model := hud.fight_model(match_service.snapshot(), guardian_name, _opponent_name())
	if arcade != null:
		model["arcade_text"] = str(arcade_hud_model().get("fight_text", ""))
	return model


## Modelo do HUD do arcade (posicao na campanha, Oponente, dificuldade).
func arcade_hud_model() -> Dictionary:
	if arcade == null or hud == null:
		return {}
	return hud.arcade_model(arcade.snapshot())


## Relatorio do desenho para a ferramenta de evidencia: se ha superficie de
## producao e quantos sprites ja foram desenhados por ela.
func sprite_report() -> Dictionary:
	var drawn := 0
	if _renderer != null and _renderer.get("sprites_drawn") != null:
		drawn = int(_renderer.sprites_drawn)
	return {"surface": _uses_surface, "sprites_drawn": drawn, "labels": _hud_labels.size()}


## Gateway de entrada efetivamente usado pela cena (teclado, toque ou sample).
func input_gateway() -> InputGateway:
	return _input


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
	if arcade != null:
		match_service = arcade.match_service
		guardian_name = arcade.guardian_name
		return
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null:
		push_error("fight scene exige o composition root app_container")
		return
	match_service = MatchService.new(
		_input,
		container.render_gateway(),
		container.asset_gateway(),
		container.audio_gateway()
	)
	match_service.configure(
		guardian_name, OPPONENT_ARCHETYPE, GUARDIAN_SEED, OPPONENT_SEED, DIFFICULTY
	)


## Gateways injetados pelo composition root; nenhum adapter e instanciado aqui.
func _resolve_gateways() -> void:
	var container: Variant = get_node_or_null("/root/app_container")
	if container == null:
		push_error("fight scene exige o composition root app_container")
		return
	_renderer = container.render_gateway()
	_asset = container.asset_gateway()
	_uses_surface = _renderer != null and _renderer.has_method("mount")
	if _uses_surface:
		_renderer.mount(self)
	_input = _resolve_input_gateway(container)


## Escolhe teclado ou toque: o toque so entra em dispositivo com tela sensivel.
## Nenhum adapter e instanciado aqui -- os dois vem do composition root.
func _resolve_input_gateway(container: Variant) -> InputGateway:
	var touch: Variant = container.touch_input_gateway()
	if touch != null and DisplayServer.is_touchscreen_available():
		if touch.has_method("mount"):
			touch.mount(self)
		return touch
	return container.input_gateway()


## Composicao do frame no renderer de producao: ceu, chao, turbilhao do Especial,
## os dois lutadores pelos spritesheets e o HUD por cima.
func _compose_surface() -> void:
	_renderer.clear()
	_renderer.draw_rect(Rect2i(0, 0, BASE_WIDTH, BASE_HEIGHT), COLOR_SKY)
	_renderer.draw_rect(
		Rect2i(0, GROUND_Y, BASE_WIDTH, BASE_HEIGHT - GROUND_Y), COLOR_GROUND
	)
	_draw_special_effect()
	_draw_fighter(match_service.guardian, GuardianStats.slug_for(guardian_name))
	_draw_fighter(match_service.opponent, _opponent_slug())
	for entry in hud.fight_hud_entries(hud_model()):
		_renderer.draw_rect(entry["rect"], entry["color"])
	_renderer.present()


## Turbilhao do Golpe Especial do Guardiao: o modelo do servico desenha o
## Redemoinho em aneis deterministas; aqui ele e reaplicado sobre os sprites.
func _draw_special_effect() -> void:
	for entry in match_service.render_model():
		var color: Color = entry["color"]
		if color == MatchService.COLOR_WHIRLWIND or color == MatchService.COLOR_WHIRLWIND_DARK:
			_renderer.draw_rect(entry["rect"], color)


func _draw_fighter(fighter: Fighter, slug: String) -> void:
	if fighter == null:
		return
	var sheet := _sheet(slug)
	if sheet == null:
		# Sem spritesheet (arte ausente): o retangulo do modelo assume. O jogo
		# nunca quebra por arte faltando (ADR 0005).
		var box := fighter.hurtbox()
		_renderer.draw_rect(
			Rect2i(box.position.x, box.position.y + GROUND_Y, box.size.x, box.size.y),
			COLOR_GUARDIAN_FALLBACK if fighter == match_service.guardian else COLOR_OPPONENT_FALLBACK
		)
		return
	var animation := animation_for(fighter)
	var frame := _frame_for(fighter, sheet, animation)
	var size := sheet.frame_size(animation, frame)
	if size == Vector2i.ZERO:
		return
	var origin := Vector2i(
		fighter.position.x - size.x * SPRITE_SCALE / 2, GROUND_Y - size.y * SPRITE_SCALE
	)
	_renderer.draw_sprite(sheet, animation, frame, origin, SPRITE_SCALE, fighter.facing < 0)


## Animacao do spritesheet para o estado do lutador. O dominio fala em estados e
## golpes; o nome da animacao e a mesma lista obrigatoria do formato.
func animation_for(fighter: Fighter) -> String:
	if FighterState.is_attacking(fighter.state):
		return _attack_animation(fighter)
	return str(STATE_ANIMATIONS.get(fighter.state, "idle"))


func _attack_animation(fighter: Fighter) -> String:
	var move := fighter.current_move
	if move == null:
		return "idle"
	if move.is_special():
		return "special"
	match move.kind:
		Move.Kind.GRAB:
			return "grab"
		Move.Kind.HEAVY:
			return "heavy"
		_:
			return "light"


## Quadro da animacao: o passo cicla com os ticks e o golpe avanca dentro da
## propria janela; o resto fica parado no primeiro quadro.
func _frame_for(fighter: Fighter, sheet: Spritesheet, animation: String) -> int:
	var count := sheet.frame_count(animation)
	if count <= 1:
		return 0
	if animation == "walk":
		return (_ticks / WALK_FRAME_TICKS) % count
	if animation in ["light", "heavy", "grab", "special"]:
		return mini(fighter.move_frame / ATTACK_FRAME_TICKS, count - 1)
	return 0


## Spritesheet codificado pelo asset-gateway (o mesmo caminho do jogo). Sem
## arquivo, devolve nulo e o retangulo do modelo assume.
func _sheet(slug: String) -> Spritesheet:
	if _asset == null or slug.is_empty():
		return null
	if _sheets.has(slug):
		return _sheets[slug]
	var sheet: Spritesheet = null
	var data: Dictionary = _asset.load_spritesheet(slug)
	if not data.is_empty():
		var decoded := Spritesheet.decode(data)
		if decoded.is_valid():
			sheet = decoded
	_sheets[slug] = sheet
	return sheet


func _opponent_name() -> String:
	if arcade != null:
		return str(arcade.snapshot().get("opponent_name", ""))
	return Archetype.display_name(OPPONENT_ARCHETYPE)


func _opponent_slug() -> String:
	if arcade != null:
		return arcade.opponent_slug()
	return Archetype.slug(OPPONENT_ARCHETYPE)


## Redesenha os rotulos do HUD (nome dos dois lutadores, relogio e a linha do
## arcade) como nos de texto sobre a superficie. So remonta quando o modelo muda.
func _update_hud() -> void:
	if hud == null or match_service == null or _image == null:
		return
	var model := hud_model()
	if str(model) == _hud_signature:
		return
	_hud_signature = str(model)
	for node in _hud_labels:
		node.queue_free()
	_hud_labels = []
	var index := 0
	for label in hud.fight_hud_labels(model):
		var text := str(label["text"])
		if text.is_empty():
			continue
		_hud_labels.append(
			_add_label(index, text, label["position"], int(label["scale"]), label["color"])
		)
		index += 1


func _add_label(
	index: int, text: String, position: Vector2i, pixel_scale: int, color: Color
) -> TextureRect:
	var node := TextureRect.new()
	node.name = "HudLabel%d" % index
	node.texture = BitmapFont.make_texture(text, color, pixel_scale)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.size = Vector2(node.texture.get_size())
	node.position = Vector2(position)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node


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
	_texture = ImageTexture.create_from_image(_image)
	_display = TextureRect.new()
	_display.name = "FightDisplay"
	_display.texture = _texture
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.position = Vector2.ZERO
	_display.size = Vector2(BASE_WIDTH, BASE_HEIGHT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)


## Pinta o modelo do servico num Image de 426x240 (resolucao base, ADR 0002).
## Modo `sample`: e a superficie de desenho efetiva (sem renderer de producao).
func _paint(model: Array) -> void:
	_image.fill(COLOR_CLEAR)
	for entry in model:
		var rect: Rect2i = entry["rect"]
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		_image.fill_rect(rect, entry["color"])
	_texture.update(_image)
