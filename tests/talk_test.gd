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
const GuardStationScript := preload("res://scripts/AISystem/GuardStation.gd")
const GuardVoiceScript := preload("res://scripts/AISystem/GuardVoice.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

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

== cool_a
cast: A = any; B = any
cooldown: 60s
A: Cool a, one.
B: Cool a, two.

== once_conv
cast: A = any; B = any
cooldown: once
priority: 5
A: Only once tonight.
B: Just the once.

== plain
cast: A = any; B = any
cooldown: 0s
A: Plain, one.
B: Plain, two.

== plain2
cast: A = any; B = any
cooldown: 0s
A: Plain again, one.
B: Plain again, two.

== g1
cast: A = any; B = any
cooldown: 0s
group: g
A: Group one.
B: Aye, one.

== g2
cast: A = any; B = any
cooldown: 0s
group: g
A: Group two.
B: Aye, two.

== g3
cast: A = any; B = any
cooldown: 0s
group: g
A: Group three.
B: Aye, three.

== cold_1
cast: A = name(Frost); B = any
cooldown: 0s
A: Cold again.
B: Always is.

== cold_2
cast: A = name(Frost); B = any
cooldown: 0s
A: Cold again.
B: You said.

== temper_check
cast: A = any; B = any
cooldown: 0s
A: What do we do?
B {if rash}: I'll gut him.
B: Let it be.

== join_me
cast: A = any; B = any; C? = any
cooldown: 0s
A: A long first line, to give him the time to walk over and join us.
B: A long second line, still waiting on the third man to come over.
A: A third line, for the time it takes.
B: And a fourth, for good measure.
C: I'm here now.
A: Good.

== chop_curse_1
place: chop
cast: A = any
cooldown: 0s
A: Come on, you knotted thing.

== chop_curse_2
place: chop
cast: A = any
cooldown: 0s
A: Split, damn you.

== muse_1
cast: A = any
cooldown: 0s
again: yes
A: Long night.

== muse_2
cast: A = any
cooldown: 0s
again: yes
A: Cold one.
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
	_writing()
	await _yard()
	seed(2026)
	GuardScript.randomize_on = false
	await _director()
	await _memory()
	await _voice()
	await _fight_talk()
	await _review_fixes()
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
# The writing
# ---------------------------------------------------------------------------

func _writing() -> void:
	var lib: Dictionary = TalkScript.load_dir()
	var sheet: Dictionary = lib["cast"]
	var cast: Array = (load("res://maps/npc_showcase.gd") as GDScript).get("CAST")

	# T34 every conversation can be cast from the showcase's men
	var uncastable := []

	for conv in lib["conversations"]:
		var men := _showcase_men(cast, sheet, StringName(conv["place"]))

		if TalkFacts.cast_parts(conv, men, {}).is_empty():
			uncastable.append(conv["id"])

	_check("T34 every conversation, remark and call can be cast from the showcase's men", uncastable.is_empty(), str(uncastable))

	# T35 enough of each
	var counts := {}

	for conv in lib["conversations"]:
		var file := String(conv["source"]).get_file().get_slice(":", 0).get_basename()
		counts[file] = int(counts.get(file, 0)) + 1

	var wanted := {"at_ease": 20, "gatherings": 15, "unease": 5, "fear": 7, "solo": 90, "combat": 22}
	var short := []

	for file in wanted:
		if int(counts.get(file, 0)) < int(wanted[file]):
			short.append("%s %d/%d" % [file, int(counts.get(file, 0)), wanted[file]])

	_check("T35 the night has its writing: enough of each kind", short.is_empty(), "short %s, counts %s" % [short, counts])

	# T36 the voice: short lines, no modern words
	var banned := ["okay", "ok", "guys", "yeah", "cool", "dude", "gonna", "wanna", "kids", "awesome"]
	var long := []
	var modern := []

	for conv in lib["conversations"]:
		for turn in conv["lines"] + conv["interrupt"]:
			for choice in turn["choices"]:
				var text := String(choice["text"])

				if text.split(" ", false).size() > 16:
					long.append(conv["id"])

				for word in text.to_lower().replace(".", " ").replace(",", " ").replace("!", " ").replace("?", " ").split(" ", false):
					if banned.has(word):
						modern.append("%s:%s" % [conv["id"], word])

	_check("T36 every line is short and of its time", long.is_empty() and modern.is_empty(), "too long %s, modern %s" % [long, modern])

	# T37 every man has his own conversations
	var thin := []

	for entry in cast:
		var name: String = entry[0]
		var count := 0

		for conv in lib["conversations"]:
			var file := String(conv["source"]).get_file().get_slice(":", 0).get_basename()

			if (file == "at_ease" or file == "gatherings") and _his(conv, name, cast, sheet):
				count += 1

		if count < 2:
			thin.append("%s %d" % [name, count])

	_check("T37 every man of the showcase is named or tied into at least two conversations of his own", thin.is_empty(), str(thin))


## The showcase's twelve, as the talk sees them, at `place`, with every
## state a requirement might ask for.
func _showcase_men(cast: Array, sheet: Dictionary, place: StringName) -> Array:
	var men := []

	for entry in cast:
		var man := TalkFacts.sheet_man(entry[0], sheet, entry[2], entry[1])
		man["station"] = place
		man["states"] = {"tired": 0.7, "hungry": 0.7, "cold": 0.7, "hurt": 0.7, "grieving": true, "afraid": true, "asleep": false}
		men.append(man)

	return men


## `name` can take a part of `conv` that asks for more than anyone.
func _his(conv: Dictionary, name: String, cast: Array, sheet: Dictionary) -> bool:
	var men := _showcase_men(cast, sheet, StringName(conv["place"]))

	for part in conv["cast"]:
		if (part["reqs"] as Array).all(func(r): return r == ["any"]):
			continue

		var key: String = part["key"]
		var only := func(m: Dictionary, p: String) -> bool: return (m["name"] == name) == (p == key)

		if not TalkFacts.cast_parts(conv, men, {}, only).is_empty():
			return true

	return false


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
# Memory, late joiners, remarks
# ---------------------------------------------------------------------------

func _memory() -> void:
	# T16 a conversation waits out its cooldown, whoever would play it
	await _fresh()
	_use(["cool_a"])
	var director: RefCounted = TalkDirector.of(self)
	var p1 := [_guard(Vector3(0, 0, 10), -PI * 0.5), _guard(Vector3(2.6, 0, 10), PI * 0.5)]
	var p2 := [_guard(Vector3(14, 0, 10), -PI * 0.5), _guard(Vector3(16.6, 0, 10), PI * 0.5)]
	await _until(func(): return director.played().size() >= 1, 900)
	var first_at: float = director.clock
	var early := [false]
	await _until(func():
		if director.clock - first_at < 55.0 and director.played().size() >= 2:
			early[0] = true
		for g in p1 + p2:
			if not g._life.talking():
				g._life._talk_rest = 0.0
		return director.clock - first_at >= 75.0, 75 * 60 + 60)
	_check("T16 a conversation waits out its cooldown before anyone plays it again, then plays",
		not early[0] and director.played().size() >= 2, "played %s, early %s" % [director.played(), early[0]])

	# T17 once a night
	await _fresh()
	_use(["once_conv", "plain", "plain2"])
	director = TalkDirector.of(self)
	var p17 := [_guard(Vector3(30, 0, 10), -PI * 0.5), _guard(Vector3(32.6, 0, 10), PI * 0.5)]
	await _rested_for(p17, 180.0)
	var onces: int = director.played().filter(func(id): return id == "once_conv").size()
	_check("T17 a conversation marked once is played once a night", onces == 1 and director.played().size() >= 3, "played %s" % [director.played()])

	# T18 a group used up before any repeats
	await _fresh()
	_use(["g1", "g2", "g3"])
	director = TalkDirector.of(self)
	var p18 := [_guard(Vector3(44, 0, 10), -PI * 0.5), _guard(Vector3(46.6, 0, 10), PI * 0.5)]
	await _until(func():
		for g in p18:
			if not g._life.talking():
				g._life._talk_rest = 0.0
		return director.played().size() >= 3, 3600)
	var three: Array = director.played().slice(0, 3)
	_check("T18 every conversation of a group is played before any is played again",
		three.size() == 3 and three.has("g1") and three.has("g2") and three.has("g3"), "played %s" % [director.played()])

	# T19 no man says the same line twice
	await _fresh()
	_use(["cold_1", "cold_2"])
	director = TalkDirector.of(self)
	var frost := _guard(Vector3(58, 0, 10), -PI * 0.5, &"steady", "Frost")
	var p19 := [frost, _guard(Vector3(60.6, 0, 10), PI * 0.5)]
	await _rested_for(p19, 120.0)
	var colds: int = _barks_of(frost).filter(func(t): return t == "Cold again.").size()
	_check("T19 no man says the same line twice in a night", colds == 1, "Frost said %s" % [_barks_of(frost)])

	# T20 a turn said his way
	await _fresh()
	_use(["temper_check"])
	director = TalkDirector.of(self)
	var steady := _guard(Vector3(72, 0, 10), -PI * 0.5)
	var rash := _guard(Vector3(74.6, 0, 10), PI * 0.5, &"rash")
	var steady2 := _guard(Vector3(72, 0, 16), -PI * 0.5)
	var steady3 := _guard(Vector3(74.6, 0, 16), PI * 0.5)
	for g in [steady, rash, steady2, steady3]:
		g._life._talk_rest = 99.0
	var started: bool = director.play("temper_check", {"A": steady, "B": rash}) and director.play("temper_check", {"A": steady2, "B": steady3})
	await _until(func(): return _barks_of(rash).size() >= 1 and _barks_of(steady3).size() >= 1, 900)
	_check("T20 a turn with an {if} is said the way that fits the man", started and _barks_of(rash).has("I'll gut him.") and _barks_of(steady3).has("Let it be."),
		"rash said %s, steady said %s" % [_barks_of(rash), _barks_of(steady3)])

	# T21 a man who walks up takes the empty part
	await _fresh()
	_use(["join_me"])
	director = TalkDirector.of(self)
	var a21 := _guard(Vector3(86, 0, 10), -PI * 0.5)
	var b21 := _guard(Vector3(88.6, 0, 10), PI * 0.5)
	var c21 := _guard(Vector3(87.3, 0, 20), PI)
	c21._life._talk_rest = 99.0
	await _until(func(): return director.in_talk(a21), 900)
	c21._life._talk_rest = 0.0
	c21._home = Transform3D(c21._home.basis, Vector3(87.3, 0, 11.9))
	await _until(func(): return _barks_of(c21).has("I'm here now.") or not director.in_talk(a21), 2400)
	_check("T21 a man who walks up to a conversation with an empty part takes it", _barks_of(c21).has("I'm here now."),
		"said %s" % [_said.map(func(e): return e[1])])

	# T22 a man alone says something to himself, now and then
	await _fresh()
	_use(["chop_curse_1", "chop_curse_2", "muse_1", "muse_2"])
	director = TalkDirector.of(self)
	var block: Node3D = GuardStationScript.new()
	block.kind = &"chop"
	add_child(block)
	block.global_position = Vector3(100, 0, 10)
	var chopper := _guard(Vector3(100, 0, 11), 0.0, &"steady", "", &"", [block])
	var loner_a := _guard(Vector3(120, 0, 10), 0.0)
	var loner_b := _guard(Vector3(130, 0, 10), 0.0)
	await _frames(100 * 60)
	var his: Array = director.remarks().filter(func(r): return r["man"] == chopper)
	var spaced := true

	for i in range(1, his.size()):
		if float(his[i]["at"]) - float(his[i - 1]["at"]) < TalkDirector.SOLO_GAP - 0.1:
			spaced = false

	var chop_first: bool = not his.is_empty() and String(his[0]["id"]).begins_with("chop_curse") and float(his[0]["at"]) < 60.0
	var pair: Array = director.remarks().filter(func(r): return r["man"] == loner_a or r["man"] == loner_b)
	var quiet := true

	for i in range(1, pair.size()):
		if pair[i]["man"] != pair[i - 1]["man"] and float(pair[i]["at"]) - float(pair[i - 1]["at"]) < TalkDirector.SOLO_QUIET - 0.1:
			quiet = false

	_check("T22 a man alone at his station says a remark of that station, not too often, and two within earshot never speak on each other",
		chop_first and spaced and his.size() >= 2 and pair.size() >= 2 and quiet,
		"chopper %s, loners %s" % [his.map(func(r): return "%s@%.0f" % [r["id"], r["at"]]), pair.map(func(r): return "%s@%.0f" % [r["id"], r["at"]])])


# ---------------------------------------------------------------------------
# The voice
# ---------------------------------------------------------------------------

func _voice() -> void:
	# T23 the heart: up in a fight, down after
	await _fresh()
	_use([])
	var fighter := _guard(Vector3(150, 0, 0), 0.0)
	player.debug_light_level = 1.0
	player.global_position = Vector3(150, 1.05, -6)
	fighter._engage(player)
	await _frames(600)
	var in_fight: float = fighter._voice.heart
	player.debug_light_level = 0.0
	player.global_position = Vector3(150, 1.05, 28)
	fighter._give_up()
	await _frames(2400)
	var after: float = fighter._voice.heart
	_check("T23 a man's heart races in a fight and eases after it", in_fight >= 120.0 and after <= 95.0,
		"in the fight %.0f bpm, 40 s after %.0f bpm (state %d)" % [in_fight, after, fighter.state])

	# T24 the ladder: pain cuts chatter; then quiet
	await _fresh()
	_use([])
	var man := _guard(Vector3(160, 0, 0), 0.0)
	man._life._talk_rest = 99.0
	var chatting: bool = man._voice.utter(GuardVoiceScript.CHATTER, "Cold tonight.", &"")
	var murmured: bool = man._voice.murmuring()
	man._voice.cry(&"pain")
	var pained: bool = man._voice.sounding() == GuardVoiceScript.PAIN and not man._voice.murmuring()
	await _frames(60)
	_check("T24 a cry of pain stops his chatter, and passes", chatting and murmured and pained and man._voice.sounding() < GuardVoiceScript.CALL,
		"chatting %s murmured %s pained %s, after %d" % [chatting, murmured, pained, man._voice.sounding()])

	# T25 chatter never talks over a call
	var called: bool = man._voice.utter(GuardVoiceScript.CALL, "Over here!", &"")
	var chat_over: bool = man._voice.utter(GuardVoiceScript.CHATTER, "Anyway...", &"")
	_check("T25 chatter never talks over a call-out", called and not chat_over, "call %s, chatter over it %s" % [called, chat_over])

	# T26 breathing: heard when his heart races, in time with his breath
	await _fresh()
	_use([])
	var breather := _guard(Vector3(170, 0, 0), 0.0)
	breather._life._talk_rest = 99.0
	breather._voice.hold_heart(72.0)
	Sfx.recording = true
	Sfx.recorded.clear()
	await _frames(600)
	var calm_breaths := Sfx.recorded.filter(func(r): return r[0] == &"breath_heavy" or r[0] == &"breath_scared").size()
	breather._voice.hold_heart(150.0)
	Sfx.recorded.clear()
	var rises: Array = []
	var was_out := [breather._voice.out_breath()]
	await _until(func():
		var now_out: bool = breather._voice.out_breath()
		if now_out and not was_out[0]:
			rises.append(breather._voice.clock)
		was_out[0] = now_out
		return false, 600)
	var hard_breaths := Sfx.recorded.filter(func(r): return r[0] == &"breath_heavy" or r[0] == &"breath_scared").size()
	Sfx.recording = false
	var period := (float(rises[-1]) - float(rises[0])) / float(rises.size() - 1) if rises.size() >= 2 else 0.0
	var expected: float = 1.0 / breather._voice.breath_rate()
	_check("T26 at rest his breath is silent; racing, he is heard breathing, in time with his breath",
		calm_breaths == 0 and hard_breaths >= 3 and absf(period - expected) <= expected * 0.1,
		"calm %d, racing %d, a breath every %.2f s (expected %.2f)" % [calm_breaths, hard_breaths, period, expected])
	breather._voice.hold_heart(-1.0)

	# T27 a line's murmur: a whisper is quieter than a shout
	await _fresh()
	_use([])
	var speaker := _guard(Vector3(180, 0, 0), 0.0)
	speaker._life._talk_rest = 99.0
	Sfx.recording = true
	Sfx.recorded.clear()
	speaker.speak("Hush now.", &"whisper")
	await _frames(150)
	speaker.speak("Get over here!", &"shout")
	var murmurs := Sfx.recorded.filter(func(r): return r[0] == &"murmur")
	Sfx.recording = false
	_check("T27 each line is murmured, a whisper well under a shout",
		murmurs.size() == 2 and float(murmurs[0][1]) <= float(murmurs[1][1]) - 12.0, "murmurs %s" % [murmurs])


# ---------------------------------------------------------------------------
# In the fight, and grief
# ---------------------------------------------------------------------------

func _fight_talk() -> void:
	var lib: Dictionary = TalkScript.library()

	# T28 a status check, answered by the man hurt
	await _fresh()
	_use_files()
	var leader := _guard(Vector3(190, 0, 0), 0.0, &"steady", "", &"swordsman")
	var cut := _guard(Vector3(192.5, 0, 0), 0.0)
	player.debug_light_level = 1.0
	player.global_position = Vector3(191, 1.05, -7)
	for g in [leader, cut]:
		g._engage(player)
	await _frames(30)
	cut.health = cut.max_health * 0.5
	var director: RefCounted = TalkDirector.of(self)
	var asked: bool = director.call_pair(&"status", leader)
	var answers := _choices_of(lib, "status_check", "B")
	await _until(func(): return _barks_of(cut).any(func(t): return answers.has(t)), 300)
	var answered: bool = _barks_of(cut).any(func(t): return answers.has(t))
	var order_ok := false

	for i in _said.size():
		if _said[i][0] == cut and answers.has(_said[i][1]):
			order_ok = _said.slice(0, i).any(func(e): return e[0] == leader)
			break

	_check("T28 in the fight a man asks another if he stands, and the man hurt answers in his own way", asked and answered and order_ok,
		"asked %s, answered %s after %s (%s)" % [asked, answered, order_ok, _said.map(func(e): return e[1])])

	# T29 no pair when nobody can answer
	await _fresh()
	_use_files()
	var alone := _guard(Vector3(200, 0, 0), 0.0, &"steady", "", &"swordsman")
	var far := _guard(Vector3(200, 0, 45), 0.0)
	alone._engage(player)
	far._engage(player)
	far.health = far.max_health * 0.4
	await _frames(10)
	director = TalkDirector.of(self)
	var none: bool = not director.call_pair(&"status", alone)
	_check("T29 a call waits for an answer only from a man who can give one: none in earshot, no pair", none, "pair started %s" % [not none])
	player.debug_light_level = 0.0
	player.global_position = Vector3(100, 1.05, 28)

	# T30 grief by name
	await _fresh()
	_use_files()
	var osric := _guard(Vector3(210, 0, 0), 0.0, &"steady", "Osric", &"swordsman")
	var jory := _guard(Vector3(210, 0, -6), PI, &"steady", "Jory")
	osric._life._talk_rest = 99.0
	jory._life._talk_rest = 99.0
	await _frames(20)
	jory.die(player)
	await _until(func(): return _barks_of(osric).any(func(t): return String(t).contains("Jory")), 240)
	_check("T30 a man who sees his brother die calls his name, and grieves",
		_barks_of(osric).any(func(t): return String(t).contains("Jory")) and float(osric.grief) >= 0.9, "Osric said %s, grief %.2f" % [_barks_of(osric), osric.grief])

	# T31 grief breaks a craven man and enrages a rash one
	await _fresh()
	_use_files()
	player.debug_light_level = 1.0
	player.global_position = Vector3(221, 1.05, -8)
	# The two craven men stand alike to everyone but the dead man's tie.
	var piers := _guard(Vector3(218, 0, 0), 0.0, &"craven", "Piers")
	var other := _guard(Vector3(222, 0, 0), 0.0, &"craven", "Gideon")
	var col := _guard(Vector3(220, 0, -3), 0.0, &"steady", "Col")
	var brother := _guard(Vector3(220, 0, 4), 0.0, &"rash", "Osric", &"swordsman")
	var kin := _guard(Vector3(220, 0, 6), 0.0, &"steady", "Jory")
	for g in [piers, other, col, brother, kin]:
		g._engage(player)
	await _frames(60)
	var squad: RefCounted = SquadScript.of(player)
	var before := [squad.resolve_of(piers), squad.resolve_of(other)]
	col.die(player)
	kin.die(player)
	await _frames(40)
	# Both lost the same men; only Piers lost his friend.
	var shaken: float = (float(before[0]) - squad.resolve_of(piers)) - (float(before[1]) - squad.resolve_of(other))
	_check("T31 grief breaks a craven man's heart and enrages a rash one",
		squad.will_of(piers) == &"broken" and squad.will_of(other) != &"broken" and shaken > 0.1 and brother._fighter.mood == &"enraged", "Piers %.2f -> %.2f (%s), Gideon %.2f -> %.2f (%s), grief's share %.2f, Osric's mood %s" % [before[0], squad.resolve_of(piers), squad.will_of(piers), before[1], squad.resolve_of(other), squad.will_of(other), shaken, brother._fighter.mood])
	player.debug_light_level = 0.0
	player.global_position = Vector3(100, 1.05, 28)

	# T32 a man missing from his post, called by name
	await _fresh()
	_use_files()
	var looker := _guard(Vector3(230, 0, 0), 0.0)
	looker._life._talk_rest = 99.0
	await _frames(10)
	GarrisonScript.of(player).post_fell(Vector3(230, 0, -3.5), "Hendrik", Comms.now())
	await _until(func(): return _barks_of(looker).any(func(t): return String(t).contains("Hendrik")), 600)
	_check("T32 a man who finds a post empty calls the missing man by name", _barks_of(looker).any(func(t): return String(t).contains("Hendrik")),
		"said %s" % [_barks_of(looker)])

	# T33 the lookout sends a man, and he answers
	await _fresh()
	_use_files()
	var watcher := _guard(Vector3(240, 0, 0), 0.0)
	watcher.lookout = true
	var sent := _guard(Vector3(244, 0, 3), 0.0)
	sent._life._talk_rest = 99.0
	await _frames(10)
	watcher._send_to_look(Vector3(244, 0, -10))
	var replies := _choices_of(lib, "send_look", "B")
	await _until(func(): return _barks_of(sent).any(func(t): return replies.has(t)), 240)
	_check("T33 the lookout sends a man by name to look, and he answers in his own way", _barks_of(sent).any(func(t): return replies.has(t)),
		"lookout said %s, the man said %s" % [_barks_of(watcher), _barks_of(sent)])


# ---------------------------------------------------------------------------
# The final review's findings
# ---------------------------------------------------------------------------

func _review_fixes() -> void:
	var lib: Dictionary = TalkScript.library()

	# T38 after a death, what is on their minds comes before the light talk
	await _fresh()
	_use_files()
	GarrisonScript.of(player).on_death(false, "Jory")
	var hendrik := _guard(Vector3(250, 0, 0), -PI * 0.5, &"steady", "Hendrik")
	var ned := _guard(Vector3(252.6, 0, 0), PI * 0.5, &"steady", "Ned")
	var director: RefCounted = TalkDirector.of(self)
	await _until(func(): return not director.played().is_empty(), 900)
	var first38: String = director.played()[0] if not director.played().is_empty() else ""
	var from38 := _file_of(lib, first38)
	_check("T38 after a death, two men at their ease talk of it before anything light", from38 == "unease" or from38 == "fear",
		"first talk %s (from %s)" % [first38, from38])

	# T38b afraid men are not at their ease
	await _fresh()
	_use_files()
	GarrisonScript.of(player).dread = 0.8
	var shaky_a := _guard(Vector3(230, 0, 12), -PI * 0.5, &"craven")
	var shaky_b := _guard(Vector3(232.6, 0, 12), PI * 0.5, &"craven")
	director = TalkDirector.of(self)
	await _until(func(): return not director.played().is_empty(), 900)
	var first38b: String = director.played()[0] if not director.played().is_empty() else ""
	var eased := false

	for c in lib["conversations"]:
		if c["id"] == first38b:
			eased = (c["when"] as Array).any(func(t): return (t as Array).has("at_ease"))

	var world38b := TalkFacts.world([shaky_a, shaky_b], get_tree(), {})
	_check("T38b men afraid are not at their ease: none of the at-ease talk", first38b != "" and not eased and not bool(world38b["at_ease"]),
		"first talk %s; states %d/%d alert %.1f/%.1f resting %.1f/%.1f rest %.1f/%.1f remarks %d" % [first38b, shaky_a.state, shaky_b.state, shaky_a.alert, shaky_b.alert, shaky_a._life._resting, shaky_b._life._resting, shaky_a._life._talk_rest, shaky_b._life._talk_rest, director.remarks().size()])

	# T39 the file checks catch what would silently never play
	var bad := TalkScript.load_text_for_test("""== t1
when: asleep(Tom)
cast: A = name(Tomas)
A: Hm.

== t2
place: dcie
cast: A = any; A = any
again: maybe
A: {C} and {dead} and {plase}.

== t3
when: situation:lunch
cast: A = any
A: Hm.
""", "typos.talk")
	var errs: String = "\n".join(bad["errors"])
	var caught := ["typos.talk:2:", "typos.talk:3:", "typos.talk:7:", "typos.talk:8:", "typos.talk:9:", "typos.talk:10:", "typos.talk:13:"].filter(func(at): return not errs.contains(at))
	_check("T39 a name nobody has, a place nobody gathers, a doubled part, a bad 'again', an unknown placeholder or situation is an error with its line",
		caught.is_empty(), "missed %s in %s" % [caught, errs])

	# T40 nobody speaks of himself by name as another man
	var smell: Dictionary = {}

	for c in lib["conversations"]:
		if c["id"] == "canal_smell":
			smell = c

	var sheet: Dictionary = lib["cast"]
	var only := [TalkFacts.sheet_man("Brand", sheet, &"rash", &"brute"), TalkFacts.sheet_man("Wat", sheet, &"sly", &"archer")]
	var cast40 := TalkFacts.cast_parts(smell, only, {"present": ["Brand", "Wat"], "at_ease": true})
	_check("T40 Brand is never the man who says 'that's Brand's boots'", not smell.is_empty() and not cast40.values().any(func(m): return m["name"] == "Brand"),
		"cast %s" % [cast40.keys().map(func(k): return "%s=%s" % [k, cast40[k]["name"]])])

	# T41 a man muttering to himself is not booked into a talk as well
	await _fresh()
	_use(["muse_1", "talk_pair"])
	director = TalkDirector.of(self)
	var mutterer := _guard(Vector3(180, 0, 20), 0.0)
	var other41 := _guard(Vector3(205, 0, 20), 0.0)
	await _until(func(): return director.remarks().any(func(r): return r["man"] == mutterer) and director.speaking(mutterer), 3600)
	var muttering: bool = director.speaking(mutterer)
	var booked: bool = director.play("talk_pair", {"A": mutterer, "B": other41})
	_check("T41 a man in the middle of a remark cannot be booked into a conversation too", muttering and not booked, "muttering %s, booked %s" % [muttering, booked])

	# T42 a new level (the scene reloaded) starts with a fresh director
	await _fresh()
	var before42: RefCounted = TalkDirector.of(self)
	var elsewhere := Node.new()
	get_tree().root.add_child(elsewhere)
	get_tree().current_scene = elsewhere
	var after42: RefCounted = TalkDirector.of(self)
	get_tree().current_scene = self
	var back42: RefCounted = TalkDirector.of(self)
	elsewhere.queue_free()
	_check("T42 the director belongs to the level: a reloaded scene gets its own", before42 != after42 and back42 == before42,
		"new level new director %s, same level same %s" % [before42 != after42, back42 == before42])

	# T43 a man nodded off in his seat (GuardHabits) is asleep: no remark to
	# himself, nobody draws him into a talk
	await _fresh()
	_use(["muse_1", "talk_pair"])
	director = TalkDirector.of(self)
	var dozer := _guard(Vector3(230, 0, 20), 0.0)
	var awake43 := _guard(Vector3(231.5, 0, 20), PI)
	dozer._habits._dozing = true
	dozer._habits._doze_left = 9999.0
	dozer._life._talk_rest = 0.0
	awake43._life._talk_rest = 0.0
	var asleep43: bool = TalkFacts.man(dozer, {})["states"]["asleep"]
	var spoke43 := [false]
	await _until(func():
		spoke43[0] = spoke43[0] or director.speaking(dozer) or director.in_talk(dozer)
		return false, 60 * 60)
	_check("T43 a man dozing in his seat is asleep: he says nothing to himself and is drawn into no talk",
		asleep43 and not spoke43[0] and not director.remarks().any(func(r): return r["man"] == dozer),
		"asleep %s, spoke %s, remarks %s" % [asleep43, spoke43[0], director.remarks().map(func(r): return r["id"])])

	# T49 a remark to himself is no conversation: it leaves him no rest after
	# it, and he talks with the next man to stand by him
	await _fresh()
	_use(["muse_1", "talk_pair"])
	director = TalkDirector.of(self)
	var loner := _guard(Vector3(150, 0, -20), 0.0)
	director._solo_next[loner.get_instance_id()] = 0.0
	await _until(func(): return director.remarks().any(func(r): return r["man"] == loner), 60 * 5)
	var remarked49: bool = director.remarks().any(func(r): return r["man"] == loner)
	await _until(func(): return not director.speaking(loner) and director.talks().is_empty(), 60 * 10)
	var rest49: float = loner._life._talk_rest
	var comer := _guard(Vector3(152.6, 0, -20), PI * 0.5)
	await _until(func(): return director.in_talk(loner) and director.in_talk(comer), 60 * 6)
	var talked49: bool = director.in_talk(loner) and director.in_talk(comer)
	_check("T49 a remark to himself is no conversation: no rest after it, and he talks with the next man to stand by him",
		remarked49 and rest49 == 0.0 and talked49,
		"remarked %s, rest after it %.1f s, talking with the next man %s" % [remarked49, rest49, talked49])


## The file a conversation comes from ("at_ease", "unease"...).
func _file_of(lib: Dictionary, id: String) -> String:
	for c in lib["conversations"]:
		if c["id"] == id:
			return String(c["source"]).get_file().get_slice(":", 0).get_basename()

	return ""


## The files' conversations for the director (not the fixtures).
func _use_files() -> void:
	TalkDirector.of(self).use_library({})


## Every way part `part` of conversation `id` may say its lines.
func _choices_of(lib: Dictionary, id: String, part: String) -> Array:
	var texts := []

	for c in lib["conversations"]:
		if c["id"] == id:
			for turn in c["lines"]:
				if turn["part"] == part:
					for choice in turn["choices"]:
						texts.append(String(choice["text"]))

	return texts


## `seconds` of the director's time, the men's rest cut short after each
## conversation (so they talk as often as they may).
func _rested_for(men: Array, seconds: float) -> void:
	var director: RefCounted = TalkDirector.of(self)
	var until: float = director.clock + seconds
	await _until(func():
		for g in men:
			if is_instance_valid(g) and not g._life.talking():
				g._life._talk_rest = 0.0
		return director.clock >= until, int(seconds * 60) + 60)


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


func _guard(at: Vector3, yaw := 0.0, preset: StringName = &"steady", name := "", archetype: StringName = &"", stations := []) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype

	if not stations.is_empty():
		var paths: Array[NodePath] = []

		for station in stations:
			paths.append((station as Node).get_path())

		g.stations = paths

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

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"stray_arrows", &"guard_stations"]:
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
