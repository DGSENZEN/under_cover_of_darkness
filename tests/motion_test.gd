extends Node3D
## Locomotion feel: the body under the camera (BodyMotion.gd), momentum at
## today's speeds, and the old feel kept behind F10 until it is signed off.
## The model checks feed a lone body frames at 60 ticks a second, the way the
## controller does; the rest drive the player.

const BodyMotionScript := preload("res://scripts/PlayerUtils/BodyMotion.gd")
const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")

const TICK := 1.0 / 60.0

var results: Array[String] = []
var player: CharacterBody3D


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	# A 3 m drop, for landings.
	Props.block(self, Vector3(-40, 1.5, 0), Vector3(6, 3, 6))
	# A long wall (its face at x = 80), for sliding along.
	Props.block(self, Vector3(80.5, 1.5, 0), Vector3(1, 3, 180))

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	_model_checks()
	await _momentum_checks()
	await _camera_checks()
	await _hand_checks()
	await _switch_checks()


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
	# (Nor may it race ahead: a crouch is the knees bending, not a faster
	# crouch. At most 6 cm ahead of the eye on the way.)
	_check("Y15 crouch and stand never trail the eye nor race it (6 cm), pass the target by 0.2-2 cm, settle within 0.6 s",
		kneel.trail <= 0.002 and kneel.lead <= 0.06 and kneel.past >= 0.002 and kneel.past <= 0.02 and kneel.after <= 0.0025
		and rise.trail <= 0.002 and rise.lead <= 0.06 and rise.past >= 0.002 and rise.past <= 0.02 and rise.after <= 0.0025,
		"down: trails %.4f leads %.3f past %.4f after 0.6 s %.4f; up: trails %.4f leads %.3f past %.4f after %.4f" % [kneel.trail, kneel.lead, kneel.past, kneel.after, rise.trail, rise.lead, rise.past, rise.after])

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

	# Y15r back into plain locomotion while the eye is still easing (dropping
	#      from a peeking hang): the view goes with the eye, never floating
	#      above it nor racing it
	var drop_off := _body()
	var raised := -0.4
	var floating := 0.0
	var racing := 0.0

	for i in 60:
		raised += (0.0 - raised) * (1.0 - exp(-12.0 / 60.0))
		var f := _frame(0.0, 0.0)
		f.locomotion = i >= 5
		f.eye_drop = raised
		f.eye_target_drop = 0.0
		drop_off.step(TICK, f)

		if i >= 5:
			var view: float = raised - drop_off.head_offset(1.0).origin.y
			floating = maxf(floating, raised - view)
			racing = maxf(racing, view - raised)

	_check("Y15r back into locomotion with the eye still easing, the view never floats above it (2 mm) nor races it (6 cm)",
		floating <= 0.002 and racing <= 0.06,
		"floats %.4f m, races %.4f m" % [floating, racing])

	# Y4b a flick of the view mid-sprint: the lean into the run swings round
	#     with it instead of jumping (no more than 3 mm a tick beyond what a
	#     sprint step moves the head anyway)
	var flicker := _body()
	var flick_gait := 0.0
	var flick_last := Vector3.ZERO
	var calm := 0.0
	var flicked := 0.0

	for i in 150:
		flick_gait = fposmod(flick_gait + 8.5 / 2.4 * TICK, 2.0)
		var f := _frame(8.5, flick_gait)
		f.facing = Basis(Vector3.UP, clampf((i - 120) / 2.0, 0.0, 1.0) * PI * 0.5)
		flicker.step(TICK, f)
		var at: Vector3 = flicker.head_offset(1.0).origin

		if i > 90 and i < 120:
			calm = maxf(calm, at.distance_to(flick_last))
		elif i >= 120:
			flicked = maxf(flicked, at.distance_to(flick_last))

		flick_last = at

	_check("Y4b a 90 deg flick mid-sprint swings the lean round, no jump", flicked <= calm + 0.003,
		"most a tick: sprinting %.4f m, flicking %.4f m" % [calm, flicked])


# --------------------------------------------------------------------------
# Momentum: the same speeds, with weight
# --------------------------------------------------------------------------

