class_name Rng
extends RefCounted
## Gerador pseudoaleatorio deterministico, com semente injetada.
##
## Aritmetica pura (xorshift32 de 32 bits) para nao depender de nada da engine:
## a mesma semente produz sempre a mesma sequencia, em qualquer maquina, com ou
## sem engine rodando. Toda aleatoriedade do dominio vem daqui (invariante 2 de
## docs/architecture.md), e nenhum outro modulo sorteia por conta propria.

const MASK_32 := 0xFFFFFFFF
const DEFAULT_SEED := 20260915

var seed_value: int
var _state: int


func _init(p_seed: int = DEFAULT_SEED) -> void:
	seed_value = p_seed
	_state = _mix_seed(p_seed)


## Mistura a semente para que sementes pequenas e vizinhas (1, 2, 3...) nao
## produzam sequencias parecidas, e para que 0 nao trave o gerador.
static func _mix_seed(value: int) -> int:
	var base := value & MASK_32
	var mixed := (base * 1664525 + 1013904223) & MASK_32
	if mixed == 0:
		mixed = 0x1B873593
	return mixed


## Proximo numero de 32 bits sem sinal.
func next_uint() -> int:
	var x := _state
	x = (x ^ (x << 13)) & MASK_32
	x = (x ^ (x >> 17)) & MASK_32
	x = (x ^ (x << 5)) & MASK_32
	_state = x
	return x


## Inteiro em [min_value, max_value], inclusivo nas duas pontas.
func next_int(min_value: int, max_value: int) -> int:
	if max_value <= min_value:
		return min_value
	var span := max_value - min_value + 1
	return min_value + (next_uint() % span)


## Fracionario em [0.0, 1.0).
func next_float() -> float:
	return float(next_uint()) / 4294967296.0


## Verdadeiro com a probabilidade pedida (0.0 nunca, 1.0 sempre).
func chance(probability: float) -> bool:
	return next_float() < clampf(probability, 0.0, 1.0)


## Volta ao inicio da sequencia da mesma semente.
func reset() -> void:
	_state = _mix_seed(seed_value)


## Estado interno, util para provar reprodutibilidade em teste.
func state() -> int:
	return _state
