extends Node3D
## The ravenous ánimas: their forms, their rush, what they do on you, and what gets
## them off (docs/superpowers/specs/2026-11-01-ravenous-animas-design.md).

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const STATE: Dictionary = AnimaScript.State
const SafePlace := preload("res://scripts/Hunt/SafePlace.gd")
const WardScript := preload("res://scripts/Magic/Ward.gd")
const HOME := Vector3(0, 1.05, 0)

var p: CharacterBody3D
var failed := 0
var _lost := 0.0


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.invulnerable = true
	p.reload_on_death = false
	p.position = HOME
	Props.give_revolver(p, 200, 40)
	p.inventory.select_by_id(&"revolver")
	p.inventory.ammo[&"copal_rounds"] = 60
	await _frames(60)
	await _hands_model()
	await _face_model()
	await _face_life()
	await _hands_life()
	await _mouth_model()
	await _mouth_on_its_body()
	await _mouth_moves()
	await _mouth_is_heavy()
	await _mouth_digs()
	await _mouth_swells()
	await _mouth_arrives_whole()
	await _mouth_spectral()
	await _mouth_gait()
	await _forms()
	await _round_cover()
	await _swipes()
	await _swipes_seen()
	await _rush()
	await _leeching()
	await _getting_off()
	await _drained_view()
	await _both_view()
	await _mouth_drain()
	await _death()
	await _character()
	await _dying()
	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


## The hands' model: a real hand, withered, up on its fingertips.
func _hands_model() -> void:
	var e := _anima(&"hands", Vector3(0, 0.3, -30))
	await _frames(3)
	var body: Node3D = e.body
	_check("V1 the model loads, with its skeleton", body.skeleton() != null and body.skeleton().find_bone("middle_02") >= 0 and body.skeleton().find_bone("arm_2") >= 0)
	var mesh: MeshInstance3D = body.part(&"Hand")
	_check("V1a a hand, and its claws, in one mesh", mesh != null)
	var colours: PackedColorArray = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var pale := 0
	var dark := 0

	for colour in colours:
		if colour.get_luminance() > 0.25:
			pale += 1
		elif colour.get_luminance() < 0.08:
			dark += 1

	_check("V1b vertex colours arrive, painted, not white (%d pale, %d dark, of %d)" % [pale, dark, colours.size()], colours.size() > 0 and pale > 20 and pale < colours.size() / 2 and dark > colours.size() / 10)
	var tris: int = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	_check("V4 under its budget (%d tris)" % tris, tris <= 9000)
	e.state = STATE.RUSH
	var skeleton: Skeleton3D = body.skeleton()
	var bone := skeleton.find_bone("index_02")
	var other := skeleton.find_bone("middle_02")
	var was: Quaternion = skeleton.get_bone_pose_rotation(bone)
	var other_was: Quaternion = skeleton.get_bone_pose_rotation(other)
	e.global_position = Vector3(0, 0.3, -40)
	await _frames(7)
	var moved_a: float = skeleton.get_bone_pose_rotation(bone).angle_to(was)
	var moved_b: float = skeleton.get_bone_pose_rotation(other).angle_to(other_was)
	_check("V2 it walks: its fingers move, not together (%.3f, %.3f)" % [moved_a, moved_b], moved_a > 0.01 and moved_b > 0.01 and skeleton.get_bone_pose_rotation(bone).angle_to(skeleton.get_bone_pose_rotation(other)) > 0.01)
	var tip_low: float = body.lowest_tip()
	_check("V2b on its fingertips: they reach the floor (%.2f)" % tip_low, absf(tip_low) < 0.1)
	_check("V2c the palm stands clear of the floor (%.2f)" % body.palm_height(), body.palm_height() > 0.2)
	e.fed = 60.0
	await _frames(3)
	_check("V3 it shows what it drank", body.fed_shown > 0.5)
	_check("V6 it has some of the Metro ánimas' fire, low", body.part(&"Ember") != null and body.ember_flare() < 1.0)
	var ember_fed: float = body.ember_flare()
	e.fed = 0.0
	await _frames(3)
	_check("V6b its fire comes up as it drinks (%.2f, %.2f)" % [body.ember_flare(), ember_fed], ember_fed > body.ember_flare() + 0.2)
	e.fed = 60.0
	e.state = STATE.THROWN
	await _frames(14)
	_check("V5 thrown, it goes over on its back (%.2f)" % body.flipped(), body.flipped() > 0.6)
	await _frames(100)
	e.state = STATE.RUSH
	await _frames(40)
	_check("V5b and rights itself (%.2f)" % body.flipped(), body.flipped() < 0.05)
	e.queue_free()
	await _frames(2)


## The face's model: two great hands, and a small dried face behind and between them.
func _face_model() -> void:
	var e := _anima(&"face", Vector3(0, 1.3, -60))
	await _frames(3)
	var body: Node3D = e.body
	_check("V7 a dried skull and its jaw, apart", body.part(&"Skull") != null and body.part(&"Jaw") != null)
	_check("V7b and two hands, a left and a right", body.hand_on(-1.0) != null and body.hand_on(1.0) != null and body.hand_on(-1.0) != body.hand_on(1.0))
	var skull: MeshInstance3D = body.part(&"Skull")
	var colours: PackedColorArray = skull.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var dark := 0
	var pale := 0

	for colour in colours:
		if colour.get_luminance() < 0.05:
			dark += 1
		elif colour.get_luminance() > 0.22:
			pale += 1

	_check("V7c it is painted: black pits, pale bone (%d dark, %d pale, of %d)" % [dark, pale, colours.size()], dark > colours.size() / 20 and pale > colours.size() / 40 and colours.size() > 0)
	var tris: int = (skull.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() + body.part(&"Jaw").mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()) / 3
	_check("V7d few enough tris, seen this close (%d)" % tris, tris <= 12000)
	_check("V7e a gullet and a tongue in its mouth", body.part(&"Gullet") != null and body.part(&"Tongue") != null)
	var left_wrist: Vector3 = body.hand_on(-1.0).global_position
	var right_wrist: Vector3 = body.hand_on(1.0).global_position
	var ahead: Vector3 = -e.global_basis.z
	var head_at: Vector3 = skull.global_position
	_check("V8 the hands first, thrust out ahead of the face, one each side", (left_wrist - head_at).dot(-body.global_basis.z) > 0.1 and (right_wrist - head_at).dot(-body.global_basis.z) > 0.1 and body.to_local(left_wrist).x < -0.1 and body.to_local(right_wrist).x > 0.1)
	e.state = STATE.RUSH
	await _frames(6)
	var at_rest: float = body.jaw_open()
	e.state = STATE.TELL
	e._state_t = -5.0
	await _frames(25)
	_check("V9 in its tell its jaw drops (%.2f, %.2f)" % [at_rest, body.jaw_open()], body.jaw_open() > at_rest + 0.3)
	var skeleton: Skeleton3D = body.hand_on(1.0)
	var bone := skeleton.find_bone("middle_02")
	var pose: Quaternion = skeleton.get_bone_pose_rotation(bone)
	var moved := 0.0

	# (Over a while: its palsy can come back to where it was at any one moment.)
	for i in 24:
		await get_tree().physics_frame
		moved = maxf(moved, skeleton.get_bone_pose_rotation(bone).angle_to(pose))

	_check("V9b its fingers never hold still (%.3f)" % moved, moved > 0.01)
	_check("V9c it has the low fire too", body.part(&"Ember") != null)
	e.queue_free()
	await _frames(2)


## Cover between it and you: it gets round, however square it meets it.
func _round_cover() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(20)
	p.invulnerable = true

	for offset in [0.0, 0.4, 0.8, -0.6]:
		var block: Node = Props.block(self, HOME + Vector3(0.0, 0.0, -3.0), Vector3(3.0, 3.0, 0.6))
		var one := _anima(&"hands", HOME + Vector3(offset, -0.6, -5.0))
		one.leap_chance = 0.0
		one.health = 500.0
		await _frames(1)
		var reached: bool = await _until(func(): return one.global_position.distance_to(p.global_position) < 2.2, 12.0)
		_check("R1 hands behind cover, %.1f m off square, get round it (%.1f m left)" % [offset, one.global_position.distance_to(p.global_position)], reached)
		one.free()
		block.free()
		await _frames(2)


func _mouth_model() -> void:
	var model: PackedScene = load("res://assets/monsters/anima_mouth.glb") if ResourceLoader.exists("res://assets/monsters/anima_mouth.glb") else null
	_check("O0 the mouth's model is there", model != null)

	if model == null:
		_check("O1 the mouth's parts", false)
		_check("O2 within budget", false)
		return

	var made: Node = model.instantiate()
	var parts_all_there := true

	for part in ["Mass", "RibsLeft", "RibsRight", "Gullet", "Candles"]:
		parts_all_there = parts_all_there and made.find_child(part, true, false) != null

	var arms := 0
	var faces := 0

	for i in range(1, 9):
		arms += 1 if made.find_child("Arm_%d" % i, true, false) != null else 0
		faces += 1 if made.find_child("Face_%d" % i, true, false) != null else 0

	var tris := 0

	for mesh in made.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3

	_check("O1 the mouth's parts (%d arms, %d faces)" % [arms, faces], parts_all_there and arms == 5 and faces == 3)
	_check("O2 within budget (%d)" % tris, tris > 0 and tris < 30000)
	made.free()


func _mouth_moves() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(10)
	var one := _anima(&"torso", HOME + Vector3(0.0, -0.5, -14.0))
	one.leap_chance = 0.0
	await _frames(10)
	await _until(func(): return one.state == STATE.RUSH, 3.0)
	var body: Node3D = one.body
	var out_of_step := 0.0
	var low := 9.0
	var high := -9.0

	for i in 150:
		await get_tree().physics_frame
		out_of_step = maxf(out_of_step, absf(body.arm_stride(0) - body.arm_stride(1)))
		low = minf(low, body.heave())
		high = maxf(high, body.heave())

	_check("T1 its dragging arms are out of step (%.2f)" % out_of_step, out_of_step > 0.2)
	_check("T2 it heaves as it goes (%.3f)" % (high - low), high - low > 0.04)
	one.free()
	await _frames(2)
	# Its tell.
	var teller := _anima(&"torso", HOME + Vector3(0.0, -0.5, -4.0))
	teller.leap_chance = 1.0
	await _until(func(): return teller.state == STATE.TELL, 9.0)
	await _frames(90)
	_check("T3 in its tell the ribs open wide and it rears (%.2f, %.2f)" % [teller.body.ribs_open(), teller.body.reared()], teller.body.ribs_open() > 0.8 and teller.body.reared() > 0.8)
	teller.free()
	await _frames(2)
	# Its rake.
	var raker := _anima(&"torso", HOME + Vector3(0.0, -0.5, -2.8))
	raker.leap_chance = 0.0
	raker.health = 500.0
	await _until(func(): return raker.state == STATE.WIND_UP, 8.0)
	await _frames(55)
	_check("T3b winding up, they open too (%.2f)" % raker.body.ribs_open(), raker.body.ribs_open() > 0.5)
	await _until(func(): return raker.state == STATE.SWIPE, 2.0)
	var least := 1.0
	var most_raking := 0

	while raker.state == STATE.SWIPE or raker.state == STATE.BACK_OFF and most_raking == 0:
		await get_tree().physics_frame
		least = minf(least, raker.body.ribs_open())
		most_raking = maxi(most_raking, raker.body.arms_raking())

	_check("T4 on the swing they snap shut (%.2f)" % least, least < 0.25)
	_check("T5 up close several arms rake (%d)" % most_raking, most_raking >= 3)
	# Backing off, the mouth stays on you: it doesn't turn its back and walk.
	await _until(func(): return raker.state == STATE.BACK_OFF, 2.0)
	var worst_facing := 1.0

	while raker.state == STATE.BACK_OFF:
		await get_tree().physics_frame
		var to_you: Vector3 = (p.global_position - raker.global_position) * Vector3(1.0, 0.0, 1.0)
		worst_facing = minf(worst_facing, (-raker.body.global_basis.z).normalized().dot(to_you.normalized()))

	_check("T9 it backs off with its mouth still on you (%.2f)" % worst_facing, worst_facing > 0.5)
	raker.free()
	await _frames(2)
	# Cover, and a gap.
	var block: Node = Props.block(self, HOME + Vector3(0.0, 0.0, -3.0), Vector3(3.0, 3.0, 0.6))
	var round_it := _anima(&"torso", HOME + Vector3(0.3, -0.5, -5.5))
	round_it.leap_chance = 0.0
	var got_round: bool = await _until(func(): return round_it.global_position.distance_to(p.global_position) < 2.6, 30.0)
	_check("T6 it gets round cover (%.1f m left)" % round_it.global_position.distance_to(p.global_position), got_round)
	round_it.free()
	block.free()
	var left_wall: Node = Props.block(self, HOME + Vector3(-2.2, 0.0, -3.0), Vector3(3.0, 3.0, 0.6))
	var right_wall: Node = Props.block(self, HOME + Vector3(2.2, 0.0, -3.0), Vector3(3.0, 3.0, 0.6))
	var through := _anima(&"torso", HOME + Vector3(0.0, -0.5, -5.5))
	through.leap_chance = 0.0
	var got_through: bool = await _until(func(): return through.global_position.z > HOME.z - 2.2, 30.0)
	_check("T6b and through a gap of 1.4 m", got_through)
	through.free()
	left_wall.free()
	right_wall.free()
	await _frames(2)
	# Its lunge against a wall.
	var stood: Vector3 = p.global_position
	var wall: Node = Props.block(self, HOME + Vector3(0.0, 0.0, -2.2), Vector3(6.0, 3.0, 0.6))
	var lunger := _anima(&"torso", HOME + Vector3(0.0, -0.5, -4.6))
	lunger.leap_chance = 1.0
	var latched := [false]

	for i in 300:
		await get_tree().physics_frame
		latched[0] = latched[0] or lunger.state == STATE.ON

	_check("T7 its lunge never takes you through a wall", not latched[0] and p.global_position.distance_to(stood) < 0.05 and lunger.global_position.z < wall.global_position.z)
	lunger.free()
	wall.free()
	await _frames(2)
	# Glass.
	var struck_one := _anima(&"torso", HOME + Vector3(0.0, -0.5, -7.0))
	struck_one.leap_chance = 0.0
	await _frames(20)
	var from_y: float = struck_one.global_position.y
	struck_one.jolted(Vector3.FORWARD)
	struck_one.body.jolt(Vector3.FORWARD)
	struck_one.body.tumble(Vector3.FORWARD)
	var went_up := 0.0
	var tipped := 0.0

	for i in 30:
		await get_tree().physics_frame
		went_up = maxf(went_up, struck_one.global_position.y - from_y)
		tipped = maxf(tipped, absf(struck_one.body.tipped()))

	var limbs_on: bool = struck_one.body.souls().all(func(soul): return struck_one.body.is_ancestor_of(soul))
	_check("T8 the Burst and the Shard move it (%.2f up, %.2f tipped), and its limbs stay on it" % [went_up, tipped], went_up > 0.05 and tipped > 0.1 and limbs_on)
	struck_one.free()
	await _frames(2)


