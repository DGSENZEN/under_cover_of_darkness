extends Node3D
## One book's effects, attached to its actual page surface and orientation.
## Shape families are added here as they pass their visual review.

const BookRadiance := preload("res://scripts/Visual/Library/BookRadiance.gd")

var book: LiveBook
var presence := 0.0
var clear_height := 0.65
var enabled := true
var _page: MeshInstance3D
var radiance: Node3D
var _clock := 0.0


func build(source: LiveBook, index: int) -> void:
	book = source
	name = "projection_%d" % index
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# LiveBook poses itself first; effects follow its current opening amount.
	process_priority = 5
	for part: MeshInstance3D in book.parts:
		if part.get_meta("book_part", "") == "live_block_right":
			_page = part
			break
	visible = false
	radiance = BookRadiance.new()
	radiance.name = "BookRadiance"
	add_child(radiance)
	_sync()


func _process(delta: float) -> void:
	_clock += delta
	_sync()


func _sync() -> void:
	if not is_instance_valid(book):
		presence = 0.0
		visible = false
		return
	var has_eye := is_instance_valid(book.watcher) or get_viewport().get_camera_3d() != null
	presence = smoothstep(0.0, 1.0, book.open) if enabled and has_eye else 0.0
	visible = presence > 0.001
	var page_basis := _page.global_basis.orthonormalized() if is_instance_valid(_page) else book.global_basis.orthonormalized()
	global_transform = Transform3D(page_basis, origin_world())
	# Ray in world-up: the book can be on a turned shelf or a pitched lectern.
	# Keep a margin below the board for shader displacement and the effect's rim.
	var anchor := origin_world()
	var ray := PhysicsRayQueryParameters3D.create(anchor + Vector3.UP * 0.005, anchor + Vector3.UP * 0.65)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	clear_height = maxf(0.0, hit.position.y - anchor.y - 0.025) if not hit.is_empty() else 0.65
	radiance.set_state(presence, clear_height, _clock)


func origin_world() -> Vector3:
	if is_instance_valid(_page):
		var bounds := _page.get_aabb()
		return _page.to_global(Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z))
	return book.to_global(Vector3(0.12, 0.035, 0.0)) if is_instance_valid(book) else global_position

func page_extent() -> Vector2:
	if not is_instance_valid(_page):
		return Vector2(0.22, 0.3)
	var size := _page.get_aabb().size * _page.global_basis.get_scale()
	return Vector2(size.x, size.z)