func _momentum_checks() -> void:
	# Y7 a press answers at once and builds to walking pace; a sprint gathers
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(20)
	Input.action_press("move_forward")
	await _frames(1)
	var first := _speed()
	await _frames(5)
	var sixth := _speed()
	await _frames(18)
	var walking := _speed()
	await _frames(36)
	Input.action_press("sprint")
	var build := 0

	while _speed() < 8.4 and build < 120:
		await _frames(1)
		build += 1

	_release()
	_check("Y7 a start answers on the first tick, is past half pace in 0.1 s and at pace by 0.4 s; a sprint gathers over 0.35-0.7 s",
		first > 0.0 and sixth >= 3.25 and walking >= 6.175 and build >= 21 and build <= 42,
		"tick 1 %.2f, tick 6 %.2f, tick 24 %.2f m/s; sprint reached 8.4 in %d ticks" % [first, sixth, walking, build])

	# Y8 stops stay planted: no sliding, from a walk or a sprint; and letting
	#    go of sprint eases back to walking pace instead of braking
	var walk_stop: Array = await _stop_from(false)
	var run_stop: Array = await _stop_from(true)
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(90)
	Input.action_release("sprint")
	var worst_drop := 0.0
	var eased := -1
	var last := _speed()

	for i in 40:
		await _frames(1)
		worst_drop = maxf(worst_drop, last - _speed())
		last = _speed()

		if eased < 0 and last <= 6.6:
			eased = i + 1

	_release()
	_check("Y8 a stop takes at most 0.2 s and 0.6 m from a walk, 0.3 s and 1.3 m from a sprint",
		walk_stop[0] <= 12 and walk_stop[1] <= 0.6 and run_stop[0] <= 18 and run_stop[1] <= 1.3,
		"walk %d ticks %.2f m; sprint %d ticks %.2f m" % [walk_stop[0], walk_stop[1], run_stop[0], run_stop[1]])
	_check("Y8b letting go of sprint eases back to walking pace (at most 0.35 m/s a tick, there within 30 ticks)",
		worst_drop <= 0.35 and eased > 0 and eased <= 30,
		"worst drop %.3f m/s a tick, at 6.6 after %d ticks" % [worst_drop, eased])

	# Y9 turning: a reversal is a stop and a start; at a sprint the old
	#    direction goes more slowly than at a walk (a carve), a walking turn
	#    is no slower than today's, and every turn finishes (no ice)
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(60)
	Input.action_release("move_forward")
	Input.action_press("move_back")
	var reversed := 0

	while player.velocity.z < 5.85 and reversed < 90:
		await _frames(1)
		reversed += 1

	_release()
	var walk_turn: Array = await _turn_from(false)
	var run_turn: Array = await _turn_from(true)
	_check("Y9 a reversal takes at most 0.45 s; a sprint turn sheds its old heading at most 0.8x as fast as a walking one, which is no slower than today's; both finish",
		reversed <= 27 and run_turn[0] <= 0.8 * walk_turn[0] and walk_turn[0] >= 31.0 and walk_turn[1] <= 27 and run_turn[1] <= 27,
		"reversal %d ticks; old heading shed at %.1f m/s2 walking (gone in %d ticks), %.1f sprinting (gone in %d)" % [reversed, walk_turn[0], walk_turn[1], run_turn[0], run_turn[1]])

	# Y10 the jump is untouched: it leaves when it always did and rises as high
	var legacy_rise: Array = await _jump_rise(true)
	var rise: Array = await _jump_rise(false)
	_check("Y10 a jump leaves the ground on the same tick as before and rises as high as before",
		rise[0] == legacy_rise[0] and rise[0] <= 2 and absf(rise[1] - legacy_rise[1]) <= 0.005 and rise[1] > 1.3,
		"left after %d ticks (old %d), rose %.3f m (old %.3f)" % [rise[0], legacy_rise[0], rise[1], legacy_rise[1]])

	# Y11b landing does not slow you: the weight is in the body, not the legs'
	#    say over speed
	_place(Vector3(0, 1.05, 30), 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(60)
	Input.action_press("jump")
	await _frames(4)
	Input.action_release("jump")
	await _until(func(): return not player.is_on_floor(), 20)
	var before_landing := _speed()

	for i in 90:
		if player.is_on_floor():
			break

		before_landing = _speed()
		await _frames(1)

	await _frames(5)
	var after_landing := _speed()
	_release()
	_check("Y11b touching down after a jump does not cost speed", after_landing >= before_landing - 0.1,
		"%.2f m/s before landing, %.2f five ticks after" % [before_landing, after_landing])

	# The old feel is still there, as it was.
	player.set("legacy_feel", true)
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(20)
	Input.action_press("move_forward")
	await _frames(6)
	var old_sixth := _speed()
	await _frames(3)
	var old_ninth := _speed()
	_release()
	player.set("legacy_feel", false)
	_check("Y7b the old feel still starts in a straight line to pace in 0.15 s", absf(old_sixth - 4.5) <= 0.05 and absf(old_ninth - 6.5) <= 0.01,
		"tick 6 %.2f, tick 9 %.2f m/s" % [old_sixth, old_ninth])

	# Y20 walls are not sticky: leaning into a wall as you go, you slide along
	#    it as fast as you did on the old feel (and never faster than the pace)
	var slow := []
	var slides := []

	for gait in ["walk", "sprint", "crouch"]:
		for degrees in [30.0, 45.0]:
			var old_slide: float = await _wall_slide(true, degrees, gait)
			var new_slide: float = await _wall_slide(false, degrees, gait)
			slides.append("%s %d: %.2f -> %.2f" % [gait, int(degrees), old_slide, new_slide])

			if new_slide < 0.95 * old_slide:
				slow.append("%s %d" % [gait, int(degrees)])

	var shallow: float = await _wall_slide(false, 10.0, "walk")
	_check("Y20 sliding along a wall is as quick as on the old feel (95%+), and a shallow slide is no faster than the pace",
		slow.is_empty() and shallow <= player.walk_speed + 0.02,
		"old -> new m/s: %s; walk 10 deg %.2f; too slow: %s" % [", ".join(slides), shallow, slow])


# --------------------------------------------------------------------------
# The body carries the camera
# --------------------------------------------------------------------------

## Calls `read` after every node has done its _process this frame (the
## smooth suite's recorder): what is drawn.
class Recorder:
	extends Node

	var read: Callable
	var seen: Array = []

	func _process(_delta: float) -> void:
		seen.append(read.call())


func _camera_checks() -> void:
	var body: RefCounted = player.get("body_motion")

	# Y2i the real walk: every footstep lands as the head goes down
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	var walked := []
	var last_steps: int = player._steps

	for i in 180:
		await _frames(1)
		var y: float = body.head_offset(1.0).origin.y if body != null else 0.0
		walked.append({"head": Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.0)), "step": player._steps != last_steps})
		last_steps = player._steps

	_release()
	var real_misses := _footfall_misses(walked)
	var real_steps := _count_steps(walked, 60)
	_check("Y2i walking for real, every footstep lands as the head goes down", body != null and real_misses == 0 and real_steps >= 5,
		"body %s; %d of %d steps off the beat" % [body != null, real_misses, real_steps])

	# Y3i the view: about a centimetre of walk, no sprint widening; the old
	#    feel's bob and FOV are still there behind the switch
	var new_walk := await _view_span(false)
	var old_walk := await _view_span(true)
	var new_fov := await _sprint_fov(false)
	var old_fov := await _sprint_fov(true)
	var base_fov: float = player.juice.base_fov
	_check("Y3i walking moves the view at most 2 cm (old: 5+), sprinting leaves the FOV alone (old: +6)",
		new_walk <= 0.02 and old_walk >= 0.05 and absf(new_fov - base_fov) <= 0.01 and absf(old_fov - base_fov - 6.0) <= 0.3,
		"view up and down %.4f m (old %.4f); sprint FOV %.2f (old %.2f, base %.2f)" % [new_walk, old_walk, new_fov, old_fov, base_fov])

	# Y14 at 30 ticks a second against 60 frames, the head is drawn between
	#    ticks: every frame shows it somewhere new
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(40)
	Engine.physics_ticks_per_second = 30
	await _frames(4)
	var recorder := Recorder.new()
	recorder.process_priority = 1000
	recorder.read = func():
		return body.head_offset(Engine.get_physics_interpolation_fraction()).origin if body != null else Vector3.ZERO
	add_child(recorder)

	for i in 24:
		await get_tree().process_frame

	recorder.queue_free()
	Engine.physics_ticks_per_second = 60
	_release()
	var frozen := 0

	for i in range(1, recorder.seen.size()):
		if (recorder.seen[i] as Vector3).distance_to(recorder.seen[i - 1]) <= 0.000001:
			frozen += 1

	_check("Y14i at two frames a tick the head moves every frame", body != null and frozen == 0 and recorder.seen.size() >= 20,
		"%d of %d frames repeated the one before" % [frozen, recorder.seen.size() - 1])

	# Y17 gameplay never sees the body: aim and sight are the same on either
	#    feel, standing, crouched and leaning
	var differ := []

	for state in [[false, false], [true, false], [false, true]]:
		var old_view: Array = await _gameplay_view(true, state[0], state[1])
		var new_view: Array = await _gameplay_view(false, state[0], state[1])

		if not _same_view(old_view, new_view):
			differ.append(state)

	_check("Y17 aim and sight points are the same on the old and new feel", differ.is_empty(),
		"differing states [crouched, leaning] %s" % [differ])

	# Y15i a real crouch and stand: the view never races the gameplay eye (the
	#    body's knee bend runs in step with the eye's own ease)
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(20)
	var ahead := 0.0
	Input.action_press("crouch")

	for i in 50:
		await _frames(1)
		ahead = maxf(ahead, absf(player.juice.view_position.y))

	Input.action_release("crouch")

	for i in 50:
		await _frames(1)
		ahead = maxf(ahead, absf(player.juice.view_position.y))

	_check("Y15i crouching and standing for real, the view stays within 6 cm of the gameplay eye", ahead <= 0.06,
		"most %.3f m" % ahead)

	# Y19 a teleport, a shove in a hit-stop, and the dial at 2 with a fall that
	#    would break bones: never past the caps, and a teleport is not a jolt
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(60)
	player.global_position += Vector3(20, 0, 0)
	player.velocity = Vector3.ZERO
	var jolt := 0.0

	for i in 30:
		await _frames(1)
		jolt = maxf(jolt, body.head_offset(1.0).origin.length() if body != null else 1.0)

	_release()
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(20)
	Engine.time_scale = 0.05
	player.shove(Vector3(8, 0, 0), 0.3)
	var held := true

	for i in 30:
		await _frames(1)
		held = held and body != null and _inside_caps(body)

	Engine.time_scale = 1.0
	await _frames(30)
	player.camera_feel = 2.0
	await _frames(5)

	if body != null:
		body.on_land(40.0)

	var peak := 0.0

	for i in 45:
		await _frames(1)
		held = held and body != null and _inside_caps(body)
		peak = maxf(peak, body.head_offset(1.0).origin.length() if body != null else 0.0)

	player.camera_feel = 1.0
	_check("Y19 a teleport is no jolt (2 cm at most); a hit-stop shove and a doubled dial stay inside the caps, which hold",
		body != null and jolt <= 0.02 and held and peak >= BodyMotionScript.HEAD_CAP - 0.01,
		"after the teleport %.4f m; inside caps %s; doubled landing peak %.3f m" % [jolt, held, peak])


