extends Area3D
## Flame Area3D: ignites flung/already burning guards, lights barrels, and
## scorches damage receivers at most once per 0.5 s across the whole area.
## Optional fuel burns down to embers; feed() restores fuel and briefly flares.

const Lights := preload("res://scripts/Visual/Lights/Lights.gd")

## Seconds a guard burns for.
@export var burn_time := 4.5
## Damage to you each time the flame catches you (twice a second at most).
@export var scorch := 6.0
## From full to embers, in seconds; 0 (as made) never burns down (a level
## where nobody tends it).
@export var fuel_seconds := 0.0

## Below this it burns low; it never burns below EMBERS. Fed, it flares to
## FLARE times as bright, easing back over FLARE_TIME.
const LOW_AT := 0.35
const EMBERS := 0.08
const FLARE := 1.5
const FLARE_TIME := 2.0

## 0..1: what it has left to burn.
var fuel := 1.0
## Fed a log (Atmosphere: a burst of embers).
signal fed
## Its flame and light (Torch.gd), made by `brazier`.
var torch: Node3D
var _flare_left := 0.0

var _scorched_at := -10.0
var _time := 0.0


## A standing iron bowl with a fire in it. Returns the fire.
static func brazier(parent: Node, position: Vector3) -> Area3D:
	var stand := StaticBody3D.new()
	stand.name = "Brazier"
	var leg := CollisionShape3D.new()
	var leg_shape := CylinderShape3D.new()
	leg_shape.radius = 0.32
	leg_shape.height = 1.0
	leg.shape = leg_shape
	leg.position.y = 0.5
	stand.add_child(leg)
	stand.set_meta(&"surface", "metal")
	parent.add_child(stand)
	stand.global_position = position

	# Its tripod, bowl and coals (Lights.gd, from the props pipeline); the
	# Atmosphere sheds its embers.
	var torch: Node3D = Lights.brazier(stand, stand.global_position)
	torch.embers_by_atmosphere = true

	var fire: Area3D = (load("res://scripts/Combat/Fire.gd") as GDScript).new()
	fire.torch = torch
	var zone := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.5
	cylinder.height = 1.0
	zone.shape = cylinder
	fire.add_child(zone)
	stand.add_child(fire)
	fire.position = Vector3(0.0, 1.45, 0.0)
	return fire


func _ready() -> void:
	# Guards know where it is: to keep off it, and to kick you into it.
	add_to_group(&"hazards")
	add_to_group(&"fires")
	collision_layer = 0
	collision_mask = 1 | 2
	monitoring = true


func _physics_process(delta: float) -> void:
	_time += delta
	if fuel_seconds > 0.0:
		fuel = maxf(fuel - delta / fuel_seconds, EMBERS)

	_flare_left = maxf(_flare_left - delta, 0.0)

	if torch != null and is_instance_valid(torch) and torch.has_method("set_strength"):
		torch.set_strength(strength())

	for body in get_overlapping_bodies():
		if body.has_method("ignite"):
			# Sent into it (kicked, thrown, blown): he catches. Brushing past
			# the bowl does not set a man alight.
			var flung: bool = float(body.get("_knock")) > 0.0

			if flung or body.is_burning():
				body.ignite(burn_time)
		elif body.has_method("light"):
			body.light(0.3)
		elif body.has_method("take_damage") and _time - _scorched_at > 0.5:
			_scorched_at = _time
			body.take_damage(scorch, self)


## Adds fuel (capped above at 1), restarts flare timing, and emits fed.
## amount defaults to 0.6; negative values are not rejected.
func feed(amount := 0.6) -> void:
	fuel = minf(fuel + amount, 1.0)
	_flare_left = FLARE_TIME
	fed.emit()


## Returns fuel < LOW_AT.
func low() -> bool:
	return fuel < LOW_AT


## "low" or "burning" (for what the men say).
func burning() -> StringName:
	return &"low" if low() else &"burning"


## Returns current fuel/flare light multiplier; it may exceed 1 during a flare.
func strength() -> float:
	var flare := 1.0 + (FLARE - 1.0) * (_flare_left / FLARE_TIME)
	return lerpf(0.25, 1.0, fuel) * flare


## What the flame is to whoever it touches: no guard stops it, nothing
## shoves you out of it.
func attack_info() -> Dictionary:
	return {"type": &"fire", "hazard": true}
