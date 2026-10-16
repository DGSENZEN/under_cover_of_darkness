extends Node3D
## Ledge sweep diagnostic (investigation only, no assertions): loads a map,
## finds ledges in its real collision geometry, and drives the real player at
## each with scripted input: walk-in mantle (A), running jump-catch (B), from a
## hang shimmy left/right and pull up (C), lower from the top (D). Writes a CSV
## + JSON of every attempt to --out (default the session scratchpad) and prints
## a summary.
##   Godot --headless --fixed-fps 60 --path . res://tests/diag_ledge_sweep.tscn \
##     --quit-after 4000000 -- --map=gym|zocalo|harbour [--case=N] [--max=N]
##     [--radius=R] [--spacing=S] [--out=DIR] [--only=A,B,C,D] [--trace]
## --case=N runs one case (ids are deterministic for the same map + options)
## and prints a per-frame trace.

const MAPS := {
	"gym": "res://maps/traversal_gym.tscn",
	"zocalo": "res://maps/zocalo.tscn",
	"harbour": "res://maps/city.tscn",
}
const DEFAULT_OUT := "/private/tmp/claude-501/-Users-tinkertailorr-a-world-of-darkness-alpha/113ec6c7-d86d-443e-9954-aa0221bafa69/scratchpad"
const LOCO := 0
const MOVING := 1
const HANGING := 2
const CLIMBING := 3

