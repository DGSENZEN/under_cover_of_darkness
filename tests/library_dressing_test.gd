extends Node3D
## The library's dressing (its rugs, what hangs in it): quick checks on the shop as it stands, headless with
## --fixed-fps 60. Kept apart from the library suite, whose walks and timings take minutes.

const LAB := preload("res://maps/library_lab.tscn")

var results: Array[String] = []
var failures := 0


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var lab: Node3D = LAB.instantiate()
	add_child(lab)
	for i in 5:
		await get_tree().process_frame
	_rugs(lab)
	await _hangings(lab)
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


func _rugs(lab: Node3D) -> void:
	# D1 his rugs (tools/textures/rugs.py): a Teotitlan rug down the left aisle, a Persian runner down the right, a
	#     petate under the front table, a folded sarape kneeling-mat before the cage; each lying on the boards, its own
	#     pattern, clear of the other rugs and the runner, the ward's chalk, the cases and his corner's things
	var r_rugs: Dictionary = lab.get("rugs") if lab.get("rugs") != null else {}
	var r_wrong := []
	var r_frame := lab.global_transform.affine_inverse()
	var r_boxes := {}
	for kind: String in r_rugs:
		var rug: MeshInstance3D = r_rugs[kind]
		var box: AABB = r_frame * (rug.global_transform * rug.get_aabb())
		r_boxes[kind] = box
		if absf(box.position.y) > 0.003 or box.end.y > 0.04:
			r_wrong.append("%s not on the boards (%.3f..%.3f)" % [kind, box.position.y, box.end.y])
		var look := rug.get_surface_override_material(0) as ShaderMaterial
		var picture: Texture2D = look.get_shader_parameter("atlas") if look != null else null
		if picture == null or not picture.resource_path.ends_with("rug_%s.png" % kind):
			r_wrong.append("%s not its pattern" % kind)
		var middle := Vector2(box.get_center().x, box.get_center().z)
		var nearest := Vector2(clampf(lab.CORNER_AT.x, box.position.x, box.end.x), clampf(lab.CORNER_AT.z, box.position.z, box.end.z))
		if nearest.distance_to(Vector2(lab.CORNER_AT.x, lab.CORNER_AT.z)) < lab.WARD_RADIUS + 0.05:
			r_wrong.append("%s on the ward" % kind)
		var runner: AABB = r_frame * (lab.room["room_rug"].global_transform * lab.room["room_rug"].get_aabb())
		if box.grow(-0.01).intersects(AABB(runner.position - Vector3(0, 1, 0), runner.size + Vector3(0, 2, 0))):
			r_wrong.append("%s on the runner" % kind)
		var solid: Array = lab.shelves.duplicate() + lab.CORNER_SOLID.map(func(n): return lab.corner.get(n)).filter(func(n): return n != null)
		for thing: MeshInstance3D in solid:
			var other: AABB = r_frame * (thing.global_transform * thing.get_aabb())
			if box.grow(-0.01).intersects(AABB(other.position - Vector3(0, 0.1, 0), other.size + Vector3(0, 0.2, 0))):
				r_wrong.append("%s under %s" % [kind, thing.name])
	var r_kinds := r_boxes.keys()
	for i in r_kinds.size():
		for j in range(i + 1, r_kinds.size()):
			if (r_boxes[r_kinds[i]] as AABB).grow(-0.005).intersects(r_boxes[r_kinds[j]]):
				r_wrong.append("%s on %s" % [r_kinds[i], r_kinds[j]])
	var r_table: bool = r_boxes.has("petate") and (r_boxes["petate"] as AABB).has_point(Vector3(lab.FRONT_TABLE_AT.x, 0.004, lab.FRONT_TABLE_AT.z))
	_check("D1 his rugs lie on the boards, each its own pattern, clear of each other, the runner, the ward, the cases and his corner; the front table on the petate",
		r_rugs.size() == 4 and r_wrong.is_empty() and r_table, "rugs %d wrong %s table on petate %s" % [r_rugs.size(), r_wrong.slice(0, 4), r_table])



## What hangs (tools/eclipse/library_hangings.py): the drying line, the herb rail, the milagros, the censer, the
## armillary; clear of a head where they hang over the floor, clear of the floating books' rings; the armillary turning.
func _hangings(lab: Node3D) -> void:
	var pieces: Dictionary = lab.get("hangings") if lab.get("hangings") != null else {}
	var frame := lab.global_transform.affine_inverse()
	var wrong := []
	for name: String in pieces:
		var piece: MeshInstance3D = pieces[name]
		var box: AABB = frame * (piece.global_transform * piece.get_aabb())
		var look := piece.get_surface_override_material(0) as ShaderMaterial
		var picture: Texture2D = look.get_shader_parameter("atlas") if look != null else null
		if picture == null or not picture.resource_path.contains("library_hangings"):
			wrong.append("%s unpainted" % name)
		if name in ["drying_line", "armillary"] and box.position.y < 2.1:
			wrong.append("%s down to %.2f m" % [name, box.position.y])
		# (The floating books' rings: each an ellipse round the vault's middle at its height.)
		for ring: Array in lab.floating.RINGS:
			for k in 48:
				var a := TAU * k / 48.0
				var at: Vector3 = lab.floating.MIDDLE + Vector3(ring[0] * cos(a), ring[2], ring[1] * sin(a))
				if box.grow(0.4).has_point(at):
					wrong.append("%s in a ring" % name)
					break
	_check("D2 what hangs: the drying line, rue on its rail, the milagros, the censer, the armillary; over the floor above a head, clear of the floating books",
		pieces.size() == 5 and wrong.is_empty(), "pieces %d wrong %s" % [pieces.size(), wrong.slice(0, 4)])

	var sphere: Node3D = lab.get("armillary")
	if sphere == null:
		_check("D3 the armillary turns slowly about its own middle", false, "no armillary")
		return
	# (Its middle: the kit's wick, in the shop's frame; where the sphere has it, as it turns.)
	var wick: Array = (JSON.parse_string(FileAccess.get_file_as_string(lab.HANGINGS_WICKS)) as Dictionary)["armillary"][0]
	var middle := lab.to_global(Vector3(wick[0], wick[1], wick[2]))
	var mesh: MeshInstance3D = lab.hangings["armillary"]
	var local := mesh.global_transform.affine_inverse() * middle
	var turned_from: float = sphere.rotation.y
	var drift := 0.0
	for i in 120:
		await get_tree().process_frame
		drift = maxf(drift, (mesh.global_transform * local).distance_to(middle))
	var turned := absf(angle_difference(turned_from, sphere.rotation.y))
	_check("D3 the armillary turns slowly about its own middle, with no draught",
		turned > 0.1 and turned < 0.5 and drift < 0.001 and sphere.global_position.distance_to(middle) < 0.001,
		"turned %.2f rad in 2 s, its middle moved %.3f m, pivot %.2f m off it" % [turned, drift,
		sphere.global_position.distance_to(middle)])


func _check(label: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1
