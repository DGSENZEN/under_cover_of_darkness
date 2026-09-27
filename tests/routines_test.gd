extends Node3D
## The garrison's night: the fire burning down and fed (Fire), the night
## rota (duties, needs, the hour: NightRota), and the things the men do
## together (Gathering: dice, the flask, a story, the watch changing, the
## captain's round, waking the sleeper, feeding the fire).
##
##   Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/routines_test.tscn

const FireScript := preload("res://scripts/Combat/Fire.gd")
const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const NightRotaScript := preload("res://scripts/AISystem/NightRota.gd")
const GuardStationScript := preload("res://scripts/AISystem/GuardStation.gd")

var results: Array[String] = []
var player: CharacterBody3D


func _ready() -> void:
	await _yard()
	seed(2028)
	GuardScript.randomize_on = false
	await _run()
	GuardScript.randomize_on = true
	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	await _fire()
	await _rota()


# ---------------------------------------------------------------------------
# The fire
# ---------------------------------------------------------------------------

func _fire() -> void:
	# R1 it burns down, its light with it, never quite out
	var fire: Area3D = FireScript.brazier(self, Vector3(0, 0, 20))
	fire.fuel_seconds = 10.0
	var torch: Node3D = fire.torch
	await _frames(480)
	var low_light: float = torch.light.light_energy
	var was_low: bool = fire.low()
	await _frames(420)
	_check("R1 a fire burns down and its light with it, and never quite out",
		was_low and low_light < 0.6 * torch.energy and fire.fuel >= FireScript.EMBERS - 0.001 and fire.burning() == &"low",
		"low %s, light %.2f of %.2f, fuel at the end %.3f" % [was_low, low_light, torch.energy, fire.fuel])

	# R2 fed, it flares, then burns as its fuel says
	var before: float = fire.fuel
	fire.feed()
	var fed: float = fire.fuel
	await _frames(10)
	var base := lerpf(0.25, 1.0, fire.fuel)
	var flared: bool = fire.strength() > base * 1.3
	var ratio: float = torch.light.light_energy / (torch.energy * fire.strength())
	await _frames(180)
	var settled := absf(fire.strength() - lerpf(0.25, 1.0, fire.fuel)) <= lerpf(0.25, 1.0, fire.fuel) * 0.05
	_check("R2 a fire fed a log flares up, then burns as its fuel says, its light following",
		absf(fed - minf(before + 0.6, 1.0)) < 0.01 and flared and absf(ratio - 1.0) <= torch.flicker + 0.02 and settled,
		"fuel %.2f -> %.2f, flared %s, light to strength %.2f, settled %s" % [before, fed, flared, ratio, settled])
	fire.get_parent().queue_free()


# ---------------------------------------------------------------------------
# The night rota
# ---------------------------------------------------------------------------

