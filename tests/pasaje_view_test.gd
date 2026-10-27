extends Node3D
## The Pasaje's middle stretch as the player sees it in the real Metro (docs/superpowers/plans/2026-10-26-pasaje-market.md,
## Task 9): the player camera's field of view, the eye 1.65 m over the floor, regions projected from points in the set's
## frame. Windowed, in the game's time:
##   Godot --path . --fixed-fps 60 --resolution 1152x648 res://tests/pasaje_view_test.tscn
## The views are saved to docs/superpowers/refs/underground/pasaje/ (review media, not committed).
const MAP := preload("res://maps/metro.tscn")
const OUT := "res://docs/superpowers/refs/underground/pasaje/"
## The views in the set's frame: [where the eye is, what it looks at, the file's name]. From the lane's mouth looking out
## west across the street and along it; from the stretch's north end looking south down it.
const MOUTH_WEST := [Vector3(4.4, 1.65, 0.45), Vector3(-5.0, 1.3, 0.45), "view_1_mouth_west"]
const MOUTH_ALONG := [Vector3(4.4, 1.65, 0.45), Vector3(-1.5, 1.3, -14.0), "view_2_mouth_along"]
const NORTH_END := [Vector3(0.0, 1.65, -19.0), Vector3(0.0, 1.4, 20.0), "view_3_north_end"]
## Where the greybox's own grey is measured: the north stretch beyond the set's end, seen from its end.
const GREYBOX := [Vector3(0.0, 1.65, -19.0), Vector3(0.0, 1.4, -40.0), "view_0_greybox_north"]
## A neon hue: saturated and bright; a tube's hue counts when its glowing pixels are this share of the frame (a far
## tube's glow is some 150 pixels; the plan's 0.2 % was for clusters over the whole frame).
const NEON_SHARE := 0.0002
## The layer the set's drawn meshes are made solid on for the view's rays alone.
const SEEN_LAYER := 1 << 30
const Silhouette := preload("res://scripts/Visual/Silhouette.gd")

var results: Array[String] = []
var failures := 0
var eye: Camera3D
var pasaje: Node3D
var map: Node3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	map = MAP.instantiate()
	add_child(map)
	await _seconds(0.5)
	var fov: float = get_viewport().get_camera_3d().fov
	map.player.global_position = map.spawn_point() + Vector3(0.0, 1.05, 0.0)
	pasaje = map.get_node("pasaje")
	eye = Camera3D.new()
	eye.fov = fov
	add_child(eye)
	eye.make_current()
	await _seconds(4.0)
	# (The crowds hidden: what is judged is the set, and what moves is its steam.)
	for set_name in ["pasaje", "candle_lane"]:
		var crowd: Node3D = map.get_node(set_name).get("crowd_of_shades")
		if crowd != null:
			crowd.visible = false

	_look(GREYBOX)
	await _seconds(0.5)
	var grey := _grey(_shot(GREYBOX[2]))

	var hues := {}
	for view in [MOUTH_WEST, MOUTH_ALONG, NORTH_END]:
		_look(view)
		await _seconds(0.5)
		var shot := _shot(view[2])
		for hue in _neon_hues(shot):
			hues[hue] = true
	_check("PV1 the stalls' neons show at least five distinct hues", hues.size() >= 5, "%s" % [hues.keys()])

	_look(NORTH_END)
	await _seconds(0.5)
	var a := _shot("")
	await _seconds(0.5)
	var b := _shot("")
	var moved := 0
	var seen := 0
	for spec: Array in pasaje.STEAM:
		var stall: Node3D = pasaje.stalls[spec[0]]
		var at: Vector3 = pasaje.to_local(stall.to_global(spec[2]))
		var rect := _region(at + Vector3(-0.5, 0.0, -0.5), at + Vector3(0.5, 1.2, 0.5))
		for y in range(rect.position.y, rect.end.y, 2):
			for x in range(rect.position.x, rect.end.x, 2):
				var c := a.get_pixel(x, y)
				var d := b.get_pixel(x, y)
				seen += 1
				var pale := (c.v > 0.45 and c.s < 0.3) or (d.v > 0.45 and d.s < 0.3)
				if pale and absf(c.r - d.r) + absf(c.g - d.g) + absf(c.b - d.b) > 0.08:
					moved += 1
	var share := float(moved) / maxf(seen, 1.0)
	_check("PV2 steam moves over the food stalls", share >= 0.01, "%.4f of the steam's regions changed" % share)

	# From the north end, the middle third of the frame is the market, not the greybox: what each of its pixels sees
	# (a ray from the eye through it) is the set's, not the greybox's. (Judged by what is hit, not by colour: the
	# greybox there is unlit, black (its grey measured on the north stretch: %.3f), as black as the shades and the
	# shadows under the stalls.)
	var middle := Rect2i(a.get_width() / 3, a.get_height() / 3, a.get_width() / 3, a.get_height() / 3)
	# (-- --bare-end: the check's own baseline, the kiosk and the canopy's back tarpaulins hidden.)
	if OS.get_cmdline_user_args().has("--bare-end"):
		if pasaje.get("kiosk") != null:
			pasaje.kiosk.visible = false
		for piece: Node3D in pasaje.overhead:
			if piece.name == "canopy_back":
				piece.visible = false
	_seen_as_solid()
	await _seconds(0.1)
	var space := get_world_3d().direct_space_state
	var greybox: Node = map.get("greybox")
	var greyed := 0
	var n := 0
	for y in range(middle.position.y, middle.end.y, 4):
		for x in range(middle.position.x, middle.end.x, 4):
			n += 1
			var from := eye.project_ray_origin(Vector2(x, y))
			var query := PhysicsRayQueryParameters3D.create(from, from + eye.project_ray_normal(Vector2(x, y)) * 80.0,
				0xFFFFFFFF)
			var hit := space.intersect_ray(query)
			if not hit.is_empty() and greybox != null and greybox.is_ancestor_of(hit["collider"]):
				greyed += 1
	var greyed_share := float(greyed) / maxf(n, 1.0)
	_check("PV3 from the north end the middle of the view is market, not greybox", greyed_share < 0.02,
		("%.4f greybox (its grey %.3f)" % [greyed_share, grey]))

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit(1 if failures > 0 else 0)


