# Formato de spritesheet codificado

Arte de lutador no Peleja do Folclore **não é PNG binário opaco**: é dado
versionado em JSON — uma paleta mais matrizes de pixel (ADR 0005). Este documento
fixa o formato que todos os lutadores do elenco (`saci`, e depois `curupira`,
`iara`, `cuca`) e os Oponentes reusam. O modelo e a validação vivem em
`src/domain/spritesheet.gd`; o carregamento em
`src/infrastructure/godot-asset-gateway.gd`; o desenho em
`src/interface-adapters/sprite-render-adapter.gd`.

## Arquivo

`assets/spritesheets/<slug>.json`, onde `<slug>` é o identificador em inglês do
lutador (`saci`). O arquivo é lido pelo `asset-gateway` (`load_spritesheet`),
decodificado por `Spritesheet.decode` e validado por `Spritesheet.is_valid()`.

```json
{
  "slug": "saci",
  "version": 1,
  "palette": ["#00000000", "#14121aff", "..."],
  "animations": {
    "idle": [
      { "width": 24, "height": 34, "pixels": ["...................", "..."] }
    ]
  }
}
```

### Chaves de topo

| Chave | Tipo | Regra |
| --- | --- | --- |
| `slug` | string | Obrigatório, não vazio; igual ao nome do arquivo. |
| `version` | inteiro | Obrigatório; precisa ser `Spritesheet.FORMAT_VERSION` (hoje `1`). |
| `palette` | lista de cores | Obrigatória; de 1 a 256 cores. Índice `0` é sempre transparente. |
| `animations` | objeto | Obrigatório; nome da animação (inglês) → lista de frames. |

### Animação e frame

Cada animação é uma lista não vazia de frames. Cada frame tem `width`, `height`
e `pixels`; **todos os frames de uma animação têm exatamente as mesmas
dimensões**. Um frame fica dentro da resolução base (426x240) — o formato não
aceita quadro maior que a tela.

### `pixels`: três codificações equivalentes

Na ordem de leitura (linha por linha, da esquerda para a direita):

1. **Lista plana** de índices: `[0, 1, 1, 2, ...]`.
2. **Lista de linhas**, cada linha uma lista de índices: `[[0, 1], [2, 0]]`.
3. **Linhas em texto compacto** (a usada pelo Saci, legível como arte no diff):
   um caractere por pixel, na base 36 — o índice `i` da paleta escreve-se com o
   caractere `Spritesheet.PIXEL_CHARS[i]`, ou seja:

   ```text
   índice:    0    1    2    3    4    5    6    7    8    9   10   11
   caractere: .    1    2    3    4    5    6    7    8    9    a    b
   ```

   `.` (`Spritesheet.TRANSPARENT_CHAR`) é o pixel transparente. Caractere fora
   do alfabeto **não passa em silêncio**: vira problema de decodificação,
   reportado por `errors()`.

## Regras de validação (`Spritesheet.errors()`)

A lista volta vazia quando a spritesheet é válida; caso contrário, nomeia cada
problema:

- `slug` ausente; `version` diferente da suportada;
- paleta vazia ou com mais de 256 cores (`MAX_PALETTE_SIZE`);
- **animação obrigatória ausente** — todo lutador precisa de
  `REQUIRED_ANIMATIONS`: `idle`, `walk`, `crouch`, `block`, `light`, `heavy`,
  `grab`, `special`, `hurt`, `ko`;
- animação sem frames ou que não é lista de frames;
- frame sem dimensões, ou maior que a resolução base;
- frame que difere em dimensão do resto da animação;
- contagem de pixels diferente de `width * height`;
- índice de pixel fora da paleta;
- caractere inválido na codificação compacta.

Índice de paleta fora do intervalo é recusado na validação, mas lido como
transparente na renderização: o jogo nunca quebra por um frame torto — ele é
reportado e o teste de formato falha no CI.

## Renderização (escala inteira, nearest, letterbox)

- A arte é **sempre** desenhada em escala **inteira** (`pixel_scale >= 1`),
  padrão **3x** (`RenderGateway.DEFAULT_PIXEL_SCALE`). Escala fracionária não
  existe na API (o parâmetro é inteiro) e qualquer valor `< 1` é recusado pela
  `render-gateway` e registrado em `rejected_scales` — nunca desenhado borrado.
