extends Node3D
## The mission (the old town's spec, section 3A): the game's way through the
## city, one district's map at a time. It holds the map in hand and, at a
## gate, swaps it for the next: the screen goes dark, the district is
## remembered as the player leaves it (CityState), the next map is built
## with him at its arrival, and it comes up again.
##   Godot --path . res://maps/mission.tscn

const Districts := preload("res://scripts/Level/Districts.gd")

## The screen goes dark, and comes up again, over this long (s).
const FADE := 0.3
## Exits ignore the player this long after he arrives (DistrictMap.GRACE).
const GRACE := 1.0

## A map is ready and the player in it, the screen up again.
signal arrived(district: StringName)

## The district's map in hand.
var map: Node = null
## No gate is being gone through.
var settled := false
var _veil: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 99
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color(0.0, 0.0, 0.0, 0.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_veil)
	CityState.begin()
	go(StringName(Districts.registry()["start"]))


## Into `district`'s map, the player at `arrival` (its spawn when empty):
## dark, the map in hand freed, the next built, then up again.
func go(district: StringName, arrival := &"") -> void:
	settled = false
	await _fade(1.0)

	if map != null and is_instance_valid(map):
		map.queue_free()
		await get_tree().process_frame

	map = (load(String(Districts.entry(district)["map"])) as PackedScene).instantiate()
	map.arrival = arrival
	add_child(map)
	await map.ready_to_play
	await _fade(0.0)
	settled = true
	arrived.emit(district)


## Through `exit` (an exit Area3D of the map in hand, its `to` a built
## district): what the player holds or carries is set down at the gate, the
## district remembered as he leaves it, and on to the arrival there.
func travel(exit: Area3D) -> void:
	if not settled or map == null:
		return

	settled = false

	if map.player != null and map.player.get("frob") != null:
		map.player.frob.drop_held()
		map.player.frob.put_page_away()

	CityState.leave(map, exit)
	go(StringName(exit.get_meta(&"to")), StringName(exit.get_meta(&"arrive", &"")))


func _fade(to: float) -> void:
	var tween := create_tween()
	tween.tween_property(_veil, "color:a", to, FADE)
	await tween.finished
