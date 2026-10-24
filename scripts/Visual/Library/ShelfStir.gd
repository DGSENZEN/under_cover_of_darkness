extends Node3D
## The shelves rearrange themselves while unwatched (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "a
## board changes only while it is outside the view or hidden behind something, and never within a few seconds of
## being seen ... Chronology's books reorder themselves by height, as if keeping their own dates"). Every twenty to
## forty seconds one board somewhere no one is looking changes: chronology's books stand again tallest first; elsewhere
## a pulled-out book is pushed home, a gap is closed by its neighbours, a leaning book stands up, a stack is squared
## differently. A change is made only whole and only if the board is still laid out as the filler lays it (within its
## uprights, each just above it, none touching, its kept runs clear); the shelf books' MultiMesh instances move with it.
## Not knowing who is looking counts as being looked at.

## How long a board must have gone unseen before it may change (s); how often the stirs come (s); how often it looks
## at which boards are seen (s); how soon it tries again when nothing could change.
const UNSEEN := 5.0
const EVERY := Vector2(20.0, 40.0)
const LOOK := 0.1
const RETRY := 2.0
## A book's lift above its board; the gap left between books moved together.
const LIFT := 0.002
const GAP := 0.003

## Who is looking (a Camera3D); else the drawing camera.
var watcher: Node3D
## How many changes it has made.
var changes := 0

var _lab: Node3D
var _seen := PackedFloat32Array()
var _frames: Array[Transform3D] = []
var _clock := 0.0
var _look_in := 0.0
var _next := 0.0
var _rng := RandomNumberGenerator.new()


func build(lab: Node3D) -> void:
	name = "stir"
	_lab = lab
	_rng.seed = 707
	for spot: Dictionary in lab.book_spots:
		_frames.append(lab.global_transform.affine_inverse() * (spot["xform"] as Transform3D))
	_seen.resize(lab.book_spots.size())
	_seen.fill(0.0)
	_next = next_gap()


## The wait before the next stir.
func next_gap() -> float:
	return _rng.randf_range(EVERY.x, EVERY.y)


func _process(delta: float) -> void:
	_clock += delta
	_look_in -= delta
	var eye := _eye()
	if _look_in <= 0.0:
		_look_in = LOOK
		for i in _seen.size():
			if not hidden(i, eye):
				_seen[i] = _clock
	_next -= delta
	if _next > 0.0:
		return
	var order := range(_seen.size())
	for i in range(order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	for i: int in order:
		if try_board(i):
			_next = next_gap()
			return
	_next = RETRY


## Board `i` changes now if it may (unseen long enough, still hidden) and if a change of it is valid.
func try_board(i: int) -> bool:
	var eye := _eye()
	if not hidden(i, eye):
		_seen[i] = _clock
		return false
	if _clock - _seen[i] < UNSEEN:
		return false
	var moves := _change(i)
	if moves.is_empty():
		return false
	for move: Array in moves:
		var entry: Dictionary = move[0]
		entry["local"] = move[1]
		entry["box"] = move[2]
		entry["pose"] = move[3]
		var draw: MultiMeshInstance3D = _lab.book_draws[entry["draw"]]
		draw.multimesh.set_instance_transform(entry["instance"], _frames[i] * (move[1] as Transform3D))
	changes += 1
	return true


## Whether board `i` is out of `eye`'s sight: outside its view, or behind something on every line to it. No eye, or
## no camera to judge by, counts as seen.
func hidden(i: int, eye: Node3D) -> bool:
	var camera := eye as Camera3D
	if camera == null or not is_instance_valid(camera):
		return false
	var spot: Dictionary = _lab.book_spots[i]
	var frame: Transform3D = spot["xform"]
	var box := AABB(Vector3(spot["x0"], spot["top"], spot["z0"]), Vector3(spot["x1"] - spot["x0"], spot["head"], spot["z1"] - spot["z0"]))
	var corners: Array[Vector3] = []
	for c in 8:
		corners.append(frame * box.get_endpoint(c))
	for plane: Plane in camera.get_frustum():
		if corners.all(func(p): return plane.is_point_over(p)):
			return true
	# In view: hidden only if every line from the eye to the board's open face is blocked.
	var facing: int = spot.get("facing", 1)
	var face: float = spot["z1"] if facing > 0 else spot["z0"]
	var points: Array[Vector3] = []
	for x in [lerpf(spot["x0"], spot["x1"], 0.5), spot["x0"] + 0.04, spot["x1"] - 0.04]:
		for y in [spot["top"] + 0.06, spot["top"] + spot["head"] * 0.7]:
			points.append(frame * Vector3(x, y, face))
	var space := get_world_3d().direct_space_state
	for p in points:
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position, p)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or (hit.position as Vector3).distance_to(p) < 0.03:
			return false
	return true


