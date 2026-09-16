extends GutTest
## O `match-service` orquestra uma Peleja inteira com adapters `sample`: comanda o
## Guardiao pelos comandos do jogador, decide a IA do Oponente, resolve os golpes,
## conta o relogio e fecha a melhor de tres. Nenhum adapter faz I/O.

const SEED_GUARDIAN := 11
const SEED_OPPONENT := 22
const MAX_TICKS := 12000
const HEAVY_RANGE := 30


func _fixture(difficulty: int = OpponentAi.Difficulty.NORMAL) -> Dictionary:
	var input := SampleInputGateway.new()
	var render := SampleRenderGateway.new()
	var asset := InMemoryAssetGateway.new()
	var audio := SilentAudioGateway.new()
	var service := MatchService.new(input, render, asset, audio)
	var configured := service.configure(
		GuardianStats.SACI, Archetype.Id.CAPATAZ, SEED_GUARDIAN, SEED_OPPONENT, difficulty
	)
	return {"service": service, "input": input, "render": render, "audio": audio, "ok": configured}


## Comando que o Guardiao "jogaria" neste tick: fecha a distancia e golpeia.
func _player_command(service: MatchService) -> int:
	var gap := service.opponent.hurtbox().horizontal_distance_to(service.guardian.hurtbox())
	if gap > HEAVY_RANGE:
		return InputGateway.Command.MOVE_RIGHT
	return InputGateway.Command.HEAVY


func test_service_orchestrates_a_full_peleja_with_sample_adapters() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	assert_true(fx["ok"], "a Peleja foi montada")
	var input: SampleInputGateway = fx["input"]
	var ticks := 0
	while not service.is_match_over() and ticks < MAX_TICKS:
		input.script_commands([_player_command(service)])
		service.advance_tick()
		ticks += 1
	assert_true(service.is_match_over(), "a Peleja chega ao fim")
	assert_ne(service.winner(), MatchRules.Winner.NONE, "ha um vencedor ou empate")
	assert_between(service.rules.rounds_played(), 2, 3, "melhor de tres")
	var render: SampleRenderGateway = fx["render"]
	service.render_frame()
	assert_gt(render.frames_presented, 0, "o render-gateway recebeu frames")
	assert_gt(render.rects.size(), 0, "o render-gateway recebeu retangulos")
	var audio: SilentAudioGateway = fx["audio"]
	assert_true(audio.music_calls.has("fight"), "a musica de luta tocou")


func test_player_commands_move_and_attack_the_guardian() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	var start_x := service.guardian.position.x
	input.script_commands([InputGateway.Command.MOVE_RIGHT])
	service.advance_tick()
	assert_gt(service.guardian.position.x, start_x, "MOVE_RIGHT aproxima o Guardiao")
	input.script_commands([InputGateway.Command.LIGHT])
	service.advance_tick()
	assert_true(service.guardian.is_attacking(), "LIGHT inicia o golpe leve")


func test_crouch_changes_the_hurtbox() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	var standing := service.guardian.hurtbox()
	input.script_commands([InputGateway.Command.CROUCH])
	service.advance_tick()
	assert_eq(service.guardian.state, FighterState.State.CROUCH)
	assert_eq(service.guardian.hurtbox().size, Fighter.CROUCH_SIZE, "agachar encolhe a hurtbox")
	assert_lt(service.guardian.hurtbox().size.y, standing.size.y)


func test_block_reduces_the_damage_received() -> void:
	var standing := _fixture()
	var standing_service: MatchService = standing["service"]
	var standing_damage := standing_service.guardian.receive_hit(
		Move.light(), standing_service.opponent
	)
	var blocking := _fixture()
	var blocking_service: MatchService = blocking["service"]
	var input: SampleInputGateway = blocking["input"]
	input.script_commands([InputGateway.Command.BLOCK])
	blocking_service.advance_tick()
	assert_eq(blocking_service.guardian.state, FighterState.State.BLOCK)
	var blocked_damage := blocking_service.guardian.receive_hit(
		Move.light(), blocking_service.opponent
	)
	assert_lt(blocked_damage, standing_damage, "defender reduz o dano do golpe bloqueavel")
	assert_gt(blocked_damage, 0, "defender nao zera o dano")


