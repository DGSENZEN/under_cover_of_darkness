extends Node3D
## What the men say to each other: the .talk files and their parser
## (TalkScript), the facts and casting (TalkFacts), the director that plays
## conversations (TalkDirector), and the voice they come out in (GuardVoice).
##
##   Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/talk_test.tscn

const TalkScript := preload("res://scripts/AISystem/Talk/TalkScript.gd")
const TalkFacts := preload("res://scripts/AISystem/Talk/TalkFacts.gd")
const TalkDirector := preload("res://scripts/AISystem/Talk/TalkDirector.gd")
const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Comms := preload("res://scripts/AISystem/Comms.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")

## Conversations for the director's own checks, so they do not hang on the
## writing.
const FIXTURES := """
== talk_pair
cast: A = any; B = any
cooldown: 0s
A: First line, from the one.
B: Second line, from the other.
A: Third line, back again.
B: Fourth and last.

== three_way
cast: A = any; B = any; C = any
cooldown: 0s
A: One.
B: Two.
C: Three.
A: Four.
B: Five.
C: Six.

== hush
when: at_ease
cast: A = any; B = any
cooldown: 0s
A: Quiet night.
B: Quiet enough.
A: Too quiet.
B: Stop saying that.
-- interrupt
B: Hush. What was that?
"""

var results: Array[String] = []
var player: CharacterBody3D
var _barks := {}
## [man, text, Comms.now()] for every line, in order.
var _said: Array = []


func _ready() -> void:
	await _run()
	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	_files()
	_facts()
	await _yard()
	seed(2026)
	GuardScript.randomize_on = false
	await _director()
	GuardScript.randomize_on = true


# ---------------------------------------------------------------------------
# The files
# ---------------------------------------------------------------------------

func _files() -> void:
	# T1 the talk files load clean
	var lib := TalkScript.load_dir()
	var cast: Dictionary = lib["cast"]
	_check("T1 the talk files load clean, the cast sheet has all twelve and its ties run both ways where they should",
		lib["errors"].is_empty() and lib["conversations"].size() >= 13 and cast.size() == 12
		and "Jory" in cast["Osric"]["ties"]["kin"] and "Osric" in cast["Jory"]["ties"]["kin"]
		and "Col" in cast["Piers"]["ties"]["owes"] and not ("Piers" in cast["Col"]["ties"]["owes"])
		and cast["Mirelle"]["rank"] == 4 and "captain" in cast["Mirelle"]["traits"],
		"errors %s, conversations %d, cast %s" % [lib["errors"], lib["conversations"].size(), cast.keys()])

	# T2 a sample reads as written
	var glass: Dictionary = _conv(lib, "the_moon_glass")
	_check("T2 the_moon_glass reads as written",
		not glass.is_empty() and glass["when"] == [["at_ease"], ["night:early", "night:middle"]]
		and glass["cast"][1]["reqs"] == [["friend(A)", "any"]] and glass["cooldown"] == TalkScript.ONCE
		and glass["lines"].size() == 4 and glass["lines"][3]["part"] == "B" and glass["lines"][3]["choices"].size() == 2
		and glass["lines"][3]["choices"][0]["if"] == "stubborn" and glass["lines"][3]["choices"][1]["if"] == ""
		and glass["lines"][0]["choices"][0]["emotes"] == ["looks:the tower"],
		str(glass))

	# T3 a bad file reports its file and line
	var bad := TalkScript.parse("== x\ncast: A = any\nA [dances]: Hi.\nQ: Who?\n== x\ncast: A = any\nA: Again.\n", "bad.talk")
	var errs: String = "\n".join(bad["errors"])
	_check("T3 a bad file names the file and line of each fault",
		errs.contains("bad.talk:3") and errs.contains("bad.talk:4") and errs.contains("bad.talk:5"), errs)

	# T4 turn and turn about
	var wrong := []

	for c in lib["conversations"]:
		if c["cast"].size() >= 2 and c["lines"].size() >= 2 and c["lines"][0]["part"] == c["lines"][1]["part"]:
			wrong.append(c["id"])

	_check("T4 every conversation of two or more opens with two different speakers", wrong.is_empty(), str(wrong))


# ---------------------------------------------------------------------------
# Facts and casting
# ---------------------------------------------------------------------------

