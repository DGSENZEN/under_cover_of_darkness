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
const WindowsScript := preload("res://scripts/Visual/Windows.gd")
const Lights := preload("res://scripts/Visual/Lights/Lights.gd")

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

	var steps := [["loader", _loader], ["sight", _sight], ["rays", _rays], ["moon", _moon_shafts], ["lamps", _lamps]]

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

	var window := {"piece": "fixture_wall", "sector": "s", "lead": "casement", "normal": [0.0, 0.0, 1.0], "outside": 0.25, "inside": 0.15,
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
	level.root.queue_free()
	await _frames(1)


func _sight() -> void:
	var level := _fixture([["room_fixture", Vector3(0.0, 1.5, 0.0), Vector3(6.0, 3.0, 6.0)]], "SightRoom")
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
	level.root.queue_free()
	await _frames(1)


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
# GW5-GW8, GW11: the moon's shafts
# ---------------------------------------------------------------------------

## A night whose moon share the test sets (GodRays reads the "night" group).
func _stub_night() -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar share := 1.0\nfunc moon_share() -> float:\n\treturn share\n"
	script.reload()
	var night := Node.new()
	night.set_script(script)
	night.add_to_group(&"night")
	add_child(night)
	return night


func _box_mesh(parent: Node, at: Vector3, layers: int) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.5
	mesh.mesh = box
	mesh.layers = layers
	parent.add_child(mesh)
	mesh.global_position = at
	return mesh


## The shaft's vertices: [near (UV2.x 0), far (UV2.x 1)].
func _ends(shaft: MeshInstance3D) -> Array:
	var arrays := (shaft.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var near: Array[Vector3] = []
	var far: Array[Vector3] = []

	for i in verts.size():
		(far if uv2[i].x > 0.5 else near).append(verts[i])

	return [near, far]


func _moon_shafts() -> void:
	var level := _fixture([], "MoonRoom")
	level.root.queue_free()
	await _frames(1)
	level = _fixture([["room_fixture", Vector3(0.0, 1.5, 0.0), Vector3(6.0, 3.0, 6.0)]], "MoonRoom2")
	var in_shaft := _box_mesh(level.root, Vector3(0, 0.25, 0.8), Layers.ROOFED)
	var aside := _box_mesh(level.root, Vector3(2.5, 0.25, -2.5), Layers.ROOFED)
	var moon := _moon()
	var night := _stub_night()
	await _frames(2)
	var windows: Node3D = WindowsScript.new()
	add_child(windows)
	windows.call("build", [level], [{"lights": {}}], moon)
	var w: Dictionary = windows.get("windows")[0]
	var built: bool = w["shaft"] != null
	var room_named: String = w["room"]
	var ends := _ends(w["shaft"]) if built else [[], []]
	var on_floor := not (ends[1] as Array).is_empty() and (ends[1] as Array).all(func(v): return absf((v as Vector3).y) < 0.1)
	var mouth_on_face := not (ends[0] as Array).is_empty() and (ends[0] as Array).all(func(v): return absf((v as Vector3).z - 3.0) < 0.01)
	var mouth_top: float = (ends[0] as Array).reduce(func(m, v): return maxf(m, (v as Vector3).y), -1.0)
	_check("GW6 a moon shaft starts at the room's face, under its head's shadow, and ends on what its corners' rays hit (the floor)",
		on_floor and mouth_on_face and absf(mouth_top - 2.222) < 0.02, "far on the floor %s, mouth on the inner face %s, its top %.3f" % [on_floor,
			mouth_on_face, mouth_top])
	var recast: Array = windows.get("recast")
	_check("GW7 what stands under a roof in a moon shaft casts again; elsewhere not", in_shaft.layers == Layers.WORLD and aside.layers == Layers.ROOFED
		and recast.has(in_shaft), "in the shaft %d, aside %d, recast %d" % [in_shaft.layers, aside.layers, recast.size()])

	# A cloud over the moon; lightning.
	var rays: Node3D = windows.get("moon_rays")
	night.set("share", 0.0)
	await _frames(2)
	var clouded := float(rays.get("strength"))
	night.set("share", 2.0)
	await _frames(2)
	var flared := float(rays.get("strength"))
	night.set("share", 1.0)
	_check("GW11 a cloud over the moon puts the window shafts out; lightning flares them", clouded < 0.01 and flared > float(rays.get("brightness")),
		"clouded %.3f, flared %.3f" % [clouded, flared])

	# Rebuilt twice: the same shafts, nothing left over.
	windows.call("rebuild")
	windows.call("rebuild")
	await _frames(1)
	rays = windows.get("moon_rays")
	var beams: Array = rays.get("beams")
	var stable := beams.size() == 1 and beams.all(func(b): return is_instance_valid(b)) and rays.get_child_count() == 1

	# The moon behind the wall; then in front, but hidden by a wall outside.
	moon.global_basis = Basis.looking_at(Vector3(0.0, -0.57, 0.82).normalized(), Vector3.UP)
	windows.call("rebuild")
	var behind: bool = windows.get("windows")[0]["shaft"] == null
	moon.global_basis = Basis.looking_at(MOON_WAY.normalized(), Vector3.UP)
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(4, 6, 1)
	blocker.add_child(shape)
	add_child(blocker)
	blocker.global_position = Vector3(0, 4, 6)
	await _frames(2)
	windows.call("rebuild")
	var hidden: bool = windows.get("windows")[0]["shaft"] == null
	blocker.queue_free()
	windows.queue_free()
	level.root.queue_free()
	await _frames(2)

	# No room at all: still its shaft.
	var bare := _fixture([], "Bare")
	await _frames(2)
	var lone: Node3D = WindowsScript.new()
	add_child(lone)
	lone.call("build", [bare], [{"lights": {}}], moon)
	var lone_window: Dictionary = lone.get("windows")[0]
	_check("GW5 a moon shaft only where the moon stands in front of the glass and sees it; in a room or none; rebuilt without duplicates",
		built and room_named == "room_fixture" and behind and hidden and lone_window["shaft"] != null and String(lone_window["room"]) == "" and stable,
		"built %s in '%s', moon behind %s, hidden %s, no room: built %s in '%s', rebuilt stable %s" % [built, room_named, behind, hidden,
			lone_window["shaft"] != null, lone_window["room"], stable])
	lone.queue_free()
	bare.root.queue_free()
	await _frames(1)

	# The smallest room holds a point.
	var nested := _fixture([["room_fixture", Vector3(0.0, 1.5, 0.0), Vector3(6.0, 3.0, 6.0)], ["room_inner", Vector3(0.0, 1.5, 0.0), Vector3(2.0, 2.0, 2.0)]],
		"Nested")
	var rooms: Node3D = WindowsScript.new()
	add_child(rooms)
	rooms.call("build", [nested], [{"lights": {}}], moon)
	var a: String = rooms.call("room_of", Vector3(0, 1.5, 0))
	var b: String = rooms.call("room_of", Vector3(2.5, 1.5, 2.5))
	var c: String = rooms.call("room_of", Vector3(0, 1.5, 9))
	_check("GW8 a point's room is the smallest box holding it; outside every box, none", a == "room_inner" and b == "room_fixture" and c == "",
		"'%s', '%s', '%s'" % [a, b, c])
	rooms.queue_free()
	nested.root.queue_free()
	moon.queue_free()
	night.queue_free()
	await _frames(1)


# ---------------------------------------------------------------------------
# GW9-GW10: a lit room's lamp thrown out through its glass
# ---------------------------------------------------------------------------

func _spot_energy(windows: Node3D) -> float:
	var spot: Variant = windows.get("windows")[0]["spot"]
	return (spot as SpotLight3D).light_energy if spot != null and is_instance_valid(spot) else 0.0


func _lamps() -> void:
	var level := _fixture([["room_fixture", Vector3(0.0, 1.5, 0.0), Vector3(6.0, 3.0, 6.0)]], "LampRoom")
	var a: Node3D = Lights.candle(self, Vector3(0, 1.0, 0))
	var b: Node3D = Lights.candle(self, Vector3(0, 1.0, -2.0))
	var c: Node3D = Lights.candle(self, Vector3(0, 1.0, 9.0))
	var moon := _moon(Vector3(0.0, -0.57, 0.82))  # (behind: no moon shaft in the way)
	await _seconds(2.0)
	var windows: Node3D = WindowsScript.new()
	add_child(windows)
	windows.call("build", [level], [{"lights": {"a": a, "b": b, "c": c}}], moon)
	await _seconds(0.5)
	var room: Dictionary = windows.get("rooms")["room_fixture"]
	var w: Dictionary = windows.get("windows")[0]
	var spot: Variant = w["spot"]
	var outside: bool = spot != null and (spot as SpotLight3D).global_position.z > 3.4
	var first: bool = room["lamp"] == a and outside and _spot_energy(windows) > 0.05 and w["lamp_shaft"] != null
	var notes := ["a: lamp %s, spot outside %s, energy %.2f, shaft %s" % [room["lamp"] == a, outside, _spot_energy(windows), w["lamp_shaft"] != null]]

	a.call("put_out", &"douse")
	await _until(func(): return room["lamp"] == b and _spot_energy(windows) > 0.05, 30)
	var next: bool = room["lamp"] == b and _spot_energy(windows) > 0.05
	notes.append("b: next %s" % next)

	b.call("put_out", &"douse")
	await _until(func(): return _spot_energy(windows) < 0.01 and float(room["fade"]) < 0.01, 30)
	var dark: bool = _spot_energy(windows) < 0.01 and float(room["fade"]) < 0.01 and room["lamp"] == null
	a.call("relight")
	await _until(func(): return _spot_energy(windows) > 0.05, 30)
	var back: bool = _spot_energy(windows) > 0.05 and room["lamp"] == a
	notes.append("c: dark %s, back %s" % [dark, back])

	var no_one: bool = not (room["lamps"] as Array).has(c) and not windows.get("rooms").values().any(func(r): return (r["lamps"] as Array).has(c))
	notes.append("d: c is no one's %s" % no_one)

	a.queue_free()
	await _until(func(): return room["lamp"] == null and _spot_energy(windows) < 0.01, 30)
	var freed: bool = room["lamp"] == null and _spot_energy(windows) < 0.01
	notes.append("e: freed -> dark %s" % freed)
	_check("GW9 a lit room throws its nearest lamp out through its glass; doused, the next; none, dark; a lamp in no room, or freed, is no one's",
		first and next and dark and back and no_one and freed, "; ".join(notes))

	b.call("relight")
	await _until(func(): return room["lamp"] == b, 30)
	var relit: bool = room["lamp"] == b
	b.set("lit", false)
	await _until(func(): return room["lamp"] != b, 30)
	_check("GW10 a lamp's state restored without a signal is caught within the poll", relit and room["lamp"] != b,
		"relit %s, then silently out: lamp now %s" % [relit, room["lamp"]])
	windows.queue_free()
	level.root.queue_free()
	moon.queue_free()

	for lamp in [b, c]:
		if is_instance_valid(lamp):
			lamp.queue_free()

	await _frames(1)


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
