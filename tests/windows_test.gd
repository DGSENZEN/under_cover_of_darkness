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
const CoronaScript := preload("res://scripts/Visual/Lights/Corona.gd")
const CITY := preload("res://maps/city.tscn")

## The harbour's: its quay's top, the customs house's upper floor, the
## carrack's place and her stern's and cabin bulkhead's x in her frame.
const QUAY := 2.5
const CUSTOMS_UPPER := QUAY + 4.0
const CARRACK_X := 40.0
const STERN := -15.2
const CASTLE_FRONT := -6.0

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

	var steps := [["loader", _loader], ["sight", _sight], ["rays", _rays], ["moon", _moon_shafts], ["lamps", _lamps], ["harbour", _harbour]]

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

	# A lamp's halo outside, seen from in the room through the glass; and
	# from behind the wall beside it, not.
	var corona: Node3D = CoronaScript.new()
	add_child(corona)
	corona.global_position = Vector3(0, 1.75, 6.0)
	var eye := Camera3D.new()
	add_child(eye)
	eye.global_position = Vector3(0, 1.75, 1.0)
	await _frames(2)
	var seen := float(corona.call("_clear_share", eye, [] as Array[RID]))
	eye.global_position = Vector3(2.0, 1.75, 1.0)
	corona.global_position = Vector3(2.0, 1.75, 6.0)
	await _frames(1)
	var hidden := float(corona.call("_clear_share", eye, [] as Array[RID]))
	_check("GW21 a lamp's halo is seen through a window's glass, not through the wall beside it", seen > 0.99 and hidden < 0.01,
		"through the glass %.2f, through the wall %.2f" % [seen, hidden])
	corona.queue_free()
	eye.queue_free()
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
	# A window's soft shafts: its edge fade and fall-off reach the shader; a
	# node left as made (the chapel's) leaves the shader's own.
	var soft: Node3D = GodRaysScript.new()
	soft.set("edge_from", 0.55)
	soft.set("edge_to", 1.0)
	soft.set("fall_power", 2.5)
	add_child(soft)
	var soft_beam: MeshInstance3D = soft.call("add_window", outline, uvs)
	var soft_material := soft_beam.material_override as ShaderMaterial
	var plain_material := beam.material_override as ShaderMaterial
	var pushed := is_equal_approx(float(soft_material.get_shader_parameter(&"edge_from")), 0.55) \
		and is_equal_approx(float(soft_material.get_shader_parameter(&"fall_power")), 2.5)
	var kept := plain_material.get_shader_parameter(&"edge_from") == null and plain_material.get_shader_parameter(&"fall_power") == null
	_check("GW4 a point-sourced shaft spreads from its lamp to each corner's own reach, carries its weight, and a lamp's node keeps the strength it is given; a window's soft edges and fall-off reach its shader, the chapel's stay the shader's own",
		missing.is_empty() and weighted and absf(given - 0.7) < 0.0001 and pushed and kept, "corners not reached %s, weighted %s, strength %.3f, soft pushed %s, plain kept %s" % [
			missing, weighted, given, pushed, kept])
	rays.queue_free()
	soft.queue_free()


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


