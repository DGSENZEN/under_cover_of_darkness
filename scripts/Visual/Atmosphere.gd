extends Node3D
## The air of a night yard, sized for the PS2 look. Presentation only:
## nothing reads it back but the talk's "wind" (TalkFacts).
##   breath  each man's breath on the cold air, on the out-breath, in time
##           with his breathing (GuardVoice); thicker as his heart races, and
##           when he shouts.
##   embers  off each fire, drifting with the wind; fewer as it burns low, a
##           burst when it is fed (Fire.fed).
##   moths   circling the torches.
##   wind    in gusts from the north-west: flames lean (Torch.lean), embers
##           and dead leaves skitter.
##   crows   on the wall-walk (`add_crows`): off at a shout or a man running
##           near, back a while later.
##   dust    hanging in shafts of light (`add_dust`), drifting slowly.
## `quality` thins it for the frame rate: 1 loses the moths, 0 the leaves
## too.
##
## As Fx.gd does, its particles are simulated here and drawn as one
## MultiMesh a kind: a few chunky sprites.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

## The wind blows toward the south-east (from the north-west), wandering
## this far either way; gusts come and go at this pace.
const WIND_FROM := Vector3(0.7, 0.0, 0.7)
const WIND_WANDER := 0.4
const GUST_PACE := 0.08
## Crows: off at a sound this loud this near, or a man running this fast
## this near; away this long, then back over RETURN seconds.
const CROW_SCARE_DB := 55.0
const CROW_SCARE_REACH := 10.0
const CROW_RUNNER := 3.5
const CROW_RUNNER_REACH := 5.0
const CROW_FLY := 4.0
const CROW_AWAY := Vector2(25.0, 40.0)
const CROW_RETURN := 2.0
## A fed fire's burst lasts this long.
const BURST := 0.3
## How often it looks for new men, fires and torches (s).
const SCAN_EVERY := 1.0
## The yard, where the level says nothing (x by z, m).
const YARD := Vector2(40.0, 30.0)
## Each kind of mote: [size at birth, size at death, colour at birth, colour
## at death, life (s), most at once]. Breath is drawn as Fx's soft puff; the
## rest as plain chunky squares.
const KINDS := {
	&"breath": [0.035, 0.11, Color(0.86, 0.9, 0.97, 0.24), Color(0.86, 0.9, 0.97, 0.0), 0.9, 160],
	&"ember": [0.035, 0.02, Color(1.0, 0.6, 0.2, 1.0), Color(0.9, 0.2, 0.05, 0.0), 1.6, 160],
	&"leaf": [0.09, 0.09, Color(0.32, 0.24, 0.12, 1.0), Color(0.28, 0.2, 0.1, 0.0), 3.0, 40],
	&"dust": [0.022, 0.022, Color(1.0, 0.86, 0.62, 0.55), Color(1.0, 0.86, 0.62, 0.0), 7.0, 260],
}
## Dust hangs in a shaft of light (add_dust): this many a second a box, this
## slow.
const DUST_RATE := 5.0
const DUST_DRIFT := 0.04

## 2 everything; 1 no moths; 0 no moths and no leaves.
var quality := 2
## How hard the weather lets the wind blow (Night): 1 as it was made.
var strength := 1.0

var _time := 0.0
var _forced: Variant = null
var _noise := FastNoiseLite.new()
## Its own dice: how hard the weather blows changes how many leaves it rolls
## for, and that must not change the world's.
var _rng := RandomNumberGenerator.new()
var _scan_in := 0.0
var _breaths := {}
var _embers := {}
var _leaves: Puffs
var _moths := {}
var _crows: Array = []
var _dust: Array = []
var _motes := {}
var _draw := {}


## Where motes come from: a place, a rate, which way they go.
class Puffs:
	var kind: StringName
	var emitting := false
	## How many of its motes it makes (0..1.5), for how much there is.
	var amount_ratio := 1.0
	var rate := 10.0
	var origin := Vector3.ZERO
	var velocity := Vector3.ZERO
	var spread := 0.2
	var box := Vector3.ZERO
	var rise := 0.0
	var wind_share := 1.0
	var _owed := 0.0

	func _init(p_kind: StringName, p_rate: float) -> void:
		kind = p_kind
		rate = p_rate


## The atmosphere of `node`'s level; null if it has none.
static func of(node: Node) -> Node:
	if node == null or not node.is_inside_tree():
		return null

	return node.get_tree().get_first_node_in_group(&"atmosphere")


