extends Node3D
## The Cinema camera (scripts/Cinema): what the world tells it (CineEvents),
## eased slow motion (TimeFx.ramp), shot framing (CineShot), places to watch
## from (CineVantage), the letterbox and the wipe (CineScreen), the camera's
## movement and lens (CineOperator), and the director's choices in its two
## modes (CineEditor).

const CineEvents := preload("res://scripts/Cinema/CineEvents.gd")
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
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const CineShot := preload("res://scripts/Cinema/CineShot.gd")
const CineVantage := preload("res://scripts/Cinema/CineVantage.gd")
const CineScreen := preload("res://scripts/Cinema/CineScreen.gd")
const CineOperator := preload("res://scripts/Cinema/CineOperator.gd")
const CineEditor := preload("res://scripts/Cinema/CineEditor.gd")

const COMBAT := 4
const SEARCHING := 3

const FIXTURES := """
== pair
cast: A = any; B = any
cooldown: 0s
A: A first line, long enough to be heard.
B: And an answer to it.
"""


## Hears every Cinema event, in order.
class Ears:
	var heard: Array = []

	func cine_event(kind: StringName, data: Dictionary) -> void:
		heard.append({"kind": kind, "data": data})


var results: Array[String] = []
var player: CharacterBody3D
var ears := Ears.new()


func _ready() -> void:
	TemperamentScript.rolling = false
	GuardScript.bleeding_on = false
	await _yard()
	CineEvents.add_listener(ears)
	await _events()
	CineEvents.remove_listener(ears)
	await _ramps()
	await _framing()
	await _vantages()
	await _screen()
	await _operator()
	await _observing()
	await _drama()
	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


# ---------------------------------------------------------------------------
# C: what the world tells the camera
# ---------------------------------------------------------------------------

func _events() -> void:
	# C1 a guard's line: speaker, listeners given, a length, a delivery
	await _fresh()
	var a := _guard(Vector3(0, 0, 0), 0.0)
	var b := _guard(Vector3(1.5, 0, 0), PI)
	await _frames(10)
	ears.heard.clear()
	a.speak("A line of some length, to be heard.", &"whisper", [b])
	var line1: Array = ears.heard.filter(func(e): return e["kind"] == &"line" and e["data"]["speaker"] == a)
	_check("C1 a guard's line tells the camera who speaks, to whom, how long and how",
		line1.size() == 1 and line1[0]["data"]["listeners"] == [b] and float(line1[0]["data"]["seconds"]) > 1.0 \
			and line1[0]["data"]["delivery"] == &"whisper" and (line1[0]["data"]["where"] as Vector3).distance_to(a.global_position) < 0.1,
		"%s" % [line1])

	# C2 a conversation's line names the others as its listeners
	await _fresh()
	_use(["pair"])
	var c := _guard(Vector3(10, 0, 0), 0.0)
	var d := _guard(Vector3(11.5, 0, 0), PI)
	await _frames(10)
	ears.heard.clear()
	var played: bool = TalkDirector.of(self).play("pair", {"A": c, "B": d})
	await _until(func(): return ears.heard.any(func(e): return e["kind"] == &"line" and e["data"]["speaker"] == d), 900)
	var from_c: Array = ears.heard.filter(func(e): return e["kind"] == &"line" and e["data"]["speaker"] == c)
	var from_d: Array = ears.heard.filter(func(e): return e["kind"] == &"line" and e["data"]["speaker"] == d)
	_check("C2 a conversation's line names the other man as its listener, and its length",
		played and from_c.size() == 1 and from_d.size() == 1 and from_c[0]["data"]["listeners"] == [d] and from_d[0]["data"]["listeners"] == [c] \
			and float(from_c[0]["data"]["seconds"]) > 1.0,
		"played %s, lines %s / %s" % [played, from_c, from_d])

	# C3 an alert as his state changes; a spotting as he goes to fight seeing you
	await _fresh()
	var e := _guard(Vector3(20, 0, 0), 0.0)
	await _frames(10)
	ears.heard.clear()
	e._target = player
	e.can_see_target = true
	e._set_state(COMBAT)
	var alert3: Array = ears.heard.filter(func(x): return x["kind"] == &"alert" and x["data"]["man"] == e)
	var spotted3: Array = ears.heard.filter(func(x): return x["kind"] == &"spotted" and x["data"]["man"] == e)
	_check("C3 a man's state changing is an alert (from, to); going to fight seeing you, a spotting",
		alert3.size() == 1 and int(alert3[0]["data"]["from"]) == 0 and int(alert3[0]["data"]["to"]) == COMBAT \
			and spotted3.size() == 1 and spotted3[0]["data"]["target"] == player,
		"alerts %s, spotted %s" % [alert3, spotted3])

	# C4 blows: a quick one light, a power one heavy, a parry, and a backstab
	# the knife then a death
	await _fresh()
	var f := _guard(Vector3(30, 0, 0), 0.0)
	var g := _guard(Vector3(31, 0, 0), PI)
	await _frames(10)
	ears.heard.clear()
	f.take_hit(4.0, g, &"quick", Vector3.ZERO, Vector3.FORWARD)
	f.take_hit(4.0, g, &"power", Vector3.ZERO, Vector3.FORWARD)
	f._struck(&"parried", &"quick", 0.0, g)
	var blows: Array = ears.heard.filter(func(x): return x["kind"] == &"blow" and x["data"]["victim"] == f)
	var weights := blows.map(func(x): return [x["data"]["weight"], x["data"]["outcome"], x["data"]["attacker"] == g])
	ears.heard.clear()
	g.take_hit(10.0, f, &"backstab", Vector3.ZERO, Vector3.FORWARD)
	var kinds := ears.heard.filter(func(x): return x["data"].get("victim") == g or x["data"].get("man") == g).map(func(x): return x["kind"])
	var knife_first: bool = kinds.find(&"knife") >= 0 and kinds.find(&"death") > kinds.find(&"knife")
	_check("C4 a quick blow is light, a power one heavy, a parry is heard as parried; a backstab is the knife, then a death",
		weights == [[&"light", &"landed", true], [&"heavy", &"landed", true], [&"light", &"parried", true]] and knife_first,
		"blows %s; the backstab %s" % [weights, kinds])

	# C5 a death names its killer; a knockout is a death too
	await _fresh()
	var h := _guard(Vector3(40, 0, 0), 0.0)
	var i := _guard(Vector3(41, 0, 0), PI)
	var j := _guard(Vector3(43, 0, 0), PI)
	await _frames(10)
	ears.heard.clear()
	h.die(i)
	j.knock_out(i, true)
	var deaths: Array = ears.heard.filter(func(x): return x["kind"] == &"death")
	_check("C5 a death names who died and who killed him; a knockout is one too",
		deaths.any(func(x): return x["data"]["man"] == h and x["data"]["killer"] == i) and deaths.any(func(x): return x["data"]["man"] == j),
		"%s" % [deaths.map(func(x): return [x["data"]["man"], x["data"]["killer"]])])

	# C6 a listener freed without saying so is passed over
	var holder := Node.new()
	add_child(holder)
	var node_ears := _NodeEars.new()
	holder.add_child(node_ears)
	CineEvents.add_listener(node_ears)
	node_ears.free()
	ears.heard.clear()
	CineEvents.emit(&"line", {"speaker": null, "listeners": [], "seconds": 1.0, "delivery": &"", "text": "x", "where": Vector3.ZERO})
	_check("C6 a listener freed without leaving is passed over; the others still hear",
		ears.heard.size() == 1, "heard %d" % ears.heard.size())
	holder.queue_free()


## A man as the camera sees him (light: no rig, no AI): where he stands,
## which way he faces and goes, what he is doing.
class Man extends Node3D:
	var velocity := Vector3.ZERO
	var _target: Node3D = null
	var eye_height := 1.6
	var doing: StringName = &""
	var _knocked_out := false

	func eye_position() -> Vector3:
		return global_position + Vector3.UP * eye_height

	func activity() -> StringName:
		return doing


## A listener that is a node (freed in C6 without leaving).
class _NodeEars extends Node:
	func cine_event(_kind: StringName, _data: Dictionary) -> void:
		pass


# ---------------------------------------------------------------------------
# R: eased slow motion
# ---------------------------------------------------------------------------

func _ramps() -> void:
	await _fresh()
	TimeFx.clear()
	TimeFx.set_base(1.0)

	# R1 eased down to 0.3, held, eased back, gone
	TimeFx.ramp(get_tree(), &"cinema", 0.3, 0.2, 1.2, 0.5)
	await _real(0.5)
	var held1 := Engine.time_scale
	await _real(1.7)
	_check("R1 a ramp eases time down to 0.3, holds it, and eases it back to 1, then is gone",
		absf(held1 - 0.3) < 0.02 and absf(Engine.time_scale - 1.0) < 0.001 and not TimeFx.is_active(&"cinema"),
		"held %.3f, after %.3f, active %s" % [held1, Engine.time_scale, TimeFx.is_active(&"cinema")])

	# R2 it stacks: on a base of 0.5, 0.15 held; a hit-stop inside it slows
	# further, then gives it back
	TimeFx.set_base(0.5)
	TimeFx.ramp(get_tree(), &"cinema", 0.3, 0.2, 1.2, 0.5)
	await _real(0.5)
	var held2 := Engine.time_scale
	TimeFx.hitstop(get_tree(), 0.1)
	await _real(0.03)
	var stopped2 := Engine.time_scale
	await _real(0.2)
	var after2 := Engine.time_scale
	await _real(1.5)
	TimeFx.set_base(1.0)
	_check("R2 a ramp stacks with the show's speed and a hit-stop: 0.15 on a base of 0.5, 0.025 in a hit-stop, 0.15 after",
		absf(held2 - 0.15) < 0.01 and absf(stopped2 - 0.025) < 0.005 and absf(after2 - 0.15) < 0.01,
		"held %.3f, in the hit-stop %.3f, after %.3f" % [held2, stopped2, after2])

	# R3 cleared in the middle: back at once, and it stays back
	TimeFx.ramp(get_tree(), &"cinema", 0.3, 0.2, 1.2, 0.5)
	await _real(0.5)
	TimeFx.clear()
	var cleared3 := Engine.time_scale
	await _real(1.8)
	_check("R3 cleared in the middle of a ramp, time is back at once and stays back",
		absf(cleared3 - 1.0) < 0.001 and absf(Engine.time_scale - 1.0) < 0.001 and not TimeFx.is_active(&"cinema"),
		"cleared %.3f, later %.3f" % [cleared3, Engine.time_scale])


