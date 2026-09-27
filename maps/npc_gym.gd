extends Node3D
## The NPC gym: every kind of guard on his own, and all of them together, to
## watch what they do and try what works against them.
##
##   Godot --path . res://maps/npc_gym.tscn
##
##   A corridor runs north from the hub, eight bays off it, each behind its
##   own walls (a fight in one is not heard in the next):
##   1 WATCHMAN   a patrol through light and dark, a noisy floor and a quiet
##                one, a crate to throw: his alert, his sight, his search. A
##                second man stands his post by the patrol's corner: they
##                talk when the patrol stops there, and when one hears
##                something he goes to look while the other covers him. The
##                storeroom door: open it and leave it, and it is noticed.
##                Shoot an arrow into a wall and it is found.
##   2 SWORDSMAN  guards, trades blows, reads a rhythm, kicks a turtle. Parry
##                right on his blow (a perfect deflect), or cut as his comes (a
##                counter); after his glint a cut of yours no longer stops his.
##   3 SWORDMASTER parries and answers, feints, steps out of long swings.
##                Step into her thrust as it comes (forward and Q): Mikiri.
##   4 BRUTE      the blow no guard stops (dodge it: Q), cuts do not stop him.
##   5 ARCHER     keeps his distance behind cover, shoots; kicks you off.
##   6 SQUAD      a swordmaster, a swordsman, a brute and an archer together:
##                a leader and a plan (Squad.gd), called out as it changes.
##   7 BODIES     weak men, spikes, powder, a hanging weight, a ledge: kick
##                them (running, or while they swing), cut them apart.
##   8 ARMS MASTER a steady beat to parry, deflect, counter and Mikiri, and
##                straw men to cut.
##   9 GUARDHOUSE through the hub's south wall: a squad in a lit yard, off-duty
##                men in a barracks down a passage (a man who breaks runs to
##                fetch them: catch him and he throws his blade down and begs
##                for his life; walk away and he runs to his own), and a dark
##                loop of corridors behind to lose them in and watch them hunt
##                you. A lookout on a platform in
##                the yard's far corner calls where you are and rings the bell
##                (and the barracks wakes); crates to be thrown, powder to be
##                shot; landmarks they call you by (the well, the gate, the
##                barracks, the dark passage).
##   10 CLIMB & SWIM at the corridor's north end: a block, a tower with a
##                ladder, two roofs with a gap between, and a pool. Get up,
##                across or into the water and they come after you: they
##                climb, drop, leap, and swim (NavLinks, GuardClimb,
##                GuardWater). Nobody strikes afloat: in the water they swim
##                after you and wait for you to climb out. Hit a man on the
##                ladder and he falls.
##   11 GARRISON  through a door in bay 10's west wall: a courtyard at night
##                and its men at their ease, none of them looking for you,
##                each in his own way (GuardHabits): a patrol with a torch, one
##                on the walkway with a lantern, a man at the gate leaning on
##                the wall, one splitting logs and shifting crates, one at the
##                mess table eating and gossiping, one dozing on a bench in the
##                dark, one at the campfire. A rope and a chain go up to a
##                tower and the walkway. Stir them and it is all dropped.
##
##   1-9  go to that bay and start it (again)     -  bay 10     =  bay 11     0  back to the hub
##   F1   what each of them is thinking, over his head: his temperament,
##        his place, his resolve
##   F2   you cannot be hurt      F4  everyone freezes      R  rest
##   F3   sight cones (the debug overlays)
##   F5   the garrison forgets you (starting a bay does not: what they
##        learn of you, and their dread, carry from one bay to the next)
##
## A lever at each bay's mouth starts it too.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const BarrelScript := preload("res://scripts/Combat/Barrel.gd")
const HangingWeightScript := preload("res://scripts/Combat/HangingWeight.gd")
const LeverScript := preload("res://scripts/Interaction/Lever.gd")
const DummyScript := preload("res://scripts/Combat/TrainingDummy.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const AlarmBellScript := preload("res://scripts/Interaction/AlarmBell.gd")
const WaterScript := preload("res://scripts/Interaction/WaterVolume.gd")
const ClimbScript := preload("res://scripts/PlayerUtils/ClimbVolume.gd")
const Furnishings := preload("res://scripts/Interaction/Furnishings.gd")
const RopeScript := preload("res://scripts/PlayerUtils/VerletRope.gd")

const STONE := Color(0.4, 0.38, 0.36)
const DARK := Color(0.2, 0.19, 0.21)
const SAND := Color(0.46, 0.4, 0.3)
const WOOD := Color(0.36, 0.25, 0.15)
const STATES := ["RELAXED", "SUSPICIOUS", "INVESTIGATING", "SEARCHING", "COMBAT"]
const STATE_COLOURS := [Color(0.55, 0.9, 0.5), Color(0.95, 0.9, 0.4), Color(1.0, 0.7, 0.3), Color(1.0, 0.5, 0.3), Color(1.0, 0.35, 0.3)]

## The bays: [name, the middle of the bay, which side of the corridor it
## opens to (-1 west, 1 east), what the sign says].
const BAYS := [
	["WATCHMAN", Vector3(-17, 0, -8), -1, "A watchman on his rounds, a second at his post. Stay in the dark (the gem), walk on the carpet,\nnot the iron. Throw the crate to draw them off: one looks, one covers. They talk when they stand together.\nLeave the storeroom door open, or an arrow in a wall: they notice. F1: what they think."],
	["SWORDSMAN", Vector3(-17, 0, -26), -1, "A swordsman. He guards, trades blows, strings two together, reads a rhythm (vary it),\nkicks a turtle, lunges from range. Parry right on his blow: a perfect deflect. Cut as his blow\ncomes (a cut for a cut, a thrust for a thrust): a counter. After his glint, a cut will not stop him."],
	["SWORDMASTER", Vector3(-17, 0, -44), -1, "The swordmaster. Parries careless blows and answers fast; feints; steps out of long\nswings (thrusts reach). Her thrust (blue): step into it as it comes (forward + Q) and pin it: Mikiri.\nWear her balance down (the bar over her) and the next blow is a deathblow."],
	["BRUTE", Vector3(-17, 0, -62), -1, "The brute. Red glow and a roar: the blow no guard stops. DODGE (Q).\nCuts do not stop his swing. Only a running kick fells him, reeling."],
	["ARCHER", Vector3(17, 0, -8), 1, "An archer behind cover. He keeps his distance and shoots:\nblock the arrow, or close in round the cover. Up close he kicks you off."],
	["SQUAD", Vector3(17, 0, -26), 1, "A squad: swordmaster, swordsman, brute, archer. A leader and a plan:\nthey surround, strike while you are busy, break a turtle, press you hurt,\nfall back, break one by one when the leader dies. Watch the plan (top right)."],
	["BODIES", Vector3(17, 0, -44), 1, "Weak men to send flying and cut apart. Kick them while they swing, or running.\nInto the spikes, off the ledge, onto the powder. A clean kill takes a limb or a head."],
	["ARMS MASTER", Vector3(17, 0, -62), 1, "The arms master swings on a steady beat: parry just before it lands, or right on it\n(a perfect deflect). Answer his cut with a cut and his thrust with a thrust (a counter), or step into\nhis thrust (forward + Q). Straw men to cut; shielded ones to break. Sprint and swing: a running blow."],
	["GUARDHOUSE", Vector3(0, 0, 24), 0, "The guardhouse. A squad in the yard; two men off duty in the barracks (east); a lookout\non the platform (far corner): he calls where you are, rings the bell, sends a man to look,\nthrows down what is to hand, and comes down when they need him. Break one and he runs\nfor help: catch him and he begs for his life. Walk away and he runs to his own; cut him down\nand the next will not beg. Lose them in the dark (west): they split the search, the lookout\nwatches. A man waiting his turn throws what is near; powder gets shot. F5: the garrison forgets you."],
	["CLIMB & SWIM", Vector3(0, 0, -86.5), 0, "Climb and swim. Get up on the block, up the ladder onto the tower, across the gap,\nor into the pool: they come after you, climbing, dropping, leaping and swimming.\nNobody strikes afloat: they swim after you and wait for you to climb out.\nHit a man on the ladder and he falls. F4 freezes them to watch."],
	["GARRISON", Vector3(-30, 0, -86.75), 0, "The garrison at its ease, and nobody looking for you. Each man in his own way: a patrol\nwith a torch, a lantern up on the walkway, the gate man leaning on the wall, a woodsman\nsplitting logs and shifting crates, a man at the mess table eating and gossiping, one\ndozing on the bench in the dark (creep past him), one at the fire. A rope and a chain go up.\nF1: what each is doing. Stir them and they drop it all."],
]
const BAY_SIZE := 14.0

var player: CharacterBody3D
var _baker: NavigationRegion3D
var _bay_guards := {}
## The guardhouse's off-duty men: not in the fight until fetched; and its
## lookout, not in it until he sees you.
var _barracks: Array = []
## Bay 11's crates, stacked again each time it starts.
var _stock: Array = []
var _posted: Array = []
var _labels_on := true
var _frozen := false
var _label_timer := 0.0
var _log: Label
var _panel: Label
var _banner: Label
var _banner_timer := 0.0
var _lines: Array = []


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	_environment()
	Props.block(self, Vector3(0, -0.5, -30), Vector3(60, 1, 90), DARK, "stone")
	_hall()

	for i in range(BAYS.size()):
		_build_bay(i)

	_baker = NavigationRegion3D.new()
	_baker.set_script(NavBakerScript)
	add_child(_baker)

	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = Vector3(0, 1.05, 8)
	Props.give_weapons(player, 30)
	Props.give_blackjack(player)
	Props.give_tools(player)
	player.inventory.select_by_id(&"sword")
	_hook_player()
	_build_overlay()

	await _baker.baked
	_say("The NPC gym. Press 1-9, - or = (or pull a lever) to start a bay. F1 shows what they think.")


# ---------------------------------------------------------------------------
# The place
# ---------------------------------------------------------------------------

func _hall() -> void:
	# The hub, lit, with the notice.
	_torch(Vector3(-4, 2.6, 6), false)
	_torch(Vector3(4, 2.6, 6), false)
	_sign(Vector3(0, 2.5, 2.5), "THE NPC GYM\n1-9 go to a bay and start it   - bay 10 (climb & swim)   = bay 11 (garrison)   0 back here\n" +
		"F1 what they think   F2 no harm to you   F3 sight cones   F4 freeze them   R rest   F5 they forget you\n" +
		"LMB attack (your look picks the cut)   RMB block/parry   F kick   Q dodge", 28)
	Props.block(self, Vector3(0, 0.4, 5.5), Vector3(2.0, 0.8, 0.9), WOOD, "wood")
	Props.arrows(self, Vector3(-0.4, 0.9, 5.5), 20)
	Props.arrows(self, Vector3(0.4, 0.9, 5.5), 20)
	LeverScript.build(self, Vector3(3, 0, 5.5), PI, "Rest (R)", _rest)

	# The outer walls; the south one with a way through into the guardhouse,
	# the north one at the corridor's end into bay 10.
	Props.block(self, Vector3(-15.75, 3, 12), Vector3(28.5, 6, 1), STONE)
	Props.block(self, Vector3(15.75, 3, 12), Vector3(28.5, 6, 1), STONE)
	Props.block(self, Vector3(-16.0, 3, -72), Vector3(28.0, 6, 1), STONE)
	Props.block(self, Vector3(16.0, 3, -72), Vector3(28.0, 6, 1), STONE)
	Props.block(self, Vector3(-30, 3, -30), Vector3(1, 6, 84), STONE)
	Props.block(self, Vector3(30, 3, -30), Vector3(1, 6, 84), STONE)

	for z in [-8.0, -26.0, -44.0, -62.0]:
		_torch(Vector3(0, 3.0, z + 4.0), false)


## A walled bay off the corridor, open on its corridor side by a gap.
func _build_bay(index: int) -> void:
	if index == 8:
		_build_guardhouse()
		return

	if index == 9:
		_build_waterside()
		return

	if index == 10:
		_build_garrison()
		return

	var spec: Array = BAYS[index]
	var centre: Vector3 = spec[1]
	var side: float = spec[2]
	var half := BAY_SIZE * 0.5
	# The walls between bays, and the back.
	Props.block(self, centre + Vector3(0, 2, half + 1.5), Vector3(BAY_SIZE + 2.0, 4, 0.6), STONE)
	Props.block(self, centre + Vector3(0, 2, -half - 1.5), Vector3(BAY_SIZE + 2.0, 4, 0.6), STONE)
	# The corridor side: two walls and a gap between.
	var mouth: float = centre.x - side * (half + 1.0)
	Props.block(self, Vector3(mouth, 2, centre.z + 5.2), Vector3(0.6, 4, 6.2), STONE)
	Props.block(self, Vector3(mouth, 2, centre.z - 5.2), Vector3(0.6, 4, 6.2), STONE)
	_sign(Vector3(mouth + side * 0.4, 3.2, centre.z), "%d  %s" % [index + 1, spec[0]], 40)
	_sign(centre + Vector3(0, 3.0, half + 1.1), spec[3], 22)
	LeverScript.build(self, Vector3(mouth - side * 0.8, 0, centre.z + 2.6), -side * PI * 0.5, "Start %s" % spec[0], func(): _start_bay(index))

	match index:
		0:
			# Light on one side, dark on the other; iron and carpet underfoot.
			_torch(centre + Vector3(-3.5, 2.6, -3.5))
			Props.block(self, centre + Vector3(2.5, 0.02, 0), Vector3(3.0, 0.04, 9.0), Color(0.35, 0.36, 0.4), "metal")
			Props.block(self, centre + Vector3(-2.5, 0.02, 3.0), Vector3(3.0, 0.04, 4.0), Color(0.45, 0.2, 0.18), "carpet")
			Props.block(self, centre + Vector3(0, 0.6, 0), Vector3(1.4, 1.2, 1.4), STONE)
			# A storeroom in the lit corner, its door on the patrol's way.
			var room := centre + Vector3(-4.8, 0, -5.6)
			Props.block(self, room + Vector3(-1.9, 1.25, 0), Vector3(0.3, 2.5, 2.6), STONE)
			Props.block(self, room + Vector3(0.0, 1.25, -1.15), Vector3(4.1, 2.5, 0.3), STONE)
			Props.block(self, room + Vector3(-1.3, 1.25, 1.15), Vector3(1.5, 2.5, 0.3), STONE)
			Props.block(self, room + Vector3(1.3, 1.25, 1.15), Vector3(1.5, 2.5, 0.3), STONE)
			Props.block(self, room + Vector3(0.0, 2.35, 1.15), Vector3(1.1, 0.3, 0.3), STONE)
			Props.block(self, room + Vector3(1.9, 1.25, 0), Vector3(0.3, 2.5, 2.6), STONE)
			Props.block(self, room + Vector3(0.0, 2.6, 0), Vector3(4.1, 0.2, 2.6), STONE)
			Props.door(self, room + Vector3(-0.55, 0, 1.15), 0.0, 1.1, 2.1, false, &"", "storeroom door")
		4:
			# Cover to shoot from, and to close in round.
			Props.block(self, centre + Vector3(0, 0.6, -3.5), Vector3(4.0, 1.2, 0.5), STONE)
			Props.block(self, centre + Vector3(-3.5, 1.5, 1.0), Vector3(0.8, 3.0, 0.8), STONE)
			Props.block(self, centre + Vector3(3.5, 1.5, 1.5), Vector3(0.8, 3.0, 0.8), STONE)
			_torch(centre + Vector3(0, 2.8, 5.0), false)
		5:
			Props.block(self, centre + Vector3(0, 0.02, 0), Vector3(12.0, 0.04, 12.0), SAND, "dirt")
			Props.block(self, centre + Vector3(-3.0, 1.5, -3.0), Vector3(0.8, 3.0, 0.8), STONE)
			Props.block(self, centre + Vector3(3.0, 1.5, -1.0), Vector3(0.8, 3.0, 0.8), STONE)
			_torch(centre + Vector3(-5.5, 2.8, 5.0), false)
			_torch(centre + Vector3(5.5, 2.8, -5.0), false)
		6:
			# Spikes on the back wall, a ledge to kick off, powder, a weight.
			Props.spikes(self, centre + Vector3(0, 1.0, -half + 0.2), 5.0, 2.0, Vector3.BACK)
			Props.block(self, centre + Vector3(-4.5, 1.25, -3.0), Vector3(3.5, 2.5, 3.0), STONE)
			_stairs(centre + Vector3(-4.5, 0, 2.2), Vector3.FORWARD, 8, 0.3125, 0.3, 2.0)
			_barrel(centre + Vector3(4.0, 0.4, 0.5))
			_barrel(centre + Vector3(4.7, 0.4, 1.2))
			Props.block(self, centre + Vector3(4.0, 5.6, -3.5), Vector3(3.0, 0.35, 0.35), WOOD, "wood")
			Props.block(self, centre + Vector3(2.5, 2.8, -3.5), Vector3(0.35, 5.6, 0.35), WOOD, "wood")
			Props.block(self, centre + Vector3(5.5, 2.8, -3.5), Vector3(0.35, 5.6, 0.35), WOOD, "wood")
			_hang(centre + Vector3(4.0, 5.4, -3.5), 2.4)
			_torch(centre + Vector3(0, 3.0, 4.5), false)
			_torch(centre + Vector3(-4.5, 4.8, -3.0), false)
		7:
			_dummy(centre + Vector3(-3.5, 0, 1.5), false)
			_dummy(centre + Vector3(3.5, 0, 1.5), true)
			_torch(centre + Vector3(0, 2.8, 4.5), false)
		_:
			_torch(centre + Vector3(0, 2.8, 4.5), false)
			_torch(centre + Vector3(0, 2.8, -4.5), false)


## Bay 9, through the hub's south wall: a lit yard for the fight, a
## barracks down a passage to the east where two men sit off duty, and a
## roofed, dark loop of corridors to the west (and a dark hall south of the
## yard) to break away into.
##
##        x -30          -10     0     10               30
##   z 12  +--- hub wall --+-  gap  -+------------------+
##         |  dark loop    |  YARD   |   (closed)       |
##         |   +-------+   |  lit    |                  |
##   z 24  |   | core  |  gap        |                  |
##   z 27  |   |       |   |        gap z 30-33 -> passage
##         |   |       |   +--------+ (yard's south wall, z 33)
##         |   +-------+   dark hall |   passage   +----+ z 38
##   z 49  +--------------------------+------------+barracks
func _build_guardhouse() -> void:
	var spec: Array = BAYS[8]
	# The wing's floor and outer walls.
	Props.block(self, Vector3(0, -0.5, 31), Vector3(60, 1, 36), DARK, "stone")
	Props.block(self, Vector3(-30, 3, 31), Vector3(1, 6, 36), STONE)
	Props.block(self, Vector3(30, 3, 31), Vector3(1, 6, 36), STONE)
	Props.block(self, Vector3(0, 3, 49), Vector3(60, 6, 1), STONE)
	_sign(Vector3(0, 3.4, 11.3), "9  %s" % spec[0], 40)
	LeverScript.build(self, Vector3(3, 0, 10.6), PI, "Start %s" % spec[0], func(): _start_bay(8))

	# The yard, lit: a gap west into the dark, one east (at its far corner)
	# to the passage.
	Props.block(self, Vector3(0, 0.02, 23), Vector3(20, 0.04, 20), SAND, "dirt")
	_wall_along_z(-10.0, 12.5, 24.0)
	_wall_along_z(-10.0, 27.0, 33.0)
	_wall_along_z(10.0, 12.5, 30.0)
	_wall_along_x(33.0, -10.0, 10.0)
	Props.block(self, Vector3(-4, 1.5, 22), Vector3(0.8, 3.0, 0.8), STONE)
	Props.block(self, Vector3(4, 1.5, 28), Vector3(0.8, 3.0, 0.8), STONE)
	_torch(Vector3(-8, 2.8, 16), false)
	_torch(Vector3(8, 2.8, 31), false)
	_sign(Vector3(0, 3.0, 13.4), spec[3], 22)

	# The passage to the barracks: walled from the dark hall to the west.
	_wall_along_x(30.0, 10.0, 30.0)
	_wall_along_z(10.0, 33.0, 49.0)

	# The barracks: a roofed room with a door on the passage, dimly lit.
	_wall_along_x(38.0, 18.0, 30.0)
	_wall_along_z(18.0, 38.0, 41.4)
	_wall_along_z(18.0, 42.6, 49.0)
	Props.block(self, Vector3(24, 4.35, 43.5), Vector3(12, 0.3, 11), STONE)
	Props.door(self, Vector3(18, 0, 42.55), PI * 0.5, 1.1, 2.1)
	Props.block(self, Vector3(26, 0.4, 41), Vector3(1.6, 0.8, 1.0), WOOD, "wood")
	_torch(Vector3(26.5, 2.4, 44), false, 0.9)

	# The dark: a loop of corridors round a solid core, and the hall south
	# of the yard, all roofed against the moon.
	Props.block(self, Vector3(-20, 2.1, 31), Vector3(8, 4.2, 22), STONE)
	Props.block(self, Vector3(-20, 4.35, 30.75), Vector3(20, 0.3, 36.5), STONE)
	Props.block(self, Vector3(0, 4.35, 41), Vector3(20, 0.3, 16), STONE)
	# A door across the west corridor, and one across the south.
	_wall_along_x(31.0, -30.0, -27.55)
	_wall_along_x(31.0, -26.45, -24.0)
	Props.door(self, Vector3(-27.55, 0, 31), 0.0, 1.1, 2.1)
	_wall_along_z(-20.0, 42.0, 45.4)
	_wall_along_z(-20.0, 46.6, 49.0)
	Props.door(self, Vector3(-20, 0, 46.6), PI * 0.5, 1.1, 2.1)

	for at in [Vector3(-13, 1.5, 16), Vector3(-13, 1.5, 38), Vector3(-27, 1.5, 44), Vector3(-4, 1.5, 42), Vector3(5, 1.5, 38)]:
		Props.block(self, at, Vector3(0.8, 3.0, 0.8), STONE)

	# The lookout's platform in the yard's far corner, stairs up its side, and
	# the bell by it.
	Props.block(self, Vector3(-7.5, 1.25, 30.5), Vector3(3.0, 2.5, 3.0), STONE)
	_stairs(Vector3(-3.6, 0, 30.5), Vector3.LEFT, 8, 0.3125, 0.3, 1.4)
	AlarmBellScript.build(self, Vector3(-8.5, 0, 26.3), 0.0)
	# The well in the yard: something to call you by, and to hide behind.
	Props.block(self, Vector3(2.5, 0.5, 20.5), Vector3(1.4, 1.0, 1.4), STONE)

	# What they call places by.
	for mark in [["well", Vector3(2.5, 0, 20.5)], ["gate", Vector3(0, 0, 12.5)], ["barracks", Vector3(18, 0, 42.5)],
			["dark passage", Vector3(-10, 0, 25.5)], ["lookout post", Vector3(-7.5, 2.5, 30.5)], ["bell", Vector3(-8.5, 0, 26.3)]]:
		var landmark := Marker3D.new()
		landmark.set_meta(&"landmark", mark[0])
		landmark.add_to_group(&"landmarks")
		add_child(landmark)
		landmark.global_position = mark[1]


## Bay 10, through the corridor's north wall: things to get up on and a pool
## to swim in, and nothing else. Its floor is thick to make the pool's sides.
##
##        x -15        -4   0      8   12  15
##   z -72  +--- wall -+- gap -+----------+
##          |               in    [block] |
##   z -82  |  +------+                   |
##          |  | POOL |     [roof][roof]  |   roofs 1.8 m, a 1.9 m gap
##          |  |      |                   |
##   z -94  |  +------+          [tower]  |   3.5 m, a ladder on its south face
##          |       they start here       |
##   z -101 +-----------------------------+
func _build_waterside() -> void:
	var spec: Array = BAYS[9]
	_sign(Vector3(0, 3.4, -71.3), "10  %s" % spec[0], 40)
	LeverScript.build(self, Vector3(3, 0, -70.9), 0.0, "Start %s" % spec[0], func(): _start_bay(9))

	# The floor round the pool (x -12..-4, z -94..-82), and its bottom, 2.1 m
	# under the water; the walls.
	Props.block(self, Vector3(0, -1.5, -77.25), Vector3(30, 3, 9.5), DARK, "stone")
	Props.block(self, Vector3(0, -1.5, -97.5), Vector3(30, 3, 7), DARK, "stone")
	Props.block(self, Vector3(-13.5, -1.5, -88), Vector3(3, 3, 12), DARK, "stone")
	Props.block(self, Vector3(5.5, -1.5, -88), Vector3(19, 3, 12), DARK, "stone")
	Props.block(self, Vector3(-8, -3.1, -88), Vector3(8, 1, 12), DARK, "stone")
	WaterScript.build(self, Vector3(-8, -1.55, -88), Vector3(8, 2.1, 12))
	# The west wall, with a way through near its south end into bay 11.
	Props.block(self, Vector3(-15.5, 3, -89.75), Vector3(1, 6, 23.5), STONE)
	Props.block(self, Vector3(-15.5, 3, -73.75), Vector3(1, 6, 3.5), STONE)
	Props.block(self, Vector3(15.5, 3, -86.75), Vector3(1, 6, 29.5), STONE)
	Props.block(self, Vector3(0, 3, -101.5), Vector3(32, 6, 1), STONE)

	# A block to get up on; two roofs with a gap to leap; a tower, up by its
	# ladder only.
	Props.block(self, Vector3(7.5, 0.6, -79), Vector3(3, 1.2, 2.5), STONE)
	Props.block(self, Vector3(1.5, 0.9, -89), Vector3(3, 1.8, 3.5), WOOD, "wood")
	Props.block(self, Vector3(6.4, 0.9, -89), Vector3(3, 1.8, 3.5), WOOD, "wood")
	Props.block(self, Vector3(11, 1.75, -95), Vector3(3, 3.5, 3), STONE)
	_ladder(Vector3(11, 1.7, -93.15), 3.4)

	_sign(Vector3(-8, 3.2, -79.5), spec[3], 22)

	# Lit all over, so they see where you go (the tower's top too).
	for at in [Vector3(-14.9, 2.8, -79), Vector3(-14.9, 2.8, -93), Vector3(14.9, 2.8, -80), Vector3(14.9, 4.2, -93),
			Vector3(-5, 2.8, -100.9), Vector3(6, 2.8, -100.9), Vector3(-7, 2.8, -72.6), Vector3(7, 2.8, -72.6)]:
		_torch(at, false)

	for mark in [["pool", Vector3(-8, -0.5, -88)], ["tower", Vector3(11, 3.5, -95)], ["roofs", Vector3(4, 1.8, -89)]]:
		var landmark := Marker3D.new()
		landmark.set_meta(&"landmark", mark[0])
		landmark.add_to_group(&"landmarks")
		add_child(landmark)
		landmark.global_position = mark[1]


## Bay 11, through the door in bay 10's west wall: a courtyard at night with
## what a garrison at its ease has about it (Furnishings.gd).
##
##        x -45                -30                 -16
##   z -101 +------ walkway (2.5 m, railing) --stairs-+
##          | tower  chain                  crates  |
##          | +rope   woodpile     fire       crates |
##          | bench                           cart   |
##          |           mess table                 door (bay 10)
##   z -72  +-- provisions ---------------------------+
func _build_garrison() -> void:
	var spec: Array = BAYS[10]
	Props.block(self, Vector3(-30, -0.5, -86.75), Vector3(29, 1, 29.5), DARK, "stone")
	Props.block(self, Vector3(-30, 3, -101.5), Vector3(30, 6, 1), STONE)
	Props.block(self, Vector3(-45, 3, -86.75), Vector3(1, 6, 29.5), STONE)
	Props.block(self, Vector3(-37.5, 3, -72), Vector3(15, 6, 1), STONE)
	_sign(Vector3(-15.0, 3.4, -76.75), "11  %s" % spec[0], 40)
	LeverScript.build(self, Vector3(-14.4, 0, -78.9), PI * 0.5, "Start %s" % spec[0], func(): _start_bay(10))
	_sign(Vector3(-22.0, 3.2, -74.0), spec[3], 20)

	# The mess: a table and its chairs, bread on a counter by the wall.
	Furnishings.table(self, Vector3(-33, 0, -80), 0.0)
	Furnishings.provisions(self, Vector3(-39, 0, -73.3), 0.0)
	# A bench against the west wall, in the dark.
	Furnishings.bench(self, Vector3(-44.0, 0, -85), -PI * 0.5)
	Furnishings.campfire(self, Vector3(-28, 0, -88))
	Furnishings.chopping_block(self, Vector3(-39, 0, -95.5), 0.0)
	_stock = Furnishings.crate_piles(self, Vector3(-19.5, 0, -95.0), 0.0, Vector3(-25.0, 0, -95.0), 0.0)
	Furnishings.cart(self, Vector3(-21, 0, -83), 0.0)

	# The walkway along the north wall, stairs up at its east end, a railing
	# along its edge to lean on and look over the yard.
	Props.block(self, Vector3(-32, 1.25, -99.75), Vector3(16, 2.5, 2.5), STONE)
	_stairs(Vector3(-21.6, 0, -99.75), Vector3.LEFT, 8, 0.3125, 0.3, 2.0)
	Furnishings.railing(self, Vector3(-39.6, 2.5, -98.62), Vector3(-24.4, 2.5, -98.62), Vector3(0, 0, 1))

	# A tower in the west corner, up by a rope; a chain up to the walkway's
	# west end.
	Props.block(self, Vector3(-42.5, 2.0, -92), Vector3(3, 4.0, 4), STONE)
	Props.block(self, Vector3(-40.5, 4.1, -92), Vector3(1.4, 0.2, 0.3), WOOD, "wood")
	_rope(Vector3(-40.1, 4.0, -92), 3.6, 0)
	Props.block(self, Vector3(-40.5, 3.4, -99.75), Vector3(1.2, 0.2, 0.3), WOOD, "wood")
	_rope(Vector3(-40.9, 3.3, -99.75), 3.0, 1)

	# Walls to lean on: by the mess, and along the east wall.
	Furnishings.lean_spots(self, Vector3(-36.5, 0, -72.5), Vector3(-30.5, 0, -72.5), Vector3(0, 0, -1), 2.5)
	Furnishings.lean_spots(self, Vector3(-16, 0, -93), Vector3(-16, 0, -86), Vector3(-1, 0, 0), 3.0)

	for at in [Vector3(-44.4, 2.8, -78), Vector3(-44.4, 2.8, -97), Vector3(-30, 4.4, -100.9), Vector3(-16.1, 2.8, -90), Vector3(-26, 2.8, -72.6)]:
		_torch(at, false, 1.8)


## A rope (`style` 0) or a chain (1) hanging `length` from `anchor`.
func _rope(anchor: Vector3, length: float, style: int) -> void:
	var rope: Area3D = RopeScript.new()
	rope.style = style
	rope.length = length
	rope.position = anchor
	add_child(rope)


## A ladder up a wall to the north of `centre` (a ClimbVolume, `height`
## tall, centred there, and its rungs against the wall).
func _ladder(centre: Vector3, height: float) -> void:
	var volume := Area3D.new()
	volume.set_script(ClimbScript)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, height, 0.7)
	shape.shape = box
	volume.add_child(shape)
	add_child(volume)
	volume.global_position = centre
	var foot := centre.y - height * 0.5

	for i in int(height / 0.3):
		var rung := Props.mesh_box(Vector3(0.8, 0.05, 0.05), WOOD)
		add_child(rung)
		rung.global_position = Vector3(centre.x, foot + 0.3 * (i + 1), centre.z - 0.28)

	for x in [-0.42, 0.42]:
		var rail := Props.mesh_box(Vector3(0.06, height, 0.06), WOOD)
		add_child(rail)
		rail.global_position = Vector3(centre.x + x, centre.y, centre.z - 0.28)


