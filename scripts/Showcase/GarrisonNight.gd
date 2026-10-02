extends "res://scripts/Showcase/ShowNight.gd"
## The night the NPC showcase plays in the garrison (maps/garrison.gd; the
## garrison spec's section 4): six acts, its beats placed by the level's
## named marks. What the guards do is their own; the beats move only the
## intruder, wait for the world to come true, and ask the camera for shots.
##
##   I.   The Watch at Rest   as the yard's: talk by the fire, dice, the
##                             captain's round, the fire fed, a story; a man at
##                             his prayers in the chapel, the mess; the watch
##                             changing at the colonnade (Jory relieves
##                             Hendrik); the wall, the lookout.
##   II.  A Knife in the Dark  in over the towpath wall when the archer's back
##                             is turned, down the flight and along the dark
##                             colonnade; the knife in Jory's back as a cloud
##                             covers the moon, and the carrier coming with a
##                             crate sees him over the body.
##   III. The Cry             he barges the carrier down and runs as the cry
##                             goes up (the brother's grief),
##                             for the drill yard, up the ladder onto the
##                             range's roof, pulls it up after him, and is
##                             lost to them; the bell, men out with lanterns, and the
##                             captain divides them into groups, each sent to
##                             its ground (Guard.send_to_search).
##   IV.  The Divided Hunt    each group searches its ground; knowing he is
##                             found, he moves through the barracks by stealth,
##                             between them: in by the chapel's loft, along the
##                             gallery over the men searching the floor below,
##                             back as they are sent upstairs, and down into
##                             the chapel.
##   V.   The Chapel          the barracks group is sent to the chapel and
##                             finds him there; they fight, lightning through
##                             the glass, and he is left standing over them.
##   VI.  The Escape          he tries the captain's chamber and it is barred;
##                             the rest come for him, and it ends one of three
##                             ways: over the wall by the breach and into the
##                             canal (escape), cut down in the courtyard
##                             (overwhelmed), or the courtyard fight survived
##                             (a man spared if one begs) and out through the
##                             gate, wounded but victorious (victor).
##
## A scene's subjects may also be "@group:<hunt area>": the men sent there.

## The captain divides the hunt: each hunt area's men.
const GROUPS := {
	"area_barracks": ["Osric", "Brand", "Col"],
	"area_west": ["Gideon", "Ned", "Piers"],
	"area_walls": ["Wat", "Aldous", "Hendrik"],
	"area_courtyard": ["Mirelle", "Tam"],
}
## Where a group searches first, if not its whole ground (the barracks' men
## the floor below, then upstairs: Act IV).
const FIRST_GROUND := {"area_barracks": "area_barracks_ground"}
## The captain's orders as she divides them, and the groups' leaders
## answering (a moment apart, s).
const ORDERS := "Split up! Osric, Brand, Col: the barracks! Gideon, the range and the cellar! Wat, the walls! Tam, with me!"
const ANSWERS := [["Osric", "Aye. With me.", 1.6], ["Gideon", "The cellar first.", 2.8], ["Wat", "Walls it is.", 3.8]]
## Act II: in over the wall once the archer on it is this far from where he
## comes in; at his hiding place he waits at most MOMENT_WAIT (s) for the
## moment.
const WALL_CLEAR := 18.0
const MOMENT_WAIT := 20.0
## Nobody else this near the post for the knife (m); as he runs from the body,
## how easily he is seen (the dark colonnade).
const ALONE_OF := 12.0
const RUN_EXPOSURE := 0.5
## Up on the range's roof: higher than this (m).
const ON_THE_ROOF := 2.5
## Breaking away, he barges down a man this near him (m), this hard (m/s).
const BARGE_REACH := 3.0
const BARGE_PUSH := 4.5
## The carrier coming along the colonnade toward the post with a crate: south
## of it by this much (m), and the archer this far from it.
const CARRIER_NEAR := Vector2(1.5, 7.5)
## Act IV: he moves on once nobody is this near him (m, flat, on his level)
## and nobody makes him out (sees him as well as NOTICE, Guard.visibility);
## how easily he is seen, sneaking (the director's hand, as in Act II).
const CLEAR_OF := 8.0
const LEVEL_OF := 2.0
const NOTICE := 0.08
## One of them this near (m, flat, on his level): he moves on, now; he waits
## at a hiding place this long at most (s).
const PRESSED_AT := 5.5
const WAIT_MOST := 12.0
const STEALTH_EXPOSURE := 0.2
## Act V: the barracks group is in the chapel when one of them is this far
## inside its box; his parrying lasts this long at most (s).
const IN_CHAPEL := 0.5
const PARRY_MOST := 25.0
## Act VI: the captain's door rattled twice, this long apart (s); the
## victor leaves with this much of his health.
const RATTLE_AGAIN := 0.9
const WOUNDED := 0.45
## They come for him: this long at most before he runs (s).
const THEY_COME := 10.0
## The victor: he presses them this long at most (s); out through the gate
## within this of its mark (m).
const BREAK_MOST := 45.0
## The escape: the chase calls where he is this often (s).
const CHASE_CALLS := 2.0
const OUT_THE_GATE := 2.0
## Jumped to after the chapel: where its dead lie round the fight (m).
const FELL_ROUND := [Vector3(1.3, 0, 0.7), Vector3(-1.1, 0, 1.2), Vector3(0.4, 0, -1.4)]
## The ways out for each ending.
const OVER_THE_WALL := ["escape_stairs", "escape_door", "escape_climb", "escape_walk", "escape_over", "canal_edge", "canal_swim"]
const INTO_THE_YARD := ["escape_stairs", "escape_door", "courtyard_fight"]

