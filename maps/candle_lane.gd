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
## The chapel's doorway in the east end: its width, its height, its middle across the lane (plan y 74.55: its frame's
## outer edges on the end tiles' joints, so no panel beside it is lost to the opening).
const DOOR := Vector2(3.0, 2.8)
const DOOR_Z := 0.2
## The stubs beyond the ends (standalone only): how far the Pasaje's floor runs past the mouth, how wide it is across,
## how far the chapel's floor runs in through the doorway.
const PASAJE_STUB := Vector2(10.0, 18.0)
const CHAPEL_STUB := 3.0
## The lane's own pieces (tools/eclipse/candle_lane.py): the chapel's doorway frame, the votive ledges, the milagros
## board and the mouth's portal (built where they stand in the lane), the Pasaje's puesto, the station's sign, the
## way's arrows; the ledges' wicks.
const LANE_KIT := "res://assets/eclipse/kit/candle_lane.glb"
const LANE_WICKS := "res://assets/eclipse/source/candle_lane_wicks.json"
## How far the end wall's opening reaches inside the doorway's frame (m, each side and over it): the wall's cut faces
## buried in the stone, the way through still the frame's 3 m.
const DOOR_INSET := 0.05
## How far along a ledge the wicks sharing one flame system (and its one light) run (m).
const CANDLE_RUN := 1.5
## The station's sign under the vault: how far in from the mouth.
const SIGN_IN := 0.9
## The way's arrows on the walls, at ARROW_Y: [piece, x along the lane, its wall (-1 the back, 1 the far), where it
## points]. (On the far wall a plate is turned round, so arrow_east points west.)
const ARROWS := [["arrow_east", -14.2, -1, "east"], ["arrow_west", 14.6, -1, "west"], ["arrow_east", -1.2, 1, "west"]]
const ARROW_Y := 2.05
## The Pasaje stub's puestos, either side of the mouth (their fronts' middles out from the mouth, facing into the
## Pasaje); how far up and down it from the mouth's middle its lit backdrops close it (clear of the puestos' ends);
## their light.
const PUESTOS := [Vector3(-1.4, 0.0, -4.0), Vector3(-1.4, 0.0, 6.2)]
const BACKDROP := 7.0
const PASAJE_GLOW := Color(1.0, 0.55, 0.42)
## The chapel's glimpse: its warm light 2 m in past the doorway's wall, its backdrop at the stub's end, its width.
const CHAPEL_GLOW := Color(1.0, 0.66, 0.36)
const CHAPEL_IN := 2.0
const CHAPEL_WIDTH := 6.0
## How brightly the backdrops glow (the Pasaje's, the chapel's): dim as the lane's own light, never a lit screen.
const BACKDROP_GLOW := Vector2(0.035, 0.03)
## How much of the stubs' lights the fog takes up.
const STUB_HAZE := 0.15

## Judged on its own (the stubs at its ends), or set into maps/metro (no stubs: the map's spaces meet it).
@export var standalone := true

var shop: Node3D
var chapel_door: Node3D
var stub: Node3D
var door_frame: MeshInstance3D
var ledges: MeshInstance3D
var milagros: MeshInstance3D
var mouth_sign: MeshInstance3D
var mouth_portal: MeshInstance3D
var arrows: Array[MeshInstance3D] = []
## The flames on the ledges (Vfx "candles", a run of wicks each, each its light) and every wick they stand on.
var candles: Array[Node3D] = []
var candle_wicks: Array[Vector3] = []


func _ready() -> void:
	half_run = LANE_HALF
	# The walk's order (plan x: the stall at 12.8 where the bay has it; her cart beside it toward the market; the niche
	# near the mouth on the north wall, across from the bench, the nahual lying by the bench; the fire main's hydrant on
	# the far wall clear of them all).
	places["cart"] = Vector3(-3.0, 0.0, 2.6)
	places["niche"] = Vector3(-10.0, 0.0, BACK_WALL)
	places["niche_yaw"] = 0.0
	places["bench"] = Vector3(-8.9, 0.0, FAR_WALL)
	places["nahual"] = Vector3(-6.6, 0.0, 4.35)
	super._ready()
	_shop_front()
	_east_end()
	_west_end()
	_lane_pieces()
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
	_box(Vector3(x, 0.0, BACK_WALL - WALL), Vector3(x + WALL, HEIGHT, lo - DOOR_INSET), tile, "east_end_north")
	_box(Vector3(x, 0.0, hi + DOOR_INSET), Vector3(x + WALL, HEIGHT, FAR_WALL + WALL), tile, "east_end_south")
	_box(Vector3(x, DOOR.y + DOOR_INSET, lo - DOOR_INSET), Vector3(x + WALL, HEIGHT, hi + DOOR_INSET), tile, "east_end_lintel")
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


