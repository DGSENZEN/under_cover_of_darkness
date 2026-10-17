extends Node3D
## The Underground's look-dev bay (maps/underground_lab.tscn): the hero stall
## in a stretch of tiled corridor, painted in the bespoke blend, its neon and
## bulb lit, two sodium work lights, a neutral form light to judge shape (F2),
## grime decals (F3); the player can walk round its front.

const LAB := preload("res://maps/underground_lab.tscn")
const FireParticles := preload("res://scripts/Visual/Lights/FireParticles.gd")
const PARTS := ["stall_frame", "stall_counter", "stall_awning", "stall_shelves", "stall_clutter", "stall_ofrenda",
	"stall_neon", "stall_bulb"]

var results: Array[String] = []
var lab: Node3D


func _ready() -> void:
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	lab = LAB.instantiate()
	add_child(lab)
	await _frames(5)

	# U1 the stall, all its parts
	var meshes := {}

	# (The bulb hangs from its pivot, beside the stall's own node.)
	for mesh: MeshInstance3D in lab.find_children("stall_*", "MeshInstance3D", true, false):
		meshes[String(mesh.name)] = mesh

	var have := PARTS.filter(func(p): return meshes.has(p))
	_check("U1 the stall stands in the bay with all eight of its parts", have.size() == PARTS.size() and lab.missing.is_empty(),
		"parts %s missing %s" % [have, lab.missing])

	# U2 its painted parts in the bespoke blend (the atlas's colour whole)
	var painted := 0
	var wrong := []

	for part in ["stall_frame", "stall_counter", "stall_awning", "stall_shelves"]:
		var mesh: MeshInstance3D = meshes.get(part)

		if mesh == null:
			wrong.append(part)
			continue

		for i in mesh.mesh.get_surface_count():
			var m: Material = mesh.get_surface_override_material(i)

			if m is ShaderMaterial and is_equal_approx(m.get_shader_parameter("paint_mix"), 0.0) \
					and m.get_shader_parameter("atlas") != null:
				painted += 1
			else:
				wrong.append("%s/%d" % [part, i])

	_check("U2 the stall's painted parts wear its atlas in the bespoke blend", painted > 0 and wrong.is_empty(),
		"painted %d wrong %s" % [painted, wrong])

	# U3 its neon glows and flickers
	var levels := {}

	if lab.neon != null:
		for i in 120:
			await get_tree().physics_frame
			levels[snappedf(lab.neon.light.light_energy, 0.001)] = true

	_check("U3 the neon sign glows from its own tube and flickers", lab.neon != null and lab.neon.tube != null
		and lab.neon.tube.name == "stall_neon" and levels.size() >= 2, "levels %s" % [levels.keys()])

	# U4 the corridor is lit by its two sodium work lights and the stall's bulb
	var lit: Array = lab.work_lights.filter(func(l): return l.visible and l.light_energy > 0.0)
	_check("U4 two sodium work lights and the stall's bulb light the corridor",
		lit.size() == 2 and lab.bulb != null and lab.bulb.light_energy > 0.0, "work %d bulb %s" % [lit.size(), lab.bulb])

	# U5 the player walks past its whole front without catching on anything unseen
	var walk := await _walk(Vector3(-2.6, 1.05, 1.0), -PI / 2, func(p): return p.x > 2.6, 600)
	_check("U5 the player walks the stall's whole front without snagging", walk["ok"] and walk["stall"] < 20,
		"%s" % [walk])

	# U6 F2 the form light: neutral grey on everything, one white light; and back
	lab.set_form(true)
	await _frames(2)
	var grey: bool = meshes.values().all(func(m): return m.material_override == lab.form_material)
	# The form light reaches the stall (no shadow from the vault), and nothing coloured lights it.
	var form_on: bool = grey and lab.form_light.visible and not lab.form_light.shadow_enabled \
		and lab.work_lights.all(func(l): return not l.visible) and not lab.bulb.visible and not lab.neon.light.visible
	lab.set_form(false)
	await _frames(2)
	var back: bool = meshes.values().all(func(m): return m.material_override == null or m == lab.neon.tube) \
		and lab.neon.tube.material_override == lab.neon.tube_material() and not lab.form_light.visible
	_check("U6 F2 turns the bay to a neutral grey under a white form light, and back", form_on and back,
		"grey %s on %s back %s" % [grey, form_on, back])

	# U7 three grime decals, F3 hides and shows them
	var decals: Array = lab.decals
	lab.set_decals(false)
	var hidden: bool = decals.all(func(d): return not d.visible)
	lab.set_decals(true)
	# Each keeps its transparency: without it a decal draws as a dark box.
	var clear: bool = decals.all(func(d): return d.texture_albedo != null \
		and d.texture_albedo.get_image().detect_alpha() != Image.ALPHA_NONE)
	_check("U7 three grime decals (drip, soot, grime), see-through at their edges, F3 turns them off and on",
		decals.size() == 3 and hidden and clear and decals.all(func(d): return d.visible),
		"%d decals, hidden %s, see-through %s" % [decals.size(), hidden, clear])

	# U10 the bulb sways in the corridor's draught, a few degrees at most, its light with it
	var swing := 0.0
	var lights := {}

	for i in 180:
		await get_tree().physics_frame
		var down: Vector3 = -lab.bulb_pivot.global_basis.y
		swing = maxf(swing, rad_to_deg(down.angle_to(Vector3.DOWN)))
		lights[lab.bulb.global_position.snapped(Vector3.ONE * 0.001)] = true

	_check("U10 the hanging bulb sways in the draught (under 4 degrees) and its light swings with it",
		swing > 0.3 and swing < 4.0 and lights.size() > 5 and lab.bulb_pivot.is_ancestor_of(lab.bulb),
		"swing %.2f deg, light at %d places" % [swing, lights.size()])

	# U11 a thread of copal rises from the censer: our own smoke sheet, blown by the one draught
	var censer: Node3D = lab.censer
	var smoke: Array = censer.find_children("*", "GPUParticles3D", true, false) if censer != null else []
	var sheet := ""

	for p: GPUParticles3D in smoke:
		var m: Material = p.draw_pass_1.surface_get_material(0) if p.draw_pass_1 != null else p.material_override
		if m is ShaderMaterial and m.get_shader_parameter("sheet") is Texture2D:
			sheet = (m.get_shader_parameter("sheet") as Texture2D).resource_path
	_check("U11 a thread of copal smoke rises from the censer, drawn from our own plume sheet",
		censer != null and censer.global_position.distance_to(lab.CENSER) < 0.05 and smoke.any(func(p): return p.emitting)
		and sheet.begins_with("res://assets/vfx/"), "censer %s sheet %s" % [censer, sheet])

	# U12 dust hangs in each work light's cone
	var in_cones := 0

	for light: Light3D in lab.work_lights:
		for d: Node3D in lab.dust:
			var below := light.global_position - d.global_position
			if below.y > 1.0 and below.y < 3.5 and Vector2(below.x, below.z).length() < 1.0:
				in_cones += 1
	_check("U12 dust motes drift in each work light's cone", lab.dust.size() == 2 and in_cones == 2,
		"%d dust systems, %d under a light" % [lab.dust.size(), in_cones])

	# U13 the neon hums on its sign, gone within 8 m, louder as it burns brighter
	var hum: AudioStreamPlayer3D = lab.neon.get_node_or_null("hum") if lab.neon != null else null
	var follows := false

	if hum != null:
		var loud: float = lab.hum_volume(1.0)
		var quiet: float = lab.hum_volume(0.0)
		follows = loud > quiet + 12.0
	_check("U13 the neon hums from its sign, silent past 8 m, its loudness following the flicker",
		hum != null and hum.stream != null and hum.stream.resource_path == "res://audio/ambience/neon_hum.wav"
		and hum.max_distance <= 8.0 and hum.playing and follows,
		"hum %s" % [hum])

	# U14 she can work it: the player walks in past the counter's end and along behind it
	var way_in := await _walk(Vector3(0.95, 1.05, 1.4), 0.0, func(p): return p.z < -1.1, 600)
	var along := await _walk(lab.player.global_position, PI / 2, func(p): return p.x < -0.1, 600)
	_check("U14 the player walks in past the counter's end and stands along behind it",
		way_in["ok"] and along["ok"] and absf(along["end"].z + 1.1) < 0.3,
		"in %s along %s" % [way_in, along])

	# U15 her ofrenda's candles burn: a flame on each recorded wick, their light flickering
	var flames: Array = lab.flames.find_children("candles", "MultiMeshInstance3D", true, false) if lab.flames != null else []
	var glow: OmniLight3D = lab.flames.find_children("*", "OmniLight3D", true, false)[0] if lab.flames != null else null
	var energies := {}

	if glow != null:
		for i in 60:
			await get_tree().physics_frame
			energies[snappedf(glow.light_energy, 0.001)] = true
	_check("U15 her ofrenda's three candles burn on their wicks, their light flickering",
		flames.size() == 1 and flames[0].visible and flames[0].multimesh.instance_count == 3 and energies.size() >= 3,
		"flames %s levels %d" % [flames.size(), energies.size()])

	# U16 the copal hangs under the canvas: a pool of haze over the censer
	var pool: Array = lab.censer.find_children("*", "FogVolume", true, false)
	_check("U16 the copal smoke pools in a haze under the canvas over the censer",
		pool.size() == 1 and (pool[0] as Node3D).global_position.y > 1.9 and (pool[0] as Node3D).global_position.y < 2.3,
		"%s" % [pool])

	# U17 the neon washes its sign's face; the bodged tap at the junction sparks now and then
	var wash: Decal = lab.neon_wash
	var before: int = FireParticles.emitted(&"spark")
	lab.spark()
	var sparked: int = FireParticles.emitted(&"spark") - before
	_check("U17 the neon washes the sign's face with its glow, and the junction's bodged tap throws sparks",
		wash != null and wash.texture_emission != null and wash.emission_energy > 0.0 and sparked > 0
		and lab.next_spark > 0.0, "wash %s sparks %d next %.1f" % [wash, sparked, lab.next_spark])

	# U18 the work lights' beams show in the air: a cone of haze under each
	var cones: Array = lab.shafts.filter(func(f): return f is FogVolume and f.shape == RenderingServer.FOG_VOLUME_SHAPE_CONE)
	_check("U18 each work light throws a visible shaft (a cone of haze under it)", cones.size() == 2,
		"%d shafts" % cones.size())

	# U19 water drips off the conduit into a puddle, and is heard
	var drip_ok: bool = lab.drip != null and lab.drip.emitting and lab.puddle != null and lab.drip_sound != null \
		and lab.drip_sound.stream != null and absf(lab.drip.global_position.y - (lab.CONDUIT.y - 0.1)) < 0.15
	_check("U19 water drips off the conduit into a puddle on the floor, its drip heard",
		drip_ok, "drip %s puddle %s sound %s" % [lab.drip, lab.puddle, lab.drip_sound])

	# U20 moths, drawn by the bulb, circle it
	var moths: Array = lab.moths.get_children() if lab.moths != null else []
	var at_start: Array = moths.map(func(m): return m.global_position)
	await _frames(30)
	var moved := 0
	var near := 0

	for i in moths.size():
		if moths[i].global_position.distance_to(at_start[i]) > 0.02:
			moved += 1
		if moths[i].global_position.distance_to(lab.bulb.global_position) < 0.6:
			near += 1
	_check("U20 three moths circle the bulb, drawn by its light", moths.size() == 3 and moved == 3 and near == 3,
		"%d moths, %d moving, %d near" % [moths.size(), moved, near])

	# U21 its painted files come through Godot's import (they would be missing from an exported game otherwise)
	var loose: Array = []
	var atlas_mat: ShaderMaterial = (meshes["stall_frame"] as MeshInstance3D).get_surface_override_material(0)
	var used: Array = [atlas_mat.get_shader_parameter("atlas")] + lab.decals.map(func(d): return d.texture_albedo) + [lab.puddle.texture_albedo]

	for t in used:
		if t == null or not (t as Resource).resource_path.begins_with("res://textures/painted/underground/"):
			loose.append(t)
	_check("U21 the atlas and decals are the imported textures, as an exported game needs", loose.is_empty(),
		"loose %s" % [loose])

	# U8 no pixel grid
	var retro: Node = get_node_or_null("/root/Retro")
	_check("U8 the pixel grid is off", retro != null and retro.virtual_height == 0, "%s" % [retro.virtual_height if retro else null])

	# U9 the bay needs only what is committed: the painted atlas, never the brush sheets
	var source := FileAccess.get_file_as_string("res://maps/underground_lab.gd")
	_check("U9 the bay reads the committed painted atlas, not the user's local brush sheets",
		not source.contains("textures/brushes") and FileAccess.file_exists(lab.atlas_dir + "stall_base.png"),
		"atlas dir %s" % lab.atlas_dir)


func _walk(start: Vector3, yaw: float, done: Callable, frames: int) -> Dictionary:
	var player: CharacterBody3D = lab.player
	player.global_position = start
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	await _frames(10)
	Input.action_press("move_forward")
	var stall := 0
	var still := 0
	var last := player.global_position
	var arrived := false

	for i in frames:
		await get_tree().physics_frame
		still = still + 1 if player.global_position.distance_to(last) < 0.005 else 0
		stall = maxi(stall, still)
		last = player.global_position

		if done.call(player.global_position):
			arrived = true
			break

	Input.action_release("move_forward")
	await _frames(10)
	return {"ok": arrived, "end": player.global_position, "stall": stall}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
