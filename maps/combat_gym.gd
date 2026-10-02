extends Node3D
## Builds a small combat test yard with player weapons, guards and a navigation bake.
## Uses the production combat and stimulus systems; F3 enables gameplay diagnostics.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Lights := preload("res://scripts/Visual/Lights/Lights.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")

const STONE := Color(0.4, 0.38, 0.36)
const DARK := Color(0.22, 0.21, 0.23)


func _ready() -> void:
	# Everything below is placed after it is added: draw it from where it ends up.
	reset_physics_interpolation.call_deferred()
	tree_exiting.connect(func(): SoundBus.debug = false)
	_environment()

	Props.block(self, Vector3(0, -0.5, -10), Vector3(60, 1, 60), DARK)

	# --- the duel: a lit yard, one guard on post ------------------------------
	_torch(Vector3(-12, 3.0, -6))
	_torch(Vector3(-4, 3.0, -6))
	_guard(Vector3(-8, 0, -10), 0.0, "Duellist", &"swordsman")
	_sign(Vector3(-8, 2.2, 1.5), "THE DUEL\nLMB attacks. Hold it to charge a power blow. Click again mid-swing: a combo.\nStrafe while attacking for a side slash, walk in for a thrust.\nRMB blocks. Block just before his blade falls: a parry, then a quick riposte.\nRMB during your own windup: a feint.   Q: dodge.\nHis sword goes up before it comes down. Watch it.\n(The full proving grounds: maps/combat_arena.tscn)")

	# --- the spikes: a guard with his back to them ----------------------------
	Props.spikes(self, Vector3(8, 1.0, -14.0), 4.0, 2.0, Vector3.BACK)
	Props.block(self, Vector3(8, 1.2, -14.3), Vector3(4.2, 2.4, 0.6), STONE)
	_torch(Vector3(8, 3.0, -9))
	_guard(Vector3(8, 0, -12.6), PI, "Gatekeeper")
	_sign(Vector3(8, 2.2, 1.5), "THE SPIKES\nF kicks. Kick him into the spikes.\nA kicked guard slides with no say in where he goes.")

	# --- the ledge: a platform with stairs, a guard at its edge ----------------
	Props.block(self, Vector3(20, 3.0, -14), Vector3(6, 6, 6), STONE)
	for i in 20:
		var top := 0.3 * (i + 1)
		Props.block(self, Vector3(24.0 + 0.3 * i + 0.15, top * 0.5, -12.5), Vector3(0.3, top, 3.0), STONE)
	_torch(Vector3(20, 8.5, -11))
	_guard(Vector3(20, 6.0, -11.6), PI, "Lookout")
	_sign(Vector3(20, 2.2, 1.5), "THE LEDGE\nClimb the stairs, and kick him off.\nSix metres is too far to fall.")

	# --- the archery hall: dark, with guards at range --------------------------
	Props.block(self, Vector3(-20, 1.5, -30), Vector3(12, 3, 0.4), STONE)
	_guard(Vector3(-22, 0, -24), PI * 0.5, "Sentry")
	_guard(Vector3(-17, 0, -27), 0.0, "Watchman")
	_sign(Vector3(-20, 2.2, -12), "THE ARCHERY HALL\nMouse wheel to the bow. Hold LMB to draw, release to loose.\nRMB lets the string down. Aim high at range: arrows drop.\nA miss sticks where it lands, is heard there, and can be taken back.\nA headshot at full draw kills.")

	# --- things to kick ------------------------------------------------------------
	Props.crate(self, Vector3(-2, 0.3, 4), 0.5, 5.0)
	Props.crate(self, Vector3(-1, 0.25, 4.5), 0.4, 3.0)
	Props.block(self, Vector3(3.5, 1.25, 6), Vector3(5.0, 2.5, 0.3), STONE)
	Props.block(self, Vector3(9.5, 1.25, 6), Vector3(5.0, 2.5, 0.3), STONE)
	Props.block(self, Vector3(6.5, 2.3, 6), Vector3(1.0, 0.4, 0.3), STONE)
	Props.door(self, Vector3(6.0, 0, 6))
	_sign(Vector3(3, 2.2, 9.5), "KICK THINGS\nCrates fly. Unlocked doors burst open.\nAdrenaline (the amber bar) fills as you fight.\nWhen it glows, your next power blow is a finisher.")

	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	var player := PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = Vector3(0, 1.05, 12)
	Props.give_weapons(player)
	player.inventory.select_by_id(&"sword")


func _guard(at: Vector3, yaw: float, speaker: String, archetype: StringName = &"") -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.archetype = archetype
	g.speaker_name = speaker
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	return g


## A torch, its flame at `at`: in a sconce on the wall there, or on a pole
## cresset (Lights.torch_at).
func _torch(at: Vector3) -> void:
	# One of the level's own: you can put it out (the guards light it again).
	Lights.torch_at(self, at, 2.4, 10.0, true, {"can_douse": true})


func _sign(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 32
	label.pixel_size = 0.008
	label.modulate = Color(0.95, 0.9, 0.8)
	label.outline_size = 8
	label.shaded = false
	add_child(label)
	label.global_position = at


func _environment() -> void:
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.light_volumetric_fog_energy = 2.0
	add_child(moon)
	moon.rotation_degrees = Vector3(-50.0, 30.0, 0.0)

	# The retro night, lit enough to read a fight: fog halos on the torches,
	# glow on sparks, and a moonlit ambient you can see a blade by.
	var environment := RetroScript.night_environment(Color(0.36, 0.4, 0.55), 0.3)
	environment.background_color = Color(0.03, 0.04, 0.07)
	environment.volumetric_fog_density = 0.025

	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