## `seconds` of real time (physics ticks are real seconds: TimeFx.real_time).
func _real(seconds: float) -> void:
	var until := TimeFx.real_time() + seconds

	while TimeFx.real_time() < until:
		await get_tree().physics_frame


# ---------------------------------------------------------------------------
# F: framing
# ---------------------------------------------------------------------------

func _framing() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.current = true
	var w := 1920.0
	var h := 1080.0
	var man := _man(Vector3(100, 0, 0), -PI * 0.5)

	# F1 a close shot: his head on a third, his eyes in the upper third
	var close := CineShot.frame(&"close", [man], {})
	var at1 := _project(camera, close, CineShot.head_of(man))
	var on_third1: bool = absf(at1.x - w / 3.0) < 0.04 * w or absf(at1.x - w * 2.0 / 3.0) < 0.04 * w
	_check("F1 a close shot puts his head on a third and his eyes in the upper third",
		on_third1 and at1.y >= 0.22 * h and at1.y <= 0.40 * h and close["size"] == &"close" and not camera.is_position_behind(CineShot.head_of(man)),
		"head at %s of %sx%s, %.2f m off" % [at1, w, h, close["position"].distance_to(CineShot.head_of(man))])

	# F2 room on the side he faces: his head on the other third, whichever
	# way he faces
	var roomy := true
	var seen2 := []

	for yaw in [-PI * 0.5, PI * 0.5, 0.0, PI]:
		man.rotation.y = yaw
		var f := CineShot.frame(&"close", [man], {})
		var head := _project(camera, f, CineShot.head_of(man))
		var ahead := _project(camera, f, CineShot.head_of(man) + CineShot.facing(man) * 0.5)
		roomy = roomy and signf(ahead.x - head.x) != signf(head.x - w * 0.5)
		seen2.append([snappedf(yaw, 0.01), roundi(head.x), roundi(ahead.x)])

	man.rotation.y = -PI * 0.5
	_check("F2 he has room on the side he faces: his head sits on the far third", roomy, "%s" % [seen2])

	# F3 the lens by kind
	var other := _man(Vector3(103, 0, 1), PI * 0.5)
	var lenses := {}

	for kind in [&"establishing", &"observe", &"roving", &"group", &"medium", &"close", &"over_shoulder", &"two", &"reaction", &"insert", &"track", &"overhead"]:
		lenses[kind] = float(CineShot.frame(kind, [man, other], {"from": Vector3(120, 4, 10), "target": man})["fov"])

	var lens_ok: bool = [&"observe", &"group", &"track"].all(func(k): return lenses[k] >= 26.0 and lenses[k] <= 32.0) \
		and [&"close", &"over_shoulder", &"reaction"].all(func(k): return lenses[k] >= 35.0 and lenses[k] <= 45.0) \
		and [&"medium", &"two", &"roving"].all(func(k): return is_equal_approx(lenses[k], 40.0)) \
		and lenses[&"establishing"] >= 30.0 and lenses[&"establishing"] <= 40.0 and is_equal_approx(lenses[&"overhead"], 50.0) and is_equal_approx(lenses[&"insert"], 32.0)
	_check("F3 each kind of shot has its lens: long for watching, near normal up close", lens_ok, "%s" % [lenses])

	# F4 a two-shot stays on the side of the line it is given
	var line := other.global_position - man.global_position
	line.y = 0.0
	var side := Vector3.UP.cross(line.normalized())
	var sides := []

	for s4 in [side, -side]:
		var f4 := CineShot.frame(&"two", [man, other], {"side": s4})
		var centre := (man.global_position + other.global_position) * 0.5
		sides.append(((f4["position"] as Vector3) - centre).dot(s4) > 0.0)

	_check("F4 a two-shot stands on the side of their line it is given", sides == [true, true], "%s" % [sides])

	# F9 a portrait: at his eye height, 32 deg, 30 deg off his line to the
	# other man, on a third with room toward him
	var toward9 := CineShot.head_of(other)
	var p9 := CineShot.frame(&"portrait", [man], {"toward": toward9, "side": side})
	var head9 := CineShot.head_of(man)
	var at9 := _project(camera, p9, head9)
	var room9 := _project(camera, p9, head9 + (toward9 - head9).normalized() * 0.5)
	var off9 := Vector3(p9["position"].x - head9.x, 0, p9["position"].z - head9.z)
	var line9 := Vector3(toward9.x - head9.x, 0, toward9.z - head9.z)
	var on_third9: bool = absf(at9.x - w / 3.0) < 0.04 * w or absf(at9.x - w * 2.0 / 3.0) < 0.04 * w
	_check("F9 a portrait: at his eye height, 32 deg, 30 deg off his line to the other man, on a third with room toward him",
		absf(p9["position"].y - head9.y) < 0.05 and is_equal_approx(float(p9["fov"]), 32.0) and on_third9 and signf(room9.x - at9.x) != signf(at9.x - w * 0.5) \
			and absf(rad_to_deg(off9.angle_to(line9)) - 30.0) < 2.0 and p9["kind"] == &"portrait" and p9["size"] == &"close",
		"height %.2f of %.2f, fov %s, head at %s (room toward %s), %.1f deg off the line" % [p9["position"].y, head9.y, p9["fov"], at9, room9, rad_to_deg(off9.angle_to(line9))])

	# F10 the other man's portrait mirrors it: the same side of the line, his
	# head on the other third
	var p10 := CineShot.frame(&"portrait", [other], {"toward": head9, "side": side})
	var at10 := _project(camera, p10, toward9)
	var centre10 := (man.global_position + other.global_position) * 0.5
	var same_side: bool = ((p9["position"] as Vector3) - centre10).dot(side) > 0.0 and ((p10["position"] as Vector3) - centre10).dot(side) > 0.0
	_check("F10 the other man's portrait mirrors it: the same side of their line, his head on the other third",
		same_side and signf(at10.x - w * 0.5) != signf(at9.x - w * 0.5), "same side %s, heads at %.0f and %.0f" % [same_side, at9.x, at10.x])

	# F5 the axial steps: one axis, nearer each time, a longer lens each time
	var axial := []

	for step in 3:
		axial.append(CineShot.frame(&"axial", [man], {"from": Vector3(115, 1.6, 6), "step": step}))

	var head5 := CineShot.head_of(man)
	var dirs := axial.map(func(f): return ((f["position"] as Vector3) - head5).normalized())
	var dists := axial.map(func(f): return (f["position"] as Vector3).distance_to(head5))
	var one_axis: bool = rad_to_deg((dirs[0] as Vector3).angle_to(dirs[1])) < 2.0 and rad_to_deg((dirs[0] as Vector3).angle_to(dirs[2])) < 2.0
	_check("F5 an axial cut-in keeps one axis, comes nearer each step, and narrows the lens 40, 34, 28",
		one_axis and dists[0] > dists[1] and dists[1] > dists[2] and axial.map(func(f): return roundi(f["fov"])) == [40, 34, 28] \
			and axial.map(func(f): return f["size"]) == [&"wide", &"medium", &"close"],
		"dirs %s, distances %s, lenses %s" % [dirs, dists, axial.map(func(f): return f["fov"])])

	# F6 a 4:3 screen: still on a third
	view.size = Vector2i(1440, 1080)
	var close6 := CineShot.frame(&"close", [man], {"aspect": 1440.0 / 1080.0})
	var at6 := _project(camera, close6, CineShot.head_of(man))
	_check("F6 on a 4:3 screen the head is still on a third",
		absf(at6.x - 480.0) < 0.04 * 1440.0 or absf(at6.x - 960.0) < 0.04 * 1440.0, "head at %s of 1440x1080" % [at6])
	view.size = Vector2i(1920, 1080)

	# F7 over the listener's shoulder onto the speaker
	var ots := CineShot.frame(&"over_shoulder", [man, other], {})
	var speaker7 := _project(camera, ots, CineShot.head_of(man))
	var listener7 := _project(camera, ots, CineShot.head_of(other))
	var third7: bool = absf(speaker7.x - w / 3.0) < 0.05 * w or absf(speaker7.x - w * 2.0 / 3.0) < 0.05 * w
	_check("F7 over the listener's shoulder: the speaker on a third, the listener's head in the frame, the shoulder soft",
		third7 and listener7.x >= 0.0 and listener7.x <= w and not camera.is_position_behind(CineShot.head_of(other)) and bool(ots["near_blur"]),
		"speaker %s, listener %s, near blur %s" % [speaker7, listener7, ots["near_blur"]])

	# F8 where his head is, lying or sat
	man.doing = &"sleep"
	var lying := CineShot.head_of(man).y - man.global_position.y
	man.doing = &"sit"
	var sat := CineShot.head_of(man).y - man.global_position.y
	man.doing = &""
	_check("F8 his head is 0.35 m up lying, 0.95 m sat", is_equal_approx(lying, 0.35) and is_equal_approx(sat, 0.95), "lying %.2f, sat %.2f" % [lying, sat])
	man.queue_free()
	other.queue_free()
	view.queue_free()


# ---------------------------------------------------------------------------
# V: places to watch from
# ---------------------------------------------------------------------------