## The lane's own pieces: the chapel's doorway framed, the votive ledges and their flames, the milagros board by the
## doorway, the portal round the mouth (the services run into it), the station's sign over the mouth, the way's arrows.
## (Not solid: the walls and floor are.)
func _lane_pieces() -> void:
	if not ResourceLoader.exists(LANE_KIT):
		missing.append(LANE_KIT)
		return
	var meshes := _kit(LANE_KIT)
	var look := Painterly.material(_painted(["candle_lane.png", "candle_lane_base.png"]), &"bespoke")
	door_frame = _place(meshes["chapel_door"], look, "chapel_door", Vector3.ZERO, 0.0, false)
	door_frame.name = "door_frame"
	ledges = _place(meshes["votive_ledges"], look, "votive_ledges", Vector3.ZERO, 0.0, false)
	milagros = _place(meshes["milagros_board"], look, "milagros_board", Vector3.ZERO, 0.0, false)
	mouth_portal = _place(meshes["mouth_portal"], look, "mouth_portal", Vector3.ZERO, 0.0, false)
	mouth_sign = _place(meshes["enamel_sign"], look, "enamel_sign", Vector3(-half_run + SIGN_IN, HEIGHT, (BACK_WALL + FAR_WALL) / 2.0),
		PI / 2.0, false)
	for arrow: Array in ARROWS:
		var wall: float = BACK_WALL if arrow[2] < 0 else FAR_WALL
		var plate := _place(meshes[arrow[0]], look, arrow[0], Vector3(arrow[1], ARROW_Y, wall), 0.0 if arrow[2] < 0 else PI, false)
		plate.name = "arrow_%d" % arrows.size()
		plate.set_meta("points", arrow[3])
		arrows.append(plate)
	_candles()


## The ledges' candles lit: their wicks in runs of CANDLE_RUN along each ledge, a flame system (and its light) to a run.
func _candles() -> void:
	if not FileAccess.file_exists(LANE_WICKS):
		missing.append(LANE_WICKS)
		return
	var runs := {}
	for w in (JSON.parse_string(FileAccess.get_file_as_string(LANE_WICKS)) as Dictionary).get("votive_ledges", []):
		var at: Vector3 = ledges.global_transform * Vector3(w[0], w[1], w[2])
		candle_wicks.append(at)
		var key := "%s%d" % ["far" if w[2] > 1.0 else "back", floori(w[0] / CANDLE_RUN)]
		runs.get_or_add(key, []).append(at)
	for key: String in runs:
		var middle := Vector3.ZERO
		var wicks := []
		for at: Vector3 in runs[key]:
			middle += at / runs[key].size()
			wicks.append([at.x, at.y, at.z])
		var flames := Vfx.system("candles")
		flames.name = "votives_%s" % key
		add_child(flames)
		Vfx.place(flames, middle, {"wicks": wicks})
		Vfx.emit(flames, true)
		candles.append(flames)


