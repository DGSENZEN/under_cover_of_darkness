extends RefCounted
## World-space hand-contact state machine for traversal and carrying.
## Each grip plants on geometry, then travels in a short arc to its next hold;
## weights ease contact changes. HandSlot reads hand(), weight(), and curl().

enum State { FREE, HANG, MANTLE, VAULT, LADDER, ROPE, CARRY, READ, POLE }

const LEFT := 0
const RIGHT := 1
## Hands this far either side of the body on an edge: a little inside the
## shoulders, as a hang is held (and framed: Dying Light's hands grip a
## quarter in from each side of the view).
const SPREAD := 0.16
## Pressing down to climb on: closer in, under the shoulders.
const PUSH_SPREAD := 0.17
## How far a planted hand may fall behind the body before it moves on.
const SLACK := 0.2
## A hand moving to a new hold: how long, and how high it lifts.
const TRAVEL_TIME := 0.13
const LIFT := 0.06
## A hand thrown at a hold: the share of its move spent gathering, how far it
## draws back to gather (m), and how far past the hold it carries (share).
const GATHER := 0.18
const GATHER_BACK := 0.04
const THROW_OVERSHOOT := 0.9
## Shorter than this (m), a hand's move is not a throw.
const THROW_MIN := 0.25
## Taking hold and letting go.
const GRIP_TIME := 0.1
## Ladder rungs, from the ground up.
const RUNG := 0.3

## One hand: where it holds (world; the palm's frame, fingers -Z into the
## edge, back of the hand +Y), where a move to it began, how far along the move
## is, and how firmly it holds.
class Grip:
	var at := Transform3D.IDENTITY
	var from := Transform3D.IDENTITY
	var travel := 1.0
	var weight := 0.0
	var wanted := false
	var planted := false

	func place(where: Transform3D) -> void:
		# From wherever it is now, or straight there if it was not holding.
		from = current() if planted and weight > 0.05 else where
		at = where
		travel = 0.0 if planted and weight > 0.05 else 1.0
		planted = true

	func current() -> Transform3D:
		if travel >= 1.0:
			return at

		# Thrown: a little pull back toward the body to gather, then out fast
		# and a touch past the hold, settling back onto it.
		var heading := at.origin - from.origin

		# A short shift (a hand turning from hooked to pressing, a shuffle) is
		# only moved, not thrown.
		if heading.length() < THROW_MIN:
			var e := travel * travel * (3.0 - 2.0 * travel)
			var moved := from.interpolate_with(at, e)
			moved.origin += Vector3.UP * LIFT * 0.5 * sin(PI * travel)
			return moved

		var gather := 1.0 - smoothstep(0.0, GATHER, travel) if travel < GATHER else 0.0
		var p := clampf((travel - GATHER) / (1.0 - GATHER), 0.0, 1.0)
		var x := p - 1.0
		var t := 1.0 + (THROW_OVERSHOOT + 1.0) * x * x * x + THROW_OVERSHOOT * x * x
		var shown := from.interpolate_with(at, clampf(t, 0.0, 1.0))
		shown.origin = from.origin.lerp(at.origin, t)
		shown.origin -= heading.normalized() * GATHER_BACK * sin(PI * (travel / GATHER)) if travel < GATHER and heading.length() > 0.001 else Vector3.ZERO
		shown.origin += Vector3.UP * LIFT * sin(PI * travel)
		return shown

var state := State.FREE
var grips: Array = [Grip.new(), Grip.new()]
var player: CharacterBody3D
## The right hand has a weapon in it (HandSlot sets this): a mantle or a vault
## is done with the left hand alone, and the weapon stays in sight. Holding on
## with both (a ledge, a ladder, a rope), the weapon goes down out of sight
## first and the empty hand comes up after it.
var right_busy := false
var _one_handed := false
## The contact the current state was entered on (edges, rungs): a new one of
## the same kind is a new state.
var _entered_on := Vector3.INF
## Hand over hand: the hand still to follow the leading one (-1: none), and
## how far through the move it goes.
var _trail_side := -1
## The hand still to lead to the next hold (-1: none), once the body is this
## far through the pull.
var _lead_side := -1
const LEAD_AFTER := 0.3
const TRAIL_AFTER := 0.6


