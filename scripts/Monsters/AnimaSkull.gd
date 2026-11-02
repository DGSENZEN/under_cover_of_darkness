extends Node3D
## The ánima's face as a piece: the dried skull, its jaw on its hinge, the tongue in it, the
## gullet hanging behind, the sinews from cheek to jaw stretched and thinned as it gapes, and
## the light down its throat. The one in the world (AnimaBody.gd) and the one on your face
## (LeechFace.gd) are the same thing, told how far to open.

const MODEL := "res://assets/monsters/anima_face.glb"
const ThroatShader := preload("res://scripts/Monsters/anima_throat.gdshader")

## How far its jaw drops, how far its tongue comes up (radians).
const JAW_DROPS := 0.85
const TONGUE_LIFTS := 0.11
## The light in its throat, behind its teeth, in the skull's space (m).
const THROAT_AT := Vector3(0.0, -0.1, 0.012)
const THROAT_SIZE := Vector3(0.048, 0.056, 0.05)

var _parts := {}
var _sinews: Array[Dictionary] = []
var _skull: Node3D
var _jaw: Node3D
var _tongue: Node3D
var _throat: MeshInstance3D
var _jaw_open := 0.0
var _tongue_up := 0.0
var _flare := 0.0


func _init(look: ShaderMaterial, layer := 1, z_clip := 1.0, fov := 0.0) -> void:
	var head: Node3D = (load(MODEL) as PackedScene).instantiate()
	add_child(head)
	var strand: Mesh = null

	for mesh in head.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == &"Sinew":
			strand = mesh.mesh
			mesh.get_parent().remove_child(mesh)
			mesh.free()
			continue

		_parts[StringName(mesh.name)] = mesh
		mesh.set_surface_override_material(0, look)
		mesh.layers = layer
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if layer != 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	_skull = _parts[&"Skull"]
	_jaw = _parts[&"Jaw"]
	_tongue = _parts[&"Tongue"]

	for marker in _skull.find_children("SinewUp_*", "Node3D", true, false):
		var low: Node3D = _jaw.find_child(String(marker.name).replace("SinewUp_", "SinewLow_"), true, false)

		if low == null:
			continue

		var sinew := MeshInstance3D.new()
		sinew.mesh = strand
		sinew.set_surface_override_material(0, look)
		sinew.layers = layer
		sinew.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_skull.add_child(sinew)
		_sinews.append({"mesh": sinew, "up": marker, "low": low, "rest": 0.0})

	_throat = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 12
	ball.rings = 6
	_throat.mesh = ball
	var glow := ShaderMaterial.new()
	glow.shader = ThroatShader
	glow.set_shader_parameter(&"z_clip", z_clip)
	glow.set_shader_parameter(&"fov_override", fov)
	_throat.material_override = glow
	_throat.layers = layer
	_throat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_throat.position = THROAT_AT
	_throat.scale = THROAT_SIZE
	_skull.add_child(_throat)
	_stretch()

	for sinew in _sinews:
		sinew["rest"] = _span(sinew)

	_stretch()


func part(id: StringName) -> MeshInstance3D:
	return _parts.get(id)


## The skull: what turns and nods; everything of the face rides on it.
func skull() -> Node3D:
	return _skull


## Opens it, 0..1, and how far up its tongue is, 0..1.
func open_to(jaw: float, tongue: float) -> void:
	_jaw_open = jaw
	_tongue_up = tongue
	_jaw.rotation.x = -JAW_DROPS * jaw
	_tongue.rotation.x = TONGUE_LIFTS * tongue
	_stretch()


func jaw_open() -> float:
	return _jaw_open


func tongue_up() -> float:
	return _tongue_up


## The light down its throat, 0..1.
func throat_to(flare: float) -> void:
	_flare = flare
	_throat.set_instance_shader_parameter(&"flare", flare)


func throat() -> float:
	return _flare


func paint(fed: float, hurt: float, smoulder: float) -> void:
	for id in _parts:
		_paint_one(_parts[id], fed, hurt, smoulder)

	for sinew in _sinews:
		_paint_one(sinew["mesh"], fed, hurt, smoulder)


func _paint_one(mesh: MeshInstance3D, fed: float, hurt: float, smoulder: float) -> void:
	mesh.set_instance_shader_parameter(&"fed", fed)
	mesh.set_instance_shader_parameter(&"hurt", hurt)
	mesh.set_instance_shader_parameter(&"smoulder", smoulder)


func sinew_count() -> int:
	return _sinews.size()


## How long the sinew furthest from its hinge is: the one that stretches the most.
func sinew_length() -> float:
	return _span(_sinews[_sinews.size() - 1])


## How thick that sinew is, against how it is made.
func sinew_width() -> float:
	return (_sinews[_sinews.size() - 1]["mesh"] as Node3D).basis.x.length()


func _span(sinew: Dictionary) -> float:
	return ((_jaw.transform * (sinew["low"] as Node3D).position) - (sinew["up"] as Node3D).position).length()


func _stretch() -> void:
	for sinew in _sinews:
		var from: Vector3 = (sinew["up"] as Node3D).position
		var to: Vector3 = _jaw.transform * (sinew["low"] as Node3D).position
		var way := to - from
		var long := maxf(way.length(), 0.001)
		var rest: float = sinew["rest"]
		var thin := sqrt(rest / long) if rest > 0.0 else 1.0
		var along := Basis.looking_at(way / long, Vector3.RIGHT)
		(sinew["mesh"] as Node3D).transform = Transform3D(Basis(along.x * thin, along.y * thin, along.z * long), from)