## A wall 4.2 m high (to the roofs) running along z at `x`, from `z0` to `z1`.
func _wall_along_z(x: float, z0: float, z1: float) -> void:
	Props.block(self, Vector3(x, 2.1, (z0 + z1) * 0.5), Vector3(0.6, 4.2, z1 - z0), STONE)


## A wall 4.2 m high running along x at `z`, from `x0` to `x1`.
func _wall_along_x(z: float, x0: float, x1: float) -> void:
	Props.block(self, Vector3((x0 + x1) * 0.5, 2.1, z), Vector3(x1 - x0, 4.2, 0.6), STONE)


# ---------------------------------------------------------------------------
# Starting a bay
# ---------------------------------------------------------------------------

func _start_bay(index: int) -> void:
	var spec: Array = BAYS[index]
	var centre: Vector3 = spec[1]
	var side: float = spec[2]

	# One bay at a time: nobody left over from another comes after you.
	for other in range(BAYS.size()):
		_clear_bay(other)
	var guards: Array = []

	match index:
		0:
			guards.append(_patrol([centre + Vector3(-4, 0, -4), centre + Vector3(4, 0, -4), centre + Vector3(4, 0, 4), centre + Vector3(-4, 0, 4)]))
			# His mate at his post by the patrol's corner: they talk when it
			# stops there.
			guards.append(_spawn(&"", centre + Vector3(5.6, 0, -5.2), PI * 0.25))
			Props.crate(self, centre + Vector3(side * 5.0, 0.3, 3.0), 0.4, 2.0)
		1:
			guards.append(_spawn(&"swordsman", centre + Vector3(0, 0, -3), 0.0))
		2:
			guards.append(_spawn(&"duelist", centre + Vector3(0, 0, -3), 0.0))
		3:
			guards.append(_spawn(&"brute", centre + Vector3(0, 0, -3), 0.0))
		4:
			guards.append(_spawn(&"archer", centre + Vector3(0, 0, -5.2), 0.0))
		5:
			guards.append(_spawn(&"duelist", centre + Vector3(0, 0, -2.5), 0.0))
			guards.append(_spawn(&"swordsman", centre + Vector3(-2.0, 0, -3.5), 0.0))
			guards.append(_spawn(&"brute", centre + Vector3(2.4, 0, -4.0), 0.0))
			guards.append(_spawn(&"archer", centre + Vector3(0, 0, -6.0), 0.0))
		6:
			for at in [centre + Vector3(0, 0, -3.8), centre + Vector3(-4.5, 2.5, -3.2), centre + Vector3(3.0, 0, 0.0)]:
				var weak := _spawn(&"swordsman", at, 0.0)
				weak.max_health = 60.0
				weak.health = 22.0
				guards.append(weak)
		7:
			var master := _spawn(&"trainer", centre + Vector3(0, 0, -2.5), 0.0)
			master.patrol_speed = 0.0
			master.investigate_speed = 0.0
			master.chase_speed = 0.0
			master._fighter.stays_put = true
			guards.append(master)
		8:
			guards.append(_spawn(&"duelist", Vector3(0, 0, 26), 0.0))
			guards.append(_spawn(&"swordsman", Vector3(-2.5, 0, 27), 0.0))
			# A craven one: the first to break, and to beg.
			guards.append(_spawn(&"swordsman", Vector3(2.5, 0, 27), 0.0, false, &"craven"))
			guards.append(_spawn(&"archer", Vector3(0, 0, 31), 0.0))
			# Up on his platform, watching the yard: he has to see you first
			# (not one of the squad in the yard until he does).
			_posted.append(_spawn(&"", Vector3(-7.5, 2.5, 30.5), 0.0, true))

			# Things to throw, and powder by the gate; and up on the platform,
			# something for the lookout to throw down.
			for at in [Vector3(6.0, 0.25, 18.0), Vector3(-6.0, 0.2, 21.0), Vector3(7.0, 0.25, 29.0)]:
				Props.crate(self, at, 0.45, 2.5)

			for at in [Vector3(-8.5, 2.7, 31.5), Vector3(-8.5, 2.7, 29.6)]:
				Props.crate(self, at, 0.3, 1.5)

			_barrel(Vector3(5.0, 0.4, 15.5))

			# Off duty, and hard of hearing over their dice: only a man
			# who comes to fetch them brings them.
			for spec_man in [[&"swordsman", Vector3(23, 0, 41), -PI * 0.5], [&"", Vector3(25, 0, 45), PI]]:
				var resting := _spawn(spec_man[0], spec_man[1], spec_man[2])
				resting.hearing_acuity = 0.15
				_barracks.append(resting)
		9:
			guards.append(_spawn(&"swordsman", Vector3(-2, 0, -97.5), PI))
			guards.append(_spawn(&"", Vector3(2.5, 0, -98.5), PI))
		10:
			# The garrison at its ease, each man in his own way; the crates
			# back on their pile.
			Furnishings.restack(_stock, Vector3(-19.5, 0, -95.0), 0.0)
			var torch := _patrol([Vector3(-20, 0, -78), Vector3(-20, 0, -92), Vector3(-35, 0, -92), Vector3(-36, 0, -84)])
			torch.rounds_light = &"torch"
			torch.habits.assign([&"fidget", &"lean", &"visit"])
			guards.append(torch)
			var lantern := _patrol([Vector3(-38, 2.5, -99.9), Vector3(-25, 2.5, -99.9), Vector3(-20, 0, -97.8)])
			lantern.rounds_light = &"lantern"
			lantern.habits.assign([&"rail", &"fidget"])
			guards.append(lantern)
			var gate := _spawn(&"", Vector3(-18.5, 0, -73.4), 0.0, false, &"steady")
			gate.habits.assign([&"lean", &"fidget", &"visit"])
			guards.append(gate)
			var woodsman := _spawn(&"swordsman", Vector3(-35, 0, -93), 0.0, false, &"rash")
			woodsman.habits.assign([&"chop", &"carry", &"pace", &"fidget"])
			woodsman.habit_range = 22.0
			guards.append(woodsman)
			var mess := _spawn(&"", Vector3(-30, 0, -82), 0.0, false, &"craven")
			mess.habits.assign([&"sit", &"eat", &"visit", &"fidget"])
			mess.habit_range = 14.0
			guards.append(mess)
			var dozer := _spawn(&"", Vector3(-41.5, 0, -85), -PI * 0.5, false, &"steady")
			dozer.habits.assign([&"sit"])
			dozer.quirk = &"dozes"
			guards.append(dozer)
			var fireside := _spawn(&"", Vector3(-26.5, 0, -90), PI, false, &"sly")
			fireside.habits.assign([&"tend", &"sit", &"fidget"])
			guards.append(fireside)

	_bay_guards[index] = guards

	# In at the mouth, facing in, whole and armed.
	var mouth: float = centre.x - side * (BAY_SIZE * 0.5 - 0.5)
	player.global_position = Vector3(mouth, 1.05, centre.z)
	player.velocity = Vector3.ZERO
	# Into the bay: west bays open east, so you face west, and the other way.
	player.rotation.y = -PI * 0.5 * side

	# The guardhouse: in through the hub's south wall, facing the yard.
	if index == 8:
		player.global_position = Vector3(0, 1.05, 14.5)
		player.rotation.y = PI
	# Bay 10: in through the corridor's north wall.
	elif index == 9:
		player.global_position = Vector3(0, 1.05, -74.5)
		player.rotation.y = 0.0
	# Bay 11: in through the door from bay 10, facing the yard.
	elif index == 10:
		player.global_position = Vector3(-17.0, 1.05, -76.75)
		player.rotation.y = PI * 0.5
	player.get_node("Neck").rotation.x = 0.0
	player.reset_physics_interpolation()
	_rest()
	player.inventory.select_by_id(&"blackjack" if index == 0 else &"sword")

	# The fights start at once; the watchmen (and the garrison at its ease)
	# have to find you.
	if index != 0 and index != 10:
		for g in guards:
			g._engage(player)

	_banner_text("%d  %s" % [index + 1, spec[0]])
	_say("Bay %d: %s" % [index + 1, spec[0]])


