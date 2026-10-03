extends Node
## The city's memory across its districts (the old town's spec, section 3A),
## an autoload: each district's state as the player left it (DistrictState),
## what he carries through the gates (his health, purse, keys and belt), and
## the watchmen following him through one. Written when he leaves a
## district, applied after it is built when he comes back. Saving (the
## program's step 5) writes the same to disk: this is the save contract.

const DistrictStateScript := preload("res://scripts/Level/DistrictState.gd")

## A man chasing the player within this of a gate (flat, m) when he goes
## through it follows him.
const FOLLOW_RANGE := 30.0

## {district: DistrictState's state}
var districts := {}
## The player's save_state() as he went through the last gate; {} at the
## mission's start (the map gives him his starting kit).
var carried := {}
## The men following him through a gate: [{"spec", "to", "arrive", "delay"}].
var followers: Array = []


## A new mission: nothing remembered, nothing carried.
func begin() -> void:
	districts.clear()
	carried.clear()
	followers.clear()


## The player leaves `map` (a DistrictMap: district, made, guards, visitors,
## player) through `exit`: the district is remembered as he left it, and
## what he carries goes with him.
func leave(map: Node, exit: Area3D) -> void:
	districts[map.district] = DistrictStateScript.capture(map, map.made, map.guards, map.get("visitors") if map.get("visitors") != null else {})

	if map.player != null and is_instance_valid(map.player):
		carried = map.player.save_state()


## The player comes into `map`, just built: the district as he left it, what
## he carries in his hands.
func enter(map: Node) -> void:
	if districts.has(map.district):
		DistrictStateScript.apply(map, map.made, map.guards, districts[map.district], map.get("visitors") if map.get("visitors") != null else {})

	if not carried.is_empty() and map.player != null:
		map.player.load_state(carried)
