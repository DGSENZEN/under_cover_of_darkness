extends "res://maps/underground_lab.gd"
## The candle lane (docs/superpowers/specs/2026-10-23-candle-lane-design.md): the Underground corridor bay run out to the
## Metro's lane between the Pasaje and the chapel, the librarian's shop opening off its south side. The bay's frame: x
## along the lane, z across it (BACK_WALL its north wall, FAR_WALL its south), the floor at 0; plan (x, y) is
## (x + 12.8, z + 74.35), its floor −11. Built to be judged on its own (standalone: with a stub of the Pasaje at its mouth
## and a glimpse of the chapel through its doorway), then set whole into maps/metro, where the map's own spaces meet it.

const LIBRARY := preload("res://maps/library_lab.tscn")
const WatchingEyes := preload("res://scripts/Visual/WatchingEyes.gd")
const WispsScript := preload("res://scripts/Visual/Wisps.gd")
const Silhouette := preload("res://scripts/Visual/Silhouette.gd")
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
## The lane crowded (after the first look): candles massed on the floor where the ledges ran out of room, and under
## her niche and the milagros board; marigolds; papel picado before the chapel; the pipes' works off their mains; the
## air line's hoods at the walls' feet (the ánimas come and go by them); the old culvert the nahual looks out of.
## [piece, where, turned]: masses and buckets with their backs to their wall, the works and culvert on its face.
const DRESSING := [
	["candle_mass_a", Vector3(12.8, 0.0, BACK_WALL + 0.53), 0.0],
	["candle_mass_b", Vector3(12.0, 0.0, FAR_WALL - 0.36), PI],
	["candle_mass_b", Vector3(16.42, 0.0, 3.1), -PI / 2.0],
	["candle_mass_b", Vector3(-10.0, 0.0, BACK_WALL + 0.36), 0.0],
	["flower_bucket", Vector3(13.65, 0.0, BACK_WALL + 0.2), 0.0],
	["flower_bucket", Vector3(16.3, 0.0, 2.5), 0.0],
	["flower_bucket", Vector3(-10.6, 0.0, BACK_WALL + 0.2), 0.0],
	["picado_strings", Vector3.ZERO, 0.0],
	["gas_meter", Vector3(-6.6, 0.0, BACK_WALL), 0.0],
	["main_gauge", Vector3(9.1, 0.0, BACK_WALL), 0.0],
	["air_branch", Vector3(-13.8, 0.0, FAR_WALL), PI],
	["air_branch", Vector3(0.9, 0.0, FAR_WALL), PI],
	["culvert", Vector3(-5.0, 0.0, FAR_WALL), PI],
]
## The ánimas' other ways up, by the vents: [the vent's foot on its wall, which way out of the wall (+1 the back
## wall's, -1 the far's), how far its face stands out, its slots' heights, how many come by it, their sizes, their
## tempers (Animas.gd), how far they go]. The hood by the mouth: little ones, mostly shy; the hood mid-lane: hungry
## for the candles; the old grille: big lurkers that keep to it.
const VENT_SOULS := [
	[Vector3(-13.8, 0.0, FAR_WALL), -1.0, 0.16, [0.2, 0.3], 6, Vector2(0.45, 0.75), {"shy": 3.0, "beggar": 1.0}, 4.0],
	[Vector3(0.9, 0.0, FAR_WALL), -1.0, 0.16, [0.2, 0.3], 4, Vector2(0.8, 1.15), {"hungry": 2.0, "beggar": 1.0}, 6.0],
	[Vector3(VENT_X, 0.0, BACK_WALL), 1.0, 0.05, [0.25, 0.36], 3, Vector2(1.2, 1.5), {"lurker": 1.0}, 2.0],
]
## The nahual's haunts in the lane (x, y, z, its turn: lying out from its wall, its head toward the lane's middle):
## by the bench (where the bay has it), beside the culvert it comes and goes by, on the north wall's foot between her
## niche and the gas meter, by the hood at the mouth.
const HAUNTS := [Vector4(-6.6, 0.0, 4.35, PI / 2.0), Vector4(-4.1, 0.0, 4.3, PI / 2.0), Vector4(-7.7, 0.0, BACK_WALL + 0.25, -PI / 2.0),
	Vector4(-15.3, 0.0, 4.3, PI / 2.0)]