## Its bottom hands dig in, and what is on them is hauled up to them.
func _mouth_digs() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(10)
	var one := _anima(&"torso", HOME + Vector3(0.3, -0.5, -14.0))
	one.leap_chance = 0.0
	await _until(func(): return one.state == STATE.RUSH, 4.0)
	await _frames(30)
	var body: Node3D = one.body
	var hauls_from: int = body.hauls_done()
	var worst_slip := 0.0
	var dragged_most := 0.0
	var dug_frames := 0
	var tips_under := true
	var wrist_clear := true
	var highest := -9.0
	var stretched := 0.0
	var plants: Array[Vector3] = []
	var held_at := Vector3.ZERO
	var body_at := Vector3.ZERO
	var was_dug := false

	for i in 480:
		await get_tree().physics_frame

		for arm in 4:
			stretched = maxf(stretched, body.arm_stretch(arm))

		var dug: bool = body.arm_dug_in(0)
		var floor_y: float = body.dug_floor(0)

		if dug and not was_dug:
			held_at = body.wrist(0)
			body_at = one.global_position
			plants.append(held_at)
		elif dug:
			worst_slip = maxf(worst_slip, body.wrist(0).distance_to(held_at))
			dragged_most = maxf(dragged_most, one.global_position.distance_to(body_at))
			dug_frames += 1

			if dug_frames % 10 == 0:
				tips_under = tips_under and body.fingertip_y(0) < floor_y
				wrist_clear = wrist_clear and body.wrist(0).y > floor_y + 0.08
		else:
			highest = maxf(highest, body.wrist(0).y - floor_y)

		was_dug = dug

	_check("Dg1 a hand dug in stays where it dug (%.3f m)" % worst_slip, dug_frames > 60 and worst_slip < 0.012)
	_check("Dg2 and the mass is dragged up to it (%.2f m)" % dragged_most, dragged_most > 0.2)
	_check("Dg3 its fingers are in the earth, its wrist out of it", tips_under and wrist_clear)
	_check("Dg4 it comes up and over, to dig in again (%.2f)" % highest, highest > 0.28)
	_check("Dg5 each time further on (%d)" % plants.size(), plants.size() >= 2 and plants[-1].distance_to(p.global_position) < plants[0].distance_to(p.global_position) - 0.3)
	_check("Dg6 all of them, none in step (%d)" % (body.hauls_done() - hauls_from), body.hauls_done() - hauls_from >= 6)
	_check("Dg7 no arm drawn out past what an arm can be (%.2f)" % stretched, stretched < 1.3)
	_check("Dg8 its arm reaches back into it, unbroken (%.3f)" % body.arm_end_gap(0), body.arm_end_gap(0) < 0.03)
	_check("Dg8b it throws up earth where they go in (%d)" % body.earth_shown(), body.earth_shown() >= 3)
	# Thrown, they let go; and they dig in again.
	one.throw_off(p.global_position)
	await _frames(3)
	var any_dug := false

	for i in 40:
		await get_tree().physics_frame

		for arm in 4:
			any_dug = any_dug or body.arm_dug_in(arm)

	_check("Dg9 thrown, they let go", not any_dug)
	await _until(func(): return one.state == STATE.RUSH, 4.0)
	await _frames(150)
	_check("Dg10 and it digs in again", body.arm_dug_in(0) or body.arm_dug_in(1))
	one.free()
	await _frames(2)
	# It doesn't dig through a wall.
	var wall: Node = Props.block(self, HOME + Vector3(0.0, 0.0, -4.0), Vector3(8.0, 3.0, 0.6))
	var at_wall := _anima(&"torso", HOME + Vector3(0.0, -0.5, -5.6))
	at_wall.leap_chance = 0.0
	var through_it := false

	for i in 300:
		await get_tree().physics_frame

		for arm in 4:
			if at_wall.body.arm_dug_in(arm):
				through_it = through_it or at_wall.body.wrist(arm).z > wall.global_position.z - 0.25

	_check("Dg11 it digs in on its own side of a wall", not through_it)
	at_wall.free()
	wall.free()
	await _frames(2)
	# Braced for its tell.
	var teller := _anima(&"torso", HOME + Vector3(0.0, -0.5, -3.2))
	teller.leap_chance = 1.0
	await _until(func(): return teller.state == STATE.TELL, 10.0)
	await _frames(90)
	_check("Dg12 gathering, its front hands are dug in, braced", teller.body.arm_dug_in(0) and teller.body.arm_dug_in(1))
	teller.free()
	await _frames(2)


## It is whole the moment it is there: arms working, hands in the earth, looking at you.
func _mouth_arrives_whole() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(10)
	var one := _anima(&"torso", HOME + Vector3(2.5, -0.5, 5.0))
	one.leap_chance = 0.0
	var body: Node3D = one.body
	var all_dug: bool = range(4).all(func(arm): return body.arm_dug_in(arm))
	_check("Ar1 before a frame has gone, its hands are in the earth", all_dug)
	_check("Ar2 and its arm goes back into it, unbroken (%.3f)" % body.arm_end_gap(0), body.arm_end_gap(0) < 0.03)
	await _frames(2)
	all_dug = range(4).all(func(arm): return body.arm_dug_in(arm))
	_check("Ar3 still, on its first tick", all_dug and body.hauls_done() == 0 and body.earth_shown() == 0)
	var to_you: Vector3 = ((p.global_position - one.global_position) * Vector3(1.0, 0.0, 1.0)).normalized()
	_check("Ar4 facing you (%.2f)" % (-body.global_basis.z).dot(to_you), (-body.global_basis.z).dot(to_you) > 0.9)
	var a: float = body.arm_stride(0)
	var b: float = body.arm_stride(1)
	_check("Ar5 not in step, from the start (%.2f, %.2f)" % [a, b], absf(a - b) > 0.1)
	one.free()
	await _frames(2)


## It is not meat: it is what is left of a great many, and they are not quiet in it.
func _mouth_spectral() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(10)
	var one := _anima(&"torso", HOME + Vector3(0.0, -0.5, -7.0))
	one.leap_chance = 0.0
	await _frames(5)
	var body: Node3D = one.body
	var mass: MeshInstance3D = body.part(&"Mass")
	var look: ShaderMaterial = mass.get_surface_override_material(0)
	_check("Sp1 its flesh is spectral", float(look.get_shader_parameter(&"spectral")) > 0.5)
	_check("Sp2 and frays, where its bone doesn't", float(look.get_shader_parameter(&"frays")) > 0.0 and not body.part(&"RibsLeft").get_surface_override_material(0).get_shader_parameter(&"frays"))
	_check("Sp3 it shows its hunger all over", mass.get_instance_shader_parameter(&"hunger") != null and body.part(&"RibsLeft").get_instance_shader_parameter(&"hunger") != null)
	var others := _anima(&"hands", HOME + Vector3(5.0, -0.5, -7.0))
	await _frames(2)
	_check("Sp4 the other forms' skin is as it was", not others.body._flesh.get_shader_parameter(&"spectral"))
	others.free()
	_check("Sp5 nothing floats off it: they are in it", body.find_child("Soul", true, false) == null)
	_check("Sp6 they press out from under its skin (%d)" % body.presses_held(), body.presses_held() >= 6 and int(look.get_shader_parameter(&"press_count")) >= 6)
	var on_skin: bool = range(body.presses_held()).all(func(n): return body.press_on_skin(n))
	_check("Sp7 where its skin is, and not in its mouth", on_skin)
	var kinds := {}
	var strongest := 0.0
	var most_at_once := 0
	var deepest := 0.0
	var jaw_low := 9.0
	var jaw_high := -9.0
	var fastest_back := 0.0
	var all_shown := true
	var was: Array[float] = []
	was.resize(body.presses_held())

	for i in 600:
		await get_tree().physics_frame
		var at_once := 0

		for n in body.presses_held():
			var strength: float = body.press_strength(n)
			strongest = maxf(strongest, strength)
			deepest = minf(deepest, strength)
			at_once += 1 if strength > 0.4 else 0
			fastest_back = maxf(fastest_back, (was[n] - strength) * 60.0)
			was[n] = strength

			if strength > 0.4:
				kinds[body.press_kind(n)] = true
				all_shown = all_shown and body.press_shown(n)

				if body.press_kind(n) == 0:
					jaw_low = minf(jaw_low, body.press_jaw(n))
					jaw_high = maxf(jaw_high, body.press_jaw(n))

		most_at_once = maxi(most_at_once, at_once)

	_check("Sp8 faces and hands both (%s)" % str(kinds.keys()), kinds.has(0) and kinds.has(1))
	_check("Sp8b each shows, up out of its skin", all_shown)
	_check("Sp9 several at once, hard (%d, %.2f)" % [most_at_once, strongest], most_at_once >= 2 and strongest > 0.8)
	_check("Sp10 the faces scream under it (%.2f..%.2f)" % [jaw_low, jaw_high], jaw_high - jaw_low > 0.4)
	_check("Sp11 hauled back in, sharply (%.1f a second), and the skin goes in after (%.2f)" % [fastest_back, deepest], fastest_back > 4.0 and deepest < -0.15)
	_check("Sp12 quiet enough, crawling (%.2f)" % body.hunger(), body.hunger() < 0.3)
	var out_low := 9.0
	var out_high := -9.0

	for i in 240:
		await get_tree().physics_frame

		for n in 3:
			out_low = minf(out_low, body.skull_out(n))
			out_high = maxf(out_high, body.skull_out(n))

	_check("Sp13 its heads try to get out of it too (%.2f..%.2f)" % [out_low, out_high], out_high - out_low > 0.15)
	# Now and then one gets a hand out, a real one, and it is hauled back.
	var furthest := -9.0
	var torn := 0.0
	var hidden_after := false

	for i in 1500:
		await get_tree().physics_frame
		furthest = maxf(furthest, body.burst_out())
		torn = maxf(torn, body.tear_open())
		hidden_after = hidden_after or (furthest > 0.2 and not body.burst_shown())

	_check("Sp14 a hand tears out of it (%.2f m)" % furthest, furthest > 0.3)
	_check("Sp15 the skin torn where it came (%.2f)" % torn, torn > 0.6)
	_check("Sp16 and it is hauled back in", hidden_after)
	one.free()
	await _frames(2)
	var teller := _anima(&"torso", HOME + Vector3(0.0, -0.5, -3.2))
	teller.leap_chance = 1.0
	await _until(func(): return teller.state == STATE.TELL, 10.0)
	await _frames(100)
	var most_gathered := 0
	var lean_toward := -1.0

	for i in 40:
		await get_tree().physics_frame
		var at_once := 0

		for n in teller.body.presses_held():
			at_once += 1 if teller.body.press_strength(n) > 0.4 else 0
			lean_toward = maxf(lean_toward, teller.body.press_toward(n, p.global_position))

		most_gathered = maxi(most_gathered, at_once)

	_check("Sp17 gathering, it blazes (%.2f)" % teller.body.hunger(), teller.body.hunger() > 0.6)
	_check("Sp18 and they all press at you (%d, %.2f)" % [most_gathered, lean_toward], most_gathered >= 4 and lean_toward > 0.4)
	teller.free()
	await _frames(2)


