extends Node3D
## Locomotion feel: the body under the camera (BodyMotion.gd), momentum at
## today's speeds, and the old feel kept behind F10 until it is signed off.
## The model checks feed a lone body frames at 60 ticks a second, the way the
## controller does; the rest drive the player.

const BodyMotionScript := preload("res://scripts/PlayerUtils/BodyMotion.gd")

const TICK := 1.0 / 60.0

var results: Array[String] = []


func _ready() -> void:
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	_model_checks()


# --------------------------------------------------------------------------
# The body on its own
# --------------------------------------------------------------------------

func _model_checks() -> void:
	# Y1 camera feel at 0 switches the body off completely (and the same
	#    walk and landing do move it when it is on)
	var quiet := _body()
	var loud := _body()

	for body in [quiet, loud]:
		_drive(body, 60, func(_i): return 6.5, 2.0)
		body.on_land(14.0)

	quiet.intensity = 0.0
	_drive(quiet, 3, func(_i): return 6.5, 2.0)
	_drive(loud, 3, func(_i): return 6.5, 2.0)
	var still := true

	for f in [0.0, 0.5, 1.0]:
		still = still and quiet.head_offset(f) == Transform3D.IDENTITY and quiet.shoulder_offset(f) == Transform3D.IDENTITY

	var moved: float = loud.head_offset(1.0).origin.length()
	_check("Y1 at camera feel 0 the head and shoulders do not move at all", still and moved > 0.01,
		"off: head %s shoulders %s; on: head moved %.4f m" % [quiet.head_offset(1.0).origin, quiet.shoulder_offset(1.0).origin, moved])

	# Y2 every footstep comes as the head is going down, and it bottoms out
	#    within 0.1 s: walking, sprinting and creeping
	var walk := _drive(_body(), 180, func(_i): return 6.5, 2.0)
	var sprint := _drive(_body(), 180, func(i): return lerpf(6.5, 8.5, clampf(i / 30.0, 0.0, 1.0)), 2.4)
	var creep := _drive(_body(), 180, func(_i): return 3.0, 1.1, true)
	var late := [_footfall_misses(walk), _footfall_misses(sprint), _footfall_misses(creep)]
	_check("Y2 every footstep lands as the head goes down, lowest within 0.1 s", late == [0, 0, 0] and _count_steps(walk, 60) >= 6,
		"steps off the beat (walk, sprint, creep) %s; walk steps %d" % [late, _count_steps(walk, 60)])

	# Y3 a steady walk: about a centimetre up and down, half that side to side,
	#    and the view barely turns
	var walk_y := _span(walk, 60, func(r): return r.head.origin.y)
	var walk_x := _span(walk, 60, func(r): return r.head.origin.x)
	var walk_turn := _most_turn(walk, 60)
	_check("Y3 a walk moves the head 0.8-1.8 cm up and down, under 1 cm sideways, turns it under 0.35 deg",
		walk_y >= 0.008 and walk_y <= 0.018 and walk_x <= 0.010 and walk_turn <= 0.0061,
		"up and down %.4f m sideways %.4f m most turn %.2f deg" % [walk_y, walk_x, rad_to_deg(walk_turn)])

	# Y4 a steady sprint: the body leans into the run (the head forward and
	#    lower), without pitching the view
	var run := _body()
	_drive(run, 60, func(_i): return 6.5, 2.0)
	var running := _drive(run, 120, func(i): return lerpf(6.5, 8.5, clampf(i / 30.0, 0.0, 1.0)), 2.4)
	var run_z := _mean(running, 60, func(r): return r.head.origin.z)
	var run_y := _mean(running, 60, func(r): return r.head.origin.y)
	var run_turn := _most_turn(running, 60)
	_check("Y4 a sprint leans the head 2 cm forward and down, turning it under 0.35 deg",
		run_z <= -0.02 and run_y <= -0.01 and run_turn <= 0.0061,
		"forward %.4f m down %.4f m most turn %.2f deg" % [run_z, run_y, rad_to_deg(run_turn)])

	# Y5 creeping: softer steps than a walk, more weight shift than bob
	var creep_y := _span(creep, 60, func(r): return r.head.origin.y)
	var creep_x := _span(creep, 60, func(r): return r.head.origin.x)
	_check("Y5 a crouch walk bobs less than a walk and sways more than it bobs", creep_y < walk_y and creep_x >= creep_y,
		"crouch up and down %.4f sideways %.4f; walk up and down %.4f" % [creep_y, creep_x, walk_y])

	# Y6 setting off the head lags a little; stopping, it carries on over the
	#    planted feet with a slight nod; stopped, only breathing moves it
	var setting := _drive(_body(), 30, func(i): return 6.5 * (1.0 - exp(-(i + 1) / 60.0 / 0.12)), 2.0)
	var head_lag := 0.0

	for r in setting:
		head_lag = maxf(head_lag, r.head.origin.z)

	var halt := _body()
	_drive(halt, 90, func(_i): return 6.5, 2.0)
	var halting := _drive(halt, 105, func(i): return maxf(6.5 - 6.5 * (i + 1) / 9.0, 0.0), 2.0)
	var carried := 0.0
	var nod := 0.0
	var settled := 0.0

	for i in 45:
		carried = minf(carried, halting[i].head.origin.z)
		nod = maxf(nod, absf((halting[i].head as Transform3D).basis.get_euler().x))

	for i in range(45, 105):
		settled = maxf(settled, (halting[i].head.origin as Vector3).length())

	_check("Y6 setting off the head lags 0.5-2 cm, a stop carries it 1.5-4 cm on with under 1 deg of nod, and 0.6 s later only breathing moves it",
		head_lag >= 0.005 and head_lag <= 0.02 and carried <= -0.015 and carried >= -0.04 and nod < deg_to_rad(1.0) and settled <= 0.003,
		"start lag %.4f m; stop carries %.4f m, nod %.2f deg; then most %.4f m" % [head_lag, carried, rad_to_deg(nod), settled])

	# Y11 landings sink the head with the fall: a hop's jump, a 3 m drop, and a
	#    fall that would break bones, and each comes back up
	var lands := []

	for fall in [9.6, 13.9, 40.0]:
		var legs := _body()
		_drive(legs, 30, func(_i): return 0.0, 2.0)
		legs.on_land(fall)
		var after := _drive(legs, 45, func(_i): return 0.0, 2.0)
		var lowest := 0.0

		for r in after:
			lowest = minf(lowest, r.head.origin.y)

		lands.append([lowest, absf(after[29].head.origin.y)])

	_check("Y11 a landing sinks the head 2-4 cm off a jump, 4.5-7.5 off 3 m, never past 12.5, and it is back within 0.5 s",
		lands[0][0] <= -0.02 and lands[0][0] >= -0.04 and lands[1][0] <= -0.045 and lands[1][0] >= -0.075
		and lands[2][0] >= -0.125 and lands[0][1] <= 0.004 and lands[1][1] <= 0.004 and lands[2][1] <= 0.004,
		"lowest and 0.5 s later: %s" % [lands.map(func(l): return "%.3f/%.4f" % [l[0], l[1]])])

	# Y12 the hands hang from the shoulders: a footfall reaches them after the
	#    head, a landing drops them further, they lag a start and swing on at
	#    a stop
	var late_hands := 0
	var steps := 0
	var starts := _step_ticks(walk, 60)

	for n in range(starts.size() - 1):
		var head_low := _lowest_tick(walk, starts[n], starts[n + 1], func(r): return r.head.origin.y)
		var hand_low := _lowest_tick(walk, starts[n], starts[n + 1], func(r): return r.head.origin.y + r.shoulder.origin.y)
		steps += 1

		if hand_low > head_low:
			late_hands += 1

	var dropped := _body()
	_drive(dropped, 30, func(_i): return 0.0, 2.0)
	dropped.on_land(13.9)
	var dropping := _drive(dropped, 45, func(_i): return 0.0, 2.0)
	var head_lowest := 0.0
	var hand_lowest := 0.0

	for r in dropping:
		head_lowest = minf(head_lowest, r.head.origin.y)
		hand_lowest = minf(hand_lowest, r.head.origin.y + r.shoulder.origin.y)

	var setting_off := _drive(_body(), 21, func(i): return 6.5 * (i + 1) / 21.0, 2.0)
	var lag := 0.0

	for r in setting_off:
		lag = maxf(lag, r.shoulder.origin.z)

	var stopper := _body()
	_drive(stopper, 90, func(_i): return 6.5, 2.0)
	var stopping := _drive(stopper, 30, func(i): return maxf(6.5 - 6.5 * (i + 1) / 9.0, 0.0), 2.0)
	var swing := 0.0

	for r in stopping:
		swing = minf(swing, r.shoulder.origin.z)

	_check("Y12 the hands dip after the head, drop further on a landing, lag a start, swing on at a stop",
		steps >= 5 and late_hands == steps and hand_lowest < head_lowest and lag > 0.002 and swing < -0.003,
		"late on %d of %d steps; landing head %.3f hands %.3f; start lag %.4f stop swing %.4f" % [late_hands, steps, head_lowest, hand_lowest, lag, swing])

	# Y13 a quarter-second hitch, even with a hard landing in it, never throws
	#    the body past its caps
	var hitch := _body()
	var inside := true
	var shaken := 0.0
	var gait := 0.0

	for i in 20:
		if i == 10:
			hitch.on_land(40.0)

		gait = fposmod(gait + 6.5 / 2.0 * 0.25, 2.0)
		hitch.step(0.25, _frame(6.5, gait))
		inside = inside and _inside_caps(hitch)
		shaken = maxf(shaken, hitch.head_offset(1.0).origin.length())

	_check("Y13 a 250 ms step never throws the head or shoulders past their caps", inside and shaken > 0.01,
		"head %s shoulders %s; most %.3f m" % [hitch.head_offset(1.0).origin, hitch.shoulder_offset(1.0).origin, shaken])

	# Y14 drawn between ticks: halfway between two ticks, halfway between
	#    their heads
	var drawn := _body()
	_drive(drawn, 47, func(_i): return 6.5, 2.0)
	var from: Vector3 = drawn.head_offset(0.0).origin
	var to: Vector3 = drawn.head_offset(1.0).origin
	var half: Vector3 = drawn.head_offset(0.5).origin
	_check("Y14 the head is drawn between its last two ticks", from != to and half.distance_to((from + to) * 0.5) < 0.000001,
		"from %s to %s half %s" % [from, to, half])

	# Y15 crouching: the view goes down at least as fast as the eye, passes the
	#    crouched height a little and settles; standing up passes the standing
	#    height a little and settles
	var kneel := _stance(0.8)
	var rise := _stance(0.0, 0.8)
	_check("Y15 crouch and stand never trail the eye, pass the target by 0.2-2 cm, settle within 0.6 s",
		kneel.trail <= 0.002 and kneel.past >= 0.002 and kneel.past <= 0.02 and kneel.after <= 0.0025
		and rise.trail <= 0.002 and rise.past >= 0.002 and rise.past <= 0.02 and rise.after <= 0.0025,
		"down: trails %.4f past %.4f after 0.6 s %.4f; up: trails %.4f past %.4f after %.4f" % [kneel.trail, kneel.past, kneel.after, rise.trail, rise.past, rise.after])

	# Y16 leaning out bends the body: a small dip that settles
	var bender := _body()
	var lean := 0.0
	var bend := []

	for i in 60:
		lean += (1.0 - lean) * (1.0 - exp(-9.0 / 60.0))
		var f := _frame(0.0, 0.0)
		f.lean = lean
		bender.step(TICK, f)
		bend.append(bender.head_offset(1.0).origin.y)

	var hold := bend.slice(48)
	_check("Y16 a full lean dips the head 0.5-1.5 cm and holds it there", bend[29] <= -0.005 and bend[29] >= -0.015 and hold.max() - hold.min() < 0.002,
		"at 0.5 s %.4f; last 0.2 s varies %.4f" % [bend[29], hold.max() - hold.min()])


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

