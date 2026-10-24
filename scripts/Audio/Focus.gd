extends Node
## The mix's one say over what is heard when many things sound at once (docs/superpowers/specs/2026-10-24-
## underground-sound-layers-design.md). Every looping source is held here with its tier and its own level now; every
## EVERY s the audible ones of each tier are ranked by how loud they arrive, and the first few of each (TIERS) play
## at their level while the rest sink, eased, by up to SINK. One-shots ask first (allow): only a few of a tier in
## any WINDOW. While something featured sounds near you, the loops and details dip under it. A scene-owned node,
## made on demand as Sfx's is; counted with sound off too.

## How many of each tier play at full; how many one-shots of a tier in any WINDOW (s); how far the rest sink (dB),
## how long that takes (s); how often they are ranked (s); the dip under a featured sound (dB), within how far of you
## (m), and how fast it comes and goes (dB/s).
const TIERS := {&"bed": 1, &"loop": 3, &"detail": 4, &"featured": 2}
const SHOTS := {&"detail": 3, &"featured": 2}
const WINDOW := 2.0
const SINK := -12.0
const EASE := 1.0
const EVERY := 0.2
const DIP := -3.0
const DIP_NEAR := 8.0
const DIP_RATE := 20.0
## How much louder a source must arrive than one playing at full to take its place (so near-equals passing each other,
## a corridor of drifting books, do not swap back and forth and pump).
const HOLD := 1.4

## Each held source: {player, tier, base, priority, duck, full}.
static var _held: Array = []
## When each tier's last one-shots were let through (on the clock below).
static var _shots := {}
## The featured sounds playing: [where, until].
static var _features: Array = []
static var _clock := 0.0
static var _dip := 0.0
static var _rank_in := 0.0
static var _node: Node = null


## Holds `player`: from now on its volume is `base_db` (base) plus its duck and the dip.
static func hold(context: Node, player: AudioStreamPlayer3D, tier: StringName, base_db: float, priority := 1.0) -> void:
	_node_for(context)
	_held.append({"player": player, "tier": tier, "base": base_db, "priority": priority, "duck": 0.0, "full": true})
	player.volume_db = base_db


## The source's own level now (a neon's flicker, a wall between).
static func base(player: AudioStreamPlayer3D, db: float) -> void:
	for entry: Dictionary in _held:
		if entry["player"] == player:
			entry["base"] = db
			return


## Whether a one-shot of `tier` at `at` may play now (tiers not in SHOTS always may).
static func allow(context: Node, tier: StringName, _at: Vector3) -> bool:
	_node_for(context)

	if not SHOTS.has(tier):
		return true

	var recent: Array = _shots.get(tier, []).filter(func(t: float) -> bool: return _clock - t < WINDOW)

	if recent.size() >= int(SHOTS[tier]):
		_shots[tier] = recent
		return false

	recent.append(_clock)
	_shots[tier] = recent
	return true


## Something featured sounds at `at` for `length` s: the loops and details dip under it while it does.
static func featured(context: Node, at: Vector3, length: float) -> void:
	_node_for(context)
	_features.append([at, _clock + length])


## A held player's own level now (dB).
static func base_of(player: AudioStreamPlayer3D) -> float:
	for entry: Dictionary in _held:
		if entry["player"] == player:
			return entry["base"]

	return 0.0


## A held player's duck now (dB).
static func duck_of(player: AudioStreamPlayer3D) -> float:
	for entry: Dictionary in _held:
		if entry["player"] == player:
			return entry["duck"]

	return 0.0


static func held_count() -> int:
	return _held.size()


## Indices of `entries` ({at, priority, reach}) most audible from `ear` first, those past their reach left out.
static func rank(entries: Array, ear: Vector3) -> Array:
	var order := []

	for i in entries.size():
		if (entries[i]["at"] as Vector3).distance_to(ear) <= float(entries[i]["reach"]):
			order.append(i)

	var heard := func(i: int) -> float:
		return float(entries[i]["priority"]) / maxf((entries[i]["at"] as Vector3).distance_to(ear), 1.0)
	order.sort_custom(func(a: int, b: int) -> bool: return heard.call(a) > heard.call(b))
	return order


## Lets go of everything (between tests, or a level left).
static func reset() -> void:
	_held.clear()
	_shots.clear()
	_features.clear()
	_clock = 0.0
	_dip = 0.0
	_rank_in = 0.0


static func _node_for(context: Node) -> Node:
	if _node != null and is_instance_valid(_node) and not _node.is_queued_for_deletion():
		return _node

	if context == null or not context.is_inside_tree():
		return null

	var tree := context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var node: Node = (load("res://scripts/Audio/Focus.gd") as GDScript).new()
	node.name = "Focus"

	if parent.is_node_ready():
		parent.add_child(node)
	else:
		parent.add_child.call_deferred(node)

	_node = node
	return node


func _process(delta: float) -> void:
	_clock += delta
	_held = _held.filter(func(e: Dictionary) -> bool: return is_instance_valid(e["player"]) and e["player"].is_inside_tree())
	var camera := get_viewport().get_camera_3d()
	var ear := camera.global_position if camera != null else Vector3.ZERO
	_rank_in -= delta

	if _rank_in <= 0.0:
		_rank_in = EVERY
		_rank(ear)

	# The dip, while something featured plays near.
	_features = _features.filter(func(f: Array) -> bool: return f[1] > _clock)
	var near := _features.any(func(f: Array) -> bool: return (f[0] as Vector3).distance_to(ear) <= DIP_NEAR)
	_dip = move_toward(_dip, DIP if near else 0.0, DIP_RATE * delta)

	for entry: Dictionary in _held:
		entry["duck"] = move_toward(entry["duck"], 0.0 if entry["full"] else SINK, -SINK / EASE * delta)
		var dip := _dip if entry["tier"] in [&"loop", &"detail"] else 0.0
		entry["player"].volume_db = entry["base"] + entry["duck"] + dip


## Each tier's first few (by how loud they arrive: priority, their own level now, distance; those at full already
## holding on by HOLD) at full; the rest sink.
func _rank(ear: Vector3) -> void:
	for tier: StringName in TIERS:
		var of_tier := _held.filter(func(e: Dictionary) -> bool: return e["tier"] == tier)
		var entries := of_tier.map(func(e: Dictionary) -> Dictionary:
			var player: AudioStreamPlayer3D = e["player"]
			var holding := HOLD if e["full"] else 1.0
			return {"at": player.global_position, "priority": float(e["priority"]) * db_to_linear(e["base"]) * holding,
				"reach": player.max_distance})
		var order := rank(entries, ear)

		for i in of_tier.size():
			of_tier[i]["full"] = order.find(i) in range(int(TIERS[tier]))


func _exit_tree() -> void:
	if _node == self:
		_node = null
