GODOT ?= $(shell command -v godot 2>/dev/null || echo /Applications/Godot.app/Contents/MacOS/Godot)
GUT_SCRIPT ?= addons/gut/gut_cmdln.gd
TEST_DIR ?= res://test
WEB_PRESET ?= Web
BUILD_DIR ?= build/web

.PHONY: run import test lint export verify clean test-art test-audio audio capture-saci capture-cast capture-opponents capture-options capture-reviravolta

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
# Prints de evidencia do ticket 6: os 7 Oponentes do arcade desenhados pelo
# sprite-render-adapter de producao, um print por Arquetipo, em docs/evidence/.
capture-opponents: import
	$(GODOT) --path . tools/capture_opponents.tscn -- res://docs/evidence
# Audio: SFX e musica chiptune sintetizados no projeto (deterministico; os WAV
# gerados sao commitados em assets/audio/ com origem e licenca em CREDITS.md).
audio:
	python3 tools/audio/build_chiptune.py

# Confere que cada WAV commitado confere byte a byte com o gerador.
test-audio:
	python3 tools/audio/build_chiptune.py --verify

# Print de evidencia do ticket 8: tela de opcoes com volume e mudo, em
# docs/evidence/ticket-08-*.png.
capture-options: import
	$(GODOT) --path . tools/capture_options.tscn -- res://docs/evidence

# Print de evidencia do ticket 7: a Reviravolta disparada por uma Peleja
# perdida de verdade -- painel de tela cheia pelo asset-gateway, sequencia de
# texto da Forca Sobrenatural e efeitos de vento/raiz, em
# docs/evidence/ticket-07-*.png.
capture-reviravolta: import
	$(GODOT) --path . tools/capture_reviravolta.tscn -- res://docs/evidence

# Prints de evidencia do ticket 10 (fechamento do v1): titulo, selecao, a Peleja
# com os spritesheets desenhados pelo renderer de producao e o HUD final, o Golpe
# Especial, as telas de vitoria/derrota/fim de arcade e as opcoes com remap.
# Roda no modo `live` (e a arte de producao que precisa aparecer).
capture-release: import
	PELEJA_ADAPTERS=live $(GODOT) --path . tools/capture_release.tscn -- res://docs/evidence

# Export web single-threaded (preset "Web" usa a variante nothreads).
export: import
	mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --path . --export-release "$(WEB_PRESET)" $(BUILD_DIR)/index.html

verify: lint test export

clean:
	rm -rf build .godot
