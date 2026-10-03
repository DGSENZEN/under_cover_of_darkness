extends Node3D
## Real windows (the real-windows plan): first a small room of colliders
## written as a level's manifest (user://glass_fixture), its south wall cut
## round a glazed window, for the parts (loading, sight and light through
## glass, the shafts, the lamplight); then the harbour as it is played.
##   Godot --headless --fixed-fps 60 --path . res://tests/windows_test.tscn [-- --only=<step>]

const LevelLoader := preload("res://scripts/Level/LevelLoader.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const SightRay := preload("res://scripts/StimuliSystem/SightRay.gd")
const Materials := preload("res://scripts/Visual/Materials.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const GodRaysScript := preload("res://scripts/Visual/GodRays.gd")

const FIXTURE := "user://glass_fixture"
const IDENTITY := [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
## The fixture's moon: from over the window's side (+z), 35 degrees up.
const MOON_WAY := Vector3(0.0, -0.57, -0.82)

var results: Array[String] = []


func _ready() -> void:
	var only := ""

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")

	var steps := [["loader", _loader], ["sight", _sight], ["rays", _rays]]

	for step in steps:
		if only == "" or step[0] == only:
			await (step[1] as Callable).call()

	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


# ---------------------------------------------------------------------------
# The fixture: a room 6 x 3 x 6 m about the origin, walls 0.4 thick, its
# south wall (z 3.0 to 3.4) cut round a window x -0.5..0.5, y 1..2.5, glass
# in it; a ceiling over it.
# ---------------------------------------------------------------------------

func _collider(centre: Vector3, size: Vector3, surface := "stone") -> Dictionary:
	var c := {"sector": "s", "centre": [centre.x, centre.y, centre.z], "basis": IDENTITY, "size": [size.x, size.y, size.z], "surface": surface}

	if surface == "glass":
		c["occluder"] = false

	return c


## Writes the fixture's manifest (its rooms [[name, centre, size]]) and loads
## it under `root_name`.
func _fixture(rooms: Array = [["room_fixture", Vector3(0.0, 1.5, 0.0), Vector3(6.0, 3.0, 6.0)]], root_name := "Fixture") -> LevelLoader.Level:
	var colliders := [_collider(Vector3(0, -0.1, 0), Vector3(7, 0.2, 7)), _collider(Vector3(0, 3.1, 0), Vector3(7, 0.2, 7)),
		_collider(Vector3(0, 1.5, -3.2), Vector3(7, 3, 0.4)), _collider(Vector3(3.2, 1.5, 0), Vector3(0.4, 3, 7)),
		_collider(Vector3(-3.2, 1.5, 0), Vector3(0.4, 3, 7)), _collider(Vector3(-1.95, 1.5, 3.2), Vector3(2.9, 3, 0.4)),
		_collider(Vector3(1.95, 1.5, 3.2), Vector3(2.9, 3, 0.4)), _collider(Vector3(0, 0.5, 3.2), Vector3(1, 1, 0.4)),
		_collider(Vector3(0, 2.75, 3.2), Vector3(1, 0.5, 0.4)), _collider(Vector3(0, 1.75, 3.2), Vector3(1, 1.5, 0.4), "glass")]
	var markers := []

	for room in rooms:
		var at: Vector3 = room[1]
		var size: Vector3 = room[2]
		markers.append({"name": room[0], "ucd": "room", "sector": "s", "position": [at.x, at.y, at.z], "basis": IDENTITY,
			"size": [size.x, size.y, size.z], "props": {}})

	var window := {"piece": "fixture_wall", "sector": "s", "lead": "casement", "normal": [0.0, 0.0, 1.0],
		"outline": [[-0.5, 1.0, 3.15], [0.5, 1.0, 3.15], [0.5, 2.5, 3.15], [-0.5, 2.5, 3.15]]}
	var manifest := {"level": "glass_fixture", "sectors": ["s"], "colliders": colliders, "markers": markers, "sockets": [], "pieces": 0,
		"ranges": {}, "terrain": [], "shadowless": [], "roofed": [], "merged": [], "loose": [], "windows": [window]}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE))
	var file := FileAccess.open(FIXTURE.path_join("glass_fixture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	return LevelLoader.load_level(self, FIXTURE, root_name)


func _moon(way: Vector3 = MOON_WAY) -> DirectionalLight3D:
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.shadow_enabled = true
	add_child(moon)
	moon.global_basis = Basis.looking_at(way.normalized(), Vector3.UP)
	LightProbe.invalidate()
	return moon


func _glass_box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.add_to_group(&"glass")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = at
	return body


# ---------------------------------------------------------------------------
# GW1-GW3: loaded; sight and light through glass
# ---------------------------------------------------------------------------

func _loader() -> void:
	var level := _fixture()
	var glass := level.root.find_children("*", "StaticBody3D", true, false).filter(func(b): return (b as Node).is_in_group(&"glass"))
	var occluders := level.root.get_node_or_null("Occluders")
	var occluded := occluders != null and occluders.get_children().any(func(o): return (o as Node3D).position.distance_to(Vector3(0, 1.75, 3.2)) < 0.01)
	var cut := LevelLoader.load_level(self, FIXTURE, "Cut", ["s"])
	var glazing := Materials.level_surface(&"glazing")
	var blended := glazing is ShaderMaterial and (glazing as ShaderMaterial).shader.code.contains("blend_mix") \
		and not (glazing as ShaderMaterial).shader.code.contains("depth_prepass_alpha")
	var quarries := Materials.level_surface(&"quarries") as BaseMaterial3D
	var scissor := quarries != null and quarries.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_check("GW1 a level's windows and room load; its glass bodies are in 'glass' and never occlude; a left-out sector drops its windows; glazing blends, quarries cut",
		level.windows.size() == 1 and level.of("room").size() == 1 and glass.size() == 1 and not occluded and cut.windows.is_empty() and blended and scissor,
		"windows %d, rooms %d, glass bodies %d, occluded %s, cut's windows %d, glazing blends %s, quarries cut %s" % [level.windows.size(),
			level.of("room").size(), glass.size(), occluded, cut.windows.size(), blended, scissor])
	cut.root.queue_free()


func _sight() -> void:
	await _frames(2)
	var space := get_world_3d().direct_space_state
	var through := SightRay.first_solid(space, PhysicsRayQueryParameters3D.create(Vector3(0, 1.75, 6), Vector3(0, 1.75, 0), 1))
	var wall := SightRay.first_solid(space, PhysicsRayQueryParameters3D.create(Vector3(2, 1.75, 6), Vector3(2, 1.75, 0), 1))
	var pane := _glass_box(Vector3(0, 1.75, 4.5), Vector3(1, 1.5, 0.1))
	await _frames(2)
	var twice := SightRay.first_solid(get_world_3d().direct_space_state, PhysicsRayQueryParameters3D.create(Vector3(0, 1.75, 6), Vector3(0, 1.75, 0), 1))
	pane.queue_free()
	_check("GW2 a ray through one pane, or two, goes on; through a wall it stops", through.is_empty() and twice.is_empty() and not wall.is_empty(),
		"through %s, two panes %s, wall %s" % [through.get("collider"), twice.get("collider"), wall.get("collider")])

	var moon := _moon()
	await _frames(2)
	var lit := LightProbe.light_at(self, Vector3(0, 0.05, 0.5))
	var dark := LightProbe.light_at(self, Vector3(2.0, 0.05, 0.5))
	_check("GW3 the probe reads the moon through the glass on the patch, and none a step beside under the ceiling", lit > dark + 0.3,
		"%.2f on the patch, %.2f beside" % [lit, dark])
	moon.queue_free()


# ---------------------------------------------------------------------------
# GW4: god rays from a point, to each corner's own reach, weighted
# ---------------------------------------------------------------------------

func _rays() -> void:
	var rays: Node3D = GodRaysScript.new()
	rays.set("follow_moon", false)
	add_child(rays)
	var outline := PackedVector3Array([Vector3(-0.5, 1, 0), Vector3(0.5, 1, 0), Vector3(0.5, 2, 0), Vector3(-0.5, 2, 0)])
	var uvs := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	var source := Vector3(0, 1.5, -2)
	var reaches := PackedFloat32Array([1.0, 2.0, 3.0, 4.0])
	var beam: MeshInstance3D = rays.call("add_window", outline, uvs, reaches, source, 0.5)
	var arrays := (beam.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var missing: Array[int] = []

	for i in outline.size():
		var far := outline[i] + (outline[i] - source).normalized() * reaches[i]

		if not Array(verts).any(func(v): return (v as Vector3).distance_to(far) < 0.001):
			missing.append(i)

	var weighted := uv2.size() == verts.size() and Array(uv2).all(func(u): return absf((u as Vector2).y - 0.5) < 0.0001)
	rays.set("strength", 0.7)
	await _frames(2)
	var given := float((beam.material_override as ShaderMaterial).get_shader_parameter(&"strength"))
	_check("GW4 a point-sourced shaft spreads from its lamp to each corner's own reach, carries its weight, and a lamp's node keeps the strength it is given",
		missing.is_empty() and weighted and absf(given - 0.7) < 0.0001, "corners not reached %s, weighted %s, strength %.3f" % [missing, weighted, given])
	rays.queue_free()


# ---------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * Engine.physics_ticks_per_second))


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
