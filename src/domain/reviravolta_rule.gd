class_name ReviravoltaRule
extends RefCounted
## Regra da Reviravolta (ADR 0003), pura: so `RefCounted` e tipos puros, sem
## cena, sem entrada, sem arquivo e sem audio.
##
## A Reviravolta dispara **se e somente se** o Oponente vence a Peleja. Vitoria
## do Guardiao nunca dispara (nao ha nada a resolver) e a derrota **nunca**
## encerra a campanha: quem perde a Peleja nao perde o arcade.
##
## O que mora aqui e so o que decide o comportamento -- quando disparar, quanto
## tempo dura cada linha e como a cena termina. A copy pt-BR da cena NAO mora no
## dominio: vive na borda de apresentacao (`PanelAdapter`).

## Fases do painel, na ordem em que acontecem.
enum Phase {
	IDLE,
	VOICE,
	WIND,
	ROOT,
	DISSOLVE,
	DONE,
}

## Ticks de apresentacao por linha de texto (60 por segundo, como o resto do jogo).
const TICKS_PER_LINE := 60
## Ticks do efeito final: o vento arranca, a raiz segura e a Forca dissolve,
## divididos em tres tercos iguais (`Phase.WIND`, `Phase.ROOT`, `Phase.DISSOLVE`).
const DISSOLVE_TICKS := 90
## A cena sempre pode ser pulada pelo jogador: a Reviravolta nao pede interacao,
## mas tambem nunca prende quem ja entendeu.
const SKIPPABLE := true

const PHASE_NAMES := {
	Phase.IDLE: "idle",
	Phase.VOICE: "voice",
	Phase.WIND: "wind",
	Phase.ROOT: "root",
	Phase.DISSOLVE: "dissolve",
	Phase.DONE: "done",
}


## Verdadeiro quando a Reviravolta entra em cena: o Oponente venceu a Peleja.
## O Guardiao vencendo, a Peleja empatando ou ainda em andamento, nao dispara.
static func triggers(winner: int) -> bool:
	return winner == MatchRules.Winner.OPPONENT


## A campanha sobrevive a qualquer resultado de Peleja: a Reviravolta resolve a
## Peleja vencida pelo Oponente e o arcade segue para a proxima. Nunca ha game
## over de campanha por derrota -- por isso a funcao e sempre verdadeira.
static func keeps_campaign_alive(_winner: int) -> bool:
	return true


static func can_skip() -> bool:
	return SKIPPABLE


## Ticks totais da cena: a sequencia de texto mais o efeito final.
static func total_ticks(line_count: int) -> int:
	return maxi(line_count, 0) * TICKS_PER_LINE + DISSOLVE_TICKS


## Indice da linha visivel no tick pedido; -1 quando a voz terminou (ou quando
## nao ha linha nenhuma).
static func line_index_for(ticks: int, line_count: int) -> int:
	if ticks < 0 or line_count <= 0:
		return -1
	if ticks >= line_count * TICKS_PER_LINE:
		return -1
	return mini(floori(float(ticks) / float(TICKS_PER_LINE)), line_count - 1)


## Fase da cena no tick pedido. Tick negativo e cena parada; depois do total, a
## cena terminou.
static func phase_for(ticks: int, line_count: int) -> int:
	if ticks < 0:
		return Phase.IDLE
	if ticks < maxi(line_count, 0) * TICKS_PER_LINE:
		return Phase.VOICE
	var elapsed := ticks - maxi(line_count, 0) * TICKS_PER_LINE
	var third := DISSOLVE_TICKS / 3
	if elapsed < third:
		return Phase.WIND
	if elapsed < third * 2:
		return Phase.ROOT
	if elapsed < DISSOLVE_TICKS:
		return Phase.DISSOLVE
	return Phase.DONE


## Verdadeiro quando a cena chegou ao fim (o Oponente esta dissolvido).
static func is_finished(ticks: int, line_count: int) -> bool:
	return ticks >= total_ticks(line_count)


## Nome em ingles da fase, para o retrato, os testes e o HUD.
static func phase_name(phase: int) -> String:
	return PHASE_NAMES.get(phase, "idle")


## O Oponente desapareceu na cena: verdadeiro na fase final e depois dela.
static func opponent_dissolved(ticks: int, line_count: int) -> bool:
	var phase := phase_for(ticks, line_count)
	return phase == Phase.DISSOLVE or phase == Phase.DONE