func _facts() -> void:
	var sheet: Dictionary = TalkScript.library()["cast"]

	# T5 conditions
	var w := {"night": &"late", "dead": 2, "at_ease": false, "dead_names": ["Jory"]}
	_check("T5 conditions read the night and the garrison",
		TalkFacts.holds("night:late", w) and not TalkFacts.holds("night:early", w) and TalkFacts.holds("dead>=1", w)
		and not TalkFacts.holds("dead>=3", w) and TalkFacts.holds("not(at_ease)", w) and TalkFacts.holds("dead(Jory)", w)
		and not TalkFacts.holds("dead(Osric)", w), "")

	# T6 requirements and ties
	var osric := TalkFacts.sheet_man("Osric", sheet)
	var jory := TalkFacts.sheet_man("Jory", sheet)
	var piers := TalkFacts.sheet_man("Piers", sheet, &"craven")
	var col := TalkFacts.sheet_man("Col", sheet)
	_check("T6 requirements read temperament, rank and ties",
		TalkFacts.meets(jory, "kin(A)", {"A": osric}, {}) and TalkFacts.meets(piers, "owes(A)", {"A": col}, {})
		and not TalkFacts.meets(col, "owes(A)", {"A": piers}, {}) and TalkFacts.meets(piers, "craven", {}, {})
		and not TalkFacts.meets(col, "craven", {}, {}) and TalkFacts.meets(TalkFacts.sheet_man("Mirelle", sheet), "rank>=4", {}, {})
		and TalkFacts.meets(TalkFacts.sheet_man("Mirelle", sheet), "captain", {}, {}) and TalkFacts.meets(col, "not(captain)", {}, {}), "")

	# T7 casting
	var dice: Dictionary = TalkScript.parse("== d\ncast: A = any; B = owes(A); C? = friend(A)|friend(B)\nA: You owe me.\nB: Three.\nC: Pay him.\n", "t")["conversations"][0]
	var cast7 := TalkFacts.cast_parts(dice, [piers, col, TalkFacts.sheet_man("Ned", sheet)], {})
	_check("T7 casting fills parts by their ties and leaves an optional part empty when nobody fits",
		cast7.get("A", {}).get("name") == "Col" and cast7.get("B", {}).get("name") == "Piers" and not cast7.has("C"), str(cast7.keys()))

	# T8 an unknown word
	var bad := TalkScript.load_text_for_test("== y\nwhen: at_eaze\ncast: A = any\nA: Hm.\n", "y.talk")
	_check("T8 a condition nobody knows is an error with its file and line",
		"\n".join(bad["errors"]).contains("y.talk:2: unknown condition 'at_eaze'"), str(bad["errors"]))

	# T9 the quietest first
	var any2: Dictionary = TalkScript.parse("== q\ncast: A = any; B = any\nA: One.\nB: Two.\n", "t")["conversations"][0]
	var x := TalkFacts.sheet_man("Tam", sheet)
	var y := TalkFacts.sheet_man("Gideon", sheet)
	var cast9 := TalkFacts.cast_parts(any2, [x, y], {})
	_check("T9 the quietest man is cast first", cast9.get("A", {}).get("name") == "Tam" and cast9.get("B", {}).get("name") == "Gideon", str(cast9.keys()))


# ---------------------------------------------------------------------------
# The director
# ---------------------------------------------------------------------------

