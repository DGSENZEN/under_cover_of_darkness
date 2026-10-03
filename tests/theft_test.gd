extends Node3D
## The theft noticed (the harbour's job plan, Task 8): a chest the player
## left open is an oddity a guard goes and shuts; a chest robbed of something
## precious raises the full alarm and sends a man to the bell, once; a robbed
## chest shut behind you goes unnoticed.
##   Godot --headless --fixed-fps 60 --path . res://tests/theft_test.tscn

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const AlarmBellScript := preload("res://scripts/Interaction/AlarmBell.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const LevelGameplay := preload("res://scripts/Level/LevelGameplay.gd")
const TallyScript := preload("res://scripts/Level/Tally.gd")

const SEARCHING := 3

var player: CharacterBody3D
var results: Array[String] = []


func _ready() -> void:
	TemperamentScript.rolling = false
	GuardScript.bleeding_on = false
	Props.block(self, Vector3(150, -0.5, 0), Vector3(400, 1, 60))
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	player.debug_light_level = 0.0
	player.global_position = Vector3(150, 1.05, 28)
	CityState.begin()
	CityState.job.arrive(&"fixture")
	await baker.baked
	await _frames(5)
	await _chests()
	await _noticed()
	await _robbed()
	await _shut()
	await _tally()
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


# ---------------------------------------------------------------------------
# R1-R3: the chests themselves
# ---------------------------------------------------------------------------

func _chests() -> void:
	var by_player: Node3D = Props.chest(self, Vector3(0, 0, -10))
	var by_guard: Node3D = Props.chest(self, Vector3(3, 0, -10))
	var a_guard := Node3D.new()
	a_guard.add_to_group(&"guards")
	add_child(a_guard)
	by_player.frob(player)
	by_guard.frob(a_guard)
	# (A man knocked out is out of the guards' group, as a door knows: what he
	# opened is still a guard's doing.)
	var by_downed: Node3D = Props.chest(self, Vector3(-3, 0, -10))
	var downed_script := GDScript.new()
	downed_script.source_code = "extends Node3D\nvar _knocked_out := true\n"
	downed_script.reload()
	var downed := Node3D.new()
	downed.set_script(downed_script)
	add_child(downed)
	by_downed.frob(downed)
	_check("R1 a chest the player left open is an oddity; one a guard opened is not, even once he is knocked out",
		by_player.left_open() and not by_guard.left_open() and not by_downed.left_open(),
		"player's %s, guard's %s, a downed man's %s" % [by_player.left_open(), by_guard.left_open(), by_downed.left_open()])
	a_guard.free()
	downed.free()

	var chest: Node3D = Props.chest(self, Vector3(6, 0, -10))
	var inside: RigidBody3D = Props.loot(self, Vector3(6, 0.15, -10.2), 250, "seal")
	inside.name = "the_seal"
	inside.set_meta(&"special", true)
	var far: RigidBody3D = Props.loot(self, Vector3(7.5, 0.15, -10), 50, "cup")
	far.name = "cup"
	far.set_meta(&"special", true)
	LevelGameplay.fill_chests({"box": chest}, {"the_seal": inside, "cup": far})
	_check("R2 a special inside a chest is held by it; one beside it is not", chest.held_specials == ["the_seal"], "held %s" % [chest.held_specials])

	var before: bool = chest.robbed()
	inside.frob(player)
	var after: bool = chest.robbed()
	var revisit: Node3D = Props.chest(self, Vector3(10, 0, -10))
	var gone: RigidBody3D = Props.loot(self, Vector3(10, 0.15, -10), 250, "ring")
	gone.set_meta(&"special", true)
	LevelGameplay.fill_chests({"box": revisit}, {"ring": gone})
	gone.free()
	_check("R3 robbed when the special is taken, or gone (a district come back to)", not before and after and revisit.robbed(),
		"before %s, after %s, revisit %s" % [before, after, revisit.robbed()])


# ---------------------------------------------------------------------------
# R4: an open chest noticed and shut
# ---------------------------------------------------------------------------

func _noticed() -> void:
	await _fresh()
	_light(Vector3(40, 2.6, 1.5))
	var chest: Node3D = Props.chest(self, Vector3(40, 0, 0))
	var g := _guard(Vector3(40, 0, 6), 0.0)
	await _frames(20)
	chest.frob(player)
	await _until(func(): return not chest.is_open, 60 * 20)
	var alarm: float = GarrisonScript.of(player).alarm
	_check("R4 a guard who sees a chest left open goes and shuts it; the garrison stirs, a little", not chest.is_open and alarm >= 0.2 and alarm < 1.0,
		"shut %s, alarm %.2f, his state %d" % [not chest.is_open, alarm, g.state])


# ---------------------------------------------------------------------------
# R5-R6: a robbed chest: the full alarm, the bell, once
# ---------------------------------------------------------------------------

func _robbed() -> void:
	await _fresh()
	_light(Vector3(80, 2.6, 1.5))
	var chest: Node3D = Props.chest(self, Vector3(80, 0, 0))
	var seal: RigidBody3D = Props.loot(self, Vector3(80, 0.15, 0), 250, "seal")
	seal.set_meta(&"special", true)
	LevelGameplay.fill_chests({"box": chest}, {"the_seal": seal})
	var bell: StaticBody3D = AlarmBellScript.build(self, Vector3(80, 0, -14), 0.0)
	var rung := []
	bell.rung.connect(func(by): rung.append(by))
	var finder := _guard(Vector3(80, 0, 6), 0.0)
	var bellman := _guard(Vector3(83, 0, -12), 0.0)
	await _frames(20)
	chest.frob(player)
	seal.frob(player)
	await _until(func(): return not rung.is_empty(), 60 * 25)
	var fact: Variant = CityState.job.fact(&"fixture", &"theft_noticed")
	_check("R5 an open, robbed chest raises the full alarm and sends a man to the bell", fact == true and GarrisonScript.of(player).alarm >= 1.0
		and rung.size() == 1 and rung[0] == bellman, "theft %s, alarm %.2f, rung by %s" % [fact, GarrisonScript.of(player).alarm,
			rung.map(func(r): return r.name if r != null else "nobody")])

	finder.knock_out(player, true)
	await _frames(30)
	var third := _guard(Vector3(86, 0, 5), deg_to_rad(40.0))
	await _until(func(): return third.state >= SEARCHING, 60 * 20)
	await _frames(60 * 4)
	var alarms := int(CityState.job.tally_of(&"fixture").get("alarms", 0))
	_check("R6 found again by another man: dealt with, but counted once and the bell not sent for again", third.state >= SEARCHING
		and alarms == 1 and rung.size() == 1, "third's state %d, alarms %d, rung %d" % [third.state, alarms, rung.size()])
	bell.queue_free()


# ---------------------------------------------------------------------------
# R7: a robbed chest shut behind you
# ---------------------------------------------------------------------------

func _shut() -> void:
	await _fresh()
	CityState.job.reset()
	CityState.job.arrive(&"fixture")
	_light(Vector3(300, 2.6, 1.5))
	var chest: Node3D = Props.chest(self, Vector3(300, 0, 0))
	var seal: RigidBody3D = Props.loot(self, Vector3(300, 0.15, 0), 250, "seal")
	seal.set_meta(&"special", true)
	LevelGameplay.fill_chests({"box": chest}, {"the_seal": seal})
	chest.frob(player)
	seal.frob(player)
	chest.frob(player)
	await _frames(60)
	var g := _guard(Vector3(300, 0, 6), 0.0)
	await _frames(60 * 20)
	var fact: Variant = CityState.job.fact(&"fixture", &"theft_noticed")
	_check("R7 a robbed chest shut behind you goes unnoticed", fact == null and GarrisonScript.of(player).alarm == 0.0 and not chest.is_open,
		"theft %s, alarm %.2f, his state %d" % [fact, GarrisonScript.of(player).alarm, g.state])


# ---------------------------------------------------------------------------
# R8: the tally counts what happens
# ---------------------------------------------------------------------------

func _tally() -> void:
	await _fresh()
	CityState.job.reset()
	CityState.job.arrive(&"fixture")
	var tally: Node = TallyScript.new()
	add_child(tally)
	tally.setup(player, {"loot_total": 100, "specials_total": 1, "read_total": 2})
	var sleeper := _guard(Vector3(200, 0, 0), 0.0)
	var watcher := _guard(Vector3(205, 0, 6), 0.0)
	await _frames(70)
	sleeper.knock_out(player, true)
	await _frames(10)
	watcher._engage(player)
	await _frames(60 * 3)
	watcher._give_up()
	await _frames(10)
	watcher._engage(player)
	await _frames(10)
	var merged := int(CityState.job.tally_of(&"fixture").get("seen", 0))
	watcher._give_up()
	await _frames(60 * 11)
	watcher._engage(player)
	await _frames(10)
	var t: Dictionary = CityState.job.tally_of(&"fixture")
	_check("R8 the tally counts a knockout, sightings (one a moment), the totals and the time", int(t.get("knockouts", 0)) == 1 and merged == 1
		and int(t.get("seen", 0)) == 2 and int(t.get("loot_total", 0)) == 100 and int(t.get("seconds", 0)) >= 14,
		"tally %s, seen after the second sighting %d" % [t, merged])
	tally.queue_free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _guard(at: Vector3, yaw: float) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = &""
	g.temperament = &"steady"
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	return g


func _light(at: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.omni_range = 9.0
	lamp.light_energy = 2.0
	lamp.add_to_group(&"theft_lights")
	add_child(lamp)
	lamp.global_position = at
	LightProbe.invalidate()


## A clean start: nobody left, nothing remembered.
func _fresh() -> void:
	for g in get_tree().get_nodes_in_group(&"guards"):
		g.remove_from_group(&"guards")
		g.set_physics_process(false)
		g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"theft_lights"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	await _frames(5)
	LightProbe.invalidate()


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
