# Balanceamento: Vantagem Oculta e Reviravolta

Números calibrados do ticket 7 (ADR 0003). Tudo aqui é **medido**, não estimado: as duas
tabelas abaixo saem da própria execução do jogo (`make capture-reviravolta` imprime os
números lidos do domínio) e dos testes que travam a invariante.

## Vantagem Oculta: os dois números

O Guardião do folclore é sempre mais forte que o Oponente, e isso **nunca aparece na
HUD**. A regra é dado explícito em `src/domain/hidden_advantage.gd`, não um ajuste
espalhado pelo código:

| Número | Constante | Valor |
| --- | --- | --- |
| Vida | `HiddenAdvantage.HEALTH_FACTOR` | **1.6** |
| Dano | `HiddenAdvantage.DAMAGE_FACTOR` | **1.4** |

Aplicada sobre os números base do Guardião (`src/domain/guardian_stats.gd`:
1000 de vida e multiplicador de dano 1.25), a Vantagem Oculta dá:

- **Guardião (com Vantagem Oculta): vida 1600, multiplicador de dano 1.750.**

Quem monta uma Peleja aplica a vantagem ao Guardião (`Fighter.duel` →
`GuardianStats.advantaged`); os Oponentes ficam com os números do próprio Arquétipo
(`src/domain/opponent_stats.gd`: base 620 de vida, +45 por posição no arcade; dano 0.72,
+0.03 por posição).

## Margem contra os 7 Oponentes

Saída real de `make capture-reviravolta` (`vantagem oculta: Guardiao vida=1600
dano=1.750` seguido das sete linhas):

| Peleja | Oponente | Vida | Dano | Margem de vida | Margem de dano | Vida (Guard./Op.) | Dano (Guard./Op.) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Capataz | 620 | 0.72 | +980 | +1.03 | 2.58x | 2.43x |
| 2 | Banqueiro | 665 | 0.75 | +935 | +1.00 | 2.41x | 2.33x |
| 3 | Redpill | 710 | 0.78 | +890 | +0.97 | 2.25x | 2.24x |
| 4 | Camisa-Verde | 755 | 0.81 | +845 | +0.94 | 2.12x | 2.16x |
| 5 | Doutor Pureza | 800 | 0.84 | +800 | +0.91 | 2.00x | 2.08x |
| 6 | Fantasma do Reich | 845 | 0.87 | +755 | +0.88 | 1.89x | 2.01x |
| 7 | Falso Pastor | 890 | 0.90 | +710 | +0.85 | 1.80x | 1.94x |

Leitura: a escada de dificuldade sobe de verdade (o Oponente da sétima Peleja tem 270 de
vida e 0.18 de dano a mais que o primeiro) e **a Vantagem Oculta continua inteira no fim
do arcade** — na pior posição o Guardião ainda tem 1.80x a vida e 1.94x o dano do
Oponente. Não há Oponente que alcance o folclore, que é o requisito de produto.

## O que a HUD mostra (e o que ela não mostra)

- A HUD recebe o retrato do `match-service` e traduz a vida em **proporção de barra**
  (`HudAdapter.fight_model` → chave `"bar"`), mais nomes, pips de round e relógio.
- `HudAdapter.discloses_hidden_advantage()` é a invariante: procura as chaves proibidas
  (`health`, `max_health`, `health_ratio`, `damage`, `damage_multiplier`,
  `hidden_advantage`) em qualquer nível do modelo. O teste monta uma Peleja de verdade,
  confirma que o Guardião tem mais vida e mais dano, e prova que nada disso aparece no
  HUD (`test/interface_adapters/test_hud_adapter.gd`).

## Reviravolta: quando dispara

Regra pura em `src/domain/reviravolta_rule.gd`, coberta em `test/domain/test_reviravolta_rule.gd`:

| Resultado da Peleja | Reviravolta | Campanha |
| --- | --- | --- |
| Oponente vence (2 rounds) | **dispara** | segue para a próxima Peleja |
| Guardião vence (2 rounds) | não dispara | segue |
| Empate (1-1-1) | não dispara | segue |
| Peleja em andamento | não dispara | — |

A cena dura `4 linhas × 60 ticks + 90 ticks = 330 ticks` (5,5 s a 60 ticks por segundo),
rola **sem interação** e aceita ser pulada. Ela não encerra a campanha: o progresso fica
no `persistence-gateway` como `{"fight": n, "campaign_over": false, "reviravolta": true}` —
o jogador perde a Peleja, nunca o arcade.

## Como recalibrar

1. Mudar `HEALTH_FACTOR`/`DAMAGE_FACTOR` em `src/domain/hidden_advantage.gd` (é o único
   lugar com os dois números).
2. Rodar `make capture-reviravolta` e atualizar a tabela de margens com a saída real.
3. Confirmar `make test`: os testes de domínio exigem `has_advantage` verdadeiro para
   **todos** os Arquétipos, então uma calibragem que inverta a vantagem quebra o gate.
