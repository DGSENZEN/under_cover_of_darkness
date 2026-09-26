extends Node
## The place, heard: a loop under everything, quiet (audio/ambience/, cut by
## tools/prepare_sfx.py). The level says which by a meta on its root node,
## "ambience": a loop's name ("interior_night", "cave", "forest_night", each
## also "_rain"), or "" for none. A level that does not say is indoors at
## night: a keep's stone around you.
##
## Started with the level (Sfx.warm), stopped with it. Only audio: guards
## hear nothing of it.

const FOLDER := "res://audio/ambience/"
const DEFAULT := "interior_night"
## How loud the place is under everything else (dB).
const VOLUME_DB := -21.0
## Faded in over this long.
const FADE_IN := 2.5

var loop_name := ""
var _player: AudioStreamPlayer
var _fade := 0.0


## Starts the level's ambience, once, if sound is on.
static func begin(context: Node) -> void:
	var tree := context.get_tree() if context != null and context.is_inside_tree() else null

	if tree == null or not Engine.get_main_loop() is SceneTree:
		return

	var level: Node = tree.current_scene if tree.current_scene != null else tree.root

	if level.has_node("Ambience"):
		return

	var wanted := String(level.get_meta(&"ambience", DEFAULT))

	if wanted == "" or not ResourceLoader.exists(FOLDER + wanted + ".ogg"):
		return

	var node: Node = (load("res://scripts/Audio/Ambience.gd") as GDScript).new()
	node.name = "Ambience"
	node.loop_name = wanted

	if level.is_node_ready():
		level.add_child(node)
	else:
		level.add_child.call_deferred(node)


func _ready() -> void:
	var stream := load(FOLDER + loop_name + ".ogg") as AudioStreamOggVorbis

	if stream == null:
		queue_free()
		return

	stream.loop = true
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.volume_db = -60.0
	add_child(_player)
	_player.play()


func _process(delta: float) -> void:
	if _player == null:
		return

	# Real time, not the game's: a hit-stop or slow motion does not dip it.
	_fade = minf(_fade + delta / maxf(Engine.time_scale, 0.05) / FADE_IN, 1.0)
	_player.volume_db = lerpf(-60.0, VOLUME_DB, sqrt(_fade))


func _exit_tree() -> void:
	if _player != null:
		_player.stop()
		_player.stream = null
