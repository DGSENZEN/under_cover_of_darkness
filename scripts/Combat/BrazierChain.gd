extends Node3D
## The brazier's chain and head, in the world: it hangs from your hand and lags it, flies where you aimed, drops and is hauled back in. Simulated with a tick's points (`work`, from PlayerCombat); drawn each frame between them, its top on your hand as it is now, so turning doesn't part them.
## Its coals breathe, and burn up when it's swung; they light what's near them, and smoke; it throws sparks and hot embers where it lands, of our own making.

const MODEL := "res://assets/weapons/brazier.glb"
const IRON := preload("res://scripts/Combat/brazier_iron.gdshader")
const COALS := preload("res://scripts/Combat/brazier_coals.gdshader")
const SMOKE := preload("res://scripts/Combat/brazier_smoke.gdshader")
const EMBER := preload("res://scripts/Combat/brazier_ember.gdshader")
const LUMP := preload("res://scripts/Combat/brazier_lump.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")
const Layers := preload("res://scripts/Visual/Layers.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")

## The points it's simulated at, and how long the chain hangs at rest (m). More is paid out as it flies.
const POINTS := 14
const HANGS := 0.07
## How far apart its links are drawn (m), and the most there can be.
const LINK_EVERY := 0.052
const MOST_LINKS := 130
## Slack in it, flying, as a share of how far it's gone: it can wave, and it's never a rod.
const SLACK := 1.05
const GRAVITY := 9.8
## How much of a point's speed it keeps a tick (a chain drags on itself), and how many times its length is held to a tick.
const KEEPS := 0.985
const HOLDS := 14
## The head's share of a correction, against a link's 1: it is by far the heaviest thing here.
const HEAD_GIVES := 0.08
## How fast it follows where it's held to, at most (m/s), and its share of the way there a tick: quick, and it has weight.
const HELD_SPEED := 14.0
## On the floor: how high it rides, and what it keeps of its speed along it.
const RIDES := 0.11
const SCRAPES := 0.8
## A thrown head gets up to speed: 1 is even, the whole way.
const THROWN_EASE := 1.12
## What the head keeps of its speed a tick while it's hauled: hand over hand, it doesn't fly on past your fist.
const HAULED_KEEPS := 0.72
## Of a haul back in, how much is the drop before the pull.
const DROPS_FOR := 0.16
## How long its coals are breathing over, how hot fanned by speed (per m/s), and what its light does with that.
const COAL_LIGHT := 1.1
const COAL_LIGHT_FANNED := 2.2
const COAL_REACH := 3.6
const COAL_COLOUR := Color(1.0, 0.46, 0.14)
const FANS_PER := 0.09
## Sparks and embers where it lands.
const BURST_EMBERS := 26
## What it does to what it lands on: stays on it this long (s), then comes off it this fast (m/s). And what it does to its light.
const BITES_FOR := 0.085
const COMES_OFF := 3.6
const LIGHT_JUMPS := 2.4
const LIGHT_SETTLES := 12.0
## Coals thrown out of its lid at each hit: how many there can be flying at once, how many a hit throws, how long they burn (s), how hard they're thrown (m/s), how they bounce.
const MOST_COALS := 30
const COALS_THROWN := 12
const COALS_BURN := 1.9
const COALS_FLY := Vector2(1.6, 4.6)
const COALS_BOUNCE := 0.32
const COAL_SIZE := Vector2(0.012, 0.028)
## Steam off wet flesh: how long it's coming (s).
const STEAM_FOR := 0.75

enum Mode { HANG, HELD, THROWN, DROPPING, HAULED }

## How many times it has thrown sparks.
var bursts := 0

var _at := PackedVector3Array()
var _was := PackedVector3Array()
## Last tick's points, to draw between them.
var _before := PackedVector3Array()
var _long := HANGS
var _mode := Mode.HANG
var _hand := Vector3.ZERO
var _hand_live: Callable = Callable()
var _not_this: Array[RID] = []

var _held_to := Vector3.ZERO
var _thrown_from := Vector3.ZERO
var _thrown_to := Vector3.ZERO
var _going := 0.0
var _takes := 0.0
var _long_from := HANGS

