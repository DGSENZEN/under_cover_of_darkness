extends Node3D
## The hunts so far, as a list of shots, each staged in the mixed gym and played with real keys,
## nothing left to chance: the camera is on what matters, and each shot says whether the thing it
## is there to show really happened (SHOW lines, read by tools/showcase/record.sh). One shot a run:
##   Godot --path . --resolution 1920x1080 --fixed-fps 60 --write-movie <file>.avi res://tests/diag_showcase_video.tscn -- --shot=<name>
## No words of ours. For the camera only: the yard is lit, and things are put where they can be seen.

const GYM := preload("res://maps/mixed_gym.tscn")
const AnimaScript := preload("res://scripts/Monsters/Anima.gd")
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")
const EyeGobScript := preload("res://scripts/Monsters/EyeGob.gd")
const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")
const DeathQuotes := preload("res://scripts/UI/DeathQuotes.gd")
## Where a shot stands, looking along -z, with room all round.
const MARK := Vector3(-3.5, 1.05, -16.0)
const AIM_RATE := 8.0

const SHOTS := ["pack", "choose", "swipe_hands", "swipe_face", "latch_whip", "face_drinks", "burst", "shard", "ward", "empower", "blink", "weak_kill", "mouth_comes", "mouth_digs", "mouth_close", "mouth_rake", "mouth_bursts", "mouth_they_get_out", "mouth_last_haul", "mouth_on_you", "elite_stands", "elite_feeds", "elite_kills", "swoop_bat", "turn", "spit_bat", "spit_curse", "egg", "line", "one_body", "die_eyes", "die_animas", "die_hands", "die_swipe", "die_both"]

## The monsters' film: each, what it does and how to kill it, then a fight with all four (tools/showcase/cut.py).
const MONSTER_FILM := ["swoop_bat", "eye_kill", "turn", "spit_bat", "swipe_hands", "latch_whip", "hands_kill", "swipe_face", "face_drinks", "face_kill", "mouth_comes", "mouth_digs", "mouth_close", "mouth_rake", "mouth_whips", "mouth_kill", "mouth_bursts", "elite_feeds", "elite_stopped", "elite_stands", "elite_kills", "fight_all_four"]

var gym: Node3D
var p: CharacterBody3D
var target: Node3D
var look_point := Vector3.ZERO
var _failed := 0
## Eyes held where the camera can see them, hovering (they would orbit behind the cover).
var pins := {}


func _ready() -> void:
	# (After the monsters have moved, so a pin holds.)
	process_physics_priority = 100
	var shot := "pack"

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")

	gym = GYM.instantiate()
	add_child(gym)
	await _frames(40)
	p = gym.player
	p.invulnerable = true
	p.reload_on_death = true
	gym.wave_now = gym._waves.size()
	CityState.job.read_slot("mixed_clue")
	_light_the_yard()
	await call("_" + shot)
	print("SHOW %s %s" % [shot, "ok" if _failed == 0 else "FAILED"])
	SaveFiles.delete_run(CityState.run_id)
	get_tree().quit()


func _light_the_yard() -> void:
	for at in [Vector3(-7, 4, -13), Vector3(7, 4, -13), Vector3(0, 4.5, -22), Vector3(-8, 4, -28), Vector3(8, 4, -28)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.8, 0.58)
		lamp.light_energy = 1.6
		lamp.omni_range = 16.0
		lamp.omni_attenuation = 0.8
		gym.add_child(lamp)
		lamp.global_position = at


func _physics_process(delta: float) -> void:
	for eye in pins:
		if is_instance_valid(eye) and not eye.dead:
			eye.global_position = pins[eye] + Vector3(sin(float(Engine.get_physics_frames()) * 0.03) * 0.25, sin(float(Engine.get_physics_frames()) * 0.05) * 0.12, 0.0)

	if p == null or not is_instance_valid(p) or p.is_dead:
		return

	var at: Vector3 = target.global_position if is_instance_valid(target) else look_point

	if at == Vector3.ZERO:
		return

	var way: Vector3 = (at - p.camera.global_position).normalized()
	var turn := 1.0 - exp(-AIM_RATE * delta)
	p.rotation.y = lerp_angle(p.rotation.y, atan2(-way.x, -way.z), turn)
	p.neck.rotation.x = lerp_angle(p.neck.rotation.x, asin(clampf(way.y, -1.0, 1.0)), turn)


