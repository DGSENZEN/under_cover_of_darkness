## Visual check: every light fixture in the lights gallery, near and far, lit
## and out, laid on one review sheet; and the lightgem beside the torch, the
## brazier and the campfire against main's readings (see stage_combat.gd).
extends Node3D
## Windowed staging for the lights:
##
##   Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_lights.tscn -- --out=<dir>
##
## Each fixture framed at 1, 3 and 8 m, lit and then out, through the Retro
## pass; one wide shot a bay (its frame time logged); sheet.png, a labelled
## row a fixture (tests/visual/lights_sheet.py, Pillow). Then the lightgem
## 2 m from each light, PASS or FAIL against MAIN_GEM (within 10%).
##
## --gem-only: just the lightgem readings, with nothing but what main has too
## (how MAIN_GEM was read on main).

const OUT_DEFAULT := "user://shots/"
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
const FireScript := preload("res://scripts/Combat/Fire.gd")
const Furnishings := preload("res://scripts/Interaction/Furnishings.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const PLAYER := preload("res://Player.tscn")

## The lightgem 2 m from a bare torch, the brazier and the campfire (their
## flicker held still), read on main (44563df) by --gem-only: the mean of
## two runs, which differed by about 1%.
const MAIN_GEM := [0.4772, 0.5520, 0.4862]
const GEM_NAMES := ["torch", "brazier", "campfire"]
## How far from a fixture each shot is taken, and how far down it looks.
const DISTANCES := [1.0, 3.0, 8.0]
const LOOK_DOWN := 0.18
## Inside the gallery's hall, with a little room to spare: no shot is taken
## from inside a wall.
const HALL := AABB(Vector3(-19.7, 0.2, -5.7), Vector3(39.4, 5.5, 11.4))
## Turns (degrees) from a fixture's own way out tried for a clear view.
const TURNS := [0.0, 40.0, -40.0, 80.0, -80.0, 120.0, -120.0, 180.0]
const SHEET_SCRIPT := "res://tests/visual/lights_sheet.py"

## Where screenshots go: user://shots/, or --out=<folder> after "--".
var out_dir := OUT_DEFAULT
var camera: Camera3D


func _ready() -> void:
	var gem_only := false

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6).trim_suffix("/") + "/"
		elif arg == "--gem-only":
			gem_only = true

	Sfx.volume_db = -60.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if not gem_only:
		await _sheet()

	await _gem(not gem_only)
	Sfx.silence()
	await _frames(3)
	get_tree().quit()


# The sheet

func _sheet() -> void:
	var gallery: Node3D = load("res://maps/lights_gallery.tscn").instantiate()
	add_child(gallery)
	await _frames(90)
	# Out of the way: the watchmen, and you (in the closet, your view hidden).
	for man in get_tree().get_nodes_in_group(&"guards"):
		man.queue_free()

	var player: CharacterBody3D = gallery.player
	player.invulnerable = true
	player.global_position = Vector3(-21.2, 1.05, 4.0)

	if player.hud != null:
		player.hud.visible = false

	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 70.0
	await _frames(10)
	var rows: Array[String] = []

	for bay in gallery.BAYS.size():
		var x: float = gallery.BAYS[bay]
		var name := "bay_%d" % (bay + 1)
		var frame_ms := await _shoot_timed(name, Vector3(x, 1.8, 5.2), Vector3(x, 1.4, -4.0))
		print("stage_lights: bay %d (%s) %.2f ms a frame" % [bay + 1, gallery.BAY_NAMES[bay], frame_ms])

	for fixture in _fixtures(gallery):
		var key := String(fixture.fixture)
		rows.append(key)
		var target := _middle(fixture)
		var out := _outward(fixture)

		for lit in [true, false]:
			if lit:
				fixture.kindle(true)
			else:
				fixture.put_out(&"snuff", true)

			for d in DISTANCES:
				var at := _vantage(fixture, target, out, d)
				await _shoot("%s_%s_%dm" % [key, "lit" if lit else "out", int(d)], at, target)

		fixture.kindle(true)

	var listing := FileAccess.open(out_dir + "rows.txt", FileAccess.WRITE)
	listing.store_string("\n".join(rows) + "\n")
	listing.close()
	var output: Array = []
	var code := OS.execute("python3", [ProjectSettings.globalize_path(SHEET_SCRIPT), ProjectSettings.globalize_path(out_dir)], output, true)
	print("stage_lights: sheet %s %s" % ["written" if code == 0 else "FAILED", "".join(output).strip_edges()])
	gallery.queue_free()
	camera.queue_free()
	camera = null
	await _frames(10)


## The gallery's fixtures, each once, in bay order (not the watchmen's).
func _fixtures(gallery: Node3D) -> Array:
	var found: Array = []
	var seen := {}

	for burner in gallery.burners():
		var fixture = burner.get("fixture")

		if fixture == null or fixture == &"" or seen.has(fixture) or String(fixture).begins_with("carried"):
			continue

		seen[fixture] = true
		found.append(burner)

	found.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	return found


## The middle of a fixture's flames.
func _middle(fixture: Node3D) -> Vector3:
	var sum := Vector3.ZERO

	for point in fixture.flame_points:
		sum += fixture.global_transform * point

	return sum / float(maxi(fixture.flame_points.size(), 1))