## Everyone and everything from the last go at it: gone.
func _clear_bay(index: int) -> void:
	for g in _bay_guards.get(index, []):
		if is_instance_valid(g):
			# Whatever he had in his arms put down first (a crate goes with
			# him otherwise).
			if g.get("_habits") != null:
				g._habits.interrupt()

			# Out of it at once: gone at the end of the frame, but no more
			# thinking, fighting or joining anything before then.
			g.remove_from_group(&"guards")
			g.set_physics_process(false)
			g.state = 0
			g.queue_free()

	_bay_guards.erase(index)
	var centre: Vector3 = BAYS[index][1]
	var half := Vector2(BAY_SIZE * 0.5 + 1.0, BAY_SIZE * 0.5 + 1.0)

	# The guardhouse: its off-duty men too, and the whole wing.
	if index == 8:
		for resting in _barracks + _posted:
			if is_instance_valid(resting):
				resting.remove_from_group(&"guards")
				resting.set_physics_process(false)
				resting.state = 0
				resting.queue_free()

		_barracks.clear()
		_posted.clear()
		centre = Vector3(0, 0, 30.5)
		half = Vector2(30.0, 18.5)
	elif index == 9:
		half = Vector2(15.5, 15.0)
	elif index == 10:
		half = Vector2(14.5, 15.0)

	for thing in get_tree().get_nodes_in_group(&"bodies"):
		var at: Vector3 = (thing as Node3D).global_position
		var man = thing.man() if thing.has_method("man") else null

		if man != null and man.ragdoll != null and man.ragdoll.is_limp():
			at = man.ragdoll.centre()

		if absf(at.x - centre.x) < half.x and absf(at.z - centre.z) < half.y:
			thing.queue_free()

	for child in get_children():
		var name := String(child.name)

		# (Not the stock the garrison carries about: that is the bay's own.)
		if (name.begins_with("DroppedSword") or name.begins_with("DroppedLantern") or name.begins_with("crate")) and not child.is_in_group(&"stock") and absf((child as Node3D).global_position.x - centre.x) < half.x and absf((child as Node3D).global_position.z - centre.z) < half.y:
			child.queue_free()

	for barrel in get_tree().get_nodes_in_group(&"explosives"):
		var at: Vector3 = (barrel as Node3D).global_position

		if index == 8 and absf(at.x - centre.x) < half.x and absf(at.z - centre.z) < half.y:
			barrel.queue_free()

	SquadScript.clear_all()