func _rota() -> void:
	# R3 the hour passes
	await _fresh()
	var rota: RefCounted = NightRotaScript.setup(self, 10.0)
	var idler := _guard(Vector3(0, 0, 0), 0.0)
	var at_start: StringName = rota.hour()
	await _frames(12 * 60)
	var at_12: StringName = rota.hour()
	await _frames(23 * 60)
	var at_35: StringName = rota.hour()
	_check("R3 the night's hour passes: early, then middle, then on to dawn", at_start == &"early" and at_12 == &"middle" and at_35 == &"dawn",
		"%s, %s, %s" % [at_start, at_12, at_35])

	# R4 needs: the cold away from the fire, warmth beside it, rest in bed
	await _fresh()
	rota = NightRotaScript.setup(self, 600.0)
	var fire: Area3D = FireScript.brazier(self, Vector3(40, 0, 0))
	var bed: Node3D = _station(&"sleep", Vector3(40, 0, -12), 0.0)
	rota.add_duty(&"bed", &"bed", {"paths": [bed.get_path()]})
	var far := _guard(Vector3(40, 0, 12), 0.0)
	var near := _guard(Vector3(41.5, 0, 0), 0.0)
	var sleeper := _guard(Vector3(41, 0, -12), 0.0)
	rota.assign(sleeper, &"bed")
	rota.set_need(near, &"cold", 0.5)
	await _until(func(): return sleeper._rota.asleep(), 600)
	rota.set_need(sleeper, &"tired", 0.8)
	await _frames(900)
	var cold_far: float = rota.needs_of(far)["cold"]
	var cold_near: float = rota.needs_of(near)["cold"]
	var tired: float = rota.needs_of(sleeper)["tired"]
	_check("R4 away from the fire a man grows cold, beside it he warms, and asleep he rests",
		cold_far > 0.05 and cold_near < 0.5 and sleeper._rota.asleep() and tired < 0.8,
		"cold far %.3f near %.3f, asleep %s tired %.3f" % [cold_far, cold_near, sleeper._rota.asleep(), tired])
	fire.get_parent().queue_free()

	# R5 a post stood too long wants relief
	await _fresh()
	rota = NightRotaScript.setup(self, 600.0)
	rota.post_turn = 20.0
	rota.add_duty(&"gate", &"post", {"transform": Transform3D(Basis.IDENTITY, Vector3(60, 0, 0))})
	var sentry := _guard(Vector3(60, 0, 0), 0.0)
	rota.assign(sentry, &"gate")
	await _frames(18 * 60)
	var early: bool = rota.wanted().any(func(w): return w["man"] == sentry)
	await _frames(3 * 60)
	var wants: bool = rota.wanted().any(func(w): return w["man"] == sentry and w["kind"] == &"relief")
	_check("R5 a man on a post too long wants relieving, not before", not early and wants, "at 18 s %s, at 21 s %s" % [early, wants])

	# R6 the alarm suspends the rota
	await _fresh()
	rota = NightRotaScript.setup(self, 600.0)
	var hungry := _guard(Vector3(70, 0, 0), 0.0)
	await _frames(5)
	GarrisonScript.of(player).raise_alarm(0.5)
	var held: bool = rota.suspended()
	rota.set_need(hungry, &"hungry", 0.99)
	await _frames(120)
	var nothing: bool = rota.wanted().is_empty() and float(rota.needs_of(hungry)["hungry"]) >= 0.99
	GarrisonScript.of(player).alarm = 0.0
	await _frames(60)
	var resumed: bool = not rota.suspended() and rota.wanted().any(func(w): return w["man"] == hungry and w["need"] == &"hungry")
	_check("R6 the alarm holds the rota: needs still grow, nobody is moved; at ease again it goes on",
		held and nothing and resumed, "held %s, nothing wanted %s, resumed %s (%s)" % [held, nothing, resumed, rota.wanted()])

	# R7 a duty moves a man: a round walked, a post stood
	await _fresh()
	rota = NightRotaScript.setup(self, 600.0)
	var route := Node3D.new()
	add_child(route)

	for point in [Vector3(80, 0, 0), Vector3(80, 0, 10)]:
		var marker := Marker3D.new()
		route.add_child(marker)
		marker.global_position = point

	rota.add_duty(&"round", &"round", {"route": route.get_path()})
	rota.add_duty(&"post", &"post", {"transform": Transform3D(Basis.IDENTITY, Vector3(90, 0, -8))})
	var walker := _guard(Vector3(86, 0, -2), 0.0)
	rota.assign(walker, &"round")
	await _until(func(): return walker.global_position.distance_to(Vector3(80, 0, 10)) < 1.2, 900)
	var rounded: bool = walker.global_position.distance_to(Vector3(80, 0, 10)) < 1.2
	rota.assign(walker, &"post")
	await _frames(900)
	var posted: bool = Vector2(walker.global_position.x - 90, walker.global_position.z + 8).length() < 0.8
	_check("R7 a duty moves a man: he walks the round he is given, then stands the post",
		rounded and posted and rota.duty_of(walker) == &"post", "rounded %s posted %s at %s, duty %s" % [rounded, posted, walker.global_position, rota.duty_of(walker)])
	route.queue_free()


# ---------------------------------------------------------------------------
# The yard
# ---------------------------------------------------------------------------

func _yard() -> void:
	TemperamentScript.rolling = false
	Props.block(self, Vector3(60, -0.5, 0), Vector3(200, 1, 60))
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

	player.debug_light_level = 0.0
	player.global_position = Vector3(60, 1.05, 28)
	await baker.baked
	await _frames(5)


func _guard(at: Vector3, yaw := 0.0, preset: StringName = &"steady", name := "", stations := []) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.temperament = preset
	g.debug_ai = false
	g.given_name = name

	if not stations.is_empty():
		var paths: Array[NodePath] = []

		for station in stations:
			paths.append((station as Node).get_path())

		g.stations = paths

	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g._life._talk_rest = 99.0
	return g


func _station(kind: StringName, at: Vector3, yaw: float) -> Node3D:
	var station: Node3D = GuardStationScript.new()
	station.kind = kind
	add_child(station)
	station.global_position = at
	station.rotation.y = yaw
	return station


func _fresh() -> void:
	for g in get_tree().get_nodes_in_group(&"guards"):
		g.remove_from_group(&"guards")
		g.set_physics_process(false)
		g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"stray_arrows", &"guard_stations", &"gathering_places"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	player.global_position = Vector3(60, 1.05, 28)
	await _frames(5)
	LightProbe.invalidate()


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
