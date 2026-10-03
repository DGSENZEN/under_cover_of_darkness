extends Node3D
## The city's distance (maps/city.gd): what tells you how far the rock and the
## land beyond it go, and that this is not our world. Built from the massing's
## markers and sockets (tools/level/layouts/city_massing.py _distance; the
## houses' chimneys, kit_massing): torches on the castle's towers and keep, at
## the Great Bridge's ends, round the cathedral's terrace and on the mirador;
## the balefire, a cold green-white fire on the keep with a pillar of its light
## standing up into the haze; mist down the gorge, in the aqueduct's valley and
## in the far land's hollows; corpse-lights drifting over the gorge's river,
## gone if you look at one too long; smoke from some of the old town's
## chimneys, leaning with the night's wind. Each kind one draw (a MultiMesh),
## on the effects' layer (the lightgem never sees them).

const Layers := preload("res://scripts/Visual/Layers.gd")
const GLOW := preload("res://scripts/Visual/distance_glow.gdshader")
const PILLAR := preload("res://scripts/Visual/distance_pillar.gdshader")
const MIST := preload("res://scripts/Visual/distance_mist.gdshader")
const SMOKE := preload("res://scripts/Visual/distance_smoke.gdshader")

## A torch's glow: its colour, its size (m across).
const TORCH := Color(1.0, 0.56, 0.22) * 1.6
const TORCH_SIZE := 3.2
## The balefire: its flames' colour and size, its pillar's width and height,
## its light's colour, energy and reach (it greens the keep's top).
const BALEFIRE := Color(0.55, 1.0, 0.72) * 2.2
const BALEFIRE_CORE := Color(0.9, 1.0, 0.95) * 2.4
const BALEFIRE_SIZE := 9.0
const PILLAR_SIZE := Vector2(30.0, 300.0)
const BALEFIRE_LIGHT := Color(0.5, 1.0, 0.7)
const BALEFIRE_ENERGY := 6.0
const BALEFIRE_RANGE := 46.0
## Corpse-lights: how many, their colour and size, how fast they drift; how
## long one may be looked at (s) before it goes, how near the middle of the
## view counts as looked at (cosine), how long it stays gone.
const WISPS := 7
const WISP := Color(0.55, 0.88, 1.0) * 1.4
const WISP_SIZE := 1.6
const WISP_PACE := 0.012
const STARE := 1.6
const STARE_COS := 0.9985
const GONE := 9.0
## Mist cards per far_air mist box (per 10 000 m2 of its floor, at least
## 2); their height as the box's; their width.
const MIST_PER := 0.8
const MIST_WIDTH := 140.0
## Low mist over the harbour's water between the eye and the town (city.gd
## gives where): SEA_MIST cards, SEA_MIST_HEIGHT m tall, thinner than the
## distance's, gone when you come within SEA_MIST_NEAR m.
const SEA_MIST := 14
const SEA_MIST_HEIGHT := 7.0
const SEA_MIST_DENSITY := 0.32
const SEA_MIST_NEAR := 70.0
## Chimney smoke: one chimney in SMOKE_SHARE smokes; its ribbon's width and
## height.
const SMOKE_SHARE := 0.3
const SMOKE_SIZE := Vector2(7.0, 26.0)

var torches: MultiMeshInstance3D
var flames: MultiMeshInstance3D
var pillar: MeshInstance3D
var light: OmniLight3D
var mist: MultiMeshInstance3D
var sea_mist: MultiMeshInstance3D
var smoke: MultiMeshInstance3D
var wisps: MultiMeshInstance3D

var _wisp_box := AABB()
var _wisp := []
## The corpse-lights' own clock (game time: the same every run).
var _clock := 0.0


