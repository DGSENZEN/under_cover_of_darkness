extends Node3D
## The wardrobe (Wardrobe.gd, Humanoid.dress): guards built as low-poly PS2
## characters from Blender-made parts. Skins re-bound to the game skeleton,
## the variety roll, the baked parts and their budgets, dressing, cloth,
## dismemberment, hit flash and armour. Headless; the look itself is judged
## by eye in tests/visual/stage_wardrobe.tscn. Run with --fixed-fps 60: the
## cloth is measured frame by frame (_paced says so if not).

const Wardrobe := preload("res://scripts/Visual/Wardrobe.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
const HumanoidScript := preload("res://scripts/Visual/Humanoid.gd")
const GUARD := preload("res://Guard.tscn")
const Layers := preload("res://scripts/Visual/Layers.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const PLAYER := preload("res://Player.tscn")
const GuardFighterScript := preload("res://scripts/AISystem/GuardFighter.gd")

const MALE := "res://assets/characters/base/Superhero_Male_FullBody.gltf"

var results: Array[String] = []

## Every kind the wardrobe dresses, and the archetype that is it (batch 1's
## Tasks 6-8 add theirs). Every per-kind check runs over it.
const DRESSED := {&"watchman": &"", &"swordsman": &"swordsman", &"archer": &"archer", &"arms_master": &"trainer"}
## What each dressed kind must show:
##   worn: every mesh he wears (none of the base body's);
##   key: his silhouette, worn by every guard of his kind;
##   rings / silent: where steel rings and where it must not, each
##     [bone, up, ahead] (metres from the bone's joint, in his frame) or
##     [bone, bone] (half-way between two joints);
##   metal: which worn piece answers for a metal bone.
##   k5: how far (m) a cloth joint may pass into a leg in his attacks
##     (default 0.005).
const EXPECT := {
	# His cloth is batch 0's, as approved: built where it hangs, not clear of
	# his legs (recipes.WATCHMAN "batch"), so his kick swings a skirt 9 mm
	# into a thigh. Rebuilt with batch 1's cloth it clears them: the user's
	# call.
	&"watchman": {"worn": ["Outfit", "Head_weathered", "kettlehat", "coif"], "key": ["kettlehat"],
		"rings": [[&"Head", 0.12, 0.0], [&"neck_01", 0.0, 0.06]],
		"silent": [[&"spine_02", 0.0, 0.15], [&"thigh_l", &"calf_l"]],
		"metal": {&"neck_01": "coif", &"Head": "coif"}, "k5": 0.012},
	&"swordsman": {"worn": ["Outfit", "Head_weathered", "nasalhelm", "curtain"], "key": ["nasalhelm"],
		"rings": [[&"Head", 0.12, 0.0], [&"spine_02", 0.0, 0.15], [&"upperarm_l", 0.0, 0.0]],
		"silent": [[&"thigh_l", &"calf_l"], [&"calf_l", 0.0, 0.0]],
		"metal": {&"Head": "nasalhelm", &"neck_01": "curtain", &"spine_02": "Outfit", &"upperarm_l": "Outfit"}},
	&"archer": {"worn": ["Outfit", "Head_weathered", "hood"], "key": ["hood"], "rings": [],
		"silent": [[&"Head", 0.12, 0.0], [&"spine_02", 0.0, 0.15], [&"thigh_l", &"calf_l"]], "metal": {}},
	# One man: every seed gives him the same face, hair and beard.
	&"arms_master": {"worn": ["Outfit", "Head_old", "Hair_parted", "Beard_full"], "key": ["Hair_parted", "Beard_full"],
		"rings": [], "silent": [[&"Head", 0.12, 0.0], [&"spine_02", 0.0, 0.15], [&"thigh_l", &"calf_l"]], "metal": {},
		"same": ["face", "hair", "beard"]},
}


func _ready() -> void:
	var paced: bool = await _paced()
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")

	if not paced:
		print("NOTE  frames are not paced: run with --fixed-fps 60 (checks here look at what is drawn frame by frame)")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	# Cloth first, on a fresh world: after the sections below, guards stood
	# so that their cloth cleared their legs where a new game's did not.
	await _cloth()
	await _k3a()
	_k10a()
	_k2a()
	_k13()
	_k13b()
	_k15()
	await _k3()
	await _dressed()
	await _integration()


# ---------------------------------------------------------------------------
# K3a: re-binding a skin made on other bone frames
# ---------------------------------------------------------------------------

func _k3a() -> void:
	# K3a a skin built on twisted bone frames lands exactly on the game skeleton
	var target := _game_skeleton()
	var source := _twisted_copy(target)
	var made := _probe_mesh(source, [&"lowerarm_r", &"spine_02", &"cloth_test_1"])
	Wardrobe.add_bones(target, source, PackedStringArray(["cloth_test_1"]))
	var mi := MeshInstance3D.new()
	mi.mesh = made[0]
	mi.skin = Wardrobe.rebind(made[1], source, target)
	target.add_child(mi)
	mi.skeleton = NodePath("..")
	await _frames(2)
	var rest_err := _max_error(_skinned(mi, target), made[0])
	var arm := target.find_bone(&"lowerarm_r")
	target.set_bone_pose_rotation(arm, target.get_bone_pose_rotation(arm) * Quaternion(Vector3.RIGHT, deg_to_rad(60)))
	await _frames(2)
	var pose_err := _max_error_moved(_skinned(mi, target), made[0], target, arm)
	var cloth := target.find_bone(&"cloth_test_1")
	var bone_err := INF

	if cloth >= 0:
		bone_err = (target.get_bone_global_rest(cloth).origin - source.get_bone_global_rest(source.find_bone(&"cloth_test_1")).origin).length()

	_check("K3a re-binding: twisted frames land exact, at rest and posed", rest_err <= 1e-4 and pose_err <= 1e-4 and bone_err <= 1e-5,
		"rest %.6f pose %.6f bone %.6f" % [rest_err, pose_err, bone_err])
	target.get_parent().queue_free()
	source.queue_free()
	await _frames(2)


## The Quaternius skeleton, as the game loads it, under the test.
func _game_skeleton() -> Skeleton3D:
	var scene: Node3D = (load(MALE) as PackedScene).instantiate()
	add_child(scene)
	var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D

	for child in skeleton.get_children():
		if child is MeshInstance3D:
			child.free()

	return skeleton


## A copy of `skeleton` whose every bone keeps its joint but has its frame
## turned 37 degrees, plus one bone of cloth under the pelvis.
func _twisted_copy(skeleton: Skeleton3D) -> Skeleton3D:
	var twist := Basis(Vector3(1, 1, 0).normalized(), deg_to_rad(37.0))
	var copy := Skeleton3D.new()
	var globals: Array[Transform3D] = []

	for i in range(skeleton.get_bone_count()):
		copy.add_bone(skeleton.get_bone_name(i))
		var rest := skeleton.get_bone_global_rest(i)
		globals.append(Transform3D(rest.basis * twist, rest.origin))

	for i in range(skeleton.get_bone_count()):
		copy.set_bone_parent(i, skeleton.get_bone_parent(i))

	var pelvis := skeleton.find_bone(&"pelvis")
	var cloth := copy.add_bone("cloth_test_1")
	copy.set_bone_parent(cloth, pelvis)
	globals.append(Transform3D(twist, globals[pelvis].origin + Vector3(0.0, -0.3, 0.12)))

	for i in range(copy.get_bone_count()):
		var parent := copy.get_bone_parent(i)
		var local: Transform3D = globals[i] if parent < 0 else globals[parent].affine_inverse() * globals[i]
		copy.set_bone_rest(i, local)
		copy.set_bone_pose_position(i, local.origin)
		copy.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
		copy.set_bone_pose_scale(i, local.basis.get_scale())

	add_child(copy)
	return copy


## One small triangle 5 cm off each of `bones`' joints, each wholly on its
## bone, bound in `skeleton`'s own frames: [ArrayMesh, Skin].
func _probe_mesh(skeleton: Skeleton3D, bones: Array) -> Array:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var weights := PackedFloat32Array()
	var skin := Skin.new()

	for b in range(bones.size()):
		var bone := skeleton.find_bone(bones[b])
		var rest := skeleton.get_bone_global_rest(bone)
		skin.add_named_bind(String(bones[b]), rest.affine_inverse())

		for corner in [Vector3(0.05, 0.0, 0.0), Vector3(0.0, 0.05, 0.0), Vector3(0.0, 0.0, 0.05)]:
			vertices.append(rest.origin + corner)
			indices.append_array([b, 0, 0, 0])
			weights.append_array([1.0, 0.0, 0.0, 0.0])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_BONES] = indices
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return [mesh, skin]


## Every vertex of `mi` where its skin puts it on `skeleton` now, in the
## skeleton's space: what the GPU draws (bone pose x bind pose x vertex,
## weighted). Worked out here because a headless run has no rendering
## skeleton to bake from (bake_mesh_from_current_skeleton_pose fails).
func _skinned(mi: MeshInstance3D, skeleton: Skeleton3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var skin := mi.skin
	var bone_of: Array[int] = []

	for i in range(skin.get_bind_count()):
		var name := String(skin.get_bind_name(i))
		bone_of.append(skeleton.find_bone(name) if name != "" else skin.get_bind_bone(i))

	for s in range(mi.mesh.get_surface_count()):
		var arrays := mi.mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(vertices.size(), 1)

		for v in range(vertices.size()):
			var at := Vector3.ZERO

			for k in range(per):
				var weight := weights[v * per + k]

				if weight <= 0.0:
					continue

				var bind := bones[v * per + k]
				at += weight * (skeleton.get_bone_global_pose(bone_of[bind]) * skin.get_bind_pose(bind) * vertices[v])

			out.append(at)

	return out


## How far any vertex in `got` is from the same vertex of `original`.
func _max_error(got: PackedVector3Array, original: ArrayMesh) -> float:
	var want: PackedVector3Array = original.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	if got.size() != want.size():
		return INF

	var worst := 0.0

	for i in range(want.size()):
		worst = maxf(worst, got[i].distance_to(want[i]))

	return worst


## The same, with `bone` posed: its triangle (the first) should have moved
## rigidly with it, the rest not at all.
func _max_error_moved(got: PackedVector3Array, original: ArrayMesh, skeleton: Skeleton3D, bone: int) -> float:
	var want: PackedVector3Array = original.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	if got.size() != want.size():
		return INF

	var moved := skeleton.get_bone_global_pose(bone) * skeleton.get_bone_global_rest(bone).affine_inverse()
	var worst := 0.0

	for i in range(want.size()):
		var expected: Vector3 = moved * want[i] if i < 3 else want[i]
		worst = maxf(worst, got[i].distance_to(expected))

	return worst


# ---------------------------------------------------------------------------
# K10a: the variety roll and the wardrobe shader
# ---------------------------------------------------------------------------

func _k10a() -> void:
	# K10a the roll: same seed same look, ranges held, new options never reshuffle
	var o := {"faces": [&"weathered"], "tones": [&"light", &"dark"], "hair": [], "beards": [],
		"headgear": [[&"kettlehat", &"coif"]], "dye": {"colour": [0.62, 0.52, 0.16], "shift": 0.04, "fade": [0.0, 0.35]},
		"grime": [0.2, 0.8]}
	var tones := {"light": [1.0, 1.0, 1.0], "dark": [0.55, 0.42, 0.35]}
	var same := str(Wardrobe.roll(o, tones, 7)) == str(Wardrobe.roll(o, tones, 7))
	var seen := {}
	var ranged := true
	var steady := true
	var o2 := o.duplicate(true)
	o2["faces"] = [&"weathered", &"old"]

	for s in range(1, 9):
		var r: Dictionary = Wardrobe.roll(o, tones, s)
		seen[str(r)] = true
		ranged = ranged and r.fade >= 0.0 and r.fade <= 0.35 and r.grime >= 0.2 and r.grime <= 0.8 \
			and r.height >= 0.97 and r.height <= 1.03 and r.tone in [&"light", &"dark"]
		steady = steady and is_equal_approx(Wardrobe.roll(o2, tones, s).grime, r.grime)

	var mat: ShaderMaterial = Wardrobe.material(load("res://icon.svg"), null, false, Color(0.62, 0.52, 0.16))
	var names := mat.shader.get_shader_uniform_list().map(func(u): return u.name)
	var two: ShaderMaterial = Wardrobe.material(load("res://icon.svg"), null, true, Color(0.62, 0.52, 0.16))
	var sided := two.shader.resource_path.ends_with("wardrobe_two_sided.gdshader") and mat.shader.resource_path.ends_with("wardrobe.gdshader")
	# Every look uniform Humanoid copies (and apply_look sets) is one the
	# shader declares per instance: a renamed one would read back null.
	var code := FileAccess.get_file_as_string("res://scripts/Visual/wardrobe.gdshaderinc")
	var declared: bool = HumanoidScript.LOOK_UNIFORMS.all(func(u): return RegEx.create_from_string("instance uniform \\w+ %s\\b" % u).search(code) != null)
	# K16 new draws never change the old ones; dye colours are picked from the list
	# Only the new keys added: its shift and fade are o's, so every old draw
	# must come out the same.
	var o3 := o.duplicate(true)
	o3["dye"]["colours"] = [[0.2, 0.3, 0.14], [0.34, 0.25, 0.15], [0.37, 0.37, 0.35]]
	o3["hair_colours"] = [[0.72, 0.7, 0.66]]
	var hues := {}
	var kept := true

	for s in range(1, 13):
		var a: Dictionary = Wardrobe.roll(o, tones, s)
		var b: Dictionary = Wardrobe.roll(o3, tones, s)
		kept = kept and [a.face, a.tone, a.headgear, a.fade, a.grime, a.height] == [b.face, b.tone, b.headgear, b.fade, b.grime, b.height]
		hues[snappedf((b.dye as Color).h, 0.01)] = true

	var hair: Variant = Wardrobe.roll(o3, tones, 5).get("hair_colour")
	_check("K16 the dye rolls from its colours, and new draws change no old look",
		kept and hues.size() >= 2 and hair is Color and (hair as Color).is_equal_approx(Color(0.72, 0.7, 0.66)), str(hues.keys()))

	_check("K10a the variety roll is repeatable, ranged and stable; the shader has its uniforms",
		same and seen.size() >= 2 and ranged and steady and "albedo" in names and "mask" in names and "dye_base" in names and sided and declared,
		"same %s distinct %d ranged %s steady %s uniforms %s two-sided %s instance %s" % [same, seen.size(), ranged, steady, names, sided, declared])


# ---------------------------------------------------------------------------
# K2a, K3: the baked, exported parts
# ---------------------------------------------------------------------------

func _k2a() -> void:
	# K2a every dressed kind's files keep the PS2 budgets
	for kind in DRESSED:
		var data := Wardrobe.kind_data(kind)
		var options: Dictionary = data.get("options", {})
		var sizes := {String(kind): 256, "%s_mask" % kind: 256}

		for face in options.get("faces", []):
			for tone in options.get("tones", []):
				sizes["heads/%s_%s" % [face, tone]] = 128

		for pieces in options.get("headgear", []):
			for piece in pieces:
				sizes["headgear/%s" % piece] = 128
				sizes["headgear/%s_mask" % piece] = 128

		for style in options.get("hair", []) + options.get("beards", []):
			sizes["hair/%s" % style] = 128
			sizes["hair/%s_mask" % style] = 128

		var ok := true
		var why := []

		for f in sizes:
			var path: String = Wardrobe.ROOT + f + ".png"

			if not ResourceLoader.exists(path):
				ok = false
				why.append("%s missing" % f)
				continue

			var img: Image = (load(path) as Texture2D).get_image()
			var colours := _colour_count(img)
			# Imported lossless, and never switched to VRAM compression when the
			# editor sees it on a 3D mesh (that would smear the palette).
			var settings := FileAccess.get_file_as_string(path + ".import")
			var lossless := settings.contains("compress/mode=0") and settings.contains("detect_3d/compress_to=0")
			var fits: bool = img.get_width() == sizes[f] and img.get_height() == sizes[f] and (f.ends_with("_mask") or colours <= 64) \
				and lossless

			if not lossless:
				why.append("%s not held lossless" % f)

			ok = ok and fits
			why.append("%s %dx%d %d" % [f, img.get_width(), img.get_height(), colours])

		var tris := _heaviest(kind)
		_check("K2a %s: 256/128 textures held lossless, at most 64 colours, at most 3,000 triangles" % kind, ok and tris <= 3000,
			"%s tris %d" % [why, tris])


## The most triangles a guard of `kind` can wear: his outfit, and the
## heaviest face, hair, beard and headgear set he can roll.
func _heaviest(kind: StringName) -> int:
	var data := Wardrobe.kind_data(kind)
	var options: Dictionary = data.get("options", {})
	var faces: Array = options.get("faces", []).map(func(f): return int(Wardrobe.head_data(StringName(f)).get("triangles", 99999)))
	var hair: Array = options.get("hair", []).map(func(h): return int(Wardrobe.hair_data(StringName(h)).get("triangles", 99999)))
	var beards: Array = options.get("beards", []).map(func(b): return int(Wardrobe.hair_data(StringName(b)).get("triangles", 99999)))
	var sets: Array = options.get("headgear", []).map(func(pieces): return pieces.reduce(
		func(n, piece): return n + int(Wardrobe.headgear_data(StringName(piece)).get("triangles", 99999)), 0))
	return int(data.get("triangles", 99999)) + (faces.max() if not faces.is_empty() else 0) + (hair.max() if not hair.is_empty() else 0) \
		+ (beards.max() if not beards.is_empty() else 0) + (sets.max() if not sets.is_empty() else 0)


## The coif's hood ends here (recipes.HEADGEAR.coif.cape.top_z); below it,
## its cape.
const CAPE_TOP := 1.575


func _k13() -> void:
	# K13 the cape rides his neck, chest and collarbones: weighed on his head
	# or his arms, it swings into his gambeson when he looks round or lowers
	# his arms
	var scene: Node = (load(Wardrobe.ROOT + "headgear/coif.glb") as PackedScene).instantiate()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var wrong := {}
	var cape := 0

	# Every surface: the cape is drawn from both sides, a surface of its own.
	for surface in range(mi.mesh.get_surface_count()):
		var arrays := mi.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(points.size(), 1)

		for v in range(points.size()):
			if points[v].y >= CAPE_TOP:
				continue

			cape += 1

			for k in range(per):
				var bone := String(mi.skin.get_bind_name(bones[v * per + k]))

				if weights[v * per + k] > 0.0 and (bone == "Head" or bone.begins_with("upperarm")):
					wrong[bone] = int(wrong.get(bone, 0)) + 1

	scene.free()
	_check("K13 the coif's cape rides his neck, chest and collarbones, not his head or arms", cape > 0 and wrong.is_empty(),
		"cape vertices %d, on the wrong bones %s" % [cape, wrong])


## The nasal helm's foot (recipes.HEADGEAR.nasalhelm: "base_z").
const HELM_FOOT := 1.722


func _k13b() -> void:
	# K13b the curtain rides his head at its top and his neck and shoulders
	# below: it hangs from his helm and drapes as he moves his head
	var top := _weights_where(&"curtain", func(p): return p.y > HELM_FOOT - 0.01)
	var low := _weights_where(&"curtain", func(p): return p.y < HELM_FOOT - 0.12)
	var top_on_head := top.all(func(w): return w.keys() == [&"Head"])
	var low_off_head := low.all(func(w): return not w.has(&"Head"))
	_check("K13b the curtain hangs from his helm and rides his neck below", not top.is_empty() and not low.is_empty()
		and top_on_head and low_off_head, "top %d vertices (on his head alone %s), hem %d (off his head %s)"
		% [top.size(), top_on_head, low.size(), low_off_head])

	# K13c the hood's tail is its own chain under his head
	var tail: Array = Wardrobe.headgear_data(&"hood").get("cloth", []).filter(func(c): return c.chain == "hood_tail")
	_check("K13c the hood's tail swings on three bones under his head", tail.size() == 1 and tail[0].parent == "Head"
		and tail[0].bones.size() == 3, str(tail))


## For each vertex of a headgear piece's GLB (every surface) that `pick`
## takes (its position, in the game's frame), its non-zero weights by bone.
func _weights_where(piece: StringName, pick: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var path := Wardrobe.ROOT + "headgear/%s.glb" % piece

	if not ResourceLoader.exists(path):
		return out

	var scene: Node = (load(path) as PackedScene).instantiate()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]

	for surface in range(mi.mesh.get_surface_count()):
		var arrays := mi.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(points.size(), 1)

		for v in range(points.size()):
			if not pick.call(points[v]):
				continue

			var found := {}

			for k in range(per):
				if weights[v * per + k] > 0.0:
					found[StringName(mi.skin.get_bind_name(bones[v * per + k]))] = weights[v * per + k]

			out.append(found)

	scene.free()
	return out


## Above this the coif's hood rides his head alone (recipes.HEADGEAR.coif:
## "rigid_above").
const HOOD_RIGID := 1.68


func _k15() -> void:
	# K15 the hood above his ears rides his head alone: weighed partly on his
	# neck, its big faces lag when he bows his head and his skull shows
	# through them
	var scene: Node = (load(Wardrobe.ROOT + "headgear/coif.glb") as PackedScene).instantiate()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var wrong := {}
	var hood := 0

	for surface in range(mi.mesh.get_surface_count()):
		var arrays := mi.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(points.size(), 1)

		for v in range(points.size()):
			if points[v].y < HOOD_RIGID:
				continue

			hood += 1

			for k in range(per):
				var bone := String(mi.skin.get_bind_name(bones[v * per + k]))

				if weights[v * per + k] > 0.001 and bone != "Head":
					wrong[bone] = int(wrong.get(bone, 0)) + 1

	scene.free()
	_check("K15 the coif's hood above his ears rides his head alone", hood > 0 and wrong.is_empty(),
		"hood vertices %d, on other bones %s" % [hood, wrong])


## Whether `mesh` carries `look`'s uniforms: each set (an unset one reads
## back null, and null equals null) and equal to what was rolled.
func _carries_look(mesh: GeometryInstance3D, look: Dictionary) -> bool:
	if look.is_empty():
		return false

	var skin: Color = look.get("skin", Color.WHITE)
	# Hair and beards are dyed his hair colour, not his dye.
	var strands := String(mesh.name).begins_with("Hair_") or String(mesh.name).begins_with("Beard_")
	var want := {&"dye_colour": look.get("hair_colour") if strands else look.get("dye"), &"dye_fade": look.get("fade"),
		&"skin_tone": Vector3(skin.r, skin.g, skin.b), &"grime": look.get("grime")}

	for p in want:
		var got = mesh.get_instance_shader_parameter(p)

		if got == null or want[p] == null:
			return false

		if got is Color and not (got as Color).is_equal_approx(want[p]):
			return false

		if got is Vector3 and not (got as Vector3).is_equal_approx(want[p]):
			return false

		if (got is float or got is int) and not is_equal_approx(float(got), float(want[p])):
			return false

	return true


func _colour_count(img: Image) -> int:
	var seen := {}

	for y in range(img.get_height()):
		for x in range(img.get_width()):
			seen[img.get_pixel(x, y).to_rgba32() >> 8] = true

	return seen.size()


func _k3() -> void:
	# K3 (spec K3, male body) every dressed kind's export re-binds exactly onto the game skeleton
	for kind in DRESSED:
		var errs := await _probe_errors(kind)
		_check("K3 %s: probes within 1 mm at rest, within 3 cm of the body mid-swing" % kind,
			errs.count > 0 and errs.rest <= 0.001 and errs.pose <= 0.03, "rest %.4f pose %.4f over %d probes" % [errs.rest, errs.pose, errs.count])


## For each probe of `kind`'s JSON: how far the re-bound outfit's vertex sits
## from where Blender put it (at rest), and how much its distance to the body
## point it covers changes mid-swing.
func _probe_errors(kind: StringName) -> Dictionary:
	var out := {"rest": INF, "pose": INF, "count": 0}
	var data := Wardrobe.kind_data(kind)
	var path := Wardrobe.ROOT + String(kind) + ".glb"

	if data.is_empty() or not ResourceLoader.exists(path):
		return out

	var scene: Node3D = (load(MALE) as PackedScene).instantiate()
	add_child(scene)
	var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var body: MeshInstance3D = null

	for child in skeleton.get_children():
		if child is MeshInstance3D and (body == null or (child as MeshInstance3D).mesh.get_faces().size() > body.mesh.get_faces().size()):
			body = child

	var part: Node3D = (load(path) as PackedScene).instantiate()
	var part_skeleton := part.find_child("Skeleton3D", true, false) as Skeleton3D
	var part_mesh := part.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var extra := PackedStringArray()

	for i in range(part_skeleton.get_bone_count()):
		if skeleton.find_bone(part_skeleton.get_bone_name(i)) < 0:
			extra.append(part_skeleton.get_bone_name(i))

	Wardrobe.add_bones(skeleton, part_skeleton, extra)
	var outfit := MeshInstance3D.new()
	outfit.mesh = part_mesh.mesh
	outfit.skin = Wardrobe.rebind(part_mesh.skin, part_skeleton, skeleton)
	skeleton.add_child(outfit)
	outfit.skeleton = NodePath("..")
	part.free()
	await _frames(2)

	var rest_outfit := _skinned(outfit, skeleton)
	var rest_body := _skinned(body, skeleton)
	var pairs := []
	var rest_err := 0.0

	for probe in data.get("probe", []):
		var want := Vector3(probe.rest[0], probe.rest[1], probe.rest[2])
		var near := Vector3(probe.near_body[0], probe.near_body[1], probe.near_body[2])
		var i := _nearest(rest_outfit, want)
		var j := _nearest(rest_body, near)
		rest_err = maxf(rest_err, rest_outfit[i].distance_to(want))
		pairs.append([i, j, rest_outfit[i].distance_to(rest_body[j])])

	_pose(skeleton, &"Sword_Attack", 0.3)
	var posed_outfit := _skinned(outfit, skeleton)
	var posed_body := _skinned(body, skeleton)
	var pose_err := 0.0

	for pair in pairs:
		pose_err = maxf(pose_err, absf(posed_outfit[pair[0]].distance_to(posed_body[pair[1]]) - pair[2]))

	scene.queue_free()
	await _frames(1)
	return {"rest": rest_err, "pose": pose_err, "count": pairs.size()}


func _nearest(points: PackedVector3Array, to: Vector3) -> int:
	var best := 0

	for i in range(points.size()):
		if points[i].distance_squared_to(to) < points[best].distance_squared_to(to):
			best = i

	return best


## One frame of an animation of the library, laid straight onto `skeleton`.
func _pose(skeleton: Skeleton3D, animation: StringName, time: float) -> void:
	var clip: Animation = HumanoidScript.library().get_animation(animation)

	for t in range(clip.get_track_count()):
		var path := clip.track_get_path(t)

		if path.get_subname_count() == 0:
			continue

		var bone := skeleton.find_bone(path.get_subname(0))

		if bone < 0:
			continue

		match clip.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, clip.rotation_track_interpolate(t, time))
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone, clip.position_track_interpolate(t, time))
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(bone, clip.scale_track_interpolate(t, time))


