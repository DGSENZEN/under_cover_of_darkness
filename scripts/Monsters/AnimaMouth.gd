extends Node3D
## The mouth, as a piece: the fused mass and its ribs (tools/monsters/build_anima_mouth.py), and
## arms grown out of it (build_mouth_arm.py), the game's own skulls pushed out of it, each still moving
## of itself. Its bottom hands dig into the earth and haul all of it up to them: a hand stays where it
## dug, in the world, and the arm is solved back from there to a shoulder sunk in the flesh. AnimaBody
## drives it; how it goes about is the body's.

const MODEL := "res://assets/monsters/anima_mouth.glb"
const ARM_MODEL := "res://assets/monsters/anima_mouth_arm.glb"
const LEFT_MODEL := "res://assets/monsters/anima_mouth_arm_left.glb"
const AnimaSkullScript := preload("res://scripts/Monsters/AnimaSkull.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const FINGER_NAMES := ["index", "middle", "ring", "pinky", "thumb"]
const ARMS := [&"Arm_1", &"Arm_2", &"Arm_3", &"Arm_4", &"Arm_5"]
const FACES := [&"Face_1", &"Face_2", &"Face_3"]
const MESHES := [&"Mass", &"RibsLeft", &"RibsRight", &"Gullet", &"Candles", &"Bones"]
## The skulls' size.
const SKULL_SIZE := 1.3
## The model's floor and middle, from the body's: the monster stands at its own height above the floor.
const MIDDLE_BEHIND := -0.25
## How much bigger than it was built it stands: it is the heaviest of them.
const SIZE := 1.25
## How far each side of the ribs swings at the widest (rad).
const RIBS_SWING := 0.42

## The arm's bones, as built (m, in the arm's own size); how far into the flesh the shoulder is from
## where it comes out, and how far an arm may be drawn out.
const BONE_LENGTH := 0.42
const SHOULDER_IN := 0.3
const DRAWN_OUT_MOST := 1.25
## Which arms dig: the two that haul it, then the two that brace and haul a little.
const DIGGERS := 4
const HAULERS := 2
## How long each stays dug in as it hauls (s), none in step; how long it takes to come up and over.
const HAUL_TAKES: Array[float] = [1.75, 2.15, 2.6, 3.05]
const REACH_TAKES := 0.85
const REACH_LIFT := 0.42
## Where it digs in, from its shoulder (m), ahead and out to its side; how far up its wrist stays.
const DIGS_AHEAD: Array[float] = [0.62, 0.62, 0.3, 0.3]
const DIGS_OUT: Array[float] = [0.62, 0.62, 0.85, 0.85]
const WRIST_UP := 0.36
## How steeply its hand drives down into the earth; how shut its fingers are, dug in.
const DRIVES_DOWN := 1.5
const DUG_SHUT := 0.62
## How far it lets a dug hand trail before it has to let go (m).
const TRAILS_MOST := 1.05
## It goes as it hauls: how fast, of its speed, with nothing hauling, and hauling flat out; what the
## braces add; how far it heaves up with a haul (m), rolls side to side and rocks onto its front (rad).
const LURCH_LEAST := 0.18
const LURCH_MOST := 0.95
const BRACES_ADD := 0.25
const HEAVES := 0.13
const ROLLS := 0.14
const ROCKS := 0.12
## An arm that isn't digging, out from its shoulder (m), hanging; how fast it gets where it is going.
const FREE_OUT := 0.62
const FREE_HANGS := 0.3
const FREE_RATE := 7.0
const GRAB_RATE := 3.2
const GRAB_SPREAD := 0.28
## The rake: how far back each arm draws, how far over it comes (rad), a little after the last.
const RAKE_BACK := 0.75
const RAKE_OVER := 1.15
const RAKE_LAGS := 0.035
const RAKING_PAST := 0.35
const RAKE_RATE := 2.4
## How much bigger it is at its most swollen, each way: across, up, out toward you; how far on it goes.
const SWELLS := Vector3(0.26, 0.15, 0.34)
const SWELLS_ON := 0.3
## The life in what pushes out of it: how far an arm sways (m, rad), a finger's curl about what, how far.
const SWAY := 0.05
const HEAD_SWAY := 0.14
const CURL := 0.42
const CURLS := 0.32
const JAW_REST := 0.34
const JAW_WORKS := 0.3
const FLOOR_MASK := 1
const SOUL_MODEL := "res://assets/monsters/mouth_soul.glb"
const SoulShader := preload("res://scripts/Monsters/mouth_soul.gdshader")
## Those in it, straining out: where they come from on it (as built), how far they get, how long it takes
## them, how long it lets them, how sharply it hauls them back, and how long until they try again (s).
const SOUL_FROM: Array[Vector3] = [
	Vector3(0.0, 0.95, 0.35), Vector3(0.42, 0.72, 0.5), Vector3(-0.42, 0.65, 0.55), Vector3(0.5, 0.25, 0.65),
	Vector3(-0.5, 0.3, 0.6), Vector3(0.2, 0.55, 1.05), Vector3(-0.22, 0.85, 0.85), Vector3(0.0, 0.3, 1.2),
]
const SOUL_REACH := Vector2(0.75, 1.25)
const SOUL_RISES := Vector2(0.9, 1.7)
const SOUL_STRAINS := Vector2(0.3, 0.9)
const SOUL_HAULED_IN := 0.16
const SOUL_RESTS := Vector2(0.5, 2.6)
## With its hunger up, how much further, and how much of the way they lean at you.
const SOUL_HUNGER_REACH := 0.5
const SOUL_LEANS := 0.9
const SOUL_HUNGRY_FROM := 0.55
## How much of its hunger it has crawling along, and how fast it comes up and goes.
const HUNGER_LOW := 0.08
const HUNGER_RATE := 2.0
## Their heads, of as built.
const SOUL_HEAD := 1.35
## The earth it throws up round each hand: how many are out at once, how long one stays, how long it takes
## to rise, and to sink back; its paint.
const EARTHS := 12
const EARTH_STAYS := 9.0
const EARTH_RISES := 0.1
const EARTH_SINKS := 1.5
const EARTH_DARK := Color(0.03, 0.022, 0.018)
const EARTH_LIGHT := Color(0.085, 0.062, 0.045)

var _parts := {}
var _made: Node3D
var _made_at := Vector3.ZERO
var _souls: Array[Node3D] = []
var _hands: Array[Skeleton3D] = []
var _hand_meshes: Array[MeshInstance3D] = []
var _markers: Array[Node3D] = []
var _skulls: Array[Node3D] = []
var _rest: Dictionary = {}
var _ribs_open := 0.0
var _clock := 0.0
var _heave := 0.0
var _hauls := 0
var _swell := 0.0
var _rake: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _rake_speed: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
## Each arm: its wrist in the world; dug in, and where and on what; how long it has hauled, or been
## on its way; where it came up from; how shut its fingers are.
var _wrist: Array[Vector3] = []
var _dug: Array[bool] = []
var _dug_floor: Array[float] = []
var _haul_t: Array[float] = []
var _reach_t: Array[float] = []
var _came_from: Array[Vector3] = []
var _shut: Array[float] = []
var _stretch: Array[float] = []
var _flesh_look: ShaderMaterial
var _earths: Array[MeshInstance3D] = []
var _earth_age: Array[float] = []
var _earth_next := 0
var _earth_look: ShaderMaterial
var _soul_nodes: Array[MeshInstance3D] = []
## Each soul: what it is doing (0 rests, 1 rises, 2 strains, 3 hauled in); how far into that; how long it takes;
## how far it is out of it, 0..1; where it is going, from where; how far.
var _soul_stage: Array[int] = []
var _soul_t: Array[float] = []
var _soul_takes: Array[float] = []
var _soul_out: Array[float] = []
var _soul_way: Array[Vector3] = []
var _soul_far: Array[float] = []
var _soul_was_yanked := false
var _hunger := 0.0
var _rng := RandomNumberGenerator.new()
var _placed := false
var _floor_y := 0.0


## Built on the body's flesh, and its bone: the same paint as the other forms.
func _init(flesh: ShaderMaterial, bone: ShaderMaterial, height: float) -> void:
	_flesh_look = flesh
	_earth_look = flesh.duplicate()
	_earth_look.set_shader_parameter(&"spectral", 0.0)
	_earth_look.set_shader_parameter(&"frays", 0.0)
	_earth_look.set_shader_parameter(&"rim", 0.0)
	_earth_look.set_shader_parameter(&"fill", 0.2)
	_made = (load(MODEL) as PackedScene).instantiate()
	add_child(_made)
	_made.scale = Vector3.ONE * SIZE
	_made_at = Vector3(0.0, -height, MIDDLE_BEHIND * -SIZE)
	_made.position = _made_at

	for id in MESHES:
		var mesh: MeshInstance3D = _made.find_child(id, true, false)
		_parts[id] = mesh
		mesh.set_surface_override_material(0, bone if id == &"RibsLeft" or id == &"RibsRight" or id == &"Bones" else flesh)

	for id in ARMS:
		var marker: Node3D = _made.find_child(id, true, false)
		_markers.append(marker)
		var hand: Node3D = (load(LEFT_MODEL if marker.position.x < 0.0 else ARM_MODEL) as PackedScene).instantiate()
		marker.add_child(hand)
		var mesh: MeshInstance3D = hand.find_children("*", "MeshInstance3D", true, false)[0]
		mesh.set_surface_override_material(0, flesh)
		_hand_meshes.append(mesh)
		_hands.append(hand.find_children("*", "Skeleton3D", true, false)[0])
		_souls.append(hand)
		_wrist.append(Vector3.ZERO)
		_dug.append(false)
		_dug_floor.append(0.0)
		_haul_t.append(0.0)
		_reach_t.append(0.0)
		_came_from.append(Vector3.ZERO)
		_shut.append(CURL)
		_stretch.append(1.0)

	for id in FACES:
		var marker: Node3D = _made.find_child(id, true, false)
		var skull: Node3D = AnimaSkullScript.new(bone)
		skull.scale = Vector3.ONE * SKULL_SIZE
		marker.add_child(skull)
		_skulls.append(skull)
		_souls.append(skull)
		_rest[skull] = skull.transform

	_build_souls()


func _ready() -> void:
	arrive()


## Whole, from the first: its hands already in the earth where it stands, each at its own point in its haul.
func arrive() -> void:
	_placed = true
	_ensure_rng()
	_floor_y = global_position.y + _made_at.y

	for i in _hands.size():
		_wrist[i] = _free_wrist(i, 0.0)

		if i < DIGGERS:
			_reach_t[i] = 0.0
			var shoulder_at := _world_shoulder(i)
			var to := _clear_of_walls(shoulder_at, shoulder_at - global_basis.z * DIGS_AHEAD[i] * 0.5 + global_basis.x * signf(_markers[i].position.x) * DIGS_OUT[i])
			_dig_in(i, to, true)
			_haul_t[i] = HAUL_TAKES[i] * fposmod(float(i) * 0.37 + 0.11, 1.0)
			_shut[i] = DUG_SHUT

		_solve_arm(i, 0.0, Vector3.ZERO)


func _ensure_rng() -> void:
	_rng.seed = hash(global_position)


func _build_souls() -> void:
	var made: Node3D = (load(SOUL_MODEL) as PackedScene).instantiate()
	var mesh: Mesh = (made.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	made.free()
	var look := ShaderMaterial.new()
	look.shader = SoulShader
	look.set_shader_parameter(&"noise", MeshVfx.noise())

	for n in SOUL_FROM.size():
		var soul := MeshInstance3D.new()
		soul.name = "Soul"
		soul.mesh = mesh
		soul.material_override = look
		soul.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		soul.visible = false
		soul.set_instance_shader_parameter(&"seed", float(n) * 2.7)
		add_child(soul)
		_soul_nodes.append(soul)
		_soul_stage.append(0)
		_soul_t.append(0.0)
		_soul_takes.append(0.4 + float(n) * 0.45)
		_soul_out.append(0.0)
		_soul_way.append(Vector3.UP)
		_soul_far.append(1.0)


## How many it holds, how many are out of it now, how far the furthest has got (m).
func souls_held() -> int:
	return _soul_nodes.size()


func souls_out() -> int:
	return _soul_out.filter(func(out): return out > 0.3).size()


func soul_reach() -> float:
	var furthest := 0.0

	for n in _soul_nodes.size():
		furthest = maxf(furthest, _soul_far[n] * _soul_out[n])

	return furthest


## Whether it has hauled any back in, yet.
func soul_yanked() -> bool:
	return _soul_was_yanked


## How much those out of it are going at `at`, the most: 1 straight at it.
func souls_toward(at: Vector3) -> float:
	var most := -1.0

	for n in _soul_nodes.size():
		if _soul_out[n] > 0.3:
			var from: Vector3 = _soul_nodes[n].global_position
			most = maxf(most, (-_soul_nodes[n].global_basis.z).normalized().dot((at - from).normalized()))

	return most


## How hungry it is showing, 0..1.
func hunger() -> float:
	return _hunger


func _work_souls(delta: float, grab_at: Vector3) -> void:
	var to_you: Vector3 = global_transform.affine_inverse().basis * (grab_at - global_position)

	for n in _soul_nodes.size():
		_soul_t[n] += delta

		# With its hunger up they don't rest, and it lets them strain.
		var hungry := _hunger > SOUL_HUNGRY_FROM
		var takes: float = _soul_takes[n] * (0.1 if hungry and _soul_stage[n] == 0 else 1.0)

		if _soul_t[n] >= takes and not (hungry and _soul_stage[n] == 2):
			_soul_t[n] = 0.0
			_soul_stage[n] = (_soul_stage[n] + 1) % 4

			match _soul_stage[n]:
				1:
					_soul_takes[n] = _rng.randf_range(SOUL_RISES.x, SOUL_RISES.y)
					var from: Vector3 = _soul_from(n)
					_soul_way[n] = (from - Vector3(0.0, 0.2, 0.55) + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0.0, 0.6), _rng.randf_range(-0.5, 0.5))).normalized()
					_soul_far[n] = _rng.randf_range(SOUL_REACH.x, SOUL_REACH.y)
				2:
					_soul_takes[n] = _rng.randf_range(SOUL_STRAINS.x, SOUL_STRAINS.y)
				3:
					_soul_takes[n] = SOUL_HAULED_IN
					_soul_was_yanked = true
				0:
					_soul_takes[n] = _rng.randf_range(SOUL_RESTS.x, SOUL_RESTS.y)

		var u: float = clampf(_soul_t[n] / maxf(_soul_takes[n], 0.01), 0.0, 1.0)
		var out: float = [0.0, 1.0 - pow(1.0 - u, 2.2), 1.0, 1.0 - u * u][_soul_stage[n]]
		_soul_out[n] = out
		var soul := _soul_nodes[n]
		soul.visible = out > 0.01

		if not soul.visible:
			continue

		var from_at: Vector3 = _soul_from(n)
		var way: Vector3 = _soul_way[n].lerp(to_you.normalized(), _hunger * SOUL_LEANS).normalized()
		var far: float = _soul_far[n] * out * (1.0 + _hunger * SOUL_HUNGER_REACH)
		var up := Vector3.UP if absf(way.y) < 0.95 else Vector3.BACK
		# Its head out there, its tail drawn out behind it to where it is held.
		soul.transform = Transform3D(Basis.looking_at(way, up).scaled(Vector3.ONE * SOUL_HEAD), from_at + way * far)
		soul.set_instance_shader_parameter(&"tail_long", maxf(far / SOUL_HEAD, 0.1))
		soul.set_instance_shader_parameter(&"shown", out)
		soul.set_instance_shader_parameter(&"strain", clampf(_hunger + (0.6 if _soul_stage[n] == 2 else 0.0) + (1.0 if _soul_stage[n] == 3 else 0.0), 0.0, 1.0))


