extends Node3D
## Windowed visual QA for the shot's effects: frame sequences (clips) of a
## hip shot and an aimed shot at a stone wall, a shell at a crate and a man
## close by, a reload, and the shot seen from the side; lit and dark. Run
## with the new arms:
## FP_ARMS=new Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_gunfx.tscn -- --out=/tmp/gunfx [--only=hip|aimed|shell|reload|side|wisp|freeze] [--dark]

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const HANDHOLD := preload("res://scripts/PlayerUtils/Handhold.gd")
const PROPS := preload("res://scripts/Interaction/Props.gd")

## The frames of a clip saved, counted from the press.
const CLIP := [0, 1, 2, 3, 4, 6, 9, 14, 20, 30, 45, 60, 75]

var _out := "/tmp/gunfx/"
var _only := ""
var _dark := false
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		elif arg == "--dark":
			_dark = true
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(0, true)
	_light()
	_box(Vector3(0, -0.5, 0), Vector3(120, 1, 60), Color(0.35, 0.33, 0.3))
	# A stone wall 6 m ahead.
	_box(Vector3(0, 1.5, -6.2), Vector3(8, 3, 0.4), Color(0.55, 0.52, 0.48))
	player = PLAYER.instantiate()
	add_child(player)
	player.debug_traversal = false
	player.reload_on_death = false
	player.invulnerable = true
	var hud := player.get_node_or_null("HUD")
	if hud != null:
		hud.visible = false
	await _frames(10)
	PROPS.give_revolver(player)
	player.inventory.select_by_id(&"revolver")
	await _place(Vector3(0, 0.1, 0))
	await _frames(60)
	var tag := "_dark" if _dark else ""

	if _wants("hip"):
		await _clip("hip" + tag)
		await _frames(60)

	if _wants("aimed"):
		player.revolver.reset_for_practice()
		Input.action_press("aim")
		await _frames(30)
		await _clip("aimed" + tag)
		Input.action_release("aim")
		await _frames(60)

	if _wants("shell"):
		# A crate and a man 2 m off.
		var crate := PROPS.crate(self, Vector3(-1.2, 0.3, -2.2), 0.5, 5.0)
		var man: CharacterBody3D = GUARD.instantiate()
		man.debug_ai = false
		man.position = Vector3(0.4, 0, -2.4)
		man.rotation.y = PI
		add_child(man)
		man.set_physics_process(false)
		await _frames(20)
		player.revolver.reset_for_practice()
		player.revolver.flip_barrel()
		await _frames(12)
		await _clip("shell" + tag)
		player.revolver.flip_barrel()
		await _frames(60)
		crate.queue_free()

		if is_instance_valid(man):
			man.queue_free()

	if _wants("wisp"):
		# Three shots, then the trail of smoke out of the barrel as the gun
		# settles; turning a little partway, so the trail bends behind it.
		player.revolver.reset_for_practice()
		for k in 3:
			_tap("throw")
			await _frames(int(player.revolver._settle * 60.0) + 2)
		for f in 150:
			if f >= 60 and f < 100:
				player.rotation.y += 0.004
			if f in [10, 20, 30, 45, 60, 80, 100, 125, 149]:
				await _shot("wisp%s_%03d" % [tag, f])
			await get_tree().physics_frame
		await _frames(60)

	if _only == "freeze":
		# The flash held on its first frame, each piece alone, from the eye
		# and from the side.
		player.revolver.reset_for_practice()
		Input.action_press("throw")
		var flash: Node3D = null

		while flash == null:
			await get_tree().physics_frame
			var found: Array = player.hand.find_children("GunFlash*", "", true, false)
			flash = found[0] if not found.is_empty() else null
		Input.action_release("throw")
		Engine.time_scale = 0.0
		var pieces := ["Core", "Spikes", "Tongue"]

		for view in ["eye", "side"]:
			var side: Camera3D = null
			if view == "side":
				side = Camera3D.new()
				add_child(side)
				var at: Vector3 = flash.global_position
				side.global_transform = Transform3D(Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP), at + Vector3(0.45, 0.0, 0.0))
				side.fov = 40.0
				side.cull_mask = 0xFFFFF
				side.make_current()
			for only in pieces + ["all"]:
				for piece in pieces:
					flash.get_node(piece).visible = only == "all" or only == piece
				await _shot("freeze_%s_%s%s" % [view, only.to_lower(), tag])
			if side != null:
				side.queue_free()
		Engine.time_scale = 1.0

	if _wants("reload"):
		player.revolver.reset_for_practice()
		for i in 3:
			_tap("throw")
			await _frames(40)
		await _frames(30)
		Input.action_press("reload")
		for f in 40:
			await get_tree().physics_frame
			if f == 2:
				Input.action_release("reload")
			if f in [4, 8, 12, 18, 26, 36]:
				await _shot("reload_%02d%s" % [f, tag])
		await _frames(200)

	if _wants("side"):
		# Seen from the side, 4 m off: a free camera; the player's own view off.
		player.revolver.reset_for_practice()
		var side := Camera3D.new()
		add_child(side)
		side.global_transform = Transform3D(Basis.looking_at(Vector3(-4, 0, -1.0), Vector3.UP), player.global_position + Vector3(4, 0.7, -1.0))
		side.fov = 50.0
		side.make_current()
		await _frames(5)
		await _clip("side" + tag)
		side.queue_free()

	get_tree().quit()


func _wants(name: String) -> bool:
	return _only == "" or _only == name


## Fire, and save the frames of CLIP from the press.
func _clip(label: String) -> void:
	Input.action_press("throw")

	for f in CLIP[-1] + 1:
		if f == 2:
			Input.action_release("throw")
		if f in CLIP:
			await _shot("%s_%02d" % [label, f])
		await get_tree().physics_frame


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.light_energy = 1.2
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.5, 0.58)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.56)
	# The game's bloom, so a bright core blooms as it will in a level.
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.8
	env.environment.glow_hdr_threshold = 1.0

	# Night: the moon low, the ambient dim.
	if _dark:
		sun.light_energy = 0.08
		env.environment.background_color = Color(0.03, 0.035, 0.05)
		env.environment.ambient_light_color = Color(0.08, 0.09, 0.12)

	add_child(env)


## A drainpipe to see (a POLE hold has none of its own).
func _pipe(center: Vector3, height: float) -> void:
	var mesh := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.045
	tube.bottom_radius = 0.045
	tube.height = height
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.27, 0.3)
	material.metallic = 0.6
	tube.material = material
	mesh.mesh = tube
	add_child(mesh)
	mesh.global_position = center


func _hold(kind: int, at: Vector3, length: float) -> Node3D:
	var hold: Node3D = HANDHOLD.new()
	hold.kind = kind
	hold.length = length
	add_child(hold)
	hold.global_position = at
	return hold


func _hang_on(hold: Node3D) -> void:
	var lip: float = hold.global_position.y
	var anchor: Vector3 = player.planner.hang_anchor(hold.global_position, Vector3.BACK, lip)
	await _place(anchor)
	player.global_position = anchor
	player._enter_hang(Vector3.BACK, lip, false, &"", hold)
	await _frames(2)


func _place(at: Vector3) -> void:
	player.teleport(Transform3D(Basis.IDENTITY, at))
	player._set_crouched(false)
	player.neck.rotation.x = 0.0
	await _frames(3)


func _box(center: Vector3, size: Vector3, colour: Color) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	cube.material = material
	mesh.mesh = cube
	body.add_child(mesh)
	add_child(body)
	body.global_position = center


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + label + ".png")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
