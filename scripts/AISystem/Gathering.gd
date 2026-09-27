extends RefCounted
## The things the men do together: small scenes, each with its parts, its
## place, its time and its own conversations (TalkScript `place:`). One
## director for each scene tree (`of`), ticked by every guard's GuardLife.
##   dice    two or three at the crate by the bench: throws, groans, cheers.
##   flask   two men: a hand held out, a pull, handed back.
##   story   a teller and his listeners round the fire: the longest talk,
##           a laugh at the end.
##   watch_change  the relief walks over to the man on a post: "Anything?"
##           "Nothing but the cold." Their duties swap (NightRota).
##   round   the captain goes from man to man, a word for each by who he is;
##           men straighten as she passes; a sleeper gets a boot.
##   wake    a man nudges a sleeper awake to take his turn; up he gets,
##           grumbling.
##   fire    the fire burning low, a man fetches a log from the woodpile,
##           kneels and feeds it; it flares.
## And the rota's other wants: a hungry man goes to eat, a cold one to the
## fire, a tired one to bed.
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
	&"story": {"size": Vector2i(3, 4), "place": &"story", "length": Vector2(60.0, 150.0), "convs": 1, "cooldown": 180.0, "reach": 20.0},
}
## The kinds with a shape of their own, and the rest before another.
const SPECIAL := {&"watch_change": 0.0, &"round": 240.0, &"wake": 0.0, &"fire": 5.0}
## The relief stands this far from the man on the post; the captain this far
## from each man; the waker this far from the sleeper.
const RELIEF_APART := 1.1
const ROUND_APART := 1.2
const WAKER_APART := 0.9
## The round: this many men at most; a man straightens with her this near.
const ROUND_VISITS := 6
const STRAIGHTEN_NEAR := 4.0
## Waking: a nudge, then this long before he stirs.
const NUDGE := 1.5
## The fire: a man comes to it from this far; takes a log this long, from
## this near the pile; kneels to feed it this long, this near; how much.
const FIRE_REACH := 25.0
const PICK_LOG := 1.0
const PILE_NEAR := 0.8
const FEED := 2.5
const FIRE_NEAR := 0.9
const LOG_FUEL := 0.6
## A man near the fire when it is fed has a word about it.
const FIRE_COMPANY := 4.0
## Needs: a meal this long, warming at the fire this long, this far from it.
const MEAL := 30.0
const WARMING := 25.0
const WARM_APART := 1.6

static var _directors := {}
static var _talk_script: GDScript = null

## Whether its men gather of their own accord where there is a night rota
## (off where the level asks for each gathering itself: the showcase).
var spontaneous := true
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
## straightens).
func captain_near(man: Node) -> bool:
	for g in _live:
		if g["kind"] != &"round":
			continue

		var captain: Variant = g["roles"].get("captain")

		if captain != null and is_instance_valid(captain) and captain != man and (captain as Node3D).global_position.distance_to((man as Node3D).global_position) <= STRAIGHTEN_NEAR:
			return true

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

	# The rota's wants: the relief for a post, a meal, the fire, bed.
	if rota != null:
		for want in rota.take_wanted():
			_see_to(want, rota)

	# A fire burning low is fed.
	if _feed_a_fire():
		return

	if not _queue.is_empty():
		var asked: Dictionary = _queue.pop_front()

		if not _start(StringName(asked["kind"]), asked["names"]):
			# Not now: again in a moment, unless there is no such thing.
			if KINDS.has(asked["kind"]) or SPECIAL.has(asked["kind"]):
				_queue.append(asked)

		return

	# Where the level keeps a night, the men gather of their own accord.
	if rota == null or not spontaneous:
		return

	for kind in KINDS:
		if clock >= float(_cooling.get(kind, -INF)) and _start(kind, []):
			return


# ---------------------------------------------------------------------------
# Starting
# ---------------------------------------------------------------------------