## What the eye sees as solid, made solid to the view's rays (test-side, on a layer of its own): every mesh the set
## draws, its cloth and tarpaulins too, which carry no collider for the player. (Not the shades: cut-outs on quads.)
func _seen_as_solid() -> void:
	for mesh: MeshInstance3D in pasaje.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree() or mesh is Silhouette or mesh.get_parent() is Silhouette:
			continue
		var body := StaticBody3D.new()
		body.collision_layer = SEEN_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		body.add_child(shape)
		mesh.add_child(body)


## The greybox's own grey (its value), from the middle of the view of the plain stretch north of the set.
func _grey(image: Image) -> float:
	var values := []
	for y in range(image.get_height() / 3, 2 * image.get_height() / 3, 3):
		for x in range(image.get_width() / 3, 2 * image.get_width() / 3, 3):
			var c := image.get_pixel(x, y)
			if c.s < 0.06:
				values.append(c.v)
	values.sort()
	return values[values.size() / 2] if not values.is_empty() else -1.0


## The neon hues a shot shows: over each stall's neon tube (its box on screen, grown a little for its glow), the hue its
## glowing pixels (saturated, bright) show most, binned (30° bins), where those pixels are NEON_SHARE of the frame.
## (Judged at the tubes: the street's red tiles and the mouth's teal wash fill the frame's own hue counts.)
func _neon_hues(image: Image) -> Array:
	var hues := []
	var frame := float(image.get_width() * image.get_height()) / 4.0
	for stall: Node3D in pasaje.stalls.values():
		for tube: MeshInstance3D in stall.find_children("neon_tube*", "MeshInstance3D", true, false):
			var box: AABB = pasaje.global_transform.affine_inverse() * tube.global_transform * tube.get_aabb()
			var rect := _region(box.position, box.end).grow(6).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
			var bins := {}
			for y in range(rect.position.y, rect.end.y, 2):
				for x in range(rect.position.x, rect.end.x, 2):
					var c := image.get_pixel(x, y)
					if c.s > 0.45 and c.v > 0.5:
						var bin := int(c.h * 12.0) % 12
						bins[bin] = int(bins.get(bin, 0)) + 1
			if bins.is_empty():
				continue
			var most: int = bins.keys().reduce(func(a, b): return a if bins[a] >= bins[b] else b)
			if float(bins[most]) / frame >= NEON_SHARE:
				hues.append(most)
	return hues


## The screen rectangle a box in the set's frame covers (its corners projected), clipped to the image.
func _region(lo: Vector3, hi: Vector3) -> Rect2i:
	var size := Vector2(get_viewport().get_texture().get_size())
	var rect := Rect2()
	var first := true
	for i in 8:
		var p := Vector3(hi.x if i & 1 else lo.x, hi.y if i & 2 else lo.y, hi.z if i & 4 else lo.z)
		var g := pasaje.to_global(p)
		if eye.is_position_behind(g):
			continue
		var s := eye.unproject_position(g)
		rect = Rect2(s, Vector2.ZERO) if first else rect.expand(s)
		first = false
	return Rect2i(rect.intersection(Rect2(Vector2.ZERO, size)))


## The eye at a view (the set's frame).
func _look(view: Array) -> void:
	eye.global_transform = Transform3D(Basis.IDENTITY, pasaje.to_global(view[0])).looking_at(pasaje.to_global(view[1]), Vector3.UP)


func _shot(file_name: String) -> Image:
	RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	if file_name != "":
		image.save_png(ProjectSettings.globalize_path(OUT + file_name + ".png"))
	return image


## `s` seconds of the game's time (60 frames a second under --fixed-fps 60).
func _seconds(s: float) -> void:
	for i in maxi(int(s * 60.0), 1):
		await get_tree().process_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
