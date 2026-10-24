class_name ClimbVolume
extends Area3D
## Climbable Area3D. Flat surfaces face into the wall along local -Z; their
## BoxShape3D should cover the climb and extend about 0.5 m from the wall.
## A flat climb may lean (its box pitched): it is climbed up its local +Y, as
## shrouds lean in to their mast. Ropes use a vertical line through the
## origin. Entry/exit registers this volume with bodies implementing
## add_climb_volume/remove_climb_volume.

## A rope: the climber hangs off a vertical line through this node's origin
## and can swing around it. Give it a tall thin box shape around the rope.
## Off: a flat climbable surface, with local -Z pointing into the wall.
@export var rope := false
## A net, ratlines: nothing behind it, so it is climbed from either side (the
## side taken hold of it from), its plane its box's middle. Climbed from
## behind up to something over it (a mast's top), the climber goes round to
## its front there (PlayerController._update_climb).
@export var open := false

## Vertical climbing speed in m/s.
@export var max_vel_vert := 2.2
## Sideways climbing speed in m/s.
@export var max_vel_horiz := 1.4
## Gap kept between the player's capsule and the volume's back plane.
@export var climb_distance := 0.08
## Where its wall is, behind its origin against its normal (m): a box that
## reaches out past its wall (a hatch's, out over the street where a man
## takes hold of it) still holds him to the wall. 0: the box's middle.
@export var plane_back := 0.0


func _ready() -> void:
	# Guards find ladders and ropes to climb by it (NavLinks).
	add_to_group(&"climb_volumes")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## For a rope: the direction from the rope to `from`, flattened.
func get_rope_normal(from: Vector3) -> Vector3:
	var n := from - global_position
	n.y = 0.0

	if n.length_squared() < 0.0001:
		return get_climb_normal()

	return n.normalized()


## Where it leads, as world points by them: [the floor at its foot, in front
## of it; over its top, on what it goes up to] (for a rope, straight below
## and at its top): the ends of the way across the guards found up it
## (NavLinks, "climb_ends"), else worked out from its box. What a guard after
## a man on it goes for (Guard.goal_of).
func ends() -> Array:
	if has_meta(&"climb_ends"):
		return get_meta(&"climb_ends")

	var box := AABB()

	for child in get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var size: Vector3 = ((child as CollisionShape3D).shape as BoxShape3D).size
			box = (child as CollisionShape3D).global_transform * AABB(-size * 0.5, size)
			break

	if box.size == Vector3.ZERO:
		return [global_position, global_position]

	var at := global_position

	if rope:
		return [Vector3(at.x, box.position.y, at.z), Vector3(at.x, box.end.y, at.z)]

	var out := get_climb_normal()

	if is_leaning():
		var face := face_ends()
		return [(face[0] as Vector3) + out * 0.6, (face[1] as Vector3) + Vector3.UP * 0.3 - out * 0.8]

	return [Vector3(at.x, box.position.y, at.z) + out * 0.6, Vector3(at.x, box.end.y + 0.3, at.z) - out * 0.8]


## Its plane's foot and top, in the middle of its width (world): where a
## leaning climb starts and where it ends.
func face_ends() -> Array:
	for child in get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var shape := child as CollisionShape3D
			var half: float = (shape.shape as BoxShape3D).size.y * 0.5
			return [shape.global_transform * Vector3(0.0, -half, 0.0), shape.global_transform * Vector3(0.0, half, 0.0)]

	return [global_position, global_position]


## The top of its plane (world y): a climber held at it goes no higher. (Of an
## upright box, the top of the box.)
func top_y() -> float:
	return (face_ends()[1] as Vector3).y


## Up the climb, along its plane: straight up, or leaning with it.
func get_climb_up() -> Vector3:
	return global_transform.basis.y.normalized()


## Whether it leans (its box pitched off upright).
func is_leaning() -> bool:
	return get_climb_up().y < 0.999


## Out of its plane's front, square to it (tilted, for a leaning climb).
func get_face_normal() -> Vector3:
	return global_transform.basis.z.normalized()


## Unit normal pointing out of the wall, toward the climber.
func get_climb_normal() -> Vector3:
	var n := global_transform.basis.z
	n.y = 0.0

	if n.length_squared() < 0.0001:
		return Vector3.BACK

	return n.normalized()


## A point on the wall plane.
func get_plane_point() -> Vector3:
	return global_position - global_transform.basis.z.normalized() * plane_back


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("add_climb_volume"):
		body.add_climb_volume(self)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("remove_climb_volume"):
		body.remove_climb_volume(self)
