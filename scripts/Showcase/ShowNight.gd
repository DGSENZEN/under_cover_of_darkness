extends RefCounted
## The night the NPC showcase plays (ShowDirector runs it): five acts of
## beats over the garrison yard (maps/npc_showcase.gd). What the guards do is
## their own; the beats move only the intruder (IntruderBrain), wait for the
## world to come true, and ask the camera for its shots.
##
##   I.   The Watch at Rest   no intruder: a stretch of the night at its
##                             ease, condensed: talk by the fire, dice, the
##                             captain's round (the sleeper booted), the fire
##                             burning low and fed, a story, the watch
##                             changing (Jory takes the postern from Hendrik),
##                             the wall, the lookout.
##   II.  A Knife in the Dark  in over the east wall and along the alley; he
##                             waits for the archer to be far along the wall
##                             and the carrier to be coming round the store,
##                             then the knife in the back of the man at the
##                             postern, and the carrier sees him over the body.
##   III. The Cry             the camp rouses; he sprints down the dark alley
##                             (faster than they run), goes to ground in its
##                             far corner, and is lost to them: the bell, the
##                             lanterns, the hunt.
##   IV.  Steel               he steps into the firelight and fights them,
##                             drawing out the squad: a steady exchange (they
##                             take their places round him), a turtle (they
##                             send the brute to break it), parries (the man in
##                             front of him thrown open and cut down), the captain
##                             (the brute goes berserk), then the wavering
##                             (a man throws down his blade and begs).
##   V.   The ending          overwhelmed (his armour lifted, they cut him
##                             down), the victor (he spares the man begging him
##                             and walks away), or over the wall (up the
##                             stairs, over, off the roofs and into the canal,
##                             and they come after him).
##
## A shot: {"type": wide | two | close | track | reveal, "subjects": [men]}.
## A subject is a cast name, "intruder", "nearest", "@talk" (the men of the
## latest conversation) or "@gathering:<kind>" (the men of that gathering).

const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TalkDirectorScript := preload("res://scripts/AISystem/Talk/TalkDirector.gd")
const GatheringScript := preload("res://scripts/AISystem/Gathering.gd")

## Guard.Alert.
const RELAXED := 0
const SUSPICIOUS := 1
const INVESTIGATING := 2
const SEARCHING := 3
const COMBAT := 4

## Act II: how easily he is seen while he sneaks in (the director's hand).
const SNEAK_EXPOSURE := 0.25
## He waits in the shadow for the archer to be this far from the postern,
## and for the carrier to be coming round the store: carrying, this near the
## crates' drop and no nearer.
const ARCHER_FAR := 12.0
const CARRIER_COMING := Vector2(4.0, 9.0)
## Over the body, this long, before he runs for the dark.
const OVER_THE_BODY := 1.6
## Act III: nobody has seen him for this long: he is lost to them.
const LOST_FOR := 3.0
## Act IV: the exchange ends with this many men at his flanks (or at
## TRADE_ENOUGH s).
const FLANKERS := 2
const TRADE_ENOUGH := 20.0
## The victor: the man he spares is up off his knees and this far from where
## he begged (running to his friends: GuardMercy's "spared").
const SPARED_RAN := 4.0
## Act I: the talk by the fire lasts at least this long; the captain's round
## is enough once she has stopped at this many men; the fire is fed past
## this; burning low is this much fuel (the director lets it burn down to
## it when its beat comes).
const ROUND_ENOUGH := 3
const FIRE_FED := 0.7
const FIRE_LOW := 0.32
## The ending's titles.
const ENDING_TITLES := {&"overwhelmed": "V. Overwhelmed", &"victor": "V. The Victor", &"escape": "V. Over the Wall"}

var map: Node3D

## name -> what he has said (the last few lines).
var _said := {}
var _bell_rung := false
var _unseen := 0.0
## Deathblows struck (a man thrown open and cut down: Guard.deathblow), and
## men cut down by his ripostes (a parry answered): the parry beat's end.
var _deathblows := 0
var _riposte_kills := 0
var _parry_mark := 0
## The ending being played; the man spared and where he begged.
var _ending: StringName = &""
var _spared: Node3D = null
var _spared_at := Vector3.ZERO
## The ending came true (it stays true: the spared man may come back).
var _ending_came := false
## Act I: the conversations started when a beat began (to know its own), and
## the round's visits so far.
var _played_at_beat := 0
var _rounds_at_beat := 0