func _start(kind: StringName, names: Array) -> bool:
	if SPECIAL.has(kind):
		return _start_special(kind, names)

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
	match g["kind"]:
		&"watch_change":
			_advance_watch(g)
			return
		&"round":
			_advance_round(g)
			return
		&"wake":
			_advance_wake(g)
			return
		&"fire":
			_advance_fire(g)
			return
		&"rest":
			_advance_rest(g)
			return

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
	_cooling[g["kind"]] = clock + float(KINDS[g["kind"]]["cooldown"] if KINDS.has(g["kind"]) else SPECIAL.get(g["kind"], 0.0))

	if g.has("log") and is_instance_valid(g["log"]):
		g["log"].queue_free()

	for m in g["members"]:
		if m != null and is_instance_valid(m) and m.has_meta(&"carry_log"):
			m.remove_meta(&"carry_log")

	for m in g["members"]:
		if m == null or not is_instance_valid(m):
			continue

		if m._rota.on_loan():
			m._rota.end_loan()

		m._life._talk_rest = maxf(float(m._life._talk_rest), randf_range(REST.x, REST.y))

	for station in g["stations"]:
		if is_instance_valid(station):
			station.queue_free()


# ---------------------------------------------------------------------------
# The watch, the round, the sleeper, the fire
# ---------------------------------------------------------------------------

func _start_special(kind: StringName, names: Array) -> bool:
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	if tree == null:
		return false

	var named: Array = tree.get_nodes_in_group(&"guards").filter(func(m): return names.has(String(m.get("given_name"))))

	match kind:
		&"watch_change":
			var rota := _rota()
			var on_post: Node = null
			var relief: Node = null

			for m in named:
				if rota != null and rota.kind_of(rota.duty_of(m)) == &"post":
					on_post = m
				else:
					relief = m

			return on_post != null and _start_watch(on_post, relief)
		&"round":
			var captain: Node = named[0] if not named.is_empty() else null

			if captain == null:
				for m in tree.get_nodes_in_group(&"guards"):
					if _free(m) and _is_captain(m):
						captain = m
						break

			return captain != null and _start_round(captain)
		&"wake":
			for m in tree.get_nodes_in_group(&"guards"):
				var rota: RefCounted = m.get("_rota")

				if rota != null and rota.asleep() and member_of(m).is_empty():
					return _start_wake(m, null, null)

			return false
		&"fire":
			return _feed_a_fire()

	return false


## A want of the rota's seen to.
func _see_to(want: Dictionary, rota: RefCounted) -> void:
	var man: Variant = want.get("man")

	if man == null or not is_instance_valid(man):
		return

	if want["kind"] == &"relief":
		if not _start_watch(man, null):
			# Nobody to send yet: asked again next time.
			_queue.append({"kind": &"watch_change", "names": [String(man.get("given_name"))], "man": man})

		return

	# A sleeper, a man set to watch, a man stirred: not now.
	if not member_of(man).is_empty() or man._rota.asleep() or bool(man.get("lookout")) or not GuardLifeScript.at_ease(man):
		return

	match StringName(want.get("need", &"")):
		&"tired":
			var bed: StringName = rota.free_duty(&"bed")

			if bed == &"":
				bed = rota.free_duty(&"bench")

			if bed != &"":
				rota.assign(man, bed)
		&"hungry":
			var bowl := _free_station(&"eat", man)

			if bowl != null:
				_rest(man, bowl, MEAL, false)
		&"cold":
			var fire := _nearest_fire((man as Node3D).global_position, INF)

			if fire != null:
				var at := _beside(fire.global_position, (man as Node3D).global_position, WARM_APART)
				_rest(man, _make_station(&"warm_hands", at, fire.global_position), WARMING, true)


