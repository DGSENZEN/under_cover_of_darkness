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
const EyeScript := preload("res://scripts/Monsters/FloatingEye.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const GUARD := preload("res://Guard.tscn")

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
const KINDS := {&"floating_eye": EyeScript}
## Each wave: how many eyes, and whether a man comes too. They are placed
## asleep from the start, so a save knows them.
const WAVES := [{"eyes": 3}, {"eyes": 5}, {"eyes": 6, "guard": true}]
## How long after one is cleared the next comes.
const WAVE_GAP := 5.0

var safe_place: Node3D
var kit_table: Node3D
var player: CharacterBody3D
## The wave under way (0: none yet), and what is in each.
var wave_now := 0
var _waves: Array = []
var _next_wave_in := -1.0


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	# A new run, unless this is a save being loaded into its own.
	if SaveGame.pending.is_empty():
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
	kit_table.show_for(player.loadout)
	player.loadout.changed.connect(kit_table.show_for.bind(player.loadout))
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	_lay_out_waves()
	SaveGame.register(self)


## A monster of `kind` at `at`.
func spawn(kind: StringName, at: Vector3) -> Node3D:
	var monster: Node3D = KINDS[kind].new()
	monster.kind = kind
	add_child(monster)
	monster.global_position = at
	return monster


func _lay_out_waves() -> void:
	var seed_value := 1

	for number in WAVES.size():
		var eyes: Array = []

		for i in int(WAVES[number]["eyes"]):
			var eye: Node3D = EyeScript.new()
			eye.seed_value = seed_value
			eye.name = "Eye%d" % seed_value
			seed_value += 1
			var turn := float(i) / float(WAVES[number]["eyes"]) * TAU
			eye.position = Vector3(cos(turn) * 8.0, 3.0, -24.0 + sin(turn) * 8.0)
			add_child(eye)
			eye.sleep()
			eyes.append(eye)

		_waves.append(eyes)


## Wave `number` (from 1) comes.
func wave(number: int) -> void:
	if number < 1 or number > _waves.size():
		return

	wave_now = number

	for eye in _waves[number - 1]:
		eye.wake()
		eye.state = eye.State.CIRCLE

	if WAVES[number - 1].get("guard", false) and is_inside_tree():
		var man: CharacterBody3D = GUARD.instantiate()
		add_child(man)
		man.global_position = Vector3(-10, 0.1, -32)


func _wave_cleared() -> bool:
	return wave_now > 0 and _waves[wave_now - 1].all(func(eye): return eye.dead)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.is_dead:
		return

	# Into the yard, the first time: they come.
	if wave_now == 0:
		if player.global_position.z <= YARD_START:
			wave(1)

		return

	if _next_wave_in >= 0.0:
		_next_wave_in -= delta

		if _next_wave_in < 0.0:
			wave(wave_now + 1)
	elif _wave_cleared() and wave_now < _waves.size():
		_next_wave_in = WAVE_GAP


func save_state() -> Dictionary:
	return {"wave_now": wave_now}


func load_state(state: Dictionary) -> void:
	wave_now = int(state.get("wave_now", 0))


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
	Lights.torch_at(self, Vector3(-14.5, 3.0, -33), 2.4, 10.0, true)
	Lights.torch_at(self, Vector3(14.5, 3.0, -9), 2.4, 10.0, true)
	Lights.torch_at(self, Vector3(-14.5, 3.0, -7), 2.4, 10.0, true)


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


## Ahead of Retro, which steps the pixel grid on F6 elsewhere.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_F5:
		get_tree().reload_current_scene()
	elif event.keycode == KEY_F6:
		wave(wave_now + 1)
		get_viewport().set_input_as_handled()
