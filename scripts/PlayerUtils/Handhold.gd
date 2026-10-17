extends Node3D
## A placed handhold on a façade: something the Prosecutor can hang from or
## climb that the ledge scanner would not find on its own (a sill too thin, a
## bracket, a drainpipe). Free-run and the careful layer both use them.
##
## The climber hangs on the hold's local +Z side. A LEDGE runs along local X,
## centred on the origin; a POLE runs up local Y from the origin; a POINT is
## the origin itself.

enum Kind { LEDGE, POLE, POINT }

const GROUP := &"handholds"

@export var kind := Kind.LEDGE
## A ledge's or a pole's length (m). A point ignores it.
@export var length := 1.0


func _ready() -> void:
	add_to_group(GROUP)


## The side the climber hangs on: the hold's +Z, flat.
func outward() -> Vector3:
	var z := global_basis.z
	return Vector3(z.x, 0.0, z.z).normalized()


## The closest point on the hold to world_point.
func grip_near(world_point: Vector3) -> Vector3:
	var span := ends()

	if span.size() < 2:
		return span[0]

	var a := span[0]
	var b := span[1]
	var t := clampf((world_point - a).dot(b - a) / maxf(a.distance_squared_to(b), 0.0001), 0.0, 1.0)
	return a.lerp(b, t)


## The hold's world end points: one for a point.
func ends() -> PackedVector3Array:
	match kind:
		Kind.LEDGE:
			var half := global_basis.x.normalized() * length * 0.5
			return PackedVector3Array([global_position - half, global_position + half])
		Kind.POLE:
			return PackedVector3Array([global_position, global_position + global_basis.y.normalized() * length])

	return PackedVector3Array([global_position])
