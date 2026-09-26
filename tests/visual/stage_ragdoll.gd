## Visual check, not a test: people going limp.
##   Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_ragdoll.tscn -- --out=/some/folder
extends Node3D

const Humanoid := preload("res://scripts/Visual/Humanoid.gd")
const Props := preload("res://scripts/Interaction/Props.gd")

var out_dir := "user://ragdoll/"
var men: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(30, 1, 30), Color(0.4, 0.38, 0.35))
	Props.block(self, Vector3(3.0, 0.25, -1.2), Vector3(1.2, 0.5, 1.0), Color(0.45, 0.35, 0.25))
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(1.0, 1.6, 5.5)
	cam.rotation = Vector3(-0.15, 0.0, 0.0)
	cam.fov = 60
	cam.current = true

	# A plain collapse, a kick back, a fall forward onto the box.
	for spec in [[Vector3(-2.0, 0, 0), 0.0, Vector3.ZERO], [Vector3(0.5, 0, 0), 0.0, Vector3(0, 1.5, 6.0)], [Vector3(2.8, 0, 0.2), PI, Vector3(0, 0.5, -2.5)]]:
		var man = Humanoid.new()
		man.build(&"guard")
		add_child(man)
		man.add_boots()
		man.add_ragdoll()
		man.global_position = spec[0]
		man.rotation.y = spec[1]
		men.append([man, spec[2]])

	for i in 30:
		await get_tree().physics_frame

	for m in men:
		m[0].go_limp(Vector3.ZERO)
		m[0].ragdoll.shove(m[1], m[0].ragdoll.chest(), 0.7)

	var shots := {0: "00", 6: "01", 15: "02", 30: "03", 60: "04", 120: "05", 180: "06"}

	for frame in 181:
		if shots.has(frame):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out_dir + "rag_%s.png" % shots[frame])

		await get_tree().physics_frame

	for extra in 4:
		for m in men:
			var rag = m[0].ragdoll
			var sk: Skeleton3D = m[0].skeleton
			var joints := []

			for pair in [["thigh_l", "calf_l"], ["thigh_r", "calf_r"], ["upperarm_l", "lowerarm_l"], ["upperarm_r", "lowerarm_r"]]:
				var a: PhysicalBone3D = rag.body(StringName(pair[0]))
				var b: PhysicalBone3D = rag.body(StringName(pair[1]))
				var rest_rel := (sk.get_bone_global_rest(sk.find_bone(pair[0])).basis.inverse() * sk.get_bone_global_rest(sk.find_bone(pair[1])).basis).get_rotation_quaternion()
				var now_rel := (a.global_basis.orthonormalized().inverse() * b.global_basis.orthonormalized()).get_rotation_quaternion()
				# The child's turn from its rest, in the child's own frame.
				var bend := (rest_rel.inverse() * now_rel).get_euler()
				joints.append("%s %.0f/%.0f/%.0f" % [pair[1], rad_to_deg(bend.x), rad_to_deg(bend.y), rad_to_deg(bend.z)])

			var fastest := ""
			var top := 0.0

			for part in rag.bodies():
				var v: float = (part as PhysicalBone3D).linear_velocity.length() + (part as PhysicalBone3D).angular_velocity.length() * 0.1

				if v > top:
					top = v
					fastest = part.name

			print("t+%d speed %.2f fastest %s %.2f | %s" % [extra, rag.speed(), fastest, top, ", ".join(joints)])

		for i in 60:
			await get_tree().physics_frame

	get_tree().quit()
