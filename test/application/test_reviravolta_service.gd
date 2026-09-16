extends GutTest
## O `reviravolta-service`: a cena em painel que dissolve o Oponente que venceu a
## Peleja. Adapters `sample` (deterministicos, sem I/O): o painel vem do
## asset-gateway pelo slug, o desenho passa pelo render-gateway e o progresso do
## arcade fica no persistence-gateway.

const PANEL_BYTES := 426 * 240 * 4
const LINES := PanelAdapter.LINES.size()
const MAX_TICKS := 900


## Painel de mentira do adapter em memoria: pixels RGBA8 completos e distintos do
## painel neutro do servico.
func _panel_pixels() -> PackedByteArray:
	var pixels := PackedByteArray()
	pixels.resize(PANEL_BYTES)
	pixels.fill(9)
	pixels[0] = 255
	pixels[PANEL_BYTES - 1] = 255
	return pixels


func _fixture(with_panel: bool) -> Dictionary:
	var content: Dictionary = {"reviravolta-panel": _panel_pixels()} if with_panel else {}
	var asset := InMemoryAssetGateway.new(content)
	var render := SampleRenderGateway.new()
	var audio := SilentAudioGateway.new()
	var persistence := InMemoryPersistenceGateway.new()
	var service := ReviravoltaService.new(asset, render, audio, persistence)
	return {
		"service": service,
		"asset": asset,
		"render": render,
		"audio": audio,
		"persistence": persistence,
	}


## Roda a cena ate o fim pelo proprio tempo e devolve as fases por onde passou.
func _run_to_end(service: ReviravoltaService) -> Array:
	var phases: Array = []
	var ticks := 0
	while service.is_active() and ticks < MAX_TICKS:
		var state := service.advance_tick()
		if not phases.has(state["phase"]):
			phases.append(state["phase"])
		ticks += 1
	return phases


func test_the_reviravolta_only_plays_when_the_opponent_wins_the_match() -> void:
	var fx := _fixture(true)
	var service: ReviravoltaService = fx["service"]
	var persistence: InMemoryPersistenceGateway = fx["persistence"]
	assert_false(service.execute(MatchRules.Winner.GUARDIAN), "Guardião vencendo, nada acontece")
	assert_false(service.is_active())
	assert_eq(service.panel_pixels().size(), 0, "sem arte carregada sem motivo")
	assert_false(service.execute(MatchRules.Winner.DRAW), "empate nao dispara a Reviravolta")
	assert_false(service.execute(MatchRules.Winner.NONE), "Peleja em andamento nao dispara")
	assert_eq(
		persistence.load_value(ReviravoltaService.CAMPAIGN_KEY, {}),
		{},
		"nada e gravado quando a Reviravolta nao entra em cena"
	)
	assert_true(service.execute(MatchRules.Winner.OPPONENT), "Oponente vencendo, a cena entra")
	assert_true(service.is_active())


func test_the_full_panel_art_comes_from_the_asset_gateway_by_slug() -> void:
	var fx := _fixture(true)
	var service: ReviravoltaService = fx["service"]
	service.execute(MatchRules.Winner.OPPONENT, LINES, 3)
	assert_eq(service.snapshot()["panel_source"], ReviravoltaService.SOURCE_GATEWAY)
	assert_eq(service.panel_pixels(), _panel_pixels(), "os pixels sao os do slug do gateway")
	assert_eq(service.panel_pixels().size(), PANEL_BYTES, "painel de tela cheia 426x240 RGBA8")
	assert_eq(service.snapshot()["panel_bytes"], PANEL_BYTES)
	assert_eq(ReviravoltaService.PANEL_SLUG, "reviravolta-panel")


func test_without_the_panel_art_the_service_draws_a_neutral_panel() -> void:
	var fx := _fixture(false)
	var service: ReviravoltaService = fx["service"]
	service.execute(MatchRules.Winner.OPPONENT, LINES, 1)
	assert_eq(service.snapshot()["panel_source"], ReviravoltaService.SOURCE_BLANK)
	assert_eq(service.panel_pixels().size(), PANEL_BYTES, "o jogo nao quebra sem arte")
	assert_ne(service.panel_pixels(), _panel_pixels(), "e o painel neutro, nao a arte de outro slug")


func test_entering_the_reviravolta_switches_the_music_and_calls_the_force() -> void:
	var fx := _fixture(true)
	var service: ReviravoltaService = fx["service"]
	var audio: SilentAudioGateway = fx["audio"]
	service.execute(MatchRules.Winner.OPPONENT, LINES, 1)
	assert_eq(audio.last_music(), AudioGateway.MUSIC_REVIRAVOLTA, "trilha da Reviravolta")
	assert_eq(audio.sfx_calls, [AudioGateway.SFX_SPECIAL], "a Forca entra em cena com cue proprio")


