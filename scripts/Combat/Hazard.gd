extends Area3D
## Spikes, a brazier, a drop onto rocks: somewhere Dark Messiah would kick a
## man into. Anything thrown into it fast enough dies; walking past it
## carefully does not. Give it a shape that covers the dangerous space.

## Slower than this, touching it is harmless.
@export var lethal_speed := 2.5
## Only speed toward the face counts (spikes on a wall, facing +Z). Off, any
## speed does (a brazier, a pit of stakes).
@export var directional := true


## How fast `velocity` is carrying something into this hazard. Running along
## a spiked wall is not running into it.
func into_speed(velocity: Vector3) -> float:
	var flat := Vector3(velocity.x, 0.0, velocity.z)

	if not directional:
		return flat.length()

	var face := global_basis.z
	face.y = 0.0

	if face.length() < 0.1:
		return flat.length()

	return flat.dot(-face.normalized())


func _ready() -> void:
	# Guards know where it is: to keep off it, and to kick you onto it.
	add_to_group(&"hazards")
	collision_layer = 0
	# Men, and men thrown limp (their limbs are on the bodies' layer).
	collision_mask = 1 | 2 | 4
	monitoring = true
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	# A body that was already inside when it sped up still counts.
	for body in get_overlapping_bodies():
		_check(body)


func _on_body_entered(body: Node3D) -> void:
	_check(body)


func _check(body: Node3D) -> void:
	# Gone already (a limb cut away, a body cleared) though still listed.
	if not is_instance_valid(body) or body.is_queued_for_deletion():
		return

	if body.has_method("hazard_hit"):
		body.hazard_hit(self, lethal_speed)
	elif body is PhysicalBone3D and body.has_meta(&"ragdoll"):
		# A limb of a man knocked off his feet (Ragdoll.gd).
		var ragdoll = body.get_meta(&"ragdoll")

		if is_instance_valid(ragdoll) and ragdoll.owner_node != null and ragdoll.owner_node.has_method("ragdoll_hazard"):
			ragdoll.owner_node.ragdoll_hazard(self, lethal_speed, body)
