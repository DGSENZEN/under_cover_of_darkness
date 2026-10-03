extends RefCounted
## What the district remembers of a pickup (Loot, KeyItem, ToolItem): taken
## or not, and where it lies if it was knocked about.


## The state of `body` (a pickup with `taken`).
static func save(body: RigidBody3D) -> Dictionary:
	return {"taken": bool(body.get("taken")), "transform": body.global_transform}


## Puts `body` as it was left: freed if taken, else where it lay, asleep.
static func restore(body: RigidBody3D, state: Dictionary) -> void:
	if bool(state.get("taken", false)):
		body.set("taken", true)
		body.queue_free()
		return

	if state.has("transform"):
		body.global_transform = state["transform"]
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = true
		body.reset_physics_interpolation()
