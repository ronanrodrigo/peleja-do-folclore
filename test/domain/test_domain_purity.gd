extends GutTest
## Invariante 1 de docs/architecture.md: o dominio nao importa engine.
##
## Este teste le o codigo-fonte de `src/domain/` e recusa no, cena, entrada,
## arquivo, audio, rede e temporizador. Nao e estilo: e o que garante que as
## regras de combate rodem headless e que os testes provem o jogo, nao a engine.

const DOMAIN_DIRECTORY := "res://src/domain"

## Nucleo de combate do ticket 2; cada arquivo tem teste espelhado em test/domain/.
const EXPECTED_FILES := [
	"archetype.gd",
	"arcade_order.gd",
	"bounding_box.gd",
	"fighter.gd",
	"fighter_state.gd",
	"fighter_stats.gd",
	"guardian_stats.gd",
	"health.gd",
	"hidden_advantage.gd",
	"match_rules.gd",
	"move.gd",
	"opponent_ai.gd",
	"opponent_stats.gd",
	"rng.gd",
	"round_clock.gd",
	"special_meter.gd",
	"spritesheet.gd",
]

## Nada disso pode aparecer no dominio, nem em codigo nem em comentario.
const FORBIDDEN_TOKENS := [
	"Node",
	"SceneTree",
	"Input",
	"Timer",
	"FileAccess",
	"DirAccess",
	"AudioServer",
	"HTTPRequest",
	"HTTPClient",
	"ResourceLoader",
	"OS.",
	"res://",
	"user://",
	"preload(",
	"get_node",
	"await ",
	"signal ",
	"@onready",
	"@export",
]


func test_every_expected_domain_file_exists() -> void:
	var files := _domain_files()
	for expected in EXPECTED_FILES:
		assert_true(files.has(expected), "arquivo de dominio presente: %s" % expected)


func test_domain_does_not_contain_any_engine_token() -> void:
	var checked := 0
	for file_name in _domain_files():
		var source := _source_of(DOMAIN_DIRECTORY + "/" + file_name)
		assert_ne(source, "", "codigo-fonte lido: %s" % file_name)
		checked += 1
		for token in FORBIDDEN_TOKENS:
			assert_false(
				source.contains(token),
				"%s nao pode conter '%s': engine proibida no dominio" % [file_name, token]
			)
	assert_eq(checked, _domain_files().size(), "todos os arquivos do dominio foram checados")
	assert_gt(checked, 0, "o dominio tem codigo para checar")


func test_domain_files_extend_only_refcounted_or_domain_classes() -> void:
	var domain_classes := _domain_class_names()
	for file_name in _domain_files():
		var source := _source_of(DOMAIN_DIRECTORY + "/" + file_name)
		var target := _extends_target(source)
		assert_ne(target, "", "%s declara de que herda" % file_name)
		assert_true(
			target == "RefCounted" or domain_classes.has(target),
			"%s herda apenas de RefCounted ou de classe do dominio (achado: %s)" % [file_name, target]
		)


func test_every_domain_file_declares_a_class_name() -> void:
	for file_name in _domain_files():
		var source := _source_of(DOMAIN_DIRECTORY + "/" + file_name)
		assert_true(
			_class_name_of(source) != "", "classe nomeada em %s (nomes em ingles)" % file_name
		)


func _domain_files() -> Array:
	var files: Array = []
	var directory := DirAccess.open(DOMAIN_DIRECTORY)
	if directory == null:
		return files
	for file_name in directory.get_files():
		if file_name.ends_with(".gd"):
			files.append(file_name)
	files.sort()
	return files


func _domain_class_names() -> Array:
	var names: Array = []
	for file_name in _domain_files():
		var declared := _class_name_of(_source_of(DOMAIN_DIRECTORY + "/" + file_name))
		if declared != "":
			names.append(declared)
	return names


func _class_name_of(source: String) -> String:
	for line in source.split("\n"):
		if line.begins_with("class_name "):
			return line.trim_prefix("class_name ").strip_edges()
	return ""


func _extends_target(source: String) -> String:
	for line in source.split("\n"):
		if line.begins_with("extends "):
			return line.trim_prefix("extends ").strip_edges()
	return ""


func _source_of(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
