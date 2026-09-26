extends Node3D
## The NPC gym: every kind of guard on his own, and all of them together, to
## watch what they do and try what works against them.
##
##   Godot --path . res://maps/npc_gym.tscn
##
##   A corridor runs north from the hub, eight bays off it, each behind its
##   own walls (a fight in one is not heard in the next):
##   1 WATCHMAN   a patrol through light and dark, a noisy floor and a quiet
##                one, a crate to throw: his alert, his sight, his search.
##   2 SWORDSMAN  guards, trades blows, reads a rhythm, kicks a turtle.
##   3 SWORDMASTER parries and answers, feints, steps out of long swings.
##   4 BRUTE      the blow no guard stops (dodge it: Q), cuts do not stop him.
##   5 ARCHER     keeps his distance behind cover, shoots; kicks you off.
##   6 SQUAD      a swordmaster, a swordsman, a brute and an archer together:
##                a leader and a plan (Squad.gd), called out as it changes.
##   7 BODIES     weak men, spikes, powder, a hanging weight, a ledge: kick
##                them (running, or while they swing), cut them apart.
##   8 ARMS MASTER a steady beat to parry, and straw men to cut.
##
##   1-8  go to that bay and start it (again)     0  back to the hub
##   F1   what each of them is thinking, over his head
##   F2   you cannot be hurt      F4  everyone freezes      R  rest
##   F3   sight cones (the debug overlays)
##
## A lever at each bay's mouth starts it too.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const BarrelScript := preload("res://scripts/Combat/Barrel.gd")
const HangingWeightScript := preload("res://scripts/Combat/HangingWeight.gd")
const LeverScript := preload("res://scripts/Interaction/Lever.gd")
const DummyScript := preload("res://scripts/Combat/TrainingDummy.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")

const STONE := Color(0.4, 0.38, 0.36)
const DARK := Color(0.2, 0.19, 0.21)
const SAND := Color(0.46, 0.4, 0.3)
const WOOD := Color(0.36, 0.25, 0.15)
const STATES := ["RELAXED", "SUSPICIOUS", "INVESTIGATING", "SEARCHING", "COMBAT"]
const STATE_COLOURS := [Color(0.55, 0.9, 0.5), Color(0.95, 0.9, 0.4), Color(1.0, 0.7, 0.3), Color(1.0, 0.5, 0.3), Color(1.0, 0.35, 0.3)]

## The bays: [name, the middle of the bay, which side of the corridor it
## opens to (-1 west, 1 east), what the sign says].
const BAYS := [
	["WATCHMAN", Vector3(-17, 0, -8), -1, "A watchman on his rounds. Stay in the dark (the gem), walk on the carpet,\nnot the iron. Throw the crate to draw him off. F1: his alert, what he sees."],
	["SWORDSMAN", Vector3(-17, 0, -26), -1, "A swordsman. He guards, trades blows, strings two together,\nreads a rhythm (vary it), kicks a turtle, lunges from range."],
	["SWORDMASTER", Vector3(-17, 0, -44), -1, "The swordmaster. Parries careless blows and answers fast;\nfeints; steps out of long swings (thrusts reach him)."],
	["BRUTE", Vector3(-17, 0, -62), -1, "The brute. Red glow and a roar: the blow no guard stops. DODGE (Q).\nCuts do not stop his swing. Only a running kick fells him, reeling."],
	["ARCHER", Vector3(17, 0, -8), 1, "An archer behind cover. He keeps his distance and shoots:\nblock the arrow, or close in round the cover. Up close he kicks you off."],
	["SQUAD", Vector3(17, 0, -26), 1, "A squad: swordmaster, swordsman, brute, archer. A leader and a plan:\nthey surround, strike while you are busy, break a turtle, press you hurt,\nfall back, rout when the leader dies. Watch the plan (top right)."],
	["BODIES", Vector3(17, 0, -44), 1, "Weak men to send flying and cut apart. Kick them while they swing, or running.\nInto the spikes, off the ledge, onto the powder. A clean kill takes a limb or a head."],
	["ARMS MASTER", Vector3(17, 0, -62), 1, "The arms master swings on a steady beat: parry just before it lands.\nStraw men to cut; shielded ones to break."],
]
const BAY_SIZE := 14.0

