extends Node3D
## The Zócalo (docs/superpowers/specs/2026-10-10-zocalo-district-design.md),
## for now its greybox: the plan (assets/eclipse/zocalo/plan.json) as plain
## blocks to walk (greybox.json, from tools/level/level.sh zocalo). F11 day
## and night.
##   --fps-report=<s>  flies a camera through the plan's cameras for s
##                     seconds, prints "fps: average <a> worst <w>", quits.

const PLAYER := preload("res://Player.tscn")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const PLAN := "res://assets/eclipse/zocalo/plan.json"
const GREYBOX := "res://assets/eclipse/zocalo/greybox.json"
const MOON_COLOUR := Color("#d8e4f0")

var plan: Dictionary
var greybox: GreyboxLoader
var player: CharacterBody3D
var world: WorldEnvironment
var sun: DirectionalLight3D
var moon: DirectionalLight3D

var _day: Environment
var _night: Environment


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	plan = JSON.parse_string(FileAccess.get_file_as_string(PLAN))
	greybox = GreyboxLoader.build(JSON.parse_string(FileAccess.get_file_as_string(GREYBOX)))
	add_child(greybox)
	_lights()
	set_day(true)
	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = spawn_point() + Vector3(0, 1.05, 0)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fps-report="):
			_fps_report.call_deferred(float(arg.trim_prefix("--fps-report=")))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		set_day(not sun.visible)


## Where the player arrives: the plan's spawn, on the street.
func spawn_point() -> Vector3:
	for m in plan["landmarks"]:
		if m["kind"] == "spawn":
			return Vector3(m["at"][0], 0.0, m["at"][-1])

	return Vector3.ZERO


## The plan's cameras: [{"name", "at": Vector3, "look_at": Vector3}].
func cameras() -> Array:
	var out := []

	for m in plan["landmarks"]:
		if m["kind"] == "camera":
			var at: Array = m["at"]
			var look: Array = m["props"]["look_at"]
			out.append({"name": String(m["name"]).trim_prefix("camera_"), "at": Vector3(at[0], at[1], at[2]),
				"look_at": Vector3(look[0], look[1], look[2])})

	return out


func set_day(day: bool) -> void:
	world.environment = _day if day else _night
	sun.visible = day
	moon.visible = not day


func _lights() -> void:
	_night = RetroScript.night_environment()
	_night.background_color = Color(0.03, 0.035, 0.06)
	_day = Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	_day.sky = sky
	_day.background_mode = Environment.BG_SKY
	_day.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_day.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world = WorldEnvironment.new()
	add_child(world)
	moon = DirectionalLight3D.new()
	moon.light_color = MOON_COLOUR
	moon.light_energy = 0.9
	moon.shadow_enabled = true
	add_child(moon)
	moon.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)


func _fps_report(seconds: float) -> void:
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var eye := Camera3D.new()
	eye.fov = 66.0
	add_child(eye)
	eye.make_current()
	var stops := cameras()
	var worst := INF
	var frames := 0
	var elapsed := 0.0

	while elapsed < seconds:
		var k := elapsed / seconds * stops.size()
		var a: Dictionary = stops[int(k) % stops.size()]
		var b: Dictionary = stops[(int(k) + 1) % stops.size()]
		var t := k - floorf(k)
		var at: Vector3 = a["at"].lerp(b["at"], t)
		eye.global_transform = Transform3D(Basis(), at).looking_at(a["look_at"].lerp(b["look_at"], t), Vector3.UP)
		await get_tree().process_frame
		var delta := get_process_delta_time()
		elapsed += delta
		frames += 1

		if frames > 30:
			worst = minf(worst, 1.0 / maxf(delta, 1e-6))

	print("fps: average %.1f worst %.1f over %d frames" % [frames / maxf(elapsed, 1e-6), worst, frames])
	get_tree().quit()
