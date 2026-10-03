extends Node3D
## Fixture gallery for light states, wind, corona occlusion and carried-light motion.
## L cycles light states, K changes wind, J toggles coronas and H changes fuel.
## Run res://maps/lights_gallery.tscn with -- --verbose for timing and asset diagnostics.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const Lights := preload("res://scripts/Visual/Lights/Lights.gd")
const Materials := preload("res://scripts/Visual/Materials.gd")
const LightFixture := preload("res://scripts/Visual/Lights/LightFixture.gd")

const STONE_ROAD := preload("res://maps/test_stone_road.png")
const STONE_WEATHERED := preload("res://maps/test_stone_weathered.png")
const BRICK := preload("res://textures/stone_brick_1.png")
const MOSS := preload("res://textures/mossy_rock_1.png")
const WOOD := preload("res://textures/wood_1.png")

## The hall inside: x -20..20, z -6..6, 6 m high; the bays are 10 m wide,
## their walls stopping at z 1.5 to leave a walk along the south wall.
const BAYS := [-15.0, -5.0, 5.0, 15.0]
const BAY_NAMES := ["TORCHES", "LANTERNS", "CANDLES AND LAMPS", "OPEN FIRES"]
const WALK_FROM := 1.5
## The L key's turn: what every light does at each press.
const CYCLE := [&"snuff", &"kindle", &"douse", &"kindle"]
## The K key's winds (from the east), and the H key's fire strengths.
const WINDS := [0.0, 0.4, 1.0]
const STRENGTHS := [1.0, 0.3]
const DOOR_EVERY := 6.0
const REPORT_EVERY := 5.0

var player: CharacterBody3D
var doors: Array[Node3D] = []
var _cycle := 0
var _wind := 0
var _strength := 0
var _coronas := true
var _verbose := false
var _report_in := REPORT_EVERY
var _report_frames := 0


func _ready() -> void:
	# Everything below is placed after it is added: draw it from where it ends up.
	reset_physics_interpolation.call_deferred()
	_verbose = OS.get_cmdline_user_args().has("--verbose")
	_hall()
	_environment()
	_torches(BAYS[0])
	_lanterns(BAYS[1])
	_candles(BAYS[2])
	_fires(BAYS[3])

	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	for i in BAYS.size():
		_watchmen(i, BAYS[i])
		_sign(Vector3(BAYS[i], 3.6, WALK_FROM - 0.3), 0.0, "%s\nL  lit / snuffed / lit / doused\nK  wind: off / gentle / strong\nJ  halos on / off\nH  fires low / high" % BAY_NAMES[i])

	var timer := Timer.new()
	timer.wait_time = DOOR_EVERY
	timer.autostart = true
	timer.timeout.connect(_swing_doors)
	add_child(timer)

	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = Vector3(-19.4, 1.05, 4.1)
	player.rotation.y = -PI * 0.5

	if _verbose:
		print("lights gallery: slots drawn in flat colour (no photo): %s" % [Materials.fallbacks()])


func _process(delta: float) -> void:
	# Held on every light, those lit since (the watchmen's) too.
	var air := Vector3(-float(WINDS[_wind]), 0.0, 0.0)

	for burner in burners():
		burner.lean(air)

		if burner.corona != null:
			burner.corona.visible = _coronas

	if _verbose:
		_report_frames += 1
		_report_in -= delta

		if _report_in <= 0.0:
			print("lights gallery: %.2f ms a frame" % (1000.0 * (REPORT_EVERY - _report_in) / maxf(_report_frames, 1)))
			_report_in = REPORT_EVERY
			_report_frames = 0


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey or not event.pressed or event.echo:
		return

	match (event as InputEventKey).physical_keycode:
		KEY_L:
			cycle_lights()
		KEY_K:
			_wind = (_wind + 1) % WINDS.size()
		KEY_J:
			_coronas = not _coronas
		KEY_H:
			_strength = (_strength + 1) % STRENGTHS.size()

			for burner in burners():
				if burner.flicker_kind == &"brazier" or burner.flicker_kind == &"fire":
					burner.set_strength(STRENGTHS[_strength])


