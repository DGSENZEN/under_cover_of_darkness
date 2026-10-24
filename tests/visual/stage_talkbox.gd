extends Node3D
## Windowed visual QA: the talk box (draft 28's layout, the plain skin) over
## a shade at night, with the HUD around it and the live portrait:
##   reveal_015/030/045   painting in, 0.15, 0.3 and 0.45 s after it opens
##   line                 her line told out
##   options              four options, the first chosen, one special
##   options_special      the special one chosen (repainted)
##   close_mid            lifting off, 0.17 s into closing
##   paused               Esc: the pause screen over the box
##   librarian            the librarian's (red) line and options
## The staging library gives her four options and a longer line (staging
## only; the fixture files are left as they are).
## Godot --fixed-fps 60 --resolution 1920x1080 --path . res://tests/visual/stage_talkbox.tscn -- --out=/tmp/box

const PLAYER := preload("res://Player.tscn")
const SHADE := preload("res://scripts/Interaction/Shade.gd")
const DialogueBook := preload("res://scripts/Level/DialogueBook.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")

var _out := "/tmp/box/"
var player: CharacterBody3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=").trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(0, true)
	var library := DialogueBook.load_dir("res://tests/fixtures/dialogue")
	_stage(library)
	DialogueBook.use(library)
	CityState.begin()
	CityState.people.load_state({})
	_night()

	var shade: StaticBody3D = SHADE.new()
	shade.character = "fx_curandera"
	add_child(shade)
	shade.rotation.y = PI
	player = PLAYER.instantiate()
	add_child(player)
	player.reload_on_death = false
	player.invulnerable = true
	player.global_position = Vector3(0.3, 1.05, 1.9)
	await _frames(60)
	_aim(shade.head_point())
	await _frames(20)
	await _shot("before")

	player.frob.talk(shade)
	var box: Node = player.frob.talking()
	await _frames(9)
	await _shot("reveal_015")
	await _frames(9)
	await _shot("reveal_030")
	await _frames(9)
	await _shot("reveal_045")
	await _frames(60)
	await _shot("line")

	while box.shown_options().is_empty():
		box.press_advance()
		await _frames(2)

	await _frames(40)
	await _shot("options")
	box.choose_by_pointing(box.shown_options().find("<<A special option.>>"))
	await _frames(5)
	await _shot("options_special_repaint")
	await _frames(20)
	await _shot("options_special")
	box.choose_by_pointing(0)
	await _frames(20)

	# Esc: paused, the pause screen over the box.
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("paused")
	player.hud.resume()
	await _frames(10)

	box.select(box.shown_options().find("<<Leave.>>"))
	await _frames(10)
	await _shot("close_mid")
	await _frames(40)
	shade.queue_free()

	var librarian: StaticBody3D = SHADE.new()
	librarian.character = "fx_librarian"
	add_child(librarian)
	librarian.rotation.y = PI
	await _frames(60)
	_aim(librarian.head_point())
	await _frames(10)
	player.frob.talk(librarian)
	box = player.frob.talking()
	await _frames(60)

	while box.shown_options().is_empty():
		box.press_advance()
		await _frames(2)

	await _frames(40)
	await _shot("librarian")
	box.interrupt()
	await _frames(10)
	get_tree().quit()


## Staging only: her opener says a longer line and offers four options, one
## special, with no inner voice between.
func _stage(library: Dictionary) -> void:
	var her: Dictionary = library["characters"]["fx_curandera"]
	var opener: Dictionary = her["beats"]["open_first"]
	var body: Array = opener["body"].filter(func(item): return String(item["type"]) != "sense")

	for item in body:
		if String(item["type"]) == "say":
			item["text"] = "<<Stand still, joven. The smoke tells me who walked behind you.>>"

	var at := body.size() - 1
	body.insert(at, {"type": "option", "text": "<<A special option.>>", "special": true, "if": "", "to": "end", "do": [], "type_only": false})
	opener["body"] = body


func _aim(point: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var to := point - eye
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Neck").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _night() -> void:
	var world := WorldEnvironment.new()
	world.environment = RetroScript.night_environment()
	add_child(world)
	_box(Vector3(0.0, -0.5, 0.0), Vector3(16.0, 1.0, 16.0), Color(0.3, 0.3, 0.31))
	_box(Vector3(0.0, 2.0, -3.0), Vector3(8.0, 4.0, 0.4), Color(0.42, 0.43, 0.46))
	_box(Vector3(1.7, 1.35, -0.9), Vector3(0.1, 2.7, 0.1), Color(0.12, 0.11, 0.1))
	_box(Vector3(1.45, 2.68, -0.9), Vector3(0.5, 0.05, 0.05), Color(0.12, 0.11, 0.1))
	var lantern := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(0.18, 0.24, 0.18)
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_color = Color(1.0, 0.85, 0.6) * 2.0
	cube.material = glass
	lantern.mesh = cube
	lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lantern)
	lantern.position = Vector3(1.25, 2.52, -0.9)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.6)
	lamp.light_energy = 2.2
	lamp.omni_range = 7.0
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.position = Vector3(1.2, 2.35, -0.75)


func _box(center: Vector3, size: Vector3, colour: Color) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	cube.material = material
	mesh.mesh = cube
	body.add_child(mesh)
	add_child(body)
	body.global_position = center


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + label + ".png")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