## The relief sent to the man on his post (or, the only one free asleep,
## woken first).
func _start_watch(on_post: Node, relief: Node) -> bool:
	for g in _live:
		if g["kind"] == &"watch_change" and (g["members"] as Array).has(on_post):
			return true

	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	if tree == null:
		return false

	if relief == null:
		var rota := _rota()
		var free: Array = tree.get_nodes_in_group(&"guards").filter(func(m): return m != on_post and _free(m))
		free.sort_custom(func(x: Node, y: Node) -> bool:
			return float(rota.needs_of(x)["tired"]) < float(rota.needs_of(y)["tired"]) if rota != null else false)

		if not free.is_empty():
			relief = free[0]
		else:
			# Only a sleeper to send: woken first.
			for m in tree.get_nodes_in_group(&"guards"):
				var stations: RefCounted = m.get("_rota")

				if m != on_post and stations != null and stations.asleep() and member_of(m).is_empty():
					return _start_wake(m, null, on_post)

			return false

	if not member_of(relief).is_empty() or not member_of(on_post).is_empty():
		return false

	var post: Vector3 = on_post._home.origin
	var at := _beside(post, (relief as Node3D).global_position, RELIEF_APART)
	var g := {"kind": &"watch_change", "members": [on_post, relief], "roles": {"post": on_post, "relief": relief},
		"stations": [], "state": &"going", "t": clock}
	_live.append(g)
	var station := _make_station(&"stand", at, post)
	g["stations"].append(station)
	relief._rota.lend(station)
	return true


func _advance_watch(g: Dictionary) -> void:
	var on_post: Variant = g["roles"]["post"]
	var relief: Variant = g["roles"]["relief"]

	if not _here(on_post) or not _here(relief):
		_end(g)
		return

	var talk := _talk()

	match g["state"]:
		&"going":
			var post: Vector3 = on_post._home.origin
			var at_post := Vector2(on_post.global_position.x - post.x, on_post.global_position.z - post.z).length() < 2.0

			if relief._rota.at_station() and at_post and not talk.in_talk(on_post) and not talk.in_talk(relief):
				g["state"] = &"talking"
				_history.append(&"watch_change")

				if not talk.play_place([on_post, relief], &"watch_change", {"A": on_post, "B": relief}):
					_hand_over(g)
			elif clock - float(g["t"]) > GATHER_FOR * 2.0:
				_end(g)
		&"talking":
			if not talk.in_talk(on_post) and not talk.in_talk(relief):
				_hand_over(g)


## Their duties swap; the man relieved goes to bed if he is worn out.
func _hand_over(g: Dictionary) -> void:
	var on_post: Node = g["roles"]["post"]
	var relief: Node = g["roles"]["relief"]
	var rota := _rota()

	if rota != null:
		rota.swap(on_post, relief)

		if float(rota.needs_of(on_post)["tired"]) >= 0.8:
			var bed: StringName = rota.free_duty(&"bed")

			if bed != &"":
				rota.assign(on_post, bed)

	_end(g)


func _start_round(captain: Node) -> bool:
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	if tree == null or not member_of(captain).is_empty():
		return false

	var candidates: Array = tree.get_nodes_in_group(&"guards").filter(func(m):
		return m != captain and _here(m) and GuardLifeScript.at_ease(m) and not bool(m.get("lookout")) and member_of(m).is_empty())
	candidates.sort_custom(func(x: Node3D, y: Node3D) -> bool:
		return x.global_position.distance_to((captain as Node3D).global_position) < y.global_position.distance_to((captain as Node3D).global_position))
	# Anyone asleep gets his boot, whoever else she has time for.
	var sleepers := candidates.filter(func(m): return m._rota.asleep())
	var visits: Array = candidates.filter(func(m): return not m._rota.asleep()).slice(0, maxi(ROUND_VISITS - sleepers.size(), 0)) + sleepers
	visits = _tour(visits, (captain as Node3D).global_position)

	if visits.is_empty():
		return false

	var g := {"kind": &"round", "members": [captain], "roles": {"captain": captain}, "stations": [],
		"visits": visits, "visit": -1, "state": &"next", "t": clock}
	_live.append(g)
	return true


## `men` in the order she would walk them: each next the nearest to the last.
func _tour(men: Array, from: Vector3) -> Array:
	var left := men.duplicate()
	var order := []
	var at := from

	while not left.is_empty():
		left.sort_custom(func(x: Node3D, y: Node3D) -> bool: return x.global_position.distance_to(at) < y.global_position.distance_to(at))
		var next: Node3D = left.pop_front()
		order.append(next)
		at = next.global_position

	return order