func _init(p_player: CharacterBody3D) -> void:
	player = p_player


## Returns the current world palm transform; side must be LEFT (0) or RIGHT (1).
func hand(side: int) -> Transform3D:
	return (grips[side] as Grip).current()


## Returns the side’s contact blend in 0..1; side must index grips.
func weight(side: int) -> float:
	return (grips[side] as Grip).weight


## Returns the greater contact weight of the two hands.
func holding() -> float:
	return maxf(weight(LEFT), weight(RIGHT))


## Whether the state wants this hand on the world (it may not be there yet).
func wants(side: int) -> bool:
	return (grips[side] as Grip).wanted


## How closed a holding hand is: flat to push down on a top, hooked over a
## ledge, wrapped round a rung or a rope.
func curl(side: int) -> float:
	match state:
		State.MANTLE, State.VAULT:
			return 0.25
		State.HANG:
			# Open on the way to a hold, hooked over it once there.
			var g := grips[side] as Grip
			return lerpf(0.2, 0.88, smoothstep(0.6, 1.0, g.travel))
		State.LADDER, State.ROPE:
			return 0.92
		State.CARRY:
			return 0.35

	return 0.5


## The hand pose a holding hand takes, for arms that have it (ArmReach.POSES),
## and how far into it: [pose, amount]. A hook over a ledge (open on the way
## to it), a wrap round a pipe, rung or rope, a flat push on a top.
func grip_pose(side: int) -> Array:
	match state:
		State.HANG:
			var g := grips[side] as Grip
			return [&"Hook", lerpf(0.2, 1.0, smoothstep(0.6, 1.0, g.travel))]
		State.LADDER, State.ROPE, State.POLE:
			return [&"Wrap", 1.0]
		State.MANTLE, State.VAULT:
			return [&"Push", 1.0]
		State.CARRY:
			return [&"Fist", 0.35]

	return [&"Fist", 0.5]


## How far below the middle of `view` (radians) the hands that are taking
## hold are: the view looks down to see them land (CameraJuice). 0 when none
## are, or they are above it.
func below(view: Transform3D) -> float:
	var sum := Vector3.ZERO
	var count := 0

	for grip in grips:
		var g := grip as Grip

		if g.wanted and g.planted:
			sum += g.at.origin
			count += 1

	if count == 0:
		return 0.0

	var to := sum / count - view.origin
	var basis := view.basis.orthonormalized()
	return maxf(atan2(-to.dot(basis.y), -to.dot(basis.z)), 0.0)


## Both hands on their holds, none still on its way (the next pull of a
## climb waits for this).
func settled() -> bool:
	if _trail_side >= 0 or _lead_side >= 0:
		return false

	for grip in grips:
		var g := grip as Grip

		if g.wanted and g.travel < 1.0:
			return false

	return true


## How far above the middle of `view` (radians) the holds the hands are on
## or going to are: on a climb the view looks up to them (CameraJuice). 0 when
## nothing is held, or it is below.
func above(view: Transform3D) -> float:
	var sum := Vector3.ZERO
	var count := 0

	for grip in grips:
		var g := grip as Grip

		if g.wanted and g.planted:
			sum += g.at.origin
			count += 1

	if count == 0:
		return 0.0

	var to := sum / count - view.origin
	var basis := view.basis.orthonormalized()
	return maxf(atan2(to.dot(basis.y), -to.dot(basis.z)), 0.0)


## Reads movement/carry state and advances grip targets, travel, and weights in game seconds.
func update(delta: float) -> void:
	var next := _state_now()

	if next != state:
		_enter(next)

	match state:
		State.HANG:
			_keep_hang()
		State.MANTLE, State.VAULT:
			_keep_move()
		State.LADDER:
			_keep_ladder()
		State.ROPE:
			_keep_rope()
		State.POLE:
			_keep_pole()
		State.CARRY:
			_keep_carry()
		State.READ:
			_keep_read()

	for side in [LEFT, RIGHT]:
		var g := grips[side] as Grip
		var was := g.travel
		g.travel = minf(g.travel + delta / TRAVEL_TIME, 1.0)

		# A hand landing on a hold on a climb: its weight is felt.
		if was < 1.0 and g.travel >= 1.0 and g.wanted and (state == State.HANG or state == State.POLE) and player.has_method("on_hand_landed"):
			player.on_hand_landed(-1.0 if side == LEFT else 1.0)

	for grip in grips:
		var g := grip as Grip
		g.weight = move_toward(g.weight, 1.0 if g.wanted else 0.0, delta / GRIP_TIME)

		if g.weight <= 0.0 and not g.wanted:
			g.planted = false


