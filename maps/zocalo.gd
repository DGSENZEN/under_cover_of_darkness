extends Node3D
## The Zócalo (docs/superpowers/specs/2026-10-10-zocalo-district-design.md),
## its greybox: the plan (assets/eclipse/zocalo/plan.json) as plain blocks
## to walk (greybox.json, from tools/level/level.sh zocalo), dressed in the
## kits built so far (dressing.json: the street and canal kit's pieces and
## the ground round them), its scenes staged (their stand-ins, trees,
## effects, pigeons), the district's wind on them. F11 day and night; F1
## labels the scenes near with their stories.
##   --undressed       the greybox alone
##   --fps-report=<s>  flies a camera through the plan's cameras for s
##                     seconds, prints "fps: average <a> worst <w>", quits.

const PLAYER := preload("res://Player.tscn")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const PLAN := "res://assets/eclipse/zocalo/plan.json"
const GREYBOX := "res://assets/eclipse/zocalo/greybox.json"
const DRESSING := "res://assets/eclipse/zocalo/dressing.json"
const MOON_COLOUR := Color("#d8e4f0")

## The greybox alone (as --undressed), set before it enters the tree.
@export var undressed := false

var plan: Dictionary
var greybox: GreyboxLoader
## The dressing laid (empty when undressed), its pieces and its ground.
var dressing: Dictionary
var kit: KitLoader
var ambient: Ambient
var pigeons: Pigeons
var gusts: Gusts
## The wind on what drifts down (Vfx.wind_attractor), steered by the Gusts.
var wind_attractor: GPUParticlesAttractorBox3D
var district_ground: DistrictGround
var player: CharacterBody3D
var world: WorldEnvironment
var sun: DirectionalLight3D
var moon: DirectionalLight3D

var _day: Environment
var _night: Environment


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	var started := Time.get_ticks_msec()
	plan = JSON.parse_string(FileAccess.get_file_as_string(PLAN))

	if FileAccess.file_exists(DRESSING) and not undressed and not "--undressed" in OS.get_cmdline_user_args():
		dressing = JSON.parse_string(FileAccess.get_file_as_string(DRESSING))

	greybox = GreyboxLoader.build(JSON.parse_string(FileAccess.get_file_as_string(GREYBOX)), dressing.get("skip", []))
	add_child(greybox)

	if dressing:
		district_ground = DistrictGround.build(dressing["ground"], 11)
		add_child(district_ground)
		kit = KitLoader.build(dressing)
		add_child(kit)
		gusts = Gusts.new()
		add_child(gusts)
		ambient = Ambient.build(dressing.get("emitters", []))
		ambient.gusts = gusts
		add_child(ambient)
		# What drifts down lands on the ground round the camera and blows
		# with the Gusts.
		Vfx.heightfield(self)
		wind_attractor = Vfx.wind_attractor()
		add_child(wind_attractor)
		pigeons = Pigeons.build(dressing.get("flocks", []), KitLoader.meshes("figures_kit")["pigeon"])
		pigeons.get_child(0).material_override = KitLoader.material("figures_kit")
		add_child(pigeons)

	_lights()
	set_day(true)
	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = spawn_point() + Vector3(0, 1.05, 0)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fps-report="):
			_fps_report.call_deferred(float(arg.trim_prefix("--fps-report=")))
		elif arg == "--load-report":
			print("load: %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
			get_tree().quit.call_deferred()


func _process(_delta: float) -> void:
	if wind_attractor != null:
		var camera := get_viewport().get_camera_3d()
		Vfx.steer(wind_attractor, gusts.wind(), camera.global_position if camera != null else Vector3.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		set_day(not sun.visible)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_labels(get_node_or_null("labels") == null)


## The scenes' labels (F1): each scene's name and story over it, seen within
## 40 m; off again.
func _labels(on: bool) -> void:
	var old := get_node_or_null("labels")

	if old:
		old.free()

	if not on or not dressing:
		return

	var group := Node3D.new()
	group.name = "labels"
	add_child(group)

	for s in dressing.get("scenes", []):
		var label := Label3D.new()
		label.text = "%s — %s" % [s["name"], s["story"]]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.width = 900.0
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.visibility_range_end = 40.0
		label.position = Vector3(s["at"][0], s["at"][1] + 2.6, s["at"][2])
		group.add_child(label)


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

	if kit:
		kit.set_day(day)

	if ambient:
		ambient.set_day(day)


func _lights() -> void:
	_night = RetroScript.night_environment()
	_night.background_color = Color(0.03, 0.035, 0.06)
	# The night's fog reaches over the sky: each lamp a halo against it.
	_night.volumetric_fog_sky_affect = 0.5
	_day = Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	_day.sky = sky
	_day.background_mode = Environment.BG_SKY
	_day.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_day.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Volumetric fog on at no density: the seeped mist and the copal's haze
	# (fog volumes) draw by day too.
	_day.volumetric_fog_enabled = true
	_day.volumetric_fog_density = 0.0
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
