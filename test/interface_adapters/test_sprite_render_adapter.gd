extends GutTest
## O renderer de producao: escala INTEIRA, filtro nearest e letterbox.
##
## A invariante de pixel art (ADR 0002) e verificada aqui: o adapter desenha a
## resolucao base 426x240, apresenta com o maior multiplo inteiro que cabe e
## recusa qualquer fator que destruiria o grid de pixel.

const SURFACE_SIZE := Vector2i(426, 240)

var _adapter: SpriteRenderAdapter


func before_each() -> void:
	_adapter = SpriteRenderAdapter.new()


func test_the_renderer_is_a_render_gateway() -> void:
	assert_true(_adapter is RenderGateway, "o adapter implementa o contrato render-gateway")
	assert_eq(_adapter.surface().get_size(), SURFACE_SIZE, "superficie na resolucao base 426x240")


func test_the_default_scale_is_the_integer_pixel_art_scale() -> void:
	assert_eq(RenderGateway.DEFAULT_PIXEL_SCALE, 3, "a pixel art do jogo e 3x")
	assert_eq(RenderGateway.BASE_SIZE, SURFACE_SIZE)
	assert_true(_adapter.is_pixel_scale_valid(1))
	assert_true(_adapter.is_pixel_scale_valid(3))
	assert_true(_adapter.is_pixel_scale_valid(5))
	assert_false(_adapter.is_pixel_scale_valid(0), "escala menor que 1 e recusada")
	assert_false(_adapter.is_pixel_scale_valid(-3), "escala negativa e recusada")


func test_a_sprite_is_drawn_in_integer_scale() -> void:
	var sheet := _sheet()
	var spot := _first_opaque_spot(sheet)
	var color := sheet.color_of(spot.z)
	var origin := Vector2i(10, 20)
	assert_true(_adapter.draw_sprite(sheet, "idle", 0, origin, 3), "o Saci desenhou")
	assert_eq(_adapter.sprites_drawn, 1)
	var pixel := Vector2i(origin.x + spot.x * 3, origin.y + spot.y * 3)
	assert_eq(_adapter.surface().get_pixelv(pixel), color, "o pixel saiu em 3x")
	assert_eq(_adapter.surface().get_pixelv(pixel + Vector2i(2, 2)), color, "o bloco 3x3 inteiro")
	var next := sheet.pixel_color("idle", 0, spot.x + 1, spot.y)
	assert_eq(
		_adapter.surface().get_pixelv(pixel + Vector2i(3, 0)),
		next,
		"o pixel seguinte do quadro comeca na coluna 3 (escala inteira)"
	)


func test_a_fractional_factor_cannot_be_expressed_and_low_scales_are_refused() -> void:
	var sheet := _sheet()
	assert_false(_adapter.draw_sprite(sheet, "idle", 0, Vector2i.ZERO, 0), "escala 0 nao desenha")
	assert_eq(_adapter.rejected_scales, [0], "a escala recusada fica registrada")
	assert_eq(_adapter.sprites_drawn, 0, "nada foi desenhado")
	assert_false(_adapter.draw_sprite(sheet, "idle", 0, Vector2i.ZERO, -2), "escala negativa")
	assert_eq(_adapter.rejected_scales, [0, -2])


func test_a_missing_animation_does_not_draw() -> void:
	var sheet := _sheet()
	assert_false(_adapter.draw_sprite(sheet, "voando", 0, Vector2i.ZERO, 3))
	assert_false(_adapter.draw_sprite(sheet, "idle", 99, Vector2i.ZERO, 3))
	assert_false(
		_adapter.draw_sprite(null, "idle", 0, Vector2i.ZERO, 3), "sem spritesheet nao desenha"
	)
	assert_eq(_adapter.sprites_drawn, 0)