## Where on it that soul strains out of, in this node's space.
func _soul_from(n: int) -> Vector3:
	var built := SOUL_FROM[n]
	return _made.transform * Vector3(built.x, built.y, built.z - 0.55)


func part(id: StringName) -> MeshInstance3D:
	return _parts.get(id)


func souls() -> Array[Node3D]:
	return _souls


## Where one of what pushes out of it is now: an arm by its wrist, a head by how it hangs.
func soul_at(index: int) -> Transform3D:
	return Transform3D(Basis.IDENTITY, _wrist[index]) if index < _hands.size() else _souls[index].transform


## How far the ribs stand open, 0..1.
func ribs_open() -> float:
	return _ribs_open


func ribs_to(open: float) -> void:
	_ribs_open = open
	# (RibsLeft lies at -x: it opens the way y turns, seen from above; RibsRight the other.)
	part(&"RibsLeft").rotation.y = RIBS_SWING * open
	part(&"RibsRight").rotation.y = -RIBS_SWING * open


## Where each hauling arm is in its going, -1..1.
func arm_stride(which: int) -> float:
	var round_takes: float = HAUL_TAKES[which] + REACH_TAKES
	var into: float = _haul_t[which] if _dug[which] else HAUL_TAKES[which] + _reach_t[which] * REACH_TAKES
	return sin(into / round_takes * TAU)