func _body() -> RefCounted:
	var body: RefCounted = BodyMotionScript.new()
	body.setup(BodyMotionScript.default_footfall(), 12.0)
	return body


func _frame(speed: float, gait: float, crouched := false) -> RefCounted:
	var f: RefCounted = BodyMotionScript.Frame.new()
	f.velocity = Vector3(0.0, 0.0, -speed)
	f.facing = Basis.IDENTITY
	f.grounded = true
	f.locomotion = true
	f.crouched = crouched
	f.gait = gait
	return f


## Steps `body` for `ticks` ticks at 60 a second, walking straight ahead at
## `speed_at.call(tick)`; the gait advances with the speed the way the
## controller's does (a foot lands at each whole step). Each tick keeps the
## head, the shoulders and whether a foot landed.
func _drive(body: RefCounted, ticks: int, speed_at: Callable, stride: float, crouched := false) -> Array:
	var out := []
	var gait := 0.0

	for i in ticks:
		var speed: float = speed_at.call(i)
		var before := gait
		gait = fposmod(gait + speed / stride * TICK, 2.0)
		body.step(TICK, _frame(speed, gait, crouched))
		out.append({
			"head": body.head_offset(1.0),
			"shoulder": body.shoulder_offset(1.0),
			"step": floorf(before) != floorf(gait),
		})

	return out


