class_name ArcadeOrder
extends RefCounted
## Ordem fixa do arcade (ADR 0007): 7 Pelejas, uma por Arquetipo, em dificuldade
## crescente e sem chefe final.
##
## A ordem e dado, nunca codigo espalhado: quem monta o arcade recebe esta lista
## e nao decide nada por conta propria. Rejogabilidade vem de trocar de Guardiao,
## nunca de sortear Oponente (invariante 3 de docs/architecture.md).

const ORDER := [
	Archetype.Id.CAPATAZ,
	Archetype.Id.BANQUEIRO,
	Archetype.Id.REDPILL,
	Archetype.Id.CAMISA_VERDE,
	Archetype.Id.DOUTOR_PUREZA,
	Archetype.Id.FANTASMA_DO_REICH,
	Archetype.Id.FALSO_PASTOR,
]


static func count() -> int:
	return ORDER.size()


## Arquetipo na posicao pedida, ou -1 fora do intervalo.
static func archetype_at(index: int) -> int:
	if index < 0 or index >= ORDER.size():
		return -1
	return ORDER[index]


## Posicao base zero do Arquetipo no arcade, ou -1 quando ele nao esta na ordem.
static func index_of(archetype: int) -> int:
	return ORDER.find(archetype)


static func slugs() -> PackedStringArray:
	var names := PackedStringArray()
	for archetype in ORDER:
		names.append(Archetype.slug(archetype))
	return names


## Verdadeiro quando a ordem cobre cada Arquetipo exatamente uma vez.
static func is_complete() -> bool:
	if ORDER.size() != Archetype.count():
		return false
	for archetype in Archetype.ALL:
		if ORDER.count(archetype) != 1:
			return false
	return true