# --------------------------------------------------------------------------
# The hands ride the body
# --------------------------------------------------------------------------

func _hand_checks() -> void:
	var body: RefCounted = player.get("body_motion")
	var hand: Node = player.hand
	Props.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	_place(Vector3(30, 1.05, 60), 0.0)
	await _frames(40)

	# Y12i the hands show the shoulders: a landing drops the sword with them
	var recorder := Recorder.new()
	recorder.process_priority = 1000
	recorder.read = func():
		return [hand._main.position.y, body.shoulder_offset(Engine.get_physics_interpolation_fraction()).origin.y]
	add_child(recorder)

	# (process_frame comes before the frame's _process: two, to have one.)
	for i in 2:
		await get_tree().process_frame

	var rest: float = recorder.seen[-1][0]
	body.on_land(13.9)

	for i in 40:
		await get_tree().process_frame

	recorder.queue_free()
	var hand_low := 0
	var shoulder_low := 0

	for i in recorder.seen.size():
		if recorder.seen[i][0] < recorder.seen[hand_low][0]:
			hand_low = i

		if recorder.seen[i][1] < recorder.seen[shoulder_low][1]:
			shoulder_low = i

	var hand_dip: float = rest - recorder.seen[hand_low][0]
	# The hands live in the view's miniature (ViewArms, 0.62 about the eye):
	# the same angle of motion is 0.62 of the distance there.
	var shoulder_dip: float = -recorder.seen[shoulder_low][1] * ViewArmsScript.SCALE

	# A real landing: the old hop is the old feel's; the body is the new's.
	var hop_new: float = await _landing_hop(false)
	var hop_old: float = await _landing_hop(true)
	_check("Y12i a landing drops the sword with the shoulders; the old hop is only on the old feel",
		shoulder_dip > 0.005 and hand_dip >= 0.8 * shoulder_dip and hand_dip <= 1.25 * shoulder_dip and absi(hand_low - shoulder_low) <= 2
		and absf(hop_new) < 0.0001 and hop_old < -0.005,
		"sword dips %.4f at frame %d, shoulders (in the view's miniature) %.4f at %d; hop new %.4f old %.4f" % [hand_dip, hand_low, shoulder_dip, shoulder_low, hop_new, hop_old])