func _advance_round(g: Dictionary) -> void:
	var captain: Variant = g["roles"]["captain"]

	if not _here(captain) or not GuardLifeScript.at_ease(captain):
		_end(g)
		return

	var talk := _talk()
	var visits: Array = g["visits"]
	var him: Variant = visits[int(g["visit"])] if int(g["visit"]) >= 0 and int(g["visit"]) < visits.size() else null

	match g["state"]:
		&"next":
			g["visit"] = int(g["visit"]) + 1

			if int(g["visit"]) >= visits.size():
				_end(g)
				return

			him = visits[int(g["visit"])]

			if not _here(him) or not member_of(him).is_empty():
				return

			g["members"] = [captain, him]
			var at := _beside((him as Node3D).global_position, (captain as Node3D).global_position, ROUND_APART)
			var station := _make_station(&"stand", at, (him as Node3D).global_position)
			g["stations"].append(station)
			captain._rota.lend(station)
			g["state"] = &"going"
			g["t"] = clock
		&"going":
			if not _here(him):
				g["state"] = &"next"
			elif captain._rota.at_station():
				if not talk.in_talk(him) and talk.play_place([captain, him], &"round", {"A": captain, "B": him}):
					g["state"] = &"talking"

					if not _history.has(&"round") or _history[-1] != &"round":
						_history.append(&"round")
				elif clock - float(g["t"]) > 6.0:
					g["state"] = &"next"
			elif clock - float(g["t"]) > GATHER_FOR:
				g["state"] = &"next"
		&"talking":
			if not talk.in_talk(captain):
				# A sleeper booted awake gets up, and goes to the bench if
				# there is one to go to.
				if _here(him) and him._rota.asleep():
					var rota := _rota()
					var bench: StringName = rota.free_duty(&"bench") if rota != null else &""

					if bench != &"":
						rota.assign(him, bench)
					else:
						him._rota.roused()

				g["members"] = [captain]
				g["state"] = &"next"


## A sleeper nudged awake by the nearest man up (or the man on the post who
## wants him); then, if a post wants him, the watch changes.
func _start_wake(sleeper: Node, waker: Node, then_relieve: Node) -> bool:
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	if tree == null:
		return false

	if waker == null:
		var awake: Array = tree.get_nodes_in_group(&"guards").filter(func(m): return m != sleeper and _free(m))
		awake.sort_custom(func(x: Node3D, y: Node3D) -> bool:
			return x.global_position.distance_to((sleeper as Node3D).global_position) < y.global_position.distance_to((sleeper as Node3D).global_position))
		waker = awake[0] if not awake.is_empty() else then_relieve

	if waker == null or not member_of(waker).is_empty():
		return false

	var g := {"kind": &"wake", "members": [waker, sleeper], "roles": {"waker": waker, "sleeper": sleeper, "then": then_relieve},
		"stations": [], "state": &"going", "t": clock}
	_live.append(g)
	var at := _beside((sleeper as Node3D).global_position, (waker as Node3D).global_position, WAKER_APART)
	var station := _make_station(&"stand", at, (sleeper as Node3D).global_position)
	g["stations"].append(station)
	waker._rota.lend(station)
	return true


func _advance_wake(g: Dictionary) -> void:
	var waker: Variant = g["roles"]["waker"]
	var sleeper: Variant = g["roles"]["sleeper"]

	if not _here(waker) or not _here(sleeper) or not GuardLifeScript.at_ease(waker):
		_end(g)
		return

	var talk := _talk()

	match g["state"]:
		&"going":
			if waker._rota.at_station():
				waker.emote("nudges")
				g["state"] = &"nudging"
				g["t"] = clock
			elif clock - float(g["t"]) > GATHER_FOR:
				_end(g)
		&"nudging":
			if clock - float(g["t"]) >= NUDGE:
				# Up he gets, and faces the man who woke him.
				var at := _beside((waker as Node3D).global_position, (sleeper as Node3D).global_position, 1.0)
				var station := _make_station(&"stand", at, (waker as Node3D).global_position)
				g["stations"].append(station)
				sleeper._rota.lend(station)
				g["state"] = &"rising"
				g["t"] = clock
		&"rising":
			if sleeper._rota.at_station():
				g["state"] = &"talking"
				_history.append(&"wake")

				if not talk.play_place([waker, sleeper], &"wake", {"A": waker, "B": sleeper}):
					_woken(g)
			elif clock - float(g["t"]) > GATHER_FOR:
				_woken(g)
		&"talking":
			if not talk.in_talk(waker) and not talk.in_talk(sleeper):
				_woken(g)