var player: CharacterBody3D
var _baker: NavigationRegion3D
var _bay_guards := {}
var _labels_on := true
var _frozen := false
var _label_timer := 0.0
var _log: Label
var _panel: Label
var _banner: Label
var _banner_timer := 0.0
var _lines: Array = []


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	_environment()
	Props.block(self, Vector3(0, -0.5, -30), Vector3(60, 1, 90), DARK, "stone")
	_hall()

	for i in range(BAYS.size()):
		_build_bay(i)

	_baker = NavigationRegion3D.new()
	_baker.set_script(NavBakerScript)
	add_child(_baker)

	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = Vector3(0, 1.05, 8)
	Props.give_weapons(player, 30)
	Props.give_blackjack(player)
	player.inventory.select_by_id(&"sword")
	_hook_player()
	_build_overlay()

	await _baker.baked
	_say("The NPC gym. Press 1-8 (or pull a lever) to start a bay. F1 shows what they think.")


# ---------------------------------------------------------------------------
# The place
# ---------------------------------------------------------------------------

func _hall() -> void:
	# The hub, lit, with the notice.
	_torch(Vector3(-4, 2.6, 6), false)
	_torch(Vector3(4, 2.6, 6), false)
	_sign(Vector3(0, 2.5, 2.5), "THE NPC GYM\n1-8 go to a bay and start it   0 back here\n" +
		"F1 what they think   F2 no harm to you   F3 sight cones   F4 freeze them   R rest\n" +
		"LMB attack (your look picks the cut)   RMB block/parry   F kick   Q dodge", 28)
	Props.block(self, Vector3(0, 0.4, 5.5), Vector3(2.0, 0.8, 0.9), WOOD, "wood")
	Props.arrows(self, Vector3(-0.4, 0.9, 5.5), 20)
	Props.arrows(self, Vector3(0.4, 0.9, 5.5), 20)
	LeverScript.build(self, Vector3(3, 0, 5.5), PI, "Rest (R)", _rest)

	# The outer walls.
	Props.block(self, Vector3(0, 3, 12), Vector3(60, 6, 1), STONE)
	Props.block(self, Vector3(0, 3, -72), Vector3(60, 6, 1), STONE)
	Props.block(self, Vector3(-30, 3, -30), Vector3(1, 6, 84), STONE)
	Props.block(self, Vector3(30, 3, -30), Vector3(1, 6, 84), STONE)

	for z in [-8.0, -26.0, -44.0, -62.0]:
		_torch(Vector3(0, 3.0, z + 4.0), false)


