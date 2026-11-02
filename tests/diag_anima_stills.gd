extends Node3D
## Stills of the ánimas' fight from the real game, windowed:
##   Godot --path . --resolution 1152x648 res://tests/diag_anima_stills.tscn -- --out=<folder> [--only=<part>]

const GYM := preload("res://maps/hunt_gym.tscn")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const MagicFxScript := preload("res://scripts/Visual/MagicFx.gd")

var out := "user://"
var only := ""
var place := "room"
var gym: Node3D
var p: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--place="):
			place = arg.trim_prefix("--place=")

	gym = GYM.instantiate()
	add_child(gym)
	await _frames(100)
	p = gym.player
	p.invulnerable = true
	gym.wave_now = 3
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-2, 1.05, -14)))
	await _frames(40)

	if only == "" or only == "hands":
		await _hands()

	if only == "" or only == "face":
		await _face()

	if only == "" or only == "life":
		await _life()

	if only == "" or only == "mouth":
		await _mouth()

	if only == "" or only == "death":
		await _death()

	if only == "" or only == "glass":
		await _glass()

	if only == "" or only == "burst":
		await _burst()

	if only == "perf":
		await _perf()

	if only == "swipe":
		await _swipe()

	if only == "eye_turned":
		await _eye_turned()

	if only.begins_with("die_"):
		await _dying_stills(only.trim_prefix("die_"))
		get_tree().quit()
		return

	if only == "spit":
		await _spit()
		get_tree().quit()
		return

	if only == "both":
		await _both()

	if only == "" or only == "shard":
		await _shard()

	if only == "" or only == "drain":
		await _drain()

	get_tree().quit()


## No curse in these: the drain alone, in a gulp and between gulps.
func _drain() -> void:
	var spots := [Vector3(-0.9, 0.5, -0.3), Vector3(0.9, 0.5, -0.3), Vector3(0.0, 0.5, 1.0)]
	var on: Array = []

	for i in 3:
		var e: CharacterBody3D = AnimaScript.new()
		e.form = &"hands"
		e.position = p.global_position + spots[i]
		add_child(e)
		await _frames(1)
		e.put_on_you()
		on.append(e)
		await _until_gulp()
		await _frames(4)
		await _shot("drain_%d_gulp" % (i + 1))
		await _frames(12)
		await _shot("drain_%d_raked" % (i + 1))
		await _frames(14)
		await _shot("drain_%d_between" % (i + 1))

	await _until_wind_up()
	await _shot("drain_wind_up")
	p.power.power = 5.0
	await _frames(80)
	await _until_gulp()
	await _frames(10)
	await _shot("drain_will_gone")
	p.power.power = 100.0
	p.leech.free_all()
	await _frames(4)
	await _shot("drain_released")


func _until_wind_up() -> void:
	var left := 200

	while left > 0 and p.leech.coming() < 0.92:
		left -= 1
		await get_tree().physics_frame


func _until_gulp() -> void:
	await p.leech.gulped


var pinned: CharacterBody3D
var pin_at := Vector3.ZERO


func _physics_process(_delta: float) -> void:
	if is_instance_valid(pinned):
		pinned.global_position = pin_at


## The hands, held in place walking: in the room's light, close and at distance, and
## in the yard's.
func _hands() -> void:
	var e: CharacterBody3D = AnimaScript.new()
	e.form = &"hands"
	e.position = Vector3(0, 0.3, -30)
	add_child(e)
	await _frames(2)
	pinned = e

	# The lit room, the player at its door, looking in.
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.05, -3.0)))
	pin_at = Vector3(0, 0.25, -1.4)
	e.state = e.State.RUSH
	await _frames(20)
	await _shot("hand_room_close")
	await _frames(9)
	await _shot("hand_room_close_2")
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(1.4, 1.05, -2.4)))
	pin_at = Vector3(0.2, 0.25, -1.4)
	await _frames(11)
	await _shot("hand_room_side")
	p.teleport(Transform3D(Basis(Vector3.UP, PI * 1.5), Vector3(-1.9, 1.05, -1.0)))
	pin_at = Vector3(0.0, 0.25, -1.0)
	p.neck.rotation.x = -0.25
	await _frames(13)
	await _shot("hand_room_profile")
	p.neck.rotation.x = 0.0
	# The yard, at fight distance, and close.
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-2, 1.05, -14)))
	pin_at = Vector3(-1, 0.25, -20)
	await _frames(14)
	await _shot("hand_yard_far")
	pin_at = Vector3(-1.6, 0.25, -16)
	await _frames(14)
	await _shot("hand_yard_near")
	pinned = null
	e.queue_free()
	await _frames(3)


