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
	&"bark": {"photo": "bark", "painted": true, "colour": Color("3D2E22"), "metallic": 0.0, "roughness": 0.85, "tile": 1.2},
	&"stone": {"photo": "stone_rubble", "colour": Color("5E5A55"), "metallic": 0.0, "roughness": 0.85, "tile": 2.0},
	&"ashlar": {"photo": "stone_ashlar", "colour": Color("6B665F"), "metallic": 0.0, "roughness": 0.85, "tile": 2.0},
	&"pitch": {"photo": "", "colour": Color("17110D"), "metallic": 0.0, "roughness": 0.85},
	&"brass": {"photo": "", "colour": Color("8C6A35"), "metallic": 0.35, "roughness": 0.85},
	&"clay": {"photo": "", "colour": Color("8A5236"), "metallic": 0.0, "roughness": 0.85},
	&"wax": {"photo": "", "colour": Color("D9C9A3"), "metallic": 0.0, "roughness": 0.85},
	&"horn": {"photo": "", "colour": Color("C8964B"), "metallic": 0.0, "roughness": 0.85},
	&"char": {"photo": "", "colour": Color("1C1714"), "metallic": 0.0, "roughness": 0.85},
	&"coal": {"photo": "", "colour": Color("2B1A12"), "metallic": 0.0, "roughness": 0.85},
	# The level kit's (tools/level): walls, floors, roofs, dressing. "tile":
	# drawn mapped to the world, one photo every so many metres (level_surface).
	&"plaster": {"photo": "plaster", "colour": Color("7A7163"), "metallic": 0.0, "roughness": 0.9, "tile": 2.5},
	&"plaster_damaged": {"photo": "plaster_damaged", "colour": Color("736A5C"), "metallic": 0.0, "roughness": 0.9, "tile": 2.5},
	&"timber": {"photo": "timber", "colour": Color("3E2C1E"), "metallic": 0.0, "roughness": 0.85, "tile": 1.5},
	# Dark oak: the frames on the plaster, joists, trusses.
	&"beam": {"photo": "beam", "colour": Color("2A1D14"), "metallic": 0.0, "roughness": 0.85, "tile": 1.5},
	&"cobble": {"photo": "cobble", "colour": Color("4E4B46"), "metallic": 0.0, "roughness": 0.9, "tile": 1.5},
	&"flagstone": {"photo": "flagstone", "colour": Color("5C5852"), "metallic": 0.0, "roughness": 0.9, "tile": 2.0},
	&"boards": {"photo": "boards", "colour": Color("4D3825"), "metallic": 0.0, "roughness": 0.85, "tile": 1.5},
	&"slate": {"photo": "slate", "colour": Color("2B2D33"), "metallic": 0.0, "roughness": 0.8, "tile": 1.5},
	&"roof_clay": {"photo": "roof_clay", "colour": Color("6A3A28"), "metallic": 0.0, "roughness": 0.85, "tile": 1.5},
	&"mud": {"photo": "mud", "colour": Color("3A2E20"), "metallic": 0.0, "roughness": 0.9, "tile": 3.0},
	&"gravel": {"photo": "gravel", "colour": Color("55514B"), "metallic": 0.0, "roughness": 0.95, "tile": 2.0},
	&"stone_moss": {"photo": "stone_moss", "colour": Color("4F5244"), "metallic": 0.0, "roughness": 0.9, "tile": 2.0},
	&"wood_studded": {"photo": "wood_studded", "colour": Color("3A2A1E"), "metallic": 0.0, "roughness": 0.85, "tile": 1.5},
	&"carpet": {"photo": "carpet", "painted": true, "colour": Color("5E1712"), "metallic": 0.0, "roughness": 0.95, "tile": 1.0},
	&"leaves": {"photo": "leaves", "colour": Color("1F2B16"), "metallic": 0.0, "roughness": 0.95, "cut": true},
	# Nature (tools/level/kit_nature; our own paintings): drawn in the
	# swaying foliage (level_surface): "sway" is [rustle, bough] (m: a
	# card's top edge; a bough, per metre over a man's height); "shadowless":
	# ground cover casts no shadow.
	&"leaf_crown": {"photo": "leaf_crown", "painted": true, "colour": Color("2E4420"), "metallic": 0.0, "roughness": 0.9, "cut": true, "sway": [0.06, 0.014]},
	&"leaf_shrub": {"photo": "leaf_shrub", "painted": true, "colour": Color("304A22"), "metallic": 0.0, "roughness": 0.9, "cut": true, "sway": [0.05, 0.0]},
	&"yew": {"photo": "yew", "painted": true, "colour": Color("1C2E1C"), "metallic": 0.0, "roughness": 0.9, "cut": true, "sway": [0.03, 0.006]},
	&"twigs": {"photo": "twigs", "painted": true, "colour": Color("3A322A"), "metallic": 0.0, "roughness": 0.9, "cut": true, "sway": [0.05, 0.01]},
	&"grass": {"photo": "grass", "colour": Color("2E3A20"), "metallic": 0.0, "roughness": 0.95, "tile": 3.0},
	&"grass_blades": {"photo": "grass", "painted": true, "colour": Color("4A5E2C"), "metallic": 0.0, "roughness": 0.9, "cut": true, "sway": [0.07, 0.0], "shadowless": true},
	&"weed_broad": {"photo": "weed_broad", "painted": true, "colour": Color("3E5A26"), "metallic": 0.0, "roughness": 0.9, "cut": true, "sway": [0.05, 0.0], "shadowless": true},
	&"reeds": {"photo": "reeds", "painted": true, "colour": Color("5E6634"), "metallic": 0.0, "roughness": 0.9, "cut": true, "sway": [0.14, 0.0], "shadowless": true},
	&"ivy": {"photo": "ivy", "painted": true, "colour": Color("22381E"), "metallic": 0.0, "roughness": 0.8, "cut": true, "sway": [0.012, 0.0], "shadowless": true},
	&"straw": {"photo": "", "colour": Color("8A7238"), "metallic": 0.0, "roughness": 0.95},
	&"cloth": {"photo": "", "colour": Color("6E1414"), "metallic": 0.0, "roughness": 0.95},
	# A window lit from within: glows its own colour whatever falls on it.
	&"glass_lit": {"photo": "", "colour": Color("FFB765"), "metallic": 0.0, "roughness": 0.4, "glow": 0.9},
	# Photos drawn on a piece's own face (its UVs): the chapel's glass, reliefs,
	# arcade and bands; shutters.
	&"stained_glass": {"photo": "stained_glass", "colour": Color("7A3A2A"), "metallic": 0.0, "roughness": 0.4, "glow": 0.75},
	&"stained_glass_small": {"photo": "stained_glass_small", "colour": Color("5E6A4A"), "metallic": 0.0, "roughness": 0.4, "glow": 0.6},
	&"relief_frieze": {"photo": "relief_frieze", "colour": Color("8C8170"), "metallic": 0.0, "roughness": 0.9},
	&"relief_angels": {"photo": "relief_angels", "colour": Color("8C8170"), "metallic": 0.0, "roughness": 0.9},
	&"arcade": {"photo": "arcade", "colour": Color("7C766C"), "metallic": 0.0, "roughness": 0.9},
	&"ornament": {"photo": "ornament", "colour": Color("7C766C"), "metallic": 0.0, "roughness": 0.9},
	&"shutters": {"photo": "shutters", "colour": Color("6A6458"), "metallic": 0.0, "roughness": 0.9},
	# Roofs laid along their slopes (their UVs: the rows along the eaves).
	&"roof_slate": {"photo": "slate", "colour": Color("2B2D33"), "metallic": 0.0, "roughness": 0.8},
	&"roof_fish": {"photo": "roof_fish", "colour": Color("303238"), "metallic": 0.0, "roughness": 0.75},
	&"roof_tiles": {"photo": "roof_tiles", "colour": Color("5E3426"), "metallic": 0.0, "roughness": 0.85},
	&"roof_shingle": {"photo": "shingles", "colour": Color("3E2E22"), "metallic": 0.0, "roughness": 0.9},
	&"door_1": {"photo": "door_1", "colour": Color("4A3322"), "metallic": 0.0, "roughness": 0.85},
	&"door_2": {"photo": "door_2", "colour": Color("4A4238"), "metallic": 0.0, "roughness": 0.85},
	&"band": {"photo": "band", "colour": Color("857E72"), "metallic": 0.0, "roughness": 0.9},
	# More walls and floors, mapped to the world.
	&"limewash": {"photo": "limewash", "colour": Color("8C8472"), "metallic": 0.0, "roughness": 0.9, "tile": 3.0},
	&"plaster_ochre": {"photo": "plaster_ochre", "colour": Color("8A6E44"), "metallic": 0.0, "roughness": 0.9, "tile": 2.5},
	&"tiles_chancel": {"photo": "tiles_chancel", "colour": Color("7A4A30"), "metallic": 0.0, "roughness": 0.6, "tile": 0.9},
	# Painted by us (tools/textures/paint.py, committed): the garrison's
	# banner, the rose window, the altar's frontal, the mess hall's shields
	# (the chapel's runner is painted too: carpet, above).
	&"banner": {"photo": "banner", "painted": true, "colour": Color("6E1414"), "metallic": 0.0, "roughness": 0.95, "cut": true},
	&"rose_window": {"photo": "rose_window", "painted": true, "colour": Color("3A3A8A"), "metallic": 0.0, "roughness": 0.4, "glow": 0.7},
	&"altar_frontal": {"photo": "altar_frontal", "painted": true, "colour": Color("681018"), "metallic": 0.0, "roughness": 0.95},
	&"shield_1": {"photo": "shield_1", "painted": true, "colour": Color("7A2A18"), "metallic": 0.1, "roughness": 0.8},
	&"shield_2": {"photo": "shield_2", "painted": true, "colour": Color("2A3A6A"), "metallic": 0.1, "roughness": 0.8},
	&"shield_3": {"photo": "shield_3", "painted": true, "colour": Color("2A2622"), "metallic": 0.1, "roughness": 0.8},
	# Small things flat, the baked shade on them: the mess's crocks and
	# food, sacks, leather, rope; dark glass in the windows nobody lit.
	&"glass_dark": {"photo": "", "colour": Color("1B2029"), "metallic": 0.2, "roughness": 0.25},
	&"pottery": {"photo": "", "colour": Color("6E4128"), "metallic": 0.0, "roughness": 0.5},
	&"pewter": {"photo": "", "colour": Color("7A7A74"), "metallic": 0.45, "roughness": 0.45},
	&"bread": {"photo": "", "colour": Color("9C6A32"), "metallic": 0.0, "roughness": 0.9},
	&"cheese": {"photo": "", "colour": Color("C9A24A"), "metallic": 0.0, "roughness": 0.7},
	&"meat": {"photo": "", "colour": Color("6E2A1E"), "metallic": 0.0, "roughness": 0.6},
	&"herbs": {"photo": "", "colour": Color("4B5A2A"), "metallic": 0.0, "roughness": 0.95},
	&"burlap": {"photo": "", "colour": Color("8A7550"), "metallic": 0.0, "roughness": 0.95},
	&"leather": {"photo": "", "colour": Color("4A2E1C"), "metallic": 0.0, "roughness": 0.7},
	&"rope": {"photo": "", "colour": Color("7C6A48"), "metallic": 0.0, "roughness": 0.95},
}

