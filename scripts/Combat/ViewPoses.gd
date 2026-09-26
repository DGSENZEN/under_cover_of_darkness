extends RefCounted
## How each weapon is held in your view, pose by pose. A pose is
## [grip, blade, edge]: where the grip is (camera space, metres: x right,
## y up, -z ahead of your eye), which way the blade points, and which way its
## true edge faces (the knuckle side of the fist). The weapon is always in the
## fist and the fist always on the grip: your arm reaches for whatever this
## says (ViewArms.gd), so these are the arm's poses as much as the blade's.
##
## Every pose here was set by looking at it in the view
## (tests/visual/stage_arms.tscn), with a wrist that bends the way wrists do.

## A one-handed sword. A swing is a sweep (see sweep_frame): the fist
## carried round a wide arc by the turn of your body, not flicked from the
## wrist, the blade trailing as it is drawn back and leading through the cut.
const SWORD := {
	"rest": [Vector3(0.23, -0.23, -0.42), Vector3(-0.5, 0.85, -0.1), Vector3(0.0, 0.0, -1.0)],
	"sprint": [Vector3(0.26, -0.33, -0.34), Vector3(-0.45, 0.6, -0.65), Vector3(0.0, 0.8, -0.5)],
	"block": [Vector3(0.2, -0.14, -0.38), Vector3(-1.0, 0.22, -0.18), Vector3(0.0, 1.0, 0.1)],
	"stagger": [Vector3(0.34, -0.22, -0.3), Vector3(0.5, 0.8, 0.3), Vector3(0.0, 0.0, -1.0)],
	"kick": [Vector3(0.26, -0.2, -0.3), Vector3(0.1, 0.95, 0.25), Vector3(0.0, 0.0, -1.0)],
	"drop": [Vector3(0.08, -0.1, -0.34), Vector3(-0.05, -0.95, -0.25), Vector3(0.0, -0.25, 1.0)],
	"sweeps": {
		# A forehand: drawn back at your right, carried across in front of
		# you at full reach, wrapped round to your left.
		&"left": {
			"pivot": Vector3(0.04, -0.3, 0.12),
			"path": [Vector3(0.4, -0.05, -0.3), Vector3(0.32, -0.1, -0.5), Vector3(0.06, -0.14, -0.6), Vector3(-0.24, -0.18, -0.5), Vector3(-0.38, -0.22, -0.3)],
			"lead": [-70.0, 12.0, 55.0],
			"rise": [0.55, 0.12, -0.2],
			"charged": [Vector3(0.42, 0.0, -0.24), -85.0, 0.75],
		},
		# A backhand: wound across your chest, then out to your right.
		&"right": {
			"pivot": Vector3(0.04, -0.3, 0.12),
			"path": [Vector3(-0.24, -0.05, -0.34), Vector3(-0.16, -0.1, -0.52), Vector3(0.1, -0.14, -0.6), Vector3(0.34, -0.18, -0.48), Vector3(0.44, -0.22, -0.26)],
			"lead": [-70.0, 12.0, 55.0],
			"rise": [0.55, 0.12, -0.2],
			"charged": [Vector3(-0.27, 0.0, -0.28), -85.0, 0.75],
		},
		# From over your right shoulder, down through the middle of your sight,
		# to your left hip.
		&"overhead": {
			"pivot": Vector3(0.18, -0.24, 0.05),
			"path": [Vector3(0.3, 0.1, -0.24), Vector3(0.22, 0.02, -0.46), Vector3(0.06, -0.14, -0.58), Vector3(-0.06, -0.26, -0.5), Vector3(-0.12, -0.3, -0.4)],
			"lead": [-75.0, 10.0, 50.0],
			"rise": [0.0, 0.0, 0.0],
			"charged": [Vector3(0.31, 0.16, -0.18), -95.0, 0.0],
		},
		# Drawn back low at your right, the point driven out to the middle.
		&"thrust": {
			"pivot": Vector3(0.18, -0.24, 0.05),
			"path": [Vector3(0.24, -0.22, -0.3), Vector3(0.22, -0.22, -0.38), Vector3(0.12, -0.2, -0.56), Vector3(0.09, -0.19, -0.63), Vector3(0.08, -0.19, -0.65)],
			"lead": [0.0, 0.0, 0.0],
			"rise": [0.2, 0.14, 0.12],
			"charged": [Vector3(0.26, -0.24, -0.24), 0.0, 0.22],
		},
	},
}

