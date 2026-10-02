extends Node3D
## Real water volumes/camera/moon: underwater transitions, light access and lifecycle.
const Water := preload("res://scripts/Interaction/WaterVolume.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
var results: Array[String] = []
var failed := false
var camera: Camera3D
var moon: DirectionalLight3D
var water: Area3D

func _ready() -> void:
	Props.block(self, Vector3(0, -4.5, 0), Vector3(40, 1, 40))
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_energy = 0.4
	moon.rotation_degrees = Vector3(-55, 20, 0)
	add_child(moon)
	water = Water.build(self, Vector3(0, -1.5, 0), Vector3(12, 5, 12))
	camera.position = Vector3(0, 0.3, 0)
	camera.look_at(camera.position + moon.global_basis.z * 10.0, Vector3.UP)
	await _frames(5)
	var view: Node = get_viewport().get_node_or_null("WaterView")
	_check("WA1 a submerged camera receives an underwater view automatically", view != null and view.get("active_water") == water, "view %s" % (view != null))
	var clear_strength: float = float(view.get("ray_strength")) if view != null else 0.0
	_check("WA2 looking toward an unobstructed moon receives underwater rays", clear_strength > 0.01, "rays %.3f" % clear_strength)
	camera.look_at(camera.position + Vector3.DOWN * 10.0, Vector3.FORWARD)
	await _frames(3)
	_check("WA3 looking away from the moon fades the ray emphasis", view != null and float(view.get("ray_strength")) < clear_strength * 0.3, "view direction")
	camera.look_at(camera.position + moon.global_basis.z * 10.0, Vector3.UP)
	var roof := Props.block(self, Vector3(0, 2.5, 0), Vector3(20, 0.4, 20))
	await _frames(5)
	_check("WA4 a solid roof blocks moon shafts underwater", view != null and float(view.get("ray_strength")) < 0.001, "roof occlusion")
	roof.queue_free()
	await _frames(5)
	_check("WA5 removing the obstruction restores the shafts", view != null and float(view.get("ray_strength")) > 0.01, "roof removed")
	camera.position.y = 1.3
	await _frames(5)
	_check("WA6 surfacing clears underwater optics", view != null and view.get("active_water") == null and not bool(view.get("visible_effect")), "above surface")
	camera.position = Vector3(0, -4.3, 0)
	await _frames(5)
	_check("WA7 below the volume's bottom is not underwater", view != null and view.get("active_water") == null, "outside bottom")
	camera.position = Vector3(20, 0.3, 0)
	await _frames(5)
	_check("WA8 outside its footprint is not underwater", view != null and view.get("active_water") == null, "outside sides")
	var second := Water.build(self, Vector3(20, -1.5, 0), Vector3(8, 5, 8))
	second.clarity = 0.8
	second.tint = Color(0.06, 0.18, 0.3, 0.7)
	await _frames(5)
	_check("WA9 camera changes select the actual containing water", view != null and view.get("active_water") == second, "selected second volume")
	var views := get_viewport().get_children().filter(func(n): return n.name == "WaterView").size()
	_check("WA10 multiple waters share one view pass", views == 1, "passes %d" % views)
	second.queue_free()
	await _frames(5)
	_check("WA11 deleting the active water leaves no stuck tint or shafts", view != null and view.get("active_water") == null and not bool(view.get("visible_effect")), "volume freed")
	camera.position = Vector3(0, 0.3, 0)
	moon.rotation_degrees = Vector3(30, 0, 0)
	camera.look_at(camera.position + Vector3(0, 0.2, -1), Vector3.UP)
	await _frames(5)
	_check("WA12 a moon below the horizon gives no underwater moon shafts", view != null and float(view.get("ray_strength")) < 0.001, "moon below horizon")
	var drawn: Variant = water._paint.get_shader_parameter("moon_direction")
	moon.rotation_degrees = Vector3(-45, -70, 0)
	await _frames(5)
	var changed: Variant = water._paint.get_shader_parameter("moon_direction")
	_check("WA13 rotating the moon updates the water's reflected direction", drawn is Vector3 and changed is Vector3 and drawn.distance_to(changed) > 0.5, "reflection follows source")
	# A preview or mirror viewport can own a different 3D world at the same
	# coordinates. Its volumes and moon must never bleed into the main view.
	var isolated := SubViewport.new()
	isolated.size = Vector2i(128, 128)
	isolated.own_world_3d = true
	add_child(isolated)
	var other_camera := Camera3D.new()
	isolated.add_child(other_camera)
	other_camera.current = true
	other_camera.position = camera.position
	var other_moon := DirectionalLight3D.new()
	other_moon.name = "OtherMoon"
	other_moon.rotation_degrees = Vector3(-80, 80, 0)
	other_moon.light_energy = 0.1
	isolated.add_child(other_moon)
	var other_water := Water.build(isolated, Vector3(0, -1.5, 0), Vector3(12, 5, 12))
	await _frames(5)
	var other_view: Node = isolated.get_node_or_null("WaterView")
	_check("WA15 independent viewport worlds select their own water", other_view != null and other_view.get("active_water") == other_water and view.get("active_water") == water, "world isolation")
	_check("WA16 independent worlds use their own moon", other_water.moon_direction().distance_to(other_moon.global_basis.z) < 0.001 and absf(other_water.moon_visibility() - 0.25) < 0.001, "source isolation")
	isolated.queue_free()
	water.queue_free()
	await _frames(5)
	_check("WA14 leaving all water clears the pass", view != null and not bool(view.get("visible_effect")), "last volume removed")
	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit(1 if failed else 0)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _check(label: String, ok: bool, detail: String) -> void:
	failed = failed or not ok
	results.append("%s  %s [%s]" % ["PASS" if ok else "FAIL", label, detail])
