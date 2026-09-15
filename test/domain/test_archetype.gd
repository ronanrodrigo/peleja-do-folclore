extends GutTest
## Os 7 Arquetipos como dado: slug, nome e posicao (ADR 0004).

## Slugs fixados pelo ADR 0004; mudar esta lista e mudar o jogo.
const EXPECTED_SLUGS := [
	"capataz",
	"banqueiro",
	"redpill",
	"camisa-verde",
	"doutor-pureza",
	"fantasma-do-reich",
	"falso-pastor",
]


func test_there_are_seven_archetypes() -> void:
	assert_eq(Archetype.count(), 7)
	assert_eq(Archetype.ALL.size(), Archetype.DATA.size())


func test_slugs_match_the_adr() -> void:
	assert_eq(Array(Archetype.slugs()), EXPECTED_SLUGS, "ordem e nomes vem do ADR 0004")


func test_every_archetype_has_slug_and_display_name() -> void:
	for archetype in Archetype.ALL:
		assert_true(Archetype.is_known(archetype))
		assert_ne(Archetype.slug(archetype), "", "todo Arquetipo tem slug")
		assert_ne(Archetype.display_name(archetype), "", "todo Arquetipo tem nome")


func test_slugs_are_unique() -> void:
	var unique := {}
	for slug in Archetype.slugs():
		unique[slug] = true
	assert_eq(unique.size(), Archetype.count(), "nenhum slug repetido")


func test_index_and_id_round_trip() -> void:
	for archetype in Archetype.ALL:
		assert_eq(Archetype.id_at(Archetype.index_of(archetype)), archetype)


func test_unknown_archetype_is_empty() -> void:
	assert_false(Archetype.is_known(99))
	assert_eq(Archetype.slug(99), "")
	assert_eq(Archetype.display_name(99), "")
	assert_eq(Archetype.index_of(99), -1)
	assert_eq(Archetype.id_at(99), -1)
	assert_eq(Archetype.id_at(-1), -1)


func test_opponents_are_personas_not_real_identities() -> void:
	for archetype in Archetype.ALL:
		var opponent_name := Archetype.display_name(archetype)
		assert_true(
			opponent_name.begins_with("O "),
			"%s e uma persona satirica, nunca o nome de alguem" % opponent_name
		)