var _floor_at := -INF
var _fans := 0.0
var _head_speed := 0.0
var _up_way := Vector3.UP
var _bite_left := 0.0
var _bite_on: Node3D = null
var _bite_local := Vector3.ZERO
var _bite_fixed := Vector3.ZERO
var _comes_off := Vector3.ZERO
## Kicked, next tick, by this much: it's been stopped short.
var _kick_next := Vector3.ZERO
var _kicked := false
var _light_jump := 0.0
## Each: [where, going, burning left, how big, turning, floor].
var _flying: Array = []
var _steam_left := 0.0

var _links: MultiMeshInstance3D
var _head: Node3D
var _head_mesh: MeshInstance3D
var _coals_mesh: MeshInstance3D
var _light: OmniLight3D
var _smoke: CPUParticles3D
var _embers: CPUParticles3D
var _burst: CPUParticles3D
var _steam: CPUParticles3D
var _coal_bits: MultiMeshInstance3D


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var scene: Node = (load(MODEL) as PackedScene).instantiate()
	var iron := ShaderMaterial.new()
	iron.shader = IRON
	iron.set_shader_parameter(&"stroke_sheet", BRUSH)
	_head = Node3D.new()
	_head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_head)
	_head_mesh = _part(scene, "Head", iron)
	_head.add_child(_head_mesh)
	var hot := ShaderMaterial.new()
	hot.shader = COALS
	_coals_mesh = _part(scene, "Coals", hot)
	_coals_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(_coals_mesh)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = (scene.find_child("Link", true, false) as MeshInstance3D).mesh.duplicate()
	many.mesh.surface_set_material(0, iron)
	many.instance_count = MOST_LINKS
	many.visible_instance_count = 0
	_links = MultiMeshInstance3D.new()
	_links.multimesh = many
	_links.custom_aabb = AABB(Vector3(-2000, -500, -2000), Vector3(4000, 1000, 4000))
	_links.layers = Layers.FX
	add_child(_links)
	scene.free()
	_light = OmniLight3D.new()
	_light.light_color = COAL_COLOUR
	_light.omni_range = COAL_REACH
	_light.light_energy = COAL_LIGHT
	# (What's near it, not itself: its own plate, a hand from the coals, would only burn white.)
	_light.light_cull_mask = Layers.ALL_BUT_PROBE & ~Layers.FX
	_light.position = Vector3(0.0, -0.33, 0.0)
	_head.add_child(_light)
	_smoke = _particles(SMOKE, 10, 1.5, 0.05)
	_smoke.gravity = Vector3(0.0, 0.5, 0.0)
	_smoke.initial_velocity_min = 0.02
	_smoke.initial_velocity_max = 0.08
	_smoke.damping_min = 0.3
	_smoke.damping_max = 0.6
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.0
	_smoke.scale_amount_curve = _rising(0.5, 1.8)
	_smoke.color_ramp = _ramp([Color(0.16, 0.15, 0.14, 0.0), Color(0.15, 0.145, 0.14, 0.13), Color(0.1, 0.1, 0.1, 0.0)], [0.0, 0.3, 1.0])
	_smoke.position = Vector3(0.0, -0.2, 0.0)
	_head.add_child(_smoke)
	_embers = _particles(EMBER, 14, 0.8, 0.0065)
	_embers.gravity = Vector3(0.0, 0.5, 0.0)
	_embers.direction = Vector3.UP
	_embers.spread = 70.0
	_embers.initial_velocity_min = 0.1
	_embers.initial_velocity_max = 0.5
	_embers.color_ramp = _ramp([Color(3.0, 1.3, 0.3, 1.0), Color(1.6, 0.4, 0.08, 0.9), Color(0.3, 0.05, 0.01, 0.0)], [0.0, 0.5, 1.0])
	_embers.position = Vector3(0.0, -0.32, 0.0)
	_embers.emitting = false
	_head.add_child(_embers)
	_burst = _particles(EMBER, BURST_EMBERS, 0.7, 0.01)
	_burst.one_shot = true
	_burst.explosiveness = 0.95
	_burst.emitting = false
	_burst.gravity = Vector3(0.0, -6.5, 0.0)
	_burst.direction = Vector3.UP
	_burst.spread = 80.0
	_burst.initial_velocity_min = 1.5
	_burst.initial_velocity_max = 5.5
	_burst.color_ramp = _embers.color_ramp
	add_child(_burst)
	_steam = _particles(SMOKE, 7, 0.95, 0.22)
	((_steam.mesh as QuadMesh).material as ShaderMaterial).set_shader_parameter(&"torn", 1.0)
	_steam.one_shot = true
	_steam.explosiveness = 0.72
	_steam.emitting = false
	_steam.gravity = Vector3(0.0, 1.6, 0.0)
	_steam.spread = 55.0
	_steam.initial_velocity_min = 0.5
	_steam.initial_velocity_max = 1.9
	_steam.damping_min = 2.5
	_steam.damping_max = 4.0
	_steam.scale_amount_curve = _rising(0.6, 2.0)
	_steam.color_ramp = _ramp([Color(0.5, 0.53, 0.51, 0.0), Color(0.46, 0.49, 0.47, 0.3), Color(0.3, 0.32, 0.31, 0.0)], [0.0, 0.12, 1.0])
	add_child(_steam)
	var lump := SphereMesh.new()
	lump.radius = 1.0
	lump.height = 2.0
	lump.radial_segments = 7
	lump.rings = 4
	var lump_look := ShaderMaterial.new()
	lump_look.shader = LUMP
	lump.material = lump_look
	var bits := MultiMesh.new()
	bits.transform_format = MultiMesh.TRANSFORM_3D
	bits.use_colors = true
	bits.mesh = lump
	bits.instance_count = MOST_COALS
	bits.visible_instance_count = 0
	_coal_bits = MultiMeshInstance3D.new()
	_coal_bits.multimesh = bits
	_coal_bits.custom_aabb = AABB(Vector3(-2000, -500, -2000), Vector3(4000, 1000, 4000))
	_coal_bits.layers = Layers.FX
	_coal_bits.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_coal_bits)
	put_away()