## A walled bay off the corridor, open on its corridor side by a gap.
func _build_bay(index: int) -> void:
	var spec: Array = BAYS[index]
	var centre: Vector3 = spec[1]
	var side: float = spec[2]
	var half := BAY_SIZE * 0.5
	# The walls between bays, and the back.
	Props.block(self, centre + Vector3(0, 2, half + 1.5), Vector3(BAY_SIZE + 2.0, 4, 0.6), STONE)
	Props.block(self, centre + Vector3(0, 2, -half - 1.5), Vector3(BAY_SIZE + 2.0, 4, 0.6), STONE)
	# The corridor side: two walls and a gap between.
	var mouth: float = centre.x - side * (half + 1.0)
	Props.block(self, Vector3(mouth, 2, centre.z + 5.2), Vector3(0.6, 4, 6.2), STONE)
	Props.block(self, Vector3(mouth, 2, centre.z - 5.2), Vector3(0.6, 4, 6.2), STONE)
	_sign(Vector3(mouth + side * 0.4, 3.2, centre.z), "%d  %s" % [index + 1, spec[0]], 40)
	_sign(centre + Vector3(0, 3.0, half + 1.1), spec[3], 22)
	LeverScript.build(self, Vector3(mouth - side * 0.8, 0, centre.z + 2.6), -side * PI * 0.5, "Start %s" % spec[0], func(): _start_bay(index))

	match index:
		0:
			# Light on one side, dark on the other; iron and carpet underfoot.
			_torch(centre + Vector3(-3.5, 2.6, -3.5))
			Props.block(self, centre + Vector3(2.5, 0.02, 0), Vector3(3.0, 0.04, 9.0), Color(0.35, 0.36, 0.4), "metal")
			Props.block(self, centre + Vector3(-2.5, 0.02, 3.0), Vector3(3.0, 0.04, 4.0), Color(0.45, 0.2, 0.18), "carpet")
			Props.block(self, centre + Vector3(0, 0.6, 0), Vector3(1.4, 1.2, 1.4), STONE)
		4:
			# Cover to shoot from, and to close in round.
			Props.block(self, centre + Vector3(0, 0.6, -3.5), Vector3(4.0, 1.2, 0.5), STONE)
			Props.block(self, centre + Vector3(-3.5, 1.5, 1.0), Vector3(0.8, 3.0, 0.8), STONE)
			Props.block(self, centre + Vector3(3.5, 1.5, 1.5), Vector3(0.8, 3.0, 0.8), STONE)
			_torch(centre + Vector3(0, 2.8, 5.0), false)
		5:
			Props.block(self, centre + Vector3(0, 0.02, 0), Vector3(12.0, 0.04, 12.0), SAND, "dirt")
			Props.block(self, centre + Vector3(-3.0, 1.5, -3.0), Vector3(0.8, 3.0, 0.8), STONE)
			Props.block(self, centre + Vector3(3.0, 1.5, -1.0), Vector3(0.8, 3.0, 0.8), STONE)
			_torch(centre + Vector3(-5.5, 2.8, 5.0), false)
			_torch(centre + Vector3(5.5, 2.8, -5.0), false)
		6:
			# Spikes on the back wall, a ledge to kick off, powder, a weight.
			Props.spikes(self, centre + Vector3(0, 1.0, -half + 0.2), 5.0, 2.0, Vector3.BACK)
			Props.block(self, centre + Vector3(-4.5, 1.25, -3.0), Vector3(3.5, 2.5, 3.0), STONE)
			_stairs(centre + Vector3(-4.5, 0, 2.2), Vector3.FORWARD, 8, 0.3125, 0.3, 2.0)
			_barrel(centre + Vector3(4.0, 0.4, 0.5))
			_barrel(centre + Vector3(4.7, 0.4, 1.2))
			Props.block(self, centre + Vector3(4.0, 5.6, -3.5), Vector3(3.0, 0.35, 0.35), WOOD, "wood")
			Props.block(self, centre + Vector3(2.5, 2.8, -3.5), Vector3(0.35, 5.6, 0.35), WOOD, "wood")
			Props.block(self, centre + Vector3(5.5, 2.8, -3.5), Vector3(0.35, 5.6, 0.35), WOOD, "wood")
			_hang(centre + Vector3(4.0, 5.4, -3.5), 2.4)
			_torch(centre + Vector3(0, 3.0, 4.5), false)
			_torch(centre + Vector3(-4.5, 4.8, -3.0), false)
		7:
			_dummy(centre + Vector3(-3.5, 0, 1.5), false)
			_dummy(centre + Vector3(3.5, 0, 1.5), true)
			_torch(centre + Vector3(0, 2.8, 4.5), false)
		_:
			_torch(centre + Vector3(0, 2.8, 4.5), false)
			_torch(centre + Vector3(0, 2.8, -4.5), false)


# ---------------------------------------------------------------------------
# Starting a bay
# ---------------------------------------------------------------------------