func _init(p_map: Node3D) -> void:
	map = p_map

	for name in map.cast:
		var man: Node = map.cast[name]
		_said[name] = []
		man.barked.connect(_heard.bind(name))
		man.deathblow.connect(func() -> void: _deathblows += 1)

	for bell in map.get_tree().get_nodes_in_group(&"alarm_bells"):
		bell.rung.connect(func(_by: Node) -> void: _bell_rung = true)

	map.intruder_spawned.connect(func(i: CharacterBody3D) -> void:
		i.combat.felled.connect(func(_man: Node3D, riposte: bool) -> void:
			if riposte:
				_riposte_kills += 1))


func acts() -> Array:
	return [_act_one(), _act_two(), _act_three(), _act_four(), _act_five()]


# ---------------------------------------------------------------------------
# I. The Watch at Rest
# ---------------------------------------------------------------------------

func _act_one() -> Dictionary:
	return {
		"title": "I. The Watch at Rest",
		"enter": func() -> void:
			# The talkers need not wait out their rest before a word.
			for name in map.cast:
				var man := _man(name)
				if man != null:
					man._life._talk_rest = randf_range(0.0, 3.0),
		"beats": [
			_look(&"establish", 8.0, &"wide", []),
			{"name": &"fire_talk", "shot": _shot(&"two", ["@talk"]), "min": 10.0, "enough": 22.0, "timeout": 40.0,
				"do": _mark_talk,
				"until": func() -> bool: return _talk_ended_since()},
			{"name": &"dice", "shot": _shot(&"two", ["@gathering:dice"]), "min": 12.0, "enough": 30.0, "timeout": 60.0,
				"do": func() -> void:
					_mark_talk()
					_gatherings().request(&"dice"),
				"until": func() -> bool: return _played_since("dice_")},
			{"name": &"round", "shot": _shot(&"track", ["Mirelle"]), "min": 10.0, "enough": 30.0, "timeout": 60.0,
				"do": func() -> void:
					_rounds_at_beat = _round_visits()
					_gatherings().request(&"round", ["Mirelle"]),
				"until": func() -> bool: return _round_visits() - _rounds_at_beat >= ROUND_ENOUGH},
			{"name": &"fire_fed", "shot": _shot(&"close", ["@gathering:fire"]), "min": 4.0, "timeout": 50.0,
				"do": func() -> void:
					# The fire has burnt low: someone sees to it.
					var fire: Variant = map.get("fire")
					if fire != null and is_instance_valid(fire) and not fire.low():
						fire.fuel = FIRE_LOW
					_gatherings().request(&"fire"),
				"until": func() -> bool:
					var fire: Variant = map.get("fire")
					return fire == null or not is_instance_valid(fire) or float(fire.fuel) > FIRE_FED},
			{"name": &"story", "shot": _shot(&"two", ["@gathering:story"]), "min": 15.0, "enough": 45.0, "timeout": 70.0,
				"do": func() -> void:
					_mark_talk()
					_gatherings().request(&"story"),
				"until": func() -> bool: return _played_since("story_") and not _talking_in("story_")},
			{"name": &"watch_change", "shot": _shot(&"two", ["Jory", "Hendrik"]), "min": 6.0, "timeout": 60.0,
				"do": func() -> void: _gatherings().request(&"watch_change", ["Jory", "Hendrik"]),
				"until": func() -> bool:
					var jory := _man("Jory")
					var rota: Variant = map.get("rota")
					return jory != null and rota != null and rota.duty_of(jory) == &"postern" and _flat(jory.global_position, map.marks["postern_post"]) < 1.0},
			_look(&"wall", 8.0, &"track", ["Wat"]),
			_look(&"lookout", 7.0, &"close", ["Aldous"]),
		],
	}


## The conversations played so far, noted as a beat begins.
func _mark_talk() -> void:
	_played_at_beat = _talk().played().size() if _talk() != null else 0