func _part(scene: Node, part: String, look: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = (scene.find_child(part, true, false) as MeshInstance3D).mesh
	mesh.material_override = look
	mesh.layers = Layers.FX
	mesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return mesh


func _particles(shader: Shader, count: int, life: float, size: float) -> CPUParticles3D:
	var look := ShaderMaterial.new()
	look.shader = shader

	if shader == SMOKE:
		look.set_shader_parameter(&"stroke_sheet", BRUSH)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size * 2.0
	quad.material = look
	var dots := CPUParticles3D.new()
	dots.mesh = quad
	dots.amount = count
	dots.lifetime = life
	dots.local_coords = false
	dots.layers = Layers.FX
	dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dots.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return dots


func _ramp(colours: Array, offsets: Array) -> Gradient:
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(colours)
	ramp.offsets = PackedFloat32Array(offsets)
	return ramp


func _rising(from: float, to: float) -> Curve:
	var curve := Curve.new()
	curve.max_value = maxf(from, to)
	curve.add_point(Vector2(0.0, from))
	curve.add_point(Vector2(1.0, to))
	return curve


## Where it's hung from, each frame: a Callable returning the point on your hand. And who's holding it: they aren't a floor for it.
func hold_from(live: Callable, holder: RID) -> void:
	_hand_live = live
	_not_this = [holder]


## Out of your hand: nothing to see, nothing lit.
func put_away() -> void:
	visible = false
	_light.visible = false
	_smoke.emitting = false
	_embers.emitting = false
	_mode = Mode.HANG
	_at.clear()
	_flying.clear()
	_coal_bits.multimesh.visible_instance_count = 0
	_bite_left = 0.0
	_steam_left = 0.0
	_light_jump = 0.0


## Taken up: it hangs from your hand, from nowhere else.
func take_up(hand: Vector3) -> void:
	visible = true
	_light.visible = true
	_smoke.emitting = true
	_hand = hand
	_long = HANGS
	_mode = Mode.HANG
	_at.resize(POINTS)
	_was.resize(POINTS)
	_before.resize(POINTS)

	for i in POINTS:
		_at[i] = hand + Vector3.DOWN * HANGS * (float(i) / (POINTS - 1))
		_was[i] = _at[i]
		_before[i] = _at[i]


func head_at() -> Vector3:
	return _at[POINTS - 1] if not _at.is_empty() else global_position


func hand_now() -> Vector3:
	return _hand


func points_now() -> PackedVector3Array:
	return _at.duplicate()


func coal_light() -> OmniLight3D:
	return _light


## Out in the air, or on its way back.
func busy() -> bool:
	return _mode != Mode.HANG or _long > HANGS * 1.05


## How long it is now against how long it's let out: 1 is true to its length.
func stretch() -> float:
	var along := 0.0

	for i in POINTS - 1:
		along += _at[i].distance_to(_at[i + 1])

	return along / maxf(_long, 0.01)


## Held to this, as far as it can be: drawn back, or carried through a swing. Say so again each tick.
func hold_to(at: Vector3) -> void:
	_mode = Mode.HELD
	_held_to = at


## Flung to there, to land in `seconds`.
func throw_to(at: Vector3, seconds: float) -> void:
	_mode = Mode.THROWN
	_thrown_from = head_at()
	_thrown_to = at
	_going = 0.0
	_takes = maxf(seconds, 0.02)


## It drops, then you haul it in, all in `seconds`. Off the end of its flight it's stopped short, and goes on this way (m/s).
func bring_back(seconds: float, kicked := Vector3.ZERO) -> void:
	if _mode == Mode.THROWN:
		_kick_next = kicked
		_kicked = true

	_mode = Mode.DROPPING
	_going = 0.0
	_takes = maxf(seconds, 0.02)
	_long_from = _long


## Where it has landed: sparks, embers, coals out of its lid, its light jumps; steam, if what it hit is wet.
func burst(at: Vector3, away: Vector3, wet := false) -> void:
	bursts += 1
	Fx.sparks(self, at, away, 1.4, true)
	_burst.global_position = at
	_burst.direction = away
	_burst.restart()
	_burst.emitting = true
	_fans = 1.0
	_light_jump = LIGHT_JUMPS
	_throw_coals(at, away)

	if wet:
		_steam_left = STEAM_FOR
		_steam.global_position = at
		_steam.direction = (away + Vector3.UP * 0.8).normalized()
		_steam.restart()
		_steam.emitting = true


## It stays on what it hit a moment, going where that goes, then comes off it. `on` may be nothing, a wall.
func bite(on: Node3D, at: Vector3, away: Vector3) -> void:
	_bite_left = BITES_FOR
	_bite_on = on
	_bite_local = on.global_transform.affine_inverse() * at if on != null else Vector3.ZERO
	_bite_fixed = at
	_comes_off = away.normalized() * COMES_OFF
	_kicked = false


## How many coals it has thrown that are still burning.
func coals_flying() -> int:
	return _flying.size()


## How low the lowest of them is, in the world.
func lowest_coal() -> float:
	var least := INF

	for coal: Array in _flying:
		least = minf(least, (coal[0] as Vector3).y)

	return least


func steaming() -> bool:
	return _steam_left > 0.0


func _throw_coals(at: Vector3, away: Vector3) -> void:
	var from := at + away.normalized() * 0.06
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0, 1, _not_this)
	var found := get_world_3d().direct_space_state.intersect_ray(query)
	var floor_at: float = (found["position"] as Vector3).y if not found.is_empty() else from.y - 8.0

	for i in COALS_THROWN:
		var way := (away.normalized() + Vector3.UP * 0.35 + Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 1.0), randf_range(-1.0, 1.0)) * 0.85).normalized()
		_flying.append([from, way * randf_range(COALS_FLY.x, COALS_FLY.y), COALS_BURN * randf_range(0.65, 1.15), randf_range(COAL_SIZE.x, COAL_SIZE.y), randf() * TAU, floor_at])

	while _flying.size() > MOST_COALS:
		_flying.pop_front()