func _ready() -> void:
	# Moved every drawn frame, not every physics tick: drawn as set (as Fx.gd).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"atmosphere")
	SoundBus.add_listener(self)
	_noise.seed = 1926
	_rng.seed = 1926
	_noise.frequency = 1.0

	for kind in KINDS:
		_motes[kind] = []
		_draw[kind] = _make_draw(kind)

	var yard: Vector2 = YARD
	var level := get_parent()

	if level != null and level.has_meta(&"yard_size"):
		yard = level.get_meta(&"yard_size")

	_leaves = Puffs.new(&"leaf", 6.0)
	_leaves.box = Vector3(yard.x * 0.5, 0.0, yard.y * 0.5)
	_leaves.origin = Vector3(0.0, 0.15, 0.0)
	_leaves.rise = 0.3
	_leaves.wind_share = 2.5


func _exit_tree() -> void:
	SoundBus.remove_listener(self)


## Tests: the wind held at `v` (null lets it blow).
func force_wind(v: Variant) -> void:
	_forced = v


## The wind now: which way and how hard (length 0..1).
func wind() -> Vector3:
	if _forced is Vector3:
		return _forced

	var gust := clampf(0.5 + 0.7 * _noise.get_noise_1d(_time * GUST_PACE * 10.0), 0.0, 1.0)
	var turn := WIND_WANDER * _noise.get_noise_1d(500.0 + _time * 0.5)
	return WIND_FROM.normalized().rotated(Vector3.UP, turn) * gust * strength


func breath_of(man: Node) -> Object:
	return _breaths.get(man)


## [the embers, the burst when fed].
func embers_of(fire: Node) -> Array:
	return _embers.get(fire, [])


func leaves() -> Object:
	return _leaves


## Every moth of every torch.
func moths() -> Array:
	var all := []

	for torch in _moths:
		all.append_array(_moths[torch])

	return all


## Each crow: {node, state (perched, flying, away, returning), home}.
func crows() -> Array:
	return _crows


## Crows perched at `points`.
## Dust hanging in shafts of light (the chapel's moonlight through its
## glass): motes drifting slowly in each of `boxes` (AABB), no wind indoors.
func add_dust(boxes: Array) -> void:
	for box in boxes:
		var puffs := Puffs.new(&"dust", DUST_RATE)
		puffs.origin = (box as AABB).get_center()
		puffs.box = (box as AABB).size * 0.5
		puffs.spread = DUST_DRIFT
		puffs.rise = 0.0
		puffs.wind_share = 0.0
		puffs.emitting = true
		_dust.append(puffs)


## Where the motes of `kind` are now.
func motes(kind: StringName) -> Array:
	return (_motes.get(kind, []) as Array).map(func(m): return m["p"])


func add_crows(points: Array) -> void:
	for point in points:
		var body := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.16, 0.12, 0.3)
		var black := StandardMaterial3D.new()
		black.albedo_color = Color(0.04, 0.04, 0.05)
		black.roughness = 1.0
		prism.material = black
		body.mesh = prism
		body.layers = Layers.FX
		add_child(body)
		body.global_position = point
		body.rotation.y = _rng.randf() * TAU
		_crows.append({"node": body, "state": &"perched", "home": point, "t": 0.0, "away": Vector3.ZERO, "back_at": 0.0})


## A sound (SoundBus): a crow near a loud one flies.
func hear_sound(event: Dictionary) -> void:
	if float(event.get("db", 0.0)) < CROW_SCARE_DB:
		return

	var at: Vector3 = event.get("position", Vector3.INF)

	for crow in _crows:
		if crow["state"] == &"perched" and (crow["home"] as Vector3).distance_to(at) <= CROW_SCARE_REACH:
			_fly(crow, at)


func _process(delta: float) -> void:
	_time += delta
	_scan_in -= delta

	if _scan_in <= 0.0:
		_scan_in = SCAN_EVERY
		_scan()

	var air := wind()
	_update_breaths()
	_update_embers()
	_leaves.emitting = quality >= 1
	_leaves.amount_ratio = clampf(air.length(), 0.0, 1.0)
	_update_moths()
	_update_crows(delta)

	for torch in get_tree().get_nodes_in_group(&"torches"):
		if torch.has_method("lean"):
			# (a storm's wind bends the flames as far as they bend)
			torch.lean(air.limit_length(1.5))

	for puffs in _all_puffs():
		_emit(puffs, delta, air)

	for kind in _motes:
		_step(kind, delta, air)
		_show(kind)


# ---------------------------------------------------------------------------
# Who and what is about
# ---------------------------------------------------------------------------