# ---------------------------------------------------------------------------
# K1, K1b, K1c, K2, K10: dressed guards
# ---------------------------------------------------------------------------

var _spawned := 0


## A guard of `archetype` (the plain watchman by default) with `seed` as his
## look, placed before he enters the tree, given a few frames to dress.
func _guard(seed: int, archetype: StringName = &"") -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.set("look_seed", seed)
	_spawned += 1
	g.position = Vector3(-30 + (_spawned % 12) * 5.0, 0.0, -30 + (_spawned / 12) * 5.0)
	add_child(g)
	await _frames(5)
	return g


func _worn_names(man: Node) -> Array:
	return man.worn().map(func(m): return String(m.name))


## The mesh he wears by that name, or null.
func _worn(man: Node, piece: String) -> MeshInstance3D:
	for m in man.worn():
		if String(m.name) == piece:
			return m

	return null


## The next guard of `kind` dresses from its JSON with `changes` merged into
## its options (Wardrobe's JSON cache, keyed by full path, doctored);
## Wardrobe.forget() undoes it. A GLB under user:// cannot be loaded
## unimported, so fixtures doctor data, never files.
func _doctor(kind: StringName, changes: Dictionary) -> void:
	var data: Dictionary = Wardrobe.kind_data(kind).duplicate(true)
	var options: Dictionary = data.get("options", {})
	options.merge(changes, true)
	data["options"] = options
	Wardrobe._json[Wardrobe.ROOT + "%s.json" % kind] = data