# --------------------------------------------------------------------------
# F10: the old feel and the new, side by side
# --------------------------------------------------------------------------

func _switch_checks() -> void:
	var hud: Node = player.hud
	_place(Vector3(40, 1.05, 60), 0.0)
	await _frames(10)

	# Y18 F10 flips to the old feel and back, and says so
	_press_f10()
	await get_tree().process_frame
	await get_tree().process_frame
	var old_on: bool = bool(player.get("legacy_feel"))
	var old_caption: String = hud._caption.text
	var old_tag: bool = hud.legacy_tag_visible() if hud.has_method("legacy_tag_visible") else false
	var old_steps: Array = await _walk_steps()
	_press_f10()
	await get_tree().process_frame
	await get_tree().process_frame
	var new_on: bool = bool(player.get("legacy_feel"))
	var new_caption: String = hud._caption.text
	var new_tag: bool = hud.legacy_tag_visible() if hud.has_method("legacy_tag_visible") else true
	var new_steps: Array = await _walk_steps()
	var old_stride: float = old_steps[1] / maxf(old_steps[0], 1.0)
	var new_stride: float = new_steps[1] / maxf(new_steps[0], 1.0)
	_check("Y18 F10 switches to the old feel (its strides, a caption, a corner tag) and back",
		old_on and old_caption == "Movement: old" and old_tag and not new_on and new_caption == "Movement: new" and not new_tag
		and absf(old_steps[1] / 1.6 - old_steps[0]) <= 1.0 and absf(new_steps[1] / 2.0 - new_steps[0]) <= 1.0,
		"old: on %s caption '%s' tag %s stride %.2f; new: on %s caption '%s' tag %s stride %.2f" % [old_on, old_caption, old_tag, old_stride, new_on, new_caption, new_tag, new_stride])


