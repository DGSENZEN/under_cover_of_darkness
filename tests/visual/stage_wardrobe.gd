extends Node3D
## Visual check, not a test: each kind the wardrobe dresses, under the retro
## screen, by day and by torchlight, beside his old painted self. Nothing is
## checked; look at the pictures (sheet_<kind>.png puts a kind's side by
## side, sheet.png every kind's lineup).
##
##   perl -e 'alarm 480; exec @ARGV' Godot --fixed-fps 60 --resolution 1280x720 --path . \
##       res://tests/visual/stage_wardrobe.tscn -- --out=/some/folder [--kinds=watchman,archer]

const GUARD := preload("res://Guard.tscn")
const Wardrobe := preload("res://scripts/Visual/Wardrobe.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

## The old painted man, then four from the wardrobe (their look seeds).
const SEEDS := [-1, 1, 2, 3, 4]
const SPACING := 1.5
## Every kind the wardrobe dresses, and the archetype that is it.
const KINDS := {&"watchman": &"", &"swordsman": &"swordsman", &"archer": &"archer", &"arms_master": &"trainer",
	&"brute": &"brute", &"duelist": &"duelist"}

var out_dir := "user://wardrobe/"
var guards: Array[CharacterBody3D] = []
var shots: Array = []
## Each kind's lineups, by day and by night (sheet.png).
var lineups: Array = []
var camera: Camera3D
var world: WorldEnvironment
var sun: DirectionalLight3D
var torch: Node3D


func _ready() -> void:
	var kinds: Array = KINDS.keys()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"
		elif arg.begins_with("--kinds="):
			kinds = Array(arg.substr(8).split(",")).map(func(k): return StringName(k))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Sfx.volume_db = -60.0
	Props.block(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.3, 0.29, 0.28))
	Props.block(self, Vector3(0, 2.0, -2.5), Vector3(14, 4, 0.4), Color(0.36, 0.34, 0.31))
	world = WorldEnvironment.new()
	world.environment = _neutral()
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 25, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 50
	add_child(camera)
	camera.current = true

	for kind in kinds:
		await _stage(kind)

	_lineup_sheet()
	print("staged into ", ProjectSettings.globalize_path(out_dir))
	Sfx.silence()
	await _frames(3)
	get_tree().quit()


## One kind, by day and by torchlight: its own shots and sheet.
func _stage(kind: StringName) -> void:
	world.environment = _neutral()
	sun.visible = true
	shots = []

	for i in range(SEEDS.size()):
		guards.append(_guard(SEEDS[i], Vector3((i - 2) * SPACING, 0, 0), KINDS.get(kind, &"")))

	await _frames(45)
	await _shoot_set("%s_day" % kind)
	world.environment = RetroScript.night_environment()
	sun.visible = false
	torch = TorchScript.new()
	torch.position = Vector3(0.6, 2.1, 1.9)
	add_child(torch)
	await _frames(20)
	await _shoot_set("%s_night" % kind)
	_sheet("sheet_%s.png" % kind)
	lineups.append([shots[0][0], shots[1][0]])

	for g in guards:
		g.queue_free()

	guards.clear()
	torch.queue_free()
	await _frames(3)


func _neutral() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.14, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.68, 0.78)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	return e


## A guard of `archetype` facing the camera, still: from the wardrobe with
## `seed`, or his old painted self (seed -1: the wardrobe hidden from him).
func _guard(seed: int, at: Vector3, archetype: StringName) -> CharacterBody3D:
	if seed < 0:
		Wardrobe.ROOT = "user://no_wardrobe/"
		Wardrobe.forget()

	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.set("look_seed", seed)
	g.position = at
	g.rotation.y = PI
	add_child(g)
	g.set_physics_process(false)

	if seed < 0:
		Wardrobe.ROOT = "res://assets/characters/wardrobe/"
		Wardrobe.forget()

	return g


## The lineup at 8 m, his painted self beside a wardrobe one, one man
## turned round at 2 m, and his face from under his headgear.
func _shoot_set(label: String) -> void:
	var row := []
	await _shot("%s_lineup" % label, Vector3(0, 1.45, 8.0), Vector3(0, 1.0, 0), row)
	# His old painted self beside a wardrobe one, both whole.
	var pair := (guards[0].position.x + guards[1].position.x) * 0.5
	await _shot("%s_before_after" % label, Vector3(pair, 1.35, 3.2), Vector3(pair, 1.0, 0), row)
	var him := guards[1]
	var x := him.position.x

	for degrees in [0, 45, 90, 180]:
		him.rotation.y = PI + deg_to_rad(degrees)
		await _frames(2)
		await _shot("%s_turn_%03d" % [label, degrees], Vector3(x, 1.5, 2.2), Vector3(x, 1.2, 0), row)

	him.rotation.y = PI
	await _frames(2)
	# His face as his pose holds it, from a little below: under the brim.
	var head := _head(him)
	await _shot("%s_face" % label, head + Vector3(0, -0.16, 0.7), head, row)
	# And from behind: the back of his headgear (or hair) and his neck.
	await _shot("%s_back" % label, head + Vector3(0, -0.05, -0.75), head, row)
	shots.append(row)


func _head(guard: Node) -> Vector3:
	var skeleton: Skeleton3D = guard._rig.man.skeleton
	var bone := skeleton.find_bone("Head")

	if bone < 0:
		return guard.global_position + Vector3(0, 1.62, 0)

	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin + Vector3(0, 0.06, 0)


func _shot(shot_name: String, from: Vector3, at: Vector3, row: Array) -> void:
	camera.global_position = from
	camera.look_at(at)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir + shot_name + ".png")
	row.append(image)


## Every kind's lineup, by day and by night: a row a kind.
func _lineup_sheet() -> void:
	if lineups.is_empty():
		return

	shots = lineups
	_sheet("sheet.png")


## Every shot at half size: a row a light.
func _sheet(file: String) -> void:
	if shots.is_empty() or shots[0].is_empty():
		return

	var w: int = shots[0][0].get_width() / 2
	var h: int = shots[0][0].get_height() / 2
	var columns := 0

	for row in shots:
		columns = maxi(columns, row.size())

	var sheet := Image.create(w * columns, h * shots.size(), false, Image.FORMAT_RGBA8)

	for r in range(shots.size()):
		for c in range(shots[r].size()):
			var small: Image = shots[r][c].duplicate()
			small.convert(Image.FORMAT_RGBA8)
			small.resize(w, h, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(small, Rect2i(0, 0, w, h), Vector2i(c * w, r * h))

	sheet.save_png(out_dir + file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
