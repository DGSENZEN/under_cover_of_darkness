extends Node3D
## Fighting together (Squad.gd): a leader and a plan, a place for each man,
## the flank that strikes while you are busy, the brute sent to break a
## turtle, pressing a hurt man, falling back, the rout when the leader falls,
## an archer who will not shoot through his own, and a man stepping in front
## of the archer you go for.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")

var player: CharacterBody3D
var combat: Node
var results: Array[String] = []


func _ready() -> void:
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200))

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
	player.global_position = Vector3(0, 1.05, 40)
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
	# Q1 a man alone is simply engaged
	_put_player(Vector3(0, 1.05, 0))
	var lone := _guard(&"swordsman", Vector3(0, 0, -2.5))
	await _frames(30)
	var squad = lone._fighter.squad
	_check("Q1 a man fighting you alone is simply engaged", squad != null and squad.role_of(lone) == &"engage" and squad.tactic == &"envelop",
		"squad %s role %s plan %s" % [squad != null, squad.role_of(lone) if squad else &"", squad.tactic if squad else &""])
	lone.queue_free()
	await _frames(10)

	# Q2 a mixed squad: the swordmaster leads, one holds you, others flank,
	#    the archer supports
	_put_player(Vector3(20, 1.05, 0))
	var master := _guard(&"duelist", Vector3(20, 0, -2.2))
	var sword := _guard(&"swordsman", Vector3(18.5, 0, -3.5))
	var brute := _guard(&"brute", Vector3(21.8, 0, -3.8))
	var archer := _guard(&"archer", Vector3(20, 0, -11.0))
	await _frames(40)
	squad = master._fighter.squad
	var roles := {}

	for g in [master, sword, brute, archer]:
		roles[String(g.archetype)] = String(squad.role_of(g))

	var holding := roles.values().count("engage")
	_check("Q2 in a mixed squad the swordmaster leads, one holds you, the rest flank, the archer supports",
		squad.leader() == master and holding == 1 and roles["archer"] == "support" and roles.values().count("flank") >= 1,
		"leader %s roles %s" % [squad.leader().archetype if squad.leader() else &"", roles])

	# Q3 a man at your side strikes only when you are busy with another
	var flanker: CharacterBody3D = sword if squad.role_of(sword) == &"flank" else brute
	# Face the one holding you, the flanker off at your side.
	flanker.global_position = player.global_position + Vector3(2.2, -1.05, 0.2)
	_aim(master.global_position + Vector3.UP * 1.2)
	await _frames(2)
	var idle_ok: bool = not squad.may_strike(flanker)
	Input.action_press("block")
	await _frames(4)
	var busy_ok: bool = squad.may_strike(flanker)
	Input.action_release("block")
	await _frames(2)
	_check("Q3 a flanker holds off while you watch, and strikes while you are busy with another", idle_ok and busy_ok,
		"held off idle %s may strike while you block %s" % [idle_ok, busy_ok])

	# Q4 hiding behind your blade: the brute is sent to break it, and they kick
	squad.read[&"turtle"] = 0.9
	squad._tactic_since = -100.0
	squad._last_think = -100.0
	await _frames(20)
	_check("Q4 turtling, they switch to breaking your guard and send the brute", squad.tactic == &"break" and squad.role_of(brute) == &"breaker" and squad.bonus(&"kick") > 0.3,
		"plan %s brute %s kick bonus %.2f" % [squad.tactic, squad.role_of(brute), squad.bonus(&"kick")])
	squad.read[&"turtle"] = 0.0

	# Q5 hurt, you are pressed: two may swing at once
	player.health = player.max_health * 0.25
	squad._tactic_since = -100.0
	squad._last_think = -100.0
	await _frames(20)
	_check("Q5 badly hurt, you are pressed: two come at once", squad.tactic == &"press" and squad.attackers() == 2,
		"plan %s at once %d" % [squad.tactic, squad.attackers()])
	player.health = player.max_health

	# Q6 an archer does not shoot through his own men
	var archer_fighter = archer._fighter
	# The archer off to one side, with a clear line to you but for the man
	# put in it.
	archer.global_position = Vector3(30, 0, -8)
	master.global_position = Vector3(14, 0, 2)
	brute.global_position = Vector3(26, 0, 4)
	sword.global_position = (archer.global_position + player.global_position) * 0.5 + Vector3(0, -1.05, 0)
	sword.velocity = Vector3.ZERO
	await _frames(3)
	var blocked_by_friend: bool = not archer_fighter._clear_shot(player)
	sword.global_position = Vector3(26, 0, -6)
	await _frames(3)
	var clear_after: bool = archer_fighter._clear_shot(player)
	_check("Q6 an archer will not shoot through one of his own", blocked_by_friend and clear_after,
		"blocked by a friend %s clear once he moves %s" % [blocked_by_friend, clear_after])

	# Q7 go for the archer: someone steps in front of him
	_put_player(Vector3(27, 1.05, -6.0))
	squad._last_think = -100.0
	await _frames(15)
	var guarding_archer := 0

	for g in [master, sword, brute]:
		if squad.role_of(g) == &"bodyguard":
			guarding_archer += 1

	_check("Q7 going for the archer, one of them steps in front of him", guarding_archer == 1, "bodyguards %d" % guarding_archer)

	# Q8 half of them down: they fall back to the leader and call for help
	player.health = player.max_health
	var shouts := [0]
	master.barked.connect(func(text): shouts[0] += 1)
	sword.barked.connect(func(text): shouts[0] += 1)
	archer.die(null)
	brute.die(null)
	squad._tactic_since = -100.0
	squad._last_think = -100.0
	await _frames(20)
	_check("Q8 with half of them down they fall back together and call it", squad.tactic == &"fall_back" and squad.role_of(sword) == &"rally" and shouts[0] >= 1,
		"plan %s swordsman %s calls %d" % [squad.tactic, squad.role_of(sword), shouts[0]])

	# Q9 their leader falls and their heart goes: the rest run
	squad._fall_back_until = -100.0
	master.die(null)
	squad._tactic_since = -100.0
	squad._last_think = -100.0
	await _frames(20)
	_check("Q9 when their leader falls and heart goes, the rest run", squad.tactic == &"rout" and squad.role_of(sword) == &"flee" and squad.morale < 0.45,
		"plan %s swordsman %s morale %.2f" % [squad.tactic, squad.role_of(sword), squad.morale])
	sword.queue_free()
	await _frames(10)

	# Q10 the brute is left alone when the leader falls: berserk
	_put_player(Vector3(50, 1.05, 0))
	var captain := _guard(&"duelist", Vector3(50, 0, -2.2))
	var big := _guard(&"brute", Vector3(52, 0, -3.0))
	await _frames(30)
	var squad10 = captain._fighter.squad
	captain.die(null)
	squad10._tactic_since = -100.0
	squad10._last_think = -100.0
	await _frames(20)
	_check("Q10 the brute goes berserk when his captain falls", squad10.role_of(big) == &"berserk",
		"plan %s brute %s" % [squad10.tactic, squad10.role_of(big)])
	big.queue_free()
	await _frames(10)


# --------------------------------------------------------------------------

func _guard(archetype: StringName, at: Vector3) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.debug_ai = false
	g.position = at
	g.rotation.y = 0.0
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g._engage(player)
	return g


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
	player.combat._reset()
	player.reset_physics_interpolation()


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
