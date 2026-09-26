extends RefCounted
## The wardrobe: guards as low-poly PS2 characters, built in Blender from the
## Quaternius body (tools/wardrobe) and put together here. Presentation only:
## nothing here decides anything.
##
## A part made in Blender (an outfit, a head, a coif) comes with a skeleton
## of its own. Its bones sit where the game's do, but Blender may have turned
## their frames, so its skin is re-bound to the game skeleton's own rest
## frames before it is worn: however Blender turned a bone, the mesh moves
## with it exactly as it did there. Bones the game skeleton lacks (the cloth
## a skirt swings on) are added to it first.
##
##   Wardrobe.add_bones(skeleton, part_skeleton, ["cloth_skirt_front_1"])
##   mesh.skin = Wardrobe.rebind(part_skin, part_skeleton, skeleton)
##
## Every guard of a kind is his own man in the details (his face, his skin,
## how faded his tabard, how dirty, how tall) and the same in outline: roll()
## draws those from the kind's options, the same every time for the same
## seed. All of a kind share one material (wardrobe.gdshader); apply_look()
## sets what is his alone on each thing he wears.

const SHADER := preload("res://scripts/Visual/wardrobe.gdshader")
const SHADER_TWO_SIDED := preload("res://scripts/Visual/wardrobe_two_sided.gdshader")
## How much taller or shorter than his kind a man may be (a fraction).
const HEIGHT_SPREAD := 0.03

## Where the parts live (tools/wardrobe exports them here). A test may point
## it elsewhere, then forget() what was read from here.
static var ROOT := "res://assets/characters/wardrobe/"

static var _materials := {}
static var _black: ImageTexture
static var _json := {}


## `skin`, made on `source`'s bones, re-bound to `target`'s: one named bind
## per bind, each laid onto the target bone's rest frame so that at rest the
## mesh lands exactly where it was made, and moves with its bones after.
static func rebind(skin: Skin, source: Skeleton3D, target: Skeleton3D) -> Skin:
	var bound := Skin.new()

	for i in range(skin.get_bind_count()):
		var name := String(skin.get_bind_name(i))

		if name == "" and skin.get_bind_bone(i) >= 0:
			name = source.get_bone_name(skin.get_bind_bone(i))

		var from := source.find_bone(name)
		var to := target.find_bone(name)

		if from < 0 or to < 0:
			push_error("Wardrobe.rebind: no bone '%s' in %s" % [name, "the part" if from < 0 else "the game skeleton"])
			bound.add_named_bind("root", skin.get_bind_pose(i))
			continue

		var pose := target.get_bone_global_rest(to).affine_inverse() * source.get_bone_global_rest(from) * skin.get_bind_pose(i)
		bound.add_named_bind(name, pose)

	return bound


## Gives `target` each of `names` it lacks, hung from the same parent as in
## `source` and resting where it rests there. Parents come first in `names`.
static func add_bones(target: Skeleton3D, source: Skeleton3D, names: PackedStringArray) -> void:
	for name in names:
		if target.find_bone(name) >= 0:
			continue

		var from := source.find_bone(name)

		if from < 0:
			push_error("Wardrobe.add_bones: the part has no bone '%s'" % name)
			continue

		var source_parent := source.get_bone_parent(from)
		var parent := target.find_bone(source.get_bone_name(source_parent)) if source_parent >= 0 else -1

		if source_parent >= 0 and parent < 0:
			push_error("Wardrobe.add_bones: '%s' hangs from '%s', which the game skeleton lacks" % [name, source.get_bone_name(source_parent)])
			continue

		var global := source.get_bone_global_rest(from)
		var local := global if parent < 0 else target.get_bone_global_rest(parent).affine_inverse() * global
		var bone := target.add_bone(name)
		target.set_bone_parent(bone, parent)
		target.set_bone_rest(bone, local)
		target.set_bone_pose_position(bone, local.origin)
		target.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())
		target.set_bone_pose_scale(bone, local.basis.get_scale())


# ---------------------------------------------------------------------------
# The parts' data
# ---------------------------------------------------------------------------

