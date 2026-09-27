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