## Whether this arm's hand has dug in.
func arm_dug_in(which: int) -> bool:
	return _dug[which]


## The ground that hand last dug into.
func dug_floor(which: int) -> float:
	return _dug_floor[which]


## That arm's wrist, in the world.
func wrist(which: int) -> Vector3:
	return _wrist[which]


## How low the tip of that hand's longest finger is, in the world.
func fingertip_y(which: int) -> float:
	var hand := _hands[which]
	var last: Transform3D = hand.get_bone_global_pose(hand.find_bone("middle_03"))
	var tip: Vector3 = last * (Vector3.UP * hand.get_bone_rest(hand.find_bone("middle_03")).origin.length())
	return (hand.global_transform * tip).y


## How far that arm is drawn out past its length, 1 at its length.
func arm_stretch(which: int) -> float:
	return _stretch[which]


## How far the end of that arm is from its shoulder (m): it should come to it.
func arm_end_gap(which: int) -> float:
	var hand := _hands[which]
	var last: Transform3D = hand.get_bone_global_pose(hand.find_bone("arm_2"))
	return (last * (Vector3.UP * BONE_LENGTH)).distance_to(_shoulder())


## How many heaps of earth it has left, there now.
func earth_shown() -> int:
	return _earths.filter(func(earth): return earth.visible).size()


