extends GutTest
## A selecao de personagem: os 4 Guardioes do elenco, com nome, slug e o nome do
## Golpe Especial, entregues como DADO.
##
## O servico e comando-e-estado puro: a cena drena o input-gateway e entrega os
## comandos; o resultado sai por `result()`. Nenhum estado global escondido -- e o
## que este teste prova comparando duas instancias.

const ROSTER := [GuardianStats.SACI, GuardianStats.CURUPIRA, GuardianStats.IARA, GuardianStats.CUCA]


func test_the_roster_has_the_four_guardians_in_order() -> void:
	var service := CharacterSelectService.new()
	assert_eq(service.count(), 4, "o elenco completo do folclore")
	assert_eq(service.roster(), ROSTER)
	assert_eq(service.guardian_name(), GuardianStats.SACI, "a selecao comeca no Saci")
	assert_eq(service.slugs(), GuardianStats.slugs(), "um slug em ingles por Guardiao")


func test_every_row_brings_portrait_slug_name_and_special() -> void:
	var service := CharacterSelectService.new()
	var rows := service.rows()
	assert_eq(rows.size(), 4)
	for index in rows.size():
		var row: Dictionary = rows[index]
		assert_eq(row["name"], ROSTER[index])
		assert_eq(row["slug"], GuardianStats.slug_for(ROSTER[index]))
		assert_false(str(row["special_name"]).is_empty(), "todo Guardiao tem Golpe Especial")
		assert_eq(row["selected"], index == 0, "so um rosto fica selecionado")
	assert_eq(
		rows[1]["special_name"], SpecialMove.PES_INVERTIDOS, "o Curupira mostra os Pes Invertidos"
	)
	assert_eq(rows[2]["special_name"], SpecialMove.CANTO_DO_RIO)
	assert_eq(rows[3]["special_name"], SpecialMove.NANA_NENEM)


func test_navigation_wraps_around_the_roster() -> void:
	var service := CharacterSelectService.new()
	assert_true(service.move_cursor(CharacterSelectService.STEP_RIGHT))
	assert_eq(service.guardian_name(), GuardianStats.CURUPIRA)
	assert_true(service.move_cursor(CharacterSelectService.STEP_LEFT))
	assert_eq(service.guardian_name(), GuardianStats.SACI)
	assert_true(service.move_cursor(CharacterSelectService.STEP_LEFT))
	assert_eq(service.guardian_name(), GuardianStats.CUCA, "a esquerda do primeiro vem o ultimo")
	assert_true(service.move_cursor(CharacterSelectService.STEP_RIGHT))
	assert_eq(service.guardian_name(), GuardianStats.SACI)
	assert_false(service.move_cursor(0), "passo zero nao move nada")


func test_the_selection_only_moves_inside_the_roster() -> void:
	var service := CharacterSelectService.new()
	assert_false(service.select(-1))
	assert_false(service.select(9))
	assert_eq(service.guardian_name(), GuardianStats.SACI, "posicao invalida nao mexe na selecao")
	assert_true(service.select(3))
	assert_eq(service.guardian_name(), GuardianStats.CUCA)


func test_the_commands_drive_the_selection() -> void:
	var service := CharacterSelectService.new()
	assert_true(service.handle_command(InputGateway.Command.MOVE_RIGHT))
	assert_eq(service.guardian_name(), GuardianStats.CURUPIRA)
	assert_false(service.handle_command(InputGateway.Command.HEAVY), "golpe nao seleciona ninguem")
	assert_true(
		service.handle_commands(
			[InputGateway.Command.MOVE_RIGHT, InputGateway.Command.MOVE_RIGHT]
		)
	)
	assert_eq(service.guardian_name(), GuardianStats.CUCA)
	assert_true(service.handle_command(InputGateway.Command.CANCEL))
	assert_eq(service.guardian_name(), GuardianStats.SACI, "cancelar volta ao comeco")
	assert_false(service.is_confirmed())


## A escolha sai como dado, pronto para o arcade consumir no ticket 6.
func test_confirming_gives_the_chosen_guardian_as_data() -> void:
	var service := CharacterSelectService.new()
	assert_true(service.result().is_empty(), "sem confirmar nao ha resultado")
	service.select(1)
	var chosen := service.confirm()
	assert_eq(chosen, GuardianStats.CURUPIRA)
	assert_true(service.is_confirmed())
	assert_eq(
		service.result(),
		{
			"guardian": GuardianStats.CURUPIRA,
			"slug": "curupira",
			"special_name": SpecialMove.PES_INVERTIDOS,
		}
	)
	assert_true(service.handle_commands([InputGateway.Command.CONFIRM]))
	assert_eq(service.snapshot()["confirmed_guardian"], GuardianStats.CURUPIRA)


## Nenhum estado global escondido: duas selecoes nao se enxergam.
func test_two_selections_do_not_share_state() -> void:
	var first := CharacterSelectService.new()
	var second := CharacterSelectService.new()
	first.select(2)
	first.confirm()
	assert_eq(first.guardian_name(), GuardianStats.IARA)
	assert_eq(second.guardian_name(), GuardianStats.SACI, "a outra selecao nao mudou")
	assert_eq(second.cursor, 0)
	assert_false(second.is_confirmed())


func test_the_snapshot_has_no_combat_state() -> void:
	var service := CharacterSelectService.new()
	var state := service.snapshot()
	for forbidden in ["health", "damage", "rounds", "hidden_advantage"]:
		assert_false(state.has(forbidden), "a selecao nao carrega %s" % forbidden)
	assert_eq(state["count"], 4)
	assert_eq(state["cursor"], 0)
	assert_eq(state["guardian"], GuardianStats.SACI)
	assert_eq(state["special_name"], SpecialMove.REDEMOINHO)