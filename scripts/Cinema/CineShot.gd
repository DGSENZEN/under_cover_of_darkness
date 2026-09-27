extends RefCounted
## Where a camera stands for a kind of shot, where it looks, and through what
## lens: framing, and nothing else (no scene tree beyond the men's places).
## `frame` gives {kind, size, position, look, fov, focus, subject, near_blur}:
##   size       wide, medium or close (the editor's cutting rules).
##   fov        the vertical field of view, degrees.
##   focus      metres from the camera to what it is on (`subject`).
##   near_blur  whether what is nearest (a shoulder) goes soft.
## The kinds:
##   establishing  the whole place from high, from a vantage.
##   observe       from a vantage, far off, a long lens fitted to the men.
##   roving        a long take's framing: waist up, near normal.
##   group         several men at different depths, from a vantage, long.
##   medium        waist up.
##   close         head and shoulders.
##   over_shoulder over the listener's shoulder (men[1]) onto the speaker.
##   two           both men, from the side of their line it is given.
##   reaction      the listener's face (men[0]) as a line lands.
##   insert        a detail (context.target): the fire, a torch, a hand.
##   track         alongside a man as he goes, from well off, long.
##   axial         straight in along one line, a step at a time (0, 1, 2).
##   overhead      straight down from high: the last resort.
## A man's head is set on a third, with room on the side he faces or goes,
## and his eyes on the upper third.
##
## The context: `aspect` (width over height, 16:9 if not given); `side` (off
## the line between men[0] and men[1], toward the camera); `from` (a vantage);
## `step` (axial); `target` (insert).

## Where a man's head is, by what he is doing, over his feet (times his size).
const HEAD_LYING := 0.35
const HEAD_KNEELING := 0.95
const HEAD_STANDING := 1.6
## How much of him each size shows top to bottom (m): its distance follows.
const CLOSE_HEIGHT := 0.9
const MEDIUM_HEIGHT := 1.6
const WIDE_HEIGHT := 6.0
## Lenses (vertical degrees).
const LONG := Vector2(18.0, 28.0)
const NORMAL := 40.0
const ESTABLISHING := 35.0
const INSERT := 32.0
const OVERHEAD := 50.0
const AXIAL := [40.0, 30.0, 22.0]
## A single man is seen from this far round from his front (degrees).
const THREE_QUARTER := 30.0
## Over the shoulder: behind the listener's head, and out to the side (m).
const SHOULDER_BACK := 0.9
const SHOULDER_OUT := 0.35
## Tracking a man: out to his side (m).
const TRACK_OFF := 7.0
## Overhead: up and a little to the south of them.
const ABOVE := Vector3(0.0, 14.0, 3.0)
const LYING := [&"sleep", &"lie_down", &"wake"]
const KNEELING := [&"kneel", &"plead_kneel", &"rise_knees", &"rummage", &"sit", &"sit_talk", &"sit_down", &"sneak", &"doze"]


## The shot `kind` of `men` (see the header).
static func frame(kind: StringName, men: Array, context: Dictionary) -> Dictionary:
	var aspect := float(context.get("aspect", 16.0 / 9.0))
	var side: Vector3 = context.get("side", Vector3.ZERO)
	var man: Node3D = men[0] if not men.is_empty() else null
	var head := head_of(man) if man != null else Vector3.ZERO
	var centre := centre_of(men)

	match kind:
		&"close", &"reaction":
			return _single(kind, man, head, CLOSE_HEIGHT, NORMAL, &"close", side, aspect)
		&"medium", &"roving":
			var from: Variant = context.get("from")

			if kind == &"roving" and from is Vector3:
				return _from(kind, men, from, NORMAL, MEDIUM_HEIGHT, aspect, &"medium")

			return _single(kind, man, head, MEDIUM_HEIGHT, NORMAL, &"medium", side, aspect)
		&"two":
			return _two(men, side, aspect)
		&"over_shoulder":
			return _over_shoulder(men, side, aspect)
		&"insert":
			var target: Node3D = context.get("target", man)
			var at := target.global_position if target != null else centre
			var toward := _away(at, side, Vector3(0.0, 0.0, 1.0))
			var position := at + toward * 2.0 + Vector3.UP * 0.8
			return _result(kind, &"close", position, at, INSERT, at, false)
		&"track":
			return _track(man, head, side, aspect)
		&"observe", &"group", &"establishing":
			var from: Variant = context.get("from")
			var vantage: Vector3 = from if from is Vector3 else centre + _away(centre, side, Vector3(0.6, 0.0, 0.8)) * 18.0 + Vector3.UP * 3.5

			if kind == &"establishing":
				return _result(kind, &"wide", vantage, centre, ESTABLISHING, centre, false)

			return _from(kind, men, vantage, -1.0, 0.0, aspect, &"")
		&"axial":
			var step := clampi(int(context.get("step", 0)), 0, 2)
			var from: Variant = context.get("from")
			var axis: Vector3 = ((from as Vector3) - head) if from is Vector3 else -facing(man) * 5.0
			axis = axis.normalized() if axis.length() > 0.01 else Vector3.BACK
			var fov: float = AXIAL[step]
			var height: float = [WIDE_HEIGHT, MEDIUM_HEIGHT, CLOSE_HEIGHT][step]
			var position := head + axis * _distance(height, fov)
			var look := _composed(position, head, facing(man), fov, aspect)
			return _result(kind, [&"wide", &"medium", &"close"][step], position, look, fov, head, false)
		&"overhead":
			var position := centre + ABOVE
			return _result(kind, &"wide", position, centre, OVERHEAD, centre, false)

	return _single(&"medium", man, head, MEDIUM_HEIGHT, NORMAL, &"medium", side, aspect)