func _vantages() -> void:
	var space := get_world_3d().direct_space_state
	var dressing: Array[Node] = []

	# V1 a marker behind a wall is never taken
	var man1 := _man(Vector3(300, 0, 0), 0.0)
	var hidden := _marker(Vector3(318, 1.6, 0))
	dressing.append(Props.block(self, Vector3(309, 2.0, 0), Vector3(0.4, 4.0, 6.0)))
	await _frames(3)
	var got1 := CineVantage.best(get_tree(), [man1], &"long", Vector3.ZERO, space)
	_check("V1 a marker behind a wall is never chosen; a clear place is",
		got1 != Vector3.INF and got1.distance_to(hidden.global_position) > 0.5 and CineVantage.sees(space, got1, [man1]),
		"chose %s (the hidden marker at %s)" % [got1, hidden.global_position])
	hidden.queue_free()

	# V2 the long lens wants 18 m, not 8 or 40
	var man2 := _man(Vector3(360, 0, 0), 0.0)
	var near := _marker(Vector3(360, 1.6, 8))
	var right := _marker(Vector3(342, 1.6, 0))
	var far := _marker(Vector3(360, 1.6, -40))
	await _frames(3)
	var got2 := CineVantage.best(get_tree(), [man2], &"long", Vector3.ZERO, space)
	_check("V2 for a long lens the place 18 m off is chosen over 8 m and 40 m", got2.distance_to(right.global_position) < 0.1,
		"chose %s" % [got2])

	for m in [near, right, far]:
		m.queue_free()

	# V3 two places 18 m off: the one with something half in the way
	var man3 := _man(Vector3(420, 0, 0), 0.0)
	var open := _marker(Vector3(438, 1.6, 0))
	var framed := _marker(Vector3(402, 1.6, 0))
	dressing.append(Props.block(self, Vector3(411, 1.2, 0.8), Vector3(0.3, 2.4, 0.3)))
	await _frames(3)
	var got3 := CineVantage.best(get_tree(), [man3], &"long", Vector3.ZERO, space)
	_check("V3 of two places 18 m off, the one with a post half in the way (watched from hiding)", got3.distance_to(framed.global_position) < 0.1,
		"chose %s (framed at %s)" % [got3, framed.global_position])
	open.queue_free()
	framed.queue_free()

	# V4 a side given: the place is on that side
	var man4 := _man(Vector3(480, 0, 0), 0.0)
	var side4 := Vector3(0, 0, -1)
	await _frames(3)
	var got4 := CineVantage.best(get_tree(), [man4], &"medium", side4, space)
	_check("V4 with a side given, the place is on that side", got4 != Vector3.INF and (got4 - man4.global_position).dot(side4) > 0.0,
		"chose %s" % [got4])

	# V5 a man shut in by four walls, no markers: nowhere
	var man5 := _man(Vector3(540, 0, 0), 0.0)

	for wall in [[Vector3(542, 2.5, 0), Vector3(0.4, 5, 4.4)], [Vector3(538, 2.5, 0), Vector3(0.4, 5, 4.4)], [Vector3(540, 2.5, 2), Vector3(4.4, 5, 0.4)], [Vector3(540, 2.5, -2), Vector3(4.4, 5, 0.4)]]:
		dressing.append(Props.block(self, wall[0], wall[1]))

	await _frames(3)
	var got5 := CineVantage.best(get_tree(), [man5], &"long", Vector3.ZERO, space)
	_check("V5 a man shut in by four walls has no place to be watched from", got5 == Vector3.INF, "chose %s" % [got5])

	# V6 a place inside a wall (a ray from inside it sees out) is never taken
	var man6 := _man(Vector3(900, 0, 0), 0.0)
	var buried := _marker(Vector3(918, 1.6, 0))
	var clear6 := _marker(Vector3(882, 1.6, 0))
	dressing.append(Props.block(self, Vector3(918, 2.0, 0), Vector3(2, 4, 2)))
	await _frames(3)
	var got6 := CineVantage.best(get_tree(), [man6], &"long", Vector3.ZERO, space)
	_check("V6 a place inside a wall is never chosen, however well it seems to see", got6.distance_to(clear6.global_position) < 0.1,
		"chose %s (inside the wall at %s)" % [got6, buried.global_position])
	buried.queue_free()
	clear6.queue_free()

	# V7 a frame walled in close on both sides is not open; out in the yard it is
	var man7 := _man(Vector3(960, 0, 0), 0.0)
	dressing.append(Props.block(self, Vector3(960, 2.0, 3.6), Vector3(12, 4, 0.3)))
	dressing.append(Props.block(self, Vector3(960, 2.0, -3.6), Vector3(12, 4, 0.3)))
	dressing.append(Props.block(self, Vector3(957, 2.0, 0.6), Vector3(8, 4, 0.2)))
	dressing.append(Props.block(self, Vector3(957, 2.0, -0.6), Vector3(8, 4, 0.2)))
	await _frames(3)
	var head7 := CineShot.head_of(man7)
	var corridor: bool = CineVantage.open(space, Vector3(957, 1.6, 0), head7, 40.0, 16.0 / 9.0, [])
	var yard: bool = CineVantage.open(space, Vector3(960, 1.6, 20), CineShot.head_of(_man(Vector3(960, 0, 17), 0.0)), 40.0, 16.0 / 9.0, [])
	var inside: bool = CineVantage.clear(space, Vector3(957, 2.0, 0.6))
	_check("V7 a frame walled in on both sides is not open, one in the open is; a place in a wall is not clear",
		not corridor and yard and not inside, "corridor open %s, yard open %s, in the wall clear %s" % [corridor, yard, inside])

	for m in [man1, man2, man3, man4, man5, man6, man7]:
		m.queue_free()

	for d in dressing:
		d.queue_free()


# ---------------------------------------------------------------------------
# S: the letterbox and the wipe
# ---------------------------------------------------------------------------

func _screen() -> void:
	var screen: CanvasLayer = CineScreen.new()
	add_child(screen)
	var size := get_viewport().get_visible_rect().size

	# S1 the bars leave a 2.39:1 band, whatever the screen, eased in
	var bands := []

	for dims in [Vector2(1920, 1080), Vector2(1280, 960)]:
		var bar: float = CineScreen.bar_for(dims)
		bands.append(dims.x / (dims.y - 2.0 * bar))

	var empty_before: bool = screen.subtitle_band() == Rect2()
	screen.letterbox(true)
	await _real(0.5)
	var early: float = screen.bar_height()
	await _real(1.1)
	var full: float = screen.bar_height()
	var target: float = CineScreen.bar_for(size)
	_check("S1 the letterbox leaves a 2.39:1 band on any screen, eased in over 1.5 s",
		bands.all(func(b): return absf(b - 2.39) < 0.01) and early < target * 0.5 and early > 0.0 and absf(full - target) < 0.5,
		"bands %s; at 0.5 s %.1f, at 1.6 s %.1f of %.1f" % [bands, early, full, target])

	# S3 the subtitles' place: the lower bar, once it shows
	var band: Rect2 = screen.subtitle_band()
	_check("S3 the subtitles' band is empty without the letterbox and the lower bar with it",
		empty_before and absf(band.position.y - (size.y - full)) < 0.5 and absf(band.size.y - full) < 0.5 and absf(band.size.x - size.x) < 0.5,
		"before %s, after %s (screen %s)" % [empty_before, band, size])

	# S2 a wipe crosses the screen in 0.6 s and lets its frame go; cleared, at once
	var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	var texture := ImageTexture.create_from_image(image)
	screen.wipe(texture)
	var during: bool = screen.wiping()
	await _real(0.3)
	var edge_mid: float = screen.wipe_edge()
	await _real(0.4)
	var over: bool = not screen.wiping() and screen.wipe_texture() == null
	screen.wipe(texture)
	await _real(0.1)
	screen.clear()
	var cleared: bool = not screen.wiping() and screen.wipe_texture() == null
	_check("S2 a wipe crosses the screen over 0.6 s and lets its frame go; cleared, it stops at once",
		during and edge_mid > 0.3 and edge_mid < 0.7 and over and cleared,
		"during %s, edge at 0.3 s %.2f, over %s, cleared %s" % [during, edge_mid, over, cleared])

	# S4 a dissolve: the held frame fades out over 1.2 s and is let go
	screen.dissolve(texture)
	var dissolving4: bool = screen.dissolving()
	await _real(0.6)
	var alpha4: float = screen.dissolve_alpha()
	await _real(0.7)
	var over4: bool = not screen.dissolving() and screen.dissolve_texture() == null
	_check("S4 a dissolve fades its frame out over 1.2 s and lets it go",
		dissolving4 and absf(alpha4 - 0.5) <= 0.1 and over4, "dissolving %s, alpha at 0.6 s %.2f, over by 1.3 s %s" % [dissolving4, alpha4, over4])

	# S5 through black: down over 0.5 s, held, up over 0.5 s
	screen.fade_through(0.4)
	await _real(0.55)
	var down5: float = screen.black()
	await _real(0.3)
	var held5: float = screen.black()
	await _real(0.65)
	var up5: float = screen.black()
	_check("S5 a fade goes to black over 0.5 s, holds, and comes back up over 0.5 s",
		down5 >= 0.99 and held5 >= 0.99 and up5 <= 0.01, "at 0.55 s %.2f, 0.85 s %.2f, 1.5 s %.2f" % [down5, held5, up5])

	# S6 (RF4) cleared in the middle of a fade and a dissolve: gone at once
	screen.fade_through(1.0)
	screen.dissolve(texture)
	await _real(0.3)
	screen.clear()
	var black6: float = screen.black()
	_check("S6 cleared in the middle of a fade and a dissolve: no black and no held frame at once",
		black6 == 0.0 and not screen.dissolving() and screen.dissolve_texture() == null and not screen.fading(),
		"black %.2f, dissolving %s" % [black6, screen.dissolving()])
	screen.queue_free()


# ---------------------------------------------------------------------------
# O: the operator
# ---------------------------------------------------------------------------