## A dagger: the sword's ways, closer in and tighter.
const DAGGER := {
	"rest": [Vector3(0.2, -0.24, -0.38), Vector3(-0.5, 0.85, -0.15), Vector3(0.0, 0.0, -1.0)],
	"sprint": [Vector3(0.24, -0.33, -0.32), Vector3(-0.45, 0.6, -0.65), Vector3(0.0, 0.8, -0.5)],
	"block": [Vector3(0.18, -0.16, -0.34), Vector3(-1.0, 0.25, -0.15), Vector3(0.0, 1.0, 0.1)],
	"stagger": [Vector3(0.3, -0.24, -0.28), Vector3(0.5, 0.8, 0.3), Vector3(0.0, 0.0, -1.0)],
	"kick": [Vector3(0.24, -0.22, -0.28), Vector3(0.1, 0.95, 0.25), Vector3(0.0, 0.0, -1.0)],
	"drop": [Vector3(0.07, -0.12, -0.32), Vector3(-0.05, -0.95, -0.25), Vector3(0.0, -0.25, 1.0)],
	"sweeps": {
		&"left": {
			"pivot": Vector3(0.04, -0.3, 0.12),
			"path": [Vector3(0.34, -0.08, -0.3), Vector3(0.28, -0.12, -0.46), Vector3(0.06, -0.16, -0.54), Vector3(-0.2, -0.2, -0.46), Vector3(-0.32, -0.24, -0.3)],
			"lead": [-65.0, 12.0, 50.0],
			"rise": [0.5, 0.12, -0.2],
			"charged": [Vector3(0.36, -0.03, -0.25), -80.0, 0.7],
		},
		&"right": {
			"pivot": Vector3(0.04, -0.3, 0.12),
			"path": [Vector3(-0.2, -0.08, -0.34), Vector3(-0.13, -0.12, -0.48), Vector3(0.09, -0.16, -0.54), Vector3(0.3, -0.2, -0.44), Vector3(0.38, -0.24, -0.26)],
			"lead": [-65.0, 12.0, 50.0],
			"rise": [0.5, 0.12, -0.2],
			"charged": [Vector3(-0.23, -0.03, -0.29), -80.0, 0.7],
		},
		&"overhead": {
			"pivot": Vector3(0.18, -0.24, 0.05),
			"path": [Vector3(0.27, 0.07, -0.24), Vector3(0.2, 0.0, -0.42), Vector3(0.06, -0.15, -0.52), Vector3(-0.05, -0.26, -0.46), Vector3(-0.1, -0.3, -0.38)],
			"lead": [-70.0, 10.0, 45.0],
			"rise": [0.0, 0.0, 0.0],
			"charged": [Vector3(0.26, 0.13, -0.17), -90.0, 0.0],
		},
		&"thrust": {
			"pivot": Vector3(0.18, -0.24, 0.05),
			"path": [Vector3(0.22, -0.22, -0.28), Vector3(0.2, -0.22, -0.35), Vector3(0.11, -0.21, -0.52), Vector3(0.08, -0.2, -0.58), Vector3(0.07, -0.2, -0.6)],
			"lead": [0.0, 0.0, 0.0],
			"rise": [0.2, 0.14, 0.12],
			"charged": [Vector3(0.24, -0.24, -0.22), 0.0, 0.22],
		},
	},
}

