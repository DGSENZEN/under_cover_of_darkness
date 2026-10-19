class_name BookFiller
extends RefCounted
## Fills a room's shelves with books (docs/superpowers/specs/2026-10-17-librarian-shop-design.md): along every
## board, books standing spine out, now a pair of one set, now a gap where one is out, now a stack lying or one fallen
## on its side, and at a board's end often one leaning on the upright; never three alike in a row, each just above
## its board, none touching. One MultiMesh per kind of book for the whole room.
##
## A spot (one board's face) is a Dictionary: "xform" (its case's Transform3D, world), "x0", "x1" (its run along
## the case's x), "top" (the board's top, y), "z0", "z1" (its depth, the case's z), "facing" (1 if its books' spines
## face the case's +z, -1 its -z), "head" (how tall a book it takes), "keep" (Array of Vector2, runs of x left empty).
## A kind of book (a Mesh) stands in its own frame: its feet at y = 0, its spine at z = 0 facing +z, its thickness
## across x about 0; a kind wider than it is tall lies (a stack): its middle at the origin, its foot at y = 0.

## How far above its board each stands (m); the gap between neighbours; how far back from the board's edge.
const LIFT := 0.002
const GAP := Vector2(0.002, 0.006)
const SET_BACK := Vector2(0.004, 0.02)
## How likely the next is of the same set as the last (a pair), a gap where one is out, a stack.
const PAIR := 0.3
const OUT := 0.07
const OUT_GAP := Vector2(0.03, 0.12)
const STACK := 0.05
## How likely one fallen on its side (spine still out); a board's first or last leaning on its upright, and how far.
const FALLEN := 0.03
const LEAN_END := 0.55
const LEAN_DEG := Vector2(5.0, 12.0)
## How much of the board left when its last is chosen to lean (m).
const LEAN_ROOM := 0.22
## Room left over a book under the board above.
const HEADROOM := 0.008

## Every book placed: {"spot": its spot's index, "box": its AABB in its case's frame, "look": its kind's index,
## "pose": "stand", "lean", "lie" (fallen) or "stack"}.
var layout: Array = []


