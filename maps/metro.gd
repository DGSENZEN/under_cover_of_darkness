extends Node3D
## The Metro Underground (docs/superpowers/specs/2026-10-16-metro-underground-
## design.md), its greybox: the plan (assets/eclipse/metro/plan.json) as
## plain blocks to walk (greybox.json, from tools/level/level.sh metro), lit
## dim: a sodium lamp at every sign and every scene, a dark environment. The
## player arrives on the north platform, where the car's doors will open.
## F1 labels the spaces, the scenes (with their causes) and the character
## places near.

const PLAYER := preload("res://Player.tscn")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const PLAN := "res://assets/eclipse/metro/plan.json"
const GREYBOX := "res://assets/eclipse/metro/greybox.json"
## A sodium work lamp (about 2000 K).
const SODIUM := Color(1.0, 0.62, 0.3)
const LAMP_ENERGY := 2.0
const LAMP_RANGE := 14.0
## The lamp hangs this high over the landmark's floor (m).
const LAMP_HEIGHT := 2.6
## Labels are seen within this (m).
const LABEL_RANGE := 30.0
## The built sets standing in for their spaces' greybox: {set: [its scene, the spaces whose greybox it takes over]}.
## Each is set in with standalone off (no stubs of its own; the map's player) at its PLAN_ORIGIN.
const SETS := {"candle_lane": ["res://maps/candle_lane.tscn", ["candle_lane", "librarian_shop"]]}

var plan: Dictionary
var greybox: GreyboxLoader
var player: CharacterBody3D
var world: WorldEnvironment
## The lamps, one per sign and scene.
var lamps: Array[OmniLight3D] = []


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	plan = JSON.parse_string(FileAccess.get_file_as_string(PLAN))
	var taken := []
	for set_name in SETS:
		taken += SETS[set_name][1]
	greybox = GreyboxLoader.build(JSON.parse_string(FileAccess.get_file_as_string(GREYBOX)), taken)
	add_child(greybox)
	_lights()
	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = spawn_point() + Vector3(0, 1.05, 0)
	# Facing the stairwell's door along the platform (west).
	player.rotation.y = PI / 2
	_sets()


## The built sets in their places, the map's player theirs.
func _sets() -> void:
	for set_name in SETS:
		var built: Node3D = (load(SETS[set_name][0]) as PackedScene).instantiate()
		built.name = set_name
		built.standalone = false
		built.host_player = player
		built.position = built.PLAN_ORIGIN
		add_child(built)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_labels(get_node_or_null("labels") == null)


## Where the player arrives: the arrival landmark, on the platform's floor.
func spawn_point() -> Vector3:
	for m in plan["landmarks"]:
		if m["kind"] == "arrival":
			return Vector3(m["at"][0], m["at"][1], m["at"][2])

	return Vector3.ZERO


## The plan's landmarks of one kind.
func landmarks(kind: String) -> Array:
	return plan["landmarks"].filter(func(m): return m["kind"] == kind)


func _lights() -> void:
	var environment := RetroScript.night_environment(Color(0.42, 0.4, 0.5), 0.35)
	environment.background_color = Color(0.01, 0.01, 0.015)
	world = WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	for m in landmarks("sign") + landmarks("scene"):
		var lamp := OmniLight3D.new()
		lamp.name = "lamp_" + String(m["name"])
		lamp.light_color = SODIUM
		lamp.light_energy = LAMP_ENERGY
		lamp.omni_range = LAMP_RANGE
		lamp.shadow_enabled = false
		lamp.position = Vector3(m["at"][0], m["at"][1] + LAMP_HEIGHT, m["at"][2])
		add_child(lamp)
		lamps.append(lamp)


## The labels (F1): every space's name and layer at its middle, every scene
## with its cause and every character place with who keeps it; off again.
func _labels(on: bool) -> void:
	var old := get_node_or_null("labels")

	if old:
		old.free()

	if not on:
		return

	var group := Node3D.new()
	group.name = "labels"
	add_child(group)

	for s in plan["spaces"]:
		var middle := Vector2.ZERO

		for p in s["polygon"]:
			middle += Vector2(p[0], p[1])

		middle /= s["polygon"].size()
		_label(group, "%s (layer %d)" % [s["name"], s["layer"]], Vector3(middle.x, s["floor"] + 2.0, middle.y))

	for m in landmarks("scene"):
		_label(group, "%s — %s" % [m["name"], m["props"]["cause"]], Vector3(m["at"][0], m["at"][1] + 2.2, m["at"][2]))

	for m in landmarks("character_place"):
		_label(group, "%s: %s" % [m["name"], m["props"]["who"]], Vector3(m["at"][0], m["at"][1] + 1.8, m["at"][2]))


func _label(group: Node3D, text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.width = 900.0
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.visibility_range_end = LABEL_RANGE
	label.position = at
	group.add_child(label)