## How many hauls have landed: a hand has dug in, and will drag all of it on.
func hauls_done() -> int:
	return _hauls


## How high the mass has heaved with them (m).
func heave() -> float:
	return _heave


## How far over it the mass has rolled with them (rad).
func roll() -> float:
	return (_hauling(0) - _hauling(1)) * ROLLS


## How far over onto its front the mass has rocked (rad): it pitches into each haul.
func rock() -> float:
	return (maxf(_hauling(0), _hauling(1)) - 0.5) * ROCKS * 2.0


## How it goes for now, of its speed: lurching on with each haul, and all but stopping between.
func lurch() -> float:
	var pulling := maxf(_hauling(0), _hauling(1)) + (_hauling(2) + _hauling(3)) * BRACES_ADD
	return LURCH_LEAST + minf(pulling * pulling, 1.0) * LURCH_MOST


## How far it is into its haul with that arm: nothing as it digs in, the most midway, nothing as it lets go.
func _hauling(which: int) -> float:
	return sin(clampf(_haul_t[which] / HAUL_TAKES[which], 0.0, 1.0) * PI) if _dug[which] else 0.0


## How many arms are coming over in a rake.
func arms_raking() -> int:
	var count := 0

	for value in _rake:
		count += 1 if value > RAKING_PAST else 0

	return count


