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

	# U39 the tamale cart stands where its axle grease stained the floor; its steamer steams from under the lid, hissing
	var cart := _furniture(lab, "tamale_cart")
	var stool := _furniture(lab, "stool")
	var oil: Decal = lab.get_node_or_null("decal_oil")
	var pot: Vector3 = cart.global_transform * lab.POT_LOCAL if cart else Vector3.INF
	_check("U39 the tamale cart stands on its oil stain, steam rising off its steamer's lid, its hiss heard; cart and stool solid",
		cart != null and stool != null and oil != null
		and Vector2(cart.global_position.x - oil.global_position.x, cart.global_position.z - oil.global_position.z).length() < 0.4
		and lab.cart_steam != null and lab.cart_steam.global_position.distance_to(pot) < 0.06
		and lab.cart_hiss != null and lab.cart_hiss.playing and lab.cart_hiss.global_position.distance_to(pot) < 0.3
		and _solid(cart) and _solid(stool), "cart %s pot %s" % [cart, pot])

	# U40 a bench against the far wall, solid, a newspaper left on its seat
	var bench := _furniture(lab, "bench")
	var left: Array = lab.clutter.filter(func(p): return p.get_meta("kind") == "news_folded" and bench != null \
		and absf(p.global_position.y - 0.45) < 0.02 and p.global_position.x < bench.global_position.x \
		and p.global_position.x > bench.global_position.x - 1.8)
	_check("U40 a bench against the far wall, solid, a newspaper left on its seat",
		bench != null and absf(bench.global_position.z - lab.FAR_WALL) < 0.01 and absf(bench.rotation.y) > 3.0
		and _solid(bench) and left.size() == 1, "bench %s papers on it %d" % [bench, left.size()])

	# U41 a bin in the Company's orange beside the bench, solid, litter dropped short of it
	var bin := _furniture(lab, "trash_bin")
	var missed: Array = lab.clutter.filter(func(p): return bin != null and p.get_meta("kind") in ["cone_crushed", "jarrito"] \
		and p.global_position.distance_to(bin.global_position) < 0.7)
	_check("U41 a bin beside the bench, solid, litter dropped short of it",
		bin != null and bench != null and bin.global_position.distance_to(bench.global_position) < 2.6 and _solid(bin)
		and missed.size() >= 1, "bin %s litter by it %d" % [bin, missed.size()])

	# U42 the Virgin's niche on the far wall: a flame on each of its wicks, its candles' soot over it
	var niche := _furniture(lab, "niche")
	var wicks: Array = JSON.parse_string(FileAccess.get_file_as_string(lab.FURNITURE_WICKS)).get("niche", []) \
		if FileAccess.file_exists(lab.FURNITURE_WICKS) else []
	var aflame := 0

	for w in wicks:
		var at: Vector3 = niche.global_transform * Vector3(w[0], w[1], w[2])
		aflame += 1 if lab.niche_wicks.any(func(f): return f.distance_to(at) < 0.01) else 0
	var soot: Decal = lab.get_node_or_null("decal_soot_niche")
	_check("U42 the niche on the far wall, a flame on each of its 7 wicks, its candles' soot above it",
		niche != null and absf(niche.global_position.z - lab.FAR_WALL) < 0.01 and wicks.size() == 7 and aflame == 7
		and lab.niche_flames != null and lab.niche_flames.is_inside_tree() and soot != null
		and absf(soot.global_position.x - niche.global_position.x) < 0.3 and soot.global_position.y > lab.NICHE_SILL + 0.6,
		"wicks %d lit %d soot %s" % [wicks.size(), aflame, soot])

	# U43 the vent breathes warm air out of the back wall, humming; its breath has stained the wall above it
	var vent := _furniture(lab, "vent_grille")
	var mouth: Vector3 = vent.global_position + Vector3(0.0, 0.35, 0.0) if vent else Vector3.INF
	var streak: Decal = lab.get_node_or_null("decal_soot_vent")
	_check("U43 the vent breathes warm air from the back wall, humming, the wall above it stained",
		vent != null and absf(vent.global_position.z - lab.BACK_WALL) < 0.01 and lab.vent_breath != null
		and lab.vent_breath.global_position.distance_to(mouth) < 0.15 and lab.vent_hum != null and lab.vent_hum.playing
		and streak != null and absf(streak.global_position.x - vent.global_position.x) < 0.2
		and streak.global_position.y > 0.55, "vent %s streak %s" % [vent, streak])

	# U44 the floor laid in tile modules wall to wall, edge to edge: dark border rows along both walls,
	#     worn modules among the plain, a drain set flush where the wall's water runs
	var rects := []
	var area := 0.0

	for module: MeshInstance3D in lab.floor_tiles:
		var box := module.global_transform * module.get_aabb()
		rects.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
		area += box.size.x * box.size.z
	var overlaps := 0

	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var shared: Rect2 = rects[i].intersection(rects[j])
			overlaps += 1 if shared.get_area() > 0.0005 else 0
	var hull := Rect2()

	for i in rects.size():
		hull = rects[i] if i == 0 else hull.merge(rects[i])
	var back_row: Array = lab.floor_tiles.filter(func(m): return absf((m.global_transform * m.get_aabb()).position.z - lab.BACK_WALL) < 0.01)
	var far_row: Array = lab.floor_tiles.filter(func(m): return absf((m.global_transform * m.get_aabb()).end.z - lab.FAR_WALL) < 0.01)
	var drains: Array = lab.floor_tiles.filter(func(m): return m.get_meta("kind") == "floor_border_drain")
	var drain_at: Vector3 = drains[0].global_transform * lab.DRAIN_LOCAL if drains.size() == 1 else Vector3.INF
	var corridor: float = (lab.FAR_WALL - lab.BACK_WALL) * 2.0 * lab.RUN
	_check("U44 the floor laid in tile modules wall to wall (borders at both walls, worn ones among them), a flush drain under the drip",
		overlaps == 0 and absf(area - corridor) < 0.01 and absf(hull.position.x + lab.RUN) < 0.01 and absf(hull.end.x - lab.RUN) < 0.01
		and absf(hull.position.y - lab.BACK_WALL) < 0.01 and absf(hull.end.y - lab.FAR_WALL) < 0.01
		and back_row.all(func(m): return String(m.get_meta("kind")).begins_with("floor_border"))
		and far_row.all(func(m): return m.get_meta("kind") == "floor_edge") and far_row.size() == 20
		and lab.floor_tiles.filter(func(m): return m.get_meta("kind") == "floor_field_worn").size() >= 4
		and Vector2(drain_at.x - lab.DRIP_AT.x, drain_at.z - lab.DRIP_AT.z).length() < 0.7,
		"modules %d overlaps %d area %.2f of %.2f hull %s back %d far %d drain %s" % [lab.floor_tiles.size(), overlaps,
		area, corridor, hull, back_row.size(), far_row.size(), drain_at])

	# U45 the walls tiled panel to panel, their face where the wall's things hang; worn panels among them,
	#     the marigold trail ending at the crack where the old stone shows; a name tablet on each wall;
	#     pasted bills and the floor's splash up the walls' feet
	var wall_spans := {lab.BACK_WALL: [], lab.FAR_WALL: []}
	var faced := true

	for panel: MeshInstance3D in lab.wall_panels:
		if panel.get_meta("kind") == "name_tablet" or absf(absf(panel.rotation.y) - PI / 2.0) < 0.01:
			continue   # (the tablets, and the end walls' panels: U47)
		var box := panel.global_transform * panel.get_aabb()
		var wall: float = lab.BACK_WALL if box.position.z < 0.0 else lab.FAR_WALL
		var face: float = box.end.z if wall == lab.BACK_WALL else box.position.z
		faced = faced and absf(face - wall) < 0.001
		wall_spans[wall].append(Vector2(box.position.x, box.end.x))
	var covered := true

	for wall in wall_spans:
		var spans: Array = wall_spans[wall]
		spans.sort_custom(func(a, b): return a.x < b.x)
		var reach: float = -lab.RUN
		for span in spans:
			covered = covered and absf(span.x - reach) < 0.01
			reach = span.y
		covered = covered and absf(reach - lab.RUN) < 0.01
	var crack: Array = lab.wall_panels.filter(func(p): return p.get_meta("kind") == "wall_crack")
	var opening: Vector2 = Vector2(crack[0].global_position.x + lab.CRACK_X.x, crack[0].global_position.x + lab.CRACK_X.y) \
		if crack.size() == 1 else Vector2.ZERO
	var back_box: Node3D = lab.get_node_or_null("back_wall")
	var bills: Array = lab.decals.filter(func(d): return String(d.name).begins_with("decal_poster"))
	var splash: Array = lab.decals.filter(func(d): return String(d.name).begins_with("decal_splash"))
	_check("U45 the walls tiled panel to panel, faced where things hang; worn panels, the trail ending at the old stone; tablets, bills, splash",
		faced and covered and lab.wall_panels.filter(func(p): return p.get_meta("kind") == "wall_tiled_worn").size() >= 6
		and crack.size() == 1 and absf(crack[0].global_position.z - (lab.BACK_WALL - lab.WALL_FACE)) < 0.001
		and lab.TRAIL_END.x > opening.x and lab.TRAIL_END.x < opening.y
		and lab.wall_panels.filter(func(p): return p.get_meta("kind") == "name_tablet").size() == 2
		and back_box != null and absf(back_box.position.z + 0.5 * lab.WALL - (lab.BACK_WALL - lab.WALL_FACE)) < 0.001
		and lab.get_node_or_null("band_back") == null and lab.get_node_or_null("band_far") == null
		and bills.size() >= 4 and splash.size() >= 6,
		"faced %s covered %s crack %d opening %s bills %d splash %d" % [faced, covered, crack.size(), opening, bills.size(), splash.size()])

	# U47 the corridor's end walls tiled too, their tiles' face at the corridor's ends, the walls set back behind
	var end_panels: Array = lab.wall_panels.filter(func(p): return absf(absf(p.rotation.y) - PI / 2.0) < 0.01)
	var faces_at_ends := true

	for panel: MeshInstance3D in end_panels:
		var box := panel.global_transform * panel.get_aabb()
		var face: float = box.position.x if panel.global_position.x > 0.0 else box.end.x
		faces_at_ends = faces_at_ends and absf(absf(face) - lab.RUN) < 0.001
	var east: Node3D = lab.get_node_or_null("end_%d" % int(lab.RUN))
	_check("U47 the corridor's end walls tiled, their face at the corridor's ends, the walls set back behind",
		end_panels.size() == 12 and faces_at_ends and east != null and east.position.x - 0.5 * lab.WALL >= lab.RUN + lab.WALL_FACE - 0.001,
		"end panels %d faced %s" % [end_panels.size(), faces_at_ends])

	# U46 the vault plastered in spans end to end, wall face to wall face, under the vault itself
	var soffit := []
	var soffit_area := 0.0

	for span: MeshInstance3D in lab.vault_spans:
		var box := span.global_transform * span.get_aabb()
		soffit.append(box)
		soffit_area += box.size.x * box.size.z
	var vault_box: Node3D = lab.get_node_or_null("vault")
	var wide: float = (lab.FAR_WALL - lab.BACK_WALL + 2.0 * lab.WALL_FACE) * 2.0 * lab.RUN
	_check("U46 the vault plastered in spans end to end, wall face to wall face; nothing fighting it",
		soffit.size() == 5 and absf(soffit_area - wide) < 0.01 and soffit.all(func(b): return absf(b.position.y - lab.HEIGHT) < 0.001)
		and vault_box != null and vault_box.position.y - 0.1 >= lab.HEIGHT + 0.039,
		"spans %d area %.2f of %.2f" % [soffit.size(), soffit_area, wide])

	# U49 the nahual: an enormous black dog lying by the bench where the old man's hat is left, its eyes
	#     glowing; it watches whoever looks at it, and once seen is gone when they look away, back only unwatched
	var n_dog: Node3D = lab.nahual
	var its_bench := _furniture(lab, "bench")
	var n_hat: Node3D = lab.old_hat
	var n_eyes_glow := false

	for i in n_dog.head.mesh.get_surface_count():
		var n_slot: Material = n_dog.head.mesh.surface_get_material(i)
		var n_drawn: Material = n_dog.head.get_surface_override_material(i)
		if n_slot != null and n_slot.resource_name == "ember":
			n_eyes_glow = n_drawn is StandardMaterial3D and n_drawn.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	var n_by_bench: bool = its_bench != null and n_dog.global_position.distance_to(its_bench.global_position) < 3.0 \
		and absf(n_dog.global_position.z - lab.FAR_WALL) < 0.6
	var n_hat_on: bool = n_hat != null and absf(n_hat.global_position.y - lab.BENCH_SEAT) < 0.02 \
		and n_hat.global_position.x < its_bench.global_position.x and n_hat.global_position.x > its_bench.global_position.x - 1.8
	var n_eye := Camera3D.new()
	add_child(n_eye)
	var n_eyes_at: Vector3 = n_dog.eyes()
	n_eye.global_position = n_eyes_at + Vector3(-2.0, 0.9, -2.6)
	n_eye.look_at(n_eyes_at, Vector3.UP)
	n_dog.watcher = n_eye
	n_dog.away_for = Vector2(1.0, 1.0)
	n_dog.appear()
	await _frames(90)
	var n_gaze: Vector3 = (n_dog.head.global_transform.basis.x * Vector3(1, 0, 1)).normalized()
	var n_to_eye: Vector3 = ((n_eye.global_position - n_dog.head.global_position) * Vector3(1, 0, 1)).normalized()
	var n_watching: bool = n_gaze.dot(n_to_eye) > cos(deg_to_rad(25.0)) and n_dog.visible
	n_eye.look_at(n_eyes_at + Vector3(0.0, 0.0, -8.0), Vector3.UP)
	n_eye.rotate_y(PI)
	await _frames(60)
	var n_gone: bool = not n_dog.visible
	n_eye.look_at(n_eyes_at, Vector3.UP)
	await _frames(150)
	var n_stayed_gone: bool = not n_dog.visible
	n_eye.rotate_y(PI)
	await _frames(90)
	var n_back_unwatched: bool = n_dog.visible
	n_dog.watcher = null
	n_eye.queue_free()
	_check("U49 the nahual lies by the bench (the old man's hat on it), eyes glowing; watches, is gone once looked away from, back only unwatched",
		n_by_bench and n_hat_on and n_eyes_glow and n_watching and n_gone and n_stayed_gone and n_back_unwatched,
		"by bench %s hat %s eyes %s watching %s gone %s stayed gone %s back %s" % [n_by_bench, n_hat_on, n_eyes_glow, n_watching, n_gone,
		n_stayed_gone, n_back_unwatched])

	# U50 the dark train: rare (far rarer than the Company's), no rumble, no brownout's flicker: every light sinks
	#     smoothly near dark, the candles gutter, a hard cold draught, the ánimas sink away, only wind heard;
	#     after it, all as it was
	var dt: TrainPass = lab.dark_train
	var rare: bool = dt != null and dt.every.x >= 4.0 * lab.train.every.y
	var lamp: Light3D = lab.work_lights[0]
	var lamp_full: float = lamp.light_energy
	var flame_light: Light3D = lab.flames.find_children("*", "OmniLight3D", false, false)[0]
	var flame_full: float = flame_light.light_energy
	var rumble_before: bool = lab.rumble.playing
	dt.start_pass()
	var steps := []

	for i in int((TrainPass.BUILD + 1.0) * 60.0):
		await get_tree().process_frame
		if i > 60 and i % 20 == 0:
			steps.append(lamp.light_energy)
	var smooth := true

	for i in range(1, steps.size()):
		smooth = smooth and steps[i] <= steps[i - 1] + 0.001
	var darkened: bool = lamp.light_energy < 0.3 * lamp_full and flame_light.light_energy < 0.4 * flame_full
	var guttered: bool = lab.flames.find_children("*", "MultiMeshInstance3D", false, false).all(func(m): return m.get_meta("gutter", 0.0) > 0.5)
	var hushed: bool = lab.rumble.playing == rumble_before and lab.dark_wind.playing and lab.animas.presence < 0.3
	for i in int((TrainPass.HOLD + TrainPass.FADE + 2.0) * 60.0):
		await get_tree().process_frame
	var restored: bool = absf(lamp.light_energy - lamp_full) < 0.05 * lamp_full and lab.animas.presence > 0.9
	_check("U50 the dark train: rare, no rumble, lights sink smoothly near dark, candles gutter, the ánimas sink, wind only; then as it was",
		rare and smooth and darkened and guttered and hushed and restored,
		"rare %s smooth %s dark %s guttered %s hushed %s restored %s" % [rare, smooth, darkened, guttered, hushed, restored])

	# U51 the nahual a spectre: its body and head drawn by the spectre shader (black, its edges fraying into
	#     rising smoke), its eyes still solid ember; dark wisps rise off its back, gone with it
	var spectre: Node3D = lab.nahual
	var haunted := true

	for part: MeshInstance3D in [spectre.body, spectre.head]:
		for i in part.mesh.get_surface_count():
			var slot: Material = part.mesh.surface_get_material(i)
			var drawn: Material = part.get_surface_override_material(i)
			var ember_slot: bool = slot != null and slot.resource_name == "ember"
			if ember_slot:
				haunted = haunted and drawn is StandardMaterial3D
			else:
				haunted = haunted and drawn is ShaderMaterial and (drawn as ShaderMaterial).shader.resource_path.ends_with("spectre.gdshader")
	var rising: bool = spectre.tendrils.size() >= 4 and spectre.tendrils.all(func(t): return t.is_visible_in_tree())
	_check("U51 the nahual is a spectre: black fraying into rising smoke, ember eyes solid, dark wisps off its back",
		haunted and rising, "spectre shader %s wisps %s" % [haunted, rising])

	# U52 the ánimas present, spirits: several out of the drain at once most of the time, drifting up to
	#     chest height round it and toward her candles; each a bright flame in a soft glow trailing wisps,
	#     the risen lighting the floor; from someone near they keep their distance but stay
	var an: Node3D = lab.animas
	var an_drain: Vector3 = an.global_position
	lab.player.global_position = Vector3(8.0, 1.05, 3.0)
	await _frames(240)
	var out_frames := 0
	var an_highest := -INF
	var an_farthest := 0.0
	var lit_floor := false

	for i in 1800:
		await get_tree().process_frame
		var out := 0
		for l in an.lights:
			if l.global_position.y > 0.1:
				out += 1
			an_highest = maxf(an_highest, l.global_position.y)
			an_farthest = maxf(an_farthest, Vector2(l.global_position.x - an_drain.x, l.global_position.z - an_drain.z).length())
		out_frames += 1 if out >= 2 else 0
		lit_floor = lit_floor or an.lamps.any(func(m): return m.light_energy > 0.2 and m.global_position.y > 0.3)
	# 3D, the Deadlock way (docs/superpowers/refs/underground/vfx_method.md): each a lathed flame mesh in an
	# eroding shell, a ribbon trailing it; no sprite cards, no particle specks.
	var no_cards: bool = an.find_children("*", "GPUParticles3D", true, false).is_empty() \
		and an.lights.all(func(l): return not (l.mesh is QuadMesh) and l.mesh.get_faces().size() >= 3 * 60)
	var ribboned: bool = an.ribbons.size() == an.lights.size() \
		and an.ribbons.any(func(r): return r.mesh != null and r.mesh.get_surface_count() > 0 and r.mesh.surface_get_array_len(0) >= 16)
	var spirited: bool = an.shells.size() == an.lights.size() and no_cards and ribboned and _all_mesh_vfx(an.lights)
	var an_near: Vector3 = an_drain + Vector3(-0.9, 1.05, 0.9)
	lab.player.global_position = an_near
	await _frames(240)
	var kept_off := true
	var still_out := 0

	for l in an.lights:
		if l.global_position.y > 0.1:
			still_out += 1
			kept_off = kept_off and Vector2(l.global_position.x - lab.player.global_position.x,
				l.global_position.z - lab.player.global_position.z).length() > 0.9
	lab.player.global_position = Vector3(8.0, 1.05, 3.0)
	_check("U52 the ánimas: two or more out most of the time, up to chest height, haloed and trailing, lighting the floor; shy but staying",
		an.lights.size() >= 6 and out_frames > 1800 * 0.6 and an_highest > 1.0 and an_highest < 1.8 and an_farthest < 4.5
		and spirited and lit_floor and kept_off and still_out >= 1,
		"count %d out-2 %.2f highest %.2f farthest %.2f spirited %s (no cards %s ribbons %s) lit %s kept off %s still out %d" % [
		an.lights.size(), out_frames / 1800.0, an_highest, an_farthest, spirited, no_cards, ribboned, lit_floor, kept_off, still_out])

	# U53 the nahual's eyes glow: bright past white (the bloom takes them), a halo round each, a faint red light
	var nd: Node3D = lab.nahual
	var glowing := false

	for i in nd.head.mesh.get_surface_count():
		var slot: Material = nd.head.mesh.surface_get_material(i)
		var drawn: Material = nd.head.get_surface_override_material(i)
		if slot != null and slot.resource_name == "ember":
			glowing = drawn is StandardMaterial3D and drawn.emission_enabled and drawn.emission_energy_multiplier >= 3.0
	_check("U53 the nahual's eyes glow: emissive past white, a halo each, a faint red light",
		glowing and nd.eye_halos.size() == 2 and nd.eye_halos.all(func(h): return h.is_visible_in_tree())
		and nd.eye_light != null and nd.eye_light.light_energy > 0.05 and nd.eye_light.light_color.r > nd.eye_light.light_color.g * 2.0,
		"glowing %s halos %d light %s" % [glowing, nd.eye_halos.size(), nd.eye_light])

	# U54 walked into, the nahual scatters into smoke (a burst of it, its body eaten away, no longer solid),
	#     and re-forms once they have stepped away
	var away_eye := Camera3D.new()
	add_child(away_eye)
	away_eye.global_position = Vector3(10.0, 3.0, 0.0)
	away_eye.look_at(Vector3(12.0, 3.0, 0.0), Vector3.UP)
	nd.watcher = away_eye
	nd.appear()
	await _frames(30)
	var whole: bool = nd.presence > 0.95 and nd.solid.collision_layer != 0
	lab.player.global_position = nd.middle() + Vector3(0.0, 1.05, -0.9)
	await _frames(90)
	var scattered: bool = nd.presence < 0.1 and nd.solid.collision_layer == 0 and nd.scattering > 0.5
	lab.player.global_position = Vector3(8.0, 1.05, 3.0)
	await _frames(300)
	var reformed: bool = nd.presence > 0.95 and nd.solid.collision_layer != 0 and nd.visible
	nd.watcher = null
	away_eye.queue_free()
	# U55 the nahual's smoke is mesh, the Deadlock way: tendrils rising off its back and a scatter of them,
	#     drawn by the shared mesh effect; no sprite cards
	var smoke_meshes: Array = nd.tendrils + nd.scatter_tendrils
	var meshed: bool = nd.find_children("*", "GPUParticles3D", true, false).is_empty() and nd.tendrils.size() >= 4 \
		and nd.scatter_tendrils.size() >= 6 and _all_mesh_vfx(smoke_meshes)
	_check("U55 the nahual's smoke is mesh tendrils (rising, and a scatter of them), no sprite cards", meshed,
		"tendrils %d scatter %d" % [nd.tendrils.size(), nd.scatter_tendrils.size()])

	_check("U54 walked into, the nahual scatters into smoke and is not solid; it re-forms once they step away",
		whole and scattered and reformed, "whole %s scattered %s reformed %s (presence %.2f)" % [whole, scattered, reformed, nd.presence])

	# U56 the procession: the dead in white, each with a lit candle, walk the marigold trail from her ofrenda
	#     into the old stone, p_facing their way, the ánimas gathering round them; then they are p_gone
	var p_pr: Node3D = lab.procession
	lab.player.global_position = Vector3(8.0, 1.05, 3.0)
	p_pr.start()
	await _frames(30)
	var p_walkers: Array = p_pr.figures
	var p_pale := true
	var p_candles_lit := true

	for f: MeshInstance3D in p_walkers:
		var p_ghost := f.get_surface_override_material(0) as ShaderMaterial
		p_pale = p_pale and p_ghost != null and p_ghost.shader.resource_path.ends_with("spectre.gdshader") \
			and (p_ghost.get_shader_parameter("ink") as Color).r > 0.6
		p_candles_lit = p_candles_lit and f.find_children("*", "OmniLight3D", true, false).any(func(l): return l.light_energy > 0.1)
	var p_lead: MeshInstance3D = p_walkers[0]
	var p_lead_from: float = p_lead.global_position.distance_to(lab.TRAIL_END)
	var p_lead_was: Vector3 = p_lead.global_position
	await _frames(180)
	var p_travel: Vector3 = (p_lead.global_position - p_lead_was) * Vector3(1, 0, 1)
	var p_facing: bool = p_travel.length() > 0.2 and p_lead.global_transform.basis.x.normalized().dot(p_travel.normalized()) > 0.7
	var p_nearer: bool = p_lead.global_position.distance_to(lab.TRAIL_END) < p_lead_from - 0.3
	var p_gathered := 0

	for i in 600:
		await get_tree().process_frame
		var p_round_them := 0
		for l in lab.animas.lights:
			if l.global_position.y > 0.1 and p_walkers.any(func(f): return Vector2(f.global_position.x - l.global_position.x,
					f.global_position.z - l.global_position.z).length() < 1.5):
				p_round_them += 1
		p_gathered = maxi(p_gathered, p_round_them)
	for i in 3600:
		await get_tree().process_frame
		if not p_pr.walking:
			break
	var p_gone: bool = not p_pr.walking and p_walkers.all(func(f): return not f.visible)
	_check("U56 the procession: 5 pale dead with lit candles walk the trail into the old stone, facing their way, ánimas round them; then gone",
		p_walkers.size() == 5 and p_pale and p_candles_lit and p_facing and p_nearer and p_gathered >= 2 and p_gone,
		"walkers %d pale %s candles %s facing %s nearer %s gathered %d gone %s" % [p_walkers.size(), p_pale, p_candles_lit, p_facing,
		p_nearer, p_gathered, p_gone])

	# U57 a shadow with no owner: a tall figure's shadow crosses the tiled wall, seen only from the corner of the
	#     eye; looked at, it is gone
	var p_sh: Node3D = lab.ownerless
	var p_watcher := Camera3D.new()
	add_child(p_watcher)
	p_sh.watcher = p_watcher
	# The p_watcher in the corridor a few metres off the wall, looking 55 degrees aside of the shadow's way.
	var p_spot: Vector3 = p_sh.crossing_middle()
	p_watcher.global_position = Vector3(p_spot.x, 1.6, p_spot.z - 3.0 if p_spot.z > 0.0 else p_spot.z + 3.0)
	var p_to_spot: Vector3 = (p_spot - p_watcher.global_position).normalized()
	p_watcher.look_at(p_watcher.global_position + p_to_spot.rotated(Vector3.UP, deg_to_rad(55.0)), Vector3.UP)
	p_sh.cross_now()
	await _frames(20)
	var p_shown: bool = p_sh.decal.visible and p_sh.decal.modulate.a > 0.5
	var p_shadow_from: Vector3 = p_sh.decal.global_position
	await _frames(40)
	var p_crossing: bool = p_sh.decal.global_position.distance_to(p_shadow_from) > 0.2
	p_watcher.look_at(p_sh.decal.global_position, Vector3.UP)
	await _frames(20)
	var p_vanished: bool = not p_sh.decal.visible or p_sh.decal.modulate.a < 0.05
	p_sh.watcher = null
	p_watcher.queue_free()
	_check("U57 a shadow with no owner crosses the wall at the corner of the eye; looked at, it is gone",
		p_shown and p_crossing and p_vanished and p_sh.decal.texture_albedo != null,
		"shown %s crossing %s vanished %s" % [p_shown, p_crossing, p_vanished])

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


## The bay's piece of furniture of a kind (the first), or null.
func _furniture(lab: Node3D, kind: String) -> MeshInstance3D:
	for piece in lab.furniture:
		if piece.get_meta("kind") == kind:
			return piece
	return null


func _solid(piece: Node3D) -> bool:
	return piece.find_children("*", "StaticBody3D", true, false).size() > 0


## Whether every one is drawn by the shared mesh effect (vfx_mesh.gdshader).
func _all_mesh_vfx(meshes: Array) -> bool:
	for mesh: MeshInstance3D in meshes:
		var look := mesh.get_surface_override_material(0) as ShaderMaterial
		if look == null or not look.shader.resource_path.ends_with("vfx_mesh.gdshader"):
			return false
	return true
