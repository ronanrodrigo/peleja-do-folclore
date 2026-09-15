extends GutTest
## Estados do lutador: quais aceitam comando, quais sao travados.

const FREE := [
	FighterState.State.IDLE,
	FighterState.State.WALK,
	FighterState.State.CROUCH,
	FighterState.State.BLOCK,
]
const BUSY := [
	FighterState.State.ATTACK,
	FighterState.State.HURT,
	FighterState.State.KNOCKED_DOWN,
]


func test_every_state_has_a_name() -> void:
	for state in FighterState.NAMES.keys():
		assert_ne(FighterState.name_of(state), "unknown", "estado %d tem nome" % state)
	assert_eq(FighterState.name_of(-99), "unknown", "estado desconhecido nao quebra")


func test_only_free_states_accept_commands() -> void:
	for state in FREE:
		assert_true(
			FighterState.accepts_command(state), "%s aceita comando" % FighterState.name_of(state)
		)
	for state in BUSY:
		assert_false(
			FighterState.accepts_command(state), "%s nao aceita comando" % FighterState.name_of(state)
		)


func test_hurt_and_knockdown_are_out_of_control() -> void:
	assert_true(FighterState.is_controlled(FighterState.State.IDLE))
	assert_true(FighterState.is_controlled(FighterState.State.ATTACK))
	assert_false(FighterState.is_controlled(FighterState.State.HURT))
	assert_false(FighterState.is_controlled(FighterState.State.KNOCKED_DOWN))


func test_attack_state_is_recognised() -> void:
	assert_true(FighterState.is_attacking(FighterState.State.ATTACK))
	assert_false(FighterState.is_attacking(FighterState.State.BLOCK))