## The face, held in place: in the room's light, close and at distance; and rearing.
func _face() -> void:
	var e: CharacterBody3D = AnimaScript.new()
	e.form = &"face"
	e.position = Vector3(0, 1.3, -30)
	add_child(e)
	await _frames(2)
	pinned = e
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.05, -3.4)))
	p.neck.rotation.x = 0.0
	pin_at = Vector3(0, 1.45, 0.8)
	e.state = e.State.RUSH
	await _frames(25)
	await _shot("face_room")
	pin_at = Vector3(0, 1.5, -1.9)
	await _frames(4)
	e.state = e.State.TELL
	e._state_t = -9.0
	await _frames(30)
	await _shot("face_room_tell")
	# From the side and close, in its tell still.
	p.teleport(Transform3D(Basis(Vector3.UP, PI * 0.72), Vector3(1.0, 1.05, -3.0)))
	p.neck.rotation.x = 0.0
	await _frames(20)
	await _shot("face_room_side")
	e.state = e.State.RUSH
	p.teleport(Transform3D(Basis.IDENTITY, Vector3(-2, 1.05, -14)))
	pin_at = Vector3(-1, 1.4, -19)
	await _frames(20)
	await _shot("face_yard")
	pinned = null
	e.queue_free()
	await _frames(3)


## The face and the hands alive, close, in the room's light: resting, woken, its attack, a miss.
func _life() -> void:
	var face: CharacterBody3D = AnimaScript.new()
	face.form = &"face"
	face.rests = true
	face.position = Vector3(0, 1.3, -30)
	add_child(face)
	await _frames(2)
	pinned = face
	# Kept as it is shown, with the camera this close: it would wake, and it would leap.
	face.notice = 0.0
	face._form = face._form.duplicate()
	face._form["leap_reach"] = 0.0
	face.state = face.State.REST
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0.4, 1.05, -3.2)))
	pin_at = Vector3(0, 1.3, -1.2)
	await _hold_rest(face, 50)
	await _shot("life_face_rest")
	p.teleport(Transform3D(Basis(Vector3.UP, PI * 0.75), Vector3(1.3, 1.05, -2.7)))
	await _hold_rest(face, 20)
	await _shot("life_face_rest_side")
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.05, -3.4)))
	face.state = face.State.RUSH
	await _frames(26)
	await _shot("life_face_rush")
	await _frames(14)
	await _shot("life_face_rush_2")
	face.state = face.State.TELL
	face._state_t = -9.0
	await _frames(34)
	await _shot("life_face_tell")
	p.teleport(Transform3D(Basis(Vector3.UP, PI * 0.75), Vector3(1.3, 1.05, -2.7)))
	await _frames(12)
	await _shot("life_face_tell_side")
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.05, -3.4)))
	face.state = face.State.LEAP
	face._state_t = -9.0
	face._leap_way = Vector3.ZERO
	await _frames(9)
	await _shot("life_face_leap")
	face.state = face.State.MISSED
	face._state_t = -9.0
	await _frames(14)
	await _shot("life_face_missed")
	await _frames(14)
	await _shot("life_face_looks_about")
	pinned = null
	face.queue_free()
	await _frames(3)
	var hand: CharacterBody3D = AnimaScript.new()
	hand.form = &"hands"
	hand.rests = true
	hand.position = Vector3(0, 0.3, -30)
	add_child(hand)
	await _frames(2)
	pinned = hand
	hand.notice = 0.0
	pin_at = Vector3(0, 0.25, -0.2)
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0.4, 1.05, -3.0)))
	hand.state = hand.State.REST
	hand._state_t = -99.0
	await _hold_rest(hand, 45)
	await _shot("life_hand_rest")
	hand.state = hand.State.MISSED
	hand._state_t = -9.0
	await _frames(8)
	await _shot("life_hand_slam")
	pinned = null
	hand.queue_free()
	await _frames(3)


func _hold_rest(e: CharacterBody3D, frames: int) -> void:
	e.state = e.State.REST
	e._state_t = -99.0
	await _frames(frames)


