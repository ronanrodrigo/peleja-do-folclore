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
## Elenco completo dos 4 Guardioes jogaveis, na ordem da tela de selecao. E dado,
## nunca codigo espalhado: a selecao, o HUD e a ferramenta de evidencia leem daqui.
const ROSTER := [SACI, CURUPIRA, IARA, CUCA]

## Identificador em ingles de cada Guardiao (nome de arquivo da spritesheet).
const SLUGS := {
	SACI: "saci",
	CURUPIRA: "curupira",
	IARA: "iara",
	CUCA: "cuca",
}


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


## Os 4 Guardioes, na ordem do elenco (copia da lista, para o chamador nao
## mexer no dado do dominio).
static func all() -> Array:
	return ROSTER.duplicate()


static func is_guardian(p_display_name: String) -> bool:
	return ROSTER.has(p_display_name)


static func count() -> int:
	return ROSTER.size()


## Slug em ingles do Guardiao, ou vazio quando o nome nao e do elenco.
static func slug_for(p_display_name: String) -> String:
	return str(SLUGS.get(p_display_name, ""))


## Nome de exibicao do Guardiao a partir do slug, ou vazio quando o slug nao e
## de nenhum Guardiao do elenco.
static func display_name_for_slug(slug: String) -> String:
	for guardian_name in ROSTER:
		if SLUGS.get(guardian_name, "") == slug:
			return guardian_name
	return ""


static func slugs() -> PackedStringArray:
	var names := PackedStringArray()
	for guardian_name in ROSTER:
		names.append(slug_for(guardian_name))
	return names
