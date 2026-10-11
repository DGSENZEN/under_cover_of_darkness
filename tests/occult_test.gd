extends Node3D
## The god breathes (the effects plan, Task 7): everything that breathes
## with it, read off the dressed Zócalo's Occult as its breath is set by
## hand (Occult.apply(value, time)). Headless:
##   Godot --headless --fixed-fps 60 --path . res://tests/occult_test.tscn

const MAP := preload("res://maps/zocalo.tscn")
const Layers := preload("res://scripts/Visual/Layers.gd")

var results: Array[String] = []
var map: Node3D


func _ready() -> void:
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	map = MAP.instantiate()
	add_child(map)
	await _frames(5)
	map.set_day(false)
	var occult: Occult = map.occult
	occult.set_process(false)

	# O1 the breath draws in at the mouth on the inhale, pushes out on the exhale
	occult.apply(1.0, 0.0)
	var drawing: float = occult.attractor.strength
	occult.apply(-1.0, 0.0)
	var pushing: float = occult.attractor.strength
	# (A sphere attractor draws in at a positive strength: V6 watches it.)
	_check("O1 the mouth draws in on the inhale, pushes out on the exhale", drawing > 0.0 and pushing < 0.0,
		"inhale %.2f, exhale %.2f" % [drawing, pushing])

	# O2 the ward lamps dim on the inhale (the same moment of their hum)
	occult.apply(1.0, 0.3)
	var ward_in: float = occult.ward_lights[0].light_energy
	occult.apply(-1.0, 0.3)
	var ward_out: float = occult.ward_lights[0].light_energy
	_check("O2 the eight ward lamps dim on the inhale", occult.ward_lights.size() == 8 and ward_in < ward_out,
		"%d lamps, in %.2f, out %.2f" % [occult.ward_lights.size(), ward_in, ward_out])

	# O3 the breath touches only the god's own lamps (its ring is its eight
	# ward lamps, O2; the nearest street lamp stands 108 m off): every lamp
	# beyond 30 m keeps its light through a full inhale
	var beyond: Array = []

	for light: OmniLight3D in map.kit.lights:
		var off := Vector2(light.position.x - occult.god.x, light.position.z - occult.god.z).length()

		if off > Occult.RING_REACH and not map.kit.stuttering.has(light):
			beyond.append(light)

	occult.apply(-1.0, 0.0)
	map.kit._process(0.0)
	var before: Array = beyond.map(func(l): return l.light_energy)
	occult.apply(1.0, 0.0)
	map.kit._process(0.0)
	var after: Array = beyond.map(func(l): return l.light_energy)
	_check("O3 lamps beyond the god's ring keep their light through its inhale", beyond.size() > 0 and before == after,
		"%d lamps beyond, %d near dipping" % [beyond.size(), occult.ring_lights.size()])

	# O4 the fog round the cage swells with the inhale
	occult.apply(-1.0, 0.0)
	var thin: float = occult.cage_fog.material.density
	occult.apply(1.0, 0.0)
	var thick: float = occult.cage_fog.material.density
	_check("O4 the cage's fog thickens on the inhale", thick > thin * 1.5, "out %.3f, in %.3f" % [thin, thick])

	# O5 a deep exhale throws the four seals' sparks, which bounce
	for s: GPUParticles3D in occult.sparks:
		s.emitting = false

	map.breath.deep_exhale.emit()
	var thrown: Array = occult.sparks.map(func(s): return s.emitting and s.one_shot and s.collision_base_size > 0.0)
	_check("O5 a deep exhale throws the four seals' sparks, bouncing", thrown.size() == 4 and thrown.all(func(t): return t),
		str(thrown))

	# O5b their trails draw (a ribbon of fewer than four sections drew nothing
	# at all, the sparks there but unseen)
	var sections: Array = occult.sparks.map(func(s): return (s.draw_pass_1 as RibbonTrailMesh).sections)
	_check("O5b the seals' sparks draw their trails", sections.all(func(n): return n >= 4), str(sections))

	# O6 every sigil disc carries its sigil 4 cm proud of its face
	var discs: Array = map.dressing["pieces"].filter(func(p): return p["piece"] == "sigil_disc")
	var placed := 0

	for p in discs:
		var basis := Basis(Vector3.UP, deg_to_rad(p["yaw"]))
		var face := Vector3(p["at"][0], p["at"][1], p["at"][2]) + basis * Vector3(0, 0, Occult.DISC_FACE)
		var normal := basis * Vector3(0, 0, 1)

		for s: MeshInstance3D in occult.sigils:
			var proud := (s.global_position - face).dot(normal)

			if (s.global_position - face).length() < 0.1 and absf(proud - 0.04) < 0.005 and s.global_basis.z.dot(normal) > 0.99:
				placed += 1
				break

	_check("O6 every sigil disc carries its sigil 4 cm proud of its face", discs.size() > 0 and placed == discs.size(),
		"%d of %d" % [placed, discs.size()])

	# O7 the god's chest swells with the inhale
	occult.apply(1.0, 0.0)
	var full: float = occult.god_look.get_shader_parameter(&"swell")
	occult.apply(-1.0, 0.0)
	var empty: float = occult.god_look.get_shader_parameter(&"swell")
	_check("O7 the god's chest swells on the inhale", full > 0.05 and empty == 0.0, "in %.3f, out %.3f" % [full, empty])

	# O10 nothing an effect throws passes through the player's head: a
	# particle collider round the camera, following it (sparks from the
	# seals fly out to where a player stands)
	var head: GPUParticlesCollisionSphere3D = map.get("head")
	var viewer: Camera3D = get_viewport().get_camera_3d()
	viewer.global_position += Vector3(0.7, 0, 0)
	await _frames(2)
	_check("O10 a collider round the player's head stops what effects throw", head != null and head.radius >= 0.3
		and head.cull_mask & Layers.FX and head.global_position.distance_to(viewer.global_position) < 0.01,
		"head %s" % (head.global_position if head else "none"))

	# O9 the lightgem's cameras see none of the god's effects
	var gem := 0

	for camera in map.player.find_children("*", "Camera3D", true, false):
		if camera.get_parent() is SubViewport:
			gem |= camera.cull_mask

	var seen := occult.find_children("*", "VisualInstance3D", true, false).filter(func(v): return not v is Light3D and v.layers & gem)
	_check("O9 the lightgem's cameras see none of the god's effects", gem != 0 and seen.is_empty(), "%d seen" % seen.size())

	# O8 the wards' ring shows round a ward lamp within 3 m of the player, not further
	var lamp: OmniLight3D = occult.ward_lights[0]
	occult.ring_for(Vector3(lamp.global_position.x + 2.0, 1.6, lamp.global_position.z))
	var close: bool = occult.ward_ring.visible
	occult.ring_for(Vector3(lamp.global_position.x + 12.0, 1.6, lamp.global_position.z + 12.0))
	_check("O8 the wards' ring shows within 3 m of a ward lamp, not beyond", close and not occult.ward_ring.visible,
		"close %s, far %s" % [close, occult.ward_ring.visible])


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