## A face on your face, through its gulps; and with its hands, and a second one.
func _mouth() -> void:
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.05, -3.0)))
	await _frames(10)
	var e: CharacterBody3D = AnimaScript.new()
	e.form = &"face"
	e.position = p.global_position + Vector3(0.6, 0.3, 0.6)
	add_child(e)
	await _frames(1)
	e.put_on_you()
	await _frames(5)
	await _shot("mouth_arriving")
	await _until_gulp()
	await _frames(3)
	await _shot("mouth_1_lunge")
	await _frames(8)
	await _shot("mouth_2_clamped")
	await _frames(18)
	await _shot("mouth_3_after")
	await _until_wind_up()
	await _shot("mouth_4_wind_up")
	await _until_gulp()
	await _frames(40)
	await _shot("mouth_5_sucking")
	var b: CharacterBody3D = AnimaScript.new()
	b.form = &"face"
	b.position = p.global_position + Vector3(-0.6, 0.3, 0.6)
	add_child(b)
	await _frames(1)
	b.put_on_you()
	await _frames(30)
	await _shot("mouth_two")
	p.leech.free_all()
	await _frames(3)
	await _shot("mouth_thrown")
	e.queue_free()
	b.queue_free()
	await _frames(3)


## Their deaths, each of them, in steps, in the room's light.
func _death() -> void:
	for kind in 3:
		await _dies(&"face", kind, Vector3(0, 1.3, 0.6), Vector3(0.0, 1.05, -2.2))

	for kind in 3:
		await _dies(&"hands", kind, Vector3(0, 0.3, 0.6), Vector3(0.0, 1.05, -1.8))


func _dies(form: StringName, kind: int, at: Vector3, stand: Vector3) -> void:
	var e: CharacterBody3D = AnimaScript.new()
	e.form = form
	e.position = at
	e.death_kind = kind
	add_child(e)
	await _frames(2)
	e._form = e._form.duplicate()
	e._form["leap_reach"] = 0.0
	e.state = e.State.RUSH
	pinned = e
	pin_at = at
	p.teleport(Transform3D(Basis(Vector3.UP, PI), stand))
	p.neck.rotation.x = -0.34
	await _frames(25)
	pinned = null
	var body: Node3D = e.body
	e.health = 1.0
	e.round_hint = &"copal"
	e.take_hit(50.0, p, &"bullet", e.global_position, Vector3.BACK)
	var last := 0

	for step in [10, 30, 55, 85, 115, 145, 170, 195, 225, 300]:
		await _frames(step - last)
		last = step
		await _shot("death_%s_%d_%03d" % [form, kind, step])

	p.neck.rotation.x = 0.0
	e.queue_free()

	if is_instance_valid(body):
		body.queue_free()

	await _frames(3)


## The Burst's glass, in the game's light and its own look: laid out to judge, and in the
## room as it will stand, tall to short.
func _glass() -> void:
	var scene: PackedScene = load("res://assets/magic/burst_glass.glb")
	var made: Node3D = scene.instantiate()
	var meshes := made.find_children("*", "MeshInstance3D", true, false)
	var spikes: Array = meshes.filter(func(m): return m.name.begins_with("Spike"))
	var chunks: Array = meshes.filter(func(m): return m.name.begins_with("Chunk"))
	var heights := [1.5, 1.25, 1.1, 0.8, 0.5]
	var shown: Array[Node3D] = []

	for i in spikes.size():
		var piece := MeshInstance3D.new()
		piece.mesh = spikes[i].mesh
		piece.material_override = MagicFxScript.big_glass_look()
		piece.scale = Vector3.ONE * heights[i]
		piece.scale = Vector3(1.25, 1.0, 1.25) * heights[i]
		piece.position = Vector3(float(i) * 0.72 - 1.45, 0.0, 1.0)
		piece.rotation.y = float(i) * 1.3
		add_child(piece)
		shown.append(piece)

	for i in chunks.size():
		var piece := MeshInstance3D.new()
		piece.mesh = chunks[i].mesh
		piece.material_override = MagicFxScript.big_glass_look()
		piece.position = Vector3(float(i) * 0.42 - 1.05, 0.12, 0.0)
		piece.rotation = Vector3(float(i) * 0.9, float(i) * 2.1, float(i) * 0.5)
		add_child(piece)
		shown.append(piece)

	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(-0.2, 1.05, -1.7)))
	p.neck.rotation.x = -0.4
	await _frames(25)
	await _shot("glass_room")
	# In the dark yard too.
	for i in shown.size():
		shown[i].position += Vector3(-2.0, 0.0, -20.0)

	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(-2.2, 1.05, -21.7)))
	await _frames(25)
	await _shot("glass_yard")
	p.neck.rotation.x = 0.0

	for piece in shown:
		piece.queue_free()

	made.free()
	await _frames(3)