func _start_bay(index: int) -> void:
	var spec: Array = BAYS[index]
	var centre: Vector3 = spec[1]
	var side: float = spec[2]

	# One bay at a time: nobody left over from another comes after you.
	for other in range(BAYS.size()):
		_clear_bay(other)
	var guards: Array = []

	match index:
		0:
			guards.append(_patrol([centre + Vector3(-4, 0, -4), centre + Vector3(4, 0, -4), centre + Vector3(4, 0, 4), centre + Vector3(-4, 0, 4)]))
			Props.crate(self, centre + Vector3(side * 5.0, 0.3, 3.0), 0.4, 2.0)
		1:
			guards.append(_spawn(&"swordsman", centre + Vector3(0, 0, -3), 0.0))
		2:
			guards.append(_spawn(&"duelist", centre + Vector3(0, 0, -3), 0.0))
		3:
			guards.append(_spawn(&"brute", centre + Vector3(0, 0, -3), 0.0))
		4:
			guards.append(_spawn(&"archer", centre + Vector3(0, 0, -5.2), 0.0))
		5:
			guards.append(_spawn(&"duelist", centre + Vector3(0, 0, -2.5), 0.0))
			guards.append(_spawn(&"swordsman", centre + Vector3(-2.0, 0, -3.5), 0.0))
			guards.append(_spawn(&"brute", centre + Vector3(2.4, 0, -4.0), 0.0))
			guards.append(_spawn(&"archer", centre + Vector3(0, 0, -6.0), 0.0))
		6:
			for at in [centre + Vector3(0, 0, -3.8), centre + Vector3(-4.5, 2.5, -3.2), centre + Vector3(3.0, 0, 0.0)]:
				var weak := _spawn(&"swordsman", at, 0.0)
				weak.max_health = 60.0
				weak.health = 22.0
				guards.append(weak)
		7:
			var master := _spawn(&"trainer", centre + Vector3(0, 0, -2.5), 0.0)
			master.patrol_speed = 0.0
			master.investigate_speed = 0.0
			master.chase_speed = 0.0
			master._fighter.stays_put = true
			guards.append(master)

	_bay_guards[index] = guards

	# In at the mouth, facing in, whole and armed.
	var mouth: float = centre.x - side * (BAY_SIZE * 0.5 - 0.5)
	player.global_position = Vector3(mouth, 1.05, centre.z)
	player.velocity = Vector3.ZERO
	# Into the bay: west bays open east, so you face west, and the other way.
	player.rotation.y = -PI * 0.5 * side
	player.get_node("Neck").rotation.x = 0.0
	player.reset_physics_interpolation()
	_rest()
	player.inventory.select_by_id(&"blackjack" if index == 0 else &"sword")

	# The fights start at once; the watchman has to find you.
	if index != 0:
		for g in guards:
			g._engage(player)

	_banner_text("%d  %s" % [index + 1, spec[0]])
	_say("Bay %d: %s" % [index + 1, spec[0]])


## Everyone and everything from the last go at it: gone.
func _clear_bay(index: int) -> void:
	for g in _bay_guards.get(index, []):
		if is_instance_valid(g):
			# Out of it at once: gone at the end of the frame, but no more
			# thinking, fighting or joining anything before then.
			g.remove_from_group(&"guards")
			g.set_physics_process(false)
			g.state = 0
			g.queue_free()

	_bay_guards.erase(index)
	var centre: Vector3 = BAYS[index][1]
	var half := BAY_SIZE * 0.5 + 1.0

	for thing in get_tree().get_nodes_in_group(&"bodies"):
		var at: Vector3 = (thing as Node3D).global_position
		var man = thing.man() if thing.has_method("man") else null

		if man != null and man.ragdoll != null and man.ragdoll.is_limp():
			at = man.ragdoll.centre()

		if absf(at.x - centre.x) < half and absf(at.z - centre.z) < half:
			thing.queue_free()

	for child in get_children():
		if String(child.name).begins_with("DroppedSword") and absf((child as Node3D).global_position.x - centre.x) < half and absf((child as Node3D).global_position.z - centre.z) < half:
			child.queue_free()

	SquadScript.clear_all()