const GLOW := preload("res://scripts/Visual/Lights/glow.gdshader")
const FOLIAGE := preload("res://scripts/Visual/foliage.gdshader")
## How a glowing slot glows: [the flame's share of its colour, brightness,
## how much in hot spots rather than evenly].
const GLOW_LOOK := {
	&"horn": [0.9, 1.1, 0.0],
	&"pitch": [0.05, 0.6, 1.0],
	&"coal": [0.1, 0.7, 0.9],
}

## World-mapped slots blend their three projections this sharply (high: a
## face shows one, as a box-mapped PS2 wall did).
const TRIPLANAR_SHARPNESS := 8.0
## A slot nobody knows is drawn this loud, so it is noticed.
const UNKNOWN := Color("FF00FF")

## Where the converted photos are (tests point it elsewhere); where the
## painted ones are.
static var folder := "res://textures/ps2/"
const PAINTED := "res://textures/painted/"
## slot -> photo name, filled from SLOTS on first use (tests may change one).
static var photo_names := {}

static var _surfaces := {}
static var _level := {}
## The foliage the wind stirs (blow()).
static var swaying: Array[ShaderMaterial] = []
static var _glowing := {}
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


## The level's material for `slot` (tools/level's kit, LevelLoader): as
## surface(), but a slot with a "tile" is mapped to the world, one photo every
## "tile" metres whichever way the face looks (walls, floors and roofs run on
## from piece to piece without seams), and a "cut" slot's photo is cut out
## where it is clear (leaves on a card), and a "glow" slot is drawn unlit in
## its own photo's colours (the chapel's glass). Shared per slot.
static func level_surface(slot: StringName) -> Material:
	if _level.has(slot):
		return _level[slot]

	var entry: Dictionary = SLOTS.get(slot, {})

	# Leaves, grass, reeds and ivy: our own paintings, stirred by the wind.
	if entry.has("sway"):
		_level[slot] = _foliage(slot, entry)
		return _level[slot]

	var material: StandardMaterial3D = surface(slot).duplicate()

	if entry.has("tile"):
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_triplanar_sharpness = TRIPLANAR_SHARPNESS
		material.uv1_scale = Vector3.ONE / float(entry["tile"])

	# Glass the moon shines through: drawn unlit, as the PS2 drew it, in its
	# own colours ("glow" as bright) whatever light falls on it.
	if float(entry.get("glow", 0.0)) > 0.0:
		var bright := float(entry["glow"])
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = (Color(bright, bright, bright) if material.albedo_texture != null else entry["colour"] * bright)

	if bool(entry.get("cut", false)) and material.albedo_texture != null:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_level[slot] = material
	return material


