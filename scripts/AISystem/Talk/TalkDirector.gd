extends RefCounted
## Who talks to whom, and what they say: one for each scene tree (`of`),
## ticked by every guard's GuardLife and working once a frame whoever calls.
##
## Every CHOOSE_EVERY seconds it looks for men at their ease near each other
## (standing a while, sitting, eating, leaning), in sight of each other: a
## group. For a group it finds every written conversation (TalkScript) whose
## conditions hold and whose parts can be cast from the group (TalkFacts),
## and plays the most specific (ties by chance), never the one these same
## men played last.
##
## Playing: one man speaks at a time. A line lasts LINE_BASE + LINE_PER_CHAR
## a letter (a whisper a little longer, a shout shorter), then a pause.
## Before each line its conditions are read again; a man stirred, gone, or
## walked off breaks it off: whoever was to speak next says the
## conversation's interrupt line, if it has one for him, and everyone goes
## back to what he was doing. A man calling out (Guard.bark) leaves it.
##
## Each line comes out of the man's mouth as Guard.speak (the subtitle, his
## murmur) and his emotes as Guard.emote (a gesture, a laugh).
##
## It remembers: a conversation waits out its cooldown (or is once a
## night); every conversation of a group is played before any again; no man
## says the same line twice in a night (unless it is marked `again`); two
## men do not air the same topic twice. A man who walks up to a conversation
## with an empty part that fits him takes it. A man alone says something to
## himself now and then (a remark: a conversation of one part, fitting his
## station), never on top of another within earshot.

const TalkScript := preload("res://scripts/AISystem/Talk/TalkScript.gd")
const TalkFacts := preload("res://scripts/AISystem/Talk/TalkFacts.gd")
const GuardLifeScript := preload("res://scripts/AISystem/GuardLife.gd")

## The things they do together (reached at run time: it reads this script).
const GATHERING := "res://scripts/AISystem/Gathering.gd"

## How often it looks for men to talk; within how far of each other, and how
## many at most to a conversation.
const CHOOSE_EVERY := 2.0
const TALK_RANGE := 3.8
const GROUP_MAX := 4
## A line's length (s): a base, and so much a letter; a whisper slower, a
## shout quicker. Then a pause.
const LINE_BASE := 0.9
const LINE_PER_CHAR := 0.055
const WHISPER_SLOW := 1.15
const SHOUT_FAST := 0.85
const PAUSE := Vector2(0.4, 0.9)
## After a conversation, this long before either man talks again (s).
const TALK_REST := Vector2(20.0, 45.0)
## Further than this from the rest, a man has left the conversation.
const LEAVE_RANGE := 2.0 * TALK_RANGE
## Emotes that say how a line is said.
const DELIVERIES := {"whispers": &"whisper", "shouts": &"shout", "murmurs": &"murmur"}
## At a station, and still free to talk.
const SEATED := [&"sit", &"sit_talk", &"eat", &"lean"]
## The first line comes this long after a conversation starts.
const OPENING := 0.4
## Remarks: this long between a man's (the first after SOLO_FIRST); none
## within SOLO_EARSHOT of another said less than SOLO_QUIET ago.
const SOLO_GAP := 40.0
const SOLO_FIRST := Vector2(5.0, 40.0)
const SOLO_EARSHOT := 15.0
const SOLO_QUIET := 8.0
## How often it looks for men to join conversations with an empty part.
const JOIN_EVERY := 0.5
## At the end of a line one man listening may nod or shake his head: the
## chance, by his temperament (a nod, but a rash man shakes his).
const REACT_CHANCE := {&"steady": 0.35, &"stubborn": 0.35, &"rash": 0.25}
const REACT_OTHERWISE := 0.15
const REACTIONS := ["nods", "shakes"]

static var _directors := {}
static var _gathering_script: GDScript = null