const WEATHER_ACTS_G := {
	1: [[&"clear", 0.0, 0.55]],
	2: [[&"clear", 0.0, 0.55]],
	3: [[&"shower", 0.0, 0.55]],
	4: [[&"rain", 0.0, 0.55]],
	5: [[&"storm", 0.0, 0.55]],
	6: [[&"storm", 0.0, 0.55]],
}
const WEATHER_BEATS_G := {
	# Drizzle begins with the witness. Moon coverage follows the existing
	# wind-driven field throughout the encounter.
	&"the_witness": {"to": [&"drizzle", 20.0]},
	# He steps out of the dark of the chapel as the lightning comes.
	&"found": {"flash": true},
	# The storm easing to fog as it ends.
	&"gone": {"to": [&"fog", 30.0]},
	&"silence": {"to": [&"fog", 30.0]},
	&"walk_out": {"to": [&"fog", 30.0]},
}
const ENDING_TITLES_G := {&"overwhelmed": "VI. Overwhelmed", &"victor": "VI. The Victor", &"escape": "VI. Over the Wall"}

## The hunt areas by their names (the level's hunt_area nodes).
var _areas := {}
## The man sent to ring the bell.
var _bell_man: Node3D = null
## The keep's spaces (its zones' boxes): never outside.
var _spaces: Array = []
## The ladder to the range's roof is up.
var _ladder_up := false
## The chase's clock and when it last called where he is.
var _chase_clock := 0.0
var _called_at := -INF


func _init(p_map: Node3D) -> void:
	super(p_map)

	for node in map.get_tree().get_nodes_in_group(&"hunt_area"):
		_areas[String(node.name)] = node.get_meta(&"box")

	var level: Variant = map.get("level")

	if level != null:
		for m in level.of("zone"):
			var size: Vector3 = m["size"]
			_spaces.append(AABB((m["transform"] as Transform3D).origin - size * 0.5, size))


func acts() -> Array:
	return [_act_one(), _act_two_g(), _act_three_g(), _act_four_g(), _act_five_g(), _act_six_g()]


func weather_acts() -> Dictionary:
	return WEATHER_ACTS_G


func weather_beats() -> Dictionary:
	return WEATHER_BEATS_G


func weather_beat(beat: StringName) -> void:
	super(beat)
	var night: Node = map.get("night")

	if night != null and bool(WEATHER_BEATS_G.get(beat, {}).get("flash", false)):
		night.flash()


func _post_duty() -> StringName:
	return &"colonnade"


func _post_mark() -> String:
	return "colonnade_post"


## Outside the walls: past the curtain on any side, and not in one of the
## keep's spaces (the watchtower stands out past the curtain's line).
func _outside(at: Vector3) -> bool:
	if not (at.z > 28.6 or at.z < -28.6 or absf(at.x) > 32.6):
		return false

	return not _spaces.any(func(box): return (box as AABB).has_point(at + Vector3.UP * 0.5))


func _subjects_of(subject: String) -> Variant:
	if subject == "@bell":
		return [_bell_man] if _bell_man != null and is_instance_valid(_bell_man) and not _bell_man._knocked_out else _hunters()

	if not subject.begins_with("@group:"):
		return null

	var group := StringName(subject.trim_prefix("@group:"))
	var men := _group(group)

	if men.is_empty():
		return _hunters()

	var i := _intruder()

	if i != null:
		men.sort_custom(func(a, b): return a.global_position.distance_to(i.global_position) < b.global_position.distance_to(i.global_position))

	return men.slice(0, 4)