func _spawn(archetype: StringName, at: Vector3, yaw: float) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.debug_ai = false
	# Each bay its own: a fight in one is not heard in the next.
	g.hearing_acuity = 0.4
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	_hook_guard(g)
	_info_label(g)
	return g


func _patrol(points: Array) -> CharacterBody3D:
	var route := Node3D.new()
	add_child(route)

	for point in points:
		var marker := Marker3D.new()
		route.add_child(marker)
		marker.global_position = point

	var g := _spawn(&"", points[0], 0.0)
	g.patrol_route = g.get_path_to(route)
	g._waypoints.assign(route.get_children())
	g._go_to(route.get_child(0).global_position, true)
	g.tree_exiting.connect(route.queue_free)
	return g


func _rest() -> void:
	player.health = player.max_health
	player.combat.stamina = player.combat.stamina_max
	player.combat.adrenaline = 0.0

	for entry in player.inventory.belt:
		if entry["id"] == &"arrows":
			entry["count"] = maxi(int(entry["count"]), 30)

	player.inventory.changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key := (event as InputEventKey).physical_keycode

	if key >= KEY_1 and key <= KEY_8:
		_start_bay(key - KEY_1)
		get_viewport().set_input_as_handled()
		return

	match key:
		KEY_0:
			player.global_position = Vector3(0, 1.05, 8)
			player.rotation.y = 0.0
			player.reset_physics_interpolation()
		KEY_F1:
			_labels_on = not _labels_on
			_say("What they think: %s" % ("shown" if _labels_on else "hidden"))
		KEY_F2:
			player.invulnerable = not player.invulnerable
			_say("You %s be hurt" % ("cannot" if player.invulnerable else "can"))
		KEY_F4:
			_frozen = not _frozen

			for g in get_tree().get_nodes_in_group(&"guards"):
				g.set_physics_process(not _frozen)

			_say("They are %s" % ("frozen" if _frozen else "free"))
		KEY_R:
			_rest()
			_say("Rested: health, stamina, arrows")
		_:
			return

	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# What they are thinking
# ---------------------------------------------------------------------------

func _info_label(g: CharacterBody3D) -> void:
	var label := Label3D.new()
	label.name = "Thinking"
	label.font_size = 30
	# The same size on screen however near he is: up close a label the size
	# of a man would hide the fight it describes.
	label.pixel_size = 0.0016
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.fixed_size = true
	g.add_child(label)
	label.position = Vector3(0, float(g.get("eye_height")) + 0.75, 0)


func _process(delta: float) -> void:
	_banner_timer = maxf(_banner_timer - delta, 0.0)

	if _banner != null:
		_banner.modulate.a = clampf(_banner_timer / 0.5, 0.0, 1.0)

	for line in _lines:
		line[2] = float(line[2]) - delta

	_lines = _lines.filter(func(l): return float(l[2]) > 0.0)

	if _log != null:
		var text := ""

		for line in _lines:
			text += String(line[0]) + "\n"

		_log.text = text

	_label_timer -= delta

	if _label_timer <= 0.0:
		_label_timer = 0.12
		_update_labels()
		_update_panel()


