extends RefCounted
## Blink (Obsidian, innate): a mirror-flash step. Where it lands: along the
## line out to its reach, or short of the first thing in the way, never into
## anything; aimed at a floor, standing on it. The player's own capsule must
## fit where it arrives (a 1 m wide capsule: passages under 1.1 m refuse it).

## How far an aimed blink reaches, and a tapped one steps (metres).
const RANGE := 10.0
const STEP := 4.0
## Arrival is this far short of what the line met, then backed off in steps
## until the capsule fits.
const SHORT := 0.6
const BACK_OFF := 0.25
## The body is swept a little off the floor it stands on, so it does not
## catch on it.
const LIFT := 0.08
## Arrivals stand this far up, and the body drops the rest.
const SETTLE := 0.05
## Aimed no further than this under a lip, a blink ends hanging from it.
const LEDGE_BELOW := 1.2


## Where the player's body arrives, blinking from `eye` toward `toward`, up
## to `reach`; the player's own position if nowhere along it fits. The eye's
## line says how far (and whether it ends on a floor); the whole body swept
## along says whether the way is clear (a man's head under the eye's line
## still stops it).
static func arrival(player: CharacterBody3D, eye: Vector3, toward: Vector3, reach: float) -> Vector3:
	var space := player.get_world_3d().direct_space_state
	var direction := toward.normalized()
	var query := PhysicsRayQueryParameters3D.create(eye, eye + direction * reach, 1 | 2, [player.get_rid()])
	var hit := space.intersect_ray(query)
	# The body's origin, as the eye has it.
	var below_eye := player.global_position - eye
	var target := eye + direction * reach + below_eye

	if not hit.is_empty():
		var normal: Vector3 = hit.get("normal", -direction)

		# A floor: stood on.
		if normal.y > 0.7:
			target = hit["position"] + Vector3.UP * (_origin_above_feet(player) + 0.05)
		else:
			target = eye + direction * maxf(eye.distance_to(hit["position"]) - SHORT, 0.0) + below_eye

	var start := player.global_position + Vector3.UP * LIFT
	var motion := target + Vector3.UP * LIFT - start
	var safe := _swept(player, start, motion)
	var along := motion.length() * safe

	if safe < 1.0:
		along -= SHORT

	var way := motion.normalized() if motion.length() > 0.001 else Vector3.ZERO

	# (Arrived a hair off the ground: a body settled a few millimetres into
	# the floor it stood on would otherwise never fit anywhere at its height.)
	while along > 0.0:
		var at := start + way * along - Vector3.UP * (LIFT - SETTLE)

		if safe >= 1.0 and along >= motion.length() - 0.001:
			at = target + Vector3.UP * SETTLE

		if fits(player, at):
			return at

		along -= BACK_OFF

	return player.global_position


## How much of `motion` the player's capsule, from `start`, gets through
## before it would touch anything (0..1).
static func _swept(player: CharacterBody3D, start: Vector3, motion: Vector3) -> float:
	var collider: CollisionShape3D = player.get("collider")

	if collider == null or collider.shape == null or motion.length() < 0.001:
		return 1.0

	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = collider.shape
	shape_query.transform = Transform3D(player.global_basis, start) * collider.transform
	shape_query.motion = motion
	shape_query.collision_mask = player.collision_mask
	shape_query.exclude = [player.get_rid()]
	var fractions := player.get_world_3d().direct_space_state.cast_motion(shape_query)
	return fractions[0] if not fractions.is_empty() else 1.0


## Aimed at a wall's face just under its top (within LEDGE_BELOW of a lip
## the climbing accepts): {anchor, normal, lip_y, face_point} to arrive
## hanging from it (TraversalPlanner.probe_hang); {} otherwise.
static func ledge_at(player: CharacterBody3D, eye: Vector3, toward: Vector3, reach: float) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var direction := toward.normalized()
	var query := PhysicsRayQueryParameters3D.create(eye, eye + direction * reach, 1, [player.get_rid()])
	var hit := space.intersect_ray(query)

	if hit.is_empty() or player.get("planner") == null:
		return {}

	var normal: Vector3 = hit.get("normal", Vector3.UP)

	if absf(normal.y) > 0.3:
		return {}

	var face := Vector3(normal.x, 0.0, normal.z).normalized()
	var point: Vector3 = hit["position"]
	# The top above where it struck: down onto it from over the face.
	var over := point - face * 0.15
	var top_query := PhysicsRayQueryParameters3D.create(over + Vector3.UP * (LEDGE_BELOW + 0.1), over, 1, [player.get_rid()])
	var top := space.intersect_ray(top_query)

	if top.is_empty() or (top.get("normal", Vector3.ZERO) as Vector3).y < 0.7:
		return {}

	var lip_y: float = (top["position"] as Vector3).y
	# (Probed from where the body would hang, off the face: from on it, the
	# probe's ray would start inside the wall.)
	var held: Dictionary = player.planner.probe_hang(point + face * 0.5, face, lip_y, 0.1)

	if held.is_empty() or not fits(player, held["anchor"]):
		return {}

	# The body must get there: swept from where it stands.
	var start := player.global_position + Vector3.UP * LIFT
	var motion: Vector3 = held["anchor"] - player.global_position

	if _swept(player, start, motion) < 0.98:
		return {}

	return held


## Whether the player's capsule, standing at `at`, touches nothing.
static func fits(player: CharacterBody3D, at: Vector3) -> bool:
	var collider: CollisionShape3D = player.get("collider")

	if collider == null or collider.shape == null:
		return true

	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = collider.shape
	shape_query.transform = Transform3D(player.global_basis, at) * collider.transform
	shape_query.collision_mask = player.collision_mask
	shape_query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_shape(shape_query, 1).is_empty()


static func _origin_above_feet(player: CharacterBody3D) -> float:
	var collider: CollisionShape3D = player.get("collider")

	if collider == null or not (collider.shape is CapsuleShape3D):
		return 1.0

	return (collider.shape as CapsuleShape3D).height * 0.5 - collider.position.y
