extends GutTest
## Perfis dos 7 Arquetipos: aparencia, golpe proprio e padrao de IA como DADO.
##
## Cobre tambem a politica do ADR 0004 no nivel do dado: nome satirico, sem
## pessoa real, sem simbolo real e sem referencia a religiao.

## Termos que nao podem aparecer em nenhum nome de Arquetipo ou de golpe: sao
## pessoas reais, simbolos reais e vocabulario religioso. Palavras inteiras
## (tokens), para nao barrar "Pilula" por causa de "lula".
const FORBIDDEN_TOKENS := [
	"lula",
	"bolsonaro",
	"hitler",
	"mussolini",
	"jesus",
	"deus",
	"cristo",
	"ss",
	"pt",
]

## Trechos que nao podem aparecer em lugar nenhum do nome.
const FORBIDDEN_SUBSTRINGS := [
	"igreja",
	"biblia",
	"bíblia",
	"cruz",
	"crucifixo",
	"templo",
	"suastica",
	"suástica",
	"swastika",
	"pastor de",
	"nazista",
]


func test_every_archetype_has_a_profile() -> void:
	assert_eq(OpponentProfile.roster().size(), 7, "um perfil por Arquetipo")
	for archetype in Archetype.ALL:
		var profile := OpponentProfile.for_archetype(archetype)
		assert_not_null(profile, "perfil do Arquetipo %d" % archetype)
		assert_eq(profile.archetype, archetype)
		assert_eq(profile.slug, Archetype.slug(archetype), "a aparencia vem do slug")
		assert_eq(profile.display_name, Archetype.display_name(archetype))


func test_an_unknown_archetype_has_no_profile() -> void:
	assert_null(OpponentProfile.for_archetype(99))
	assert_null(OpponentProfile.for_archetype(-1))


func test_every_opponent_has_its_own_signature_move() -> void:
	var names: Array = []
	for archetype in Archetype.ALL:
		var profile := OpponentProfile.for_archetype(archetype)
		assert_true(profile.has_signature(), "todo Arquetipo tem golpe proprio")
		var move := profile.signature_move()
		assert_not_null(move)
		assert_eq(move.display_name, profile.signature_name)
		assert_gt(move.damage, 0, "o golpe proprio machuca")
		assert_gt(move.reach, 0, "o golpe proprio alcanca")
		assert_gt(move.total_frames(), 0, "o golpe proprio tem janela")
		names.append(profile.signature_name)
	assert_eq(names.size(), 7)
	for name in names:
		assert_eq(names.count(name), 1, "nenhum golpe-assinatura repetido: %s" % name)


func test_the_signature_move_window_is_data_not_a_hardcoded_frame() -> void:
	var banqueiro := OpponentProfile.for_archetype(Archetype.Id.BANQUEIRO)
	var move := banqueiro.signature_move()
	assert_eq(move.startup_frames, banqueiro.signature_startup)
	assert_eq(move.active_frames, banqueiro.signature_active)
	assert_eq(move.recovery_frames, banqueiro.signature_recovery)
	assert_eq(move.is_active_at(banqueiro.signature_startup), true)
	assert_eq(move.is_active_at(banqueiro.signature_startup - 1), false)


func test_the_doutrina_pierces_the_guard_and_the_rest_do_not() -> void:
	var pureza := OpponentProfile.for_archetype(Archetype.Id.DOUTOR_PUREZA)
	assert_false(pureza.signature_move().blockable, "a doutrina enfraquece pela guarda")
	for archetype in Archetype.ALL:
		var profile := OpponentProfile.for_archetype(archetype)
		if archetype == Archetype.Id.DOUTOR_PUREZA:
			continue
		assert_true(profile.signature_move().blockable, "%s e bloqueavel" % profile.slug)


func test_only_the_banker_and_the_false_preacher_steal_the_meter() -> void:
	var stealers := MeterStealMove.stealers()
	assert_eq(
		stealers,
		[Archetype.Id.BANQUEIRO, Archetype.Id.FALSO_PASTOR],
		"so os Arquetipos da cobranca roubam a Barra de Especial"
	)
	for archetype in Archetype.ALL:
		var profile := OpponentProfile.for_archetype(archetype)
		if archetype in stealers:
			assert_true(profile.steals_meter())
			assert_ne(profile.steal_name(), "")
			assert_eq(
				profile.signature_name,
				profile.meter_steal.display_name,
				"o roubo dispara no golpe-assinatura do Arquetipo"
			)
		else:
			assert_false(profile.steals_meter(), "%s nao cobra barra" % profile.slug)


