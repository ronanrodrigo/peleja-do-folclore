extends GutTest
## Audio da Peleja: o `match-service` emite os efeitos do contrato (impacto leve e
## pesado, dano, nocaute e Golpe Especial) e troca o contexto musical ao entrar na
## luta e no fim dela -- quando o Oponente vence, quem entra em cena e a
## Reviravolta e o contexto vai para `reviravolta`.
##
## Todos os adapters sao `sample` (audio silencioso): nenhum som e produzido e
## nenhum arquivo e tocado.

const SEED_GUARDIAN := 11
const SEED_OPPONENT := 22
const MAX_TICKS := 12000
const HEAVY_RANGE := 30
const PAUSE_GUARD := MatchService.ROUND_PAUSE_TICKS + 4


func _fixture() -> Dictionary:
	var input := SampleInputGateway.new()
	var audio := SilentAudioGateway.new()
	var service := MatchService.new(
		input, SampleRenderGateway.new(), InMemoryAssetGateway.new(), audio
	)
	var configured := service.configure(
		GuardianStats.SACI, Archetype.Id.CAPATAZ, SEED_GUARDIAN, SEED_OPPONENT
	)
	return {"service": service, "input": input, "audio": audio, "ok": configured}


## Comando que o Guardiao "jogaria": fecha a distancia e golpeia pesado.
func _player_command(service: MatchService) -> int:
	var gap := service.opponent.hurtbox().horizontal_distance_to(service.guardian.hurtbox())
	return InputGateway.Command.MOVE_RIGHT if gap > HEAVY_RANGE else InputGateway.Command.HEAVY


## Roda a Peleja ate o fim (ou ate o Oponente cair, quando pedido).
func _run_match(service: MatchService, input: SampleInputGateway, until_knockout: bool) -> int:
	var ticks := 0
	while ticks < MAX_TICKS and not service.is_match_over():
		if until_knockout and service.opponent.is_knocked_out():
			break
		input.script_commands([_player_command(service)])
		service.advance_tick()
		ticks += 1
	return ticks


## Fecha a Peleja com um lado sempre vencendo: zerar a vida do perdedor no comeco
## de cada round e o caminho mais curto e nao depende da sorte da IA.
func _force_victory(service: MatchService, loser: Fighter) -> void:
	var rounds := 0
	while rounds < MatchRules.MAX_ROUNDS + 1 and not service.is_match_over():
		rounds += 1
		loser.health.apply_damage(loser.health.max_value)
		service.advance_tick()
		var ticks := 0
		while not service.is_match_over() and not service.is_active() and ticks < PAUSE_GUARD:
			service.advance_tick()
			ticks += 1


func test_entering_the_fight_switches_the_music_context() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var audio: SilentAudioGateway = fx["audio"]
	assert_true(fx["ok"], "a Peleja foi montada")
	assert_eq(
		audio.last_music(),
		AudioGateway.MUSIC_FIGHT,
		"entrar na luta troca o contexto musical para a trilha de luta"
	)


func test_impact_damage_and_round_end_cues_come_from_the_played_match() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	var audio: SilentAudioGateway = fx["audio"]
	_run_match(service, input, false)
	assert_true(
		audio.sfx_calls.has(AudioGateway.SFX_IMPACT_HEAVY),
		"o golpe pesado do Guardiao toca o impacto pesado"
	)
	assert_true(
		audio.sfx_calls.has(AudioGateway.SFX_DAMAGE),
		"quando o Guardiao apanha, o cue de dano toca"
	)
	assert_true(
		audio.sfx_calls.has(AudioGateway.SFX_ROUND_END),
		"o fim de cada round tem cue proprio"
	)
	for kind in audio.sfx_calls:
		assert_true(
			AudioGateway.SFX_KINDS.has(kind),
			"o servico so pede efeitos do contrato: %s" % kind
		)


func test_knockout_cue_when_a_fighter_is_knocked_out() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	var audio: SilentAudioGateway = fx["audio"]
	service.opponent.health.apply_damage(service.opponent.health.max_value - 1)
	_run_match(service, input, true)
	assert_true(service.opponent.is_knocked_out(), "o Oponente foi nocauteado")
	assert_true(
		audio.sfx_calls.has(AudioGateway.SFX_KNOCKOUT), "o nocaute toca o cue proprio"
	)


func test_special_cue_when_the_special_starts() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	var audio: SilentAudioGateway = fx["audio"]
	service.guardian.meter.gain(SpecialMeter.MAX_UNITS)
	input.script_commands([InputGateway.Command.SPECIAL])
	service.advance_tick()
	assert_true(service.guardian.current_move.is_special(), "o Especial comecou")
	assert_true(
		audio.sfx_calls.has(AudioGateway.SFX_SPECIAL), "o Especial toca o cue proprio"
	)


func test_reviravolta_context_when_the_opponent_wins_the_match() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var audio: SilentAudioGateway = fx["audio"]
	_force_victory(service, service.guardian)
	assert_true(service.is_match_over(), "a Peleja acabou")
	assert_eq(service.winner(), MatchRules.Winner.OPPONENT, "o Oponente venceu")
	assert_eq(
		service.final_music_context(),
		AudioGateway.MUSIC_REVIRAVOLTA,
		"Peleja vencida pelo Oponente leva a trilha da Reviravolta"
	)
	assert_eq(
		audio.last_music(),
		AudioGateway.MUSIC_REVIRAVOLTA,
		"a troca de contexto musical acontece ao entrar na Reviravolta"
	)
	assert_true(
		audio.music_calls.has(AudioGateway.MUSIC_FIGHT),
		"a trilha de luta tocou antes da Reviravolta"
	)


func test_result_context_when_the_guardian_wins_the_match() -> void:
	var fx := _fixture()
	var service: MatchService = fx["service"]
	var audio: SilentAudioGateway = fx["audio"]
	_force_victory(service, service.opponent)
	assert_true(service.is_match_over(), "a Peleja acabou")
	assert_eq(service.winner(), MatchRules.Winner.GUARDIAN, "o Guardiao venceu")
	assert_eq(
		service.final_music_context(),
		AudioGateway.MUSIC_RESULT,
		"Peleja vencida pelo Guardiao fecha com a trilha de resultado"
	)
	assert_eq(audio.last_music(), AudioGateway.MUSIC_RESULT)
	assert_false(
		audio.music_calls.has(AudioGateway.MUSIC_REVIRAVOLTA),
		"sem derrota do Guardiao, a Reviravolta nunca entra"
	)