func _burst() -> void:
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.05, -3.0)))
	p.neck.rotation.x = -0.18
	await _frames(10)

	for i in 6:
		var turn := float(i) * TAU / 6.0 + 0.2
		var e: CharacterBody3D = AnimaScript.new()
		e.form = [&"hands", &"face", &"hands"][i % 3]
		e.position = p.global_position + Vector3(cos(turn) * 4.0, 0.0, sin(turn) * 4.0 + 1.5)
		add_child(e)

	await _frames(14)
	p.power.power = 100.0
	Input.action_press("spell_4")
	await _frames(12)
	await _shot("burst_0_windup")
	await _frames(7)
	Input.action_release("spell_4")
	var last := 0

	for step in [2, 6, 12, 20, 26, 32, 40, 50, 80, 110, 140, 180, 240]:
		await _frames(step - last)
		last = step
		await _shot("burst_%03d" % step)

	p.neck.rotation.x = 0.0


## The Shard: in the hand, away, through one, into the floor beyond, and what it leaves.
func _shard() -> void:
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.05, -3.0)))
	p.neck.rotation.x = -0.14
	await _frames(10)
	var e: CharacterBody3D = AnimaScript.new()
	e.form = &"face"
	e.position = Vector3(0.1, 1.3, -0.4)
	add_child(e)
	await _frames(2)
	pinned = e
	pin_at = e.position
	e.health = 600.0
	e._form = e._form.duplicate()
	e._form["leap_reach"] = 0.0
	e.state = e.State.RUSH
	await _frames(20)
	var way: Vector3 = (e.global_position - p.camera.global_position).normalized()
	p.rotation.y = atan2(-way.x, -way.z)
	p.neck.rotation.x = asin(way.y)
	await _frames(2)
	p.power.power = 100.0
	Input.action_press("spell_1")
	await _frames(20)
	await _shot("shard_0_hand")

	while not get_tree().get_nodes_in_group(&"shards").size() > 0:
		await get_tree().physics_frame

	Input.action_release("spell_1")
	var last := 0

	for step in [1, 3, 5, 8, 12, 20, 40, 90]:
		await _frames(step - last)
		last = step
		await _shot("shard_%03d" % step)

	pinned = null
	e.queue_free()
	p.neck.rotation.x = 0.0
	await _frames(3)


## The eye and the eye turned, side by side, in the game's looks: lit room and dark yard.
## A death, as it plays, one a run (it can't be taken back): --only=die_eyes|animas|both|swipe,
## --place=room|yard.
func _dying_stills(how: String) -> void:
	var at := Vector3(0, 1.05, -3.0) if place == "room" else Vector3(-2.0, 1.05, 8.0)
	p.teleport(Transform3D(Basis(Vector3.UP, PI), at))
	await _frames(10)
	p.reload_on_death = false
	p.invulnerable = false

	if how == "both" or how == "eyes":
		p.statuses.apply(&"evil_eye", 60.0)

		for i in 3:
			p.curse.deepen()

	await _frames(70)

	if how == "both" or how == "animas":
		var face := _feeder(&"face", p.global_position + Vector3(0.9, -0.5, -0.3))
		var hands := _feeder(&"hands", p.global_position + Vector3(-0.9, -0.5, -0.3))
		await _frames(1)
		face.put_on_you()
		hands.put_on_you()
		await _frames(70)

	# The real thing that kills you is the last blow; it stays in the room, to be seen leaving.
	var blow: Node3D = _feeder(&"hands", p.global_position + Vector3(0.7, -0.7, 1.4))
	blow.leap_chance = 0.0
	await _frames(1)
	p.health = 0.01

	match how:
		"eyes":
			var eye: Node3D = load("res://scripts/Monsters/FloatingEye.gd").new()
			eye.position = p.global_position + Vector3(0, 1.5, 30)
			add_child(eye)
			eye.sleep()
			blow.sleep()
			blow.visible = false
			p.take_damage(50.0, eye)
		"swipe":
			p.hud.claw_at(1.0)
			p.take_damage(50.0, blow)
		_:
			p.drain_life(50.0)

	var was := 0.0

	for t in [0.5, 1.2, 2.0, 2.5, 3.0, 3.4, 3.8]:
		await _frames(int((t - was) * 60.0))
		was = t

		if p.death.since_end() < 0.2:
			await _shot("die_%s_%s_%.1f" % [how, place, t])

	for t in [0.9, 1.5, 2.2, 3.3, 4.5]:
		while p.death.since_end() < t:
			await get_tree().physics_frame

		await _shot("die_%s_%s_quote_%.1f" % [how, place, t])

	p.hud.show_death_page()
	await _frames(20)
	await _shot("die_%s_%s_page" % [how, place])


