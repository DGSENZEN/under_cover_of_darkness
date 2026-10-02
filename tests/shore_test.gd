extends Node3D
## Real bank geometry: the water's bed survey follows slopes and islands,
## ignores overhead bridges and actors, and can refresh changed terrain.
const Water := preload("res://scripts/Interaction/WaterVolume.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
var failed := false
var results: Array[String] = []
const ORIGIN := Vector3(50, 0, -20)

func _ready() -> void:
	Props.block(self, ORIGIN + Vector3(0, -2.5, 0), Vector3(20, 1, 20))
	var bank := Props.block(self, ORIGIN + Vector3(-3, -0.62, 0), Vector3(2, 1, 6))
	Props.block(self, ORIGIN + Vector3(0, 0.5, 2), Vector3(1, 2, 1))
	Props.block(self, ORIGIN + Vector3(3, 3, 0), Vector3(2, 0.4, 6))
	var actor := Props.block(self, ORIGIN + Vector3(3, -0.5, -2), Vector3(1, 1, 1))
	actor.collision_layer = 2
	_concave_block(ORIGIN + Vector3(0, 0, -2), Vector3(1.2, 2, 1.2))
	_concave_block(ORIGIN + Vector3(3, 3, 0), Vector3(2, 0.4, 6))
	_concave_bridge_with_pier()
	_concave_block(ORIGIN + Vector3(3, 1.7, 1), Vector3(0.6, 5, 0.6))
	var water := Water.build(self, ORIGIN + Vector3(0, -1.5, 0), Vector3(12, 3, 8))
	await _frames(5)
	var ready := bool(water._paint.get_shader_parameter("shore_ready"))
	_check("SH1 a translated volume surveys its actual shallow bed", ready and absf(_depth(water, Vector2(-3, 0)) - 0.10) < 0.03, "shallow %.3f" % _depth(water, Vector2(-3, 0)))
	_check("SH2 deep water keeps the true bed depth", absf(_depth(water, Vector2(3, 2)) - 1.98) < 0.03, "deep %.3f" % _depth(water, Vector2(3, 2)))
	_check("SH3 an overhead bridge does not become a shoreline", absf(_depth(water, Vector2(3, 0)) - 1.98) < 0.03, "under bridge %.3f" % _depth(water, Vector2(3, 0)))
	_check("SH4 an interior island is detected away from the volume edges", _depth(water, Vector2(0, 2)) < 0.01, "island %.3f" % _depth(water, Vector2(0, 2)))
	_check("SH5 actors do not leave a permanent mark in the bed survey", absf(_depth(water, Vector2(3, -2)) - 1.98) < 0.03, "actor %.3f" % _depth(water, Vector2(3, -2)))
	_check("SH9 concave terrain containing the surface counts as land", _depth(water, Vector2(0, -2)) < 0.01, "concave bank %.3f" % _depth(water, Vector2(0, -2)))
	_check("SH10 concave bridges leave deep water below them", absf(_depth(water, Vector2(3, 0)) - 1.98) < 0.03, "concave bridge %.3f" % _depth(water, Vector2(3, 0)))
	_check("SH11 a concave bridge with a submerged pier keeps its open channel", absf(_depth(water, Vector2(3, 2)) - 1.98) < 0.03, "under connected deck %.3f" % _depth(water, Vector2(3, 2)))
	_check("SH12 an overlapping bridge cannot clear another solid bank", _depth(water, Vector2(3, 1)) < 0.01, "overlapping pier %.3f" % _depth(water, Vector2(3, 1)))
	water.ripple(2.0, 4.0, 0.06)
	await _frames(2)
	var shore: ShaderMaterial = water._paint.next_pass
	var flow: Variant = shore.get_shader_parameter("flow")
	_check("SH6 shallows and deep water share their ripple motion", flow is Vector2 and flow.distance_to(Vector2(0.06, 0.0)) < 0.001 and absf(float(shore.get_shader_parameter("water_clock")) - water.render_clock) < 0.04, "same flow and clock")
	bank.position.y -= 1.0
	water.refresh_shoreline()
	await _frames(5)
	_check("SH7 rebuilding updates a changed bank", absf(_depth(water, Vector2(-3, 0)) - 1.10) < 0.03, "changed %.3f" % _depth(water, Vector2(-3, 0)))
	water.queue_free()
	await _frames(3)
	var view: Node = get_viewport().get_node("WaterView")
	_check("SH8 removing water clears its view pass", view.active_water == null and not view.visible_effect, "no stranded pass")
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failed else 0)

func _depth(water: Area3D, local: Vector2) -> float:
	var texture: Texture2D = water._paint.get_shader_parameter("shore_depth")
	if texture == null:
		return -1.0
	var image := texture.get_image()
	var uv := local / Vector2(water.size.x, water.size.z) + Vector2(0.5, 0.5)
	return image.get_pixel(clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1), clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1)).r

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _check(label: String, okay: bool, detail: String) -> void:
	failed = failed or not okay
	results.append("%s  %s [%s]" % ["PASS" if okay else "FAIL", label, detail])


func _concave_block(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	body.position = at
	add_child(body)


func _concave_bridge_with_pier() -> void:
	var body := StaticBody3D.new()
	var faces := PackedVector3Array()
	for pair in [[Vector3(3, 3.5, 2), Vector3(3, 0.3, 2)], [Vector3(4.3, 1, 2), Vector3(0.4, 5, 0.4)]]:
		var mesh := BoxMesh.new()
		mesh.size = pair[1]
		for point in mesh.get_faces():
			faces.append(point + (pair[0] as Vector3))
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(faces)
	shape.shape = concave
	body.add_child(shape)
	body.position = ORIGIN
	add_child(body)
