class_name Move
extends RefCounted
## Um golpe: alcance, dano e a janela de frames (inicio, ativo, recuperacao).
##
## O tempo do golpe e contado em ticks de simulacao, nunca em segundos nem por
## temporizador de engine. A janela ativa e o intervalo de frames
## [startup_frames, startup_frames + active_frames).

enum Kind {
	LIGHT,
	HEAVY,
	GRAB,
	SPECIAL,
}

const KIND_NAMES := {
	Kind.LIGHT: "light",
	Kind.HEAVY: "heavy",
	Kind.GRAB: "grab",
	Kind.SPECIAL: "special",
}

## Alcance, dano e janelas dos tres golpes basicos.
const LIGHT_DAMAGE := 6
const LIGHT_REACH := 26
const LIGHT_STARTUP := 4
const LIGHT_ACTIVE := 3
const LIGHT_RECOVERY := 6

const HEAVY_DAMAGE := 14
const HEAVY_REACH := 32
const HEAVY_STARTUP := 10
const HEAVY_ACTIVE := 4
const HEAVY_RECOVERY := 14

const GRAB_DAMAGE := 10
const GRAB_REACH := 18
const GRAB_STARTUP := 6
const GRAB_ACTIVE := 2
const GRAB_RECOVERY := 18

const SPECIAL_DAMAGE := 30
const SPECIAL_REACH := 44
const SPECIAL_STARTUP := 12
const SPECIAL_ACTIVE := 6
const SPECIAL_RECOVERY := 22

var kind: int
var damage: int
var reach: int
var startup_frames: int
var active_frames: int
var recovery_frames: int
## Golpe bloqueavel: a defesa reduz o dano. Agarrao ignora a defesa.
var blockable: bool
var display_name: String


func _init(
	p_kind: int,
	p_damage: int,
	p_reach: int,
	p_startup_frames: int,
	p_active_frames: int,
	p_recovery_frames: int,
	p_blockable: bool = true,
	p_display_name: String = ""
) -> void:
	kind = p_kind
	damage = maxi(p_damage, 0)
	reach = maxi(p_reach, 1)
	startup_frames = maxi(p_startup_frames, 0)
	active_frames = maxi(p_active_frames, 1)
	recovery_frames = maxi(p_recovery_frames, 0)
	blockable = p_blockable
	display_name = p_display_name if not p_display_name.is_empty() else kind_name()


static func light() -> Move:
	return Move.new(
		Kind.LIGHT,
		LIGHT_DAMAGE,
		LIGHT_REACH,
		LIGHT_STARTUP,
		LIGHT_ACTIVE,
		LIGHT_RECOVERY
	)


static func heavy() -> Move:
	return Move.new(
		Kind.HEAVY,
		HEAVY_DAMAGE,
		HEAVY_REACH,
		HEAVY_STARTUP,
		HEAVY_ACTIVE,
		HEAVY_RECOVERY
	)


## Agarrao: curto, lento e sem defesa possivel (passa pela guarda).
static func grab() -> Move:
	return Move.new(
		Kind.GRAB,
		GRAB_DAMAGE,
		GRAB_REACH,
		GRAB_STARTUP,
		GRAB_ACTIVE,
		GRAB_RECOVERY,
		false
	)


## Golpe Especial de um Guardiao. O poder vem da lenda do lutador; aqui so entra
## a moldura comum (alcance, dano e janela), nao o nome de cada um.
static func special(
	p_display_name: String, p_damage: int = SPECIAL_DAMAGE, p_reach: int = SPECIAL_REACH
) -> Move:
	return Move.new(
		Kind.SPECIAL,
		p_damage,
		p_reach,
		SPECIAL_STARTUP,
		SPECIAL_ACTIVE,
		SPECIAL_RECOVERY,
		true,
		p_display_name
	)


func kind_name() -> String:
	return KIND_NAMES.get(kind, "unknown")


func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames


func first_active_frame() -> int:
	return startup_frames


func last_active_frame() -> int:
	return startup_frames + active_frames - 1


## Verdadeiro quando o frame esta na janela em que o golpe pode conectar.
func is_active_at(frame: int) -> bool:
	return frame >= startup_frames and frame <= last_active_frame()


## Verdadeiro quando o golpe ja passou da recuperacao e o lutador volta a agir.
func is_finished_at(frame: int) -> bool:
	return frame >= total_frames()


func is_special() -> bool:
	return kind == Kind.SPECIAL


func is_grab() -> bool:
	return kind == Kind.GRAB


func is_unblockable() -> bool:
	return not blockable