## A conversation begun since the beat began has ended (not a remark).
func _talk_ended_since() -> bool:
	var talk := _talk()

	if talk == null:
		return false

	var since: Array = talk.played().slice(_played_at_beat)
	var live: Array = talk.talks().map(func(t): return t["id"])
	return since.any(func(id): return not live.has(id))


## A conversation whose id begins so has been played since the beat began.
func _played_since(prefix: String) -> bool:
	var talk := _talk()
	return talk != null and talk.played().slice(_played_at_beat).any(func(id): return String(id).begins_with(prefix))


func _talking_in(prefix: String) -> bool:
	var talk := _talk()
	return talk != null and talk.talks().any(func(t): return String(t["id"]).begins_with(prefix))


## How many men the captain has stopped at on her rounds tonight.
func _round_visits() -> int:
	var talk := _talk()
	return talk.played().filter(func(id): return String(id).begins_with("round_")).size() if talk != null else 0


func _talk() -> RefCounted:
	return TalkDirectorScript.of(map)


func _gatherings() -> RefCounted:
	return GatheringScript.of(map)


## Jumped to a later act: the watch has changed (Jory has the postern,
## Hendrik is on his rounds), as Act I would have left it.
func _after_the_watch_change() -> void:
	var rota: Variant = map.get("rota")
	var jory := _man("Jory")
	var hendrik := _man("Hendrik")

	if rota == null:
		return

	if hendrik != null:
		rota.assign(hendrik, &"yard_round")
		var route: Node3D = map.get_node_or_null("YardRoute")

		if route != null and route.get_child_count() > 0:
			hendrik.global_position = (route.get_child(0) as Node3D).global_position
			hendrik.reset_physics_interpolation()

	if jory != null:
		rota.assign(jory, &"postern")
		# Put there once Hendrik has gone from it in the physics too (else
		# he lands on Hendrik and is carried off with him).
		var held: WeakRef = weakref(jory)
		var post: Vector3 = map.marks["postern_post"]
		map.get_tree().create_timer(0.1, true, true).timeout.connect(func() -> void:
			var man := held.get_ref() as Node3D

			if man != null and is_instance_valid(man) and not man._knocked_out:
				man.global_position = post
				man.rotation.y = -PI * 0.5
				man.velocity = Vector3.ZERO
				man.reset_physics_interpolation())


# ---------------------------------------------------------------------------
# II. A Knife in the Dark
# ---------------------------------------------------------------------------

func _act_two() -> Dictionary:
	return {
		"title": "II. A Knife in the Dark",
		"stage": _after_the_watch_change,
		"enter": func() -> void:
			var i: Node3D = map.spawn_intruder(map.marks["drop_in"], PI)
			i.exposure_scale = SNEAK_EXPOSURE
			i.crouched = true,
		"beats": [
			{"name": &"drop_in", "shot": _shot(&"track", ["intruder"]), "timeout": 25.0,
				"do": func() -> void: _verb(&"go_to", [map.marks["alley_wait"], &"sneak"]),
				"until": func() -> bool: return _brain() != null and _brain().done()},
			{"name": &"his_moment", "shot": _shot(&"two", ["intruder", "Wat"]), "min": 1.0, "timeout": 30.0,
				"until": _his_moment},
			{"name": &"the_knife", "shot": _shot(&"track", ["intruder", "Jory"]), "timeout": 20.0,
				"do": func() -> void: _verb(&"backstab", [_man("Jory")]),
				"until": func() -> bool: return _dead("Jory")},
			{"name": &"the_witness", "shot": _shot(&"close", ["Ned"]), "min": OVER_THE_BODY, "timeout": 12.0,
				"do": func() -> void:
					var i := _intruder()
					if i != null:
						i.exposure_scale = 1.0
					_verb(&"stand", [])
					_verb(&"face", [_man_position("Ned")]),
				"until": func() -> bool: return _state("Ned") >= SEARCHING or _has_said("Ned", "Murder")},
			# His brother knew the voice of that cry.
			{"name": &"grief", "shot": _shot(&"close", ["Osric"]), "min": 3.0, "timeout": 20.0,
				"until": func() -> bool: return _has_said("Osric", "Jory") or _man("Osric") == null},
		],
	}


