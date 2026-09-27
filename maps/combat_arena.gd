extends Node3D
## The proving grounds: everything the fighting can do, in one walled yard
## at night.
##
##   Godot --path . res://maps/combat_arena.tscn
##
##   THE RING      (north of the start) pull a lever and they come through
##                 the gate: a swordsman, a duelist, a brute, an archer, a
##                 swordsman with an archer behind him, or the gauntlet (waves,
##                 harder each time). Braziers, spikes,
##                 powder barrels and a hanging weight are in there with you.
##                 The gallery on its west side overlooks it: drop on them.
##   TRAINING YARD (west) straw men to cut, shielded ones to break, an arms
##                 master who swings on a steady beat (parry practice) and a
##                 fencer who parries everything (feint practice).
##   HAZARD GARDEN (east) spikes, a ledge, barrels, a hanging cage, a brazier:
##                 a guard at each, to be sent into it.
##   THE CELLS     (north-west, dark) patrols to sneak past, backstab or drop
##                 on from the balcony.
##
##   1-7   the ring's levers from anywhere: swordsman, duelist, brute, archer,
##         swordsman + archer, gauntlet, clear.   R  rest (health, stamina, arrows).
##
## Every parry, block, feint, riposte and broken guard is called out where it
## happened, and the log in the corner says how it went (how early a parry
## was, what a block cost).

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Lights := preload("res://scripts/Visual/Lights/Lights.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const BarrelScript := preload("res://scripts/Combat/Barrel.gd")
const HangingWeightScript := preload("res://scripts/Combat/HangingWeight.gd")
const FireScript := preload("res://scripts/Combat/Fire.gd")
const LeverScript := preload("res://scripts/Interaction/Lever.gd")
const DummyScript := preload("res://scripts/Combat/TrainingDummy.gd")
const GuardFighterScript := preload("res://scripts/AISystem/GuardFighter.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

const STONE := Color(0.4, 0.38, 0.36)
const DARK := Color(0.2, 0.19, 0.21)
const SAND := Color(0.46, 0.4, 0.3)
const WOOD := Color(0.36, 0.25, 0.15)

## The gauntlet: each wave, harder than the last.
const WAVES := [
	[&"swordsman"],
	[&"swordsman", &"swordsman"],
	[&"duelist"],
	[&"swordsman", &"archer"],
	[&"brute"],
	[&"duelist", &"duelist"],
	[&"brute", &"archer", &"swordsman"],
	[&"brute", &"duelist", &"archer", &"swordsman"],
]

## Where the ring's fighters wait, north of its gate.
const PEN := Vector3(0, 0, -30)
const RING_CENTRE := Vector3(0, 0, -14)

var player: CharacterBody3D
var _ring: Array[Node3D] = []
var _wave := -1
var _wave_wait := -1.0
var _portcullis: Node3D
var _gate_open := 0.0
## The portcullis's solid part: in the way while it is down.
var _gate_body: StaticBody3D
var _log: Label
var _banner: Label
var _banner_timer := 0.0
var _lines: Array = []
var _baker: NavigationRegion3D


func _ready() -> void:
	# Everything below is placed after it is added: draw it from where it ends up.
	reset_physics_interpolation.call_deferred()
	tree_exiting.connect(func(): SoundBus.debug = false; GuardFighterScript.max_attackers = 1)
	# A crowd presses harder here: two may swing at you at once.
	GuardFighterScript.max_attackers = 2
	_environment()

	# The ground, everywhere.
	Props.block(self, Vector3(0, -0.5, -14), Vector3(92, 1, 80), DARK, "stone")
	_outer_walls()
	_entry()
	_ring_yard()
	_gallery()
	_training_yard()
	_hazard_garden()
	_cells()

	_baker = NavigationRegion3D.new()
	_baker.set_script(NavBakerScript)
	add_child(_baker)

	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = Vector3(0, 1.05, 16)
	Props.give_weapons(player, 24)
	Props.give_blackjack(player)
	player.inventory.select_by_id(&"sword")
	_hook_player()
	_build_overlay()

	await _baker.baked
	_bar_gate()
	_say("The proving grounds. Pull a lever at the ring, or press 1-7.")


# ---------------------------------------------------------------------------
# The yard
# ---------------------------------------------------------------------------

func _outer_walls() -> void:
	Props.block(self, Vector3(0, 3, 26), Vector3(92, 6, 1), STONE)
	Props.block(self, Vector3(0, 3, -54), Vector3(92, 6, 1), STONE)
	Props.block(self, Vector3(-46, 3, -14), Vector3(1, 6, 80), STONE)
	Props.block(self, Vector3(46, 3, -14), Vector3(1, 6, 80), STONE)

	# Tall walls between the grounds, each with a doorway by the entry: a
	# fight in the ring stays in the ring, and the guards at their posts
	# elsewhere do not come running.
	for side in [-1.0, 1.0]:
		var x: float = side * 17.8
		Props.block(self, Vector3(x, 2, -13.5), Vector3(0.6, 4, 27), STONE)
		Props.block(self, Vector3(x, 2, 2.8), Vector3(0.6, 4, 1.6), STONE)
		Props.block(self, Vector3(x, 3.4, 0.8), Vector3(0.6, 1.2, 2.4), STONE)

	# North of the training yard, with the way to the cells.
	Props.block(self, Vector3(-38.4, 2, -27.2), Vector3(15.2, 4, 0.6), STONE)
	Props.block(self, Vector3(-23.6, 2, -27.2), Vector3(11.6, 4, 0.6), STONE)


func _entry() -> void:
	# A table of arrows, and the primer.
	Props.block(self, Vector3(-5, 0.4, 12), Vector3(2.0, 0.8, 0.9), WOOD, "wood")
	Props.arrows(self, Vector3(-5.4, 0.9, 12), 12)
	Props.arrows(self, Vector3(-4.6, 0.9, 12), 12)
	_torch(Vector3(-5, 2.6, 10.5), false)
	_torch(Vector3(5, 2.6, 10.5), false)
	LeverScript.build(self, Vector3(5, 0, 12), PI, "Rest (R)", _rest)
	_sign(Vector3(0, 2.4, 9), "THE PROVING GROUNDS\n" +
		"LMB attack, hold to charge. Your movement picks the swing.\n" +
		"Click again during a swing: the next follows, quicker (a combo).\n" +
		"RMB block. Just before his blade falls: PARRY, then strike back fast (riposte).\n" +
		"RMB during your own windup: FEINT (draws out his parry).\n" +
		"Q dodge   F kick (breaks a guard, sends them flying)   wheel: weapons\n" +
		"Stamina (the arc under the crosshair): blocks cost it. Out, a blow breaks through.\n" +
		"Falling onto a guard with LMB: DROP ATTACK.", 30)


func _ring_yard() -> void:
	# Sand inside a low wall, a gate on each side.
	Props.block(self, RING_CENTRE + Vector3(0, 0.02, 0), Vector3(23.4, 0.04, 23.4), SAND, "dirt")
	var h := 1.1

	for side in [-1.0, 1.0]:
		# South and north walls, each side of the gate.
		Props.block(self, Vector3(side * 6.8, h * 0.5, -2), Vector3(10.4, h, 0.5), STONE)
		Props.block(self, Vector3(side * 6.8, h * 0.5, -26), Vector3(10.4, h, 0.5), STONE)
		# West and east walls, each side of their gates.
		Props.block(self, Vector3(side * 12, h * 0.5, -7.25), Vector3(0.5, h, 10.5), STONE)
		Props.block(self, Vector3(side * 12, h * 0.5, -20.75), Vector3(0.5, h, 10.5), STONE)

	# Two broken pillars to fight around.
	Props.block(self, Vector3(-5, 1.4, -10), Vector3(0.9, 2.8, 0.9), STONE)
	Props.block(self, Vector3(5.5, 1.1, -18), Vector3(0.9, 2.2, 0.9), STONE)

	# Fire in two corners, spikes on a wall, powder by the gate, a weight hung
	# over the middle.
	FireScript.brazier(self, Vector3(-9.6, 0, -4.4))
	FireScript.brazier(self, Vector3(9.6, 0, -23.6))
	Props.spikes(self, Vector3(-7, 0.95, -25.55), 5.0, 1.3, Vector3.BACK)
	_barrel(Vector3(9.2, 0.4, -20.2))
	_barrel(Vector3(9.9, 0.4, -19.5))
	_barrel(Vector3(-9.8, 0.4, -12.6))
	Props.block(self, Vector3(3, 7.3, -12), Vector3(7, 0.35, 0.35), WOOD, "wood")
	Props.block(self, Vector3(-0.6, 3.6, -12), Vector3(0.35, 7.4, 0.35), WOOD, "wood")
	Props.block(self, Vector3(6.6, 3.6, -12), Vector3(0.35, 7.4, 0.35), WOOD, "wood")
	_hang(Vector3(3, 7.1, -12), 4.0)
	_mark(Vector3(3, 0.05, -12), 1.6)

	for x in [-10.0, 10.0]:
		for z in [-4.0, -24.0]:
			_torch(Vector3(x, 3.0, z))

	# A lantern on a long chain from the beam, over the middle of the ring
	# (a torch hung in the air there before), as bright as the torches and,
	# without its bars, lighting the ring below as the torch did.
	Lights.hanging_lantern(self, Vector3(0.2, 7.12, -12), 2.7, {"energy": 2.4, "light_range": 10.0, "cookie": false, "can_douse": true})

	# The pen they come from, behind the north gate, and its portcullis.
	Props.block(self, Vector3(-4.5, 1.8, -30), Vector3(0.5, 3.6, 8), STONE)
	Props.block(self, Vector3(4.5, 1.8, -30), Vector3(0.5, 3.6, 8), STONE)
	Props.block(self, Vector3(0, 1.8, -34), Vector3(9.5, 3.6, 0.5), STONE)
	Props.block(self, Vector3(-3.1, 1.8, -26.2), Vector3(2.8, 3.6, 0.6), STONE)
	Props.block(self, Vector3(3.1, 1.8, -26.2), Vector3(2.8, 3.6, 0.6), STONE)
	Props.block(self, Vector3(0, 3.3, -26.2), Vector3(3.4, 0.6, 0.6), STONE)
	_torch(Vector3(0, 3.0, -31))
	_build_portcullis(Vector3(0, 0, -26.2))

	# The levers, facing the start.
	var levers := [
		["Swordsman (1)", func(): _release([&"swordsman"])],
		["Duelist (2)", func(): _release([&"duelist"])],
		["Brute (3)", func(): _release([&"brute"])],
		["Archer (4)", func(): _release([&"archer"])],
		["Swordsman and archer (5)", func(): _release([&"swordsman", &"archer"])],
		["The gauntlet (6)", _start_gauntlet],
		["Clear the ring (7)", _clear_ring],
	]

	for i in levers.size():
		var x: float = [-10.5, -7.8, -5.1, 2.8, 5.4, 8.0, 10.6][i]
		LeverScript.build(self, Vector3(x, 0, 1.4), PI, levers[i][0], levers[i][1])

	_sign(Vector3(0, 3.4, -1.6), "THE RING", 64)


## A raised walk down the ring's west side, reached by stairs from the south:
## drop off its edge onto whoever fights below.
func _gallery() -> void:
	var top := 3.2
	# Out over the ring's west edge: step off it and you land inside.
	Props.block(self, Vector3(-13.5, top - 0.15, -14.5), Vector3(5.8, 0.3, 21), WOOD, "wood")

	for z in [-5.0, -10.0, -19.0, -24.5]:
		Props.block(self, Vector3(-16.0, (top - 0.3) * 0.5, z), Vector3(0.35, top - 0.3, 0.35), WOOD, "wood")

	# A rail at the back, none at the front.
	Props.block(self, Vector3(-16.3, top + 0.5, -14.5), Vector3(0.12, 1.0, 21), WOOD, "wood")
	_stairs(Vector3(-15.2, 0, 0.8), Vector3.FORWARD, 16, 0.2, 0.3, 2.4)
	_torch(Vector3(-15.8, top + 2.0, -6), false)
	_torch(Vector3(-15.8, top + 2.0, -22), false)
	_sign(Vector3(-13.5, top + 1.6, -4.4), "THE GALLERY\nstep off over a guard, LMB as you fall", 24)


func _training_yard() -> void:
	var yard := Vector3(-30, 0, -14)
	Props.block(self, yard + Vector3(0, 0.02, 0), Vector3(22, 0.04, 22), Color(0.3, 0.32, 0.24), "grass")

	# Straw men to cut, from any side (from behind they count as unaware).
	for x in [-6.0, -3.0, 0.0]:
		_dummy(yard + Vector3(x, 0, 7), false)

	# Shields up: break them with a power blow or a kick.
	for x in [4.0, 7.0]:
		_dummy(yard + Vector3(x, 0, 7), true)

	_sign(yard + Vector3(0, 2.6, 9.8), "STRAW MEN: quick cuts, power blows, combos, backstabs\nSHIELDS: quick cuts are caught. A power blow or a kick knocks the shield aside.", 26)

	# The arms master: swings on a steady beat, and barely hurts.
	var master := _post(&"trainer", yard + Vector3(-4, 0, -3), PI, true)
	master.speaker_name = "Arms master"
	_sign(yard + Vector3(-4, 2.8, -1.2), "PARRY PRACTICE\nhe swings every second or so\nRMB just after the glint, just before the blade falls", 24)

	# The fencer: parries anything, never swings first.
	var fencer := _post(&"duelist", yard + Vector3(5, 0, -3), PI, true)
	fencer.speaker_name = "Fencer"
	fencer._fighter.parry_chance = 0.95
	fencer._fighter.feint_chance = 0.0
	fencer._fighter.dodge_chance = 0.0
	fencer._fighter.counter_chance = 0.0
	fencer.block_chance = 0.0
	fencer.attack_damage = 3.0
	fencer.attack_cooldown = 999.0
	fencer._attack_timer = 999.0
	_sign(yard + Vector3(5, 2.8, -1.2), "FEINT PRACTICE\nhe parries everything\nRMB during your windup (a feint) spends his parry: then strike", 24)

	for p in [Vector3(-9, 3, 9), Vector3(9, 3, 9), Vector3(-9, 3, -6), Vector3(9, 3, -6)]:
		_torch(yard + p, false)

	_torch(yard + Vector3(0, 3, 0))


func _hazard_garden() -> void:
	var garden := Vector3(30, 0, -14)

	# Spikes on the north wall, a gatekeeper in front of them.
	Props.spikes(self, garden + Vector3(0, 1.0, -11.4), 5.0, 2.0, Vector3.BACK)
	Props.block(self, garden + Vector3(0, 1.2, -11.8), Vector3(5.4, 2.4, 0.6), STONE)
	_post(&"swordsman", garden + Vector3(0, 0, -9.9), PI)
	_torch(garden + Vector3(0, 3.0, -8), false)

	# A ledge six metres up, a lookout at its edge.
	Props.block(self, garden + Vector3(10, 3, 0), Vector3(6, 6, 6), STONE)
	_stairs(garden + Vector3(10, 0, 9.0), Vector3.FORWARD, 20, 0.3, 0.3, 2.4)
	# At the far edge, looking out: come up behind him.
	_post(&"swordsman", garden + Vector3(10, 6, -2.2), 0.0)
	_torch(garden + Vector3(10, 8.2, 3))

	# Powder barrels round a pair of guards.
	_barrel(garden + Vector3(-6, 0.4, 1))
	_barrel(garden + Vector3(-5.3, 0.4, 1.7))
	_barrel(garden + Vector3(-6.6, 0.4, 1.9))
	_post(&"", garden + Vector3(-4.6, 0, 0.2), PI * 0.8)
	_post(&"", garden + Vector3(-6.9, 0, 0.3), -PI * 0.8)

	# A cage of stones over a guard at his post.
	Props.block(self, garden + Vector3(-6, 6.6, -6), Vector3(4, 0.35, 0.35), WOOD, "wood")
	Props.block(self, garden + Vector3(-8, 3.3, -6), Vector3(0.35, 6.6, 0.35), WOOD, "wood")
	Props.block(self, garden + Vector3(-4, 3.3, -6), Vector3(0.35, 6.6, 0.35), WOOD, "wood")
	_hang(garden + Vector3(-6, 6.4, -6), 3.2)
	_post(&"", garden + Vector3(-6, 0, -6), PI)
	_torch(garden + Vector3(-9, 3.0, -4), false)

	# A brazier, and a guard warming his hands at it.
	FireScript.brazier(self, garden + Vector3(4, 0, -4))
	_post(&"", garden + Vector3(4, 0, -5.4), PI)

	# Things to throw.
	for i in 4:
		Props.crate(self, garden + Vector3(-10 + i * 0.8, 0.3, 9), 0.45, 3.0)

	_sign(garden + Vector3(0, 2.6, 10.4), "THE HAZARD GARDEN\nkick them into the spikes, off the ledge, into the fire\nshoot the powder, cut the rope (arrow), throw crates at them", 26)
	_torch(garden + Vector3(0, 3.0, 10), false)


## A dark hall of cells: two patrols and a watchman under a balcony.
func _cells() -> void:
	var hall := Vector3(-30, 0, -44)
	# Walls, a roof, and one way in: a doorway in the south wall.
	Props.block(self, hall + Vector3(-6.6, 3.25, 8.5), Vector3(10.8, 6.5, 0.5), STONE)
	Props.block(self, hall + Vector3(6.6, 3.25, 8.5), Vector3(10.8, 6.5, 0.5), STONE)
	Props.block(self, hall + Vector3(0, 4.55, 8.5), Vector3(2.4, 3.9, 0.5), STONE)
	Props.block(self, hall + Vector3(0, 3.25, -8.5), Vector3(24, 6.5, 0.5), STONE)
	Props.block(self, hall + Vector3(-12, 3.25, 0), Vector3(0.5, 6.5, 17.5), STONE)
	Props.block(self, hall + Vector3(12, 3.25, 0), Vector3(0.5, 6.5, 17.5), STONE)
	Props.block(self, hall + Vector3(0, 6.7, 0), Vector3(24.5, 0.4, 17.5), STONE)

	for x in [-6.0, 0.0, 6.0]:
		Props.block(self, hall + Vector3(x, 3.25, 0), Vector3(0.8, 6.5, 0.8), STONE)

	# The balcony along the north wall, and the stairs up to its west end.
	Props.block(self, hall + Vector3(3, 3.25, -7), Vector3(10, 0.3, 2.4), WOOD, "wood")
	_stairs(hall + Vector3(-5.6, 0, -7.2), Vector3.RIGHT, 12, 0.28, 0.3, 1.8)
	# The watchman, just off the balcony, facing away from it.
	_post(&"", hall + Vector3(4, 0, -4.6), PI)
	_torch(hall + Vector3(4, 2.6, -2.8))

	var route := [hall + Vector3(-9, 0, 5), hall + Vector3(9, 0, 5), hall + Vector3(9, 0, -2), hall + Vector3(-9, 0, -2)]
	_patrol(route, 0)
	_patrol(route, 2)
	_sign(hall + Vector3(0, 2.6, 8.0), "THE CELLS\nstay dark, get behind them\nthe balcony (stairs west): drop on the watchman", 24)


# ---------------------------------------------------------------------------
# The ring
# ---------------------------------------------------------------------------

func _release(kinds: Array) -> void:
	_wave = -1
	_wave_wait = -1.0
	_let_in(kinds)


func _let_in(kinds: Array) -> void:
	_gate_open = 2.2
	Sfx.play(self, &"door_open", Vector3(0, 1.5, -26.2), 2.0, 0.6)

	for i in kinds.size():
		var at := PEN + Vector3((i - (kinds.size() - 1) * 0.5) * 1.6, 0, randf_range(-0.5, 0.5))
		var g := _spawn(kinds[i], at, 0.0)
		# Their shouts are for the ring: the rest of the grounds keep to
		# their own business.
		g.shout_db = 50.0
		g._engage(player)
		_ring.append(g)

	var names := ", ".join(kinds.map(func(k): return String(k)))
	_say("Into the ring: " + names)


func _start_gauntlet() -> void:
	_clear_ring()
	_wave = 0
	_wave_wait = 1.5
	_say("The gauntlet. %d waves." % WAVES.size())


func _clear_ring() -> void:
	for g in _ring:
		if is_instance_valid(g):
			g.queue_free()

	_ring.clear()
	_wave = -1
	_wave_wait = -1.0


func _rest() -> void:
	player.health = player.max_health
	player.combat.stamina = player.combat.stamina_max

	for entry in player.inventory.belt:
		if entry["id"] == &"arrows":
			entry["count"] = maxi(int(entry["count"]), 24)
			player.inventory.changed.emit()

	_say("Rested: health, stamina and arrows restored.")


func _physics_process(delta: float) -> void:
	_ring = _ring.filter(func(g): return is_instance_valid(g) and not g._knocked_out)

	if _wave >= 0:
		if _ring.is_empty() and _wave_wait < 0.0:
			_wave += 1

			if _wave >= WAVES.size():
				_say("The gauntlet is won.")
				_wave = -1
			else:
				_wave_wait = 3.0
				_say("Wave %d of %d cleared." % [_wave, WAVES.size()])

		if _wave_wait >= 0.0:
			_wave_wait -= delta

			if _wave_wait < 0.0 and _wave >= 0 and _wave < WAVES.size():
				_let_in(WAVES[_wave])
				_banner_text("WAVE %d" % (_wave + 1))

	# The portcullis rises for them, and drops behind.
	_gate_open = maxf(_gate_open - delta, 0.0)

	if _portcullis != null:
		var up := 3.0 if _gate_open > 0.0 else 0.0
		_portcullis.position.y = move_toward(_portcullis.position.y, up, delta * (6.0 if up > 0.0 else 3.0))

		# Solid once it is most of the way down.
		if _gate_body != null:
			_gate_body.collision_layer = 1 if _portcullis.position.y < 1.0 else 0


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	match (event as InputEventKey).physical_keycode:
		KEY_1:
			_release([&"swordsman"])
		KEY_2:
			_release([&"duelist"])
		KEY_3:
			_release([&"brute"])
		KEY_4:
			_release([&"archer"])
		KEY_5:
			_release([&"swordsman", &"archer"])
		KEY_6:
			_start_gauntlet()
		KEY_7:
			_clear_ring()
		KEY_R:
			_rest()


## The portcullis stops you and them while it is down. Built after the
## navmesh is baked, so the way through the gate is still a path.
func _bar_gate() -> void:
	_gate_body = StaticBody3D.new()
	_gate_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.4, 3.0, 0.3)
	shape.shape = box
	shape.position.y = 1.5
	_gate_body.add_child(shape)
	add_child(_gate_body)
	_gate_body.global_position = Vector3(0, 0, -26.2)


func _build_portcullis(at: Vector3) -> void:
	_portcullis = Node3D.new()
	add_child(_portcullis)
	_portcullis.global_position = at
	var iron := Props.material(Color(0.2, 0.2, 0.22), 0.6)

	for i in 7:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.07, 3.0, 0.07)
		mesh.material = iron
		bar.mesh = mesh
		bar.position = Vector3(-1.5 + i * 0.5, 1.5, 0.0)
		_portcullis.add_child(bar)

	for y in [0.6, 1.6, 2.6]:
		var rail := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(3.2, 0.07, 0.07)
		mesh.material = iron
		rail.mesh = mesh
		rail.position = Vector3(0.0, y, 0.0)
		_portcullis.add_child(rail)


