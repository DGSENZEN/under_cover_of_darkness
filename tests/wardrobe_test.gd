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

const MALE := "res://assets/characters/base/Superhero_Male_FullBody.gltf"

var results: Array[String] = []


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
	await _k3a()
	_k10a()
	_k2a()
	await _k3()
	await _k1_k2_k10()
	await _cloth()
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
	_check("K10a the variety roll is repeatable, ranged and stable; the shader has its uniforms",
		same and seen.size() >= 2 and ranged and steady and "albedo" in names and "mask" in names and "dye_base" in names and sided,
		"same %s distinct %d ranged %s steady %s uniforms %s two-sided %s" % [same, seen.size(), ranged, steady, names, sided])


# ---------------------------------------------------------------------------
# K2a, K3: the baked, exported parts
# ---------------------------------------------------------------------------

func _k2a() -> void:
	# K2a the files keep the PS2 budgets
	var sizes := {"watchman": 256, "watchman_mask": 256, "heads/weathered_light": 128, "heads/weathered_dark": 128,
		"headgear/kettlehat": 128, "headgear/coif": 128}
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
		var fits: bool = img.get_width() == sizes[f] and img.get_height() == sizes[f] and (f.ends_with("_mask") or colours <= 64)
		ok = ok and fits
		why.append("%s %dx%d %d" % [f, img.get_width(), img.get_height(), colours])

	var tris := int(Wardrobe.kind_data(&"watchman").get("triangles", 99999)) + int(Wardrobe.head_data(&"weathered").get("triangles", 99999)) \
		+ int(Wardrobe.headgear_data(&"kettlehat").get("triangles", 99999)) + int(Wardrobe.headgear_data(&"coif").get("triangles", 99999))
	_check("K2a baked parts: 256/128 textures, at most 64 colours, at most 3,000 triangles", ok and tris <= 3000, "%s tris %d" % [why, tris])


func _colour_count(img: Image) -> int:
	var seen := {}

	for y in range(img.get_height()):
		for x in range(img.get_width()):
			seen[img.get_pixel(x, y).to_rgba32() >> 8] = true

	return seen.size()


