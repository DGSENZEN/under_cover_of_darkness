extends Node3D
## Stills of the revenant's body in the real game, windowed:
##   Godot --path . --resolution 1920x1080 res://tests/diag_revenant_stills.tscn -- --out=<folder> [--place=room|yard]

const GYM := preload("res://maps/hunt_gym.tscn")
const MODEL := preload("res://assets/monsters/revenant.glb")
const LOOK := preload("res://scripts/Monsters/revenant_flesh.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")
## From where, and at what: [name, offset from it, what it looks at (m up), field of view].
const SHOTS := [
	["front", Vector3(0, 1.4, 3.7), 1.3, 62.0], ["quarter", Vector3(2.9, 1.4, 2.6), 1.3, 62.0], ["side", Vector3(3.8, 1.3, 0.0), 1.3, 62.0], ["back", Vector3(-1.8, 1.9, -3.1), 1.3, 62.0],
	["far", Vector3(1.0, 1.4, 16.0), 1.3, 40.0], ["low", Vector3(0.4, 0.8, 2.6), 1.9, 66.0],
	["head", Vector3(0.45, 2.3, 1.95), 2.25, 40.0], ["head_side", Vector3(1.2, 2.25, 0.95), 2.25, 40.0], ["crust", Vector3(1.0, 2.2, 0.5), 1.85, 42.0], ["crust_back", Vector3(1.2, 2.2, -1.1), 1.8, 42.0],
	["chest", Vector3(-0.4, 1.5, 1.7), 1.45, 42.0], ["hand", Vector3(-0.5, 0.6, 1.8), 0.5, 36.0], ["foot", Vector3(0.6, 0.35, 1.5), 0.15, 40.0],
]

var out := "user://"
var place := "room"
var gym: Node3D
var body: Node3D
var camera: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--place="):
			place = arg.trim_prefix("--place=")

	gym = GYM.instantiate()
	add_child(gym)
	await _frames(60)
	gym.player.invulnerable = true
	gym.player.hud.visible = false
	# (Out of its way: a player has a body too.)
	gym.player.teleport(Transform3D(Basis.IDENTITY, Vector3(13, 1.05, -33)))
	gym.player.visible = false
	# (Nothing else in the picture.)
	gym.set_physics_process(false)

	for other in get_tree().get_nodes_in_group(&"monsters"):
		other.queue_free()

	body = MODEL.instantiate()
	gym.add_child(body)
	body.global_position = Vector3(0, 0, 0.0) if place == "room" else Vector3(-3.0, 0, -18.0)
	body.rotation.y = PI
	var look := ShaderMaterial.new()
	look.shader = LOOK
	look.set_shader_parameter(&"stroke_sheet", BRUSH)

	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = look

	camera = Camera3D.new()
	gym.add_child(camera)
	camera.current = true
	await _frames(10)

	for shot in SHOTS:
		var off: Vector3 = shot[1]
		camera.fov = shot[3]
		camera.global_position = body.global_position + Vector3(off.x, off.y, off.z)
		camera.look_at(body.global_position + Vector3(0, shot[2], 0))
		await _frames(2)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("rev_%s_%s.png" % [place, shot[0]]))

	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
