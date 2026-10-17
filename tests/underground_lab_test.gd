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

	# U7 the grime decals, each named for its kind, F3 hides and shows them
	var decals: Array = lab.decals
	var named := {}

	for d in decals:
		named[String(d.name)] = true
	lab.set_decals(false)
	var hidden: bool = decals.all(func(d): return not d.visible)
	lab.set_decals(true)
	# Each keeps its transparency: without it a decal draws as a dark box.
	var clear: bool = decals.all(func(d): return d.texture_albedo != null \
		and d.texture_albedo.get_image().detect_alpha() != Image.ALPHA_NONE)
	_check("U7 five grime decals (drip, soot, grime, oil, wet), see-through at their edges, F3 turns them off and on",
		["decal_drip", "decal_soot", "decal_grime", "decal_oil", "decal_wet"].all(func(k): return named.has(k)) and hidden and clear and decals.all(func(d): return d.visible),
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

	# U22 the metro breathes: a train passes now and then, its pass building, holding and fading
	var train: TrainPass = lab.train
	var waits := train != null and train.next >= TrainPass.EVERY.x and train.next <= TrainPass.EVERY.y
	var swing_before := 0.0

	for i in 120:
		await get_tree().physics_frame
		swing_before = maxf(swing_before, rad_to_deg((-lab.bulb_pivot.global_basis.y).angle_to(Vector3.DOWN)))

	var light_full: float = lab.work_lights[0].light_energy
	train.start_pass()
	var peak := 0.0
	var swing_peak := 0.0
	var dimmest := INF
	var rumble_loudest := -80.0
	var sifting := false
	var blown_most := 0.0

	for i in int((TrainPass.BUILD + TrainPass.HOLD) * 60.0):
		await get_tree().physics_frame
		peak = maxf(peak, train.strength())
		swing_peak = maxf(swing_peak, rad_to_deg((-lab.bulb_pivot.global_basis.y).angle_to(Vector3.DOWN)))
		dimmest = minf(dimmest, lab.work_lights[0].light_energy)
		rumble_loudest = maxf(rumble_loudest, lab.rumble.volume_db)
		sifting = sifting or (lab.dust_sift.emitting and lab.dust_sift.amount_ratio > 0.4)
		var copal: GPUParticles3D = lab.censer.find_children("*", "GPUParticles3D", true, false)[0]
		blown_most = maxf(blown_most, absf((copal.process_material as ParticleProcessMaterial).gravity.x))

	_check("U22 a train passes now and then: its strength builds to full and holds",
		waits and peak > 0.95 and train.passing(), "next %.0f s peak %.2f" % [train.next, peak])

	# U23 the gust: the bulb swings harder (never wild), the copal bends, dust sifts from the vault
	_check("U23 its gust swings the bulb harder (under 10 degrees), bends the copal and sifts dust from the vault",
		swing_peak > swing_before * 1.8 and swing_peak < 10.0 and blown_most > 0.2 and sifting,
		"swing %.1f -> %.1f deg, smoke pushed %.2f, sifting %s" % [swing_before, swing_peak, blown_most, sifting])

	# U24 the lights brown out and the rumble is heard; the jars rattle
	_check("U24 the lights brown out under it, its rumble swells, the jars on the shelves rattle",
		dimmest < light_full * 0.8 and rumble_loudest > -12.0 and lab.rattles >= 1,
		"lights %.2f -> %.2f rumble %.1f dB rattles %d" % [light_full, dimmest, rumble_loudest, lab.rattles])

	# U25 and it passes: everything settles back, the next train reckoned
	for i in int((TrainPass.FADE + 1.0) * 60.0):
		await get_tree().physics_frame

	_check("U25 the train passes on: strength back to nothing, the lights full again, the next one reckoned",
		not train.passing() and train.strength() == 0.0 and is_equal_approx(lab.work_lights[0].light_energy, light_full)
		and train.next >= TrainPass.EVERY.x, "strength %.2f lights %.2f next %.0f" % [train.strength(),
		lab.work_lights[0].light_energy, train.next])

	# U26 the crowd's murmur fills the corridor from both ends, sinking under a train
	var crowd: Crowd = lab.crowd
	var beds: Array = crowd.beds if crowd != null else []
	var ends := beds.size() == 2 and beds.all(func(b): return b.playing and b.stream != null) \
		and absf(beds[0].global_position.x) > 6.0 and absf(beds[1].global_position.x) > 6.0 \
		and signf(beds[0].global_position.x) != signf(beds[1].global_position.x)
	var calm: float = crowd.bed_volume(0.0) if crowd != null else 0.0
	var masked: float = crowd.bed_volume(1.0) if crowd != null else 0.0
	_check("U26 the crowd's murmur fills the corridor from both ends and sinks under a passing train",
		ends and masked < calm - 6.0, "beds %d calm %.1f masked %.1f" % [beds.size(), calm, masked])

	# U27 people pass: footsteps on the tile walk the corridor, never inside the stall
	var steps_before: int = crowd.steps_played
	var where := {}

	for i in 600:
		await get_tree().physics_frame
		for w in crowd.walkers:
			where[snappedf(w["x"], 0.5)] = true

	var inside: bool = crowd.walkers.any(func(w): return w["z"] < 0.9)
	_check("U27 passers-by's footsteps walk the corridor on the tile, out in front of the stall",
		crowd.steps_played - steps_before >= 15 and where.size() >= 6 and not inside,
		"steps %d places %d inside %s" % [crowd.steps_played - steps_before, where.size(), inside])

	# U28 now and then someone coughs, laughs, sighs, clears their throat, somewhere down the corridor
	var voices_before: int = crowd.voices_played
	crowd.voice()
	_check("U28 now and then a voice from the crowd: a cough, a laugh, a sigh, somewhere down the corridor",
		crowd.voices_played == voices_before + 1 and crowd.next_voice >= Crowd.VOICE_EVERY.x
		and crowd.next_voice <= Crowd.VOICE_EVERY.y, "next %.1f" % crowd.next_voice)

	# U29 the junction box hums where the stall's cable is tapped
	var box_hum: AudioStreamPlayer3D = lab.junction_hum
	_check("U29 the junction box hums where the stall's cable is tapped",
		box_hum != null and box_hum.playing and box_hum.global_position.distance_to(lab.JUNCTION_TOP) < 0.3
		and box_hum.max_distance <= 6.0, "%s" % [box_hum])

	# U30 the floor's clutter staged as scenes: customers' litter by the counter, her stock against the wall,
	#     newspapers, a cable run to the next stall, a child's top in her aisle, a marigold trail
	var kinds := {}

	for piece: MeshInstance3D in lab.clutter:
		var kind := String(piece.get_meta("kind"))
		kinds[kind] = kinds.get(kind, 0) + 1

	var wanted := {"cone_crushed": 2, "jarrito": 1, "news_spread": 1, "news_folded": 1, "sack_slumped": 1,
		"sack_lying": 1, "crate": 2, "crate_corn": 1, "cable_run": 1, "trompo": 1, "marigold_head": 18}
	var short := wanted.keys().filter(func(k): return kinds.get(k, 0) < wanted[k])
	var solid := true
	var in_gap := []

	for p: MeshInstance3D in lab.clutter:
		var stock: bool = p.get_meta("kind") in ["sack_slumped", "sack_lying", "crate", "crate_corn"]
		solid = solid and stock == (p.find_children("*", "StaticBody3D", true, false).size() > 0)
		var at := p.global_position
		if at.x > 0.45 and at.x < 1.45 and at.z > -1.6 and at.z < 1.6:
			in_gap.append(p)
	_check("U30 the floor's clutter is staged as scenes (litter, stock, papers, a cable run, a top, marigolds), stock solid, the way in clear",
		short.is_empty() and solid and in_gap.is_empty(), "short %s solid %s in the way %s" % [short, solid, in_gap])

	# U31 the marigold trail leads from her ofrenda across the floor to the wall
	var trail: Array = lab.clutter.filter(func(p): return p.get_meta("kind") == "marigold_head")
	var towards := true

	for i in range(1, trail.size()):
		towards = towards and trail[i].global_position.distance_to(lab.TRAIL_END) < trail[i - 1].global_position.distance_to(lab.TRAIL_END)
	_check("U31 a trail of marigold heads leads from her ofrenda across the floor to the wall",
		trail.size() >= 8 and towards and trail[0].global_position.distance_to(lab.TRAIL_START) < 0.3
		and trail[-1].global_position.distance_to(lab.TRAIL_END) < 0.5, "heads %d toward %s" % [trail.size(), towards])

	# U32 an oil stain where a cart stands, a wet patch where the water runs
	var stains: Array = lab.decals.filter(func(d): return d.name in ["decal_oil", "decal_wet"])
	_check("U32 an oil stain and a wet patch on the floor, each where its cause is", stains.size() == 2,
		"%s" % [stains])

	# U33 loose petals strewn along the trail between the heads, not breadcrumbs
	var petals: Array = lab.decals.filter(func(d): return String(d.name).begins_with("decal_petals"))
	var strewn := true

	for d in petals:
		var nearest := 99.0

		for head in trail:
			nearest = minf(nearest, Vector2(d.global_position.x, d.global_position.z).distance_to(
				Vector2(head.global_position.x, head.global_position.z)))
		strewn = strewn and nearest < 0.6
	_check("U33 loose marigold petals are strewn along the trail between its heads", petals.size() >= 6 and strewn,
		"%d petal patches, along %s" % [petals.size(), strewn])

	# U34 the back wall's services: the water main and the gas line run its length, the Company's tray above them
	var green := _services_on(lab, "pipe_green", lab.BACK_WALL, lab.CONDUIT.y)
	var ochre := _services_on(lab, "pipe_ochre", lab.BACK_WALL, lab.GAS_Y)
	var tray := _services_on(lab, "cable_tray", lab.BACK_WALL, lab.TRAY_Y)
	_check("U34 along the back wall the water main, the gas line and the Company's tray each run the corridor's length",
		_covers(lab, green) and _covers(lab, ochre) and _covers(lab, tray)
		and tray.any(func(p): return p.get_meta("kind") == "cable_tray_4_spill"),
		"green %d ochre %d tray %d" % [green.size(), ochre.size(), tray.size()])

	# U35 the drip has its cause: it falls from a weeping joint of the water main
	var joints: Array = green.map(func(p): return p.global_position.x)
	_check("U35 the water drips from a joint of the water main", joints.any(func(x): return absf(x - lab.DRIP_AT.x) < 0.1),
		"joints %s" % [joints])

	# U36 the far wall: the fire main with a valve and a hydrant low on the wall, the air line, heavy cables swagged
	var red := _services_on(lab, "pipe_red", lab.FAR_WALL, lab.FIRE_Y)
	var blue := _services_on(lab, "pipe_blue", lab.FAR_WALL, lab.AIR_Y)
	var swag := _services_on(lab, "cable_swag", lab.FAR_WALL, lab.HOOK_Y)
	var hydrant: Array = red.filter(func(p): return p.get_meta("kind") == "pipe_red_drop")
	_check("U36 on the far wall the red fire main (a valve, a hydrant low on the wall, solid), the blue air line, heavy cables on hooks",
		_covers(lab, red.filter(func(p): return p.get_meta("kind") != "pipe_red_drop"), 1.0)
		and red.any(func(p): return p.get_meta("kind") == "pipe_red_valve") and hydrant.size() == 1
		and hydrant[0].find_children("*", "StaticBody3D", true, false).size() > 0
		and _covers(lab, blue) and _covers(lab, swag),
		"red %d hydrant %d blue %d swag %d" % [red.size(), hydrant.size(), blue.size(), swag.size()])

	# U38 on the far wall the valve's wheel stays clear below the cables swagged over it
	var wheel_top := -INF
	var cables_low := INF

	for piece: MeshInstance3D in lab.services:
		var box := piece.global_transform * piece.get_aabb()
		if piece.get_meta("kind") == "pipe_red_valve":
			wheel_top = maxf(wheel_top, box.end.y)
		elif piece.get_meta("kind") == "cable_swag":
			cables_low = minf(cables_low, box.position.y)
	_check("U38 the fire main's valve wheel stays at least 3 cm below the swagged cables",
		cables_low - wheel_top >= 0.03, "wheel top %.3f, cables' lowest %.3f" % [wheel_top, cables_low])

	# U37 the stall's power rises in the Company's orange from its junction box into the tray; the flat stand-ins are gone
	var rise: Array = lab.services.filter(func(p): return p.get_meta("kind") == "conduit_drop")
	var gone: bool = ["conduit", "conduit_brass", "drop"].all(func(n): return lab.get_node_or_null(n) == null)
	_check("U37 the stall's power rises in orange conduit from its junction box into the tray; no flat stand-in tubes left",
		rise.size() == 1 and rise[0].global_position.distance_to(lab.JUNCTION_TOP) < 0.01
		and absf(lab.JUNCTION_TOP.y + 0.75 - lab.TRAY_Y) < 0.01 and gone, "rise %d gone %s" % [rise.size(), gone])

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


## The bay's services of a kind hung on the wall at `wall_z`, at height `y`.
func _services_on(lab: Node3D, prefix: String, wall_z: float, y: float) -> Array:
	return lab.services.filter(func(p): return String(p.get_meta("kind")).begins_with(prefix) \
		and absf(p.global_position.z - wall_z) < 0.01 and absf(p.global_position.y - y) < 0.01)


## A wall piece's run along the wall (m): the kit's lengths.
func _run_of(kind: String) -> float:
	if kind.ends_with("_2"):
		return 2.0
	if kind == "cable_swag":
		return 3.0
	if kind in ["cable_hook", "pipe_red_drop", "conduit_drop"]:
		return 0.0
	return 4.0


## Whether pieces laid end to end cover the corridor's run, wall to wall, with no gap
## (but `short` metres left at the ends, where something else takes over).
func _covers(lab: Node3D, pieces: Array, short := 0.0) -> bool:
	var spans := []

	for piece in pieces:
		var x: float = piece.global_position.x
		var dx: float = _run_of(String(piece.get_meta("kind"))) * (1.0 if absf(piece.rotation.y) < 0.1 else -1.0)
		spans.append(Vector2(minf(x, x + dx), maxf(x, x + dx)))

	if spans.is_empty():
		return false

	spans.sort_custom(func(a, b): return a.x < b.x)
	var to: float = spans[0].y

	if spans[0].x > -lab.RUN + short:
		return false

	for span in spans:
		if span.x > to + 0.01:
			return false
		to = maxf(to, span.y)

	return to >= lab.RUN - short