func _work_coals(delta: float) -> void:
	var i := _flying.size() - 1

	while i >= 0:
		var coal: Array = _flying[i]
		coal[2] = float(coal[2]) - delta

		if float(coal[2]) <= 0.0:
			_flying.remove_at(i)
			i -= 1
			continue

		var going: Vector3 = coal[1]
		going += Vector3.DOWN * GRAVITY * delta
		var at: Vector3 = (coal[0] as Vector3) + going * delta
		var rests_at: float = float(coal[5]) + float(coal[3])

		if at.y < rests_at:
			at.y = rests_at
			going = Vector3(going.x * 0.55, absf(going.y) * COALS_BOUNCE, going.z * 0.55)

			if going.y < 0.35:
				going = Vector3.ZERO

		coal[0] = at
		coal[1] = going
		coal[4] = float(coal[4]) + going.length() * delta * 3.0
		i -= 1

	var bits := _coal_bits.multimesh
	bits.visible_instance_count = _flying.size()

	for k in _flying.size():
		var coal: Array = _flying[k]
		var turned := Basis(Vector3(0.6, 0.7, 0.3).normalized(), float(coal[4])).scaled(Vector3.ONE * float(coal[3]))
		bits.set_instance_transform(k, Transform3D(turned, coal[0]))
		# (Hot till near its end, then going out.)
		bits.set_instance_color(k, Color(clampf(float(coal[2]) / 0.8, 0.0, 1.0), 0.0, 0.0, 1.0))