func _spawn(archetype: StringName, at: Vector3, yaw: float, lookout := false, preset: StringName = &"") -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.lookout = lookout

	if preset != &"":
		g.temperament = preset

	g.debug_ai = false
	# Each bay its own: a fight in one is not heard in the next.
	g.hearing_acuity = 0.4
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	_hook_guard(g)
	_info_label(g)
	return g


func _patrol(points: Array) -> CharacterBody3D:
	var route := Node3D.new()
	add_child(route)

	for point in points:
		var marker := Marker3D.new()
		route.add_child(marker)
		marker.global_position = point

	var g := _spawn(&"", points[0], 0.0)
	g.patrol_route = g.get_path_to(route)
	g._waypoints.assign(route.get_children())
	g._go_to(route.get_child(0).global_position, true)
	g.tree_exiting.connect(route.queue_free)
	return g


## F5: everything the garrison has learned of you, and its dread, gone.
func _forget() -> void:
	GarrisonScript.clear_all()
	_say("The garrison forgets you")


func _rest() -> void:
	player.health = player.max_health
	player.combat.stamina = player.combat.stamina_max
	player.combat.adrenaline = 0.0

	for entry in player.inventory.belt:
		if entry["id"] == &"arrows":
			entry["count"] = maxi(int(entry["count"]), 30)

	player.inventory.changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key := (event as InputEventKey).physical_keycode

	if key >= KEY_1 and key <= KEY_9:
		_start_bay(key - KEY_1)
		get_viewport().set_input_as_handled()
		return

	match key:
		KEY_MINUS:
			_start_bay(9)
		KEY_EQUAL:
			_start_bay(10)
		KEY_0:
			player.global_position = Vector3(0, 1.05, 8)
			player.rotation.y = 0.0
			player.reset_physics_interpolation()
		KEY_F1:
			_labels_on = not _labels_on
			_say("What they think: %s" % ("shown" if _labels_on else "hidden"))
		KEY_F2:
			player.invulnerable = not player.invulnerable
			_say("You %s be hurt" % ("cannot" if player.invulnerable else "can"))
		KEY_F4:
			_frozen = not _frozen

			for g in get_tree().get_nodes_in_group(&"guards"):
				g.set_physics_process(not _frozen)

			_say("They are %s" % ("frozen" if _frozen else "free"))
		KEY_R:
			_rest()
			_say("Rested: health, stamina, arrows")
		KEY_F5:
			_forget()
		_:
			return

	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# What they are thinking