func _press_f10() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_F10
	key.physical_keycode = KEY_F10
	key.pressed = true
	player._unhandled_input(key)


## Walk two seconds: [footsteps taken, distance walked].
func _walk_steps() -> Array:
	_place(Vector3(40, 1.05, 60), 0.0)
	await _frames(10)
	var from := player.global_position
	var steps := 0
	var last: int = player._steps
	Input.action_press("move_forward")

	for i in 120:
		await _frames(1)

		if player._steps != last:
			steps += 1
			last = player._steps

	_release()
	var walked := from.distance_to(player.global_position)
	await _frames(20)
	return [steps, walked]


## A standing jump and its landing: how far the hands' old hop went.
func _landing_hop(legacy: bool) -> float:
	player.set("legacy_feel", legacy)
	_place(Vector3(30, 1.05, 60), 0.0)
	await _frames(20)
	Input.action_press("jump")
	var lowest := 0.0

	for i in 70:
		await _frames(1)
		lowest = minf(lowest, player.hand._hop)

	Input.action_release("jump")
	await _frames(20)
	player.set("legacy_feel", false)
	return lowest


## Walk steadily a second, then the view's height span over the next second.
func _view_span(legacy: bool) -> float:
	player.set("legacy_feel", legacy)
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(60)
	var low := INF
	var high := -INF

	for i in 60:
		await _frames(1)
		low = minf(low, player.juice.view_position.y)
		high = maxf(high, player.juice.view_position.y)

	_release()
	player.set("legacy_feel", false)
	return high - low


func _sprint_fov(legacy: bool) -> float:
	player.set("legacy_feel", legacy)
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(10)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(90)
	var fov: float = player.camera.fov
	_release()
	await _frames(40)
	player.set("legacy_feel", false)
	return fov