func fill(spots: Array, meshes: Array, material: Material, seed: int) -> Array[MultiMeshInstance3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var placed: Array = []
	for k in meshes.size():
		placed.append([])
	layout.clear()

	for s in spots.size():
		_board(s, spots[s], meshes, rng, placed)

	var draws: Array[MultiMeshInstance3D] = []
	for k in meshes.size():
		if placed[k].is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = meshes[k]
		multi.instance_count = placed[k].size()
		for i in placed[k].size():
			multi.set_instance_transform(i, placed[k][i])
		var draw := MultiMeshInstance3D.new()
		draw.name = "books_%d" % k
		draw.multimesh = multi
		draw.material_override = material
		# (Hundreds of books cast into every shadowed light's six faces: a fifth of the frame. The cases' own
		# shadows already darken their insides.)
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draws.append(draw)

	return draws


func _board(s: int, spot: Dictionary, meshes: Array, rng: RandomNumberGenerator, placed: Array) -> void:
	var keep: Array = spot.get("keep", [])
	var x: float = spot["x0"] + rng.randf_range(0.004, 0.03)
	var last := [-1, -1]

	# Its first, now and then, leaning on the left upright.
	if rng.randf() < LEAN_END * 0.5:
		var k := _pick(meshes, spot, rng, last, false)
		if k >= 0:
			var local := _posed(meshes[k], spot, "lean", -rng.randf_range(LEAN_DEG.x, LEAN_DEG.y), rng)
			local = _at_x(local, meshes[k], spot["x0"] + 0.001)
			var box: AABB = local * (meshes[k] as Mesh).get_aabb()
			if _fits(box, spot, keep):
				_put(s, k, local, box, "lean", spot, placed)
				last = [k, -1]
				x = box.end.x + rng.randf_range(GAP.x, GAP.y) + 0.01

	var ending := rng.randf() < LEAN_END

	while true:
		# Near the board's end, its last leaning on the upright (when it is to).
		if ending and spot["x1"] - x < LEAN_ROOM:
			ending = false
			var j := _pick(meshes, spot, rng, last, false)
			if j >= 0:
				var lean := _posed(meshes[j], spot, "lean", rng.randf_range(LEAN_DEG.x, LEAN_DEG.y), rng)
				var lean_box: AABB = lean * (meshes[j] as Mesh).get_aabb()
				lean = _at_x(lean, meshes[j], spot["x1"] - 0.001 - lean_box.size.x)
				lean_box = lean * (meshes[j] as Mesh).get_aabb()
				if lean_box.position.x >= x and _fits(lean_box, spot, keep):
					_put(s, j, lean, lean_box, "lean", spot, placed)
					return

		var k := _pick(meshes, spot, rng, last, true)
		if k < 0:
			return
		var mesh_box: AABB = (meshes[k] as Mesh).get_aabb()
		var pose := "stack" if mesh_box.size.y < mesh_box.size.x else ("lie" if rng.randf() < FALLEN else "stand")
		var local := _posed(meshes[k], spot, pose, 0.0, rng)
		local = _at_x(local, meshes[k], x)
		var box: AABB = local * mesh_box

		# Into a run kept empty: on past it. Off the board's end: done.
		var past := -INF
		for run: Vector2 in keep:
			if box.end.x > run.x and box.position.x < run.y:
				past = maxf(past, run.y)
		if past > -INF:
			x = past + rng.randf_range(0.004, 0.02)
			continue
		if box.end.x > spot["x1"] - 0.004 or not _fits(box, spot, keep):
			return

		_put(s, k, local, box, pose, spot, placed)
		last = [k, last[0]]
		x = box.end.x + rng.randf_range(GAP.x, GAP.y)
		if rng.randf() < OUT:
			x += rng.randf_range(OUT_GAP.x, OUT_GAP.y)


## A kind for the next place on the board: one that fits under the board above and within its depth, not a third of
## the last two alike; a pair with the last now and then; a stack only now and then (never if `stacks` is false).
func _pick(meshes: Array, spot: Dictionary, rng: RandomNumberGenerator, last: Array, stacks: bool) -> int:
	var depth: float = spot["z1"] - spot["z0"]
	var fits := []
	for k in meshes.size():
		var box: AABB = (meshes[k] as Mesh).get_aabb()
		var lying := box.size.y < box.size.x
		if box.size.y + LIFT + HEADROOM > spot["head"] or (box.size.z if lying else box.size.z + SET_BACK.y) > depth:
			continue
		if last[0] == k and last[1] == k:
			continue
		if lying and (not stacks or rng.randf() > STACK):
			continue
		fits.append(k)
	if fits.is_empty():
		return -1
	return last[0] if last[0] in fits and rng.randf() < PAIR else fits[rng.randi() % fits.size()]


## A kind's place on the board in its case's frame (x left at 0): standing spine out, set back from the board's
## edge; leaning `lean_deg` (its top toward +x for positive) on the edge it rests on; fallen on its side; a stack in
## the board's middle depth. Its lowest point LIFT above the board.
func _posed(mesh: Mesh, spot: Dictionary, pose: String, lean_deg: float, rng: RandomNumberGenerator) -> Transform3D:
	var facing: int = spot.get("facing", 1)
	var front: float = spot["z1"] if facing > 0 else spot["z0"]
	var face := Basis() if facing > 0 else Basis(Vector3.UP, PI)
	var local: Transform3D
	match pose:
		"stack":
			local = Transform3D(Basis(), Vector3(0.0, 0.0, (spot["z0"] + spot["z1"]) / 2.0))
		"lie":
			local = Transform3D(Basis(Vector3.BACK, -PI / 2.0) * face, Vector3(0.0, 0.0, front - facing * rng.randf_range(SET_BACK.x, SET_BACK.y)))
		"lean":
			local = Transform3D(Basis(Vector3.BACK, -deg_to_rad(lean_deg)) * face, Vector3(0.0, 0.0, front - facing * rng.randf_range(SET_BACK.x, SET_BACK.y)))
		_:
			local = Transform3D(face, Vector3(0.0, 0.0, front - facing * rng.randf_range(SET_BACK.x, SET_BACK.y)))
	var box: AABB = local * mesh.get_aabb()
	local.origin.y += spot["top"] + LIFT - box.position.y
	return local


## `local` moved along x so its box's left side is at `x`.
func _at_x(local: Transform3D, mesh: Mesh, x: float) -> Transform3D:
	var box: AABB = local * mesh.get_aabb()
	local.origin.x += x - box.position.x
	return local


## Within the board's run, under the board above, clear of the runs kept empty.
func _fits(box: AABB, spot: Dictionary, keep: Array) -> bool:
	if box.position.x < spot["x0"] or box.end.x > spot["x1"] or box.end.y > spot["top"] + spot["head"]:
		return false
	for run: Vector2 in keep:
		if box.end.x > run.x and box.position.x < run.y:
			return false
	return true


func _put(s: int, k: int, local: Transform3D, box: AABB, pose: String, spot: Dictionary, placed: Array) -> void:
	placed[k].append(spot["xform"] * local)
	layout.append({"spot": s, "box": box, "look": k, "pose": pose})
