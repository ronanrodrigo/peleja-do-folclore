extends GutTest
## Status de Golpe Especial como dado puro: tipo, duracao em ticks e o espelho do
## lado do movimento (Pes Invertidos do Curupira).
##
## A duracao e sempre contada em ticks de simulacao (60 por segundo), nunca em
## segundos nem por temporizador de engine -- e o que mantem a Peleja
## reproduzivel pela semente.

const TICKS_PER_SECOND := MatchService.TICKS_PER_SECOND


func test_the_kinds_are_named_in_english() -> void:
	assert_eq(StatusEffect.name_of(StatusEffect.Kind.INVERT_CONTROLS), "invert_controls")
	assert_eq(StatusEffect.name_of(StatusEffect.Kind.SLEEP), "sleep")
	assert_eq(StatusEffect.name_of(99), "unknown", "tipo desconhecido nao inventa nome")
	assert_eq(StatusEffect.known_kinds().size(), 2, "sao dois status nesta fatia")


func test_the_duration_is_counted_in_ticks() -> void:
	var effect := StatusEffect.new(StatusEffect.Kind.SLEEP, 3)
	assert_eq(effect.ticks_remaining, 3)
	assert_true(effect.is_active())
	assert_true(effect.is_sleep())
	assert_false(effect.advance_tick(), "ainda dura")
	assert_eq(effect.ticks_remaining, 2)
	assert_false(effect.advance_tick(), "e ainda dura no segundo tick")
	assert_eq(effect.ticks_remaining, 1)
	assert_true(effect.advance_tick(), "o terceiro tick termina o status")
	assert_false(effect.is_active())


func test_a_status_without_duration_is_never_active() -> void:
	var effect := StatusEffect.new(StatusEffect.Kind.SLEEP, 0)
	assert_false(effect.is_active())
	assert_true(effect.advance_tick(), "status vazio ja acabou")
	var negative := StatusEffect.new(StatusEffect.Kind.INVERT_CONTROLS, -5)
	assert_eq(negative.ticks_remaining, 0, "duracao negativa vira zero")


func test_refresh_renews_the_duration_and_never_shortens_it() -> void:
	var effect := StatusEffect.new(StatusEffect.Kind.INVERT_CONTROLS, 10)
	effect.refresh(4)
	assert_eq(effect.ticks_remaining, 10, "o mesmo golpe de novo nao encurta o status")
	effect.refresh(25)
	assert_eq(effect.ticks_remaining, 25, "e renova quando vem mais tempo")


func test_invert_direction_mirrors_the_side_of_the_movement() -> void:
	assert_eq(StatusEffect.invert_direction(1), -1, "pedir um lado anda para o outro")
	assert_eq(StatusEffect.invert_direction(-1), 1)
	assert_eq(StatusEffect.invert_direction(0), 0, "parado continua parado")


## Os Pes Invertidos duram 3 s: 3 * 60 ticks de simulacao. E o numero do golpe do
## Curupira cadastrado na tabela, nao um temporizador.
func test_the_pes_invertidos_last_three_seconds_of_simulation() -> void:
	var effect := SpecialMoveTable.for_guardian(GuardianStats.CURUPIRA)
	assert_eq(effect.invert_ticks, 3 * TICKS_PER_SECOND)
	assert_eq(TICKS_PER_SECOND, 60, "a simulacao roda a 60 ticks por segundo")


func test_the_effects_carry_their_status_as_data() -> void:
	var cuca := SpecialMoveTable.for_guardian(GuardianStats.CUCA)
	var statuses := cuca.status_effects()
	assert_eq(statuses.size(), 1, "o Nana Nenem so adormece o alvo")
	assert_eq(statuses[0].kind, StatusEffect.Kind.SLEEP)
	assert_eq(statuses[0].ticks_remaining, cuca.sleep_ticks)
	var iara := SpecialMoveTable.for_guardian(GuardianStats.IARA)
	assert_eq(iara.status_effects()[0].kind, StatusEffect.Kind.SLEEP)
	var sem_efeito := SpecialMoveTable.for_guardian("Guardião de Fora do Elenco")
	assert_true(sem_efeito.status_effects().is_empty(), "sem efeito, sem status")