## A tick: follows the hand, moves its points, keeps its length.
func work(delta: float, hand: Vector3) -> void:
	if _at.is_empty():
		take_up(hand)

	# (You went somewhere all at once: a gate, a respawn. So does it.)
	if hand.distance_to(_hand) > 3.0:
		take_up(hand)

	_hand = hand
	_before = _at.duplicate()
	_find_floor()
	var last := POINTS - 1

	# (Stopped short: what it was flying at isn't its speed any more.)
	if _kicked and _bite_left <= 0.0:
		_was[last] = _at[last] - _kick_next * delta
		_kicked = false

	for i in range(1, POINTS):
		var moved := (_at[i] - _was[i]) * (HAULED_KEEPS if _mode == Mode.HAULED and i == last else KEEPS)
		_was[i] = _at[i]
		_at[i] += moved + Vector3.DOWN * GRAVITY * delta * delta

	var head_held := _carry_head(delta)
	_long = _wanted_long(delta)
	_at[0] = hand
	_was[0] = hand
	# (All the chain there is, and it has its weight on it: it comes with the chain, however heavy it is.)
	var from_hand := _at[last] - hand

	if from_hand.length() > _long:
		_at[last] = hand + from_hand.normalized() * _long
		head_held = true

	var gap := _long / (POINTS - 1)

	for _pass in HOLDS:
		for i in POINTS - 1:
			var way := _at[i + 1] - _at[i]
			var far := way.length()

			if far <= gap or far < 0.00001:
				continue

			var over := way * ((far - gap) / far)
			var near_gives := 0.0 if i == 0 else 1.0
			var far_gives := 1.0

			if i + 1 == last:
				far_gives = 0.0 if head_held else HEAD_GIVES

			var share := near_gives + far_gives

			if share > 0.0:
				_at[i] += over * (near_gives / share)
				_at[i + 1] -= over * (far_gives / share)

		_at[0] = hand

	# (However fast it's being hauled: from each end in turn, nothing further from the next than a link's worth.)
	for _sweep in 2:
		for i in range(last - 1, 0, -1):
			_at[i] = _within(_at[i], _at[i + 1], gap)

		for i in range(1, last):
			_at[i] = _within(_at[i], _at[i - 1], gap)

	if not head_held:
		_at[last] = _within(_at[last], _at[last - 1], gap)

	_keep_off_floor()
	_head_speed = _at[last].distance_to(_before[last]) / maxf(delta, 0.001)
	_fans = move_toward(_fans, clampf(_head_speed * FANS_PER, 0.0, 1.0), delta * (6.0 if _head_speed * FANS_PER > _fans else 1.1))
	_embers.emitting = _fans > 0.35
	_light_jump = move_toward(_light_jump, 0.0, delta * LIGHT_SETTLES)
	_steam_left = maxf(_steam_left - delta, 0.0)
	_work_coals(delta)


func _within(point: Vector3, of: Vector3, far: float) -> Vector3:
	var way := point - of
	return of + way.normalized() * far if way.length() > far else point


## How much chain there is out now.
func _wanted_long(delta: float) -> float:
	var there := head_at().distance_to(_hand)

	match _mode:
		Mode.THROWN:
			return maxf(_long, there * SLACK)
		Mode.HELD:
			return maxf(move_toward(_long, there * SLACK, delta * 25.0), HANGS)
		Mode.DROPPING:
			return _long
		Mode.HAULED:
			var u := clampf(_going / _takes, 0.0, 1.0)
			# (Hand over hand, hardest at the start of it.)
			return maxf(lerpf(_long_from, HANGS, 1.0 - pow(1.0 - u, 2.2)), HANGS)

	return move_toward(_long, HANGS, delta * 4.0)


