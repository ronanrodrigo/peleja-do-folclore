extends GutTest
## Roubo da Barra de Especial: os golpes do Banqueiro (Juros Compostos) e do
## Falso Pastor (Dizimo) tiram barra de quem apanha.
##
## A regra e pura e o efeito de jogo e indireto: como o Golpe Especial exige a
## barra CHEIA, roubar barra adia o Especial do Guardiao -- sem regra nova no
## `Fighter`.

const SEED_GUARDIAN := 5
const SEED_OPPONENT := 6
const ADJACENT := 10
const GUARDIAN_METER_BEFORE := 50


func _service(archetype: int) -> MatchService:
	var service := MatchService.new(
		SampleInputGateway.new(),
		SampleRenderGateway.new(),
		InMemoryAssetGateway.new(),
		SilentAudioGateway.new()
	)
	service.configure(GuardianStats.SACI, archetype, SEED_GUARDIAN, SEED_OPPONENT)
	return service


## Encosta o Oponente no Guardiao e deixa o golpe-assinatura dele conectar.
## Devolve o dano aplicado ao Guardiao.
func _land_the_signature(service: MatchService) -> int:
	var move := service.opponent_signature
	assert_not_null(move, "o Oponente tem golpe-assinatura")
	service.opponent.position.x = service.guardian.position.x + ADJACENT
	assert_true(service.opponent.start_move(move), "o Oponente entra no golpe proprio")
	var health_before := service.guardian.health.current
	for tick in move.total_frames() + 2:
		service.opponent.face_towards(service.guardian.position.x)
		service.advance_tick()
		if service.guardian.health.current < health_before:
			return health_before - service.guardian.health.current
	return 0


func test_the_banker_charges_the_special_meter_on_contact() -> void:
	var service := _service(Archetype.Id.BANQUEIRO)
	assert_true(service.meter_steal != null, "o Banqueiro tem o golpe da cobranca")
	assert_eq(service.meter_steal.display_name, MeterStealMove.BANQUEIRO_DISPLAY_NAME)
	service.guardian.meter.gain(GUARDIAN_METER_BEFORE)
	var before := service.guardian.meter.current
	var opponent_before := service.opponent.meter.current
	var damage := _land_the_signature(service)
	assert_gt(damage, 0, "o golpe-assinatura conectou")
	assert_eq(
		service.meter_stolen,
		MeterStealMove.BANQUEIRO_TAKE_UNITS,
		"os juros compostos tiraram a barra do Guardiao"
	)
	assert_eq(
		service.guardian.meter.current,
		before + service.guardian.stats.meter_gain_on_hurt - MeterStealMove.BANQUEIRO_TAKE_UNITS,
		"a barra dele caiu exatamente o valor cobrado"
	)
	assert_eq(
		service.opponent.meter.current,
		opponent_before + MeterStealMove.BANQUEIRO_TAKE_UNITS
		+ service.opponent.stats.meter_gain_on_hit,
		"o que foi cobrado foi para o bolso do Banqueiro"
	)


func test_the_false_preacher_takes_the_tithe() -> void:
	var service := _service(Archetype.Id.FALSO_PASTOR)
	service.guardian.meter.gain(GUARDIAN_METER_BEFORE)
	var before := service.guardian.meter.current
	var damage := _land_the_signature(service)
	assert_gt(damage, 0)
	assert_eq(service.meter_stolen, MeterStealMove.FALSO_PASTOR_TAKE_UNITS)
	assert_eq(
		service.guardian.meter.current,
		before + service.guardian.stats.meter_gain_on_hurt - MeterStealMove.FALSO_PASTOR_TAKE_UNITS
	)


func test_an_opponent_without_the_charge_never_steals() -> void:
	var service := _service(Archetype.Id.CAPATAZ)
	assert_null(service.meter_steal, "o Capataz nao cobra barra")
	service.guardian.meter.gain(GUARDIAN_METER_BEFORE)
	var damage := _land_the_signature(service)
	assert_gt(damage, 0, "o Capataz bate com o chicote")
	assert_eq(service.meter_stolen, 0, "mas nao rouba nada da barra")
	assert_eq(
		service.guardian.meter.current,
		GUARDIAN_METER_BEFORE + service.guardian.stats.meter_gain_on_hurt
	)


func test_the_steal_takes_only_the_units_that_existed() -> void:
	var steal := MeterStealMove.for_archetype(Archetype.Id.BANQUEIRO)
	var duel := Fighter.duel(GuardianStats.SACI, Archetype.Id.BANQUEIRO, 1, 2)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	guardian.meter.gain(7)
	assert_eq(steal.steal_from(guardian, opponent), 7, "so o que havia na barra")
	assert_true(guardian.meter.is_empty())
	assert_eq(opponent.meter.current, 7, "e tudo passou para quem cobrou")
	assert_eq(steal.steal_from(guardian, opponent), 0, "barra vazia nao rende nada")
	assert_eq(steal.steal_from(null, opponent), 0, "sem defensor nao ha cobranca")
	assert_eq(steal.steal_from(guardian, null), 0, "sem cobrador a barra fica onde esta")


func test_the_steal_delays_the_guardian_special() -> void:
	var duel := Fighter.duel(GuardianStats.SACI, Archetype.Id.FALSO_PASTOR, 1, 2)
	var guardian: Fighter = duel["guardian"]
	var opponent: Fighter = duel["opponent"]
	guardian.meter.gain(SpecialMeter.MAX_UNITS)
	assert_true(guardian.can_use_special(), "com a barra cheia o Especial entra")
	var steal := MeterStealMove.for_archetype(Archetype.Id.FALSO_PASTOR)
	assert_eq(steal.steal_from(guardian, opponent), MeterStealMove.FALSO_PASTOR_TAKE_UNITS)
	assert_false(
		guardian.can_use_special(),
		"o dizimo tirou a barra cheia: o Especial do Guardiao fica para depois"
	)


func test_the_charge_is_identified_by_the_signature_move_name() -> void:
	var steal := MeterStealMove.for_archetype(Archetype.Id.BANQUEIRO)
	assert_true(steal.is_named(MeterStealMove.BANQUEIRO_DISPLAY_NAME))
	assert_false(steal.is_named("Redemoinho"), "o Golpe Especial do Guardiao nao rouba barra")
	assert_false(steal.is_named(""))
	assert_null(MeterStealMove.for_archetype(Archetype.Id.REDPILL))
	assert_false(MeterStealMove.steals_meter(Archetype.Id.CAMISA_VERDE))


func test_the_meter_drain_never_goes_negative() -> void:
	var meter := SpecialMeter.new(SpecialMeter.MAX_UNITS)
	assert_eq(meter.drain(MeterStealMove.BANQUEIRO_TAKE_UNITS), 25)
	assert_eq(meter.current, SpecialMeter.MAX_UNITS - 25)
	assert_eq(meter.drain(1000), SpecialMeter.MAX_UNITS - 25, "a barra esvazia, nunca inverte")
	assert_eq(meter.current, 0)
	assert_eq(meter.drain(0), 0)
	assert_eq(meter.drain(-5), 0)