## Its own time: game seconds since it was made.
var clock := 0.0
var _tree: WeakRef
var _frame := -1
var _choose_in := 0.0
var _library: Dictionary = {}
## The conversations going on: {conv, id, cast {part: man}, members, turn,
## timer, speaker, speaking_until, started_at, place, extra}.
var _talks: Array = []
var _played: Array[String] = []
## By the set of men: the conversation they played last.
var _last_for := {}
## By man (instance id): what he has said tonight, and when he last spoke.
var _lines := {}
var _last_spoke := {}
## Memory: when each conversation was last started; those played once; for
## each group, those played since it was last used up; for each pair of men,
## the topics they have aired.
var _played_at := {}
var _once := {}
var _group_used := {}
var _aired := {}
## Remarks: [{id, man, at, where}], and when each man may make his next.
var _remarks: Array = []
var _solo_next := {}
var _join_in := 0.0


## The director for `node`'s tree (made the first time it is asked for).
static func of(node: Node) -> RefCounted:
	var tree := node.get_tree() if node != null and node.is_inside_tree() else null

	if tree == null:
		return null

	var key := tree.get_instance_id()
	var director: RefCounted = _directors.get(key)

	if director == null:
		director = (load("res://scripts/AISystem/Talk/TalkDirector.gd") as GDScript).new()
		director._tree = weakref(tree)
		director._choose_in = randf() * CHOOSE_EVERY
		_directors[key] = director

	return director


## Forget every conversation (a new level, a test).
static func clear_all() -> void:
	_directors.clear()


## The conversations to choose from: `lib` (TalkScript's shape) instead of
## the files; {} for the files again.
func use_library(lib: Dictionary) -> void:
	_library = lib


## Once a physics frame, whoever calls first.
func tick(delta: float) -> void:
	var frame := Engine.get_physics_frames()

	if frame == _frame:
		return

	_frame = frame
	clock += delta

	for talk in _talks.duplicate():
		if _talks.has(talk):
			_advance(talk, delta)

	_join_in -= delta

	if _join_in <= 0.0:
		_join_in = JOIN_EVERY
		_join()

	_choose_in -= delta

	if _choose_in <= 0.0:
		_choose_in = CHOOSE_EVERY
		_choose()


# ---------------------------------------------------------------------------
# Asking
# ---------------------------------------------------------------------------

## In a conversation (a remark to himself is not one).
func in_talk(man: Node) -> bool:
	var talk := _talk_of(man)
	return not talk.is_empty() and not bool(talk["solo"])


## His line is being said now.
func speaking(man: Node) -> bool:
	var talk := _talk_of(man)
	return not talk.is_empty() and talk["speaker"] == man and clock < float(talk["speaking_until"])


## Whom he should face: the man who spoke last in his conversation, or (while
## he speaks himself, or before anyone has) the one most in front of him.
func speaker_near(man: Node) -> Variant:
	var talk := _talk_of(man)

	if talk.is_empty():
		return null

	var last: Variant = talk["speaker"]

	if last != null and last != man and is_instance_valid(last):
		return last

	var best: Variant = null
	var best_dot := -INF

	for other in talk["members"]:
		if other == man or not is_instance_valid(other):
			continue

		var to: Vector3 = (other as Node3D).global_position - (man as Node3D).global_position
		to.y = 0.0
		var dot := (-(man as Node3D).global_basis.z).dot(to.normalized()) if to.length() > 0.01 else 0.0

		if dot > best_dot:
			best_dot = dot
			best = other

	return best


## He leaves his conversation: broken off (its interrupt line) or quietly.
func leave(man: Node, interrupted := true) -> void:
	var talk := _talk_of(man)

	if talk.is_empty():
		return

	if interrupted:
		_interrupt(talk)
	else:
		_end(talk)


## Starts the conversation `conv_id` with these men ({part: man}) now. False
## if there is no such conversation, or a man is not free for it.
func play(conv_id: String, cast: Dictionary, extra := {}) -> bool:
	var conv := _find(conv_id)

	if conv.is_empty():
		return false

	for key in cast:
		var man: Variant = cast[key]

		if man == null or not is_instance_valid(man) or in_talk(man):
			return false

	_start(conv, cast, extra)
	return true