func _update_labels() -> void:
	for g in get_tree().get_nodes_in_group(&"guards"):
		var label := g.get_node_or_null("Thinking") as Label3D

		if label == null:
			continue

		label.visible = _labels_on

		if not _labels_on:
			continue

		var state: int = int(g.state)
		var kind: String = String(g.get("speaker_name"))
		var lines := ["%s  %s  %d/%d" % [kind.to_upper(), STATES[state], roundi(g.health), roundi(g.max_health)]]
		var fighter = g._fighter

		if g.is_downed():
			lines.append("OFF HIS FEET")
		elif g._rising > 0.0:
			lines.append("getting up")
		elif state == 4 and fighter != null:
			var squad = fighter.squad

			if squad != null and squad.members().size() > 1:
				lines.append("%s  (plan %s)" % [String(fighter.role()).to_upper(), String(squad.tactic).to_upper()])

			# How he is doing: his mood, his balance, his wounds.
			var status := "OPEN - DEATHBLOW" if fighter.is_open() else String(fighter.mood).to_upper()

			if fighter.posture_max < 9999.0:
				status += "  balance %d/%d" % [roundi(fighter.posture), roundi(fighter.posture_max)]

			if float(g.bleeding) > 0.05:
				status += "  bleeding %.1f" % float(g.bleeding)

			lines.append(status)

			var doing := ""

			if g._phase != &"":
				doing = "%s %s" % [String(g._phase), String(g._attack)]

				var call: StringName = fighter.attack_info().get("call", &"cut")

				if call != &"cut":
					doing += "  (%s)" % String(call).to_upper()
			elif fighter.guarding:
				doing = "guard up"
			elif fighter.is_parrying():
				doing = "parrying"
			elif g._stagger > 0.0:
				doing = "reeling"

			if fighter._read_level > 0.05:
				doing += "  reads you %.1f" % fighter._read_level

			if doing != "":
				lines.append(doing)
		else:
			lines.append("alert %d  sees you %.2f" % [roundi(g.alert), g.visibility])

		label.text = "\n".join(lines)
		label.modulate = STATE_COLOURS[state]


## The squad after you, in the corner: its plan, its heart, what it has read.
func _update_panel() -> void:
	if _panel == null:
		return

	var squad = SquadScript.of(player)
	var members: Array = squad.members() if squad != null else []

	if members.size() < 2:
		_panel.text = ""
		return

	var lead = squad.leader()
	var text := "SQUAD   plan %s   heart %.2f   leader %s\n" % [String(squad.tactic).to_upper(), squad.morale, String(lead.get("speaker_name")) if lead != null else "none"]
	text += "they read you:  turtle %.2f  rhythm %.2f  keeping away %.2f  bow %.2f\n" % [squad.read[&"turtle"], squad.read[&"spam"], squad.read[&"kite"], squad.read[&"bow"]]
	var places := []

	for m in members:
		places.append("%s: %s" % [String(m.get("speaker_name")), String(squad.role_of(m))])

	_panel.text = text + "   ".join(places)


# ---------------------------------------------------------------------------
# Calling it out (as the proving grounds do)
# ---------------------------------------------------------------------------

func _hook_player() -> void:
	var combat: Node = player.combat
	combat.defended.connect(_on_defended)
	combat.feinted.connect(func(): _log_line("Feint"))
	combat.riposte_started.connect(func(): _popup(_ahead(1.4), "RIPOSTE", Color(1.0, 0.85, 0.3)))
	combat.landed.connect(_on_landed)


func _on_defended(result: StringName) -> void:
	if result == &"parry":
		_popup(_ahead(1.0), "PARRY", Color(1.0, 0.95, 0.5))
	elif result == &"broken":
		_popup(_ahead(1.0), "GUARD BROKEN", Color(1.0, 0.35, 0.25))


func _on_landed(target: Object, result: StringName, _damage: float) -> void:
	if result == &"parried":
		_popup((target as Node3D).global_position + Vector3.UP * 2.2, "PARRIED", Color(1.0, 0.4, 0.3))
	elif result == &"blocked":
		_popup((target as Node3D).global_position + Vector3.UP * 2.2, "blocked", Color(0.8, 0.8, 0.85))


