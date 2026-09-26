extends Node3D
## Reproductions for the polish pass. Each check describes the CORRECT
## behaviour; before its fix, it fails.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const CLIMB := preload("res://scripts/PlayerUtils/ClimbVolume.gd")
const ROPE := preload("res://scripts/PlayerUtils/VerletRope.gd")

const RELAXED := 0
const SUSPICIOUS := 1
const INVESTIGATING := 2
const SEARCHING := 3
const COMBAT := 4


class Ear:
	var events: Array = []

	func hear_sound(event: Dictionary) -> void:
		events.append(event)


var player: CharacterBody3D
var baker: NavigationRegion3D
var results: Array[String] = []
var locked_door: Node3D
var rattles := 0


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(120, 1, 80))           # floor, top at 0

	# A: a wall with a LOCKED door, a patrol route through it.
	Props.block(self, Vector3(-43.0, 1.25, -5), Vector3(5.0, 2.5, 0.3))
	Props.block(self, Vector3(-37.0, 1.25, -5), Vector3(5.0, 2.5, 0.3))
	Props.block(self, Vector3(-40.0, 2.3, -5), Vector3(1.0, 0.4, 0.3))
	locked_door = Props.door(self, Vector3(-40.5, 0, -5), 0.0, 1.0, 2.1, true, &"vault", "vault door")
	locked_door.rattled.connect(func(): rattles += 1)

	# B: a 3 m roof block the guard cannot climb.
	Props.block(self, Vector3(20, 1.5, -20), Vector3(4, 3, 4))

	# C: a 1.2 m ledge for the mantle-into-a-guard check.
	Props.block(self, Vector3(40, 0.6, -20), Vector3(3, 1.2, 3))

	# D: a 1.5 m ledge for dropping things off.
	Props.block(self, Vector3(-20, 0.75, 20), Vector3(3, 1.5, 3))

	# E: a 3.6 m wall to hang from.
	Props.block(self, Vector3(40, 1.8, 20), Vector3(3, 3.6, 3))

	# F: stairs, 8 x 0.2 rise, 0.3 tread, climbing toward -Z from z = -8.
	for i in 8:
		var top := 0.2 * (i + 1)
		Props.block(self, Vector3(-52, top * 0.5, -8.0 - 0.3 * i - 0.15), Vector3(3, top, 0.3))
	Props.block(self, Vector3(-52, 0.8, -11.9), Vector3(3, 1.6, 2.0))

	# G: a 1 m corridor between two walls, and a frozen crate jammed in it.
	Props.block(self, Vector3(44.35, 1.5, 0), Vector3(0.3, 3, 8))
	Props.block(self, Vector3(45.65, 1.5, 0), Vector3(0.3, 3, 8))

	# H: a ladder up a 5 m wall.
	Props.block(self, Vector3(5, 2.5, -34.5), Vector3(3, 5, 3))
	var ladder := Area3D.new()
	ladder.set_script(CLIMB)
	var ladder_shape := CollisionShape3D.new()
	var ladder_box := BoxShape3D.new()
	ladder_box.size = Vector3(1.4, 5.0, 0.7)
	ladder_shape.shape = ladder_box
	ladder.add_child(ladder_shape)
	add_child(ladder)
	ladder.global_position = Vector3(5, 2.5, -32.65)

	# I: a simulated rope hanging from 7 m in open space.
	var rope := Area3D.new()
	rope.set_script(ROPE)
	rope.length = 6.0
	rope.name = "TestRope"
	add_child(rope)
	rope.global_position = Vector3(-10, 7.0, -32)

	# J: a plain wall to knock a guard out against.
	Props.block(self, Vector3(-30, 1.5, 0), Vector3(0.3, 3, 6))

	# K: an unlocked door in a wall, for things lying in its swing.
	Props.block(self, Vector3(-3.0, 1.25, 12), Vector3(5.0, 2.5, 0.3))
	Props.block(self, Vector3(3.0, 1.25, 12), Vector3(5.0, 2.5, 0.3))
	Props.block(self, Vector3(0.0, 2.3, 12), Vector3(1.0, 0.4, 0.3))

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
	player.global_position = Vector3(55, 1.05, 35)

	await baker.baked
	var jam := Props.crate(self, Vector3(45, 0.45, 0), 0.9, 40.0)
	jam.freeze = true
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# Q1 a patrol through a door he has no key for: he must not stand there
	# rattling it forever.
	var route := Node3D.new()
	add_child(route)
	for point in [Vector3(-40, 0, -1), Vector3(-40, 0, -9)]:
		var marker := Marker3D.new()
		route.add_child(marker)
		marker.global_position = point
	var walker := _new_guard(Vector3(-40, 0, -1), 0.0)
	walker.patrol_wait = 0.3
	walker.patrol_route = walker.get_path_to(route)
	walker._waypoints.assign(route.get_children())
	walker._go_to(route.get_child(1).global_position)
	await _frames(900)
	var gap: float = walker.global_position.distance_to(Vector3(-40, 0, -5))
	_check("Q1 locked door on a route: no endless rattling", rattles <= 2 and not locked_door.is_open,
		"rattles %d in 15 s, guard %.2f m from the door, door open %s" % [rattles, gap, locked_door.is_open])
	walker.queue_free()
	await _frames(3)

	# Q2 a guard who only GLIMPSES you investigates, searches, and stands down.
	var g2 := _new_guard(Vector3(0, 0, 0), 0.0)
	g2.look_around_time = 0.4
	g2.search_points = 1
	player.debug_light_level = 0.6
	_put_player(Vector3(0, 1.05, -20))
	await _until(func(): return g2.state == INVESTIGATING, 900)
	var investigated: bool = g2.state == INVESTIGATING
	player.debug_light_level = 0.0
	_put_player(Vector3(55, 1.05, 35))
	await _until(func(): return g2.state == RELAXED, 2400)
	_check("Q2 a glimpse is investigated and resolved", investigated and g2.state == RELAXED,
		"investigated %s final state %d alert %.1f" % [investigated, g2.state, g2.alert])
	g2.queue_free()
	await _frames(3)

	# Q3 a chase does not ask for a new path every frame.
	var g3 := _new_guard(Vector3(0, 0, 0), 0.0)
	player.debug_light_level = 1.0
	_put_player(Vector3(0, 1.05, -6))
	await _until(func(): return g3.state == COMBAT, 120)
	var before: int = g3.path_requests
	await _frames(60)
	var requests: int = g3.path_requests - before
	_check("Q3 chasing a player standing still: few path requests", g3.state == COMBAT and requests <= 6,
		"state %d path requests in 60 frames %d" % [g3.state, requests])
	g3.queue_free()
	await _frames(3)

	# Q4 a player on a roof he cannot climb: he looks up at you, and he
	# cannot hit you from the ground. A guard's view only reaches 45 degrees
	# above level, so under the roof edge he would honestly lose you; widen
	# it here so that it is the reach rule being tested.
	var g4 := _new_guard(Vector3(20, 0, -15), 0.0)
	g4.fov_vertical = 179.0
	player.debug_light_level = 1.0
	player.invulnerable = false
	player.health = player.max_health
	_put_player(Vector3(21.5, 4.05, -20))
	for i in 420:
		await _frames(1)
	var to_player := Vector3(player.global_position.x - g4.global_position.x, 0, player.global_position.z - g4.global_position.z).normalized()
	var facing: float = (-g4.global_transform.basis.z).dot(to_player)
	var still: bool = Vector3(g4.velocity.x, 0, g4.velocity.z).length() < 0.3
	_check("Q4 player out of reach on a roof: faced, never hit", player.health == player.max_health and facing > 0.9 and still,
		"health %.0f facing %.2f still %s guard at %s" % [player.health, facing, still, g4.global_position])
	player.invulnerable = true
	g4.queue_free()
	await _frames(3)

	# Q5 a vault is fast motion: guards should see it as moving, not standing still.
	_box_fence(Vector3(0, 0, 25))
	player.debug_light_level = 0.5
	_put_player(Vector3(0, 1.05, 31))
	await _frames(5)
	var still_exposure: float = player.get_exposure()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _until(func(): return player.global_position.z < 25.6, 240)
	await _tap("jump")
	var peak_exposure := 0.0
	for i in 30:
		await _frames(1)
		if player.movement_state == 1:
			peak_exposure = maxf(peak_exposure, player.get_exposure())
	_release_all()
	await _frames(20)
	_check("Q5 exposure counts movement during a vault", peak_exposure > still_exposure + 0.1,
		"still %.2f during the vault %.2f" % [still_exposure, peak_exposure])

	# Q6 mantling onto a ledge where a guard is standing: never end up inside him.
	var g6 := _new_guard(Vector3(40, 1.2, -19.1), PI)
	g6.debug_ai = false
	player.debug_light_level = 0.0
	_put_player(Vector3(40, 1.05, -17.3))
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(30)
	await _tap("jump")
	await _frames(90)
	_release_all()
	var flat_gap: float = Vector2(player.global_position.x - g6.global_position.x, player.global_position.z - g6.global_position.z).length()
	var overlapping: bool = flat_gap < 0.55 and absf((player.global_position.y - 1.0) - g6.global_position.y) < 1.5
	_check("Q6 no mantling into a guard", not overlapping, "flat gap %.2f player feet %.2f guard feet %.2f" % [flat_gap, player.global_position.y - 1.0, g6.global_position.y])
	g6.queue_free()
	await _frames(3)

	# Q7 hanging from a ledge, the hands are busy: no swinging, no picking things up.
	Props.give_blackjack(player)
	_put_player(Vector3(40, 1.05, 22.5))
	player.rotation.y = 0.0
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_press("jump")
	await _until(func(): return player.movement_state == 2, 120)
	_release_all()
	await _frames(5)
	await _tap("throw")
	await _frames(5)
	var swung: bool = player.frob._swing_cooldown > 0.0
	_check("Q7 no blackjack while hanging", player.movement_state == 2 and not swung, "state %d swung %s" % [player.movement_state, swung])
	await _tap("crouch")
	await _frames(60)

	# Q8 dead: no more frobbing or swinging, and guards stop fighting a corpse.
	var g8 := _new_guard(Vector3(-5, 0, 10), 0.0)
	player.debug_light_level = 1.0
	_put_player(Vector3(-5, 1.05, 8))
	await _until(func(): return g8.state == COMBAT, 120)
	player.invulnerable = false
	player.take_damage(1000.0, null)
	await _frames(3)
	await _tap("throw")
	await _frames(3)
	var dead_swung: bool = player.frob._swing_cooldown > 0.0
	await _frames(400)
	_check("Q8 the dead do nothing, and guards stand down", player.is_dead and not dead_swung and g8.state != COMBAT,
		"dead %s swung %s guard state %d" % [player.is_dead, dead_swung, g8.state])
	player.is_dead = false
	player.health = player.max_health
	player.invulnerable = true
	g8.queue_free()
	await _frames(3)

	# Q9 the light probe notices a new light at once, not two seconds later.
	var point := Vector3(-30, 0.3, -25)
	var lamp_a := _lamp(Vector3(-30, 2.5, -25))
	LightProbe.invalidate()
	await _frames(2)
	var lit_a: float = LightProbe.light_at(self, point)
	lamp_a.free()
	var lamp_b := _lamp(Vector3(-30, 2.5, -25))
	await _frames(2)
	var lit_b: float = LightProbe.light_at(self, point)
	_check("Q9 a replaced light is seen immediately", lit_a > 0.3 and lit_b > 0.3, "before %.2f after %.2f" % [lit_a, lit_b])
	lamp_b.queue_free()

	# Q10 the click that takes the mouse back must not also swing the blackjack.
	player.movement_state = 0
	_put_player(Vector3(0, 1.05, 40))
	await _frames(5)
	player.frob._swing_cooldown = 0.0
	player._recapture_mouse()
	Input.action_press("throw")
	await _frames(2)
	Input.action_release("throw")
	await _frames(2)
	var click_swung: bool = player.frob._swing_cooldown > 0.0
	_check("Q10 recapture click does not swing", not click_swung, "swung %s" % click_swung)

	# Q11 a crate set down gently is quiet; one dropped off a ledge is heard.
	var ear := Ear.new()
	SoundBus.add_listener(ear)
	var crate := Props.crate(self, Vector3(-20, 1.75, 20), 0.4, 3.0)
	_put_player(Vector3(-20, 2.55, 21.2))
	await _frames(30)
	_aim(crate.global_position)
	await _frames(3)
	await _tap("frob")
	await _frames(20)
	player.get_node("Neck").rotation.x = -0.6
	await _frames(10)
	ear.events.clear()
	await _tap("frob")
	await _frames(60)
	var gentle := _loudest(ear.events, &"impact")
	_aim(crate.global_position)
	await _frames(3)
	await _tap("frob")
	await _frames(20)
	player.rotation.y = PI
	player.get_node("Neck").rotation.x = 0.0
	await _frames(10)
	ear.events.clear()
	await _tap("frob")
	await _frames(90)
	var dropped := _loudest(ear.events, &"impact")
	SoundBus.remove_listener(ear)
	crate.queue_free()
	_check("Q11 dropping things off a ledge makes noise; setting down does not", gentle < 1.0 and dropped >= 40.0,
		"set down %.0f dB, dropped from the ledge %.0f dB (crate ended at y %.2f)" % [gentle, dropped, crate.global_position.y])

	await _review_findings()


