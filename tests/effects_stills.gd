extends Node3D
## The street's ambient effects side by side (the scenes plan, Task 4), by
## day and by night, with a flock of pigeons in front. In a window:
##   Godot --path . --resolution 1600x900 res://tests/effects_stills.tscn -- --out=/tmp/fx
## effects_day.png, effects_night.png.

const EFFECTS := ["steam", "copal", "smoke", "embers", "mist", "petals", "leaves", "dust", "canal_fog", "candles"]
const GAP := 3.2

var out := "/tmp/fx/"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"

	DirAccess.make_dir_recursive_absolute(out)
	var list := []

	for k in EFFECTS.size():
		var e := {"effect": EFFECTS[k], "at": [k * GAP, 4.0 if EFFECTS[k] == "leaves" else 0.0, 0.0]}

		if EFFECTS[k] == "leaves":
			e["floor"] = 0.0

		list.append(e)

	var width := EFFECTS.size() * GAP
	add_child(Ground.build(Rect2(-10, -20, width + 20, 40), [], [], 3, {"tile": &"ground_flags", "level": -0.003}))

	for k in EFFECTS.size():
		var label := Label3D.new()
		label.text = EFFECTS[k]
		label.pixel_size = 0.012
		label.position = Vector3(k * GAP, 0.05, 1.4)
		label.rotation.x = -PI / 2
		add_child(label)

	var ambient := Ambient.build(list)
	var gusts := Gusts.new()
	add_child(gusts)
	ambient.gusts = gusts
	add_child(ambient)
	var pigeons := Pigeons.build([{"at": [width * 0.5, 0, 4.0], "count": 14, "radius": 2.0}],
		KitLoader.meshes("figures_kit")["pigeon"])
	pigeons.get_child(0).material_override = KitLoader.material("figures_kit")
	add_child(pigeons)
	var environment := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-30), 0)
	var eye := Camera3D.new()
	eye.fov = 70.0
	add_child(eye)
	eye.make_current()
	eye.global_transform = Transform3D(Basis(), Vector3(width * 0.45, 2.4, 7.5)).looking_at(Vector3(width * 0.45, 1.0, 0), Vector3.UP)
	await _seconds(5.0)
	_save("effects_day.png")
	sun.light_energy = 0.03
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.025, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.05, 0.06, 0.09)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#e8d8a8")
	lamp.omni_range = 16.0
	lamp.light_energy = 1.6
	lamp.position = Vector3(width * 0.45, 5.0, 2.0)
	add_child(lamp)
	ambient.set_day(false)
	await _seconds(4.0)
	_save("effects_night.png")
	get_tree().quit()


func _seconds(s: float) -> void:
	var start := Time.get_ticks_msec()

	while Time.get_ticks_msec() - start < s * 1000.0:
		await get_tree().process_frame

	# (A frame drawn now, not the last one the window drew.)
	RenderingServer.force_draw()


func _save(file: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + file)
	print("still: ", out + file)