## How swollen it is, 0..1 and a little past as it overshoots.
func swollen() -> float:
	return _swell


## How big it stands, as built, each way.
func size_now() -> Vector3:
	return _made.scale


## Each tick: what pushes out of it goes on moving, each in its own time. `speed`, `going`: how fast it is being
## dragged and where. `rake_to`: -1 drawn back, 0 at rest, 1 come over. `digs`: whether its hands are on
## the earth. `grab`: how far every arm it has is going for `grab_at`. `swell`, how swollen. `fed` shows on all of it.
func tick(delta: float, speed: float, going: Vector3, rake_to: float, digs: bool, grab: float, grab_at: Vector3, swell: float, fed: float, hurt: float, smoulder: float) -> void:
	_clock += delta
	_swell = swell
	_made.scale = (Vector3.ONE + SWELLS * swell) * SIZE
	_made.position = _made_at + Vector3(0.0, 0.0, -SWELLS_ON * swell)

	if not _placed:
		arrive()

	# Gathering at you, swollen, feeding: it blazes.
	_hunger = move_toward(_hunger, clampf(HUNGER_LOW + swell * 1.1 + fed * 0.25, 0.0, 1.0), delta * HUNGER_RATE)
	_work_souls(delta, grab_at)

	for i in _rake.size():
		var w := minf(TAU * RAKE_RATE, 0.8 / delta)
		var late := clampf(float(i) * RAKE_LAGS, 0.0, 0.2)
		_rake_speed[i] += (w * w * (rake_to - _rake[i]) - 2.0 * 0.75 * w * _rake_speed[i]) * delta * (1.0 - late)
		_rake[i] += _rake_speed[i] * delta

	var heaved := 0.0

	for i in _hands.size():
		# The two that haul stay on the earth to the last; the rest come up for a rake.
		var on_earth: bool = digs and i < DIGGERS and (i < HAULERS or absf(rake_to) < 0.01)
		var shut_to: float

		if on_earth:
			shut_to = _dig(i, delta, speed, going)
		else:
			_dug[i] = false
			_reach_t[i] = 0.0
			_came_from[i] = _wrist[i]
			var wanted := _free_wrist(i, grab).lerp(_grab_point(i, grab_at), grab)
			_wrist[i] = _wrist[i].lerp(wanted, 1.0 - exp(-lerpf(FREE_RATE, GRAB_RATE, grab) * delta))
			shut_to = lerpf(CURL, -0.1, grab)

		_shut[i] = lerpf(_shut[i], shut_to, 1.0 - exp(-14.0 * delta))
		_solve_arm(i, grab, grab_at)
		_curl_fingers(_hands[i], i)
		_hand_meshes[i].set_instance_shader_parameter(&"fed", fed)
		_hand_meshes[i].set_instance_shader_parameter(&"hurt", hurt)
		_hand_meshes[i].set_instance_shader_parameter(&"smoulder", smoulder)

		if i < HAULERS:
			heaved = maxf(heaved, _hauling(i))

	_heave = heaved * HEAVES
	_settle_earth(delta)

	for i in _skulls.size():
		var seed := float(i) * 3.1
		var skull := _skulls[i]
		var rest: Transform3D = _rest[skull]
		var sway := Basis.from_euler(Vector3(sin(_clock * (0.9 + float(i) * 0.13) + seed), sin(_clock * (0.7 + float(i) * 0.09) + seed * 1.7), 0.0) * HEAD_SWAY)
		skull.transform = Transform3D(sway * rest.basis, rest.origin)
		# (Stretched with the rest of it, they gape.)
		skull.open_to(clampf(JAW_REST + sin(_clock * (2.1 + float(i) * 0.7) + seed) * JAW_WORKS + swell * 0.5, 0.0, 1.0), 0.3)
		skull.paint(fed, hurt, smoulder)

	for id in MESHES:
		var mesh: MeshInstance3D = part(id)
		mesh.set_instance_shader_parameter(&"fed", fed)
		mesh.set_instance_shader_parameter(&"hurt", hurt)
		mesh.set_instance_shader_parameter(&"smoulder", smoulder)

	part(&"Mass").set_instance_shader_parameter(&"swell", maxf(swell, 0.0))

	for id in [&"Mass", &"RibsLeft", &"RibsRight", &"Bones"]:
		part(id).set_instance_shader_parameter(&"hunger", _hunger)

	for mesh in _hand_meshes:
		mesh.set_instance_shader_parameter(&"hunger", _hunger)


