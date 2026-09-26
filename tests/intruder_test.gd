extends Node3D
## The intruder of the NPC showcase: a guard's body with the guard's mind
## switched off (Guard.puppet), who answers to the guards as the player does
## (Intruder.gd, IntruderCombat.gd) and is driven by the director
## (IntruderBrain.gd).
##
##   Godot --headless --fixed-fps 60 --quit-after 40000 --path . res://tests/intruder_test.tscn

const GUARD := preload("res://Guard.tscn")
const INTRUDER := preload("res://Intruder.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")

const RELAXED := 0
const SUSPICIOUS := 1
const INVESTIGATING := 2
const SEARCHING := 3
const COMBAT := 4

## The near-black the intruder's outfit is dyed.
const DYE := Color(0.07, 0.07, 0.08)

var results: Array[String] = []
var _barks := {}


func _ready() -> void:
	TemperamentScript.rolling = false
	GuardScript.bleeding_on = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(400, 1, 60))

	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	# I1 he is the one the guards are after, not one of them, and deaf
	await _fresh()
	var i1 := _intruder(Vector3(0, 0, 0))
	await _frames(5)
	_check("I1 the intruder is in the player group, not the guards group, and not a SoundBus listener",
		i1.is_in_group(&"player") and not i1.is_in_group(&"guards") and not SoundBus._listeners.has(i1),
		"player %s guards %s listener %s" % [i1.is_in_group(&"player"), i1.is_in_group(&"guards"), SoundBus._listeners.has(i1)])

	# I2 dressed as the archer, in near-black, a sword in his hand
	var man: Node = i1._rig.man
	var look: Variant = man.get("look")
	var dressed: bool = look is Dictionary and not (look as Dictionary).is_empty()
	var dyed: bool = not dressed or ((look as Dictionary).get("dye", Color.WHITE) as Color).is_equal_approx(DYE)
	_check("I2 his look is the archer outfit dyed near-black, with a sword",
		i1._rig._carried == &"sword" and dyed,
		"carried %s, dressed %s, dye %s" % [i1._rig._carried, dressed, (look as Dictionary).get("dye", "-") if dressed else "painted"])

	# I3 a guard in the light beside him: the guard reacts, he does not
	await _fresh()
	_light(Vector3(40, 3, 0))
	var i3 := _intruder(Vector3(40, 0, 0))
	var g3 := _guard(&"", Vector3(40, 0, 5), 0.0)
	_barks[i3] = []
	i3.barked.connect(func(t): _barks[i3].append(t))
	await _frames(30)
	# A shout right beside him, and a guard beside him: nothing stirs him.
	SoundBus.emit_sound(i3.global_position + Vector3(1, 1, 0), 75.0, g3, &"shout")
	await _frames(300)
	_check("I3 he never barks, and his state and alert never change by themselves (a shout beside him, a guard in light)",
		_barks[i3].is_empty() and i3.state == RELAXED and i3.alert == 0.0,
		"his barks %s, his state %d, his alert %.1f" % [_barks[i3], i3.state, i3.alert])

	# I4 killed, he is nobody's friend: no body to find, no post, no dread
	await _fresh()
	var i4 := _intruder(Vector3(80, 0, 0))
	var g4 := _guard(&"", Vector3(80, 0, 2), PI)
	await _frames(10)
	var garrison4: RefCounted = GarrisonScript.of(i4)
	i4.take_hit(999.0, g4, &"quick", i4.global_position + Vector3.UP, Vector3.BACK)
	await _frames(10)
	var bodies := get_tree().get_nodes_in_group(&"bodies")
	_check("I4 killed, he leaves no body in \"bodies\", no fallen post in the garrison, and no dread",
		bodies.is_empty() and garrison4.fallen.is_empty() and garrison4.dread == 0.0,
		"bodies %d, fallen %s, dread %.2f" % [bodies.size(), garrison4.fallen, garrison4.dread])


func _intruder(at: Vector3) -> CharacterBody3D:
	var i: CharacterBody3D = INTRUDER.instantiate()
	i.position = at
	add_child(i)
	return i


func _guard(archetype: StringName, at: Vector3, yaw := 0.0, preset: StringName = &"steady") -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.temperament = preset
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	_barks[g] = []
	g.barked.connect(func(t): _barks[g].append(t))
	return g


func _light(at: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.omni_range = 12.0
	lamp.light_energy = 3.0
	lamp.add_to_group(&"test_lights")
	add_child(lamp)
	lamp.global_position = at
	LightProbe.invalidate()


## A clean start: nobody left, nothing lying about, nothing remembered.
func _fresh() -> void:
	for group in [&"guards", &"player"]:
		for g in get_tree().get_nodes_in_group(group):
			g.remove_from_group(group)
			g.set_physics_process(false)
			g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"test_lights", &"stray_arrows"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	LightProbe.invalidate()
	await _frames(3)


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
