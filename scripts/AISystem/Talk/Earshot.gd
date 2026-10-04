extends RefCounted
## Whether the player hears what a man says (the harbour's job spec, section
## 5.2): near enough (RANGE) and nothing solid between his mouth and the
## player's head (a closed door is solid; an open one is not). The subtitle
## shows only then, and a line carrying a note teaches it only then: a line
## shown is a line learnt.

const RANGE := 22.0


static func heard(speaker: Node3D, listener: Node3D) -> bool:
	if speaker == null or listener == null or not is_instance_valid(speaker) or not is_instance_valid(listener):
		return false

	if speaker.global_position.distance_to(listener.global_position) > RANGE:
		return false

	var mouth: Vector3 = speaker.eye_position() if speaker.has_method("eye_position") else speaker.global_position + Vector3.UP * 1.6
	var eye := listener.get_node_or_null("Neck/Camera3D") as Node3D
	var head: Vector3 = eye.global_position if eye != null else listener.global_position + Vector3.UP * 1.6

	if speaker.has_method("_line_of_sight"):
		return speaker._line_of_sight(mouth, head, listener)

	var query := PhysicsRayQueryParameters3D.create(mouth, head, 1)
	query.exclude = [speaker.get_rid(), listener.get_rid()] if speaker is CollisionObject3D and listener is CollisionObject3D else []
	return speaker.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
