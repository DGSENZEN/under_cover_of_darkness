extends Node3D
## The city's memory, thing by thing (the districts-as-maps plan): every
## changeable thing's save_state() and load_state() on the fixture level,
## the player's carried things, and a district captured and applied whole.
##   Godot --headless --fixed-fps 60 --path . res://tests/state_test.tscn

const LevelLoader := preload("res://scripts/Level/LevelLoader.gd")
const LevelGameplay := preload("res://scripts/Level/LevelGameplay.gd")
const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
const DistrictState := preload("res://scripts/Level/DistrictState.gd")
const FIXTURE := "res://assets/level/fixture"
## Guard.Alert.SEARCHING.
const SEARCHING := 3
## A body put back lies within this of where it lay (m): it is a limp man
## laid down, his hips where the body was.
const BODY_SLACK := 0.6

var results: Array[String] = []
var player: CharacterBody3D


func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	add_child(world)
	player = PLAYER.instantiate()
	player.set("show_hud", false)
	add_child(player)
	player.global_position = Vector3(0.0, 0.1, 4.0)
	await _frames(3)
	await _things()
	await _men()
	await _district()
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


## The fixture level built under its own holder: [holder, level, made].
func _build(root_name: String) -> Array:
	var holder := Node3D.new()
	holder.name = root_name
	add_child(holder)
	var level: RefCounted = LevelLoader.load_level(holder, FIXTURE, root_name)
	var made: Dictionary = LevelGameplay.build_all(holder, level)
	# (The torch is a bare flame for two ticks, then its fixture.)
	await _frames(4)
	return [holder, level, made]


func _drop(built: Array) -> void:
	(built[0] as Node).queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# S1-S5: doors, chests, pickups, lamps
# ---------------------------------------------------------------------------

func _things() -> void:
	var a := await _build("state_a")
	var made: Dictionary = a[2]
	var door: Node = made["doors"]["door_room"]
	var chest: Node = made["chests"]["strongbox"]
	var purse: Node = made["pickups"]["purse"]
	var key: Node = made["pickups"]["room_key"]
	var torch: Node = made["lights"].get("torch_door")
	var douses: bool = torch != null and is_instance_valid(torch) and bool(torch.get("can_douse"))
	_check("S5 lights are named after their markers and douse as marked (after the torch's fixture replaced its flame)",
		torch != null and is_instance_valid(torch) and torch.name == "torch_door" and douses,
		"found %s, named %s, douses %s" % [torch != null and is_instance_valid(torch), torch.name if torch != null and is_instance_valid(torch) else "-", douses])

	player.global_position = door.global_position + Vector3(0.0, 0.1, 1.5)
	door.frob(player)
	player.inventory.add_key(&"room", "the room's key")
	# (Holding its key, one frob unlocks and opens it.)
	chest.frob(player)
	await _seconds(1.5)
	var door_state: Dictionary = door.save_state()
	var chest_state: Dictionary = chest.save_state()
	purse.frob(player)
	key.global_position += Vector3(1.0, 0.0, 0.0)
	await _frames(2)
	var key_state: Dictionary = key.save_state()
	var key_at: Vector3 = key.global_position
	var purse_state: Dictionary = {"taken": true}

	if torch != null and is_instance_valid(torch):
		torch.put_out(&"douse")

	await _frames(2)
	var torch_state: Dictionary = torch.save_state() if torch != null and is_instance_valid(torch) else {}
	await _drop(a)

	var b := await _build("state_b")
	made = b[2]
	var door_b: Node = made["doors"]["door_room"]
	door_b.load_state(door_state)
	# (A door moves with the physics: what is set shows on its next tick.)
	await _frames(2)
	var open_angle := wrapf(door_b.rotation.y - float(door_b.get("_closed_yaw")), -PI, PI)
	_check("S1 a door's state survives: open and unlocked, swung open at once (not over its 0.9 s swing)", bool(door_b.is_open) and not bool(door_b.locked)
		and absf(open_angle) > deg_to_rad(80.0), "open %s, locked %s, at %.0f degrees" % [door_b.is_open, door_b.locked, rad_to_deg(open_angle)])

	var chest_b: Node = made["chests"]["strongbox"]
	chest_b.load_state(chest_state)
	_check("S2 a chest's state survives: unlocked and open", bool(chest_b.is_open) and not bool(chest_b.locked),
		"open %s, locked %s" % [chest_b.is_open, chest_b.locked])

	var purse_b: Node = made["pickups"]["purse"]
	var key_b: Node = made["pickups"]["room_key"]
	purse_b.load_state(purse_state)
	key_b.load_state(key_state)
	await _frames(2)
	_check("S3 loot taken stays taken; a key knocked about stays where it lay", not is_instance_valid(purse_b) and is_instance_valid(key_b)
		and key_b.global_position.distance_to(key_at) < 0.05, "purse gone %s, key %.2f m from where it lay" % [not is_instance_valid(purse_b),
			key_b.global_position.distance_to(key_at) if is_instance_valid(key_b) else -1.0])

	var torch_b: Node = made["lights"].get("torch_door")
	var out := false

	if torch_b != null and is_instance_valid(torch_b) and not torch_state.is_empty():
		torch_b.load_state(torch_state)
		await _frames(2)
		out = not torch_b.is_lit()

	_check("S4 a doused lamp stays out", out, "state %s" % [torch_state])
	await _drop(b)