# ---------------------------------------------------------------------------

func _info_label(g: CharacterBody3D) -> void:
	var label := Label3D.new()
	label.name = "Thinking"
	label.font_size = 30
	# The same size on screen however near he is: up close a label the size
	# of a man would hide the fight it describes.
	label.pixel_size = 0.0016
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.fixed_size = true
	g.add_child(label)
	label.position = Vector3(0, float(g.get("eye_height")) + 0.75, 0)


func _process(delta: float) -> void:
	_banner_timer = maxf(_banner_timer - delta, 0.0)

	if _banner != null:
		_banner.modulate.a = clampf(_banner_timer / 0.5, 0.0, 1.0)

	for line in _lines:
		line[2] = float(line[2]) - delta

	_lines = _lines.filter(func(l): return float(l[2]) > 0.0)

	if _log != null:
		var text := ""

		for line in _lines:
			text += String(line[0]) + "\n"

		_log.text = text

	_label_timer -= delta

	if _label_timer <= 0.0:
		_label_timer = 0.12
		_update_labels()
		_update_panel()


func _update_labels() -> void:
	for g in get_tree().get_nodes_in_group(&"guards"):
		var label := g.get_node_or_null("Thinking") as Label3D

		if label == null:
			continue

		label.visible = _labels_on

		if not _labels_on:
			continue

		var state: int = int(g.state)
		var kind: String = String(g.get("speaker_name"))
		var lines := ["%s  %s  %d/%d" % [kind.to_upper(), STATES[state], roundi(g.health), roundi(g.max_health)]]
		var fighter = g._fighter

		# Who he is.
		if fighter != null and fighter.temper != null:
			var t = fighter.temper
			lines.append("%s  N%.2f D%.2f G%.2f" % [String(t.tag), t.nerve, t.drive, t.guile])

		if g.is_downed():
			lines.append("OFF HIS FEET")
		elif g._rising > 0.0:
			lines.append("getting up")
		else:
			# What he is about, off his own bat (GuardLife, GuardHands).
			var about := _about(g)

			if about != "":
				lines.append(about)

			# His part in the hunt, even alone: what he is doing, the plan,
			# and how near he is to breaking.
			var squad = fighter.squad if fighter != null else null

			if squad != null:
				var status: StringName = squad.status_of(g)
				var doing_now: String = String(fighter.role()).to_upper() if status == &"fighting" or status == &"running" else String(status).to_upper()
				lines.append("%s  (plan %s)  resolve %.2f %s" % [doing_now, String(squad.tactic).to_upper(), squad.resolve_of(g), String(squad.will_of(g))])

			if state == 4 and fighter != null:
				# How he is doing: his mood, his balance, his wounds.
				var status := "OPEN - DEATHBLOW" if fighter.is_open() else String(fighter.mood).to_upper()

				if fighter.posture_max < 9999.0:
					status += "  balance %d/%d" % [roundi(fighter.posture), roundi(fighter.posture_max)]

				if float(g.bleeding) > 0.05:
					status += "  bleeding %.1f" % float(g.bleeding)

				lines.append(status)

				var doing := ""

				if g._phase != &"":
					doing = "%s %s" % [String(g._phase), String(g._attack)]

					var call: StringName = fighter.attack_info().get("call", &"cut")

					if call != &"cut":
						doing += "  (%s)" % String(call).to_upper()
				elif fighter.guarding:
					doing = "guard up"
				elif fighter.is_parrying():
					doing = "parrying"
				elif g._stagger > 0.0:
					doing = "reeling"

				if fighter._read_level > 0.05:
					doing += "  reads you %.1f" % fighter._read_level

				if doing != "":
					lines.append(doing)
			else:
				lines.append("alert %d  sees you %.2f" % [roundi(g.alert), g.visibility])

		label.text = "\n".join(lines)
		label.modulate = STATE_COLOURS[state]


