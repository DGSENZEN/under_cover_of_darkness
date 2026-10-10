class_name KitLoader
extends Node3D
## A district's kit pieces (tools/eclipse/<kit>.py, exported to
## assets/eclipse/kit/<kit>.glb) brought into Godot: each piece's mesh by
## its object's name, each kit's painterly material from its painted atlas
## (the user's overpaint first), its vertex paint turned on.

const Painterly := preload("res://scripts/Visual/Painterly.gd")
const KITS := "res://assets/eclipse/kit/"
const ATLASES := "res://textures/painted/eclipse/"

## Pieces are drawn together within cells this wide (m), so the camera can
## leave out what it does not see.
const CELL := 100.0

static var _materials := {}
static var _meshes := {}
static var _shapes := {}


## A district's dressing (tools/level/dress.py's dressing.json): each piece
## kind drawn as one MultiMesh a cell, the colliders it lists as boxes, and
## the pieces it marks solid as their own mesh.
static func build(dressing: Dictionary) -> KitLoader:
	var out := KitLoader.new()
	out.name = "kit"
	var groups := {}

	for p in dressing["pieces"]:
		var at := Vector3(p["at"][0], p["at"][1], p["at"][2])
		var key := "%s/%s/%d/%d" % [p["kit"], p["piece"], floori(at.x / CELL), floori(at.z / CELL)]
		var basis := Basis(Vector3.UP, deg_to_rad(p["yaw"])) * Basis.from_scale(Vector3(p.get("stretch", 1.0), 1, 1))

		if not groups.has(key):
			groups[key] = {"kit": p["kit"], "piece": p["piece"], "transforms": []}

		groups[key]["transforms"].append(Transform3D(basis, at))

		if p.get("collider", "") == "mesh":
			out._solid(p["kit"], p["piece"], Transform3D(basis, at))

	for key in groups:
		var g: Dictionary = groups[key]
		var mesh: Mesh = meshes(g["kit"]).get(g["piece"])

		if mesh == null:
			push_warning("KitLoader: %s has no %s" % [g["kit"], g["piece"]])
			continue

		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = g["transforms"].size()

		for i in multi.instance_count:
			multi.set_instance_transform(i, g["transforms"][i])

		var draw := MultiMeshInstance3D.new()
		draw.name = key.replace("/", "_")
		draw.multimesh = multi
		draw.material_override = material(g["kit"])
		draw.set_meta("piece", g["piece"])
		out.add_child(draw)

	var body := StaticBody3D.new()
	body.name = "colliders"
	out.add_child(body)

	for c in dressing["colliders"]:
		var b: Array = c["box"]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(b[3], b[4], b[5])
		shape.shape = box
		shape.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(c["yaw"])), Vector3(b[0], b[1], b[2]))
		body.add_child(shape)

	return out


func _solid(kit: String, piece: String, at: Transform3D) -> void:
	var key := kit + "/" + piece

	if not _shapes.has(key):
		_shapes[key] = (meshes(kit)[piece] as Mesh).create_trimesh_shape()

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = _shapes[key]
	body.add_child(shape)
	body.transform = at
	add_child(body)


## Every piece's mesh in a kit, by name.
static func meshes(kit: String) -> Dictionary:
	if not _meshes.has(kit):
		var out := {}
		var scene: Node = (load(KITS + kit + ".glb") as PackedScene).instantiate()

		for m: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			out[String(m.name)] = m.mesh

		scene.free()
		_meshes[kit] = out

	return _meshes[kit]


## A kit's material in the shader-led blend, its vertex paint on.
static func material(kit: String) -> ShaderMaterial:
	if not _materials.has(kit):
		var m := Painterly.material(atlas(kit, ""), &"shader_led", Painterly.ZOCALO, atlas(kit, "_normal"),
			atlas(kit, "_under"), atlas(kit, "_under_normal"))
		m.set_shader_parameter("vertex_paint", 1.0)
		_materials[kit] = m

	return _materials[kit]


## A kit's painted texture: the user's overpaint (<kit><suffix>.png), else
## the painter's (<kit><suffix>_base.png); the under layers have only the one.
static func atlas(kit: String, suffix: String) -> Texture2D:
	var names := [kit + suffix + ".png"]

	if suffix in ["", "_normal"]:
		names.append(kit + suffix + "_base.png")

	for file in names:
		var path: String = ATLASES + file

		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			image.convert(Image.FORMAT_RGB8)
			image.generate_mipmaps(suffix.ends_with("normal"))
			return ImageTexture.create_from_image(image)

	push_warning("KitLoader: none of %s in %s" % [names, ATLASES])
	return null
