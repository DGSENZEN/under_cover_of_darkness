class_name KitLoader
extends Node3D
## A district's kit pieces (tools/eclipse/<kit>.py, exported to
## assets/eclipse/kit/<kit>.glb) brought into Godot: each piece's mesh by
## its object's name, each kit's painterly material from its painted atlas
## (the user's overpaint first), its vertex paint turned on.

const Painterly := preload("res://scripts/Visual/Painterly.gd")
const KITS := "res://assets/eclipse/kit/"
const ATLASES := "res://textures/painted/eclipse/"

static var _materials := {}
static var _meshes := {}


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