## His moment: the archer far along the wall, the carrier coming round the
## store with a crate.
func _his_moment() -> bool:
	var wat := _man("Wat")
	var archer_far: bool = wat == null or _flat(wat.global_position, map.marks["postern_post"]) >= ARCHER_FAR
	var ned := _man("Ned")

	if ned == null:
		return archer_far

	var drop: Vector3 = map.get_node("CratesDrop").global_position
	var to_drop := _flat(ned.global_position, drop)
	var coming: bool = ned._rota.carried != null and not ned._rota._swapped and to_drop >= CARRIER_COMING.x and to_drop <= CARRIER_COMING.y
	return archer_far and coming


# ---------------------------------------------------------------------------
# III. The Cry
# ---------------------------------------------------------------------------

func _act_three() -> Dictionary:
	return {
		"title": "III. The Cry",
		"stage": func() -> void:
			# Jumped to: the man at the postern dead, the intruder over him, the
			# carrier at the body with the alarm in him.
			_after_the_watch_change()
			var i: Node3D = map.spawn_intruder(map.marks["postern_post"] + Vector3(0.2, 0, 1.2), PI)
			var jory := _man("Jory")
			if jory != null:
				jory.take_hit(999.0, i, &"backstab", jory.global_position + Vector3.UP * 1.2, Vector3.FORWARD)
			var ned := _man("Ned")
			if ned != null:
				ned.global_position = map.marks["postern_post"] + Vector3(-3.0, 0, 5.5)
				ned.alert = 100.0
				ned.last_known_position = i.global_position
				ned.has_last_known = true,
		"beats": [
			{"name": &"the_cry", "shot": _shot(&"reveal", ["Ned"]), "timeout": 20.0,
				"do": func() -> void:
					var i := _intruder()
					if i != null:
						i.exposure_scale = 1.0
					_verb(&"go_to", [map.marks["hide"], &"run"]),
				"until": func() -> bool: return _out_of_rest(["Mirelle", "Osric", "Piers", "Brand", "Tam"]) and (_brain() == null or _brain().done())},
			{"name": &"lost_him", "shot": _shot(&"track", ["intruder"]), "timeout": 20.0,
				"do": func() -> void: _verb(&"hide_at", [map.marks["hide"]]),
				"until": _lost_him},
			{"name": &"the_hunt", "shot": _shot(&"wide", []), "min": 4.0, "timeout": 30.0,
				"until": func() -> bool: return _searching() >= 2 and _lanterns() >= 1},
		],
	}


# ---------------------------------------------------------------------------
# IV. Steel
# ---------------------------------------------------------------------------

func _act_four() -> Dictionary:
	return {
		"title": "IV. Steel",
		"stage": _stage_fight.bind(false),
		"beats": [
			{"name": &"found", "shot": _shot(&"two", ["intruder", "Osric"]), "timeout": 25.0,
				"do": func() -> void:
					var i := _intruder()
					if i != null:
						i.exposure_scale = 1.0
					_verb(&"go_to", [map.marks["found"], &"walk"]),
				"until": func() -> bool: return _fighting() >= 2},
			{"name": &"trade", "shot": _shot(&"two", ["intruder", "Osric"]), "min": 8.0, "enough": TRADE_ENOUGH, "timeout": 30.0,
				"do": func() -> void: _verb(&"fight", [&"trade"]),
				"until": func() -> bool: return _flankers() >= FLANKERS},
			{"name": &"turtle", "shot": _shot(&"two", ["intruder", "Brand"]), "timeout": 25.0,
				"do": func() -> void: _verb(&"fight", [&"turtle"]),
				"until": _breaking},
			# Whoever stands in front of him: his blows turned aside and
			# answered, until one is cut down (thrown open and given the
			# deathblow, or felled by a riposte).
			{"name": &"parry", "shot": _shot(&"two", ["intruder", "nearest"]), "timeout": 60.0,
				"do": func() -> void:
					_parry_mark = _deathblows + _riposte_kills
					_verb(&"fight", [&"parry"]),
				"until": func() -> bool: return _deathblows + _riposte_kills > _parry_mark},
			{"name": &"focus", "shot": _shot(&"two", ["intruder", "Mirelle"]), "timeout": 60.0,
				"do": func() -> void: _verb(&"fight", [&"focus", _man("Mirelle")]),
				"until": func() -> bool: return _dead("Mirelle")},
			{"name": &"press", "shot": _shot(&"wide", []), "timeout": 40.0,
				"do": func() -> void: _verb(&"fight", [&"press"]),
				"until": func() -> bool: return _pleader() != null},
		],
	}


