extends RefCounted
## One shared material per surface slot of a prop ("iron", "wax", "stone"
## ...): the slot's PS2 photo when it is on this machine, its flat colour
## when it is not. Either way the model's baked vertex colour (ambient
## occlusion, grime, soot) multiplies in, so a fresh clone without the photos
## still reads as shaded, grimy iron.
##
## The photos are converted by tools/textures/ps2ify.py into textures/ps2/,
## which is gitignored (textures.com's licence: the repository is public), so
## nothing here may assume they exist and nothing warns when they do not.
##
##   mesh.material_override = Materials.surface(&"iron")

## slot -> its photo (a name in `folder`, "" for none), flat colour and finish.
const SLOTS := {
	&"iron": {"photo": "rust_iron", "colour": Color("2A2826"), "metallic": 0.35, "roughness": 0.85},
	&"chain": {"photo": "chain", "colour": Color("33302C"), "metallic": 0.35, "roughness": 0.85},
	&"wood_old": {"photo": "wood_old", "colour": Color("4A3524"), "metallic": 0.0, "roughness": 0.85},
	&"bark": {"photo": "bark", "colour": Color("3D2E22"), "metallic": 0.0, "roughness": 0.85},
	&"stone": {"photo": "stone_rubble", "colour": Color("5E5A55"), "metallic": 0.0, "roughness": 0.85},
	&"ashlar": {"photo": "stone_ashlar", "colour": Color("6B665F"), "metallic": 0.0, "roughness": 0.85},
	&"pitch": {"photo": "", "colour": Color("17110D"), "metallic": 0.0, "roughness": 0.85},
	&"brass": {"photo": "", "colour": Color("8C6A35"), "metallic": 0.35, "roughness": 0.85},
	&"clay": {"photo": "", "colour": Color("8A5236"), "metallic": 0.0, "roughness": 0.85},
	&"wax": {"photo": "", "colour": Color("D9C9A3"), "metallic": 0.0, "roughness": 0.85},
	&"horn": {"photo": "", "colour": Color("C8964B"), "metallic": 0.0, "roughness": 0.85},
	&"char": {"photo": "", "colour": Color("1C1714"), "metallic": 0.0, "roughness": 0.85},
	&"coal": {"photo": "", "colour": Color("2B1A12"), "metallic": 0.0, "roughness": 0.85},
}

## A slot nobody knows is drawn this loud, so it is noticed.
const UNKNOWN := Color("FF00FF")

## Where the converted photos are (tests point it elsewhere).
static var folder := "res://textures/ps2/"
## slot -> photo name, filled from SLOTS on first use (tests may change one).
static var photo_names := {}

static var _surfaces := {}
static var _warned := {}


## The shared material for `slot`.
static func surface(slot: StringName) -> StandardMaterial3D:
	if _surfaces.has(slot):
		return _surfaces[slot]

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

	if SLOTS.has(slot):
		var entry: Dictionary = SLOTS[slot]
		var texture := photo(slot)
		material.metallic = entry["metallic"]
		material.roughness = entry["roughness"]

		if texture != null:
			material.albedo_texture = texture
		else:
			material.albedo_color = entry["colour"]
	else:
		material.albedo_color = UNKNOWN

		if not _warned.has(slot):
			_warned[slot] = true
			push_error("Materials: no slot called '%s'" % slot)

	_surfaces[slot] = material
	return material


## The slot's converted photo, or null when it is not on this machine.
static func photo(slot: StringName) -> Texture2D:
	var name := _photo_name(slot)

	if name.is_empty():
		return null

	var path := folder.path_join(name + ".png")

	if not ResourceLoader.exists(path):
		return null

	return load(path) as Texture2D


## The slots that have a photo named but not found (for the gallery's
## --verbose).
static func fallbacks() -> Array[StringName]:
	var missing: Array[StringName] = []

	for slot in SLOTS:
		if not _photo_name(slot).is_empty() and photo(slot) == null:
			missing.append(slot)

	return missing


static func clear_cache() -> void:
	_surfaces.clear()


static func _photo_name(slot: StringName) -> String:
	if photo_names.is_empty():
		for key in SLOTS:
			photo_names[key] = SLOTS[key]["photo"]

	var name = photo_names.get(slot, "")
	return "" if name == null else String(name)