# ---------------------------------------------------------------------------
# I. The Watch at Rest: the yard's, with the chapel and the mess
# ---------------------------------------------------------------------------

func _act_one() -> Dictionary:
	var act: Dictionary = super()
	var beats: Array = act["beats"]
	var at := beats.find_custom(func(b): return b["name"] == &"watch_change")
	var more := [
		{"name": &"prayer", "scene": _scene(&"observe", ["Gideon"]), "min": 7.0, "timeout": 45.0,
			"until": func() -> bool:
				var gideon := _man("Gideon")
				return gideon == null or StringName(gideon.activity()) == &"pray"},
		_look(&"mess", 7.0, &"observe", ["Col"]),
	]

	for k in more.size():
		beats.insert(at + k, more[k])

	return act


# ---------------------------------------------------------------------------
# II. A Knife in the Dark
# ---------------------------------------------------------------------------

func _act_two_g() -> Dictionary:
	return {
		"title": "II. A Knife in the Dark",
		"stage": _after_the_watch_change,
		"enter": func() -> void:
			# The night moves on: whatever they were doing together is over,
			# and the watch has changed however Act I went.
			_gatherings().end_all()
			var jory_now := _man("Jory")
			var rota_now: Variant = map.get("rota")
			if jory_now != null and rota_now != null and rota_now.duty_of(jory_now) != _post_duty():
				_after_the_watch_change(),
		"beats": [
			{"name": &"the_wall", "scene": _scene(&"observe", ["Wat"]), "min": 2.0, "timeout": 40.0,
				"until": func() -> bool:
					var wat := _man("Wat")
					return wat == null or _flat(wat.global_position, map.marks["drop_in"]) >= WALL_CLEAR},
			{"name": &"drop_in", "scene": _scene(&"observe", ["intruder"]), "timeout": 70.0,
				"do": func() -> void:
					var i: Node3D = map.spawn_intruder(map.marks["drop_in"], 0.0)
					i.exposure_scale = SNEAK_EXPOSURE
					i.crouched = true
					_verb(&"go_to", [map.marks["colonnade_wait"], &"sneak"]),
				"until": func() -> bool: return _brain() != null and _brain().done()},
			# (His moment, or as long as he will wait for it.)
			{"name": &"his_moment", "scene": _scene(&"observe", ["intruder", "Ned"]), "min": 1.0, "enough": MOMENT_WAIT, "timeout": MOMENT_WAIT + 10.0,
				"until": _his_moment_g},
			{"name": &"the_knife", "scene": _scene(&"drama", ["intruder", "Jory"], {"kind": &"track", "seconds": 4.0}), "timeout": 25.0,
				"do": func() -> void: _verb(&"backstab", [_man("Jory")]),
				"until": func() -> bool: return _dead("Jory")},
			{"name": &"the_witness", "scene": _scene(&"drama", ["Ned"]), "min": OVER_THE_BODY, "timeout": 14.0,
				"do": func() -> void:
					var i := _intruder()
					if i != null:
						i.exposure_scale = 1.0
					_verb(&"stand", [])
					_verb(&"face", [_man_position("Ned")]),
				"until": func() -> bool: return _state("Ned") >= SEARCHING or _has_said("Ned", "Murder")},
		],
	}


## His moment: the archer far from the post, the carrier coming along the
## colonnade toward it with a crate (the knife falls as he walks into it).
func _his_moment_g() -> bool:
	var post: Vector3 = map.marks["colonnade_post"]
	var wat := _man("Wat")
	var archer_far: bool = wat == null or _flat(wat.global_position, post) >= ARCHER_FAR
	var ned := _man("Ned")

	if ned == null:
		return archer_far

	var south := ned.global_position.z - post.z
	var coming: bool = ned._rota.carried != null and ned.global_position.x > post.x - 2.8 and south >= CARRIER_NEAR.x and south <= CARRIER_NEAR.y
	return archer_far and coming and _alone_but(["Jory", "Ned"], post)


## Nobody but `names` within ALONE_OF of `at`.
func _alone_but(names: Array, at: Vector3) -> bool:
	for name in map.cast:
		var man := _man(name)

		if man != null and not (name in names) and _flat(man.global_position, at) < ALONE_OF:
			return false

	return true


# ---------------------------------------------------------------------------
# III. The Cry
# ---------------------------------------------------------------------------

