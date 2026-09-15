GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot

.PHONY: run test export lint verify

run:
	$(GODOT) --path .

test:
	$(GODOT) --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit

lint:
	@command -v gdlint >/dev/null 2>&1 && gdlint src scenes autoloads test || echo "gdlint ausente: instale com pipx install gdtoolkit"

export:
	mkdir -p build/web
	$(GODOT) --headless --path . --export-release "Web" build/web/index.html

verify: lint test export