func _woken(g: Dictionary) -> void:
	var then: Variant = g["roles"].get("then")
	var sleeper: Node = g["roles"]["sleeper"]
	_end(g)

	if then != null and is_instance_valid(then):
		_start_watch(then, sleeper)


## A fire burning low, and a man free to feed it: he goes. True if one went.
func _feed_a_fire() -> bool:
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	if tree == null or clock < float(_cooling.get(&"fire", -INF)):
		return false

	for fire in tree.get_nodes_in_group(&"fires"):
		if not fire.has_method("low") or not fire.low():
			continue

		if _live.any(func(g): return g["kind"] == &"fire" and g["fire"] == fire):
			continue

		var at: Vector3 = (fire as Node3D).global_position
		var free: Array = tree.get_nodes_in_group(&"guards").filter(func(m): return _free(m) and (m as Node3D).global_position.distance_to(at) <= FIRE_REACH)

		if free.is_empty():
			continue

		free.sort_custom(func(x: Node3D, y: Node3D) -> bool: return x.global_position.distance_to(at) < y.global_position.distance_to(at))
		var feeder: Node3D = free[0]
		var g := {"kind": &"fire", "members": [feeder], "roles": {"feeder": feeder}, "fire": fire, "stations": [],
			"state": &"fetching", "t": clock}
		_live.append(g)
		var pile := _nearest_in(tree, &"woodpiles", feeder.global_position)

		if pile != null:
			var spot := _beside(pile.global_position, feeder.global_position, PILE_NEAR)
			var station := _make_station(&"pick_log", spot, pile.global_position)
			g["stations"].append(station)
			feeder._rota.lend(station)
		else:
			_carry_to_fire(g)

		return true

	return false


func _carry_to_fire(g: Dictionary) -> void:
	var feeder: Node3D = g["roles"]["feeder"]
	var fire: Node3D = g["fire"]
	var ground := Vector3(fire.global_position.x, feeder.global_position.y, fire.global_position.z)
	var station := _make_station(&"feed_fire", _beside(ground, feeder.global_position, FIRE_NEAR), ground)
	g["stations"].append(station)
	feeder.set_meta(&"carry_log", true)
	# A log across his arms.
	var log := MeshInstance3D.new()
	log.name = "Log"
	var round := CylinderMesh.new()
	round.top_radius = 0.09
	round.bottom_radius = 0.1
	round.height = 0.75
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.36, 0.25, 0.15)
	round.material = bark
	log.mesh = round
	feeder.add_child(log)
	log.position = Vector3(0.0, 1.0, -0.38)
	log.rotation = Vector3(0.0, 0.0, PI * 0.5)
	g["log"] = log
	feeder._rota.lend(station)
	g["state"] = &"carrying"
	g["t"] = clock


