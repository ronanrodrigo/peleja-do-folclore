class_name Archetype
extends RefCounted
## Os 7 Arquetipos satiricos do poder (ADR 0004).
##
## Dado puro: nome, slug e nada mais. Nenhum Arquetipo usa pessoa real, simbolo
## real, nome de organizacao historica nem referencia a religiao. A critica e ao
## comportamento e ao poder, nunca a identidade de quem assiste (CONTEXT.md).

enum Id {
	CAPATAZ,
	BANQUEIRO,
	REDPILL,
	CAMISA_VERDE,
	DOUTOR_PUREZA,
	FANTASMA_DO_REICH,
	FALSO_PASTOR,
}

## Todos os Arquetipos, na ordem dos ADR 0004 e 0007.
const ALL := [
	Id.CAPATAZ,
	Id.BANQUEIRO,
	Id.REDPILL,
	Id.CAMISA_VERDE,
	Id.DOUTOR_PUREZA,
	Id.FANTASMA_DO_REICH,
	Id.FALSO_PASTOR,
]

const DATA := {
	Id.CAPATAZ: {"slug": "capataz", "display_name": "O Capataz"},
	Id.BANQUEIRO: {"slug": "banqueiro", "display_name": "O Banqueiro"},
	Id.REDPILL: {"slug": "redpill", "display_name": "O Redpill"},
	Id.CAMISA_VERDE: {"slug": "camisa-verde", "display_name": "O Camisa-Verde"},
	Id.DOUTOR_PUREZA: {"slug": "doutor-pureza", "display_name": "O Doutor Pureza"},
	Id.FANTASMA_DO_REICH: {"slug": "fantasma-do-reich", "display_name": "O Fantasma do Reich"},
	Id.FALSO_PASTOR: {"slug": "falso-pastor", "display_name": "O Falso Pastor"},
}


static func count() -> int:
	return ALL.size()


static func is_known(archetype: int) -> bool:
	return DATA.has(archetype)


## Slug usado em nome de arquivo de arte e em chave de dados.
static func slug(archetype: int) -> String:
	return str(DATA.get(archetype, {}).get("slug", ""))


static func display_name(archetype: int) -> String:
	return str(DATA.get(archetype, {}).get("display_name", ""))


## Posicao base zero na lista dos 7, ou -1 para Arquetipo desconhecido.
static func index_of(archetype: int) -> int:
	return ALL.find(archetype)


static func id_at(index: int) -> int:
	if index < 0 or index >= ALL.size():
		return -1
	return ALL[index]


static func slugs() -> PackedStringArray:
	var names := PackedStringArray()
	for archetype in ALL:
		names.append(slug(archetype))
	return names
