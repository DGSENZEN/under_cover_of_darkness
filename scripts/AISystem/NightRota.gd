extends RefCounted
## The night at a garrison: its duties, its hour, and what the men need. One
## for each scene tree, and only where a level sets one up (`setup`: the
## showcase); elsewhere men keep the posts and rounds they were given.
##   duties  a post (where he stands), a round (a route he walks), stations
##           (his rota of GuardStations), the bench, a bed. `assign` puts a
##           man on one (Guard.take_duty); `swap` exchanges two men's.
##   hour    early, middle, late, dawn: it runs on game time, `hour_length`
##           seconds an hour (condensed for the showcase).
##   needs   tired, hungry, cold, each 0..1, for every man: tired grows
##           awake and falls asleep; hungry grows, and falls eating; cold
##           grows away from a fire and falls near one.
##   wants   a man on a post too long (post_turn), or worn out on it, wants
##           relieving; a man whose need has run full wants seeing to. They
##           are queued for whoever sees to them (Gathering: the watch
##           change, the bench, the bed, the fire), once until the need
##           eases.
## The alarm suspends it: needs still grow, but nobody is moved until the
## garrison is at its ease again.

const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")

## Guard.Alert.
const SEARCHING := 3
const COMBAT := 4

const HOURS := [&"early", &"middle", &"late", &"dawn"]
## A second of it, how much each need grows or falls.
const TIRED_RATE := 1.0 / 300.0
const SLEEP_RATE := 1.0 / 60.0
const HUNGRY_RATE := 1.0 / 240.0
const EAT_RATE := 1.0 / 40.0
const COLD_RATE := 1.0 / 180.0
const WARM_RATE := 1.0 / 30.0
## A fire this near warms him.
const FIRE_WARMTH := 5.0
## Roused past this, the rota waits.
const SUSPEND_ALARM := 0.3
## A want is not asked again until its need has eased below this.
const EASED := 0.8

static var _rotas := {}

## Game seconds since it was set up; seconds an hour; the hour it began at.
var clock := 0.0
var hour_length := 600.0
var _start := 0
## A man on a post this long wants relieving (s).
var post_turn := 600.0
## Whether a need run full asks for a man to be moved (off where a level
## wants each man to stay where it put him: its needs still grow).
var wants_rest := true

var _tree: WeakRef
var _frame := -1
## id -> {kind, data}.
var _duties := {}
## By man (instance id): his duty's id, and the man (weakref).
var _assigned := {}
var _men := {}
var _needs := {}
var _on_post := {}
var _wanted: Array = []
var _asked := {}


## Sets one up for `node`'s tree.
static func setup(node: Node, p_hour_length: float, start_hour := &"early") -> RefCounted:
	var rota: RefCounted = (load("res://scripts/AISystem/NightRota.gd") as GDScript).new()
	rota.hour_length = maxf(p_hour_length, 1.0)
	rota._start = maxi(HOURS.find(start_hour), 0)
	rota._tree = weakref(node.get_tree())
	_rotas[node.get_tree().get_instance_id()] = rota
	return rota


## The rota of `node`'s tree; null if none was set up.
static func of(node: Node) -> RefCounted:
	if node == null or not node.is_inside_tree():
		return null

	return _rotas.get(node.get_tree().get_instance_id())


static func clear_all() -> void:
	_rotas.clear()


func add_duty(id: StringName, kind: StringName, data: Dictionary) -> void:
	_duties[id] = {"kind": kind, "data": data}


## `man` on duty `id` (he goes to it now).
func assign(man: Node, id: StringName) -> void:
	if not _duties.has(id) or man == null or not is_instance_valid(man):
		return

	var key := man.get_instance_id()
	_assigned[key] = id
	_men[key] = weakref(man)
	_on_post[key] = 0.0
	man.take_duty(_duties[id])


func duty_of(man: Node) -> StringName:
	return _assigned.get(man.get_instance_id(), &"")


func kind_of(id: StringName) -> StringName:
	return StringName((_duties.get(id, {}) as Dictionary).get("kind", &""))


## The men on duty `id`.
func men_on(id: StringName) -> Array:
	var found := []

	for key in _assigned:
		var man: Variant = (_men[key] as WeakRef).get_ref()

		if _assigned[key] == id and man != null and is_instance_valid(man):
			found.append(man)

	return found


## A duty of `kind` nobody is on; &"" if every one is taken.
func free_duty(kind: StringName) -> StringName:
	for id in _duties:
		if kind_of(id) == kind and men_on(id).is_empty():
			return id

	return &""