func _act_three_g() -> Dictionary:
	return {
		"title": "III. The Cry",
		"stage": func() -> void:
			# Jumped to: the man at the post dead, the intruder over him, the
			# carrier coming up the colonnade with the alarm in him.
			_after_the_watch_change()
			var post: Vector3 = map.marks["colonnade_post"]
			var i: Node3D = map.spawn_intruder(post + Vector3(0.2, 0, 1.2), PI)
			_kill("Jory", i, &"backstab", post)
			var ned := _man("Ned")
			if ned != null:
				ned.global_position = post + Vector3(-0.4, 0, 5.5)
				ned.reset_physics_interpolation()
				ned.alert = 100.0
				ned.last_known_position = i.global_position
				ned.has_last_known = true,
		"beats": [
			# He runs as the cry goes up (the dark colonnade half hides him),
			# and the brother, who knew the voice of that cry, comes.
			{"name": &"the_cry", "scene": _scene(&"drama", ["Ned"]), "min": 1.5, "timeout": 25.0,
				"do": func() -> void:
					var i := _intruder()
					if i != null:
						i.exposure_scale = RUN_EXPOSURE
					_barge("Ned")
					_verb(&"go_to", [map.marks["gone_to_ground"], &"run"]),
				"until": func() -> bool: return _out_of_rest(["Mirelle", "Osric", "Piers", "Brand", "Col"])},
			{"name": &"grief", "scene": _scene(&"drama", ["Osric"]), "min": 3.0, "timeout": 20.0,
				"until": func() -> bool:
					# (The ladder up the moment he is on the roof.)
					_pull_up_ladder()
					return (_has_said("Osric", "Jory") or _man("Osric") == null) and (_brain() == null or _brain().done())},
			# Up on the roof he pulls the ladder up after him and goes to ground
			# in the dark (the director's hand: hard to see).
			{"name": &"lost_him", "scene": _scene(&"drama", ["intruder"]), "timeout": 20.0,
				"do": func() -> void:
					_pull_up_ladder()
					_verb(&"hide_at", [map.marks["gone_to_ground"]])
					_sneaking(),
				"until": _lost_him},
			# The captain sends the man nearest the bell to ring it.
			{"name": &"the_bell", "scene": _scene(&"drama", ["@bell"]), "min": 3.0, "timeout": 40.0,
				"do": _send_to_bell,
				"until": bell_rung},
			{"name": &"lanterns", "scene": _scene(&"observe", ["Tam", "Col"]), "min": 3.0, "timeout": 20.0,
				"until": func() -> bool: return _lanterns() >= 2 or _searching() >= 4},
			{"name": &"divided", "scene": _scene(&"drama", ["Mirelle"]), "min": 5.0,
				"do": _divide},
		],
	}


## The captain divides the hunt: each group sent to its ground (the
## barracks' men to its ground floor first), her orders called and answered.
func _divide() -> void:
	for area in GROUPS:
		var ground: String = FIRST_GROUND.get(area, area)

		if not _areas.has(ground):
			continue

		for name in GROUPS[area]:
			var man := _man(name)

			if man != null:
				man.send_to_search(_areas[ground], StringName(area))

	var captain := _man("Mirelle")

	if captain != null:
		captain.bark(ORDERS)

	for answer in ANSWERS:
		var held: WeakRef = weakref(map.cast.get(answer[0]))
		map.get_tree().create_timer(float(answer[2]), false).timeout.connect(func() -> void:
			var man := held.get_ref() as Node3D
			if man != null and is_instance_valid(man) and not man._knocked_out and int(man.state) != COMBAT:
				man.bark(answer[1]))


## The man nearest the bell and not fighting runs to ring it (the captain's
## word).
func _send_to_bell() -> void:
	var bells := map.get_tree().get_nodes_in_group(&"alarm_bells")

	if bells.is_empty() or bell_rung():
		return

	var at: Vector3 = (bells[0] as Node3D).global_position
	var best: Node3D = null

	for name in map.cast:
		var man := _man(name)

		if man != null and int(man.state) != COMBAT and (best == null or man.global_position.distance_to(at) < best.global_position.distance_to(at)):
			best = man

	_bell_man = best

	if best != null:
		best.send_to_bell()
		var captain := _man("Mirelle")

		if captain != null and captain != best:
			captain.bark("%s! The bell!" % best.given_name)


## The men sent to `group`'s ground, standing.
func _group(group: StringName) -> Array:
	var men := []

	for name in map.cast:
		var man := _man(name)

		if man != null and man.get_meta(&"hunt_group", &"") == group:
			men.append(man)

	return men