## Where his head is: his feet, and up by what he is doing and his size.
static func head_of(man: Node3D) -> Vector3:
	if man == null or not is_instance_valid(man):
		return Vector3.ZERO

	var doing: StringName = man.activity() if man.has_method("activity") else &""

	if doing in LYING:
		return man.global_position + Vector3.UP * HEAD_LYING

	var rig: Variant = man.get("_rig")
	var size := float(rig.get("size")) if rig != null and rig.get("size") != null else 1.0

	if doing in KNEELING:
		return man.global_position + Vector3.UP * HEAD_KNEELING * size

	return man.global_position + Vector3.UP * HEAD_STANDING * size


## Which way he faces, flat: the way he goes if he is going anywhere.
static func facing(man: Node3D) -> Vector3:
	if man == null or not is_instance_valid(man):
		return Vector3.FORWARD

	var going: Variant = man.get("velocity")

	if going is Vector3:
		var flat := Vector3((going as Vector3).x, 0.0, (going as Vector3).z)

		if flat.length() > 0.5:
			return flat.normalized()

	var ahead := -man.global_basis.z
	ahead.y = 0.0
	return ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD


## The middle of the men's heads (the world's origin for nobody).
static func centre_of(men: Array) -> Vector3:
	var sum := Vector3.ZERO
	var count := 0

	for m in men:
		if m != null and is_instance_valid(m):
			sum += head_of(m)
			count += 1

	return sum / float(count) if count > 0 else Vector3.ZERO


# ---------------------------------------------------------------------------
# The kinds
# ---------------------------------------------------------------------------

## One man, from three-quarters round his front (on `side` if given), far
## enough for `height` of him through `fov`.
static func _single(kind: StringName, man: Node3D, head: Vector3, height: float, fov: float, size: StringName, side: Vector3, aspect: float) -> Dictionary:
	var ahead := facing(man)
	var round := ahead.rotated(Vector3.UP, deg_to_rad(THREE_QUARTER))

	if side != Vector3.ZERO and round.dot(side) < 0.0:
		round = ahead.rotated(Vector3.UP, -deg_to_rad(THREE_QUARTER))

	var position := head + round * _distance(height, fov)
	var look := _composed(position, head, ahead, fov, aspect)
	return _result(kind, size, position, look, fov, head, false)


## Both men from the side of their line (the side given, else the one to
## their right), far enough for both, their eyes on the upper third.
static func _two(men: Array, side: Vector3, aspect: float) -> Dictionary:
	var a: Node3D = men[0]
	var b: Node3D = men[1] if men.size() > 1 else men[0]
	var line := head_of(b) - head_of(a)
	line.y = 0.0
	var across := Vector3.UP.cross(line.normalized()) if line.length() > 0.05 else Vector3.RIGHT

	if side != Vector3.ZERO and across.dot(side) < 0.0:
		across = -across

	var centre := centre_of([a, b])
	var half := tan(deg_to_rad(NORMAL) * 0.5)
	var wide := (line.length() + 1.6) / (2.0 * half * aspect)
	var distance := maxf(wide, _distance(MEDIUM_HEIGHT, NORMAL))
	var position := centre + across * distance + Vector3.UP * 0.2
	var look := centre + Vector3.DOWN * distance * half / 3.0
	return _result(&"two", &"medium", position, look, NORMAL, centre, false)