## As if `kind` had no files: it cannot be dressed until Wardrobe.forget().
func _doctor_missing(kind: StringName) -> void:
	Wardrobe._json[Wardrobe.ROOT + "%s.json" % kind] = {}


## The bones from `bone` down, as the severed piece would take them.
func _bones_under(g: Node, bone: StringName) -> PackedInt32Array:
	var man = g._rig.man
	return PackedInt32Array(man._bones_under(man.skeleton.find_bone(bone)))


## Whether steel answers a blow at `bone`'s joint (as K9 asks).
func _rings(g: Node, bone: StringName) -> bool:
	var man = g._rig.man
	return man.armour_near(man.bone_global(bone).origin) != null


## A point of EXPECT's rings/silent lists on his body.
func _point(man: Node, g: Node, spec: Array) -> Vector3:
	if spec[1] is StringName:
		return (man.bone_global(spec[0]).origin + man.bone_global(spec[1]).origin) * 0.5

	return man.bone_global(spec[0]).origin + Vector3.UP * float(spec[1]) - g.global_basis.z * float(spec[2])


## The attacks K5 drives for an archetype: its own (the watchman: kick and lunge).
func _attacks_of(archetype: StringName) -> Array:
	if archetype == &"":
		return [&"kick", &"lunge"]

	return (GuardFighterScript.ARCHETYPES[archetype]["attacks"] as Dictionary).keys()


