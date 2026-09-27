extends Node3D
## What makes a man look alive: the rig's upper-body layer and the small
## turns laid over the animation (Humanoid, Posture), his expression (gaze,
## posture by temperament, breathing, gestures: Expression), his pastimes
## (GuardPastimes), and the air about him (Atmosphere).
##
##   Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/aliveness_test.tscn

const HumanoidScript := preload("res://scripts/Visual/Humanoid.gd")
const ExpressionScript := preload("res://scripts/Visual/Expression.gd")
const TalkScript := preload("res://scripts/AISystem/Talk/TalkScript.gd")
const TalkDirector := preload("res://scripts/AISystem/Talk/TalkDirector.gd")
const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const GuardStationScript := preload("res://scripts/AISystem/GuardStation.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const FireScript := preload("res://scripts/Combat/Fire.gd")
const NightRotaScript := preload("res://scripts/AISystem/NightRota.gd")
const AtmosphereScript := preload("res://scripts/Visual/Atmosphere.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")

const FIXTURES := """
== talk_pair
cast: A = any; B = any
cooldown: 0s
A: A good long first line, so there is time to look at him.
B: A good long second line, so there is time to look back.
A: A third.
B: A fourth.

== nodding
cast: A = any; B = any
cooldown: 0s
A: A first line, and the other nods at the end of it.
B [nods]: Aye.
"""

var results: Array[String] = []
var player: CharacterBody3D


func _ready() -> void:
	await _run()
	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	await _rig()
	await _yard()
	seed(2027)
	GuardScript.randomize_on = false
	await _expression()
	await _pastimes()
	await _atmosphere()
	await _steady_gaze()
	GuardScript.randomize_on = true


# ---------------------------------------------------------------------------
# The rig
# ---------------------------------------------------------------------------

func _rig() -> void:
	var a := _man(Vector3(-2, 0, 0))
	var b := _man(Vector3(2, 0, 0))
	var walking := Vector3(0, 0, -1.1)

	# A1 the upper layer plays over walking
	for f in 60:
		a.set_motion(walking, false, 1.0 / 60.0)
		b.set_motion(walking, false, 1.0 / 60.0)
		b.show_upper(&"Consume", f / 60.0)
		await get_tree().physics_frame

	await get_tree().process_frame
	var hand_gap := _local(a, &"hand_r").origin.distance_to(_local(b, &"hand_r").origin)
	var thigh_gap := _local(a, &"thigh_l").basis.get_rotation_quaternion().angle_to(_local(b, &"thigh_l").basis.get_rotation_quaternion())
	_check("A1 the upper layer plays a clip over walking: the hand moves, the legs keep walking",
		hand_gap > 0.08 and thigh_gap < 0.02 and b.upper_weight() > 0.8, "hand %.3f m apart, thigh %.3f rad, weight %.2f" % [hand_gap, thigh_gap, b.upper_weight()])

	# A2 cleared, it fades back to the walk
	b.clear_upper(0.25)

	for f in 27:
		a.set_motion(walking, false, 1.0 / 60.0)
		b.set_motion(walking, false, 1.0 / 60.0)
		await get_tree().physics_frame

	await get_tree().process_frame
	hand_gap = _local(a, &"hand_r").origin.distance_to(_local(b, &"hand_r").origin)
	_check("A2 cleared, the upper layer fades back to the walk", hand_gap < 0.02 and b.upper_weight() < 0.01, "hand %.3f m apart, weight %.2f" % [hand_gap, b.upper_weight()])

	# A3 the new turns: head pitch, shoulders, breath
	for f in 40:
		a.set_motion(Vector3.ZERO, false, 1.0 / 60.0)
		b.set_motion(Vector3.ZERO, false, 1.0 / 60.0)
		b.posture.set("head_bow", 0.4)
		b.posture.set("shoulders", 1.0)
		await get_tree().physics_frame

	var bones := [&"Head", &"upperarm_l", &"upperarm_r", &"pelvis", &"spine_03"]
	var pa := await _posed(a, bones)
	var pb := await _posed(b, bones)
	var down := _forward_y(pa[&"Head"]) - _forward_y(pb[&"Head"])
	# The clavicle turns about its own root: its far end (the shoulder, where
	# the upper arm starts) is what rises, both sides.
	var shrug_l := ((pb[&"upperarm_l"] as Transform3D).origin.y - (pb[&"pelvis"] as Transform3D).origin.y) - ((pa[&"upperarm_l"] as Transform3D).origin.y - (pa[&"pelvis"] as Transform3D).origin.y)
	var shrug_r := ((pb[&"upperarm_r"] as Transform3D).origin.y - (pb[&"pelvis"] as Transform3D).origin.y) - ((pa[&"upperarm_r"] as Transform3D).origin.y - (pa[&"pelvis"] as Transform3D).origin.y)
	var shrug := minf(shrug_l, shrug_r)
	b.posture.set("head_bow", 0.0)
	b.posture.set("shoulders", 0.0)
	b.posture.set("breath", 0.0)

	for f in 30:
		b.set_motion(Vector3.ZERO, false, 1.0 / 60.0)
		await get_tree().physics_frame

	var out := ((await _posed(b, bones))[&"spine_03"] as Transform3D).basis.get_rotation_quaternion()
	b.posture.set("breath", 1.0)
	var inn := ((await _posed(b, bones))[&"spine_03"] as Transform3D).basis.get_rotation_quaternion()
	var breath := out.angle_to(inn)
	_check("A3 posture's new turns: the head bows, the shoulders rise, the chest breathes",
		down > 0.2 and shrug > 0.015 and breath >= 0.03, "head forward dropped %.3f, shoulders up %.3f/%.3f m, breath %.3f rad" % [down, shrug_l, shrug_r, breath])
	a.queue_free()
	b.queue_free()


# ---------------------------------------------------------------------------
# Expression
# ---------------------------------------------------------------------------

func _expression() -> void:
	# A4 a listener's head turns to the man speaking
	await _fresh()
	_use(["talk_pair"])
	var seat: Node3D = GuardStationScript.new()
	seat.kind = &"sit"
	add_child(seat)
	seat.global_position = Vector3(0, 0, 0)
	seat.rotation.y = -PI * 0.5
	var sitter := _guard(Vector3(0, 0, 0.3), -PI * 0.5, &"steady", "", [seat])
	var stander := _guard(Vector3(-0.2, 0, -2.2), 0.0)
	var director: RefCounted = TalkDirector.of(self)
	await _until(func(): return director.speaking(stander), 1800)
	await _frames(20)
	var pose: Dictionary = await _posed_global(sitter, [&"Head"])
	var axis := _rest_forward_axis(sitter)
	var facing: Vector3 = ((pose[&"Head"] as Transform3D).basis * axis).normalized()
	var to_him: Vector3 = (stander.eye_position() - (pose[&"Head"] as Transform3D).origin).normalized()
	var flat_facing := Vector2(facing.x, facing.z).normalized()
	var flat_to := Vector2(to_him.x, to_him.z).normalized()
	var angle := rad_to_deg(acos(clampf(flat_facing.dot(flat_to), -1.0, 1.0)))
	_check("A4 a man sitting turns his head to the man speaking to him", director.speaking(stander) and angle < 35.0,
		"speaking %s, head %.0f deg off him, sitter doing %s" % [director.speaking(stander), angle, sitter.activity()])

	# A5 posture differs by temperament
	await _fresh()
	_use([])
	var craven := _guard(Vector3(10, 0, 0), 0.0, &"craven")
	var steady := _guard(Vector3(14, 0, 0), 0.0, &"steady")
	for g in [craven, steady]:
		g._life._talk_rest = 99.0
	await _frames(90)
	# His shoulders against his neck (the idle clip's own sway and dip, each man
	# at his own point in it, and his hunched chest move them together).
	var bones := [&"Head", &"upperarm_l", &"upperarm_r", &"neck_01"]
	var pc: Dictionary = await _posed(craven._rig.man, bones)
	var ps: Dictionary = await _posed(steady._rig.man, bones)
	var hunch: float = (((pc[&"upperarm_l"] as Transform3D).origin.y + (pc[&"upperarm_r"] as Transform3D).origin.y) - ((ps[&"upperarm_l"] as Transform3D).origin.y + (ps[&"upperarm_r"] as Transform3D).origin.y)) * 0.5 \
		- ((pc[&"neck_01"] as Transform3D).origin.y - (ps[&"neck_01"] as Transform3D).origin.y)
	var bowed: float = _forward_y(ps[&"Head"]) - _forward_y(pc[&"Head"])
	_check("A5 a craven man stands hunched, shoulders up and head down; a steady one does not",
		hunch > 0.01 and bowed > 0.05, "shoulders %.3f m higher, head forward %.3f lower" % [hunch, bowed])

	# A6 two men of one kind do not move alike
	var v1 := ExpressionScript.variation(1, &"", &"steady")
	var v2 := ExpressionScript.variation(2, &"", &"steady")
	await _fresh()
	var w21 := _guard(Vector3(20, 0, 0), 0.0, &"steady", "", [], 21)
	var w22 := _guard(Vector3(24, 0, 0), 0.0, &"steady", "", [], 22)
	var speeds := absf(w21.patrol_speed - w22.patrol_speed) / maxf(w21.patrol_speed, 0.01)
	_check("A6 two men of one kind walk at their own pace and rhythm",
		v1["walk"] != v2["walk"] and speeds >= 0.005 and w21._rig.expression.traits["rhythm"] != w22._rig.expression.traits["rhythm"],
		"walk %.3f/%.3f, patrol %.3f/%.3f, rhythm %.3f/%.3f" % [v1["walk"], v2["walk"], w21.patrol_speed, w22.patrol_speed, w21._rig.expression.traits["rhythm"], w22._rig.expression.traits["rhythm"]])

	# A7 his breathing moves his chest, at his breath's pace
	await _fresh()
	var breather := _guard(Vector3(30, 0, 0), 0.0)
	breather._life._talk_rest = 99.0
	breather._voice.hold_heart(100.0)
	await _frames(30)
	var peaks := [0]
	var last := [0.0, 0.0]
	for f in 600:
		var b: float = float(breather._rig.man.posture.get("breath"))
		if last[1] < last[0] and last[0] > b and last[0] > 0.3:
			peaks[0] += 1
		last[1] = last[0]
		last[0] = b
		await get_tree().physics_frame
	var expected: float = breather._voice.breath_rate() * 10.0
	breather._voice.hold_heart(-1.0)
	_check("A7 his chest rises and falls with his breath", absf(float(peaks[0]) - expected) <= 1.5, "peaks %d in 10 s, expected %.1f" % [peaks[0], expected])

	# A8 speaking, his hands talk; his legs are his own
	await _fresh()
	_use(["talk_pair"])
	director = TalkDirector.of(self)
	var s1 := _guard(Vector3(40, 0, 0), -PI * 0.5)
	var s2 := _guard(Vector3(42.6, 0, 0), PI * 0.5)
	await _until(func(): return director.speaking(s1) or director.speaking(s2), 1800)
	await _frames(24)
	var talker: Node = s1 if director.speaking(s1) else s2
	_check("A8 a man speaking gestures with his upper body alone", talker._rig.man.upper_weight() > 0.3 and not talker._rig.man.is_acting(),
		"upper %.2f, whole-body action %s" % [talker._rig.man.upper_weight(), talker._rig.man.is_acting()])

	# A9 the captain's formal walk
	await _fresh()
	var captain := _guard(Vector3(50, 0, 0), 0.0, &"steady", "Mirelle")
	var space := captain._rig.man._root.get_node(&"relaxed") as AnimationNodeBlendSpace1D
	_check("A9 the captain walks her formal walk", (space.get_blend_point_node(1) as AnimationNodeAnimation).animation == &"Walk_Formal",
		"walk %s" % (space.get_blend_point_node(1) as AnimationNodeAnimation).animation)

	# A10 a nod, and a listener who nods at the end of a line
	await _fresh()
	var nodder := _guard(Vector3(60, 0, 0), 0.0)
	nodder._life._talk_rest = 99.0
	nodder.emote("nods")
	await _frames(6)
	var clip: StringName = (nodder._rig.man._root.get_node(&"upper_clip") as AnimationNodeAnimation).animation
	await _frames(84)
	var gone: bool = nodder._rig.man.upper_weight() < 0.05
	_use(["nodding"])
	director = TalkDirector.of(self)
	var n1 := _guard(Vector3(64, 0, 0), -PI * 0.5)
	var n2 := _guard(Vector3(66.6, 0, 0), PI * 0.5)
	for g in [n1, n2]:
		g._life._talk_rest = 99.0
	director.play("nodding", {"A": n1, "B": n2})
	await _until(func(): return director.speaking(n1), 600)
	await _until(func(): return not director.speaking(n1), 600)
	await _frames(6)
	var reacted: StringName = (n2._rig.man._root.get_node(&"upper_clip") as AnimationNodeAnimation).animation
	_check("A10 a nod plays on his upper body and passes; the man to answer nods as the line ends",
		clip == &"Yes" and gone and reacted == &"Yes" and n2._rig.man.upper_weight() > 0.2, "clip %s, gone %s, the listener %s (%.2f)" % [clip, gone, reacted, n2._rig.man.upper_weight()])


# ---------------------------------------------------------------------------
# Pastimes
# ---------------------------------------------------------------------------

func _pastimes() -> void:
	# A11 never the same twice running, never three in five
	await _fresh()
	var picker := _guard(Vector3(80, 0, 0), 0.0)
	picker._life._talk_rest = 99.0
	var picks: Array = []

	for i in 200:
		picks.append(picker._life._pastimes.choose())

	var twice := 0
	var thrice := 0

	for i in range(1, picks.size()):
		if picks[i] == picks[i - 1]:
			twice += 1

	for i in range(0, picks.size() - 4):
		var window: Array = picks.slice(i, i + 5)

		for id in window:
			if window.count(id) >= 3:
				thrice += 1
				break

	_check("A11 his pastimes never repeat twice running, nor three times in five", twice == 0 and thrice == 0 and not picks.has(&""),
		"twice %d, three in five %d, first %s" % [twice, thrice, picks.slice(0, 12)])

	# A12 the most pressing first: cold, by a fire
	await _fresh()
	var rota: RefCounted = NightRotaScript.setup(self, 600.0)
	var fire: Area3D = FireScript.brazier(self, Vector3(90, 0, 0))
	var chilly := _guard(Vector3(92, 0, 0), PI * 0.5)
	var far := _guard(Vector3(90, 0, 20), 0.0)
	chilly._life._talk_rest = 99.0
	far._life._talk_rest = 99.0
	await _frames(5)
	var warm_picks := []
	var far_picks := []

	for i in 20:
		rota.set_need(chilly, &"cold", 0.8)
		rota.set_need(far, &"cold", 0.8)
		warm_picks.append(chilly._life._pastimes.choose())
		far_picks.append(far._life._pastimes.choose())

	var by_fire: bool = warm_picks.all(func(p): return p in [&"warm_hands", &"squat", &"stamp"])
	var no_fire: bool = far_picks.all(func(p): return p != &"warm_hands" and p != &"squat")
	_check("A12 cold, a man by the fire warms himself (or stamps); away from it he never warms his hands at nothing",
		by_fire and no_fire and far_picks.has(&"stamp"), "by the fire %s; away %s" % [warm_picks.slice(0, 8), far_picks.slice(0, 8)])
	fire.get_parent().queue_free()

	# A13 no fire, no wall, blade put away: none of what needs them
	await _fresh()
	var bowl: Node3D = GuardStationScript.new()
	bowl.kind = &"eat"
	add_child(bowl)
	bowl.global_position = Vector3(100, 0, 0)
	var eater := _guard(Vector3(100, 0, 0.5), 0.0, &"steady", "", [bowl])
	eater._life._talk_rest = 99.0
	await _until(func(): return eater._rota.at_station(), 600)
	var eat_picks := []

	for i in 100:
		eat_picks.append(eater._life._pastimes.choose())

	var none: bool = not eat_picks.any(func(p): return p in [&"warm_hands", &"squat", &"lean", &"check_blade", &"pace"])
	_check("A13 at his bowl, blade away, with no fire or wall near: nothing that needs them, and he does not wander off",
		eater._rota.at_station() and none, "at station %s, picks %s" % [eater._rota.at_station(), eat_picks.slice(0, 10)])

	# A14 temperament weighs the choice
	await _fresh()
	var stubborn := _guard(Vector3(110, 0, 0), 0.0, &"stubborn")
	var steady := _guard(Vector3(114, 0, 0), 0.0, &"steady")
	var shares := []

	for g in [stubborn, steady]:
		g._life._talk_rest = 99.0
		var count := 0

		for i in 300:
			if g._life._pastimes.choose() == &"fold_arms":
				count += 1

		shares.append(count)

	_check("A14 a stubborn man folds his arms more often than a steady one", shares[0] > shares[1], "stubborn %d, steady %d of 300" % shares)

	# A15 standing his post, he passes the time
	await _fresh()
	var sentry := _guard(Vector3(120, 0, 0), 0.0)
	sentry._life._talk_rest = 9999.0
	var seen := {}
	var furthest := [0.0]
	await _until(func():
		var doing: StringName = sentry.activity()
		if doing != &"":
			seen[doing] = true
		furthest[0] = maxf(furthest[0], Vector2(sentry.global_position.x - 120, sentry.global_position.z).length())
		return false, 3600)
	await _until(func(): return sentry.activity() != &"pace", 600)
	await _frames(120)
	var back := Vector2(sentry.global_position.x - 120, sentry.global_position.z).length()
	# And a pace, out and back (once he is between habits of his own, which
	# stop a pastime: GuardLife.at_rest).
	await _until(func(): return not sentry._habits.busy(), 600)
	sentry._life._pastimes._end()
	sentry._life._pastimes._begin(&"pace")
	var out := [0.0]
	await _until(func():
		out[0] = maxf(out[0], Vector2(sentry.global_position.x - 120, sentry.global_position.z).length())
		return sentry.activity() != &"pace", 900)
	await _frames(60)
	var home := Vector2(sentry.global_position.x - 120, sentry.global_position.z).length()
	_check("A15 standing his post a minute he passes the time three ways or more, never straying far; pacing, out a step or two and back",
		seen.size() >= 3 and furthest[0] <= 2.2 and back < 0.8 and out[0] >= 1.0 and out[0] <= 2.2 and home < 0.8,
		"did %s, furthest %.2f m, back to %.2f m; paced out %.2f m, home %.2f m" % [seen.keys(), furthest[0], back, out[0], home])


# ---------------------------------------------------------------------------
# Atmosphere
# ---------------------------------------------------------------------------

func _atmosphere() -> void:
	await _fresh()
	var air: Node3D = AtmosphereScript.new()
	add_child(air)

	# A16 breath on the cold air, with his breathing
	var breather := _guard(Vector3(130, 0, 0), 0.0)
	breather._life._talk_rest = 99.0
	await _frames(30)
	var matched := [0]

	for f in 120:
		var puffs: Object = air.breath_of(breather)
		if puffs != null and bool(puffs.emitting) == breather._voice.out_breath():
			matched[0] += 1
		await get_tree().physics_frame

	breather._voice.hold_heart(72.0)
	await _frames(10)
	var calm: float = air.breath_of(breather).amount_ratio
	breather._voice.hold_heart(150.0)
	await _frames(10)
	var hard: float = air.breath_of(breather).amount_ratio
	breather._voice.hold_heart(-1.0)
	_check("A16 his breath shows on the out-breath, thicker when his heart races",
		matched[0] >= 108 and hard > calm, "in time %d of 120 frames, puffs %.2f calm, %.2f racing" % [matched[0], calm, hard])

	# A17 embers with the fire
	var fire: Area3D = FireScript.brazier(self, Vector3(140, 0, 0))
	# (It looks about it once a second.)
	await _frames(70)
	fire.fuel = 1.0
	await _frames(3)
	var full: float = air.embers_of(fire)[0].amount_ratio
	fire.fuel = 0.2
	await _frames(3)
	var low: float = air.embers_of(fire)[0].amount_ratio
	fire.feed()
	await _frames(2)
	var burst: bool = air.embers_of(fire)[1].emitting
	_check("A17 embers rise with the fire: fewer burning low, a burst when it is fed", low < full and burst, "embers %.2f full, %.2f low, burst %s" % [full, low, burst])
	fire.get_parent().queue_free()

	# A18 crows on the wall take off at a shout, and come back
	air.add_crows([Vector3(150, 3, 0)])
	await _frames(5)
	SoundBus.emit_sound(Vector3(150, 1, 6), 70.0, self, &"test")
	await _frames(12)
	var flew: bool = air.crows()[0]["state"] == &"flying"
	# Back by the longest they can be gone (Atmosphere: CROW_FLY, the most of
	# CROW_AWAY, CROW_RETURN: 46 s), and a little over.
	await _until(func(): return air.crows()[0]["state"] == &"perched", 3000)
	_check("A18 crows on the wall take off at a shout, and settle again later", flew and air.crows()[0]["state"] == &"perched",
		"flew %s, now %s" % [flew, air.crows()[0]["state"]])

	# A19 the wind leans the flames
	var torch: Node3D = TorchScript.new()
	add_child(torch)
	torch.global_position = Vector3(160, 2, 0)
	air.force_wind(Vector3(1, 0, 0))
	await _frames(70)
	var leaned: float = torch.flame.position.x
	air.force_wind(null)
	_check("A19 the wind leans the flames its way", leaned > 0.01, "flame leaned %.3f m" % leaned)

	# A20 thinned for the frame rate: moths first, then leaves
	air.quality = 1
	await _frames(3)
	var moths_hidden: bool = air.moths().all(func(m): return not m.visible)
	var leaves_on: bool = air.leaves().emitting
	air.quality = 0
	await _frames(3)
	var leaves_off: bool = not air.leaves().emitting
	_check("A20 thinned, the moths go first, then the leaves", not air.moths().is_empty() and moths_hidden and leaves_on and leaves_off,
		"moths %d hidden %s, leaves at 1 %s, at 0 off %s" % [air.moths().size(), moths_hidden, leaves_on, leaves_off])
	torch.queue_free()
	air.queue_free()


# ---------------------------------------------------------------------------
# The final review's findings
# ---------------------------------------------------------------------------

func _steady_gaze() -> void:
	# A21 a man listening holds his eyes on the man speaking (his gaze is
	# not added to his idle drift)
	await _fresh()
	_use(["talk_pair"])
	var director: RefCounted = TalkDirector.of(self)
	var a := _guard(Vector3(170, 0, 0), -PI * 0.5)
	var b := _guard(Vector3(172.6, 0, 0), PI * 0.5)
	await _until(func(): return director.speaking(a) or director.speaking(b), 1800)
	await _frames(20)
	var speaker: Node3D = a if director.speaking(a) else b
	var listener: Node3D = b if speaker == a else a
	var axis := _rest_forward_axis(listener)
	var worst := 0.0

	for i in 8:
		var pose: Dictionary = await _posed_global(listener, [&"Head"])
		var facing: Vector3 = ((pose[&"Head"] as Transform3D).basis * axis).normalized()
		var to_him: Vector3 = (speaker.eye_position() - (pose[&"Head"] as Transform3D).origin).normalized()
		worst = maxf(worst, rad_to_deg(acos(clampf(Vector2(facing.x, facing.z).normalized().dot(Vector2(to_him.x, to_him.z).normalized()), -1.0, 1.0))))
		await _frames(10)

	_check("A21 a man listening holds his eyes on the man speaking, not drifting about him", worst <= 20.0, "at worst %.0f deg off him" % worst)


# ---------------------------------------------------------------------------
# The yard
# ---------------------------------------------------------------------------

func _yard() -> void:
	TemperamentScript.rolling = false
	Props.block(self, Vector3(60, -0.5, 0), Vector3(200, 1, 60))
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.debug_traversal = false
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	player.debug_light_level = 0.0
	player.global_position = Vector3(60, 1.05, 28)
	await baker.baked
	await _frames(5)


func _use(ids: Array) -> void:
	var lib := TalkScript.parse(FIXTURES, "fixtures")
	lib["conversations"] = (lib["conversations"] as Array).filter(func(c): return ids.has(c["id"]))
	TalkDirector.of(self).use_library(lib)


func _guard(at: Vector3, yaw := 0.0, preset: StringName = &"steady", name := "", stations := [], look := -1) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.temperament = preset
	g.debug_ai = false
	g.given_name = name

	if look >= 0:
		g.look_seed = look

	if not stations.is_empty():
		var paths: Array[NodePath] = []

		for station in stations:
			paths.append((station as Node).get_path())

		g.stations = paths

	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g._life._talk_rest = 0.0
	return g


func _fresh() -> void:
	for g in get_tree().get_nodes_in_group(&"guards"):
		g.remove_from_group(&"guards")
		g.set_physics_process(false)
		g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"stray_arrows", &"guard_stations"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	await _frames(5)
	LightProbe.invalidate()


## A man's Head axis that points to his front when he stands at rest.
func _rest_forward_axis(guard: Node3D) -> Vector3:
	var man: Node3D = guard._rig.man
	var rest: Transform3D = man.skeleton.global_transform * man.skeleton.get_bone_global_rest(man.skeleton.find_bone(&"Head"))
	var front := -guard.global_basis.z
	var best := Vector3.ZERO
	var best_dot := -INF

	for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var dot: float = (rest.basis * axis).normalized().dot(front)

		if dot > best_dot:
			best_dot = dot
			best = axis

	return best


## `bones` of a man (a guard's) in the world as posed this frame.
func _posed_global(guard: Node3D, bones: Array) -> Dictionary:
	var man: Node3D = guard._rig.man
	var got := {}
	man.skeleton.skeleton_updated.connect(func():
		for bone in bones:
			got[bone] = man.bone_global(bone), CONNECT_ONE_SHOT)

	while got.is_empty():
		await get_tree().process_frame

	return got


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame


## A man, built as a guard's rig builds one.
func _man(at: Vector3) -> Node3D:
	var man: Node3D = HumanoidScript.new()
	add_child(man)
	man.build(&"watchman", false, &"Sword_Idle")
	man.global_position = at
	return man


## `bones` of `man` in his own frame as posed this frame, Posture's turns and
## all (read while the skeleton says it is posed: after that the turns are
## gone until the next).
func _posed(man: Node3D, bones: Array) -> Dictionary:
	var got := {}
	man.skeleton.skeleton_updated.connect(func():
		for bone in bones:
			got[bone] = _local(man, bone), CONNECT_ONE_SHOT)

	while got.is_empty():
		await get_tree().process_frame

	return got


## A bone of `man` in his own frame.
func _local(man: Node3D, bone: StringName) -> Transform3D:
	return man.global_transform.affine_inverse() * man.bone_global(bone)


## How far up (y, in his frame) the way a bone faces points: its axis
## nearest his front.
func _forward_y(pose: Transform3D) -> float:
	var best := Vector3.ZERO
	var best_dot := -INF

	for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var dir: Vector3 = pose.basis * axis
		var dot := dir.dot(Vector3.FORWARD)

		if dot > best_dot:
			best_dot = dot
			best = dir.normalized()

	return best.y


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