## Returns descendant nodes in the torches group, including watchmen's lights.
func burners() -> Array[Node3D]:
	var found: Array[Node3D] = []

	for burner in get_tree().get_nodes_in_group(&"torches"):
		if is_ancestor_of(burner):
			found.append(burner)

	return found


## Advances descendant fixtures through the lit/snuffed/doused cycle (the L key).
func cycle_lights() -> void:
	var step: StringName = CYCLE[_cycle % CYCLE.size()]
	_cycle += 1

	for burner in burners():
		if step == &"kindle":
			burner.kindle()
		else:
			burner.put_out(step)


func _swing_doors() -> void:
	for door in doors:
		if is_instance_valid(door):
			door.frob(self)


# The hall

func _hall() -> void:
	_brush(Vector3(0, -0.25, 0), Vector3(40.8, 0.5, 12.8), STONE_ROAD, 2.0)
	_brush(Vector3(0, 6.25, 0), Vector3(40.8, 0.5, 12.8), WOOD, 2.0, "wood")
	_brush(Vector3(0, 3, -6.2), Vector3(40.8, 6, 0.4), BRICK, 2.0)
	_brush(Vector3(0, 3, 6.2), Vector3(40.8, 6, 0.4), BRICK, 2.0)
	_brush(Vector3(20.2, 3, 0), Vector3(0.4, 6, 12.8), STONE_WEATHERED, 2.5)

	# The west wall, its door into a closet (the way you came in).
	_brush(Vector3(-20.2, 3, -1.25), Vector3(0.4, 6, 9.5), BRICK, 2.0)
	_brush(Vector3(-20.2, 3, 5.25), Vector3(0.4, 6, 1.5), BRICK, 2.0)
	_brush(Vector3(-20.2, 4.05, 4.0), Vector3(0.4, 3.9, 1.0), BRICK, 2.0)
	_brush(Vector3(-21.2, -0.25, 4.0), Vector3(1.6, 0.5, 2.4), STONE_ROAD, 2.0)
	_brush(Vector3(-21.2, 2.35, 4.0), Vector3(1.6, 0.3, 2.4), WOOD, 2.0, "wood")
	_brush(Vector3(-22.2, 1.1, 4.0), Vector3(0.4, 2.2, 2.4), BRICK, 2.0)

	for z in [2.6, 5.4]:
		_brush(Vector3(-21.2, 1.1, z), Vector3(1.6, 2.2, 0.4), BRICK, 2.0)

	doors.append(Props.door(self, Vector3(-20.2, 0, 3.5), -PI * 0.5))

	# Walls between the bays, each with a door near the back.
	for x in [-10.0, 0.0, 10.0]:
		_brush(Vector3(x, 3, -5.5), Vector3(0.4, 6, 1.0), BRICK, 2.0)
		_brush(Vector3(x, 3, (-4.0 + WALK_FROM) * 0.5), Vector3(0.4, 6, WALK_FROM + 4.0), BRICK, 2.0)
		_brush(Vector3(x, 4.05, -4.5), Vector3(0.4, 3.9, 1.0), BRICK, 2.0)
		doors.append(Props.door(self, Vector3(x, 0, -5.0), -PI * 0.5))

	# A pillar in each bay, to pass behind.
	for x in BAYS:
		_brush(Vector3(x, 3, -2.5), Vector3(0.7, 6, 0.7), MOSS, 1.5)


func _environment() -> void:
	var world := WorldEnvironment.new()
	world.environment = RetroScript.night_environment()
	add_child(world)


# The bays

func _torches(x: float) -> void:
	# Two sconces on the back wall, the pillar between them.
	# A sconce's flame stands out from its wall by its reach.
	var reach := float(LightFixture.spec(&"wall_torch")["sockets"]["flame"][0][2])
	Lights.wall_torch(self, Vector3(x - 2.5, 2.4, -6.0 + reach), Vector3.BACK)
	Lights.wall_torch(self, Vector3(x + 2.5, 2.4, -6.0 + reach), Vector3.BACK)
	Lights.cresset(self, Vector3(x - 2.0, 0, -0.5))
	Lights.cresset(self, Vector3(-20.0, 2.0, -2.5), &"wall", Lights.yaw_facing(Vector3.RIGHT))