## True when no two entries of `list` are the same object.
func _distinct(list: Array) -> bool:
	for i in range(list.size()):
		for j in range(i + 1, list.size()):
			if list[i] == list[j]:
				return false

	return true


func _dressed() -> void:
	var first := {}

	for kind in DRESSED:
		var archetype: StringName = DRESSED[kind]
		var expect: Dictionary = EXPECT[kind]
		# K1 he dresses in the wardrobe, nothing of the base body left
		var g := await _guard(3, archetype)
		var man = g._rig.man
		first[kind] = g
		var names := _worn_names(man)
		var bare := names.any(func(n): return n in ["SuperHero_Male", "SuperHero_Female", "Eyes", "Eyebrows", "Boots"])
		var layered: bool = man.worn().all(func(m): return m.layers == Layers.ACTORS)
		_check("K1 %s: dressed in everything his kind wears; no base body" % kind,
			man.body != null and man.body.name == "Outfit" and expect.worn.all(func(n): return n in names) and not bare and layered, str(names))

		# K14 his headgear wears a dirt mask: how dirty he rolled reaches it
		var masked := {}

		for worn in man.worn():
			if Wardrobe.headgear_data(StringName(worn.name)).is_empty():
				continue

			for surface in range(worn.mesh.get_surface_count()):
				var mat := worn.get_surface_override_material(surface) as ShaderMaterial
				var mask: Texture2D = mat.get_shader_parameter("mask") if mat != null else null
				masked["%s/%d" % [worn.name, surface]] = mask != null and mask.get_width() > 1

		if not Wardrobe.kind_data(kind).get("options", {}).get("headgear", [[]]).all(func(pieces): return pieces.is_empty()):
			_check("K14 %s: his headgear wears a dirt mask, so his grime reaches it" % kind,
				not masked.is_empty() and not masked.values().has(false), str(masked))

		# K2 every worn triangle counted
		var tris: int = man.worn().reduce(func(n, m): return n + m.mesh.get_faces().size() / 3, 0)
		_check("K2 %s: at most 3,000 triangles" % kind, tris <= 3000 and tris > 0, "tris %d" % tris)

		# K10 same seed, same man; four seeds, not four clones; his silhouette always
		var twin := await _guard(3, archetype)
		var looks := {}
		var keyed := true
		# What must not vary (one man: the arms master's face, hair, beard).
		var kept := {}

		for s in [1, 2, 3, 4]:
			var w := await _guard(s, archetype)
			looks[str(w._rig.man.look)] = true
			keyed = keyed and expect.key.all(func(n): return n in _worn_names(w._rig.man))

			for key in expect.get("same", []):
				kept[key] = kept.get(key, {}).merged({str(w._rig.man.look.get(key)): true})

		var same: bool = kept.values().all(func(values): return values.size() == 1)
		_check("K10 %s: the same seed makes the same man, four seeds at least two looks, his silhouette always" % kind,
			not man.look.is_empty() and str(twin._rig.man.look) == str(man.look)
			and _carries_look(man.body, man.look) and _carries_look(twin._rig.man.body, twin._rig.man.look)
			and looks.size() >= 2 and keyed and same, "distinct %d same %s look %s" % [looks.size(), kept, man.look])

		# K1d the strips are drawn from both sides, the rest culls
		var shaders := []

		for surface in range(man.body.mesh.get_surface_count()):
			var worn := man.body.get_surface_override_material(surface) as ShaderMaterial
			shaders.append(worn.shader.resource_path.get_file() if worn != null else "none")

		_check("K1d %s: the outfit's cloth strips are drawn from both sides, its closed parts cull their backs" % kind,
			shaders.has(Wardrobe.SHADER_TWO_SIDED.resource_path.get_file()) and shaders.has(Wardrobe.SHADER.resource_path.get_file()),
			str(shaders))

	# K17 a kind without headgear dresses, whether its options say one empty
	# set ([[]]) or no sets at all ([]) (the watchman, doctored)
	var bares := []

	for none in [[[]], []]:
		_doctor(&"watchman", {"headgear": none})
		var bared := await _guard(3)
		var bare_names := _worn_names(bared._rig.man)
		Wardrobe.forget()
		bares.append(bared._rig.man.body != null and bared._rig.man.body.name == "Outfit"
			and bared._rig.man.look.get("headgear", [&"?"]).is_empty() and bare_names.all(func(n): return n in ["Outfit", "Head_weathered"]))

	_check("K17 a kind with no headgear dresses ([[]] or [])", not bares.has(false), str(bares))

	# K18 hair and beard are worn and tinted his hair colour (the watchman,
	# doctored bare-headed and old)
	_doctor(&"watchman", {"faces": ["old"], "tones": ["light"], "hair": ["parted"], "beards": ["full"],
		"hair_colours": [[0.72, 0.70, 0.66]], "headgear": [[]]})
	var old := await _guard(7)
	var aged = old._rig.man
	Wardrobe.forget()
	var hair := _worn(aged, "Hair_parted")
	var beard := _worn(aged, "Beard_full")
	var tinted: bool = hair != null and beard != null \
		and hair.get_instance_shader_parameter(&"dye_colour").is_equal_approx(aged.look.hair_colour) \
		and beard.get_instance_shader_parameter(&"dye_colour").is_equal_approx(aged.look.hair_colour)
	_check("K18 his hair and beard are worn and tinted his hair colour", "Head_old" in _worn_names(aged) and tinted,
		str(_worn_names(aged)))

	if DRESSED.has(&"archer"):
		# K16b a squad of archers wears more than one colour, hood and tunic alike
		var dyes := {}
		var matched := true

		for s in range(1, 9):
			var a := await _guard(s, &"archer")
			# (Unset on a painted fallback: null.)
			var tunic = a._rig.man.body.get_instance_shader_parameter(&"dye_colour")
			var hood := _worn(a._rig.man, "hood")
			matched = matched and tunic is Color and hood != null and tunic.is_equal_approx(hood.get_instance_shader_parameter(&"dye_colour"))

			if tunic is Color:
				dyes[snappedf(tunic.h, 0.02)] = true

		_check("K16b archers roll green, brown or grey, hood and tunic the same", dyes.size() >= 2 and matched, str(dyes.keys()))

		# K16c a kind whose dye is a list of colours was baked in the first:
		# his outfit's dye base is that (white would darken every dyed texel)
		var archer := await _guard(3, &"archer")
		var worn := archer._rig.man.body.get_surface_override_material(0) as ShaderMaterial
		var base = worn.get_shader_parameter(&"dye_base") if worn != null else null
		_check("K16c his outfit's dye base is the first of his kind's dye colours", base is Color
			and base.is_equal_approx(Color(0.20, 0.30, 0.14)), str(base))

	var g: CharacterBody3D = first[&"watchman"]
	var man = g._rig.man

	# K1b (Review Focus 3) a missing option is dropped; missing kind files: still a watchman, painted, kettle hat on
	var kept: Dictionary = Wardrobe.usable_options({"faces": [&"weathered", &"nobody"], "tones": [&"light"], "hair": [], "beards": [],
		"headgear": [[&"kettlehat", &"coif"], [&"nothing"]], "dye": {"colour": [0.62, 0.52, 0.16], "shift": 0.04, "fade": [0.0, 0.35]},
		"grime": [0.2, 0.8]})
	Wardrobe.ROOT = "user://no_wardrobe/"
	Wardrobe.forget()
	var painted := await _guard(5)
	_check("K1b missing options are dropped; without wardrobe files the watchman falls back to the painted look",
		kept.get("faces", []) == [&"weathered"] and kept.get("headgear", []).size() == 1
		and painted._rig.man.body.material_override is StandardMaterial3D
		and painted._rig.man.armour.any(func(a): return a.name == "kettlehat"), "kept %s" % kept)
	Wardrobe.ROOT = "res://assets/characters/wardrobe/"
	Wardrobe.forget()

	# K1c (Review Focus 1) a mixed squad: shared within a kind, never across kinds
	var squad := {}

	for kind in DRESSED:
		squad[kind] = [await _guard(51, DRESSED[kind]), await _guard(52, DRESSED[kind])]

	var within: bool = squad.values().all(func(p): return (p[0]._rig.man.body.mesh == p[1]._rig.man.body.mesh
		and p[0]._rig.man.body.skin == p[1]._rig.man.body.skin and p[0]._rig.man.body.get_surface_override_material(0) != null
		and p[0]._rig.man.body.get_surface_override_material(0) == p[1]._rig.man.body.get_surface_override_material(0)))
	var shared: Array = squad.values().map(func(p): return p[0]._rig.man.body.get_surface_override_material(0))
	var meshes: Array = squad.values().map(func(p): return p[0]._rig.man.body.mesh)
	_check("K1c every kind shares its own mesh, skin and material, and no two kinds share one",
		within and _distinct(shared) and _distinct(meshes), "%d kinds" % squad.size())

	# K1b (Review Focus 2) one kind's files gone: that kind alone falls back to
	# its own painted look
	_doctor_missing(&"swordsman")
	var sw := await _guard(53, &"swordsman")
	var ar := await _guard(54, &"archer")
	Wardrobe.forget()
	_check("K1b a swordsman without files is painted, with his own helm; the archer still dresses",
		sw._rig.man.body.material_override is StandardMaterial3D and sw._rig.man.armour.any(func(a): return a.name == "nasalhelm")
		and ar._rig.man.body.name == "Outfit", "")

	for x in [g, painted, sw, ar]:
		x.queue_free()

	for child in get_children():
		if child is CharacterBody3D:
			child.queue_free()

	await _frames(3)


