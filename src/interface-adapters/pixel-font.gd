class_name PixelFont
extends RefCounted
## Fonte bitmap 5x7 escrita a mao, desenhada em pixel art.
##
## Vive na borda de apresentacao: recebe texto e devolve uma imagem ja em escala
## **inteira** (nunca fracionaria), com `#` acendendo o pixel. Nenhum arquivo de
## fonte de terceiros entra no projeto -- o desenho e dado versionado aqui.
##
## Acentuadas que precisam de cedilha ou til defino usam uma linha extra (ver
## `Ç` e `Õ`): o desenho continua alinhado pelo topo, como no resto da fonte.

const GLYPH_WIDTH := 5
const GLYPH_SPACING := 1
## Glifo usado quando o caractere nao existe na fonte (nunca pixel silencioso).
const UNKNOWN_GLYPH := "?"

## Cada glifo e uma sequencia de linhas de `GLYPH_WIDTH` colunas separadas por
## "/". "#" acende o pixel.
const GLYPHS := {
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
	"Ç": ".###./#...#/#..../#..../#..../#...#/.###./..##.",
	"Õ": ".#.#./#.#.#/.###./#...#/#...#/#...#/#...#/.###.",
	"Ã": ".#.#./#.#.#/.###./#...#/#...#/#...#/#...#",
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
	".": "...../...../...../...../...../...../..#..",
	"?": ".###./#...#/....#/...#./..#../...../..#..",
	":": "...../..#../..#../...../..#../..#../.....",
	"%": "##..#/##.#./..#../.#.../#.##./..###/.....",
	"/": "....#/...#./..#../.#.../#..../...../.....",
}


## Linhas do glifo; caractere fora da fonte devolve o `UNKNOWN_GLYPH`.
func rows(character: String) -> PackedStringArray:
	var encoded: String = GLYPHS.get(character, GLYPHS[UNKNOWN_GLYPH])
	return encoded.split("/")


## Verdadeiro quando todo caractere do texto tem glifo proprio (sem "?").
func supports(text: String) -> bool:
	for index in text.length():
		if not GLYPHS.has(text.substr(index, 1)):
			return false
	return true


func text_size(text: String, pixel_scale: int = 1) -> Vector2i:
	var scale := maxi(pixel_scale, 1)
	var glyphs: int = text.length()
	var source_width := maxi(glyphs * (GLYPH_WIDTH + GLYPH_SPACING) - GLYPH_SPACING, 1)
	return Vector2i(source_width * scale, _tallest(text) * scale)


## Converte texto em imagem pela fonte, ja em escala inteira.
func text_image(text: String, pixel_scale: int = 1, color: Color = Color.WHITE) -> Image:
	assert(pixel_scale >= 1, "escala de pixel tem de ser inteira e >= 1")
	var glyph_rows: Array = []
	var tallest := 1
	for index in text.length():
		var glyph := rows(text.substr(index, 1))
		glyph_rows.append(glyph)
		tallest = maxi(tallest, glyph.size())
	var source_width := maxi(
		text.length() * (GLYPH_WIDTH + GLYPH_SPACING) - GLYPH_SPACING, 1
	)
	var image := Image.create_empty(source_width, tallest, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var pen_x := 0
	for glyph in glyph_rows:
		for row_index in glyph.size():
			var row: String = glyph[row_index]
			for column in row.length():
				if row.substr(column, 1) == "#":
					image.set_pixel(pen_x + column, row_index, color)
		pen_x += GLYPH_WIDTH + GLYPH_SPACING
	if pixel_scale > 1:
		image.resize(
			source_width * pixel_scale, tallest * pixel_scale, Image.INTERPOLATE_NEAREST
		)
	return image


## Textura pronta para um `TextureRect` com filtro nearest.
func text_texture(
	text: String, pixel_scale: int = 1, color: Color = Color.WHITE
) -> ImageTexture:
	return ImageTexture.create_from_image(text_image(text, pixel_scale, color))


func _tallest(text: String) -> int:
	var tallest := 1
	for index in text.length():
		tallest = maxi(tallest, rows(text.substr(index, 1)).size())
	return tallest