func _director() -> void:
	# T10 two men at their ease talk a whole conversation, turn and turn about
	await _fresh()
	_use(["talk_pair"])
	var a := _guard(Vector3(0, 0, 0), -PI * 0.5)
	var b := _guard(Vector3(2.6, 0, 0), PI * 0.5)
	await _until(func(): return _said.size() >= 4, 1500)
	var texts := _said.map(func(e): return e[1])
	var turns: bool = _said.size() >= 4 and _said[0][0] != _said[1][0] and _said[1][0] != _said[2][0] and _said[2][0] != _said[3][0]
	_check("T10 two men at their ease talk a written conversation through, turn and turn about",
		texts.slice(0, 4) == ["First line, from the one.", "Second line, from the other.", "Third line, back again.", "Fourth and last."] and turns,
		"said %s" % [texts])

	# T11 one speaker at a time
	await _fresh()
	_use(["three_way"])
	var men := [_guard(Vector3(20, 0, 0), 0.0), _guard(Vector3(22.5, 0, 0), 0.0), _guard(Vector3(21.25, 0, 2.1), PI)]
	var director: RefCounted = TalkDirector.of(self)
	var both := [0]
	await _until(func():
		var at_once := men.filter(func(m): return director.speaking(m)).size()
		if at_once > 1:
			both[0] += 1
		return _said.size() >= 6, 2400)
	var gaps_ok := true

	for i in range(1, _said.size()):
		if float(_said[i][2]) - float(_said[i - 1][2]) < TalkDirector.LINE_BASE:
			gaps_ok = false

	_check("T11 in a group of three only one speaks at a time, each line given its time",
		_said.size() >= 6 and both[0] == 0 and gaps_ok, "lines %d, frames with two speaking %d, gaps ok %s" % [_said.size(), both[0], gaps_ok])

	# T12 something stirs them: the interrupt line, and it is over
	await _fresh()
	_use(["hush"])
	var a12 := _guard(Vector3(40, 0, 0), -PI * 0.5)
	var b12 := _guard(Vector3(42.6, 0, 0), PI * 0.5)
	await _until(func(): return _said.size() >= 1, 900)
	var first_by: Node = _said[0][0] if not _said.is_empty() else null
	SoundBus.emit_sound(Vector3(41.3, 0, -6), 60.0, self, &"test")
	await _frames(20)
	var other: Node = b12 if first_by == a12 else a12
	var hushed: bool = _barks_of(other).has("Hush. What was that?")
	var never: bool = not _said.any(func(e): return e[1] == "Too quiet.")
	_check("T12 a noise breaks it off: the next man says the interrupt line, and neither talks on",
		first_by != null and hushed and never and not a12._life.talking() and not b12._life.talking(),
		"said %s, after: %s/%s" % [_said.map(func(e): return e[1]), a12._life.talking(), b12._life.talking()])

	# T13 a call-out ends it
	await _fresh()
	_use(["talk_pair"])
	var a13 := _guard(Vector3(60, 0, 0), -PI * 0.5)
	var b13 := _guard(Vector3(62.6, 0, 0), PI * 0.5)
	await _until(func(): return _said.size() >= 1, 900)
	var was13: bool = a13._life.talking()
	a13.bark("Over here!")
	await _frames(12)
	_check("T13 a man calling out ends his conversation", was13 and not a13._life.talking() and not b13._life.talking(),
		"talking before %s, after %s/%s" % [was13, a13._life.talking(), b13._life.talking()])

	# T14 a man gone in the middle of his line
	await _fresh()
	_use(["talk_pair"])
	var a14 := _guard(Vector3(80, 0, 0), -PI * 0.5)
	var b14 := _guard(Vector3(82.6, 0, 0), PI * 0.5)
	var director14: RefCounted = TalkDirector.of(self)
	await _until(func(): return director14.speaking(a14) or director14.speaking(b14), 900)
	var gone: Node = a14 if director14.speaking(a14) else b14
	var left: Node = b14 if gone == a14 else a14
	var was14: bool = left._life.talking()
	gone.remove_from_group(&"guards")
	gone.queue_free()
	await _frames(60)
	_check("T14 a man freed in the middle of his line: the other stops talking, and nothing breaks",
		was14 and is_instance_valid(left) and not left._life.talking(), "talking before %s, after %s" % [was14, left._life.talking()])

	# T15 a man who walks off
	await _fresh()
	_use(["talk_pair"])
	var a15 := _guard(Vector3(100, 0, 0), -PI * 0.5)
	var b15 := _guard(Vector3(102.6, 0, 0), PI * 0.5)
	await _until(func(): return _said.size() >= 1, 900)
	var was15: bool = b15._life.talking()
	b15._home = Transform3D(b15._home.basis, b15.global_position + Vector3(0, 0, 14))
	await _until(func(): return not a15._life.talking(), 900)
	var apart: float = a15.global_position.distance_to(b15.global_position)
	_check("T15 a man who walks off ends it once he is out of earshot of the talk",
		was15 and not a15._life.talking() and not b15._life.talking() and apart >= TalkDirector.LEAVE_RANGE - 0.5,
		"talking before %s, after %s/%s, apart %.1f m" % [was15, a15._life.talking(), b15._life.talking(), apart])


# ---------------------------------------------------------------------------
# The yard
# ---------------------------------------------------------------------------

func _yard() -> void:
	TemperamentScript.rolling = false
	Props.block(self, Vector3(100, -0.5, 0), Vector3(320, 1, 60))
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
	player.global_position = Vector3(100, 1.05, 28)
	await baker.baked
	await _frames(5)


## The director's conversations for a check: those of FIXTURES named.
func _use(ids: Array) -> void:
	var lib := TalkScript.parse(FIXTURES, "fixtures")
	lib["conversations"] = (lib["conversations"] as Array).filter(func(c): return ids.has(c["id"]))
	TalkDirector.of(self).use_library(lib)


func _guard(at: Vector3, yaw := 0.0, preset: StringName = &"steady", name := "", archetype: StringName = &"") -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.temperament = preset
	g.debug_ai = false
	g.given_name = name
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g._life._talk_rest = 0.0
	_barks[g] = []
	g.barked.connect(func(t):
		_barks[g].append(t)
		_said.append([g, t, Comms.now()]))
	return g


func _fresh() -> void:
	for g in get_tree().get_nodes_in_group(&"guards"):
		g.remove_from_group(&"guards")
		g.set_physics_process(false)
		g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"stray_arrows"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	_barks.clear()
	_said.clear()
	player.debug_light_level = 0.0
	player.global_position = Vector3(100, 1.05, 28)
	await _frames(5)
	LightProbe.invalidate()


func _barks_of(g: Node) -> Array:
	return _barks.get(g, [])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _conv(lib: Dictionary, id: String) -> Dictionary:
	for c in lib["conversations"]:
		if c["id"] == id:
			return c

	return {}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
