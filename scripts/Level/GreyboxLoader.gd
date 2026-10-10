class_name GreyboxLoader
extends Node3D
## A district's greybox (tools/level/greybox.py) brought into Godot: one
## plain-coloured mesh and one solid body per element of the plan (the
## ground, each sunken place, plot, underground space and route, the brink).
## The geometry and its overlap gate are Python's; this only loads it.

const KIND_COLOURS := {
	"ground": Color("#8f8a84"), "raised": Color("#a39d96"), "sunken": Color("#6d6f78"), "space": Color("#4c4658"),
	"route": Color("#c47a3a"), "brink": Color("#3a3434"),
}
## A plot's colour by its kit family (tools/level/plan_draw.py's, so the
## greybox reads like the plan sheets).
const FAMILY_COLOURS := {
	"house": Color8(172, 92, 74), "arcade": Color8(196, 150, 110), "cathedral": Color8(120, 112, 128),
	"sagrario": Color8(140, 120, 138), "palace": Color8(150, 70, 60), "pawnshop": Color8(110, 80, 120),
	"iturbide": Color8(160, 110, 90), "inquisition": Color8(80, 60, 70), "evangelistas": Color8(190, 160, 120),
	"church": Color8(130, 120, 112), "deco_tower": Color8(70, 130, 110), "market_hall": Color8(90, 120, 120),
	"stall": Color8(200, 170, 90), "town_hall": Color8(170, 120, 100),
}
const OTHER_FAMILY := Color8(150, 150, 150)
## A ladder's climbable box (m): across the wall, and out from it.
const LADDER_WIDTH := 1.2
const LADDER_DEPTH := 0.7


## The greybox's meshes and bodies, from greybox.json's data; `skip` names
## the elements a district's dressing has taken over.
static func build(greybox: Dictionary, skip: Array = []) -> GreyboxLoader:
	var out := GreyboxLoader.new()
	out.name = "greybox"
	var materials := {}

	for m in greybox["meshes"]:
		if m["name"] in skip:
			continue

		var colour: Color = FAMILY_COLOURS.get(m.get("family", ""), OTHER_FAMILY) if m["kind"] == "plot" \
			else KIND_COLOURS.get(m["kind"], OTHER_FAMILY)

		if not materials.has(colour):
			var material := StandardMaterial3D.new()
			material.albedo_color = colour
			material.roughness = 0.95
			materials[colour] = material

		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var triangles := PackedVector3Array()

		for f in m["faces"]:
			var points: Array = f["points"]
			var normal := Vector3(f["normal"][0], f["normal"][1], f["normal"][2])

			for i in range(1, points.size() - 1):
				# Faces run counter-clockwise round their normal; Godot draws
				# the clockwise side as the front.
				for q in [points[0], points[i + 1], points[i]]:
					var v := Vector3(q[0], q[1], q[2])
					tool.set_normal(normal)
					tool.add_vertex(v)
					triangles.append(v)

		if triangles.is_empty():
			continue

		var mesh := MeshInstance3D.new()
		mesh.name = String(m["name"])
		mesh.mesh = tool.commit()
		mesh.material_override = materials[colour]
		mesh.set_meta("kind", m["kind"])
		mesh.set_meta("route", m.get("route", ""))
		out.add_child(mesh)

		# A climb is a ladder to take hold of, its board only to be seen.
		if m.get("route", "") == "climb":
			out.add_child(_ladder(m["points"]))
			continue

		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var concave := ConcavePolygonShape3D.new()
		concave.backface_collision = true
		concave.set_faces(triangles)
		shape.shape = concave
		body.add_child(shape)
		mesh.add_child(body)

	return out


## A ladder (ClimbVolume) up the wall a climb crosses: from its lower end
## to its upper, standing out from the wall on the side it is climbed from,
## its local -Z into the wall.
static func _ladder(points: Array) -> ClimbVolume:
	var a := Vector3(points[0][0], points[0][1], points[0][2])
	var b := Vector3(points[-1][0], points[-1][1], points[-1][2])
	var lower := a if a.y <= b.y else b
	var upper := b if a.y <= b.y else a
	var into := Vector3(upper.x - lower.x, 0, upper.z - lower.z).normalized()
	var wall := Vector3((a.x + b.x) * 0.5, 0, (a.z + b.z) * 0.5)
	var volume := ClimbVolume.new()
	volume.name = "ladder"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LADDER_WIDTH, upper.y - lower.y, LADDER_DEPTH)
	shape.shape = box
	volume.add_child(shape)
	volume.transform = Transform3D(Basis.looking_at(into, Vector3.UP),
		wall - into * LADDER_DEPTH * 0.5 + Vector3(0, (lower.y + upper.y) * 0.5, 0))
	return volume
