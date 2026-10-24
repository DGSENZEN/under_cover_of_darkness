extends Node3D
## Ánimas from a drain (docs/superpowers/refs/underground/supernatural_refs.md): the souls of the old city's
## drowned, come up the drain from its cistern. They are the ánimas of the retablos, burning in purgatory and
## begging the living for their candles and their prayers. Each is a black hand reaching up out of a crown of
## chartreuse spirit-fire, drawn as Graves' Deadheads are (vfx_method.md), a ribbon of it trailing behind.
##
## What each does, in its turn:
## - below: pressed up under the grate, edge-on, so its fingers come up through a slot;
## - climbing: up through a gap to the wrist, held there trembling as if feeling for a hold, then torn free;
## - seeking: making for a candle (`candles`, the lights the living keep) in halting surges, reaching ahead;
## - warming: close beside its flame, the hand turned to it;
## - straining: at the end of its tether toward what it cannot reach (her niche across the corridor),
##   reaching hard, lunging and pulled back;
## - pleading: to someone standing still near the drain, at arm's length before their eyes, chest high, the hand
##   reaching out to them; stepped into, it flinches aside, and never flees;
## - escorting: round the procession's dead while they walk (`gather`);
## - dragged: at the end of its time, or when what they fear passes (`hush`, the dark train), yanked back to the
##   drain, still reaching back toward what it leaves, and pulled down through it.
## All are bound to the drain, never farther from it than TETHER. The node is placed at the drain's middle at
## the floor, its axes the grate's (its gaps at `lanes` along Z).

## Under the grate: how deep their wrists are, how far along the slots they wander.
const HOME := Vector3(0.0, -0.24, 0.0)
const SLIDE := 0.17
## How far from the drain they can go (m), and where a climbing hand holds (its wrist at the grate).
const TETHER := 3.4
const GRIP_Y := 0.0
const GRIP_FOR := Vector2(0.7, 1.4)
## Torn free, how high it lurches (m) and how fast (m/s).
const FREED_Y := 0.42
const FREED_SPEED := 1.8
## Making for something: its pace at the height of a surge, its surges' rate (rad/s), its drift between them.
const SPEED := 0.55
const SURGE := 3.8
const IDLE := 0.08
## Dragged home: how fast at the last (m/s), how soon it gets there (m/s per s); through the gap.
const DRAG_SPEED := 2.6
const DRAG_GAIN := 5.0
const SINK_SPEED := 1.2
## How many are out at once, how long each stays out, how soon another climbs (s).
const WANT_OUT := 5
const OUT_FOR := Vector2(14.0, 26.0)
const RISE_GAP := Vector2(1.5, 4.0)
## At a candle: how far beside its flame (m), how far below it the wrist, how long it stays (s).
const WARM_OFF := 0.17
const WARM_DROP := 0.05
const WARM_FOR := Vector2(4.0, 9.0)
## Straining at the tether, how long (s), and how far each lunge goes (m).
const STRAIN_FOR := Vector2(3.0, 6.0)
const LUNGE := 0.09
## Begging: how long someone must stand still (s, under STILL m/s), how far before their eyes it hangs (m), how
## far below them, how near it lets them come before it flinches aside, how many beg at once, how often another
## is called from the candles (s).
const STILL := 0.35
const STILL_FOR := 1.0
const ARM := 0.85
const BELOW_EYES := 0.5
const FLINCH := 0.55
const PLEADERS := 2
const CALL_EVERY := 2.0
## How often a soul looks again at its way (s).
const ROUTE_EVERY := 0.25
## The lines a hand's way is looked along, off its wrist (m): its fire below, its palm above, round it where it leans.
const HAND_ROOM := [Vector3(0.0, -0.04, 0.0), Vector3.ZERO, Vector3(0.0, 0.14, 0.0), Vector3(0.12, 0.08, 0.0),
	Vector3(-0.12, 0.08, 0.0), Vector3(0.0, 0.08, 0.12), Vector3(0.0, 0.08, -0.12)]
## How each hand is held while it does each thing: how far it leans toward what it reaches for (rad), how
## hard it trembles (rad).
const TILT := {"below": 0.0, "climbing": 0.0, "seeking": 0.6, "warming": 0.7, "straining": 1.1, "pleading": 0.3,
	"escorting": 0.35, "dragged": 1.05}
const TREMBLE := {"below": 0.03, "climbing": 0.12, "seeking": 0.04, "warming": 0.03, "straining": 0.13,
	"pleading": 0.06, "escorting": 0.04, "dragged": 0.08}