func _lanterns(x: float) -> void:
	Lights.hanging_lantern(self, Vector3(x - 2.5, 6.0, -3.0), 2.4)
	Lights.wall_lantern(self, Vector3(x + 2.5, 2.3, -6.0), Vector3.BACK)
	# Its arm out sideways, so the walk sees its lantern beside the post.
	Lights.lamp_post(self, Vector3(x + 1.5, 0, 0.5), PI * 0.5)


func _candles(x: float) -> void:
	# A table along the back, near the door: every candle, stick and lamp on it.
	var top := 0.9
	var table := Props.block(self, Vector3(x - 1.8, top * 0.5, -4.6), Vector3(4.4, top, 1.0), Color(0.3, 0.2, 0.12), "wood")
	table.name = "Table"
	# All clear of the pillar's line, to be seen from the walk.
	var along := x - 3.7
	Lights.candle(self, Vector3(along, top, -4.6), 6)
	Lights.candle(self, Vector3(along + 0.3, top, -4.6), 10)
	Lights.candle(self, Vector3(along + 0.6, top, -4.6), 16)
	Lights.candlestick(self, Vector3(along + 1.0, top, -4.6), &"iron")
	Lights.candlestick(self, Vector3(along + 1.4, top, -4.6), &"brass")
	Lights.candelabra(self, Vector3(along + 1.9, top, -4.6), 3)
	Lights.candelabra(self, Vector3(along + 2.65, top, -4.6), 5)
	Lights.oil_lamp(self, Vector3(along + 3.2, top, -4.6), &"clay")
	# The chandeliers either side of the pillar, a lamp hung by the wall.
	Lights.chandelier(self, Vector3(x - 2.5, 6.0, -1.5), 6, 1.6)
	Lights.chandelier(self, Vector3(x + 2.5, 6.0, -1.5), 8, 1.6)
	Lights.oil_lamp(self, Vector3(x + 3.0, 6.0, -4.8), &"hanging", 0.0, 2.2)


func _fires(x: float) -> void:
	# The brazier and the hearth either side of the pillar, the campfire
	# nearer the walk, none in front of another.
	Lights.brazier(self, Vector3(x - 2.5, 0, -2.0))
	Lights.campfire(self, Vector3(x - 0.5, 0, 0.5))
	# Set into the end wall.
	Lights.hearth(self, Vector3(20.0, 0, -3.5), Lights.yaw_facing(Vector3.LEFT))


## One watchman with a lantern and one with a torch, walking the bay's walk.
func _watchmen(bay: int, x: float) -> void:
	for pair in [[&"lantern", 3.2], [&"torch", 5.0]]:
		var route := Node3D.new()
		route.name = "Route%d%s" % [bay, pair[0]]
		add_child(route)
		var ends := [Vector3(x - 3.0, 0, pair[1]), Vector3(x + 3.5, 0, pair[1])]

		if pair[0] == &"torch":
			ends.reverse()

		for at in ends:
			var point := Node3D.new()
			route.add_child(point)
			point.global_position = at

		var man: CharacterBody3D = GUARD.instantiate()
		man.name = "Watchman%d%s" % [bay, String(pair[0]).capitalize()]
		man.debug_ai = false
		man.rounds_light = pair[0]
		man.patrol_route = NodePath("../" + route.name)
		# Here to show their lights, not to find you.
		man.vision_gain = 0.0
		man.hearing_acuity = 0.0
		add_child(man)
		man.global_position = ends[0]


# Building blocks

## A solid block with a texture laid on in world space (retro_showcase's).
func _brush(center: Vector3, size: Vector3, texture: Texture2D, tile: float, surface := "stone") -> StaticBody3D:
	var body := Props.block(self, center, size, Color.WHITE, surface)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / tile
	material.roughness = 0.92

	for child in body.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = material

	return body


func _sign(at: Vector3, yaw: float, text: String) -> void:
	var label := Label3D.new()
	label.rotation.y = yaw
	label.text = text
	label.font_size = 28
	label.pixel_size = 0.006
	label.modulate = Color(0.95, 0.9, 0.8)
	label.outline_size = 8
	label.shaded = false
	add_child(label)
	label.global_position = at
