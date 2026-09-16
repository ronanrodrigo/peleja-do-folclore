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
			return SpecialMove.new()


## Nome do Golpe Especial de um Guardiao (copy pt-BR do golpe), ou vazio quando
## ele ainda nao tem efeito proprio cadastrado.
static func display_name_for(guardian_name: String) -> String:
	return for_guardian(guardian_name).display_name
