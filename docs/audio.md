# Audio

## Regra de ouro

Nenhum arquivo de audio de terceiros entra no projeto. Todo som e toda trilha sao
**sintetizados dentro do repositorio** por `tools/audio/build_chiptune.py` (Python
padrao, sem dependencia externa), commitados em `assets/audio/` com origem e
licenca registradas em [`assets/audio/CREDITS.md`](../assets/audio/CREDITS.md).

```bash
make audio        # regera os WAV (deterministico: mesmo codigo, mesmos bytes)
make test-audio   # confere cada WAV commitado byte a byte com o gerador
```

## Camadas

| Camada | Arquivo | Papel |
| --- | --- | --- |
| Contrato | `src/application/gateways/audio-gateway.gd` | Capacidades fechadas (`SFX_*`, `MUSIC_*`) e o gesto do jogador |
| Contrato | `src/application/gateways/persistence-gateway.gd` | `save`/`load_value`/`has`/`erase` |
| Aplicacao | `src/application/services/options-service.gd` | Volume e mudo: aplica no audio **e** persiste na mesma chamada |
| Infra (producao) | `src/infrastructure/godot-audio-gateway.gd` | Toca os WAV, loop de trilha, volume/mudo no barramento `Master` |
| Infra (producao) | `src/infrastructure/local-persistence-gateway.gd` | JSON em `user://` (localStorage no web) |
| Infra (sample) | `src/infrastructure/sample/silent-audio-gateway.gd` | Silencioso, sem I/O: registra a intencao para o teste |
| Apresentacao | `src/interface-adapters/options-view-adapter.gd` | Copy pt-BR e modelo de tela das opcoes |
| Apresentacao | `src/interface-adapters/pixel-font.gd` | Fonte bitmap compartilhada (titulo e opcoes) |
| App | `scenes/options_screen.gd` + `.tscn` | Tela fina: desenha o modelo e delega ao caso de uso |

Os adapters concretos sao instanciados **somente** em
`autoloads/app_container.gd` (composition root), que tambem monta o adapter de
audio no proprio autoload: a trilha atravessa a troca de cenas. Em modo `sample`
(o dos testes) nada e montado, porque o adapter silencioso nao toca nada.

## Capacidades

Efeitos (`AudioGateway.SFX_KINDS`): `impact_light`, `impact_heavy`, `special`,
`damage`, `knockout`, `select`, `navigate`, `round_end`.

Contextos musicais (`AudioGateway.MUSIC_CONTEXTS`): `title`, `select`, `fight`,
`reviravolta`, `result`.

O `match-service` traduz a Peleja em audio: o peso do impacto vem do golpe que
conectou (`light` -> `impact_light`, `heavy`/`grab` -> `impact_heavy`,
`special` -> `special`), o guardiao que apanha toca `damage`, o nocaute toca
`knockout`, e o fim da Peleja troca o contexto musical: vitoria do Oponente ->
`reviravolta` (e a Reviravolta que entra em cena), vitoria do Guardiao ->
`result`. Pedido fora da lista de capacidades e ignorado: o contrato e a lista
fechada, nao o nome do arquivo.

## Preferencias

Volume mestre (0 a 1, em 10 passos) e mudo sao gravados em
`user://peleja/preferences.json` pelas chaves `audio.master_volume` e
`audio.muted`. Cada mudanca e aplicada no barramento `Master` e gravada na mesma
chamada, entao a sessao seguinte restaura exatamente o que o jogador deixou. No
web, `user://` e o armazenamento do navegador: as preferencias sobrevivem ao
recarregar a pagina.

## Autoplay no navegador

Navegadores so liberam audio depois de um gesto do usuario. O jogo trata isso no
gateway, nao no chamador:

1. Antes do gesto, `play_music` registra a intencao e **nao** chama o player (o
   navegador recusaria); `play_sfx` idem.
2. `notify_user_gesture()` e chamado no primeiro comando do jogador (tela de
   titulo), ao mexer no menu de opcoes e em qualquer toque/clique.
3. No gesto, a ultima trilha pedida comeca a tocar.

Resultado: o jogo nunca fica mudo por causa da politica de autoplay e nenhum som
e pedido antes de existir gesto. Em teste e headless nada disso produz som.

## Tela de opcoes

`Esc` na tela de titulo abre `scenes/options_screen.tscn`: `MOVE_LEFT`/`A`
abaixa o volume, `MOVE_RIGHT`/`D` sobe, `CONFIRM`/`Enter` alterna o mudo e
`CANCEL`/`Esc` volta. Cada passo de volume faz `navigate`, alternar o mudo faz
`select`.

Evidencia: `make capture-options` grava prints 426x240 em
`docs/evidence/ticket-08-options-*.png` mexendo no volume e no mudo pelo caso de
uso real (`OptionsService`) com os gateways injetados pelo composition root.