# The stage.

## Out in the yard, kitted, gun up on copal, looking ahead.
func _stand(aim_low := 0.0) -> void:
	for what in [&"copal", &"copal_line", &"egg"]:
		gym.kit_table.piece(what).frob(p)

	p.loadout.restock()
	p.revolver.cylinder_round = &"copal"
	p.revolver.loaded[&"cylinder"] = 6
	p.teleport(Transform3D(Basis.IDENTITY, MARK))
	look_point = MARK + Vector3(0.0, 0.2 - aim_low, -10.0)
	p.rotation.y = 0.0
	p.neck.rotation.x = 0.0
	await _frames(20)


func _ahead(x: float, z: float, y := 0.0) -> Vector3:
	return MARK + Vector3(x, y, -z)


func _anima(form: StringName, at: Vector3, leaps := 0.0) -> CharacterBody3D:
	var one: CharacterBody3D = AnimaScript.new()
	one.form = form
	one.leap_chance = leaps
	one.position = at
	gym.add_child(one)
	await _frames(1)
	return one


## Told to hold off, for a shot that needs it standing there.
func _holds_off(one: CharacterBody3D) -> void:
	one.notice = 0.0
	one.state = one.State.CIRCLE


func _eye(at: Vector3, near := 3.6, high := 2.3, turned := false) -> CharacterBody3D:
	var one: CharacterBody3D = EyeScript.new()
	one.position = at
	one.start_turned = turned
	gym.add_child(one)
	await _frames(1)
	one.state = one.State.CIRCLE
	one.next_swoop_in = 100.0
	one.spit_in = 100.0
	one._radius = near
	one._height = high
	return one


func _pinned_eye(at: Vector3, turned := false) -> CharacterBody3D:
	var one := await _eye(at, at.distance_to(p.global_position), at.y - 0.05, turned)
	pins[one] = at
	return one


func _expect(what: String, ok: bool) -> void:
	print("SHOW   %s %s" % ["ok  " if ok else "FAIL", what])

	if not ok:
		_failed += 1


func _shoot(at: Node3D, count: int) -> void:
	target = at
	var left := 480
	var fired := 0

	while fired < count and left > 0 and is_instance_valid(at) and not at.dead:
		left -= 1

		if p.revolver.ready_to_fire() and _on_target(at):
			await _press("throw")
			fired += 1
			await _frames(18)
		else:
			await _frames(1)


func _on_target(at: Node3D) -> bool:
	var way: Vector3 = (at.global_position - p.camera.global_position).normalized()
	return way.dot(-p.camera.global_basis.z) > 0.995


func _spell(action: String, frames: int) -> void:
	p.power.power = p.power.MAX
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _gulps(count: int, most: float) -> void:
	var seen := [0]
	var on_gulp := func(): seen[0] += 1
	p.leech.gulped.connect(on_gulp)
	await _until(func(): return seen[0] >= count, most)
	p.leech.gulped.disconnect(on_gulp)


func _spit_at_you(eye: CharacterBody3D) -> Node3D:
	eye.spit_in = 0.0
	await _until(func(): return not get_tree().get_nodes_in_group(&"eye_gobs").is_empty(), 3.0)
	var gobs: Array = get_tree().get_nodes_in_group(&"eye_gobs")
	return gobs[0] if not gobs.is_empty() else null


# The shots.

func _pack() -> void:
	for what in [&"copal", &"copal_line", &"egg"]:
		look_point = gym.kit_table.piece(what).global_position
		await _frames(50)
		gym.kit_table.piece(what).frob(p)
		await _frames(28)

	_expect("three packed", p.loadout.items.size() == 2 and p.loadout.rounds.has(&"copal"))


func _choose() -> void:
	await _stand()
	await _frames(45)
	var was: StringName = p.loadout.selected_item()
	await _press("next_item")
	await _frames(70)
	var then: StringName = p.loadout.selected_item()
	await _press("next_item")
	await _frames(70)
	_expect("cycled and came back", then != was and p.loadout.selected_item() == was)


