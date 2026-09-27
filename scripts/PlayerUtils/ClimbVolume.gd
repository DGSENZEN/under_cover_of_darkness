class_name ClimbVolume
extends Area3D
## Marks a climbable surface: a ladder, a vine wall, a drainpipe.
##
## Place it against the surface with its local -Z pointing INTO the wall, the
## same way a Camera3D would look at it. Give it a BoxShape3D that covers the
## climbable area and sticks out about half a metre from the wall. Make it end
## near the top of the wall so the player can mantle off the top.

## A rope: the climber hangs off a vertical line through this node's origin
## and can swing around it. Give it a tall thin box shape around the rope.
## Off: a flat climbable surface, with local -Z pointing into the wall.
@export var rope := false

## Vertical climbing speed in m/s.
@export var max_vel_vert := 2.2
## Sideways climbing speed in m/s.
@export var max_vel_horiz := 1.4
## Gap kept between the player's capsule and the volume's back plane.
@export var climb_distance := 0.08


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
	return [Vector3(at.x, box.position.y, at.z) + out * 0.6, Vector3(at.x, box.end.y + 0.3, at.z) - out * 0.8]


## Unit normal pointing out of the wall, toward the climber.
func get_climb_normal() -> Vector3:
	var n := global_transform.basis.z
	n.y = 0.0

	if n.length_squared() < 0.0001:
		return Vector3.BACK

	return n.normalized()


## A point on the wall plane.
func get_plane_point() -> Vector3:
	return global_position


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("add_climb_volume"):
		body.add_climb_volume(self)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("remove_climb_volume"):
		body.remove_climb_volume(self)
