class_name LanternPhysicsBody
extends RigidBody3D
## A mounted lantern accepts bumps and weapon impulses, but cannot be carried
## off while its hook still holds it.

func can_carry() -> bool:
	return false


## CharacterBody3D stops at its collision margin, before the rigid solver
## receives a contact. Transfer the incoming normal speed explicitly.
static func slide_character(character: CharacterBody3D) -> void:
	var incoming := character.velocity
	character.move_and_slide()
	var pushed := {}
	for i in character.get_slide_collision_count():
		var contact := character.get_slide_collision(i)
		var body := contact.get_collider() as LanternPhysicsBody
		if body == null or pushed.has(body):
			continue
		pushed[body] = true
		var normal := -contact.get_normal()
		var offset := contact.get_position() - body.global_position
		var moving := body.linear_velocity + body.angular_velocity.cross(offset)
		var speed := clampf((incoming - moving).dot(normal), 0.0, 3.0)
		if speed > 0.05:
			body.sleeping = false
			body.apply_impulse(normal * speed * body.mass * 6.0 * character.get_physics_process_delta_time(), offset)
