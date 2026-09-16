class_name MeterStealMove
extends RefCounted
## Golpe de Oponente que rouba a Barra de Especial do Guardiao.
##
## O Banqueiro cobra "juros compostos" e o Falso Pastor cobra o "dizimo": os dois
## tiram unidades da Barra de Especial de quem apanha e passam para quem bate. A
## regra e pura -- sem temporizador, sem entrada, sem cena, sem engine.
##
## O efeito de jogo do roubo e indireto e proposital: o Golpe Especial do Guardiao
## continua exigindo a barra CHEIA (`Fighter.start_special`), entao roubar barra
## adia o Especial dele sem tocar na regra ja existente.
##
## A tabela (`for_archetype`) devolve null para os Arquetipos que nao roubam: o
## dado nunca inventa regra, so devolve o que existe (Banqueiro e Falso Pastor,
## ADR 0004). Nenhum campo aqui carrega pessoa real, simbolo real ou religiao: o
## que se critica e a cobranca.

## O Banqueiro: os juros compostos comem a barra de quem apanha.
const BANQUEIRO_DISPLAY_NAME := "Juros Compostos"
const BANQUEIRO_TAKE_UNITS := 25
## O Falso Pastor: o dizimo cobra a barra -- o alvo e o charlatao, nunca a fe.
const FALSO_PASTOR_DISPLAY_NAME := "Dizimo"
const FALSO_PASTOR_TAKE_UNITS := 20

## Copy pt-BR do golpe (nome da assinatura do Arquetipo).
var display_name: String
## Unidades de Barra de Especial tiradas de quem apanha.
var take_units: int


func _init(p_display_name: String = "", p_take_units: int = 0) -> void:
	display_name = p_display_name
	take_units = maxi(p_take_units, 0)


func is_named(other_name: String) -> bool:
	return not display_name.is_empty() and display_name == other_name


## Tira `take_units` da Barra de Especial do defensor e passa para o atacante.
## Devolve quanto saiu de verdade -- nunca mais do que a barra tinha, e zero
## quando nao ha barra para roubar.
func steal_from(defender: Fighter, attacker: Fighter) -> int:
	if defender == null or defender.meter == null:
		return 0
	if take_units <= 0 or defender.meter.is_empty():
		return 0
	var stolen: int = defender.meter.drain(take_units)
	if stolen > 0 and attacker != null and attacker.meter != null:
		attacker.meter.gain(stolen)
	return stolen


## Golpe que rouba a Barra de Especial de um Arquetipo, ou null quando ele nao
## cobra nada de ninguem.
static func for_archetype(archetype: int) -> MeterStealMove:
	match archetype:
		Archetype.Id.BANQUEIRO:
			return MeterStealMove.new(BANQUEIRO_DISPLAY_NAME, BANQUEIRO_TAKE_UNITS)
		Archetype.Id.FALSO_PASTOR:
			return MeterStealMove.new(FALSO_PASTOR_DISPLAY_NAME, FALSO_PASTOR_TAKE_UNITS)
		_:
			return null


static func steals_meter(archetype: int) -> bool:
	return for_archetype(archetype) != null


## Os Arquetipos que roubam a Barra de Especial, na ordem fixa do arcade.
static func stealers() -> Array:
	var found: Array = []
	for archetype in ArcadeOrder.ORDER:
		if steals_meter(archetype):
			found.append(archetype)
	return found
