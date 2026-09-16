class_name CharacterSelectService
extends RefCounted
## Caso de uso "selecao de personagem": navega os 4 Guardioes e devolve o
## escolhido como DADO.
##
## A selecao e comando-e-estado puro: a cena drena o `input-gateway` injetado e
## entrega os comandos aqui (`handle_commands`), e o resultado sai por
## `result()` -- o Guardiao escolhido, pronto para alimentar o arcade. Nenhum
## singleton, nenhuma variavel global e nenhuma leitura de engine: duas
## instancias deste servico nao se enxergam (o estado da selecao vive aqui, nao
## no composition root).
##
## O consumo por `arcade-service` acontece quando o ticket 6 chegar; aqui o
## contrato e somente o dado de saida.

## Passo de navegacao no sentido dos comandos do jogador.
const STEP_LEFT := -1
const STEP_RIGHT := 1

## Posicao do cursor no elenco (base zero) e Guardiao ja confirmado.
var cursor: int = 0
var confirmed_guardian: String = ""


func _init(p_cursor: int = 0) -> void:
	cursor = clampi(p_cursor, 0, count() - 1)


## Elenco completo, na ordem da tela (copia do dado do dominio).
func roster() -> Array:
	return GuardianStats.all()


func count() -> int:
	return GuardianStats.count()


## Guardiao sob o cursor.
func guardian_name() -> String:
	return str(roster()[cursor]) if count() > 0 else ""


## Slugs do elenco inteiro, na ordem da tela (nome de arquivo da spritesheet).
func slugs() -> PackedStringArray:
	var names := PackedStringArray()
	for guardian_name in roster():
		names.append(GuardianStats.slug_for(guardian_name))
	return names


func slug() -> String:
	return GuardianStats.slug_for(guardian_name())


## Nome do Golpe Especial do Guardiao sob o cursor (copy pt-BR do golpe).
func special_name() -> String:
	return SpecialMoveTable.display_name_for(guardian_name())


## Uma linha por Guardiao: nome, slug, nome do especial e se esta selecionado.
## E o dado que a tela de selecao e a HUD consomem -- sem tocar em no de UI.
func rows() -> Array:
	var entries: Array = []
	var names := roster()
	for index in names.size():
		var guardian_name := str(names[index])
		entries.append(
			{
				"index": index,
				"name": guardian_name,
				"slug": GuardianStats.slug_for(guardian_name),
				"special_name": SpecialMoveTable.display_name_for(guardian_name),
				"selected": index == cursor,
			}
		)
	return entries


## Move o cursor, dando a volta no elenco (navegacao de arcade).
func move_cursor(step: int) -> bool:
	if count() == 0 or step == 0:
		return false
	cursor = posmod(cursor + step, count())
	return true


## Coloca o cursor numa posicao valida. Fora do intervalo nao mexe em nada.
func select(index: int) -> bool:
	if index < 0 or index >= count():
		return false
	cursor = index
	return true


## Executa um comando do jogador. Devolve verdadeiro quando o comando mudou o
## estado da selecao.
func handle_command(command: int) -> bool:
	match command:
		InputGateway.Command.MOVE_LEFT:
			return move_cursor(STEP_LEFT)
		InputGateway.Command.MOVE_RIGHT:
			return move_cursor(STEP_RIGHT)
		InputGateway.Command.CONFIRM:
			confirm()
			return true
		InputGateway.Command.CANCEL:
			reset()
			return true
		_:
			return false


## Executa uma fila de comandos, na ordem; devolve verdadeiro quando algum deles
## mudou a selecao (a confirmacao tambem conta: ela fecha a escolha).
func handle_commands(commands: Array) -> bool:
	var changed := false
	for command in commands:
		if handle_command(command):
			changed = true
		if is_confirmed():
			break
	return changed


## Fecha a escolha e devolve o Guardiao escolhido como dado. Sem elenco devolve
## string vazia (nunca inventa Guardiao).
func confirm() -> String:
	confirmed_guardian = guardian_name()
	return confirmed_guardian


func is_confirmed() -> bool:
	return not confirmed_guardian.is_empty()


## Volta a selecao ao estado inicial (o comando de cancelar da tela).
func reset() -> void:
	cursor = 0
	confirmed_guardian = ""


## Guardiao escolhido, pronto para o arcade (ticket 6). Vazio enquanto a
## escolha nao foi confirmada.
func result() -> Dictionary:
	if not is_confirmed():
		return {}
	return {
		"guardian": confirmed_guardian,
		"slug": GuardianStats.slug_for(confirmed_guardian),
		"special_name": SpecialMoveTable.display_name_for(confirmed_guardian),
	}


## Retrato do estado da selecao. Nunca inclui numero de combate: a selecao nao
## conhece vida, dano nem Vantagem Oculta.
func snapshot() -> Dictionary:
	return {
		"cursor": cursor,
		"count": count(),
		"guardian": guardian_name(),
		"slug": slug(),
		"special_name": special_name(),
		"confirmed": is_confirmed(),
		"confirmed_guardian": confirmed_guardian,
	}


## Lista de nomes do elenco na ordem da tela (atalho para HUD e evidencia).
func display_names() -> PackedStringArray:
	var names := PackedStringArray()
	for guardian_name in roster():
		names.append(str(guardian_name))
	return names
