class_name DistrictGround
extends Node3D
## A district's ground (the street and canal kit's plan, Task 3): each area
## of dressing.json's "ground" laid by Ground.gd in chunks on a world grid,
## so the camera can leave most of it out and no chunk weighs more than its
## share. Each chunk gets only the openings, inlays, covers, patches and
## footprints near it; the walking lines are drawn once per area, so the wear
## runs on across chunk edges.
##   {"chunk": m, "areas": [{"tile", "level", "rect": [x0, z0, x1, z1],
##     "openings": [rect], "covered": [polygon], "inlays": [polygon],
##     "patches": [rect], "footprints": [{"rect": rect, "roofed": bool}]}]}

## How far round a chunk a footprint still weathers it (Ground.BANK and its corners).
const REACH := 2.0


static func build(ground: Dictionary, seed: int) -> DistrictGround:
	var out := DistrictGround.new()
	out.name = "district_ground"
	var chunk: float = ground.get("chunk", 50.0)

	for a in ground["areas"].size():
		var area: Dictionary = ground["areas"][a]
		var rect := _rect(area["rect"])
		var openings: Array[Rect2] = []
		openings.assign(area.get("openings", []).map(_rect))
		var patches: Array[Rect2] = []
		patches.assign(area.get("patches", []).map(_rect))
		var inlays: Array = area.get("inlays", []).map(_polygon)
		var covered: Array = area.get("covered", []).map(_polygon)
		var footprints: Array[Dictionary] = []
		footprints.assign(area.get("footprints", []).map(func(f): return {"rect": _rect(f["rect"]),
			"roofed": f.get("roofed", false)}))
		var paths := Ground._paths(footprints, openings)
		var i0 := floori(rect.position.x / chunk)
		var j0 := floori(rect.position.y / chunk)

		for i in range(i0, ceili(rect.end.x / chunk - 1e-6)):
			for j in range(j0, ceili(rect.end.y / chunk - 1e-6)):
				var piece := rect.intersection(Rect2(i * chunk, j * chunk, chunk, chunk))

				if piece.get_area() < 1e-6:
					continue

				var near := piece.grow(REACH)
				var near_openings: Array[Rect2] = []
				near_openings.assign(openings.filter(func(o: Rect2): return o.intersects(near)))
				var near_patches: Array[Rect2] = []
				near_patches.assign(patches.filter(func(r: Rect2): return r.intersects(piece.grow(0.01))))
				var near_footprints: Array[Dictionary] = []
				near_footprints.assign(footprints.filter(func(f): return (f["rect"] as Rect2).grow(Ground.BANK).intersects(near)))
				var options := {"tile": StringName(area.get("tile", "ground_cobbles")), "level": float(area.get("level", 0.0)),
					"inlays": inlays.filter(func(p): return Ground._box(p).intersects(piece)),
					"covered": covered.filter(func(p): return Ground._box(p).intersects(piece)),
					"patches": near_patches,
					"paths": paths.filter(func(p): return _segment_box(p).grow(Ground.PATH).intersects(near))}
				var g := Ground.build(piece, near_openings, near_footprints, seed, options)
				g.name = "%s_%d_%d_%d" % [area.get("tile", "ground"), a, i, j]
				out.add_child(g)

	return out


static func _rect(r: Array) -> Rect2:
	return Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])


static func _polygon(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()

	for p in points:
		out.append(Vector2(p[0], p[1]))

	return out


static func _segment_box(segment: Array) -> Rect2:
	return Rect2(segment[0], Vector2.ZERO).expand(segment[1])