- O desenho vai para uma superfície RGBA8 de **426x240**
  (`RenderGateway.BASE_SIZE`) e é apresentado num `TextureRect` com
  `TEXTURE_FILTER_NEAREST` e **letterbox**: `SpriteRenderAdapter.display_scale()`
  acha o maior múltiplo inteiro do espaço disponível e `letterbox_rect()`
  centraliza a sobra. Janela 1278x720 → 3x; 900x500 → 2x; 400x300 → 1x.
- Na renderização, o pixel de índice `TRANSPARENT_INDEX` (0) é pulado: a
  transparência é da paleta, nunca um PNG com canal alfa opaco.

## O Saci (`assets/spritesheets/saci.json`)

Paleta de 12 cores (índice 0 transparente; contorno, pele e sombra, gorro
vermelho e vermelho escuro, branco, cachimbo, vento claro e escuro, amarelo do
folclore, pupila). Todas as animações exigidas, com os tamanhos reais:

| Animação | Frames | Quadro | O que mostra |
| --- | --- | --- | --- |
| `idle` | 2 | 24x34 | respiração: o corpo sobe um pixel no segundo quadro |
| `walk` | 4 | 24x34 | troca de passo com os braços alternando |
| `crouch` | 2 | 26x20 | agachado: corpo encolhido, mais baixo e mais largo |
| `block` | 2 | 24x34 | antebraços cruzados na frente do peito |
| `light` | 2 | 24x34 | golpe leve: braço estendido |
| `heavy` | 2 | 32x34 | golpe pesado: a perna única esticada (quadro mais largo) |
| `grab` | 2 | 24x34 | agarrão: os dois braços à frente |
| `special` | 3 | 40x40 | **Redemoinho**: o turbilhão cresce e o Saci reaparece dentro dele |
| `hurt` | 2 | 24x34 | dano: corpo jogado para trás, boca aberta |
| `ko` | 2 | 34x20 | nocaute: tombando e depois caído, com o gorro no chão |

O Redemoinho não é só desenho: o efeito de puxão vive no domínio
(`SpecialMove` / `SpecialMoveTable`), é aplicado no `match-service` durante a
janela ativa do golpe, e o Golpe Especial consome a Barra de Especial inteira e
só dispara com a barra cheia (`Fighter.start_special`).

## O resto do elenco (ticket 5)

Os outros três Guardiões reusam exatamente o mesmo formato e o mesmo esquema de
quadros da tabela acima (corpo 24x34, agachado 26x20, pesado 32x34, especial
40x40, nocaute 34x20), com dez animações e três quadros no `special`:

| Slug | Guardião | Golpe Especial | O que a arte e o efeito mostram |
| --- | --- | --- | --- |
| `curupira` | Curupira | **Pés Invertidos** | cabelo de fogo e pés virados (calcanhar na frente); o quadro do especial traz as pegadas correndo ao contrário |
| `iara` | Iara | **Canto do Rio** | cabelo de rio, concha e cauda de escamas; o especial traz as ondas, as notas e o abraço d'água |
| `cuca` | Cuca | **Nana Neném** | focinho de jacaré com dentes e cabelo de fogo; o especial traz o jacaré inteiro mordendo |

O efeito de cada um é dado na `SpecialMoveTable` (aplicado na janela ativa do
golpe): `invert_ticks` e `knockback_pixels` nos Pés Invertidos, `sleep_ticks` e
`drain_per_tick` no Canto do Rio, `sleep_ticks` e `bite_per_tick` no Nana Neném.

## Como (re)gerar

A arte é autoral e determinística: `tools/art/build_saci_spritesheet.py` desenha
o Saci com primitivas e emite o JSON. O script é fronteira de ferramentaria,
fora das camadas do jogo — o jogo só lê o JSON versionado.

```bash
python3 tools/art/build_saci_spritesheet.py                 # regrava o JSON
python3 tools/art/build_saci_spritesheet.py --preview /tmp/saci.png   # inspeção
make capture-saci                                          # prints de evidência
```

## Adicionar um lutador novo

1. Escreva `assets/spritesheets/<slug>.json` com as dez animações obrigatórias
   (ou reusa um gerador como o do Saci).
2. Cobre o formato no teste: `Spritesheet.decode` das animações obrigatórias,
   dimensões por animação, paleta dentro do máximo, nenhum pixel fora da paleta.
3. Nome do golpe e efeito entram em `SpecialMoveTable` como dado — por adição,
   nunca mudando o contrato existente.