# Which state

func _state_now() -> int:
	if player == null or player.get("is_dead") == true:
		return State.FREE

	match player.movement_state:
		player.MoveState.HANGING:
			return State.HANG
		player.MoveState.CLIMBING:
			var volume: Area3D = player.current_climb

			if player.get("climb_hold") != null:
				return State.POLE

			return State.ROPE if volume != null and volume.has_method("rope_point") else State.LADDER
		player.MoveState.MOVING:
			var move = player.current_move

			if move == null or not move.has_contact:
				return State.FREE

			match int(move.kind):
				0:
					return State.VAULT
				1, 100:
					# A mantle, and pulling up over a held lip: hands press flat.
					return State.MANTLE
				106:
					# Running up a wall: the hands come up for the hold halfway.
					if float(player.get("move_progress")) < 0.4:
						return State.FREE

			# Reaching for a hang, a pull-up, a leap to another ledge: the hands
			# are on (or going to) an edge, as when hanging.
			return State.HANG

	if player.get("frob") != null and player.frob.held != null:
		return State.CARRY

	# A page held up to read (the letter, a notice): both hands on it.
	var hand: Node = player.get("hand")

	if hand != null and hand.has_method("is_page_up") and hand.is_page_up():
		return State.READ

	return State.FREE


func _enter(next: int) -> void:
	state = next
	_trail_side = -1
	_lead_side = -1
	_one_handed = right_busy

	for grip in grips:
		(grip as Grip).wanted = false

	match state:
		State.HANG:
			_plant_edge_pair(false)
		State.MANTLE:
			if _one_handed:
				# Just the left, nearer the middle, while the right keeps its
				# weapon up.
				var edge := _edge()
				var lateral := _lateral(edge[1])
				var centre := _nearest_on_edge(edge[0], lateral)
				_plant(LEFT, _pushing(_on_top(centre + lateral * SPREAD * 0.55, edge[1], 0.15), LEFT))
				_entered_on = centre
			else:
				_plant_edge_pair(true)
		State.VAULT:
			# Over on one hand: the left, just left of the middle, so the right
			# can keep hold of whatever it has.
			var edge := _edge()
			var lateral := _lateral(edge[1])
			var spot: Vector3 = _nearest_on_edge(edge[0], lateral) + lateral * 0.1
			_plant(LEFT, _pushing(_on_top(spot, edge[1], 0.12), LEFT))
		State.LADDER:
			_plant_rungs()
		State.ROPE:
			_plant_rope()
		State.POLE:
			_plant_pole()
		State.CARRY:
			_keep_carry()
		State.READ:
			_keep_read()


# Edges: a ledge hung from, climbed onto, vaulted

## [a point on the edge, the edge's outward normal] for whatever the body is
## on or going to.
func _edge() -> Array:
	var move = player.current_move

	if player.movement_state == player.MoveState.MOVING and move != null and move.has_contact:
		return [move.contact_point, move.contact_normal]

	var normal: Vector3 = player.hang_normal
	var point: Vector3 = player.global_position - normal * (float(player._radius) + 0.02)
	point.y = player.hang_lip_y
	return [point, normal]


func _lateral(normal: Vector3) -> Vector3:
	var n := Vector3(normal.x, 0.0, normal.z)
	return n.normalized().cross(Vector3.UP).normalized() if n.length() > 0.01 else player.global_basis.x


## The body projected onto the edge: where it is along it.
func _nearest_on_edge(point: Vector3, lateral: Vector3) -> Vector3:
	var along: float = (player.global_position - point).dot(lateral)
	return point + lateral * along


## One hand's hold on an edge: hooked over it, or pushing down on its top.
func _edge_hold(side: int, edge: Array, lateral: Vector3, centre: Vector3, pushing: bool) -> Transform3D:
	var inset := 0.15 if pushing else 0.03
	var spread := PUSH_SPREAD if pushing else SPREAD
	var hold := _on_top(centre + lateral * (spread if side == LEFT else -spread), edge[1], inset)
	return _pushing(hold, side) if pushing else hold