# ---------------------------------------------------------------------------
# People
# ---------------------------------------------------------------------------

func _spawn(archetype: StringName, at: Vector3, yaw: float) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.debug_ai = false
	# Each part of the grounds is its own: a fight in the ring is not heard
	# at the far posts (an explosion still is).
	g.hearing_acuity = 0.4
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	_hook_guard(g)
	return g


## A guard standing at his post, facing `yaw`. With `stays`, a training post:
## he never takes a step, whatever happens.
func _post(archetype: StringName, at: Vector3, yaw: float, stays := false) -> CharacterBody3D:
	var g := _spawn(archetype, at, yaw)

	if stays:
		g.patrol_speed = 0.0
		g.investigate_speed = 0.0
		g.chase_speed = 0.0
		g._fighter.stays_put = true
		# Kicks and heavy blows do not move him off his mark.
		g._fighter.kick_resist = 0.0

	return g


func _patrol(points: Array, start: int) -> void:
	var route := Node3D.new()
	add_child(route)

	for i in points.size():
		var marker := Marker3D.new()
		route.add_child(marker)
		marker.global_position = points[(start + i) % points.size()]

	var g := _spawn(&"swordsman", points[start], 0.0)
	g.patrol_route = g.get_path_to(route)
	g._waypoints.assign(route.get_children())
	g._go_to(route.get_child(0).global_position, true)