func test_grab_pierces_the_guard_through_the_service() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	input.script_commands([InputGateway.Command.BLOCK])
	service.advance_tick()
	var blocked_grab := service.guardian.receive_hit(Move.grab(), service.opponent)
	var fresh := _fixture()
	var fresh_service: MatchService = fresh["service"]
	var standing_grab := fresh_service.guardian.receive_hit(Move.grab(), fresh_service.opponent)
	assert_eq(blocked_grab, standing_grab, "o agarrão ignora a defesa")


func test_the_opponent_ai_acts_without_player_input() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var start_x := service.opponent.position.x
	for tick in 180:
		service.advance_tick()
	assert_lt(service.opponent.position.x, start_x, "a IA se aproxima do Guardiao")


func test_the_match_is_deterministic_for_the_same_seed_and_commands() -> void:
	var first := _run_scripted()
	var second := _run_scripted()
	assert_gt(first.size(), 0)
	assert_eq(first, second, "mesma semente e mesmos comandos -> mesma Peleja")


func test_configure_refuses_an_unknown_archetype() -> void:
	var input := SampleInputGateway.new()
	var service := MatchService.new(
		input, SampleRenderGateway.new(), InMemoryAssetGateway.new(), SilentAudioGateway.new()
	)
	assert_false(service.configure(GuardianStats.SACI, 99, 1, 2), "Arquetipo desconhecido nao monta")
	assert_false(service.is_active(), "nenhum round comeca")
	var state := service.snapshot()
	assert_eq(state["phase"], "idle")
	assert_eq(state["winner"], MatchRules.Winner.NONE)
	assert_eq(state["rounds_played"], 0)
	assert_eq(state["guardian_health_ratio"], 0.0)
	assert_eq(state["clock_seconds"], 0)


func test_render_model_exposes_only_rectangles_and_colors() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var model := service.render_model()
	assert_gt(model.size(), 0, "ha o que desenhar")
	for entry in model:
		assert_eq(entry.keys().size(), 2, "cada entrada tem apenas rect e color")
		assert_true(entry.has("rect") and entry.has("color"))
	assert_eq(model[0]["rect"], Rect2i(0, 0, 426, 240), "a resolucao base e 426x240")


## O efeito proprio do Golpe Especial atravessa o caso de uso: o Redemoinho
## consome a barra inteira e puxa o Oponente para dentro do turbilhao.
func test_the_redemoinho_consumes_the_meter_and_pulls_the_opponent() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	assert_eq(service.special_effect.display_name, SpecialMove.REDEMOINHO)
	service.guardian.meter.gain(SpecialMeter.MAX_UNITS)
	assert_true(service.guardian.meter.is_full(), "a barra comeca cheia")
	var before := service.guardian.meter.current
	assert_true(before > 0)
	input.script_commands([InputGateway.Command.SPECIAL])
	service.advance_tick()
	assert_eq(service.snapshot()["special_name"], SpecialMove.REDEMOINHO)
	assert_true(service.guardian.meter.is_empty(), "o Especial consome a Barra inteira")
	assert_true(service.guardian.current_move.is_special(), "e o golpe entra em andamento")
	var before_pull := service.opponent.position.x
	var active := false
	for tick in service.special_move.total_frames() + 1:
		service.advance_tick()
		if service.snapshot()["special_active"]:
			active = true
			break
	assert_true(active, "a janela ativa do Redemoinho aconteceu")
	service.advance_tick()
	assert_lt(service.opponent.position.x, before_pull + 1, "o turbilhao puxa o Oponente para dentro")


## Sem barra cheia o Especial nao dispara: nem gasta a barra, nem puxa ninguem.
func test_the_special_does_not_fire_without_a_full_meter() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	service.guardian.meter.gain(SpecialMeter.MAX_UNITS - 1)
	input.script_commands([InputGateway.Command.SPECIAL])
	service.advance_tick()
	assert_false(service.guardian.current_move != null and service.guardian.current_move.is_special())
	assert_eq(service.snapshot()["special_active"], false)
	assert_eq(service.guardian.meter.current, SpecialMeter.MAX_UNITS - 1, "a barra fica intacta")


func _run_scripted() -> Array:
	var fx := _fixture(OpponentAi.Difficulty.HARD)
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	var log: Array = []
	for tick in 400:
		input.script_commands([_player_command(service)])
		log.append(service.advance_tick())
	return log