func _scan() -> void:
	for man in get_tree().get_nodes_in_group(&"guards"):
		if not _breaths.has(man):
			var puffs := Puffs.new(&"breath", 12.0)
			puffs.spread = 0.08
			puffs.rise = 0.1
			puffs.wind_share = 0.4
			_breaths[man] = puffs

	for fire in get_tree().get_nodes_in_group(&"fires"):
		if not _embers.has(fire):
			var embers := Puffs.new(&"ember", 12.0)
			embers.spread = 0.25
			embers.rise = 0.8
			embers.wind_share = 1.5
			var burst := Puffs.new(&"ember", 70.0)
			burst.spread = 0.6
			burst.rise = 1.6
			burst.wind_share = 1.0
			_embers[fire] = [embers, burst, 0.0]

			if fire.has_signal(&"fed"):
				fire.fed.connect(func() -> void: _embers[fire][2] = BURST)

	for torch in get_tree().get_nodes_in_group(&"torches"):
		if not _moths.has(torch):
			_moths[torch] = _make_moths()

	for dict in [_breaths, _embers, _moths]:
		for key in dict.keys():
			if not is_instance_valid(key):
				if dict == _moths:
					for moth in dict[key]:
						if is_instance_valid(moth):
							moth.queue_free()

				dict.erase(key)


func _update_breaths() -> void:
	for man in _breaths:
		if not is_instance_valid(man):
			continue

		var puffs: Puffs = _breaths[man]
		var voice: Variant = man.get("_voice")
		var alive: bool = man.get("_knocked_out") != true and man.is_inside_tree()
		puffs.emitting = alive and voice != null and voice.out_breath()

		if voice == null:
			continue

		var shout: bool = StringName(man.get("last_delivery")) == &"shout" and float(man.get("_bark_timer")) > 2.0
		puffs.amount_ratio = lerpf(0.25, 1.0, clampf((float(voice.heart) - 60.0) / 110.0, 0.0, 1.0)) * (1.5 if shout else 1.0)
		var forward := -(man as Node3D).global_basis.z
		var head: Vector3 = man.eye_position() if man.has_method("eye_position") else (man as Node3D).global_position + Vector3.UP * 1.6
		puffs.origin = head + forward * 0.15 - Vector3.UP * 0.08
		puffs.velocity = forward * 0.35


func _update_embers() -> void:
	for fire in _embers:
		if not is_instance_valid(fire):
			continue

		var entry: Array = _embers[fire]
		var embers: Puffs = entry[0]
		var burst: Puffs = entry[1]
		embers.origin = (fire as Node3D).global_position
		burst.origin = embers.origin
		embers.emitting = true
		embers.amount_ratio = float(fire.get("fuel")) if fire.get("fuel") != null else 1.0
		entry[2] = maxf(float(entry[2]) - get_process_delta_time(), 0.0)
		burst.emitting = float(entry[2]) > 0.0


func _make_moths() -> Array:
	var moths := []

	for i in 3:
		var moth := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.04, 0.04)
		var pale := StandardMaterial3D.new()
		pale.albedo_color = Color(0.92, 0.88, 0.75)
		pale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pale.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		quad.material = pale
		moth.mesh = quad
		moth.layers = Layers.FX
		moth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		moth.set_meta(&"phase", _rng.randf() * TAU)
		moth.set_meta(&"radius", _rng.randf_range(0.3, 0.7))
		moth.set_meta(&"pace", _rng.randf_range(2.0, 4.0))
		add_child(moth)
		moths.append(moth)

	return moths


func _update_moths() -> void:
	for torch in _moths:
		if not is_instance_valid(torch):
			continue

		var at: Vector3 = (torch as Node3D).global_position

		for moth in _moths[torch]:
			moth.visible = quality >= 2

			if not moth.visible:
				continue

			var phase: float = moth.get_meta(&"phase")
			var radius: float = moth.get_meta(&"radius")
			var pace: float = moth.get_meta(&"pace")
			var t := _time * pace + phase
			var wobble := _noise.get_noise_2d(phase * 100.0, _time * 2.0)
			moth.global_position = at + Vector3(cos(t) * radius, 0.25 + 0.15 * sin(t * 1.7) + wobble * 0.1, sin(t) * radius)


# ---------------------------------------------------------------------------
# Crows
# ---------------------------------------------------------------------------

func _fly(crow: Dictionary, from: Vector3) -> void:
	var away: Vector3 = (crow["home"] as Vector3) - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	crow["state"] = &"flying"
	crow["t"] = 0.0
	crow["away"] = away