## Which way to stand back from it: out from its wall, else toward the walk.
func _outward(fixture: Node3D) -> Vector3:
	if fixture.spec_data.get("mount", "") == "wall":
		var out: Vector3 = fixture.global_basis.z
		return Vector3(out.x, 0.0, out.z).normalized()

	return Vector3.BACK


## Where to stand `d` from `target`: out its own way if that is inside the
## hall and nothing stands between, else the nearest turn that is; else the
## clearest, brought in short of what is in the way.
func _vantage(fixture: Node3D, target: Vector3, out: Vector3, d: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var own: Array[RID] = fixture.get("_bodies")
	var best := target + out * 0.5
	var clearest := -1.0

	for turn in TURNS:
		var way := out.rotated(Vector3.UP, deg_to_rad(turn))
		var at := target + way * d * cos(LOOK_DOWN) + Vector3.UP * d * sin(LOOK_DOWN)
		var query := PhysicsRayQueryParameters3D.create(target, at, 1, own)
		var hit := space.intersect_ray(query)

		if hit.is_empty() and HALL.has_point(at):
			return at

		var reach: float = target.distance_to(hit["position"]) - 0.3 if not hit.is_empty() else d

		if reach > clearest:
			clearest = reach
			best = target + (at - target).normalized() * minf(reach, d)

	return best


func _shoot(shot_name: String, at: Vector3, target: Vector3) -> void:
	camera.global_position = at
	camera.look_at(target)
	camera.current = true
	await _frames(12)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + shot_name + ".png")


## A shot, and the average frame time over a second there (real time: the
## stager runs at fixed fps).
func _shoot_timed(shot_name: String, at: Vector3, target: Vector3) -> float:
	await _shoot(shot_name, at, target)
	var start := Time.get_ticks_usec()

	for i in 60:
		await get_tree().process_frame

	return float(Time.get_ticks_usec() - start) / 60000.0


# The lightgem

## You 2 m from a bare torch, the brazier and the campfire in turn (each
## flicker held still), your lightgem read after 60 frames; `wall_too`, and
## 2 m out from a wall torch in its sconce (the maps' torches now), held to
## the bare torch's reading on main.
func _gem(wall_too: bool) -> void:
	var stage := Node3D.new()
	add_child(stage)
	Props.block(stage, Vector3(0, -0.5, 0), Vector3(120, 1, 20))
	var torch: Node3D = TorchScript.new()
	stage.add_child(torch)
	torch.global_position = Vector3(0, 2.2, 0)
	var fire: Area3D = FireScript.brazier(stage, Vector3(20, 0, 0))
	var camp: Node3D = Furnishings.campfire(stage, Vector3(40, 0, 0))
	var player: CharacterBody3D = PLAYER.instantiate()
	stage.add_child(player)
	await _frames(10)
	var burners := [torch, _burner_in(fire.get_parent()), _burner_in(camp)]
	var names: Array = GEM_NAMES.duplicate()
	var baselines: Array = MAIN_GEM.duplicate()

	if wall_too:
		# Not on main: loaded, not preloaded, so --gem-only runs there.
		var lights: GDScript = load("res://scripts/Visual/Lights/Lights.gd")
		Props.block(stage, Vector3(60, 2, -0.6), Vector3(4, 4, 0.4))
		var reach := float(load("res://scripts/Visual/Lights/LightFixture.gd").spec(&"wall_torch")["sockets"]["flame"][0][2])
		burners.append(lights.wall_torch(stage, Vector3(60, 2.2, -0.4 + reach), Vector3.BACK))
		names.append("wall torch")
		baselines.append(MAIN_GEM[0])
		await _frames(5)

	var readings: Array[float] = []

	for i in burners.size():
		var burner: Node3D = burners[i]
		burner.flicker = 0.0
		player.velocity = Vector3.ZERO
		var flame: Vector3 = burner.global_transform * burner.flame_points[0] if burner.get("flame_points") != null else burner.global_position
		var out := Vector3.BACK if i == 3 else Vector3.RIGHT
		player.global_position = Vector3(flame.x, 1.05, flame.z) + out * 2.0
		player.rotation.y = atan2(out.x, out.z)
		await _frames(60)
		readings.append(player.get_light_level())
		# What the gem's cameras see: nothing of the flames, halos or smoke.
		var views := player.find_children("*", "SubViewport", false, false)

		for v in views.size():
			(views[v] as SubViewport).get_texture().get_image().save_png(out_dir + "gem_%s_%d.png" % [names[i].replace(" ", "_"), v])

	print("stage_lights: gem %s" % [readings])

	for i in readings.size():
		var before: float = baselines[i]

		if before < 0.0:
			print("stage_lights: NO BASELINE %s %.4f" % [names[i], readings[i]])
			continue

		var off := absf(readings[i] - before) / maxf(before, 0.0001)
		print("stage_lights: %s gem %s %.4f (main %.4f, %+.1f%%)" % ["PASS" if off <= 0.1 else "FAIL", names[i], readings[i], before, 100.0 * (readings[i] - before) / maxf(before, 0.0001)])

	stage.queue_free()
	await _frames(5)


## The burner under a node (the brazier's stand, the campfire's body).
func _burner_in(node: Node) -> Node3D:
	for child in node.find_children("*", "", true, false):
		if child.get("flicker") != null and child is Node3D:
			return child

	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