# --------------------------------------------------------------------------
# From the three code reviews
# --------------------------------------------------------------------------
func _review_findings() -> void:
	player.debug_light_level = 0.0

	# Q12 jumping while walking up stairs actually jumps
	_put_player(Vector3(-52, 1.05, -6.0))
	Input.action_press("move_forward")
	await _until(func(): return player.global_position.z < -8.9, 240)
	await _tap("jump")
	var rise := 0.0
	for i in 6:
		await _frames(1)
		rise = maxf(rise, player.velocity.y)
	_release_all()
	await _frames(60)
	_check("Q12 jump on stairs", rise > 5.0, "peak upward speed %.1f" % rise)

	# Q13 you can stop halfway up a staircase
	_put_player(Vector3(-52, 1.05, -6.0))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _until(func(): return player.global_position.z < -8.9, 240)
	_release_all()
	var z_at_release: float = player.global_position.z
	await _frames(40)
	var slid: float = absf(player.global_position.z - z_at_release)
	var speed_after: float = Vector2(player.velocity.x, player.velocity.z).length()
	_check("Q13 stop on stairs", speed_after < 0.5 and slid < 1.0, "slid %.2f m after letting go, speed %.2f" % [slid, speed_after])

	# Q14 carrying a crate, you cannot climb down into a hang
	var box := Props.crate(self, Vector3(-19.5, 1.75, 19.0), 0.3, 1.0)
	_put_player(Vector3(-20, 2.55, 20.2))
	await _frames(20)
	_aim(box.global_position)
	await _frames(3)
	await _tap("frob")
	await _frames(10)
	var carrying: bool = player.frob.held == box
	# Stand at the ledge's +Z edge, facing out over the drop, looking down.
	player.global_position = Vector3(-20, 2.55, 21.2)
	player.rotation.y = PI
	player.get_node("Neck").rotation.x = -1.0
	await _frames(5)
	await _tap("crouch")
	await _frames(60)
	_check("Q14 no climbing down while carrying", carrying and player.movement_state == 0, "carrying %s state %d" % [carrying, player.movement_state])
	player.frob.drop_held()
	_release_all()
	await _frames(20)

	# Q15 vaulting a fence with a guard just beyond it: never end inside him
	Props.block(self, Vector3(20, 0.45, 8), Vector3(3, 0.9, 0.2))
	var g15 := _new_guard(Vector3(20, 0, 6.9), 0.0)
	g15.debug_ai = false
	_put_player(Vector3(20, 1.05, 14))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _until(func(): return player.global_position.z < 8.7, 240)
	await _tap("jump")
	await _frames(40)
	_release_all()
	var gap15: float = Vector2(player.global_position.x - g15.global_position.x, player.global_position.z - g15.global_position.z).length()
	_check("Q15 no vaulting into a guard", gap15 > 0.55, "flat gap %.2f" % gap15)
	g15.queue_free()
	await _frames(3)

	# Q16 dead in mid-air: the body still falls
	player.invulnerable = false
	_put_player(Vector3(50, 6.0, -30))
	await _frames(2)
	player.take_damage(1000.0, null)
	var y0: float = player.global_position.y
	await _frames(40)
	var fell: float = y0 - player.global_position.y
	_check("Q16 the dead fall", player.is_dead and fell > 2.0, "fell %.2f m" % fell)
	player.is_dead = false
	player.health = player.max_health
	player.invulnerable = true

	# Q17 carrying a crate while crouched, looking down: you can still stand up
	var low := Props.crate(self, Vector3(30, 0.2, 29), 0.4, 3.0)
	_put_player(Vector3(30, 1.05, 30.2))
	await _frames(20)
	Input.action_press("crouch")
	await _frames(10)
	_aim(low.global_position)
	await _frames(3)
	await _tap("frob")
	await _frames(10)
	player.get_node("Neck").rotation.x = -1.4
	await _frames(20)
	var hold_gap: float = Vector2(low.global_position.x - player.global_position.x, low.global_position.z - player.global_position.z).length()
	Input.action_release("crouch")
	await _frames(20)
	_check("Q17 stand up while carrying, crate kept clear of you", player.frob.held == low and not player.is_crouched and hold_gap > 0.6,
		"held %s crouched %s crate %.2f m from your axis" % [player.frob.held == low, player.is_crouched, hold_gap])
	player.frob.drop_held()
	_release_all()
	await _frames(10)

	# Q18 leaving a rope any way at all lets go of it
	var rope := get_node("TestRope")
	_put_player(Vector3(-10, 1.05, -29.5))
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 3, 240)
	var on_rope: bool = player.movement_state == 3
	_release_all()
	await _frames(20)
	_put_player(Vector3(55, 1.05, 35))
	await _frames(20)
	_check("Q18 a rope is let go of when you leave it", on_rope and rope._grip_param < 0.0, "was on %s grip %.2f" % [on_rope, rope._grip_param])

	# Q19 crouch-walking into a ladder: you climb standing
	_put_player(Vector3(5, 1.05, -29.0))
	Input.action_press("crouch")
	await _frames(10)
	Input.action_press("move_forward")
	await _until(func(): return player.movement_state == 3, 240)
	Input.action_release("crouch")
	await _frames(20)
	var climbed_crouched: bool = player.is_crouched
	_release_all()
	await _tap("jump")
	await _frames(90)
	_check("Q19 climbing is done standing", not climbed_crouched, "crouched on the ladder %s" % climbed_crouched)

	# Q20 a failed knockout tells him where YOU are, not where he is
	Props.give_blackjack(player)
	var g20 := _new_guard(Vector3(-20, 0, -25), 0.0)
	g20.state = INVESTIGATING
	g20.alert = 60.0
	g20._look_timer = 30.0
	g20._look_from_yaw = PI
	g20.rotation.y = PI
	player.debug_light_level = 0.0
	_put_player(Vector3(-20, 1.05, -23.6))
	await _frames(2)
	g20._look_timer = 30.0
	_aim(g20.global_position + Vector3.UP * 1.4)
	await _frames(2)
	await _tap("throw")
	await _frames(20)
	var remembered: Vector3 = g20.last_known_position
	_check("Q20 a failed knockout gives your position away", is_instance_valid(g20) and remembered.distance_to(player.global_position) < 1.0,
		"remembered %.2f m from you, %.2f m from himself" % [remembered.distance_to(player.global_position), remembered.distance_to(g20.global_position)])
	g20.queue_free()
	await _frames(3)

	# Q21 once knocked out, he says nothing more
	var g21 := _new_guard(Vector3(-25, 0, -25), 0.0)
	var after_barks := [0]
	_put_player(Vector3(-25, 1.05, -23.6))
	await _frames(5)
	_aim(g21.global_position + Vector3.UP * 1.4)
	await _frames(2)
	Input.action_press("throw")
	await _frames(1)
	Input.action_release("throw")
	await _until(func(): return g21._knocked_out if is_instance_valid(g21) else true, 60)
	if is_instance_valid(g21):
		g21.barked.connect(func(_t): after_barks[0] += 1)
	await _frames(5)
	_check("Q21 a downed guard is silent", after_barks[0] == 0, "barks after the knockout %d" % after_barks[0])
	for b in get_tree().get_nodes_in_group(&"bodies"):
		b.queue_free()
	await _frames(3)

	# Q22 finding a body while already searching starts the search again
	var g22 := _new_guard(Vector3(-35, 0, -25), 0.0)
	g22.state = SEARCHING
	g22._search_left = 1
	var fake := Node3D.new()
	add_child(fake)
	fake.global_position = Vector3(-35, 0, -28)
	g22._discover(fake)
	_check("Q22 a body found mid-search restarts it", g22._search_left == g22.search_points, "search points left %d of %d" % [g22._search_left, g22.search_points])
	g22.queue_free()
	fake.queue_free()
	await _frames(3)

	# Q23 a patrol begins at its first waypoint, not the second
	var r23 := Node3D.new()
	add_child(r23)
	for point in [Vector3(30, 0, 5), Vector3(35, 0, 15)]:
		var m := Marker3D.new()
		r23.add_child(m)
		m.global_position = point
	var g23: CharacterBody3D = GUARD.instantiate()
	g23.debug_ai = false
	g23.position = Vector3(30, 0, 12)
	g23.patrol_route = NodePath("../" + String(r23.name))
	add_child(g23)
	var nearest_first := INF
	for i in 300:
		await _frames(1)
		if g23._waypoint_index == 0:
			nearest_first = minf(nearest_first, Vector2(g23.global_position.x - 30, g23.global_position.z - 5).length())
	_check("Q23 patrol starts at waypoint 0", nearest_first < 1.2, "closest approach to waypoint 0 before moving on %.2f m" % nearest_first)
	g23.queue_free()
	await _frames(3)

	# Q24 in a fight, standing next to you, he stands
	var g24 := _new_guard(Vector3(10, 0, -12), 0.0)
	player.debug_light_level = 1.0
	_put_player(Vector3(10, 1.05, -13.2))
	await _until(func(): return g24.state == COMBAT, 120)
	var speed_sum := 0.0
	for i in 60:
		await _frames(1)
		speed_sum += Vector2(g24.velocity.x, g24.velocity.z).length()
	_check("Q24 no running on the spot beside you", speed_sum / 60.0 < 0.5, "average speed %.2f m/s" % (speed_sum / 60.0))
	g24.queue_free()
	player.debug_light_level = 0.0
	await _frames(3)

	# Q25 a corridor blocked by something the navmesh does not know about
	var r25 := Node3D.new()
	add_child(r25)
	for point in [Vector3(45, 0, 3.5), Vector3(45, 0, -3.5)]:
		var m := Marker3D.new()
		r25.add_child(m)
		m.global_position = point
	var g25: CharacterBody3D = GUARD.instantiate()
	g25.debug_ai = false
	g25.patrol_wait = 0.3
	g25.position = Vector3(45, 0, 3.5)
	g25.patrol_route = NodePath("../" + String(r25.name))
	add_child(g25)
	var turned_back := false
	for i in 480:
		await _frames(1)
		if g25._waypoint_index == 0 and i > 60:
			turned_back = true
	_check("Q25 a blocked corridor is given up on", turned_back, "waypoint %d at %s" % [g25._waypoint_index, g25.global_position])
	g25.queue_free()
	await _frames(3)

	# Q26 knocked out facing a wall: the body is not put inside it
	var g26 := _new_guard(Vector3(-29.3, 0, 0), -PI * 0.5)
	_put_player(Vector3(-27.9, 1.05, 0))
	var spawned := [null, true]
	# Checked the instant it appears, before physics can shove it anywhere.
	g26.knocked_out.connect(func(b): spawned[0] = b; spawned[1] = _overlaps_world(b))
	await _frames(5)
	_aim(g26.global_position + Vector3.UP * 1.4)
	await _frames(2)
	await _tap("throw")
	await _frames(30)
	var body26: Node3D = spawned[0]
	_check("Q26 a body never spawns inside a wall or the player", body26 != null and not spawned[1],
		"body at %s overlapping at spawn %s" % [body26.global_position if body26 else Vector3.ZERO, spawned[1]])

	# Q28 facing a wall, a shouldered body is put down clear of it and of you
	_aim(body26.global_position)
	await _frames(4)
	await _tap("frob")
	await _frames(10)
	var shouldered_ok: bool = player.frob.is_shouldering()
	player.global_position = Vector3(-29.0, 1.05, 0)
	player.rotation.y = PI * 0.5
	player.get_node("Neck").rotation.x = 0.0
	await _frames(5)
	player.frob.put_down_body()
	var in_wall_28 := _overlaps_world(body26)
	await _frames(30)
	_check("Q28 a body put down at a wall is clear of it and you", shouldered_ok and not in_wall_28,
		"was shouldering %s overlapping %s at %s" % [shouldered_ok, in_wall_28, body26.global_position])

	# Q29 while shouldered, the body is not an invisible obstacle where it lay
	_aim(body26.global_position)
	await _frames(4)
	await _tap("frob")
	await _frames(5)
	var was_at: Vector3 = body26.global_position
	player.global_position = Vector3(-26, 1.05, 3)
	await _frames(5)
	var probe := Props.crate(self, was_at + Vector3.UP * 1.5, 0.3, 1.0)
	await _frames(90)
	_check("Q29 a shouldered body is not solid where it lay", probe.global_position.y < 0.3, "a crate dropped on the spot came to rest at y %.2f" % probe.global_position.y)
	player.frob.drop_held()
	await _frames(10)

	# Q27 a key lying in a door's swing does not jam it
	var door := Props.door(self, Vector3(-0.5, 0, 12))
	Props.key(self, Vector3(0.3, 0.05, 11.4), &"spare", "spare key")
	_put_player(Vector3(0, 1.05, 14.0))
	await _frames(20)
	_aim(door.to_global(Vector3(0.5, 1.05, 0.0)))
	await _frames(3)
	await _tap("frob")
	await _frames(80)
	var angle27: float = absf(wrapf(door.rotation.y, -PI, PI))
	_check("Q27 a key on the floor does not jam a door", angle27 > 1.2, "door angle %.2f rad" % angle27)

	# Q30 chests report being opened
	var chest := Props.chest(self, Vector3(-40, 0, 25))
	var opened := [false]
	chest.opened.connect(func(): opened[0] = true)
	_put_player(Vector3(-40, 1.05, 26.4))
	await _frames(10)
	_aim(Vector3(-40, 0.56, 24.8))
	await _frames(3)
	await _tap("frob")
	await _frames(60)
	_check("Q30 a chest's opened signal fires", chest.is_open and opened[0], "open %s signalled %s" % [chest.is_open, opened[0]])


