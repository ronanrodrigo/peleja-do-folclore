class_name BitmapFont
extends RefCounted
## Fonte bitmap 5x7 da borda de apresentacao, como DADO escrito a mao.
##
## Cada glifo e uma sequencia de linhas de 5 colunas separadas por "/"; "#"
## acende o pixel. Nenhuma fonte de terceiros, nenhum arquivo externo: a copy do
## jogo e desenhada em pixels na resolucao base (426x240), sempre em escala
## inteira. Letras acentuadas em caixa alta (Á, Ã, Ç, É, Ê, Í, Ó, Ô, Õ, Ú) tem
## glifo proprio, porque a copy pt-BR do jogo nao e escrita sem acento.
##
## O texto entra em caixa alta: a fonte da tela de selecao so tem caixa alta, e
## `to_upper()` resolve o mapeamento de acento da copy.

const GLYPH_WIDTH := 5
const GLYPH_HEIGHT := 7
const GLYPH_SPACING := 1

const FONT_GLYPHS := {
	"A": ".###./#...#/#...#/#####/#...#/#...#/#...#",
	"B": "####./#...#/#...#/####./#...#/#...#/####.",
	"C": ".###./#...#/#..../#..../#..../#...#/.###.",
	"D": "####./#...#/#...#/#...#/#...#/#...#/####.",
	"E": "#####/#..../#..../####./#..../#..../#####",
	"F": "#####/#..../#..../####./#..../#..../#....",
	"G": ".###./#...#/#..../#.###/#...#/#...#/.###.",
	"H": "#...#/#...#/#...#/#####/#...#/#...#/#...#",
	"I": "#####/..#../..#../..#../..#../..#../#####",
	"J": "..###/...#./...#./...#./...#./#..#./.##..",
	"K": "#...#/#..#./#.#../##.../#.#../#..#./#...#",
	"L": "#..../#..../#..../#..../#..../#..../#####",
	"M": "#...#/##.##/#.#.#/#.#.#/#...#/#...#/#...#",
	"N": "#...#/##..#/#.#.#/#..##/#...#/#...#/#...#",
	"O": ".###./#...#/#...#/#...#/#...#/#...#/.###.",
	"P": "####./#...#/#...#/####./#..../#..../#....",
	"Q": ".###./#...#/#...#/#...#/#.#.#/#..#./.##.#",
	"R": "####./#...#/#...#/####./#.#../#..#./#...#",
	"S": ".####/#..../#..../.###./....#/....#/####.",
	"T": "#####/..#../..#../..#../..#../..#../..#..",
	"U": "#...#/#...#/#...#/#...#/#...#/#...#/.###.",
	"V": "#...#/#...#/#...#/#...#/#...#/.#.#./..#..",
	"W": "#...#/#...#/#...#/#.#.#/#.#.#/##.##/#...#",
	"X": "#...#/#...#/.#.#./..#../.#.#./#...#/#...#",
	"Y": "#...#/#...#/.#.#./..#../..#../..#../..#..",
	"Z": "#####/....#/...#./..#../.#.../#..../#####",
	"Á": "..#../.###./#...#/#####/#...#/#...#/#...#",
	"Ã": ".##.#/.###./#...#/#####/#...#/#...#/#...#",
	"Ç": ".###./#...#/#..../#..../#..../#...#/.###./..##.",
	"É": "#####/#..../####./#..../#..../#####/.....",
	"Ê": "..#../#####/#..../####./#..../#####/.....",
	"Í": "..#../#####/..#../..#../..#../..#../.###.",
	"Ó": "..#../.###./#...#/#...#/#...#/#...#/.###.",
	"Ô": "..#../.###./#...#/#...#/#...#/#...#/.###.",
	"Õ": ".##.#/.###./#...#/#...#/#...#/#...#/.###.",
	"Ú": "..#../#...#/#...#/#...#/#...#/#...#/.###.",
	"0": ".###./#...#/#..##/#.#.#/##..#/#...#/.###.",
	"1": "..#../.##../..#../..#../..#../..#../.###.",
	"2": ".###./#...#/....#/...#./..#../.#.../#####",
	"3": "####./....#/....#/.###./....#/....#/####.",
	"4": "...#./..##./.#.#./#..#./#####/...#./...#.",
	"5": "#####/#..../####./....#/....#/#...#/.###.",
	"6": ".###./#..../#..../####./#...#/#...#/.###.",
	"7": "#####/....#/...#./..#../.#.../.#.../.#...",
	"8": ".###./#...#/#...#/.###./#...#/#...#/.###.",
	"9": ".###./#...#/#...#/.####/....#/....#/.###.",
	" ": "...../...../...../...../...../...../.....",
	"!": "..#../..#../..#../..#../..#../...../..#..",
	"-": "...../...../...../...../.####/...../.....",
	":": "...../..#../..#../...../..#../..#../.....",
	".": "...../...../...../...../...../...../..#..",
	"?": ".###./#...#/....#/...#./..#../...../..#..",
	"_": "...../...../...../...../...../...../#####",
}


## Largura de um texto em pixels da resolucao base (sem escala).
static func text_width(text: String) -> int:
	if text.is_empty():
		return 0
	return text.length() * (GLYPH_WIDTH + GLYPH_SPACING) - GLYPH_SPACING


## Linhas de um caractere, ja em caixa alta; caractere desconhecido vira "?".
static func glyph_rows(character: String) -> PackedStringArray:
	var upper := character.to_upper()
	var encoded: String = FONT_GLYPHS.get(upper, FONT_GLYPHS["?"])
	return encoded.split("/")


## Imagem transparente com o texto desenhado em caixa alta, escala 1 (sem
## suavizacao: quem amplia usa `make_texture` com escala inteira). A altura
## acompanha o glifo mais alto do texto: `Ç` e `Õ` tem uma linha extra (cedilha e
## til), e a imagem nao pode cortar o que a copy pt-BR pede.
static func make_image(text: String, color: Color) -> Image:
	var upper := text.to_upper()
	var rows_count := _tallest(upper)
	var width := maxi(text_width(upper), 1)
	var image := Image.create_empty(width, rows_count, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var pen_x := 0
	for index in upper.length():
		var rows := glyph_rows(upper.substr(index, 1))
		for row_index in rows.size():
			var row: String = rows[row_index]
			for column in row.length():
				if row.substr(column, 1) == "#":
					image.set_pixel(pen_x + column, row_index, color)
		pen_x += GLYPH_WIDTH + GLYPH_SPACING
	return image


## Altura do glifo mais alto do texto (7 linhas, 8 quando ha cedilha ou til).
static func _tallest(text: String) -> int:
	var tallest := GLYPH_HEIGHT
	for index in text.length():
		tallest = maxi(tallest, glyph_rows(text.substr(index, 1)).size())
	return tallest


## Textura do texto em escala INTEIRA (o pixel art nunca e ampliado por fator
## fracionario: isso destruiria o grid de pixel).
static func make_texture(text: String, color: Color, pixel_scale: int = 1) -> ImageTexture:
	var image := make_image(text, color)
	if pixel_scale > 1:
		image.resize(
			image.get_width() * pixel_scale,
			image.get_height() * pixel_scale,
			Image.INTERPOLATE_NEAREST
		)
	return ImageTexture.create_from_image(image)