func _advance_fire(g: Dictionary) -> void:
	var feeder: Variant = g["roles"]["feeder"]
	var fire: Variant = g["fire"]

	if not _here(feeder) or fire == null or not is_instance_valid(fire) or not GuardLifeScript.at_ease(feeder):
		_end(g)
		return

	var talk := _talk()

	match g["state"]:
		&"fetching":
			if feeder._rota.at_station():
				g["state"] = &"picking"
				g["t"] = clock
			elif clock - float(g["t"]) > GATHER_FOR:
				_end(g)
		&"picking":
			if clock - float(g["t"]) >= PICK_LOG:
				_carry_to_fire(g)
		&"carrying":
			if feeder._rota.at_station():
				feeder.remove_meta(&"carry_log")
				g["state"] = &"feeding"
				g["t"] = clock
			elif clock - float(g["t"]) > GATHER_FOR:
				_end(g)
		&"feeding":
			if clock - float(g["t"]) >= FEED:
				fire.feed(LOG_FUEL)

				if g.has("log") and is_instance_valid(g["log"]):
					g["log"].queue_free()

				_history.append(&"fire")
				var company: Array = [feeder]
				var tree: SceneTree = _tree.get_ref() as SceneTree

				for m in tree.get_nodes_in_group(&"guards"):
					if m != feeder and _free(m) and (m as Node3D).global_position.distance_to((feeder as Node3D).global_position) <= FIRE_COMPANY:
						company.append(m)

				g["state"] = &"talking"

				if not talk.play_place(company.slice(0, 2), &"fire", {"A": feeder}):
					_end(g)
		&"talking":
			if not talk.in_talk(feeder):
				_end(g)


## A man lent `station` for `seconds` (a meal, warming at the fire).
func _rest(man: Node, station: Node3D, seconds: float, made: bool) -> void:
	var g := {"kind": &"rest", "members": [man], "roles": {}, "stations": [station] if made else [], "until": clock + seconds}
	_live.append(g)
	man._rota.lend(station)


func _advance_rest(g: Dictionary) -> void:
	var man: Variant = g["members"][0]

	if not _here(man) or not GuardLifeScript.at_ease(man) or clock >= float(g["until"]):
		_end(g)


# ---------------------------------------------------------------------------
# Places
# ---------------------------------------------------------------------------

## A station for a while (freed with the gathering), at `at` facing `look`.
func _make_station(kind: StringName, at: Vector3, look: Vector3) -> Node3D:
	var tree: SceneTree = _tree.get_ref() as SceneTree
	var station: Node3D = GuardStationScript.new()
	station.name = "Gathering_%s" % kind
	station.kind = kind
	var home: Node = tree.current_scene if tree.current_scene != null else tree.root
	home.add_child(station)
	station.global_position = at
	var to := Vector3(look.x - at.x, 0.0, look.z - at.z)

	if to.length() > 0.01:
		station.global_basis = Basis.looking_at(to.normalized(), Vector3.UP)

	return station


## `apart` from `centre`, on the side `from` is on.
func _beside(centre: Vector3, from: Vector3, apart: float) -> Vector3:
	var side := Vector3(from.x - centre.x, 0.0, from.z - centre.z)
	side = side.normalized() if side.length() > 0.05 else Vector3.BACK
	return Vector3(centre.x, from.y, centre.z) + side * apart


func _nearest_fire(from: Vector3, reach: float) -> Node3D:
	var tree: SceneTree = _tree.get_ref() as SceneTree
	return _nearest_in(tree, &"fires", from, reach)


func _nearest_in(tree: SceneTree, group: StringName, from: Vector3, reach := INF) -> Node3D:
	var best: Node3D = null
	var near := reach

	for node in tree.get_nodes_in_group(group):
		var d := (node as Node3D).global_position.distance_to(from)

		if d < near:
			near = d
			best = node

	return best


## An `kind` station nobody holds, the nearest to `man`.
func _free_station(kind: StringName, man: Node) -> Node3D:
	var best: Node3D = null
	var near := INF

	for station in (_tree.get_ref() as SceneTree).get_nodes_in_group(&"guard_stations"):
		if StringName(station.kind) != kind or (station.holder != null and is_instance_valid(station.holder)):
			continue

		var d := (station as Node3D).global_position.distance_to((man as Node3D).global_position)

		if d < near:
			near = d
			best = station

	return best


func _here(man: Variant) -> bool:
	return man != null and is_instance_valid(man) and not (man as Node).is_queued_for_deletion() and man.get("_knocked_out") != true


func _is_captain(man: Node) -> bool:
	var sheet: Dictionary = TalkScript.library().get("cast", {})
	return TalkFacts.meets(TalkFacts.man(man, sheet), "captain", {}, {})


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
