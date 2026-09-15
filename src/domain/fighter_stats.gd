class_name FighterStats
extends RefCounted
## Numeros base de um lutador: vida, multiplicador de dano e defesa.
##
## Nada aqui e lido pela interface: o que a HUD mostra e a proporcao da barra de
## vida, nunca os numeros por tras dela (ADR 0003).

var display_name: String
var max_health: int
var damage_multiplier: float
## Fracao do dano bloqueavel absorvida ao defender, de 0.0 a 1.0.
var block_damage_reduction: float
## Pixels de deslocamento por tick ao andar.
var walk_speed: int
## Unidades de Barra de Especial ganhas ao conectar um golpe.
var meter_gain_on_hit: int
## Unidades de Barra de Especial ganhas ao apanhar.
var meter_gain_on_hurt: int


func _init(
	p_display_name: String = "fighter",
	p_max_health: int = 1000,
	p_damage_multiplier: float = 1.0,
	p_block_damage_reduction: float = 0.5,
	p_walk_speed: int = 3,
	p_meter_gain_on_hit: int = 10,
	p_meter_gain_on_hurt: int = 10
) -> void:
	display_name = p_display_name
	max_health = maxi(p_max_health, 1)
	damage_multiplier = maxf(p_damage_multiplier, 0.0)
	block_damage_reduction = clampf(p_block_damage_reduction, 0.0, 1.0)
	walk_speed = maxi(p_walk_speed, 0)
	meter_gain_on_hit = maxi(p_meter_gain_on_hit, 0)
	meter_gain_on_hurt = maxi(p_meter_gain_on_hurt, 0)


## Dano do golpe ja com o multiplicador do lutador. Golpe sem dano continua zero.
func damage_for(move: Move) -> int:
	if move == null or move.damage <= 0:
		return 0
	return maxi(roundi(float(move.damage) * damage_multiplier), 1)


## Dano efetivamente recebido: a defesa reduz apenas golpes bloqueaveis, e nunca
## a zero -- um golpe defendido ainda custa pelo menos 1 de vida.
func damage_taken(move: Move, blocking: bool) -> int:
	var incoming := damage_for(move)
	if not blocking or not move.blockable:
		return incoming
	return maxi(roundi(float(incoming) * (1.0 - block_damage_reduction)), 1)


## Copia com outro maximo de vida e outro multiplicador de dano, usada pela
## Vantagem Oculta sem alterar os numeros de quem chamou.
func with_advantage(health_factor: float, damage_factor: float) -> FighterStats:
	return FighterStats.new(
		display_name,
		roundi(float(max_health) * health_factor),
		damage_multiplier * damage_factor,
		block_damage_reduction,
		walk_speed,
		meter_gain_on_hit,
		meter_gain_on_hurt
	)