## Where its eyes look out of the culvert while it is away: in the dark a hand behind the bars (tools/eclipse/
## candle_lane.py CULVERT, CULVERT_DARK).
const CULVERT_EYES := Vector3(-5.0, 0.34, FAR_WALL - 0.29)
## The lane's people (scripts/Visual/Silhouette.gd), each side-on to the way, facing along the lane: [pose, where
## (bay frame, at the foot), its face toward the lane's middle (+1 from the north side, -1 from the south), mirrored
## (to face the other way)]. At the end of her counter, a woman bargaining and a man waiting his turn; before the
## chapel, a woman and a man kneeling toward its doorway; at the mouth, the crowd coming in and going out.
const PEOPLE := [
	["bargaining", Vector3(0.65, 0.0, 0.1), 1.0, false],
	["waiting", Vector3(1.85, 0.0, 0.15), 1.0, false],
	["kneeling_a", Vector3(14.3, 0.0, -0.75), 1.0, true],
	["kneeling_b", Vector3(13.5, 0.0, 2.95), -1.0, false],
	["walking_a", Vector3(-15.0, 0.0, -0.5), 1.0, false],
	["walking_b", Vector3(-14.3, 0.0, 2.8), -1.0, false],
	["walking_c", Vector3(-15.7, 0.0, 0.1), 1.0, false],
]
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
var ledges: Array[MeshInstance3D] = []
var masses: Array[MeshInstance3D] = []
var milagros: MeshInstance3D
var mouth_sign: MeshInstance3D
var mouth_portal: MeshInstance3D
var arrows: Array[MeshInstance3D] = []
## The flames (Vfx "candles": a run of a ledge's wicks or a floor mass's each, each its light), and every wick on the
## ledges.
var candles: Array[Node3D] = []
var candle_wicks: Array[Vector3] = []
## The ánimas that come up by the vents (VENT_SOULS), each source its own.
var vent_souls: Array[Node3D] = []
## The nahual's eyes in the culvert (scripts/Visual/WatchingEyes.gd).
var culvert_eyes: Node3D
## The ánimas' warmth slipping out of their ways up into the candles' flames (scripts/Visual/Wisps.gd).
var wisps: Node3D
## Its people, black cut-outs (PEOPLE).
var people: Array[MeshInstance3D] = []


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
	_vent_souls()
	_nahual_ways()
	_people()
	_stubs()
	shop = LIBRARY.instantiate()
	shop.name = "Library"
	shop.standalone = false
	shop.player = player
	shop.transform = Transform3D(Basis(Vector3.UP, PI), SHOP_AT)
	add_child(shop)
	inspection_sections.append(shop)


## The vents' ánimas fear what the drain's fear and gather where they gather (the dark train, the procession).
func _process(delta: float) -> void:
	super._process(delta)
	for souls in vent_souls:
		souls.hush = animas.hush if animas != null else 0.0
		souls.gather = animas.gather if animas != null else null