## The window's glow (lit from within): its energy, and whether it is for
## show only (no one is lit up by it: fx_light, not on the gem's layer).
func _glow(windows: Node3D) -> Array:
	var glow: Variant = windows.get("windows")[0].get("glow")

	if glow == null or not is_instance_valid(glow):
		return [0.0, false]

	var light := glow as OmniLight3D
	return [light.light_energy, light.is_in_group(&"fx_light") and (light.light_cull_mask & Layers.GEM_PROBE) == 0]


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
	# (The engine draws a projector only through a light's shadow: a patch
	# with one and no shadow would light nothing yet count as light.)
	var drawn: bool = spot != null and ((spot as SpotLight3D).light_projector == null or (spot as SpotLight3D).shadow_enabled)
	var glow_lit: Array = _glow(windows)
	var first: bool = room["lamp"] == a and outside and drawn and _spot_energy(windows) > 0.05 and w["lamp_shaft"] != null and float(glow_lit[0]) > 0.05 and bool(glow_lit[1])
	var notes := ["a: lamp %s, spot outside %s drawn %s, energy %.2f, shaft %s, glow %.2f for show %s" % [room["lamp"] == a, outside, drawn,
		_spot_energy(windows), w["lamp_shaft"] != null, float(glow_lit[0]), glow_lit[1]]]

	a.call("put_out", &"douse")
	await _until(func(): return room["lamp"] == b and _spot_energy(windows) > 0.05, 30)
	var next: bool = room["lamp"] == b and _spot_energy(windows) > 0.05
	notes.append("b: next %s" % next)

	b.call("put_out", &"douse")
	await _until(func(): return _spot_energy(windows) < 0.01 and float(room["fade"]) < 0.01, 30)
	var dark: bool = _spot_energy(windows) < 0.01 and float(room["fade"]) < 0.01 and room["lamp"] == null and float(_glow(windows)[0]) < 0.01
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
# GW12-GW20: the harbour, as it is played
# ---------------------------------------------------------------------------