func _dummy(at: Vector3, shield: bool) -> void:
	var dummy: StaticBody3D = DummyScript.new()
	dummy.guards = shield
	add_child(dummy)
	dummy.global_position = at
	dummy.rotation.y = PI
	dummy.struck.connect(func(result, kind, damage): _on_dummy(dummy, result, kind, damage))
	dummy.guard_broken.connect(func(): _popup(dummy.global_position + Vector3.UP * 2.1, "SHIELD BROKEN", Color(1.0, 0.6, 0.2)))


func _barrel(at: Vector3) -> void:
	var barrel: RigidBody3D = BarrelScript.new()
	add_child(barrel)
	barrel.global_position = at
	barrel.reset_physics_interpolation()
	barrel.exploded.connect(func(where): _log_line("Powder barrel", Color(1.0, 0.6, 0.3)))


func _hang(beam: Vector3, rope: float) -> void:
	var weight: Node3D = HangingWeightScript.new()
	weight.drop = rope
	add_child(weight)
	weight.global_position = beam
	weight.crushed.connect(func(victim): _popup(victim.global_position + Vector3.UP * 2.2, "CRUSHED", Color(1.0, 0.5, 0.2)))


# ---------------------------------------------------------------------------
# Calling it out
# ---------------------------------------------------------------------------

