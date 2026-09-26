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