## Its limbs go as an animal's do: in an order, each its own, no two steps alike.
func _mouth_gait() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(10)
	var one := _anima(&"torso", HOME + Vector3(0.3, -0.5, -16.0))
	one.leap_chance = 0.0
	await _frames(30)
	var body: Node3D = one.body
	var order: Array[int] = []
	var was_up := [false, false, false, false]
	var both_up := 0
	var lifts: Array = [[], [], [], []]
	var high := [0.0, 0.0, 0.0, 0.0]
	var steps_took: Array = [[], [], [], []]
	var since := [0, 0, 0, 0]
	var hovered := 0

	for frame in 900:
		await get_tree().physics_frame

		for arm in 4:
			var up: bool = not body.arm_dug_in(arm)

			if up and not was_up[arm]:
				order.append(arm)
				since[arm] = 0
				high[arm] = 0.0

			if up:
				since[arm] += 1
				high[arm] = maxf(high[arm], body.wrist(arm).y - body.dug_floor(arm))
				hovered += 1 if body.arm_hovering(arm) else 0

			if was_up[arm] and not up:
				lifts[arm].append(high[arm])
				steps_took[arm].append(since[arm])

			was_up[arm] = up

		if not body.arm_dug_in(0) and not body.arm_dug_in(1):
			both_up += 1

	var in_order := 0

	for i in range(1, order.size()):
		var next_arm: int = [3, 2, 0, 1][order[i - 1]]
		in_order += 1 if order[i] == next_arm else 0

	_check("An1 it steps in an order, as an animal does (%d of %d)" % [in_order, order.size() - 1], order.size() >= 10 and in_order >= (order.size() - 1) * 0.7)
	_check("An2 its two front limbs are hardly ever up together (%d of 900)" % both_up, both_up < 130)
	var lift_spread := 0.0
	var time_spread := 0
	var means: Array[float] = []

	for arm in 4:
		if lifts[arm].size() >= 2:
			lift_spread = maxf(lift_spread, lifts[arm].max() - lifts[arm].min())
			time_spread = maxi(time_spread, steps_took[arm].max() - steps_took[arm].min())
			means.append(lifts[arm].reduce(func(a, b): return a + b) / float(lifts[arm].size()))

	_check("An3 no two steps alike: how high (%.2f)" % lift_spread, lift_spread > 0.08)
	_check("An4 how long (%d frames)" % time_spread, time_spread > 8)
	_check("An5 each limb its own (%.2f..%.2f)" % [means.min(), means.max()], means.size() == 4 and means.max() - means.min() > 0.12)
	_check("An6 it feels for the ground before it strikes (%d frames)" % hovered, hovered > 30)
	var left_way: Vector3 = (body.wrist(0) - one.global_position) * Vector3(1.0, 0.0, 1.0)
	var right_way: Vector3 = (body.wrist(1) - one.global_position) * Vector3(1.0, 0.0, 1.0)
	_check("An7 not mirrored (%.2f, %.2f m out)" % [left_way.length(), right_way.length()], absf(body.arm_reach_of(0) - body.arm_reach_of(1)) > 0.05)
	one.free()
	await _frames(2)


## It swells at you as it grabs.
func _mouth_swells() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(10)
	var one := _anima(&"torso", HOME + Vector3(0.0, -0.5, -3.3))
	one.leap_chance = 1.0
	await _frames(30)
	var body: Node3D = one.body
	_check("Sw0 crawling, it isn't swollen (%.2f)" % body.swollen(), body.swollen() < 0.1)
	var at_rest: Vector3 = body.mouth_size()
	var front_was: float = body.front_of_it().distance_to(p.global_position)
	await _until(func(): return one.state == STATE.TELL, 10.0)
	await _until(func(): return one.state == STATE.LEAP, 3.0)
	_check("Sw1 gathering, it swells (%.2f)" % body.swollen(), body.swollen() > 0.5)
	var size_now: Vector3 = body.mouth_size()
	_check("Sw2 wider, and out toward you", size_now.x > at_rest.x * 1.1 and size_now.z > at_rest.z * 1.15)
	_check("Sw3 its flesh is stretched", float(body.part(&"Mass").get_instance_shader_parameter(&"swell")) > 0.3)
	var nearest := 99.0
	var biggest := 0.0

	while one.state == STATE.LEAP:
		await get_tree().physics_frame
		biggest = maxf(biggest, body.swollen())

		for arm in 5:
			nearest = minf(nearest, body.wrist(arm).distance_to(p.global_position + Vector3.UP * 0.15))

	_check("Sw4 lunging, at its fullest (%.2f)" % biggest, biggest > 0.8)
	_check("Sw5 and every arm it has comes at you (%.2f m)" % nearest, nearest < 1.1)
	one.free()
	p.leech.free_all()
	await _frames(2)
	# Up close.
	var raker := _anima(&"torso", HOME + Vector3(0.0, -0.5, -2.7))
	raker.leap_chance = 0.0
	raker.health = 500.0
	await _until(func(): return raker.state == STATE.SWIPE, 9.0)
	var swung := 0.0
	var back_up := 0

	while raker.state == STATE.SWIPE:
		await get_tree().physics_frame
		swung = maxf(swung, raker.body.swollen())

	_check("Sw6 it swells into a rake too (%.2f)" % swung, swung > 0.4)
	await _until(func(): return raker.state == STATE.RUSH, 4.0)
	await _frames(40)
	_check("Sw7 and it goes down again (%.2f)" % raker.body.swollen(), raker.body.swollen() < 0.2)
	raker.free()
	await _frames(2)


## It is a great many of them dragged along as one: it has to read as a weight, everywhere it goes.
func _mouth_is_heavy() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(10)
	# Its crawl: slow, and in hauls.
	var one := _anima(&"torso", HOME + Vector3(0.0, -0.5, -16.0))
	one.leap_chance = 0.0
	await _until(func(): return one.state == STATE.RUSH, 3.0)
	await _frames(60)
	var from: Vector3 = one.global_position
	var fastest := 0.0
	var slowest := 99.0
	var frames := 360
	var hauls_from: int = one.body.hauls_done()
	var rocked_low := 9.0
	var rocked_high := -9.0

	for i in frames:
		await get_tree().physics_frame
		var pace: float = (one.velocity * Vector3(1.0, 0.0, 1.0)).length()
		fastest = maxf(fastest, pace)
		slowest = minf(slowest, pace)
		rocked_low = minf(rocked_low, one.body.rock())
		rocked_high = maxf(rocked_high, one.body.rock())

	var mean: float = (one.global_position - from).length() / (float(frames) / 60.0)
	_check("Wt1 it crawls, about half a metre a second (%.2f)" % mean, mean > 0.3 and mean < 0.6)
	_check("Wt2b each haul lands (%d)" % (one.body.hauls_done() - hauls_from), one.body.hauls_done() - hauls_from >= 2)
	_check("Wt2c the mass rocks with them (%.3f)" % (rocked_high - rocked_low), rocked_high - rocked_low > 0.05)
	_check("Wt2 it comes in hauls, not at a glide (%.2f..%.2f)" % [slowest, fastest], fastest > slowest * 2.0 and fastest < 1.1)
	one.free()
	await _frames(2)
	# Near it, you feel it come.
	var near_it := _anima(&"torso", HOME + Vector3(0.0, -0.5, -5.5))
	near_it.leap_chance = 0.0
	await _frames(60)
	var felt := 0.0

	for i in 300:
		await get_tree().physics_frame
		felt = maxf(felt, p.juice.trauma())

	_check("Wt2d near it, you feel each haul (%.3f)" % felt, felt > 0.02)
	near_it.free()
	await _frames(2)
	# Its lunge: a long time gathering, then the weight of it goes over.
	var lunger := _anima(&"torso", HOME + Vector3(0.0, -0.5, -3.2))
	lunger.leap_chance = 1.0
	await _until(func(): return lunger.state == STATE.TELL, 8.0)
	var told := 0

	while lunger.state == STATE.TELL:
		await get_tree().physics_frame
		told += 1

	_check("Wt3 it takes well over a second to gather (%.2f s)" % (float(told) / 60.0), told >= 114)
	var early: Vector3 = lunger.global_position
	var fastest_lunge := 0.0
	var steps := 0

	while lunger.state == STATE.LEAP:
		if steps == 12:
			_check("Wt4 it gets going slowly (%.2f m in 0.2 s)" % lunger.global_position.distance_to(early), lunger.global_position.distance_to(early) < 0.25)

		await get_tree().physics_frame
		steps += 1
		fastest_lunge = maxf(fastest_lunge, lunger.velocity.length())

	_check("Wt5 at its fastest it is no leap (%.1f m/s)" % fastest_lunge, fastest_lunge < 3.6)
	lunger.free()
	p.leech.free_all()
	await _frames(2)
	# Missing, it lies where it fell.
	var missed := _anima(&"torso", HOME + Vector3(0.0, -0.5, -3.2))
	missed.leap_chance = 1.0
	await _until(func(): return missed.state == STATE.LEAP, 8.0)
	missed.global_position += Vector3(4.0, 0.0, 0.0)
	var shaken_from: float = p.juice.trauma()
	await _until(func(): return missed.state == STATE.MISSED, 3.0)
	_check("Wt6b it comes down, and you feel it (%.2f)" % (p.juice.trauma() - shaken_from), p.juice.trauma() > shaken_from + 0.03)
	var lay := 0

	while missed.state == STATE.MISSED:
		await get_tree().physics_frame
		lay += 1

	_check("Wt6 missing, it takes a long time to gather itself (%.2f s)" % (float(lay) / 60.0), lay >= 130)
	missed.free()
	await _frames(2)
	# Up close.
	var raker := _anima(&"torso", HOME + Vector3(0.0, -0.5, -2.6))
	raker.leap_chance = 0.0
	raker.health = 500.0
	await _until(func(): return raker.state == STATE.WIND_UP, 8.0)
	var drew := 0

	while raker.state == STATE.WIND_UP:
		await get_tree().physics_frame
		drew += 1

	_check("Wt7 it draws back slowly for a rake (%.2f s)" % (float(drew) / 60.0), drew >= 75)
	var back_fastest := 0.0
	var turned_fastest := 0.0
	await _until(func(): return raker.state == STATE.BACK_OFF, 2.0)
	var last_facing: Vector3 = -raker.body.global_basis.z

	var worst_after := 1.0

	# Backing off, and on after it, with what it is still carrying.
	for i in 150:
		var backing: bool = raker.state == STATE.BACK_OFF
		await get_tree().physics_frame

		if backing:
			back_fastest = maxf(back_fastest, (raker.velocity * Vector3(1.0, 0.0, 1.0)).length())

		var facing: Vector3 = -raker.body.global_basis.z
		turned_fastest = maxf(turned_fastest, last_facing.angle_to(facing) * 60.0)
		last_facing = facing
		var to_you: Vector3 = ((p.global_position - raker.global_position) * Vector3(1.0, 0.0, 1.0)).normalized()
		worst_after = minf(worst_after, facing.dot(to_you))

	_check("Wt8 it backs off at its own pace (%.2f m/s)" % back_fastest, back_fastest < 0.85)
	_check("Wt9 it doesn't whip round (%.2f rad/s)" % turned_fastest, turned_fastest < 1.4)
	_check("Wt9b near you, it never turns from you, whatever it is carrying (%.2f)" % worst_after, worst_after > 0.5)
	raker.free()
	await _frames(2)