func _hook_player() -> void:
	var combat: Node = player.combat
	combat.defended.connect(_on_defended)
	combat.feinted.connect(func(): _log_line("Feint", Color(0.7, 0.85, 1.0)))
	combat.dodged.connect(func(_d): _log_line("Dodge", Color(0.8, 0.8, 0.8)))
	combat.riposte_started.connect(func(): _popup(_ahead(1.4), "RIPOSTE", Color(1.0, 0.85, 0.3)))
	combat.drop_attacked.connect(func(t): _popup(t.global_position + Vector3.UP * 2.0, "DROP ATTACK", Color(1.0, 0.4, 0.2)); _log_line("Drop attack", Color(1.0, 0.5, 0.3)))
	combat.staggered.connect(func(why): _log_line({&"broken": "Your guard broke (no stamina)", &"kicked": "Kicked: guard down", &"flinch": "Cut while winding up: attack lost"}.get(why, String(why)), Color(1.0, 0.45, 0.35)))
	combat.landed.connect(_on_landed)


func _hook_guard(g: CharacterBody3D) -> void:
	g.struck_by.connect(func(result, kind, damage): _on_guard_struck(g, result, kind, damage))
	g.guard_broken.connect(func(): _popup(g.global_position + Vector3.UP * 2.3, "GUARD BROKEN", Color(1.0, 0.6, 0.2)); _log_line("You broke his guard", Color(1.0, 0.7, 0.3)))
	g.feinted.connect(func(): _popup(g.global_position + Vector3.UP * 2.3, "feint!", Color(0.7, 0.85, 1.0)))


