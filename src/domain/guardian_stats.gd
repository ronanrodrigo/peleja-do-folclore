class_name GuardianStats
extends FighterStats
## Numeros do Guardiao (o lutador do folclore, escolhido pelo jogador).
##
## Sao os numeros base, antes da Vantagem Oculta: quem monta uma Peleja aplica
## `HiddenAdvantage.apply()` e so entao o Guardiao entra no round (ADR 0003).

const BASE_HEALTH := 1000
const BASE_DAMAGE_MULTIPLIER := 1.25
const BASE_BLOCK_REDUCTION := 0.6
const BASE_WALK_SPEED := 3
const BASE_METER_ON_HIT := 12
const BASE_METER_ON_HURT := 8

## Guardioes previstos no elenco (ticket 5); os dois ultimos entram depois.
const SACI := "Saci"
const CURUPIRA := "Curupira"
const IARA := "Iara"
const CUCA := "Cuca"


func _init(p_display_name: String = SACI) -> void:
	super(
		p_display_name,
		BASE_HEALTH,
		BASE_DAMAGE_MULTIPLIER,
		BASE_BLOCK_REDUCTION,
		BASE_WALK_SPEED,
		BASE_METER_ON_HIT,
		BASE_METER_ON_HURT
	)


static func for_guardian(p_display_name: String) -> GuardianStats:
	return GuardianStats.new(p_display_name)


## Guardiao com a Vantagem Oculta ja aplicada: e este que entra na Peleja.
static func advantaged(p_display_name: String) -> FighterStats:
	return HiddenAdvantage.apply(GuardianStats.new(p_display_name))