## The ánimas up by the vents (VENT_SOULS): each source at its vent's face, out of its wall, making for the lane's
## candles (the drain's, the ledges', the masses').
func _vent_souls() -> void:
	var hands: Array[Mesh] = []
	if ResourceLoader.exists(UNCANNY_KIT):
		var kit := _kit(UNCANNY_KIT)
		hands = [kit["anima_hand_reach"], kit["anima_hand_claw"]] as Array[Mesh]
	var lit := PackedVector3Array(animas.candles) if animas != null else PackedVector3Array()
	for flames in candles:
		lit.append(flames.global_position)
	for k in VENT_SOULS.size():
		var vent: Array = VENT_SOULS[k]
		var souls: Node3D = AnimasScript.new()
		souls.name = "vent_animas_%d" % k
		souls.hand_meshes = hands
		souls.colour = Color("b8f04a")
		souls.seed = 41 + 17 * k
		souls.flee_from = player
		souls.mouth = "wall"
		souls.lanes = PackedFloat32Array(vent[3])
		souls.count = vent[4]
		souls.want_out = maxi(1, int(vent[4]) - 1)
		souls.sizes = vent[5]
		souls.tempers = vent[6]
		souls.tether = vent[7]
		souls.candles = lit
		add_child(souls)
		souls.position = vent[0] + Vector3(0.0, 0.0, float(vent[1]) * float(vent[2]))
		souls.rotation.y = 0.0 if vent[1] > 0.0 else PI
		vent_souls.append(souls)

	# Their warmth, now and then, out of where they come up and into the flames.
	wisps = WispsScript.new()
	wisps.name = "wisps"
	var ways_up := PackedVector3Array()
	if animas != null:
		ways_up.append(animas.global_position + Vector3(0.0, 0.05, 0.0))
	for souls in vent_souls:
		ways_up.append(souls.to_global(Vector3(0.0, 0.25, 0.05)))
	wisps.sources = ways_up
	var flames := PackedVector3Array()
	for flame in candles:
		flames.append(flame.global_position)
	wisps.targets = flames
	add_child(wisps)


## The nahual given the lane's haunts, and its eyes in the culvert for while it is away between them.
func _nahual_ways() -> void:
	if nahual == null:
		return
	var haunts: Array[Vector4] = []
	haunts.assign(HAUNTS)
	nahual.haunts = haunts
	culvert_eyes = WatchingEyes.new()
	culvert_eyes.name = "culvert_eyes"
	culvert_eyes.nahual = nahual
	culvert_eyes.watched = player
	add_child(culvert_eyes)
	culvert_eyes.position = CULVERT_EYES


## The people stood in their places (PEOPLE), their faces to the lane's middle.
func _people() -> void:
	for spec: Array in PEOPLE:
		var person: MeshInstance3D = Silhouette.make(spec[0], spec[3])
		if person == null:
			missing.append(Silhouette.SHEET)
			return
		add_child(person)
		person.position = spec[1]
		person.rotation.y = 0.0 if spec[2] > 0.0 else PI
		people.append(person)


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
	# (And what the bay hung on that stretch of wall: its name tablet, its bills, its splashes.)
	for n: Node in get_children():
		var at := (n as Node3D).position if n is Node3D else Vector3.INF
		if (n is Decal or String(n.name).begins_with("name_tablet")) and at.z > FAR_WALL - 0.3 \
				and at.x > SHOP_FRONT.x - 0.3 and at.x < SHOP_FRONT.y + 0.3:
			if n is MeshInstance3D:
				wall_panels.erase(n)
			if n is Decal:
				decals.erase(n)
			n.free()


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
	for kind in ["votive_north", "votive_south"]:
		ledges.append(_place(meshes[kind], look, kind, Vector3.ZERO, 0.0, false))
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
	for dressed: Array in DRESSING:
		var piece := _place(meshes[dressed[0]], look, dressed[0], dressed[1], dressed[2], false)
		if String(dressed[0]).begins_with("candle_mass"):
			masses.append(piece)
	_candles()


## The candles lit: the ledges' wicks in runs of CANDLE_RUN along each ledge, each floor mass's all together; a flame
## system (and its light) to a run or a mass.
func _candles() -> void:
	if not FileAccess.file_exists(LANE_WICKS):
		missing.append(LANE_WICKS)
		return
	var all_wicks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LANE_WICKS))
	var runs := {}
	for ledge in ledges:
		for w in all_wicks.get(String(ledge.get_meta("kind")), []):
			var at: Vector3 = ledge.global_transform * Vector3(w[0], w[1], w[2])
			candle_wicks.append(at)
			var key := "%s%d" % ["far" if w[2] > 1.0 else "back", floori(w[0] / CANDLE_RUN)]
			runs.get_or_add(key, []).append(at)
	for mass in masses:
		for w in all_wicks.get(String(mass.get_meta("kind")), []):
			runs.get_or_add(String(mass.name), []).append(mass.global_transform * Vector3(w[0], w[1], w[2]))
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