func _on_defended(result: StringName) -> void:
	var combat: Node = player.combat
	var early: float = combat._game_time - combat._block_started

	match result:
		&"parry":
			_popup(_ahead(1.0), "PARRY", Color(1.0, 0.95, 0.5))
			_log_line("Parry (raised %.2f s before the blow)" % early, Color(1.0, 0.95, 0.5))
		&"block":
			_log_line("Blocked (raised %.2f s before; a parry needs under %.2f)  stamina %d" % [early, combat.parry_window, int(combat.stamina)], Color(0.85, 0.85, 0.85))
		&"broken":
			_popup(_ahead(1.0), "GUARD BROKEN", Color(1.0, 0.35, 0.25))


func _on_landed(target: Object, result: StringName, damage: float) -> void:
	var combat: Node = player.combat

	match result:
		&"parried":
			_popup((target as Node3D).global_position + Vector3.UP * 2.2, "PARRIED", Color(1.0, 0.4, 0.3))
			_log_line("He parried you: guard up, his answer is coming", Color(1.0, 0.45, 0.35))
		&"blocked":
			_popup((target as Node3D).global_position + Vector3.UP * 2.2, "blocked", Color(0.8, 0.8, 0.85))
		_:
			if combat.combo >= 2:
				_log_line("Combo x%d" % combat.combo, Color(1.0, 0.8, 0.4))