## Everything from `level` (the massing's LevelLoader.Level); low mist over
## `sea` (world x, z) at `sea_level`.
func build(level, sea := Rect2(), sea_level := 0.0) -> void:
	var torch_at: Array[Vector3] = []
	var balefire := Vector3.INF

	for m in level.of("far_light"):
		var at: Vector3 = (m["transform"] as Transform3D).origin

		if String(m["props"].get("kind", "")) == "balefire":
			balefire = at
		else:
			torch_at.append(at)

	torches = _glows("Torches", torch_at.size())

	for i in torch_at.size():
		_glow(torches, i, torch_at[i], TORCH_SIZE, TORCH, i * 0.37, 0.0)

	if balefire != Vector3.INF:
		_balefire(balefire)

	var cards: Array = []

	for m in level.of("far_air"):
		var box := _box(m)

		match String(m["props"].get("kind", "")):
			"mist":
				# (By its floor, and enough cards to run its length.)
				var count := maxi(2, maxi(int(round(box.size.x * box.size.z / 10000.0 * MIST_PER)), int(ceil(maxf(box.size.x, box.size.z) / (MIST_WIDTH * 0.6)))))
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(String(m["name"]))

				for k in count:
					cards.append(Transform3D(Basis.from_scale(Vector3(MIST_WIDTH, box.size.y, 1.0)),
						Vector3(rng.randf_range(box.position.x, box.end.x), box.position.y, rng.randf_range(box.position.z, box.end.z))))
			"wisps":
				_wisp_box = box

	mist = _cards("Mist", MIST, cards)

	if sea.has_area():
		var rng := RandomNumberGenerator.new()
		rng.seed = 1755
		var low: Array = []

		for k in SEA_MIST:
			low.append(Transform3D(Basis.from_scale(Vector3(MIST_WIDTH, SEA_MIST_HEIGHT, 1.0)),
				Vector3(rng.randf_range(sea.position.x, sea.end.x), sea_level - 0.5, rng.randf_range(sea.position.y, sea.end.y))))

		sea_mist = _cards("SeaMist", MIST, low)
		(sea_mist.material_override as ShaderMaterial).set_shader_parameter(&"density", SEA_MIST_DENSITY)
		(sea_mist.material_override as ShaderMaterial).set_shader_parameter(&"near_fade", SEA_MIST_NEAR)
	var stacks: Array = []

	for s in level.sockets:
		if String(s.get("kind", "")) == "chimney" and _hash_of(s["position"]) < SMOKE_SHARE:
			var p: Array = s["position"]
			stacks.append(Transform3D(Basis.from_scale(Vector3(SMOKE_SIZE.x, SMOKE_SIZE.y, 1.0)), Vector3(p[0], p[1], p[2])))

	smoke = _cards("Smoke", SMOKE, stacks)

	if _wisp_box.size != Vector3.ZERO:
		_make_wisps()


## Where corpse-light `i` is now, and how much of it shows (0..1).
func wisp(i: int) -> Array:
	return [_wisp[i]["at"], float(_wisp[i]["shows"])]


## How many mist cards, smoke ribbons and lit things there are (for tests).
func counts() -> Dictionary:
	return {"torches": torches.multimesh.instance_count if torches else 0, "mist": mist.multimesh.instance_count if mist else 0,
		"smoke": smoke.multimesh.instance_count if smoke else 0, "wisps": _wisp.size(), "balefire": light != null,
		"sea_mist": sea_mist.multimesh.instance_count if sea_mist else 0}


func _process(delta: float) -> void:
	# (Under the water none of it shows: it is drawn after the water's own
	# murk, which would not dim it.)
	var view := get_viewport().get_node_or_null(^"WaterView")
	visible = view == null or not bool(view.get("visible_effect"))
	var night := get_tree().get_first_node_in_group(&"night")

	if smoke != null and night != null and night.has_method(&"wind"):
		(smoke.material_override as ShaderMaterial).set_shader_parameter(&"wind", night.wind())

	if wisps != null:
		_drift(delta)


func _balefire(at: Vector3) -> void:
	flames = _glows("Balefire", 3)
	_glow(flames, 0, at + Vector3(0.0, 2.2, 0.0), BALEFIRE_SIZE, BALEFIRE, 0.1, 0.0)
	_glow(flames, 1, at + Vector3(0.0, 1.2, 0.0), BALEFIRE_SIZE * 0.45, BALEFIRE_CORE, 0.7, 0.0)
	_glow(flames, 2, at + Vector3(0.0, 6.0, 0.0), BALEFIRE_SIZE * 1.8, BALEFIRE * 0.35, 1.3, 1.0)
	pillar = MeshInstance3D.new()
	pillar.name = "Pillar"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	pillar.mesh = quad
	var look := ShaderMaterial.new()
	look.shader = PILLAR
	pillar.material_override = look
	pillar.layers = Layers.FX
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.extra_cull_margin = PILLAR_SIZE.y
	add_child(pillar)
	pillar.global_transform = Transform3D(Basis.from_scale(Vector3(PILLAR_SIZE.x, PILLAR_SIZE.y, 1.0)), at)
	light = OmniLight3D.new()
	light.name = "BalefireLight"
	light.light_color = BALEFIRE_LIGHT
	light.light_energy = BALEFIRE_ENERGY
	light.omni_range = BALEFIRE_RANGE
	light.shadow_enabled = false
	add_child(light)
	light.global_position = at + Vector3(0.0, 3.0, 0.0)


