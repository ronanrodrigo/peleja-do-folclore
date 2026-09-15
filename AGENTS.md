# AGENTS.md — Peleja do Folclore

Jogo de luta 2D em pixel art, Godot 4.7.2 (GDScript), export web single-threaded, deploy estático no Vercel.

## Comandos (rode antes de qualquer explicação)

```bash
make run        # abre o jogo no editor Godot
make test       # GUT headless: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
make export     # export web single-threaded para build/web
make verify     # lint (gdlint) + test + export; é o gate de PR
```

## Estrutura

- `src/domain/` — regras puras de combate (sem `Node`, sem `SceneTree`, sem I/O)
- `src/application/` — serviços de caso de uso (partida, arcade, progressão)
- `src/interface-adapters/` — tradução de input e binding de HUD
- `src/infrastructure/` — carregamento de assets, áudio, persistência
- `scenes/` — cenas Godot (camada `app`), finas: só montam e delegam
- `autoloads/` — composition root (wiring de dependências)
- `assets/` — spritesheets JSON, paletas, áudio, painéis
- `test/` — testes GUT, colados ao comportamento que verificam
- `docs/` — architecture.md, adr/, plans/, implementation-progress.md

## Convenções

- Código, nomes de arquivo, classes, sinais e chaves de configuração em inglês; copy do jogo em pt-BR.
- Domínio não importa nada de Godot além de `RefCounted`/tipos puros. Nada de `get_node` no domínio.
- Direção de dependência para dentro: `scenes/autoloads -> interface-adapters -> application -> domain`.
- Pixel art sempre em escala inteira (3x), `texture_filter` nearest, sem suavização.
- Commits em pt-BR, Conventional Commits. Branch a partir da `main`, PR via `gh`, merge só com checks verdes.

## Boundaries

- **Sempre:** rodar `make verify` antes de abrir PR; atualizar `docs/implementation-progress.md` ao fechar uma fatia.
- **Perguntar antes:** adicionar dependência externa, mudar resolução base, mudar política de representação dos oponentes.
- **Nunca:** commitar segredos; usar símbolos reais de organizações criminosas ou históricas; retratar pessoas reais; publicar arte de terceiros sem licença compatível.

## Gotchas

- Export web com threads exige `SharedArrayBuffer` e headers COOP/COEP; o Vercel não os dá por padrão — exporte **single-threaded**.
- Export templates precisam existir em `~/Library/Application Support/Godot/export_templates/<versão>`; sem eles o `--export-release` falha.
- GUT headless precisa de `-gexit` ou o processo nunca termina.
- Sprite fora de escala inteira destrói o grid de pixel: nunca escale por fator fracionário.