func _on_guard_struck(g: Node3D, result: StringName, kind: StringName, damage: float) -> void:
	if result == &"hit" or result == &"killed":
		var text := "%d" % roundi(damage)

		match kind:
			&"power":
				text = "POWER %d" % roundi(damage)
			&"backstab":
				text = "BACKSTAB"
			&"drop":
				text = "DROP %d" % roundi(damage)
			&"fire", &"blast", &"crush":
				text = "%s %d" % [String(kind), roundi(damage)]

		if player.combat.is_riposte() and kind in [&"quick", &"power"]:
			text = "RIPOSTE %d" % roundi(damage)

		_popup(g.global_position + Vector3.UP * (2.0 + randf() * 0.3), text, Color(1.0, 0.3, 0.2) if result == &"killed" else Color(1.0, 0.85, 0.75))

		if result == &"killed":
			_log_line("%s down (%s)" % [String(g.get("speaker_name")), String(kind)], Color(1.0, 0.5, 0.4))


func _on_dummy(dummy: Node3D, result: StringName, kind: StringName, damage: float) -> void:
	var text := "blocked" if result == &"blocked" else "%s %d" % [String(kind), roundi(damage)]

	if kind == &"quick" and result == &"hit":
		text = "%d" % roundi(damage)

	if player.combat.is_riposte():
		text = "RIPOSTE " + text

	if player.combat.combo >= 2 and result == &"hit":
		text += "  x%d" % player.combat.combo

	_popup(dummy.global_position + Vector3.UP * (2.0 + randf() * 0.25), text, Color(0.8, 0.8, 0.85) if result == &"blocked" else Color(1.0, 0.85, 0.6))