func _mouth_on_you() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(40)
	var hands: Node = p.leech_hands
	var hud: Node = p.hud
	var mouth := _anima(&"torso", p.global_position + Vector3(0.9, -0.5, -1.0))
	mouth.leap_chance = 0.0
	mouth.health = 900.0
	await _frames(1)
	mouth.put_on_you()
	await _frames(30)
	var slot: int = p.leech.slot_of(mouth)
	_check("C1 on you, the ribs come in round your view, with faces and hands", hands.cage_shown(slot) and hands.shown(slot) and hands.other_hand_shown() and hands.cage().faces_shown() >= 2)
	_check("C1b the one in the world is not (you would see two)", not mouth.body.visible)
	p.rotation.y += 1.4
	await _frames(3)
	var ahead: Vector3 = -p.camera.global_basis.z
	var from: Vector3 = p.camera.global_position
	_check("C2 you hit it where you see it", mouth.on_line(from, from + ahead * 6.0) and ahead.dot((mouth.global_position - from).normalized()) > 0.95)
	# It beats with the gulps, and its ribs keep out of the middle.
	var size: Vector2 = get_viewport().get_visible_rect().size
	var aspect := size.x / size.y
	var cage: Node3D = hands.cage()
	var low := 9.0
	var high := -9.0
	var all_clear := true
	p.power.power = 100.0

	for i in 120:
		await get_tree().physics_frame
		low = minf(low, cage.closed())
		high = maxf(high, cage.closed())

		if i % 6 == 0:
			all_clear = all_clear and cage.keeps_clear_of_middle(aspect)

	_check("C1c they beat with the gulps (%.2f..%.2f)" % [low, high], high - low > 0.15)
	_check("C7 the drain runs into its mouth", hud.drain_state()["threads"] == 1 and hud.drain_target(0).distance_to(cage.mouth_on_screen(aspect)) < 0.02)
	_check("C7b which is low in your view, out of the middle (%.2f)" % cage.mouth_on_screen(aspect).y, cage.mouth_on_screen(aspect).y > 2.0 / 3.0)
	_check("C8 over all of that, the cage is out of the middle third", all_clear)
	# Two whips.
	_hit(mouth, &"blow", &"blow")
	await _frames(2)
	_check("C3 the first whip cracks them, and it still has you", mouth.grip_left == 1 and mouth.ribs_cracked and mouth.state == STATE.ON)
	await _frames(20)
	_check("C3b you see it", cage.cracked_shown())
	_check("C3c and they stay clear of the middle, cracked", cage.keeps_clear_of_middle(aspect))
	_hit(mouth, &"blow", &"blow")
	await _frames(2)
	_check("C4 the second throws it off", mouth.state == STATE.THROWN and not hands.cage_shown(slot) and mouth.body.visible)
	await _frames(10)
	mouth.put_on_you()
	await _frames(25)
	_check("C5 back on you, whole again", hands.cage_shown(p.leech.slot_of(mouth)) and not mouth.ribs_cracked and not cage.cracked_shown() and mouth.grip_left == 2)
	# Everything that takes the others off takes it.
	var gone_each := true
	p.leech.tear_free()
	await _frames(2)
	gone_each = gone_each and not cage.visible
	mouth.put_on_you()
	await _frames(10)
	_hit(mouth, &"bullet", &"copal")
	await _frames(2)
	gone_each = gone_each and not cage.visible
	mouth.put_on_you()
	await _frames(10)
	p.leech.free_all()
	await _frames(2)
	gone_each = gone_each and not cage.visible
	_check("C6 a blink, the line or the Burst take the cage too", gone_each)
	# With the others and the curse.
	mouth.put_on_you()
	var face := _anima(&"face", p.global_position + Vector3(-0.9, -0.5, -0.2))
	var clawing := _anima(&"hands", p.global_position + Vector3(0.0, -0.5, 1.0))
	await _frames(1)
	face.put_on_you()
	clawing.put_on_you()
	p.statuses.apply(&"evil_eye", 10.0)
	await _frames(40)
	_check("C8b with a face, hands and the curse on you too, the middle is clear", hud.middle_kept_clear())
	p.statuses.clear(&"evil_eye")
	# Each whip goes where it's aimed: at the one you've turned to, or else into what's all round you.
	p.leech.tear_free()
	await _frames(2)
	_free([face])
	await _frames(1)
	mouth.put_on_you()
	clawing.put_on_you()
	await _frames(20)
	var arm: Node = p.revolver
	var eyes: Transform3D = p.camera.global_transform
	_check("C9 whipping, not looking at the other, it goes into the mouth", arm._whip_at_on_you(eyes) == mouth)
	var other_way: Vector3 = (clawing.global_position - eyes.origin).normalized()
	_check("C9b turned to the other, it goes there", arm._whip_at_on_you(Transform3D(Basis.looking_at(other_way, Vector3.UP), eyes.origin)) == clawing)
	_free([mouth, clawing])
	await _frames(3)


func _mouth_on_its_body() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(10)
	var one := _anima(&"torso", HOME + Vector3(0.0, -0.5, -9.0))
	one.leap_chance = 0.0
	await _frames(20)
	var body: Node3D = one.body
	_check("O3 it wears the mouth, and no boxes", body.part(&"Mass") != null and body.part(&"RibsLeft") != null and body._look == null)
	_check("O4 five arms and three faces on it", body.souls().size() == 8)
	_check("O4b it sits on the floor, as big as it should (%.2f)" % one.global_position.y, absf(one.global_position.y - 0.5) < 0.15)
	var top: Vector3 = one.global_position + Vector3(0.0, 0.7, 0.0)
	var from: Vector3 = top + Vector3(0.0, 0.0, 6.0)
	_check("O5 a shot at its upper flesh lands", one.global_position.distance_to(Geometry3D.get_closest_point_to_segment(one.global_position, from, top + Vector3(0.0, 0.0, -6.0))) <= one.hit_radius())
	var jaw_was: Array = []

	for i in body.souls().size():
		jaw_was.append(body.soul_at(i))

	var moved := 0
	await _frames(40)

	for i in body.souls().size():
		if not body.soul_at(i).is_equal_approx(jaw_was[i]):
			moved += 1

	# (Its four dug in stay where they dug: the arm that's free and its heads go on moving.)
	_check("O6 they move, each of its own (%d)" % moved, moved == 4)
	# (Stilled, so what it is doing doesn't set them back.)
	one.process_mode = Node.PROCESS_MODE_DISABLED
	body.ribs_to(1.0)
	await _frames(3)
	var left: Node3D = body.part(&"RibsLeft")
	var right: Node3D = body.part(&"RibsRight")
	_check("O7 the ribs swing apart", left.rotation.y * right.rotation.y < 0.0 and absf(left.rotation.y) > 0.3 and is_equal_approx(body.ribs_open(), 1.0))
	var left_fang: Vector3 = left.global_transform * Vector3(0.0, 0.0, -0.5)
	var right_fang: Vector3 = right.global_transform * Vector3(0.0, 0.0, -0.5)
	body.ribs_to(0.0)
	await _frames(3)
	var left_shut: Vector3 = left.global_transform * Vector3(0.0, 0.0, -0.5)
	var right_shut: Vector3 = right.global_transform * Vector3(0.0, 0.0, -0.5)
	_check("O7b outward, each to its own side", left_fang.distance_to(right_fang) > left_shut.distance_to(right_shut) + 0.2)
	one.free()
	await _frames(2)


func _forms() -> void:
	var hands := _anima(&"hands", Vector3(0, 0.3, -30))
	var face := _anima(&"face", Vector3(4, 1.3, -30))
	var torso := _anima(&"torso", Vector3(8, 0.4, -30))
	await _frames(2)
	_check("A1 three forms, their health", hands.health == 40.0 and face.health == 70.0 and torso.health == 130.0)
	_check("A2 lead passes through: resisted, little harm (%.1f)" % _lost, _hit(face, &"bullet", &"lead") == &"resisted" and is_equal_approx(_lost, 50.0 * 0.15))
	p.power.power = 50.0
	face.statuses.clear(&"exposed")
	await _frames(20)
	var result := _hit(face, &"bullet", &"copal")
	_check("A3 copal is weak, exposes, pays power back", result == &"weak" and face.is_exposed() and p.power.power > 50.0)
	_check("A4 a shell is a poor answer", _hit(torso, &"shot", &"lead") == &"resisted" and is_equal_approx(_lost, 25.0))
	_free([hands, face, torso])
	await _frames(5)
	for cloud in get_tree().get_nodes_in_group(&"copal_clouds"):
		cloud.queue_free()


func _rush() -> void:
	await _place_player(HOME)
	var hands := _anima(&"hands", Vector3(-3, 0.3, -24))
	var torso := _anima(&"torso", Vector3(3, 0.4, -24))
	await _until(func(): return hands.state == STATE.RUSH and torso.state == STATE.RUSH, 3.0)
	var hands_from := hands.global_position
	var torso_from := torso.global_position
	await _frames(60)
	var hands_covered := hands_from.distance_to(hands.global_position)
	var torso_covered := torso_from.distance_to(torso.global_position)
	_check("A5 from far off it rushes you (%.1f m)" % hands_covered, hands.global_position.distance_to(p.global_position) < hands_from.distance_to(p.global_position) - 1.2)
	_check("A5b hands are faster than a torso, but slow enough to aim at (%.1f, %.1f)" % [hands_covered, torso_covered], hands_covered > torso_covered * 1.4 and hands_covered < 4.2)
	# It goes hungrily: a slow creep you can hit, broken by surges.
	var slowest := 99.0
	var fastest := 0.0

	for i in 240:
		await get_tree().physics_frame

		if hands.state == STATE.RUSH:
			var flat := Vector2(hands.velocity.x, hands.velocity.z).length()
			slowest = minf(slowest, flat)
			fastest = maxf(fastest, flat)

	_check("A5c it creeps and surges (%.1f to %.1f m/s)" % [slowest, fastest], slowest < 2.2 and fastest > slowest * 2.0 and fastest < 6.0)
	_check("A8 hands and torso keep to the floor (%.2f, %.2f)" % [hands.global_position.y, torso.global_position.y], absf(hands.global_position.y - 0.25) < 0.2 and absf(torso.global_position.y - 0.5) < 0.2)
	_free([hands, torso])
	var face := _anima(&"face", Vector3(0, 1.3, -14))
	await _until(func(): return face.state == STATE.RUSH, 3.0)
	await _frames(20)
	_check("A8b the face floats (%.2f)" % face.global_position.y, absf(face.global_position.y - 1.3) < 0.3)
	var told := await _until(func(): return face.state == STATE.TELL, 6.0)
	var leapt := await _until(func(): return face.state == STATE.LEAP or face.state == STATE.ON, 2.0)
	_check("A6 close enough it tells, then leaps", told and leapt)
	_free([face])
	await _frames(3)
	var open := _anima(&"face", Vector3(0, 1.3, -6))
	await _until(func(): return open.state == STATE.TELL, 6.0)
	open.health = 1000.0
	var result := _hit(open, &"bullet", &"copal")
	_check("A7 in its tell, a copal hit breaks it: weak, triple (%.1f)" % _lost, result == &"weak" and open.state == STATE.THROWN and is_equal_approx(_lost, 150.0))
	_free([open])
	await _frames(3)
	var through := _anima(&"torso", Vector3(0, 0.4, -4))
	await _until(func(): return through.state == STATE.TELL, 12.0)
	var lead_result := _hit(through, &"bullet", &"lead")
	_check("A7b in its tell, lead still does nothing to it", through.state == STATE.TELL and lead_result == &"resisted")
	_free([through])
	await _frames(3)
	for cloud in get_tree().get_nodes_in_group(&"copal_clouds"):
		cloud.queue_free()


func _leeching() -> void:
	await _place_player(HOME)
	p.leech.free_all()
	_clear_all()
	await _frames(3)
	p.power.power = 100.0
	p.health = p.max_health
	# Leaps at you, standing still.
	var first := _anima(&"face", Vector3(0, 1.3, -7))
	var on := await _until(func(): return first.state == STATE.ON, 8.0)
	_check("A9 a leap that lands puts it on you", on and p.leech.count() == 1)
	p.invulnerable = false
	var power_from: float = p.power.power
	var life_from: float = p.health
	await _frames(480)
	var power_rate: float = (power_from - p.power.power) / 8.0
	var life_rate: float = (life_from - p.health) / 8.0
	_check("A11 it drains power (%.1f /s) and life (%.1f /s)" % [power_rate, life_rate], absf(power_rate - 8.0) < 0.5 and absf(life_rate - 2.5) < 0.3)
	var stood: float = p.health
	_check("A11b your power doesn't refill", p.power.refill_scale == 0.0)
	_check("A11c it is fed by what it drinks (%.1f)" % first.fed, first.fed > 7.0)
	_check("A13 one on you: pace 0.8", is_equal_approx(p.leech.speed(), 0.8))
	_check("A13b with the curse too, the costs multiply", _both_multiply())
	p.power.power = 0.0
	p.health = p.max_health
	life_from = p.health
	await _frames(300)
	var empty_rate: float = (life_from - p.health) / 5.0
	_check("A12 no power left, life goes twice as fast (%.1f)" % empty_rate, absf(empty_rate - 5.0) < 0.5)
	_check("A11d your shield doesn't refill while it is on you", p.health < stood)
	p.power.power = 100.0

	# Back at the kit room, with one on you.
	p.invulnerable = true
	var safe: Node3D = SafePlace.build(self, HOME, Vector3(20, 6, 20))
	p.loadout.lock()
	await _frames(240)
	_check("A18 with one on you the kit room won't restock you", p.loadout.locked and p.leech.count() == 1)
	p.loadout.unlock()
	safe.queue_free()

	# Killed, half of what it drank comes back.
	p.power.power = 20.0
	await _frames(60)
	var drank: float = first.fed
	var before: float = p.power.power
	first.take_hit(1000.0, p, &"power", first.global_position, Vector3.FORWARD)
	_check("A15 what it drank, half comes back when it dies (%.1f, %.1f)" % [p.power.power - before, drank], absf(p.power.power - before - drank * 0.5) < 0.5)
	_check("A15b and it lets go", p.leech.count() == 0 and is_equal_approx(p.leech.speed(), 1.0))
	await _frames(3)

	# Four come: three on you, the rest wait.
	var pack: Array = []
	for i in 4:
		var turn := float(i) * TAU / 4.0
		pack.append(_anima(&"hands", Vector3(cos(turn) * 6.0, 0.3, sin(turn) * 6.0)))
	await _until(func(): return p.leech.count() == 3, 8.0)
	# (One still leaping when the last place went misses first.)
	await _frames(90)
	var waiting: Array = pack.filter(func(a): return a.state != STATE.ON)
	var waits_in: Array = [STATE.CIRCLE, STATE.RUSH, STATE.WIND_UP, STATE.SWIPE, STATE.BACK_OFF]
	_check("A14 no more than three (%d); the rest wait, circling or coming in to cut" % p.leech.count(), p.leech.count() == 3 and waiting.size() == 1 and waits_in.has(waiting[0].state))
	_check("A13c three on you: pace 0.5", is_equal_approx(p.leech.speed(), 0.5))
	_check("A10a the slots are all different", _slots_differ(pack.filter(func(a): return a.state == STATE.ON)))
	var gone: Node3D = pack.filter(func(a): return a.state == STATE.ON)[0]
	gone.queue_free()
	await _frames(3)
	_check("A17 freed while on you, the leech forgets it", p.leech.count() >= 2 and not p.leech.on_me().has(gone))
	_free(pack)
	await _frames(3)
	_check("A17b all gone, nothing is left on you", p.leech.count() == 0)

	# A dodge makes it miss.
	await _place_player(HOME)
	var missed := _anima(&"face", Vector3(0, 1.3, -7))
	await _until(func(): return missed.state == STATE.TELL, 8.0)
	Input.action_press("move_left")
	await _press("gun_dodge")
	await _until(func(): return missed.state == STATE.MISSED or missed.state == STATE.ON, 2.0)
	Input.action_release("move_left")
	_check("A10 a dodge at the right moment makes it miss", missed.state == STATE.MISSED and p.leech.count() == 0)
	_free([missed])
	await _frames(3)