## A conversation belonging to `place` (a gathering: "dice", "story"...),
## cast from exactly these men, now. False if none fits.
func play_place(members: Array, place: StringName) -> bool:
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null
	var here := members.filter(func(m): return m != null and is_instance_valid(m) and _talk_of(m).is_empty())

	if tree == null or here.size() < members.size():
		return false

	here.sort_custom(func(x: Node, y: Node) -> bool:
		return float(_last_spoke.get(x.get_instance_id(), -INF)) < float(_last_spoke.get(y.get_instance_id(), -INF)))
	var sheet: Dictionary = _conversations_lib().get("cast", {})
	var men: Array = here.map(func(g: Node) -> Dictionary: return _facts_of(g, sheet))

	for m in men:
		m["station"] = place

	var world := TalkFacts.world(here, tree, {"place": [place]})
	world["at_ease"] = true
	var candidates := []

	for conv in _conversations_lib().get("conversations", []):
		if StringName(conv["place"]) != place or _required(conv) > here.size():
			continue

		if not _available(conv) or not _when_holds(conv, world):
			continue

		var cast := TalkFacts.cast_parts(conv, men, world, _allowed_for(conv))

		if not cast.is_empty():
			candidates.append({"conv": conv, "cast": cast, "spec": TalkFacts.specificity(conv, cast), "priority": int(conv["priority"])})

	if candidates.is_empty():
		return false

	var best_priority: int = candidates.map(func(c): return int(c["priority"])).max()
	var top := candidates.filter(func(c): return int(c["priority"]) >= best_priority)
	var best_spec: int = top.map(func(c): return int(c["spec"])).max()
	var pick := _weighted(top.filter(func(c): return int(c["spec"]) >= best_spec - 1))
	var nodes := {}

	for part in pick["cast"]:
		nodes[part] = (pick["cast"][part] as Dictionary)["node"]

	_start(pick["conv"], nodes, {"place": [place]})
	return true


## The conversations going on, for tests and the showcase.
func talks() -> Array:
	return _talks.map(func(t: Dictionary) -> Dictionary: return {
		"id": t["id"], "cast": t["cast"], "members": t["members"], "turn": t["turn"],
		"started_at": t["started_at"], "place": t["place"]})


## Every conversation started tonight, in order (remarks are in `remarks`).
func played() -> Array[String]:
	return _played


## Every remark tonight: [{id, man, at}].
func remarks() -> Array:
	return _remarks.map(func(r: Dictionary) -> Dictionary: return {"id": r["id"], "man": r["man"], "at": r["at"]})


## What he has said tonight.
func lines_of(man: Node) -> Array:
	return _lines.get(man.get_instance_id(), [])


# ---------------------------------------------------------------------------
# Choosing
# ---------------------------------------------------------------------------

func _choose() -> void:
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	if tree == null:
		return

	for group in _groups(tree):
		_choose_for(group, tree)

	_remark(tree)


## Men free to talk, in sight and in reach of each other: each group two or
## more, at most GROUP_MAX.
func _groups(tree: SceneTree) -> Array:
	var free: Array = tree.get_nodes_in_group(&"guards").filter(_free)
	var groups := []
	var used := {}

	for man in free:
		if used.has(man):
			continue

		var group := [man]
		used[man] = true
		var i := 0

		while i < group.size():
			var a: Node3D = group[i]

			for b in free:
				if used.has(b):
					continue

				if a.global_position.distance_to((b as Node3D).global_position) <= TALK_RANGE and a._line_of_sight(a.eye_position(), b.eye_position(), b):
					group.append(b)
					used[b] = true

			i += 1

		if group.size() < 2:
			continue

		var first: Vector3 = (group[0] as Node3D).global_position
		group.sort_custom(func(x: Node3D, y: Node3D) -> bool: return x.global_position.distance_to(first) < y.global_position.distance_to(first))
		groups.append(group.slice(0, GROUP_MAX))

	return groups


## Free to join a conversation: at his ease, not set to watch, rested from the
## last one, not asleep, and standing a while or settled at a station.
func _free(man: Node) -> bool:
	if not is_instance_valid(man) or man.is_queued_for_deletion() or man.get("puppet") == true:
		return false

	if not GuardLifeScript.at_ease(man) or bool(man.get("lookout")) or not _talk_of(man).is_empty() or _gathering(man):
		return false

	var life: RefCounted = man.get("_life")

	if life == null or float(life._talk_rest) > 0.0:
		return false

	var rota: RefCounted = man.get("_rota")

	if rota != null and rota.asleep():
		return false

	var doing: StringName = rota.activity() if rota != null else &""
	return float(life._resting) >= 1.0 or SEATED.has(doing)