## A kind's JSON (tools/wardrobe/export.py): its cloth, colliders, metal,
## skin tones, probes and options. Empty if it has none.
static func kind_data(kind: StringName) -> Dictionary:
	return _read("%s.json" % kind)


static func head_data(face: StringName) -> Dictionary:
	return _read("heads/%s.json" % face)


static func headgear_data(piece: StringName) -> Dictionary:
	return _read("headgear/%s.json" % piece)


## The colour a kind's outfit was baked in (its dyed faces): its dye's
## `colour`, or the first of its `colours`; white with no dye.
static func dye_base(options: Dictionary) -> Color:
	var dye: Dictionary = options.get("dye", {})
	var colours: Array = dye.get("colours", [])
	var base: Array = colours[0] if not colours.is_empty() else dye.get("colour", [1.0, 1.0, 1.0])
	return Color(base[0], base[1], base[2])


static func hair_data(style: StringName) -> Dictionary:
	return _read("hair/%s.json" % style)


static func _read(relative: String) -> Dictionary:
	var path := ROOT + relative

	if _json.has(path):
		return _json[path]

	var data := {}

	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

		if parsed is Dictionary:
			data = parsed

	_json[path] = data
	return data


# ---------------------------------------------------------------------------
# Each his own
# ---------------------------------------------------------------------------