## Standalone, a stub of the Pasaje past the mouth (its floor, its east wall either side of the mouth with a puesto
## against each, lit backdrops closing it up and down, a far wall) and a glimpse of the chapel through its doorway (its
## floor, walls and ceiling, a warm light 2 m in, a backdrop where it ends), so the lane can be walked and judged
## alone. Set into the map, none of it is built.
func _stubs() -> void:
	stub = Node3D.new()
	stub.name = "stub"
	add_child(stub)
	if not standalone:
		stub.visible = false
		return
	var floor_look := _flat(FLOOR)
	var tile := _flat(TILE)
	var middle := (BACK_WALL + FAR_WALL) / 2.0
	var mouth := -half_run
	var chapel := half_run + WALL_FACE + WALL
	var side_z := Vector2(DOOR_Z - CHAPEL_WIDTH / 2.0, DOOR_Z + CHAPEL_WIDTH / 2.0)
	var boxes := [
		["stub_floor_0", Vector3(mouth - PASAJE_STUB.x, -0.2, middle - PASAJE_STUB.y / 2.0), Vector3(mouth, 0.0, middle + PASAJE_STUB.y / 2.0), floor_look],
		["stub_floor_1", Vector3(half_run, -0.2, side_z.x), Vector3(chapel + CHAPEL_STUB, 0.0, side_z.y), floor_look],
		["stub_wall_north", Vector3(mouth - WALL, 0.0, middle - PASAJE_STUB.y / 2.0), Vector3(mouth, HEIGHT, BACK_WALL - WALL_FACE - WALL), tile],
		["stub_wall_south", Vector3(mouth - WALL, 0.0, FAR_WALL + WALL_FACE + WALL), Vector3(mouth, HEIGHT, middle + PASAJE_STUB.y / 2.0), tile],
		["stub_wall_west", Vector3(mouth - PASAJE_STUB.x - WALL, 0.0, middle - PASAJE_STUB.y / 2.0), Vector3(mouth - PASAJE_STUB.x, HEIGHT, middle + PASAJE_STUB.y / 2.0), tile],
		["stub_ceiling", Vector3(mouth - PASAJE_STUB.x - WALL, HEIGHT, middle - PASAJE_STUB.y / 2.0), Vector3(mouth - WALL_FACE - WALL, HEIGHT + 0.2, middle + PASAJE_STUB.y / 2.0), tile],
		["chapel_wall_north", Vector3(chapel, 0.0, side_z.x - WALL), Vector3(chapel + CHAPEL_STUB, HEIGHT + 0.5, side_z.x), tile],
		["chapel_wall_south", Vector3(chapel, 0.0, side_z.y), Vector3(chapel + CHAPEL_STUB, HEIGHT + 0.5, side_z.y + WALL), tile],
		["chapel_ceiling", Vector3(chapel, HEIGHT + 0.5, side_z.x - WALL), Vector3(chapel + CHAPEL_STUB, HEIGHT + 0.7, side_z.y + WALL), tile]]
	for b: Array in boxes:
		_box(b[1], b[2], b[3], b[0])
		get_node(NodePath(b[0])).reparent(stub)

	if ResourceLoader.exists(LANE_KIT):
		var puesto: Mesh = _kit(LANE_KIT)["puesto"]
		var look := Painterly.material(_painted(["candle_lane.png", "candle_lane_base.png"]), &"bespoke")
		for i in PUESTOS.size():
			# (Turned to face into the Pasaje, its back to the wall beside the mouth.)
			var stall_at: Vector3 = PUESTOS[i]
			var piece := _place(puesto, look, "puesto", Vector3(mouth + stall_at.x, 0.0, stall_at.z), -PI / 2.0, false)
			piece.name = "puesto_%s" % ["north", "south"][i]
			piece.reparent(stub)

	# The Pasaje's lit reaches up and down it, and the chapel's candlelit far wall: glowing cards, each with its light.
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var card := _backdrop("backdrop_%s" % ["north", "south"][i], Vector2(PASAJE_STUB.x, HEIGHT), PASAJE_GLOW, BACKDROP_GLOW.x)
		card.position = Vector3(mouth - PASAJE_STUB.x / 2.0, HEIGHT / 2.0, middle + side * BACKDROP)
		card.rotation.y = 0.0 if side < 0 else PI
		_glow("pasaje_glow_%d" % i, Vector3(mouth - PASAJE_STUB.x / 2.0, 2.6, middle + side * (BACKDROP - 1.2)), PASAJE_GLOW, 1.4, 7.0)
	var far := _backdrop("chapel_backdrop", Vector2(CHAPEL_WIDTH, HEIGHT + 0.5), CHAPEL_GLOW, BACKDROP_GLOW.y)
	far.position = Vector3(chapel + CHAPEL_STUB - 0.02, (HEIGHT + 0.5) / 2.0, DOOR_Z)
	far.rotation.y = -PI / 2.0
	_glow("chapel_glow", Vector3(chapel + CHAPEL_IN, 1.7, DOOR_Z), CHAPEL_GLOW, 1.6, 5.5)


## A card at a stub's end glowing with what lies beyond it: dark at the floor and the vault, lit between (stalls'
## lamps and neon up the Pasaje; candles round the chapel's altar). Faces +z until turned.
func _backdrop(node_name: String, size: Vector2, colour: Color, energy: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.45, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(0.05, 0.05, 0.05), Color.WHITE, Color(0.45, 0.45, 0.45), Color.BLACK])
	var glow := GradientTexture2D.new()
	glow.gradient = fade
	glow.fill_from = Vector2(0.5, 1.0)
	glow.fill_to = Vector2(0.5, 0.0)
	var look := StandardMaterial3D.new()
	look.albedo_color = Color.BLACK
	look.emission_enabled = true
	look.emission_texture = glow
	look.emission = colour
	look.emission_energy_multiplier = energy
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = look
	var card := MeshInstance3D.new()
	card.name = node_name
	card.mesh = quad
	stub.add_child(card)
	return card


func _glow(node_name: String, at: Vector3, colour: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	# (A breath of haze about it, no more: at the fog's full share it fills the doorway like a lit sheet.)
	light.light_volumetric_fog_energy = STUB_HAZE
	stub.add_child(light)
	light.position = at


## A box built by _box (`name`, from `lo` to `hi`) rebuilt as two, cut away along x between `from` and `to`.
func _cut(name: String, lo: Vector3, hi: Vector3, from: float, to: float) -> void:
	var old := get_node_or_null(name)
	if old == null:
		return
	var look: Material = (old as MeshInstance3D).mesh.surface_get_material(0)
	old.free()
	_box(lo, Vector3(from, hi.y, hi.z), look, name + "_a")
	_box(Vector3(to, lo.y, lo.z), hi, look, name + "_b")
