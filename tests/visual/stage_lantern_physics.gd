extends Node3D
## Rendered captures of the same lamp at rest, in wind, and after impact.
const Lights := preload("res://scripts/Visual/Lights/Lights.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
var lamp: Node3D

func _ready() -> void:
	get_tree().root.size = Vector2i(960, 540)
	get_tree().root.get_node("Retro").enabled = false
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.025, 0.03, 0.04)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.4, 0.5, 0.65)
	world.environment.ambient_light_energy = 0.12
	add_child(world)
	Props.block(self, Vector3(0, -0.15, 0), Vector3(8, 0.3, 7), Color(0.28, 0.3, 0.32))
	Props.block(self, Vector3(0, 2, -1.1), Vector3(8, 4, 0.25), Color(0.5, 0.48, 0.42))
	Props.block(self, Vector3(0, 2.85, 0), Vector3(3.2, 0.15, 0.2), Color(0.15, 0.1, 0.07))
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(2.2, 1.7, 3.4)
	cam.look_at(Vector3(0, 1.8, 0))
	cam.fov = 43
	cam.current = true
	lamp = Lights.hanging_lantern(self, Vector3(0, 2.8, 0), 0.6, {"can_douse": true, "flicker": 0.0})
	await _frames(100)
	await _capture("rest")
	lamp.lean(Vector3(1.3, 0, 0.4))
	await _frames(100)
	await _capture("wind")
	lamp.lean(Vector3.ZERO)
	lamp.swing_body.apply_impulse(Vector3(-1.6, 0, 0.4), lamp.flame_position() - lamp.swing_body.global_position)
	await _frames(18)
	await _capture("impact")
	print("PASS rendered lantern captures: /tmp/lantern-physics-{rest,wind,impact}.png")
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/lantern-physics-" + label + ".png")
	print(label, " lamp ", lamp.flame_position(), " light ", lamp.light.global_position, " tilt ", lamp.global_basis.y.angle_to(Vector3.UP))