# ---------------------------------------------------------------------------
# K-order, K4, K4b, K5, K6, K6b, K12: cloth
# ---------------------------------------------------------------------------

## Markers that follow his bones as drawn (bone attachments see the cloth's
## simulation; plain bone reads do not): each chain's hem and every joint
## of it, his pelvis, thighs and calves.
func _watch(man: Node, kind: StringName = &"watchman") -> Dictionary:
	var skeleton: Skeleton3D = man.skeleton
	var out := {"tips": {}, "joints": [], "legs": {}, "anchors": {}}
	var chains: Array = Wardrobe.kind_data(kind).get("cloth", []).duplicate()

	for piece in man.look.get("headgear", []):
		chains += Wardrobe.headgear_data(piece).get("cloth", [])

	for chain in chains:
		var last := _marker(skeleton, chain.bones[-1], Vector3(0.0, float(chain.tip), 0.0))
		out.tips[chain.chain] = last

		# Every joint (a skirt's middle one pokes a thigh as readily as its
		# hem), each with the chain's name for the report.
		for bone in chain.bones:
			out.joints.append([chain.chain, _marker(skeleton, bone, Vector3.ZERO)])

		out.joints.append([chain.chain, last])

	out.pelvis = _marker(skeleton, &"pelvis", Vector3.ZERO)

	# The bone each chain hangs from: his pelvis, or (a hood's tail) his head.
	for chain in chains:
		var parent := String(chain.get("parent", "pelvis"))
		out.anchors[chain.chain] = out.pelvis if parent == "pelvis" else _marker(skeleton, parent, Vector3.ZERO)

	for leg in [&"thigh_l", &"thigh_r", &"calf_l", &"calf_r"]:
		out.legs[leg] = _marker(skeleton, leg, Vector3.ZERO)

	return out


func _marker(skeleton: Skeleton3D, bone: String, offset: Vector3) -> Node3D:
	var holder := BoneAttachment3D.new()
	holder.bone_name = bone
	skeleton.add_child(holder)
	var mark := Node3D.new()
	holder.add_child(mark)
	mark.position = offset
	return mark


## Each hem in the frame of the bone its chain hangs from (his pelvis; a
## hood's tail, his head): whatever he does (turn, fall, get up, whip his
## head round), a hem that simply rode with that bone would not move here;
## only the cloth's own swing does.
func _hems(w: Dictionary) -> Dictionary:
	var out := {}

	for chain in w.tips:
		var frame := (w.anchors.get(chain, w.pelvis) as Node3D).global_transform.affine_inverse()
		out[chain] = frame * (w.tips[chain] as Node3D).global_position

	return out


## The fastest any hem moved relative to him between two readings `dt` apart.
func _fastest(a: Dictionary, b: Dictionary, dt: float) -> float:
	var top := 0.0

	for chain in a:
		top = maxf(top, (b[chain] - a[chain]).length() / maxf(dt, 1e-6))

	return top