func _choose_for(group: Array, tree: SceneTree) -> void:
	# The quietest first: they get the parts.
	group.sort_custom(func(x: Node, y: Node) -> bool:
		return float(_last_spoke.get(x.get_instance_id(), -INF)) < float(_last_spoke.get(y.get_instance_id(), -INF)))
	var sheet: Dictionary = _conversations_lib().get("cast", {})
	var men: Array = group.map(func(g: Node) -> Dictionary: return _facts_of(g, sheet))
	var places := []

	for m in men:
		if StringName(m["station"]) != &"":
			places.append(StringName(m["station"]))

	var world := TalkFacts.world(group, tree, {"place": places})
	var candidates := []
	var best_priority := -INF
	var key := _key_of(group)

	for conv in _conversations_lib().get("conversations", []):
		if (conv["cast"] as Array).size() < 2 or _required(conv) > group.size():
			continue

		if StringName(conv["place"]) != &"" and not places.has(StringName(conv["place"])):
			continue

		if conv["id"] == _last_for.get(key, "") or not _available(conv) or not _when_holds(conv, world):
			continue

		var cast := TalkFacts.cast_parts(conv, men, world, _allowed_for(conv))

		if cast.is_empty() or _aired_by(conv, cast):
			continue

		candidates.append({"conv": conv, "cast": cast, "spec": TalkFacts.specificity(conv, cast), "priority": int(conv["priority"])})
		best_priority = maxf(best_priority, float(conv["priority"]))

	if candidates.is_empty():
		return

	candidates = _placed_first(candidates)
	best_priority = candidates.map(func(c): return float(c["priority"])).max()
	var top := candidates.filter(func(c): return float(c["priority"]) >= best_priority)
	var best_spec: int = top.map(func(c): return int(c["spec"])).max()
	var pool := top.filter(func(c): return int(c["spec"]) >= best_spec - 1)
	var pick: Dictionary = _weighted(pool)
	var nodes := {}

	for part in pick["cast"]:
		nodes[part] = (pick["cast"][part] as Dictionary)["node"]

	_start(pick["conv"], nodes, {})


## Whether a conversation may be chosen now: its cooldown waited out (or,
## once a night, not yet played), and its group not waiting to be used up.
func _available(conv: Dictionary) -> bool:
	var id := String(conv["id"])

	if float(conv["cooldown"]) == TalkScript.ONCE:
		if _once.has(id):
			return false
	elif _played_at.has(id) and clock - float(_played_at[id]) < float(conv["cooldown"]):
		return false

	var group := StringName(conv["group"])

	if group == &"":
		return true

	var used: Dictionary = _group_used.get(group, {})

	if not used.has(id):
		return true

	# All of the group played: it starts again.
	var size := (_conversations_lib().get("conversations", []) as Array).filter(func(c): return StringName(c["group"]) == group).size()

	if used.size() >= size:
		used.clear()
		return true

	return false


## Who may take which part: not a man who has said one of its lines tonight
## (unless the conversation says he may).
func _allowed_for(conv: Dictionary) -> Callable:
	if bool(conv["again"]):
		return Callable()

	var texts := {}

	for turn in conv["lines"]:
		for choice in turn["choices"]:
			if not texts.has(turn["part"]):
				texts[turn["part"]] = []

			texts[turn["part"]].append(String(choice["text"]))

	return func(man: Dictionary, part: String) -> bool:
		var node: Variant = man.get("node")

		if node == null or not is_instance_valid(node):
			return true

		var said: Array = _lines.get((node as Node).get_instance_id(), [])
		return not (texts.get(part, []) as Array).any(func(t): return said.has(t))


## These men have aired this topic between them before. Only talk at no
## particular place counts.
func _aired_by(conv: Dictionary, cast: Dictionary) -> bool:
	if StringName(conv["place"]) != &"":
		return false

	var topic := _topic_of(conv)

	for pair in _pairs_of(cast.values().map(func(m): return m.get("node") if m is Dictionary else m)):
		if (_aired.get(pair, {}) as Dictionary).has(topic):
			return true

	return false


