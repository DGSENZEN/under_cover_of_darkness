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
