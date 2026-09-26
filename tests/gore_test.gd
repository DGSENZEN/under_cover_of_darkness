extends Node3D
## Wounds and what is left: deep cuts bleed (a trail of drops, health seeping
## away, never all of it) until a man who has lost you binds them; a corpse
## can be hacked apart; a blast tears men apart; a man cut apart shakes those
## who see it; a kill up close throws blood across your eyes; a part cut off
## bleeds where it lies.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const GuardBodyScript := preload("res://scripts/AISystem/GuardBody.gd")
const SeveredPartScript := preload("res://scripts/Visual/SeveredPart.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")

var player: CharacterBody3D
var combat: Node
var results: Array[String] = []


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(160, 1, 160))

	var baker := NavigationRegion3D.new()
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

	player.debug_light_level = 1.0
	player.global_position = Vector3(0, 1.05, 60)
	Props.give_weapons(player, 12)
	combat = player.combat
	player.inventory.select_by_id(&"sword")

	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# W1 a deep cut bleeds: health seeps away after it, and drops fall
	var g1 := _guard(&"swordsman", Vector3(0, 0, -2.0))
	await _frames(10)
	var stains_before := Fx.stains_in_use()
	g1.take_hit(30.0, player, &"power", g1._rig.chest(), Vector3.FORWARD)
	var after_blow: float = g1.health
	await _frames(120)
	var seeped: float = after_blow - g1.health
	_check("W1 a deep cut bleeds: his health seeps away and drops fall", g1.bleeding > 0.3 and seeped > 1.0 and Fx.stains_in_use() > stains_before,
		"bleeding %.2f/s, lost %.1f more over 2 s, stains %d -> %d" % [g1.bleeding, seeped, stains_before, Fx.stains_in_use()])

	# W2 bleeding alone never takes the last of him
	g1.health = g1.max_health * 0.14
	g1.bleeding = 4.0
	await _frames(120)
	_check("W2 bleeding alone never takes the last of him", g1.health >= g1.max_health * g1.BLEED_FLOOR - 0.01 and g1.health > 0.0,
		"health %.1f (floor %.1f)" % [g1.health, g1.max_health * g1.BLEED_FLOOR])
	g1.queue_free()
	await _frames(10)

	# W3 once he has lost you, he binds his wounds
	var g3 := _guard(&"swordsman", Vector3(40, 0, 40))
	await _frames(10)
	g3.take_hit(25.0, player, &"power", g3._rig.chest(), Vector3.FORWARD)
	var bound := [false]
	g3.bound_wounds.connect(func(): bound[0] = true)
	# Gone: far off and out of his sight.
	_put_player(Vector3(-60, 1.05, -60))
	await _until(func(): return bound[0], 900)
	_check("W3 once he has lost you he binds his wounds", bound[0] and g3.bleeding == 0.0 and g3.state != 4,
		"bound %s bleeding %.2f state %d" % [bound[0], g3.bleeding, g3.state])
	g3.queue_free()
	await _frames(10)

	# W4 a corpse can be hacked apart
	var g4 := _guard(&"swordsman", Vector3(10, 0, 0))
	await _frames(10)
	g4.die(null)
	await _frames(90)
	var corpse := _last_body()
	var man: Node3D = corpse.man() if corpse != null else null
	var parts_before := _parts()
	var arm: Vector3 = Vector3.ZERO
	var limb: StringName = &""

	if man != null:
		# Where physics has his arm.
		var skeleton: Skeleton3D = man.skeleton
		var shoulder: Vector3 = skeleton.global_transform * (man.pose_now(skeleton.find_bone(&"upperarm_r")) as Transform3D).origin
		var elbow: Vector3 = skeleton.global_transform * (man.pose_now(skeleton.find_bone(&"lowerarm_r")) as Transform3D).origin
		arm = (shoulder + elbow) * 0.5
		limb = GuardBodyScript.limb_at(man, arm)
		corpse.struck(arm, Vector3.DOWN, true, true)

	await _frames(5)
	_check("W4 a heavy cut on a corpse takes off what it met", limb == &"upperarm_r" and _parts() == parts_before + 1,
		"cut met %s, parts %d -> %d" % [limb, parts_before, _parts()])

	# W5 a quick cut from a dagger or a thrust takes nothing off
	var parts_now := _parts()
	if man != null:
		var skeleton: Skeleton3D = man.skeleton
		var hip: Vector3 = skeleton.global_transform * (man.pose_now(skeleton.find_bone(&"thigh_l")) as Transform3D).origin
		var knee: Vector3 = skeleton.global_transform * (man.pose_now(skeleton.find_bone(&"calf_l")) as Transform3D).origin
		corpse.struck(hip.lerp(knee, 0.5), Vector3.DOWN, true, false)
	await _frames(5)
	_check("W5 a blow that does not cut (a point, a dagger) takes nothing off", _parts() == parts_now, "parts %d -> %d" % [parts_now, _parts()])

	# W6 a blast tears a man apart
	var g6 := _guard(&"swordsman", Vector3(-10, 0, 0))
	await _frames(10)
	var before_blast := _parts()
	g6.take_hit(130.0, null, &"blast", g6._rig.chest(), Vector3.UP)
	await _frames(5)
	var torn := _parts() - before_blast
	_check("W6 a blast that kills a man tears him apart", torn >= 2, "parts torn off %d" % torn)

	# W7 a part cut off bleeds where it lies
	var stains_part := Fx.stains_in_use()
	await _frames(120)
	_check("W7 a part cut off drips where it lies", Fx.stains_in_use() > stains_part, "stains %d -> %d" % [stains_part, Fx.stains_in_use()])

	# W8 a man cut apart shakes those who see it, and the squad's heart sinks
	_put_player(Vector3(0, 1.05, 20))
	var victim := _guard(&"swordsman", Vector3(-1.2, 0, 18.0))
	var witness := _guard(&"swordsman", Vector3(1.2, 0, 18.0))
	victim._engage(player)
	witness._engage(player)
	await _frames(40)
	var squad: RefCounted = witness._fighter.squad
	var heart_before: float = float(squad.morale) if squad != null else -1.0
	witness._fighter.posture = 0.0
	victim.sever_hint = [&"neck_01"] as Array[StringName]
	victim.take_hit(999.0, player, &"power", victim._rig.chest() + Vector3.UP * 0.4, Vector3.FORWARD)
	await _frames(3)
	var heart_after: float = float(squad.morale) if squad != null else -1.0
	_check("W8 a man beheaded in front of his friend shakes him and sinks the squad's heart", witness._fighter.posture >= 20.0 and squad != null and heart_after < heart_before,
		"his balance %.0f, squad heart %.2f -> %.2f" % [witness._fighter.posture, heart_before, heart_after])
	witness.queue_free()
	await _frames(20)

	# W9 a kill up close that cuts him apart throws blood across your eyes
	var g9 := _guard(&"swordsman", Vector3(0, 0, 18.6))
	g9.block_chance = 0.0
	g9._fighter.parry_chance = 0.0
	g9.max_health = 30.0
	g9.health = 8.0
	_put_player(Vector3(0, 1.05, 20))
	await _frames(10)
	var drops_before: int = player.hud.splatter_count()
	await _tap("throw")
	await _frames(20)
	_check("W9 a kill up close that cuts him apart throws blood across your eyes", player.hud.splatter_count() > drops_before,
		"drops on the view %d -> %d, killed %s" % [drops_before, player.hud.splatter_count(), not is_instance_valid(g9)])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _guard(archetype: StringName, at: Vector3) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.debug_ai = false
	g.position = at
	g.rotation.y = PI
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g.block_chance = 0.0
	return g


func _parts() -> int:
	return get_tree().get_nodes_in_group(&"bodies").filter(func(n): return n.get_script() == SeveredPartScript and not n.is_queued_for_deletion()).size()


func _last_body() -> Node:
	var found: Node = null

	for n in get_tree().get_nodes_in_group(&"bodies"):
		if n is GuardBodyScript and not n.is_queued_for_deletion():
			found = n

	return found


func _put_player(at: Vector3) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw", "block", "kick", "dodge"]:
		if InputMap.has_action(a):
			Input.action_release(a)

	player.movement_state = 0
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0
	combat._reset()
	combat.stamina = combat.stamina_max


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
