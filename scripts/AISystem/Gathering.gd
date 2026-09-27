extends RefCounted
## The things the men do together: small scenes, each with its parts, its
## place, its time and its own conversations (TalkScript `place:`). One
## director for each scene tree (`of`), ticked by every guard's GuardLife.
##   dice    two or three at the crate by the bench: throws, groans, cheers.
##   flask   two men: a hand held out, a pull, handed back.
##   story   a teller and his listeners round the fire: the longest talk,
##           a laugh at the end.
## A gathering starts when it is asked for (`request`) or, where the level
## keeps a night rota (NightRota), when its men are free and near. It asks
## them first ("Dice?" "Go on then."), lends each a station at his spot
## (GuardRota.lend: he walks there and settles), plays its conversations,
## and lets them go. Anything that stirs one of them ends it for all.
##
## A place is a node in the group "gathering_places" with its kind in the
## meta "gathering"; its spots are its Marker3D children (meta "activity":
## squat, stand, sit; meta "role": teller, listener, any), each facing its
## -Z.

const TalkFacts := preload("res://scripts/AISystem/Talk/TalkFacts.gd")
const TalkScript := preload("res://scripts/AISystem/Talk/TalkScript.gd")
const GuardLifeScript := preload("res://scripts/AISystem/GuardLife.gd")
const GuardStationScript := preload("res://scripts/AISystem/GuardStation.gd")

## Reached at run time (they read the guard scripts too).
const TALK_DIRECTOR := "res://scripts/AISystem/Talk/TalkDirector.gd"
const NIGHT_ROTA := "res://scripts/AISystem/NightRota.gd"

## How often it looks to start one (s).
const START_EVERY := 4.0
## Men walking to their spots: longer than this and it is off.
const GATHER_FOR := 30.0
## Between its conversations (s).
const BETWEEN := Vector2(3.0, 6.0)
## The flask: the second man stands this far from the first.
const FLASK_APART := 1.2
## After a gathering, this long before its men talk again (TalkDirector).
const REST := Vector2(20.0, 45.0)
## Each kind: size [least, most], its place kind ("" where they stand), how
## long it lasts (s, once playing), how many conversations, the rest before
## another like it, how far its men may be to come.
const KINDS := {
	&"dice": {"size": Vector2i(2, 3), "place": &"dice", "length": Vector2(45.0, 80.0), "convs": 2, "cooldown": 150.0, "reach": 14.0},
	&"flask": {"size": Vector2i(2, 2), "place": &"", "length": Vector2(12.0, 20.0), "convs": 1, "cooldown": 90.0, "reach": 5.0},
	&"story": {"size": Vector2i(3, 4), "place": &"story", "length": Vector2(60.0, 150.0), "convs": 1, "cooldown": 180.0, "reach": 14.0},
}

static var _directors := {}
static var _talk_script: GDScript = null
static var _rota_script: GDScript = null

var clock := 0.0
var _tree: WeakRef
var _frame := -1
var _start_in := START_EVERY
## Asked for: [{kind, names}].
var _queue: Array = []
var _cooling := {}
## The gatherings going on: {kind, members, roles, place, stations, spots,
## started_at, conversations, state, until, next_at}.
var _live: Array = []
var _history: Array[StringName] = []


## The director for `node`'s tree (made the first time it is asked for).
static func of(node: Node) -> RefCounted:
	if node == null or not node.is_inside_tree():
		return null

	var key := node.get_tree().get_instance_id()
	var director: RefCounted = _directors.get(key)

	if director == null:
		director = (load("res://scripts/AISystem/Gathering.gd") as GDScript).new()
		director._tree = weakref(node.get_tree())
		_directors[key] = director

	return director


static func clear_all() -> void:
	_directors.clear()


## Starts a `kind` soon (whatever its rest), with these men (names) if given.
func request(kind: StringName, names := []) -> void:
	_queue.append({"kind": kind, "names": names})
	_start_in = minf(_start_in, 0.0)


## The gatherings going on, for tests and the showcase.
func live() -> Array:
	return _live


## The kinds that came to be played tonight, in order.
func history() -> Array[StringName]:
	return _history


## The gathering he is in; {} if none.
func member_of(man: Node) -> Dictionary:
	for g in _live:
		if (g["members"] as Array).has(man):
			return g

	return {}


## On her round, the captain is within reach of him (Expression: he
## straightens). None until the round is made (the second part of this).
func captain_near(_man: Node) -> bool:
	return false