# ---------------------------------------------------------------------------
# IV. The Divided Hunt
# ---------------------------------------------------------------------------

func _act_four_g() -> Dictionary:
	return {
		"title": "IV. The Divided Hunt",
		"stage": func() -> void:
			_stage_hunt(map.marks["gone_to_ground"], [])
			_divide(),
		"enter": _sneaking,
		"beats": [
			_look(&"the_groups", 5.0, &"observe", ["@group:area_courtyard"]),
			_look(&"group_west", 4.5, &"observe", ["@group:area_west"]),
			_look(&"group_walls", 4.5, &"observe", ["@group:area_walls"]),
			# From hiding place to hiding place: each move goes all the way;
			# each wait ends when nobody is near and nobody makes him out, at
			# once if one of them comes close, and by a held length whatever.
			{"name": &"in_the_dark", "scene": _scene(&"observe", ["intruder"]), "min": 2.0, "enough": WAIT_MOST, "timeout": WAIT_MOST + 10.0,
				"do": func() -> void: _verb(&"hide_at", [map.marks["gone_to_ground"]]),
				"until": _clear},
			# In by the chapel (nobody's ground) and up to its loft...
			{"name": &"by_the_chapel", "scene": _scene(&"observe", ["intruder"]), "timeout": 70.0,
				"do": func() -> void: _verb(&"hide_at", [map.marks["sneak_3"]]),
				"until": _arrived},
			{"name": &"the_loft_door", "scene": _scene(&"observe", ["intruder"]), "min": 2.0, "enough": WAIT_MOST, "timeout": WAIT_MOST + 10.0,
				"until": func() -> bool: return _clear() or _pressed()},
			# ...through into the barracks, along the gallery over the mess,
			# the group searching the floor below him...
			{"name": &"the_gallery", "scene": _scene(&"observe", ["intruder"]), "timeout": 60.0,
				"do": func() -> void: _verb(&"hide_at", [map.marks["sneak_2"]]),
				"until": _arrived},
			{"name": &"above_them", "scene": _scene(&"observe", ["intruder", "@group:area_barracks"]), "min": 6.0, "enough": WAIT_MOST, "timeout": WAIT_MOST + 10.0,
				"until": func() -> bool: return _clear() or _pressed()},
			# ...and back to the loft as they are sent up after him.
			{"name": &"slip_back", "scene": _scene(&"observe", ["intruder"]), "timeout": 60.0,
				"do": func() -> void: _verb(&"hide_at", [map.marks["sneak_3"]]),
				"until": _arrived},
			{"name": &"upstairs", "scene": _scene(&"drama", ["@group:area_barracks"]), "min": 3.0, "enough": 12.0, "timeout": 25.0,
				"do": func() -> void:
					for man in _group(&"area_barracks"):
						man.send_to_search(_areas.get("area_barracks", AABB()), &"area_barracks")
					var osric := _man("Osric")
					if osric != null and int(osric.state) != COMBAT:
						osric.bark("Nothing down here. Upstairs!"),
				"until": func() -> bool: return _group(&"area_barracks").any(func(m): return m.global_position.y > 2.5)},
			{"name": &"sanctuary", "scene": _scene(&"observe", ["intruder"]), "timeout": 60.0,
				"do": func() -> void: _verb(&"hide_at", [map.marks["chapel_hide"]]),
				"until": func() -> bool: return _brain() == null or _brain().done()},
		],
	}


## The director's hand for the stealth: crouched, hard to see.
func _sneaking() -> void:
	var i := _intruder()

	if i != null:
		i.exposure_scale = STEALTH_EXPOSURE
		i.crouched = true


## One of them close to him on his level (PRESSED_AT): time to move.
func _pressed() -> bool:
	var i := _intruder()

	if i == null:
		return true

	for man in map.get_tree().get_nodes_in_group(&"guards"):
		if man == i or man._knocked_out:
			continue

		var at: Vector3 = (man as Node3D).global_position

		if _flat(at, i.global_position) < PRESSED_AT and absf(at.y - i.global_position.y) < LEVEL_OF:
			return true

	return false


## At the place he was making for (or gone: nothing to wait for).
func _arrived() -> bool:
	return _brain() == null or _brain().done()


