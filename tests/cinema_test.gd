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

	var lens_ok: bool = [&"observe", &"group", &"track"].all(func(k): return lenses[k] >= 18.0 and lenses[k] <= 28.0) \
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

	# F5 the axial steps: one axis, nearer each time, a longer lens each time
	var axial := []

	for step in 3:
		axial.append(CineShot.frame(&"axial", [man], {"from": Vector3(115, 1.6, 6), "step": step}))

	var head5 := CineShot.head_of(man)
	var dirs := axial.map(func(f): return ((f["position"] as Vector3) - head5).normalized())
	var dists := axial.map(func(f): return (f["position"] as Vector3).distance_to(head5))
	var one_axis: bool = rad_to_deg((dirs[0] as Vector3).angle_to(dirs[1])) < 2.0 and rad_to_deg((dirs[0] as Vector3).angle_to(dirs[2])) < 2.0
	_check("F5 an axial cut-in keeps one axis, comes nearer each step, and narrows the lens 40, 30, 22",
		one_axis and dists[0] > dists[1] and dists[1] > dists[2] and axial.map(func(f): return roundi(f["fov"])) == [40, 30, 22] \
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

	for m in [man1, man2, man3, man4, man5]:
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
	screen.queue_free()


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
