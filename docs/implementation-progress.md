# Progresso de implementacao

Registro por fatia fechada. Cada entrada exige evidencia executavel (regra de
evidencia do ADR 0006) -- nunca "pronto" declarado.

## Ticket 1 — Esqueleto jogavel e deploy

**Estado:** fechado.

**Entregue**

- `project.godot`: resolucao base 426x240, `default_texture_filter` nearest,
  autoload `app_container`, renderizador `gl_compatibility` (o melhor alvo web).
- `export_presets.cfg`: preset `Web` **single-threaded**
  (`variant/thread_support=false`), saida `build/web/index.html`, com
  `test/`, `addons/gut/` e `docs/` fora do pacote publicado.
- `scenes/title_screen.tscn` + `scenes/title_screen.gd`: tela de titulo em pixel
  art codificada em dados (fonte bitmap 5x7 escrita a mao + silhuetas
  deterministicas). Nenhum asset externo, nenhuma fonte de terceiros.
- `autoloads/app_container.gd`: composition root. Unico lugar que instancia
  adapters; modo `sample`/`live` por configuracao explicita (env
  `PELEJA_ADAPTERS`, argumento `--adapters=`, project setting
  `peleja/adapters/mode`); nenhum estado de jogo.
- `src/application/gateways/`: os cinco contratos de capacidade, um por arquivo.
- `src/infrastructure/sample/`: cinco adapters deterministicos, sem I/O.
- `addons/gut/`: GUT 9.7.1 (`bitwes/Gut`, tag `v9.7.1`, commit
  `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`), vendorizado.
- `test/smoke/`: testes GUT de bootstrap, de contrato dos adapters sample e da
  tela de titulo.
- `.github/workflows/ci.yml`: `barichello/godot-ci:4.7.2` rodando `make verify`
  em PR e push na `main`.
- `vercel.json`: deploy estatico de `build/web`.

**Evidencia de fechamento**

- `make verify` sai com codigo 0: gdlint `Success: no problems found`; GUT
  headless `19/19` testes, `125` asserts, com `-gexit`; export gerou
  `index.html`, `index.js`, `index.pck` e `index.wasm`.
- Export comprovadamente single-threaded: `build/web/index.wasm` tem
  `39514754` bytes, exatamente o `godot.wasm` de `web_nothreads_release.zip`
  (a variante com threads mede `38820072`).
- Build servido localmente responde 200 e o jogo publicado aparece na URL do
  Vercel (print anexado ao PR).

**Dividas assumidas nesta fatia**

- Modo `live` ainda cai para os adapters `sample` nas cinco capacidades, porque
  nenhum adapter de producao existe: `keyboard-input-adapter` e
  `sprite-render-adapter` chegam no ticket 3/4, `godot-asset-gateway` no ticket
  4, `godot-audio-gateway` e `local-persistence-gateway` no ticket 8.
  `app_container.missing_production()` reporta o que falta, e o teste cobre o
  fallback.
- A tela de titulo desenha o proprio placeholder; ela passa a delegar ao
  `render-gateway` de producao quando o `sprite-render-adapter` existir.