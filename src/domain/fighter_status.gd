class_name FighterStatus
extends RefCounted
## Conjunto de status ativos de um lutador, como dado puro.
##
## Os Golpes Especiais deixam status no alvo (Pes Invertidos troca o lado do
## movimento, Canto do Rio e Nana Nenem adormecem). O conjunto vive aqui, num
## objeto proprio, e nao dentro do `Fighter`: o lutador continua com a mesma
## superficie publica de antes e quem guarda/consulta status usa `fighter.statuses`.
##
## Avanca por tick de simulacao (nunca por temporizador) e nunca conhece cena,
## no de UI ou engine.

## Status ativos, na ordem em que entraram.
var active: Array = []


## Adiciona um status; o mesmo efeito batendo de novo RENOVA a duracao em vez de
## empilhar (dois sonos nao viram o dobro de sono).
func add(effect: StatusEffect) -> void:
	if effect == null or not effect.is_active():
		return
	for current in active:
		if current.kind == effect.kind:
			current.refresh(effect.ticks_remaining)
			return
	active.append(StatusEffect.new(effect.kind, effect.ticks_remaining))


func has(kind: int) -> bool:
	for current in active:
		if current.kind == kind and current.is_active():
			return true
	return false


## Ticks restantes de um status (0 quando ele nao esta ativo).
func remaining(kind: int) -> int:
	for current in active:
		if current.kind == kind:
			return current.ticks_remaining
	return 0


## Adormecido: nao aceita comando nenhum enquanto durar.
func is_asleep() -> bool:
	return has(StatusEffect.Kind.SLEEP)


## Comandos de movimento com o lado trocado (Pes Invertidos do Curupira).
func inverts_controls() -> bool:
	return has(StatusEffect.Kind.INVERT_CONTROLS)


func clear() -> void:
	active.clear()


func count() -> int:
	return active.size()


## Nomes em ingles dos status ativos (relatorio, HUD e teste).
func names() -> PackedStringArray:
	var labels := PackedStringArray()
	for current in active:
		if current.is_active():
			labels.append(StatusEffect.name_of(current.kind))
	return labels


## Avanca um tick e descarta os status que terminaram.
func advance() -> void:
	if active.is_empty():
		return
	var remaining_statuses: Array = []
	for current in active:
		if not current.advance_tick():
			remaining_statuses.append(current)
	active = remaining_statuses