## A turned eye, real, gathering its spit and the gob on its way to you.
func _spit() -> void:
	var EyeScript: GDScript = load("res://scripts/Monsters/FloatingEye.gd")

	for place in [[Vector3(0.0, 1.05, -2.7), Vector3(0.5, 1.8, 1.3), "room"], [Vector3(-2.0, 1.05, 8.0), Vector3(-1.5, 1.9, 12.0), "yard"]]:
		p.teleport(Transform3D(Basis(Vector3.UP, PI), place[0]))
		await _frames(4)
		var e: CharacterBody3D = EyeScript.new()
		e.seed_value = 11
		e.start_turned = true
		e.position = place[1]
		add_child(e)
		e.next_swoop_in = 100.0
		e.spit_in = 100.0
		await _frames(6)
		e.state = e.State.SPIT_UP
		e._state_t = 0.0
		e._clear_line = true
		await _frames(26)
		await _shot("spit_windup_%s" % place[2])
		e.spit_in = 100.0
		await _until_gob()
		await _frames(14)
		await _shot("spit_gob_%s" % place[2])
		await _frames(30)
		e.free()

		for gob in get_tree().get_nodes_in_group(&"eye_gobs"):
			gob.free()


func _until_gob() -> void:
	for i in 60:
		if not get_tree().get_nodes_in_group(&"eye_gobs").is_empty():
			return

		await get_tree().physics_frame


func _eye_turned() -> void:
	var EyeBodyScript: GDScript = load("res://scripts/Monsters/EyeBody.gd")
	var plain: Node3D = EyeBodyScript.new()
	var worse: Node3D = EyeBodyScript.new()
	worse.model = EyeBodyScript.TURNED_MODEL
	# (A body moves itself about its holder.)
	var plain_at := Node3D.new()
	var worse_at := Node3D.new()
	add_child(plain_at)
	add_child(worse_at)
	plain_at.add_child(plain)
	worse_at.add_child(worse)

	for place in [[Vector3(0.0, 1.05, -2.7), Vector3(-0.85, 1.7, -0.9), Vector3(0.75, 1.7, -0.9), "room"], [Vector3(-2.0, 1.05, -24.0), Vector3(-2.85, 1.7, -22.2), Vector3(-1.25, 1.7, -22.2), "yard"]]:
		p.teleport(Transform3D(Basis(Vector3.UP, PI), place[0]))
		plain_at.global_position = place[1]
		worse_at.global_position = place[2]

		for i in 40:
			plain.tick(1.0 / 60.0, &"circle", p, Vector3.ZERO, false, false, 1.0)
			worse.tick(1.0 / 60.0, &"circle", p, Vector3.ZERO, false, false, 0.5)
			await get_tree().physics_frame

		await _shot("eye_turned_%s" % place[3])

	for i in 30:
		worse.tick(1.0 / 60.0, &"tell", p, Vector3.ZERO, false, false, 0.5)
		await get_tree().physics_frame

	plain.queue_free()
	await _frames(2)
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.05, -2.0)))
	worse_at.global_position = Vector3(0.0, 1.75, -0.8)

	for i in 30:
		worse.tick(1.0 / 60.0, &"tell", p, Vector3.ZERO, false, false, 0.5)
		await get_tree().physics_frame

	await _shot("eye_turned_close")
	worse_at.queue_free()
	await _frames(2)


## A swipe, close: its wind-up and its rake, hands and face.
func _swipe() -> void:
	for form in [&"hands", &"face"]:
		p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.05, -2.0)))
		p.neck.rotation.x = -0.22 if form == &"hands" else 0.0
		await _frames(10)
		var e: CharacterBody3D = AnimaScript.new()
		e.form = form
		e.position = Vector3(0.0, 0.3 if form == &"hands" else 1.3, -0.6)
		add_child(e)
		await _until_state(e, e.State.WIND_UP)
		await _frames(10)
		await _shot("swipe_%s_0_wind" % form)
		await _until_state(e, e.State.SWIPE)
		await _frames(3)
		await _shot("swipe_%s_1_rake" % form)
		await _frames(5)
		await _shot("swipe_%s_2_after" % form)
		await _frames(25)
		await _shot("swipe_%s_3_back" % form)
		e.queue_free()
		await _frames(3)


