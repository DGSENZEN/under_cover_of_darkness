extends Node3D
## The library owns its supernatural presentation. No static scene or camera references.

const BookProjection := preload("res://scripts/Visual/Library/BookProjection.gd")
const LibraryLight := preload("res://scripts/Visual/Library/LibraryLight.gd")
const SectionAura := preload("res://scripts/Visual/Library/SectionAura.gd")
const LibraryWords := preload("res://scripts/Visual/Library/LibraryWords.gd")
const LibraryWard := preload("res://scripts/Visual/Library/LibraryWard.gd")
const LibraryShadow := preload("res://scripts/Visual/Library/LibraryShadow.gd")

var projections: Array[Node3D] = []
var enabled := true
var inspecting := false
var lighting: Node3D
## Each section's aura, by section; the living words; the chained book's ward; the librarian's shadow.
var auras := {}
var words: Node3D
var ward: Node3D
var shadow: Node3D


func build(lab: Node3D) -> void:
	if not projections.is_empty():
		return
	for i in lab.live_books.size():
		var projection := BookProjection.new()
		add_child(projection)
		projection.build(lab.live_books[i], i)
		projections.append(projection)
	lighting = LibraryLight.new()
	lighting.name = "LibraryLight"
	add_child(lighting)
	lighting.build(lab)
	var k := 0
	for section: StringName in LibraryLight.COLOURS:
		if not lab.sections.has(section):
			continue
		var aura := SectionAura.new()
		add_child(aura)
		aura.build(lab, section, lab.sections[section], LibraryLight.COLOURS[section], 70.0 + k)
		auras[section] = aura
		k += 1
	words = LibraryWords.new()
	add_child(words)
	words.build(lab, projections)
	if lab.get("chained") != null and lab.get("ward_ring") != null:
		ward = LibraryWard.new()
		add_child(ward)
		ward.build(lab.chained, lab.global_transform * Transform3D(Basis.IDENTITY, lab.CORNER_AT), lab.WARD_RADIUS,
			lab.ward_wicks, lab.ward_ring)
	if ResourceLoader.exists(LibraryShadow.IMAGE) and not lab.sections.is_empty():
		shadow = LibraryShadow.new()
		add_child(shadow)
		shadow.build(_shadow_ways(lab), load(LibraryShadow.IMAGE))


## His shadow's ways: along each wall case's front (its frame's front middle on the floor), from beyond one end of
## the case to beyond the other, so he walks in off its edge and out past the other; each end only as far out as his
## decal stays clear of every other case and of the corner's things (drawn in from a case's end if they are close:
## the metaphysics case meets the hunting case in the back corner). The chronology case's own ladder is its.
func _shadow_ways(lab: Node3D) -> Array:
	var ways := []
	var others: Array[AABB] = []
	for mesh in lab.shelves + lab.corner.values():
		if mesh is MeshInstance3D and not String(mesh.name).begins_with("ladder"):
			others.append((mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb())
	var half := LibraryShadow.SIZE.x * 0.5
	for section: String in lab.sections:
		var case: MeshInstance3D = lab.sections[section]
		var box := case.get_aabb()
		var own := case.global_transform * box
		var ends := Vector2(box.position.x - half, box.end.x + half)
		for side: float in [-1.0, 1.0]:
			var at: float = ends.x if side < 0.0 else ends.y
			# (In from fully off the case, a step at a time, until nothing else is under him.)
			while absf(at - (box.position.x if side < 0.0 else box.end.x)) <= 2.0 * half:
				var decal := case.global_transform * AABB(Vector3(at - half, 0.0, -LibraryShadow.INTO),
					Vector3(LibraryShadow.SIZE.x, LibraryShadow.SIZE.y, LibraryShadow.BEFORE + LibraryShadow.INTO))
				if not others.any(func(o): return o != own and o.intersects(decal)):
					break
				at -= side * 0.05
			if side < 0.0:
				ends.x = at
			else:
				ends.y = at
		ways.append([case.global_transform, ends, case])
	return ways


func set_enabled(on: bool) -> void:
	enabled = on
	for projection in projections:
		projection.enabled = on
	if is_instance_valid(lighting):
		lighting.enabled = on
	_show_auras()


func set_inspection(on: bool) -> void:
	inspecting = on
	if is_instance_valid(lighting):
		lighting.set_inspection(on)
	_show_auras()


func _show_auras() -> void:
	for aura: Node3D in auras.values():
		aura.visible = enabled and not inspecting
	if is_instance_valid(words):
		words.visible = enabled and not inspecting
	if is_instance_valid(ward):
		ward.shown = enabled and not inspecting
	if is_instance_valid(shadow):
		shadow.set_shown(enabled and not inspecting)
