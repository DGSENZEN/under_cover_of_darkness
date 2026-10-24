extends Node3D
## The corridor bay at any length (docs/superpowers/plans/2026-10-23-candle-lane.md, Task 2): headless with --fixed-fps
## 60. B1 holds the bay at its own length to every piece where it stood (tests/fixtures/bay_pieces.json, captured with
## -- --capture from the bay before it learnt any length); B2 builds it longer, its pieces from its table.

const BAY := preload("res://maps/underground_lab.tscn")
const FIXTURE := "res://tests/fixtures/bay_pieces.json"

var results: Array[String] = []
var failures := 0


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var bay: Node3D = BAY.instantiate()
	add_child(bay)
	for i in 5:
		await get_tree().process_frame
	var pieces := _pieces(bay)
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://tests/fixtures")
		var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
		file.store_string(JSON.stringify(pieces, "\t"))
		file.close()
		print("captured %d pieces" % pieces.size())
		get_tree().quit()
		return

	var was: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var moved := []
	for name: String in was:
		if not pieces.has(name):
			moved.append("%s gone" % name)
			continue
		var a: Array = was[name]
		var b: Array = pieces[name]
		for i in a.size():
			if absf(float(a[i]) - float(b[i])) > 0.001:
				moved.append(name)
				break
	for name: String in pieces:
		if not was.has(name):
			moved.append("%s new" % name)
	_check("B1 the bay at its own length builds every piece where it stood", moved.is_empty() and was.size() > 50,
		"%d pieces, moved %s" % [was.size(), moved.slice(0, 5)])
	bay.queue_free()
	await get_tree().process_frame

	var long: Node3D = BAY.instantiate()
	long.set("half_run", 16.8)
	var places = long.get("places")
	if places is Dictionary:
		places["cart"] = Vector3(-3.5, 0.0, 2.6)
	add_child(long)
	for i in 5:
		await get_tree().process_frame
	var floor_mesh: MeshInstance3D = long.get_node_or_null("floor")
	var length := floor_mesh.get_aabb().size.x if floor_mesh != null else 0.0
	var cart: Node3D = long.get_node_or_null("tamale_cart")
	_check("B2 the bay's length and places are settable: 33.6 m long, its cart where its table puts it",
		places is Dictionary and is_equal_approx(length, 33.6) and cart != null and cart.position.distance_to(Vector3(-3.5, 0.0, 2.6)) < 0.001,
		"length %.2f cart %s" % [length, cart.position if cart != null else null])

	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


## Every mesh the bay sets down as a piece (its own children), by name: its global transform's twelve numbers.
func _pieces(bay: Node3D) -> Dictionary:
	var out := {}
	for child in bay.get_children():
		if child is MeshInstance3D or child is MultiMeshInstance3D:
			var t: Transform3D = (child as Node3D).global_transform
			out[String(child.name)] = [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
				t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]
	return out


func _check(label: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1
