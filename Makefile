GODOT ?= $(shell command -v godot 2>/dev/null || echo /Applications/Godot.app/Contents/MacOS/Godot)
GUT_SCRIPT ?= addons/gut/gut_cmdln.gd
TEST_DIR ?= res://test
WEB_PRESET ?= Web
BUILD_DIR ?= build/web

.PHONY: run import test lint export verify clean test-art capture-saci capture-cast

run:
	$(GODOT) --path .

import:
	$(GODOT) --headless --path . --import

# Testes sempre no modo sample: adapters deterministicos, sem I/O.
test: import
	PELEJA_ADAPTERS=sample $(GODOT) --headless --path . -s $(GUT_SCRIPT) -gdir=$(TEST_DIR) -ginclude_subdirs -gexit

lint:
	gdlint src scenes autoloads test tools

# Validacao da arte gerada por IA: pos-processamento (426x240, <= 32 cores) e
# arte publicada + metadados. Complementa o verify; nao depende do ComfyUI no ar.
test-art:
	python3 tools/comfy/test_postprocess.py
	python3 tools/comfy/generate.py --verify

# Prints de evidencia do ticket 4: cada animacao do Saci desenhada pelo
# sprite-render-adapter de producao, em docs/evidence/.
capture-saci: import
	$(GODOT) --path . tools/capture_saci.tscn -- res://docs/evidence

# Prints de evidencia do ticket 5: a tela de selecao dos 4 Guardioes e cada um
# em luta, com a arte codificada desenhada pelo renderer de producao.
capture-cast: import
	$(GODOT) --path . tools/capture_cast.tscn -- res://docs/evidence

# Export web single-threaded (preset "Web" usa a variante nothreads).
export: import
	mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . --export-release "$(WEB_PRESET)" $(BUILD_DIR)/index.html

verify: lint test export

clean:
	rm -rf build .godot