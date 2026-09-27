extends Node3D
## The NPC showcase: one night at a Watch garrison, for others to watch. The
## guards run their own minds; only the intruder follows a script (the
## director, ShowDirector.gd, plays the night in acts).
##
##   Godot --path . res://maps/npc_showcase.tscn
##
## The yard (40 x 30 m, its middle at the origin, the gate to the south, +Z):
##   the north wall carries a wall-walk (stairs at both ends) and the tower in
##   its east corner (the lookout, the bell); the postern is in the east wall
##   just south of the tower, in the dark. An open shed of bedrolls on the west
##   side, the quartermaster's store on the east (a dark alley behind it, along
##   the east wall, up to the postern), the fire and its benches in the
##   middle, the well, the woodpile and the cart.
##   Outside the north wall: lean-to roofs, then a canal. Every building is
##   open above (rafters, no roof), so a camera overhead sees into it.
##
## Keys (ShowDirector, ShowCamera, ShowOverlay):
##   1-5 start from that act       N the next beat       V Act V's ending
##   R from the start again        Space pause           [ ] slow motion
##   C the camera to the director  Tab follow the next man, or click on one
##   WASD Q/E fly (right mouse held to look, Shift fast, the wheel for speed)
##   H hide the subtitles, marks and titles      F6-F8 the retro look
##
## After -- on the command line:
##   --act=N          start at act N (1-5)
##   --ending=X       overwhelmed, victor or escape (else one at random)
##   --auto           nobody at the controls: the director has the camera
##   --quit-at-end    quit a few seconds after the night is over
##   --seed=N         another night than the usual one (the same N, the same
##                    night)
##   --fps-report=N   the yard at rest for N seconds, then its frame rate
##                    (average and lowest), and quit.
##
## To record the whole night to a video, frame by frame whatever the machine
## can draw (Godot's Movie Maker):
##   Godot --path . --write-movie showcase.avi --fixed-fps 60 --resolution 1920x1080 res://maps/npc_showcase.tscn -- --auto --ending=escape --quit-at-end

## Built, baked and peopled: the director (or a test) can begin.
signal ready_to_show
## The intruder is made (the story hears what he does through him).
signal intruder_spawned(intruder: CharacterBody3D)