func test_every_opponent_has_a_distinct_ai_pattern() -> void:
	var aggression: Array = []
	var signature: Array = []
	for archetype in ArcadeOrder.ORDER:
		var profile := OpponentProfile.for_archetype(archetype)
		var ai := OpponentAi.new(OpponentAi.Difficulty.NORMAL)
		ai.apply_overrides(profile.ai_overrides)
		aggression.append(ai.value_of("aggression"))
		signature.append(ai.signature_chance)
	for index in range(1, aggression.size()):
		assert_gt(
			aggression[index],
			aggression[index - 1],
			"a agressao cresce ao longo do arcade (posicao %d)" % index
		)
	for index in range(1, signature.size()):
		assert_gt(
			signature[index],
			signature[index - 1],
			"o golpe proprio aparece mais adiante no arcade (posicao %d)" % index
		)


func test_applying_the_profile_does_not_touch_the_shared_difficulty_data() -> void:
	var before := OpponentAi.PROFILES[OpponentAi.Difficulty.NORMAL].duplicate()
	var profile := OpponentProfile.for_archetype(Archetype.Id.FALSO_PASTOR)
	var ai := OpponentAi.new(OpponentAi.Difficulty.NORMAL)
	ai.apply_overrides(profile.ai_overrides)
	assert_eq(ai.value_of("aggression"), profile.ai_value("aggression"))
	assert_eq(ai.signature_chance, profile.signature_chance())
	assert_eq(
		OpponentAi.PROFILES[OpponentAi.Difficulty.NORMAL],
		before,
		"o dado compartilhado de dificuldade fica intacto"
	)


func test_the_ai_ladder_from_the_levels_survives_the_profile() -> void:
	var profile := OpponentProfile.for_archetype(Archetype.Id.CAPATAZ)
	var easy := OpponentAi.new(OpponentAi.Difficulty.EASY)
	var hard := OpponentAi.new(OpponentAi.Difficulty.HARD)
	easy.apply_overrides(profile.ai_overrides)
	hard.apply_overrides(profile.ai_overrides)
	assert_lt(easy.value_of("block_chance"), hard.value_of("block_chance"))
	assert_lt(easy.value_of("special_chance"), hard.value_of("special_chance"))
	assert_gt(easy.reaction_ticks(), hard.reaction_ticks())


func test_the_ai_can_choose_the_signature_move_when_the_profile_asks() -> void:
	var ai := OpponentAi.new(OpponentAi.Difficulty.NORMAL)
	ai.apply_overrides({"signature_chance": 1.0, "aggression": 1.0})
	assert_true(OpponentAi.is_attack(OpponentAi.Action.SIGNATURE))
	assert_eq(OpponentAi.action_name(OpponentAi.Action.SIGNATURE), "signature")
	var duel := Fighter.duel(GuardianStats.SACI, Archetype.Id.CAPATAZ, 3, 4)
	var opponent: Fighter = duel["opponent"]
	var guardian: Fighter = duel["guardian"]
	opponent.position.x = guardian.position.x + 18
	assert_eq(ai.decide(opponent, guardian, Rng.new(9)), OpponentAi.Action.SIGNATURE)


func test_a_profile_without_signature_chance_never_asks_for_it() -> void:
	var ai := OpponentAi.new(OpponentAi.Difficulty.NORMAL)
	var duel := Fighter.duel(GuardianStats.SACI, Archetype.Id.CAPATAZ, 3, 4)
	var opponent: Fighter = duel["opponent"]
	var guardian: Fighter = duel["guardian"]
	var rng := Rng.new(11)
	for index in 200:
		opponent.position.x = guardian.position.x + 18
		assert_ne(
			ai.decide(opponent, guardian, rng),
			OpponentAi.Action.SIGNATURE,
			"sem `signature_chance` a IA nao inventa o golpe proprio"
		)


func test_the_roster_slugs_match_the_spritesheets() -> void:
	var slugs := []
	for profile in OpponentProfile.roster():
		slugs.append(profile.slug)
	assert_eq(slugs, Array(Archetype.slugs()), "um Oponente por Arquetipo, na ordem fixa")
	assert_eq(slugs.size(), 7)


## Politica do ADR 0004 checada no dado: nome satirico, sem pessoa real, sem
## simbolo real e sem referencia a religiao. O alvo e o comportamento.
func test_the_policy_holds_for_every_name_in_the_data() -> void:
	var names: Array = []
	for archetype in Archetype.ALL:
		var profile := OpponentProfile.for_archetype(archetype)
		names.append(profile.display_name)
		names.append(profile.signature_name)
		names.append(profile.steal_name())
	for name in names:
		var lowered: String = str(name).to_lower()
		for term in FORBIDDEN_SUBSTRINGS:
			assert_false(
				lowered.contains(term),
				"'%s' nao pode conter o termo proibido '%s'" % [name, term]
			)
		var tokens := lowered.replace("-", " ").split(" ", false)
		for token in tokens:
			assert_false(
				token in FORBIDDEN_TOKENS,
				"'%s' nao pode citar '%s': o alvo e o comportamento" % [name, token]
			)
	for archetype in Archetype.ALL:
		assert_true(
			Archetype.display_name(archetype).begins_with("O "),
			"o nome e um apelido satirico, nunca um nome proprio"
		)