## Once a physics frame, whoever calls.
func tick(delta: float) -> void:
	var frame := Engine.get_physics_frames()

	if frame == _frame:
		return

	_frame = frame
	clock += delta

	for g in _live.duplicate():
		if _live.has(g):
			_advance(g)

	_start_in -= delta

	if _start_in > 0.0:
		return

	_start_in = START_EVERY
	var rota := _rota()

	if rota != null and rota.suspended():
		return

	if not _queue.is_empty():
		var asked: Dictionary = _queue.pop_front()

		if not _start(StringName(asked["kind"]), asked["names"]):
			# Not now: again in a moment, unless there is no such thing.
			if KINDS.has(asked["kind"]):
				_queue.push_front(asked)

		return

	# Where the level keeps a night, the men gather of their own accord.
	if rota == null:
		return

	for kind in KINDS:
		if clock >= float(_cooling.get(kind, -INF)) and _start(kind, []):
			return


# ---------------------------------------------------------------------------
# Starting
# ---------------------------------------------------------------------------

func _start(kind: StringName, names: Array) -> bool:
	var spec: Dictionary = KINDS.get(kind, {})
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	if spec.is_empty() or tree == null:
		return false

	var free: Array = tree.get_nodes_in_group(&"guards").filter(_free)

	if not names.is_empty():
		free = free.filter(func(m): return names.has(String(m.get("given_name"))))

	var place: Node3D = null
	var centre: Vector3

	if StringName(spec["place"]) != &"":
		place = _place_of(tree, StringName(spec["place"]))

		if place == null:
			return false

		centre = place.global_position
	elif not free.is_empty():
		centre = (free[0] as Node3D).global_position
	else:
		return false

	var reach := float(spec["reach"])
	free = free.filter(func(m): return (m as Node3D).global_position.distance_to(centre) <= reach)
	free.sort_custom(func(x: Node3D, y: Node3D) -> bool: return x.global_position.distance_to(centre) < y.global_position.distance_to(centre))
	var size: Vector2i = spec["size"]

	if free.size() < size.x:
		return false

	var members: Array = free.slice(0, size.y)
	var roles := {}

	if kind == &"story":
		var teller := _teller(members, free)

		if teller == null:
			return false

		if not members.has(teller):
			members[-1] = teller

		roles["teller"] = teller

	var g := {
		"kind": kind, "members": members, "roles": roles, "place": place, "stations": [], "spots": {},
		"started_at": clock, "conversations": 0, "state": &"invite", "until": INF, "next_at": 0.0,
	}
	_live.append(g)
	_spots(g, spec)

	# Asked first: "Dice?" "Go on then." (The teller asks for his story.)
	var talk := _talk()
	var asker: Node = roles.get("teller", members[0])
	var asked: Node = members[1] if asker == members[0] else members[0]

	if talk == null or not talk.play("invite_%s" % kind, {"A": asker, "B": asked}):
		_lend(g)

	return true


## Free to join: at his ease, not set to watch, not on a post, not
## carrying, not asleep, not talking, not already in one.
func _free(man: Node) -> bool:
	if not is_instance_valid(man) or man.is_queued_for_deletion() or man.get("puppet") == true:
		return false

	if not GuardLifeScript.at_ease(man) or bool(man.get("lookout")) or not member_of(man).is_empty():
		return false

	var rota: RefCounted = man.get("_rota")

	if rota != null and (rota.carried != null or rota.asleep() or rota.on_loan()):
		return false

	var night := _rota()

	if night != null and night.kind_of(night.duty_of(man)) == &"post":
		return false

	var talk := _talk()
	return talk == null or not talk.in_talk(man)


## The man to tell the story: a storyteller, else one of rank.
func _teller(members: Array, free: Array) -> Node:
	var sheet: Dictionary = TalkScript.library().get("cast", {})
	var best: Node = null

	for m in members + free:
		var facts := TalkFacts.man(m, sheet)

		if TalkFacts.meets(facts, "storyteller", {}, {}):
			return m

		if best == null and TalkFacts.meets(facts, "rank>=2", {}, {}):
			best = m

	return best


func _place_of(tree: SceneTree, kind: StringName) -> Node3D:
	for place in tree.get_nodes_in_group(&"gathering_places"):
		if StringName(place.get_meta(&"gathering", &"")) == kind:
			return place as Node3D

	return null