func _hook_guard(g: CharacterBody3D) -> void:
	g.struck_by.connect(func(result, kind, damage): _on_struck(g, result, kind, damage))
	g.guard_broken.connect(func(): _popup(g.global_position + Vector3.UP * 2.3, "GUARD BROKEN", Color(1.0, 0.6, 0.2)))
	g.feinted.connect(func(): _popup(g.global_position + Vector3.UP * 2.3, "feint!", Color(0.7, 0.85, 1.0)))
	g.barked.connect(func(text): _log_line("%s: \"%s\"" % [String(g.get("speaker_name")), text]))


func _on_struck(g: Node3D, result: StringName, kind: StringName, damage: float) -> void:
	if result != &"hit" and result != &"killed":
		return

	var text := "%d" % roundi(damage) if kind == &"quick" else "%s %d" % [String(kind), roundi(damage)]
	_popup(g.global_position + Vector3.UP * (2.0 + randf() * 0.3), text, Color(1.0, 0.3, 0.2) if result == &"killed" else Color(1.0, 0.85, 0.75))

	if result == &"killed":
		_log_line("%s down (%s)" % [String(g.get("speaker_name")), String(kind)])


func _popup(at: Vector3, text: String, colour: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 44
	label.pixel_size = 0.006
	label.outline_size = 10
	label.modulate = colour
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	add_child(label)
	label.global_position = at
	var tween := label.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(label, "position:y", label.position.y + 0.7, 1.1)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.1).set_delay(0.35)
	tween.tween_callback(label.queue_free)


func _ahead(distance: float) -> Vector3:
	var eye: Transform3D = player.aim_transform()
	return eye.origin - eye.basis.z * distance + Vector3.UP * 0.25


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_log = _text_label(Vector2(20, 20), 17)
	layer.add_child(_log)
	_panel = _text_label(Vector2(20, 230), 17)
	_panel.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
	layer.add_child(_panel)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-300, 90)
	_banner.size = Vector2(600, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_banner)


func _text_label(at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _log_line(text: String) -> void:
	_lines.append([text, Color.WHITE, 6.0])

	while _lines.size() > 8:
		_lines.pop_front()


func _say(text: String) -> void:
	_log_line(text)


func _banner_text(text: String) -> void:
	if _banner != null:
		_banner.text = text
		_banner_timer = 2.0


# ---------------------------------------------------------------------------
# Building bits
# ---------------------------------------------------------------------------

func _stairs(start: Vector3, direction: Vector3, count: int, rise: float, run: float, width: float) -> void:
	var across := Vector3.UP.cross(direction).abs()

	for i in count:
		var top := rise * (i + 1)
		var centre := start + direction * (run * (i + 0.5)) + Vector3.UP * (top * 0.5)
		Props.block(self, centre, across * width + direction.abs() * run + Vector3.UP * top, STONE)


func _barrel(at: Vector3) -> void:
	var barrel: RigidBody3D = BarrelScript.new()
	add_child(barrel)
	barrel.global_position = at
	barrel.reset_physics_interpolation()


func _hang(beam: Vector3, rope: float) -> void:
	var weight: Node3D = HangingWeightScript.new()
	weight.drop = rope
	add_child(weight)
	weight.global_position = beam


func _dummy(at: Vector3, shield: bool) -> void:
	var dummy: StaticBody3D = DummyScript.new()
	dummy.guards = shield
	add_child(dummy)
	dummy.global_position = at
	dummy.rotation.y = PI


func _torch(at: Vector3, shadows := true) -> void:
	var torch: Node3D = TorchScript.new()
	torch.energy = 2.4
	torch.light_range = 10.0
	torch.shadows = shadows
	add_child(torch)
	torch.global_position = at


func _sign(at: Vector3, text: String, size := 32) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.008
	label.modulate = Color(0.95, 0.9, 0.8)
	label.outline_size = 8
	label.shaded = false
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(label)
	label.global_position = at


func _environment() -> void:
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	add_child(moon)
	moon.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	var environment := RetroScript.night_environment(Color(0.42, 0.45, 0.58), 0.5)
	environment.background_color = Color(0.03, 0.04, 0.07)
	environment.volumetric_fog_density = 0.02
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
