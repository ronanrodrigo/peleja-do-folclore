extends GutTest
## Ordem fixa do arcade: sete Pelejas, uma por Arquetipo (ADR 0007).

const EXPECTED_ORDER := [
	Archetype.Id.CAPATAZ,
	Archetype.Id.BANQUEIRO,
	Archetype.Id.REDPILL,
	Archetype.Id.CAMISA_VERDE,
	Archetype.Id.DOUTOR_PUREZA,
	Archetype.Id.FANTASMA_DO_REICH,
	Archetype.Id.FALSO_PASTOR,
]


func test_order_has_seven_fights() -> void:
	assert_eq(ArcadeOrder.count(), 7)


func test_order_is_the_one_fixed_by_the_adr() -> void:
	assert_eq(ArcadeOrder.ORDER, EXPECTED_ORDER, "a ordem e dado, nao sorteio")


func test_order_covers_each_archetype_exactly_once() -> void:
	assert_true(ArcadeOrder.is_complete())
	assert_eq(ArcadeOrder.ORDER.size(), Archetype.count())
	for archetype in Archetype.ALL:
		assert_eq(ArcadeOrder.ORDER.count(archetype), 1, "sem repeticao nem ausencia")


func test_lookup_by_position_and_by_archetype() -> void:
	for index in ArcadeOrder.count():
		var archetype := ArcadeOrder.archetype_at(index)
		assert_eq(ArcadeOrder.index_of(archetype), index, "posicao base zero")
	assert_eq(ArcadeOrder.archetype_at(-1), -1)
	assert_eq(ArcadeOrder.archetype_at(ArcadeOrder.count()), -1)
	assert_eq(ArcadeOrder.index_of(99), -1)


func test_slugs_follow_the_order() -> void:
	assert_eq(
		Array(ArcadeOrder.slugs()),
		[
			"capataz",
			"banqueiro",
			"redpill",
			"camisa-verde",
			"doutor-pureza",
			"fantasma-do-reich",
			"falso-pastor",
		]
	)


func test_order_is_not_mutated_by_readers() -> void:
	var slugs := ArcadeOrder.slugs()
	slugs.append("intruso")
	assert_eq(ArcadeOrder.slugs().size(), ArcadeOrder.count(), "a copia nao altera o dado")
