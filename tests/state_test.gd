extends Node3D
## The city's memory, thing by thing (the districts-as-maps plan): every
## changeable thing's save_state() and load_state() on the fixture level,
## the player's carried things, and a district captured and applied whole.
##   Godot --headless --fixed-fps 60 --path . res://tests/state_test.tscn

const LevelLoader := preload("res://scripts/Level/LevelLoader.gd")
const LevelGameplay := preload("res://scripts/Level/LevelGameplay.gd")
const PLAYER := preload("res://Player.tscn")
const FIXTURE := "res://assets/level/fixture"

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
# Helpers
# ---------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * Engine.physics_ticks_per_second))


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