func _both_multiply() -> bool:
	p.statuses.apply(&"evil_eye", 8.0)
	var both: float = p.fight_pace()
	var expected: float = p.curse.speed() * p.leech.speed()
	p.statuses.clear(&"evil_eye")
	return is_equal_approx(both, expected) and expected < p.leech.speed()


func _slots_differ(on: Array) -> bool:
	var seen := {}

	for a in on:
		seen[p.leech.slot_of(a)] = true

	return seen.size() == on.size() and on.size() == 3


## Those on you, from these forms, put there directly.
func _on_you(forms: Array) -> Array:
	var list: Array = []

	for i in forms.size():
		var turn := float(i) * TAU / 3.0 + 0.4
		var e := _anima(forms[i], p.global_position + Vector3(cos(turn) * 0.8, 0.5, sin(turn) * 0.8))
		await _frames(1)
		e.put_on_you()
		list.append(e)

	await _frames(2)
	return list


func _whip() -> bool:
	var went: bool = p.revolver.try_whip()
	await _frames(int(p.revolver.WHIP_TIME * 60.0) + 4)
	return went


func _getting_off() -> void:
	await _place_player(HOME)
	p.invulnerable = true
	p.power.power = 100.0
	_clear_all()
	await _frames(3)
	var two: Array = await _on_you([&"hands", &"hands"])
	_check("W0 what is on you can be aimed at: it stays where it came from", _stays_put(two[0]))
	_face(two[0])
	await _frames(2)
	var whipped: bool = await _whip()
	_check("W1 a whip throws off the one you aim at, only that one", whipped and two[0].state == STATE.THROWN and two[1].state == STATE.ON)
	_check("W1a from anywhere you stand: it needs no cone", p.leech.count() == 1)
	await _frames(25)
	_check("W1b thrown clear, stunned and exposed (%.1f m)" % two[0].global_position.distance_to(p.global_position), two[0].global_position.distance_to(p.global_position) > 1.5 and two[0].is_exposed() and two[0].state == STATE.THROWN)
	_free(two)
	await _frames(3)
	var faces: Array = await _on_you([&"face", &"face"])
	await _frames(2)
	var whipped_face: bool = await _whip()
	_check("W1c a whip gets a face off your face, only one of them", whipped_face and p.leech.count() == 1)
	_free(faces)
	await _frames(3)

	var torso: Array = await _on_you([&"torso"])
	_face(torso[0])
	await _whip()
	_check("W2 a torso needs two whips (%d left)" % torso[0].grip_left, torso[0].state == STATE.ON and torso[0].grip_left == 1)
	await _whip()
	_check("W2b and the second throws it off", torso[0].state == STATE.THROWN)
	_free(torso)
	await _frames(3)

	var pair: Array = await _on_you([&"torso", &"torso"])
	p.power.power = 50.0
	_hit(pair[0], &"bullet", &"copal")
	_check("W3 a copal round throws off the one it hits, and pays you", pair[0].state == STATE.THROWN and pair[1].state == STATE.ON and p.power.power > 50.0)
	await _frames(30)
	p.power.power = 80.0
	p.invulnerable = false
	var was_power: float = p.power.power
	await _frames(60)
	p.invulnerable = true
	_check("W3b its cloud doesn't: the other holds on, draining at half (%.1f)" % (was_power - p.power.power), pair[1].state == STATE.ON and absf(was_power - p.power.power - 6.0) < 0.6)
	var smoked := _anima(&"hands", p.global_position + Vector3(0, 0, -3.0))
	await _frames(150)
	_check("W3c nothing can latch inside the cloud", smoked.state != STATE.ON and p.leech.slot_of(smoked) < 0)
	_free(pair + [smoked])
	_clear_clouds()
	await _frames(3)

	var kept: Array = await _on_you([&"torso"])
	var was: float = kept[0].health
	_hit(kept[0], &"bullet", &"lead")
	_check("W4 lead doesn't free you", kept[0].state == STATE.ON and kept[0].health < was)
	was = kept[0].health
	_hit(kept[0], &"shot", &"lead")
	var after_shell: float = kept[0].health
	_hit(kept[0], &"shard", &"lead")
	_check("W4b nor a shell, nor a shard, though both hurt", kept[0].state == STATE.ON and after_shell < was and kept[0].health < after_shell)
	_face(kept[0])
	await _until(func(): return p.revolver.ready_to_fire(), 4.0)
	var read := await _fired_read()
	_check("W4c a lead ball is seen to pass through (%s)" % str(read), read == &"through")
	_free(kept)
	await _frames(3)

	# The Ward.
	await _until(func(): return p.revolver.ready_to_fire(), 4.0)
	p.power.power = 100.0
	var warded: Array = await _on_you([&"hands", &"face"])
	Input.action_press("spell_2")
	await _frames(40)
	Input.action_release("spell_2")
	await _frames(2)
	_check("W5 the Ward throws off everything", p.leech.count() == 0 and warded[0].state == STATE.THROWN and warded[1].state == STATE.THROWN)
	var outsider := _anima(&"hands", p.global_position + Vector3(0, 0, -3.0))
	await _frames(100)
	_check("W5b and they can't enter it (%.2f m)" % outsider.global_position.distance_to(p.global_position), p.leech.slot_of(outsider) < 0 and outsider.state != STATE.ON and not WardScript.covers(outsider.global_position))
	_free(warded + [outsider])
	# (Being hauled at can carry you out of a ward that is still up: wait it out.)
	await _frames(int(WardScript.LIFE * 60.0) + 90)

	# A blink.
	p.power.power = 100.0
	var blinked: Array = await _on_you([&"face"])
	p.caster._blink_to(p.global_position + Vector3(0, 0, -3.0))
	await _frames(1)
	_check("W6 a blink tears you free, but they aren't thrown or hurt", p.leech.count() == 0 and blinked[0].state != STATE.ON and blinked[0].state != STATE.THROWN and not blinked[0].is_exposed() and is_equal_approx(blinked[0].health, 70.0))
	_free(blinked)
	await _place_player(HOME)

	# No power.
	var bound: Array = await _on_you([&"face"])
	p.power.power = 0.0
	await _until(func(): return p.revolver.ready_to_fire(), 4.0)
	Input.action_press("spell_2")
	await _frames(40)
	Input.action_release("spell_2")
	_check("W7 no power: the Ward refuses (covered %s, state %d, power %.1f)" % [str(WardScript.covers(p.global_position + Vector3.UP)), bound[0].state, p.power.power], not WardScript.covers(p.global_position + Vector3.UP) and bound[0].state == STATE.ON)
	_face(bound[0])
	await _whip()
	_check("W7b the whip still works", bound[0].state == STATE.THROWN)
	_free(bound)
	await _frames(3)

	# Over a ledge with one on you.
	Props.block(self, Vector3(30, 0.6, -2), Vector3(4, 1.2, 2))
	await _place_player(Vector3(30, 1.05, 0.2))
	p.rotation.y = 0.0
	p.neck.rotation = Vector3.ZERO
	var alone: float = await _over_the_ledge()
	_check("W8a with nothing on you it mantles (%.2f)" % alone, alone > 1.6)
	await _place_player(Vector3(30, 1.05, 0.2))
	var rider: Array = await _on_you([&"hands"])
	var ridden: float = await _over_the_ledge()
	_check("W8 mantling with one on you: it holds on (%.2f)" % ridden, ridden > 1.6 and p.leech.count() == 1 and rider[0].state == STATE.ON)
	_free(rider)
	await _frames(3)
	p.power.power = 100.0


## The curse and the drain at once: one body under attack.
func _both_view() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(40)
	var hud: Node = p.hud
	var eye_look: ShaderMaterial = hud._curse_view.material
	var power_was: float = p.power.power
	# The curse alone.
	p.statuses.apply(&"evil_eye", 300.0)

	for i in 5:
		p.curse.deepen()

	await _frames(90)
	var alone: Dictionary = hud.curse_state()
	_check("B7 curse alone: as it was", alone["drained"] == 0.0 and alone["squeeze"] == 0.0 and eye_look.get_shader_parameter(&"drained") == 0.0)
	# One on you, to your right, and little will left.
	var a := _anima(&"hands", p.global_position + Vector3(0.9, 0.5, -0.2))
	await _frames(1)
	a.put_on_you()
	a.health = 500.0
	p.power.power = p.power.MAX * 0.2
	await _frames(70)
	var state: Dictionary = hud.curse_state()
	_check("B1 drained, the flesh goes pale (%.2f)" % state["drained"], state["drained"] > 0.5 and float(eye_look.get_shader_parameter(&"drained")) > 0.5)
	_check("B3 the eyes turn to what is on you (%.2f)" % state["eyes_to"].x, state["eyes_to"].x > 0.5 and eye_look.get_shader_parameter(&"feeders")[0].z > 0.5)
	var squeeze_low := 1.0
	var squeeze_high := 0.0
	var age_least := 1.0

	for i in 240:
		await get_tree().physics_frame
		var now: float = hud.curse_state()["squeeze"]
		squeeze_low = minf(squeeze_low, now)
		squeeze_high = maxf(squeeze_high, now)
		age_least = minf(age_least, eye_look.get_shader_parameter(&"claw_age"))

	_check("B2 on a gulp the flesh squeezes in (%.2f to %.2f)" % [squeeze_low, squeeze_high], squeeze_high > squeeze_low + 0.3)
	_check("B4 a rake reaching the flesh tears it (%.2f)" % age_least, age_least < 0.5)
	hud.claw_at(1.0)
	await _frames(2)
	var claws: PackedVector3Array = eye_look.get_shader_parameter(&"claws_from")
	_check("B4b so does a swipe", float(eye_look.get_shader_parameter(&"claw_age")) < 0.5 and claws[0].z + claws[1].z + claws[2].z > 0.0)
	_check("B5 one crosshair", hud._crosshair.marks_shown() == 1)
	# The worst: all six, and three on you.
	var b := _anima(&"face", p.global_position + Vector3(-0.9, 0.5, -0.2))
	var c := _anima(&"hands", p.global_position + Vector3(0.0, 0.5, 0.9))
	await _frames(1)
	b.put_on_you()
	c.put_on_you()
	await _frames(70)
	_check("B6 at the worst, the middle is clear", hud.middle_kept_clear())
	var ahead: Vector3 = p.camera.global_position - p.camera.global_transform.basis.z * 6.0
	_check("B6b a stare from dead ahead keeps out of it", hud.gazer_keeps_clear(hud._edge_mark(p.camera, ahead, get_viewport().get_visible_rect().size)))
	# The drain gone, the flesh comes back; nor do the eyes stay turned.
	p.leech.free_all()
	await _frames(120)
	var back: Dictionary = hud.curse_state()
	var left_on: PackedVector3Array = eye_look.get_shader_parameter(&"feeders")
	_check("B7b the drain gone, the flesh comes back (%.2f)" % back["drained"], back["drained"] < 0.05 and float(eye_look.get_shader_parameter(&"drained")) < 0.05)
	_check("B7d and no eye stays turned", left_on[0].z < 0.01 and left_on[1].z < 0.01 and left_on[2].z < 0.01)
	# The curse gone, the drain as it was.
	_clear_all()
	await _frames(4)
	var d := _anima(&"face", p.global_position + Vector3(0.9, 0.5, -0.2))
	await _frames(1)
	d.put_on_you()
	p.statuses.clear(&"evil_eye")
	await _frames(240)
	_check("B7c the curse gone, the drain as it was", not hud.curse_view_shown() and hud.drain_view_shown())
	p.power.power = power_was
	p.leech.free_all()
	_clear_all()
	await _frames(30)


