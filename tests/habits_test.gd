extends Node3D
## A garrison at its ease (GuardHabits, Furnishings, IdleSpot): each man his
## own ways, by his temperament and a quirk of his own. Down on a chair and up
## again, and up off it in a hurry when stirred; back against the wall behind
## him; bread from the provisions; the axe at the block, heard well off; on
## his knees at the fire; crates carried from one pile to the other, let fall
## when he is stirred; over to a friend for a word, the easy man nodding and
## the hard one shaking his head; talk at the table where they sit; forearms
## on a rail; asleep on a bench, blind to you and woken by a noise; rounds
## walked with a torch or a lantern (the blade at his belt), up the stairs
## with it, dropped into a fight and lit again after; up a rope and a chain to
## the ledges beside them; and the navmesh keeping them off the furniture.
##
## Each station stands on its own, 40 m from the next, and each man is set
## to the one thing checked (Guard.habits) and starts on it at once.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const Furnishings := preload("res://scripts/Interaction/Furnishings.gd")
const IdleSpotScript := preload("res://scripts/Interaction/IdleSpot.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const GuardHabitsScript := preload("res://scripts/AISystem/GuardHabits.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const RopeScript := preload("res://scripts/PlayerUtils/VerletRope.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

const RELAXED := 0
const SUSPICIOUS := 1
const COMBAT := 4
## Where you stand while out of it: far off, in the dark.
const AWAY := Vector3(-100, 1.05, 0)

var player: CharacterBody3D
var baker: NavigationRegion3D
var results: Array[String] = []
var heard: Array = []
var _barks := {}


func _ready() -> void:
	# Every man at his temperament's own leanings, no quirks but those given.
	TemperamentScript.rolling = false
	GuardScript.bleeding_on = false
	seed(20260926)
	Props.block(self, Vector3(300, -0.5, 0), Vector3(840, 1, 60))

	# The chair, sat on and got up from.
	Furnishings.chair(self, Vector3(0, 0, -3), 0.0)
	# The wall behind a man's post.
	Props.block(self, Vector3(40, 1.5, 1.2), Vector3(4, 3, 0.4))
	# The provisions, the chopping block, the fire, the crates.
	Furnishings.provisions(self, Vector3(80, 0, -3), 0.0)
	Furnishings.chopping_block(self, Vector3(120, 0, -3), 0.0)
	Furnishings.campfire(self, Vector3(160, 0, -3))
	Furnishings.crate_piles(self, Vector3(200, 0, -2), 0.0, Vector3(206, 0, -2), 0.0, 4)
	# The bench a dozy man sleeps on.
	Furnishings.bench(self, Vector3(280, 0, -3), 0.0)
	# A platform up a flight of stairs (8 steps of 0.3125 m): 2.5 m up.
	Props.block(self, Vector3(333, 1.25, -8), Vector3(6, 2.5, 2.5))

	for i in 8:
		var top := 0.3125 * float(i + 1)
		Props.block(self, Vector3(327.6 + 0.3 * (float(i) + 0.5), top * 0.5, -8), Vector3(0.3, top, 2.0))

	# A tower 4 m high with a rope down its face from an arm; a walkway 2.5 m
	# high with a chain.
	Props.block(self, Vector3(360, 2.0, -8), Vector3(3, 4.0, 3))
	Props.block(self, Vector3(360, 4.1, -6.0), Vector3(0.3, 0.2, 1.2))
	_rope(Vector3(360, 4.0, -5.6), 3.6, 0)
	Props.block(self, Vector3(372, 1.25, -8), Vector3(3, 2.5, 3))
	Props.block(self, Vector3(372, 3.4, -6.0), Vector3(0.3, 0.2, 1.2))
	_rope(Vector3(372, 3.3, -5.6), 3.0, 1)
	# Low furniture, for the navmesh to keep off.
	Furnishings.chair(self, Vector3(400, 0, -3), 0.0)
	Furnishings.bench(self, Vector3(400, 0, 3), 0.0)
	Furnishings.campfire(self, Vector3(405, 0, 0))
	Furnishings.chopping_block(self, Vector3(395, 0, 0), 0.0)
	# A rail to lean on; a table with its chairs.
	Furnishings.railing(self, Vector3(438, 0, -3), Vector3(442, 0, -3), Vector3(0, 0, -1))
	Furnishings.table(self, Vector3(480, 0, -3), 0.0)

	baker = NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.debug_traversal = false
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	player.debug_light_level = 0.0
	player.global_position = AWAY
	SoundBus.add_listener(self)

	await baker.baked
	await _frames(5)
	Sfx.recording = true
	await _run()
	Sfx.recording = false
	SoundBus.remove_listener(self)

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


## Every sound made (SoundBus), for the checks to look through.
func hear_sound(event: Dictionary) -> void:
	heard.append(event)


func _run() -> void:
	# H1 each man his own: his temperament leans him his own way, and rolled
	# (Temperament.rolling), no two men alike
	var favourite := {}
	var tables := []
	var x := 600.0

	for tag in [&"steady", &"stubborn", &"craven", &"rash", &"sly"]:
		var g := _man(Vector3(x, 0, 0), 0.0, tag, [])
		x += 6.0
		g._habits.roll()
		tables.append(g._habits.leanings)
		favourite[tag] = _top(g._habits.leanings)

	TemperamentScript.rolling = true
	var one := _man(Vector3(x, 0, 0), 0.0, &"steady", [])
	var two := _man(Vector3(x + 6.0, 0, 0), 0.0, &"steady", [])
	one._habits.roll()
	two._habits.roll()
	TemperamentScript.rolling = false
	var distinct := {}

	for each in favourite.values():
		distinct[each] = true

	var unlike := true

	for i in tables.size():
		for j in range(i + 1, tables.size()):
			unlike = unlike and tables[i] != tables[j]

	_check("H1 each man his own ways: each temperament leans its own way, and two men of one rolled differ",
		distinct.size() >= 3 and unlike and one._habits.leanings != two._habits.leanings,
		"favourites %s; rolled %s / %s quirks '%s' '%s'" % [favourite, _top(one._habits.leanings), _top(two._habits.leanings), one._habits.quirk, two._habits.quirk])

	# H2 down on the chair near his post, a while, and up again: his blade
	# put by as he sits, the chair letting him in among it, and a step back out
	# of it before he goes
	await _fresh()
	var sitter := _man(Vector3(0, 0, 0), 0.0, &"steady", [&"sit"], &"", 6.0)
	var seat: Node3D = IdleSpotScript.nearest(get_tree(), &"seat", Vector3(0, 0, -3), 1.0, sitter)
	var seen := {}
	var sat_at := Vector3.INF
	var let_in := false
	var put_by := false

	for i in 60 * 25:
		await _frames(1)
		seen[sitter.activity()] = true

		if sitter.activity() == &"sit" and sat_at == Vector3.INF:
			sat_at = sitter.global_position
			let_in = not sitter.get_collision_exceptions().is_empty()
			put_by = not sitter._rig.weapon.visible
			# A while sat; then (rather than wait it all out) up again.
			await _frames(60)
			seen[sitter.activity()] = true
			sitter._habits._t = float(sitter._habits._steps[sitter._habits._step]["time"]) - 0.5

		if sat_at != Vector3.INF and sitter._habits.habit == &"":
			break

	# Back out where he stepped in from (the floor clear of the chair).
	var stepped_out := _flat(sitter.global_position - seat.global_position)
	var came_back := _flat(sitter.global_position - sitter._habits._came_from)
	_check("H2 he sits down on the chair by his post, a while, and gets up again: blade put by, in among the chair, a step back out of it",
		seen.has(&"sit_down") and seen.has(&"sit") and seen.has(&"stand_up") and sat_at != Vector3.INF and _flat(sat_at - seat.global_position) < 0.15
			and let_in and put_by and sitter._habits.habit == &"" and sitter.get_collision_exceptions().is_empty() and sitter._rig.weapon.visible and stepped_out > 0.1 and came_back < 0.05,
		"did %s, sat %.2f m from the seat, let in %s, blade put by %s; after: exceptions %d, blade %s, stepped %.2f m back out to where he came from (%.2f off it)" % [seen.keys(), _flat(sat_at - seat.global_position) if sat_at != Vector3.INF else -1.0, let_in, put_by, sitter.get_collision_exceptions().size(), sitter._rig.weapon.visible, stepped_out, came_back])

	# H3 stirred where he sits: up at once, in a hurry, and a guard again
	await _fresh()
	var stirred := _man(Vector3(0, 0, 0), 0.0, &"steady", [&"sit"], &"", 6.0)
	await _until(func(): return stirred.activity() == &"sit", 60 * 20)
	await _frames(30)
	var seated: bool = stirred.activity() == &"sit"
	SoundBus.emit_sound(Vector3(4, 0, -8), 55.0, self, &"test")
	var hurried := false

	for i in 60:
		await _frames(1)
		hurried = hurried or stirred.activity() == &"stand_up_quick"

	_check("H3 stirred where he sits, he is up at once in a hurry, and a guard again",
		seated and hurried and int(stirred.state) >= SUSPICIOUS and stirred._habits.habit == &"" and stirred._rig.weapon.visible,
		"seated %s hurried %s state %d habit '%s' blade %s" % [seated, hurried, int(stirred.state), stirred._habits.habit, stirred._rig.weapon.visible])

	# H4 back against the wall behind his post, looking out from it
	await _fresh()
	var leaner := _man(Vector3(40, 0, 0), 0.0, &"stubborn", [&"lean"])
	await _until(func(): return leaner.activity() == &"lean", 60 * 12)
	await _frames(30)
	var leaning: bool = leaner.activity() == &"lean"
	var off_wall: float = 1.0 - leaner.global_position.z
	var looks_out: float = (-leaner.global_basis.z).dot(Vector3.FORWARD)
	_check("H4 he leans back on the wall behind his post, looking out from it",
		leaning and absf(off_wall - Furnishings.LEAN_OUT) < 0.12 and looks_out > 0.9,
		"leaning %s, %.2f m off the wall, facing out %.2f" % [leaning, off_wall, looks_out])

	# H5 bread from the provisions, in his hand, eaten there
	await _fresh()
	var eater := _man(Vector3(80, 0, -8), 0.0, &"craven", [&"eat"])
	var ate := {}
	var in_hand := false

	for i in 60 * 20:
		await _frames(1)
		ate[eater.activity()] = true
		in_hand = in_hand or (eater.activity() == &"eat" and eater._habits._held.size() == 1)

		if ate.has(&"eat") and eater._habits.habit == &"":
			break

	_check("H5 he goes to the provisions, takes bread and eats it there, and puts nothing back",
		ate.has(&"reach") and ate.has(&"eat") and in_hand and eater._habits._held.is_empty() and eater._habits.habit == &"",
		"did %s, bread in hand %s, after: held %d" % [ate.keys(), in_hand, eater._habits._held.size()])

	# H6 the axe at the block, blow on blow, heard well off; the blade put by
	# meanwhile and back after
	await _fresh()
	var woodsman := _man(Vector3(120, 0, 2), 0.0, &"rash", [&"chop"])
	heard.clear()
	var thuds_before := _count(&"thud_wood")
	var axe := false
	var chopped := false

	for i in 60 * 30:
		await _frames(1)

		if woodsman.activity() == &"chop":
			chopped = true
			axe = axe or (woodsman._habits._held.size() == 1 and not woodsman._rig.weapon.visible)

		if chopped and woodsman._habits.habit == &"":
			break

	var blows := heard.filter(func(e): return e["kind"] == &"chop" and e["source"] == woodsman)
	var far: float = SoundBus.range_for(GuardHabitsScript.CHOP_DB)
	_check("H6 he splits logs at the block with an axe, blow on blow, each heard well off; his blade back after",
		chopped and axe and blows.size() >= GuardHabitsScript.CHOPS.x and _count(&"thud_wood") - thuds_before >= blows.size() and far > 15.0
			and woodsman._habits._held.is_empty() and woodsman._rig.weapon.visible,
		"chopped %s axe %s, %d blows heard to %.0f m, thuds %d, after: held %d blade %s" % [chopped, axe, blows.size(), far, _count(&"thud_wood") - thuds_before, woodsman._habits._held.size(), woodsman._rig.weapon.visible])

	# H7 down on his knees at the fire, tending it, and up again
	await _fresh()
	var tender := _man(Vector3(160, 0, 1), 0.0, &"sly", [&"tend"])
	var tended := {}
	var by_fire := INF
	var at_it := -1.0

	for i in 60 * 20:
		await _frames(1)
		tended[tender.activity()] = true

		if tender.activity() == &"tend" and at_it < 0.0:
			by_fire = _flat(tender.global_position - Vector3(160, 0, -3))
			at_it = (-tender.global_basis.z).dot((Vector3(160, 0, -3) - tender.global_position).normalized())
			await _frames(60)
			tender._habits._t = float(tender._habits._steps[tender._habits._step]["time"]) - 0.5

		if at_it >= 0.0 and tender._habits.habit == &"":
			break

	_check("H7 he kneels at the fire, facing it, tends it, and gets up again",
		tended.has(&"kneel_down") and tended.has(&"tend") and tended.has(&"kneel_up") and by_fire < 1.0 and at_it > 0.9,
		"did %s, %.2f m from the fire facing it %.2f" % [tended.keys(), by_fire, at_it])

	# H8 a crate from the fuller pile carried to the other and set down there
	await _fresh()
	var carrier := _man(Vector3(203, 0, 2), 0.0, &"rash", [&"carry"])
	var piles := _piles(Vector3(200, 0, -2), Vector3(206, 0, -2))
	var before := [GuardHabitsScript._stock_at(piles[0]).size(), GuardHabitsScript._stock_at(piles[1]).size()]
	var carried := {}
	var in_arms := false

	for i in 60 * 30:
		await _frames(1)
		carried[carrier.activity()] = true
		in_arms = in_arms or (carrier.activity() == &"carry" and carrier._habits._crate != null)

		if carried.has(&"set_down") and carrier._habits.habit == &"":
			break

	await _frames(60)
	var after := [GuardHabitsScript._stock_at(piles[0]).size(), GuardHabitsScript._stock_at(piles[1]).size()]
	_check("H8 he carries a crate in his arms from the fuller pile to the other and sets it down there",
		carried.has(&"reach") and in_arms and carried.has(&"set_down") and before == [4, 0] and after == [3, 1],
		"did %s, crate in arms %s, piles %s -> %s" % [carried.keys(), in_arms, before, after])

	# H9 stirred with a crate in his arms: he lets it fall
	carrier._habits._rested = GuardHabitsScript.IDLE_AFTER
	carrier._habits._wait = 0.0
	await _until(func(): return carrier.activity() == &"carry" and carrier._habits._crate != null, 60 * 25)
	var crate: RigidBody3D = carrier._habits._crate
	await _frames(20)
	SoundBus.emit_sound(carrier.global_position + Vector3(0, 0, -7), 55.0, self, &"test")
	await _frames(40)
	var let_fall := crate != null and is_instance_valid(crate) and not crate.freeze and crate.get_parent() == self and carrier._habits._crate == null
	_check("H9 stirred with a crate in his arms, he lets it fall",
		let_fall and carrier._habits.habit == &"" and int(carrier.state) >= SUSPICIOUS,
		"had one %s, let fall %s, habit '%s' state %d" % [crate != null, let_fall, carrier._habits.habit, int(carrier.state)])

	# H10 over to a friend at his ease for a word: they talk, turn and turn
	# about
	await _fresh()
	var visitor := _man(Vector3(240, 0, 0), 0.0, &"steady", [&"visit"])
	var friend := _man(Vector3(240, 0, -7), PI, &"rash", [&"chop"])
	visitor._life._talk_rest = 0.0
	friend._life._talk_rest = 0.0
	var went := false
	var close := INF
	var listened := {}

	for i in 60 * 30:
		await _frames(1)
		went = went or visitor._habits.habit == &"visit"

		if visitor._life.talking() and friend._life.talking():
			close = minf(close, visitor.global_position.distance_to(friend.global_position))
			listened[friend.activity()] = true
			listened[visitor.activity()] = true

		if not _barks_of(visitor).is_empty() and not _barks_of(friend).is_empty() and not visitor._life.talking():
			break

	_check("H10 he goes over to a friend at his ease for a word, and they talk, turn and turn about",
		went and close < 2.5 and not _barks_of(visitor).is_empty() and not _barks_of(friend).is_empty() and listened.has(&"listen"),
		"went %s, %.1f m apart talking, did %s, lines %d/%d" % [went, close, listened.keys(), _barks_of(visitor).size(), _barks_of(friend).size()])

	# H11 listening, an easy man nods along; a hard one shakes his head
	var nods := [0, 0]
	var shakes := [0, 0]

	for i in 400:
		for m in 2:
			var listener: Node = visitor if m == 0 else friend
			listener._life._take_line()
			nods[m] += 1 if listener._life._react == &"nod" else 0
			shakes[m] += 1 if listener._life._react == &"shake" else 0

	_check("H11 listening, an easy man mostly nods along, a hard one mostly shakes his head",
		nods[0] > shakes[0] * 3 and shakes[1] > nods[1],
		"steady nods %d shakes %d; rash nods %d shakes %d (of 400)" % [nods[0], shakes[0], nods[1], shakes[1]])

	# H12 two sat at the table talk where they sit
	await _fresh()
	var diner := _man(Vector3(478, 0, 0), 0.0, &"steady", [&"sit"])
	var other := _man(Vector3(482, 0, 0), 0.0, &"craven", [&"sit"])
	var table_talk := [false, false]
	var both_sat := false

	for i in 60 * 30:
		await _frames(1)

		# Both down: a word is due (the rest after the last one over).
		if not both_sat and diner.activity() == &"sit" and other.activity() == &"sit":
			both_sat = true
			diner._life._talk_rest = 0.0
			other._life._talk_rest = 0.0

		table_talk[0] = table_talk[0] or diner.activity() == &"sit_talk"
		table_talk[1] = table_talk[1] or other.activity() == &"sit_talk"

		if table_talk[0] and table_talk[1]:
			break

	_check("H12 two sat at the table talk where they sit",
		table_talk[0] and table_talk[1],
		"sat talking %s, now %s / %s" % [table_talk, diner.activity(), other.activity()])

	# H13 forearms on the rail, looking out over it
	await _fresh()
	var railer := _man(Vector3(440, 0, 0), 0.0, &"steady", [&"rail"])
	await _until(func(): return railer.activity() == &"rail", 60 * 12)
	await _frames(30)
	var on_rail: bool = railer.activity() == &"rail"
	var over: float = (-railer.global_basis.z).dot(Vector3.FORWARD)
	var back_from: float = railer.global_position.z - (-3.0)
	_check("H13 he leans his forearms on the rail and looks out over it",
		on_rail and over > 0.9 and absf(back_from - Furnishings.RAIL_BACK) < 0.12,
		"on the rail %s, facing out %.2f, %.2f m back from it" % [on_rail, over, back_from])

	# H14 a man given to it nods off on the bench: head down, blind to you
	# right before him in the light, and a noise wakes him with a start
	await _fresh()
	var dozer := _man(Vector3(280, 0, 0), 0.0, &"steady", [&"sit"], &"dozes", 6.0)
	await _until(func(): return dozer.activity() == &"doze", 60 * 30)
	await _frames(20)
	var asleep: bool = dozer.activity() == &"doze"
	var bowed: bool = dozer._habits.head().y < -0.3
	player.debug_light_level = 1.0
	_put_player(dozer.global_position + Vector3(0, 1.05, -3.2))
	await _frames(180)
	var blind: bool = int(dozer.state) == RELAXED and dozer.activity() == &"doze"
	_put_player(AWAY)
	player.debug_light_level = 0.0
	SoundBus.emit_sound(dozer.global_position + Vector3(4, 0, 2), 55.0, self, &"test")
	var started := false

	for i in 60:
		await _frames(1)
		started = started or dozer.activity() == &"stand_up_quick"

	var woken: bool = _barks_of(dozer).any(func(t): return _is_line(t, &"woken"))
	_check("H14 a dozy man nods off on the bench, head down: blind to you before him in the light, woken by a noise with a start",
		asleep and bowed and blind and started and woken and int(dozer.state) >= SUSPICIOUS,
		"asleep %s bowed %s blind %s started %s woken %s state %d lines %s" % [asleep, bowed, blind, started, woken, int(dozer.state), _barks_of(dozer)])

	# H15 his rounds with a torch held up: lit, only a look about on the way,
	# dropped into a fight, lit again a while after
	await _fresh()
	var torch := _rounds([Vector3(316, 0, 4), Vector3(316, 0, 14)], &"torch")
	await _frames(60)
	var lit: bool = torch._hands.lantern != null and torch._hands.light_kind == &"torch" and torch.activity() == &"carry_torch"
	var left: bool = _held_in(torch._hands.lantern, &"hand_l")
	var busied := {}

	for i in 60 * 20:
		await _frames(1)
		busied[torch._habits.habit] = true

	torch._engage(player)
	await _frames(10)
	var dropped: bool = torch._hands.lantern == null and not get_tree().get_nodes_in_group(&"dropped_lights").is_empty()
	torch.alert = 0.0
	torch._set_state(RELAXED)
	await _frames(60)
	var not_yet: bool = torch._hands.lantern == null
	await _until(func(): return torch._hands.lantern != null, 60 * 6)
	var relit: bool = torch._hands.lantern != null and torch._hands.light_kind == &"torch"
	_check("H15 his rounds with a torch held up: nothing but a look about on the way, dropped into a fight, lit again a while after",
		lit and left and busied.keys().all(func(h): return h in [&"", &"fidget"]) and dropped and not_yet and relit,
		"lit %s in his left hand %s, about %s, dropped %s, not at once %s, relit %s" % [lit, left, busied.keys(), dropped, not_yet, relit])

	# H16 his rounds with a lantern held out, his blade at his belt: up the
	# stairs with it (walked, not climbed), and into a fight it drops and the
	# blade comes out
	await _fresh()
	var lantern := _rounds([Vector3(324, 0, -8), Vector3(334, 2.5, -8)], &"lantern")
	var up := {}
	var belted := true

	for i in 60 * 25:
		await _frames(1)
		up[lantern.activity()] = true

		if lantern._hands.lantern != null:
			belted = belted and not lantern._rig.weapon.visible

		if lantern.global_position.y > 2.4:
			break

	var on_top: bool = lantern.global_position.y > 2.4
	lantern._engage(player)
	await _frames(10)
	_check("H16 his rounds with a lantern held out, blade at his belt: up the stairs with it, and into a fight it drops and the blade comes out",
		on_top and up.has(&"carry_lantern") and belted and not (up.has(&"climb") or up.has(&"ladder")) and lantern._hands.lantern == null and lantern._rig.weapon.visible,
		"up %s did %s belted %s; in the fight: light %s blade %s" % [on_top, up.keys(), belted, lantern._hands.lantern != null, lantern._rig.weapon.visible])

	# H17 up a rope to the tower top beside it, and a chain to the walkway,
	# hand over hand
	var rope_links := _links_near(Vector3(360, 0, -5.6), 1.5)
	var chain_links := _links_near(Vector3(372, 0, -5.6), 1.5)
	var tops := []

	for way in [[Vector3(360, 0, -3), Vector3(360, 4.0, -8)], [Vector3(372, 0, -3), Vector3(372, 2.5, -8)]]:
		await _fresh()
		var climber := _man(way[0], 0.0, &"steady", [&"chop"])
		climber._home.origin = way[1]
		var did := await _watch(climber, func(): return climber.global_position.y > (way[1] as Vector3).y - 0.3, 60 * 25)
		tops.append([climber.global_position.y > (way[1] as Vector3).y - 0.3, did.has(&"ladder")])

	_check("H17 he goes up a rope to the tower top beside it, and a chain to the walkway, hand over hand",
		rope_links.has(&"rope") and chain_links.has(&"rope") and tops.all(func(t): return t[0] and t[1]),
		"links by the rope %s by the chain %s; up (there, hand over hand) %s" % [rope_links.keys(), chain_links.keys(), tops])

	# H18 the navmesh keeps them off the furniture: no way over a seat, a
	# bench, a stump or the fire, and room round each to pass
	var map := get_world_3d().navigation_map
	var floor_y: float = NavigationServer3D.map_get_closest_point(map, Vector3(400, 0, -9)).y
	var kept := []

	for piece in [[Vector3(400, 0, -3), 0.44], [Vector3(400, 0, 3), 0.44], [Vector3(405, 0, 0), 0.2], [Vector3(395, 0, 0), 0.45]]:
		var on_top_of: Vector3 = (piece[0] as Vector3) + Vector3.UP * (float(piece[1]) + 0.05)
		var nearest := NavigationServer3D.map_get_closest_point(map, on_top_of)
		kept.append(snappedf(_flat(nearest - on_top_of), 0.01))

	var across := NavigationServer3D.map_get_path(map, Vector3(400, 0, -5), Vector3(400, 0, -1), true)
	var highest := -INF

	for point in across:
		highest = maxf(highest, point.y)

	_check("H18 the navmesh keeps them off the furniture: none walked over, room round each",
		kept.all(func(k): return k > 0.4) and across.size() > 2 and highest - floor_y < 0.15,
		"nearest walkable to each top %s m off; across the chair %d points, highest %.2f over the floor" % [kept, across.size(), highest - floor_y])


# ---------------------------------------------------------------------------

## A man at `at` facing `yaw`, of temperament `tag`, set to `habits` only
## (none: his temperament's), with `quirk`, finding things to do within
## `reach`, and at it at once: no waiting about first, no small talk unless a
## check wants it.
func _man(at: Vector3, yaw: float, tag: StringName, habits: Array, quirk: StringName = &"", reach := 10.0) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = &""
	g.temperament = tag
	g.debug_ai = false
	g.habits.assign(habits)
	g.quirk = quirk
	g.habit_range = reach
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._habits._wait = 0.0
	g._life._talk_rest = 999.0
	_barks[g] = []
	g.barked.connect(func(t): _barks[g].append(t))
	return g


## A man walking `points` round with his `light` ("torch", "lantern").
func _rounds(points: Array, light: StringName) -> CharacterBody3D:
	var route := Node3D.new()
	add_child(route)
	route.add_to_group(&"habits_routes")

	for point in points:
		var marker := Marker3D.new()
		route.add_child(marker)
		marker.global_position = point

	var g := _man(points[0], 0.0, &"steady", [&"fidget", &"sit", &"lean"])
	g.rounds_light = light
	g.patrol_wait = 2.0
	g.patrol_route = g.get_path_to(route)
	g._waypoints.assign(route.get_children())
	g._waypoint_index = 1
	g._go_to(points[1], true)
	return g


func _rope(anchor: Vector3, length: float, style: int) -> void:
	var rope: Area3D = RopeScript.new()
	rope.style = style
	rope.length = length
	rope.position = anchor
	add_child(rope)


## The two crate piles by their places ([from, to]).
func _piles(from: Vector3, to: Vector3) -> Array:
	var found := [null, null]

	for spot in get_tree().get_nodes_in_group(&"idle_spots"):
		if spot.get("kind") != &"pile":
			continue

		if _flat((spot as Node3D).global_position - from) < 0.1:
			found[0] = spot
		elif _flat((spot as Node3D).global_position - to) < 0.1:
			found[1] = spot

	return found


## The favourite of `leanings` (name -> pull).
func _top(leanings: Dictionary) -> StringName:
	var best: StringName = &""
	var most := -1.0

	for each in leanings.keys():
		if float(leanings[each]) > most:
			most = float(leanings[each])
			best = each

	return best


## Whether `thing` is held on `bone` (a BoneAttachment3D above it).
func _held_in(thing: Node, bone: StringName) -> bool:
	var at := thing

	while at != null:
		if at is BoneAttachment3D:
			return (at as BoneAttachment3D).bone_name == bone

		at = at.get_parent()

	return false


func _links_near(point: Vector3, reach: float) -> Dictionary:
	var kinds := {}

	for link in baker.get_node("TraversalLinks").get_children():
		var a: Vector3 = link.global_transform * (link as NavigationLink3D).start_position
		var b: Vector3 = link.global_transform * (link as NavigationLink3D).end_position

		for end in [a, b]:
			if Vector2(end.x - point.x, end.z - point.z).length() < reach:
				var kind: StringName = link.get_meta(&"kind")
				kinds[kind] = int(kinds.get(kind, 0)) + 1
				break

	return kinds


## Up to `max_frames`, until `done` (and half a second more): what `g` did
## meanwhile (his activities).
func _watch(g: Node, done: Callable, max_frames: int) -> Dictionary:
	var did := {}
	var after := -1

	for i in max_frames:
		await _frames(1)

		if not is_instance_valid(g):
			break

		var doing: StringName = g.activity()

		if doing != &"":
			did[doing] = int(did.get(doing, 0)) + 1

		if after < 0 and done.call():
			after = 30

		if after >= 0:
			after -= 1

			if after <= 0:
				break

	return did


## A clean start: nobody left, nothing remembered, you away in the dark.
func _fresh() -> void:
	for g in get_tree().get_nodes_in_group(&"guards"):
		g.remove_from_group(&"guards")
		g.set_physics_process(false)
		g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"habits_routes"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	_put_player(AWAY)
	player.debug_light_level = 0.0
	await _frames(5)
	LightProbe.invalidate()


func _put_player(at: Vector3) -> void:
	player.movement_state = 0
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0
	player.combat._reset()
	player.reset_physics_interpolation()


func _barks_of(g: Node) -> Array:
	return _barks.get(g, [])


## One of the lines any temperament has for `situation`.
func _is_line(text: String, situation: StringName) -> bool:
	for tag in TemperamentScript.MORE_LINES:
		if text in (TemperamentScript.MORE_LINES[tag] as Dictionary).get(situation, []):
			return true

	return false


func _count(sound: StringName) -> int:
	var n := 0

	for entry in Sfx.recorded:
		if entry[0] == sound:
			n += 1

	return n


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