## The two men's duties exchanged.
func swap(a: Node, b: Node) -> void:
	var duty_a := duty_of(a)
	var duty_b := duty_of(b)

	if duty_b != &"":
		assign(a, duty_b)

	if duty_a != &"":
		assign(b, duty_a)


func hour() -> StringName:
	return HOURS[clampi(_start + int(clock / hour_length), 0, HOURS.size() - 1)]


## {tired, hungry, cold}, each 0..1.
func needs_of(man: Node) -> Dictionary:
	var key := man.get_instance_id()

	if not _needs.has(key):
		_needs[key] = {"tired": 0.0, "hungry": 0.0, "cold": 0.0}

	return _needs[key]


## Tests: a need set.
func set_need(man: Node, need: StringName, value: float) -> void:
	needs_of(man)[String(need)] = clampf(value, 0.0, 1.0)


## How long he has stood the post he is on (s).
func on_post_for(man: Node) -> float:
	return float(_on_post.get(man.get_instance_id(), 0.0))


## Once a physics frame, whoever calls.
func tick(delta: float) -> void:
	var frame := Engine.get_physics_frames()

	if frame == _frame:
		return

	_frame = frame
	clock += delta
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	if tree == null:
		return

	var fires: Array = tree.get_nodes_in_group(&"fires")
	var waiting := suspended()

	for man in tree.get_nodes_in_group(&"guards"):
		if not is_instance_valid(man) or man.get("_knocked_out") == true or man.get("puppet") == true:
			continue

		_grow(man, delta, fires)

		if not waiting:
			_ask(man)


## The men's needs wait for the garrison to be at its ease.
func suspended() -> bool:
	var tree: SceneTree = _tree.get_ref() as SceneTree if _tree != null else null

	if tree == null:
		return false

	var target := tree.get_first_node_in_group(&"player") as Node3D

	if target != null:
		var garrison: RefCounted = GarrisonScript.of(target)

		if garrison != null and float(garrison.alarm) >= SUSPEND_ALARM:
			return true

	for man in tree.get_nodes_in_group(&"guards"):
		var state := int(man.get("state"))

		if state == SEARCHING or state == COMBAT:
			return true

	return false


## Whether he has asked for `what` ("relief", or a need: "tired", "hungry",
## "cold") and it has not eased since (whoever took it up).
func asked(man: Node, what: StringName) -> bool:
	return _asked.has("%d:%s" % [man.get_instance_id(), what])


## What is waiting to be seen to (a peek).
func wanted() -> Array:
	return _wanted


## What is waiting to be seen to, taken (the one who takes it sees to it).
func take_wanted() -> Array:
	var taken := _wanted
	_wanted = []
	return taken


func _grow(man: Node, delta: float, fires: Array) -> void:
	var needs := needs_of(man)
	var rota: RefCounted = man.get("_rota")
	var asleep: bool = rota != null and rota.asleep()
	var eating: bool = rota != null and rota.activity() == &"eat"
	var warm := false

	for fire in fires:
		if (fire as Node3D).global_position.distance_to((man as Node3D).global_position) <= FIRE_WARMTH:
			warm = true
			break

	needs["tired"] = clampf(float(needs["tired"]) + (-SLEEP_RATE if asleep else TIRED_RATE) * delta, 0.0, 1.0)
	needs["hungry"] = clampf(float(needs["hungry"]) + (-EAT_RATE if eating else HUNGRY_RATE) * delta, 0.0, 1.0)
	needs["cold"] = clampf(float(needs["cold"]) + (-WARM_RATE if warm else COLD_RATE) * delta, 0.0, 1.0)
	var key := man.get_instance_id()
	_on_post[key] = float(_on_post.get(key, 0.0)) + delta if kind_of(duty_of(man)) == &"post" else 0.0


## His wants, queued once until they ease.
func _ask(man: Node) -> void:
	var key := man.get_instance_id()
	var needs := needs_of(man)
	var on_post := kind_of(duty_of(man)) == &"post"

	if on_post and (on_post_for(man) > post_turn or float(needs["tired"]) >= 1.0):
		_want(key, &"relief", {"kind": &"relief", "man": man, "duty": duty_of(man)})
	else:
		_asked.erase("%d:relief" % key)

	for need in ["tired", "hungry", "cold"]:
		if float(needs[need]) >= 1.0 and not on_post and wants_rest and kind_of(duty_of(man)) != &"round":
			_want(key, StringName(need), {"kind": &"rest", "man": man, "need": StringName(need)})
		elif float(needs[need]) < EASED:
			_asked.erase("%d:%s" % [key, need])


func _want(key: int, what: StringName, want: Dictionary) -> void:
	var asked := "%d:%s" % [key, what]

	if _asked.has(asked):
		return

	_asked[asked] = true
	_wanted.append(want)