func _drained_view() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(40)
	var hud: Node = p.hud
	var hands: Node = p.leech_hands
	_check("S1 nothing on you, nothing shows", hud.drain_state()["drain"] < 0.01 and not hud.drain_view_shown())
	# One to your left, as you look.
	var a := _anima(&"face", p.global_position + Vector3(-0.9, 0.5, -0.2))
	await _frames(1)
	a.put_on_you()
	await _frames(50)
	var d1: float = hud.drain_state()["drain"]
	_check("S2 one on you: it starts (%.2f)" % d1, d1 > 0.2 and hud.drain_view_shown())
	var slot_a: int = p.leech.slot_of(a)
	_check("S3 hands in your view on its side (%.2f)" % hands.on_screen(slot_a).x, hands.shown(slot_a) and hands.on_screen(slot_a).x < 0.5)
	_check("S3b never over the crosshair (%.2f)" % hands.on_screen(slot_a).distance_to(Vector2(0.5, 0.5)), hands.on_screen(slot_a).distance_to(Vector2(0.5, 0.5)) > 0.28)
	_check("S4 a thread toward the one holding you", hud.drain_state()["threads"] == 1)
	var b := _anima(&"face", p.global_position + Vector3(0.9, 0.5, -0.2))
	var c := _anima(&"hands", p.global_position + Vector3(0.0, 0.5, 0.9))
	await _frames(1)
	b.put_on_you()
	c.put_on_you()
	await _frames(60)
	var d3: float = hud.drain_state()["drain"]
	_check("S2b deepens with each (%.2f, %.2f)" % [d1, d3], d3 > d1 + 0.2)
	_check("S3c the right one on the right, and each shown", hands.on_screen(p.leech.slot_of(b)).x > 0.5 and hands.shown(p.leech.slot_of(c)))
	_check("S4b a thread for each, even from behind you", hud.drain_state()["threads"] == 3)
	# It drinks in gulps.
	var gulps := [0]
	var tugged := [0.0]
	var gulped_watch := func(): gulps[0] += 1
	p.leech.gulped.connect(gulped_watch)
	var gulp_seen := 0.0
	var squeeze_low := 9.0
	var squeeze_high := -9.0
	var trauma_seen := 0.0
	p.power.power = 100.0

	for i in 130:
		await get_tree().physics_frame
		gulp_seen = maxf(gulp_seen, hud.drain_state()["gulp"])
		squeeze_low = minf(squeeze_low, hands.squeeze(slot_a))
		squeeze_high = maxf(squeeze_high, hands.squeeze(slot_a))
		trauma_seen = maxf(trauma_seen, p.juice._trauma)

	p.leech.gulped.disconnect(gulped_watch)
	# What a gulp takes, against what is taken between them.
	p.power.power = 100.0
	var worst := 0.0
	var least := 99.0
	var power_was: float = p.power.power

	for i in 130:
		await get_tree().physics_frame
		var lost: float = power_was - p.power.power
		power_was = p.power.power
		worst = maxf(worst, lost)
		least = minf(least, lost)

	_check("S9 your magic goes in lurches, with each gulp (%.3f to %.3f a tick)" % [least, worst], worst > least * 3.0)
	_check("S9b your magic and your shields are up where you can see them go", hud.get("_crosshair").power_alpha > 0.9 and hud.get("_shields").modulate.a > 0.5)
	_check("S9c your sight is pulled toward the hands that hold you (%.3f)" % hud.drain_state()["pull"], hud.drain_state()["pull"] > 0.0)
	p.power.power = 0.0
	await _frames(30)
	_check("S9d no magic left, your sight knows it (%.2f)" % hud.drain_state()["magic"], hud.drain_state()["magic"] < 0.05)
	p.invulnerable = false
	var life_was: float = p.health
	p.health = p.max_health * 0.2
	await _frames(5)
	_check("S9e your life low, your sight knows that too (%.2f)" % hud.drain_state()["life"], hud.drain_state()["life"] < 0.25)
	p.health = life_was
	p.invulnerable = true
	p.power.power = 100.0
	await _frames(30)
	_check("S7 it drinks in gulps, not a steady bleed (%d in 2.2 s)" % gulps[0], gulps[0] >= 2 and gulps[0] <= 4)
	_check("S7b each one shows on your sight (%.2f)" % gulp_seen, gulp_seen > 0.5)
	_check("S7c its hands squeeze with each (%.2f to %.2f)" % [squeeze_low, squeeze_high], squeeze_high > squeeze_low + 0.2)
	_check("S7e the hands on you carry its fire", hands.has_ember(slot_a))
	# They come at you, and are flung off: they don't just appear.
	var late := _anima(&"hands", p.global_position + Vector3(-0.2, 0.5, 0.9))
	await _frames(40)
	late.queue_free()
	await _frames(3)
	var newcomer := _anima(&"hands", p.global_position + Vector3(0.0, 0.5, -0.9))
	await _frames(1)
	var taken_before: Array = p.leech.on_me()

	if newcomer.put_on_you():
		var slot_new: int = p.leech.slot_of(newcomer)
		await get_tree().process_frame
		await get_tree().process_frame
		var arriving: float = hands.arrival(slot_new)
		await _frames(30)
		_check("S11 a hand lunges into your view (%.2f, then %.2f)" % [arriving, hands.arrival(slot_new)], arriving < 0.6 and hands.arrival(slot_new) > 0.99)
		newcomer.throw_off(p.global_position)
		await get_tree().process_frame
		await get_tree().process_frame
		_check("S11b thrown, it is flung out of your view, not gone at once", hands.shown(slot_new) and hands.flung(slot_new) > 0.0)
		await _frames(20)
		_check("S11c and then gone", not hands.shown(slot_new))

	newcomer.queue_free()
	await _frames(2)
	# It claws: rears back open, then rakes down and closes.
	var open_most := 9.0
	var closed_most := -9.0
	var high := -9.0
	var low := 9.0
	var marks_most := 0.0
	var fingers_apart := 0.0

	for i in 130:
		await get_tree().process_frame
		open_most = minf(open_most, hands.curl(slot_a))
		closed_most = maxf(closed_most, hands.curl(slot_a))
		high = maxf(high, hands.reach_y(slot_a))
		low = minf(low, hands.reach_y(slot_a))
		marks_most = maxf(marks_most, hud.drain_state()["claws"])
		fingers_apart = maxf(fingers_apart, hands.finger_spread(slot_a))

	_check("S10 it opens and closes its claw (%.2f to %.2f)" % [open_most, closed_most], closed_most > open_most + 0.6)
	_check("S10b it rakes down your view, a long way (%.3f)" % (high - low), high - low > 0.05)
	_check("S10c its fingers scrabble, not all as one (%.2f)" % fingers_apart, fingers_apart > 0.15)
	_check("S10e they spread on the wind-up and come together on the rake (%.2f)" % hands.splay_range(slot_a), hands.splay_range(slot_a) > 0.1)
	_check("S10d it leaves claw marks across your sight (%.2f)" % marks_most, marks_most > 0.5)
	_check("S7d and it jolts your view (%.3f)" % trauma_seen, trauma_seen > 0.02)
	p.power.power = 5.0
	await _frames(40)
	var sag: float = p.leech.sag()
	_check("S8 your will gone, your gun arm sags (%.2f)" % sag, sag > 0.6)
	_check("S8b it shows (%.3f)" % p.hand.position.y, p.hand.position.y < -0.005)
	_check("S8c and your view is heavy", p.juice.unsteady() > 0.3)
	p.power.power = 100.0
	p.statuses.apply(&"evil_eye", 8.0)
	await _frames(40)
	_check("S6 with the curse on too, both show", hud.curse_view_shown() and hud.drain_view_shown())
	p.statuses.clear(&"evil_eye")
	var slot_b: int = p.leech.slot_of(b)
	p.leech.free_all()
	await _frames(10)
	var state: Dictionary = hud.drain_state()
	_check("S5 thrown off: colour floods back at once (%.2f, %.2f)" % [state["drain"], state["release"]], state["release"] > 0.5 and state["drain"] < d3 * 0.5)
	_check("S5b and the hands are gone", not hands.shown(slot_a) and not hands.shown(slot_b))
	await _frames(60)
	_check("S8d your arm comes back up", absf(p.hand.position.y) < 0.002 and p.leech.sag() < 0.01)
	_check("S5c and then nothing shows", not hud.drain_view_shown())
	_free([a, b, c])
	await _frames(3)


## Walks at the ledge and over: the highest you got.
func _over_the_ledge() -> float:
	var peak := 0.0
	Input.action_press("move_forward")
	await _until(func(): return p.global_position.z < -0.35, 3.0)
	Input.action_press("jump")

	for i in 120:
		await get_tree().physics_frame
		peak = maxf(peak, p.global_position.y)

	Input.action_release("move_forward")
	Input.action_release("jump")
	return peak


func _stays_put(e: Node3D) -> bool:
	var was := e.global_position
	var yaw_was: float = p.rotation.y
	p.rotation.y += 1.2
	var same := e.global_position.distance_to(was) < 0.01
	p.rotation.y = yaw_was
	return same


func _face(target: Node3D) -> void:
	var way: Vector3 = (target.global_position - p.camera.global_position).normalized()
	p.rotation.y = atan2(-way.x, -way.z)
	p.neck.rotation = Vector3(asin(way.y), 0.0, 0.0)


## Fighting, not only clinging: swipes that cut you and don't stay.
func _swipes() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(3)
	p.invulnerable = false
	p.health = 500.0
	p.power.power = 100.0
	var e := _anima(&"hands", HOME + Vector3(0, -0.75, -1.3))
	var wound_up := await _until(func(): return e.state == STATE.WIND_UP, 3.0)
	_check("P1 in reach, it winds up to swipe, it doesn't leap", wound_up)
	var was: float = p.health
	var power_was: float = p.power.power
	var from_you: float = e.global_position.distance_to(p.global_position)
	await _until(func(): return e.state == STATE.BACK_OFF, 2.0)
	var lost: float = was - p.health
	_check("P2 the swipe hurts your life (%.1f), and takes no power" % lost, is_equal_approx(lost, 6.0) and p.power.power == power_was)
	_check("P2b it doesn't get on you", p.leech.count() == 0)
	await _until(func(): return e.state == STATE.RUSH, 2.0)
	var backed: float = e.global_position.distance_to(p.global_position) - from_you
	# (Only its swipes, here: on its way back in it could have leapt.)
	e._leap_in = 99.0
	var again := await _until(func(): return e.state == STATE.WIND_UP, 6.0)
	_check("P3 then it backs off (%.2f m), and comes again" % backed, backed > 1.0 and again)
	# A dodge avoids it: and takes you out of its reach.
	await _until(func(): return e.state == STATE.WIND_UP, 6.0)
	was = p.health
	await _press("gun_dodge")
	await _until(func(): return e.state == STATE.BACK_OFF, 2.0)
	_check("P4 a dodge avoids it", p.health == was)
	await _place_player(HOME)
	_free([e])
	await _frames(2)
	# Its wind-up is an opening: anything but lead breaks it.
	var broke := _anima(&"hands", HOME + Vector3(0, -0.75, -1.3))
	await _until(func(): return broke.state == STATE.WIND_UP, 3.0)
	broke.health = 500.0
	_hit(broke, &"bullet", &"copal")
	_check("P5 a non-lead hit in its wind-up breaks it, and opens it", broke.state == STATE.THROWN and broke.is_exposed())
	_free([broke])
	await _frames(2)
	var leaded := _anima(&"face", HOME + Vector3(0, 0.25, -1.5))
	await _until(func(): return leaded.state == STATE.WIND_UP, 3.0)
	leaded.health = 500.0
	was = p.health
	_hit(leaded, &"bullet", &"lead")
	var went_on := await _until(func(): return leaded.state == STATE.BACK_OFF, 2.0)
	_check("P5b lead passes through, and it swipes anyway", went_on and p.health < was)
	_free([leaded])
	await _frames(2)
	# Out of reach, in leap range, it may leap; and not again within 4 s.
	var leaper := _anima(&"hands", HOME + Vector3(0, -0.75, -2.3))
	leaper._state_t = 0.0
	leaper.state = STATE.RUSH
	var leaps := 0
	var was_leaping := false

	for i in 200:
		await get_tree().physics_frame
		leaper.global_position = HOME + Vector3(0, -0.75, -2.3)
		leaper.state = leaper.state if leaper.state != STATE.ON else STATE.RUSH

		if leaper.state == STATE.TELL and not was_leaping:
			leaps += 1

		was_leaping = leaper.state == STATE.TELL

		if leaper.state == STATE.LEAP or leaper.state == STATE.MISSED or leaper.state == STATE.THROWN:
			leaper._enter(STATE.RUSH)

	_check("P6 in leap range it tells, and not again within 4 s (%d in 3.3 s)" % leaps, leaps == 1)
	_free([leaper])
	await _frames(2)
	# Held by one, another can still cut you. And dead, you take nothing.
	var holder := _anima(&"hands", HOME + Vector3(1.5, -0.75, 0))
	var cutter := _anima(&"hands", HOME + Vector3(-1.3, -0.75, 0))
	await _frames(1)
	holder.put_on_you()
	was = p.health
	p.power.power = 0.0
	await _until(func(): return cutter.state == STATE.BACK_OFF, 4.0)
	_check("P8 held by one, another can still cut you (%.1f)" % (was - p.health), was - p.health >= 6.0)
	_free([holder, cutter])
	await _frames(2)
	# Put on you mid wind-up: the swipe is gone.
	var held := _anima(&"hands", HOME + Vector3(0, -0.75, -1.3))
	await _until(func(): return held.state == STATE.WIND_UP, 3.0)
	was = p.health
	p.power.power = 100.0
	held.put_on_you()
	p.leech.player = p
	await _frames(30)
	_check("P10 put on you mid wind-up: the swipe is gone", held.state == STATE.ON and held.get("_swung") != true)
	_free([held])
	await _frames(2)
	# The three forms, their numbers.
	var taken := {}

	for form in [&"hands", &"face", &"torso"]:
		var one := _anima(form, HOME + Vector3(0, -0.75 if form != &"face" else 0.25, -1.3))
		await _frames(2)
		one._form = one._form.duplicate()
		await _until(func(): return one.state == STATE.WIND_UP, 4.0)
		was = p.health
		await _until(func(): return one.state == STATE.BACK_OFF, 3.0)
		taken[form] = was - p.health
		_free([one])
		await _frames(2)

	_check("P11 the three forms, their numbers (%s)" % taken, is_equal_approx(taken[&"hands"], 6.0) and is_equal_approx(taken[&"face"], 10.0) and is_equal_approx(taken[&"torso"], 14.0))
	p.health = p.get("max_health") if p.get("max_health") != null else p.health
	p.invulnerable = true
	await _frames(2)