## Behind the listener's head (men[1]) and out to the side, onto the speaker
## (men[0]), set on the third away from the shoulder.
static func _over_shoulder(men: Array, side: Vector3, aspect: float) -> Dictionary:
	var speaker: Node3D = men[0]
	var listener: Node3D = men[1] if men.size() > 1 else men[0]
	var s := head_of(speaker)
	var l := head_of(listener)
	var back := l - s
	back.y = 0.0
	back = back.normalized() if back.length() > 0.05 else Vector3.BACK
	var out := Vector3.UP.cross(back)

	if side != Vector3.ZERO and out.dot(side) < 0.0:
		out = -out

	var position := l + back * SHOULDER_BACK + out * SHOULDER_OUT + Vector3.UP * 0.05
	# The listener shows on the side the camera stepped away from; the
	# speaker goes to the other third.
	var look := _composed(position, s, -out, NORMAL, aspect)
	return _result(&"over_shoulder", &"close", position, look, NORMAL, s, true)


## Alongside him, well off to his side, a long lens, room ahead of him.
static func _track(man: Node3D, head: Vector3, side: Vector3, aspect: float) -> Dictionary:
	var going := facing(man)
	var out := Vector3.UP.cross(going)

	if side != Vector3.ZERO and out.dot(side) < 0.0:
		out = -out

	var fov := 22.0
	var position := head + out * TRACK_OFF + Vector3.DOWN * 0.1
	var look := _composed(position, head, going, fov, aspect)
	return _result(&"track", &"medium", position, look, fov, head, false)


## From `vantage`, the lens fitted to the men (a long one when `fov` < 0),
## the one man set on a third, a group's nearest.
static func _from(kind: StringName, men: Array, vantage: Vector3, fov: float, height: float, aspect: float, size: StringName) -> Dictionary:
	var live := men.filter(func(m): return m != null and is_instance_valid(m))
	var centre := centre_of(live)
	var distance := maxf(vantage.distance_to(centre), 0.5)
	var spread := 0.0

	for a in live:
		for b in live:
			spread = maxf(spread, head_of(a).distance_to(head_of(b)))

	if fov < 0.0:
		var needed := maxf(spread + 2.0, 2.5)
		fov = clampf(rad_to_deg(2.0 * atan(needed / (2.0 * distance))), LONG.x, LONG.y)

	if size == &"":
		var shown := 2.0 * distance * tan(deg_to_rad(fov) * 0.5)
		size = &"wide" if shown >= 4.0 else &"medium"

	var nearest: Node3D = null

	for m in live:
		if nearest == null or head_of(m).distance_to(vantage) < head_of(nearest).distance_to(vantage):
			nearest = m

	var look := centre

	if live.size() == 1 or kind == &"group":
		look = _composed(vantage, head_of(nearest), facing(nearest), fov, aspect) if nearest != null else centre

	return _result(kind, size, vantage, look, fov, head_of(nearest) if nearest != null else centre, false)


# ---------------------------------------------------------------------------
# Composition
# ---------------------------------------------------------------------------

## Where to look from `position` so `head` lands on the third away from
## `ahead` (the room on his side) with his eyes on the upper third: the look
## point moved off the head across the view and down.
static func _composed(position: Vector3, head: Vector3, ahead: Vector3, fov: float, aspect: float) -> Vector3:
	var view := head - position
	var distance := view.length()

	if distance < 0.01:
		return head + Vector3.FORWARD

	var forward := view / distance
	var right := forward.cross(Vector3.UP)
	right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var half_v := tan(deg_to_rad(fov) * 0.5)
	var half_h := half_v * aspect
	# He faces to screen right: his head goes left, the look point right.
	var toward := signf(ahead.dot(right))

	if toward == 0.0:
		toward = 1.0

	return head + right * toward * distance * half_h / 3.0 - up * distance * half_v / 3.0


## Far enough for `height` to fill the frame through `fov`.
static func _distance(height: float, fov: float) -> float:
	return height / (2.0 * tan(deg_to_rad(fov) * 0.5))


## A flat way out from `at`: `side` if given, else `default`.
static func _away(at: Vector3, side: Vector3, default: Vector3) -> Vector3:
	var way := side if side != Vector3.ZERO else default
	way.y = 0.0
	return way.normalized() if way.length() > 0.01 else Vector3.BACK


static func _result(kind: StringName, size: StringName, position: Vector3, look: Vector3, fov: float, subject: Vector3, near_blur: bool) -> Dictionary:
	return {"kind": kind, "size": size, "position": position, "look": look, "fov": fov, "focus": position.distance_to(subject),
		"subject": subject, "near_blur": near_blur}
