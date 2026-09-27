## Visual check, not a test: the whole HUD at once, at whatever size the
## window is. A man ahead makes you out (his mark, and beside it what he is
## doing about you); one behind you heard something (his mark at the bottom
## edge); a torch in front of you (the prompt under the crosshair); a long
## line said near you (the subtitle, wrapped); what came into your hand (the
## caption); hurt (the shields); the old movement on (its tag). Last, the
## pause screen. Run it at several sizes and compare:
##   Godot --fixed-fps 60 --resolution 1920x1080 --path . res://tests/visual/stage_hud.tscn -- --out=/some/folder
extends Node3D

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var out_dir := "user://hud/"
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out_dir)
	Sfx.volume_db = -60.0
	TemperamentScript.rolling = false
	Props.block(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color(0.3, 0.29, 0.28))
	Props.block(self, Vector3(0, 2, -24), Vector3(30, 4, 0.4), Color(0.42, 0.4, 0.38))
	Props.block(self, Vector3(1.5, 1.5, -2.6), Vector3(3, 3, 0.4), Color(0.42, 0.4, 0.38))

	for at in [Vector3(-4, 3.0, -12), Vector3(4, 3.0, -12), Vector3(0, 3.0, 2)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.72, 0.42)
		lamp.light_energy = 1.8
		lamp.omni_range = 12.0
		add_child(lamp)
		lamp.global_position = at

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.03, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.38, 0.5)
	environment.ambient_light_energy = 0.3
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.invulnerable = true
	player.reload_on_death = false
	player.show_hud = true
	player.global_position = Vector3(0, 1.05, -0.9)
	player.debug_light_level = 0.0
	await baker.baked

	# A torch on the wall just ahead, a little to the right: the prompt.
	var torch: Node3D = TorchScript.new()
	torch.can_douse = true
	add_child(torch)
	torch.global_position = Vector3(0.9, 1.6, -2.35)
	var ahead := _man(Vector3(-2.5, 0, -10), PI)
	var behind := _man(Vector3(1.5, 0, 9), 0.0)
	# He only hears you.
	behind.vision_gain = 0.0
	await _frames(30)
	SoundBus.emit_sound(Vector3(1, 0, 6), 50.0, self, &"test")
	player.debug_light_level = 0.4
	# Looking at the torch.
	var eye: Transform3D = player.aim_transform()
	var to := torch.global_position - eye.origin
	player.rotation.y = atan2(-to.x, -to.z)
	player.neck.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.set("legacy_feel", true)
	player.hud._shield_timer = 30.0
	player.hud._shields.fraction = 0.6
	player.health = player.max_health * 0.6
	await _frames(40)
	player.hud._on_bark("Did you hear that? Something moved down by the old well, past the cart and the barrels. Go and have a look, and take a light with you.", behind)
	player.hud.show_caption("Water flask", 30.0)
	await _frames(12)
	await _shot("hud_all")
	print("hud: ahead state %d alert %.0f, behind state %d; view %s window %s" % [int(ahead.state), ahead.alert, int(behind.state), get_viewport().get_visible_rect().size, get_tree().root.size])

	for mark in player.hud.awareness_marks():
		print("  mark %s at %s says '%s %s' words %.2f" % [mark["icon"], mark["at"], mark["name"], mark["says"], float(mark["words"])])

	for key in player.hud.layout_rects():
		print("  %s %s" % [key, player.hud.layout_rects()[key]])

	# The pause screen.
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	player._unhandled_input(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("hud_paused")
	Sfx.silence()
	get_tree().paused = false
	await get_tree().process_frame
	get_tree().quit()


func _man(at: Vector3, yaw: float) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._habits._wait = 999.0
	g._life._talk_rest = 999.0
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	return g


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