## The blackjack: a club, held low and brought over and down.
const BLACKJACK := {
	"rest": [Vector3(0.22, -0.26, -0.38), Vector3(-0.45, 0.85, -0.25), Vector3(0.0, 0.2, -1.0)],
	"sprint": [Vector3(0.25, -0.34, -0.32), Vector3(-0.45, 0.6, -0.65), Vector3(0.0, 0.8, -0.5)],
	"sweeps": {
		&"overhead": {
			"pivot": Vector3(0.18, -0.24, 0.05),
			"path": [Vector3(0.28, 0.08, -0.24), Vector3(0.21, 0.01, -0.44), Vector3(0.06, -0.14, -0.54), Vector3(-0.05, -0.26, -0.48), Vector3(-0.1, -0.3, -0.38)],
			"lead": [-75.0, 10.0, 45.0],
			"rise": [0.0, 0.0, 0.0],
			"charged": [Vector3(0.28, 0.16, -0.16), -90.0, 0.0],
		},
	},
}

## The bow: [grip, limb (up the stave), the way it shoots]. Carried low across
## you, raised to just left of your line of sight as it is drawn.
## The bow (its frame: the grip, the stave's way up, the way the arrow
## points). At rest it is carried low and across you, an arrow on the string,
## out of the middle of the view. Drawn, it is pushed out at arm's length and
## canted well over to the left at the top, so the stave keeps out of the
## band round the middle of the view you fight in (the combat corridor);
## the arrow lies along your line of sight, its head just under the middle of
## the view, and the string comes back under your chin (HandSlot's
## BOW_DRAW_LENGTH): the drawing hand and the feathers are out of sight.
const BOW := {
	"rest": [Vector3(-0.13, -0.34, -0.5), Vector3(0.72, 0.62, 0.3), Vector3(-0.3, 0.1, -1.0)],
	"drawn": [Vector3(0.043, -0.169, -0.512), Vector3(-0.545, 0.839, 0.0), Vector3(0.0, 0.0, -1.0)],
	"sprint": [Vector3(-0.06, -0.42, -0.36), Vector3(0.85, 0.35, 0.4), Vector3(-0.35, 0.1, -1.0)],
}

## Anything else in hand (a key, a tool): held up in front of you.
const ITEM := {
	"rest": [Vector3(0.18, -0.26, -0.36), Vector3(-0.2, 0.9, -0.35), Vector3(-0.1, 0.35, -1.0)],
}


static func set_of(id: StringName) -> Dictionary:
	match id:
		&"sword":
			return SWORD
		&"dagger":
			return DAGGER
		&"blackjack":
			return BLACKJACK
		&"bow":
			return BOW

	return ITEM


## A pose as the weapon's frame: its grip at the origin, the blade +Y, the
## true edge +X. A bow: the stave +Y, the way it shoots -Z.
static func frame(pose: Array) -> Transform3D:
	var blade: Vector3 = (pose[1] as Vector3).normalized()
	var edge: Vector3 = pose[2]
	edge = (edge - blade * edge.dot(blade)).normalized()
	return Transform3D(Basis(edge, blade, edge.cross(blade)), pose[0])


## A bow's pose: [grip, stave up, shooting direction] as the bow's frame
## (the stave +Y, the string toward you +Z).
static func bow_frame(pose: Array) -> Transform3D:
	var up: Vector3 = (pose[1] as Vector3).normalized()
	var ahead: Vector3 = pose[2]
	ahead = (ahead - up * ahead.dot(up)).normalized()
	var back := -ahead
	return Transform3D(Basis(up.cross(back), up, back), pose[0])


