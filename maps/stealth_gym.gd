extends Node3D
## A playable stealth gym: a dark yard, two torches, a patrolling guard, a
## second guard on post at a locked-room door, cover, and things to throw.
## It uses the real lightgem, so light and shadow matter here.
##
##   Godot --path . res://maps/stealth_gym.tscn
##
## Debug is on: each guard shows its state, alert, and how well it sees you;
## its view cone is drawn; every gameplay sound flashes where it happened.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")

const STONE := Color(0.36, 0.36, 0.4)
const DARK := Color(0.2, 0.2, 0.23)


func _ready() -> void:
	# Everything below is placed after it is added: draw it from where it ends up.
	reset_physics_interpolation.call_deferred()
	SoundBus.debug = true
	# Static, so it would outlive this scene. Switch it off on the way out.
	tree_exiting.connect(func(): SoundBus.debug = false)
	_environment()

	Props.block(self, Vector3(0, -0.5, 0), Vector3(50, 1, 44), DARK)

	# The keep in the middle: the patrol circles it.
	Props.block(self, Vector3(0, 2.0, 0), Vector3(8, 4, 6), STONE)

	# Cover along the route: pillars to hide behind, low walls to crouch behind.
	Props.block(self, Vector3(-8.5, 1.5, 6.5), Vector3(0.8, 3, 0.8), STONE)
	Props.block(self, Vector3(8.5, 1.5, 6.5), Vector3(0.8, 3, 0.8), STONE)
	Props.block(self, Vector3(-8.5, 1.5, -6.5), Vector3(0.8, 3, 0.8), STONE)
	Props.block(self, Vector3(0, 0.5, 8.5), Vector3(4, 1.0, 0.4), STONE)
	Props.block(self, Vector3(-10, 0.5, 0), Vector3(0.4, 1.0, 4), STONE)

	# Floors that change your footsteps. A carpet runner along the dark west
	# side of the patrol: quiet. A metal grate across the lit south side: loud.
	Props.block(self, Vector3(-6.5, 0.02, 0), Vector3(1.6, 0.04, 9), Color(0.45, 0.15, 0.15), "carpet")
	Props.block(self, Vector3(0, 0.02, 5.5), Vector3(9, 0.04, 1.6), Color(0.3, 0.32, 0.36), "metal")

	# A dark alcove in the south-west, walled on three sides and out of the
	# patrol's sight: somewhere to leave a body.
	Props.block(self, Vector3(-16, 1.5, 12), Vector3(0.3, 3, 5), STONE)
	Props.block(self, Vector3(-13.5, 1.5, 14.5), Vector3(5, 3, 0.3), STONE)
	Props.block(self, Vector3(-13.5, 1.5, 9.5), Vector3(5, 3, 0.3), STONE)

	# Two torches: the south-east and north-west corners are lit, the rest is dark.
	_torch(Vector3(7, 3.0, 6))
	_torch(Vector3(-7, 3.0, -6))

	# The strongroom, north-east. Its door faces south; a guard stands at it.
	var room := Vector3(16, 0, -10)
	Props.block(self, room + Vector3(0, 1.5, -3), Vector3(6, 3, 0.3), STONE)
	Props.block(self, room + Vector3(-3, 1.5, 0), Vector3(0.3, 3, 6), STONE)
	Props.block(self, room + Vector3(3, 1.5, 0), Vector3(0.3, 3, 6), STONE)
	Props.block(self, room + Vector3(-1.75, 1.5, 3), Vector3(2.5, 3, 0.3), STONE)
	Props.block(self, room + Vector3(1.75, 1.5, 3), Vector3(2.5, 3, 0.3), STONE)
	Props.block(self, room + Vector3(0, 2.55, 3), Vector3(1.0, 0.9, 0.3), STONE)
	Props.block(self, room + Vector3(0, 3.1, 0), Vector3(6.3, 0.2, 6.3), STONE)
	Props.door(self, room + Vector3(-0.5, 0, 3), 0.0, 1.0, 2.1, true, &"strongroom", "strongroom door")
	Props.chest(self, room + Vector3(0, 0, -2))
	Props.loot(self, room + Vector3(-0.2, 0.15, -2), 300, "gold idol")
	Props.loot(self, room + Vector3(0.2, 0.15, -2), 150, "silver chain")
	_torch(room + Vector3(0, 3.2, 5.5))

	# The strongroom key, on a table in the lit corner the patrol passes.
	Props.block(self, Vector3(9.5, 0.4, 8.5), Vector3(1.2, 0.8, 0.7), Color(0.4, 0.3, 0.2))
	Props.key(self, Vector3(9.5, 0.83, 8.5), &"strongroom", "strongroom key")

	# Things to throw, by the start.
	Props.crate(self, Vector3(-2, 0.2, 17), 0.3, 1.0, Color(0.7, 0.55, 0.3))
	Props.crate(self, Vector3(-1, 0.2, 17), 0.3, 1.0, Color(0.7, 0.55, 0.3))
	Props.crate(self, Vector3(1, 0.25, 17), 0.4, 3.0)

	_sign(Vector3(0, 2.0, 15), "STEALTH GYM\nthe guard circles the keep; two corners are torchlit\nstay dark, stay behind him, crouch to go quiet\nthe red runner is carpet (quiet), the grate is metal (loud)\nZ and C lean round corners\nLEFT CLICK swings the blackjack: from behind, or before he is hunting you\nE shoulders the body: hide it in the dark alcove to the south-west\na body left in torchlight gets found, and he shouts for the sentry\nthrow a crate (E, then left click) to pull him away\nthe key is on the table in the lit corner; the strongroom is north-east")

	# Navigation comes from the level's static bodies, baked right now.
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	# The patrol: a loop around the keep.
	var route := Node3D.new()
	route.name = "PatrolRoute"
	add_child(route)

	for point in [Vector3(-6.5, 0, 5.5), Vector3(6.5, 0, 5.5), Vector3(6.5, 0, -5.5), Vector3(-6.5, 0, -5.5)]:
		var marker := Marker3D.new()
		route.add_child(marker)
		marker.global_position = point

	var patrol: CharacterBody3D = GUARD.instantiate()
	patrol.debug_ai = true
	patrol.name = "PatrolGuard"
	patrol.position = Vector3(-6.5, 0, 5.5)
	add_child(patrol)
	patrol.patrol_route = patrol.get_path_to(route)
	patrol._waypoints.assign(route.get_children())

	# The sentry: no route, so he stands where he is put, facing where he faces.
	var sentry: CharacterBody3D = GUARD.instantiate()
	sentry.debug_ai = true
	sentry.name = "Sentry"
	sentry.position = room + Vector3(0, 0, 4.5)
	sentry.rotation.y = PI
	add_child(sentry)

	var player := PLAYER.instantiate()
	player.debug_traversal = true
	add_child(player)
	player.global_position = Vector3(0, 1.05, 19)
	Props.give_blackjack(player)
	Props.give_tools(player)

	await baker.baked
	patrol._go_to(route.get_child(1).global_position)


## A torch: a flickering light with a pixel flame (scripts/Visual/Torch.gd).
func _torch(at: Vector3) -> void:
	var torch: Node3D = TorchScript.new()
	torch.energy = 2.2
	torch.light_range = 9.0
	# One of the level's own: you can put it out (the guards light it again).
	torch.can_douse = true
	add_child(torch)
	torch.global_position = at


func _sign(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 36
	label.pixel_size = 0.008
	label.modulate = Color(0.95, 0.9, 0.8)
	label.outline_size = 8
	label.shaded = false
	add_child(label)
	label.global_position = at


func _environment() -> void:
	# Night. Almost no ambient light, so shadow really is dark and the
	# lightgem has somewhere to fall to.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.06
	moon.shadow_enabled = true
	add_child(moon)
	moon.rotation_degrees = Vector3(-50.0, 30.0, 0.0)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.02, 0.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.35, 0.5)
	environment.ambient_light_energy = 0.05

	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
