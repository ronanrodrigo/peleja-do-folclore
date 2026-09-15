# Peleja do Folclore

Jogo de luta 2D em pixel art (estilo arcade/Street Fighter) feito em Godot 4.7, exportado para web.
Lutadores do folclore brasileiro enfrentam, em arcade de 7 lutas, arquétipos satíricos do poder:
o capataz, o banqueiro, o redpill, o camisa-verde, o doutor pureza, o fantasma do reich e o falso pastor.

Os guardiões do folclore são sempre mais fortes. Se o oponente vencer a melhor de três, a mata
resolve a questão — e ele é derrotado de todo modo.

- Jogar: https://peleja.ronanrodrigo.dev
- Documentação de arquitetura: `docs/architecture.md`
- Decisões: `docs/adr/`
- Glossário: `CONTEXT.md`
- Plano do ComfyUI: `docs/plans/comfyui.md`

## Comandos

```bash
# rodar o jogo no editor
/Applications/Godot.app/Contents/MacOS/Godot --path .

# testes (GUT, headless)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit

# export web (single-threaded)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" build/web/index.html

# gate completo
make verify
```