## Standing (or crouched, or leaning right), settled: the aim and the sight
## points, in the body's own space.
func _gameplay_view(legacy: bool, crouched: bool, leaning: bool) -> Array:
	player.set("legacy_feel", legacy)
	_place(Vector3(10, 1.05, 60), 0.0)
	await _frames(10)

	if crouched:
		Input.action_press("crouch")

	if leaning:
		Input.action_press("lean_right")

	await _frames(60)
	var to_body := player.global_transform.affine_inverse()
	var aim: Transform3D = to_body * player.aim_transform()
	var sights: Array = player.get_sight_points().map(func(p): return to_body * p)
	_release()
	await _frames(40)
	player.set("legacy_feel", false)
	return [aim, sights]


func _same_view(a: Array, b: Array) -> bool:
	var aim_a: Transform3D = a[0]
	var aim_b: Transform3D = b[0]

	if aim_a.origin.distance_to(aim_b.origin) > 0.00001:
		return false

	for axis in 3:
		if aim_a.basis[axis].distance_to(aim_b.basis[axis]) > 0.00001:
			return false

	for i in (a[1] as Array).size():
		if (a[1][i] as Vector3).distance_to(b[1][i]) > 0.00001:
			return false

	return true


## Hold forward (sprinting, walking or crouched) with the view turned
## `degrees` into the long wall on the right: the speed the slide settles at.
func _wall_slide(legacy: bool, degrees: float, gait: String) -> float:
	player.set("legacy_feel", legacy)
	_place(Vector3(78.5, 1.05, 60), -deg_to_rad(degrees))
	await _frames(10)

	if gait == "crouch":
		Input.action_press("crouch")
		await _frames(20)

	Input.action_press("move_forward")

	if gait == "sprint":
		Input.action_press("sprint")

	await _frames(70)
	var total := 0.0

	for i in 20:
		await _frames(1)
		total += _speed()

	_release()
	await _frames(20)
	player.set("legacy_feel", false)
	return total / 20.0


## Walk (or sprint) steadily, let go: [ticks to a standstill, distance].
func _stop_from(sprinting: bool) -> Array:
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(10)
	Input.action_press("move_forward")

	if sprinting:
		Input.action_press("sprint")

	await _frames(90)
	var from := player.global_position
	_release()
	var ticks := 0

	while _speed() >= 0.05 and ticks < 60:
		await _frames(1)
		ticks += 1

	var gone := from.distance_to(player.global_position)
	return [ticks, gone]


## Walk (or sprint) steadily ahead, then turn hard to the right: [how fast
## the old heading's speed goes over the first three ticks (m/s²), ticks until
## it is under 0.5 m/s].
func _turn_from(sprinting: bool) -> Array:
	_place(Vector3(0, 1.05, 60), 0.0)
	await _frames(10)
	Input.action_press("move_forward")

	if sprinting:
		Input.action_press("sprint")

	await _frames(90)
	var ahead := -player.velocity.z
	Input.action_release("move_forward")
	Input.action_press("move_right")
	await _frames(3)
	var shed := (ahead - (-player.velocity.z)) / (3.0 * TICK)
	var ticks := 3

	while -player.velocity.z >= 0.5 and ticks < 90:
		await _frames(1)
		ticks += 1

	_release()
	return [shed, ticks]


## Standing, a full jump (held past the top, so the jump cut never comes):
## [ticks until the feet leave the ground, how high they rise].
func _jump_rise(legacy: bool) -> Array:
	player.set("legacy_feel", legacy)
	_place(Vector3(20, 1.05, 60), 0.0)
	await _frames(20)
	var start: float = player.get_feet_position().y
	Input.action_press("jump")
	var left := 0

	while player.get_feet_position().y <= start + 0.001 and left < 10:
		await _frames(1)
		left += 1

	var top := start

	for i in 60:
		top = maxf(top, player.get_feet_position().y)
		await _frames(1)

	Input.action_release("jump")
	await _frames(30)
	player.set("legacy_feel", false)
	return [left, top - start]


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

func _place(at: Vector3, yaw: float) -> void:
	_release()
	player.movement_state = 0
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = yaw
	player.neck.rotation.x = 0.0
	player.reset_physics_interpolation()


func _release() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint", "crouch", "jump", "lean_left", "lean_right"]:
		Input.action_release(a)


func _speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame


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
	var lead := 0.0
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
			lead = maxf(lead, view - eye)
			past = maxf(past, view - target)
		else:
			trail = maxf(trail, view - eye)
			lead = maxf(lead, eye - view)
			past = maxf(past, target - view)

		if i >= 36:
			after = maxf(after, absf(view - target))

	return {"trail": trail, "lead": lead, "past": past, "after": after}


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
