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
const MagicView := preload("res://scripts/Visual/MagicView.gd")
const WardScript := preload("res://scripts/Magic/Ward.gd")

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
		# Aimed from your own eyes: the mark and the reaching hand, then let
		# go: every frame of the rush and the landing.
		var through := [5, 15, 30, 40]
		through.append_array(range(41, 53))
		through.append_array([56, 62, 70])
		# Facing the open floor, away from the wall (whose top it would catch).
		await _place(Vector3(0, 0.1, 0))
		player.rotation.y = PI
		await _frames(20)
		player.power.power = player.power.MAX
		await _hold_clip("blink" + tag, "blink", through, 41)
		await _frames(60)
		# The same from the side, ahead of where you stood and looking back:
		# the cracked pane hanging there and falling apart, the dust where you
		# land.
		await _place(Vector3(0, 0.1, 0))
		player.rotation.y = PI
		await _frames(30)
		var side := Camera3D.new()
		add_child(side)
		side.global_transform = Transform3D(Basis.looking_at(Vector3(0, 1.0, 4.5) - Vector3(6.5, 1.9, 6.5), Vector3.UP), Vector3(6.5, 1.9, 6.5))
		side.make_current()
		var view: CanvasLayer = MagicView.of(get_tree())
		view.visible = false
		player.power.power = player.power.MAX
		await _hold_clip("blink_side" + tag, "blink", [20, 41, 42, 43, 44, 46, 48, 52, 56, 60, 66, 72, 80, 88], 41)
		side.queue_free()
		await _place(Vector3(0, 0.1, 0))
		player.rotation.y = PI
		await _frames(60)
		# Close, looking back at the pane face on.
		var back := Camera3D.new()
		add_child(back)
		back.global_transform = Transform3D(Basis.looking_at(Vector3(-0.3, -0.2, -2.4), Vector3.UP), Vector3(0.3, 1.5, 2.4))
		back.make_current()
		player.power.power = player.power.MAX
		await _hold_clip("blink_back" + tag, "blink", [42, 44, 48, 56, 60, 64, 68], 41)
		back.queue_free()
		view.visible = true
		await _place(Vector3(0, 0.1, 0))
		await _frames(60)

	if _wants("ward"):
		# From your eyes: the wind-up and the pour, frame by frame, then
		# standing in it.
		var steps := range(0, 48, 2)
		steps.append_array([60, 80])
		player.power.power = player.power.MAX
		await _hold_clip("ward" + tag, "spell_2", steps, 30)
		# An arrow stopped from the front, watched from inside.
		var archer := Node3D.new()
		add_child(archer)
		archer.global_position = Vector3(1.5, 0, -8)
		for f in 70:
			if f == 5:
				_loose_at_player(archer)
			if f in [12, 14, 16, 20, 28, 40, 60]:
				await _shot("ward_hit_%02d%s" % [f, tag])
			await get_tree().physics_frame
		await _frames(int(WardScript.LIFE * 60.0))
		# From outside, 4 m off: cast, the pour round the floor, standing, a
		# ball and an arrow stopped, the sinking and the drain.
		await _place(Vector3(0, 0.1, 0))
		await _frames(30)
		var outside := Camera3D.new()
		add_child(outside)
		outside.global_transform = Transform3D(Basis.looking_at(Vector3(-3.2, -0.7, -3.0).normalized(), Vector3.UP), player.global_position + Vector3(3.2, 1.2, 3.0))
		outside.make_current()
		player.power.power = player.power.MAX
		Input.action_press("spell_2")
		var ward_at := -1
		for f in 420:
			if ward_at < 0 and not WardScript.active.is_empty():
				ward_at = f
				Input.action_release("spell_2")
			var since := f - ward_at if ward_at >= 0 else -1
			if since == 70:
				var ward: Node3D = WardScript.active[0].get_ref()
				WardScript.turned_aside(player, ward.global_position + Vector3(0.0, 0.3, WardScript.RADIUS).rotated(Vector3.UP, 0.8), Vector3(0, 0, -1).rotated(Vector3.UP, 0.8), ward, &"ball")
			if since == 100:
				_loose_at_player(archer)
			if since in [0, 2, 4, 8, 12, 16, 20, 26, 34, 50, 71, 73, 76, 82, 108, 112, 120, 200, 215, 225, 235, 240, 245, 250, 260, 275, 290]:
				await _shot("ward_outside_%03d%s" % [since, tag])
			await get_tree().physics_frame
		outside.queue_free()
		archer.queue_free()
		await _frames(60)

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


## An arrow from `archer` at the player's chest, flying straight.
func _loose_at_player(archer: Node3D) -> void:
	var arrow: StaticBody3D = ArrowScript.new()
	add_child(arrow)
	var from := archer.global_position + Vector3.UP * 1.5
	var chest := player.global_position + Vector3.UP * 0.4
	arrow.launch(from, (chest - from).normalized() * 30.0, 10.0, archer, 2.5)
	arrow.gravity = 0.0


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