## One arm on the earth: dug in and hauling, or up and on its way to dig in again. How shut its fingers should be.
func _dig(i: int, delta: float, speed: float, going: Vector3) -> float:
	var shoulder_at := _world_shoulder(i)

	if _dug[i]:
		# Standing still, it holds on. It lets go when it has hauled what it can, or it is left behind.
		if speed > 0.05:
			_haul_t[i] += delta

		var left_behind := (_wrist[i] - shoulder_at).length() > TRAILS_MOST

		if _haul_t[i] >= HAUL_TAKES[i] or left_behind:
			_dug[i] = false
			_reach_t[i] = 0.0
			_came_from[i] = _wrist[i]

		return DUG_SHUT + sin(_clock * 3.0 + float(i)) * 0.03

	_reach_t[i] = minf(_reach_t[i] + delta / REACH_TAKES, 1.0)
	var u := _reach_t[i]
	var heading := Vector3(going.x, 0.0, going.z)
	var ahead: Vector3 = heading.normalized() if heading.length() > 0.08 else -global_basis.z
	var out: Vector3 = global_basis.x * signf(_markers[i].position.x)
	var to: Vector3 = _clear_of_walls(shoulder_at, shoulder_at + ahead * DIGS_AHEAD[i] + out * DIGS_OUT[i])
	to.y = _floor_y + WRIST_UP
	# Slow up and over, and it falls the last of the way.
	var along := u * u * (3.0 - 2.0 * u)
	_wrist[i] = _came_from[i].lerp(to, along) + Vector3.UP * sin(pow(u, 0.8) * PI) * REACH_LIFT

	if u >= 1.0:
		_dig_in(i, to)

	return lerpf(CURL, -0.15, sin(u * PI))


## Where it means to dig, kept on its own side of what is in the way.
func _clear_of_walls(from: Vector3, to: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(from, to, FLOOR_MASK)
	var hit := space.intersect_ray(ray)

	if hit.is_empty():
		return to

	var way := (to - from).normalized()
	return from + way * maxf(from.distance_to(hit["position"]) - 0.3, 0.0)


## It comes down: fingers into the earth, and what that throws up.
func _dig_in(i: int, to: Vector3, quietly := false) -> void:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(to + Vector3.UP * 0.7, to + Vector3.DOWN * 1.6, FLOOR_MASK)
	var hit := space.intersect_ray(ray)

	if not hit.is_empty():
		_floor_y = float(hit["position"].y)

	var at := Vector3(to.x, _floor_y + WRIST_UP, to.z)
	_wrist[i] = at
	_dug[i] = true
	_dug_floor[i] = _floor_y
	_haul_t[i] = 0.0

	if quietly:
		return

	_hauls += 1
	var on_floor := Vector3(at.x, _floor_y, at.z)
	var heavy := 1.0 if i < HAULERS else 0.55
	Fx.dust(self, on_floor, Vector3.UP, heavy, "dirt")
	_throw_up_earth(on_floor + _finger_way(i) * 0.3, heavy)


## The way that hand's fingers go in, on the level.
func _finger_way(i: int) -> Vector3:
	var way := _wrist[i] - _world_shoulder(i)
	way.y = 0.0
	return way.normalized() if way.length() > 0.01 else -global_basis.z


## What its fingers turn over, where they go in. It stays where it was thrown up.
func _throw_up_earth(at: Vector3, heavy: float) -> void:
	if _earths.size() < EARTHS:
		var earth := MeshInstance3D.new()
		earth.mesh = _earth_mesh()
		earth.material_override = _earth_look
		earth.top_level = true
		earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		earth.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(earth)
		_earths.append(earth)
		_earth_age.append(0.0)

	var earth := _earths[_earth_next]
	_earth_age[_earth_next] = 0.0
	earth.visible = true
	earth.set_meta(&"at", at)
	earth.set_meta(&"size", 0.8 + heavy * 0.5)
	earth.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), at)
	_earth_next = (_earth_next + 1) % EARTHS