func _overlaps_world(node: Node3D) -> bool:
	if node == null:
		return true

	# A man gone limp is his limbs (Ragdoll.gd): none may start in a wall.
	if node.has_method("ragdoll") and node.ragdoll() != null:
		for part in node.ragdoll().bodies():
			for c in (part as Node).get_children():
				if c is CollisionShape3D:
					var limb_query := PhysicsShapeQueryParameters3D.new()
					limb_query.shape = (c as CollisionShape3D).shape
					limb_query.transform = (c as CollisionShape3D).global_transform
					limb_query.collision_mask = 1
					limb_query.margin = -0.03

					if not get_world_3d().direct_space_state.intersect_shape(limb_query, 1).is_empty():
						return true

		return false

	var shape_node: CollisionShape3D = null
	for c in node.get_children():
		if c is CollisionShape3D:
			shape_node = c
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	# The world, and the player too: a body inside you is as bad as one in a wall.
	query.collision_mask = 1
	query.exclude = [node.get_rid()]
	query.margin = -0.03
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# --------------------------------------------------------------------------
func _box_fence(at: Vector3) -> void:
	Props.block(self, at + Vector3(0, 0.45, 0), Vector3(3, 0.9, 0.2))


func _lamp(at: Vector3) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.omni_range = 8.0
	lamp.light_energy = 2.0
	add_child(lamp)
	lamp.global_position = at
	return lamp


func _new_guard(at: Vector3, yaw: float) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	return g


func _loudest(events: Array, kind: StringName) -> float:
	var best := 0.0
	for event in events:
		if event["kind"] == kind:
			best = maxf(best, event["db"])
	return best


func _put_player(at: Vector3) -> void:
	player.movement_state = 0
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


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
