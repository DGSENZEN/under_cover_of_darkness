extends Node3D
## The tesla arc (scripts/Visual/TeslaArc.gd; docs/superpowers/plans/2026-10-31-station-machinery.md Task 3): headless
## with --fixed-fps 60:
##   Godot --headless --fixed-fps 60 --path . res://tests/tesla_arc_test.tscn

const TeslaArcScript := preload("res://scripts/Visual/TeslaArc.gd")

var results: Array[String] = []
var failures := 0


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var eye := Camera3D.new()
	add_child(eye)
	eye.position = Vector3(0.0, 1.0, 6.0)
	eye.current = true
	var leap := _arc(PackedVector3Array([Vector3(-2.0, 1.0, 0.0), Vector3(2.0, 1.5, 0.0)]), false, 7)
	var run := PackedVector3Array([Vector3(-6.0, 3.0, 0.0), Vector3(0.0, 3.2, 0.0), Vector3(6.0, 3.0, 1.0)])
	var ride := _arc(run, true, 11)
	await get_tree().process_frame

	# T1: a leap starts and ends at its points; every inner point within 1.5 jag of the line between them.
	var shape: PackedVector3Array = leap.shape_at(0.37)
	var a: Vector3 = leap.points[0]
	var b: Vector3 = leap.points[1]
	var stray := 0.0
	for p in shape:
		stray = maxf(stray, (Geometry3D.get_closest_point_to_segment(p, a, b) - p).length())
	_check("T1 a leap spans its points, its jags within reach", shape.size() > 8 and shape[0].distance_to(a) <= 0.01
		and shape[shape.size() - 1].distance_to(b) <= 0.01 and stray <= leap.jag * 1.5,
		"%d points, ends %.3f %.3f, stray %.3f" % [shape.size(), shape[0].distance_to(a),
			shape[shape.size() - 1].distance_to(b), stray])

	# T2: it changes from step to step.
	_check("T2 it crackles: its shape changes", leap.shape_at(0.0) != leap.shape_at(0.2), "")

	# T3: its light flickers within its energy, never dead for long.
	var energies := []
	for i in 180:
		await get_tree().process_frame
		energies.append(leap.light.light_energy)
	var mean: float = energies.reduce(func(s, e): return s + e, 0.0) / energies.size()
	_check("T3 its light flickers within its energy", energies.min() >= 0.0
		and energies.max() <= leap.light_energy * 1.5 and mean >= 0.3 * leap.light_energy
		and energies.max() - energies.min() > 0.1 * leap.light_energy,
		"%.2f…%.2f, mean %.2f of %.2f" % [energies.min(), energies.max(), mean, leap.light_energy])

	# T4: a ride travels along its run, staying on it.
	var along := func(p: Vector3) -> float:
		var best := INF
		var at := 0.0
		var walked := 0.0
		for k in run.size() - 1:
			var q := Geometry3D.get_closest_point_to_segment(p, run[k], run[k + 1])
			if q.distance_to(p) < best:
				best = q.distance_to(p)
				at = walked + q.distance_to(run[k])
			walked += run[k].distance_to(run[k + 1])
		return at
	var c0: Vector3 = ride.centre_at(1.0)
	var c1: Vector3 = ride.centre_at(1.4)
	var off := 0.0
	for p in ride.shape_at(1.2):
		var nearest := INF
		for k in run.size() - 1:
			nearest = minf(nearest, (Geometry3D.get_closest_point_to_segment(p, run[k], run[k + 1]) - p).length())
		off = maxf(off, nearest)
	_check("T4 a ride travels along its run", along.call(c1) > along.call(c0) and off <= ride.jag * 1.5,
		"along %.2f → %.2f, off %.3f" % [along.call(c0), along.call(c1), off])

	# T5: drawn uninterpolated (it is rebuilt between ticks).
	_check("T5 uninterpolated", leap.mesh_instance.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF
		and leap.light.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF
		and leap.sparks.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "")

	# T6: seeded: the same seed the same shape, another seed another.
	var twin := _arc(leap.points, false, 7)
	var other := _arc(leap.points, false, 8)
	await get_tree().process_frame
	_check("T6 seeded", twin.shape_at(1.3) == leap.shape_at(1.3) and other.shape_at(1.3) != leap.shape_at(1.3), "")

	# T7: our own shader, no texture bound (no downloaded VFX).
	var look := leap.mesh_instance.material_override as ShaderMaterial
	var samplers := []
	if look != null:
		samplers = look.shader.get_shader_uniform_list().filter(func(u): return u["type"] == TYPE_OBJECT)
	_check("T7 drawn by its own shader, no texture", look != null
		and look.shader.resource_path == "res://scripts/Visual/tesla_arc.gdshader" and samplers.is_empty()
		and look.shader.code.contains("fog_disabled"), "%s" % [samplers])

	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


func _arc(points: PackedVector3Array, ride: bool, seed: int) -> Node3D:
	var arc: Node3D = TeslaArcScript.new()
	arc.points = points
	arc.ride = ride
	arc.seed = seed
	add_child(arc)
	return arc


func _check(label: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1
