extends Node3D
## The NPC gym (maps/npc_gym.tscn) works: every bay starts, its people come
## to life doing what they should, starting it again replaces them, and what
## they think is shown over them and in the corner.

const GYM := preload("res://maps/npc_gym.tscn")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")

var gym: Node3D
var results: Array[String] = []


func _ready() -> void:
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	gym = GYM.instantiate()
	add_child(gym)
	await gym._baker.baked
	await _frames(5)
	gym.player.invulnerable = true
	gym.player.reload_on_death = false
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# G1 each bay starts with its people doing what they should
	var summary := []
	var all_ok := true

	for i in range(gym.BAYS.size()):
		gym._start_bay(i)
		await _frames(45)
		var guards: Array = gym._bay_guards.get(i, [])
		var alive := guards.filter(func(g): return is_instance_valid(g))
		var fighting := alive.filter(func(g): return int(g.state) == 4).size()
		# The watchman is on his rounds; everyone else is on you.
		var ok := alive.size() == guards.size() and alive.size() > 0 and (fighting == 0 if i == 0 else fighting == alive.size())
		all_ok = all_ok and ok
		summary.append("%d:%d/%d%s" % [i + 1, fighting, alive.size(), "" if ok else "!"])

	_check("G1 every bay starts, its people alive and doing what they should", all_ok, " ".join(summary))

	# G2 starting a bay again replaces its people
	gym._start_bay(1)
	await _frames(20)
	var first: Array = gym._bay_guards[1].duplicate()
	gym._start_bay(1)
	await _frames(5)
	var second: Array = gym._bay_guards[1]
	var gone := first.filter(func(g): return is_instance_valid(g) and not g.is_queued_for_deletion()).is_empty()
	_check("G2 starting a bay again replaces its people", gone and second.size() == 1 and is_instance_valid(second[0]),
		"old ones gone %s new %d" % [gone, second.size()])

	# G3 what they think, over their heads; G4 the squad's plan in the corner
	gym._start_bay(5)
	await _frames(40)
	var label := (gym._bay_guards[5][0] as Node).get_node_or_null("Thinking") as Label3D
	var thinking: String = label.text if label != null else ""
	var panel: String = gym._panel.text
	_check("G3 what each thinks shows over his head", label != null and label.visible and thinking.contains("COMBAT"), "'%s'" % thinking.replace("\n", " | "))
	_check("G4 the squad's plan and places show in the corner", panel.contains("plan") and panel.contains("Duelist") and panel.contains("Archer"), "'%s'" % panel.replace("\n", " | "))

	# G5 the guardhouse: the squad is on you in the yard, the barracks men rest out of earshot
	gym._start_bay(8)
	await _frames(45)
	var yard: Array = gym._bay_guards.get(8, [])
	var barracks: Array = gym._barracks
	var map: RID = gym.get_world_3d().navigation_map
	var far_enough := true
	for g in barracks:
		var path := NavigationServer3D.map_get_path(map, Vector3(0, 0, 24), g.global_position, true)
		var length := 0.0
		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		far_enough = far_enough and length > 25.0
	_check("G5 the guardhouse: the squad is on you in the yard, the barracks men rest out of earshot",
		yard.size() == 4 and yard.all(func(g): return int(g.state) == 4) and barracks.size() == 2 and barracks.all(func(g): return int(g.state) == 0) and far_enough,
		"yard %d barracks %d far %s" % [yard.size(), barracks.size(), far_enough])

	# G6 the corner shows the hunt even for one man
	gym._start_bay(1)
	await _frames(40)
	var one: String = gym._panel.text
	_check("G6 the corner shows the hunt even for one man", one.contains("plan") and one.contains("Swordsman") and one.contains("dread"), "'%s'" % one.replace("\n", " | "))

	# G7 starting a bay keeps what the garrison knows; F5 forgets it
	GarrisonScript.of(gym.player).dread = 0.4
	gym._start_bay(1)
	await _frames(5)
	# (Set by hand, it has no quiet spell to hold it: it starts fading at once,
	# a hair a frame.)
	var kept: bool = absf(GarrisonScript.of(gym.player).dread - 0.4) < 0.01
	gym._forget()
	_check("G7 starting a bay keeps what the garrison knows; F5 makes it forget", kept and GarrisonScript.of(gym.player).dread == 0.0, "kept %s" % kept)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
