extends Node3D
## The candle lane's crowd (maps/candle_lane.gd): shades coming and going, never the same twice. Each forms out of its
## mist where it comes in (the Pasaje beyond the mouth, the chapel's doorway, or somewhere along the way), walks its
## route and comes apart into smoke at a point of its own: thick across the mouth, now and then down the lane past her
## stall, hardly ever at the chapel's end. When the dark train passes, a surge pours in from the mouth, as from an
## emptied platform. Walked into, a shade comes apart at once.
## Its routes are in its parent's frame, on the floor.

const Silhouette := preload("res://scripts/Visual/Silhouette.gd")
## The walkers it is made of (the loops' sheet).
const WALKS := ["walk_coat", "walk_rebozo", "walk_carry", "walk_jacket"]
## How many at once, at most; how fast they go (m/s); how long one takes to form, and to come apart (s); how near
## someone may come before one comes apart, and how fast it does then (s).
const POOL := 14
const SPEED := Vector2(0.7, 0.95)
const FORM := 1.2
const GO := 1.4
const NEAR := 0.8
const SCATTER := 0.45
## A surge: how many, over how long (s).
const SURGE := Vector2(5, 4.0)

## The routes: [{name, points (PackedVector3Array), every (s: least, most, between one setting out and the next),
## keep (how much of it one walks before it may come apart: least, most), along (the chance one forms partway along
## it instead of at its start)}].
var routes: Array[Dictionary] = []
## Whoever may walk into them.
var walked_into_by: Node3D
## The shades walking: {shade, route, length, at (m along), end (m along, where it comes apart), speed, phase
## ("forming", "walking", "going"), scatter (walked into)}.
var walkers: Array[Dictionary] = []
## How many have set out on each route, and how many came apart walked into.
var started: Dictionary = {}
var scattered := 0

var _next: Dictionary = {}
var _queued: Array[float] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 17
	for route in routes:
		_next[route["name"]] = _rng.randf_range(0.0, float(route["every"].y) * 0.5)
		started[route["name"]] = 0


## A surge from the mouth (the dark train has emptied a platform): SURGE.x shades into the lane over SURGE.y s.
func surge() -> void:
	for k in int(SURGE.x):
		_queued.append(SURGE.y * k / SURGE.x)


## One set out on `route` (by name): forming at its start, or (by its `along` chance) partway along it. Routes keep
## to POOL between them; a surge (`forced`) may go over it, by SURGE's count.
func start(route_name: String, forced := false) -> Dictionary:
	if walkers.size() >= POOL + (int(SURGE.x) if forced else 0):
		return {}
	var route: Dictionary = {}
	for r in routes:
		if r["name"] == route_name:
			route = r
	if route.is_empty():
		return {}
	var shade: MeshInstance3D = Silhouette.make_loop(WALKS[_rng.randi() % WALKS.size()])
	if shade == null:
		return {}
	add_child(shade)
	shade.presence = 0.0
	shade.cycle = _rng.randf()
	var length := _length(route["points"])
	var from := length * _rng.randf_range(0.15, 0.6) if _rng.randf() < float(route.get("along", 0.0)) else 0.0
	var end := minf(length, from + length * _rng.randf_range(route["keep"].x, route["keep"].y))
	var walker := {"shade": shade, "route": route, "length": length, "at": from, "end": end,
		"speed": _rng.randf_range(SPEED.x, SPEED.y), "phase": "forming", "scatter": false}
	walkers.append(walker)
	started[route_name] += 1
	_place(walker, 0.0)
	return walker


func _process(delta: float) -> void:
	for route in routes:
		_next[route["name"]] -= delta
		if _next[route["name"]] <= 0.0:
			start(route["name"])
			_next[route["name"]] = _rng.randf_range(route["every"].x, route["every"].y)
	for k in range(_queued.size() - 1, -1, -1):
		_queued[k] -= delta
		if _queued[k] <= 0.0:
			_queued.remove_at(k)
			start("into_lane", true)
	for walker in walkers.duplicate():
		_advance(walker, delta)


func _advance(walker: Dictionary, delta: float) -> void:
	var shade: MeshInstance3D = walker["shade"]
	var near: bool = walked_into_by != null and is_instance_valid(walked_into_by) \
		and Vector2(walked_into_by.global_position.x - shade.global_position.x,
			walked_into_by.global_position.z - shade.global_position.z).length() < NEAR
	match walker["phase"]:
		"forming":
			shade.presence += delta / FORM
			if shade.presence >= 1.0:
				walker["phase"] = "walking"
		"walking":
			if walker["at"] >= walker["end"]:
				walker["phase"] = "going"
	if near and walker["phase"] != "going":
		walker["phase"] = "going"
		walker["scatter"] = true
		scattered += 1
	if walker["phase"] == "going":
		shade.presence -= delta / (SCATTER if walker["scatter"] else GO)
		if shade.presence <= 0.0:
			walkers.erase(walker)
			shade.queue_free()
			return
	_place(walker, delta)


## The walker moved on along its route by its pace this frame, its feet stepping with it, turned the way it goes.
func _place(walker: Dictionary, delta: float) -> void:
	var step: float = walker["speed"] * delta
	walker["at"] = minf(walker["at"] + step, walker["length"])
	var points: PackedVector3Array = walker["route"]["points"]
	var shade: MeshInstance3D = walker["shade"]
	var left: float = walker["at"]
	for i in points.size() - 1:
		var span := points[i].distance_to(points[i + 1])
		if left <= span or i == points.size() - 2:
			shade.position = points[i].lerp(points[i + 1], clampf(left / maxf(span, 0.001), 0.0, 1.0))
			shade.heading = (points[i + 1] - points[i]).normalized()
			break
		left -= span
	if step > 0.0:
		shade.walk(step)


func _length(points: PackedVector3Array) -> float:
	var length := 0.0
	for i in points.size() - 1:
		length += points[i].distance_to(points[i + 1])
	return length