## Jumped to: the man at the postern dead, the intruder at the fire, the
## fighters on him and everyone else roused; for the ending, the swordsman
## and the captain dead too.
func _stage_fight(for_the_end: bool) -> void:
	_after_the_watch_change()
	var i: Node3D = map.spawn_intruder(map.marks["found"], PI * 0.75)
	i.exposure_scale = 1.0
	var dead := ["Jory", "Osric", "Mirelle"] if for_the_end else ["Jory"]

	for name in dead:
		var man := _man(name)

		if man != null:
			man.take_hit(999.0, i, &"backstab" if name == "Jory" else &"power", man.global_position + Vector3.UP * 1.2, Vector3.FORWARD)

			# (Dead before any hunt: the garrison hears of it as the hunt would
			# have told it: Squad.member_died.)
			GarrisonScript.of(i).on_death(name == "Mirelle", name)

	# Late in the fight, the two craven men have been cut badly: they are the
	# wavering.
	if for_the_end:
		for name in ["Piers", "Ned"]:
			var man := _man(name)

			if man != null:
				man.health = man.max_health * 0.22

	for name in map.cast:
		var man := _man(name)

		if man == null:
			continue

		if for_the_end or name in ["Mirelle", "Osric", "Brand", "Wat"]:
			man._engage(i)
		else:
			man.alert = maxf(float(man.alert), 60.0)
			man.last_known_position = i.global_position
			man.has_last_known = true


# ---------------------------------------------------------------------------
# V. The ending
# ---------------------------------------------------------------------------

func _act_five() -> Dictionary:
	return {
		"title": func() -> String: return ENDING_TITLES.get(_ending_now(), "V."),
		"stage": _stage_fight.bind(true),
		"beats": func() -> Array: return _ending_beats(_ending_now()),
	}


func _ending_now() -> StringName:
	if _ending == &"":
		_ending = map.director.chosen_ending() if map.get("director") != null else &"escape"

	return _ending


func _ending_beats(ending: StringName) -> Array:
	match ending:
		&"overwhelmed":
			return [
				{"name": &"overwhelmed", "shot": _shot(&"two", ["intruder"]), "timeout": 75.0,
					"do": func() -> void:
						var i := _intruder()
						if i != null:
							i.fall()
						_verb(&"fight", [&"trade"]),
					"until": func() -> bool: return _intruder() == null},
				_look(&"silence", 5.0, &"wide", []),
			]
		&"victor":
			return [
				{"name": &"break_them", "shot": _shot(&"wide", []), "timeout": 40.0,
					"do": func() -> void: _verb(&"fight", [&"press"]),
					"until": func() -> bool: return _pleader() != null},
				{"name": &"spare", "shot": _shot(&"two", ["intruder"]), "timeout": 40.0,
					"do": func() -> void:
						_spared = _pleader()
						_spared_at = _spared.global_position if _spared != null else Vector3.ZERO
						_verb(&"fight", [&"spare"]),
					# (Nobody begging, nobody to spare: on to his walk out.)
					"until": func() -> bool: return _spared == null or _spared_ran()},
				{"name": &"walk_out", "shot": _shot(&"track", ["intruder"]), "timeout": 30.0,
					"do": func() -> void: _verb(&"go_to", [map.marks["gate"], &"walk"]),
					"until": func() -> bool: return _brain() == null or _brain().done()},
			]

	# Over the wall: up the stairs, along the wall-walk, over it, off the
	# roofs and into the canal.
	var route: Array[Vector3] = [map.marks["east_stairs"], map.marks["walk_east"], map.marks["over_wall"], map.marks["roofs"], map.marks["bank"], map.marks["canal"]]
	return [
		{"name": &"break_off", "shot": _shot(&"track", ["intruder"]), "timeout": 75.0,
			"do": func() -> void: _verb(&"flee_by", [route]),
			"until": _escaped},
		_look(&"gone", 5.0, &"wide", []),
	]


