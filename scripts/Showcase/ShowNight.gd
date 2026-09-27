extends RefCounted
## The night the NPC showcase plays (ShowDirector runs it): five acts of
## beats over the garrison yard (maps/npc_showcase.gd). What the guards do is
## their own; the beats move only the intruder (IntruderBrain), wait for the
## world to come true, and ask the camera for its shots.
##
##   I.   The Watch at Rest   no intruder: a tour of the yard at its ease.
##   II.  A Knife in the Dark  in over the east wall and along the alley; he
##                             waits for the archer to be far along the wall
##                             and the carrier to be coming round the store,
##                             then the knife in the back of the man at the
##                             postern, and the carrier sees him over the body.
##   III. The Cry             the camp rouses and he goes to ground: the bell,
##                             the lanterns, the hunt.
##   IV.  Steel               (ShowNight's fight: see _act_four)
##   V.   The ending          (see _act_five)
##
## A shot: {"type": wide | two | close | track | reveal, "subjects": [men]}.

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

var map: Node3D

## name -> what he has said (the last few lines).
var _said := {}
var _bell_rung := false
var _unseen := 0.0


func _init(p_map: Node3D) -> void:
	map = p_map

	for name in map.cast:
		var man: Node = map.cast[name]
		_said[name] = []
		man.barked.connect(_heard.bind(name))

	for bell in map.get_tree().get_nodes_in_group(&"alarm_bells"):
		bell.rung.connect(func(_by: Node) -> void: _bell_rung = true)


func acts() -> Array:
	return [_act_one(), _act_two(), _act_three()]


# ---------------------------------------------------------------------------
# I. The Watch at Rest
# ---------------------------------------------------------------------------

func _act_one() -> Dictionary:
	return {
		"title": "I. The Watch at Rest",
		"enter": func() -> void:
			# The talkers need not wait out their rest before a word.
			for name in ["Mirelle", "Osric", "Piers", "Col"]:
				var man := _man(name)
				if man != null:
					man._life._talk_rest = randf_range(0.0, 3.0),
		"beats": [
			_look(&"establish", 8.0, &"wide", []),
			_look(&"fire_talk", 10.0, &"two", ["Mirelle", "Osric"]),
			_look(&"sitters", 7.0, &"two", ["Piers", "Col"]),
			_look(&"sleeper", 6.0, &"close", ["Tam"]),
			_look(&"quartermaster", 8.0, &"close", ["Gideon"]),
			_look(&"carrier", 8.0, &"track", ["Ned"]),
			_look(&"chopper", 6.0, &"close", ["Brand"]),
			_look(&"wall", 8.0, &"track", ["Wat"]),
			_look(&"lookout", 7.0, &"close", ["Aldous"]),
		],
	}


# ---------------------------------------------------------------------------
# II. A Knife in the Dark
# ---------------------------------------------------------------------------

func _act_two() -> Dictionary:
	return {
		"title": "II. A Knife in the Dark",
		"enter": func() -> void:
			var i: Node3D = map.spawn_intruder(map.marks["drop_in"], PI)
			i.exposure_scale = SNEAK_EXPOSURE
			i.crouched = true,
		"beats": [
			{"name": &"drop_in", "shot": _shot(&"track", ["intruder"]), "timeout": 25.0,
				"do": func() -> void: _brain().go_to(map.marks["alley_wait"], &"sneak"),
				"until": func() -> bool: return _brain() != null and _brain().done()},
			{"name": &"his_moment", "shot": _shot(&"two", ["intruder", "Wat"]), "min": 1.0, "timeout": 30.0,
				"until": _his_moment},
			{"name": &"the_knife", "shot": _shot(&"track", ["intruder", "Jory"]), "timeout": 20.0,
				"do": func() -> void: _brain().backstab(_man("Jory")),
				"until": func() -> bool: return _dead("Jory")},
			{"name": &"the_witness", "shot": _shot(&"close", ["Ned"]), "min": OVER_THE_BODY, "timeout": 12.0,
				"do": func() -> void:
					var i := _intruder()
					if i != null:
						i.exposure_scale = 1.0
						_brain().stand()
						_brain().face(_man_position("Ned")),
				"until": func() -> bool: return _state("Ned") >= SEARCHING or _has_said("Ned", "Murder")},
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
						_brain().go_to(map.marks["hide"], &"run"),
				"until": func() -> bool: return _out_of_rest(["Mirelle", "Osric", "Piers", "Brand", "Tam"])},
			{"name": &"lost_him", "shot": _shot(&"track", ["intruder"]), "timeout": 20.0,
				"do": func() -> void: _brain().hide_at(map.marks["hide"]),
				"until": _lost_him},
			{"name": &"the_hunt", "shot": _shot(&"wide", []), "min": 4.0, "timeout": 30.0,
				"until": func() -> bool: return _searching() >= 2 and _lanterns() >= 1},
		],
	}


func _lost_him() -> bool:
	var seen := false

	for man in map.get_tree().get_nodes_in_group(&"guards"):
		if bool(man.get("can_see_target")):
			seen = true
			break

	_unseen = 0.0 if seen else _unseen + 1.0 / float(Engine.physics_ticks_per_second)
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
		var node: Node3D = _intruder() if name == "intruder" else _man(name)

		if node != null:
			found.append(node)

	return found


func _man(name: String) -> Node3D:
	var man: Variant = map.cast.get(name)

	if man == null or not is_instance_valid(man) or (man as Node3D)._knocked_out:
		return null

	return man as Node3D


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
