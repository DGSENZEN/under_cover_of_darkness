extends Node3D
## The Underground's look-dev bay (maps/underground_lab.tscn): the hero stall
## in a stretch of tiled corridor, painted in the bespoke blend, its neon and
## bulb lit, two sodium work lights, a neutral form light to judge shape (F2),
## grime decals (F3); the player can walk round its front.

const LAB := preload("res://maps/underground_lab.tscn")
const PARTS := ["stall_frame", "stall_counter", "stall_awning", "stall_shelves", "stall_clutter", "stall_ofrenda",
	"stall_neon"]

var results: Array[String] = []
var lab: Node3D


func _ready() -> void:
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	lab = LAB.instantiate()
	add_child(lab)
	await _frames(5)

	# U1 the stall, all its parts
	var meshes := {}

	if lab.stall != null:
		for mesh: MeshInstance3D in lab.stall.find_children("*", "MeshInstance3D", true, false):
			meshes[String(mesh.name)] = mesh

	var have := PARTS.filter(func(p): return meshes.has(p))
	_check("U1 the stall stands in the bay with all seven of its parts", have.size() == PARTS.size() and lab.missing.is_empty(),
		"parts %s missing %s" % [have, lab.missing])

	# U2 its painted parts in the bespoke blend (the atlas's colour whole)
	var painted := 0
	var wrong := []

	for part in ["stall_frame", "stall_counter", "stall_awning", "stall_shelves"]:
		var mesh: MeshInstance3D = meshes.get(part)

		if mesh == null:
			wrong.append(part)
			continue

		for i in mesh.mesh.get_surface_count():
			var m: Material = mesh.get_surface_override_material(i)

			if m is ShaderMaterial and is_equal_approx(m.get_shader_parameter("paint_mix"), 0.0) \
					and m.get_shader_parameter("atlas") != null:
				painted += 1
			else:
				wrong.append("%s/%d" % [part, i])

	_check("U2 the stall's painted parts wear its atlas in the bespoke blend", painted > 0 and wrong.is_empty(),
		"painted %d wrong %s" % [painted, wrong])

	# U3 its neon glows and flickers
	var levels := {}

	if lab.neon != null:
		for i in 120:
			await get_tree().physics_frame
			levels[snappedf(lab.neon.light.light_energy, 0.001)] = true

	_check("U3 the neon sign glows from its own tube and flickers", lab.neon != null and lab.neon.tube != null
		and lab.neon.tube.name == "stall_neon" and levels.size() >= 2, "levels %s" % [levels.keys()])

	# U4 the corridor is lit by its two sodium work lights and the stall's bulb
	var lit: Array = lab.work_lights.filter(func(l): return l.visible and l.light_energy > 0.0)
	_check("U4 two sodium work lights and the stall's bulb light the corridor",
		lit.size() == 2 and lab.bulb != null and lab.bulb.light_energy > 0.0, "work %d bulb %s" % [lit.size(), lab.bulb])

	# U5 the player walks past its whole front without catching on anything unseen
	var walk := await _walk(Vector3(-2.6, 1.05, 1.0), -PI / 2, func(p): return p.x > 2.6, 600)
	_check("U5 the player walks the stall's whole front without snagging", walk["ok"] and walk["stall"] < 20,
		"%s" % [walk])

	# U6 F2 the form light: neutral grey on everything, one white light; and back
	lab.set_form(true)
	await _frames(2)
	var grey: bool = meshes.values().all(func(m): return m.material_override == lab.form_material)
	var form_on: bool = grey and lab.form_light.visible and lab.work_lights.all(func(l): return not l.visible)
	lab.set_form(false)
	await _frames(2)
	var back: bool = meshes.values().all(func(m): return m.material_override == null or m == lab.neon.tube) \
		and lab.neon.tube.material_override == lab.neon.tube_material() and not lab.form_light.visible
	_check("U6 F2 turns the bay to a neutral grey under a white form light, and back", form_on and back,
		"grey %s on %s back %s" % [grey, form_on, back])

	# U7 three grime decals, F3 hides and shows them
	var decals: Array = lab.decals
	lab.set_decals(false)
	var hidden: bool = decals.all(func(d): return not d.visible)
	lab.set_decals(true)
	_check("U7 three grime decals (drip, soot, grime), F3 turns them off and on",
		decals.size() == 3 and hidden and decals.all(func(d): return d.visible and d.texture_albedo != null),
		"%d decals, hidden %s" % [decals.size(), hidden])

	# U8 no pixel grid
	var retro: Node = get_node_or_null("/root/Retro")
	_check("U8 the pixel grid is off", retro != null and retro.virtual_height == 0, "%s" % [retro.virtual_height if retro else null])

	# U9 the bay needs only what is committed: the painted atlas, never the brush sheets
	var source := FileAccess.get_file_as_string("res://maps/underground_lab.gd")
	_check("U9 the bay reads the committed painted atlas, not the user's local brush sheets",
		not source.contains("textures/brushes") and FileAccess.file_exists(lab.atlas_dir + "stall_base.png"),
		"atlas dir %s" % lab.atlas_dir)


func _walk(start: Vector3, yaw: float, done: Callable, frames: int) -> Dictionary:
	var player: CharacterBody3D = lab.player
	player.global_position = start
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	await _frames(10)
	Input.action_press("move_forward")
	var stall := 0
	var still := 0
	var last := player.global_position
	var arrived := false

	for i in frames:
		await get_tree().physics_frame
		still = still + 1 if player.global_position.distance_to(last) < 0.005 else 0
		stall = maxi(stall, still)
		last = player.global_position

		if done.call(player.global_position):
			arrived = true
			break

	Input.action_release("move_forward")
	await _frames(10)
	return {"ok": arrived, "end": player.global_position, "stall": stall}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
