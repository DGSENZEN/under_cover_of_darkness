class_name BookFiller
extends RefCounted
## Fills a room's shelves with books (docs/superpowers/specs/2026-10-17-librarian-shop-design.md): along every
## board, books standing spine out, now a pair of one set, now a gap where one is out, now a stack lying; never three
## alike in a row, each just above its board, none touching. One MultiMesh per kind of book for the whole room.
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
## Room left over a book under the board above.
const HEADROOM := 0.008

## Every book placed: {"spot": its spot's index, "box": its AABB in its case's frame, "look": its kind's index}.
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
		draws.append(draw)

	return draws


func _board(s: int, spot: Dictionary, meshes: Array, rng: RandomNumberGenerator, placed: Array) -> void:
	var facing: int = spot.get("facing", 1)
	var depth: float = spot["z1"] - spot["z0"]
	var front: float = spot["z1"] if facing > 0 else spot["z0"]
	var keep: Array = spot.get("keep", [])
	var x: float = spot["x0"] + rng.randf_range(0.004, 0.03)
	var last := [-1, -1]

	while true:
		var fits := []
		for k in meshes.size():
			var box: AABB = (meshes[k] as Mesh).get_aabb()
			var lying := box.size.y < box.size.x
			if box.size.y + LIFT + HEADROOM > spot["head"] or (box.size.z if lying else box.size.z + SET_BACK.y) > depth:
				continue
			if last[0] == k and last[1] == k:
				continue
			if lying and rng.randf() > STACK:
				continue
			fits.append(k)
		if fits.is_empty():
			return

		var k: int = last[0] if last[0] in fits and rng.randf() < PAIR else fits[rng.randi() % fits.size()]
		var mesh_box: AABB = (meshes[k] as Mesh).get_aabb()
		var local: Transform3D
		var lying := mesh_box.size.y < mesh_box.size.x
		if lying:
			local = Transform3D(Basis(), Vector3(0.0, spot["top"] + LIFT, (spot["z0"] + spot["z1"]) / 2.0))
		else:
			var back := rng.randf_range(SET_BACK.x, SET_BACK.y)
			local = Transform3D(Basis() if facing > 0 else Basis(Vector3.UP, PI), Vector3(0.0, spot["top"] + LIFT, front - facing * back))
		var box: AABB = local * mesh_box
		local.origin.x += x - box.position.x
		box = local * mesh_box

		# Into a run kept empty: on past it. Off the board's end: done.
		var past := -INF
		for run: Vector2 in keep:
			if box.end.x > run.x and box.position.x < run.y:
				past = maxf(past, run.y)
		if past > -INF:
			x = past + rng.randf_range(0.004, 0.02)
			continue
		if box.end.x > spot["x1"] - 0.004:
			return

		placed[k].append(spot["xform"] * local)
		layout.append({"spot": s, "box": box, "look": k})
		last = [k, last[0]]
		x = box.end.x + rng.randf_range(GAP.x, GAP.y)
		if rng.randf() < OUT:
			x += rng.randf_range(OUT_GAP.x, OUT_GAP.y)