## Shy of what passes them as well as of the near: how dim they go, near someone, for the escort's height.
const SHY_DIM := 0.75
const HEIGHT := Vector2(0.6, 1.5)

## Its spirit-fire: a crown of tongues round the wrist (the tallest, its width, the ring they stand round),
## sunk this far below the wrist; how far it streams behind for each m/s it moves, and at most.
const CROWN := Vector3(0.23, 0.032, 0.06)
const TONGUES := 5
const SHELL_SINK := 0.06
const STREAM := 0.075
const STREAM_MOST := 0.13
## The fire's bands, Graves' chartreuse (vfx_method.md): a near-white core held to its roots, the acid green,
## a deep olive edge. The hand's rim.
const CORE_COLOUR := Color("e6ff96")
const BODY_COLOUR := Color("b2ea3a")
const EDGE_COLOUR := Color("2a480b")
const RIM := Color("c8ff52")
const CORE_REACH := 0.25
## How bright its fire burns (past 1 the bloom takes it; much past, it whites out).
const FIRE_ENERGY := 1.5
const SILHOUETTE := preload("res://scripts/Visual/anima_silhouette.gdshader")
const AURA := preload("res://scripts/Visual/anima_aura.gdshader")
## Without hands: a flame of its own (its height and width).
const CORE := Vector2(0.26, 0.075)
## Its trail: how many points, how often one is laid (s), how wide at its head.
const TRAIL_POINTS := 20
const TRAIL_EVERY := 0.035
const TRAIL_WIDTH := 0.09
## The light each casts at full, and how far.
const LAMP_ENERGY := 0.3
const LAMP_RANGE := 1.6
## The glow under the grate: a sheet of light just under its bars, and a light deep in the sump.
const SHEET := Vector2(0.54, 0.54)
const SHEET_Y := -0.045
const GLOW_Y := -0.19
const GLOW_ENERGY := 0.3
const SHEET_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 colour : source_color;
uniform float presence = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// (Round, and gone well before the sheet's edges: no square shows.)
	float fall = 1.0 - smoothstep(0.2, 0.95, length(p));
	float stir = 0.85 + 0.15 * sin(TIME * 1.7 + p.x * 4.0) * sin(TIME * 1.1 + p.y * 3.0);
	ALBEDO = colour.rgb * fall * stir * presence * 1.2;
}
"""

@export var count := 9
@export var seed := 7
@export var colour := Color("a8eba0")
## The living: they beg of them, and flinch from them.
@export var flee_from: Node3D
## The candles the living keep (world): what they make for; and for each, which way it is open (world, as long as
## the hand keeps off its flame), so the hand never reaches through what holds it.
@export var candles := PackedVector3Array()
@export var sides := PackedVector3Array()
## Ways round what stands near the drain (world): where nothing solid stands between a soul and where it goes, it
## goes straight; else by the way round with a clear line to both.
@export var ways := PackedVector3Array()
## The gaps between the grate's bars, along local Z.
@export var lanes := PackedFloat32Array()
## The hands they are (from the uncanny kit: one reaching, one clawing); without them, flames.
@export var hand_meshes: Array[Mesh] = []

## Each ánima's hand (it carries its aura and its light), its fire, its trail, its light.
var lights: Array[MeshInstance3D] = []
var shells: Array[MeshInstance3D] = []
var ribbons: Array[MeshInstance3D] = []
var lamps: Array[OmniLight3D] = []
var glow: OmniLight3D
## 1 when they are here; 0 when they have hidden from what passes.
var presence := 1.0
## Something passing they fear (the dark train, 0-1): they are all dragged down and go dark.
var hush := 0.0
## Something they gather to (the procession walking): those out escort it instead.
var gather: Node3D

var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _souls := []
var _next_rise := 0.0
var _next_call := 0.0
var _cores: Array[ShaderMaterial] = []
var _auras: Array[ShaderMaterial] = []
var _fire_looks: Array[ShaderMaterial] = []
var _trail_looks: Array[ShaderMaterial] = []
var _paths := []
var _trail_clock := 0.0
var _sheet: ShaderMaterial
## The living's last place, and how long they have stood still.
var _living_was := Vector3.INF
var _still_for := 0.0


func _ready() -> void:
	_rng.seed = seed
	var core_mesh := MeshVfx.flame(CORE.x, CORE.y)

	for i in count:
		var hand := MeshInstance3D.new()
		hand.name = "anima_%d" % i
		var core: ShaderMaterial

		if hand_meshes.is_empty():
			hand.mesh = core_mesh
			core = MeshVfx.look(CORE_COLOUR, BODY_COLOUR, EDGE_COLOUR, 3.2, 0.02, 0.9, float(i) * 3.1)
		else:
			# A hand reaching up out of its fire, as Graves' Deadheads are drawn: black, its rim aglow.
			hand.mesh = hand_meshes[i % hand_meshes.size()]
			core = ShaderMaterial.new()
			core.shader = SILHOUETTE
			core.set_shader_parameter(&"glow", RIM)
			core.set_shader_parameter(&"noise", MeshVfx.noise())
			core.set_shader_parameter(&"seed", float(i) * 2.9)
			# Its aura: the hand's shape pushed out a little and lit from behind, outlining it in fire.
			var aura := MeshInstance3D.new()
			aura.name = "aura"
			aura.mesh = hand.mesh
			var burn := ShaderMaterial.new()
			burn.shader = AURA
			burn.set_shader_parameter(&"glow", RIM)
			burn.set_shader_parameter(&"noise", MeshVfx.noise())
			burn.set_shader_parameter(&"seed", float(i) * 2.9)
			aura.set_surface_override_material(0, burn)
			aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hand.add_child(aura)
			_auras.append(burn)

		hand.set_surface_override_material(0, core)
		hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hand)
		lights.append(hand)
		_cores.append(core)

		# Its fire: a crown of tongues round the wrist, standing up in the world whichever way the hand reaches,
		# streaming behind it as it goes, eaten away in tongues as they climb.
		var shell := MeshInstance3D.new()
		shell.name = "fire"
		shell.mesh = MeshVfx.tongues(TONGUES, CROWN.x, CROWN.y, CROWN.z, 0.5, seed * 31 + i)
		var fire := MeshVfx.look(CORE_COLOUR, BODY_COLOUR, EDGE_COLOUR, FIRE_ENERGY, 0.2, 1.7, float(i) * 1.7 + 9.0)
		fire.set_shader_parameter(&"tail_eat", 0.7)
		fire.set_shader_parameter(&"hardness", 0.03)
		fire.set_shader_parameter(&"churn", 0.01)
		fire.set_shader_parameter(&"tiling", Vector2(1.7, 1.0))
		fire.set_shader_parameter(&"core_reach", CORE_REACH)
		shell.set_surface_override_material(0, fire)
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand.add_child(shell)
		shells.append(shell)
		_fire_looks.append(fire)

		# Its trail: a ribbon of its fire left where it has been (drawn in the world, not carried).
		var ribbon := MeshInstance3D.new()
		ribbon.name = "ribbon_%d" % i
		ribbon.top_level = true
		var trail := MeshVfx.look(BODY_COLOUR, BODY_COLOUR.darkened(0.3), EDGE_COLOUR, 1.8, 0.2, 2.0, float(i) * 2.3 + 4.0)
		trail.set_shader_parameter(&"tail_eat", 0.85)
		trail.set_shader_parameter(&"tiling", Vector2(1.0, 3.0))
		trail.set_shader_parameter(&"churn", 0.0)
		trail.set_shader_parameter(&"hardness", 0.03)
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ribbon)
		ribbon.global_transform = Transform3D.IDENTITY
		ribbons.append(ribbon)
		_trail_looks.append(trail)
		_paths.append(PackedVector3Array())

		var lamp := OmniLight3D.new()
		lamp.name = "lamp"
		lamp.light_color = colour
		lamp.omni_range = LAMP_RANGE
		lamp.shadow_enabled = false
		lamp.light_energy = 0.0
		shell.add_child(lamp)
		lamp.position = Vector3(0.0, CROWN.x * 0.5, 0.0)
		lamps.append(lamp)

		var phase := Vector3(_rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU), _rng.randf_range(0.0, TAU))
		var lane: float = lanes[(i * 5) % lanes.size()] if not lanes.is_empty() else 0.0
		_souls.append({"state": "below", "phase": phase, "t": 0.0, "until": 0.0, "lane": lane, "goal": Vector3.ZERO,
			"held": 0.0, "candle": -1, "fade": 1.0, "flare": 0.0, "at": Vector3.ZERO, "vel": Vector3.ZERO,
			"face": Vector3.FORWARD, "clock": 0.0, "from": Vector3.ZERO, "pace": 0.0, "route": Vector3.INF,
			"route_to": Vector3.INF, "route_at": 0.0})
		_souls[i]["at"] = _below(i)
		hand.position = _souls[i]["at"]

	_build_glow()
	_next_rise = _rng.randf_range(0.2, 1.0)


## What one is doing now (see the head of this file).
func state_of(i: int) -> String:
	return _souls[i]["state"]


## One ánima sent up now (the stills; they climb by themselves); returns it.
func rise_now() -> Node3D:
	for i in count:
		if _souls[i]["state"] == "below":
			_become(i, "climbing")
			return lights[i]

	return lights[0]


func _process(delta: float) -> void:
	_time += delta
	var hidden := hush > 0.3
	presence = maxf(0.0, presence - 3.0 * delta) if hidden else minf(1.0, presence + 0.8 * delta)
	_watch_living(delta)

	if not hidden:
		_next_rise -= delta
		if _count_out() < WANT_OUT and _next_rise <= 0.0:
			for i in count:
				if _souls[i]["state"] == "below":
					_become(i, "climbing")
					break
			_next_rise = _rng.randf_range(RISE_GAP.x, RISE_GAP.y)
		_call_to_beg(delta)

	for i in count:
		_move(i, delta, hidden)

	_trail(delta)
	_sheet.set_shader_parameter(&"presence", presence)
	glow.light_energy = GLOW_ENERGY * presence


func _count_out() -> int:
	var out := 0

	for soul in _souls:
		out += 1 if soul["state"] != "below" else 0

	return out


func _count(state: String) -> int:
	var n := 0

	for soul in _souls:
		n += 1 if soul["state"] == state else 0

	return n


func _become(i: int, state: String) -> void:
	var soul: Dictionary = _souls[i]
	soul["state"] = state
	soul["held"] = 0.0
	soul["clock"] = 0.0

	match state:
		"climbing":
			soul["t"] = 0.0
			soul["until"] = _rng.randf_range(OUT_FOR.x, OUT_FOR.y)
			soul["held"] = _rng.randf_range(GRIP_FOR.x, GRIP_FOR.y)
		"warming":
			soul["held"] = _rng.randf_range(WARM_FOR.x, WARM_FOR.y)
			soul["flare"] = 1.0
		"straining":
			soul["held"] = _rng.randf_range(STRAIN_FOR.x, STRAIN_FOR.y)
		"dragged":
			soul["pace"] = 0.4
			soul["flare"] = 1.0
			soul["candle"] = -1
		"pleading", "escorting":
			soul["candle"] = -1


## Where a soul goes next once free: home if its time is up; to someone standing still near, if few beg them yet;
## round the procession while it walks; else to a candle, or to strain toward one out of reach.
func _choose(i: int) -> void:
	var soul: Dictionary = _souls[i]

	if soul["t"] > soul["until"] and not _gathering():
		_become(i, "dragged")
		return

	if _gathering():
		_become(i, "escorting")
		return

	if _beggable() and _count("pleading") < PLEADERS:
		_become(i, "pleading")
		return

	var free := []
	var taken := []
	var far := []

	for c in candles.size():
		var spot := _warm_spot(c)
		if _flat(spot).length() > TETHER:
			far.append(c)
		elif _souls.any(func(s): return s["candle"] == c):
			taken.append(c)
		else:
			free.append(c)

	soul["candle"] = -1

	if not far.is_empty() and _count("straining") == 0 and _rng.randf() < 0.35:
		soul["candle"] = far[_rng.randi() % far.size()]
		soul["goal"] = _tethered(to_local(candles[soul["candle"]]), _rng.randf_range(0.7, 1.3))
		soul["state"] = "seeking"
		soul["from"] = to_local(candles[soul["candle"]])
		return

	var pick: Array = free if not free.is_empty() else taken

	if not pick.is_empty():
		soul["candle"] = pick[_rng.randi() % pick.size()]
		soul["goal"] = _warm_spot(soul["candle"])
		soul["from"] = to_local(candles[soul["candle"]])
	else:
		# (No candles here: about the drain.)
		var a := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(0.4, TETHER * 0.7)
		soul["goal"] = Vector3(cos(a) * r, _rng.randf_range(HEIGHT.x, HEIGHT.y), sin(a) * r)
		soul["from"] = soul["goal"]

	soul["state"] = "seeking"
	soul["clock"] = 0.0


## Beside a candle's flame on its open side (`sides`; else toward the drain), the wrist a little below the flame
## (local).
func _warm_spot(c: int) -> Vector3:
	var flame := to_local(candles[c])
	var out := -_flat(flame).normalized() * WARM_OFF if _flat(flame).length() > 0.01 else Vector3.RIGHT * WARM_OFF

	if c < sides.size():
		out = global_basis.inverse() * sides[c]

	return flame + out + Vector3(0.0, -WARM_DROP, 0.0)


## A point held within the tether, at a height.
func _tethered(at: Vector3, y: float) -> Vector3:
	var flat := _flat(at)
	if flat.length() > TETHER - 0.05:
		flat = flat.normalized() * (TETHER - 0.05)
	return Vector3(flat.x, y, flat.z)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _gathering() -> bool:
	return gather != null and is_instance_valid(gather) and gather.is_visible_in_tree()


## How long the living have stood still.
func _watch_living(delta: float) -> void:
	if flee_from == null or not is_instance_valid(flee_from):
		_still_for = 0.0
		return

	var at := flee_from.global_position
	var moved := at.distance_to(_living_was) / maxf(delta, 1e-4) if _living_was != Vector3.INF else INF
	_living_was = at
	_still_for = _still_for + delta if moved < STILL else 0.0


## Someone has stood still within reach of the drain.
func _beggable() -> bool:
	if _still_for < STILL_FOR:
		return false

	return _flat(to_local(flee_from.global_position)).length() < TETHER + ARM


## Someone standing still near: now and then one more leaves its candle and comes to beg of them.
func _call_to_beg(delta: float) -> void:
	_next_call -= delta
	if _next_call > 0.0 or not _beggable() or _count("pleading") >= PLEADERS:
		return

	_next_call = CALL_EVERY
	var them := to_local(flee_from.global_position)
	var best := -1

	for i in count:
		if _souls[i]["state"] in ["seeking", "warming", "straining"]:
			if best < 0 or _souls[i]["at"].distance_to(them) < _souls[best]["at"].distance_to(them):
				best = i

	if best >= 0:
		_become(best, "pleading")


## Where a pleading soul hangs: at arm's length before the living's eyes, a little below them (local).
func _before_them() -> Vector3:
	var eye := _eye()
	var ahead := _flat(-eye.basis.z)
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	return to_local(eye.origin + ahead * ARM + Vector3(0.0, -BELOW_EYES, 0.0))


## The living's eyes: the camera, if it is theirs; else their body, a head above it.
func _eye() -> Transform3D:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.global_position.distance_to(flee_from.global_position) < 1.2:
		return camera.global_transform

	return Transform3D(flee_from.global_basis, flee_from.global_position + Vector3(0.0, 0.6, 0.0))


func _move(i: int, delta: float, hidden: bool) -> void:
	var soul: Dictionary = _souls[i]
	var at: Vector3 = soul["at"]
	var was := at
	soul["t"] += delta
	soul["clock"] += delta
	soul["flare"] = maxf(0.0, soul["flare"] - 1.4 * delta)

	if hidden and soul["state"] in ["seeking", "warming", "straining", "pleading", "escorting", "climbing"]:
		_become(i, "dragged")

	var state: String = soul["state"]
	var phase: Vector3 = soul["phase"]
	# What it reaches toward (local), if anything.
	var toward := Vector3.INF

	match state:
		"below":
			at = at.lerp(_below(i), 1.0 - exp(-3.0 * delta))
		"climbing":
			# Up its gap to the wrist, held there trembling, then torn free and up.
			var gap := Vector3(clampf(at.x, -SLIDE, SLIDE), at.y, soul["lane"])
			if at.y < GRIP_Y - 0.005 and soul["clock"] < 3.0:
				at = at.move_toward(Vector3(gap.x, GRIP_Y, gap.z), SPEED * 1.2 * delta)
			elif soul["held"] > 0.0:
				soul["held"] -= delta
				if soul["held"] <= 0.0:
					soul["flare"] = 1.0
			else:
				at = at.move_toward(Vector3(at.x, FREED_Y, at.z), FREED_SPEED * delta)
				if at.y >= FREED_Y - 0.01:
					_choose(i)
		"seeking":
			# In surges: a lunge, then a pause, reaching ahead.
			var surge := pow(maxf(0.0, sin(soul["clock"] * SURGE + phase.x)), 2.0)
			at = at.move_toward(_next(i, soul["goal"]), SPEED * (IDLE + 2.0 * surge) * delta)
			toward = soul["goal"] + Vector3(0.0, 0.2, 0.0) if at.distance_to(soul["goal"]) > 0.25 else soul["from"]
			if at.distance_to(soul["goal"]) < 0.04:
				if soul["candle"] >= 0 and _flat(_warm_spot(soul["candle"])).length() <= TETHER:
					_become(i, "warming")
				elif soul["candle"] >= 0:
					_become(i, "straining")
				else:
					_choose(i)
		"warming":
			var spot := _warm_spot(soul["candle"])
			var bob := Vector3(sin(_time * 1.3 + phase.x), sin(_time * 0.9 + phase.y), sin(_time * 1.1 + phase.z)) * 0.02
			at = at.lerp(spot + bob, 1.0 - exp(-4.0 * delta))
			toward = to_local(candles[soul["candle"]])
			soul["held"] -= delta
			if soul["held"] <= 0.0:
				_choose(i)
		"straining":
			# At the tether's end, reaching hard toward what it cannot reach; lunging, pulled back.
			var lunge := maxf(0.0, sin(soul["clock"] * 2.6 + phase.y))
			var reach: Vector3 = soul["goal"] + _flat(soul["from"] - soul["goal"]).normalized() * LUNGE * lunge
			at = at.lerp(_next(i, _tethered(reach, reach.y)), 1.0 - exp(-7.0 * delta))
			toward = soul["from"]
			soul["held"] -= delta
			if soul["held"] <= 0.0:
				_choose(i)
		"pleading":
			if not _living():
				_choose(i)
			else:
				var spot := _before_them()
				var them := to_local(flee_from.global_position)
				# Out of reach (they have gone on), it strains after them.
				if _flat(spot).length() > TETHER:
					soul["goal"] = _tethered(spot, spot.y)
					soul["from"] = them + Vector3(0.0, 0.6, 0.0)
					_become(i, "straining")
					soul["candle"] = -1
				else:
					var lift := sin(soul["clock"] * 1.4 + phase.x) * 0.05
					at = at.move_toward(_next(i, spot + Vector3(0.0, lift, 0.0)), SPEED * 1.6 * delta)
					toward = them + Vector3(0.0, 0.6, 0.0)
				if soul["t"] > soul["until"] + 6.0 or (not _beggable() and soul["t"] > soul["until"]):
					_become(i, "dragged")
		"escorting":
			if not _gathering():
				_choose(i)
			else:
				var round_it := to_local(gather.global_position)
				var a := _time * 0.7 + phase.x
				var goal := _tethered(round_it + Vector3(cos(a), 0.0, sin(a)) * 0.8, lerpf(HEIGHT.x, HEIGHT.y, 0.5 + 0.5 * sin(phase.y + _time)))
				at = at.move_toward(_next(i, goal), SPEED * 2.4 * delta)
				toward = round_it + Vector3(0.0, 1.2, 0.0)
		"dragged":
			# Yanked back to its gap, faster and faster, reaching back toward what it leaves; then down through it.
			soul["pace"] = minf(DRAG_SPEED, soul["pace"] + DRAG_GAIN * delta)
			var mouth := Vector3(clampf(at.x, -SLIDE, SLIDE), 0.12, _nearest_lane(at.z))
			if _flat(at - mouth).length() > 0.03:
				at = at.move_toward(_next(i, Vector3(mouth.x, maxf(mouth.y, minf(at.y, 0.6)), mouth.z)), soul["pace"] * delta)
				toward = soul["from"] if soul["from"] != Vector3.ZERO else at + Vector3(0.0, 0.5, 0.0)
			else:
				soul["lane"] = mouth.z
				at = at.move_toward(Vector3(at.x, HOME.y, mouth.z), SINK_SPEED * delta)
				if at.y <= HOME.y + 0.02:
					soul["state"] = "below"
					soul["from"] = Vector3.ZERO

	if state in ["seeking", "warming", "straining", "pleading", "escorting", "dragged"]:
		at = _flinch(at)

	soul["at"] = at
	if state in ["warming", "pleading", "straining"] and toward != Vector3.INF:
		soul["from"] = toward
	var vel := (at - was) / maxf(delta, 1e-4)
	soul["vel"] = (soul["vel"] as Vector3).lerp(vel, 1.0 - exp(-10.0 * delta))
	_draw(i, delta, toward)


## The next point on a soul's way to `goal` (local): `goal` itself if nothing solid stands between, else the way
## round with clear lines to both, the shortest. (Looked again a few times a second, or when the goal moves.)
func _next(i: int, goal: Vector3) -> Vector3:
	var soul: Dictionary = _souls[i]

	if _time < soul["route_at"] and (soul["route_to"] as Vector3).distance_to(goal) < 0.15:
		return goal if soul["route"] == Vector3.INF else soul["route"]

	soul["route_at"] = _time + ROUTE_EVERY
	soul["route_to"] = goal
	var at: Vector3 = soul["at"]
	var next := goal

	if not _clear(at, goal):
		var shortest := INF

		for w in ways:
			var round_it := to_local(w)
			var length := at.distance_to(round_it) + round_it.distance_to(goal)
			if length < shortest and _clear(at, round_it) and _clear(round_it, goal):
				shortest = length
				next = round_it

	# (Straight there: the goal itself, wherever it has moved since.)
	soul["route"] = Vector3.INF if next == goal else next
	return next


## Whether a hand could go from `a` to `b` (local) with nothing solid in the way: its wrist's line, its fire's below
## it, its palm's above, and its fingers' either side, however it leans (HAND_ROOM).
func _clear(a: Vector3, b: Vector3) -> bool:
	var space := get_world_3d().direct_space_state

	for off in HAND_ROOM:
		var ray := PhysicsRayQueryParameters3D.create(to_global(a + off), to_global(b + off))
		if _living() and flee_from is CollisionObject3D:
			ray.exclude = [(flee_from as CollisionObject3D).get_rid()]
		if not space.intersect_ray(ray).is_empty():
			return false

	return true


## Kept out of the living's body: one that comes too near flinches aside.
func _flinch(at: Vector3) -> Vector3:
	if not _living() or at.y < 0.1:
		return at

	var them := to_local(flee_from.global_position)
	var off := _flat(at - them)

	if off.length() < FLINCH:
		var away := off.normalized() if off.length() > 0.01 else Vector3.RIGHT
		var to := them + away * FLINCH
		at.x = to.x
		at.z = to.z

	return at


func _living() -> bool:
	return flee_from != null and is_instance_valid(flee_from)


## The hand drawn where its soul is: turned toward what it reaches for (fingers leaning to it, palm to it),
## trembling; its fire standing up from the wrist and streaming behind; its light, its fading.
func _draw(i: int, delta: float, toward: Vector3) -> void:
	var soul: Dictionary = _souls[i]
	var hand := lights[i]
	var state: String = soul["state"]
	var at: Vector3 = soul["at"]
	var phase: Vector3 = soul["phase"]
	var amount: float = TREMBLE[state]
	var shake := Vector3(sin(_time * 31.0 + phase.x), sin(_time * 27.0 + phase.y), sin(_time * 29.0 + phase.z))
	hand.position = at + shake * amount * 0.012

	# Which way it faces: toward what it reaches for; going, the way it goes; below and climbing, edge-on to the slots.
	var face: Vector3 = soul["face"]
	var tilt: float = TILT[state]

	if state in ["below", "climbing"] or (state == "dragged" and at.y < 0.3 and _flat(at - Vector3(at.x, 0.0, _nearest_lane(at.z))).length() < 0.2 and absf(at.x) < SLIDE + 0.2):
		face = Vector3.FORWARD
		tilt = 0.0
	elif toward != Vector3.INF and _flat(toward - at).length() > 0.02:
		face = _flat(toward - at).normalized()
	elif _flat(soul["vel"]).length() > 0.05:
		face = _flat(soul["vel"]).normalized()

	soul["face"] = face
	if state == "pleading":
		tilt += 0.2 * sin(soul["clock"] * 1.4 + phase.x)
	# Fingers leaning toward it by `tilt`, the palm turned to it.
	var up := Vector3.UP * cos(tilt) + face * sin(tilt)
	var palm := face * cos(tilt) - Vector3.UP * sin(tilt)
	var turned := Basis(palm, up, palm.cross(up)).orthonormalized()
	var wobble := Basis(Vector3(cos(phase.x + _time), 0.0, sin(phase.x + _time)).normalized(), amount * sin(_time * 23.0 + phase.y))
	# (Turned edge-on fast as it goes down through its slot, so it never lies across the bars.)
	var rate := 20.0 if tilt == 0.0 and state != "below" else (9.0 if state == "dragged" else 5.0)
	hand.quaternion = hand.quaternion.slerp((wobble * turned).get_rotation_quaternion(), 1.0 - exp(-rate * delta))

	# Its fire: upright in the world at the wrist, taller as it flares or hurries, streaming behind it.
	var shell := shells[i]
	var vel: Vector3 = soul["vel"]
	var speed := vel.length()
	var flare: float = soul["flare"]
	var tall := 1.0 + 0.5 * flare + 0.25 * minf(speed, 1.5)
	var wide := 1.0 + 0.15 * flare
	shell.global_transform = Transform3D(Basis.from_scale(Vector3(wide, tall, wide)),
		hand.global_position + Vector3(0.0, -SHELL_SINK, 0.0))
	var stream := -(global_basis * vel) * STREAM
	if stream.length() > STREAM_MOST:
		stream = stream.normalized() * STREAM_MOST
	# (Given in the fire's own, scaled space.)
	_fire_looks[i].set_shader_parameter(&"sway", Vector3(stream.x / wide, stream.y / tall, stream.z / wide))
	_fire_looks[i].set_shader_parameter(&"energy", FIRE_ENERGY + 1.2 * flare)

	# Dimmer near the living (they are shy of them), and eaten away as they fade.
	var near := _living() and _flat(at - to_local(flee_from.global_position)).length() < FLINCH + 0.4
	soul["fade"] = lerpf(soul["fade"], SHY_DIM if near else 1.0, 1.0 - exp(-4.0 * delta))
	var shown: float = soul["fade"] * presence

	if hand_meshes.is_empty():
		_cores[i].set_shader_parameter(&"erosion", lerpf(0.75, 0.02, shown))
	else:
		_cores[i].set_shader_parameter(&"presence", shown)
		_auras[i].set_shader_parameter(&"presence", shown)

	_fire_looks[i].set_shader_parameter(&"erosion", lerpf(0.9, 0.2, shown))
	_trail_looks[i].set_shader_parameter(&"erosion", lerpf(0.95, 0.2, shown))
	var risen := clampf(at.y / 0.4, 0.0, 1.0)
	lamps[i].light_energy = LAMP_ENERGY * risen * shown * (1.0 + 0.8 * flare)


## Where a soul below wanders: along its slot under the grate.
func _below(i: int) -> Vector3:
	var p: Vector3 = _souls[i]["phase"] if i < _souls.size() else Vector3.ZERO
	var lane: float = _souls[i]["lane"] if i < _souls.size() else 0.0
	return Vector3(HOME.x + sin(_time * 0.43 + p.x) * SLIDE * 0.8, HOME.y + sin(_time * 0.81 + p.y) * 0.025, lane)


func _nearest_lane(z: float) -> float:
	if lanes.is_empty():
		return z

	var best: float = lanes[0]

	for lane in lanes:
		if absf(lane - z) < absf(best - z):
			best = lane

	return best


## Each soul's trail: where its fire has been, a point every TRAIL_EVERY s, drawn as a ribbon turned to the eye;
## none while it is under the grate or climbing.
func _trail(delta: float) -> void:
	_trail_clock += delta
	var step := _trail_clock >= TRAIL_EVERY
	if step:
		_trail_clock = 0.0
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else global_position + Vector3(0, 1.6, 3)

	for i in count:
		var path: PackedVector3Array = _paths[i]
		var head := shells[i].global_position + Vector3(0.0, CROWN.x * 0.4, 0.0)

		if _souls[i]["state"] in ["below", "climbing"]:
			path.clear()
		elif step:
			path.insert(0, head)
			if path.size() > TRAIL_POINTS:
				path.resize(TRAIL_POINTS)
		elif path.size() > 0:
			path[0] = head

		_paths[i] = path
		if path.size() >= 2:
			# (Its look on the mesh itself: a mesh made anew each frame drops a node's override.)
			var strip := MeshVfx.ribbon(path, TRAIL_WIDTH, eye)
			strip.surface_set_material(0, _trail_looks[i])
			ribbons[i].mesh = strip
		else:
			ribbons[i].mesh = null


func _build_glow() -> void:
	var sheet := MeshInstance3D.new()
	sheet.name = "anima_sheet"
	var plane := PlaneMesh.new()
	plane.size = SHEET
	_sheet = ShaderMaterial.new()
	_sheet.shader = Shader.new()
	_sheet.shader.code = SHEET_CODE
	_sheet.set_shader_parameter(&"colour", colour)
	plane.material = _sheet
	sheet.mesh = plane
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)
	sheet.position = Vector3(0.0, SHEET_Y, 0.0)
	glow = OmniLight3D.new()
	glow.name = "anima_glow"
	glow.light_color = colour
	glow.omni_range = 0.35
	glow.shadow_enabled = false
	glow.light_energy = GLOW_ENERGY
	add_child(glow)
	glow.position = Vector3(0.0, GLOW_Y, 0.0)
