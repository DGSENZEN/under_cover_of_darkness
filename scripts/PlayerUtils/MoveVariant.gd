class_name MoveVariant
extends Resource
## Traversal matching and playback Resource. Table order determines priority;
## the controller tries matching rows until one produces a clear path.

enum Kind {
	VAULT,
	MANTLE,
	HANG_ENTER,
}

enum Stance {
	ANY,
	SNEAK,
	NOT_SNEAK,
	SPRINT,
}

enum Air {
	ANY,
	GROUNDED,
	AIRBORNE,
}

@export var label: StringName = &"move"
@export var kind := Kind.MANTLE

@export_group("Matching")
## Feet-relative height window of the obstacle's top.
@export var min_height := 0.35
@export var max_height := 1.0
@export var air := Air.ANY
@export var stance := Stance.ANY
## Minimum speed toward the face.
@export var min_speed := 0.0

@export_group("Vault only")
## When true the obstacle must be thin and have a floor on the far side.
@export var needs_thin := false
## Allowed thickness = thickness_base + thickness_per_speed * approach speed.
@export var thickness_base := 0.45
@export var thickness_per_speed := 0.1
## The far floor may be at most this far below the player's feet.
@export var max_drop := 2.5

@export_group("Feel")
## Path length / move_speed gives the duration, clamped to min_time..max_time.
@export var move_speed := 4.0
@export var min_time := 0.25
@export var max_time := 0.6
## 0 = constant speed along the path, 1 = full ease in and out.
@export_range(0.0, 1.0, 0.05) var smoothing := 1.0
## Fraction of the approach speed handed back when the move ends.
@export_range(0.0, 1.0, 0.05) var speed_kept := 0.0
## How loud the move is, in dB. 50 carries 15 m; every 7 dB doubles that.
@export var noise_db := 45.0


## Creates a fresh variant Resource with the supplied matching and playback values.
## Other properties retain defaults; path loading works before editor class registration.
static func make(
	p_label: StringName,
	p_kind: Kind,
	p_min_height: float,
	p_max_height: float,
	p_move_speed: float,
	p_min_time: float,
	p_max_time: float,
	p_smoothing: float,
	p_speed_kept: float
) -> Resource:
	# Loaded by path rather than by class name, so this also works before the
	# editor has registered the class (for example when run from the terminal).
	var v: Resource = (load("res://scripts/PlayerUtils/MoveVariant.gd") as GDScript).new()
	v.label = p_label
	v.kind = p_kind
	v.min_height = p_min_height
	v.max_height = p_max_height
	v.move_speed = p_move_speed
	v.min_time = p_min_time
	v.max_time = p_max_time
	v.smoothing = p_smoothing
	v.speed_kept = p_speed_kept
	return v


## Returns new priority-ordered variants for a 2.0 m capsule; scale height tuning for other sizes.
static func default_table() -> Array[Resource]:
	var table: Array[Resource] = []

	# Catching a ledge out of a jump or a fall. First, so the air grab wins
	# over a slow high mantle when both would match.
	var hang = make(&"hang", Kind.HANG_ENTER, 1.9, 2.6, 5.0, 0.10, 0.25, 0.5, 0.0)
	hang.air = Air.AIRBORNE
	hang.noise_db = 40.0
	table.append(hang)

	# Sneaking variants use reduced noise and slower traversal.
	var quiet_step = make(&"quiet step-up", Kind.MANTLE, 0.35, 1.0, 2.2, 0.35, 0.70, 1.0, 0.0)
	quiet_step.stance = Stance.SNEAK
	quiet_step.noise_db = 28.0
	table.append(quiet_step)

	var quiet_mantle = make(&"quiet mantle", Kind.MANTLE, 1.0, 2.3, 1.9, 0.60, 1.40, 1.0, 0.0)
	quiet_mantle.stance = Stance.SNEAK
	quiet_mantle.noise_db = 30.0
	table.append(quiet_mantle)

	# Thin obstacle, arriving fast, floor beyond: go over it and keep running.
	var vault = make(&"vault", Kind.VAULT, 0.35, 1.25, 7.0, 0.22, 0.50, 0.15, 1.0)
	vault.stance = Stance.NOT_SNEAK
	vault.min_speed = 5.0
	vault.needs_thin = true
	vault.noise_db = 54.0
	table.append(vault)

	table.append(make(&"step-up", Kind.MANTLE, 0.35, 1.0, 5.0, 0.20, 0.40, 0.6, 0.5))
	table.append(make(&"mantle", Kind.MANTLE, 1.0, 1.7, 3.8, 0.35, 0.65, 1.0, 0.25))

	var high = make(&"high mantle", Kind.MANTLE, 1.7, 2.3, 2.8, 0.60, 1.00, 1.0, 0.0)
	high.noise_db = 48.0
	table.append(high)

	return table