## A foliage slot's material (foliage.gdshader): its painting cut out, its
## rustle and bough sway, the wind as it is now.
static func _foliage(slot: StringName, entry: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FOLIAGE
	material.set_shader_parameter(&"albedo_texture", photo(slot))
	material.set_shader_parameter(&"albedo", Color.WHITE if photo(slot) != null else entry["colour"])
	material.set_shader_parameter(&"rustle", float(entry["sway"][0]))
	material.set_shader_parameter(&"bough", float(entry["sway"][1]))
	material.set_shader_parameter(&"wind", Vector3(0.6, 0.0, 0.6))
	swaying.append(material)
	return material


## The wind (m/s, Night's) on all the foliage.
static func blow(wind: Vector3) -> void:
	for material in swaying:
		material.set_shader_parameter(&"wind", wind)


## The slot shining from inside (a pitch head, coals, horn panes): shared,
## its glow and char set per fixture (glow.gdshader's instance uniforms).
static func glowing(slot: StringName) -> ShaderMaterial:
	if _glowing.has(slot):
		return _glowing[slot]

	var material := ShaderMaterial.new()
	material.shader = GLOW
	var texture := photo(slot)
	material.set_shader_parameter(&"has_texture", texture != null)

	if texture != null:
		material.set_shader_parameter(&"albedo_texture", texture)

	material.set_shader_parameter(&"albedo", SLOTS.get(slot, {"colour": UNKNOWN})["colour"])
	var look: Array = GLOW_LOOK.get(slot, [0.35, 0.55, 0.0])
	material.set_shader_parameter(&"flame_share", look[0])
	material.set_shader_parameter(&"brightness", look[1])
	material.set_shader_parameter(&"mottle", look[2])
	_glowing[slot] = material
	return material


## A converted photo by its own name (a decal's), else our own painting of
## that name (textures/painted: always here), or null.
static func picture(name: String) -> Texture2D:
	for path in [folder.path_join(name + ".png"), PAINTED.path_join(name + ".png")]:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D

	return null


## The slot's converted photo, or null when it is not on this machine.
static func photo(slot: StringName) -> Texture2D:
	var name := _photo_name(slot)

	if name.is_empty():
		return null

	var path := (PAINTED if bool(SLOTS.get(slot, {}).get("painted", false)) else folder).path_join(name + ".png")

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


## Every shared surface made so far (Night wets them).
static func surfaces() -> Array:
	return _surfaces.values()


static func clear_cache() -> void:
	_surfaces.clear()
	_glowing.clear()
	_level.clear()
	swaying.clear()


static func _photo_name(slot: StringName) -> String:
	if photo_names.is_empty():
		for key in SLOTS:
			photo_names[key] = SLOTS[key]["photo"]

	var name = photo_names.get(slot, "")
	return "" if name == null else String(name)
