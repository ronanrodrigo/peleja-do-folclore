# Creditos de audio

Todo o audio do jogo e **sintetizado dentro do projeto**. Nao ha amostra, banco de
sons, trilha licenciada, musica de terceiros nem arquivo baixado da internet em
`assets/audio/`.

## Origem

| Origem | Como foi feito |
| --- | --- |
| `assets/audio/sfx/*.wav` | Sintetizados por `tools/audio/build_chiptune.py` (`SFX_BUILDERS`): osciladores quadrado/triangular/serra e ruido por registrador de deslocamento (LFSR), escritos no projeto |
| `assets/audio/music/*.wav` | Sintetizados por `tools/audio/build_chiptune.py` (`TRACKS`): sequenciador chiptune em grade de notas (melodia, baixo e bateria) |

Nenhum arquivo destes veio de fora do repositorio: o gerador e a unica origem, e
ele e deterministico (mesmo codigo, mesmos bytes). Para conferir:

```bash
python3 tools/audio/build_chiptune.py --verify   # confere byte a byte com o gerador
```

## Licenca

- **Titularidade:** obra do proprio projeto Peleja do Folclore. Os WAV sao
  derivados exclusivamente do codigo do repositorio (nenhum material de terceiros
  foi incorporado, copiado ou reaproveitado).
- **Licenca:** a mesma licenca do repositorio (ver `README.md`), sem nenhuma
  obrigacao de atribuicao a terceiros.
- **Dedicacao:** por serem gerados por codigo proprio, os arquivos podem ser
  regerados a qualquer momento por `python3 tools/audio/build_chiptune.py`; o
  gerador e o registro de origem e licenca desta pasta.

## Arquivos

### Efeitos (`assets/audio/sfx/`)

| Arquivo | Capacidade (`AudioGateway`) | Uso |
| --- | --- | --- |
| `impact_light.wav` | `impact_light` | golpe leve conectando |
| `impact_heavy.wav` | `impact_heavy` | golpe pesado ou agarrao conectando |
| `special.wav` | `special` | Golpe Especial armando (o redemoinho do Saci) |
| `damage.wav` | `damage` | o Guardiao apanhou |
| `knockout.wav` | `knockout` | nocaute de qualquer lutador |
| `select.wav` | `select` | confirmacao de menu |
| `navigate.wav` | `navigate` | navegacao de menu (passo de volume) |
| `round_end.wav` | `round_end` | fim de round |

### Musica (`assets/audio/music/`)

| Arquivo | Contexto (`AudioGateway`) | Uso |
| --- | --- | --- |
| `title.wav` | `title` | tela de titulo |
| `select.wav` | `select` | telas de menu (opcoes) |
| `fight.wav` | `fight` | durante a Peleja |
| `reviravolta.wav` | `reviravolta` | fim da Peleja vencida pelo Oponente |
| `result.wav` | `result` | fim da Peleja vencida pelo Guardiao |

Cada capacidade tem exatamente um arquivo, mapeado em
`src/infrastructure/godot-audio-gateway.gd` (`SFX_FILES` e `MUSIC_FILES`). Trocar
a sintese por outra nao muda o contrato nem o chamador.