func _swipes_by(form: StringName) -> void:
	await _stand(0.5)
	var one := await _anima(form, _ahead(0.5, 3.4, 0.3 if form == &"face" else -0.5))
	target = one
	var cuts := [0]
	one.swiped.connect(func(hit): cuts[0] += 1 if hit else 0)
	await _until(func(): return cuts[0] >= 2, 8.0)
	await _frames(40)
	_expect("two cuts landed on camera (%d)" % cuts[0], cuts[0] >= 2)


func _swipe_hands() -> void:
	await _swipes_by(&"hands")


func _swipe_face() -> void:
	await _swipes_by(&"face")


func _latch_whip() -> void:
	await _stand(0.5)
	var one := await _anima(&"hands", _ahead(-0.4, 3.4, -0.5), 1.0)
	target = one
	var got: bool = await _until(func(): return p.leech.count() > 0, 8.0)
	target = null
	await _gulps(2, 6.0)
	p.revolver.try_whip()
	await _until(func(): return p.leech.count() == 0, 2.0)
	await _frames(70)
	_expect("it leapt on, drank, and the whip threw it off", got and p.leech.count() == 0)


func _face_drinks() -> void:
	await _stand()
	var one := await _anima(&"face", _ahead(0.8, 0.5, 0.3))
	one.put_on_you()
	await _gulps(4, 8.0)
	await _frames(40)
	_expect("a face on you, drinking", p.leech.count() == 1)


func _burst() -> void:
	await _stand(0.6)
	var hits := [0]

	for i in 5:
		var turn := -1.0 + float(i) * 0.5
		var one := await _anima(&"face" if i % 2 == 1 else &"hands", _ahead(sin(turn) * 3.6, cos(turn) * 3.6, 0.3 if i % 2 == 1 else -0.5))
		one.health = 500.0
		_holds_off(one)
		one.struck.connect(func(_result, _source): hits[0] += 1)

	await _frames(30)
	await _spell("spell_4", 40)
	await _until(func(): return hits[0] >= 3, 2.0)
	await _frames(150)
	_expect("the wave reached them (%d hit)" % hits[0], hits[0] >= 3)


func _shard() -> void:
	await _stand()
	var near := await _anima(&"face", _ahead(0.0, 5.0, 0.15))
	var far := await _anima(&"face", _ahead(0.0, 9.0, 0.15))
	var hits := [0]

	for one in [near, far]:
		one.health = 500.0
		_holds_off(one)
		one.struck.connect(func(_result, _source): hits[0] += 1)

	target = near
	await _frames(30)
	await _spell("spell_1", 36)
	await _frames(100)
	_expect("it went through (%d hit)" % hits[0], hits[0] >= 2)


func _ward() -> void:
	await _stand()
	var eye := await _pinned_eye(_ahead(0.0, 7.0, 0.9), true)
	target = eye
	await _frames(40)
	await _spell("spell_2", 34)
	await _frames(40)
	# (Behind its smoke the eye can't see you to spit: this one left before it rose.)
	var gob: Node3D = EyeGobScript.spat_at(gym, eye.global_position, p.global_position + Vector3.UP * 0.15, eye)
	await _until(func(): return not is_instance_valid(gob), 3.0)
	await _frames(80)
	_expect("the Ward stopped the spit", not is_instance_valid(gob) and not p.statuses.has(&"evil_eye"))


func _empower() -> void:
	await _stand(0.5)
	var one := await _anima(&"hands", _ahead(0.3, 3.2, -0.5))
	one.health = 9000.0
	_holds_off(one)
	var hit := [false]
	one.struck.connect(func(_result, _source): hit[0] = true)
	await _spell("spell_3", 85)
	target = one
	await _until(func(): return one.global_position.distance_to(p.global_position) < 1.25, 4.0)
	p.revolver.try_whip()
	await _until(func(): return hit[0], 1.0)
	await _frames(110)
	_expect("empowered, and the blow landed", hit[0])


func _blink() -> void:
	await _stand()
	await _frames(25)
	var from: Vector3 = p.global_position
	p.power.power = p.power.MAX
	look_point = _ahead(1.5, 12.0, 0.2)
	await _frames(25)
	Input.action_press("blink")
	await _frames(30)
	Input.action_release("blink")
	await _frames(70)
	_expect("it went (%.1f m)" % from.distance_to(p.global_position), from.distance_to(p.global_position) > 2.0)