func _operator() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	var screen: CanvasLayer = CineScreen.new()
	add_child(screen)
	var op: Node = CineOperator.new()
	add_child(op)
	op.attach(camera, screen)
	var head := Vector3(600, 1.6, 0)

	# O9 the camera is drawn where it is put
	_check("O9 the operator's camera is not interpolated between physics ticks",
		camera.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "mode %d" % camera.physics_interpolation_mode)

	# O1 a drama glide settles without overshooting
	op.set_mode(&"drama")
	op.show(_frame_at(Vector3(600, 1.6, 4), head, 40.0, &"medium"), &"cut")
	await _frames(2)
	var goal1 := Vector3(605, 1.6, 4)
	op.show(_frame_at(goal1, head, 40.0, &"medium"), &"glide")
	var closer := true
	var last := INF
	var grew := []

	for f in 180:
		await get_tree().process_frame
		var gap := camera.global_position.distance_to(goal1)

		if gap > last + 0.0001 and grew.size() < 6:
			grew.append([f, snappedf(last, 0.0001), snappedf(gap, 0.0001), camera.global_position])

		closer = closer and gap <= last + 0.0001
		last = gap

	_check("O1 a glide in drama settles on its mark without overshooting", closer and last < 0.01, "never further %s, off by %.4f m; grew %s" % [closer, last, grew])

	# O2 an observe glide keeps to 0.4 m/s
	op.set_mode(&"observe")
	op.show(_frame_at(Vector3(600, 1.6, 10), head, 24.0, &"medium"), &"cut")
	await _frames(2)
	op.show(_frame_at(Vector3(610, 1.6, 10), head, 24.0, &"medium"), &"glide")
	var fastest := 0.0
	var was := camera.global_position

	for f in 240:
		await get_tree().process_frame
		fastest = maxf(fastest, camera.global_position.distance_to(was) * 60.0)
		was = camera.global_position

	_check("O2 in observe the camera dollies no faster than 0.4 m/s", fastest <= 0.42 and fastest > 0.1, "fastest %.3f m/s" % fastest)

	# O3 a glide through a wall is a cut
	var wall := Props.block(self, Vector3(600, 2.0, 20), Vector3(8, 4, 0.4))
	await _frames(3)
	op.set_mode(&"drama")
	op.show(_frame_at(Vector3(600, 1.6, 17), head, 40.0, &"medium"), &"cut")
	await _frames(2)
	var beyond := Vector3(600, 1.6, 23)
	op.show(_frame_at(beyond, head, 40.0, &"medium"), &"glide")
	await _frames(2)
	_check("O3 a glide whose way crosses a wall becomes a cut", camera.global_position.distance_to(beyond) < 0.01, "at %s" % camera.global_position)
	wall.queue_free()

	# O4 a path through four points, in order
	op.set_mode(&"drama")
	var points := PackedVector3Array([Vector3(600, 1.6, -4), Vector3(602, 1.8, -5), Vector3(604, 1.8, -5), Vector3(606, 1.6, -4)])
	var path_framing := _frame_at(points[0], head, 40.0, &"medium")
	path_framing["path"] = points
	op.show(_frame_at(points[0], head, 40.0, &"medium"), &"cut")
	await _frames(2)
	op.show(path_framing, &"path")
	var nearest := [INF, INF, INF, INF]
	var order := []

	for f in 600:
		await get_tree().process_frame

		for i in 4:
			var d := camera.global_position.distance_to(points[i])
			nearest[i] = minf(nearest[i], d)

			if d < 0.3 and not order.has(i):
				order.append(i)

	_check("O4 a path passes each of its points in order", order == [0, 1, 2, 3], "nearest %s, order %s" % [nearest, order])

	# O10 an observe path keeps to its 0.4 m/s at the joins of its pieces too
	op.set_mode(&"observe")
	var arc := PackedVector3Array()

	for angle in [0.0, 0.53, 1.07, 1.6]:
		arc.append(Vector3(600, 1.7, -10) + Vector3(sin(angle), 0, cos(angle)) * 4.0)

	op.show(_frame_at(arc[0], head, 40.0, &"medium"), &"cut")
	await _frames(2)
	var arc_framing := _frame_at(arc[3], head, 40.0, &"medium")
	arc_framing["path"] = arc
	op.show(arc_framing, &"path")
	var fastest10 := 0.0
	var was10 := camera.global_position

	for f in 1200:
		await get_tree().process_frame
		fastest10 = maxf(fastest10, camera.global_position.distance_to(was10) * 60.0)
		was10 = camera.global_position

	_check("O10 along an observe path, even where its pieces join, the camera keeps to 0.4 m/s", fastest10 <= 0.42 and camera.global_position.distance_to(arc[3]) < 0.05,
		"fastest %.2f m/s, end %.2f m from the last point" % [fastest10, camera.global_position.distance_to(arc[3])])
	op.set_mode(&"drama")

	# O5 a new shot sets its lens at once, a glide too; within a shot (a
	# push-in) the lens eases
	op.show(_frame_at(Vector3(600, 1.6, 4), head, 40.0, &"close"), &"cut")
	await _frames(2)
	op.show(_frame_at(Vector3(600, 1.6, 4.5), head, 28.0, &"close"), &"glide")
	await _frames(1)
	var set5: float = camera.fov
	op.follow(_frame_at(Vector3(600, 1.6, 4.5), head, 34.0, &"close"))
	var biggest := 0.0
	var was_fov: float = camera.fov

	for f in 180:
		await get_tree().process_frame
		biggest = maxf(biggest, absf(camera.fov - was_fov))
		was_fov = camera.fov

	_check("O5 a new shot's lens is set at once (a glide's too); a push-in within the shot eases, never a degree a frame",
		absf(set5 - 28.0) < 0.01 and biggest <= 1.0 and biggest > 0.0 and absf(camera.fov - 34.0) < 0.1,
		"glide set %.2f, biggest step easing %.2f, now %.2f" % [set5, biggest, camera.fov])

	# O6 focus on his head, the blur held down, the near blur only over a shoulder
	op.show(_frame_at(Vector3(600, 1.6, 3), head, 40.0, &"close"), &"cut")
	await _real(0.5)
	var attributes: CameraAttributesPractical = camera.attributes as CameraAttributesPractical
	var focus_ok: bool = attributes != null and absf(op.focus_distance() - camera.global_position.distance_to(head)) < 0.1 \
		and absf(attributes.dof_blur_amount - 0.04) < 0.001 and absf(attributes.dof_blur_far_distance - op.focus_distance() - 4.0) < 0.1 \
		and attributes.dof_blur_far_enabled and not attributes.dof_blur_near_enabled
	var shoulder := _frame_at(Vector3(600, 1.6, 3), head, 40.0, &"close")
	shoulder["near_blur"] = true
	op.show(shoulder, &"cut")
	await _frames(2)
	_check("O6 focus is on his head, the blur a gentle 0.04 beginning 4 m behind him, the near blur only over a shoulder",
		focus_ok and (camera.attributes as CameraAttributesPractical).dof_blur_near_enabled,
		"focus %.2f vs %.2f, attributes %s" % [op.focus_distance(), camera.global_position.distance_to(head), attributes])

	# O7 handheld: a drama close shot within 0.15 deg; observe still
	var sway := {}

	for mode in [&"drama", &"observe"]:
		op.set_mode(mode)
		op.show(_frame_at(Vector3(600, 1.6, 3), head, 40.0, &"close"), &"cut")
		var worst := 0.0

		for f in 240:
			await get_tree().process_frame
			var aim: Vector3 = (op.look_point() - camera.global_position).normalized()
			worst = maxf(worst, rad_to_deg((-camera.global_basis.z).angle_to(aim)))

		sway[mode] = worst

	_check("O7 handheld sways a drama close shot no more than 0.15 deg; an observed one is still",
		sway[&"drama"] <= 0.15 and sway[&"drama"] > 0.01 and sway[&"observe"] < 0.001, "%s" % [sway])

	# O11 no blur on a medium or a wide shot
	var blurless := true

	for size in [&"medium", &"wide"]:
		op.show(_frame_at(Vector3(600, 1.6, 6), head, 30.0, size), &"cut")
		await _frames(2)
		var att := camera.attributes as CameraAttributesPractical
		blurless = blurless and (att == null or (not att.dof_blur_far_enabled and not att.dof_blur_near_enabled))

	_check("O11 a medium or a wide shot has no blur at all", blurless, "blur off %s" % blurless)

	# O8 a shake: never over 2.5 deg, gone in 0.6 s
	op.set_mode(&"observe")
	op.show(_frame_at(Vector3(600, 1.6, 3), head, 40.0, &"medium"), &"cut")
	await _frames(2)
	op.shake(0.8)
	var worst8 := 0.0

	for f in 36:
		await get_tree().process_frame
		var aim8: Vector3 = (op.look_point() - camera.global_position).normalized()
		worst8 = maxf(worst8, rad_to_deg((-camera.global_basis.z).angle_to(aim8)))

	_check("O8 a shake never turns the camera more than 2.5 deg and dies away within 0.6 s",
		worst8 <= 2.5 and worst8 > 0.2 and float(op.trauma) < 0.01, "worst %.2f deg, trauma %.3f" % [worst8, op.trauma])
	op.queue_free()
	screen.queue_free()
	camera.queue_free()


# ---------------------------------------------------------------------------
# E: the editor, observing
# ---------------------------------------------------------------------------

