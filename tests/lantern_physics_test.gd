extends Node3D
## Real fixture/world physics, including lighting and use after a collision.
const Lights := preload("res://scripts/Visual/Lights/Lights.gd")
const Probe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const LanternBody := preload("res://scripts/Visual/Lights/LanternBody.gd")
const GUARD := preload("res://Guard.tscn")
var failed := false

func _ready() -> void:
	Sfx.enabled = false
	print("==== RESULTS ====")
	await _hanging()
	await _wall()
	await _contacts()
	await _guard_sight()
	get_tree().quit(1 if failed else 0)

func _check(label: String, okay: bool, info := "") -> void:
	failed = failed or not okay
	print("%s %s %s" % ["PASS" if okay else "FAIL", label, info])

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _body(lamp: Node3D) -> RigidBody3D:
	var found := lamp.find_children("*", "RigidBody3D", true, false)
	return found[0] as RigidBody3D if not found.is_empty() else null

func _hanging() -> void:
	var hook := Vector3(20, 4, 10)
	var lamp := Lights.make(self, &"hanging_lantern", hook, PI * 0.5, {"hang_drop": 0.6, "can_douse": true, "flicker": 0.0})
	await _ticks(8)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(19, 3.65 - 0.6, 10), Vector3(21, 3.65 - 0.6, 10), 1))
	var body := _body(lamp)
	_check("LP1 the hanging lamp has a solid body at its model", body != null and hit.get("collider") == body)
	if body != null:
		var old_light: Vector3 = lamp.light.global_position
		body.apply_impulse(Vector3(1.2, 0, 0), lamp.flame_position() - body.global_position)
		var travel := 0.0
		var hook_error := 0.0
		var alignment := 0.0
		var light_tilt := 0.0
		for i in 60:
			await _ticks(1)
			travel = maxf(travel, old_light.distance_to(lamp.light.global_position))
			hook_error = maxf(hook_error, lamp.global_position.distance_to(hook))
			alignment = maxf(alignment, lamp.flame_position().distance_to(lamp._reach.global_position))
			light_tilt = maxf(light_tilt, lamp.light.global_basis.y.angle_to(Vector3.UP))
		_check("LP2 a blow swings the lamp while its hook stays fixed", travel > 0.08 and hook_error < 0.03, "travel %.3f hook error %.3f" % [travel, hook_error])
		_check("LP3 the flame, use area and projected light follow the body", alignment < 0.02 and lamp.light.light_projector != null and light_tilt > 0.02, "alignment %.3f light tilt %.3f" % [alignment, light_tilt])
		lamp.lean(Vector3.ZERO)
		await _ticks(600)
		_check("LP4 a disturbed lamp settles under gravity", lamp.global_basis.y.angle_to(Vector3.UP) < 0.035 and lamp.swing_speed() < 0.06, "tilt %.3f speed %.3f" % [lamp.global_basis.y.angle_to(Vector3.UP), lamp.swing_speed()])
		lamp.lean(Vector3(1, 0, 0))
		var downwind := 0.0
		for i in 180:
			await _ticks(1)
			downwind = maxf(downwind, lamp.flame_position().x - hook.x)
		_check("LP5 wind acts in world space on a rotated lamp", downwind > 0.04 and lamp.global_position.distance_to(hook) < 0.03, "downwind %.3f" % downwind)
		lamp.put_out(&"snuff", true)
		await _ticks(3)
		_check("LP6 dousing a moving lamp still extinguishes its actual light", not lamp.is_lit() and lamp.light.light_energy < 0.001 and lamp._reach.collision_layer == 0)
	lamp.queue_free()
	await _ticks(3)