func _weak_kill() -> void:
	await _stand(0.2)
	var hands := await _anima(&"hands", _ahead(-1.0, 3.6, -0.5))
	var face := await _anima(&"face", _ahead(1.2, 4.0, 0.2))

	for one in [hands, face]:
		_holds_off(one)
		one.health = 1.0

	await _frames(20)
	await _shoot(hands, 2)
	await _frames(120)
	await _shoot(face, 2)
	await _frames(170)
	_expect("both shot, and burnt", hands.dead and face.dead)


func _mouth_comes() -> void:
	await _stand(0.2)
	var one := await _anima(&"torso", _ahead(0.3, 5.5, -0.5), 1.0)
	target = one
	var told: bool = await _until(func(): return one.state == one.State.TELL, 14.0)
	await _until(func(): return one.state == one.State.ON or one.state == one.State.MISSED, 6.0)
	await _frames(40)
	_expect("it dragged itself up, reared with its ribs open, and came", told)


func _mouth_digs() -> void:
	await _stand(0.2)
	# Going past you, near, so you see its hands go in.
	var one := await _anima(&"torso", _ahead(-2.4, 3.2, -0.5))
	one.leap_chance = 0.0
	target = one
	var from: int = one.body.hauls_done()
	await _until(func(): return one.body.hauls_done() >= from + 12, 12.0)
	await _frames(60)
	_expect("it dug in and hauled itself on (%d)" % (one.body.hauls_done() - from), one.body.hauls_done() >= from + 12)


func _mouth_close() -> void:
	await _stand(0.2)
	# Near, held off, so you see what is trying to get out of it.
	var one := await _anima(&"torso", _ahead(0.0, 2.6, -0.5))
	one.leap_chance = 0.0
	target = one
	await _frames(20)
	var eye: Vector3 = p.camera.global_position

	for n in 3:
		one.body.hold_press(n, eye + Vector3(float(n) - 1.0, float(n) * 0.5, 0.0), 0.2 + float(n) * 0.4)

	await _frames(300)
	_expect("those in it are pressing out of it", one.body.press_shown(0) and one.body.press_shown(2))


func _mouth_dying(kind: int) -> void:
	await _stand(0.2)
	var one := await _anima(&"torso", _ahead(0.0, 4.2, -0.5))
	one.leap_chance = 0.0
	one.death_kind = kind
	target = one
	await _frames(40)
	var body: Node3D = one.body
	one.health = 1.0
	# (Not with copal: its smoke would hide it.)
	one.round_hint = &"shot"
	one.take_hit(50.0, p, &"bullet", one.global_position, Vector3.FORWARD)
	await _frames(330)
	_expect("it died its own way, and came apart (%d)" % body.souls_apart(), body.souls_apart() >= 3)


func _mouth_bursts() -> void:
	await _mouth_dying(0)


func _mouth_they_get_out() -> void:
	await _mouth_dying(1)


func _mouth_last_haul() -> void:
	await _mouth_dying(2)


func _mouth_on_you() -> void:
	await _stand(0.2)
	var one := await _anima(&"torso", _ahead(0.0, 3.0, -0.5), 1.0)
	target = one
	await _until(func(): return one.state == one.State.ON, 12.0)
	await _frames(260)
	_expect("it closed on you", one.state == one.State.ON)


## An elite, and an elite that has taken three.
func _elite_stands() -> void:
	await _stand(0.2)
	var one: CharacterBody3D = AnimaScript.new()
	one.form = &"torso"
	one.elite = true
	one.leap_chance = 0.0
	one.position = _ahead(0.0, 4.2, -0.5)
	add_child(one)
	target = one
	await _frames(90)

	for kind in [&"face", &"hands", &"face"]:
		one.take_in(kind)
		await _frames(90)

	_expect("it took three, and shows it", one.body.taken_up() == 3)


func _elite_feeds() -> void:
	await _stand(0.2)
	var one: CharacterBody3D = AnimaScript.new()
	one.form = &"torso"
	one.elite = true
	one.leap_chance = 0.0
	one.position = _ahead(0.0, 8.6, -0.5)
	add_child(one)
	target = one
	var small := await _anima(&"face", _ahead(-2.6, 8.4, 0.3))
	small.leap_chance = 0.0
	await _frames(110)
	one.health = 120.0
	await _until(func(): return one.taken_count() >= 1, 8.0)
	await _frames(70)
	_expect("it fed (%d)" % one.taken_count(), one.taken_count() == 1)


