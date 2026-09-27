## Visual check, not a test: each kind of guard with his weapon put by (a
## sword's hilt over the scabbard he wears, a maul or a crossbow slung on his
## back), then drawing it and putting it away again (GuardRig: Guard.wants_blade
## turned on and off), filmed close.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_sheath.tscn -- --out=/some/folder
extends Node3D

const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

## [name, archetype] of each man filmed.
const KINDS := [["watchman", &""], ["swordsman", &"swordsman"], ["duelist", &"duelist"], ["brute", &"brute"], ["archer", &"archer"], ["master", &"trainer"]]

var out_dir := "user://sheath/"
var camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	TemperamentScript.rolling = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(60, 1, 20), Color(0.4, 0.38, 0.36))
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.7, 0.0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(env)
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 40
	await baker.baked

	var men := []

	for i in range(KINDS.size()):
		var g: CharacterBody3D = GUARD.instantiate()
		g.debug_ai = false
		g.archetype = KINDS[i][1]
		g.position = Vector3(-20.0 + i * 8.0, 0.0, 0.0)
		g.hearing_acuity = 0.0
		add_child(g)
		g._habits._wait = 999.0
		g._life._talk_rest = 999.0
		men.append(g)

	await _ticks(90)

	for i in range(men.size()):
		var g: CharacterBody3D = men[i]
		var tag: String = KINDS[i][0]
		var slung: bool = g._rig._slung
		# Put by, from where it shows best: the hip he wears it on (his left),
		# or his back.
		await _shoot(g, "%s_0_put_by_side" % tag, _left(g, 1.7) if not slung else _behind(g, 2.0))
		await _shoot(g, "%s_0_put_by_front" % tag, _front(g, 2.2))
		# Drawn (wary: on edge after a hunt), then put away again: from in
		# front, his sword hand crossing to his hip.
		g._hunted_at = g._game_time
		await _film(g, tag + "_1_draw", _front(g, 1.9), 42)
		await _ticks(30)
		await _shoot(g, "%s_2_drawn" % tag, _front(g, 2.4))
		g._hunted_at = -1000.0
		await _film(g, tag + "_3_sheathe", _front(g, 1.9), 45)

	print("filmed %d men" % men.size())
	get_tree().quit()


## Views of him (as big as he is drawn): from his left, where a scabbard is
## worn; from in front and to his left; from behind.
func _left(g: Node3D, reach: float) -> Array:
	var big: float = g._rig.size
	return [(-g.global_basis.x * reach - g.global_basis.z * reach * 0.35 + Vector3.UP * 1.1) * big, Vector3.UP * 0.95 * big]


func _front(g: Node3D, reach: float) -> Array:
	var big: float = g._rig.size
	return [(-g.global_basis.z * reach - g.global_basis.x * reach * 0.3 + Vector3.UP * 1.25) * big, Vector3.UP * 0.95 * big]


func _behind(g: Node3D, reach: float) -> Array:
	var big: float = g._rig.size
	return [(g.global_basis.z * reach - g.global_basis.x * reach * 0.3 + Vector3.UP * 1.4) * big, Vector3.UP * 1.1 * big]


## One picture of `g` from `view` ([offset from his feet, where it looks]).
func _shoot(g: Node3D, shot_name: String, view: Array) -> void:
	_place(g, view)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


## `frames` drawn frames of `g` from `view`, every third one kept.
func _film(g: Node3D, shot_name: String, view: Array, frames: int) -> void:
	for i in frames:
		_place(g, view)
		await RenderingServer.frame_post_draw

		if i % 3 == 0:
			get_viewport().get_texture().get_image().save_png(out_dir + "%s_%02d.png" % [shot_name, i])


func _place(g: Node3D, view: Array) -> void:
	camera.global_position = g.global_position + (view[0] as Vector3)
	camera.look_at(g.global_position + (view[1] as Vector3))
	camera.reset_physics_interpolation()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