## How a swipe looks: drawn back and open, then raked shut; a cut on your view.
func _swipes_seen() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(3)
	var hud: Node = p.hud
	var e := _anima(&"hands", HOME + Vector3(0, -0.75, -1.3))
	await _until(func(): return e.state == STATE.WIND_UP, 3.0)
	await _frames(14)
	var open: float = e.body.finger_curl()
	_check("Q1 wind-up: drawn up, fingers open (%.2f, %.2f high)" % [open, e.body.palm_height()], open < 0.25 and e.body.palm_height() > 0.4)
	await _until(func(): return e.state == STATE.SWIPE, 1.0)
	var shut := 0.0
	var claws_seen := 0.0
	var rolled := 0.0

	for i in 12:
		await get_tree().physics_frame
		shut = maxf(shut, e.body.finger_curl())
		rolled = maxf(rolled, absf(e.body.rake_roll()))
		claws_seen = maxf(claws_seen, hud.drain_state()["claws"])

	_check("Q2 the swing shuts its fingers through the rake (%.2f), and rolls it (%.2f)" % [shut, rolled], shut > open + 0.4 and rolled > 0.3)
	_check("Q4 cut, your view shows the claw marks, with nothing on you (%.2f)" % claws_seen, claws_seen > 0.1 and p.leech.count() == 0)
	_free([e])
	await _frames(100)
	_check("Q4b and they go, leaving no drain", not hud.drain_view_shown() and hud.drain_state()["drain"] < 0.01)
	var face := _anima(&"face", HOME + Vector3(0, 0.25, -1.5))
	await _until(func(): return face.state == STATE.WIND_UP, 3.0)
	await _until(func(): return face.state == STATE.SWIPE, 1.0)
	await _frames(6)
	_check("Q3 a face's hands cross (%.2f)" % face.body.hand_across(), face.body.hand_across() < 0.05)
	_free([face])
	await _frames(40)


## The face alive: resting, woken, in its attack, missing.
func _face_life() -> void:
	await _place_player(HOME)
	var e := _anima(&"face", Vector3(0, 1.3, -40))
	e.rests = true
	await _frames(4)
	e.state = STATE.REST
	await _frames(45)
	var body: Node3D = e.body
	_check("F1 at rest: it stays where it is, doing nothing (%.2f)" % e.velocity.length(), e.state == STATE.REST and Vector2(e.velocity.x, e.velocity.z).length() < 0.05)
	_check("F1b its head hangs (%.2f)" % body.head_nod(), body.head_nod() < -0.3)
	var hanging: float = body.hands_up()
	_check("F1c its hands hang under it (%.2f)" % hanging, hanging < -0.15)
	_check("F1d its jaw slack, not gaping (%.2f)" % body.jaw_open(), body.jaw_open() > 0.1 and body.jaw_open() < 0.6)
	var nod_was: float = body.head_nod()
	var tilt_was: Vector3 = body.part(&"Skull").rotation
	var bone: int = body.hand_on(1.0).find_bone("middle_02")
	var finger_was: Quaternion = body.hand_on(1.0).get_bone_pose_rotation(bone)
	var head_moved := 0.0
	var finger_moved := 0.0

	for i in 40:
		await get_tree().physics_frame
		head_moved = maxf(head_moved, body.part(&"Skull").rotation.distance_to(tilt_was))
		finger_moved = maxf(finger_moved, body.hand_on(1.0).get_bone_pose_rotation(bone).angle_to(finger_was))

	_check("F1e it never holds quite still (%.3f, %.3f)" % [head_moved, finger_moved], head_moved > 0.005 and finger_moved > 0.003)
	# It knows you when you come near.
	e.global_position = p.global_position + Vector3(0, 0.25, -5.0)
	var woke := await _until(func(): return e.state == STATE.WAKE, 1.0)
	_check("F2 it wakes when you come near", woke)
	await _frames(14)
	_check("F2b its head comes up (%.2f from %.2f)" % [body.head_nod(), nod_was], body.head_nod() > nod_was + 0.4)
	await _until(func(): return e.state != STATE.WAKE, 2.0)
	_check("F2c and then it comes", e.state == STATE.RUSH or e.state == STATE.TELL)
	# A shot wakes it, and those near it.
	var far := _anima(&"face", p.global_position + Vector3(20, 0.25, -30))
	var neighbour := _anima(&"hands", p.global_position + Vector3(24, -0.7, -30))
	far.rests = true
	neighbour.rests = true
	await _frames(3)
	far.state = STATE.REST
	neighbour.state = STATE.REST
	_hit(far, &"bullet", &"copal")
	await _frames(2)
	_check("F3 struck, it wakes", far.state != STATE.REST)
	_check("F3b so does what lies near it", neighbour.state == STATE.WAKE)
	_free([far, neighbour])
	await _frames(2)
	# The attack: drawn back and wide, then thrown at you, hands first.
	e.global_position = Vector3(0, 1.3, -40)
	e.state = STATE.RUSH
	await _frames(30)
	var rush_back: float = body.head_back()
	var rush_up: float = body.hands_up()
	e.state = STATE.TELL
	e._state_t = -9.0
	await _frames(30)
	_check("F4 its tell: it draws back (%.2f, %.2f)" % [rush_back, body.head_back()], body.head_back() > rush_back + 0.06)
	_check("F4b its hands up and wide, above its head (%.2f, %.2f)" % [rush_up, body.hands_up()], body.hands_up() > rush_up + 0.12 and body.hands_up() > 0.0)
	_check("F4c its jaw as wide as it goes (%.2f)" % body.jaw_open(), body.jaw_open() > 0.85)
	var tell_ahead: float = body.hands_ahead()
	e.state = STATE.LEAP
	e._state_t = -9.0
	e._leap_way = Vector3.ZERO
	await _frames(12)
	_check("F5 its leap: hands thrown ahead (%.2f from %.2f)" % [body.hands_ahead(), tell_ahead], body.hands_ahead() > tell_ahead + 0.15)
	_check("F5b the head after them (%.2f)" % body.head_back(), body.head_back() < -0.05)
	# Missing: it bites on nothing, its head down, and looks about.
	var missed_jaw := 9.0
	e.state = STATE.MISSED
	e._state_t = 0.0

	for i in 24:
		await get_tree().physics_frame
		missed_jaw = minf(missed_jaw, body.jaw_open())

	_check("F6 it misses: its jaw snaps shut on nothing (%.2f)" % missed_jaw, missed_jaw < 0.2)
	_check("F6b and its head goes down (%.2f)" % body.head_nod(), body.head_nod() < -0.15)
	# Its arms grow from the base of its skull, whatever it is doing.
	var worst_arm := 0.0

	for doing in [STATE.REST, STATE.RUSH, STATE.TELL, STATE.LEAP, STATE.MISSED]:
		e.state = doing
		e._state_t = -9.0
		await _frames(30)
		worst_arm = maxf(worst_arm, maxf(body.arm_gap(1.0), body.arm_gap(-1.0)))

	_check("F8 its arms end at the base of its skull, in every pose (%.3f off)" % worst_arm, worst_arm < 0.03)
	# Its sinews stretch as it gapes.
	var rig: Node3D = body.skull_rig()
	e.state = STATE.REST
	await _frames(40)
	var slack: float = rig.sinew_length()
	var slack_wide: float = rig.sinew_width()
	e.state = STATE.TELL
	e._state_t = -9.0
	await _frames(30)
	_check("F7 sinews from cheek to jaw, stretched as it gapes (%.3f, %.3f)" % [slack, rig.sinew_length()], rig.sinew_count() >= 6 and rig.sinew_length() > slack + 0.02)
	_check("F7b and thinner for it", rig.sinew_width() < slack_wide)
	_free([e])
	await _frames(2)


## The hands alive: curled up at rest, slammed down by a miss.
func _hands_life() -> void:
	var e := _anima(&"hands", Vector3(0, 0.3, -40))
	e.rests = true
	await _frames(4)
	e.state = STATE.RUSH
	await _frames(30)
	var walking: float = e.body.palm_height()
	e.state = STATE.REST
	await _frames(45)
	var body: Node3D = e.body
	_check("H1 at rest: down on its palm (%.2f from %.2f)" % [body.palm_height(), walking], body.palm_height() < walking - 0.08)
	_check("H1b still on the floor (%.3f)" % body.lowest_tip(), absf(body.lowest_tip()) < 0.05)
	var skeleton: Skeleton3D = body.skeleton()
	var bone := skeleton.find_bone("index_02")
	var seen: Array[Quaternion] = []

	# (Over a whole cycle of its slow tapping: its phase is its own.)
	for i in 200:
		await get_tree().physics_frame
		seen.append(skeleton.get_bone_pose_rotation(bone))

	var most := 0.0

	for pose in seen:
		most = maxf(most, pose.angle_to(seen[0]))

	_check("H1c its fingers flexing, slowly (%.3f)" % most, most > 0.02)
	e.state = STATE.TELL
	e._state_t = -9.0
	await _frames(25)
	var reared: float = body.palm_height()
	_check("H2 its tell: up off the floor (%.2f)" % reared, reared > walking + 0.08)
	e.state = STATE.MISSED
	e._state_t = 0.0
	var lowest := 9.0

	for i in 24:
		await get_tree().physics_frame
		lowest = minf(lowest, body.palm_height())

	_check("H3 it misses: slammed down flat (%.2f)" % lowest, lowest < walking - 0.08)
	_free([e])
	await _frames(2)


## The face on you: it is on your face, its mouth at yours, and that is where you go.
func _mouth_drain() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(40)
	var hands: Node = p.leech_hands
	var hud: Node = p.hud
	var e := _anima(&"face", p.global_position + Vector3(0.9, 0.5, -0.2))
	await _frames(1)
	e.put_on_you()
	await _frames(30)
	var slot: int = p.leech.slot_of(e)
	_check("M1 its face is in your view", hands.face_shown(slot))
	_check("M1b the one in the world is not (you would see two)", not e.body.visible)
	var mouth: Vector2 = hands.mouth_on_screen(slot)
	_check("M2 its mouth at you, in the middle of your view (%.2f, %.2f)" % [mouth.x, mouth.y], mouth.distance_to(Vector2(0.5, 0.5)) < 0.22)
	_check("M2b its two hands have hold of you", hands.other_hand_shown() and hands.shown(slot))
	_check("M3 what you lose goes into its mouth", hud.drain_state()["threads"] == 1 and hud.drain_target(0).distance_to(mouth) < 0.04)
	# Its mouth drinks, in time with the gulps.
	var jaw_low := 9.0
	var jaw_high := -9.0
	var near_low := 9.0
	var near_high := -9.0
	var jaw_at_gulp := -1.0
	var jaw_at_wind := -1.0
	var tongue_low := 9.0
	var tongue_high := -9.0
	var flare_high := 0.0
	p.power.power = 100.0

	for i in 200:
		await get_tree().physics_frame
		var jaw: float = hands.face_jaw(slot)
		jaw_low = minf(jaw_low, jaw)
		jaw_high = maxf(jaw_high, jaw)
		near_low = minf(near_low, hands.face_near(slot))
		near_high = maxf(near_high, hands.face_near(slot))
		tongue_low = minf(tongue_low, hands.face_tongue(slot))
		tongue_high = maxf(tongue_high, hands.face_tongue(slot))
		flare_high = maxf(flare_high, hands.face_throat(slot))

		if p.leech.gulp() > 0.72 and p.leech.gulp() < 0.8:
			jaw_at_gulp = jaw

		if p.leech.gulp() <= 0.0 and p.leech.coming() > 0.93:
			jaw_at_wind = jaw

	_check("M4 its jaw works as it drinks (%.2f..%.2f)" % [jaw_low, jaw_high], jaw_high - jaw_low > 0.3)
	_check("M4b wide winding up, clamped on the gulp (%.2f, %.2f)" % [jaw_at_wind, jaw_at_gulp], jaw_at_wind > jaw_at_gulp + 0.2)
	_check("M5 it lunges at you with each, and draws back (%.2f..%.2f)" % [near_low, near_high], near_high - near_low > 0.1)
	_check("M5b its tongue works (%.2f..%.2f)" % [tongue_low, tongue_high], tongue_high - tongue_low > 0.15)
	_check("M5c its throat comes up as it swallows (%.2f)" % flare_high, flare_high > 0.5)
	# You hit it where you see it, whichever way you turn.
	p.rotation.y += 1.4
	await _frames(3)
	var ahead: Vector3 = -p.camera.global_basis.z
	var to_it: Vector3 = (e.global_position - p.camera.global_position).normalized()
	_check("M6 it is where you see it, as you turn (%.2f)" % ahead.dot(to_it), ahead.dot(to_it) > 0.95)
	_check("M7 a copal shot in the mouth gets it off", _hit(e, &"bullet", &"copal") == &"weak" and e.state == STATE.THROWN)
	await _frames(1)
	_check("M8 thrown, its face goes from your view at once, and the one in the world is there", not hands.face_shown(slot) and e.body.visible)
	_free([e])
	await _frames(3)
	# Two: side by side, each its own.
	var a := _anima(&"face", p.global_position + Vector3(-0.9, 0.5, -0.2))
	var b := _anima(&"face", p.global_position + Vector3(0.9, 0.5, -0.2))
	await _frames(1)
	a.put_on_you()
	b.put_on_you()
	await _frames(20)
	_check("M9 two faces are apart (%.2f)" % a.global_position.distance_to(b.global_position), a.global_position.distance_to(b.global_position) > 0.4)
	_check("M9b both in view, apart", hands.face_shown(p.leech.slot_of(a)) and hands.face_shown(p.leech.slot_of(b)) and hands.mouth_on_screen(p.leech.slot_of(a)).distance_to(hands.mouth_on_screen(p.leech.slot_of(b))) > 0.2)
	_free([a, b])
	await _frames(3)