func _wall() -> void:
	var lamp := Lights.wall_lantern(self, Vector3(40, 3, 10), Vector3.BACK, {"shadows": true, "flicker": 0.0})
	await _ticks(8)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(39, 2.95, 10.3), Vector3(41, 2.95, 10.3), 1))
	_check("LP7 a wall lantern is solid and stays mounted", hit.get("collider") is StaticBody3D and _body(lamp) == null)
	var at: Vector3 = lamp.light.global_position + Vector3.RIGHT * 2.0
	Probe.invalidate()
	var lit: float = Probe.light_at(self, at)
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.15, 2, 2)
	shape.shape = box
	blocker.add_child(shape)
	add_child(blocker)
	blocker.global_position = lamp.light.global_position + Vector3.RIGHT
	await _ticks(4)
	var blocked: float = Probe.light_at(self, at)
	_check("LP8 a lantern's own collision never erases its gameplay light, but a wall does", lit > 0.1 and blocked < 0.001, "lit %.3f blocked %.3f" % [lit, blocked])
	lamp.queue_free()
	blocker.queue_free()
	await _ticks(3)

func _contacts() -> void:
	var hook := Vector3(60, 3, 10)
	var lamp := Lights.hanging_lantern(self, hook, 0.6)
	await _ticks(8)
	var body := _body(lamp)
	if body == null:
		_check("LP9 thrown objects can collide with the hanging lamp", false, "no solid lamp")
		_check("LP10 walking into the lamp gives it momentum", false, "no solid lamp")
		lamp.queue_free()
		return
	var missile := RigidBody3D.new()
	missile.mass = 0.5
	missile.gravity_scale = 0.0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.08
	shape.shape = sphere
	missile.add_child(shape)
	add_child(missile)
	missile.global_position = Vector3(59.2, 2.05, 10)
	missile.linear_velocity = Vector3(4, 0, 0)
	var travel := 0.0
	for i in 60:
		await _ticks(1)
		travel = maxf(travel, absf(lamp.flame_position().x - hook.x))
	_check("LP9 thrown objects can collide with the hanging lamp", travel > 0.04, "travel %.3f" % travel)
	missile.queue_free()
	lamp.queue_free()
	await _ticks(3)

	lamp = Lights.hanging_lantern(self, hook, 0.6)
	await _ticks(8)
	var walker := CharacterBody3D.new()
	shape = CollisionShape3D.new()
	sphere = SphereShape3D.new()
	sphere.radius = 0.2
	shape.shape = sphere
	walker.add_child(shape)
	add_child(walker)
	walker.global_position = Vector3(59.3, 2.05, 10)
	travel = 0.0
	for i in 50:
		walker.velocity = Vector3(1.5, 0, 0)
		LanternBody.slide_character(walker)
		await _ticks(1)
		travel = maxf(travel, absf(lamp.flame_position().x - hook.x))
	_check("LP10 walking into the lamp gives it momentum", travel > 0.04, "travel %.3f" % travel)
	walker.queue_free()
	lamp.queue_free()
	await _ticks(3)


func _guard_sight() -> void:
	var guard := GUARD.instantiate() as CharacterBody3D
	add_child(guard)
	guard.set_physics_process(false)
	guard.global_position = Vector3(100, 0, 0)
	for fixture in [&"hanging_lantern", &"wall_lantern"]:
		var lamp := Lights.make(self, fixture, Vector3(80, 3, 10), 0.0, {"hang_drop": 0.6, "can_douse": true})
		await _ticks(8)
		lamp.put_out(&"snuff", true)
		var flame: Vector3 = lamp.flame_position()
		var eye := flame + Vector3.BACK * 3.0
		var seen: bool = guard._line_of_sight(eye, flame, lamp)
		var blocker := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2, 2, 0.2)
		shape.shape = box
		blocker.add_child(shape)
		add_child(blocker)
		blocker.global_position = flame + Vector3.BACK
		await _ticks(3)
		var behind_wall: bool = guard._line_of_sight(eye, flame, lamp)
		_check("LP11 guards can see a dark %s through its own shell, but not through a wall" % fixture, seen and not behind_wall, "seen %s behind wall %s" % [seen, behind_wall])
		blocker.queue_free()
		lamp.queue_free()
		await _ticks(3)
	guard.queue_free()
	await _ticks(3)
