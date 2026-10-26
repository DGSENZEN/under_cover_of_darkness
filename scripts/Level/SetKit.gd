class_name SetKit
## What a set builds its pieces with (maps/pasaje.gd; the same as maps/underground_lab.gd's own helpers): a kit's
## meshes by name, a piece placed and made solid, a painted atlas, the clear glass of a glazed slot.

const ATLAS_DIR := "res://textures/painted/underground/"


## A kit's meshes by name.
static func kit(path: String) -> Dictionary:
	var meshes := {}
	var built: Node3D = (load(path) as PackedScene).instantiate()
	for mesh: MeshInstance3D in built.find_children("*", "MeshInstance3D", true, false):
		meshes[String(mesh.name)] = mesh.mesh
	built.free()
	return meshes


## A kit piece set under `parent` at `at`, turned `yaw` about the vertical, solid if asked (its convex hull, or its
## own faces if `concave`: what stands open under it stays open); its glazed slots clear glass, the rest `material`.
static func place(parent: Node3D, mesh: Mesh, material: Material, kind: String, at: Vector3, yaw: float,
		solid: bool, concave := false) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = kind
	piece.mesh = mesh
	piece.set_meta("kind", kind)
	for i in mesh.get_surface_count():
		var slot: Material = mesh.surface_get_material(i)
		var glazed := slot != null and slot.resource_name.begins_with("glass")
		piece.set_surface_override_material(i, glass() if glazed else material)
	parent.add_child(piece, true)
	piece.position = at
	piece.rotation.y = yaw
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape() if concave else mesh.create_convex_shape()
		body.add_child(shape)
		piece.add_child(body)
	return piece


## The first of `names` painted (imported, or read from disk if not imported yet), or null.
static func painted(names: Array, atlas_dir := ATLAS_DIR, alpha := false) -> Texture2D:
	for file in names:
		var path: String = atlas_dir + file
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			image.convert(Image.FORMAT_RGBA8 if alpha else Image.FORMAT_RGB8)
			image.generate_mipmaps()
			return ImageTexture.create_from_image(image)
	return null


## Clear glass, as the bay's.
static func glass() -> StandardMaterial3D:
	var clear := StandardMaterial3D.new()
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	clear.albedo_color = Color(0.66, 0.78, 0.74, 0.32)
	clear.roughness = 0.1
	clear.metallic_specular = 0.8
	return clear