## Moves the head as it's being moved, if it is: whether it's held there and not free.
func _carry_head(delta: float) -> bool:
	var last := POINTS - 1

	if _bite_left > 0.0:
		_bite_left -= delta
		var bitten: Vector3 = _bite_on.global_transform * _bite_local if is_instance_valid(_bite_on) else _bite_fixed
		_at[last] = bitten

		if _bite_left <= 0.0:
			_was[last] = bitten - _comes_off * delta
		else:
			_was[last] = bitten

		return true

	match _mode:
		Mode.HELD:
			_at[last] = _was[last] + (_held_to - _was[last]).limit_length(HELD_SPEED * delta)
			return true
		Mode.THROWN:
			_going += delta
			var u := clampf(_going / _takes, 0.0, 1.0)
			var now := _thrown_from.lerp(_thrown_to, pow(u, THROWN_EASE))
			_at[last] = now
			return true
		Mode.DROPPING:
			_going += delta

			if _going >= _takes * DROPS_FOR:
				_mode = Mode.HAULED
				_going = 0.0
				_takes = maxf(_takes * (1.0 - DROPS_FOR), 0.02)
				_long_from = _long
		Mode.HAULED:
			_going += delta

			if _going >= _takes:
				_mode = Mode.HANG

	return false


## What's under its head.
func _find_floor() -> void:
	var from := head_at() + Vector3.UP * 0.4
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0, 1, _not_this)
	var found := get_world_3d().direct_space_state.intersect_ray(query)
	_floor_at = (found["position"] as Vector3).y if not found.is_empty() else -INF


## It doesn't go through the floor: it lands and it drags.
func _keep_off_floor() -> void:
	if _floor_at == -INF:
		return

	for i in range(1, POINTS):
		var rides := RIDES if i == POINTS - 1 else 0.012

		if _at[i].y < _floor_at + rides:
			_at[i].y = _floor_at + rides
			var slid := _at[i] - _was[i]
			_was[i] = _at[i] - Vector3(slid.x, 0.0, slid.z) * SCRAPES


func _process(_delta: float) -> void:
	if not visible or _at.is_empty():
		return

	var between := Engine.get_physics_interpolation_fraction()
	var shown := PackedVector3Array()
	shown.resize(POINTS)

	for i in POINTS:
		shown[i] = _before[i].lerp(_at[i], between)

	var live: Vector3 = _hand_live.call() if _hand_live.is_valid() else _hand
	var moved_by := live - shown[0]

	# (Your hand is where it is now, and the chain near it goes with it: less and less further down.)
	for i in POINTS:
		shown[i] += moved_by * pow(1.0 - float(i) / (POINTS - 1), 3.0)

	_draw_links(shown)
	_draw_head(shown)


func _draw_links(shown: PackedVector3Array) -> void:
	var many := _links.multimesh
	var count := 0
	var left_over := 0.0

	for i in POINTS - 1:
		var from := shown[i]
		var way := shown[i + 1] - from
		var long := way.length()

		if long < 0.0001:
			continue

		var along := way / long
		var side := along.cross(Vector3(0.21, 0.91, 0.35)).normalized()
		var other := side.cross(along).normalized()
		var d := left_over

		while d < long and count < MOST_LINKS:
			var turned := count % 2 == 1
			var across := other if turned else side
			var up := along.cross(across).normalized()
			many.set_instance_transform(count, Transform3D(Basis(across, up, along), from + along * d))
			count += 1
			d += LINK_EVERY

		left_over = d - long

	many.visible_instance_count = count


func _draw_head(shown: PackedVector3Array) -> void:
	var at := shown[POINTS - 1]
	var from := shown[POINTS - 2]
	var up := from - at
	up = up.normalized() if up.length() > 0.0001 else _up_way
	_up_way = up
	var side := up.cross(Vector3(0.31, 0.27, 0.91)).normalized()
	_head.global_transform = Transform3D(Basis(side, up, side.cross(up).normalized()), at)
	var breath := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.0016) * sin(float(Time.get_ticks_msec()) * 0.0041 + 1.0)
	_light.light_energy = lerpf(COAL_LIGHT * (0.82 + breath * 0.18), COAL_LIGHT_FANNED, _fans) + _light_jump
	_coals_mesh.set_instance_shader_parameter(&"fanned", _fans)
	_head_mesh.set_instance_shader_parameter(&"fanned", _fans)