## The ticks (from `skip` on) on which a foot landed.
func _step_ticks(records: Array, skip: int) -> Array:
	var ticks := []

	for i in range(skip, records.size()):
		if records[i].step:
			ticks.append(i)

	return ticks


func _count_steps(records: Array, skip: int) -> int:
	return _step_ticks(records, skip).size()


## Footsteps (after the first second) where the head was not already going
## down, or where the step's lowest point came more than 6 ticks after it.
func _footfall_misses(records: Array) -> int:
	var ticks := _step_ticks(records, 60)
	var misses := 0

	for n in range(ticks.size() - 1):
		var at: int = ticks[n]
		var going_down: bool = records[at].head.origin.y < records[at - 1].head.origin.y
		var low := _lowest_tick(records, at, ticks[n + 1], func(r): return r.head.origin.y)

		if not going_down or low > at + 6:
			misses += 1

	return misses


func _lowest_tick(records: Array, from: int, to: int, value: Callable) -> int:
	var best := from

	for i in range(from, to):
		if float(value.call(records[i])) < float(value.call(records[best])):
			best = i

	return best


func _span(records: Array, skip: int, value: Callable) -> float:
	var values := records.slice(skip).map(value)
	return float(values.max()) - float(values.min())


func _mean(records: Array, skip: int, value: Callable) -> float:
	var values := records.slice(skip).map(value)
	var total := 0.0

	for v in values:
		total += float(v)

	return total / maxf(values.size(), 1.0)