func test_the_scene_advances_alone_through_the_phases_and_ends() -> void:
	var fx := _fixture(true)
	var service: ReviravoltaService = fx["service"]
	service.execute(MatchRules.Winner.OPPONENT, LINES, 2)
	var phases := _run_to_end(service)
	assert_eq(phases, ["voice", "wind", "root", "dissolve", "done"], "a cena rola sozinha")
	assert_true(service.is_finished(), "a cena terminou sem nenhuma interacao")
	assert_false(service.is_active())
	assert_false(service.was_skipped(), "terminou pelo tempo, nao pelo comando de pular")
	assert_true(service.snapshot()["opponent_dissolved"], "o Oponente foi dissolvido")
	assert_eq(service.phase_name(), "done")
	assert_eq(service.snapshot()["ticks"], ReviravoltaRule.total_ticks(LINES))


func test_the_force_cues_are_the_contract_ones_and_happen_once_per_phase() -> void:
	var fx := _fixture(true)
	var service: ReviravoltaService = fx["service"]
	var audio: SilentAudioGateway = fx["audio"]
	service.execute(MatchRules.Winner.OPPONENT, LINES, 1)
	_run_to_end(service)
	assert_eq(
		audio.sfx_calls,
		[
			AudioGateway.SFX_SPECIAL,
			AudioGateway.SFX_IMPACT_HEAVY,
			AudioGateway.SFX_DAMAGE,
			AudioGateway.SFX_KNOCKOUT,
		],
		"vento, raiz e dissolucao tem cue do contrato, uma vez cada"
	)
	for kind in audio.sfx_calls:
		assert_true(AudioGateway.SFX_KINDS.has(kind), "efeito do contrato: %s" % kind)


func test_the_wind_and_the_roots_are_drawn_through_the_render_gateway() -> void:
	var fx := _fixture(true)
	var service: ReviravoltaService = fx["service"]
	var render: SampleRenderGateway = fx["render"]
	service.execute(MatchRules.Winner.OPPONENT, LINES, 1)
	while service.phase_name() != "wind":
		service.advance_tick()
	service.render_frame()
	assert_gt(render.frames_presented, 0, "o frame passa pelo render-gateway")
	assert_gt(render.rects.size(), 0, "o vento desenha rajadas")
	var wind_count := render.rects.size()
	while service.phase_name() != "root":
		service.advance_tick()
	service.render_frame()
	assert_gt(render.rects.size(), wind_count, "na raiz entram as hastes")
	while not service.is_finished():
		service.advance_tick()
	service.render_frame()
	assert_eq(service.render_model(), [], "no fim, nenhum efeito fica na cena")


func test_the_effects_are_deterministic_for_the_same_ticks() -> void:
	var first: ReviravoltaService = _fixture(true)["service"]
	var second: ReviravoltaService = _fixture(true)["service"]
	for service in [first, second]:
		service.execute(MatchRules.Winner.OPPONENT, LINES, 1)
		for _tick in 200:
			service.advance_tick()
	assert_eq(first.render_model(), second.render_model(), "mesma fase e mesmo tick: mesmo desenho")
	assert_eq(first.snapshot(), second.snapshot())


func test_the_scene_can_be_skipped() -> void:
	var fx := _fixture(true)
	var service: ReviravoltaService = fx["service"]
	service.execute(MatchRules.Winner.OPPONENT, LINES, 1)
	for _tick in ReviravoltaRule.TICKS_PER_LINE:
		service.advance_tick()
	assert_eq(service.snapshot()["line_index"], 1, "a voz ja avancou uma linha")
	assert_true(service.skip(), "a cena aceita ser pulada")
	assert_true(service.is_finished())
	assert_true(service.was_skipped())
	assert_false(service.is_active())
	assert_true(service.snapshot()["skipped"])
	assert_false(service.skip(), "pular duas vezes nao faz nada")
	assert_eq(service.phase_name(), "done")


func test_the_arcade_progress_is_kept_and_the_campaign_never_dies() -> void:
	var fx := _fixture(true)
	var service: ReviravoltaService = fx["service"]
	var persistence: InMemoryPersistenceGateway = fx["persistence"]
	service.execute(MatchRules.Winner.OPPONENT, LINES, 4)
	var stored: Dictionary = fx["persistence"].load_value(ReviravoltaService.CAMPAIGN_KEY, {})
	assert_eq(stored["fight"], 4, "a Peleja em que a Reviravolta aconteceu")
	assert_false(stored["campaign_over"], "a campanha continua viva")
	assert_true(stored["reviravolta"])
	assert_eq(service.campaign_progress(), stored, "o progresso e lido de volta do gateway")
	assert_true(service.snapshot()["campaign_continues"], "nunca ha game over de campanha")
	assert_true(persistence.has(ReviravoltaService.CAMPAIGN_KEY))
