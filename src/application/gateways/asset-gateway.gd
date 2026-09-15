class_name AssetGateway
extends RefCounted
## Contrato da capacidade "obter arte e dados por identificador".
##
## Uma capacidade, um arquivo. A arte nunca e um PNG binario opaco de lutador:
## e dado versionado (paleta + matrizes de pixel) ou arte gerada por slug com
## fallback obrigatorio, para o jogo nunca quebrar por arte ausente.

## O identificador existe no repositorio de arte?
func exists(_id: String) -> bool:
	return false


## Paleta de cores por identificador. Vazia quando o identificador nao existe.
func load_palette(_id: String) -> PackedColorArray:
	return PackedColorArray()


## Spritesheet decodificado por slug. Dicionario vazio quando nao existe.
func load_spritesheet(_slug: String) -> Dictionary:
	return {}


## Painel de tela cheia por slug, com fallback obrigatorio.
func load_panel(_slug: String, _fallback: PackedByteArray) -> PackedByteArray:
	return _fallback