## Nobody near him on his level, and nobody makes him out: he can move on.
func _clear() -> bool:
	var i := _intruder()

	if i == null:
		return true

	for man in map.get_tree().get_nodes_in_group(&"guards"):
		if man == i or man._knocked_out:
			continue

		if float(man.get("visibility")) >= NOTICE or int(man.state) == COMBAT:
			return false

		var at: Vector3 = (man as Node3D).global_position

		if _flat(at, i.global_position) < CLEAR_OF and absf(at.y - i.global_position.y) < LEVEL_OF:
			return false

	return true


## The ladder he climbed to the range's roof, pulled up after him (if he is
## up there; jumped to a later act, it was). Once.
func _pull_up_ladder() -> void:
	var i := _intruder()

	if not _ladder_up and map.has_method("pull_up_ladder") and (i == null or i.global_position.y > ON_THE_ROOF):
		_ladder_up = true
		map.pull_up_ladder()


## He barges `name` off his feet as he breaks away (the man nearest him, who
## would be on his heels).
func _barge(name: String) -> void:
	var i := _intruder()
	var man := _man(name)

	if i == null or man == null or _flat(man.global_position, i.global_position) > BARGE_REACH:
		return

	var away := man.global_position - i.global_position
	away.y = 0.0
	man.knock_down(away.normalized() * BARGE_PUSH + Vector3.UP * 1.2, i)


## Jumped to the hunt: the watch changed, the man at the post dead and the
## garrison roused; the intruder at `at`, crouched; `dead` killed too; the
## ladder up the range's roof pulled up long since.
func _stage_hunt(at: Vector3, dead: Array) -> void:
	if map.has_method("pull_up_ladder"):
		_ladder_up = true
		map.pull_up_ladder()

	_after_the_watch_change()
	var i: Node3D = map.spawn_intruder(at, 0.0)
	i.exposure_scale = STEALTH_EXPOSURE
	i.crouched = true
	_kill("Jory", i, &"backstab", map.marks["colonnade_post"])

	# (The chapel's dead where they fell round the fight.)
	for k in dead.size():
		_kill(dead[k], i, &"power", map.marks["chapel_fight"] + FELL_ROUND[k % FELL_ROUND.size()])

	for name in map.cast:
		var man := _man(name)

		if man != null:
			man.alert = maxf(float(man.alert), 60.0)
			man.last_known_position = map.marks["colonnade_post"]
			man.has_last_known = true


## `name` dead by the intruder's hand at `at` (where he fell), as the
## garrison would have heard it.
func _kill(name: String, by: Node3D, kind: StringName, at: Vector3) -> void:
	var man := _man(name)

	if man == null:
		return

	man.global_position = at
	man.velocity = Vector3.ZERO
	man.reset_physics_interpolation()
	man.take_hit(999.0, by, kind, man.global_position + Vector3.UP * 1.2, Vector3.FORWARD)
	GarrisonScript.of(by).on_death(name == "Mirelle", name)


# ---------------------------------------------------------------------------
# V. The Chapel
# ---------------------------------------------------------------------------

