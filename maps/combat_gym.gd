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
const DummyScript := preload("res://scripts/Combat/TrainingDummy.gd")
const WeaponScript := preload("res://scripts/Combat/Weapon.gd")

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

	_range_bay()

	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	var player := PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = Vector3(0, 1.05, 12)
	Props.give_weapons(player)
	Props.give_revolver(player)
	player.inventory.select_by_id(&"sword")
	# Opt-in launch for repeated gun/magic feel tests; the normal gym is unchanged.
	if "--range" in OS.get_cmdline_user_args():
		player.teleport(Transform3D(Basis.IDENTITY, Vector3(40, 1.05, -12)))
		player.inventory.select_by_id(&"revolver")
		player.inventory.add_ammo(&"rounds", 96)
		player.inventory.add_ammo(&"shells", 20)
		player.invulnerable = true


## The range: the revolver and the spells. Dummies at 5, 15 and 30 m, a wall
## to read the shell's spread on, three men among pillars to fight, and
## rounds, shells and the tome on a table.
func _range_bay() -> void:
	Props.block(self, Vector3(45, -0.5, -28), Vector3(30, 1, 40), DARK)
	_torch(Vector3(38, 3.0, -12))
	_torch(Vector3(52, 3.0, -30))
	_torch(Vector3(42, 3.0, -44))

	for reach in [5.0, 15.0, 30.0]:
		var dummy: StaticBody3D = DummyScript.new()
		add_child(dummy)
		dummy.global_position = Vector3(40, 0, -12.0 - reach)
		dummy.rotation.y = PI

	# Shoot the wall with the shell: its pellets show where they went.
	Props.block(self, Vector3(46, 1.5, -20), Vector3(3, 3, 0.3), STONE)
	_sign(Vector3(46, 3.4, -19.8), "THE SPREAD")

	# Three men among pillars: shoot past them and they take cover; reload
	# and they come for you.
	for at in [Vector3(51, 1.5, -34), Vector3(56, 1.5, -34), Vector3(53.5, 1.5, -40)]:
		Props.block(self, at, Vector3(1.2, 3, 1.2), STONE)

	_guard(Vector3(51, 0, -37), 0.0, "Sentry")
	_guard(Vector3(54, 0, -37), 0.0, "Watchman")
	_guard(Vector3(56, 0, -42), 0.0, "Gatekeeper")

	# A table: rounds, shells, the tome.
	Props.block(self, Vector3(36, 0.45, -11), Vector3(1.6, 0.9, 0.8), STONE)
	Props.ammo(self, Vector3(35.6, 1.0, -11), &"rounds", 24)
	Props.ammo(self, Vector3(36.0, 1.0, -11), &"shells", 6)
	var tome := MeshInstance3D.new()
	tome.mesh = WeaponScript.tome_mesh()
	add_child(tome)
	tome.global_position = Vector3(36.4, 0.95, -11)
	tome.rotation = Vector3(-PI * 0.5, 0.0, 0.0)

	_sign(Vector3(40, 2.6, -9.5), "THE RANGE\nMouse wheel to the revolver. LMB fires. RMB aims down the sights. R reloads, round by round (fire to stop).\nX flips to the shot barrel (one shell): point-blank it bursts a man. F: pistol-whip up close, else the kick.\nHold 1 Shard, 2 Ward, 3 Empower (the tome) while each forms; let go early and nothing is spent.\nQ: Blink (tap a step, hold to aim; onto a ledge's lip to hang). Ward stops shots and spells, not blades.")


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


func _unhandled_key_input(event: InputEvent) -> void:
	if "--range" in OS.get_cmdline_user_args() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		get_tree().reload_current_scene()