## What this man wears and looks like, drawn from a kind's `options` (its
## JSON's): {face, tone, hair, beard, headgear, dye, fade, grime, height,
## skin, hair_colour}. Eleven draws, always all eleven and in this order, so
## an option added later never changes the rest of anyone's looks: the nine
## of the spec (§7.5), then (batch 1) which dye colour of `dye.colours`, and
## which of `hair_colours`. Which hair a helmet hides is the dresser's
## business (Humanoid.dress), not the roll's.
static func roll(options: Dictionary, skin_tones: Dictionary, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var face := _pick(options.get("faces", []), rng.randf())
	var tone := _pick(options.get("tones", []), rng.randf())
	var hair := _pick(options.get("hair", []), rng.randf())
	var beard := _pick(options.get("beards", []), rng.randf())
	var sets: Array = options.get("headgear", [])
	var set_draw := rng.randf()
	var dye_draw := rng.randf() * 2.0 - 1.0
	var fade_draw := rng.randf()
	var grime_draw := rng.randf()
	var height_draw := rng.randf() * 2.0 - 1.0
	var colour_draw := rng.randf()
	var hair_draw := rng.randf()

	var headgear: Array[StringName] = []

	if not sets.is_empty():
		for piece in sets[mini(int(set_draw * sets.size()), sets.size() - 1)]:
			headgear.append(StringName(piece))

	var dye: Dictionary = options.get("dye", {})
	var colours: Array = dye.get("colours", [])
	var base := _colour(colours[mini(int(colour_draw * colours.size()), colours.size() - 1)] if not colours.is_empty()
		else dye.get("colour", [1.0, 1.0, 1.0]))
	var hair_colours: Array = options.get("hair_colours", [])
	var hair_colour := _colour(hair_colours[mini(int(hair_draw * hair_colours.size()), hair_colours.size() - 1)]) \
		if not hair_colours.is_empty() else Color(0.3, 0.25, 0.2)
	var shift := float(dye.get("shift", 0.0))
	var fades: Array = dye.get("fade", [0.0, 0.0])
	var grimes: Array = options.get("grime", [0.0, 0.0])

	return {
		"face": face,
		"tone": tone,
		"hair": hair,
		"beard": beard,
		"headgear": headgear,
		"dye": Color.from_hsv(wrapf(base.h + dye_draw * shift, 0.0, 1.0), base.s, clampf(base.v * (1.0 + 2.0 * dye_draw * shift), 0.0, 1.0)),
		"fade": lerpf(float(fades[0]), float(fades[1]), fade_draw),
		"grime": lerpf(float(grimes[0]), float(grimes[1]), grime_draw),
		"height": 1.0 + height_draw * HEIGHT_SPREAD,
		"skin": _colour(skin_tones.get(String(tone), [1.0, 1.0, 1.0])),
		"hair_colour": hair_colour,
	}


static func _pick(list: Array, draw: float) -> StringName:
	if list.is_empty():
		return &""

	return StringName(list[mini(int(draw * list.size()), list.size() - 1)])


static func _colour(rgb: Variant) -> Color:
	if rgb is Color:
		return rgb

	var values: Array = rgb
	return Color(float(values[0]), float(values[1]), float(values[2]))


## The material all of a kind share for one texture (and its mask): the
## wardrobe shader, two-sided for cloth strips. `dye_base` is the colour the
## dyed cloth was baked in.
static func material(albedo: Texture2D, mask: Texture2D, two_sided: bool, dye_base: Color) -> ShaderMaterial:
	var key := "%d|%d|%s|%s" % [albedo.get_instance_id() if albedo != null else 0, mask.get_instance_id() if mask != null else 0, two_sided, dye_base]

	if _materials.has(key):
		return _materials[key]

	var made := ShaderMaterial.new()
	made.shader = SHADER_TWO_SIDED if two_sided else SHADER
	made.set_shader_parameter(&"albedo", albedo)
	made.set_shader_parameter(&"mask", mask if mask != null else _black_texture())
	made.set_shader_parameter(&"dye_base", dye_base)
	_materials[key] = made
	return made


## What is his alone, on one thing he wears: his dye and its fading, his
## skin, his dirt (roll()).
static func apply_look(mesh: GeometryInstance3D, look: Dictionary) -> void:
	var skin: Color = look.get("skin", Color.WHITE)
	mesh.set_instance_shader_parameter(&"dye_colour", look.get("dye", Color.WHITE))
	mesh.set_instance_shader_parameter(&"dye_fade", float(look.get("fade", 0.0)))
	mesh.set_instance_shader_parameter(&"skin_tone", Vector3(skin.r, skin.g, skin.b))
	mesh.set_instance_shader_parameter(&"grime", float(look.get("grime", 0.0)))


## A mask that says nothing: no dye, no skin, no dirt.
static func _black_texture() -> ImageTexture:
	if _black == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
		image.fill(Color.BLACK)
		_black = ImageTexture.create_from_image(image)

	return _black


# ---------------------------------------------------------------------------
# Dressing: what can be worn, and the worn parts themselves
# ---------------------------------------------------------------------------

static var _skins := {}
static var _warned := {}


## Whether `kind` can be dressed from the wardrobe: its own files are all
## there, and at least one face and one set of headgear it can roll.
static func can_dress(kind: StringName) -> bool:
	var own := [ROOT + "%s.glb" % kind, ROOT + "%s.png" % kind, ROOT + "%s_mask.png" % kind]
	var ok := own.all(func(path): return ResourceLoader.exists(path)) and not kind_data(kind).is_empty()

	if ok:
		var wanted: Array = kind_data(kind).get("options", {}).get("headgear", [])
		var options := usable_options(kind_data(kind).get("options", {}))
		# Bare-headed by design ([] or [[]]) dresses; a kind whose every
		# headgear set is missing does not (its silhouette would be gone),
		# nor one whose every hair style, or every beard, is.
		var bare := wanted.all(func(pieces): return pieces.is_empty())
		ok = not options.get("faces", []).is_empty() and (bare or not options.get("headgear", []).is_empty())

		for key in ["hair", "beards"]:
			var styles: Array = kind_data(kind).get("options", {}).get(key, [])
			ok = ok and (styles.is_empty() or not options.get(key, []).is_empty())

	if not ok and not _warned.has(kind):
		_warned[kind] = true
		push_warning("Wardrobe: %s cannot be dressed from %s (files missing); painted instead" % [kind, ROOT])

	return ok


## `options` without the faces, headgear sets, hair or beards whose files
## are missing, each dropped with a warning.
static func usable_options(options: Dictionary) -> Dictionary:
	var kept := options.duplicate(true)
	var faces := []

	for face in options.get("faces", []):
		var files := [ROOT + "heads/%s.glb" % face]

		for tone in options.get("tones", []):
			files.append(ROOT + "heads/%s_%s.png" % [face, tone])

		if files.all(func(path): return ResourceLoader.exists(path)) and not head_data(StringName(face)).is_empty():
			faces.append(StringName(face))
		else:
			_warn_once("face %s" % face)

	var sets := []

	for pieces in options.get("headgear", []):
		var whole := true

		for piece in pieces:
			whole = whole and _piece_ready(StringName(piece))

		if whole:
			sets.append(pieces.map(func(piece): return StringName(piece)))
		else:
			_warn_once("headgear %s" % [pieces])

	kept["faces"] = faces
	kept["headgear"] = sets

	for key in ["hair", "beards"]:
		var styles := []

		for style in options.get(key, []):
			var files := [ROOT + "hair/%s.glb" % style, ROOT + "hair/%s.png" % style, ROOT + "hair/%s_mask.png" % style]

			if files.all(func(path): return ResourceLoader.exists(path)) and not hair_data(StringName(style)).is_empty():
				styles.append(StringName(style))
			else:
				_warn_once("hair %s" % style)

		kept[key] = styles

	return kept


static func _piece_ready(piece: StringName) -> bool:
	return ResourceLoader.exists(ROOT + "headgear/%s.glb" % piece) and ResourceLoader.exists(ROOT + "headgear/%s.png" % piece) \
		and not headgear_data(piece).is_empty()


static func _warn_once(what: String) -> void:
	if not _warned.has(what):
		_warned[what] = true
		push_warning("Wardrobe: %s has missing files; dropped" % what)


## The mesh of the part at `path` (a GLB) and its skin, re-bound to
## `target`, after giving `target` the bones it lacks (cloth). Read once for
## each body kind; every man of that body shares the mesh and the skin.
## Nothing for a file with no skinned mesh (remembered: one error, not one
## a man).
static func skinned(path: String, target: Skeleton3D, body: String) -> Array:
	var key := "%s|%s" % [path, body]

	if _skins.has(key) and (_skins[key] as Array).is_empty():
		return []

	if not _skins.has(key):
		var scene: Node = (load(path) as PackedScene).instantiate()
		var source := scene.find_child("Skeleton3D", true, false) as Skeleton3D
		var found: MeshInstance3D = null

		for node in scene.find_children("*", "MeshInstance3D", true, false):
			if (node as MeshInstance3D).skin != null:
				found = node
				break

		if source == null or found == null:
			scene.free()
			push_error("Wardrobe: %s has no skinned mesh on a skeleton" % path)
			_skins[key] = []
			return []

		var extra := PackedStringArray()

		for i in range(source.get_bone_count()):
			if target.find_bone(source.get_bone_name(i)) < 0:
				extra.append(source.get_bone_name(i))

		var specs := []

		for name in extra:
			var bone := source.find_bone(name)
			var parent := source.get_bone_parent(bone)
			specs.append([name, source.get_bone_name(parent) if parent >= 0 else "", source.get_bone_global_rest(bone)])

		add_bones(target, source, extra)
		_skins[key] = [found.mesh, rebind(found.skin, source, target), specs]
		scene.free()
	else:
		_add_specs(target, _skins[key][2])

	return [_skins[key][0], _skins[key][1]]


## Bones a part needs, given by [name, parent, global rest] (skinned()).
static func _add_specs(target: Skeleton3D, specs: Array) -> void:
	for spec in specs:
		if target.find_bone(spec[0]) >= 0:
			continue

		var parent := target.find_bone(spec[1]) if spec[1] != "" else -1
		var global: Transform3D = spec[2]
		var local := global if parent < 0 else target.get_bone_global_rest(parent).affine_inverse() * global
		var bone := target.add_bone(spec[0])
		target.set_bone_parent(bone, parent)
		target.set_bone_rest(bone, local)
		target.set_bone_pose_position(bone, local.origin)
		target.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())
		target.set_bone_pose_scale(bone, local.basis.get_scale())


## Lets go of everything read (a test that moved ROOT, a clean exit).
static func forget() -> void:
	_json.clear()
	_skins.clear()
	_materials.clear()
	_warned.clear()
