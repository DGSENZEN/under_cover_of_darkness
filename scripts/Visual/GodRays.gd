extends Node3D
## Window shafts swept along direction to inward-facing room planes and drawn with glass colours.
## The depth shader softens contact and edge-on views; dust drifts within each volume.
## Night moon/cloud/rain/lightning state scales the shafts and companion lights from their calm energy.

const SHADER := preload("res://scripts/Visual/god_rays.gdshader")

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
	strength = brightness


## Builds a shaft from matching local outline/UV arrays; outline must contain at least three points.
## Sweeps vertices to inward-facing planes and returns a child MeshInstance3D; caller provides the glass texture/material inputs.
func add_window(outline: PackedVector3Array, uvs: PackedVector2Array) -> MeshInstance3D:
	var way := direction.normalized()
	var far := PackedVector3Array()
	var middle := Vector3.ZERO

	for p in outline:
		far.append(p + way * _reach(p, way))
		middle += p / float(outline.size())

	# Each corner's normal points straight out from the shaft's axis (round,
	# not faceted: its edge-on softening shows no creases).
	var round := PackedVector3Array()

	for p in outline:
		var out := p - middle
		round.append((out - way * out.dot(way)).normalized())

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
			st.set_uv2(Vector2(along[k], 0.0))
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