## One shot, and the mark it left.
func _fired_read() -> StringName:
	var seen := &""
	Input.action_press("throw")

	for i in 5:
		await get_tree().physics_frame

		for mark in get_tree().get_nodes_in_group(&"round_fx_impact"):
			seen = mark.get_meta(&"read", &"")

	Input.action_release("throw")
	return seen


func _clear_clouds() -> void:
	for cloud in get_tree().get_nodes_in_group(&"copal_clouds"):
		cloud.queue_free()


## Left to the last: the player stays dead.
## Their deaths: they go limp, their own fire takes them, and they burn down to ash.
func _death() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(5)
	await _dies_as(&"face", Vector3(0, 1.3, -6), 0.16)
	await _dies_as(&"hands", Vector3(3, 0.3, -6), 0.25)
	# Killed on your face: it falls off you, there in front of you.
	var on := _anima(&"face", p.global_position + Vector3(0.9, 0.5, -0.2))
	on.death_kind = 0
	await _frames(1)
	on.put_on_you()
	await _frames(20)
	var slot: int = p.leech.slot_of(on)
	on.health = 1.0
	_hit(on, &"bullet", &"copal")
	await _frames(2)
	var fallen: Array = get_tree().get_nodes_in_group(&"anima_ash")
	_check("D9 killed on you: it lets go, and leaves your face at once", p.leech.count() == 0 and not p.leech_hands.face_shown(slot))
	_check("D9b and the body is there in front of you, seen", fallen.size() == 1 and fallen[0].is_visible_in_tree())
	await _frames(10)
	for node in fallen:
		node.queue_free()

	await _frames(2)
	_check("D10 nothing burns on once it is gone", get_tree().get_nodes_in_group(&"anima_ash").is_empty())
	_free([on])
	await _frames(2)


func _dies_as(form: StringName, at: Vector3, rests_at: float) -> void:
	var e := _anima(form, at)
	e.state = STATE.REST
	e.rests = true
	e.notice = 0.0
	e.death_kind = 0
	await _frames(20)
	e.state = STATE.REST
	var body: Node3D = e.body
	var height_was: float = body.global_position.y
	e.health = 1.0
	_hit(e, &"bullet", &"copal")
	_check("D1 %s: dead, the monster gives up its body to burn" % form, e.dead and e.body == null and body.is_inside_tree() and body.is_in_group(&"anima_ash"))
	_check("D1b it can be seen, though the monster is out of play", body.is_visible_in_tree())
	var burn: Node = body.burning()
	var most_flames := 0
	var most_light := 0.0
	var most_wisps := 0
	var flakes := false
	var black := false
	var left := 500

	while left > 0 and burn.crumbled() < 0.02:
		left -= 1
		await get_tree().physics_frame
		most_flames = maxi(most_flames, burn.flames_lit())
		most_light = maxf(most_light, burn.light_energy())
		most_wisps = maxi(most_wisps, burn.wisps_rising())
		black = black or burn.charred() >= 1.0

	_check("D2 %s: limp by the end, down on the floor (%.2f from %.2f)" % [form, body.global_position.y, height_was], absf(body.global_position.y - rests_at) < 0.09)
	_check("D4 %s: a blaze, not a few flames (%d)" % [form, most_flames], most_flames >= 10)
	_check("D4b it throws its own light (%.2f), and smoke goes up from it (%d)" % [most_light, most_wisps], most_light > 0.3 and most_wisps >= 2)
	_check("D5 %s: burnt black before it goes to ash" % form, black)
	left = 200

	while left > 0 and burn.crumbled() < 1.0:
		left -= 1
		await get_tree().physics_frame
		flakes = flakes or burn.flakes_falling()

	await _frames(30)
	_check("D6 %s: it comes apart, flakes off it" % form, burn.crumbled() >= 1.0 and flakes)
	_check("D6b nothing left of it standing", not body.part(&"Skull" if form == &"face" else &"Hand").visible)
	_check("D7 %s: a heap of ash on the floor (%.2f high)" % [form, burn.heap_height()], burn.heap_height() > 0.02 and absf(burn.heap_floor()) < 0.05)
	await _frames(40)
	_check("D7b and its fire out", burn.flames_lit() == 0)

	for i in 720:
		if not is_instance_valid(body):
			break

		await get_tree().physics_frame

	_check("D8 %s: and in a while, that is gone too" % form, not is_instance_valid(body))
	_free([e])
	await _frames(2)


## Each death has its own acting. Returns the body, its monster dead, `kind` of its form's.
func _killed(form: StringName, kind: int, at: Vector3) -> Array:
	var e := _anima(form, at)
	e.state = STATE.REST
	e.rests = true
	e.notice = 0.0
	e.death_kind = kind
	await _frames(5)
	# Awake, at the height of its attack: nothing it does after that is left over from rest.
	e.state = STATE.TELL
	e._state_t = -9.0
	await _frames(30)
	var body: Node3D = e.body
	e.health = 1.0
	_hit(e, &"bullet", &"copal")
	return [e, body]


func _character() -> void:
	await _place_player(HOME)
	_clear_all()
	await _frames(3)
	var script: GDScript = AnimaScript.AnimaBody
	_check("C0 three deaths each, told apart", script.DEATHS[&"face"].size() == 3 and script.DEATHS[&"hands"].size() == 3)
	# The face: it screams, its hands at its skull.
	var scream: Array = await _killed(&"face", 0, Vector3(-6, 1.3, -6))
	var body: Node3D = scream[1]
	await _frames(36)
	_check("C1 it screams: head back (%.2f), jaw wide (%.2f)" % [body.head_nod(), body.jaw_open()], body.head_nod() > 0.4 and body.jaw_open() > 0.85)
	_check("C1b its hands to its skull (%.2f m off), still up in the air (%.2f)" % [body.fingers_from_skull(), body.global_position.y], body.fingers_from_skull() < 0.32 and body.global_position.y > 1.0)
	body.queue_free()
	_free([scream[0]])
	# The face: it reaches for you to the last.
	var at := Vector3(0, 1.3, -6)
	var reach: Array = await _killed(&"face", 1, at)
	body = reach[1]
	var was: float = body.global_position.distance_to(p.global_position)
	await _frames(125)
	_check("C2 it drags itself at you (%.2f m nearer)" % (was - body.global_position.distance_to(p.global_position)), was - body.global_position.distance_to(p.global_position) > 0.45)
	await _frames(35)
	_check("C2b one hand left stretched out for you (%.2f)" % absf(body.hand_ahead(1.0) - body.hand_ahead(-1.0)), absf(body.hand_ahead(1.0) - body.hand_ahead(-1.0)) > 0.25)
	body.queue_free()
	_free([reach[0]])
	# The face: the strings cut, its hands first, and it looks down at them.
	var cut: Array = await _killed(&"face", 2, Vector3(6, 1.3, -6))
	body = cut[1]
	await _frames(30)
	_check("C3 its hands drop first (%.2f), its head still up (%.2f)" % [body.hands_up(), body.global_position.y], body.hands_up() < -0.3 and body.global_position.y > 1.2)
	await _frames(30)
	_check("C3b it looks down at them (%.2f)" % body.head_nod(), body.head_nod() < -0.4)
	body.queue_free()
	_free([cut[0]])
	await _frames(2)
	# The hands: a dying spider, over on its back, legs going, then drawn in.
	var spider: Array = await _killed(&"hands", 0, Vector3(-6, 0.3, -6))
	body = spider[1]
	await _frames(20)
	_check("C4 over on its back (%.2f)" % body.flipped(), body.flipped() > 0.8)
	var skeleton: Skeleton3D = body.skeleton()
	var moved_early: float = await _finger_motion(skeleton, 20)
	var curl_early: float = body.finger_curl()
	await _frames(115)
	var moved_late: float = await _finger_motion(skeleton, 20)
	_check("C4b its fingers going hard, then dying off (%.2f, %.2f)" % [moved_early, moved_late], moved_early > 0.4 and moved_late < moved_early * 0.3)
	_check("C4c and drawn in (%.2f from %.2f)" % [body.finger_curl(), curl_early], body.finger_curl() > curl_early + 0.25)
	body.queue_free()
	_free([spider[0]])
	# The hands: crawling to you to the last.
	var crawl: Array = await _killed(&"hands", 1, Vector3(0, 0.3, -6))
	body = crawl[1]
	was = body.global_position.distance_to(p.global_position)
	await _frames(100)
	_check("C5 it crawls on at you (%.2f m nearer)" % (was - body.global_position.distance_to(p.global_position)), was - body.global_position.distance_to(p.global_position) > 0.3)
	body.queue_free()
	_free([crawl[0]])
	# The hands: up, open, as if asking; it closes on nothing, and goes over.
	var asks: Array = await _killed(&"hands", 2, Vector3(6, 0.3, -6))
	body = asks[1]
	await _frames(30)
	_check("C6 it rears right up, open (%.2f high, %.2f curled)" % [body.palm_height(), body.finger_curl()], body.palm_height() > 0.55 and body.finger_curl() < 0.2)
	await _frames(65)
	_check("C6b it closes on nothing (%.2f)" % body.finger_curl(), body.finger_curl() > 0.6)
	await _frames(70)
	_check("C6c and it goes over (%.2f)" % body.palm_height(), body.palm_height() < 0.2)
	body.queue_free()
	_free([asks[0]])
	await _frames(2)


func _finger_motion(skeleton: Skeleton3D, frames: int) -> float:
	var bone := skeleton.find_bone("index_02")
	var total := 0.0
	var last: Quaternion = skeleton.get_bone_pose_rotation(bone)

	for i in frames:
		await get_tree().physics_frame
		var now: Quaternion = skeleton.get_bone_pose_rotation(bone)
		total += now.angle_to(last)
		last = now

	return total


func _dying() -> void:
	await _place_player(HOME)
	p.power.power = 100.0
	var taker := _anima(&"hands", Vector3(0, 0.3, -4))
	await _until(func(): return taker.state == STATE.ON, 6.0)
	p.invulnerable = false
	p.health = 1.0
	await _until(func(): return p.is_dead, 4.0)
	await _frames(5)
	var after: float = p.power.power
	_check("A16 dead, it doesn't let go yet", p.leech.count() == 1 and taker.state == STATE.ON)
	await _frames(int(p.death.LETS_GO[p.death.kind] * 60.0))
	_check("A16b then it lets go and crawls off, and has taken no more", p.is_dead and p.leech.count() == 0 and taker.state == STATE.LEAVE and is_equal_approx(p.power.power, after))


func _clear_all() -> void:
	for monster in get_tree().get_nodes_in_group(&"monsters"):
		monster.queue_free()


func _anima(form: StringName, at: Vector3) -> CharacterBody3D:
	var e: CharacterBody3D = AnimaScript.new()
	e.form = form
	e.position = at
	add_child(e)
	return e


func _hit(e: Node, kind: StringName, round_id: StringName) -> StringName:
	var was: float = e.health
	e.round_hint = round_id
	var result: StringName = e.take_hit(50.0, p, kind, e.global_position, Vector3.FORWARD)
	_lost = was - e.health
	return result


func _free(list: Array) -> void:
	for e in list:
		if is_instance_valid(e):
			e.queue_free()


func _place_player(at: Vector3) -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "gun_dodge", "sprint", "throw"]:
		Input.action_release(action)

	p.teleport(Transform3D(Basis.IDENTITY, at))
	await _frames(20)


func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _until(done: Callable, most: float) -> bool:
	var left := int(most * 60.0)

	while left > 0:
		if done.call():
			return true

		left -= 1
		await get_tree().physics_frame

	return done.call()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])

	if not ok:
		failed += 1