## Frames still to skip after his body itself popped (his pelvis moved more
## than 25 cm in one frame: a physics handover, not his cloth): the cloth
## follows a popping body; these checks judge the cloth. 3 frames a pop.
func _popped(w: Dictionary, hips_before: Vector3, owed: int) -> int:
	if (w.pelvis as Node3D).global_position.distance_to(hips_before) > 0.25:
		return 3

	return maxi(owed - 1, 0)


## His fallen body at rest where it lies: every part of his ragdoll asleep.
func _rest(man: Node) -> void:
	for part in man.ragdoll.bodies():
		PhysicsServer3D.body_set_state((part as PhysicalBone3D).get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING, true)


## How low his lowest hem is (world height).
func _lowest(w: Dictionary) -> float:
	var low := INF

	for chain in w.tips:
		low = minf(low, (w.tips[chain] as Node3D).global_position.y)

	return low


func _finite(h: Dictionary) -> bool:
	return h.values().all(func(v): return v.is_finite())


## One frame of his own animation and cloth, `dt` of game time.
## How far his hems travel in his own frame (summed over them) in `frames`
## real frames, his rig kept at the game's pace.
func _travel(g: Node, w: Dictionary, frames: int) -> float:
	var total := 0.0
	var last := _hems(w)

	for i in range(frames):
		await _step(g, Engine.time_scale / 60.0)
		var now := _hems(w)

		for chain in now:
			total += (now[chain] - last[chain]).length()

		last = now

	return total


func _step(g: Node, dt: float) -> void:
	g._rig.update(dt)
	await get_tree().process_frame


## K21 and K22, the swordsman's own cloth and plate.
func _layers_and_plates(g: Node, w: Dictionary, man: Node) -> void:
	var dt := 1.0 / 60.0
	# K21 (Review Focus 3) the surcoat never swings through the mail skirt:
	# through a run, a stop and a kick, where the mail skirt's front hem is (a
	# vertex of it, where his skin puts it), the surcoat hangs in front of it
	var fwd: Vector3 = -g.global_basis.z
	var hem := _vertex_on(man.body, man.skeleton, func(p): return absf(p.x) < 0.002 and p.z > 0.05, MAIL_SKIRT_HEM)
	var line := _chain_line(man, &"surcoat_front")
	var worst_behind := -INF
	var phases := {"run": -INF, "stop": -INF, "kick": -INF}

	for i in range(150):
		if i < 60:
			g.velocity = fwd * 3.2
			g.global_position += g.velocity * dt
		elif i < 120:
			g.velocity = Vector3.ZERO
		else:
			g._phase = &"strike"
			g._attack = &"kick"
			g._phase_length = 0.5
			g._phase_timer = 0.5 * (1.0 - (i - 120) / 29.0)

		await _step(g, dt)

		if not hem.is_empty() and not line.is_empty():
			var behind := _in_front_of(_skin_one(hem), line, fwd)
			var phase := "run" if i < 60 else ("stop" if i < 120 else "kick")
			phases[phase] = maxf(phases[phase], behind)
			worst_behind = maxf(worst_behind, behind)

	g._phase = &""
	_check("K21 through a run, a stop and a kick his surcoat stays over his mail skirt", not hem.is_empty() and not line.is_empty()
		and worst_behind <= 0.01, "%.3f m (run %.3f stop %.3f kick %.3f)" % [worst_behind, phases.run, phases.stop, phases.kick])

	# K22 (Review Focus 4) overhead, his pauldrons stay out of his head
	var plates := _pauldron_vertices(man.body)
	var head: int = man.skeleton.find_bone(&"Head")
	var nearest := INF

	for i in range(30):
		g._phase = &"strike"
		g._attack = &"overhead"
		g._phase_length = 0.5
		g._phase_timer = 0.5 * (1.0 - i / 29.0)
		await _step(g, dt)
		var skinned := _skinned(man.body, man.skeleton)
		var at: Vector3 = man.skeleton.get_bone_global_pose(head).origin

		for index in plates:
			nearest = minf(nearest, skinned[index].distance_to(at))

	g._phase = &""
	# (On the wardrobe's outfit: a painted body's own arms would pass.)
	_check("K22 his pauldrons clear his head through an overhead strike", man.body.name == "Outfit" and not plates.is_empty()
		and nearest >= 0.10, "%.3f m (%d plate vertices on %s)" % [nearest, plates.size(), man.body.name])

	for i in range(90):
		await _step(g, dt)


## The swordsman's mail skirt's hem (recipes.SWORDSMAN mail_skirt: calf_l
## 0.05 down, in the game's frame).
const MAIL_SKIRT_HEM := 0.519


## One vertex of `mi` to follow as his skin moves it (_skin_one): of those
## `pick` takes (by rest position), the one resting nearest height `y`. Its
## bones are followed by attachments (bone reads miss the cloth's pose).
func _vertex_on(mi: MeshInstance3D, skeleton: Skeleton3D, pick: Callable, y: float) -> Dictionary:
	var best := {}
	var gap := INF

	for s in range(mi.mesh.get_surface_count()):
		var arrays := mi.mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(vertices.size(), 1)

		for v in range(vertices.size()):
			if not pick.call(vertices[v]) or absf(vertices[v].y - y) >= gap:
				continue

			gap = absf(vertices[v].y - y)
			var binds := []

			for k in range(per):
				if weights[v * per + k] > 0.0:
					binds.append([String(mi.skin.get_bind_name(bones[v * per + k])), mi.skin.get_bind_pose(bones[v * per + k]),
						weights[v * per + k]])

			best = {"rest": vertices[v], "binds": binds}

	if best.is_empty():
		return best

	for bind in best.binds:
		bind[0] = _marker(skeleton, bind[0], Vector3.ZERO).get_parent()

	return best


## Where his skin puts a vertex from _vertex_on now (world).
func _skin_one(vertex: Dictionary) -> Vector3:
	var at := Vector3.ZERO

	for bind in vertex.binds:
		at += float(bind[2]) * ((bind[0] as Node3D).global_transform * (bind[1] as Transform3D) * (vertex.rest as Vector3))

	return at


## A chain's joints as simulated, root to hem (markers).
func _chain_line(man: Node, chain: StringName) -> Array:
	for kind in DRESSED:
		for c in Wardrobe.kind_data(kind).get("cloth", []):
			if StringName(c.chain) == chain:
				var out: Array = c.bones.map(func(b): return _marker(man.skeleton, b, Vector3.ZERO))
				out.append(_marker(man.skeleton, c.bones[-1], Vector3(0.0, float(c.tip), 0.0)))
				return out

	return []


## How far `point` stands in front (along `fwd`) of the chain `line` where
## the chain is at its height; -INF where the chain is not.
func _in_front_of(point: Vector3, line: Array, fwd: Vector3) -> float:
	for k in range(line.size() - 1):
		var a: Vector3 = (line[k] as Node3D).global_position
		var b: Vector3 = (line[k + 1] as Node3D).global_position

		if (a.y - point.y) * (b.y - point.y) <= 0.0 and absf(a.y - b.y) > 1e-5:
			return (point - a.lerp(b, (point.y - a.y) / (b.y - a.y))).dot(fwd)

	return -INF


## His pauldrons, as _skinned lists vertices (flat, surface by surface): the
## outfit's vertices wholly on an upper arm, resting above y = 1.42.
func _pauldron_vertices(mi: MeshInstance3D) -> PackedInt32Array:
	var out := PackedInt32Array()
	var flat := 0

	for s in range(mi.mesh.get_surface_count()):
		var arrays := mi.mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(vertices.size(), 1)

		for v in range(vertices.size()):
			for k in range(per):
				if weights[v * per + k] >= 0.99 and vertices[v].y > 1.42 \
						and String(mi.skin.get_bind_name(bones[v * per + k])).begins_with("upperarm"):
					out.append(flat + v)
					break

		flat += vertices.size()

	return out


func _cloth() -> void:
	for kind in DRESSED:
		await _cloth_kind(kind, DRESSED[kind])


