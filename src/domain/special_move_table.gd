class_name SpecialMoveTable
extends RefCounted
## Tabela dos Golpes Especiais do elenco, como dado.
##
## Um golpe por Guardiao, com o nome da lenda e os parametros do efeito. Os
## Guardioes que ainda nao tem efeito proprio cadastrado recebem o Golpe Especial
## sem puxao: a tabela nunca inventa regra, so devolve o dado.

## Redemoinho do Saci: turbilhao curto e forte, que suga o Oponente para dentro.
const SACI_PULL_PER_TICK := 3
const SACI_PULL_REACH := 72


static func for_guardian(guardian_name: String) -> SpecialMove:
	match guardian_name:
		GuardianStats.SACI:
			return SpecialMove.new(
				SpecialMove.REDEMOINHO, SACI_PULL_PER_TICK, SACI_PULL_REACH
			)
		_:
			return _effect_for_roster(guardian_name)


## Nome do Golpe Especial de um Guardiao (copy pt-BR do golpe), ou vazio quando
## ele ainda nao tem efeito proprio cadastrado.
static func display_name_for(guardian_name: String) -> String:
	return for_guardian(guardian_name).display_name


## --- Ticket 5: efeitos proprios dos tres Guardioes seguintes (adicao no fim) ---
## Cada Guardiao novo entra AQUI, por adicao: o Saci e a funcao `for_guardian`
## acima continuam exatamente como estavam, e nenhum contrato muda.

## Efeito proprio dos Guardioes cadastrados depois do Saci. Um nome fora do
## elenco recebe o Golpe Especial sem efeito, como antes.
static func _effect_for_roster(guardian_name: String) -> SpecialMove:
	match guardian_name:
		GuardianStats.CURUPIRA:
			return SpecialMove.new(
				SpecialMove.PES_INVERTIDOS,
				0,
				0,
				180,  # 3 s de comandos invertidos (180 ticks a 60 por segundo)
				0,
				0,
				0,
				24  # derruba para o lado contrario ao que o alvo defende
			)
		GuardianStats.IARA:
			return SpecialMove.new(
				SpecialMove.CANTO_DO_RIO,
				0,
				0,
				0,
				120,  # 2 s de sono
				3  # vida drenada por tick de janela ativa, devolvida a Iara
			)
		GuardianStats.CUCA:
			return SpecialMove.new(
				SpecialMove.NANA_NENEM,
				0,
				0,
				0,
				120,  # 2 s de sono
				0,
				4  # a mordida de jacare, por tick de janela ativa
			)
		_:
			return SpecialMove.new()
