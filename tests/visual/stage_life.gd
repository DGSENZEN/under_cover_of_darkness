## Visual check, not a test: a garrison at its ease (GuardHabits). Each man
## set to one thing, filmed from the side and the front once he is at it: sat
## on a chair and getting up, asleep on a bench, back against a wall, bread
## at the provisions, the axe at the block, on his knees at the fire, a crate
## carried and set down, forearms on a rail, talk at the table, a word with a
## friend, a torch and a lantern on their rounds, up a rope.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_life.tscn -- --out=/some/folder
extends Node3D

const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Furnishings := preload("res://scripts/Interaction/Furnishings.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const RopeScript := preload("res://scripts/PlayerUtils/VerletRope.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://life/"
var camera: Camera3D
var men := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	TemperamentScript.rolling = false
	var stone := Color(0.4, 0.38, 0.36)
	Props.block(self, Vector3(0, -0.5, 5), Vector3(80, 1, 50), stone)
	Furnishings.chair(self, Vector3(2, 0, 1), -PI * 0.5)
	Furnishings.bench(self, Vector3(-30, 0, 1), 0.0)
	Props.block(self, Vector3(8, 1.5, 1.2), Vector3(4, 3, 0.4), Color(0.45, 0.42, 0.4))
	Furnishings.chopping_block(self, Vector3(-8, 0, -3), 0.0)
	Furnishings.provisions(self, Vector3(2, 0, 12), 0.0)
	Furnishings.campfire(self, Vector3(8, 0, 13))
	Furnishings.crate_piles(self, Vector3(-10, 0, 12), 0.0, Vector3(-5, 0, 12), 0.0)
	Furnishings.railing(self, Vector3(14, 0, -2), Vector3(18, 0, -2), Vector3(0, 0, -1))
	Furnishings.table(self, Vector3(-20, 0, 0), 0.0)
	# A tower with a rope down its face from an arm.
	Props.block(self, Vector3(28, 2.0, 18), Vector3(3, 4.0, 3), stone)
	Props.block(self, Vector3(28, 4.1, 20.0), Vector3(0.3, 0.2, 1.2), Color(0.36, 0.25, 0.15))
	var rope: Area3D = RopeScript.new()
	rope.length = 3.6
	rope.position = Vector3(28, 4.0, 20.4)
	add_child(rope)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.7, 0.0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 45
	await baker.baked

	men["sit"] = _man(Vector3(0, 0, 0), 0.0, [&"sit"])
	men["doze"] = _man(Vector3(-30, 0, 3), 0.0, [&"sit"], &"dozes")
	men["lean"] = _man(Vector3(8, 0, 0.5), 0.0, [&"lean"])
	men["chop"] = _man(Vector3(-8, 0, 0), 0.0, [&"chop"])
	men["eat"] = _man(Vector3(0, 0, 10), 0.0, [&"eat"])
	men["tend"] = _man(Vector3(8, 0, 10), 0.0, [&"tend"])
	men["carry"] = _man(Vector3(-8, 0, 9), 0.0, [&"carry"])
	men["rail"] = _man(Vector3(16, 0, 1), 0.0, [&"rail"])
	men["table"] = _man(Vector3(-21, 0, 3), 0.0, [&"sit"])
	men["table_b"] = _man(Vector3(-19, 0, 3), 0.0, [&"sit"])
	men["visit"] = _man(Vector3(-30, 0, 20), 0.0, [&"visit"])
	men["friend"] = _man(Vector3(-30, 0, 12), PI, [&"chop"], &"", &"rash")
	var torch := _man(Vector3(-15, 0, 15), 0.0, [&"fidget"])
	torch.rounds_light = &"torch"
	men["torch"] = torch
	var lantern := _man(Vector3(20, 0, 18), 0.0, [&"fidget"])
	lantern.rounds_light = &"lantern"
	men["lantern"] = lantern
	var climber := _man(Vector3(28, 0, 23), 0.0, [&"chop"])
	climber._home.origin = Vector3(28, 4.0, 18)
	men["rope"] = climber

	for key in [&"visit", &"friend"]:
		men[key]._life._talk_rest = 0.0

	var want := {"sit": [&"sit_down", &"sit", &"stand_up"], "doze": [&"doze"], "lean": [&"lean"], "chop": [&"chop"], "eat": [&"reach", &"eat"],
		"tend": [&"kneel_down", &"tend"], "carry": [&"reach", &"carry", &"set_down"], "rail": [&"rail"], "table": [&"sit_talk"], "visit": [&"talk", &"listen", &"nod", &"shake"],
		"torch": [&"carry_torch"], "lantern": [&"carry_lantern"], "rope": [&"ladder"]}
	var shot := {}

	for i in 60 * 70:
		await get_tree().physics_frame

		# Both sat at the table: a word is due.
		if men["table"].activity() == &"sit" and men["table_b"].activity() == &"sit" and men["table"]._life._talk_rest > 100.0:
			men["table"]._life._talk_rest = 0.0
			men["table_b"]._life._talk_rest = 0.0

		for key in want.keys():
			var g: Node3D = men[key]
			var doing: StringName = g.activity()
			var tag := "%s_%s" % [key, doing]

			if doing in want[key] and not shot.has(tag) and (g._habits._t > 0.6 or doing in [&"ladder", &"talk", &"listen", &"nod", &"shake", &"carry_torch", &"carry_lantern"]):
				shot[tag] = true
				await _film(g, tag)

	print("filmed %s" % [shot.keys()])
	get_tree().quit()


## `g` from his side and from in front of him.
func _film(g: Node3D, tag: String) -> void:
	for view in [["side", g.global_basis.x * 2.6 + Vector3.UP * 1.1], ["front", -g.global_basis.z * 2.6 + g.global_basis.x * 0.8 + Vector3.UP * 1.2]]:
		camera.global_position = g.global_position + view[1]
		camera.look_at(g.global_position + Vector3.UP * 0.8)
		camera.reset_physics_interpolation()
		# Drawn from there first, then taken.
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir + "%s_%s.png" % [tag, view[0]])


func _man(at: Vector3, yaw: float, habits: Array, quirk: StringName = &"", tag: StringName = &"steady") -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.temperament = tag
	g.position = at
	g.rotation.y = yaw
	g.habits.assign(habits)
	g.quirk = quirk
	g.hearing_acuity = 0.0
	add_child(g)
	g._habits._wait = 0.0
	g._life._talk_rest = 999.0
	return g