## What they talked of: the conversation itself (a group is many topics:
## small talk, dice).
func _topic_of(conv: Dictionary) -> String:
	return String(conv["id"])


## Every pair of these men, as keys.
func _pairs_of(men: Array) -> Array:
	var keys := []
	var valid := men.filter(func(m): return m != null and is_instance_valid(m))

	for i in valid.size():
		for j in range(i + 1, valid.size()):
			keys.append(_key_of([valid[i], valid[j]]))

	return keys


## What belongs where they are comes before what could be said anywhere.
func _placed_first(candidates: Array) -> Array:
	var placed := candidates.filter(func(c): return StringName(c["conv"]["place"]) != &"")
	return placed if not placed.is_empty() else candidates


func _when_holds(conv: Dictionary, world: Dictionary) -> bool:
	for term in conv["when"]:
		if not (term as Array).any(func(alt): return TalkFacts.holds(String(alt), world)):
			return false

	return true


func _required(conv: Dictionary) -> int:
	return (conv["cast"] as Array).filter(func(p): return not bool(p["optional"])).size()


func _weighted(pool: Array) -> Dictionary:
	var total := 0.0

	for c in pool:
		total += 1.0 + float(c["spec"])

	var roll := randf() * total

	for c in pool:
		roll -= 1.0 + float(c["spec"])

		if roll <= 0.0:
			return c

	return pool[-1]


# ---------------------------------------------------------------------------
# Playing
# ---------------------------------------------------------------------------

func _start(conv: Dictionary, cast: Dictionary, extra: Dictionary, solo := false) -> void:
	var members := []

	for part in cast:
		if not members.has(cast[part]):
			members.append(cast[part])

	var id := String(conv["id"])
	_talks.append({
		"conv": conv, "id": id, "cast": cast.duplicate(), "members": members, "turn": 0,
		"timer": OPENING if not solo else 0.0, "speaker": null, "speaking_until": -1.0, "started_at": clock,
		"place": StringName(conv["place"]), "extra": extra.duplicate(), "solo": solo,
	})
	_played_at[id] = clock

	if float(conv["cooldown"]) == TalkScript.ONCE:
		_once[id] = true

	if StringName(conv["group"]) != &"":
		if not _group_used.has(StringName(conv["group"])):
			_group_used[StringName(conv["group"])] = {}

		_group_used[StringName(conv["group"])][id] = true

	if solo:
		return

	_played.append(id)
	_last_for[_key_of(members)] = id

	if StringName(conv["place"]) == &"":
		for pair in _pairs_of(members):
			if not _aired.has(pair):
				_aired[pair] = {}

			_aired[pair][_topic_of(conv)] = true


func _advance(talk: Dictionary, delta: float) -> void:
	for man in talk["members"]:
		if not _can_stay(man, talk):
			_interrupt(talk)
			return

	if not bool(talk.get("reacted", true)) and clock >= float(talk["speaking_until"]):
		talk["reacted"] = true
		_react(talk)

	talk["timer"] = float(talk["timer"]) - delta

	if float(talk["timer"]) > 0.0:
		return

	var turns: Array = talk["conv"]["lines"]

	while int(talk["turn"]) < turns.size():
		var turn: Dictionary = turns[int(talk["turn"])]
		talk["turn"] = int(talk["turn"]) + 1
		var speaker: Variant = talk["cast"].get(turn["part"])

		if speaker == null or not is_instance_valid(speaker):
			continue

		# Before each line: does what it rests on still hold?
		var world := _world_of(talk)

		if not _when_holds(talk["conv"], world):
			talk["turn"] = int(talk["turn"]) - 1
			_interrupt(talk)
			return

		var choice := _choice(turn, speaker, talk, world)

		if choice.is_empty():
			continue

		var length := _say(speaker, choice, talk, world, int(talk.get("pre_emoted", -1)) == int(talk["turn"]) - 1)
		talk["speaker"] = speaker
		talk["reacted"] = false
		talk["speaking_until"] = clock + length
		talk["timer"] = length + randf_range(PAUSE.x, PAUSE.y)
		return

	_end(talk)