func _act_five_g() -> Dictionary:
	return {
		"title": "V. The Chapel",
		"stage": func() -> void:
			_stage_hunt(map.marks["chapel_hide"], [])
			_divide(),
		"enter": _sneaking,
		"beats": [
			{"name": &"sent_to_chapel", "scene": _scene(&"drama", ["@group:area_barracks"]), "min": 2.0, "timeout": 45.0,
				"do": func() -> void:
					_verb(&"hide_at", [map.marks["chapel_hide"]])
					for man in _group(&"area_barracks"):
						man.send_to_search(_areas.get("area_chapel", AABB()), &"area_barracks")
					var osric := _man("Osric")
					if osric != null and int(osric.state) != COMBAT:
						osric.bark("The chapel! Try the chapel!"),
				"until": func() -> bool:
					var chapel: AABB = _areas.get("area_chapel", AABB())
					return _group(&"area_barracks").any(func(m): return chapel.grow(-IN_CHAPEL).has_point(m.global_position + Vector3.UP * 0.5))},
			{"name": &"found", "scene": _scene(&"drama", ["intruder", "Osric"]), "timeout": 25.0,
				"do": func() -> void:
					var i := _intruder()
					if i != null:
						i.exposure_scale = 1.0
						i.crouched = false
					_verb(&"go_to", [map.marks["chapel_fight"], &"walk"]),
				"until": func() -> bool: return _fighting() >= 1},
			{"name": &"chapel_trade", "scene": _scene(&"drama", ["intruder", "Osric"]), "min": 6.0, "enough": 16.0, "timeout": 25.0,
				"do": func() -> void: _verb(&"fight", [&"trade"]),
				"until": func() -> bool: return _flankers() >= 1},
			# (His blows turned aside and answered a while: until one is cut
			# down, or PARRY_MOST.)
			{"name": &"chapel_parry", "scene": _scene(&"drama", ["intruder", "nearest"]), "enough": PARRY_MOST, "timeout": PARRY_MOST + 20.0,
				"do": func() -> void:
					_parry_mark = _deathblows + _riposte_kills
					_verb(&"fight", [&"parry"]),
				"until": func() -> bool: return _deathblows + _riposte_kills > _parry_mark},
			{"name": &"chapel_osric", "scene": _scene(&"drama", ["intruder", "Osric"]), "timeout": 50.0,
				"do": func() -> void: _verb(&"fight", [&"focus", _man("Osric")]),
				"until": func() -> bool: return _dead("Osric")},
			{"name": &"chapel_last", "scene": _scene(&"drama", ["intruder", "@group:area_barracks"]), "timeout": 60.0,
				# (He calls the last of them on, and they come: none left
				# searching the doorway for a man in the middle of the nave.
				# He goes for them, one and then the next, not for whoever
				# else has come in: the beat waits on them.)
				"do": func() -> void:
					_verb(&"fight", [&"focus", _next_of("area_barracks")])
					_call_group("area_barracks"),
				"until": func() -> bool:
					var brain := _brain()
					var next := _next_of("area_barracks")

					if brain != null and next != null and brain.focus != next:
						brain.fight(&"focus", next)

					return next == null},
			{"name": &"over_them", "scene": _scene(&"observe", ["intruder"]), "min": 5.0,
				"do": func() -> void: _verb(&"stand", [])},
		],
	}


## The first man of `group` not yet beaten (null: all of them are).
func _next_of(group: String) -> Node3D:
	for name in GROUPS.get(group, []):
		if not _beaten(name):
			return _man(name)

	return null


## Beaten: dead or down, begging, broken or running from the fight.
func _beaten(name: String) -> bool:
	var man := _man(name)

	if man == null:
		return true

	var squad: RefCounted = man._fighter.squad if man._fighter != null else null
	return bool(man._mercy.pleading) or (squad != null and (squad.status_of(man) in [&"running", &"down"] or squad.will_of(man) == &"broken"))


# ---------------------------------------------------------------------------
# VI. The Escape
# ---------------------------------------------------------------------------

func _act_six_g() -> Dictionary:
	return {
		"title": func() -> String: return ENDING_TITLES_G.get(_ending_now(), "VI."),
		"stage": func() -> void:
			_stage_hunt(map.marks["chapel_fight"], GROUPS["area_barracks"])
			_divide(),
		"enter": func() -> void:
			var i := _intruder()
			if i != null:
				i.exposure_scale = 1.0
				i.crouched = false,
		"beats": func() -> Array: return _escape_beats(_ending_now()),
	}


func _escape_beats(ending: StringName) -> Array:
	var beats := [
		{"name": &"the_door", "scene": _scene(&"drama", ["intruder"]), "timeout": 45.0,
			"do": func() -> void: _verb(&"go_to", [map.marks["captain_door_at"], &"run"]),
			"until": func() -> bool: return _brain() == null or _brain().done()},
		{"name": &"barred", "scene": _scene(&"drama", ["intruder"]), "min": 3.0,
			"do": _try_the_door},
		# (Coming for him: a held shot of them, done when the nearest is close or
		# by THEY_COME whatever.)
		{"name": &"they_come", "scene": _scene(&"drama", ["@hunt"]), "min": 2.0, "enough": THEY_COME, "timeout": THEY_COME + 10.0,
			"until": func() -> bool: return _nearest() != null and _intruder() != null and _nearest().global_position.distance_to(_intruder().global_position) < 14.0},
	]

	match ending:
		&"overwhelmed":
			beats.append_array([
				_into_the_yard(),
				{"name": &"overwhelmed", "scene": _scene(&"drama", ["intruder", "@hunt"]), "timeout": 90.0,
					"do": func() -> void:
						var i := _intruder()
						if i != null:
							i.fall()
						_call_in()
						_verb(&"fight", [&"trade"]),
					"until": func() -> bool: return _intruder() == null},
				_look(&"silence", 6.0, &"observe", ["@hunt"]),
			])
		&"victor":
			beats.append_array([
				_into_the_yard(),
				# Until one of them begs, or none is left fighting him: the
				# fight is his (by BREAK_MOST whatever).
				{"name": &"break_them", "scene": _scene(&"drama", ["intruder", "@hunt"]), "enough": BREAK_MOST, "timeout": BREAK_MOST + 15.0,
					"do": func() -> void:
						_call_in()
						_verb(&"fight", [&"press"]),
					"until": func() -> bool: return _pleader() != null or _fighting() == 0},
				{"name": &"spare", "scene": _scene(&"drama", ["intruder", "nearest"]), "timeout": 40.0,
					"do": func() -> void:
						_spared = _pleader()
						_spared_at = _spared.global_position if _spared != null else Vector3.ZERO
						_verb(&"fight", [&"spare"]),
					"until": func() -> bool: return _spared == null or _spared_ran()},
				{"name": &"walk_out", "scene": _scene(&"observe", ["intruder"]), "timeout": 45.0,
					"do": func() -> void:
						var i := _intruder()
						if i != null:
							i.health = minf(float(i.health), float(i.max_health) * WOUNDED)
						_verb(&"go_to", [map.marks["gate_out"], &"walk"]),
					"until": func() -> bool: return _brain() == null or _brain().done()},
			])
		_:
			beats.append_array([
				# After him as he goes: the chase calls where he is running.
				{"name": &"break_off", "scene": _scene(&"drama", ["intruder", "@hunt"]), "timeout": 100.0,
					"do": func() -> void:
						_verb(&"flee_by", [_route(OVER_THE_WALL)])
						_called_at = -INF,
					"until": func() -> bool:
						_chase_calls()
						return _escaped()},
				_look(&"gone", 6.0, &"observe", ["@hunt"]),
			])

	return beats