func _observing() -> void:
	seed(1932)
	var camera := Camera3D.new()
	add_child(camera)
	var editor: Node = CineEditor.new()
	add_child(editor)
	editor.take_over(camera)
	var shots: Array = []
	editor.shot_started.connect(func(shot: Dictionary) -> void: shots.append(shot))

	# E1 one man standing, nothing said: long takes, 15 to 45 s each
	var man := _man(Vector3(700, 0, 0), 0.0)
	editor.scene({"mode": &"observe", "subjects": [man]})
	await _real(200.0)
	var lengths := _lengths(shots)
	_check("E1 watched, a man standing still gets long takes: three or more, each 15 to 45 s",
		shots.size() >= 3 and lengths.all(func(l): return l >= 14.9 and l <= 45.1),
		"%d shots, lengths %s" % [shots.size(), lengths])

	# E35 observe: a new take that does not drift there comes in on a dissolve
	var still35 := shots.filter(func(sh): return sh["how"] != &"path")
	_check("E35 watched, a new take that does not drift there comes in on a dissolve",
		not still35.is_empty() and still35.all(func(sh): return sh["how"] == &"dissolve"), "%s" % [shots.map(func(sh): return [sh["kind"], sh["how"]])])

	# E45 a drifting take never snaps: it sets off from where the camera is,
	# or comes in on a dissolve to where it sets off from
	var drifts45 := shots.filter(func(sh): return sh["how"] == &"path")
	_check("E45 watched, a drifting take sets off from where the camera is or dissolves to its start",
		not drifts45.is_empty() and drifts45.all(func(sh): return sh.get("enter") in [&"path", &"dissolve"]), "%s" % [drifts45.map(func(sh): return sh.get("enter"))])

	# E2 no cut while a line is being said (lines not between the scene's
	# men: a conversation's portraits cut inside lines, E27-E33)
	var other := _man(Vector3(701.5, 0, 0.5), PI)
	editor.scene({"mode": &"observe", "subjects": [man, other]})
	await _real(2.0)
	shots.clear()
	var during := [0]
	var speaking_until := [0.0]

	for i in 10:
		var speaker := man if i % 2 == 0 else other
		CineEvents.emit(&"line", {"speaker": speaker, "listeners": [], "seconds": 4.0, "delivery": &"", "text": "...", "where": speaker.global_position})
		speaking_until[0] = TimeFx.real_time() + 4.0
		var start := shots.size()
		await _real(4.0)
		during[0] += shots.size() - start
		await _real(2.0)

	_check("E2 no cut falls while a line is being said", during[0] == 0, "%d shots began during lines" % during[0])

	# E3 a long talk: the lens narrows as it goes on
	await _real(5.0)
	editor.scene({"mode": &"observe", "subjects": [man, other]})
	await _real(1.0)
	var shot3: Dictionary = editor.current()
	var lens_start: float = float(shot3["framing"]["fov"])
	var talked := TimeFx.real_time()

	# (spoken to no one in the scene: a conversation goes to portraits, E28)
	while TimeFx.real_time() - talked < 25.0:
		CineEvents.emit(&"line", {"speaker": man, "listeners": [], "seconds": 4.0, "delivery": &"", "text": "...", "where": man.global_position})
		await _real(4.5)

	var lens_end: float = camera.fov
	_check("E3 over a talk of 25 s the lens narrows to 0.82 of its width or less (the same take throughout)",
		lens_end <= lens_start * 0.82 and editor.current() == shot3, "%.1f -> %.1f, same take %s" % [lens_start, lens_end, editor.current() == shot3])

	# E4 after the last line, it holds 3 s at least before the next shot
	var ended := TimeFx.real_time() + 4.0
	CineEvents.emit(&"line", {"speaker": man, "listeners": [other], "seconds": 4.0, "delivery": &"", "text": "...", "where": man.global_position})
	shots.clear()
	await _real(60.0)
	var began_real: float = float(shots[0]["real_at"]) if not shots.is_empty() else INF
	_check("E4 after the last line it holds 3 s or more before the next shot", began_real - ended >= 2.95,
		"next shot %.2f s after the line ended" % (began_real - ended))

	# E5 a long quiet: it drifts to the fire
	var fire := Node3D.new()
	add_child(fire)
	fire.global_position = Vector3(705, 0.5, 3)
	fire.add_to_group(&"fires")
	editor.scene({"mode": &"observe", "subjects": [man]})
	shots.clear()
	await _real(95.0)
	var insert5 := shots.filter(func(sh): return sh["kind"] == &"insert")
	_check("E5 after a long quiet it drifts to the fire (an insert)", not insert5.is_empty(), "shots %s" % [shots.map(func(sh): return sh["kind"])])
	fire.remove_from_group(&"fires")
	fire.queue_free()

	# E6 hidden behind a wall, a new shot within a second
	editor.scene({"mode": &"observe", "subjects": [man]})
	await _real(3.0)
	shots.clear()
	var eye := camera.global_position
	var head6 := CineShot.head_of(man)
	var mid := (eye + head6) * 0.5
	# (as wide as a third of the way to him, up to 3 m: never round the camera)
	var across6 := minf(3.0, eye.distance_to(head6) * 0.3)
	var wall := Props.block(self, mid, Vector3(across6, 5.0, across6))
	await _real(1.0)
	var hid6 := shots.filter(func(sh): return sh["cause"] == &"hidden")
	_check("E6 his head hidden behind a wall: a new shot within a second", not hid6.is_empty(), "shots %s" % [shots.map(func(sh): return sh["cause"])])
	wall.queue_free()
	await _frames(2)

	# E7 a pin holds under a flood of lines
	editor.scene({"mode": &"observe", "subjects": [man, other], "pin": {"kind": &"close", "subjects": [man], "seconds": 10.0}})
	# (Asked for straight after a cut, the pin waits out the floor first.)
	await _until(func(): return editor.current().get("cause") == &"pin", 120)
	var kinds7 := {}
	var pinned_at := TimeFx.real_time()

	while TimeFx.real_time() - pinned_at < 8.0:
		CineEvents.emit(&"line", {"speaker": other, "listeners": [man], "seconds": 1.0, "delivery": &"shout", "text": "!", "where": other.global_position})
		await _real(0.5)
		kinds7[editor.current().get("kind")] = true

	_check("E7 a pinned close shot holds for its 10 s whatever is said", kinds7.keys() == [&"close"], "%s" % [kinds7.keys()])

	# E8 the man freed in the middle of a shot, then nobody: a new shot, then
	# the place from on high
	await _real(11.0)
	editor.scene({"mode": &"observe", "subjects": [man, other]})
	await _real(3.0)
	shots.clear()
	other.queue_free()
	await _real(2.0)
	man.queue_free()
	await _real(3.0)
	_check("E8 a man freed mid-shot brings a new shot; with nobody left, the place from on high",
		not shots.is_empty() and editor.current().get("kind") == &"establishing", "shots %s" % [shots.map(func(sh): return [sh["kind"], sh["cause"]])])

	# E19 paused, nothing is cut; unpaused, it goes on
	var man19 := _man(Vector3(740, 0, 0), 0.0)
	editor.scene({"mode": &"observe", "subjects": [man19]})
	await _real(2.0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	shots.clear()
	await _real(50.0)
	var while_paused := shots.size()
	get_tree().paused = false
	await _real(50.0)
	process_mode = Node.PROCESS_MODE_INHERIT
	_check("E19 paused, nothing is cut; unpaused, the takes go on", while_paused == 0 and shots.size() >= 1,
		"%d while paused, %d after" % [while_paused, shots.size()])

	# E43 watched scenes asked through black, one after another: each opens
	# through black, a take that would drift there too (the takes turn about
	# between drifting and standing off)
	var fades43 := []

	for i in 4:
		await _real(2.0)
		shots.clear()
		editor.scene({"mode": &"observe", "subjects": [man19], "transition": &"fade"})
		await _real(0.5)
		fades43.append([shots[0]["kind"], shots[0]["how"]] if not shots.is_empty() else [&"none", &"none"])

	_check("E43 watched scenes asked through black each open through black, drifting takes too",
		fades43.all(func(f): return f[1] == &"fade"), "%s" % [fades43])
	man19.queue_free()
	editor.release()
	editor.queue_free()
	camera.queue_free()


# ---------------------------------------------------------------------------
# E: the editor, in drama
# ---------------------------------------------------------------------------

func _drama() -> void:
	seed(1954)
	TimeFx.clear()
	TimeFx.set_base(1.0)
	var camera := Camera3D.new()
	add_child(camera)
	var editor: Node = CineEditor.new()
	add_child(editor)
	editor.take_over(camera)
	var shots: Array = []
	editor.shot_started.connect(func(shot: Dictionary) -> void: shots.append(shot))
	var a := _man(Vector3(800, 0, 0), -PI * 0.5)
	var b := _man(Vector3(803, 0, 0), PI * 0.5)

	# E17 a drama scene brings the letterbox (checked below, once it is in)
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	var screen: CanvasLayer = editor.screen()
	await _real(1.6)
	var bar17: float = screen.bar_height()
	var target17: float = CineScreen.bar_for(get_viewport().get_visible_rect().size)

	# E9 shouts and blows: shots of 3 to 8 s, each ending on a beat or 1.5 s
	# after it fell due (shouts to no one: a fight's barks, not a talk)
	shots.clear()
	var t9 := TimeFx.real_time()
	var n := 0

	while TimeFx.real_time() - t9 < 40.0:
		if n % 3 == 0:
			CineEvents.emit(&"line", {"speaker": a if n % 2 == 0 else b, "listeners": [], "seconds": 2.0, "delivery": &"shout", "text": "...", "where": a.global_position})
		if n % 2 == 0:
			CineEvents.emit(&"blow", {"attacker": a, "victim": b, "weight": &"light", "outcome": &"blocked", "where": b.global_position})
		n += 1
		await _real(1.0)

	var lengths9 := _lengths(shots.filter(func(sh): return sh["kind"] != &"axial"))
	var sorted9 := lengths9.duplicate()
	sorted9.sort()
	var median9: float = sorted9[sorted9.size() / 2] if not sorted9.is_empty() else 0.0
	_check("E9 in drama the shots run 3 to 9.5 s (8 and a wait for a beat), the middle one 3 to 8",
		lengths9.size() >= 4 and lengths9.all(func(l): return l >= 2.95 and l <= 9.55) and median9 >= 2.95 and median9 <= 8.05,
		"%d shots, lengths %s" % [shots.size(), lengths9])

	# E10 two men trading lines: the camera keeps to one side of their line
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(2.0)
	shots.clear()

	for i in 10:
		var speaker := a if i % 2 == 0 else b
		CineEvents.emit(&"line", {"speaker": speaker, "listeners": [b if speaker == a else a], "seconds": 2.5, "delivery": &"shout" if i % 3 == 0 else &"", "text": "...", "where": speaker.global_position})
		await _real(3.0)

	var sides := shots.filter(func(sh): return sh["cause"] != &"neutral").map(func(sh): return signf(((sh["framing"]["position"] as Vector3) - Vector3(801.5, 0, 0)).z))
	_check("E10 two men trading lines: every shot from one side of their line (neutral ones aside)",
		sides.size() >= 4 and (sides.all(func(x): return x > 0.0) or sides.all(func(x): return x < 0.0)),
		"%d shots, sides %s" % [shots.size(), sides])

	# E11 no jump cuts
	var jumps := 0
	var jumped := []
	var centre11 := Vector3(801.5, 1.6, 0)

	for i in range(1, shots.size()):
		var p: Dictionary = shots[i - 1]
		var q: Dictionary = shots[i]

		# (one man's portrait to the other's is shot and reverse shot)
		if p["size"] == q["size"] and q["kind"] != &"axial" and p["subjects"] == q["subjects"]:
			var u: Vector3 = (p["framing"]["position"] as Vector3) - centre11
			var v: Vector3 = (q["framing"]["position"] as Vector3) - centre11
			u.y = 0.0
			v.y = 0.0

			if rad_to_deg(u.angle_to(v)) < 30.0:
				jumps += 1
				jumped.append([p["kind"], p["cause"], p["subjects"].size(), q["kind"], q["cause"], q["subjects"].size(), roundi(rad_to_deg(u.angle_to(v)))])

	_check("E11 no two shots in a row of one size from within 30 deg", jumps == 0, "%d jump cuts in %d shots %s" % [jumps, shots.size(), jumped])

	# E12 a man stirred to searching: three cuts straight in on him
	await _real(2.0)
	shots.clear()
	CineEvents.emit(&"alert", {"man": a, "from": 0, "to": SEARCHING, "where": a.global_position})
	await _real(3.0)
	var axial := shots.filter(func(sh): return sh["kind"] == &"axial")
	var gaps := []
	var one_line := true

	for i in range(1, axial.size()):
		gaps.append(snappedf(float(axial[i]["real_at"]) - float(axial[i - 1]["real_at"]), 0.01))
		var d0: Vector3 = ((axial[0]["framing"]["position"] as Vector3) - CineShot.head_of(a)).normalized()
		var di: Vector3 = ((axial[i]["framing"]["position"] as Vector3) - CineShot.head_of(a)).normalized()
		one_line = one_line and rad_to_deg(d0.angle_to(di)) < 5.0

	var lenses12 := axial.map(func(sh): return roundi(sh["framing"]["fov"]))
	_check("E12 a man stirred to searching: three cuts straight in on him, 0.6 s apart, the lens narrowing",
		axial.size() == 3 and gaps.all(func(g): return absf(g - 0.6) <= 0.1) and one_line and lenses12 == [40, 34, 28],
		"%d axial, gaps %s, one line %s, lenses %s" % [axial.size(), gaps, one_line, lenses12])

	# E13 a face-off held still, side on, long; the first blow cuts in (two
	# who mean each other harm)
	a._target = b
	b._target = a
	await _real(8.0)
	shots.clear()
	await _real(4.0)
	var face: Dictionary = editor.current()
	var still := [0.0]
	var was13 := camera.global_position

	for f in 60:
		await get_tree().process_frame
		still[0] = maxf(still[0], camera.global_position.distance_to(was13) * 60.0)
		was13 = camera.global_position

	var face_ok: bool = face.get("cause") == &"face_off" and float(face["framing"]["fov"]) <= 32.0 and still[0] < 0.05
	var before13 := shots.size()
	CineEvents.emit(&"blow", {"attacker": b, "victim": a, "weight": &"heavy", "outcome": &"landed", "where": a.global_position})
	await _real(0.3)
	var after13: Dictionary = editor.current()
	_check("E13 a face-off is held still, side on, on a long lens; the first blow cuts to a medium shot of the striker",
		face_ok and shots.size() > before13 and after13["size"] == &"medium" and after13["subjects"].size() == 1 and after13["subjects"][0] == b,
		"face-off %s (cause %s, fov %s, moving %.3f m/s); then %s on %s" % [face_ok, face.get("cause"), face.get("framing", {}).get("fov"), still[0], after13.get("kind"), after13.get("subjects")])

	# E14 the knife slows time; a death 3 s after does not, one 9 s after does
	await _real(9.0)
	CineEvents.emit(&"knife", {"attacker": a, "victim": b, "where": b.global_position})
	await _real(0.3)
	var slowed14 := Engine.time_scale
	await _real(1.8)
	var back14 := Engine.time_scale
	await _real(1.0)
	CineEvents.emit(&"death", {"man": b, "killer": a, "where": b.global_position})
	await _real(0.4)
	var third14 := Engine.time_scale
	await _real(5.6)
	CineEvents.emit(&"death", {"man": a, "killer": b, "where": a.global_position})
	await _real(0.4)
	var ninth14 := Engine.time_scale
	await _real(2.5)
	_check("E14 the knife slows time to 0.3 and back by 2.1 s; a death 3 s later does not slow it, one 9 s later does",
		slowed14 <= 0.32 and absf(back14 - 1.0) < 0.01 and absf(third14 - 1.0) < 0.01 and ninth14 <= 0.32,
		"knife %.2f, after %.2f, 3 s on %.2f, 9 s on %.2f" % [slowed14, back14, third14, ninth14])

	# E15 a melee's flood: no cut under 1.5 s apart, the shake held, one slowing at most
	await _real(9.0)
	shots.clear()
	var ramps := [0]
	var worst15 := [0.0]
	var t15 := TimeFx.real_time()
	var slow_before := false

	for i in 30:
		CineEvents.emit(&"blow", {"attacker": a if i % 2 == 0 else b, "victim": b if i % 2 == 0 else a, "weight": &"heavy", "outcome": &"parried" if i % 5 == 0 else &"landed", "where": a.global_position})
		var slow_now: bool = Engine.time_scale < 0.99
		ramps[0] += 1 if slow_now and not slow_before else 0
		slow_before = slow_now
		var aim: Vector3 = (editor._operator.look_point() - camera.global_position).normalized()
		worst15[0] = maxf(worst15[0], rad_to_deg((-camera.global_basis.z).angle_to(aim)))
		await _real(2.0 / 30.0)

	await _real(3.0)
	var gaps15 := []

	for i in range(1, shots.size()):
		if shots[i]["kind"] != &"axial":
			gaps15.append(float(shots[i]["real_at"]) - float(shots[i - 1]["real_at"]))

	_check("E15 a flood of blows: no two cuts under 1.5 s apart, the shake never past 2.5 deg, one slowing at most",
		gaps15.all(func(g): return g >= 1.45) and worst15[0] <= 2.5 and ramps[0] <= 1,
		"gaps %s, worst %.2f deg, slowings %d" % [gaps15, worst15[0], ramps[0]])

	# E16 a new scene of other men: a wipe
	await _real(9.0)
	var c := _man(Vector3(820, 0, 0), 0.0)
	editor.scene({"mode": &"drama", "subjects": [c]})
	_check("E16 a drama scene of men not in the last one opens with a wipe", editor.current().get("how") == &"wipe", "how %s" % editor.current().get("how"))

	# E17 the letterbox: in with drama, kept through observe, down when asked
	editor.scene({"mode": &"observe", "subjects": [c]})
	await _real(2.0)
	var kept17: float = screen.bar_height()
	editor.scene({"mode": &"observe", "subjects": [c], "letterbox": false})
	await _real(2.0)
	var gone17: float = screen.bar_height()
	_check("E17 drama brings the letterbox in within 1.6 s; a later observe scene keeps it; letterbox false takes it down",
		absf(bar17 - target17) < 0.5 and absf(kept17 - target17) < 0.5 and gone17 < 0.5, "in %.1f of %.1f, kept %.1f, then %.1f" % [bar17, target17, kept17, gone17])

	# E20 a line and a death at once: the death's shot (b turned away: no
	# face-off to cut to first)
	b.rotation.y = -PI * 0.5
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(2.0)
	CineEvents.emit(&"line", {"speaker": a, "listeners": [b], "seconds": 2.0, "delivery": &"", "text": "...", "where": a.global_position})
	CineEvents.emit(&"death", {"man": b, "killer": a, "where": b.global_position})
	await _real(0.2)
	_check("E20 a line and a death in one moment: the death is cut to", editor.current().get("cause") == &"death", "cause %s" % editor.current().get("cause"))

	# E21 a new scene straight after a cut waits out the 1.5 s floor (from a
	# shot that has had its floor, so the first scene cuts at once)
	b.rotation.y = -PI * 0.5
	await _real(3.0)
	await _until(func(): return TimeFx.real_time() - float(editor.current()["real_at"]) >= 1.6, 600)
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	var first21: float = float(editor.current()["real_at"])
	shots.clear()
	await _real(0.1)
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(1.25)
	var early21 := shots.size()
	await _real(0.6)
	_check("E21 a new scene 0.1 s after a cut waits for the 1.5 s floor, then cuts",
		absf(first21 - TimeFx.real_time() + 1.95) < 0.2 and early21 == 0 and shots.size() >= 1 and float(shots[0]["real_at"]) - first21 >= 1.45,
		"first cut %.2f s ago, %d shots before 1.35 s, then %s" % [TimeFx.real_time() - first21, early21, shots.map(func(sh): return snappedf(float(sh["real_at"]) - first21, 0.01))])

	# E22 a face-off with nowhere to watch it from: the shots go on; and two
	# men facing who mean nobody harm are no face-off
	var d := _man(Vector3(900, 0, 40), -PI * 0.5)
	var e := _man(Vector3(903, 0, 40), PI * 0.5)
	d._target = e
	e._target = d
	var walls22: Array[Node] = []

	for z in [38.5, 41.5]:
		walls22.append(Props.block(self, Vector3(901.5, 2.5, z), Vector3(80, 5, 0.3)))

	await _frames(3)
	editor.scene({"mode": &"drama", "subjects": [d, e]})
	shots.clear()
	await _real(8.0)
	var went22 := shots.size()

	for w in walls22:
		w.queue_free()

	d._target = null
	e._target = null
	await _frames(3)
	editor.scene({"mode": &"drama", "subjects": [d, e]})
	shots.clear()
	await _real(6.0)
	var friends22 := shots.filter(func(sh): return sh["cause"] == &"face_off").size()
	_check("E22 a face-off nowhere can see still gives way to the next shot; two men facing who mean nobody harm are no face-off",
		went22 >= 1 and friends22 == 0, "%d shots in the corridor in 8 s; %d face-offs between friends" % [went22, friends22])

	# E23 a track runs alongside a running man, keeping him in view
	var runner := _man(Vector3(900, 0, 80), -PI * 0.5)
	runner.velocity = Vector3(5, 0, 0)
	editor.scene({"mode": &"drama", "subjects": [runner], "pin": {"kind": &"track", "subjects": [runner], "seconds": 5.0}})
	await _frames(2)
	var from23 := camera.global_position
	var seen23 := true

	for f in 120:
		runner.global_position += runner.velocity / 60.0
		await get_tree().process_frame
		seen23 = seen23 and not camera.is_position_behind(CineShot.head_of(runner))

	var ran23 := camera.global_position.distance_to(from23)
	_check("E23 a track runs alongside a running man (5 m/s for 2 s) and keeps him before it", ran23 >= 6.0 and seen23,
		"the camera went %.1f m, kept him before it %s" % [ran23, seen23])
	runner.velocity = Vector3.ZERO

	for m in [d, e, runner]:
		m.queue_free()

	# E24 a cut back to a man finds him where he was: the same place, the same lens
	b.rotation.y = PI * 0.5
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(1.6)
	# (from a shot of the other man: the scene may open on a close of him)
	editor.cut_to(&"medium", [b])
	await _real(1.6)
	editor.cut_to(&"close", [a])
	var first24: Dictionary = editor.current()["framing"]
	await _real(1.6)
	editor.cut_to(&"medium", [b])
	await _real(1.6)
	editor.cut_to(&"close", [a])
	var back24: Dictionary = editor.current()["framing"]
	_check("E24 a cut back to a man returns to the same setup: the same place and lens",
		(back24["position"] as Vector3).distance_to(first24["position"]) < 0.1 and is_equal_approx(float(back24["fov"]), float(first24["fov"])),
		"%.3f m apart, lenses %s / %s" % [(back24["position"] as Vector3).distance_to(first24["position"]), first24["fov"], back24["fov"]])

	# E25 moved 2 m since: a new setup
	await _real(1.6)
	editor.cut_to(&"medium", [b])
	a.global_position += Vector3(0, 0, 2.0)
	await _real(1.6)
	editor.cut_to(&"close", [a])
	var moved25: Dictionary = editor.current()["framing"]
	_check("E25 a man who has moved 2 m gets a new setup", (moved25["position"] as Vector3).distance_to(first24["position"]) > 0.5,
		"%.2f m from the old setup" % (moved25["position"] as Vector3).distance_to(first24["position"]))
	a.global_position -= Vector3(0, 0, 2.0)

	# E26 a portrait whose place is in a wall: the shot taken stands clear and sees him
	await _real(1.6)
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(1.6)
	var planned26 := CineShot.frame(&"portrait", [a], {"toward": CineShot.head_of(b), "side": editor._side_of([a, b])})
	var wall26 := Props.block(self, planned26["position"], Vector3(1.2, 4.0, 1.2))
	await _frames(3)
	editor.cut_to(&"portrait", [a], {"toward": CineShot.head_of(b)})
	var took26: Vector3 = editor.current()["framing"]["position"]
	var space26 := get_world_3d().direct_space_state
	_check("E26 a portrait whose place is in a wall is taken from somewhere clear that sees him",
		CineVantage.clear(space26, took26) and CineVantage.sees(space26, took26, [a]), "took %s (planned %s, %s)" % [took26, planned26["position"], editor.current()["kind"]])
	wall26.queue_free()

	# E27 a drama talk: a two-shot until the second line, then portraits,
	# each cut 0.3 s into the new speaker's line; the same man again keeps his
	a._target = null
	b._target = null
	b.rotation.y = PI * 0.5
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(2.0)
	shots.clear()
	var said27 := []
	said27.append(_say(a, b, 2.0))
	await _real(2.4)
	var two27: StringName = editor.current()["kind"]
	await _real(0.1)
	said27.append(_say(b, a, 2.0))
	await _real(2.5)
	var before_again := shots.size()
	said27.append(_say(b, a, 2.0))
	await _real(2.5)
	var kept27 := shots.size() == before_again
	said27.append(_say(a, b, 2.0))
	await _real(1.0)
	var portraits27 := shots.filter(func(sh): return sh["cause"] == &"portrait")
	var lags27 := []

	for sh in portraits27:
		var who: Node3D = sh["subjects"][0]
		var line_at: float = said27[1] if who == b else said27[3]
		lags27.append(snappedf(float(sh["real_at"]) - line_at, 0.01))

	_check("E27 a drama talk: a two-shot until the second line, then portraits 0.3 s into each new speaker's line; the same man again keeps his",
		two27 == &"two" and portraits27.size() == 2 and portraits27[0]["subjects"][0] == b and portraits27[1]["subjects"][0] == a \
			and lags27.all(func(l): return absf(l - 0.3) <= 0.1) and kept27,
		"after the first line %s; portraits %s at %s s into their lines; the same man again kept %s" % [two27, portraits27.map(func(sh): return sh["subjects"][0] == a), lags27, kept27])

	# E34 portraits hold still while he stands
	var at34 := camera.global_position
	var aim34 := -camera.global_basis.z
	var moved34 := 0.0
	var turned34 := 0.0

	for f in 150:
		await get_tree().process_frame
		moved34 = maxf(moved34, camera.global_position.distance_to(at34))
		turned34 = maxf(turned34, rad_to_deg((-camera.global_basis.z).angle_to(aim34)))

	_check("E34 a portrait holds still while he stands: the camera neither moves nor turns",
		editor.current()["kind"] == &"portrait" and moved34 < 0.01 and turned34 < 0.1, "%s, moved %.4f m, turned %.3f deg" % [editor.current()["kind"], moved34, turned34])

	# E29 a shouted line: the listener's portrait as it ends; another 4 s on: no second one
	await _real(4.0)
	shots.clear()
	_say(a, b, 2.0, &"shout")
	await _real(4.0)
	_say(a, b, 2.0, &"shout")
	await _real(3.0)
	var reactions29 := shots.filter(func(sh): return sh["cause"] == &"reaction")
	_check("E29 a hard line brings the listener's portrait as it ends; a second one 4 s later does not",
		reactions29.size() == 1 and reactions29[0]["subjects"][0] == b, "%s" % [shots.map(func(sh): return [sh["cause"], sh["subjects"][0] == b])])

	# E30 the fourth change of speaker: back to a two-shot for one line, then portraits
	await _real(4.0)
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(2.0)
	shots.clear()

	for i in 7:
		_say(a if i % 2 == 0 else b, b if i % 2 == 0 else a, 2.0)
		await _real(2.5)

	var causes30 := shots.map(func(sh): return sh["cause"])
	var re30 := causes30.find(&"reestablish")
	_check("E30 on the fourth change of speaker it goes back to a two-shot for a line, then to portraits",
		re30 >= 0 and re30 < causes30.size() - 1 and causes30[re30 + 1] == &"portrait", "%s" % [causes30])

	# E28 an observe talk: the take goes on until the third line, then portraits
	await _real(4.0)
	editor.scene({"mode": &"observe", "subjects": [a, b]})
	await _real(2.0)
	shots.clear()
	_say(a, b, 2.0)
	await _real(2.5)
	_say(b, a, 2.0)
	await _real(2.5)
	var early28 := shots.filter(func(sh): return sh["cause"] == &"portrait").size()
	_say(a, b, 2.0)
	await _real(1.0)
	var late28 := shots.filter(func(sh): return sh["cause"] == &"portrait")
	_check("E28 an observed talk stays in its take for two lines, and goes to portraits on the third",
		early28 == 0 and late28.size() == 1 and late28[0]["subjects"][0] == a, "%s" % [shots.map(func(sh): return sh["cause"])])

	# E32 (RF2) three men talking in turn: portraits of each, never two cuts
	# under 1.5 s apart, a group shot when the third speaks
	await _real(4.0)
	var c3 := _man(Vector3(801.5, 0, 2.5), PI)
	editor.scene({"mode": &"drama", "subjects": [a, b, c3]})
	await _real(2.0)
	shots.clear()
	var order32 := [[a, b], [b, a], [a, b], [c3, a], [b, c3], [c3, b], [a, c3]]

	for pair in order32:
		_say(pair[0], pair[1], 2.0)
		await _real(2.4)

	var gaps32 := []

	for i in range(1, shots.size()):
		gaps32.append(float(shots[i]["real_at"]) - float(shots[i - 1]["real_at"]))

	var who32 := {}

	for sh in shots.filter(func(sh): return sh["cause"] == &"portrait"):
		who32[sh["subjects"][0]] = true

	_check("E32 three men talking: portraits of each, a group shot when the third speaks, no two cuts under 1.5 s apart",
		who32.size() == 3 and shots.any(func(sh): return sh["cause"] == &"reestablish") and gaps32.all(func(g): return g >= 1.45),
		"portraits of %d men, causes %s, gaps %s" % [who32.size(), shots.map(func(sh): return sh["cause"]), gaps32.map(func(g): return snappedf(g, 0.01))])

	# E31 (RF1) the man in a portrait freed mid-line: a new shot, no error
	await _real(3.0)
	editor.scene({"mode": &"drama", "subjects": [a, c3]})
	await _real(2.0)
	_say(a, c3, 2.0)
	await _real(2.5)
	_say(c3, a, 3.0)
	await _real(2.0)
	var on31: Node3D = editor.current()["subjects"][0] if not (editor.current()["subjects"] as Array).is_empty() else null
	shots.clear()
	var freed31 := TimeFx.real_time()
	c3.queue_free()
	await _real(0.3)
	_check("E31 the man in a portrait freed mid-line: a new shot at once",
		on31 == c3 and not shots.is_empty() and float(shots[0]["real_at"]) - freed31 <= 0.2, "portrait of c3 %s, then %s" % [on31 == c3, shots.map(func(sh): return [sh["kind"], snappedf(float(sh["real_at"]) - freed31, 0.01)])])

	# E33 (RF3) a talk begun during a pin: the pin holds, portraits after
	await _real(3.0)
	editor.scene({"mode": &"drama", "subjects": [a, b], "pin": {"kind": &"close", "subjects": [a], "seconds": 6.0}})
	await _until(func(): return editor.current().get("cause") == &"pin", 120)
	var pinned33 := TimeFx.real_time()
	var held33 := true

	for i in 5:
		_say(a if i % 2 == 0 else b, b if i % 2 == 0 else a, 2.0)

		for f in 150:
			await get_tree().process_frame

			if TimeFx.real_time() - pinned33 < 5.9:
				held33 = held33 and editor.current().get("cause") == &"pin"

	_check("E33 a talk begun during a pin leaves the pin its time; the portraits come after",
		held33 and editor.history().any(func(sh): return sh["cause"] == &"portrait" and float(sh["real_at"]) >= pinned33 + 5.9), "held %s, now %s" % [held33, editor.current().get("cause")])

	# E38 a man stirred in the middle of a drama talk: the three cuts in on
	# him all run, the talk after
	await _real(4.0)
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(2.0)

	for i in 3:
		_say(a if i % 2 == 0 else b, b if i % 2 == 0 else a, 2.0)
		await _real(2.5)

	shots.clear()
	CineEvents.emit(&"alert", {"man": b, "from": 0, "to": SEARCHING, "where": b.global_position})
	_say(a, b, 2.0)
	await _real(2.5)
	var axial38 := shots.filter(func(sh): return sh["kind"] == &"axial")
	_check("E38 a man stirred during a drama talk: the three cuts straight in on him all run",
		axial38.size() == 3, "%s" % [shots.map(func(sh): return [sh["kind"], sh["cause"]])])

	# E39 an act's scene asked through black while the last shot has its
	# floor, and another scene asked before it opens: it opens through black
	await _real(4.0)
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(0.2)
	shots.clear()
	editor.scene({"mode": &"drama", "subjects": [a, b], "transition": &"fade"})
	await _real(0.3)
	editor.scene({"mode": &"drama", "subjects": [b, a]})
	await _real(1.5)
	_check("E39 a fade asked, then another scene before either opens: the scene opens through black",
		not shots.is_empty() and shots[0]["how"] == &"fade", "%s" % [shots.map(func(sh): return [sh["kind"], sh["how"]])])

	# E36 a drama shot past its length waits for a beat and cuts on it
	await _real(4.0)
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(2.0)
	editor.cut_to(&"medium", [a])
	var shot36: Dictionary = editor.current()
	await _real(float(shot36["planned"]) + 0.8)
	var held36: bool = editor.current() == shot36
	CineEvents.emit(&"blow", {"attacker": a, "victim": b, "weight": &"light", "outcome": &"blocked", "where": b.global_position})
	var blow36 := TimeFx.real_time()
	await _real(0.2)
	var after36: Dictionary = editor.current()
	_check("E36 a drama shot past its length waits for a beat: a blow 0.8 s after, and the cut lands on it",
		held36 and after36 != shot36 and absf(float(after36["real_at"]) - blow36) <= 0.1,
		"held %s, cut %.2f s after the blow" % [held36, float(after36["real_at"]) - blow36])

	# E37 after two short shots, a long one
	await _real(2.0)
	editor.cut_to(&"medium", [a])
	await _real(1.6)
	editor.cut_to(&"close", [b])
	await _real(1.6)
	editor.cut_to(&"medium", [b])
	var shot37: Dictionary = editor.current()
	await _real(5.9)
	_check("E37 after two shots under 4 s the next runs 6 s or more",
		editor.current() == shot37 and float(shot37["planned"]) >= 6.0, "planned %.1f, still on it %s" % [float(shot37["planned"]), editor.current() == shot37])

	# E40 lines traded while blows fall: a fight, not a conversation
	await _real(4.0)
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(2.0)
	shots.clear()

	for i in 8:
		CineEvents.emit(&"blow", {"attacker": a, "victim": b, "weight": &"light", "outcome": &"blocked", "where": b.global_position})
		_say(a if i % 2 == 0 else b, b if i % 2 == 0 else a, 1.5)
		await _real(2.0)

	var talked40 := shots.filter(func(sh): return sh["cause"] in [&"portrait", &"reestablish", &"two"])
	_check("E40 lines traded while blows fall are a fight: no portraits",
		talked40.is_empty() and shots.size() >= 2, "%s" % [shots.map(func(sh): return [sh["kind"], sh["cause"]])])

	# E41 men walking as they talk: no portraits
	await _real(6.0)
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(2.0)
	a.velocity = Vector3(1.4, 0, 0)
	b.velocity = Vector3(1.4, 0, 0)
	shots.clear()

	for i in 6:
		_say(a if i % 2 == 0 else b, b if i % 2 == 0 else a, 2.0)
		await _real(2.5)

	a.velocity = Vector3.ZERO
	b.velocity = Vector3.ZERO
	var talked41 := shots.filter(func(sh): return sh["cause"] in [&"portrait", &"reestablish", &"two"])
	_check("E41 men walking as they talk: no portraits",
		talked41.is_empty(), "%s" % [shots.map(func(sh): return [sh["kind"], sh["cause"]])])

	# E44 a talk whose speaker's portrait place is walled: his portrait from
	# further round him, not a close
	await _real(6.0)
	# (he stands side on to the other: his close stands well away from it)
	var yaw44 := b.rotation.y
	b.rotation.y = 0.0
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(2.0)
	var planned44 := CineShot.frame(&"portrait", [b], {"toward": CineShot.head_of(a), "side": editor._side_of([b, a]), "aspect": editor._aspect()})
	var wall44 := Props.block(self, planned44["position"], Vector3(0.8, 4.0, 0.8))
	await _frames(3)
	shots.clear()
	_say(a, b, 2.0)
	await _real(2.5)
	_say(b, a, 2.0)
	await _real(1.0)
	var of_b44 := shots.filter(func(sh): return sh["cause"] == &"portrait" and sh["subjects"] == [b])
	_check("E44 a talk whose portrait place is walled: his portrait from further round him, not a close",
		not of_b44.is_empty() and of_b44[0]["kind"] == &"portrait", "%s" % [shots.map(func(sh): return [sh["kind"], sh["cause"]])])
	wall44.queue_free()
	b.rotation.y = yaw44

	# E18 released in the middle of a slowing and a wipe: time back at once, the screen cleared
	editor.scene({"mode": &"drama", "subjects": [a, b]})
	await _real(9.0)
	CineEvents.emit(&"knife", {"attacker": a, "victim": b, "where": b.global_position})
	var image := Image.create(8, 8, false, Image.FORMAT_RGB8)
	screen.wipe(ImageTexture.create_from_image(image))
	await _real(0.3)
	var slowed18 := Engine.time_scale
	editor.release()
	_check("E18 released in the middle of a slowing and a wipe: time is back at once and the screen cleared",
		slowed18 < 0.99 and absf(Engine.time_scale - 1.0) < 0.001 and screen.wipe_texture() == null,
		"slowed %.2f, now %.2f, wipe %s" % [slowed18, Engine.time_scale, screen.wipe_texture()])

	for m in [a, b, c]:
		m.queue_free()

	editor.queue_free()
	camera.queue_free()
	TimeFx.clear()


## A line from `speaker` to `listener`, `seconds` long, as the talk director
## tells it; when it began (TimeFx.real_time).
func _say(speaker: Node3D, listener: Node3D, seconds: float, delivery: StringName = &"") -> float:
	CineEvents.emit(&"line", {"speaker": speaker, "listeners": [listener], "seconds": seconds, "delivery": delivery, "text": "...", "where": speaker.global_position})
	return TimeFx.real_time()


## How long each shot of `shots` ran, all but the last (editor seconds).
func _lengths(shots: Array) -> Array:
	var lengths := []

	for i in range(shots.size() - 1):
		lengths.append(snappedf(float(shots[i + 1]["at"]) - float(shots[i]["at"]), 0.01))

	return lengths


## A framing as CineShot gives one, with its subject's head.
func _frame_at(position: Vector3, subject: Vector3, fov: float, size: StringName) -> Dictionary:
	return {"kind": &"test", "size": size, "position": position, "look": subject, "fov": fov,
		"focus": position.distance_to(subject), "subject": subject, "near_blur": false}


func _marker(at: Vector3) -> Marker3D:
	var m := Marker3D.new()
	add_child(m)
	m.global_position = at
	m.add_to_group(&"cine_vantage")
	return m


## Where `point` falls on the screen of `camera` put where `framing` says.
func _project(camera: Camera3D, framing: Dictionary, point: Vector3) -> Vector2:
	camera.fov = float(framing["fov"])
	camera.global_position = framing["position"]
	camera.look_at(framing["look"], Vector3.UP)
	return camera.unproject_position(point)


func _man(at: Vector3, yaw: float) -> Man:
	var m := Man.new()
	add_child(m)
	m.global_position = at
	m.rotation.y = yaw
	return m


# ---------------------------------------------------------------------------
# The stage
# ---------------------------------------------------------------------------

func _yard() -> void:
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


func _guard(at: Vector3, yaw := 0.0, preset: StringName = &"steady") -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.temperament = preset
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g._life._talk_rest = 999.0
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


func _frames(n: int) -> void:
	for f in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for f in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