func _settle_earth(delta: float) -> void:
	for n in _earths.size():
		var earth := _earths[n]

		if not earth.visible:
			continue

		_earth_age[n] += delta
		var age := _earth_age[n]

		if age >= EARTH_STAYS + EARTH_SINKS:
			earth.visible = false
			continue

		var up := minf(age / EARTH_RISES, 1.0) * (1.0 - clampf((age - EARTH_STAYS) / EARTH_SINKS, 0.0, 1.0))
		var size: float = earth.get_meta(&"size")
		var turned := Basis(earth.global_basis.get_rotation_quaternion())
		earth.global_transform = Transform3D(turned.scaled(Vector3(size, size * maxf(up, 0.01), size)), earth.get_meta(&"at"))


static var _earth_shared: ArrayMesh


## Clods and a torn lip of it, round a hole: one mesh, painted, and shared.
static func _earth_mesh() -> ArrayMesh:
	if _earth_shared != null:
		return _earth_shared

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41

	for n in 13:
		var angle := TAU * float(n) / 13.0 + rng.randf_range(-0.25, 0.25)
		var far := rng.randf_range(0.11, 0.2)
		var wide := rng.randf_range(0.05, 0.095)
		var at := Vector3(cos(angle) * far, wide * rng.randf_range(0.1, 0.5), sin(angle) * far)
		var size := Vector3(wide * rng.randf_range(0.9, 1.25), wide * rng.randf_range(0.8, 1.2), wide * rng.randf_range(0.9, 1.25))
		var tone := EARTH_DARK.lerp(EARTH_LIGHT, rng.randf())
		_add_clod(tool, at, size, tone, rng)

	tool.index()
	tool.generate_normals()
	_earth_shared = tool.commit()
	return _earth_shared


## A lump, its faces flat enough to read as broken earth.
static func _add_clod(tool: SurfaceTool, at: Vector3, size: Vector3, tone: Color, rng: RandomNumberGenerator) -> void:
	const RINGS := 4
	const AROUND := 6
	var points: Array[Vector3] = []

	for r in RINGS + 1:
		var down := PI * float(r) / float(RINGS)

		for a in AROUND:
			var turn := TAU * float(a) / float(AROUND)
			var rough := rng.randf_range(0.93, 1.07)
			points.append(at + Vector3(sin(down) * cos(turn) * size.x, cos(down) * size.y, sin(down) * sin(turn) * size.z) * rough)

	for r in RINGS:
		for a in AROUND:
			var n := (a + 1) % AROUND
			var corners: Array[Vector3] = [points[r * AROUND + a], points[r * AROUND + n], points[(r + 1) * AROUND + n], points[(r + 1) * AROUND + a]]

			for k in [0, 1, 2, 0, 2, 3]:
				tool.set_color(tone)
				tool.add_vertex(corners[k])


## Where that arm's wrist would be if it wasn't on the earth: out from its shoulder, drawn back or come over for a rake.
func _free_wrist(i: int, _grab: float) -> Vector3:
	var over: float = _rake[i] * (RAKE_OVER if _rake[i] > 0.0 else RAKE_BACK)
	var out := Basis(Vector3.RIGHT, -over) * Vector3(0.0, 0.0, -FREE_OUT)
	var seed := float(i) * 2.3 + 0.7
	out += Vector3(sin(_clock * (0.9 + float(i) * 0.13) + seed), sin(_clock * (0.7 + float(i) * 0.09) + seed * 1.7), 0.0) * SWAY
	return _markers[i].global_transform * out + Vector3.DOWN * FREE_HANGS


## Each arm goes for its own part of you.
func _grab_point(i: int, grab_at: Vector3) -> Vector3:
	var angle := float(i) * TAU / float(_hands.size()) + 0.6
	return grab_at + (global_basis.x * cos(angle) + Vector3.UP * sin(angle)) * GRAB_SPREAD


