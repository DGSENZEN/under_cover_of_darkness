extends RefCounted
## Picks the next grip for a climber on a wall, in a steered direction, from
## placed Handholds and from ledges the scanner finds on its own.
##
## Targets are hang-target dictionaries, the same as the planner's:
## {anchor, normal, lip_y, face_point, hold, reach}. hold is the Handhold, or
## null for a detected ledge; reach is true when the hands can get there
## without a leap.

const HANDHOLD := preload("res://scripts/PlayerUtils/Handhold.gd")

var scanner
var planner
var body: Node3D

## Hand over hand, from the grip held now (m).
var reach_up := 1.0
var reach_side := 0.8
var reach_down := 1.0
## How far off the steered direction a hold may lie.
var cone_degrees := 50.0


func setup(p_scanner, p_planner, p_body: Node3D) -> void:
	scanner = p_scanner
	planner = p_planner
	body = p_body


## The best grip from a hang at anchor (on wall_normal, lip at lip_y) toward
## direction (world, in the wall's plane), no further than max_reach from the
## grip held now. {} when nothing is there.
func next_hold(anchor: Vector3, wall_normal: Vector3, lip_y: float, direction: Vector3, max_reach: float) -> Dictionary:
	if direction.length() < 0.01:
		return {}

	var dir := direction.normalized()
	var grip := _grip_of(anchor, wall_normal, lip_y)
	var best := {}
	var best_score := INF

	for target in _candidates(grip, wall_normal, lip_y, dir, max_reach):
		var offset: Vector3 = _target_grip(target) - grip
		var distance := offset.length()

		if distance < 0.25 or distance > max_reach:
			continue

		var angle := rad_to_deg(dir.angle_to(offset))

		if angle > cone_degrees:
			continue

		target["reach"] = _within_reach(offset, wall_normal)
		# Within reach beats a leap; then straightest; then nearest.
		var score := (0.0 if target["reach"] else 1000.0) + angle + distance

		if score < best_score:
			best_score = score
			best = target

	return best


## Hanging on one hold, at its grip nearest near. {} when the hanging body
## would not fit there.
func hold_target(hold: Node3D, near: Vector3) -> Dictionary:
	var grip: Vector3 = hold.grip_near(near)
	var normal: Vector3 = hold.outward()
	var anchor: Vector3 = planner.hang_anchor(grip, normal, grip.y)

	if not scanner.fits(anchor, false) or not _grip_is_real(grip, normal, anchor):
		return {}

	return {
		"anchor": anchor,
		"normal": normal,
		"lip_y": grip.y,
		"face_point": grip,
		"hold": hold,
		"reach": false,
	}


## A hold's marker can drift from its stone (moved in the workshop, the
## geometry gone): the hands must reach the grip through open air, and there
## must be something just behind it to hold.
func _grip_is_real(grip: Vector3, normal: Vector3, anchor: Vector3) -> bool:
	var hands := Vector3(anchor.x, grip.y - 0.02, anchor.z)
	var short_of := grip + normal * 0.02 - Vector3.UP * 0.02

	if not scanner.ray(hands, short_of).is_empty():
		return false

	var front := grip + normal * 0.05 - Vector3.UP * 0.03
	return not scanner.ray(front, front - normal * 0.3).is_empty()


## Placed holds within radius of point.
func holds_within(point: Vector3, radius: float) -> Array:
	var found := []

	if body == null or not body.is_inside_tree():
		return found

	for node in body.get_tree().get_nodes_in_group(HANDHOLD.GROUP):
		var hold := node as Node3D

		if hold != null and hold.grip_near(point).distance_to(point) <= radius:
			found.append(hold)

	return found


func _candidates(grip: Vector3, wall_normal: Vector3, lip_y: float, dir: Vector3, max_reach: float) -> Array:
	var list := []

	for hold in holds_within(grip, max_reach):
		# Only holds on this side of a wall like ours, or ahead of us across a
		# corner; never the back of something.
		if hold.outward().dot(wall_normal) < 0.0:
			continue

		var target := hold_target(hold, grip + dir * grip.distance_to(hold.grip_near(grip)))

		if not target.is_empty():
			list.append(target)

	# Ledges in the stone itself: probe along the steered direction.
	var lateral := wall_normal.cross(Vector3.UP).normalized()
	var distance := 0.4

	while distance <= max_reach:
		var at: Vector3 = grip + dir * distance
		var point: Vector3 = at + wall_normal * (scanner.radius + planner.hang_gap)
		var found: Dictionary = planner.probe_hang(Vector3(point.x, at.y, point.z), wall_normal, at.y, 0.15)

		if not found.is_empty() and (absf(found["lip_y"] - lip_y) > 0.2 or absf((found["face_point"] - grip).dot(lateral)) > 0.3):
			found["hold"] = null
			list.append(found)

		distance += 0.25

	return list


func _grip_of(anchor: Vector3, wall_normal: Vector3, lip_y: float) -> Vector3:
	var grip: Vector3 = anchor - wall_normal * (scanner.radius + planner.hang_gap)
	return Vector3(grip.x, lip_y, grip.z)


func _target_grip(target: Dictionary) -> Vector3:
	var face: Vector3 = target["face_point"]
	return Vector3(face.x, target["lip_y"], face.z)


func _within_reach(offset: Vector3, wall_normal: Vector3) -> bool:
	var side := absf(offset.dot(wall_normal.cross(Vector3.UP).normalized()))

	if side > reach_side:
		return false

	return offset.y <= reach_up and -offset.y <= reach_down
