GODOT ?= $(shell command -v godot 2>/dev/null || echo /Applications/Godot.app/Contents/MacOS/Godot)
GUT_SCRIPT ?= addons/gut/gut_cmdln.gd
TEST_DIR ?= res://test
WEB_PRESET ?= Web
BUILD_DIR ?= build/web

.PHONY: run import test lint export verify clean

run:
	$(GODOT) --path .

import:
	$(GODOT) --headless --path . --import

# Testes sempre no modo sample: adapters deterministicos, sem I/O.
test: import
	PELEJA_ADAPTERS=sample $(GODOT) --headless --path . -s $(GUT_SCRIPT) -gdir=$(TEST_DIR) -ginclude_subdirs -gexit

lint:
	gdlint src scenes autoloads test tools

# Export web single-threaded (preset "Web" usa a variante nothreads).
export: import
	mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . --export-release "$(WEB_PRESET)" $(BUILD_DIR)/index.html

verify: lint test export

clean:
	rm -rf build .godot