## What he is about besides fighting: talking, covering a friend, keeping
## watch, going for a blade, holding something to throw, his lantern, getting
## clear of powder, dealing with something out of place.
func _about(g: Node) -> String:
	var bits: Array[String] = [String(g.given_name)]
	# His own ways: his quirk, and whether he has nodded off.
	var habits: RefCounted = g.get("_habits")

	if habits != null and habits.quirk != &"":
		bits.append("(%s)" % String(habits.quirk))

	if habits != null and habits.dozing():
		bits.append("ASLEEP")

	if g.lookout:
		bits.append("lookout (come down)" if g._left_post else ("lookout, on his post" if g._holds_post() else "lookout"))

	if g._fighter._throw_meant():
		bits.append("going to throw something")

	if not g._hands.armed:
		bits.append("DISARMED")

	var doing: StringName = g.activity()

	if doing != &"":
		bits.append(String(doing))

	if g._life.covering():
		bits.append("covering a friend")

	if g._life.oddity() != null:
		bits.append("something out of place")

	if g._watching:
		bits.append("keeping watch for the hunt")

	if g._hands.lantern != null:
		bits.append("lantern lit")

	if g.is_evading():
		bits.append("GETTING CLEAR OF POWDER")

	if g._mercy.pleading:
		bits.append("BEGGING FOR HIS LIFE")
	elif g._mercy.sheltered():
		bits.append("safe with his own")
	elif g._mercy.refused:
		bits.append("no mercy asked")

	return "  ".join(bits)