## Whether the ending came true, and what came of it (for the checks).
func ending_done() -> bool:
	match _ending:
		&"overwhelmed":
			return _intruder() == null
		&"victor":
			return _spared_ran()
		&"escape":
			return _escaped()

	return false


func ending_outcome() -> String:
	match _ending:
		&"overwhelmed":
			return "the intruder %s" % ("dead" if _intruder() == null else "standing")
		&"victor":
			return "spared %s, %.1f m away" % [_spared.given_name if _spared != null and is_instance_valid(_spared) else "nobody", _flat(_spared.global_position, _spared_at) if _spared != null and is_instance_valid(_spared) else 0.0]
		&"escape":
			var i := _intruder()
			return "the intruder %s, followed %s" % ["afloat" if i != null and i._water.swimming else "not afloat", _followed()]

	return "no ending"


func _spared_ran() -> bool:
	if _ending_came:
		return true

	if _spared == null or not is_instance_valid(_spared) or _spared._knocked_out:
		return false

	_ending_came = not bool(_spared._mercy.pleading) and _flat(_spared.global_position, _spared_at) >= SPARED_RAN
	return _ending_came


func _escaped() -> bool:
	var i := _intruder()
	_ending_came = _ending_came or (i != null and bool(i._water.swimming) and _followed())
	return _ending_came


## A guard gone after him over the wall: outside it, or in the water.
func _followed() -> bool:
	for man in map.get_tree().get_nodes_in_group(&"guards"):
		if (man as Node3D).global_position.z < -16.6 or bool(man._water.swimming):
			return true

	return false


func _lost_him() -> bool:
	var seen := false

	for man in map.get_tree().get_nodes_in_group(&"guards"):
		if bool(man.get("can_see_target")):
			seen = true
			break

	_unseen = 0.0 if seen else _unseen + Engine.time_scale / float(Engine.physics_ticks_per_second)
	return _brain() != null and _brain().done() and _unseen >= LOST_FOR


# ---------------------------------------------------------------------------
# Beats, shots, and what is true
# ---------------------------------------------------------------------------

## A beat that only looks: `length` s on its shot.
func _look(beat_name: StringName, length: float, type: StringName, names: Array) -> Dictionary:
	return {"name": beat_name, "min": length, "shot": _shot(type, names)}


## A shot of `names` (cast names, or "intruder"), found when the shot is
## taken (the intruder is made in Act II).
func _shot(type: StringName, names: Array) -> Dictionary:
	return {"type": type, "subjects": names.map(func(n): return n)}


## The men a shot names, as nodes (ShowCamera asks through this).
func subjects(shot: Dictionary) -> Array:
	var found := []

	for name in shot.get("subjects", []):
		if String(name) == "@talk":
			found.append_array(_talkers())
			continue

		if String(name).begins_with("@gathering:"):
			found.append_array(_gathered(StringName(String(name).trim_prefix("@gathering:"))))
			continue

		var node: Node3D = _intruder() if name == "intruder" else (_nearest() if name == "nearest" else _man(name))

		if node != null:
			found.append(node)

	return found


## The men of the latest conversation going on (not a call in a fight); the
## captain and her swordsman if there is none.
func _talkers() -> Array:
	var talk := _talk()
	var live: Array = talk.talks().filter(func(t): return (t["members"] as Array).size() >= 2) if talk != null else []

	if not live.is_empty():
		return (live[-1]["members"] as Array).filter(func(m): return m != null and is_instance_valid(m))

	return [_man("Mirelle"), _man("Osric")].filter(func(m): return m != null)