func _until_state(e: CharacterBody3D, wanted: int) -> void:
	var left := 300

	while left > 0 and e.state != wanted:
		left -= 1
		await get_tree().physics_frame


## The curse and the drain at once: what you see with both on you.
func _both() -> void:
	for place in [[Vector3(0, 1.05, -3.0), "room"], [Vector3(-2.0, 1.05, 8.0), "yard"]]:
		p.teleport(Transform3D(Basis(Vector3.UP, PI), place[0]))
		await _frames(10)
		var a := _feeder(&"hands", p.global_position + Vector3(0.9, -0.5, -0.3))
		await _frames(1)
		a.put_on_you()
		await _frames(50)
		await _until_gulp()
		await _frames(4)
		await _shot("both_%s_0_drain_alone" % place[1])
		p.leech.free_all()
		a.queue_free()
		await _frames(30)
		p.statuses.apply(&"evil_eye", 60.0)

		for i in 2:
			p.curse.deepen()

		await _frames(70)
		await _shot("both_%s_1_curse_alone" % place[1])
		var b := _feeder(&"face", p.global_position + Vector3(0.9, -0.5, -0.3))
		await _frames(1)
		b.put_on_you()
		p.power.power = p.power.MAX * 0.45
		await _frames(60)
		await _until_gulp()
		await _frames(3)
		await _shot("both_%s_2_one_gulp" % place[1])
		await _frames(30)
		await _shot("both_%s_3_one_between" % place[1])

		for i in 3:
			p.curse.deepen()

		var c := _feeder(&"face", p.global_position + Vector3(-0.9, -0.5, -0.3))
		var d := _feeder(&"hands", p.global_position + Vector3(0.0, -0.5, 0.9))
		await _frames(1)
		c.put_on_you()
		d.put_on_you()
		p.power.power = p.power.MAX * 0.1
		await _frames(80)
		await _shot("both_%s_4_worst" % place[1])
		await _until_gulp()
		await _frames(3)
		await _shot("both_%s_5_worst_gulp" % place[1])
		p.leech.free_all()
		p.statuses.clear(&"evil_eye")
		p.power.power = p.power.MAX

		for one in [b, c, d]:
			one.queue_free()

		await _frames(60)


func _feeder(form: StringName, at: Vector3) -> CharacterBody3D:
	var one: CharacterBody3D = AnimaScript.new()
	one.form = form
	one.position = at
	add_child(one)
	return one


## What a cast into a full wave costs, in frames: before, during, and while they all burn.
func _perf() -> void:
	p.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.05, -8.0)))
	await _frames(20)
	var crowd: Array = []

	for i in 7:
		var turn := float(i) * TAU / 7.0
		var e: CharacterBody3D = AnimaScript.new()
		e.form = [&"hands", &"face", &"hands", &"hands"][i % 4]
		e.position = p.global_position + Vector3(cos(turn) * 3.5, 0.0 if e.form == &"hands" else 0.3, sin(turn) * 3.5)
		add_child(e)
		crowd.append(e)

	await _frames(30)
	print("PERF before: ", await _frame_ms(120))
	p.power.power = 100.0
	Input.action_press("spell_4")
	await _frames(19)
	Input.action_release("spell_4")
	print("PERF wave, none dying: ", await _frame_ms(120))
	await get_tree().create_timer(4.0).timeout

	for e in crowd:
		if is_instance_valid(e):
			e.health = 1.0

	p.power.power = 100.0
	Input.action_press("spell_4")
	await _frames(19)
	Input.action_release("spell_4")
	print("PERF wave, all burning: ", await _frame_ms(240))


func _frame_ms(frames: int) -> String:
	var worst := 0
	var total := 0
	var last := Time.get_ticks_usec()

	for i in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		total += now - last
		last = now

	return "mean %.1f ms, worst %.1f ms" % [float(total) / float(frames) / 1000.0, float(worst) / 1000.0]


func _shot(name_of: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("anima_" + name_of + ".png"))
	print("STILL ", name_of)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
