extends Node3D
## Windowed visual QA for the spells' effects: frame sequences (clips) of the
## Shard (the circle, the flight, the shatter on stone), Blink (the
## mirror-crack, the ripple), the Ward (rising, an arrow stopped, sinking, seen
## from outside), and Empower (the pages, the charge, the kick that spends it).
## Run with the new arms:
## FP_ARMS=new Godot --fixed-fps 60 --resolution 960x540 --path . res://tests/visual/stage_magic.tscn -- --out=/tmp/magic [--only=shard] [--dark]

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const HANDHOLD := preload("res://scripts/PlayerUtils/Handhold.gd")
const PROPS := preload("res://scripts/Interaction/Props.gd")
const ArrowScript := preload("res://scripts/Combat/Arrow.gd")

var _out := "/tmp/magic/"
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

	if _wants("shard"):
		# Close: the wall 6 m off. Every frame through the release and the
		# hit, then the spikes standing and crumbling.
		var every := range(0, 41)
		every.append_array([60, 100, 150, 200, 215, 230])
		player.power.power = player.power.MAX
		await _hold_clip("shard" + tag, "spell_1", every)
		await _frames(120)
		# The spikes up close, from beside them.
		player.power.power = player.power.MAX
		await _hold_clip("shard_spikes" + tag, "spell_1", [40], 30)
		var beside := Camera3D.new()
		add_child(beside)
		beside.global_transform = Transform3D(Basis.looking_at(Vector3(-1.2, -0.25, -1.0).normalized(), Vector3.UP), Vector3(1.4, 1.9, -4.7))
		beside.make_current()
		await _frames(2)
		await _shot("shard_spikes_beside%s" % tag)
		beside.queue_free()
		await _frames(240)
		# Far: the wall 24 m off.
		await _place(Vector3(0, 0.1, 18))
		await _frames(20)
		player.power.power = player.power.MAX
		await _hold_clip("shard_far" + tag, "spell_1", range(22, 46, 2))
		await _frames(240)
		# Into a man 5 m off.
		var man: CharacterBody3D = GUARD.instantiate()
		man.debug_ai = false
		man.position = Vector3(0.0, 0, 13)
		man.rotation.y = PI
		add_child(man)
		await _frames(10)
		man.set_physics_process(false)
		player.power.power = player.power.MAX
		await _hold_clip("shard_man" + tag, "spell_1", [24, 26, 28, 30, 40, 60])
		await _frames(30)
		man.queue_free()
		await _place(Vector3(0, 0.1, 0))
		await _frames(30)

	if _wants("blink"):
		player.power.power = player.power.MAX
		await _hold_clip("blink" + tag, "blink", [0, 2, 3, 4, 6, 9, 14, 20, 30, 40], 2)
		await _place(Vector3(0, 0.1, 0))
		await _frames(30)

	if _wants("ward"):
		player.power.power = player.power.MAX
		await _hold_clip("ward" + tag, "spell_2", [0, 12, 24, 26, 30, 40, 60], 30)
		var archer := Node3D.new()
		add_child(archer)
		archer.global_position = Vector3(1.5, 0, -8)
		for f in 60:
			if f == 5:
				var arrow: StaticBody3D = ArrowScript.new()
				add_child(arrow)
				var from := archer.global_position + Vector3.UP * 1.5
				var chest := player.global_position + Vector3.UP * 0.4
				arrow.launch(from, (chest - from).normalized() * 30.0, 10.0, archer, 2.5)
				arrow.gravity = 0.0
			if f in [14, 18, 24, 32, 44]:
				await _shot("ward_hit_%02d%s" % [f, tag])
			await get_tree().physics_frame
		# From outside, 4 m off.
		var outside := Camera3D.new()
		add_child(outside)
		outside.global_transform = Transform3D(Basis.looking_at(Vector3(-3, -0.3, -2.0).normalized(), Vector3.UP), player.global_position + Vector3(3, 1.0, 2.0))
		outside.make_current()
		await _frames(3)
		await _shot("ward_outside%s" % tag)
		await _frames(60)
		await _shot("ward_sinking%s" % tag)
		outside.queue_free()
		await _frames(90)

	if _wants("empower"):
		await _place(Vector3(0, 0.1, 0))
		player.power.power = player.power.MAX
		await _hold_clip("empower" + tag, "spell_3", [0, 18, 36, 54, 72, 76])
		await _frames(30)
		await _shot("empower_charged%s" % tag)
		var man: CharacterBody3D = GUARD.instantiate()
		man.debug_ai = false
		man.position = Vector3(0.0, 0, -1.6)
		man.rotation.y = PI
		add_child(man)
		man.set_physics_process(false)
		await _frames(10)
		Input.action_press("kick")
		for f in 40:
			if f == 2:
				Input.action_release("kick")
			if f in [6, 9, 12, 16, 22, 30]:
				await _shot("empower_kick_%02d%s" % [f, tag])
			await get_tree().physics_frame
		await _frames(60)

	get_tree().quit()


func _wants(name: String) -> bool:
	return _only == "" or _only == name


## Hold `action` (let go at `release`, or at the end), saving the listed
## frames from the press.
func _hold_clip(label: String, action: String, frames: Array, release := -1) -> void:
	Input.action_press(action)

	for f in frames[-1] + 1:
		if f == release:
			Input.action_release(action)
		if f in frames:
			await _shot("%s_%02d" % [label, f])
		await get_tree().physics_frame

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