## The most the head turns (pitch or roll) over the records from `skip` on.
func _most_turn(records: Array, skip: int) -> float:
	var most := 0.0

	for r in records.slice(skip):
		var turn: Vector3 = (r.head as Transform3D).basis.get_euler()
		most = maxf(most, maxf(absf(turn.x), absf(turn.z)))

	return most


func _inside_caps(body: RefCounted) -> bool:
	var head: Transform3D = body.head_offset(1.0)
	var shoulder: Transform3D = body.shoulder_offset(1.0)
	var head_turn := head.basis.get_euler()
	var shoulder_turn := shoulder.basis.get_euler()
	var ok := head.origin.length() <= BodyMotionScript.HEAD_CAP + 0.000001
	ok = ok and shoulder.origin.length() <= BodyMotionScript.SHOULDER_CAP + 0.000001

	for axis in 3:
		ok = ok and absf(head_turn[axis]) <= BodyMotionScript.HEAD_TURN_CAP + 0.000001
		ok = ok and absf(shoulder_turn[axis]) <= BodyMotionScript.SHOULDER_TURN_CAP + 0.000001

	return ok


## Crouching (or standing) in place: the gameplay eye eases toward `target`
## (its drop below standing) the way the controller eases it; the view's drop
## is the eye's minus the head's rise. How far the view trails the eye at
## worst, how far it passes the target, and how far off it still is from
## 0.6 s on.
func _stance(target: float, start := 0.0) -> Dictionary:
	var body := _body()
	var eye := start

	# Settle where it starts.
	for i in 60:
		var f := _frame(0.0, 0.0)
		f.eye_drop = start
		f.eye_target_drop = start
		body.step(TICK, f)

	var trail := 0.0
	var past := 0.0
	var after := 0.0
	var down := target > start

	for i in 90:
		eye += (target - eye) * (1.0 - exp(-12.0 / 60.0))
		var f := _frame(0.0, 0.0)
		f.eye_drop = eye
		f.eye_target_drop = target
		body.step(TICK, f)
		var view: float = eye - body.head_offset(1.0).origin.y

		if down:
			trail = maxf(trail, eye - view)
			past = maxf(past, view - target)
		else:
			trail = maxf(trail, view - eye)
			past = maxf(past, target - view)

		if i >= 36:
			after = maxf(after, absf(view - target))

	return {"trail": trail, "past": past, "after": after}


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
