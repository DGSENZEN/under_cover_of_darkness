extends "res://maps/underground_lab.gd"
## The candle lane (docs/superpowers/specs/2026-10-23-candle-lane-design.md): the Underground corridor bay run out to the
## Metro's lane between the Pasaje and the chapel, the librarian's shop opening off its south side. The bay's frame: x
## along the lane, z across it (BACK_WALL its north wall, FAR_WALL its south), the floor at 0; plan (x, y) is
## (x + 12.8, z + 74.35), its floor −11. Built to be judged on its own (standalone: with a stub of the Pasaje at its mouth
## and a glimpse of the chapel through its doorway), then set whole into maps/metro, where the map's own spaces meet it.

const LIBRARY := preload("res://maps/library_lab.tscn")
## Where the lane's middle is in the plan; how far the corridor runs each way from it (m: 28 tile modules, 7 vault spans).
const PLAN_ORIGIN := Vector3(12.8, -11.0, 74.35)
const LANE_HALF := 16.8
## The shop's front along the far wall (x from, to; plan x 15 to 23); where the shop's room stands (its front 2 cm proud
## of the wall's tiles, so their faces never share a plane), turned to face the lane.
const SHOP_FRONT := Vector2(2.2, 10.2)
const SHOP_AT := Vector3(6.2, 0.0, FAR_WALL + 0.38)
## The chapel's doorway in the east end: its width, its height, its middle across the lane (plan y 74.5).
const DOOR := Vector2(3.0, 2.8)
const DOOR_Z := 0.15
## The stubs beyond the ends (standalone only): how far the Pasaje's floor runs past the mouth, how wide it is across,
## how far the chapel's floor runs in through the doorway.
const PASAJE_STUB := Vector2(10.0, 18.0)
const CHAPEL_STUB := 3.0

## Judged on its own (the stubs at its ends), or set into maps/metro (no stubs: the map's spaces meet it).
@export var standalone := true

var shop: Node3D
var chapel_door: Node3D
var stub: Node3D


func _ready() -> void:
	half_run = LANE_HALF
	super._ready()
	_shop_front()
	_east_end()
	_west_end()
	_stubs()
	shop = LIBRARY.instantiate()
	shop.name = "Library"
	shop.standalone = false
	shop.player = player
	shop.transform = Transform3D(Basis(Vector3.UP, PI), SHOP_AT)
	add_child(shop)
	inspection_sections.append(shop)


## A point in the lane's frame, in the plan's (x, floor height, y).
func plan_point(bay: Vector3) -> Vector3:
	return bay + PLAN_ORIGIN


## The far wall opened for the shop's front: its tile panels wholly behind the front gone (the two at its ends stay,
## half behind it), its backing wall cut across the front (the shopfront is solid itself).
func _shop_front() -> void:
	for panel: MeshInstance3D in wall_panels.duplicate():
		var box := panel.global_transform * panel.get_aabb()
		if box.position.z > FAR_WALL - 0.05 and box.position.x >= SHOP_FRONT.x - 0.01 and box.end.x <= SHOP_FRONT.y + 0.01:
			wall_panels.erase(panel)
			panel.free()
	_cut("far_wall", Vector3(-half_run, 0.0, FAR_WALL + WALL_FACE), Vector3(half_run, HEIGHT, FAR_WALL + WALL_FACE + WALL),
		SHOP_FRONT.x, SHOP_FRONT.y)


## The east end: its tiles over the doorway gone, its wall rebuilt round the chapel's doorway.
func _east_end() -> void:
	var lo := DOOR_Z - DOOR.x / 2.0
	var hi := DOOR_Z + DOOR.x / 2.0
	for panel: MeshInstance3D in wall_panels.duplicate():
		var box := panel.global_transform * panel.get_aabb()
		if box.position.x > half_run - 0.05 and box.end.z > lo + 0.01 and box.position.z < hi - 0.01:
			wall_panels.erase(panel)
			panel.free()
	var x := half_run + WALL_FACE
	var end := get_node_or_null("end_%d" % x)
	if end != null:
		end.free()
	var tile := _flat(TILE)
	_box(Vector3(x, 0.0, BACK_WALL - WALL), Vector3(x + WALL, HEIGHT, lo), tile, "east_end_north")
	_box(Vector3(x, 0.0, hi), Vector3(x + WALL, HEIGHT, FAR_WALL + WALL), tile, "east_end_south")
	_box(Vector3(x, DOOR.y, lo), Vector3(x + WALL, HEIGHT, hi), tile, "east_end_lintel")
	chapel_door = Node3D.new()
	chapel_door.name = "chapel_door"
	add_child(chapel_door)
	chapel_door.position = Vector3(x + WALL / 2.0, 0.0, DOOR_Z)


## The west end: open its whole width and height on the Pasaje.
func _west_end() -> void:
	for panel: MeshInstance3D in wall_panels.duplicate():
		if (panel.global_transform * panel.get_aabb()).end.x < -half_run + 0.05:
			wall_panels.erase(panel)
			panel.free()
	var end := get_node_or_null("end_%d" % (-half_run - WALL_FACE - WALL))
	if end != null:
		end.free()


## Standalone, a stub of the Pasaje's floor past the mouth and of the chapel's through its doorway, so the lane can be
## walked and judged alone. (Task 5 dresses them.)
func _stubs() -> void:
	stub = Node3D.new()
	stub.name = "stub"
	add_child(stub)
	if not standalone:
		stub.visible = false
		return
	var floor_look := _flat(FLOOR)
	var middle := (BACK_WALL + FAR_WALL) / 2.0
	var floors := [[Vector3(-half_run - PASAJE_STUB.x, -0.2, middle - PASAJE_STUB.y / 2.0), Vector3(-half_run, 0.0, middle + PASAJE_STUB.y / 2.0)],
		[Vector3(half_run, -0.2, DOOR_Z - DOOR.x / 2.0), Vector3(half_run + WALL_FACE + WALL + CHAPEL_STUB, 0.0, DOOR_Z + DOOR.x / 2.0)]]
	for k in floors.size():
		_box(floors[k][0], floors[k][1], floor_look, "stub_floor_%d" % k)
		var slab := get_node("stub_floor_%d" % k)
		slab.reparent(stub)


## A box built by _box (`name`, from `lo` to `hi`) rebuilt as two, cut away along x between `from` and `to`.
func _cut(name: String, lo: Vector3, hi: Vector3, from: float, to: float) -> void:
	var old := get_node_or_null(name)
	if old == null:
		return
	var look: Material = (old as MeshInstance3D).mesh.surface_get_material(0)
	old.free()
	_box(lo, Vector3(from, hi.y, hi.z), look, name + "_a")
	_box(Vector3(to, lo.y, lo.z), hi, look, name + "_b")