# ---------------------------------------------------------------------------
# S6-S9: guards, bodies, a man who followed the player in, what he carries
# ---------------------------------------------------------------------------

## The fixture built with its navmesh and its guard: [holder, level, made, guards].
func _build_guarded(root_name: String, with_guards := true) -> Array:
	var built := await _build(root_name)
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	baker.bake_bounds = AABB(Vector3(-8.0, -2.0, -12.0), Vector3(24.0, 8.0, 20.0))
	(built[0] as Node).add_child(baker)
	await baker.baked
	var made: Dictionary = built[2]
	built.append(LevelGameplay.guards(built[0], built[1], made["routes"], made["stations"], GUARD) if with_guards else {})
	await _frames(10)
	return built


func _men() -> void:
	# S6 a man searching is searching again, where he was
	var a := await _build_guarded("state_c")
	var hendrik: Node = a[3]["Hendrik"]
	hendrik.set("last_known_position", Vector3(2.0, 0.0, 2.0))
	hendrik.set("has_last_known", true)
	hendrik.set("alert", 60.0)
	hendrik.call("_set_state", SEARCHING)
	await _frames(30)
	var searching: Dictionary = hendrik.save_state()
	var stood: Vector3 = hendrik.global_position
	await _drop(a)
	var b := await _build_guarded("state_d")
	var hendrik_b: Node = b[3]["Hendrik"]
	hendrik_b.load_state(searching)
	var at6: Vector3 = hendrik_b.global_position
	await _frames(1)
	_check("S6 a guard searching is still searching where he was", int(hendrik_b.get("state")) == SEARCHING and bool(hendrik_b.get("has_last_known"))
		and at6.distance_to(stood) < 0.1, "state %d, knows %s, %.2f m from where he stood" % [int(hendrik_b.get("state")),
			hendrik_b.get("has_last_known"), at6.distance_to(stood)])

	# S7 a man knocked out is a body where he fell, and nobody is told
	player.global_position = hendrik_b.global_position + Vector3(0.0, 0.0, 1.2)
	hendrik_b.knock_out(player, true)
	await _seconds(3.0)
	var body: Node = _body_of(b[0], "Hendrik")
	var fallen: Dictionary = body.save_state() if body != null else {}
	await _drop(b)
	var c := await _build_guarded("state_e")
	var hendrik_c: Node = c[3]["Hendrik"]
	var barks := [0]
	hendrik_c.barked.connect(func(_text: String) -> void: barks[0] += 1)

	if not fallen.is_empty():
		hendrik_c.restore_downed(fallen["transform"], bool(fallen["dead"]), bool(fallen["discovered"]))

	await _seconds(2.0)
	var again: Node = _body_of(c[0], "Hendrik")
	var lies: float = again.global_position.distance_to((fallen["transform"] as Transform3D).origin) if again != null and not fallen.is_empty() else -1.0
	_check("S7 a guard knocked out is a body where he fell, and nobody is told", not fallen.is_empty() and not is_instance_valid(hendrik_c)
		and again != null and lies >= 0.0 and lies < BODY_SLACK and barks[0] == 0, "saved %s, guard gone %s, body %s, %.2f m from where it lay, barks %d" % [
			not fallen.is_empty(), not is_instance_valid(hendrik_c), again != null, lies, barks[0]])
	var spec: Dictionary = {}

	if not fallen.is_empty():
		spec = {"name": "Wanderer", "archetype": &"", "temperament": &"", "look_seed": 3, "light": &"", "keys": []}

	await _drop(c)

	# S8 a man who followed the player in: a guard with no route, standing
	var d := await _build_guarded("state_f", false)
	var wanderer: Node = LevelGameplay.visitor(d[0], spec, Transform3D(Basis(), Vector3(2.0, 0.1, 2.0)), GUARD) if not spec.is_empty() else null
	await _seconds(1.0)
	var on_mesh := wanderer != null and NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, wanderer.global_position) \
		.distance_to(wanderer.global_position) < 0.6
	_check("S8 a visitor is a guard with no route, standing on the navmesh", wanderer != null and wanderer.is_in_group(&"guards")
		and wanderer.name == "Wanderer" and on_mesh, "made %s, named %s, on the mesh %s" % [wanderer != null,
			wanderer.name if wanderer != null else "-", on_mesh])
	await _drop(d)

	# S9 what the player carries survives: purse, keys, belt, health
	var one: CharacterBody3D = PLAYER.instantiate()
	one.set("show_hud", false)
	add_child(one)
	await _frames(2)
	Props.give_blackjack(one)
	Props.give_tools(one)
	one.inventory.add_key(&"room", "the room's key")
	one.inventory.add_loot(120)
	one.set("health", 63.0)
	var carried: Dictionary = one.save_state()
	var belt_one: Array = one.inventory.belt.map(func(e): return [e["id"], e["count"]])
	one.queue_free()
	var two: CharacterBody3D = PLAYER.instantiate()
	two.set("show_hud", false)
	add_child(two)
	await _frames(2)
	two.load_state(carried)
	var belt_two: Array = two.inventory.belt.map(func(e): return [e["id"], e["count"]])
	var drawn: bool = two.inventory.belt.all(func(e): return e["mesh"] != null)
	_check("S9 the player's carried things survive", int(two.inventory.purse) == 120 and two.inventory.has_key(&"room") and belt_two == belt_one
		and drawn and is_equal_approx(float(two.get("health")), 63.0), "purse %d, key %s, belt %s / %s, meshes %s, health %.0f" % [
			two.inventory.purse, two.inventory.has_key(&"room"), belt_two, belt_one, drawn, float(two.get("health"))])
	two.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# S10: a district captured whole, and applied to a fresh build of it
