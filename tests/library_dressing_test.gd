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



func _check(label: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1
