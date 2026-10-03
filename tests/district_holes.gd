extends Node3D
## A district's holes (plan B1a): its levels and the massing loaded as its
## map loads them, then a ray down every COLUMN m over its bounds and MARGIN
## m round them, against its colliders and against what is drawn (the
## visible meshes as trimesh bodies of their own, cards and cloth and glass
## and plants left out). Two faults: a column with no ground at all, and one
## where something drawn stands DRAWN_OVER or more over the first collider
## under it (a floor you would fall through, a top drawn with nothing to
## stand on under it). Prints the verdict ("HOLES ...") and writes the
## faulty columns to --out/holes.json.
##   Godot --headless --path . res://tests/district_holes.tscn -- --district=old_town [--out=/tmp/holes] [--margin=30] [--column=2]

const Districts := preload("res://scripts/Level/Districts.gd")
const LevelLoader := preload("res://scripts/Level/LevelLoader.gd")
const LevelGameplay := preload("res://scripts/Level/LevelGameplay.gd")
const LEVELS_DIR := "res://assets/level"
const MASSING := "city_massing"
const VIS := 1 << 20
const TOP := 260.0
const BOTTOM := -140.0
const DRAWN_OVER := 0.5
## Drawn things that are not stood on: cards, cloth, glass, ironwork,
## plants, lights, effects, water.
const SKIP := ["grass", "weed", "reed", "ivy", "leaf", "leaves", "needle", "twig", "net", "rope", "wash", "laundry", "glass", "water",
	"banner", "sail", "smoke", "flame", "fern", "gorse", "fennel", "moss", "straw", "decal", "stain", "light", "lamp", "glow", "rail",
	"grille", "lattice", "casement", "sash", "cypress", "pine", "palm", "agave", "orange", "bark", "cloth", "proxy", "shutters",
	"door_", "pitch", "iron"]

var district := "old_town"
var out := "/tmp/holes"
var margin := 30.0
var column := 2.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--district="):
			district = arg.trim_prefix("--district=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--margin="):
			margin = float(arg.trim_prefix("--margin="))
		elif arg.begins_with("--column="):
			column = float(arg.trim_prefix("--column="))

	DirAccess.make_dir_recursive_absolute(out)
	var entry: Dictionary = Districts.entry(StringName(district))
	var own: Array = []

	for level in entry.get("levels", []):
		var loaded = LevelLoader.load_level(self, LEVELS_DIR.path_join(String(level)), String(level))
		LevelGameplay.build_all(self, loaded)
		own.append(loaded.root)

	var skip: Array = [entry["massing"]] if String(entry.get("massing", "")) != "" else []
	var massing = LevelLoader.load_level(self, LEVELS_DIR.path_join(MASSING), MASSING, skip)
	LevelGameplay.build_all(self, massing)
	var bounds := _bounds(own)
	print("holes: %s over x %.0f..%.0f z %.0f..%.0f (and %.0f m round)" % [district, bounds.position.x, bounds.end.x, bounds.position.z,
		bounds.end.z, margin])
	var made := _visual_bodies()

	for i in 4:
		await get_tree().physics_frame

	var space := get_world_3d().direct_space_state
	var none: Array = []
	var drawn: Array = []
	var count := 0
	var x := bounds.position.x - margin

	while x <= bounds.end.x + margin:
		var z := bounds.position.z - margin

		while z <= bounds.end.z + margin:
			var at := Vector3(x, TOP, z)
			var solid := _down(space, at, 1)
			var seen := _down(space, at, VIS)
			count += 1

			if is_nan(solid):
				none.append([snappedf(x, 0.1), snappedf(z, 0.1)])
			elif not is_nan(seen) and seen > solid + DRAWN_OVER:
				drawn.append([snappedf(x, 0.1), snappedf(z, 0.1), snappedf(seen, 0.01), snappedf(solid, 0.01)])

			z += column

		x += column

	var f := FileAccess.open(out.path_join("holes.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"district": district, "columns": count, "visual_bodies": made, "none": none, "drawn": drawn}))
	f.close()
	print("HOLES %s: %d columns, %d with no ground, %d drawn over nothing" % [district, count, none.size(), drawn.size()])
	get_tree().quit()


## The district's own meshes' bounds (its levels', not the massing's).
func _bounds(roots: Array) -> AABB:
	var box := AABB()
	var first := true

	for root in roots:
		for node in (root as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D

			if mi.mesh == null:
				continue

			var b := mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false

	return box


func _down(space: PhysicsDirectSpaceState3D, at: Vector3, mask: int) -> float:
	var q := PhysicsRayQueryParameters3D.create(at, Vector3(at.x, BOTTOM, at.z), mask)
	var hit := space.intersect_ray(q)
	return NAN if hit.is_empty() else float(hit["position"].y)


## Every visible mesh's triangles as a trimesh body on VIS (the SKIP words'
## surfaces left out).
func _visual_bodies() -> int:
	var made := 0

	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_node as MeshInstance3D

		if mi.mesh == null or not mi.is_visible_in_tree():
			continue

		var faces := PackedVector3Array()
		var xf := mi.global_transform

		for s in mi.mesh.get_surface_count():
			var material := mi.mesh.surface_get_material(s)
			var slot := material.resource_name.to_lower() if material != null else ""
			var skip := false

			for word in SKIP:
				if slot.contains(word):
					skip = true
					break

			if skip or (mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES):
				continue

			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

			if index.is_empty():
				for v in verts:
					faces.append(xf * v)
			else:
				for i in index:
					faces.append(xf * verts[i])

		if faces.is_empty():
			continue

		var body := StaticBody3D.new()
		body.collision_layer = VIS
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var concave := ConcavePolygonShape3D.new()
		concave.backface_collision = true
		concave.set_faces(faces)
		shape.shape = concave
		body.add_child(shape)
		add_child(body)
		made += 1

	return made