func _elite_kills() -> void:
	await _stand(0.2)
	p.invulnerable = false
	p.reload_on_death = false
	var one: CharacterBody3D = AnimaScript.new()
	one.form = &"torso"
	one.elite = true
	one.leap_chance = 1.0
	one.position = _ahead(0.0, 3.9, -0.5)
	add_child(one)
	target = one
	await _frames(2)

	for kind in [&"face", &"hands", &"face"]:
		one.take_in(kind)

	await _until(func(): return p.is_dead, 12.0)
	await _frames(300)
	_expect("full, it had you, and that was all", p.is_dead)


## An eye: hit it in its tell, and it's yours.
func _eye_kill() -> void:
	await _stand()
	var eye := await _eye(_ahead(0.0, 6.5, 1.0), 6.5)
	target = eye
	await _frames(70)
	eye.next_swoop_in = 0.0
	var told: bool = await _until(func(): return eye.state == eye.State.TELL, 4.0)
	await _shoot(eye, 1)
	var broke: bool = eye.state != eye.State.SWOOP
	await _shoot(eye, 6)
	await _frames(100)
	_expect("hit in its tell, it broke off, and died (%s)" % eye.dead, told and broke and eye.dead)


## Hands: a copal round, as they come.
func _hands_kill() -> void:
	await _stand(0.3)
	var one := await _anima(&"hands", _ahead(-1.0, 8.5, -0.5))
	target = one
	await _until(func(): return one.state == one.State.RUSH, 3.0)
	await _frames(70)
	await _shoot(one, 3)
	await _frames(190)
	_expect("copal burnt it", one.dead)


## A face on you: copal in its mouth, and again.
func _face_kill() -> void:
	await _stand()
	var one := await _anima(&"face", _ahead(0.8, 0.5, 0.3))
	one.put_on_you()
	await _gulps(2, 5.0)
	target = one
	await _shoot(one, 1)
	var off: bool = p.leech.count() == 0
	await _shoot(one, 4)
	await _frames(190)
	_expect("copal threw it off (%s), and burnt it (%s)" % [off, one.dead], off and one.dead)


## The mouth has you: two whips.
func _mouth_whips() -> void:
	await _stand(0.2)
	var one := await _anima(&"torso", _ahead(0.5, 1.2, -0.5))
	one.put_on_you()
	await _gulps(2, 5.0)
	p.revolver.try_whip()
	await _until(func(): return one.ribs_cracked, 1.5)
	var cracked: bool = one.ribs_cracked
	await _gulps(2, 5.0)
	await _frames(20)
	p.revolver.try_whip()
	await _until(func(): return p.leech.count() == 0, 1.5)
	await _frames(100)
	_expect("the first broke its ribs, the second threw it", cracked and p.leech.count() == 0)


## The mouth: hit it as it gathers. It stops, and it is open.
func _mouth_kill() -> void:
	await _stand(0.3)
	var one := await _anima(&"torso", _ahead(0.0, 3.4, -0.5), 1.0)
	target = one
	var told: bool = await _until(func(): return one.state == one.State.TELL, 8.0)
	await _frames(45)
	await _shoot(one, 1)
	var stopped: bool = one.state == one.State.THROWN or one.dead
	await _shoot(one, 6)
	await _frames(150)
	_expect("hit gathering, it stopped (%s), and burnt (%s)" % [stopped, one.dead], told and stopped and one.dead)


## The elite, feeding: hit it, and it lets go.
func _elite_stopped() -> void:
	await _stand(0.2)
	var one: CharacterBody3D = AnimaScript.new()
	one.form = &"torso"
	one.elite = true
	one.leap_chance = 0.0
	one.position = _ahead(0.0, 7.2, -0.5)
	gym.add_child(one)
	target = one
	var small := await _anima(&"face", _ahead(-2.2, 7.0, 0.3))
	small.leap_chance = 0.0
	await _frames(110)
	one.health = 200.0
	var seized: bool = await _until(func(): return one.state == one.State.DRAG, 8.0)
	await _frames(22)
	await _shoot(one, 1)
	var let_go: bool = not small.is_seized() and not small.dead
	await _frames(110)
	_expect("seized (%s), and it let go, the small one alive (%s)" % [seized, let_go], seized and let_go and one.taken_count() == 0)