# ---------------------------------------------------------------------------

func _district() -> void:
	var a := await _build_guarded("state_g")
	var made: Dictionary = a[2]
	var door: Node = made["doors"]["door_room"]
	player.global_position = door.global_position + Vector3(0.0, 0.1, 1.5)
	door.frob(player)
	made["pickups"]["purse"].frob(player)
	var torch: Node = made["lights"]["torch_door"]
	torch.put_out(&"douse")
	var hendrik: Node = a[3]["Hendrik"]
	player.global_position = hendrik.global_position + Vector3(0.0, 0.0, 1.2)
	hendrik.knock_out(player, true)
	await _seconds(2.0)
	var state := DistrictState.capture(a[0], {"fixture": made}, a[3])
	await _drop(a)

	var b := await _build_guarded("state_h")
	made = b[2]
	DistrictState.apply(b[0], {"fixture": made}, b[3], state)
	await _seconds(1.0)
	var door_b: Node = made["doors"]["door_room"]
	var torch_b: Node = made["lights"]["torch_door"]
	# (Gone from the level, not only from the map's list.)
	var standing: bool = get_tree().get_nodes_in_group(&"guards").any(func(g): return (b[0] as Node).is_ancestor_of(g) and g.name == "Hendrik")
	var ok: bool = bool(door_b.is_open) and not is_instance_valid(made["pickups"]["purse"]) and not torch_b.is_lit() \
		and not standing and not b[3].has("Hendrik") and _body_of(b[0], "Hendrik") != null
	_check("S10 a district captured and applied is as it was left (door open, loot gone, lamp out, a body for a guard)", ok,
		"door open %s, purse gone %s, lamp out %s, guard standing %s, body %s" % [door_b.is_open, not is_instance_valid(made["pickups"]["purse"]),
			not torch_b.is_lit(), standing, _body_of(b[0], "Hendrik") != null])
	await _drop(b)


## The body of the man called `who` under `holder`, or null.
func _body_of(holder: Node, who: String) -> Node:
	for body in get_tree().get_nodes_in_group(&"bodies"):
		if holder.is_ancestor_of(body) and String(body.get("called")) == who:
			return body

	return null


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * Engine.physics_ticks_per_second))


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
