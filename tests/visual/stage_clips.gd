## Visual check, not a test: what the animation library's fighting clips look
## like, as filmstrips (an armed guard, frozen at even steps through each).
##   Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_clips.tscn -- --out=/some/folder [--clips=A,B@0.2-0.6,C] [--steps=8]
## A clip given as Name@from-to is filmed over only those seconds of it.
extends Node3D

const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")

const CLIPS := [&"Sword_Attack", &"Sword_Regular_A", &"Sword_Regular_A_Rec", &"Sword_Regular_B", &"Sword_Regular_B_Rec",
	&"Sword_Regular_C", &"Sword_Regular_Combo", &"Sword_Heavy_Combo", &"Sword_Dash", &"Sword_Block", &"Melee_Hook",
	&"Melee_Hook_Rec", &"Punch_Jab", &"Punch_Cross", &"Shield_Dash", &"Shield_OneShot", &"Idle_Shield_Break", &"Hit_Knockback", &"Roll", &"Slide_Start"]
const STEPS := 8
var steps := STEPS

var out_dir := "user://clips/"


func _ready() -> void:
	var clips: Array = CLIPS

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"
		elif arg.begins_with("--clips="):
			clips = Array(arg.substr(8).split(","))
		elif arg.begins_with("--steps="):
			steps = int(arg.substr(8))

	DirAccess.make_dir_recursive_absolute(out_dir)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.4, 0.38, 0.36))
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.7, 0.0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)

	# Two views of one man: side on, and as you would face him.
	var guard: CharacterBody3D = GUARD.instantiate()
	guard.position = Vector3.ZERO
	add_child(guard)
	guard.set_physics_process(false)
	var rig: Node3D = guard.get_node("Rig")
	rig.set_process(false)
	var man: Node3D = rig.get("man")
	var side := Camera3D.new()
	add_child(side)
	side.fov = 45
	var front := Camera3D.new()
	add_child(front)
	front.fov = 45
	side.global_position = Vector3(4.2, 1.2, 0.0)
	side.look_at(Vector3(0, 1.0, 0.0))
	front.global_position = Vector3(0.0, 1.3, -4.2)
	front.look_at(Vector3(0, 1.0, 0.0))

	for i in 5:
		await get_tree().process_frame

	for spec in clips:
		var clip := StringName(String(spec).get_slice("@", 0))
		var length: float = man.action_length(clip)

		if length <= 0.0:
			continue

		var from := 0.0
		var to := length

		if String(spec).contains("@"):
			var span := String(spec).get_slice("@", 1)
			from = float(span.get_slice("-", 0))
			to = minf(float(span.get_slice("-", 1)), length)

		for view in [["side", side], ["front", front]]:
			(view[1] as Camera3D).current = true

			for step in range(steps):
				var t := lerpf(from, to, float(step) / float(steps - 1))
				man.show_action(clip, t, 0.0)
				man._action = 1.0
				man._cross = float(man._front)
				man.mixer.set(&"parameters/act/blend_amount", 1.0)
				man.mixer.set(&"parameters/cross/blend_amount", man._cross)
				man.mixer.advance(0.0)
				await get_tree().process_frame
				man.mixer.advance(0.0)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out_dir + "%s_%s_%d_%.2f.png" % [clip, view[0], step, t])

	get_tree().quit()
