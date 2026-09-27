extends Node3D
## A playable gym for the interaction layer: doors, locks and keys, chests
## with loot, things to carry and throw. Built in code from Props so every
## piece is easy to read and copy.
##
##   Godot --path . res://maps/interaction_gym.tscn

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")


func _ready() -> void:
	# Everything below is placed after it is added: draw it from where it ends up.
	reset_physics_interpolation.call_deferred()
	_environment()
	Props.block(self, Vector3(10.0, -0.5, -8.0), Vector3(40.0, 1.0, 40.0), Color(0.22, 0.22, 0.24))

	# --- doors ---------------------------------------------------------------
	_sign(Vector3(0.0, 1.6, 2.0), "DOORS\nlook at a door, press E\nthey swing away from you\nthe second one is locked:\nthe key is on the pedestal")
	_wall_with_doorway(Vector3(0.0, 0.0, -4.0))
	Props.door(self, Vector3(-0.5, 0.0, -4.0))

	_wall_with_doorway(Vector3(5.0, 0.0, -4.0))
	Props.door(self, Vector3(4.5, 0.0, -4.0), 0.0, 1.0, 2.1, true, &"cellar", "cellar door")
	Props.block(self, Vector3(6.5, 0.3, -1.5), Vector3(0.4, 0.6, 0.4), Color(0.4, 0.4, 0.45))
	Props.key(self, Vector3(6.5, 0.62, -1.5), &"cellar", "cellar key")

	# --- chests --------------------------------------------------------------
	_sign(Vector3(10.0, 1.6, 2.0), "CHESTS\nopen the lid, look inside,\ntake the loot piece by piece\nthe locked one wants the\nkey from the first chest")
	Props.chest(self, Vector3(10.0, 0.0, -4.0))
	Props.loot(self, Vector3(9.8, 0.15, -4.0), 50, "goblet")
	Props.loot(self, Vector3(10.2, 0.15, -4.0), 120, "necklace")
	Props.key(self, Vector3(10.0, 0.15, -3.85), &"strongbox", "strongbox key")

	Props.chest(self, Vector3(13.0, 0.0, -4.0), 0.0, Vector3(0.7, 0.45, 0.45), true, &"strongbox", "strongbox")
	Props.loot(self, Vector3(13.0, 0.15, -4.0), 400, "jewelled crown")

	# a shelf with loot on it
	Props.block(self, Vector3(16.0, 1.0, -4.2), Vector3(1.6, 0.05, 0.4), Color(0.4, 0.3, 0.2))
	Props.loot(self, Vector3(15.6, 1.13, -4.2), 30, "candlestick")
	Props.loot(self, Vector3(16.4, 1.13, -4.2), 80, "silver plate")

	# --- carrying ------------------------------------------------------------
	_sign(Vector3(20.0, 1.6, 2.0), "CARRY & THROW\nE picks up a crate, E again\nsets it down, left click throws\nthe dark block is too heavy:\nE only shoves it\nyou cannot climb while carrying")
	Props.crate(self, Vector3(19.0, 0.3, -3.0))
	Props.crate(self, Vector3(20.0, 0.3, -3.0), 0.4, 3.0)
	Props.crate(self, Vector3(21.0, 0.2, -3.0), 0.3, 1.0, Color(0.7, 0.55, 0.3))
	Props.crate(self, Vector3(22.5, 0.4, -3.0), 0.8, 60.0, Color(0.3, 0.3, 0.35))
	Props.block(self, Vector3(20.0, 0.6, -8.0), Vector3(3.0, 1.2, 2.0), Color(0.5, 0.5, 0.52))

	# --- tools ---------------------------------------------------------------
	_sign(Vector3(-7.0, 1.9, 2.0), "YOUR HANDS\ntake the tools: they come to your off hand, then away\nmouse wheel: lower one, raise the next (or empty hands)\nloot goes into your purse; its tag tallies the total\nhold Tab to hold up your purse and key ring\na locked door you have the key for: the key turns first\nno key, but a lockpick: pick it (stay put a few seconds)\nclick: throw a flash bomb (blinds guards) or a water flask (puts out torches)")
	Props.block(self, Vector3(-7.0, 0.45, -3.0), Vector3(2.0, 0.9, 0.7), Color(0.4, 0.3, 0.2))
	Props.tool(self, Vector3(-7.6, 0.96, -3.0), &"flashbomb", "flash bomb", Color(0.3, 0.28, 0.26))
	Props.tool(self, Vector3(-7.0, 0.99, -3.0), &"lockpick", "lockpick", Color(0.6, 0.6, 0.65), "rod")
	Props.tool(self, Vector3(-6.4, 0.97, -3.0), &"waterflask", "water flask", Color(0.4, 0.6, 0.9), "flask", 3)

	var player := PLAYER.instantiate()
	player.debug_traversal = true
	add_child(player)
	player.global_position = Vector3(0.0, 1.05, 5.0)


func _wall_with_doorway(doorway: Vector3) -> void:
	# A wall with a 1 m by 2.1 m opening at `doorway` (the door's hinge foot
	# sits at doorway.x - 0.5).
	var color := Color(0.5, 0.48, 0.45)
	Props.block(self, doorway + Vector3(-1.75, 1.25, 0.0), Vector3(2.5, 2.5, 0.2), color)
	Props.block(self, doorway + Vector3(1.75, 1.25, 0.0), Vector3(2.5, 2.5, 0.2), color)
	Props.block(self, doorway + Vector3(0.0, 2.3, 0.0), Vector3(1.0, 0.4, 0.2), color)


func _sign(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.008
	label.modulate = Color(0.95, 0.9, 0.8)
	label.outline_size = 8
	add_child(label)
	label.global_position = at


func _environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.13, 0.17)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.65)
	environment.ambient_light_energy = 0.7

	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
