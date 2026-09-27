extends Area3D
## Open flame: a brazier, a burning pile. A guard who goes into it (kicked,
## thrown, blown) catches fire and runs about screaming until it burns out
## or he does. A barrel in it goes up. You only scorch yourself.
##
## Build with Fire.brazier(parent, position) for the bowl, the flame and the
## light together.
##
## Tended (`fuel_seconds` set), it burns down: over that long its fuel
## goes, and its light and flame shrink to embers (never quite out). Fed a
## log (`feed`), it flares up and burns on. Burning low (`low`), the men talk
## of it and one goes for wood (TalkFacts, Gathering).

const TorchScript := preload("res://scripts/Visual/Torch.gd")

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
	var bowl := MeshInstance3D.new()
	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius = 0.42
	bowl_mesh.bottom_radius = 0.18
	bowl_mesh.height = 0.3
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.15, 0.15)
	iron.metallic = 0.6
	iron.roughness = 0.55
	bowl_mesh.material = iron
	bowl.mesh = bowl_mesh
	bowl.position.y = 0.95
	stand.add_child(bowl)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.06
	post_mesh.bottom_radius = 0.14
	post_mesh.height = 0.85
	post_mesh.material = iron
	post.mesh = post_mesh
	post.position.y = 0.42
	stand.add_child(post)
	stand.set_meta(&"surface", "metal")
	parent.add_child(stand)
	stand.global_position = position

	var torch: Node3D = TorchScript.new()
	torch.energy = 2.6
	torch.light_range = 8.0
	torch.flame_size = 0.8
	stand.add_child(torch)
	torch.position = Vector3(0.0, 1.35, 0.0)

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


## A log put on: more to burn, and it flares.
func feed(amount := 0.6) -> void:
	fuel = minf(fuel + amount, 1.0)
	_flare_left = FLARE_TIME


func low() -> bool:
	return fuel < LOW_AT


## "low" or "burning" (for what the men say).
func burning() -> StringName:
	return &"low" if low() else &"burning"


## How bright it burns (1 full, over 1 flaring): its light and flame.
func strength() -> float:
	var flare := 1.0 + (FLARE - 1.0) * (_flare_left / FLARE_TIME)
	return lerpf(0.25, 1.0, fuel) * flare


## What the flame is to whoever it touches: no guard stops it, nothing
## shoves you out of it.
func attack_info() -> Dictionary:
	return {"type": &"fire", "hazard": true}
