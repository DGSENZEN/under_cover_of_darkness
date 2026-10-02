extends Node
## Level ambience loop in audio/ambience/<name>.ogg, selected by root ambience metadata.
## Default is interior_night; an empty name or missing file is silent. Sfx.warm() starts it; scene exit stops it.
## Real-time fades and Music intensity duck the loop. It emits no gameplay sound stimulus.

const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

const FOLDER := "res://audio/ambience/"
const DEFAULT := "interior_night"
## How loud the place is under everything else (dB).
const VOLUME_DB := -21.0
## Faded in over this long.
const FADE_IN := 2.5
## How far the place recedes (dB) as the fight's score rises to FIGHT_FULL.
const FIGHT_DIP := -9.0
const FIGHT_FULL := 0.6

var loop_name := ""
var _player: AudioStreamPlayer
var _fade := 0.0
var _last_real := -1.0


## Adds one Ambience node to the current scene (or tree root) from ambience metadata.
## Detached contexts, duplicate nodes, empty names, or missing OGG files are ignored.
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
	# Pressed down under the fight (Sfx's Ambience bus).
	_player.bus = &"Ambience" if AudioServer.get_bus_index(&"Ambience") >= 0 else &"Master"
	add_child(_player)
	_player.play()


func _process(_delta: float) -> void:
	if _player == null:
		return

	# Real time, not the game's: a hit-stop or slow motion does not dip it.
	var real := TimeFx.real_since(_last_real) if _last_real >= 0.0 else 0.0
	_last_real = TimeFx.real_time()
	_fade = minf(_fade + real / FADE_IN, 1.0)
	_player.volume_db = lerpf(-60.0, VOLUME_DB, sqrt(_fade)) + dip_for(_fight())


## Returns the additional ambience attenuation in dB for normalized score intensity (0 to FIGHT_DIP).
static func dip_for(intensity: float) -> float:
	return FIGHT_DIP * smoothstep(0.0, FIGHT_FULL, intensity)


func _fight() -> float:
	var music := get_parent().get_node_or_null("Music") if get_parent() != null else null
	return float(music.get("intensity")) if music != null and music.get("intensity") != null else 0.0


## Stops it for good: its stream let go of (leaving the level, tests).
func hush() -> void:
	if _player != null:
		_player.stop()
		_player.stream = null


func _exit_tree() -> void:
	hush()