func _eye() -> Node3D:
	if is_instance_valid(watcher):
		return watcher
	return get_viewport().get_camera_3d() if get_viewport() != null else null


# The changes

## A valid change of board `i`: [[entry, its new local, its new box, its new pose], ...], or none.
func _change(i: int) -> Array:
	var spot: Dictionary = _lab.book_spots[i]
	var entries: Array = _lab.book_layout.filter(func(e): return e["spot"] == i)
	entries.sort_custom(func(p, q): return p["box"].position.x < q["box"].position.x)
	if entries.is_empty():
		return []
	var tries: Array[Callable] = [_push_home, _close_gap, _stand_up, _square_stack]
	if spot["section"] == "chronology":
		tries.push_front(_by_height)
	else:
		for k in range(tries.size() - 1, 0, -1):
			var j := _rng.randi_range(0, k)
			var swap: Callable = tries[k]
			tries[k] = tries[j]
			tries[j] = swap
	for attempt: Callable in tries:
		var moves: Array = attempt.call(spot, entries)
		if not moves.is_empty() and _valid(spot, entries, moves):
			return moves
	return []


func _aabb(entry: Dictionary) -> AABB:
	return (_lab.book_draws[entry["draw"]] as MultiMeshInstance3D).multimesh.mesh.get_aabb()


## Chronology: its standing books re-laid tallest first, left to right, round whatever lies, leans or is kept clear.
func _by_height(spot: Dictionary, entries: Array) -> Array:
	var standing := entries.filter(func(e): return e["pose"] == "stand" or e["pose"] == "pulled")
	if standing.size() < 2:
		return []
	var tallest := standing.duplicate()
	tallest.sort_custom(func(p, q): return p["box"].size.y > q["box"].size.y)
	if tallest.map(func(e): return e["box"].position.x) == standing.map(func(e): return e["box"].position.x) \
			and tallest == standing:
		return []
	# The free runs of the board: its whole run less what does not move and what is kept clear.
	var blocked: Array = spot["keep"].duplicate()
	for e: Dictionary in entries:
		if not standing.has(e):
			blocked.append(Vector2(e["box"].position.x - GAP, e["box"].end.x + GAP))
	blocked.sort_custom(func(p, q): return p.x < q.x)
	var runs: Array = []
	var from: float = spot["x0"] + 0.004
	for b: Vector2 in blocked:
		if b.x > from:
			runs.append(Vector2(from, b.x))
		from = maxf(from, b.y)
	runs.append(Vector2(from, spot["x1"] - 0.004))
	var moves := []
	var run := 0
	var at: float = runs[0].x
	for e: Dictionary in tallest:
		var w: float = e["box"].size.x
		while run < runs.size() and at + w > runs[run].y:
			run += 1
			if run < runs.size():
				at = runs[run].x
		if run >= runs.size():
			return []
		var local: Transform3D = e["local"]
		local.origin.x += at - e["box"].position.x
		moves.append([e, local, local * _aabb(e), e["pose"]])
		at += w + GAP
	return moves