func _plant_edge_pair(pushing: bool) -> void:
	var edge := _edge()
	var lateral := _lateral(edge[1])
	var centre := _nearest_on_edge(edge[0], lateral)
	# Pushing down to climb on: flat on the top, well in from the edge.
	var inset := 0.15 if pushing else 0.03
	var spread := PUSH_SPREAD if pushing else SPREAD
	var left := _on_top(centre + lateral * spread, edge[1], inset)
	var right := _on_top(centre - lateral * spread, edge[1], inset)
	_plant(LEFT, _pushing(left, LEFT) if pushing else left)
	_plant(RIGHT, _pushing(right, RIGHT) if pushing else right)
	_entered_on = centre


## A hand pushing down on a top: fingers turned in a little toward the other.
static func _pushing(hold: Transform3D, side: int) -> Transform3D:
	var turn := deg_to_rad(-18.0 if side == LEFT else 18.0)
	return Transform3D(Basis(Vector3.UP, turn) * hold.basis, hold.origin)


## Hanging and shuffling: each hand stays where it took hold until the body has
## gone on past it, then moves up along the edge; one at a time.
func _keep_hang() -> void:
	var edge := _edge()
	var lateral := _lateral(edge[1])
	var centre := _nearest_on_edge(edge[0], lateral)

	# Hand over hand up a wall: both hands pull on the hold they have until
	# the body is up near the next, then the leading hand goes to it, then the
	# other follows. (A real arm cannot reach the next hold from a hang.)
	if _lead_side >= 0 or _trail_side >= 0:
		var moving: bool = player.movement_state == player.MoveState.MOVING
		var s := float(player.move_progress) if moving else 1.0

		if _lead_side >= 0 and s >= LEAD_AFTER:
			_plant(_lead_side, _edge_hold(_lead_side, edge, lateral, centre, false))
			_lead_side = -1

		if _lead_side < 0 and _trail_side >= 0 and s >= TRAIL_AFTER:
			_plant(_trail_side, _edge_hold(_trail_side, edge, lateral, centre, false))
			_trail_side = -1
			_entered_on = centre

		for grip in grips:
			(grip as Grip).wanted = true

		return

	# A new edge (a leap, a corner): take hold of it afresh.
	if _entered_on.distance_to(centre) > 1.2 or absf(_entered_on.y - centre.y) > 0.25:
		var move = player.current_move

		# Climbing on to it (a reach, a leap, the catch of a wall run): one
		# hand leads, the one on the side it goes, else the other one's turn.
		if player.movement_state == player.MoveState.MOVING and move != null and int(move.kind) in [103, 105, 106] and grips[LEFT].planted and grips[RIGHT].planted:
			var lead := RIGHT if float(player.juice.reach_side) > 0.0 else LEFT
			_lead_side = lead
			_trail_side = 1 - lead

			for grip in grips:
				(grip as Grip).wanted = true

			return

		_plant_edge_pair(false)
		return

	_entered_on = centre

	for side in [LEFT, RIGHT]:
		var g := grips[side] as Grip
		var other := grips[1 - side] as Grip

		if g.travel < 1.0 or other.travel < 1.0:
			continue

		var ideal := centre + lateral * (SPREAD if side == LEFT else -SPREAD)
		var off: float = (g.at.origin - ideal).dot(lateral)

		if absf(off) > SLACK or g.at.origin.distance_to(ideal) > 0.6:
			# Reach on a little past where it is needed, so the next move is
			# the other hand's.
			_plant(side, _on_top(ideal - lateral * signf(off) * 0.06, edge[1], 0.03))
			break

	for grip in grips:
		(grip as Grip).wanted = true


## A mantle or a vault: the hands stay where they were planted, and let go as
## the body goes up and over them.
func _keep_move() -> void:
	var s: float = player.move_progress

	if state == State.MANTLE:
		var hold := s < 0.82
		(grips[LEFT] as Grip).wanted = hold
		(grips[RIGHT] as Grip).wanted = hold and not _one_handed
	else:
		(grips[LEFT] as Grip).wanted = s < 0.62


# Ladders and ropes: hand over hand

