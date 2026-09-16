class_name OpponentProfile
extends RefCounted
## Perfil de combate de um Arquetipo: aparencia (slug do spritesheet), golpe
## proprio e o tempero de IA que distingue um Oponente do outro.
##
## Tudo e dado puro. A escada de dificuldade continua em `OpponentStats` (vida e
## dano por posicao no arcade) e em `OpponentAi` (agressao, defesa, Especial e
## tempo de reacao por nivel); o perfil so ACENTUA o comportamento de cada
## Arquetipo -- ele nunca zera a escada (ADR 0007).
##
## Politica do ADR 0004 (checada no PR): o nome e satirico, o golpe-assinatura
## critica o COMPORTAMENTO (o chicote, os juros, o spray, a marcha, a doutrina que
## drena, a ideia derrotada que assombra, o dizimo do charlatao) e nenhum campo
## carrega pessoa real, simbolo real de organizacao historica ou criminosa, nem
## referencia a religiao.

## Golpe-assinatura: a janela e a mesma moldura de `Move` (ticks de inicio,
## ativo e recuperacao), com o nome da assinatura do Arquetipo.
const DATA := {
	Archetype.Id.CAPATAZ: {
		"signature_name": "Chicote Largo",
		"kind": Move.Kind.HEAVY,
		"damage": 15,
		"reach": 34,
		"startup": 9,
		"active": 4,
		"recovery": 13,
		"blockable": true,
		"ai": {
			"aggression": 0.50,
			"retreat_chance": 0.20,
			"grab_chance": 0.20,
			"heavy_chance": 0.45,
			"signature_chance": 0.25,
		},
	},
	Archetype.Id.BANQUEIRO: {
		"signature_name": "Juros Compostos",
		"kind": Move.Kind.HEAVY,
		"damage": 12,
		"reach": 30,
		"startup": 8,
		"active": 5,
		"recovery": 12,
		"blockable": true,
		"ai": {
			"aggression": 0.55,
			"retreat_chance": 0.24,
			"grab_chance": 0.18,
			"heavy_chance": 0.30,
			"signature_chance": 0.30,
		},
	},
	Archetype.Id.REDPILL: {
		"signature_name": "Spray de Pilula",
		"kind": Move.Kind.LIGHT,
		"damage": 9,
		"reach": 30,
		"startup": 5,
		"active": 4,
		"recovery": 8,
		"blockable": true,
		"ai": {
			"aggression": 0.60,
			"retreat_chance": 0.14,
			"grab_chance": 0.24,
			"heavy_chance": 0.28,
			"signature_chance": 0.35,
		},
	},
	Archetype.Id.CAMISA_VERDE: {
		"signature_name": "Gaita de Marcha",
		"kind": Move.Kind.HEAVY,
		"damage": 14,
		"reach": 32,
		"startup": 10,
		"active": 4,
		"recovery": 14,
		"blockable": true,
		"ai": {
			"aggression": 0.66,
			"retreat_chance": 0.10,
			"grab_chance": 0.25,
			"heavy_chance": 0.40,
			"signature_chance": 0.38,
		},
	},
	Archetype.Id.DOUTOR_PUREZA: {
		"signature_name": "Teoria Drenante",
		"kind": Move.Kind.HEAVY,
		"damage": 11,
		"reach": 28,
		"startup": 9,
		"active": 6,
		"recovery": 15,
		# A doutrina passa por cima da guarda: e o "enfraquece" do Arquetipo.
		"blockable": false,
		"ai": {
			"aggression": 0.72,
			"retreat_chance": 0.12,
			"grab_chance": 0.30,
			"heavy_chance": 0.34,
			"signature_chance": 0.40,
		},
	},
	Archetype.Id.FANTASMA_DO_REICH: {
		"signature_name": "Vento de Cinzas",
		"kind": Move.Kind.HEAVY,
		"damage": 16,
		"reach": 36,
		"startup": 7,
		"active": 4,
		"recovery": 12,
		"blockable": true,
		"ai": {
			"aggression": 0.80,
			"retreat_chance": 0.08,
			"grab_chance": 0.22,
			"heavy_chance": 0.50,
			"signature_chance": 0.45,
		},
	},
	Archetype.Id.FALSO_PASTOR: {
		"signature_name": "Dizimo",
		"kind": Move.Kind.HEAVY,
		"damage": 10,
		"reach": 30,
		"startup": 7,
		"active": 4,
		"recovery": 12,
		"blockable": true,
		"ai": {
			"aggression": 0.88,
			"retreat_chance": 0.06,
			"grab_chance": 0.28,
			"heavy_chance": 0.42,
			"signature_chance": 0.50,
		},
	},
}

var archetype: int
## Slug da aparencia: `assets/spritesheets/<slug>.json` (arte como dado).
var slug: String
var display_name: String
## Copy pt-BR do golpe-assinatura.
var signature_name: String
var signature_kind: int
var signature_damage: int
var signature_reach: int
var signature_startup: int
var signature_active: int
var signature_recovery: int
var signature_blockable: bool
## Ajustes de IA mesclados sobre o nivel de dificuldade (`OpponentAi`).
var ai_overrides: Dictionary
## Golpe que rouba a Barra de Especial, ou null quando o Arquetipo nao rouba.
var meter_steal: MeterStealMove


func _init(p_archetype: int = -1) -> void:
	archetype = p_archetype
	var record: Dictionary = DATA.get(p_archetype, {})
	if record.is_empty():
		return
	slug = Archetype.slug(p_archetype)
	display_name = Archetype.display_name(p_archetype)
	signature_name = str(record["signature_name"])
	signature_kind = int(record["kind"])
	signature_damage = int(record["damage"])
	signature_reach = int(record["reach"])
	signature_startup = int(record["startup"])
	signature_active = int(record["active"])
	signature_recovery = int(record["recovery"])
	signature_blockable = bool(record["blockable"])
	ai_overrides = (record["ai"] as Dictionary).duplicate()
	meter_steal = MeterStealMove.for_archetype(p_archetype)


## Perfil do Arquetipo pedido, ou null quando ele nao existe.
static func for_archetype(p_archetype: int) -> OpponentProfile:
	if not Archetype.is_known(p_archetype):
		return null
	return OpponentProfile.new(p_archetype)


## Os sete perfis, na ordem fixa do arcade (ADR 0007).
static func roster() -> Array:
	var profiles: Array = []
	for p_archetype in ArcadeOrder.ORDER:
		profiles.append(OpponentProfile.new(p_archetype))
	return profiles


func has_signature() -> bool:
	return not signature_name.is_empty()


## O golpe proprio do Arquetipo, com o nome da assinatura. Null quando o perfil
## nao tem assinatura (Arquetipo desconhecido).
func signature_move() -> Move:
	if not has_signature():
		return null
	return Move.new(
		signature_kind,
		signature_damage,
		signature_reach,
		signature_startup,
		signature_active,
		signature_recovery,
		signature_blockable,
		signature_name
	)


## Vivendo do trabalho alheio: o Arquetipo tira Barra de Especial de quem apanha.
func steals_meter() -> bool:
	return meter_steal != null


func steal_name() -> String:
	return meter_steal.display_name if meter_steal != null else ""


## Ajuste de IA do Arquetipo, ou o padrao quando a chave nao existe no perfil.
func ai_value(key: String, fallback: float = 0.0) -> float:
	return float(ai_overrides.get(key, fallback))


func signature_chance() -> float:
	return ai_value("signature_chance", 0.0)
