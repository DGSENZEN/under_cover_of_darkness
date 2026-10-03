extends Node
## Camera atmosphere zones: smallest containing transformed box wins; outside uses the default grade.
## Eases shadow/mid/high colours, saturation, fog multiplier, and fog colour into the current look.
## Applies colour correction to the environment; Night combines zone fog with weather, or this node applies fog directly.

const GRADES := {
	"outside": {"shadow": Color(0.006, 0.02, 0.05), "mid": Color(0.4, 0.5, 0.6), "high": Color(0.92, 0.97, 1.0), "saturation": 0.92, "fog_color": Color(0.55, 0.62, 0.78)},
	"indoors": {"shadow": Color(0.04, 0.024, 0.012), "mid": Color(0.56, 0.44, 0.3), "high": Color(1.0, 0.93, 0.78), "saturation": 1.05, "fog_color": Color(0.62, 0.48, 0.32)},
	"chapel": {"shadow": Color(0.045, 0.014, 0.012), "mid": Color(0.58, 0.32, 0.22), "high": Color(1.0, 0.86, 0.6), "saturation": 1.15, "fog_color": Color(0.62, 0.34, 0.22)},
	"cellar": {"shadow": Color(0.008, 0.024, 0.012), "mid": Color(0.34, 0.42, 0.3), "high": Color(0.84, 0.94, 0.76), "saturation": 0.8, "fog_color": Color(0.32, 0.4, 0.3)},
	"hearth": {"shadow": Color(0.05, 0.022, 0.008), "mid": Color(0.64, 0.42, 0.24), "high": Color(1.0, 0.88, 0.66), "saturation": 1.1, "fog_color": Color(0.72, 0.44, 0.24)},
}
const DEFAULT := "outside"
## A new zone is eased in over this long (s).
const EASE := 1.0

var _zones: Array = []
var _now := {}
var _gradient := Gradient.new()
var _lut := GradientTexture1D.new()
var _environment: Environment
var _fog_base := -1.0
var current := DEFAULT


func _ready() -> void:
	_now = (GRADES[DEFAULT] as Dictionary).duplicate()
	_now["fog"] = 1.0
	_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_gradient.colors = PackedColorArray([_now["shadow"], _now["mid"], _now["high"]])
	_lut.gradient = _gradient
	_lut.width = 256


## Adds a transformed box centred at at.origin, with size in metres and fog as a multiplier.
## Unknown grade colours fall back to outside; fog_color is a Color string or empty for grade colour.
func add_zone(zone_name: String, at: Transform3D, size: Vector3, grade: String, fog: float, fog_color: String) -> void:
	var entry := (GRADES.get(grade, GRADES[DEFAULT]) as Dictionary).duplicate()
	entry["fog"] = fog

	if fog_color != "":
		entry["fog_color"] = Color(fog_color)

	_zones.append({"name": zone_name, "grade": grade, "inverse": at.affine_inverse(), "half": size * 0.5,
		"volume": size.x * size.y * size.z, "look": entry})


## The zone `point` is in (its name, "" for none).
func zone_at(point: Vector3) -> String:
	var found := _find(point)
	return found["name"] if not found.is_empty() else ""


## The grade at `point`.
func grade_at(point: Vector3) -> String:
	var found := _find(point)
	return found["grade"] if not found.is_empty() else DEFAULT


## Returns the live look Dictionary: shadow/mid/high/fog_color (Color), saturation/fog (float).
## This is shared mutable state; treat it as read-only or duplicate it before edits.
func look() -> Dictionary:
	return _now


func _find(point: Vector3) -> Dictionary:
	var best := {}

	for zone in _zones:
		var local: Vector3 = (zone["inverse"] as Transform3D) * point
		var half: Vector3 = zone["half"]

		if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
			if best.is_empty() or float(zone["volume"]) < float(best["volume"]):
				best = zone

	return best


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()

	if camera == null:
		return

	var found := _find(camera.global_position)
	current = found["grade"] if not found.is_empty() else DEFAULT
	var wanted: Dictionary = found["look"] if not found.is_empty() else _default_look()
	var k := clampf(delta / EASE, 0.0, 1.0)

	for key in ["shadow", "mid", "high", "fog_color"]:
		_now[key] = (_now[key] as Color).lerp(wanted[key], k)

	for key in ["saturation", "fog"]:
		_now[key] = lerpf(float(_now[key]), float(wanted[key]), k)

	_apply()


func _default_look() -> Dictionary:
	var look := (GRADES[DEFAULT] as Dictionary).duplicate()
	look["fog"] = 1.0
	return look


func _apply() -> void:
	if _environment == null:
		_environment = _find_environment()

		if _environment == null:
			return

	_gradient.set_color(0, _now["shadow"])
	_gradient.set_color(1, _now["mid"])
	_gradient.set_color(2, _now["high"])
	_environment.adjustment_enabled = true
	_environment.adjustment_color_correction = _lut
	_environment.adjustment_saturation = float(_now["saturation"])
	var night := get_tree().get_first_node_in_group(&"night")

	if night != null and &"zone_fog" in night:
		night.zone_fog = float(_now["fog"])
		night.zone_fog_color = _now["fog_color"]
	else:
		if _fog_base < 0.0:
			_fog_base = _environment.volumetric_fog_density

		_environment.volumetric_fog_density = _fog_base * float(_now["fog"])
		_environment.volumetric_fog_albedo = _now["fog_color"]


func _find_environment() -> Environment:
	var night := get_tree().get_first_node_in_group(&"night")

	if night != null and night.get("environment") != null:
		return night.environment

	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		return (node as WorldEnvironment).environment

	return null
