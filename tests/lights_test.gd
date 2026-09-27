extends Node3D
## Lights and fire: the materials by slot, the flames, their flicker, the
## coronas, embers and smoke, lit and out, the shadow budget, every fixture
## the props pipeline builds, their sounds, and the levels switched over.
## Headless, so this checks settings and arithmetic, not pixels; the pixels
## are checked by eye with tests/visual/stage_lights.tscn.
##
##   Godot --headless --fixed-fps 60 --path . res://tests/lights_test.tscn

const Props := preload("res://scripts/Interaction/Props.gd")
const Furnishings := preload("res://scripts/Interaction/Furnishings.gd")
const FireScript := preload("res://scripts/Combat/Fire.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const Materials := preload("res://scripts/Visual/Materials.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")

## LightProbe 2 m from a bare torch, the brazier and the campfire (each
## flame's flicker held still), read on main before any of this work: the
## gameplay's light must stay within 10% of these.
const PROBE_BASELINE := [0.6870, 0.5878, 0.8089, 0.7449, 0.6229, 0.6943]

var results: Array[String] = []


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(400, 1, 400))
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	await _materials()
	await _baselines()


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

func _materials() -> void:
	# L1 no photo: the slot's flat colour, shaded by vertex colour
	var folder_before: String = Materials.folder
	Materials.folder = "res://nowhere/"
	Materials.clear_cache()
	var iron: StandardMaterial3D = Materials.surface(&"iron")
	_check("L1 with no photo a slot is its flat colour, shaded by vertex colour",
		iron != null and iron.albedo_texture == null and iron.albedo_color.is_equal_approx(Color("2A2826")) and iron.vertex_color_use_as_albedo,
		"texture %s colour %s vertex colour %s" % [iron.albedo_texture if iron else null, iron.albedo_color if iron else Color.BLACK, iron.vertex_color_use_as_albedo if iron else false])

	# L2 a photo where there is one
	Materials.folder = "res://textures/"
	var stone_before = Materials.photo_names.get(&"stone")
	Materials.photo_names[&"stone"] = "stone_brick_1"
	Materials.clear_cache()
	var stone: StandardMaterial3D = Materials.surface(&"stone")
	_check("L2 a slot whose photo exists is drawn with it, sampled nearest",
		stone != null and stone.albedo_texture != null and stone.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,
		"texture %s filter %d" % [stone.albedo_texture if stone else null, stone.texture_filter if stone else -1])
	Materials.photo_names[&"stone"] = stone_before
	Materials.folder = folder_before
	Materials.clear_cache()


# ---------------------------------------------------------------------------
# The gameplay's light, before and after
# ---------------------------------------------------------------------------

func _baselines() -> void:
	# L3 LightProbe beside a torch, the brazier and the campfire
	var torch: Node3D = TorchScript.new()
	add_child(torch)
	torch.global_position = Vector3(100, 2, 100)
	var fire: Area3D = FireScript.brazier(self, Vector3(120, 0, 100))
	var camp: Node3D = Furnishings.campfire(self, Vector3(140, 0, 100))
	await _frames(5)
	var burners := [torch, _burner_in(fire.get_parent()), _burner_in(camp)]
	var readings: Array[float] = []

	for burner in burners:
		if burner == null:
			readings.append(-1.0)
			continue

		burner.flicker = 0.0

	await _frames(3)

	for burner in burners:
		if burner == null:
			continue

		var flame: Vector3 = burner.global_position
		# Two metres off, at chest height.
		readings.append(LightProbe.light_at(self, Vector3(flame.x + 2.0, 1.2, flame.z)))
		# And from the other side, lower.
		readings.append(LightProbe.light_at(self, Vector3(flame.x, 0.6, flame.z - 2.0)))

	print("L3 probe readings: %s" % [readings])
	var close := PROBE_BASELINE.size() == readings.size()

	for i in mini(PROBE_BASELINE.size(), readings.size()):
		close = close and absf(readings[i] - float(PROBE_BASELINE[i])) <= 0.1 * maxf(float(PROBE_BASELINE[i]), 0.01)

	_check("L3 the probe reads the torch, brazier and campfire as it did before (within 10%)", close,
		"now %s, before %s" % [readings, PROBE_BASELINE])

	for node in [torch, fire.get_parent(), camp]:
		node.queue_free()

	await _frames(3)


## The burner (anything in "torches") at or under `node`.
func _burner_in(node: Node) -> Node3D:
	if node == null:
		return null

	if node.is_in_group(&"torches"):
		return node

	for child in node.find_children("*", "", true, false):
		if child.is_in_group(&"torches"):
			return child

	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