## In the fight: how long between shots, how long before you answer what has you, how close you let them.
const FIGHT_BETWEEN_SHOTS := 48
const FIGHT_CATCHES := 70
const FIGHT_LETS_COME := 5.0

## All four, for real: nothing held off, nothing staged but where they start. Rounds kept up; you can't die of it,
## so it can be seen through. What has you first; then an eye in its tell; a mouth gathering; what is closest; the rest.
func _fight_all_four() -> void:
	await _stand(0.2)
	p.invulnerable = true
	var mouth := await _anima(&"torso", _ahead(3.0, 7.5, -0.5), 0.45)
	var face := await _anima(&"face", _ahead(-5.0, 10.0, 0.3), 0.45)
	var hands := await _anima(&"hands", _ahead(1.0, 10.0, -0.5), 0.45)
	var eye: CharacterBody3D = EyeScript.new()
	eye.position = _ahead(-1.0, 8.0, 1.6)
	gym.add_child(eye)
	await _frames(1)
	var all: Array[CharacterBody3D] = [mouth, face, hands, eye]
	# (Its first swoop soon, or the fight is over before it has done anything.)
	eye.next_swoop_in = 3.0
	var left := 60 * 75
	var used_burst := false

	while left > 0 and all.any(func(one): return not one.dead):
		left -= 1
		p.revolver.loaded[&"cylinder"] = 6
		p.health = p.max_health
		var on_you: Array = p.leech.on_me()

		# A hand on you comes off with a whip, once you've felt it.
		if not on_you.is_empty() and on_you[0].form == &"hands" and _whip_ready():
			await _frames(FIGHT_CATCHES)
			p.revolver.try_whip()
			await _frames(30)
			left -= FIGHT_CATCHES + 30
			continue

		# A swoop, batted back as it arrives.
		if not eye.dead and eye.state == eye.State.SWOOP and eye.global_position.distance_to(p.camera.global_position) < 3.0 and _whip_ready():
			target = eye
			p.revolver.try_whip()
			await _frames(25)
			left -= 25
			continue

		# Bunched and close, the Burst.
		if not used_burst and all.filter(func(one): return not one.dead and one != eye and one.global_position.distance_to(p.global_position) < 4.0).size() >= 2:
			used_burst = true
			await _spell("spell_4", 40)
			await _frames(40)
			left -= 80
			continue

		var after: CharacterBody3D = _next_in_the_fight(all, on_you)
		target = after

		if after != null and p.revolver.ready_to_fire() and _on_target(after) and _worth_a_round(after, on_you):
			await _press("throw")
			await _frames(FIGHT_BETWEEN_SHOTS)
			left -= FIGHT_BETWEEN_SHOTS
		else:
			await _frames(1)

	target = null
	look_point = _ahead(0.0, 8.0, 0.2)
	await _frames(150)
	_expect("all four dead, in %.0f s (%s)" % [float(60 * 75 - left) / 60.0, all.map(func(one): return one.dead)], all.all(func(one): return one.dead))


## Rounds are few: on what has you, on what has opened itself, or on what has come close.
func _worth_a_round(one: CharacterBody3D, on_you: Array) -> bool:
	if on_you.has(one) or one._is_opening():
		return true

	return one.global_position.distance_to(p.global_position) < FIGHT_LETS_COME


func _whip_ready() -> bool:
	return p.revolver.weapon() != null and p.revolver._whip_t < 0.0


func _next_in_the_fight(all: Array[CharacterBody3D], on_you: Array) -> CharacterBody3D:
	if not on_you.is_empty():
		return on_you[0]

	var eye: CharacterBody3D = all[3]
	var mouth: CharacterBody3D = all[0]

	if not eye.dead and eye.state == eye.State.TELL:
		return eye

	if not mouth.dead and (mouth.state == mouth.State.TELL or mouth.state == mouth.State.WIND_UP):
		return mouth

	var best: CharacterBody3D = null
	var nearest := 999.0

	for one in all:
		if one.dead or one == eye:
			continue

		# The small ones before the mouth, unless it is on top of you.
		var off: float = one.global_position.distance_to(p.global_position) + (5.0 if one == mouth else 0.0)

		if off < nearest:
			nearest = off
			best = one

	return best if best != null else eye