func _harbour() -> void:
	var city: Node3D = CITY.instantiate()
	add_child(city)

	while not city.get("player"):
		await get_tree().process_frame

	if not city.get("load_seconds"):
		await city.ready_to_play

	await _seconds(1.0)

	# The guards held still: the checks measure the place.
	for g in city.guards.values():
		(g as Node).set_physics_process(false)
		(g as Node).set_process(false)

	var windows: Node3D = city.get("windows")
	var level: LevelLoader.Level = city.levels["city_harbour"]
	var all: Array = windows.get("windows")
	var glass := level.root.find_children("*", "StaticBody3D", true, false).filter(func(b): return (b as Node).is_in_group(&"glass"))
	var occluding: Array[String] = []

	for occluder in level.root.get_node("Occluders").get_children():
		var box := (occluder as OccluderInstance3D).occluder as BoxOccluder3D

		if box == null:
			continue

		for w in all:
			var local: Vector3 = (occluder as Node3D).global_transform.affine_inverse() * (w["middle"] as Vector3)

			if absf(local.x) < box.size.x / 2.0 and absf(local.y) < box.size.y / 2.0 and absf(local.z) < box.size.z / 2.0:
				occluding.append(String(w["piece"]))

	_check("GW12 the harbour's 21 windows are loaded; their glass is in 'glass'; no occluder stands in a window", level.windows.size() == 21
		and all.size() == 21 and not glass.is_empty() and occluding.is_empty(), "records %d, windows %d, glass bodies %d, occluders in windows %s" % [
			level.windows.size(), all.size(), glass.size(), occluding])

	# The moon in.
	var front := all.filter(func(w): return (w["normal"] as Vector3).z > 0.9 and (w["middle"] as Vector3).y > CUSTOMS_UPPER)
	var back_lit := all.filter(func(w): return (w["normal"] as Vector3).z < -0.5 and w["shaft"] != null)
	var odd := all.filter(func(w): return w["shaft"] != null and (float(w["facing"]) <= 0.1 or float(w["sky"]) < 5.0 / 9.0))
	_check("GW13 the store front's three windows have moon shafts; no back window has one; every shaft's window faces the moon and sees it",
		front.size() == 3 and front.all(func(w): return w["shaft"] != null) and back_lit.is_empty() and odd.is_empty(),
		"front %d (with shafts %d), back with shafts %d, odd %d; shafts in all %d" % [front.size(), front.filter(func(w): return w["shaft"] != null).size(),
			back_lit.size(), odd.size(), all.filter(func(w): return w["shaft"] != null).size()])

	if front.size() == 3 and front.all(func(w): return w["shaft"] != null):
		front.sort_custom(func(a, b): return (a["middle"] as Vector3).x < (b["middle"] as Vector3).x)
		var middle_window: Dictionary = front[1]
		var far: Array = _ends(middle_window["shaft"])[1]
		var patch := Vector3.ZERO

		for v in far:
			patch += v / float(far.size())

		patch += Vector3.UP * 0.05
		var beside := patch - Vector3(1.2, 0.0, 0.0)
		var lit := LightProbe.light_at(self, patch)
		var dark := LightProbe.light_at(self, beside)
		_check("GW14 the probe reads the store's moon patch lit, a step along the wall darker", lit >= dark + 0.15, "%.2f on the patch %s, %.2f beside" % [lit,
			patch.snapped(Vector3.ONE * 0.01), dark])

		# Sight through the glass, and not through the stone beside it.
		var guard: Node3D = city.guards.values()[0]
		var normal: Vector3 = middle_window["normal"]
		var target: Vector3 = (middle_window["middle"] as Vector3) - normal * (float(middle_window["inside"]) + 1.5) + Vector3.UP * 0.5
		var eye: Vector3 = (middle_window["middle"] as Vector3) + ((middle_window["middle"] as Vector3) - target).normalized() * 8.0
		var along := Vector3(2.25, 0.0, 0.0)
		var through: bool = guard.call("_line_of_sight", eye, target, null)
		var stone: bool = guard.call("_line_of_sight", eye + along, target + along, null)
		_check("GW15 a guard on the quay sees into the store through its glass, not through the stone beside it", through and not stone,
			"through the glass %s, through the stone %s" % [through, stone])

		# Your marks: a guard watching you through the glass is not behind a
		# wall (his mark not dimmed); one behind the stone is.
		var hud: Node = city.player.get("hud")
		var view := Camera3D.new()
		add_child(view)
		var guard_at: Vector3 = (middle_window["middle"] as Vector3) + normal * 6.0
		guard_at.y = QUAY
		guard.global_position = guard_at
		await _frames(2)
		var guard_eye: Vector3 = guard.call("eye_position")
		view.global_position = (middle_window["middle"] as Vector3) + ((middle_window["middle"] as Vector3) - guard_eye).normalized() * (float(middle_window["inside"]) + 1.5)
		await _frames(1)
		var walled_glass: bool = hud.call("_walled_off", view, guard)
		# (Both moved along the wall: the line now through the stone between
		# two windows.)
		guard.global_position = guard_at + along
		view.global_position += along
		await _frames(2)
		var walled_stone: bool = hud.call("_walled_off", view, guard)
		view.queue_free()
		_check("GW22 your marks: a guard watching through the glass is not behind a wall; one behind the stone is", not walled_glass and walled_stone,
			"through the glass walled %s, behind the stone walled %s" % [walled_glass, walled_stone])

		# A thing thrown at the glass from inside stays in.
		var body := RigidBody3D.new()
		body.mass = 2.0
		body.collision_layer = 1
		body.collision_mask = 1
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3.ONE * 0.2
		body.add_child(shape)
		add_child(body)
		body.global_position = (middle_window["middle"] as Vector3) - normal * (float(middle_window["inside"]) + 0.5)
		body.linear_velocity = normal * 6.0
		await _seconds(1.0)
		var kept_in := (body.global_position - (middle_window["middle"] as Vector3)).dot(normal) < 0.0
		body.queue_free()

		# You, walking and jumping at a west window of the hall, stay in.
		var player: CharacterBody3D = city.player
		var west := all.filter(func(w): return (w["normal"] as Vector3).x < -0.9 and w["room"] == "room_customs_hall")
		var stayed := false

		if not west.is_empty():
			var ww: Dictionary = west[0]
			var n: Vector3 = ww["normal"]
			var at: Vector3 = (ww["middle"] as Vector3) - n * 1.0
			at.y = QUAY + 0.05
			player.movement_state = player.MoveState.LOCOMOTION
			player.current_move = null
			player.velocity = Vector3.ZERO
			player.global_position = at
			player.rotation.y = atan2(-n.x, -n.z)
			player.reset_physics_interpolation()
			Input.action_press("move_forward")

			for i in 120:
				if i % 20 == 0:
					Input.action_press("jump")
				elif i % 20 == 5:
					Input.action_release("jump")

				await get_tree().physics_frame

			Input.action_release("move_forward")
			Input.action_release("jump")
			stayed = (player.global_position - (ww["middle"] as Vector3)).dot(n) < 0.0

		_check("GW16 a thing thrown at a window from inside stays in; so do you, walking and jumping at a hall window", kept_in and stayed,
			"thrown thing in %s, you in %s (west windows %d)" % [kept_in, stayed, west.size()])

	# The office's candle out through its window, doused and relit.
	var made: Dictionary = city.made["city_harbour"]
	var candle: Node3D = made["lights"].get("office_candle")
	var office := all.filter(func(w): return w["room"] == "room_customs_office")
	var spot_of := func(w: Dictionary) -> float: return (w["spot"] as SpotLight3D).light_energy if w["spot"] != null and is_instance_valid(w["spot"]) else 0.0
	var outside := office.size() == 1 and office[0]["spot"] != null and (office[0]["spot"] as Node3D).global_position.z < -34.0
	var notes := ["office windows %d, spot outside %s, shaft %s" % [office.size(), outside, office.size() == 1 and office[0]["lamp_shaft"] != null]]
	var follows := false
	var remembered := false

	if candle != null and office.size() == 1:
		await _until(func(): return spot_of.call(office[0]) > 0.05, 60)
		var lit_first: bool = spot_of.call(office[0]) > 0.05
		candle.call("put_out", &"douse")
		await _until(func(): return spot_of.call(office[0]) < 0.01, 30)
		var doused: bool = spot_of.call(office[0]) < 0.01
		candle.call("relight")
		await _until(func(): return spot_of.call(office[0]) > 0.05, 30)
		var relit: bool = spot_of.call(office[0]) > 0.05
		follows = lit_first and doused and relit
		notes.append("lit %s, doused %s, relit %s" % [lit_first, doused, relit])

		# As a district remembers it.
		candle.call("load_state", {"lit": false})
		await _until(func(): return spot_of.call(office[0]) < 0.01, 30)
		var out_again: bool = spot_of.call(office[0]) < 0.01
		candle.call("load_state", {"lit": true})
		await _until(func(): return spot_of.call(office[0]) > 0.05, 30)
		remembered = out_again and spot_of.call(office[0]) > 0.05

	_check("GW17 the office's candle throws its window out onto the yard; doused, dark; relit, back", outside and follows and office[0]["lamp_shaft"] != null,
		"; ".join(notes))
	_check("GW20 a district's remembered candle (load_state) darkens and lights its window", remembered, "remembered %s" % remembered)

	# The cabin's lamps astern and onto the waist.
	var cabin := all.filter(func(w): return w["room"] == "room_carrack_cabin")
	var astern := cabin.filter(func(w): return w["spot"] != null and (w["spot"] as Node3D).global_position.x < CARRACK_X + STERN)
	var waist := cabin.filter(func(w): return w["spot"] != null and (w["spot"] as Node3D).global_position.x > CARRACK_X + CASTLE_FRONT)
	_check("GW18 the cabin's lamps throw out through its four windows: two astern, two onto the waist", cabin.size() == 4 and astern.size() == 2
		and waist.size() == 2, "cabin windows %d, astern %d, waist %d" % [cabin.size(), astern.size(), waist.size()])

	# Under a roof, in a shaft: casting again.
	var shafts: Array[AABB] = []

	for w in all:
		if w["shaft"] != null:
			shafts.append((w["shaft"] as MeshInstance3D).global_transform * (w["shaft"] as MeshInstance3D).get_aabb())

	var left_out := 0

	for node in level.root.find_children("*", "GeometryInstance3D", true, false):
		var mesh := node as GeometryInstance3D

		if mesh.layers == Layers.ROOFED and shafts.any(func(b): return (b as AABB).intersects(mesh.global_transform * mesh.get_aabb())):
			left_out += 1

	var recast: Array = windows.get("recast")
	var all_in := recast.all(func(m): return shafts.any(func(b): return (b as AABB).intersects((m as GeometryInstance3D).global_transform * (m as GeometryInstance3D).get_aabb())))
	_check("GW19 nothing under a roof stands in a moon shaft without casting; what was made to cast stands in one", left_out == 0 and all_in,
		"recast %d, left under the roof in a shaft %d" % [recast.size(), left_out])
	city.queue_free()
	await _frames(2)


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