func _cloth_kind(kind: StringName, archetype: StringName) -> void:
	var dt := 1.0 / 60.0

	# K-order the modifiers: Posture, then Ragdoll, then Cloth
	var g := await _guard(31, archetype)
	g.set_physics_process(false)
	var man = g._rig.man
	var order: bool = man.cloth != null and man.posture.get_index() < man.ragdoll.get_index() and man.ragdoll.get_index() < man.cloth.get_index()
	_check("K-order %s: his skeleton's modifiers run Posture, Ragdoll, Cloth" % kind, order,
		"posture %d ragdoll %d cloth %d" % [man.posture.get_index(), man.ragdoll.get_index(), man.cloth.get_index() if man.cloth else -1])

	# K4 a run and a sudden stop: the skirts swing, then settle
	var w := _watch(man, kind)

	for i in range(60):
		g.velocity = -g.global_basis.z * 3.2
		g.global_position += g.velocity * dt
		await _step(g, dt)

	g.velocity = Vector3.ZERO
	var start := _hems(w)
	var last := start
	var swing := 0.0
	var speed := INF
	var finite := true

	for i in range(90):
		await _step(g, dt)
		var now := _hems(w)
		finite = finite and _finite(now)

		for chain in now:
			swing = maxf(swing, (now[chain] - start[chain]).length())

		speed = _fastest(last, now, dt)
		last = now

	_check("K4 %s: after a run and a sudden stop the skirts swing at least 5 cm and settle within 1.5 s" % kind,
		finite and swing >= 0.05 and speed < 0.02, "swing %.3f end speed %.3f finite %s" % [swing, speed, finite])

	# K4b (Review Focus 1) slow motion mid-swing: the cloth slows with the
	# game (the same swing, in the same number of real frames, travels a
	# fraction as far), and nothing jumps when time resumes
	for i in range(30):
		g.velocity = -g.global_basis.z * 3.2
		g.global_position += g.velocity * dt
		await _step(g, dt)

	g.velocity = Vector3.ZERO
	var played := await _travel(g, w, 12)
	await _travel(g, w, 90)

	for i in range(30):
		g.velocity = -g.global_basis.z * 3.2
		g.global_position += g.velocity * dt
		await _step(g, dt)

	g.velocity = Vector3.ZERO
	TimeFx.request(get_tree(), &"wardrobe_test", 0.05, 0.5)
	var slowed := await _travel(g, w, 12)
	var real := 12 * dt

	while real < 0.6:
		await _step(g, dt * Engine.time_scale)
		real += dt

	TimeFx.clear()
	last = _hems(w)
	var burst := 0.0

	for i in range(10):
		await _step(g, dt)
		var now := _hems(w)
		burst = maxf(burst, _fastest(last, now, dt))
		last = now

	_check("K4b %s: in slow motion the cloth slows with the game, and after it no hem moves faster than 5 m/s" % kind,
		played > 0.02 and slowed < played * 0.25 and burst <= 5.0 and _finite(last),
		"12 frames: played %.3f m slowed %.3f m; after %.2f m/s" % [played, slowed, burst])

	# K5 (Review Focus 5) his own attacks: the cloth stays out of his legs.
	# A guard of his own (the one above has been through slow motion): a run
	# and a stop, then his attacks again and again after idles of different
	# lengths, as between exchanges (the stance's phase at a strike's first
	# frame decides how his legs meet his cloth); every joint of every chain.
	var worst := INF
	var where := ""

	# Two men of his kind (their height is rolled: a taller one's cloth
	# meets his legs otherwise).
	for seed in [31, 34]:
		var fighter := await _guard(seed, archetype)
		fighter.set_physics_process(false)
		var fw := _watch(fighter._rig.man, kind)
		var colliders := {}

		for c in Wardrobe.kind_data(kind).get("colliders", []):
			colliders[StringName(c.bone)] = c

		for i in range(60):
			fighter.velocity = -fighter.global_basis.z * 3.2
			fighter.global_position += fighter.velocity * dt
			await _step(fighter, dt)

		fighter.velocity = Vector3.ZERO

		for i in range(90):
			await _step(fighter, dt)

		for idle in [0, 23, 46, 69, 92]:
			fighter._phase = &""
			fighter._attack = &""

			for i in range(idle):
				await _step(fighter, dt)

			for attack in _attacks_of(archetype):
				for i in range(30):
					fighter._phase = &"strike"
					fighter._attack = attack
					fighter._phase_length = 0.5
					fighter._phase_timer = 0.5 * (1.0 - i / 29.0)
					await _step(fighter, dt)

					for leg in fw.legs:
						if not colliders.has(leg):
							continue

						var mark: Node3D = fw.legs[leg]
						var a := mark.global_position
						var b := a + mark.global_basis.y.normalized() * float(colliders[leg].height)

						for joint in fw.joints:
							var p: Vector3 = (joint[1] as Node3D).global_position
							var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 1e-6), 0.0, 1.0)
							var d := p.distance_to(a + (b - a) * t) - float(colliders[leg].radius)

							if d < worst:
								worst = d
								where = "%s in %s, %s frame %d after %d idle, seed %d" % [joint[0], leg, attack, i, idle, seed]

		fighter._phase = &""
		fighter.queue_free()

	var allowed: float = EXPECT[kind].get("k5", 0.005)
	_check("K5 %s: through his own attacks, again and again, no cloth joint enters a thigh or calf more than %.0f mm"
		% [kind, allowed * 1000.0], worst >= -allowed, "closest %.3f past the surface (%s)" % [worst, where])

	if kind == &"swordsman":
		await _layers_and_plates(g, w, man)

	# K12 moved 20 m in one frame: no whip (once the kick's swing has died)
	for i in range(90):
		await _step(g, dt)

	last = _hems(w)
	g.global_position += Vector3(20.0, 0.0, 0.0)
	var jump := 0.0

	for i in range(5):
		await _step(g, dt)
		var now := _hems(w)
		jump = maxf(jump, _fastest(last, now, dt))
		last = now

	# A restart hangs the cloth back at its own pose: a few-centimetre settle
	# in one frame. A whip is 60 m/s and more.
	_check("K12 %s: moved 20 m in one frame, he does not whip his cloth (< 3 m/s)" % kind, jump < 3.0, "fastest %.2f m/s" % jump)

	# K6 dead and limp: the tabard settles on his body without flying off
	var dead := await _guard(32, archetype)
	var corpse = dead._rig.man
	var dw := _watch(corpse, kind)
	# A guard that has stood a moment (his cloth hanging still), as any guard
	# someone kills has: dying moves him to his body, which starts his cloth
	# afresh where it hangs.
	await _frames(60)
	dead.die(null)
	# Dying moves him onto his body (GuardBody), which starts his cloth afresh
	# where it hangs: one frame's settle, then physics has him. From then on.
	await get_tree().physics_frame
	last = _hems(dw)
	var wild := 0.0
	var hips := (dw.pelvis as Node3D).global_position
	var popped := 0

	for i in range(150):
		await get_tree().physics_frame
		var now := _hems(dw)
		popped = _popped(dw, hips, popped)
		hips = (dw.pelvis as Node3D).global_position

		if popped == 0:
			wild = maxf(wild, _fastest(last, now, dt))

		last = now

	# Settling is his cloth's once his body is at rest. A fallen body comes to
	# rest in its own time (some shiver on for many seconds: a ragdoll matter,
	# not the cloth's), so here it is put to rest where it lies, and from then
	# his cloth has half a second.
	_rest(corpse)

	for i in range(30):
		await get_tree().physics_frame
		var now := _hems(dw)
		speed = _fastest(last, now, dt)
		last = now

	# A body hitting the floor swings its cloth at up to ~9 m/s for a few
	# frames; flying apart is far faster (or NaN). Settled, it lies on the
	# floor (the floor's top is y = 0 here), not through it.
	var lowest := _lowest(dw)
	var crept := (dw.pelvis as Node3D).global_position.distance_to(hips)
	_check("K6 %s: on a limp body the cloth never flies (<= 12 m/s), settles (< 5 cm/s) within half a second of his body resting, and lies on the floor" % kind,
		wild <= 12.0 and speed < 0.05 and lowest >= -0.02 and crept < 0.005,
		"fastest %.2f settled to %.3f (his body moved %.4f at rest) lowest hem %.3f" % [wild, speed, crept, lowest])

	# K6b (Review Focus 2) knocked down and getting up: no whip, no NaN
	var down := await _guard(33, archetype)
	var kw := _watch(down._rig.man, kind)
	await _frames(2)
	down.knock_down(down.global_basis.z * 4.0)
	last = _hems(kw)
	wild = 0.0
	finite = true
	var frames := 0

	hips = (kw.pelvis as Node3D).global_position
	var pops := 0
	var in_pops := 0.0
	var floor_low := INF

	# Every frame counts but the one his body itself is put elsewhere in
	# (the rig's 2 m pop at getting up: its own task): the cloth goes with
	# him then, and must not whip after.
	while frames < 300 and (frames < 30 or down.get("_downed") or float(down.get("_rising")) > 0.0):
		await get_tree().physics_frame
		var now := _hems(kw)
		finite = finite and _finite(now)
		var put := (kw.pelvis as Node3D).global_position.distance_to(hips) > 0.25
		hips = (kw.pelvis as Node3D).global_position
		var fastest := _fastest(last, now, dt)

		# Down a second (settled on the floor): his cloth lies on it.
		if down.get("_downed") and frames > 60:
			floor_low = minf(floor_low, _lowest(kw))

		if put:
			pops += 1
			in_pops = maxf(in_pops, fastest)
		else:
			wild = maxf(wild, fastest)

		last = now
		frames += 1

	_check("K6b %s: knocked down and back up, his cloth stays sane (<= 12 m/s, no NaN), every frame after his body's pop too, on the floor while down" % kind,
		finite and wild <= 12.0 and not down.get("_downed") and floor_low >= -0.02 and floor_low < INF,
		"fastest %.2f (the pop frames themselves: %d, %.2f) lowest hem down %.3f frames %d still down %s"
		% [wild, pops, in_pops, floor_low, frames, down.get("_downed")])

	for x in [g, dead, down]:
		if is_instance_valid(x):
			x.queue_free()

	for child in get_children():
		if child is CharacterBody3D or child is RigidBody3D:
			child.queue_free()

	await _frames(3)