func _glows(node_name: String, count: int) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = quad
	multi.instance_count = count
	var look := ShaderMaterial.new()
	look.shader = GLOW
	return _drawn(node_name, multi, look)


func _glow(draw: MultiMeshInstance3D, i: int, at: Vector3, size: float, colour: Color, seed_value: float, life: float) -> void:
	draw.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), at))
	draw.multimesh.set_instance_color(i, colour)
	draw.multimesh.set_instance_custom_data(i, Color(seed_value, life, 1.0, 0.0))


func _cards(node_name: String, shader: Shader, at: Array) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = quad
	multi.instance_count = at.size()

	for i in at.size():
		multi.set_instance_transform(i, at[i])
		multi.set_instance_custom_data(i, Color(fposmod(i * 0.618034, 1.0) * 10.0, 0.0, 0.0, 0.0))

	var look := ShaderMaterial.new()
	look.shader = shader
	return _drawn(node_name, multi, look)


func _drawn(node_name: String, multi: MultiMesh, look: ShaderMaterial) -> MultiMeshInstance3D:
	var draw := MultiMeshInstance3D.new()
	draw.name = node_name
	draw.multimesh = multi
	draw.material_override = look
	draw.layers = Layers.FX
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (Billboards stand out of their own bounds: never culled by them.)
	draw.custom_aabb = AABB(Vector3(-4000.0, -500.0, -4000.0), Vector3(8000.0, 2000.0, 8000.0))
	add_child(draw)
	return draw


func _make_wisps() -> void:
	wisps = _glows("CorpseLights", WISPS)

	for i in WISPS:
		# (Its place kept here: a MultiMesh's transforms do not read back
		# without a renderer.)
		_wisp.append({"phase": Vector3(i * 1.7, i * 2.9, i * 0.6), "stare": 0.0, "gone": 0.0, "shows": 0.0, "at": _wisp_box.get_center()})
		_glow(wisps, i, _wisp_box.get_center(), WISP_SIZE, WISP, i * 0.91, 1.0)


## The corpse-lights drift through their box on slow, never-repeating paths;
## one looked at too long goes out, and comes back elsewhere after a while.
func _drift(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	_clock += delta
	var t := _clock * WISP_PACE

	for i in _wisp.size():
		var w: Dictionary = _wisp[i]
		var ph: Vector3 = w["phase"]
		var u := Vector3(0.5 + 0.5 * sin(t * 1.3 + ph.x) * cos(t * 0.47 + ph.y), 0.5 + 0.5 * sin(t * 2.1 + ph.z),
			0.5 + 0.5 * sin(t * 0.83 + ph.y) * sin(t * 0.31 + ph.x))
		var at := _wisp_box.position + _wisp_box.size * u
		w["at"] = at

		if camera != null:
			var to := at - camera.global_position
			var looked := (-camera.global_basis.z).dot(to.normalized()) > STARE_COS
			w["stare"] = float(w["stare"]) + delta if looked else maxf(0.0, float(w["stare"]) - delta)

		if float(w["stare"]) > STARE:
			w["gone"] = GONE
			w["stare"] = 0.0

		w["gone"] = maxf(0.0, float(w["gone"]) - delta)
		var wanted := 0.0 if float(w["gone"]) > 0.0 else 1.0
		w["shows"] = move_toward(float(w["shows"]), wanted, delta * (3.0 if wanted < 0.5 else 0.25))
		wisps.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * WISP_SIZE), at))
		wisps.multimesh.set_instance_custom_data(i, Color(i * 0.91, 1.0, float(w["shows"]), 0.0))


## A far_air marker's box in the world (its transform's origin its middle).
static func _box(m: Dictionary) -> AABB:
	var size: Vector3 = m["size"] if m["size"] != null else Vector3.ONE
	var middle: Vector3 = (m["transform"] as Transform3D).origin
	return AABB(middle - size * 0.5, size)


static func _hash_of(p: Array) -> float:
	return fposmod(sin(float(p[0]) * 12.9898 + float(p[2]) * 78.233) * 43758.5453, 1.0)
