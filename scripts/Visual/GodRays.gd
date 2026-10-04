extends Node3D
## Window shafts swept along direction to inward-facing room planes and drawn with glass colours.
## The depth shader softens contact and edge-on views; dust drifts within each volume.
## Night moon/cloud/rain/lightning state scales the shafts and companion lights from their calm energy.

const SHADER := preload("res://scripts/Visual/god_rays.gdshader")
## The shader's own tint (moonlight through clear glass), edge fade and
## fall-off.
const TINT := Color(0.6, 0.78, 1.25)
const EDGE := Vector2(0.03, 0.45)
const FALL := 0.7

## The way the light goes (normalised when used).
@export var direction := Vector3(0.62, -0.5, 0.6)
## How bright the shafts are under a clear moon.
@export var brightness := 1.0
## Below this share of the moon's light they are gone; from 1 whole.
@export var fade_from := 0.3
## A lightning flash (the moon's share over 1) flares them this much for each
## unit of it.
@export var flare_gain := 1.2
## However the weather (a cloud over the moon, rain), never less than this
## share of their brightness: the chapel is never without them.
@export var least := 0.6
## Driven by the moon's share (the night's); false: a lamp's shafts, whose
## strength their owner sets (Windows).
@export var follow_moon := true
## The light's colour through clear glass, and how much the shafts add.
@export var tint := TINT
@export var gain := 0.14
## A face is whole from this square-on to the view, gone below edge_from
## (a window's: soft, not slabs); how fast a shaft dims along its length.
## Left as made, the shader's own (the chapel's look).
@export var edge_from := EDGE.x
@export var edge_to := EDGE.y
@export var fall_power := FALL
## The glass's picture (null: plain moonlight).
var glass: Texture2D
## The room the shafts stay in: each plane's normal points inside it.
var planes: Array[Plane] = []
## Lights that follow the shafts (from their `calm` meta, or the energy they
## had when given).
var lights: Array[Light3D] = []

## How bright the shafts are now (brightness times the light's share).
var strength := 0.0
var beams: Array[MeshInstance3D] = []

var _material: ShaderMaterial
var _night: Node = null


func _ready() -> void:
	add_to_group(&"god_rays")
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"glass", glass if glass != null else _white())
	_material.set_shader_parameter(&"dust", _dust())
	# (The shader's own tint unless given another: the chapel's as it was.)
	if tint != TINT:
		_material.set_shader_parameter(&"tint", tint)

	_material.set_shader_parameter(&"gain", gain)

	if Vector2(edge_from, edge_to) != EDGE:
		_material.set_shader_parameter(&"edge_from", edge_from)
		_material.set_shader_parameter(&"edge_to", edge_to)

	if fall_power != FALL:
		_material.set_shader_parameter(&"fall_power", fall_power)
	strength = brightness


## Builds a shaft from matching local outline/UV arrays; outline must contain at least three points.
## Each corner goes `direction` (or, from a finite `source`, away from that point: a lamp's) to its
## own reach in `reaches` (else to the nearest of the node's planes); `weight` scales this shaft
## among the node's. Returns a child MeshInstance3D; caller provides the glass texture/material inputs.
func add_window(outline: PackedVector3Array, uvs: PackedVector2Array, reaches := PackedFloat32Array(), source := Vector3.INF,
		weight := 1.0) -> MeshInstance3D:
	var ways := PackedVector3Array()
	var far := PackedVector3Array()
	var middle := Vector3.ZERO
	var own := reaches.size() == outline.size()

	for i in outline.size():
		var p := outline[i]
		var way := (p - source).normalized() if source.is_finite() else direction.normalized()
		ways.append(way)
		far.append(p + way * (reaches[i] if own else _reach(p, way)))
		middle += p / float(outline.size())

	# Each corner's normal points straight out from the shaft's axis (round,
	# not faceted: its edge-on softening shows no creases).
	var round := PackedVector3Array()

	for i in outline.size():
		var out := outline[i] - middle
		round.append((out - ways[i] * out.dot(ways[i])).normalized())

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in outline.size():
		var j := (i + 1) % outline.size()
		var quad: Array[Vector3] = [outline[i], outline[j], far[j], far[i]]
		var normals: Array[Vector3] = [round[i], round[j], round[j], round[i]]
		var along := [0.0, 0.0, 1.0, 1.0]
		var glass_uv: Array[Vector2] = [uvs[i], uvs[j], uvs[j], uvs[i]]

		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(normals[k])
			st.set_uv(glass_uv[k])
			st.set_uv2(Vector2(along[k], weight))
			st.add_vertex(quad[k])

	var beam := MeshInstance3D.new()
	beam.name = "Beam%d" % beams.size()
	beam.mesh = st.commit()
	beam.material_override = _material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beams.append(beam)
	return beam


## How far along `way` from `p` the room ends (its nearest plane), less a
## little so the shaft's end stays inside.
func _reach(p: Vector3, way: Vector3) -> float:
	var best := 60.0

	for plane in planes:
		var toward := plane.normal.dot(way)

		if toward < -0.0001:
			best = minf(best, (plane.distance_to(p)) / -toward)

	return maxf(best - 0.03, 0.0)


func _process(_delta: float) -> void:
	if follow_moon:
		var share := _light_share()
		var steady := lerpf(least, 1.0, smoothstep(fade_from, 1.0, minf(share, 1.0)))
		var flare := maxf(share - 1.0, 0.0)
		strength = brightness * (steady + flare_gain * flare)

	_material.set_shader_parameter(&"strength", strength)

	for light in lights:
		if is_instance_valid(light):
			light.light_energy = float(light.get_meta(&"calm", 1.0)) * strength / maxf(brightness, 0.001)


func _light_share() -> float:
	if _night == null or not is_instance_valid(_night):
		_night = get_tree().get_first_node_in_group(&"night")

	return float(_night.moon_share()) if _night != null and _night.has_method(&"moon_share") else 1.0


## Dust drifting in the light: soft seamless noise.
static func _dust() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 23
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.06
	noise.fractal_octaves = 3
	var image := noise.get_seamless_image(64, 64, false, false, 0.1, true)
	return ImageTexture.create_from_image(image)


static func _white() -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