func test_the_scale_is_the_biggest_integer_that_fits_with_letterbox() -> void:
	assert_eq(_adapter.display_scale(Vector2i(1278, 720)), 3, "janela padrao do jogo: 3x")
	assert_eq(_adapter.display_scale(Vector2i(2556, 1440)), 6, "o dobro da janela: 6x")
	assert_eq(_adapter.display_scale(Vector2i(900, 500)), 2, "900/426=2 e 500/240=2")
	assert_eq(_adapter.display_scale(Vector2i(853, 720)), 2, "853/426=2 (o maior que cabe)")
	assert_eq(_adapter.display_scale(Vector2i(400, 300)), 1, "menor que a base ainda desenha 1x")
	assert_eq(_adapter.display_scale(Vector2i(0, 0)), 1, "nunca menos de 1x")


func test_letterbox_centers_the_base_resolution_in_any_window() -> void:
	var default_window := _adapter.letterbox_rect(Vector2i(1278, 720))
	assert_eq(default_window, Rect2i(0, 0, 1278, 720), "3x exato preenche a janela")
	var tall := _adapter.letterbox_rect(Vector2i(900, 900))
	assert_eq(tall.size, Vector2i(852, 480), "escala 2x em 900x900")
	assert_eq(tall.position, Vector2i(24, 210), "com faixa preta em cima e embaixo")
	var small := _adapter.letterbox_rect(Vector2i(426, 240))
	assert_eq(small, Rect2i(0, 0, 426, 240), "a resolucao base desenha 1x")


func test_the_display_uses_nearest_and_the_letterbox_rect() -> void:
	var host := Control.new()
	host.size = Vector2(900, 900)
	add_child_autofree(host)
	var display := _adapter.mount(host)
	assert_not_null(display, "o display foi montado no host")
	assert_eq(display.name, SpriteRenderAdapter.DISPLAY_NAME)
	assert_eq(display.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "filtro nearest")
	assert_eq(display.texture, _adapter.texture(), "o display mostra a superficie do adapter")
	_adapter.apply_layout(Vector2i(900, 900))
	assert_eq(display.size, Vector2(852, 480), "o display respeita o letterbox")
	assert_eq(display.position, Vector2(24, 210), "e fica centralizado")


func test_presenting_a_frame_updates_the_texture() -> void:
	var sheet := _sheet()
	_adapter.clear()
	assert_true(_adapter.draw_sprite(sheet, "special", 2, Vector2i(40, 40), 3), "quadro do Redemoinho")
	_adapter.draw_rect(Rect2i(0, 0, 10, 10), Color8(255, 211, 92))
	_adapter.present()
	assert_eq(_adapter.frames_presented, 1)
	assert_eq(_adapter.frames_begun, 1)
	assert_eq(
		_adapter.surface().get_pixel(2, 2),
		Color8(255, 211, 92),
		"os retangulos entram na mesma superficie"
	)


func test_rectangles_outside_the_base_resolution_are_clipped() -> void:
	_adapter.draw_rect(Rect2i(400, 220, 400, 200), Color8(255, 255, 255))
	assert_eq(_adapter.surface().get_pixel(425, 239), Color8(255, 255, 255), "a parte visivel aparece")
	assert_eq(_adapter.surface().get_size(), SURFACE_SIZE, "e a superficie nao cresce")


func test_drawing_writes_only_the_pixels_of_the_sprite() -> void:
	var before := _adapter.surface().get_pixel(0, 0)
	_adapter.draw_sprite(_sheet(), "idle", 0, Vector2i(200, 100), 1)
	assert_eq(_adapter.surface().get_pixel(0, 0), before, "fora do sprite nada muda")


func _sheet() -> Spritesheet:
	return Spritesheet.decode(
		GodotAssetGateway.new().load_spritesheet("saci")
	)


## Primeiro pixel opaco do idle: posicao no quadro mais o indice na paleta.
func _first_opaque_spot(sheet: Spritesheet) -> Vector3i:
	var size := sheet.frame_size("idle", 0)
	for y in size.y:
		for x in size.x:
			var index := sheet.pixel_at("idle", 0, x, y)
			if index != Spritesheet.TRANSPARENT_INDEX:
				return Vector3i(x, y, index)
	return Vector3i(-1, -1, Spritesheet.TRANSPARENT_INDEX)