## A word that rises and fades where something happened.
func _popup(at: Vector3, text: String, colour: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 44
	label.pixel_size = 0.006
	label.outline_size = 10
	label.modulate = colour
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.fixed_size = false
	add_child(label)
	label.global_position = at
	var tween := label.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(label, "position:y", label.position.y + 0.7, 1.1)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.1).set_delay(0.35)
	tween.tween_callback(label.queue_free)


func _ahead(distance: float) -> Vector3:
	var eye: Transform3D = player.aim_transform()
	return eye.origin - eye.basis.z * distance + Vector3.UP * 0.25


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_log = Label.new()
	# As wide as the screen allows: a line too long is cut short.
	_log.anchor_right = 1.0
	_log.offset_left = 20.0
	_log.offset_top = 20.0
	_log.offset_right = -20.0
	_log.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_log.add_theme_font_size_override("font_size", 17)
	_log.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_log.add_theme_constant_override("outline_size", 5)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_log)
	_banner = Label.new()
	# Across the top of the screen, centred, whatever its size; wrapped if
	# it is too long for one line.
	_banner.anchor_right = 1.0
	_banner.offset_left = 24.0
	_banner.offset_right = -24.0
	_banner.offset_top = 90.0
	_banner.offset_bottom = 150.0
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_banner)


