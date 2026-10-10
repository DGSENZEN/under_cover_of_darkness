extends Node3D
## The kit's vertex paint survives Godot's glTF import (the vertex-paint
## plan, Task 4), headless:
##   Godot --headless --path . res://tests/vertex_colour_import.tscn
## The Blender build writes one mid-grey corner's place, facing and RGBA to
## assets/eclipse/source/kiosk_probe.json; the imported mesh must carry that
## colour there, read either as linear or as sRGB (which one tells the
## painterly shader whether to convert: Painterly.VERTEX_COLOUR_SRGB).

const Painterly := preload("res://scripts/Visual/Painterly.gd")
const PROBE := "res://assets/eclipse/source/kiosk_probe.json"
const PIECE := "res://assets/eclipse/lab/kiosk.glb"
const TOLERANCE := 2.0 / 255.0

var results: Array[String] = []


func _ready() -> void:
	var probe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROBE))
	var scene: Node = (load(PIECE) as PackedScene).instantiate()
	var holder := scene.find_child(probe["object"], true, false)
	var mesh: Mesh = null

	for node in [holder] + (holder.find_children("*", "MeshInstance3D", true, false) if holder else []):
		if node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
			break

	var arrays: Array = mesh.surface_get_arrays(0) if mesh else []
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays.size() > 0 and arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	_check("V1 the imported kit mesh has vertex colours", colours.size() > 0, "%d colours" % colours.size())

	var want := Color(probe["rgba"][0], probe["rgba"][1], probe["rgba"][2], probe["rgba"][3])
	var at := Vector3(probe["position"][0], probe["position"][1], probe["position"][2])
	var facing := Vector3(probe["normal"][0], probe["normal"][1], probe["normal"][2])
	var got := Color(-1, -1, -1)
	var best := INF

	for s in mesh.get_surface_count() if mesh else 0:
		var a: Array = mesh.surface_get_arrays(s)

		if a[Mesh.ARRAY_COLOR] == null:
			continue

		var points: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]

		for i in points.size():
			var d := points[i].distance_to(at)

			if d < best and normals[i].dot(facing) > 0.99:
				best = d
				got = (a[Mesh.ARRAY_COLOR] as PackedColorArray)[i]

	var linear := _near(got, want)
	var srgb := _near(got.srgb_to_linear(), want)
	# ...in the colour space the painterly shader is told it comes in.
	_check("V2 the probe corner keeps its colour, in the space Painterly expects",
		best < 1e-3 and (linear or srgb) and (srgb and not linear) == Painterly.VERTEX_COLOUR_SRGB,
		"got %s want %s at %.4f m; as linear %s, as sRGB %s" % [got, want, best, linear, srgb])
	print("VERTEX_COLOUR_SRGB ", srgb and not linear)
	scene.free()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= TOLERANCE and absf(a.g - b.g) <= TOLERANCE and absf(a.b - b.b) <= TOLERANCE \
		and absf(a.a - b.a) <= TOLERANCE


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