## Still part of it: here, at his ease, and near the others.
func _can_stay(man: Variant, talk: Dictionary) -> bool:
	if man == null or not is_instance_valid(man) or (man as Node).is_queued_for_deletion() or man.get("_knocked_out") == true:
		return false

	if not GuardLifeScript.at_ease(man):
		return false

	for other in talk["members"]:
		if other != man and other != null and is_instance_valid(other) and (other as Node3D).global_position.distance_to((man as Node3D).global_position) <= LEAVE_RANGE:
			return true

	return (talk["members"] as Array).size() < 2


## The first way of saying this turn that fits the man; {} if none does.
func _choice(turn: Dictionary, speaker: Node, talk: Dictionary, world: Dictionary) -> Dictionary:
	var sheet: Dictionary = _conversations_lib().get("cast", {})
	var cast_facts := {}

	for part in talk["cast"]:
		var man: Variant = talk["cast"][part]

		if man != null and is_instance_valid(man):
			cast_facts[part] = _facts_of(man, sheet)

	var me := _facts_of(speaker, sheet)

	for choice in turn["choices"]:
		if String(choice["if"]) == "" or TalkFacts.meets(me, String(choice["if"]), cast_facts, world):
			return choice

	return {}


## Says a line: the words, how, and his emotes. Returns how long it lasts.
func _say(speaker: Node, choice: Dictionary, talk: Dictionary, world: Dictionary, nodded := false) -> float:
	var text := _fill(String(choice["text"]), talk, world)
	var delivery: StringName = &""

	for emote in choice["emotes"]:
		if DELIVERIES.has(emote):
			delivery = DELIVERIES[emote]

	if delivery == &"" and bool(talk.get("solo", false)):
		# To himself: under his breath.
		delivery = &"murmur"

	if delivery == &"":
		var voice: Variant = speaker.get("_voice")

		if voice != null and voice.has_method("delivery_for"):
			delivery = voice.delivery_for(&"", bool(world.get("uneasy", false)))

	speaker.speak(text, delivery)

	for emote in choice["emotes"]:
		# A nod he already gave as the last line ended is not given twice.
		if nodded and REACTIONS.has(emote):
			continue

		if not DELIVERIES.has(emote) and speaker.has_method("emote"):
			speaker.emote(String(emote))

	var id := speaker.get_instance_id()

	if not _lines.has(id):
		_lines[id] = []

	_lines[id].append(String(choice["text"]))
	_last_spoke[id] = clock
	var length := LINE_BASE + LINE_PER_CHAR * text.length()

	match delivery:
		&"whisper":
			length *= WHISPER_SLOW
		&"shout":
			length *= SHOUT_FAST

	return length


## Names and places put in: {A}..{D}, {dead} (the one they speak of, or the
## last to die), {missing}, {spared}, {slain}, {place}.
func _fill(text: String, talk: Dictionary, world: Dictionary) -> String:
	for part in talk["cast"]:
		var man: Variant = talk["cast"][part]

		if man != null and is_instance_valid(man):
			text = text.replace("{%s}" % part, String(man.get("given_name")))

	var dead := String(world.get("dead_name", ""))

	if dead == "" and not (world.get("dead_names", []) as Array).is_empty():
		dead = String((world["dead_names"] as Array)[-1])

	text = text.replace("{dead}", dead).replace("{place}", String(world.get("place_name", "")))

	for pair in [["{missing}", "missing"], ["{spared}", "spared_names"], ["{slain}", "slain_names"]]:
		var names: Array = world.get(pair[1], [])

		if text.contains(pair[0]):
			text = text.replace(pair[0], String(names[randi() % names.size()]) if not names.is_empty() else "one of ours")

	return text