## Down the stairs and out into the courtyard, until they are on him.
func _into_the_yard() -> Dictionary:
	return {"name": &"into_the_yard", "scene": _scene(&"drama", ["intruder", "@hunt"]), "timeout": 45.0,
		"do": func() -> void:
			_verb(&"flee_by", [_route(INTO_THE_YARD)])
			_call_in(),
		"until": func() -> bool: return _fighting() >= 2 or _brain() == null or _brain().done()}


## The captain's door: barred against him (rattled twice, loud enough to be
## heard), and the rest of them called in off their ground to him.
func _try_the_door() -> void:
	var door: Node = map.get("doors").get("captain_door") if map.get("doors") != null else null
	var i := _intruder()

	if door == null or i == null:
		return

	_verb(&"stand", [])
	_verb(&"face", [(door as Node3D).global_position])
	door.frob(i)
	var held: WeakRef = weakref(door)
	var by: WeakRef = weakref(i)
	map.get_tree().create_timer(RATTLE_AGAIN, false).timeout.connect(func() -> void:
		var d := held.get_ref() as Node
		var who := by.get_ref() as Node3D
		if d != null and who != null and is_instance_valid(who) and not who.is_dead:
			d.frob(who))

	_call_in()


## The rattle and the shout are heard: they come, all of them, to where he is
## (off whatever ground they were sent to).
func _call_in() -> void:
	var i := _intruder()

	if i == null:
		return

	for name in map.cast:
		var man := _man(name)

		if man != null:
			man.call_off_search()
			man.hear_call(i.global_position)


## The men of `group` still on their feet come to where he is.
func _call_group(group: String) -> void:
	var i := _intruder()

	if i == null:
		return

	for name in GROUPS.get(group, []):
		var man := _man(name)

		if man != null and not _beaten(name):
			man.hear_call(i.global_position)


## In a chase, where he is running is called every CHASE_CALLS seconds (of
## the world's time): the hunt comes after him.
func _chase_calls() -> void:
	_chase_clock += Engine.time_scale / float(Engine.physics_ticks_per_second)

	if _chase_clock - _called_at >= CHASE_CALLS:
		_called_at = _chase_clock
		_call_in()


## The marks named, as places.
func _route(names: Array) -> Array[Vector3]:
	var points: Array[Vector3] = []

	for name in names:
		points.append(map.marks[name])

	return points


## The victor's ending came true when he is out through the gate alive
## (whether or not a man begged to be spared on the way).
func ending_done() -> bool:
	if _ending == &"victor":
		var i := _intruder()
		return i != null and _flat(i.global_position, map.marks["gate_out"]) < OUT_THE_GATE

	return super()


func ending_outcome() -> String:
	if _ending == &"victor":
		var i := _intruder()
		return "%s; the intruder %s, %.1f m from the gate" % [super(), "standing" if i != null else "dead", _flat(i.global_position, map.marks["gate_out"]) if i != null else -1.0]

	return super()
