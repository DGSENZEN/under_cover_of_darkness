extends Node
## The city's memory across its districts (the old town's spec, section 3A),
## an autoload: each district's state as the player left it (DistrictState),
## what he carries through the gates (his health, purse, keys and belt), and
## the watchmen following him through one. Written when he leaves a
## district, applied after it is built when he comes back. Saving (the
## program's step 5) writes the same to disk: this is the save contract.

const DistrictStateScript := preload("res://scripts/Level/DistrictState.gd")

const LevelGameplayScript := preload("res://scripts/Level/LevelGameplay.gd")
const JobStateScript := preload("res://scripts/Level/JobState.gd")

## A man chasing the player within this of a gate (flat, m) when he goes
## through it follows him; he comes through this far behind the player's
## arrival (m).
const FOLLOW_RANGE := 30.0
const BEHIND := 1.5
## Guard.Alert.SEARCHING and COMBAT; the guard scene a follower is made from.
const SEARCHING := 3
const COMBAT := 4
const GUARD_SCENE := "res://Guard.tscn"

## {district: DistrictState's state}
var districts := {}
## The player's save_state() as he went through the last gate; {} at the
## mission's start (the map gives him his starting kit).
var carried := {}
## The men following him through a gate: [{"spec", "to", "arrive", "delay"}].
var followers: Array = []
## What he has done of the job (JobState: goals, notes, readables, the
## districts' facts and tallies).
var job: RefCounted = JobStateScript.new()


## A new mission: nothing remembered, nothing carried.
func begin() -> void:
	districts.clear()
	carried.clear()
	followers.clear()
	job.reset()


## The player leaves `map` (a DistrictMap: district, made, guards, visitors,
## player) through `exit`: the district is remembered as he left it, what he
## carries goes with him, and every man after him (fighting him, up, within
## FOLLOW_RANGE of the gate) follows him through: away from this district,
## arriving on the far side as long after him as his run takes.
func leave(map: Node, exit: Area3D) -> void:
	var state := DistrictStateScript.capture(map, map.made, map.guards, map.visitors)
	var gate := exit.global_position

	# Men remembered down or away before: the map put them down again (or
	# never made them), and no longer lists them; still down, still away.
	var before: Dictionary = districts.get(map.district, {}).get("guards", {})

	for guard_name in before:
		if not state["guards"].has(guard_name) and (before[guard_name].has("down") or before[guard_name].has("away")):
			state["guards"][guard_name] = before[guard_name]

	# Men still on their way in behind the player, who has gone again first:
	# they come through to find him gone and wait at the arrival, searching;
	# in their own district, as its own men again.
	for follower in followers.filter(func(f): return StringName(f["to"]) == map.district):
		followers.erase(follower)
		var at := _arrival(map, follower)
		var waiting := {"transform": at, "state": SEARCHING, "alert": 60.0, "has_last_known": true, "last_known": at.origin}
		var follower_name := String(follower["spec"]["name"])

		if (state["guards"].get(follower_name, {}) as Dictionary).has("away"):
			state["guards"][follower_name] = waiting
		else:
			state["visitors"][follower_name] = {"spec": follower["spec"], "state": waiting}

	for guard_name in map.guards:
		var g: Variant = map.guards[guard_name]

		if not _after(g, map.player):
			continue

		var run := Vector2(g.global_position.x - gate.x, g.global_position.z - gate.z).length()

		if run > FOLLOW_RANGE:
			continue

		followers.append({"spec": g.spec(), "to": StringName(exit.get_meta(&"to", &"")), "arrive": StringName(exit.get_meta(&"arrive", &"")),
			"delay": run / maxf(float(g.get("chase_speed")), 0.1)})

		if state["visitors"].has(guard_name):
			state["visitors"].erase(guard_name)
		else:
			state["guards"][guard_name] = {"away": true}

	districts[map.district] = state
	job.leave(map.district)

	if map.player != null and is_instance_valid(map.player):
		carried = map.player.save_state()


## The player comes into `map`, just built: the district as he left it, what
## he carries in his hands, and the men following him, each through the gate
## behind him in his own time.
func enter(map: Node) -> void:
	if districts.has(map.district):
		DistrictStateScript.apply(map, map.made, map.guards, districts[map.district], map.visitors)

	if not carried.is_empty() and map.player != null:
		map.player.load_state(carried)

	for follower in followers.filter(func(f): return StringName(f["to"]) == map.district):
		_follow(map, follower)


## Up, fighting, and fighting `player`.
func _after(g: Variant, player: Node) -> bool:
	return g != null and is_instance_valid(g) and not bool(g.get("_knocked_out")) and int(g.get("state")) == COMBAT and g.get("_target") == player


## Where a follower comes through into `map`: a pace behind the player's
## arrival.
func _arrival(map: Node, follower: Dictionary) -> Transform3D:
	var at: Transform3D = map.marker(String(follower["arrive"])).get("transform", Transform3D())
	at.origin += at.basis.z * BEHIND
	return at


## A man following the player into `map`: through the gate `delay` s after
## him, a pace behind his arrival, made again from his spec and after him; a
## visitor here, or (coming home, away in its memory) the district's own
## man again. Pending until then: if the player leaves first, `leave` puts
## him there instead.
func _follow(map: Node, follower: Dictionary) -> void:
	await map.get_tree().create_timer(float(follower["delay"]), false).timeout

	if not followers.has(follower):
		return

	followers.erase(follower)

	if not is_instance_valid(map) or not map.is_inside_tree():
		return

	var spec: Dictionary = follower["spec"]
	var follower_name := String(spec["name"])
	var home: bool = (districts.get(map.district, {}).get("guards", {}).get(follower_name, {}) as Dictionary).has("away")
	var g := LevelGameplayScript.visitor(map, spec, _arrival(map, follower), load(GUARD_SCENE) as PackedScene)
	map.guards[follower_name] = g

	if not home:
		map.visitors[follower_name] = spec

	await map.get_tree().physics_frame

	if is_instance_valid(g) and map.player != null and is_instance_valid(map.player):
		g._engage(map.player)
