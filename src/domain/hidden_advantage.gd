class_name HiddenAdvantage
extends RefCounted
## Vantagem Oculta (ADR 0003): o Guardiao sempre tem mais vida e mais dano que o
## Oponente, e isso nunca aparece na interface.
##
## A regra e dado explicito, nao um ajuste espalhado: quem monta a Peleja chama
## `apply()` no Guardiao e os Oponentes ficam com os numeros do seu Arquetipo. A
## garantia (Guardiao > Oponente) e verificada por teste para todos os Arquetipos.

const HEALTH_FACTOR := 1.6
const DAMAGE_FACTOR := 1.4


## Guardiao com a Vantagem Oculta aplicada. Nao altera os numeros originais.
static func apply(guardian: FighterStats) -> FighterStats:
	return guardian.with_advantage(HEALTH_FACTOR, DAMAGE_FACTOR)


static func health_margin(guardian: FighterStats, opponent: FighterStats) -> int:
	return guardian.max_health - opponent.max_health


static func damage_margin(guardian: FighterStats, opponent: FighterStats) -> float:
	return guardian.damage_multiplier - opponent.damage_multiplier


## Verdadeiro apenas quando as duas vantagens existem: mais vida e mais dano.
static func has_advantage(guardian: FighterStats, opponent: FighterStats) -> bool:
	return health_margin(guardian, opponent) > 0 and damage_margin(guardian, opponent) > 0