## A line has ended: the man who answers next with a nod or a shake of the
## head gives it now, as it ends; else one man listening may, by his
## temperament.
func _react(talk: Dictionary) -> void:
	var turns: Array = talk["conv"]["lines"]
	var index := int(talk["turn"])

	if index < turns.size():
		var next: Dictionary = turns[index]
		var answerer: Variant = talk["cast"].get(next["part"])

		if answerer != null and is_instance_valid(answerer) and answerer != talk["speaker"]:
			for emote in (next["choices"][0] as Dictionary)["emotes"]:
				if REACTIONS.has(emote):
					answerer.emote(String(emote))
					talk["pre_emoted"] = index
					return

	var listeners := (talk["members"] as Array).filter(func(m): return m != talk["speaker"] and m != null and is_instance_valid(m))

	if listeners.is_empty():
		return

	var listener: Node = listeners[randi() % listeners.size()]
	var fighter: RefCounted = listener.get("_fighter")
	var tag: StringName = fighter.temper.tag if fighter != null and fighter.temper != null else &"steady"

	if randf() < float(REACT_CHANCE.get(tag, REACT_OTHERWISE)):
		listener.emote("shakes" if tag == &"rash" else "nods")


## Broken off: whoever was to speak next says its interrupt line (if it has
## one for him), and it is over.
func _interrupt(talk: Dictionary) -> void:
	if not _talks.has(talk):
		return

	# Over before anything else can break it again.
	_talks.erase(talk)
	var next_part := ""
	var turns: Array = talk["conv"]["lines"]

	if int(talk["turn"]) < turns.size():
		next_part = String(turns[int(talk["turn"])]["part"])

	var speaker: Variant = talk["cast"].get(next_part)

	if not _can_speak(speaker):
		speaker = null

		for turn in talk["conv"]["interrupt"]:
			if _can_speak(talk["cast"].get(turn["part"])):
				speaker = talk["cast"][turn["part"]]
				break

	if speaker != null:
		for turn in talk["conv"]["interrupt"]:
			if talk["cast"].get(turn["part"]) == speaker:
				var world := _world_of(talk)
				var choice := _choice(turn, speaker, talk, world)

				if not choice.is_empty():
					_say(speaker, choice, talk, world)

				break

	_talks.append(talk)
	_end(talk)


func _end(talk: Dictionary) -> void:
	_talks.erase(talk)

	for man in talk["members"]:
		if man != null and is_instance_valid(man) and man.get("_life") != null:
			man._life._talk_rest = randf_range(TALK_REST.x, TALK_REST.y)


func _can_speak(man: Variant) -> bool:
	return man != null and is_instance_valid(man) and not (man as Node).is_queued_for_deletion() and man.get("_knocked_out") != true


# ---------------------------------------------------------------------------
# Late joiners and remarks
# ---------------------------------------------------------------------------

## A man free and near a conversation with an empty part he fits: he takes
## it.
func _join() -> void:
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	if tree == null:
		return

	var free: Array = []

	for talk in _talks:
		if bool(talk["solo"]):
			continue

		var empty := (talk["conv"]["cast"] as Array).filter(func(p): return bool(p["optional"]) and not talk["cast"].has(p["key"]))

		if empty.is_empty():
			continue

		if free.is_empty():
			free = tree.get_nodes_in_group(&"guards").filter(_free)

		var sheet: Dictionary = _conversations_lib().get("cast", {})

		for part in empty:
			for man in free:
				if (talk["members"] as Array).has(man) or not _near_any(man, talk["members"]):
					continue

				var cast_facts := {}

				for key in talk["cast"]:
					if is_instance_valid(talk["cast"][key]):
						cast_facts[key] = _facts_of(talk["cast"][key], sheet)

				var me := _facts_of(man, sheet)

				if not TalkFacts._fits(me, part["reqs"], cast_facts, _world_of(talk)):
					continue

				if not _allowed_for(talk["conv"]).is_null() and not _allowed_for(talk["conv"]).call(me, String(part["key"])):
					continue

				talk["cast"][part["key"]] = man
				talk["members"].append(man)
				free.erase(man)
				break


## In one of the things they do together (Gathering): not free for talk
## but its own.
func _gathering(man: Node) -> bool:
	if _gathering_script == null:
		_gathering_script = load(GATHERING)

	var gatherings: RefCounted = _gathering_script.of(man)
	return gatherings != null and not gatherings.member_of(man).is_empty()


