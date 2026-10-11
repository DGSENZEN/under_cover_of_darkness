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
## The Company's lit lamps: their globes glow in the light's colour at night.
const LIT := {"tram_pole_lamp": Color("#e8d8a8"), "ward_cage_lamp": Color("#CFE8F0")}
const LAMP_ENERGY := 1.6
const GLOW := 2.5
const FOLIAGE := preload("res://scripts/Visual/foliage.gdshader")
const Materials := preload("res://scripts/Visual/Materials.gd")
const PAINTED := "res://textures/painted/"
## Leaf and washing cards (tools/eclipse/common.Mesh.card): each slot's own
## painting cut out, its rustle (m), whether it hangs from its top edge
## (washing on a line), and whether it rides its tree's sway.
const CARDS := {
	"leaf_crown": [0.06, false, true], "palm_frond": [0.09, false, true], "willow": [0.12, true, true],
	"laurel": [0.04, false, true], "twigs": [0.04, false, true], "laundry": [0.14, true, false],
}
## Kits whose pieces are trees: their bark bends in the wind with their
## leaves (sway.gdshaderinc), this far (m) for each square metre of height.
const TREE_SWAY := 0.006
const TREES := {"trees_kit": TREE_SWAY}

## The lamps' lights and their glowing globes, switched by night and day.
var lights: Array[OmniLight3D] = []
var globes: Array[StandardMaterial3D] = []

static var _materials := {}
static var _cards := {}
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
		multi.mesh = out._dressed(g["kit"], g["piece"], mesh)
		multi.instance_count = g["transforms"].size()

		for i in multi.instance_count:
			multi.set_instance_transform(i, g["transforms"][i])

		var draw := MultiMeshInstance3D.new()
		draw.name = key.replace("/", "_")
		draw.multimesh = multi
		draw.set_meta("piece", g["piece"])
		out.add_child(draw)

	var lamps := Node3D.new()
	lamps.name = "lights"
	out.add_child(lamps)

	for l in dressing.get("lights", []):
		var light := OmniLight3D.new()
		light.light_color = Color(l["colour"])
		light.omni_range = l["range"]
		light.light_energy = LAMP_ENERGY
		light.shadow_enabled = l.get("shadow", false)
		light.position = Vector3(l["at"][0], l["at"][1], l["at"][2])
		light.visible = false
		lamps.add_child(light)
		out.lights.append(light)

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


## The Company's lamps lit (night) or out (day): their lights and globes.
func set_lights(on: bool) -> void:
	for light in lights:
		light.visible = on

	for glass in globes:
		glass.emission_energy_multiplier = GLOW if on else 0.0


## A piece's mesh as the kit draws it: each surface in the kit's painterly
## material, but glass as glass (a lit lamp's globe glowing in its colour).
func _dressed(kit: String, piece: String, mesh: Mesh) -> Mesh:
	var out: Mesh = mesh.duplicate()

	for i in out.get_surface_count():
		var slot: Material = mesh.surface_get_material(i)

		if slot != null and CARDS.has(slot.resource_name):
			out.surface_set_material(i, card_material(slot.resource_name))
		elif slot != null and slot.resource_name == "glass":
			var glass := StandardMaterial3D.new()
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.albedo_color = Color(0.72, 0.8, 0.82, 0.35)
			glass.roughness = 0.15

			if LIT.has(piece):
				glass.albedo_color = Color(LIT[piece], 0.6)
				glass.emission_enabled = true
				glass.emission = LIT[piece]
				glass.emission_energy_multiplier = 0.0
				globes.append(glass)

			out.surface_set_material(i, glass)
		else:
			out.surface_set_material(i, material(kit))

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


## A card slot's material (foliage.gdshader): its painting cut out, swaying
## in the wind (Materials.blow), one shared for every kit.
static func card_material(slot: String) -> ShaderMaterial:
	if not _cards.has(slot):
		var m := ShaderMaterial.new()
		m.shader = FOLIAGE
		m.set_shader_parameter(&"albedo_texture", load(PAINTED + slot + ".png"))
		m.set_shader_parameter(&"rustle", float(CARDS[slot][0]))
		m.set_shader_parameter(&"bough", 0.0)
		m.set_shader_parameter(&"hanging", bool(CARDS[slot][1]))
		m.set_shader_parameter(&"tree", TREE_SWAY if CARDS[slot][2] else 0.0)
		m.set_shader_parameter(&"wind", Vector3(0.6, 0.0, 0.6))
		m.set_shader_parameter(&"vertex_colour", false)
		Materials.swaying.append(m)
		_cards[slot] = m

	return _cards[slot]


## A kit's material in the shader-led blend, its vertex paint on.
static func material(kit: String) -> ShaderMaterial:
	if not _materials.has(kit):
		var m := Painterly.material(atlas(kit, ""), &"shader_led", Painterly.ZOCALO, atlas(kit, "_normal"),
			atlas(kit, "_under"), atlas(kit, "_under_normal"))
		m.set_shader_parameter("vertex_paint", 1.0)

		if TREES.has(kit):
			m.set_shader_parameter("tree", float(TREES[kit]))
			Materials.swaying.append(m)

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
