class_name OpponentStats
extends FighterStats
## Numeros de um Oponente do arcade, por Arquetipo, em dificuldade crescente.
##
## Nenhum Oponente alcanca os numeros do Guardiao com a Vantagem Oculta
## aplicada: quanto mais adiante no arcade, mais resistencia e dano o Oponente
## tem, mas a vantagem do folclore continua inteira (ADR 0003, ADR 0007).

const BASE_HEALTH := 620
const HEALTH_STEP := 45
const BASE_DAMAGE_MULTIPLIER := 0.72
const DAMAGE_STEP := 0.03
const BASE_BLOCK_REDUCTION := 0.35
const BASE_WALK_SPEED := 2
const BASE_METER_ON_HIT := 10
const BASE_METER_ON_HURT := 10

## Posicao do Arquetipo no arcade, base zero; define a dificuldade.
var arcade_index: int


func _init(p_display_name: String = "", p_arcade_index: int = 0) -> void:
	arcade_index = maxi(p_arcade_index, 0)
	super(
		p_display_name,
		BASE_HEALTH + HEALTH_STEP * arcade_index,
		BASE_DAMAGE_MULTIPLIER + DAMAGE_STEP * float(arcade_index),
		BASE_BLOCK_REDUCTION,
		BASE_WALK_SPEED,
		BASE_METER_ON_HIT,
		BASE_METER_ON_HURT
	)


## Oponente do Arquetipo pedido, com a dificuldade da posicao dele no arcade.
## Devolve null para Arquetipo desconhecido.
static func for_archetype(archetype: int) -> OpponentStats:
	var index := Archetype.index_of(archetype)
	if index < 0:
		return null
	var opponent := OpponentStats.new(Archetype.display_name(archetype), index)
	opponent.arcade_index = index
	return opponent


## Os sete Oponentes do arcade, na ordem fixa.
static func arcade_roster() -> Array:
	var roster: Array = []
	for archetype in ArcadeOrder.ORDER:
		roster.append(OpponentStats.for_archetype(archetype))
	return roster