## The hunt after you, in the corner, while there is one (even one man): its
## plan, its heart, what it reads of you, what the garrison knows and dreads,
## and each man's part.
func _update_panel() -> void:
	if _panel == null:
		return

	var squad = SquadScript.of(player)
	var members: Array = squad.members() if squad != null else []

	if members.is_empty():
		_panel.text = ""
		return

	var lead = squad.leader()
	var garrison = GarrisonScript.of(player)
	var text := "HUNT   plan %s   heart %.2f   leader %s%s\n" % [String(squad.tactic).to_upper(), squad.morale, String(lead.get("speaker_name")) if lead != null else "none", "   help coming" if squad.help_coming() else ""]
	text += "they read you:  turtle %.2f  rhythm %.2f  keeping away %.2f  bow %.2f  parry %.2f  dodge %.2f\n" % [squad.read[&"turtle"], squad.read[&"spam"], squad.read[&"kite"], squad.read[&"bow"], squad.read.get(&"parry", 0.0), squad.read.get(&"dodge", 0.0)]
	text += "garrison:  dread %.2f   alarm %.2f   %d dead   %d captains   spared %d   cut down begging %d   known: turtle %.2f rhythm %.2f keeping away %.2f bow %.2f parry %.2f dodge %.2f\n" % [garrison.dread, garrison.alarm, garrison.dead, garrison.captains, garrison.spared.size(), garrison.slain_begging.size(), garrison.habits[&"turtle"], garrison.habits[&"spam"], garrison.habits[&"kite"], garrison.habits[&"bow"], garrison.habits.get(&"parry", 0.0), garrison.habits.get(&"dodge", 0.0)]
	var places := []

	for m in members:
		var t = m._fighter.temper if m.get("_fighter") != null else null
		var status: StringName = squad.status_of(m)
		var part: String = String(squad.role_of(m)) if status == &"fighting" or status == &"running" else String(status)
		places.append("%s (%s): %s" % [String(m.get("speaker_name")), String(t.tag) if t != null else "?", part])

	_panel.text = text + "   ".join(places)