func _ladder_hold(height: float, side: int) -> Transform3D:
	var volume: Area3D = player.current_climb
	var normal: Vector3 = player.climb_normal()
	var lateral := _lateral(normal)
	var wall: Vector3 = player.global_position - normal * (float(player._radius) + 0.05)
	# (Up the climb's plane to that height: a leaning one's, shrouds', in or
	# out with it.)
	var up: Vector3 = volume.get_climb_up() if volume.has_method("get_climb_up") else Vector3.UP
	var at := wall + up * ((height - wall.y) / maxf(up.y, 0.2)) + lateral * (0.2 if side == LEFT else -0.2)
	return Transform3D(_palm_basis(normal), at)


## Your eyes' height, and the rung at or above a height.
func _eye_y() -> float:
	return (player.camera as Node3D).global_position.y if player.get("camera") != null else player.global_position.y + 0.8


static func _rung_above(height: float) -> float:
	return ceilf(height / RUNG) * RUNG


## One hand on the rung just above your eyes, the other on the one below.
func _plant_rungs() -> void:
	var high := _rung_above(_eye_y() + 0.05)
	_plant(LEFT, _ladder_hold(high, LEFT))
	_plant(RIGHT, _ladder_hold(high - RUNG * 2.0, RIGHT))


## Hand over hand: climbing past the higher hand, the lower one goes over it
## to the rung above; climbing down to the lower one, the higher one goes
## under it. Far off (a jump onto the ladder partway), both take hold afresh.
func _keep_ladder() -> void:
	var eye := _eye_y()
	var left := grips[LEFT] as Grip
	var right := grips[RIGHT] as Grip

	for grip in grips:
		(grip as Grip).wanted = true

	if left.travel < 1.0 or right.travel < 1.0:
		return

	var high_side := LEFT if left.at.origin.y >= right.at.origin.y else RIGHT
	var high: float = (grips[high_side] as Grip).at.origin.y
	var low: float = (grips[1 - high_side] as Grip).at.origin.y

	if absf(high - eye) > 1.0 or absf(low - eye) > 1.3:
		_plant_rungs()
		return

	if eye > high - 0.05:
		_plant(1 - high_side, _ladder_hold(high + RUNG * 2.0, 1 - high_side))
	elif eye < low + RUNG * 1.5:
		_plant(high_side, _ladder_hold(low - RUNG * 2.0, high_side))


## The rope is measured from its anchor, in metres: up it is less.
func _rope_here() -> float:
	var volume: Area3D = player.current_climb
	var here: float = player.rope_param

	if here < 0.0 and volume.has_method("closest_param"):
		here = volume.closest_param(player.global_position)

	return here


func _rope_hold(param: float) -> Transform3D:
	var volume: Area3D = player.current_climb
	var point: Vector3 = volume.rope_point(maxf(param, 0.0))
	return Transform3D(_palm_basis(volume.get_rope_normal(player.global_position)), point)


## One hand at your eyes, the other a reach above.
func _plant_rope() -> void:
	var here := _rope_here()
	_plant(LEFT, _rope_hold(here - 1.0))
	_plant(RIGHT, _rope_hold(here - 0.65))


func _keep_rope() -> void:
	var here := _rope_here()
	var volume: Area3D = player.current_climb
	var left := grips[LEFT] as Grip
	var right := grips[RIGHT] as Grip

	for grip in grips:
		(grip as Grip).wanted = true

	if left.travel < 1.0 or right.travel < 1.0:
		return

	var eye_point: Vector3 = volume.rope_point(maxf(here - 0.65, 0.0))
	var high_side := LEFT if left.at.origin.y >= right.at.origin.y else RIGHT
	var high: float = (grips[high_side] as Grip).at.origin.y
	var low: float = (grips[1 - high_side] as Grip).at.origin.y

	if absf(high - eye_point.y) > 1.2 or absf(low - eye_point.y) > 1.2:
		_plant_rope()
		return

	# Up the rope: the lower hand over the higher, a reach above it.
	if eye_point.y > low + 0.45:
		_plant(1 - high_side, _rope_hold(here - 1.05))
	elif eye_point.y < high - 0.8:
		_plant(high_side, _rope_hold(here - 0.3))


# A pole (a drainpipe): both hands round it, one at the eyes and one a reach
# above, the lower going over the higher as the body climbs.