func _mouth_rake() -> void:
	await _stand(0.2)
	var one := await _anima(&"torso", _ahead(0.3, 3.4, -0.5))
	target = one
	var cuts := [0]
	one.swiped.connect(func(hit): cuts[0] += 1 if hit else 0)
	await _until(func(): return cuts[0] >= 2, 16.0)
	await _frames(40)
	_expect("it raked with all its arms, twice (%d)" % cuts[0], cuts[0] >= 2)


func _swoop_bat() -> void:
	await _stand()
	var eye := await _eye(_ahead(0.0, 5.0, 1.0), 5.0)
	target = eye
	await _frames(60)
	eye.next_swoop_in = 0.0
	var swooped: bool = await _until(func(): return eye.state == eye.State.SWOOP, 4.0)
	await _until(func(): return eye.global_position.distance_to(p.camera.global_position) < 3.0, 2.0)
	p.revolver.try_whip()
	var batted: bool = await _until(func(): return eye.state == eye.State.BATTED, 1.0)
	# (Stays on the yard: not up after it into the sky.)
	target = null
	look_point = _ahead(0.0, 8.0, 1.0)
	await _frames(110)
	_expect("it told, swooped, and was whipped back", swooped and batted)


func _turn() -> void:
	await _stand()
	var eye := await _pinned_eye(_ahead(0.0, 3.6, 0.8))
	target = eye
	p.revolver.cylinder_round = &"lead"
	await _frames(60)
	# (However hard the round: this one hit is the one that tears it open.)
	eye.health = 500.0
	eye.struck.connect(func(_result, _source):
		eye.health = eye._max_health() * eye.TURNS_AT
		eye.turn())
	await _shoot(eye, 1)
	await _until(func(): return eye.turned, 2.0)
	await _frames(200)
	_expect("it tore open", eye.turned and not eye.dead)


func _spit_bat() -> void:
	await _stand()
	var eye := await _pinned_eye(_ahead(0.0, 5.5, 0.8), true)
	eye.health = 500.0
	var hurt := [false]
	eye.struck.connect(func(_result, _source): hurt[0] = true)
	target = eye
	await _frames(50)
	var gob: Node3D = await _spit_at_you(eye)
	var seen := gob != null

	if seen:
		await _until(func(): return not is_instance_valid(gob) or gob.global_position.distance_to(p.camera.global_position) < 2.6, 3.0)
		p.revolver.try_whip()
		await _until(func(): return not is_instance_valid(gob) or gob.is_batted(), 0.6)

		# (The eye has moved since it spat: this much help, for the camera.)
		for i in 60:
			if not is_instance_valid(gob) or hurt[0]:
				break

			if gob.is_batted():
				gob.velocity = (eye.global_position - gob.global_position).normalized() * gob.BAT_SPEED

			await _frames(1)

	await _frames(90)
	_expect("whipped back into the eye that spat it", seen and hurt[0])


func _spit_curse() -> void:
	await _stand()
	var eye := await _pinned_eye(_ahead(0.0, 5.5, 0.8), true)
	target = eye
	await _frames(40)
	await _spit_at_you(eye)
	await _until(func(): return p.statuses.has(&"evil_eye"), 3.0)
	await _frames(60)
	var one: bool = p.statuses.has(&"evil_eye")
	var depth: int = p.curse.depth()
	await _spit_at_you(eye)
	await _until(func(): return p.curse.depth() > depth, 3.0)
	await _frames(100)
	_expect("it put the curse on you, then opened another eye (%d)" % p.curse.depth(), one and p.curse.depth() > depth)