# ---------------------------------------------------------------------------
# Calling it out (as the proving grounds do)
# ---------------------------------------------------------------------------

func _hook_player() -> void:
	var combat: Node = player.combat
	combat.defended.connect(_on_defended)
	combat.feinted.connect(func(): _log_line("Feint"))
	combat.riposte_started.connect(func(): _popup(_ahead(1.4), "RIPOSTE", Color(1.0, 0.85, 0.3)))
	combat.landed.connect(_on_landed)


func _on_defended(result: StringName) -> void:
	if result == &"parry":
		_popup(_ahead(1.0), "PARRY", Color(1.0, 0.95, 0.5))
	elif result == &"broken":
		_popup(_ahead(1.0), "GUARD BROKEN", Color(1.0, 0.35, 0.25))


func _on_landed(target: Object, result: StringName, _damage: float) -> void:
	if result == &"parried":
		_popup((target as Node3D).global_position + Vector3.UP * 2.2, "PARRIED", Color(1.0, 0.4, 0.3))
	elif result == &"blocked":
		_popup((target as Node3D).global_position + Vector3.UP * 2.2, "blocked", Color(0.8, 0.8, 0.85))


func _hook_guard(g: CharacterBody3D) -> void:
	g.struck_by.connect(func(result, kind, damage): _on_struck(g, result, kind, damage))
	g.guard_broken.connect(func(): _popup(g.global_position + Vector3.UP * 2.3, "GUARD BROKEN", Color(1.0, 0.6, 0.2)))
	g.feinted.connect(func(): _popup(g.global_position + Vector3.UP * 2.3, "feint!", Color(0.7, 0.85, 1.0)))
	g.barked.connect(func(text): _log_line("%s: \"%s\"" % [String(g.get("speaker_name")), text]))


func _on_struck(g: Node3D, result: StringName, kind: StringName, damage: float) -> void:
	if result != &"hit" and result != &"killed":
		return

	var text := "%d" % roundi(damage) if kind == &"quick" else "%s %d" % [String(kind), roundi(damage)]
	_popup(g.global_position + Vector3.UP * (2.0 + randf() * 0.3), text, Color(1.0, 0.3, 0.2) if result == &"killed" else Color(1.0, 0.85, 0.75))

	if result == &"killed":
		_log_line("%s down (%s)" % [String(g.get("speaker_name")), String(kind)])


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
	_log = _text_label(Vector2(20, 20), 17)
	layer.add_child(_log)
	_panel = _text_label(Vector2(20, 230), 17)
	_panel.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
	layer.add_child(_panel)
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


## Text at `at` from the top left, as wide as the screen allows: a line too
## long for it is cut short, not run off the screen.
func _text_label(at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.anchor_right = 1.0
	label.offset_left = at.x
	label.offset_top = at.y
	label.offset_right = -at.x
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _log_line(text: String) -> void:
	_lines.append([text, Color.WHITE, 6.0])

	while _lines.size() > 8:
		_lines.pop_front()


func _say(text: String) -> void:
	_log_line(text)


func _banner_text(text: String) -> void:
	if _banner != null:
		_banner.text = text
		_banner_timer = 2.0


# ---------------------------------------------------------------------------
# Building bits
# ---------------------------------------------------------------------------

func _stairs(start: Vector3, direction: Vector3, count: int, rise: float, run: float, width: float) -> void:
	var across := Vector3.UP.cross(direction).abs()

	for i in count:
		var top := rise * (i + 1)
		var centre := start + direction * (run * (i + 0.5)) + Vector3.UP * (top * 0.5)
		Props.block(self, centre, across * width + direction.abs() * run + Vector3.UP * top, STONE)


func _barrel(at: Vector3) -> void:
	var barrel: RigidBody3D = BarrelScript.new()
	add_child(barrel)
	barrel.global_position = at
	barrel.reset_physics_interpolation()


func _hang(beam: Vector3, rope: float) -> void:
	var weight: Node3D = HangingWeightScript.new()
	weight.drop = rope
	add_child(weight)
	weight.global_position = beam


func _dummy(at: Vector3, shield: bool) -> void:
	var dummy: StaticBody3D = DummyScript.new()
	dummy.guards = shield
	add_child(dummy)
	dummy.global_position = at
	dummy.rotation.y = PI


func _torch(at: Vector3, shadows := true, energy := 2.4) -> void:
	var torch: Node3D = TorchScript.new()
	torch.energy = energy
	torch.light_range = 10.0
	torch.shadows = shadows
	# One of the level's own: you can put it out (the guards light it again).
	torch.can_douse = true
	add_child(torch)
	torch.global_position = at


func _sign(at: Vector3, text: String, size := 32) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.008
	label.modulate = Color(0.95, 0.9, 0.8)
	label.outline_size = 8
	label.shaded = false
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(label)
	label.global_position = at


func _environment() -> void:
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	add_child(moon)
	moon.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	var environment := RetroScript.night_environment(Color(0.42, 0.45, 0.58), 0.5)
	environment.background_color = Color(0.03, 0.04, 0.07)
	environment.volumetric_fog_density = 0.02
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