const GUARD := preload("res://Guard.tscn")
const INTRUDER := preload("res://Intruder.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Lights := preload("res://scripts/Visual/Lights/Lights.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const FireScript := preload("res://scripts/Combat/Fire.gd")
const AlarmBellScript := preload("res://scripts/Interaction/AlarmBell.gd")
const WaterScript := preload("res://scripts/Interaction/WaterVolume.gd")
const GuardStationScript := preload("res://scripts/AISystem/GuardStation.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const DirectorScript := preload("res://scripts/Showcase/ShowDirector.gd")
const NightRotaScript := preload("res://scripts/AISystem/NightRota.gd")
const GatheringScript := preload("res://scripts/AISystem/Gathering.gd")
const AtmosphereScript := preload("res://scripts/Visual/Atmosphere.gd")
const TalkScript := preload("res://scripts/AISystem/Talk/TalkScript.gd")
const CameraScript := preload("res://scripts/Showcase/ShowCamera.gd")
const OverlayScript := preload("res://scripts/Showcase/ShowOverlay.gd")
## The night's story (acts and beats), for the director.
const STORY := "res://scripts/Showcase/ShowNight.gd"

const STONE_ROAD := preload("res://maps/test_stone_road.png")
const STONE_WEATHERED := preload("res://maps/test_stone_weathered.png")
const BRICK := preload("res://textures/stone_brick_1.png")
const MOSS := preload("res://textures/mossy_rock_1.png")
const WOOD := preload("res://textures/wood_1.png")
const PLASTER := preload("res://textures/plaster_1.png")
const GRASS := preload("res://textures/grass_ground_1.png")

## Everyone at the garrison: [name, archetype, temperament, look seed, what
## he is to the viewer]. The fight squad lives in the camp.
const CAST := [
	["Mirelle", &"duelist", &"steady", 11, "the captain"],
	["Osric", &"swordsman", &"steady", 12, "swordsman"],
	["Brand", &"brute", &"rash", 13, "the brute"],
	["Wat", &"archer", &"sly", 14, "archer on the wall"],
	["Aldous", &"", &"stubborn", 15, "lookout"],
	["Hendrik", &"", &"steady", 16, "at the postern"],
	["Piers", &"", &"craven", 17, "by the fire"],
	["Col", &"", &"steady", 18, "at his supper"],
	["Tam", &"", &"steady", 19, "asleep"],
	["Gideon", &"", &"steady", 20, "quartermaster"],
	["Ned", &"", &"craven", 21, "carrier"],
	["Jory", &"", &"steady", 22, "off watch"],
]
const CAST_NAMES := ["Mirelle", "Osric", "Brand", "Wat", "Aldous", "Hendrik", "Piers", "Col", "Tam", "Gideon", "Ned", "Jory"]
## The heights of things: the curtain wall, the wall-walk on it, the tower.
const WALL_HEIGHT := 4.2
const WALK_HEIGHT := 3.0
const TOWER_HEIGHT := 4.8
## The seed every run starts from: the same night each time.
const SEED := 1926

## Off in a test that only wants the people living (no director).
static var run_show := true
## Another night than the usual one for a test (-1: --seed, else SEED).
static var seed_override := -1
## The night: an hour of it lasts this long (s); the man at a post is not
## relieved of his own accord (the night's beats change the watch).
const HOUR := 90.0
const POST_TURN := 600.0
## The fire: well fed at dusk, burning down over this long.
const FIRE_FUEL := 0.9
const FIRE_BURNS := 240.0

## name -> the man; name -> what he is to the viewer.
var cast := {}
var roles := {}
## Named places for the story (Vector3): see _marks.
var marks := {}
var intruder: CharacterBody3D = null
## The director, when the show runs, and the night it plays.
var director: Node = null
var story: RefCounted = null
## The show camera and the viewer's overlay, when the show runs.
var camera: Camera3D = null
var overlay: CanvasLayer = null

var _baker: NavigationRegion3D
var _stations := {}
var _routes := {}
## The brazier's fire, the night's rota, and the air.
var fire: Area3D = null
var rota: RefCounted = null
var atmosphere: Node3D = null
## Temperament.rolling as it was before the showcase (put back after it).
var _was_rolling := true


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	_was_rolling = TemperamentScript.rolling
	TemperamentScript.rolling = false
	SquadScript.clear_all()
	GarrisonScript.clear_all()
	LightProbe.invalidate()
	build()

	# Its sound: the recordings loaded, the ambience, the stone's acoustics,
	# the score (Sfx.warm: what the player's arrival does in a level); a cold
	# night, heard on the men's breath (GuardVoice).
	set_meta(&"acoustics", "stone")
	set_meta(&"cold", true)
	Sfx.warm(self)
	await _baker.baked
	LightProbe.invalidate()

	# Every conversation read before anyone speaks.
	TalkScript.library()

	# The same night every run: nobody reseeds the dice as he is made.
	GuardScript.randomize_on = false
	seed(_seed())
	_spawn_cast()
	GuardScript.randomize_on = true
	_night()
	_overview()
	# The director is there when the showcase says it is ready; it begins
	# once whoever waits for that has heard it.
	if run_show and ResourceLoader.exists(STORY):
		director = DirectorScript.new()
		director.read_args(OS.get_cmdline_user_args())
		add_child(director)
		story = (load(STORY) as GDScript).new(self)
		director.setup(self, story)
		camera = CameraScript.new()
		add_child(camera)
		camera.setup(self, story)
		camera.make_current()
		director.beat_started.connect(func(_beat: StringName, scene: Dictionary) -> void: camera.want(scene))

		var overview := get_node_or_null("Overview")

		if overview != null:
			overview.queue_free()

		overlay = OverlayScript.new()
		add_child(overlay)
		overlay.setup(self)
		director.act_started.connect(func(_index: int, act_title: String) -> void: overlay.title(act_title))
		# Each act opens through black.
		director.act_started.connect(func(_index: int, _title: String) -> void: camera.fade_next())
		camera.following.connect(overlay.name_card)
		director.ending_chosen.connect(func(ending: StringName) -> void: overlay.toast("Ending: %s" % String(ending)))
		director.speed_changed.connect(func(scale: float) -> void: overlay.toast("Speed x%s" % String.num(scale, 2)))
		director.paused_changed.connect(func(paused: bool) -> void: overlay.toast("Paused" if paused else "Playing"))
		director.show_ended.connect(func() -> void:
			overlay.title("The night is over")
			overlay.toast("R to watch it again"))

		# The intruder's name card too, once he is made.
		intruder_spawned.connect(func(i: CharacterBody3D) -> void: overlay.watch(i, "the intruder"))

	ready_to_show.emit()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fps-report="):
			# Measured with the show running: the night as it is filmed (the
			# Cinema camera, its focus and all).
			if director != null:
				director.run()

			_fps_report(float(arg.trim_prefix("--fps-report=")))
			return

	if director != null:
		director.run()


## Gone: the men made after it roll their temperaments as they did before.
func _exit_tree() -> void:
	TemperamentScript.rolling = _was_rolling


## Everything but the people: the yard, the buildings, outside, the lights,
## the stations and the marks, and the navmesh baker.
func build() -> void:
	_yard()
	_walls()
	_tower()
	_shed()
	_store()
	_middle()
	_outside()
	_stations_and_props()
	_marks()
	_vantages()
	_lights()
	_baker = NavigationRegion3D.new()
	_baker.set_script(NavBakerScript)
	add_child(_baker)


## The night's rota (duties, the hour) and the air of the yard.
func _night() -> void:
	rota = NightRotaScript.setup(self, HOUR, &"early")
	rota.post_turn = POST_TURN
	# Its gatherings and the watch changing move them; their needs do not
	# (the story wants each man where it left him).
	rota.wants_rest = false
	rota.add_duty(&"postern", &"post", {"transform": Transform3D(Basis(Vector3.UP, -PI * 0.5), marks["postern_post"])})
	rota.add_duty(&"yard_round", &"round", {"route": (_routes["yard"] as Node).get_path()})
	rota.add_duty(&"wall_round", &"round", {"route": (_routes["wall"] as Node).get_path()})
	rota.add_duty(&"bench", &"bench", {"paths": [(_stations["sit_bench"] as Node).get_path()]})
	rota.add_duty(&"bed", &"bed", {"paths": [(_stations["sleep_tam"] as Node).get_path()]})
	var duties := {"Hendrik": &"postern", "Wat": &"wall_round", "Jory": &"bench", "Tam": &"bed"}

	for name in duties:
		var man: Node = cast.get(name)

		if man != null:
			rota.assign(man, duties[name])

	# The night's beats ask for each gathering (ShowNight); the fire is fed
	# when it burns low whoever asks.
	GatheringScript.of(self).spontaneous = false
	set_meta(&"yard_size", Vector2(40.0, 30.0))
	atmosphere = AtmosphereScript.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	atmosphere.add_crows([Vector3(-10, WALL_HEIGHT + 0.05, -15.1), Vector3(-4, WALL_HEIGHT + 0.05, -15.1), Vector3(3, WALL_HEIGHT + 0.05, -15.1),
		Vector3(8, WALL_HEIGHT + 0.05, -15.1), Vector3(-15, WALL_HEIGHT + 0.05, -15.1)])


## A place they gather of `kind` at `at`: spots [offset, activity, role],
## each facing the middle.
func _gathering_place(kind: StringName, at: Vector3, spots: Array) -> void:
	var place := Marker3D.new()
	place.name = "Gather_%s" % kind
	place.set_meta(&"gathering", kind)
	place.add_to_group(&"gathering_places")
	add_child(place)
	place.global_position = at

	for spot in spots:
		var marker := Marker3D.new()
		marker.set_meta(&"activity", spot[1])
		marker.set_meta(&"role", spot[2])
		place.add_child(marker)
		marker.global_position = at + (spot[0] as Vector3)
		var inward: Vector3 = -(spot[0] as Vector3)
		marker.global_basis = Basis.looking_at(Vector3(inward.x, 0, inward.z).normalized(), Vector3.UP)


## The intruder, at `at` (the director's).
func spawn_intruder(at: Vector3, yaw := 0.0) -> CharacterBody3D:
	if intruder != null and is_instance_valid(intruder):
		intruder.queue_free()

	intruder = INTRUDER.instantiate()
	intruder.position = at
	intruder.rotation.y = yaw
	add_child(intruder)
	intruder_spawned.emit(intruder)
	return intruder


# ---------------------------------------------------------------------------
# The place
# ---------------------------------------------------------------------------

func _yard() -> void:
	_brush(Vector3(0, -0.25, 0), Vector3(42, 0.5, 33), STONE_ROAD, 2.0)


func _walls() -> void:
	var h := WALL_HEIGHT

	# North (1.2 m thick: a man can stand on it, going over).
	_brush(Vector3(0, h * 0.5, -15.9), Vector3(42, h, 1.2), BRICK, 2.0)

	# South, the gate in its middle (shut).
	_brush(Vector3(-11.5, h * 0.5, 15.9), Vector3(19, h, 0.8), BRICK, 2.0)
	_brush(Vector3(11.5, h * 0.5, 15.9), Vector3(19, h, 0.8), BRICK, 2.0)
	_brush(Vector3(0, h - 0.5, 15.9), Vector3(4, 1.0, 0.8), BRICK, 2.0)
	_brush(Vector3(0, 1.6, 15.75), Vector3(4, 3.2, 0.3), WOOD, 1.0, "wood")

	# West, and east with the postern in it (z -9.5..-8.1, shut).
	_brush(Vector3(-20.9, h * 0.5, 0), Vector3(0.8, h, 32.6), BRICK, 2.0)
	_brush(Vector3(20.9, h * 0.5, -12.7), Vector3(0.8, h, 7.2), BRICK, 2.0)
	_brush(Vector3(20.9, h * 0.5, 3.75), Vector3(0.8, h, 23.7), BRICK, 2.0)
	_brush(Vector3(20.9, h - 0.85, -8.8), Vector3(0.8, 1.7, 1.4), BRICK, 2.0)
	_brush(Vector3(20.65, 1.25, -8.8), Vector3(0.3, 2.5, 1.4), WOOD, 1.0, "wood")

	# The wall-walk along the north wall, from the west wall to the tower, and
	# its stairs at each end.
	_brush(Vector3(-1.8, WALK_HEIGHT * 0.5, -14.5), Vector3(37.4, WALK_HEIGHT, 1.6), STONE_WEATHERED, 2.0)
	_stairs(Vector3(-14.8, 0, -9.7), Vector3(0, 0, -1), 12, WALK_HEIGHT / 12.0, 0.333, 1.4)
	_stairs(Vector3(15.0, 0, -9.7), Vector3(0, 0, -1), 12, WALK_HEIGHT / 12.0, 0.333, 1.4)


func _tower() -> void:
	# The north-east corner, over the postern: a step up off the wall-walk (a
	# man climbs it).
	_brush(Vector3(18.7, TOWER_HEIGHT * 0.5, -13.7), Vector3(3.6, TOWER_HEIGHT, 3.6), BRICK, 2.0)

	for corner in [Vector2(20.3, -15.3), Vector2(17.1, -15.3), Vector2(20.3, -12.1), Vector2(17.1, -12.1)]:
		_brush(Vector3(corner.x, TOWER_HEIGHT + 0.55, corner.y), Vector3(0.4, 1.1, 0.4), BRICK, 1.0)

	AlarmBellScript.build(self, Vector3(19.9, TOWER_HEIGHT, -14.9), -PI * 0.25)


func _shed() -> void:
	# The open shed on the west side: posts, rafters, bedrolls.
	for corner in [Vector2(-14.2, -3.2), Vector2(-14.2, 5.2)]:
		_brush(Vector3(corner.x, 1.45, corner.y), Vector3(0.25, 2.9, 0.25), WOOD, 1.0, "wood")

	_rafters(Vector3(-17.4, 2.95, 1.0), Vector2(6.4, 8.6), true)

	for z in [-1.8, 0.8, 3.4]:
		Props.block(self, Vector3(-18.6, 0.03, z), Vector3(2.0, 0.06, 0.9), Color(0.33, 0.28, 0.2), "wood")


func _store() -> void:
	# The quartermaster's store on the east side: its back wall, posts,
	# rafters; the alley behind it along the east wall, unlit.
	_brush(Vector3(16.6, 2.0, -0.5), Vector3(0.3, 4.0, 11.2), WOOD, 1.5, "wood")

	for corner in [Vector2(11.5, -6.0), Vector2(11.5, 5.0), Vector2(16.4, -6.0), Vector2(16.4, 5.0)]:
		_brush(Vector3(corner.x, 1.5, corner.y), Vector3(0.25, 3.0, 0.25), WOOD, 1.0, "wood")

	_rafters(Vector3(14.0, 3.05, -0.5), Vector2(5.2, 11.4), false)


func _middle() -> void:
	# The fire and its benches; the well; the woodpile; the cart.
	fire = FireScript.brazier(self, Vector3.ZERO)
	fire.fuel = FIRE_FUEL
	fire.fuel_seconds = FIRE_BURNS
	_brush(Vector3(0, 0.22, -2.6), Vector3(2.8, 0.45, 0.45), WOOD, 1.0, "wood")
	_brush(Vector3(0, 0.22, 2.9), Vector3(2.2, 0.45, 0.45), WOOD, 1.0, "wood")
	# The crate by the south bench they dice on.
	_brush(Vector3(2.9, 0.25, 3.8), Vector3(0.6, 0.5, 0.6), WOOD, 1.0, "wood")

	_brush(Vector3(-5, 0.45, 7), Vector3(1.6, 0.9, 1.6), MOSS, 1.0)

	for x in [-5.7, -4.3]:
		_brush(Vector3(x, 1.4, 7), Vector3(0.14, 1.9, 0.14), WOOD, 1.0, "wood")

	_brush(Vector3(-5, 2.35, 7), Vector3(1.7, 0.14, 0.14), WOOD, 1.0, "wood")

	_brush(Vector3(-12, 0.3, 10.6), Vector3(0.55, 0.6, 0.55), WOOD, 1.0, "wood")

	for i in 5:
		var log := MeshInstance3D.new()
		var round := CylinderMesh.new()
		round.top_radius = 0.16
		round.bottom_radius = 0.16
		round.height = 1.4
		round.material = Props.material(Color(0.4, 0.28, 0.17))
		log.mesh = round
		add_child(log)
		log.global_position = Vector3(-14.4 + (i % 3) * 0.34, 0.16 + (i / 3) * 0.3, 11.2 + (i / 3) * 0.17)
		log.rotation = Vector3(0, 0, PI * 0.5)

	# A tall stack of cut wood in the south-east corner, and a fence on from
	# the store's back wall to it: the moon (from the north-west) leaves the
	# whole alley and the nook east of the stack in shadow.
	_brush(Vector3(17.8, 1.6, 12.4), Vector3(1.2, 3.2, 3.2), WOOD, 0.8, "wood")
	_brush(Vector3(16.6, 2.0, 7.95), Vector3(0.2, 4.0, 5.7), WOOD, 1.5, "wood")

	# The cart: a bed on four blocks for wheels.
	_brush(Vector3(9, 0.75, 10.2), Vector3(2.8, 0.15, 1.5), WOOD, 1.0, "wood")

	for wheel in [Vector2(7.9, 9.45), Vector2(10.1, 9.45), Vector2(7.9, 10.95), Vector2(10.1, 10.95)]:
		_brush(Vector3(wheel.x, 0.34, wheel.y), Vector3(0.6, 0.68, 0.12), WOOD, 1.0, "wood")


func _outside() -> void:
	# Beyond the north wall: ground at the yard's level, lean-to roofs against
	# the wall, and a canal (its surface 0.6 m under the ground).
	_brush(Vector3(0, -1.75, -18.75), Vector3(42, 3.5, 4.5), GRASS, 2.0, "grass")
	_brush(Vector3(0, 0.9, -17.55), Vector3(20, 1.8, 2.1), WOOD, 1.5, "wood")
	_brush(Vector3(0, -3.75, -24), Vector3(42, 0.5, 6), MOSS, 2.0)
	_brush(Vector3(0, -1.75, -28.5), Vector3(42, 3.5, 3), GRASS, 2.0, "grass")
	WaterScript.build(self, Vector3(0, -2.05, -24), Vector3(42, 2.9, 6))


# ---------------------------------------------------------------------------
# Stations, props, marks
# ---------------------------------------------------------------------------

func _stations_and_props() -> void:
	# By the fire: Piers on the north bench facing it; Col at his supper on
	# its south side.
	_station("sit_piers", &"sit", Vector3(-0.6, 0, -2.05), PI)
	_station("eat_col", &"eat", Vector3(1.0, 0, 2.1), 0.0)

	# Tam asleep in the shed.
	_station("sleep_tam", &"sleep", Vector3(-18.6, 0, -1.8), -PI * 0.5)

	# Gideon's chests in the store, their fronts to the yard.
	for i in 3:
		var z := -3.6 + i * 3.0
		var chest: Node3D = Props.chest(self, Vector3(15.5, 0, z), -PI * 0.5, Vector3(0.9, 0.55, 0.55))
		var station := _station("chest_%d" % i, &"rummage", Vector3(14.55, 0, z), -PI * 0.5)
		station.chest = station.get_path_to(chest)

	# Ned's crates on the cart, to the store's north end.
	var drop := Marker3D.new()
	drop.name = "CratesDrop"
	add_child(drop)
	drop.global_position = Vector3(13.6, 0, -5.0)
	var carry := _station("carry_ned", &"carry", Vector3(9, 0, 8.7), PI)
	carry.drop_to = carry.get_path_to(drop)

	# Two rows of four: a night's hauling.
	for i in 8:
		var crate := Props.crate(self, Vector3(8.0 + (i % 4) * 0.66, 1.1 + (i / 4) * 0.52, 10.2), 0.5, 5.0)
		crate.add_to_group(&"cargo")

	# Brand at the chopping block.
	_station("chop_brand", &"chop", Vector3(-12, 0, 11.3), 0.0)

	# The south bench, where a man off watch sits (the night's bench duty).
	_station("sit_bench", &"sit", Vector3(-0.7, 0, 2.45), 0.0)

	# Where they gather: dice at the crate by the south bench; a story round
	# the fire (the teller to the east); the woodpile a log is fetched from.
	_gathering_place(&"dice", Vector3(2.9, 0, 3.8), [[Vector3(-0.8, 0, 0.0), &"squat", &"any"], [Vector3(0.8, 0, 0.0), &"squat", &"any"], [Vector3(0, 0, 0.8), &"squat", &"any"]])
	_gathering_place(&"story", Vector3.ZERO, [[Vector3(1.9, 0, 0), &"stand", &"teller"], [Vector3(-1.9, 0, 0), &"squat", &"listener"],
		[Vector3(0, 0, -1.9), &"stand", &"listener"], [Vector3(0.3, 0, 1.9), &"squat", &"listener"]])
	var pile := Marker3D.new()
	pile.name = "Woodpile"
	pile.add_to_group(&"woodpiles")
	add_child(pile)
	pile.global_position = Vector3(-13.8, 0, 11.2)

	# Crates and a barrel about the yard, for throwing when it comes to it.
	for at in [Vector3(-10, 0.3, -6), Vector3(6.5, 0.3, -8.5), Vector3(-8.6, 0.3, 11.8)]:
		Props.crate(self, at, 0.55, 6.0)


func _marks() -> void:
	marks = {
		"fire": Vector3(0, 0, 0),
		"gate": Vector3(0, 0, 13.5),
		"postern_post": Vector3(19.6, 0, -8.8),
		# The intruder: in over the east wall into the alley behind the store,
		# where he waits for the archer to pass, and where he hides.
		"drop_in": Vector3(19.4, 0, 9.0),
		"alley_wait": Vector3(18.9, 0, -4.2),
		# Where he goes to ground: the far, unlit end of the alley, in the
		# yard's south-east corner.
		"hide": Vector3(19.6, 0, 14.2),
		"found": Vector3(2.5, 0, 2.5),
		"east_stairs": Vector3(15.0, 0, -9.2),
		"walk_east": Vector3(12.5, WALK_HEIGHT, -14.5),
		"over_wall": Vector3(11.0, WALL_HEIGHT, -15.9),
		"roofs": Vector3(8.0, 1.8, -17.6),
		"bank": Vector3(6.0, 0, -20.0),
		"canal": Vector3(4.0, -0.6, -24.0),
		"gate_out": Vector3(0, 0, 15.0),
	}

	for mark in [["the fire", Vector3(0, 0, 0)], ["the well", Vector3(-5, 0, 7)], ["the gate", Vector3(0, 0, 14.5)],
			["the tower", Vector3(18.7, TOWER_HEIGHT, -13.7)], ["the store", Vector3(14, 0, -0.5)], ["the shed", Vector3(-17.4, 0, 1)],
			["the postern", Vector3(20.3, 0, -8.8)], ["the wall", Vector3(0, WALK_HEIGHT, -14.5)], ["the woodpile", Vector3(-13, 0, 11)]]:
		var landmark := Marker3D.new()
		landmark.set_meta(&"landmark", mark[0])
		landmark.add_to_group(&"landmarks")
		add_child(landmark)
		landmark.global_position = mark[1]

	# Wat's round on the wall-walk (looking out at each end), Hendrik's round
	# of the yard.
	_routes["wall"] = _route("WallRoute", [[Vector3(-13.5, WALK_HEIGHT, -14.5), 0.0], [Vector3(12.8, WALK_HEIGHT, -14.5), 0.0]])
	_routes["yard"] = _route("YardRoute", [[Vector3(-7, 0, -6), PI * 0.75], [Vector3(7, 0, -6), -PI * 0.75], [Vector3(7, 0, 5.5), -PI * 0.25], [Vector3(-7, 0, 5.5), PI * 0.25]])


func _lights() -> void:
	var environment := RetroScript.night_environment(Color(0.34, 0.34, 0.42), 0.28)
	environment.background_color = Color(0.025, 0.035, 0.07)
	environment.volumetric_fog_density = 0.01
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.75
	moon.shadow_enabled = true
	moon.light_volumetric_fog_energy = 4.0
	moon.directional_shadow_max_distance = 60.0
	add_child(moon)
	# From the north-west, low: the alley behind the store and the postern
	# corner lie in the east wall's shadow.
	moon.global_basis = Basis.looking_at(Vector3(0.62, -0.5, 0.6).normalized(), Vector3.UP)

	# Torches: the gate, the tower, the store's front and inside it, inside the
	# shed, by the woodpile. The postern has one of its own, dim (a man there
	# is seen only near); the alley behind the store has none.
	for torch in [[Vector3(-2.6, 2.6, 15.2), 2.4], [Vector3(2.6, 2.6, 15.2), 2.4], [Vector3(16.6, 3.4, -11.7), 2.0],
			[Vector3(11.3, 2.3, 5.2), 1.8], [Vector3(13.6, 2.5, -0.5), 1.4], [Vector3(-16.4, 2.4, 1.0), 1.6],
			[Vector3(-20.4, 2.6, 10.5), 1.8], [Vector3(20.4, 2.4, -10.2), 0.7]]:
		_torch(torch[0], torch[1])


# ---------------------------------------------------------------------------
# The people
# ---------------------------------------------------------------------------

func _spawn_cast() -> void:
	# [name, where, yaw, stations, route, lookout].
	var places := {
		"Mirelle": [Vector3(2.3, 0, -1.0), PI * 0.5, [], "", false],
		"Osric": [Vector3(2.7, 0, 1.1), PI * 0.5, [], "", false],
		"Brand": [Vector3(-12, 0, 12.4), 0.0, ["chop_brand"], "", false],
		"Wat": [Vector3(-13.5, WALK_HEIGHT, -14.5), -PI * 0.5, [], "wall", false],
		"Aldous": [Vector3(18.5, TOWER_HEIGHT, -13.5), 2.2, [], "", true],
		"Hendrik": [marks["postern_post"], -PI * 0.5, [], "", false],
		"Piers": [Vector3(-0.6, 0, -1.2), PI, ["sit_piers"], "", false],
		"Col": [Vector3(1.0, 0, 3.4), 0.0, ["eat_col"], "", false],
		"Tam": [Vector3(-18.6, 0, -1.8), -PI * 0.5, ["sleep_tam"], "", false],
		"Gideon": [Vector3(13.2, 0, -0.6), -PI * 0.5, ["chest_0", "chest_1", "chest_2"], "", false],
		"Ned": [Vector3(9, 0, 7.5), PI, ["carry_ned"], "", false],
		"Jory": [Vector3(-0.7, 0, 3.4), 0.0, ["sit_bench"], "", false],
	}

	for entry in CAST:
		var name: String = entry[0]
		var place: Array = places[name]
		var g: CharacterBody3D = GUARD.instantiate()
		g.name = name
		g.given_name = name
		g.archetype = entry[1]
		g.temperament = entry[2]
		g.look_seed = entry[3]
		g.lookout = place[4]
		g.debug_ai = false
		# His own ways (GuardHabits) keep him at his mark: a fidget, the wall
		# behind him. The night moves him (the rota, the gatherings), not a
		# whim to go and see a friend.
		g.habits.assign([&"fidget", &"lean"])
		var paths: Array[NodePath] = []

		for key in place[2]:
			paths.append((_stations[key] as Node).get_path())

		g.stations = paths

		if place[3] != "":
			g.patrol_route = (_routes[place[3]] as Node).get_path()

		g.position = place[0]
		g.rotation.y = place[1]
		add_child(g)

		# What they say is the overlay's to show (ShowOverlay), not floating
		# labels.
		if g.get("_bark_label") != null:
			g._bark_label.visible = false

		cast[name] = g
		roles[name] = entry[4]


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

## A solid block with a texture laid on in world space, one tile every `tile`
## metres (maps/retro_showcase.gd's).
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


## Stairs up from `start` along `direction`, each step a block from the floor.
func _stairs(start: Vector3, direction: Vector3, count: int, rise: float, run: float, width: float) -> void:
	var across := Vector3.UP.cross(direction).abs()

	for i in count:
		var top := rise * (i + 1)
		var centre := start + direction * (run * (i + 0.5)) + Vector3.UP * (top * 0.5)
		_brush(centre, across * width + direction.abs() * run + Vector3.UP * top, STONE_WEATHERED, 2.0)


## A frame of beams over a building, open to the sky (and the camera): a ridge
## beam along it and rafters across. `along_z` says which way it runs.
func _rafters(centre: Vector3, size: Vector2, along_z: bool) -> void:
	var length := size.y if along_z else size.x
	var span := size.x if along_z else size.y
	var beam_along := Vector3(0.18, 0.18, length) if along_z else Vector3(length, 0.18, 0.18)
	_mesh_beam(centre + Vector3.UP * 0.2, beam_along)

	var count := int(length / 1.1)

	for i in count + 1:
		var t := -length * 0.5 + length * float(i) / float(count)
		var at := centre + (Vector3(0, 0, t) if along_z else Vector3(t, 0, 0))
		_mesh_beam(at, Vector3(span, 0.12, 0.12) if along_z else Vector3(0.12, 0.12, span))


func _mesh_beam(at: Vector3, size: Vector3) -> void:
	var beam := Props.mesh_box(size, Color(0.3, 0.21, 0.13))
	add_child(beam)
	beam.global_position = at


func _torch(at: Vector3, energy: float) -> void:
	Lights.torch_at(self, at, energy, 9.0, energy > 1.0)


func _station(key: String, kind: StringName, at: Vector3, yaw: float) -> Marker3D:
	var station: Marker3D = GuardStationScript.new()
	station.name = key
	station.kind = kind
	add_child(station)
	station.global_position = at
	station.rotation.y = yaw
	_stations[key] = station
	return station


## A patrol route: waypoints [where, which way he faces there].
func _route(route_name: String, points: Array) -> Node3D:
	var route := Node3D.new()
	route.name = route_name
	add_child(route)

	for p in points:
		var point := Marker3D.new()
		route.add_child(point)
		point.global_position = p[0]
		point.rotation.y = p[1]

	return route


## The night's seed: --seed=N, else SEED.
func _seed() -> int:
	if seed_override >= 0:
		return seed_override

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.trim_prefix("--seed="))

	return SEED


## A camera high over the south-east corner that sees the whole yard (the
## show camera takes over from it when there is one).
func _overview() -> void:
	if get_viewport().get_camera_3d() != null:
		return

	var camera := Camera3D.new()
	camera.name = "Overview"
	camera.fov = 55.0
	add_child(camera)
	camera.global_position = Vector3(16, 24, 26)
	camera.look_at(Vector3(-1, 0, -2), Vector3.UP)
	camera.make_current()


## Places the camera may watch from, half hidden (CineVantage): behind the
## woodpile, the wall-walk, by the gate, the tower's top, the shed's mouth,
## behind the store's crates, the mouth of the alley.
func _vantages() -> void:
	for at in [Vector3(-15.5, 1.5, 13.8), Vector3(-12.0, WALK_HEIGHT + 1.6, -14.5), Vector3(9.0, WALK_HEIGHT + 1.6, -14.5),
			Vector3(2.8, 2.2, 14.8), Vector3(17.3, TOWER_HEIGHT + 1.6, -12.3), Vector3(-15.8, 1.6, -3.5),
			Vector3(11.5, 1.3, 5.5), Vector3(19.8, 1.6, 6.0)]:
		var mark := Marker3D.new()
		add_child(mark)
		mark.global_position = at
		mark.add_to_group(&"cine_vantage")


## The frame rate over `seconds` of the night from its start, then quit.
func _fps_report(seconds: float) -> void:
	var samples: Array[float] = []

	for i in int(seconds):
		await get_tree().create_timer(1.0, true, false, true).timeout
		samples.append(Engine.get_frames_per_second())

	var total := 0.0
	var lowest := INF

	for s in samples.slice(2):
		total += s
		lowest = minf(lowest, s)

	var counted := maxi(samples.size() - 2, 1)
	print("[fps] %d guards, the show running: average %.1f, lowest %.1f over %d s" % [cast.size(), total / counted, lowest, counted])
	get_tree().quit()