## The men of the gathering of `kind` going on; else whoever it would be
## (for the fire, the man nearest it).
func _gathered(kind: StringName) -> Array:
	for g in _gatherings().live():
		if g["kind"] == kind:
			return (g["members"] as Array).filter(func(m): return m != null and is_instance_valid(m))

	var fire: Variant = map.get("fire")

	if kind == &"fire" and fire != null and is_instance_valid(fire):
		var best: Node3D = null

		for name in map.cast:
			var man := _man(name)

			if man != null and (best == null or man.global_position.distance_to((fire as Node3D).global_position) < best.global_position.distance_to((fire as Node3D).global_position)):
				best = man

		if best != null:
			return [best]

	return _talkers()


func _man(name: String) -> Node3D:
	var man: Variant = map.cast.get(name)

	if man == null or not is_instance_valid(man) or (man as Node3D)._knocked_out:
		return null

	return man as Node3D


## The man nearest the intruder (the one in front of him).
func _nearest() -> Node3D:
	var i := _intruder()

	if i == null:
		return null

	var best: Node3D = null
	var best_distance := INF

	for man in map.get_tree().get_nodes_in_group(&"guards"):
		var d := (man as Node3D).global_position.distance_to(i.global_position)

		if d < best_distance and not man._knocked_out:
			best_distance = d
			best = man as Node3D

	return best


func deathblows() -> int:
	return _deathblows


func riposte_kills() -> int:
	return _riposte_kills


func _man_position(name: String) -> Vector3:
	var man := _man(name)
	return man.global_position if man != null else map.marks["fire"]


func _intruder() -> Node3D:
	var i: Variant = map.intruder

	if i == null or not is_instance_valid(i) or (i as Node3D).is_dead:
		return null

	return i as Node3D


func _brain() -> RefCounted:
	var i := _intruder()
	return i.brain if i != null else null


## One of the intruder's verbs (IntruderBrain), if he is still up to it.
func _verb(verb: StringName, args: Array) -> void:
	var brain := _brain()

	if brain != null:
		brain.callv(verb, args)


func _dead(name: String) -> bool:
	return _man(name) == null


func _state(name: String) -> int:
	var man := _man(name)
	return int(man.state) if man != null else -1


func _out_of_rest(names: Array) -> bool:
	for name in names:
		var man := _man(name)

		if man != null and int(man.state) == RELAXED:
			return false

	return true


func _fighting() -> int:
	var count := 0

	for man in map.get_tree().get_nodes_in_group(&"guards"):
		if int(man.state) == COMBAT:
			count += 1

	return count


## The hunt after him (Squad), if there is one yet.
func _squad() -> RefCounted:
	for man in map.get_tree().get_nodes_in_group(&"guards"):
		var fighter: RefCounted = man.get("_fighter")

		if fighter != null and fighter.squad != null:
			return fighter.squad

	return null


func _flankers() -> int:
	var squad := _squad()

	if squad == null:
		return 0

	var count := 0

	for man in squad.members():
		if squad.role_of(man) == &"flank":
			count += 1

	return count


## The squad reads his turtle: it plans to break it, and sends the brute.
func _breaking() -> bool:
	var squad := _squad()
	var brand := _man("Brand")
	return squad != null and squad.tactic == &"break" and (brand == null or squad.role_of(brand) == &"breaker")


## A man begging for his life, if any.
func _pleader() -> Node3D:
	for man in map.get_tree().get_nodes_in_group(&"guards"):
		if man.get("_mercy") != null and man._mercy.pleading:
			return man as Node3D

	return null


func _searching() -> int:
	var count := 0

	for man in map.get_tree().get_nodes_in_group(&"guards"):
		if int(man.state) == SEARCHING:
			count += 1

	return count


func _lanterns() -> int:
	var count := 0

	for man in map.get_tree().get_nodes_in_group(&"guards"):
		if man.get("_hands") != null and man._hands.lantern != null:
			count += 1

	return count


func _has_said(name: String, text: String) -> bool:
	return (_said.get(name, []) as Array).any(func(line): return String(line).contains(text))


func bell_rung() -> bool:
	return _bell_rung


func _heard(text: String, name: String) -> void:
	var lines: Array = _said[name]
	lines.append(text)

	if lines.size() > 12:
		lines.pop_front()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