## Where each man goes: his spot at the place (the teller his), or, with no
## place, facing each other where the first stands.
func _spots(g: Dictionary, _spec: Dictionary) -> void:
	var members: Array = g["members"]
	var place: Node3D = g["place"]

	if place == null:
		var first: Node3D = members[0]
		var second: Node3D = members[1]
		var apart := second.global_position - first.global_position
		apart.y = 0.0
		apart = apart.normalized() * FLASK_APART if apart.length() > 0.01 else -first.global_basis.z * FLASK_APART
		g["spots"][first] = [Transform3D(Basis.looking_at(apart, Vector3.UP), first.global_position), &"stand"]
		g["spots"][second] = [Transform3D(Basis.looking_at(-apart, Vector3.UP), first.global_position + apart), &"stand"]
		return

	var markers := place.get_children().filter(func(c): return c is Marker3D)
	var teller: Variant = g["roles"].get("teller")

	for m in members:
		var want := &"teller" if m == teller else &"listener"
		var chosen: Node3D = null

		for marker in markers:
			var role := StringName(marker.get_meta(&"role", &"any"))

			if role == want or (role == &"any" and want != &"teller"):
				chosen = marker
				break

		if chosen == null and not markers.is_empty():
			chosen = markers[0]

		if chosen == null:
			continue

		markers.erase(chosen)
		g["spots"][m] = [chosen.global_transform, StringName(chosen.get_meta(&"activity", &"stand"))]


## Each man lent a station at his spot: they go to it.
func _lend(g: Dictionary) -> void:
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	for m in g["members"]:
		var spot: Array = g["spots"].get(m, [])

		if spot.is_empty() or tree == null:
			continue

		var station: Node3D = GuardStationScript.new()
		station.name = "Gathering_%s" % g["kind"]
		station.kind = spot[1]
		var home: Node = tree.current_scene if tree.current_scene != null else tree.root
		home.add_child(station)
		station.global_transform = spot[0]
		g["stations"].append(station)
		m._rota.lend(station)

	g["state"] = &"gathering"
	g["started_at"] = clock


# ---------------------------------------------------------------------------
# Going on
# ---------------------------------------------------------------------------

func _advance(g: Dictionary) -> void:
	for m in g["members"]:
		if m == null or not is_instance_valid(m) or m.get("_knocked_out") == true or not GuardLifeScript.at_ease(m):
			_end(g)
			return

	var talk := _talk()
	var talking: bool = talk != null and (g["members"] as Array).any(func(m): return talk.in_talk(m))

	match g["state"]:
		&"invite":
			if not talking:
				_lend(g)
		&"gathering":
			if (g["members"] as Array).all(func(m): return m._rota.at_station()):
				var spec: Dictionary = KINDS[g["kind"]]
				g["state"] = &"playing"
				g["until"] = clock + randf_range(spec["length"].x, spec["length"].y)
				g["next_at"] = clock + 1.0
				_history.append(g["kind"])
			elif clock - float(g["started_at"]) > GATHER_FOR:
				_end(g)
		&"playing":
			var spec: Dictionary = KINDS[g["kind"]]

			if talking:
				g["next_at"] = clock + randf_range(BETWEEN.x, BETWEEN.y)
				return

			if int(g["conversations"]) >= int(spec["convs"]) or clock >= float(g["until"]):
				_end(g)
				return

			if clock >= float(g["next_at"]):
				if talk != null and talk.play_place(g["members"], g["kind"]):
					g["conversations"] = int(g["conversations"]) + 1
				else:
					# Nothing left to say here.
					_end(g)


func _end(g: Dictionary) -> void:
	_live.erase(g)
	_cooling[g["kind"]] = clock + float(KINDS[g["kind"]]["cooldown"])

	for m in g["members"]:
		if m == null or not is_instance_valid(m):
			continue

		if m._rota.on_loan():
			m._rota.end_loan()

		m._life._talk_rest = maxf(float(m._life._talk_rest), randf_range(REST.x, REST.y))

	for station in g["stations"]:
		if is_instance_valid(station):
			station.queue_free()


func _talk() -> RefCounted:
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	if tree == null:
		return null

	if _talk_script == null:
		_talk_script = load(TALK_DIRECTOR)

	return _talk_script.of(tree.root)


func _rota() -> RefCounted:
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	if tree == null:
		return null

	if _rota_script == null:
		_rota_script = load(NIGHT_ROTA)

	return _rota_script.of(tree.root)
