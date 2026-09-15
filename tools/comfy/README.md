# tools/comfy — arte gerada por ComfyUI (fora das camadas do jogo)

Ferramentaria de geracao e pos-processamento da arte de **cenarios, paineis de
Reviravolta e retratos** (ADR 0005). Lutadores e oponentes nao passam por aqui:
sao spritesheets codificados como dados.

## Pre-requisitos

- ComfyUI local de pe: `curl -s http://127.0.0.1:8188/system_stats` responde JSON
  (sem ele, `comfy launch --background`).
- Checkpoint SD 1.5 (a maquina e um M4 com 16 GB unificados: SDXL/Flux ficam
  apertados). O checkpoint **nao** e versionado no repositorio:

  ```bash
  comfy model download \
    --url "https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors" \
    --relative-path models/checkpoints
  comfy model list        # confirma v1-5-pruned-emaonly.safetensors
  ```

- `Pillow` disponivel no `python3` (pos-processamento).

## Arquivos

| Arquivo | Papel |
|---|---|
| `workflows/pixelart_bg.json` | Workflow em formato **API** (nao o do editor): SD 1.5 txt2img 512x288, 28 passos, cfg 7.0, `dpmpp_2m`/`karras` |
| `scripts/run_workflow.py` | Cliente HTTP do ComfyUI (stdlib): injeta prompt/negativo/seed/tamanho por papel, enfileira, espera e baixa |
| `postprocess.py` | Pos-processamento obrigatorio: 426x240 com **nearest**, paleta do jogo + dominantes em **ate 32 cores** |
| `generate.py` | Gera as tres artes, escreve `<slug>.json` e reescreve `CREDITS.md` |
| `extract_palette.py` | Extrai `assets/palettes/peleja.json` das cores da tela de titulo |
| `test_postprocess.py` | Teste executavel do pos-processamento (roda sem GPU, sem rede) |

## Como rodar

```bash
# 1. paleta do jogo a partir da tela de titulo (so quando ela mudar)
python3 tools/comfy/extract_palette.py

# 2. gerar as tres artes (o tamanho/passos vem do workflow versionado)
python3 tools/comfy/generate.py
python3 tools/comfy/generate.py --only forest-arena    # uma so

# 3. validar o que esta publicado (426x240 e <= 32 cores) + metadados
python3 tools/comfy/generate.py --verify
python3 tools/comfy/test_postprocess.py

# ou, pelos alvos do Makefile
make test-art
```

O resumo da geracao sai em JSON com o `prompt_id`, a seed e os arquivos -- e a
evidencia a colar no PR. Cada arte sai em `assets/generated/<tipo>/<slug>.png`
com o `<slug>.json` ao lado (prompt, prompt negativo, seed, workflow, modelo,
licenca, URL de origem e sha256 do PNG). `assets/generated/CREDITS.md` e
reescrito a cada geracao.

## Prompt

O prompt vem do template **verbatim** da skill `rrn:pixel-art` (bloco de Visual
Style e prompt negativo inclusive). Os campos entre chaves sao preenchidos em
`generate.py`: onde o questionario tem opcao literal, o texto e o da opcao; onde
a arte nao tem personagem (cenario, painel), o campo e livre e esta anotado em
`prompt_field_notes` no `.json` da arte. Nenhuma arte usa pessoa real, simbolo
real ou referencia religiosa (ADR 0004).

## Pitfalls

- O ComfyUI 0.36.0 valida **todo** top-level do workflow como no do grafo: uma
  chave de documentacao como `"_comment"` derruba o `/prompt` com HTTP 500
  (`validate_prompt` faz `node_data.get('_meta', {})` em cima de uma `str`).
  Por isso nenhum workflow aqui tem chave de comentario, e
  `scripts/run_workflow.py` descarta chaves com `_` antes de enfileirar.
- Gere em 16:9 (512x288). Gerar em 512x512 e depois reduzir para 426x240
  achata a imagem (fator 0.47 na vertical contra 0.83 na horizontal).
- Nunca salve a versao ampliada: o arquivo publicado fica em 426x240; a
  ampliacao 3x acontece na renderizacao, com escala inteira (ADR 0002).
- O estilo da skill pede "retro dithering": sem o freio `no dithering noise,
  simple large flat shapes` nos campos de sujeito, o SD 1.5 devolve textura
  granulada que a quantizacao transforma em chuvisco.
- Arte ausente ou ComfyUI fora do ar nao quebra o jogo: o
  `godot-asset-gateway` cai no fallback em codigo (ver
  `test/infrastructure/asset_gateway_fallback_test.gd`).
