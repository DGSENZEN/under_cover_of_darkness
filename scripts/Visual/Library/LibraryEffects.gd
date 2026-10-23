extends Node3D
## The library owns its supernatural presentation. No static scene or camera references.

const BookProjection := preload("res://scripts/Visual/Library/BookProjection.gd")
const LibraryLight := preload("res://scripts/Visual/Library/LibraryLight.gd")

var projections: Array[Node3D] = []
var enabled := true
var inspecting := false
var lighting: Node3D


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


func set_enabled(on: bool) -> void:
	enabled = on
	for projection in projections:
		projection.enabled = on
	if is_instance_valid(lighting):
		lighting.enabled = on


func set_inspection(on: bool) -> void:
	inspecting = on
	if is_instance_valid(lighting):
		lighting.set_inspection(on)