## A pulled-out book pushed home, back from the board's edge.
func _push_home(spot: Dictionary, entries: Array) -> Array:
	var pulled := entries.filter(func(e): return e["pose"] == "pulled")
	if pulled.is_empty():
		return []
	var e: Dictionary = pulled[_rng.randi_range(0, pulled.size() - 1)]
	var facing: int = spot.get("facing", 1)
	var front: float = spot["z1"] if facing > 0 else spot["z0"]
	var local: Transform3D = e["local"]
	local.origin.z = front - facing * 0.012
	return [[e, local, local * _aabb(e), "stand"]]


## The widest gap along the board closed: the books after it moved up against those before.
func _close_gap(spot: Dictionary, entries: Array) -> Array:
	var best := -1
	var widest := 0.03
	for k in range(1, entries.size()):
		var gap: float = entries[k]["box"].position.x - entries[k - 1]["box"].end.x
		var kept := (spot["keep"] as Array).any(func(r): return r.x < entries[k]["box"].position.x and r.y > entries[k - 1]["box"].end.x)
		if gap > widest and not kept:
			widest = gap
			best = k
	if best < 0:
		return []
	var shift := -(widest - GAP)
	var moves := []
	for k in range(best, entries.size()):
		if k > best and entries[k]["box"].position.x - entries[k - 1]["box"].end.x > 0.03:
			break
		var e: Dictionary = entries[k]
		var local: Transform3D = e["local"]
		local.origin.x += shift
		moves.append([e, local, local * _aabb(e), e["pose"]])
	return moves


## A book leaning on its upright stood up straight where it was.
func _stand_up(spot: Dictionary, entries: Array) -> Array:
	var leaning := entries.filter(func(e): return e["pose"] == "lean")
	if leaning.is_empty():
		return []
	var e: Dictionary = leaning[0]
	var facing: int = spot.get("facing", 1)
	var face := Basis() if facing > 0 else Basis(Vector3.UP, PI)
	var local := Transform3D(face, Vector3(0.0, 0.0, (e["local"] as Transform3D).origin.z))
	var box := local * _aabb(e)
	local.origin.y += spot["top"] + LIFT - box.position.y
	var at_left: bool = e["box"].position.x - spot["x0"] < spot["x1"] - e["box"].end.x
	box = local * _aabb(e)
	local.origin.x += (e["box"].position.x - box.position.x) if at_left else (e["box"].end.x - box.end.x)
	return [[e, local, local * _aabb(e), "stand"]]


## A stack squared up differently, turned a little about its middle.
func _square_stack(spot: Dictionary, entries: Array) -> Array:
	var stacks := entries.filter(func(e): return e["pose"] == "stack")
	if stacks.is_empty():
		return []
	var e: Dictionary = stacks[0]
	var middle: Vector3 = e["box"].get_center()
	var turn := Basis(Vector3.UP, _rng.randf_range(0.06, 0.16) * (1.0 if _rng.randf() < 0.5 else -1.0))
	var old: Transform3D = e["local"]
	var local := Transform3D(turn * old.basis, middle + turn * (old.origin - middle))
	return [[e, local, local * _aabb(e), "stack"]]


## The board as it would be after `moves`, laid out as the filler lays it.
func _valid(spot: Dictionary, entries: Array, moves: Array) -> bool:
	var boxes := {}
	for e: Dictionary in entries:
		boxes[e] = e["box"]
	for m: Array in moves:
		boxes[m[0]] = m[2]
	var sorted := boxes.values()
	sorted.sort_custom(func(p, q): return p.position.x < q.position.x)
	for k in sorted.size():
		var box: AABB = sorted[k]
		if box.position.x < spot["x0"] - 0.0001 or box.end.x > spot["x1"] + 0.0001:
			return false
		var lift: float = box.position.y - spot["top"]
		if lift < 0.001 or lift > 0.004 or box.end.y > spot["top"] + spot["head"]:
			return false
		for run: Vector2 in spot["keep"]:
			if box.end.x > run.x and box.position.x < run.y:
				return false
		if k > 0 and box.position.x < sorted[k - 1].end.x + 0.001:
			return false
	return true