func _update_crows(delta: float) -> void:
	for crow in _crows:
		var body: Node3D = crow["node"]

		if not is_instance_valid(body):
			continue

		match crow["state"]:
			&"perched":
				body.visible = true
				body.global_position = (crow["home"] as Vector3) + Vector3.UP * absf(sin(_time * 3.0 + body.rotation.y)) * 0.02

				for man in get_tree().get_nodes_in_group(&"guards"):
					var runner := man as CharacterBody3D

					if runner != null and runner.global_position.distance_to(crow["home"]) <= CROW_RUNNER_REACH and Vector2(runner.velocity.x, runner.velocity.z).length() > CROW_RUNNER:
						_fly(crow, runner.global_position)
						break
			&"flying":
				crow["t"] = float(crow["t"]) + delta
				body.global_position += ((crow["away"] as Vector3) * 3.0 + Vector3.UP * 2.0) * delta
				body.look_at(body.global_position + (crow["away"] as Vector3) + Vector3.UP * 0.3, Vector3.UP)

				if float(crow["t"]) >= CROW_FLY:
					crow["state"] = &"away"
					crow["back_at"] = _time + _rng.randf_range(CROW_AWAY.x, CROW_AWAY.y)
					body.visible = false
			&"away":
				if _time >= float(crow["back_at"]):
					crow["state"] = &"returning"
					crow["t"] = 0.0
					body.visible = true
			&"returning":
				crow["t"] = float(crow["t"]) + delta
				var u := clampf(float(crow["t"]) / CROW_RETURN, 0.0, 1.0)
				var from: Vector3 = (crow["home"] as Vector3) + (crow["away"] as Vector3) * 6.0 + Vector3.UP * 4.0
				body.global_position = from.lerp(crow["home"], u)

				if u >= 1.0:
					crow["state"] = &"perched"


# ---------------------------------------------------------------------------
# Motes
# ---------------------------------------------------------------------------

func _all_puffs() -> Array:
	var all: Array = _breaths.values() + [_leaves] + _dust

	for entry in _embers.values():
		all.append(entry[0])
		all.append(entry[1])

	return all


func _emit(puffs: Puffs, delta: float, air: Vector3) -> void:
	if not puffs.emitting:
		puffs._owed = 0.0
		return

	puffs._owed += puffs.rate * clampf(puffs.amount_ratio, 0.0, 1.5) * delta
	var spec: Array = KINDS[puffs.kind]
	var motes: Array = _motes[puffs.kind]

	while puffs._owed >= 1.0 and motes.size() < int(spec[5]):
		puffs._owed -= 1.0
		var at := puffs.origin + Vector3(_rng.randf_range(-1, 1) * puffs.box.x, 0.0, _rng.randf_range(-1, 1) * puffs.box.z)

		# (A box with height, as dust in a shaft: anywhere up it too.)
		if puffs.box.y > 0.0:
			at.y += _rng.randf_range(-1, 1) * puffs.box.y

		var v := puffs.velocity + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0, 1), _rng.randf_range(-1, 1)) * puffs.spread + Vector3.UP * puffs.rise
		motes.append({"p": at, "v": v, "age": 0.0, "wind": puffs.wind_share})


func _step(kind: StringName, delta: float, air: Vector3) -> void:
	var spec: Array = KINDS[kind]
	var life := float(spec[4])
	var motes: Array = _motes[kind]
	var i := motes.size() - 1

	while i >= 0:
		var mote: Dictionary = motes[i]
		mote["age"] = float(mote["age"]) + delta

		if float(mote["age"]) >= life:
			motes.remove_at(i)
		else:
			var drift: Vector3 = air * float(mote["wind"])
			mote["v"] = (mote["v"] as Vector3).lerp(drift + Vector3.UP * (mote["v"] as Vector3).y, 1.0 - exp(-1.5 * delta))
			mote["p"] = (mote["p"] as Vector3) + (mote["v"] as Vector3) * delta

		i -= 1


func _make_draw(kind: StringName) -> MultiMeshInstance3D:
	var spec: Array = KINDS[kind]
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	look.billboard_keep_scale = true
	look.vertex_color_use_as_albedo = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.disable_fog = kind == &"ember"

	if kind == &"breath":
		look.albedo_texture = Fx.texture(&"puff")
		look.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	quad.material = look
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = quad
	multi.instance_count = int(spec[5])
	multi.visible_instance_count = 0
	var draw := MultiMeshInstance3D.new()
	draw.multimesh = multi
	draw.layers = Layers.FX
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.top_level = true
	add_child(draw)
	return draw


func _show(kind: StringName) -> void:
	var spec: Array = KINDS[kind]
	var motes: Array = _motes[kind]
	var multi: MultiMesh = (_draw[kind] as MultiMeshInstance3D).multimesh
	var life := float(spec[4])
	var count := mini(motes.size(), multi.instance_count)

	for i in count:
		var mote: Dictionary = motes[i]
		var u := float(mote["age"]) / life
		var size := lerpf(float(spec[0]), float(spec[1]), u)
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), mote["p"]))
		multi.set_instance_color(i, (spec[2] as Color).lerp(spec[3], u))

	multi.visible_instance_count = count
