extends GutTest
## Os especiais atravessam o caso de uso: a selecao alimenta o arcade como dado e
## os efeitos do Golpe Especial agem na janela ativa da Peleja.

const SEED_GUARDIAN := 11
const SEED_OPPONENT := 22

func _fixture(guardian_name: String) -> Dictionary:
	var input := SampleInputGateway.new()
	var service := MatchService.new(
		input, SampleRenderGateway.new(), InMemoryAssetGateway.new(), SilentAudioGateway.new()
	)
	var ok := service.configure(
		guardian_name, Archetype.Id.CAPATAZ, SEED_GUARDIAN, SEED_OPPONENT
	)
	return {"service": service, "input": input, "ok": ok}


## A Peleja montada com cada Guardiao novo responde pelo Golpe Especial da lenda.
func test_every_new_guardian_enters_the_match_with_the_legend_special() -> void:
	for guardian_name in [GuardianStats.CURUPIRA, GuardianStats.IARA, GuardianStats.CUCA]:
		var fx := _fixture(guardian_name)
		assert_true(fx["ok"], "a Peleja monta com %s" % guardian_name)
		var service: MatchService = fx["service"]
		assert_eq(service.special_effect.display_name, SpecialMoveTable.display_name_for(guardian_name))
		assert_true(service.special_effect.has_effect())
		assert_eq(service.guardian.stats.display_name, guardian_name)


## Pes Invertidos dentro da Peleja: o Oponente sai com os comandos invertidos e
## o relatorio do tick traz o efeito aplicado.
func test_the_pes_invertidos_reach_the_opponent_inside_the_match() -> void:
	var fx := _fixture(GuardianStats.CURUPIRA)
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	service.guardian.meter.gain(SpecialMeter.MAX_UNITS)
	input.script_commands([InputGateway.Command.SPECIAL])
	service.advance_tick()
	var inverted := false
	for tick in service.special_move.total_frames() + 1:
		var state := service.advance_tick()
		for status in state["opponent_status"]:
			if status["name"] == "invert_controls" and status["ticks"] > 0:
				inverted = true
	assert_true(inverted, "o Oponente fica com o lado dos comandos trocado")
	assert_gt(service.special_report["knockback"], 0, "e cai para o lado contrario da guarda")


## O espelho do lado vale para o comando do jogador: pedir um lado anda para o
## outro enquanto o status durar.
func test_the_inverted_commands_mirror_the_player_command() -> void:
	var fx := _fixture(GuardianStats.CURUPIRA)
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	service.guardian.statuses.add(StatusEffect.new(StatusEffect.Kind.INVERT_CONTROLS, 30))
	var before := service.guardian.position.x
	input.script_commands([InputGateway.Command.MOVE_RIGHT])
	service.advance_tick()
	assert_lt(service.guardian.position.x, before, "MOVE_RIGHT anda para a esquerda")


## Canto do Rio dentro da Peleja: o Oponente fica adormecido e sem controle.
func test_the_canto_do_rio_sleeps_the_opponent_and_the_ai_cannot_act() -> void:
	var fx := _fixture(GuardianStats.IARA)
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	service.guardian.meter.gain(SpecialMeter.MAX_UNITS)
	input.script_commands([InputGateway.Command.SPECIAL])
	service.advance_tick()
	for tick in service.special_move.total_frames() + 1:
		service.advance_tick()
	assert_true(service.opponent.statuses.is_asleep(), "o Canto do Rio encanta o Oponente")
	assert_false(service.opponent.can_act(), "e ele nao aceita comando nenhum")
	var frozen := service.opponent.position.x
	for tick in 5:
		service.advance_tick()
		if service.opponent.statuses.is_asleep():
			assert_eq(service.opponent.position.x, frozen, "adormecido, a IA nao anda")


## Nana Nenem dentro da Peleja: sono e mordida de jacare saem no relatorio.
func test_the_nana_nenem_sleeps_and_bites_inside_the_match() -> void:
	var fx := _fixture(GuardianStats.CUCA)
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	service.guardian.meter.gain(SpecialMeter.MAX_UNITS)
	input.script_commands([InputGateway.Command.SPECIAL])
	service.advance_tick()
	var slept := false
	var bit := false
	for tick in service.special_move.total_frames() + 1:
		var state := service.advance_tick()
		if int(state["special_report"].get("bite", 0)) > 0:
			bit = true
		for status in state["opponent_status"]:
			if status["name"] == "sleep":
				slept = true
	assert_true(slept, "o Nana Nenem adormece o Oponente")
	assert_true(bit, "e a Cuca virada jacare morde")


## Sem barra cheia nenhum dos especiais novos dispara.
func test_the_new_specials_need_a_full_meter_as_always() -> void:
	var fx := _fixture(GuardianStats.IARA)
	var service: MatchService = fx["service"]
	var input: SampleInputGateway = fx["input"]
	service.guardian.meter.gain(SpecialMeter.MAX_UNITS - 1)
	input.script_commands([InputGateway.Command.SPECIAL])
	service.advance_tick()
	assert_eq(service.snapshot()["special_active"], false)
	assert_eq(service.guardian.meter.current, SpecialMeter.MAX_UNITS - 1)
	assert_eq(service.snapshot()["opponent_status"].size(), 0, "e ninguem dorme")