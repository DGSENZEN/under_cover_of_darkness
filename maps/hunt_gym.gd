extends Node3D
## The hunt gym: a lit kit room with a clue and a table, and a dark yard past
## its door to fight in (the hunts spec). Greybox, to judge the loop on. F5
## starts it again.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Lights := preload("res://scripts/Visual/Lights/Lights.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const SafePlace := preload("res://scripts/Hunt/SafePlace.gd")
const KitTable := preload("res://scripts/Hunt/KitTable.gd")
const MonsterScript := preload("res://scripts/Monsters/Monster.gd")

const STONE := Color(0.4, 0.38, 0.36)
const DARK := Color(0.22, 0.21, 0.23)
const WALL := 0.3
## The room: x and z half-sizes, and its height.
const ROOM := Vector3(5.0, 3.6, 4.0)
## Past this, you are in the yard.
const YARD_START := -5.0
const YARD := Rect2(-15.0, -36.0, 30.0, 32.0)
const YARD_HEIGHT := 6.0
## The beam to slide under: its middle on the floor, how wide, how clear.
const BEAM_AT := Vector3(10.0, 0.0, -20.0)
const BEAM_WIDTH := 5.0
const BEAM_CLEAR := 1.4
## What each kind's spawn is made of.
const KINDS := {&"floating_eye": MonsterScript}

var safe_place: Area3D
var kit_table: Node3D
var player: CharacterBody3D


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	SaveGame.begin_run(&"hunt_gym")
	_environment()
	_room()
	_yard()
	player = PLAYER.instantiate()
	add_child(player)
	player.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.05, 1.0))
	Props.give_revolver(player, 0, 0)
	player.inventory.select_by_id(&"revolver")
	safe_place = SafePlace.build(self, Vector3(0, ROOM.y * 0.5, 0), Vector3(ROOM.x * 2.0, ROOM.y, ROOM.z * 2.0))
	kit_table = KitTable.build(self, Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 2.8)))


## A monster of `kind` at `at`.
func spawn(kind: StringName, at: Vector3) -> Node3D:
	var monster: Node3D = KINDS[kind].new()
	monster.kind = kind
	add_child(monster)
	monster.global_position = at
	return monster


func _room() -> void:
	Props.block(self, Vector3(0, -0.5, -16), Vector3(44, 1, 60), DARK)
	var height := ROOM.y
	Props.block(self, Vector3(0, height + 0.1, 0), Vector3(ROOM.x * 2.0 + 0.6, 0.2, ROOM.z * 2.0 + 0.6), STONE)
	Props.block(self, Vector3(-ROOM.x - WALL * 0.5, height * 0.5, 0), Vector3(WALL, height, ROOM.z * 2.0), STONE)
	Props.block(self, Vector3(ROOM.x + WALL * 0.5, height * 0.5, 0), Vector3(WALL, height, ROOM.z * 2.0), STONE)
	Props.block(self, Vector3(0, height * 0.5, ROOM.z + WALL * 0.5), Vector3(ROOM.x * 2.0 + 0.6, height, WALL), STONE)
	# The door's wall: 2.2 m of door in the middle.
	var side := ROOM.x - 1.1
	Props.block(self, Vector3(-1.1 - side * 0.5, height * 0.5, -ROOM.z - WALL * 0.5), Vector3(side, height, WALL), STONE)
	Props.block(self, Vector3(1.1 + side * 0.5, height * 0.5, -ROOM.z - WALL * 0.5), Vector3(side, height, WALL), STONE)
	Props.block(self, Vector3(0, height - 0.5, -ROOM.z - WALL * 0.5), Vector3(2.2, 1.0, WALL), STONE)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 1.6
	lamp.omni_range = 9.0
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.global_position = Vector3(0, 3.0, 1.0)
	Props.readable(self, Transform3D(Basis.IDENTITY, Vector3(2.6, 1.6, -ROOM.z)), &"notice", "eye_clue")


func _yard() -> void:
	var left := YARD.position.x
	var right := YARD.end.x
	var far := YARD.position.y
	var near := YARD.end.y
	var middle := (left + right) * 0.5
	var across := (near + far) * 0.5
	Props.block(self, Vector3(left - 0.5, YARD_HEIGHT * 0.5, across), Vector3(1, YARD_HEIGHT, YARD.size.y), STONE)
	Props.block(self, Vector3(right + 0.5, YARD_HEIGHT * 0.5, across), Vector3(1, YARD_HEIGHT, YARD.size.y), STONE)
	Props.block(self, Vector3(middle, YARD_HEIGHT * 0.5, far - 0.5), Vector3(YARD.size.x + 2.0, YARD_HEIGHT, 1), STONE)
	# The near wall, either side of the room.
	for x in [(left - ROOM.x - WALL) * 0.5, (right + ROOM.x + WALL) * 0.5]:
		Props.block(self, Vector3(x, YARD_HEIGHT * 0.5, near - 0.15), Vector3(right - ROOM.x - WALL, YARD_HEIGHT, 0.3), STONE)

	for at in [Vector2(-7, -14), Vector2(7, -13), Vector2(0, -23), Vector2(-8, -29), Vector2(6, -30)]:
		Props.block(self, Vector3(at.x, 2.0, at.y), Vector3(1.4, 4.0, 1.4), STONE)

	# A low wall to mantle or to keep between you, and a ledge to get up on.
	Props.block(self, Vector3(-7, 0.6, -9), Vector3(5, 1.2, 0.5), STONE)
	Props.block(self, Vector3(-12, 1.0, -31), Vector3(5, 2.0, 5), STONE)
	# The beam, with a wall each side of it: only a crouch or a slide goes through.
	var clear := BEAM_CLEAR
	Props.block(self, BEAM_AT + Vector3(0, clear + 1.2, 0), Vector3(BEAM_WIDTH, 2.4, 1.0), STONE)
	Props.block(self, BEAM_AT + Vector3(-BEAM_WIDTH * 0.5 - 3.0, 1.8, 0), Vector3(6.0, 3.6, 1.0), STONE)
	Props.block(self, BEAM_AT + Vector3(BEAM_WIDTH * 0.5 + 1.25, 1.8, 0), Vector3(2.5, 3.6, 1.0), STONE)
	Lights.torch_at(self, Vector3(-14.5, 3.0, -18), 2.4, 10.0, true)
	Lights.torch_at(self, Vector3(14.5, 3.0, -28), 2.4, 10.0, true)


func _environment() -> void:
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	add_child(moon)
	moon.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	var environment := RetroScript.night_environment(Color(0.36, 0.4, 0.55), 0.3)
	environment.background_color = Color(0.03, 0.04, 0.07)
	environment.volumetric_fog_density = 0.025
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		get_tree().reload_current_scene()