## Where a sweep has the weapon, `u` from 0 (drawn back) through 0.5 (the
## blade meeting what it cuts) to 1 (followed through); `charged` 0..1 draws
## it further back first. The fist runs a smooth curve through the sweep's
## path; the blade points out along the reach (from the pivot the body turns
## about), running behind it (`lead` < 0) or ahead (> 0) by degrees, and
## rising by `rise`; its true edge faces the way it is travelling.
static func sweep_frame(spec: Dictionary, u: float, charged := 0.0) -> Transform3D:
	var path: Array = (spec["path"] as Array).duplicate()
	var lead: Array = (spec["lead"] as Array).duplicate()
	var rise: Array = (spec["rise"] as Array).duplicate()

	if charged > 0.0 and spec.has("charged"):
		var drawn: Array = spec["charged"]
		path[0] = (path[0] as Vector3).lerp(drawn[0], charged)
		lead[0] = lerpf(lead[0], drawn[1], charged)
		rise[0] = lerpf(rise[0], drawn[2], charged)

	var t := clampf(u, 0.0, 1.0)
	var fist := _along(path, t)
	var motion := _along(path, minf(t + 0.02, 1.0)) - _along(path, maxf(t - 0.02, 0.0))
	motion = motion.normalized() if motion.length() > 0.0001 else Vector3.FORWARD
	# The blade points out along the reach, turned toward the way it travels
	# by its lead (behind it, negative). Driven straight out (a thrust: reach
	# and travel the same way), there is nothing to turn about: it points.
	var outward := (fist - (spec["pivot"] as Vector3)).normalized()
	var turn_axis := outward.cross(motion)
	var swept := outward

	if turn_axis.length() > 0.05:
		swept = outward.rotated(turn_axis.normalized(), deg_to_rad(_curve3(lead[0], lead[1], lead[2], t)))

	var blade := (swept + Vector3.UP * _curve3(rise[0], rise[1], rise[2], t)).normalized()
	var edge := motion - blade * motion.dot(blade)

	if edge.length() < 0.2:
		edge = Vector3.DOWN - blade * Vector3.DOWN.dot(blade)

	edge = edge.normalized()
	return Transform3D(Basis(edge, blade, edge.cross(blade)), fist)


## A point along a Catmull-Rom curve through `points` (0..1 end to end).
static func _along(points: Array, t: float) -> Vector3:
	var count := points.size()

	if count == 1:
		return points[0]

	var at := clampf(t, 0.0, 1.0) * float(count - 1)
	var i := mini(int(floor(at)), count - 2)
	var f := at - float(i)
	var p1: Vector3 = points[i]
	var p2: Vector3 = points[i + 1]
	var p0: Vector3 = points[i - 1] if i > 0 else p1 * 2.0 - p2
	var p3: Vector3 = points[i + 2] if i + 2 < count else p2 * 2.0 - p1
	return _catmull(p0, p1, p2, p3, f)


## A value through three keys at 0, 0.5 and 1, smoothly (no stop at the middle).
static func _curve3(a: float, b: float, c: float, t: float) -> float:
	var u := clampf(t, 0.0, 1.0)

	if u < 0.5:
		return _catmull_1d(a * 2.0 - b, a, b, c, u * 2.0)

	return _catmull_1d(a, b, c, c * 2.0 - b, u * 2.0 - 1.0)


static func _catmull_1d(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


static func blend(a: Transform3D, b: Transform3D, t: float) -> Transform3D:
	var q := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), clampf(t, 0.0, 1.0))
	return Transform3D(Basis(q), a.origin.lerp(b.origin, t))


## Along the curve from `a` through `b` to `c` (0 at a, 0.5 at b, 1 at c): a
## swing's arc, not two straight lines.
static func arc(a: Transform3D, b: Transform3D, c: Transform3D, t: float) -> Transform3D:
	var u := clampf(t, 0.0, 1.0)
	# Catmull-Rom through the three, ends extended by reflection.
	var before := a.origin * 2.0 - b.origin
	var after := c.origin * 2.0 - b.origin
	var at: Vector3

	if u < 0.5:
		at = _catmull(before, a.origin, b.origin, c.origin, u * 2.0)
	else:
		at = _catmull(a.origin, b.origin, c.origin, after, u * 2.0 - 1.0)

	var q: Quaternion

	if u < 0.5:
		q = a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), u * 2.0)
	else:
		q = b.basis.get_rotation_quaternion().slerp(c.basis.get_rotation_quaternion(), u * 2.0 - 1.0)

	return Transform3D(Basis(q), at)


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