# ---------------------------------------------------------------------------
# K7, K7b, K8, K9, K11: dismemberment, hit flash, armour, your arms
# ---------------------------------------------------------------------------

## The meshes a severed piece carries (its copy of his skeleton's children).
func _piece_meshes(piece: Node) -> Array:
	var copy := piece.get_node_or_null("Skeleton3D")
	return [] if copy == null else copy.get_children().filter(func(n): return n is MeshInstance3D).map(func(n): return String(n.name))


func _integration() -> void:
	for kind in DRESSED:
		await _integration_kind(kind, DRESSED[kind])

	# K19 a severed part takes exactly the worn meshes weighted to its bones
	var g := await _guard(43)
	var weighted: Array = g._rig.man.weighted_meshes(_bones_under(g, &"thigh_l")).map(func(m): return String(m.name)) \
		if g._rig.man.has_method("weighted_meshes") else ["(no weighted_meshes)"]
	_check("K19 a leg takes what is weighted to it: his outfit, not his head or gear", weighted == ["Outfit"], str(weighted))

	# K20 a severed leg's cloth capsules go with it (his man outlives the
	# guard: dying hands him to his body)
	var man = g._rig.man
	g.die(null)
	await _frames(5)
	man.sever(&"thigh_l", Vector3.RIGHT)
	await _frames(2)
	var left: Array = man.cloth.get_children().map(func(c): return String(c.name))
	_check("K20 a severed leg no longer props his skirts", not ("Keep_thigh_l" in left) and not ("Keep_calf_l" in left) and "Keep_thigh_r" in left,
		str(left))

	# K11 your arms are untouched: painted, no cloth, no outfit
	var player: Node = PLAYER.instantiate()
	player.position = Vector3(20, 0, 20)
	add_child(player)
	await _frames(5)
	var arms: Node = null

	for node in player.find_children("*", "", true, false):
		var script: Script = node.get_script()

		if script != null and script.resource_path.ends_with("ViewArms.gd"):
			arms = node.get("man")

	var painted := false
	var bare := false

	if arms != null and arms.body != null:
		var material: Variant = arms.body.material_override
		painted = material is StandardMaterial3D and (material as StandardMaterial3D).albedo_texture != null \
			and (material as StandardMaterial3D).albedo_texture.resource_path.ends_with("T_player.png")
		bare = arms.cloth == null and arms.skeleton.get_node_or_null("Outfit") == null

	_check("K11 your first-person arms stay painted, without cloth or an outfit", painted and bare, "arms %s painted %s bare %s" % [arms != null, painted, bare])

	for x in [g, player]:
		if is_instance_valid(x):
			x.queue_free()

	for child in get_children():
		if child is CharacterBody3D or child is RigidBody3D:
			child.queue_free()

	await _frames(3)


func _integration_kind(kind: StringName, archetype: StringName) -> void:
	var expect: Dictionary = EXPECT[kind]
	# K7 cut apart: his head takes its face and gear, his leg its part of the outfit
	var g := await _guard(41, archetype)
	var man = g._rig.man
	g.die(null)
	await _frames(10)
	var head: Node = man.sever(&"neck_01", Vector3(0, 2, 1))
	var leg: Node = man.sever(&"thigh_l", Vector3(1, 1, 0))
	await _frames(2)
	var in_head := _piece_meshes(head) if head else []
	var in_leg := _piece_meshes(leg) if leg else []
	var skeleton: Skeleton3D = man.skeleton
	var under_leg: Array = man._bones_under(skeleton.find_bone(&"thigh_l")).map(func(b): return skeleton.get_bone_name(b))
	var cloth_on_leg: bool = under_leg.any(func(n): return String(n).begins_with("cloth_"))
	var last_word: bool = man.severed != null and man.cloth != null and man.severed.get_index() > man.cloth.get_index()
	var head_items: Array = expect.worn.filter(func(n): return n != "Outfit")
	_check("K7 %s: a severed head takes his face and headgear; a leg its outfit; cloth stays on him; Severed runs last" % kind,
		head_items.all(func(n): return n in in_head)
		and "Outfit" in in_leg and not head_items.any(func(n): return n in in_leg)
		and not cloth_on_leg and man.severed != null and &"neck_01" in man.severed.bones and &"thigh_l" in man.severed.bones and last_word,
		"head %s leg %s cloth on leg %s last %s" % [in_head, in_leg, cloth_on_leg, last_word])

	# K7b (Review Focus 5) the severed leg and head keep his colours: every
	# piece they carry has his look set, not merely equal to his (unset reads
	# back null on both)
	var copies := []

	for piece in [leg, head]:
		if piece:
			copies += piece.get_node("Skeleton3D").get_children().filter(func(n): return n is MeshInstance3D)

	var kept: Array = copies.map(func(c): return _carries_look(c, man.look))
	_check("K7b %s: a severed part keeps his dye, fading, skin and dirt" % kind, copies.size() >= head_items.size() + 1 and not kept.has(false),
		"%s" % [copies.map(func(c): return String(c.name))])

	# K8 the hit flash covers everything he wears
	var h := await _guard(42, archetype)
	var rig = h._rig
	rig.react_hit(h.global_basis.z, 1.0)
	rig.update(1.0 / 60.0)
	var lit: bool = rig.man.worn().all(func(m): return m.material_overlay == rig._overlay)

	for i in range(36):
		rig.update(1.0 / 60.0)
		await get_tree().physics_frame

	var cleared: bool = rig.man.worn().all(func(m): return m.material_overlay != rig._overlay)
	_check("K8 %s: a hit flashes on every mesh he wears, and clears" % kind, lit and cleared, "lit %s cleared %s worn %d" % [lit, cleared, rig.man.worn().size()])

	# K9 steel rings where he wears it, and nowhere else
	var am = rig.man
	var rings: Array = expect.rings.map(func(spec): return am.armour_near(_point(am, h, spec)) != null)
	var silent: Array = expect.silent.map(func(spec): return am.armour_near(_point(am, h, spec)) == null)
	var metal_ok: bool = expect.metal.keys().all(func(bone): return am.metal.get(bone) != null and String(am.metal[bone].name) == expect.metal[bone])
	_check("K9 %s: steel rings where he wears it, and nowhere else" % kind, not rings.has(false) and not silent.has(false) and metal_ok,
		"rings %s silent %s metal %s" % [rings, silent, metal_ok])

	# K9b steel rings on his chest, back and shoulders; not on his calves
	if kind == &"swordsman":
		_check("K9b a swordsman's mail and pauldrons ring", _rings(h, &"spine_02") and _rings(h, &"upperarm_l") and not _rings(h, &"calf_l"), "")

	for x in [g, h]:
		if is_instance_valid(x):
			x.queue_free()

	for child in get_children():
		if child is CharacterBody3D or child is RigidBody3D:
			child.queue_free()

	await _frames(3)


# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])


## Whether every frame is a fixed 60th of a second (run with --fixed-fps 60,
## as the suites are meant to be run). Some checks here look at what is drawn
## frame by frame; without it the machine's own frame rate decides how many
## physics ticks fall in a frame, and those checks do not hold.
func _paced() -> bool:
	for i in 3:
		await get_tree().process_frame

		if not is_equal_approx(get_process_delta_time(), 1.0 / 60.0):
			return false

	return true