func _near_any(man: Node3D, members: Array) -> bool:
	for other in members:
		if other != null and is_instance_valid(other) and (other as Node3D).global_position.distance_to(man.global_position) <= TALK_RANGE:
			return true

	return false


## A man alone, at his ease, his time come: a remark fitting his station (or
## none in particular), unless another has just been made near him.
func _remark(tree: SceneTree) -> void:
	var guards: Array = tree.get_nodes_in_group(&"guards")
	var free: Array = guards.filter(_free)
	var sheet: Dictionary = _conversations_lib().get("cast", {})

	for man in guards:
		if not is_instance_valid(man) or man.get("puppet") == true or not GuardLifeScript.at_ease(man) or not _talk_of(man).is_empty() or _gathering(man):
			continue

		var id: int = man.get_instance_id()

		if not _solo_next.has(id):
			_solo_next[id] = clock + randf_range(SOLO_FIRST.x, SOLO_FIRST.y)

		if clock < float(_solo_next[id]):
			continue

		# Someone to talk to is company, not solitude.
		if free.any(func(other): return other != man and (other as Node3D).global_position.distance_to((man as Node3D).global_position) <= TALK_RANGE):
			continue

		if _remarks.any(func(r): return clock - float(r["at"]) < SOLO_QUIET and (r["where"] as Vector3).distance_to((man as Node3D).global_position) <= SOLO_EARSHOT):
			continue

		var me := _facts_of(man, sheet)
		var world := TalkFacts.world([man], tree, {"place": [me["station"]]})
		var candidates := []

		for conv in _conversations_lib().get("conversations", []):
			if (conv["cast"] as Array).size() != 1:
				continue

			var place := StringName(conv["place"])

			# A sleeper only talks in his sleep.
			if (place != &"" and place != StringName(me["station"])) or (bool(me["states"]["asleep"]) and place != &"sleep"):
				continue

			if not _available(conv) or not _when_holds(conv, world):
				continue

			var cast := TalkFacts.cast_parts(conv, [me], world, _allowed_for(conv))

			if not cast.is_empty():
				candidates.append({"conv": conv, "cast": cast, "spec": TalkFacts.specificity(conv, cast), "priority": int(conv["priority"])})

		if candidates.is_empty():
			continue

		candidates = _placed_first(candidates)
		var best_priority: int = candidates.map(func(c): return int(c["priority"])).max()
		var top := candidates.filter(func(c): return int(c["priority"]) >= best_priority)
		var best_spec: int = top.map(func(c): return int(c["spec"])).max()
		var pick := _weighted(top.filter(func(c): return int(c["spec"]) >= best_spec - 1))
		var part := String((pick["conv"]["cast"] as Array)[0]["key"])
		_start(pick["conv"], {part: man}, {}, true)
		_solo_next[id] = clock + SOLO_GAP
		_remarks.append({"id": String(pick["conv"]["id"]), "man": man, "at": clock, "where": (man as Node3D).global_position})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _talk_of(man: Node) -> Dictionary:
	for talk in _talks:
		if (talk["members"] as Array).has(man):
			return talk

	return {}


func _world_of(talk: Dictionary) -> Dictionary:
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null
	var men := (talk["members"] as Array).filter(func(m): return m != null and is_instance_valid(m))
	var extra: Dictionary = talk["extra"].duplicate()

	if not extra.has("place"):
		extra["place"] = [talk["place"]]

	return TalkFacts.world(men, tree, extra)


func _facts_of(man: Node, sheet: Dictionary) -> Dictionary:
	var facts := TalkFacts.man(man, sheet)
	facts["quiet_for"] = clock - float(_last_spoke.get(man.get_instance_id(), -INF))
	return facts


func _find(conv_id: String) -> Dictionary:
	for conv in _conversations_lib().get("conversations", []):
		if conv["id"] == conv_id:
			return conv

	return {}


func _conversations_lib() -> Dictionary:
	return _library if not _library.is_empty() else TalkScript.library()


## The same men, whatever order.
func _key_of(men: Array) -> String:
	var ids := men.filter(func(m): return m != null and is_instance_valid(m)).map(func(m): return (m as Node).get_instance_id())
	ids.sort()
	return str(ids)