func _pole_hold(y: float) -> Transform3D:
	var hold: Node3D = player.climb_hold
	var at: Vector3 = hold.grip_near(Vector3(player.global_position.x, y, player.global_position.z))
	return Transform3D(_palm_basis(hold.outward()), at)


func _pole_eye() -> float:
	return player.global_position.y + 0.8


func _plant_pole() -> void:
	_plant(LEFT, _pole_hold(_pole_eye() - 0.1))
	_plant(RIGHT, _pole_hold(_pole_eye() + 0.25))


func _keep_pole() -> void:
	var left := grips[LEFT] as Grip
	var right := grips[RIGHT] as Grip

	for grip in grips:
		(grip as Grip).wanted = true

	if left.travel < 1.0 or right.travel < 1.0:
		return

	var eye := _pole_eye()
	var high_side := LEFT if left.at.origin.y >= right.at.origin.y else RIGHT
	var high: float = (grips[high_side] as Grip).at.origin.y
	var low: float = (grips[1 - high_side] as Grip).at.origin.y

	if absf(high - eye) > 1.2 or absf(low - eye) > 1.2:
		_plant_pole()
		return

	if eye > low + 0.45:
		_plant(1 - high_side, _pole_hold(eye + 0.3))
	elif eye < high - 0.8:
		_plant(high_side, _pole_hold(eye - 0.3))


# Carrying: both hands on what you hold (it moves with you: not planted)

func _keep_carry() -> void:
	var held: RigidBody3D = player.frob.held if player.get("frob") != null else null

	if held == null:
		return

	var side_axis: Vector3 = player.global_basis.x
	var size := 0.28
	var shape := held.get_node_or_null("CollisionShape3D") as CollisionShape3D

	if shape != null and shape.shape is BoxShape3D:
		size = (shape.shape as BoxShape3D).size.x * 0.5 + 0.02

	var basis := Basis(Vector3.UP, player.global_rotation.y)

	for side in [LEFT, RIGHT]:
		var g := grips[side] as Grip
		var sign := -1.0 if side == LEFT else 1.0
		# Palms in on its sides, fingers forward.
		g.at = Transform3D(basis * Basis(Vector3.FORWARD, sign * PI * 0.5), held.global_position + side_axis * sign * size)
		g.travel = 1.0
		g.planted = true
		g.wanted = true


## Both hands on the page held up, at its side edges (HandSlot.page_edge).
func _keep_read() -> void:
	var hand: Node = player.get("hand")

	if hand == null:
		return

	for side in [LEFT, RIGHT]:
		var g := grips[side] as Grip
		g.at = hand.page_edge(side)
		g.travel = 1.0
		g.planted = true
		g.wanted = true


# Surfaces

## A hold on the top of an edge near `point`: the top found by casting down
## just behind the edge, the palm `inset` in from the edge, fingers pointing
## over it into the face (-normal). Where there is no top to find (a thin
## rail), on the edge itself.
func _on_top(point: Vector3, normal: Vector3, inset: float) -> Transform3D:
	var n := Vector3(normal.x, 0.0, normal.z)
	n = n.normalized() if n.length() > 0.01 else -player.global_basis.z
	var basis := _palm_basis(n)
	var over := point - n * maxf(inset, 0.02)
	var space := player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	var down := PhysicsRayQueryParameters3D.create(over + Vector3.UP * 0.35, over - Vector3.UP * 0.3, 1, exclude)
	var top := space.intersect_ray(down)

	if not top.is_empty() and (top["normal"] as Vector3).y > 0.6:
		return Transform3D(basis, (top["position"] as Vector3) + Vector3.UP * 0.012)

	return Transform3D(basis, point + Vector3.UP * 0.012)


## A palm flat on a surface facing `normal`'s way: fingers -Z into it, the
## back of the hand +Y up.
static func _palm_basis(normal: Vector3) -> Basis:
	var n := Vector3(normal.x, 0.0, normal.z)

	if n.length_squared() < 0.0001:
		return Basis.IDENTITY

	return Basis.looking_at(-n.normalized(), Vector3.UP)


func _plant(side: int, where: Transform3D) -> void:
	var g := grips[side] as Grip
	g.place(where)
	g.wanted = true
