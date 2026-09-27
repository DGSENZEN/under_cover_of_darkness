extends RefCounted
## What a conversation's conditions read: the night, the garrison, the men
## there. All of it plain data, gathered when a conversation is weighed
## (`world`, `man`) and read by `holds` (a `when:` term) and `meets` (a part's
## requirement, or a line's {if}). Casting (`cast_parts`) and how specific a
## conversation is (`specificity`) work on the same data, so they can be
## checked without anyone in the yard (`sheet_man`).
##
## A man, as the talk sees him:
##   {name, temper, rank, kind, traits, ties, states, station, near,
##    quiet_for, node}
## where `states` is {tired, hungry, cold, hurt (0..1), grieving, afraid,
## asleep (bools)}.

const GuardLifeScript := preload("res://scripts/AISystem/GuardLife.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const Comms := preload("res://scripts/AISystem/Comms.gd")

## Scripts made later in the night's work, reached only if they are there.
const NIGHT_ROTA := "res://scripts/AISystem/NightRota.gd"
const ATMOSPHERE := "res://scripts/Visual/Atmosphere.gd"

## Guard.Alert.
const RELAXED := 0
const SUSPICIOUS := 1
const INVESTIGATING := 2
const SEARCHING := 3
const COMBAT := 4

const TEMPERS := ["rash", "craven", "stubborn", "sly", "steady"]
const STATES := ["tired", "hungry", "cold", "hurt", "grieving", "afraid", "asleep"]
const MEASURED := ["tired", "hungry", "cold", "hurt"]
const TIES := ["kin", "friend", "rival", "owes", "suspects"]
const HOURS := ["early", "middle", "late", "dawn"]
const HABITS := ["turtle", "spam", "kite", "bow", "parry", "dodge"]
## Bare words a `when:` may use, and what can be compared (>=, >, <).
const WHEN_WORDS := ["at_ease", "uneasy", "alarm", "hunt", "combat", "bell_rung", "body_found", "spared", "slain_begging", "cold", "wind",
	"captain_dead", "missing"]
const WHEN_MEASURES := ["alarm", "dead", "dread"]
const WHEN_NAMED := ["dead", "missing", "present", "asleep"]
## A man's rank when the cast sheet does not give one, by his kind.
const RANK_OF_KIND := {&"duelist": 4, &"brute": 3, &"swordsman": 2}
## A fire this near the men counts for them.
const FIRE_NEAR := 15.0
## A habit this strong is talked of.
const HABIT_TALKED := 0.35
## A bell rung this recently still counts.
const BELL_FOR := 600.0
## The dread on his nerve past this, a man is afraid (not at his ease).
const AFRAID_AT := 0.3
## What a fight's call can be about (Squad, Guard: TalkDirector.call_pair).
const SITUATIONS := ["status", "excuse", "spotted_ask", "man_down", "last_man", "send",
	"tactic_envelop", "tactic_press", "tactic_break", "tactic_rush", "tactic_fall_back", "tactic_rout"]


# ---------------------------------------------------------------------------
# Gathering
# ---------------------------------------------------------------------------

## Asleep: on his bed (GuardRota), or nodded off in his seat (GuardHabits).
static func asleep(guard: Node) -> bool:
	var stations: RefCounted = guard.get("_rota")
	var habits: RefCounted = guard.get("_habits")
	return (stations != null and bool(stations.asleep())) or (habits != null and bool(habits.dozing()))


## A man in the yard, as the talk sees him.
static func man(guard: Node, sheet: Dictionary) -> Dictionary:
	var name := String(guard.get("given_name"))
	var fighter: RefCounted = guard.get("_fighter")
	var temper: StringName = fighter.temper.tag if fighter != null and fighter.temper != null else &"steady"
	var facts := sheet_man(name, sheet, temper, StringName(guard.get("archetype")))
	facts["node"] = guard
	var states: Dictionary = facts["states"]
	var rota := _night_rota(guard)

	if rota != null:
		var needs: Dictionary = rota.needs_of(guard)
		states["tired"] = float(needs.get("tired", 0.0))
		states["hungry"] = float(needs.get("hungry", 0.0))
		states["cold"] = float(needs.get("cold", 0.0))

	var most := maxf(float(guard.get("max_health")), 1.0)
	states["hurt"] = clampf(1.0 - float(guard.get("health")) / most, 0.0, 1.0)
	states["grieving"] = float(guard.get("grief") if guard.get("grief") != null else 0.0) > 0.5
	states["asleep"] = asleep(guard)
	var stations: RefCounted = guard.get("_rota")
	var garrison := _garrison(guard.get_tree())

	if garrison != null and fighter != null and fighter.temper != null:
		states["afraid"] = float(garrison.fear_of(float(fighter.temper.nerve))) > AFRAID_AT

	if stations != null:
		var held: Node = stations._held()
		facts["station"] = StringName(held.kind) if held != null else &""

	var near: Array[String] = []

	for mark in guard.get_tree().get_nodes_in_group(&"landmarks"):
		if mark is Node3D and (mark as Node3D).global_position.distance_to((guard as Node3D).global_position) < Comms.LANDMARK_REACH:
			near.append(String(mark.get_meta(&"landmark")) if mark.has_meta(&"landmark") else String(mark.name).to_lower())

	facts["near"] = near
	return facts


## A man known only from the cast sheet (no one in the yard): for checks, and
## the start of `man`.
static func sheet_man(name: String, sheet: Dictionary, temper := &"steady", kind := &"") -> Dictionary:
	var entry: Dictionary = sheet.get(name, {})
	# Unranked on the sheet, a man is ranked by his kind.
	var rank := int(entry.get("rank", 1))

	if rank <= 1:
		rank = int(RANK_OF_KIND.get(kind, 1))

	var ties := {}

	for tie in TIES:
		ties[tie] = (entry.get("ties", {}) as Dictionary).get(tie, []).duplicate()

	return {
		"name": name,
		"temper": temper,
		"rank": rank,
		"kind": kind,
		"traits": (entry.get("traits", []) as Array).duplicate(),
		"ties": ties,
		"states": {"tired": 0.0, "hungry": 0.0, "cold": 0.0, "hurt": 0.0, "grieving": false, "afraid": false, "asleep": false},
		"station": &"",
		"near": [],
		"quiet_for": 999.0,
		"node": null,
	}


## The night, the garrison and who is about, for `men` (nodes or sheet men).
## `extra` adds what the caller knows: situation, place, place_name,
## dead_name.
static func world(men: Array, tree: SceneTree, extra := {}) -> Dictionary:
	var facts := {
		"at_ease": true, "uneasy": false, "combat": false, "hunt": false,
		"alarm": 0.0, "bell_rung": false, "dead": 0, "dead_names": [], "body_found": false, "missing": [],
		"captain_dead": false, "spared_names": [], "slain_names": [],
		"dread": 0.0, "spared": false, "slain_begging": false, "habits": {},
		"night": &"early", "cold": false, "fire": &"", "wind": false,
		"present": [], "asleep": [],
		"situation": StringName(extra.get("situation", &"")), "place": extra.get("place", []),
		"place_name": String(extra.get("place_name", "")), "dead_name": String(extra.get("dead_name", "")),
	}

	var dread_of: RefCounted = _garrison(tree)

	for m in men:
		var node: Variant = m.get("node") if m is Dictionary else m

		if node != null and is_instance_valid(node) and not GuardLifeScript.at_ease(node):
			facts["at_ease"] = false

		# Afraid, a man is not at his ease, whatever he is doing.
		if node != null and is_instance_valid(node) and dread_of != null:
			var fighter: RefCounted = node.get("_fighter")

			if fighter != null and fighter.temper != null and float(dread_of.fear_of(float(fighter.temper.nerve))) > AFRAID_AT:
				facts["at_ease"] = false

	if tree == null:
		return facts

	var first: Node3D = null

	for m in men:
		var node: Variant = m.get("node") if m is Dictionary else m

		if node != null and is_instance_valid(node):
			first = node
			break

	for guard in tree.get_nodes_in_group(&"guards"):
		if guard.get("_knocked_out") == true:
			continue

		facts["present"].append(String(guard.get("given_name")))
		var state := int(guard.get("state"))

		if state == SUSPICIOUS or state == INVESTIGATING:
			facts["uneasy"] = true
		elif state == COMBAT:
			facts["combat"] = true

		var fighter: RefCounted = guard.get("_fighter")

		if fighter != null and fighter.squad != null:
			facts["hunt"] = true

		if asleep(guard):
			facts["asleep"].append(String(guard.get("given_name")))

	var garrison := _garrison(tree)

	if garrison != null:
		facts["alarm"] = float(garrison.alarm)
		facts["dread"] = float(garrison.dread)
		facts["dead"] = int(garrison.dead)
		facts["dead_names"] = Array(garrison.dead_names).duplicate()
		facts["body_found"] = int(garrison.get("bodies_found")) > 0
		facts["spared"] = not garrison.spared.is_empty()
		facts["slain_begging"] = not garrison.slain_begging.is_empty()
		facts["spared_names"] = Array(garrison.spared).duplicate()
		facts["slain_names"] = Array(garrison.slain_begging).duplicate()
		facts["captain_dead"] = int(garrison.captains) > 0
		facts["habits"] = (garrison.habits as Dictionary).duplicate()

		for post in garrison.fallen:
			if bool(post["noticed"]) and String(post["name"]) != "":
				facts["missing"].append(String(post["name"]))

		if float(garrison.alarm) >= 0.2:
			facts["uneasy"] = true

	# The man they speak of is dead to them, whatever the garrison knows yet.
	if facts["dead_name"] != "" and not (facts["dead_names"] as Array).has(facts["dead_name"]):
		(facts["dead_names"] as Array).append(facts["dead_name"])

	for bell in tree.get_nodes_in_group(&"alarm_bells"):
		if float(bell.get("_since_rung")) < BELL_FOR:
			facts["bell_rung"] = true

	var rota := _night_rota(first) if first != null else null

	if rota != null:
		facts["night"] = StringName(rota.hour())

	facts["cold"] = facts["night"] == &"late" or facts["night"] == &"dawn"

	if first != null:
		for fire in tree.get_nodes_in_group(&"fires"):
			if fire is Node3D and (fire as Node3D).global_position.distance_to(first.global_position) < FIRE_NEAR:
				facts["fire"] = &"low" if fire.has_method("low") and fire.low() else &"burning"

				if facts["fire"] == &"low":
					break

	for atmosphere in tree.get_nodes_in_group(&"atmosphere"):
		if atmosphere.has_method("wind"):
			facts["wind"] = (atmosphere.wind() as Vector3).length() > 0.6

	return facts


# ---------------------------------------------------------------------------
# Reading
# ---------------------------------------------------------------------------

## Whether a `when:` term (one alternative) holds.
static func holds(term: String, world: Dictionary, cast := {}) -> bool:
	term = term.strip_edges()

	if term.begins_with("not(") and term.ends_with(")"):
		return not holds(term.substr(4, term.length() - 5), world, cast)

	var compared := _compare(term)

	if not compared.is_empty():
		return _measure(float(world.get(compared[0], 0.0)), compared[1], compared[2])

	var called := _called(term)

	if not called.is_empty():
		var list: Array = world.get({"dead": "dead_names"}.get(called[0], called[0]), [])
		return list.has(called[1])

	if term.contains(":"):
		var key := term.substr(0, term.find(":"))
		var value := term.substr(term.find(":") + 1)

		match key:
			"habit":
				return float((world.get("habits", {}) as Dictionary).get(StringName(value), 0.0)) > HABIT_TALKED
			_:
				return String(world.get(key, "")) == value

	return _truthy(world.get(term, false))


## Whether `man` meets a requirement (or a line's {if}); `cast` has the parts
## already cast (for ties to them).
static func meets(man: Dictionary, term: String, cast: Dictionary, world: Dictionary) -> bool:
	term = term.strip_edges()

	if term.begins_with("not(") and term.ends_with(")"):
		return not meets(man, term.substr(4, term.length() - 5), cast, world)

	if term == "any":
		return true

	if TEMPERS.has(term):
		return String(man.get("temper", "")) == term

	var states: Dictionary = man.get("states", {})
	var compared := _compare(term)

	if not compared.is_empty():
		var value: float = float(man.get("rank", 1)) if compared[0] == "rank" else float(states.get(compared[0], 0.0))
		return _measure(value, compared[1], compared[2])

	if STATES.has(term):
		var state: Variant = states.get(term, false)
		var on: bool = float(state) >= 0.5 if state is float else bool(state)
		return on or (man.get("traits", []) as Array).has(term)

	var called := _called(term)

	if not called.is_empty():
		var what: String = called[0]
		var arg: String = called[1]

		match what:
			"name":
				return String(man.get("name", "")) == arg
			"kind":
				var kind := String(man.get("kind", ""))
				return kind == arg or (kind == "" and arg == "watchman")
			"station":
				return String(man.get("station", "")) == arg
			"near":
				return (man.get("near", []) as Array).has(arg)
			_:
				if TIES.has(what):
					var other := arg

					if cast.has(arg):
						other = String((cast[arg] as Dictionary).get("name", ""))
					elif arg.length() == 1:
						return false

					return ((man.get("ties", {}) as Dictionary).get(what, []) as Array).has(other)

		return false

	return (man.get("traits", []) as Array).has(term)


## Whether a word means anything: in a `when:` (as_requirement false) or as a
## part's requirement or a line's {if} (true; `traits` are the cast sheet's).
static func known(term: String, as_requirement: bool, traits := [], names := []) -> bool:
	term = term.strip_edges()

	if term.begins_with("not(") and term.ends_with(")"):
		return known(term.substr(4, term.length() - 5), as_requirement, traits, names)

	var compared := _compare(term)
	var called := _called(term)

	if not as_requirement:
		if not compared.is_empty():
			return WHEN_MEASURES.has(compared[0])

		if not called.is_empty():
			return WHEN_NAMED.has(called[0]) and (names.is_empty() or names.has(called[1]))

		if term.contains(":"):
			var key := term.substr(0, term.find(":"))
			var value := term.substr(term.find(":") + 1)

			match key:
				"night":
					return HOURS.has(value)
				"fire":
					return value in ["low", "burning"]
				"habit":
					return HABITS.has(value)
				"situation":
					return SITUATIONS.has(value)

			return false

		return WHEN_WORDS.has(term)

	if not compared.is_empty():
		return compared[0] == "rank" or MEASURED.has(compared[0])

	if not called.is_empty():
		# A man named must be one of the cast (a tie may name a part instead).
		var named: bool = called[0] == "name" or (TIES.has(called[0]) and called[1].length() > 1)

		if named and not names.is_empty() and not names.has(called[1]):
			return false

		return called[0] in ["name", "kind", "station", "near"] or TIES.has(called[0])

	return term == "any" or term == "captain" or TEMPERS.has(term) or STATES.has(term) or traits.has(term)


# ---------------------------------------------------------------------------
# Casting
# ---------------------------------------------------------------------------

## The men of `men` (in the order given: the quietest first) in the parts of
## `conv`, {part: man}, the assignment meeting most requirements; {} if a part
## that must be filled cannot be. `allowed.call(man, part)` can refuse a man
## a part.
static func cast_parts(conv: Dictionary, men: Array, world: Dictionary, allowed := Callable()) -> Dictionary:
	var best := {"score": -1, "cast": {}}
	_search(conv["cast"], 0, men, {}, 0, world, allowed, best)
	return best["cast"]


## How much a conversation asks for, cast as `cast`: its conditions, and the
## requirements of the parts filled (not "any").
static func specificity(conv: Dictionary, cast: Dictionary) -> int:
	var count: int = (conv["when"] as Array).size()

	for part in conv["cast"]:
		if cast.has(part["key"]):
			for req in part["reqs"]:
				if not (req.size() == 1 and req[0] == "any"):
					count += 1

	return count


static func _search(parts: Array, index: int, men: Array, cast: Dictionary, score: int, world: Dictionary, allowed: Callable, best: Dictionary) -> void:
	if index >= parts.size():
		if score > int(best["score"]):
			best["score"] = score
			best["cast"] = cast.duplicate()

		return

	var part: Dictionary = parts[index]
	var key: String = part["key"]

	for m in men:
		if cast.values().has(m):
			continue

		if allowed.is_valid() and not allowed.call(m, key):
			continue

		if not _fits(m, part["reqs"], cast, world):
			continue

		cast[key] = m
		var gained := 0

		for req in part["reqs"]:
			if not (req.size() == 1 and req[0] == "any"):
				gained += 1

		_search(parts, index + 1, men, cast, score + gained + (10 if part["optional"] else 0), world, allowed, best)
		cast.erase(key)

	if part["optional"]:
		_search(parts, index + 1, men, cast, score, world, allowed, best)


## Every requirement met (any of its alternatives).
static func _fits(m: Dictionary, reqs: Array, cast: Dictionary, world: Dictionary) -> bool:
	for req in reqs:
		if not (req as Array).any(func(alt): return meets(m, String(alt), cast, world)):
			return false

	return true


# ---------------------------------------------------------------------------
# Words
# ---------------------------------------------------------------------------

## "dead>=2" is ["dead", ">=", 2.0]; [] if it is no comparison.
static func _compare(term: String) -> Array:
	for op in [">=", "<=", ">", "<"]:
		var at := term.find(op)

		if at > 0:
			var number := term.substr(at + op.length())

			if number.is_valid_float():
				return [term.substr(0, at), op, float(number)]

	return []


## A fact that is there: true, a number above nothing, a list with
## something in it.
static func _truthy(value: Variant) -> bool:
	if value is Array:
		return not (value as Array).is_empty()

	if value is bool:
		return value

	if value is int or value is float:
		return float(value) > 0.0

	return value != null and String(value) != ""


static func _measure(value: float, op: String, against: float) -> bool:
	match op:
		">=":
			return value >= against
		"<=":
			return value <= against
		">":
			return value > against
		"<":
			return value < against

	return false


## "dead(Jory)" is ["dead", "Jory"]; [] if it is not of that shape.
static func _called(term: String) -> Array:
	var open := term.find("(")

	if open <= 0 or not term.ends_with(")"):
		return []

	return [term.substr(0, open), term.substr(open + 1, term.length() - open - 2)]


static func _garrison(tree: SceneTree) -> RefCounted:
	if tree == null:
		return null

	var target := tree.get_first_node_in_group(&"player") as Node3D
	return GarrisonScript.of(target) if target != null else null


static func _night_rota(node: Node) -> RefCounted:
	if node == null or not ResourceLoader.exists(NIGHT_ROTA):
		return null

	return (load(NIGHT_ROTA) as GDScript).call(&"of", node)