var map_name := "gym"
var map: Node
var player: CharacterBody3D
var only_case := -1
var max_cases := 160
var radius := 55.0
var spacing := 2.0
var out_dir := DEFAULT_OUT
var attempts_enabled := "ABCD"
var trace := false
## --center=x,z: the sweep's middle instead of the spawn.
var center_arg := ""
var mask := 1
var rows: Array = []
var cases: Array = []
var _rec: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=")
		match kv[0]:
			"map": map_name = kv[1]
			"case": only_case = int(kv[1])
			"max": max_cases = int(kv[1])
			"radius": radius = float(kv[1])
			"spacing": spacing = float(kv[1])
			"out": out_dir = kv[1]
			"only": attempts_enabled = kv[1].replace(",", "")
			"trace": trace = true
			"center": center_arg = kv[1]
	if map_name == "gym" and not "--spacing" in " ".join(OS.get_cmdline_user_args()):
		spacing = 1.5
	if only_case >= 0:
		trace = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _load_map()
	if player == null:
		print("SWEEP: map did not load")
		get_tree().quit(2)
		return
	var t0 := Time.get_ticks_msec()
	_find_cases()
	print("SWEEP %s: %d cases (%.1f s to find)" % [map_name, cases.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	t0 = Time.get_ticks_msec()
	for c in cases:
		if only_case >= 0 and c["id"] != only_case:
			continue
		await _run_case(c)
		if int(c["id"]) % 10 == 0:
			print("  .. case %d/%d (%.0f s)" % [c["id"], cases.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	_release_all()
	_write()
	_summary()
	get_tree().quit(0)


# Loading

func _load_map() -> void:
	var scene := load(MAPS[map_name]) as PackedScene
	map = scene.instantiate()
	if "open_with_letter" in map:
		map.set("open_with_letter", false)
	add_child(map)
	for i in 30000:
		if map.get("player") != null:
			break
		await get_tree().process_frame
	if map.get("player") == null:
		return
	if map_name == "harbour" and not map.get("load_seconds"):
		await map.ready_to_play
	player = map.get("player")
	player.invulnerable = true
	player.reload_on_death = false
	player.debug_traversal = false
	mask = player.collision_mask & ~2
	await _frames(30)
	# Guards stand still and out of it (they are not climbed and would only
	# block or fight).
	var frozen := 0
	for body in map.find_children("*", "CharacterBody3D", true, false):
		if body != player:
			body.set_physics_process(false)
			body.set_process(false)
			frozen += 1
	print("SWEEP %s loaded; player at %s; froze %d bodies; player mask %d traversal_mask %d" % [map_name, player.global_position, frozen, player.collision_mask, player.traversal_mask])
	await _frames(30)


# Geometry (independent of the scanner, except capsule fits)

func _ray(from: Vector3, to: Vector3, back_faces := true) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, [player.get_rid()])
	q.hit_back_faces = back_faces
	q.hit_from_inside = false
	return get_world_3d().direct_space_state.intersect_ray(q)


func _fits(feet: Vector3, crouched := false) -> bool:
	return player.scanner.fits(feet + Vector3.UP * (1.0 + 0.03), crouched)


func _shape_name(hit: Dictionary) -> String:
	var col: Object = hit.get("collider")
	if col == null or not (col is CollisionObject3D):
		return "?"
	var co := col as CollisionObject3D
	var shape_type := "?"
	var owner_id := co.shape_find_owner(int(hit.get("shape", 0)))
	if owner_id >= 0 and co.shape_owner_get_shape_count(owner_id) > 0:
		shape_type = co.shape_owner_get_shape(owner_id, 0).get_class().replace("Shape3D", "")
	var layer_note := "" if (co.collision_layer & player.traversal_mask) != 0 else "!LAYER%d" % co.collision_layer
	var n := String(co.name)
	if co.get_parent() != null:
		n = String(co.get_parent().name) + "/" + n
	return "%s:%s%s" % [n.left(40), shape_type, layer_note]


func _center() -> Vector3:
	if center_arg != "":
		var xz := center_arg.split(",")
		return Vector3(float(xz[0]), player.global_position.y, float(xz[1]))
	return player.global_position


func _area() -> Rect2:
	var c := _center()
	if map_name == "gym":
		return Rect2(-12, -166, 140, 178)
	return Rect2(c.x - radius, c.z - radius, radius * 2.0, radius * 2.0)


func _find_cases() -> void:
	var area := _area()
	var c0 := _center()
	var y_hi := c0.y + (16.0 if map_name == "gym" else 22.0)
	var y_lo := c0.y - 14.0
	var found: Array = []
	var seen := {}
	var nx := int(area.size.x / spacing)
	var nz := int(area.size.y / spacing)
	for ix in nx + 1:
		for iz in nz + 1:
			var x := area.position.x + ix * spacing
			var z := area.position.y + iz * spacing
			if map_name != "gym" and Vector2(x - c0.x, z - c0.z).length() > radius:
				continue
			var y := y_hi
			for layer in 4:
				var hit := _ray(Vector3(x, y, z), Vector3(x, y_lo, z), false)
				if hit.is_empty():
					break
				var p: Vector3 = hit["position"]
				y = p.y - 0.25
				if (hit["normal"] as Vector3).y < 0.7 or not _fits(p):
					continue
				for k in 8:
					var a := k * TAU / 8.0
					var d := Vector3(sin(a), 0, cos(a))
					var wc := _wall_case(p, d)
					if not wc.is_empty():
						var key := "w%d_%d_%d_%d" % [roundi(wc["lip"].x / 1.2), roundi(wc["lip"].z / 1.2), roundi(wc["lip_y"] / 0.5), _dir8(wc["n"])]
						if not seen.has(key):
							seen[key] = true
							found.append(wc)
					var lc := _lower_case(p, d)
					if not lc.is_empty():
						var key2 := "l%d_%d_%d_%d" % [roundi(lc["edge"].x / 1.2), roundi(lc["edge"].z / 1.2), roundi(lc["lip_y"] / 0.5), _dir8(lc["n"])]
						if not seen.has(key2):
							seen[key2] = true
							found.append(lc)
	# Cap each band, spread evenly over the found list (deterministic).
	var bands := {}
	for f in found:
		var b: String = f["band"]
		if not bands.has(b):
			bands[b] = []
		bands[b].append(f)
	var caps := {"low": 0.3, "high": 0.3, "catch": 0.15, "lower": 0.25}
	var counts := []
	for b in ["low", "high", "catch", "lower"]:
		var list: Array = bands.get(b, [])
		var cap := maxi(int(max_cases * caps[b]), 1)
		counts.append("%s %d/%d" % [b, mini(cap, list.size()), list.size()])
		var stride := maxf(float(list.size()) / float(cap), 1.0)
		var i := 0.0
		while int(i) < list.size() and int(i / stride) < cap:
			cases.append(list[int(i)])
			i += stride
	for i in cases.size():
		cases[i]["id"] = i
	print("SWEEP %s bands (tested/found): %s" % [map_name, ", ".join(counts)])


func _dir8(n: Vector3) -> int:
	return int(round(fposmod(atan2(n.x, n.z), TAU) / (TAU / 8.0))) % 8


## A wall ahead of floor point p along d, with its lip: {} or a case.
func _wall_case(p: Vector3, d: Vector3) -> Dictionary:
	var wall := {}
	var h_hit := 0.0
	for h in [0.45, 0.9, 1.5]:
		var hit := _ray(p + Vector3.UP * h, p + Vector3.UP * h + d * 1.4)
		if not hit.is_empty():
			wall = hit
			h_hit = h
			break
	if wall.is_empty():
		return {}
	var raw: Vector3 = wall["normal"]
	if absf(raw.y) > 0.35:
		return {}
	var n := Vector3(raw.x, 0, raw.z).normalized()
	if d.dot(-n) < 0.92:
		return {}  # another direction meets it squarely
	var w: Vector3 = wall["position"]
	# Stand in front of it (where the walk-in ends up).
	var s := Vector3(w.x, p.y, w.z) + n * (0.5 + 0.25)
	var sf := _ray(s + Vector3.UP * 0.4, s - Vector3.UP * 0.4, false)
	if sf.is_empty() or (sf["normal"] as Vector3).y < 0.7:
		return {}
	var sfeet: Vector3 = sf["position"]
	if absf(sfeet.y - p.y) > 0.3 or not _fits(sfeet):
		return {}
	# March up the face till a ray along -n passes over it.
	var last_hit := w
	var top_h := -1.0
	var hh: float = h_hit
	var reach := (Vector3(w.x, 0, w.z) - Vector3(sfeet.x, 0, sfeet.z)).length() + 0.3
	while hh <= 3.8:
		var from := sfeet + Vector3.UP * hh
		var hit := _ray(from, from - n * reach)
		if hit.is_empty():
			top_h = hh
			break
		last_hit = hit["position"]
		hh += 0.1
	if top_h < 0.0:
		return {}
	var probe := Vector3(last_hit.x, 0, last_hit.z) - n * 0.08
	var lip := _ray(Vector3(probe.x, sfeet.y + top_h + 0.02, probe.z), Vector3(probe.x, sfeet.y + top_h - 0.2, probe.z), false)
	if lip.is_empty():
		return {}
	var lip_pt: Vector3 = lip["position"]
	if (lip["normal"] as Vector3).y < 0.7:
		return {}
	var L := lip_pt.y - sfeet.y
	var band := ""
	if L >= 0.5 and L < 1.3:
		band = "low"
	elif L >= 1.3 and L < 2.4:
		band = "high"
	elif L >= 2.4 and L <= 3.6:
		band = "catch"
	else:
		return {}
	# Room on top, a capsule's width past the face.
	var room := "none"
	var top_depth := 0.0
	for depth in [0.55, 0.35, 0.2]:
		var t: Vector3 = Vector3(lip_pt.x, 0, lip_pt.z) - n * depth
		var tf := _ray(Vector3(t.x, lip_pt.y + 0.3, t.z), Vector3(t.x, lip_pt.y - 0.3, t.z), false)
		if tf.is_empty() or (tf["normal"] as Vector3).y < 0.7:
			continue
		var tp: Vector3 = tf["position"]
		if _fits(tp):
			room = "stand"
		elif _fits(tp, true):
			room = "crouch"
		if room != "none":
			top_depth = depth
			break
	# Top's thickness (how far its surface goes on behind the lip).
	var thick := 1.2
	for i in range(1, 25):
		var q := Vector3(lip_pt.x, 0, lip_pt.z) - n * (0.05 * i)
		var th := _ray(Vector3(q.x, lip_pt.y + 0.1, q.z), Vector3(q.x, lip_pt.y - 0.15, q.z), false)
		if th.is_empty():
			thick = 0.05 * i
			break
	var face_hit := _ray(sfeet + Vector3.UP * minf(L - 0.15, 1.0), sfeet + Vector3.UP * minf(L - 0.15, 1.0) - n * reach)
	var anchor := Vector3(lip_pt.x, 0, lip_pt.z) + n * 0.52
	anchor.y = lip_pt.y - 1.05
	var hang_room: bool = player.scanner.fits(anchor, false)
	var ceiling := _ray(sfeet + Vector3.UP * 1.0, sfeet + Vector3.UP * 4.5)
	var head := 4.5 if ceiling.is_empty() else (ceiling["position"] as Vector3).y - sfeet.y
	return {
		"kind": "wall", "band": band, "feet": sfeet, "n": n, "wall": Vector3(last_hit.x, lip_pt.y, last_hit.z), "lip": lip_pt,
		"lip_y": lip_pt.y, "L": L, "room": room, "top_depth": top_depth, "thick": thick, "hang_room": hang_room,
		"face_ny": raw.y, "head": head, "shape": _shape_name(face_hit if not face_hit.is_empty() else wall),
	}


## An edge in front of floor point p along d with a 2-9 m drop and a face
## under it: {} or a case.
func _lower_case(p: Vector3, d: Vector3) -> Dictionary:
	var edge_k := -1.0
	var k := 0.2
	while k <= 1.4:
		var q := p + d * k
		if _ray(q + Vector3.UP * 0.2, q - Vector3.UP * 0.3, false).is_empty():
			edge_k = k
			break
		k += 0.1
	if edge_k < 0.0:
		return {}
	var beyond := p + d * (edge_k + 0.45)
	var below := _ray(beyond - Vector3.UP * 0.1, beyond - Vector3.UP * 9.0, false)
	var drop := 9.0 if below.is_empty() else p.y - (below["position"] as Vector3).y
	if drop < 2.2:
		return {}  # (the controller needs 2.15 m of air under a hang)
	# Room to swing the body out over the edge (an eave over it is no way down).
	if not player.scanner.fits(p + d * (edge_k + 0.55) + Vector3.UP * 1.03, true):
		return {}
	var from := p + d * (edge_k + 0.3) - Vector3.UP * 0.3
	var face := _ray(from, from - d * 0.9)
	if face.is_empty():
		return {}
	var raw: Vector3 = face["normal"]
	if absf(raw.y) > 0.3:
		return {}
	var m := Vector3(raw.x, 0, raw.z).normalized()
	if m.dot(d) < 0.92:
		return {}
	var fp: Vector3 = face["position"]
	var lip := _ray(Vector3(fp.x, p.y + 0.3, fp.z) - m * 0.1, Vector3(fp.x, p.y - 0.3, fp.z) - m * 0.1, false)
	var lip_y := p.y if lip.is_empty() else (lip["position"] as Vector3).y
	var stand := Vector3(fp.x, 0, fp.z) - m * 0.55
	var sf := _ray(Vector3(stand.x, lip_y + 0.3, stand.z), Vector3(stand.x, lip_y - 0.3, stand.z), false)
	if sf.is_empty() or (sf["normal"] as Vector3).y < 0.7:
		return {}
	var sfeet: Vector3 = sf["position"]
	if not _fits(sfeet):
		return {}
	var anchor := Vector3(fp.x, 0, fp.z) + m * 0.52
	anchor.y = lip_y - 1.05
	return {
		"kind": "lower", "band": "lower", "feet": sfeet, "n": m, "edge": Vector3(fp.x, lip_y, fp.z), "lip": Vector3(fp.x, lip_y, fp.z),
		"lip_y": lip_y, "L": drop, "room": "stand", "hang_room": player.scanner.fits(anchor, false), "face_ny": raw.y,
		"thick": 0.0, "head": 0.0, "top_depth": 0.0, "shape": _shape_name(face),
	}


# Driving the player

func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "sprint"]:
		_release(a)


func _yaw_for(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _place(feet: Vector3, facing: Vector3, pitch := 0.0) -> void:
	_release_all()
	await _frames(1)
	player.teleport(Transform3D(Basis(Vector3.UP, _yaw_for(facing)), feet + Vector3.UP * 1.04))
	player._set_crouched(false)
	player.neck.rotation.x = pitch
	await _frames(6)


func _new_rec(c: Dictionary, attempt: String) -> Dictionary:
	return {"case": c, "attempt": attempt, "labels": [], "states": {}, "moved": false, "hung": false, "stuck": "",
		"air": 0, "diag": "", "result": "", "detail": "", "start": player.global_position}


func _observe(r: Dictionary) -> void:
	var s: int = player.movement_state
	r["states"][s] = true
	# A move just ended on the ground: note where, and let go of the stick
	# (a held forward would walk off the far side of what was climbed).
	if r.get("last_state", -1) == MOVING and s == LOCO and not r.has("end_feet_y"):
		r["end_feet_y"] = _feet_y()
		r["end_past"] = _past_face(r["case"]) if r["case"]["kind"] == "wall" else 0.0
		_release("move_forward")
		_release("sprint")
	r["last_state"] = s
	if s == MOVING and player.current_move != null:
		r["moved"] = true
		var lbl := String(player.current_move.label)
		if r["labels"].is_empty() or r["labels"][-1] != lbl:
			r["labels"].append(lbl)
		var mv = player.current_move
		if player.move_elapsed > mv.windup_time + mv.duration + 1.0 and r["stuck"] == "":
			r["stuck"] = "move '%s' never finished (%.1f s)" % [lbl, player.move_elapsed]
	if s == HANGING:
		r["hung"] = true
	if s == LOCO and not player.is_on_floor():
		r["air"] += 1
		if r["air"] > 240 and r["stuck"] == "":
			r["stuck"] = "airborne 4 s without falling (perched) at %s vy %.2f" % [_v(player.global_position), player.velocity.y]
	else:
		r["air"] = 0
	if trace and Engine.get_physics_frames() % 5 == 0:
		print("   f%d st%d pos %s vel %s floor %s crouch %s move %s rej '%s'" % [Engine.get_physics_frames(), s, _v(player.global_position), _v(player.velocity),
			player.is_on_floor(), player.is_crouched, String(player.current_move.label) if player.current_move != null else "-", player._last_reject])


func _watch(r: Dictionary, n: int, settle := true) -> void:
	var calm := 0
	for i in n:
		await _frames(1)
		_observe(r)
		if settle and (r["moved"] or r["hung"]) and player.movement_state != MOVING and (player.movement_state == HANGING or player.is_on_floor()):
			calm += 1
			if calm > 20:
				return
		else:
			calm = 0


## What the controller's own pipeline says right now, without acting on it.
func _diag() -> String:
	var f: Vector3 = player._facing_direction()
	var prof = player.scanner.scan(f, player.velocity, not player._on_floor_now())
	if prof == null:
		return "scan: " + player.scanner.last_reject
	var out := "h %.2f th %.2f head %d far %s spd %.1f air %s" % [prof.height, prof.thickness, prof.headroom, prof.has_far_floor, prof.approach_speed, prof.airborne]
	if trace:
		var land: Vector3 = player.scanner.origin_for_feet(prof.landing)
		var lift: Vector3 = prof.face_point + prof.face_normal * 0.55
		lift.y = maxf(prof.top_point.y, prof.landing.y) + 1.12
		print("   explain scan: face %s n %s top %s landing %s | fits lift %s landing %s(c %s) | start->lift %s lift->landing %s (crouched %s %s)" % [_v(prof.face_point), _v(prof.face_normal),
			_v(prof.top_point), _v(prof.landing), player.scanner.fits(lift, false), player.scanner.fits(land, false), player.scanner.fits(land, true),
			player.scanner.motion_is_clear(player.global_position, lift, false), player.scanner.motion_is_clear(lift, land, false),
			player.scanner.motion_is_clear(player.global_position, lift, true), player.scanner.motion_is_clear(lift, land, true)])
		var line := ""
		for i in range(-4, 12):
			var q: Vector3 = Vector3(prof.face_point.x, 0, prof.face_point.z) - prof.face_normal * (i * 0.1)
			var h := _ray(Vector3(q.x, prof.feet_y + 4.0, q.z), Vector3(q.x, prof.feet_y - 1.0, q.z), false)
			line += " %+.1f:%s" % [i * 0.1, "-" if h.is_empty() else "%.2f" % (h["position"] as Vector3).y]
		print("   section behind the face (top y):", line)
	var cands = player.planner.classify(prof, player.is_crouched, player._is_sprinting(), player.variant_table)
	if cands.is_empty():
		out += " | no variant"
	for v in cands:
		var mv = player.planner.generate(prof, v, player.global_position)
		out += " | %s:%s" % [v.label, "ok" if mv != null else player.planner.last_reject]
	return out


func _feet_y() -> float:
	return player.global_position.y - 1.0


func _past_face(c: Dictionary) -> float:
	var w: Vector3 = c["wall"]
	var n: Vector3 = c["n"]
	var p := player.global_position
	return (Vector3(p.x, 0, p.z) - Vector3(w.x, 0, w.z)).dot(-n)


func _state_name(s: int) -> String:
	return ["LOCO", "MOVING", "HANGING", "CLIMBING", "SWIMMING"][s] if s < 5 else str(s)


## After an attempt ends on the ground: embedded? able to move at all?
func _stuck_check(r: Dictionary) -> void:
	if r["stuck"] != "":
		return
	if player.movement_state == MOVING:
		r["stuck"] = "still MOVING at the end ('%s', %.1f s)" % [String(player.current_move.label), player.move_elapsed]
		return
	if player.movement_state != LOCO:
		return
	if not player.scanner.fits(player.global_position, player.is_crouched):
		r["stuck"] = "capsule embedded in geometry at %s" % _v(player.global_position)
		return
	_release_all()
	await _frames(2)
	var start := player.global_position
	var best := 0.0
	for a in ["move_back", "move_left", "move_right", "move_forward"]:
		var from := player.global_position
		_press(a)
		for i in 22:
			await _frames(1)
			_observe(r)
		_release(a)
		best = maxf(best, from.distance_to(player.global_position))
		if best > 0.25 or player.movement_state != LOCO:
			break
	if best <= 0.25 and player.movement_state == LOCO:
		# One more chance: jump out.
		_press("jump")
		await _frames(2)
		_release("jump")
		for i in 20:
			await _frames(1)
		best = maxf(best, start.distance_to(player.global_position))
		if best <= 0.25:
			r["stuck"] = "wedged: cannot walk or jump away from %s (best %.2f m)" % [_v(start), best]


# Attempts

func _run_case(c: Dictionary) -> void:
	if trace:
		_section(c)
	var hang_from := ""
	if c["kind"] == "wall":
		if "A" in attempts_enabled and c["band"] != "catch":
			var r := await _attempt_walk_in(c)
			if player.movement_state == HANGING:
				hang_from = "A"
		if "B" in attempts_enabled and c["band"] != "low" and hang_from == "":
			await _attempt_jump_catch(c)
			if player.movement_state == HANGING:
				hang_from = "B"
		if "C" in attempts_enabled and (c["band"] != "low") and (hang_from != "" or c["hang_room"]):
			await _attempt_hang(c, hang_from)
	elif "D" in attempts_enabled:
		await _attempt_lower(c)


func _attempt_walk_in(c: Dictionary) -> Dictionary:
	var n: Vector3 = c["n"]
	var w: Vector3 = c["wall"]
	var start: Vector3 = c["feet"] + n * 0.45
	var sf := _ray(start + Vector3.UP * 0.4, start - Vector3.UP * 0.4, false)
	if sf.is_empty() or not _fits(sf["position"]):
		start = c["feet"]
	else:
		start = sf["position"]
	await _place(start, -n)
	var r := _new_rec(c, "A walk-in")
	_press("move_forward")
	var pressed := false
	for i in 40:
		await _frames(1)
		_observe(r)
		var dist := (Vector3(player.global_position.x, 0, player.global_position.z) - Vector3(w.x, 0, w.z)).length()
		if dist < 1.0 or i == 39:
			r["diag"] = _diag()
			_press("jump")
			pressed = true
			break
	await _frames(1)
	_observe(r)
	for i in 10:
		await _frames(1)
		_observe(r)
	_release("jump")
	await _watch(r, 140)
	_release("move_forward")
	await _watch(r, 30)
	_judge_climb(r, c)
	await _stuck_check(r)
	_finish(r)
	return r


func _attempt_jump_catch(c: Dictionary) -> Dictionary:
	var n: Vector3 = c["n"]
	var w: Vector3 = c["wall"]
	var start: Vector3 = c["feet"] + n * 2.3
	var sf := _ray(start + Vector3.UP * 0.5, start - Vector3.UP * 0.5, false)
	var run_up := true
	if sf.is_empty() or not _fits(sf["position"]) or not _ray(c["feet"] + Vector3.UP * 0.5, start + Vector3.UP * 0.5).is_empty():
		start = c["feet"]
		run_up = false
	else:
		start = sf["position"]
	await _place(start, -n)
	var r := _new_rec(c, "B jump-catch" if run_up else "B jump-catch (standing)")
	_press("move_forward")
	_press("sprint")
	for i in 60:
		await _frames(1)
		_observe(r)
		var dist := (Vector3(player.global_position.x, 0, player.global_position.z) - Vector3(w.x, 0, w.z)).length()
		if dist < 1.5 or i == 59 or not run_up:
			break
	_press("jump")
	var apex_diag := ""
	for i in 70:
		await _frames(1)
		_observe(r)
		if apex_diag == "" and player.movement_state == LOCO and player.velocity.y < 1.0 and not player.is_on_floor():
			apex_diag = _diag()
		if r["moved"] or r["hung"]:
			break
	r["diag"] = "apex: " + apex_diag
	_release("jump")
	_release("sprint")
	await _watch(r, 120)
	_release("move_forward")
	await _watch(r, 20)
	_judge_climb(r, c)
	if player.movement_state != HANGING:
		await _stuck_check(r)
	_finish(r)
	return r


func _judge_climb(r: Dictionary, c: Dictionary) -> void:
	var lip_y: float = c["lip_y"]
	var fy: float = r.get("end_feet_y", _feet_y())
	var past: float = r.get("end_past", _past_face(c))
	var on_top: bool = absf(fy - lip_y) < 0.2 and past > (0.1 if c["thick"] > 0.4 else -0.05) and player.movement_state == LOCO
	var over: bool = past > 0.3 and player.movement_state == LOCO
	var st: int = player.movement_state
	if r["stuck"] != "":
		r["result"] = "STUCK"
	elif on_top:
		r["result"] = "OK"
	elif st == HANGING:
		r["result"] = "OK_HANG" if c["band"] != "low" else "WRONG_MOVE"
	elif over:
		r["result"] = "OK_OVER"
	elif r["moved"] or r["hung"]:
		r["result"] = "WRONG_MOVE" if _feet_y() > c["feet"].y - 0.3 else "FELL"
	else:
		var possible: bool = c["room"] != "none" or (c["band"] != "low" and c["hang_room"])
		if c["band"] == "catch":
			possible = c["hang_room"]
		r["result"] = "NO_TRIGGER" if possible else "SKIP"
		if not possible:
			r["detail"] = "no room on top / to hang"


func _enter_hang_synthetic(c: Dictionary) -> bool:
	var n: Vector3 = c["n"]
	var lip: Vector3 = c["lip"]
	var anchor: Vector3 = player.planner.hang_anchor(c["wall"], n, lip.y)
	if not player.scanner.fits(anchor, false):
		return false
	_release_all()
	await _frames(1)
	player.teleport(Transform3D(Basis(Vector3.UP, _yaw_for(-n)), anchor))
	player.global_position = anchor
	player._enter_hang(n, lip.y, false)
	await _frames(3)
	return player.movement_state == HANGING


func _ledge_continues(side: Vector3) -> bool:
	var hn: Vector3 = player.hang_normal
	var hy: float = player.hang_lip_y
	var p := player.global_position + side * 0.35
	var chest := Vector3(p.x, hy - 0.1, p.z)
	var face := _ray(chest, chest - hn * 1.1)
	if face.is_empty() or absf((face["normal"] as Vector3).y) > 0.3:
		return false
	var fp: Vector3 = face["position"]
	var lip := _ray(Vector3(fp.x, hy + 0.2, fp.z) - hn * 0.08, Vector3(fp.x, hy - 0.2, fp.z) - hn * 0.08, false)
	if lip.is_empty() or absf((lip["position"] as Vector3).y - hy) > 0.12:
		return false
	var anchor := Vector3(fp.x, 0, fp.z) + hn * 0.52
	anchor.y = (lip["position"] as Vector3).y - 1.05
	return player.scanner.fits(anchor, false)


func _attempt_hang(c: Dictionary, natural: String) -> void:
	var how := natural
	if natural == "":
		if not await _enter_hang_synthetic(c):
			var r0 := _new_rec(c, "C hang (synthetic)")
			r0["result"] = "SKIP"
			r0["detail"] = "synthetic hang refused"
			_finish(r0)
			return
		how = "synthetic"
	for side in [["move_left", -1.0], ["move_right", 1.0]]:
		if player.movement_state != HANGING:
			break
		var r := _new_rec(c, "C shimmy %s (%s)" % [side[0].trim_prefix("move_"), how])
		var lateral: Vector3 = player.hang_normal.cross(Vector3.UP).normalized() * float(side[1])
		var continues := _ledge_continues(lateral)
		var before := player.global_position
		_press(side[0])
		for i in 60:
			await _frames(1)
			_observe(r)
		_release(side[0])
		await _watch(r, 90)
		var travelled := Vector3(player.global_position.x - before.x, 0, player.global_position.z - before.z).length()
		r["detail"] = "travel %.2f m, ledge continues %s" % [travelled, continues]
		if r["stuck"] != "":
			r["result"] = "STUCK"
		elif player.movement_state == LOCO:
			r["result"] = "FELL"
		elif player.movement_state == HANGING and travelled < 0.03 and continues:
			r["result"] = "STUCK"
			r["stuck"] = "shimmy does not move along a continuing ledge"
		else:
			r["result"] = "OK"
		_finish(r)
	if player.movement_state != HANGING:
		return
	var rp := _new_rec(c, "C pull up (%s)" % how)
	player.neck.rotation.x = 0.0
	var hn: Vector3 = player.hang_normal
	var hy: float = player.hang_lip_y
	var top := player.global_position - hn * 1.05
	top.y = hy
	var tf := _ray(top + Vector3.UP * 0.3, top - Vector3.UP * 0.3, false)
	var room := not tf.is_empty() and (_fits(tf["position"]) or _fits(tf["position"], true))
	if not room:
		top = player.global_position - hn * 0.75
		top.y = hy
		tf = _ray(top + Vector3.UP * 0.3, top - Vector3.UP * 0.3, false)
		room = not tf.is_empty() and (_fits(tf["position"]) or _fits(tf["position"], true))
	rp["diag"] = "pull_up probe: %s" % ("ok" if player.planner.pull_up(hn, player.global_position, hy) != null else player.planner.last_reject)
	_press("jump")
	await _frames(2)
	_observe(rp)
	_release("jump")
	await _watch(rp, 150)
	if rp["stuck"] != "":
		rp["result"] = "STUCK"
	elif player.movement_state == LOCO and absf(_feet_y() - hy) < 0.2:
		rp["result"] = "OK"
	elif player.movement_state == HANGING and not rp["moved"]:
		rp["result"] = "NO_TRIGGER" if room else "SKIP"
		rp["detail"] = "room on top %s" % room
	elif player.movement_state == HANGING:
		rp["result"] = "WRONG_MOVE"
	else:
		rp["result"] = "FELL" if _feet_y() < hy - 0.5 else "WRONG_MOVE"
	if player.movement_state == LOCO:
		await _stuck_check(rp)
		if rp["stuck"] != "":
			rp["result"] = "STUCK"
	_finish(rp)


func _attempt_lower(c: Dictionary) -> void:
	var m: Vector3 = c["n"]
	await _place(c["feet"], m, -deg_to_rad(50.0))
	var r := _new_rec(c, "D lower")
	if not c["hang_room"]:
		r["result"] = "SKIP"
		r["detail"] = "no room to hang"
		_finish(r)
		return
	r["diag"] = _lower_diag()
	if trace:
		_explain_lower()
	_press("crouch")
	await _frames(3)
	_observe(r)
	_release("crouch")
	await _watch(r, 110)
	if r["stuck"] != "":
		r["result"] = "STUCK"
	elif player.movement_state == HANGING:
		r["result"] = "OK"
	elif r["moved"]:
		r["result"] = "WRONG_MOVE" if _feet_y() > c["lip_y"] - 0.3 else "FELL"
	else:
		r["result"] = "NO_TRIGGER"
	r["detail"] = "pitch %.0f deg; crouched %s" % [rad_to_deg(player.neck.rotation.x), player.is_crouched]
	if player.movement_state == LOCO:
		await _stuck_check(r)
		if r["stuck"] != "":
			r["result"] = "STUCK"
	_finish(r)
	if player.movement_state == HANGING:
		# Back up again.
		var rp := _new_rec(c, "D pull up")
		player.neck.rotation.x = 0.0
		var hy: float = player.hang_lip_y
		rp["diag"] = "pull_up probe: %s" % ("ok" if player.planner.pull_up(player.hang_normal, player.global_position, hy) != null else player.planner.last_reject)
		_press("jump")
		await _frames(2)
		_release("jump")
		await _watch(rp, 150)
		if rp["stuck"] != "":
			rp["result"] = "STUCK"
		elif player.movement_state == LOCO and absf(_feet_y() - hy) < 0.2:
			rp["result"] = "OK"
		elif player.movement_state == HANGING and not rp["moved"]:
			rp["result"] = "NO_TRIGGER"
		else:
			rp["result"] = "WRONG_MOVE"
		if player.movement_state == LOCO:
			await _stuck_check(rp)
			if rp["stuck"] != "":
				rp["result"] = "STUCK"
		_finish(rp)


## Trace mode: a vertical section through the case along its normal: at
## each step, every surface a ray down from 6 m over the lip meets (y and
## whether it faces up or down).
func _section(c: Dictionary) -> void:
	var n: Vector3 = c["n"]
	var lip: Vector3 = c["lip"]
	print("   section case %d along -n from 1.5 m in front of the lip (offset: surfaces top->bottom, U=up-facing D=down-facing)" % c["id"])
	for i in range(-15, 11):
		var q: Vector3 = Vector3(lip.x, 0, lip.z) - n * (i * 0.1)
		var y := lip.y + 6.0
		var hits := ""
		for k in 6:
			var h := _ray(Vector3(q.x, y, q.z), Vector3(q.x, lip.y - 6.0, q.z), true)
			if h.is_empty():
				break
			var hp: Vector3 = h["position"]
			hits += " %.2f%s" % [hp.y, "U" if (h["normal"] as Vector3).y > 0.0 else "D"]
			y = hp.y - 0.01
		print("     %+.1f:%s" % [i * 0.1, hits])


## Trace mode: which leg of the lower's path is blocked, and by what.
func _explain_lower() -> void:
	var f: Vector3 = player._facing_direction()
	var needed: float = player.planner.hang_eye_drop + player._neck_stand_y + player._standing_height * 0.5 + 0.1
	var edge: Dictionary = player.scanner.edge_below(f, needed)
	if edge.is_empty():
		print("   explain: no edge")
		return
	var start := player.global_position
	var anchor: Vector3 = player.planner.hang_anchor(edge["face_point"], edge["normal"], edge["lip_y"])
	var out := Vector3(anchor.x, start.y, anchor.z)
	var sc = player.scanner
	print("   explain: start %s out %s anchor %s face %s" % [_v(start), _v(out), _v(anchor), _v(edge["face_point"])])
	for crouched in [false, true]:
		print("     crouched %s: fits start %s out %s anchor %s; start->out %s; out->anchor %s" % [crouched, sc.fits(start, crouched), sc.fits(out, crouched),
			sc.fits(anchor, crouched), sc.motion_is_clear(start, out, crouched), sc.motion_is_clear(out, anchor, crouched)])
	# What is in the way: the capsule at a few points down the out->anchor leg.
	for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var at: Vector3 = out.lerp(anchor, t)
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.48
		cap.height = 1.96
		q.shape = cap
		q.transform = Transform3D(Basis.IDENTITY, at)
		q.collision_mask = 3
		q.exclude = [player.get_rid()]
		var hits := get_world_3d().direct_space_state.get_rest_info(q)
		print("     t %.2f at %s rest %s" % [t, _v(at), "clear" if hits.is_empty() else "%s n %s on %s" % [_v(hits["point"]), _v(hits["normal"]), instance_from_id(hits["collider_id"]).name]])
	# Section through the edge along the facing: floor heights.
	var line := ""
	for i in range(-6, 8):
		var p: Vector3 = Vector3(edge["face_point"].x, 0, edge["face_point"].z) + f * (i * 0.1)
		var h := _ray(Vector3(p.x, start.y + 3.0, p.z), Vector3(p.x, start.y - 6.0, p.z), false)
		line += " %+.1f:%s" % [i * 0.1, "-" if h.is_empty() else "%.2f" % (h["position"] as Vector3).y]
	print("     section (offset from face along facing: top y):", line)


func _lower_diag() -> String:
	var f: Vector3 = player._facing_direction()
	var needed: float = player.planner.hang_eye_drop + player._neck_stand_y + player._standing_height * 0.5 + 0.1
	var edge: Dictionary = player.scanner.edge_below(f, needed)
	if edge.is_empty():
		var rail: Dictionary = player.scanner.rail_ahead(f, needed)
		return "edge_below: none; rail_ahead: %s" % ("none" if rail.is_empty() else "found")
	var mv = player.planner.lower(edge, player.global_position, player.rotation.y)
	return "edge lip %.2f n %s -> %s" % [edge["lip_y"], _v(edge["normal"]), "ok" if mv != null else player.planner.last_reject]


# Output

func _v(v: Vector3) -> String:
	return "(%.2f %.2f %.2f)" % [v.x, v.y, v.z]


func _finish(r: Dictionary) -> void:
	var c: Dictionary = r["case"]
	var states: Array = []
	for s in r["states"].keys():
		states.append(_state_name(s))
	var row := {
		"map": map_name, "case": c["id"], "kind": c["kind"], "band": c["band"], "attempt": r["attempt"], "result": r["result"],
		"x": snappedf(c["lip"].x, 0.01), "y": snappedf(c["lip_y"], 0.01), "z": snappedf(c["lip"].z, 0.01),
		"feet": _v(c["feet"]), "nx": snappedf(c["n"].x, 0.01), "nz": snappedf(c["n"].z, 0.01), "face_ny": snappedf(c["face_ny"], 0.01),
		"L": snappedf(c["L"], 0.01), "room": c["room"], "thick": snappedf(c["thick"], 0.01), "hang_room": c["hang_room"], "head": snappedf(c["head"], 0.01),
		"shape": c["shape"], "labels": "/".join(r["labels"]), "states": "/".join(states), "final_state": _state_name(player.movement_state),
		"final_pos": _v(player.global_position), "stuck": r["stuck"], "detail": r["detail"], "last_reject": player._last_reject, "diag": r["diag"],
	}
	rows.append(row)
	if trace or (row["result"] != "OK" and row["result"] != "OK_HANG" and row["result"] != "OK_OVER" and row["result"] != "SKIP"):
		print("  [%s] case %d %s %s L=%.2f lip (%.2f %.2f %.2f) n (%.2f %.2f) %s: %s | %s | %s | rej '%s' | %s" % [row["result"], c["id"], c["band"], r["attempt"],
			c["L"], c["lip"].x, c["lip_y"], c["lip"].z, c["n"].x, c["n"].z, row["shape"], row["labels"], row["stuck"], row["detail"], row["last_reject"], row["diag"]])


func _write() -> void:
	var suffix := "" if only_case < 0 else "_case%d" % only_case
	var csv := FileAccess.open(out_dir + "/ledge_sweep_%s%s.csv" % [map_name, suffix], FileAccess.WRITE)
	if csv == null:
		print("SWEEP: cannot write to ", out_dir)
		return
	var keys := ["map", "case", "kind", "band", "attempt", "result", "x", "y", "z", "feet", "nx", "nz", "face_ny", "L", "room", "thick", "hang_room", "head",
		"shape", "labels", "states", "final_state", "final_pos", "stuck", "detail", "last_reject", "diag"]
	csv.store_line(",".join(keys))
	for row in rows:
		var cells: Array = []
		for k in keys:
			cells.append("\"" + str(row[k]).replace("\"", "'") + "\"")
		csv.store_line(",".join(cells))
	csv.close()
	var js := FileAccess.open(out_dir + "/ledge_sweep_%s%s.json" % [map_name, suffix], FileAccess.WRITE)
	js.store_string(JSON.stringify(rows, " "))
	js.close()


func _summary() -> void:
	var by := {}
	for row in rows:
		var key: String = row["attempt"].split(" (")[0]
		if not by.has(key):
			by[key] = {}
		by[key][row["result"]] = int(by[key].get(row["result"], 0)) + 1
	print("\n==== LEDGE SWEEP %s: %d cases, %d attempts ====" % [map_name, cases.size() if only_case < 0 else 1, rows.size()])
	for k in by:
		print("  %-26s %s" % [k, by[k]])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Input as a real key would arrive: between physics ticks (after this
## frame's tick), so the next tick sees it pressed AND just pressed. (An
## Input.action_press from inside a tick is only "just pressed" on the tick
## after, which made buffered drop presses fire in the harness only.)
func _press(action: String) -> void:
	get_tree().process_frame.connect(func(): Input.action_press(action), CONNECT_ONE_SHOT)


func _release(action: String) -> void:
	get_tree().process_frame.connect(func(): Input.action_release(action), CONNECT_ONE_SHOT)