func _process(delta: float) -> void:
	_banner_timer = maxf(_banner_timer - delta, 0.0)

	if _banner != null:
		_banner.modulate.a = clampf(_banner_timer / 0.5, 0.0, 1.0)

	# Old lines fade out of the log.
	for line in _lines:
		line[2] = float(line[2]) - delta

	_lines = _lines.filter(func(l): return float(l[2]) > 0.0)

	if _log != null:
		var text := ""

		for line in _lines:
			text += String(line[0]) + "\n"

		_log.text = text


func _log_line(text: String, _colour := Color.WHITE) -> void:
	_lines.append([text, _colour, 6.0])

	while _lines.size() > 7:
		_lines.pop_front()


func _say(text: String) -> void:
	_log_line(text, Color(0.95, 0.9, 0.8))


func _banner_text(text: String) -> void:
	if _banner != null:
		_banner.text = text
		_banner_timer = 2.0


# ---------------------------------------------------------------------------
# Building bits
# ---------------------------------------------------------------------------

## Solid steps from the floor: `count` of them, each `rise` up and `run`
## along `direction` from `start` (the foot of the first).
func _stairs(start: Vector3, direction: Vector3, count: int, rise: float, run: float, width: float) -> void:
	var across := Vector3.UP.cross(direction).abs()

	for i in count:
		var top := rise * (i + 1)
		var centre := start + direction * (run * (i + 0.5)) + Vector3.UP * (top * 0.5)
		var size := across * width + direction.abs() * run + Vector3.UP * top
		Props.block(self, centre, size, STONE)


## A dark ring on the floor: under the weight.
func _mark(at: Vector3, radius: float) -> void:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.01
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.25, 0.12, 0.08)
	mesh.material = paint
	disc.mesh = mesh
	add_child(disc)
	disc.global_position = at


## `shadows` off for the lesser lights: every guard who moves near a
## shadowed light has it drawn over again.
func _torch(at: Vector3, shadows := true) -> void:
	# One of the level's own: you can put it out (the guards light it again).
	Lights.torch_at(self, at, 2.4, 10.0, shadows, {"can_douse": true})


func _sign(at: Vector3, text: String, size := 32) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.008
	label.modulate = Color(0.95, 0.9, 0.8)
	label.outline_size = 8
	label.shaded = false
	add_child(label)
	label.global_position = at


func _environment() -> void:
	# Brighter than a stealth level's night: a fight here should be seen.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.light_volumetric_fog_energy = 2.0
	add_child(moon)
	moon.rotation_degrees = Vector3(-50.0, 30.0, 0.0)

	var environment := RetroScript.night_environment(Color(0.42, 0.45, 0.58), 0.5)
	environment.background_color = Color(0.03, 0.04, 0.07)
	environment.volumetric_fog_density = 0.02

	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