func _egg() -> void:
	await _stand()
	var eye := await _pinned_eye(_ahead(1.2, 5.0, 0.8))
	var eye_two := await _pinned_eye(_ahead(-1.4, 5.0, 0.8))
	p.statuses.apply(&"evil_eye", 60.0)

	for i in 3:
		p.curse.deepen()

	target = eye
	await _frames(80)
	p.loadout.selected = p.loadout.items.find(&"egg")
	await _press("use_item")
	# (Off the pins as it takes: they are flung, and sink.)
	await _frames(55)
	pins.clear()
	await _frames(125)
	_expect("the egg took it, and sent it back", not p.statuses.has(&"evil_eye") and (eye.state == eye.State.DAZED or eye_two.state == eye.State.DAZED))


func _line() -> void:
	await _stand(0.7)
	var one := await _anima(&"hands", _ahead(0.8, 0.5, -0.4))
	one.put_on_you()
	await _gulps(1, 5.0)
	await _frames(20)
	p.loadout.selected = p.loadout.items.find(&"copal_line")
	await _press("use_item")
	await _until(func(): return p.leech.count() == 0, 2.0)
	var thrown: bool = p.leech.count() == 0
	await _frames(170)
	_expect("the line threw it off and holds it out", thrown)


func _one_body() -> void:
	await _stand()
	p.statuses.apply(&"evil_eye", 60.0)

	for i in 2:
		p.curse.deepen()

	await _frames(80)
	var a := await _anima(&"face", _ahead(0.9, 0.5, 0.3))
	a.put_on_you()
	p.power.power = p.power.MAX * 0.5
	await _gulps(2, 6.0)

	for i in 3:
		p.curse.deepen()

	var b := await _anima(&"face", _ahead(-0.9, 0.5, 0.3))
	var c := await _anima(&"hands", _ahead(0.0, -0.5, 0.0))
	b.put_on_you()
	c.put_on_you()
	p.power.power = p.power.MAX * 0.15
	await _gulps(3, 6.0)
	_expect("curse and drain together", p.leech.count() == 3 and p.statuses.has(&"evil_eye"))


func _words(quote: int, kind: StringName) -> void:
	await _until(func(): return p.is_dead, 20.0)
	_expect("the death is %s (%s)" % [kind, p.death.kind], p.death.kind == kind)
	# (One of each, for the film; in play a death draws among its own.)
	p.hud._death.set_quote(DeathQuotes.ALL[quote])
	await _until(func(): return p.hud.death_page.visible, 14.0)
	_expect("the words and the page came", p.hud.death_page.visible)
	await _frames(150)


func _die_eyes() -> void:
	await _stand()
	p.statuses.apply(&"evil_eye", 60.0)
	p.curse.deepen()
	var eye := await _eye(_ahead(0.0, 4.5, 1.0), 4.5)
	target = eye
	await _frames(40)
	eye.next_swoop_in = 0.0
	p.invulnerable = false
	p.health = 1.0
	await _words(3, &"eyes")


func _feeders_and_crowd() -> void:
	var a := await _anima(&"face", _ahead(0.9, 0.5, 0.3))
	var b := await _anima(&"hands", _ahead(-0.9, 0.5, 0.0))
	a.put_on_you()
	b.put_on_you()

	for i in 3:
		await _anima(&"hands" if i < 2 else &"face", _ahead(float(i) * 3.0 - 3.0, 8.0, -0.5 if i < 2 else 0.3))


func _die_animas() -> void:
	await _stand()
	await _feeders_and_crowd()
	await _gulps(1, 4.0)
	p.invulnerable = false
	p.health = 0.01
	p.drain_life(1.0)
	await _words(1, &"animas")


func _die_hands() -> void:
	await _stand()
	var a := await _anima(&"hands", _ahead(0.9, 0.5, 0.0))
	a.put_on_you()
	await _gulps(1, 4.0)
	p.invulnerable = false
	p.health = 0.01
	p.drain_life(1.0)
	await _words(0, &"animas")


func _die_swipe() -> void:
	await _stand(0.4)
	var one := await _anima(&"hands", _ahead(0.5, 3.2, -0.5))
	target = one
	p.invulnerable = false
	p.health = 1.0
	await _words(4, &"swipe")


func _die_both() -> void:
	await _stand()
	p.statuses.apply(&"evil_eye", 60.0)

	for i in 4:
		p.curse.deepen()

	await _frames(50)
	await _feeders_and_crowd()
	await _gulps(1, 4.0)
	p.invulnerable = false
	p.health = 0.01
	p.drain_life(1.0)
	await _words(2, &"both")


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