func _k3() -> void:
	# K3 (spec K3, male body) the exported watchman re-binds exactly onto the game skeleton
	var errs := await _probe_errors(&"watchman")
	_check("K3 exported watchman: probes within 1 mm at rest, within 3 cm of the body mid-swing",
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


## A watchman (the default guard) with `seed` as his look, placed before he
## enters the tree, given a few frames to dress.
func _guard(seed: int) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = &""
	g.set("look_seed", seed)
	_spawned += 1
	g.position = Vector3(-30 + (_spawned % 12) * 5.0, 0.0, -30 + (_spawned / 12) * 5.0)
	add_child(g)
	await _frames(5)
	return g


func _worn_names(man: Node) -> Array:
	return man.worn().map(func(m): return String(m.name))


func _k1_k2_k10() -> void:
	# K1 a watchman dresses in the wardrobe, nothing of the base body left
	var g := await _guard(3)
	var man = g._rig.man
	var names := _worn_names(man)
	var bare := names.any(func(n): return n in ["SuperHero_Male", "Eyes", "Eyebrows", "Boots"])
	var layered: bool = man.worn().all(func(m): return m.layers == Layers.ACTORS)
	_check("K1 the watchman is dressed: outfit, weathered head, coif, kettle hat; no base body",
		man.body != null and man.body.name == "Outfit" and "Head_weathered" in names and "coif" in names and "kettlehat" in names
		and not bare and layered, str(names))

	# K2 every worn triangle counted
	var tris: int = man.worn().reduce(func(n, m): return n + m.mesh.get_faces().size() / 3, 0)
	_check("K2 a dressed watchman is at most 3,000 triangles", tris <= 3000 and tris > 0, "tris %d" % tris)

	# K10 same seed, same man; four seeds, not four clones; the kettle hat always
	var twin := await _guard(3)
	var looks := {}
	var hats := true

	for s in [1, 2, 3, 4]:
		var w := await _guard(s)
		looks[str(w._rig.man.look)] = true
		hats = hats and "kettlehat" in _worn_names(w._rig.man)

	_check("K10 the same seed makes the same watchman, four seeds at least two looks, always the kettle hat",
		not man.look.is_empty() and str(twin._rig.man.look) == str(man.look)
		and twin._rig.man.body.get_instance_shader_parameter("dye_colour") == man.body.get_instance_shader_parameter("dye_colour")
		and looks.size() >= 2 and hats, "distinct %d look %s" % [looks.size(), man.look])

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

	# K1c (Review Focus 4) a squad shares one mesh, skin and material
	var a := await _guard(21)
	var b := await _guard(22)
	var oa: MeshInstance3D = a._rig.man.body
	var ob: MeshInstance3D = b._rig.man.body
	_check("K1c dressed guards share the outfit's mesh, skin and material",
		oa.mesh == ob.mesh and oa.skin == ob.skin and oa.get_surface_override_material(0) != null
		and oa.get_surface_override_material(0) == ob.get_surface_override_material(0), "")

	# K1d the strips (tabard, skirts) are drawn from both sides, the rest culls
	var shaders := []

	for s in range(oa.mesh.get_surface_count()):
		var worn := oa.get_surface_override_material(s) as ShaderMaterial
		shaders.append(worn.shader.resource_path.get_file() if worn != null else "none")

	_check("K1d the outfit's cloth strips are drawn from both sides, its closed parts cull their backs",
		shaders.has(Wardrobe.SHADER_TWO_SIDED.resource_path.get_file()) and shaders.has(Wardrobe.SHADER.resource_path.get_file()),
		str(shaders))

	for x in [g, twin, painted, a, b]:
		x.queue_free()

	for child in get_children():
		if child is CharacterBody3D:
			child.queue_free()

	await _frames(3)


# ---------------------------------------------------------------------------
# K-order, K4, K4b, K5, K6, K6b, K12: cloth
# ---------------------------------------------------------------------------

## Markers that follow his bones as drawn (bone attachments see the cloth's
## simulation; plain bone reads do not): each chain's hem and moving joint,
## his pelvis, thighs and calves.
func _watch(man: Node) -> Dictionary:
	var skeleton: Skeleton3D = man.skeleton
	var out := {"tips": {}, "joints": [], "legs": {}}

	for chain in Wardrobe.kind_data(&"watchman").get("cloth", []):
		var last := _marker(skeleton, chain.bones[-1], Vector3(0.0, float(chain.tip), 0.0))
		out.tips[chain.chain] = last
		out.joints.append(_marker(skeleton, chain.bones[-1], Vector3.ZERO))
		out.joints.append(last)

	out.pelvis = _marker(skeleton, &"pelvis", Vector3.ZERO)

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


## Each hem in his pelvis's own frame: whatever he does (turn, fall, get up),
## a hem that simply rode with him would not move here; only the cloth's own
## swing does.
func _hems(w: Dictionary) -> Dictionary:
	var out := {}
	var frame := (w.pelvis as Node3D).global_transform.affine_inverse()

	for chain in w.tips:
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


func _finite(h: Dictionary) -> bool:
	return h.values().all(func(v): return v.is_finite())


## One frame of his own animation and cloth, `dt` of game time.
func _step(g: Node, dt: float) -> void:
	g._rig.update(dt)
	await get_tree().process_frame


func _cloth() -> void:
	var dt := 1.0 / 60.0

	# K-order the modifiers: Posture, then Ragdoll, then Cloth
	var g := await _guard(31)
	g.set_physics_process(false)
	var man = g._rig.man
	var order: bool = man.cloth != null and man.posture.get_index() < man.ragdoll.get_index() and man.ragdoll.get_index() < man.cloth.get_index()
	_check("K-order his skeleton's modifiers run Posture, Ragdoll, Cloth", order,
		"posture %d ragdoll %d cloth %d" % [man.posture.get_index(), man.ragdoll.get_index(), man.cloth.get_index() if man.cloth else -1])

	# K4 a run and a sudden stop: the skirts swing, then settle
	var w := _watch(man)

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

	_check("K4 after a run and a sudden stop the skirts swing at least 5 cm and settle within 1.5 s",
		finite and swing >= 0.05 and speed < 0.02, "swing %.3f end speed %.3f finite %s" % [swing, speed, finite])

	# K4b (Review Focus 1) hit-stop mid-swing: nothing jumps when time resumes
	for i in range(30):
		g.velocity = -g.global_basis.z * 3.2
		g.global_position += g.velocity * dt
		await _step(g, dt)

	g.velocity = Vector3.ZERO
	TimeFx.request(get_tree(), &"wardrobe_test", 0.05, 0.5)
	var real := 0.0

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

	_check("K4b after slow motion ends, no hem moves faster than 5 m/s", burst <= 5.0 and _finite(last), "fastest %.2f m/s" % burst)

	# K5 a kick and a lunge: the cloth stays out of his legs
	var colliders := {}

	for c in Wardrobe.kind_data(&"watchman").get("colliders", []):
		colliders[StringName(c.bone)] = c

	var worst := INF

	for attack in [&"kick", &"lunge"]:
		for i in range(30):
			g._phase = &"strike"
			g._attack = attack
			g._phase_length = 0.5
			g._phase_timer = 0.5 * (1.0 - i / 29.0)
			await _step(g, dt)

			for leg in w.legs:
				if not colliders.has(leg):
					continue

				var mark: Node3D = w.legs[leg]
				var a := mark.global_position
				var b := a + mark.global_basis.y.normalized() * float(colliders[leg].height)

				for joint in w.joints:
					var p: Vector3 = (joint as Node3D).global_position
					var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 1e-6), 0.0, 1.0)
					worst = minf(worst, p.distance_to(a + (b - a) * t) - float(colliders[leg].radius))

	g._phase = &""
	_check("K5 through a kick and a lunge no cloth joint enters a thigh or calf", worst >= -0.005, "closest %.3f past the surface" % worst)

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
	_check("K12 a guard moved 20 m in one frame does not whip his cloth (< 3 m/s)", jump < 3.0, "fastest %.2f m/s" % jump)

	# K6 dead and limp: the tabard settles on his body without flying off
	var dead := await _guard(32)
	var dw := _watch(dead._rig.man)
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
	speed = INF

	for i in range(150):
		await get_tree().physics_frame
		var now := _hems(dw)
		speed = _fastest(last, now, dt)
		popped = _popped(dw, hips, popped)
		hips = (dw.pelvis as Node3D).global_position

		if popped == 0:
			wild = maxf(wild, speed)


		last = now

	# A body hitting the floor swings its cloth at up to ~9 m/s for a few
	# frames; flying apart is far faster (or NaN).
	_check("K6 on a limp body the cloth never flies (<= 12 m/s) and settles (< 5 cm/s) within 2.5 s", wild <= 12.0 and speed < 0.05,
		"fastest %.2f end %.3f" % [wild, speed])

	# K6b (Review Focus 2) knocked down and getting up: no whip, no NaN
	var down := await _guard(33)
	var kw := _watch(down._rig.man)
	await _frames(2)
	down.knock_down(down.global_basis.z * 4.0)
	last = _hems(kw)
	wild = 0.0
	finite = true
	var frames := 0

	hips = (kw.pelvis as Node3D).global_position
	popped = 0

	while frames < 300 and (frames < 30 or down.get("_downed") or float(down.get("_rising")) > 0.0):
		await get_tree().physics_frame
		var now := _hems(kw)
		finite = finite and _finite(now)
		popped = _popped(kw, hips, popped)
		hips = (kw.pelvis as Node3D).global_position

		if popped == 0:
			wild = maxf(wild, _fastest(last, now, dt))

		last = now
		frames += 1

	_check("K6b knocked down and back up, his cloth stays sane (<= 12 m/s, no NaN)", finite and wild <= 12.0 and not down.get("_downed"),
		"fastest %.2f frames %d still down %s" % [wild, frames, down.get("_downed")])

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
	# K7 a dressed watchman cut apart: his head takes its face and gear, his leg its part of the outfit
	var g := await _guard(41)
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
	_check("K7 a severed head takes his face, coif and hat; a leg its boot and outfit; cloth stays on him; Severed runs last",
		"Head_weathered" in in_head and "coif" in in_head and "kettlehat" in in_head
		and "Outfit" in in_leg and not ("Head_weathered" in in_leg) and not ("coif" in in_leg)
		and not cloth_on_leg and man.severed != null and &"neck_01" in man.severed.bones and &"thigh_l" in man.severed.bones and last_word,
		"head %s leg %s cloth on leg %s last %s" % [in_head, in_leg, cloth_on_leg, last_word])

	# K7b (Review Focus 5) the severed leg keeps his colours
	var same := false

	if leg:
		var copy: MeshInstance3D = leg.get_node("Skeleton3D").get_node_or_null("Outfit")
		same = copy != null and [&"dye_colour", &"dye_fade", &"skin_tone", &"grime"].all(
			func(p): return copy.get_instance_shader_parameter(p) == man.body.get_instance_shader_parameter(p))

	_check("K7b a severed part keeps his dye, fading, skin and dirt", same, "")

	# K8 the hit flash covers everything he wears
	var h := await _guard(42)
	var rig = h._rig
	rig.react_hit(h.global_basis.z, 1.0)
	rig.update(1.0 / 60.0)
	var lit: bool = rig.man.worn().all(func(m): return m.material_overlay == rig._overlay)

	for i in range(36):
		rig.update(1.0 / 60.0)
		await get_tree().physics_frame

	var cleared: bool = rig.man.worn().all(func(m): return m.material_overlay != rig._overlay)
	_check("K8 a hit flashes on every mesh he wears, and clears", lit and cleared, "lit %s cleared %s worn %d" % [lit, cleared, rig.man.worn().size()])

	# K9 his helmet and mail ring; his gambeson and legs do not
	var am = rig.man
	var ahead: Vector3 = -h.global_basis.z
	var coif: Node = am.worn().filter(func(m): return m.name == "coif").front() if am.worn().any(func(m): return m.name == "coif") else null
	var helm: Vector3 = am.bone_global(&"Head").origin + Vector3.UP * 0.12
	var neck: Vector3 = am.bone_global(&"neck_01").origin + ahead * 0.06
	var belly: Vector3 = am.bone_global(&"spine_02").origin + ahead * 0.15
	var thigh: Vector3 = (am.bone_global(&"thigh_l").origin + am.bone_global(&"calf_l").origin) * 0.5
	_check("K9 steel rings on his hat and coif, not on his gambeson or legs",
		coif != null and am.metal.get(&"neck_01") == coif and am.metal.get(&"Head") == coif
		and am.armour_near(helm) != null and am.armour_near(neck) != null and am.armour_near(belly) == null and am.armour_near(thigh) == null,
		"helm %s neck %s belly %s thigh %s" % [am.armour_near(helm) != null, am.armour_near(neck) != null, am.armour_near(belly) != null, am.armour_near(thigh) != null])

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

	for x in [g, h, player]:
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