## The shoulder, in the arm's own space: sunk in the flesh, behind where it comes out.
func _shoulder() -> Vector3:
	return Vector3(0.0, 0.0, SHOULDER_IN)


func _world_shoulder(i: int) -> Vector3:
	return _hands[i].global_transform * _shoulder()


## The arm from its wrist back to its shoulder: the elbow out and up, the hand where it is going and how.
func _solve_arm(i: int, grab: float, grab_at: Vector3) -> void:
	var hand := _hands[i]
	var into := hand.global_transform.affine_inverse()
	var wrist_at: Vector3 = into * _wrist[i]
	var shoulder := _shoulder()
	var side := signf(_markers[i].position.x)
	# How the hand goes: down into the earth, dug in or coming to it; out at what it is after, else.
	var world_way: Vector3 = (_wrist[i] - _world_shoulder(i))
	world_way.y = 0.0
	world_way = world_way.normalized() if world_way.length() > 0.01 else -global_basis.z
	var low := 1.0 if _dug[i] else (sin(_reach_t[i] * PI * 0.5) if i < DIGGERS and _reach_t[i] > 0.0 else 0.0)
	var pointing: Vector3 = (world_way + Vector3.DOWN * DRIVES_DOWN * low).normalized()

	if not _dug[i] and low <= 0.0:
		var from_shoulder: Vector3 = (_wrist[i] - _world_shoulder(i)).normalized()
		pointing = from_shoulder.lerp((grab_at - _wrist[i]).normalized(), grab).normalized()

	var fingers: Vector3 = (into.basis * pointing).normalized()
	var back: Vector3 = (into.basis * Vector3.UP).normalized()

	if absf(fingers.dot(back)) > 0.95:
		back = (into.basis * (-global_basis.z)).normalized()

	var hand_turned := Basis.looking_at(fingers, back)
	var hand_bone := hand.find_bone("hand")
	var hand_rest: Basis = hand.get_bone_rest(hand_bone).basis
	var hand_basis: Basis = hand_turned * hand_rest
	hand.set_bone_pose_position(hand_bone, wrist_at)
	hand.set_bone_pose_rotation(hand_bone, hand_basis.get_rotation_quaternion())
	# The elbow.
	var span := shoulder - wrist_at
	var far := span.length()
	var reach := BONE_LENGTH * 2.0
	var stretch := clampf(far / (reach * 0.98), 1.0, DRAWN_OUT_MOST * 1.2)
	_stretch[i] = stretch
	var bone := BONE_LENGTH * stretch
	var along_span: Vector3 = span / maxf(far, 0.001)
	var elbow_way: Vector3 = (into.basis * (Vector3.UP + global_basis.x * side * 0.7)).normalized()
	elbow_way = (elbow_way - along_span * elbow_way.dot(along_span)).normalized()
	var elbow := wrist_at + span * 0.5 + elbow_way * sqrt(maxf(bone * bone - far * far * 0.25, 0.0))
	var arm_1 := hand.find_bone("arm_1")
	var arm_2 := hand.find_bone("arm_2")
	var forearm := _aim(hand, arm_1, hand_basis, (elbow - wrist_at).normalized())
	hand.set_bone_pose_scale(arm_1, Vector3(1.0, stretch, 1.0))
	_aim(hand, arm_2, forearm, (shoulder - elbow).normalized())


func _aim(hand: Skeleton3D, bone: int, parent: Basis, wanted: Vector3) -> Basis:
	var rest: Basis = parent * hand.get_bone_rest(bone).basis
	var aimed := Basis(Quaternion(rest.y.normalized(), wanted)) * rest
	hand.set_bone_pose_rotation(bone, (parent.inverse() * aimed).get_rotation_quaternion())
	return aimed


func _curl_fingers(hand: Skeleton3D, which: int) -> void:
	for f in FINGER_NAMES.size():
		var seed := float(f) * 1.9 + float(which) * 2.3
		var palsy := sin(_clock * 3.0 + seed) * 0.6 + sin(_clock * 7.7 + seed * 2.0) * 0.4
		var shut := _shut[which] + palsy * CURLS * (0.15 if _dug[which] else 1.0)

		for k in range(1, 4):
			var bone := hand.find_bone("%s_%02d" % [FINGER_NAMES[f], k])
			var rest: Basis = hand.get_bone_rest(bone).basis
			hand.set_bone_pose_rotation(bone, (rest * Basis(Vector3.RIGHT, -shut * [0.7, 1.0, 1.25][k - 1])).get_rotation_quaternion())
