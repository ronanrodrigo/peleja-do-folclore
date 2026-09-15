# Creditos da arte gerada

Arte de cenario, paineis de Reviravolta e retratos gerada localmente para este
projeto. Lutadores e oponentes nao passam por aqui: sao spritesheets codificados
como dados (ADR 0005).

## Modelo

- Checkpoint: `v1-5-pruned-emaonly.safetensors`
- Licenca: CreativeML Open RAIL-M (modelo aberto, com as restricoes da licenca)
- URL de origem: https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors
- Model card: https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5
- Gerado com: ComfyUI 0.36.0 local (Apple M4, 16 GB unificados, backend MPS)

O checkpoint nao e versionado no repositorio (4 GB). Para reproduzir, baixe com
`comfy model download --url "<URL de origem>" --relative-path models/checkpoints`.

## Artes versionadas

| Arte | Slug | Seed | Prompt ID | Tamanho | Cores | Licenca |
|---|---|---|---|---|---|---|
| `res://assets/generated/backgrounds/forest-arena.png` | forest-arena | 42 | b5df59e5-8e82-4325-9a81-4ec4abb80617 | 426x240 | 32 | CreativeML Open RAIL-M |
| `res://assets/generated/panels/reviravolta-panel.png` | reviravolta-panel | 7 | 921fc2ad-afc6-4c31-a20f-bc09acc612ac | 426x240 | 30 | CreativeML Open RAIL-M |
| `res://assets/generated/portraits/saci-portrait.png` | saci-portrait | 42 | 978332d3-7187-4d0c-9cc8-dcf2c9507c56 | 426x240 | 32 | CreativeML Open RAIL-M |

## Terceiros

Nenhum arquivo de terceiros (fonte, textura ou trilha) entra neste repositorio
nesta fatia. O unico insumo externo e o checkpoint acima, sob CreativeML Open RAIL-M.

Os metadados completos de cada arte (prompt, prompt negativo, seed, workflow,
modelo e licenca) ficam no `.json` ao lado do `.png`.
