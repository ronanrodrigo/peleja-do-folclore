# Plano — ComfyUI local para a arte de cenários, painéis e UI

Objetivo: gerar pixel art de **cenários, painéis de Reviravolta, retratos e UI** nesta máquina
(Apple M4, 16 GB unificados) e integrar os arquivos ao jogo. Lutadores e oponentes **não** passam
por aqui: eles são spritesheets codificados (ADR 0005).

## Fase A — Diagnóstico de hardware (antes de instalar)

```bash
python ~/.hermes/skills/creative/comfyui/scripts/hardware_check.py --json
```

Veredito esperado nesta máquina: `marginal` (16 GB unificados ficam abaixo dos 32 GB recomendados).
Consequência: usar **SD 1.5** (pixel art), não SDXL nem Flux; resolução de geração baixa
(512x512 ou 640x384) já que a saída final é 426x240. Se o veredito vier `cloud`, decidir entre
Comfy Cloud (paga) ou forçar local.

## Fase B — Instalação

```bash
pipx install comfy-cli            # ou: uvx --from comfy-cli comfy --help
comfy --skip-prompt tracking disable
comfy --skip-prompt install --m-series
comfy launch --background
curl -s http://127.0.0.1:8188/system_stats   # health check
```

## Fase C — Modelos e workflow

```bash
# checkpoint SD 1.5 (pixel art; ~4 GB)
comfy model download --url "<url-do-checkpoint-pixel-art>" --relative-path models/checkpoints
comfy model list
```

- Workflow em formato **API** (não editor) salvo em `tools/comfy/workflows/pixelart_bg.json`.
- Prompt montado pela skill `rrn:pixel-art` (Visual Style e prompt negativo verbatim).
- Rodar com `scripts/run_workflow.py --workflow ... --args '{"prompt": "...", "seed": -1}'`.

## Fase D — Pós-processamento obrigatório

1. Reduzir para a resolução alvo com **nearest-neighbor**.
2. Quantizar a paleta (máx. 32 cores) e alinhar à paleta do jogo.
3. Ampliar por fator inteiro (3x) apenas na renderização; nunca salvar ampliado com filtro suave.
4. Conferir legibilidade de texto pixelado: no máximo 2-3 palavras por elemento de UI.

## Fase E — Integração

- Saída em `assets/generated/<tipo>/<slug>.png` + `.json` de metadados (prompt, seed, workflow, licença).
- O `godot-asset-gateway` carrega por slug; arte ausente cai no fallback em código.
- Licença: só modelos e checkpoints com licença compatível com uso público; registrar em
  `assets/generated/CREDITS.md`.

## Critérios de saída

- `curl http://127.0.0.1:8188/system_stats` responde JSON.
- `comfy model list` mostra o checkpoint.
- Um cenário gerado, quantizado e integrado, aparecendo no jogo (print como evidência).
- `assets/generated/CREDITS.md` com modelo, licença e URL de origem.
