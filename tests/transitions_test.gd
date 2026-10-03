extends Node3D
## Districts as maps (the districts-as-maps plan): each district's map by
## itself (T1-T2), then the mission travelling between them through their
## gates, remembered and followed (T3-T12).
##   Godot --headless --fixed-fps 60 --path . res://tests/transitions_test.tscn

const OLD_TOWN := preload("res://maps/old_town.tscn")
const HARBOUR := preload("res://maps/city.tscn")
const LevelLoader := preload("res://scripts/Level/LevelLoader.gd")

## The harbour's load before its navmesh was baked offline (s).
const HARBOUR_LOAD_BEFORE := 13.8

var results: Array[String] = []


func _ready() -> void:
	await _alone()
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


# ---------------------------------------------------------------------------
# T1-T2: each district's map by itself
# ---------------------------------------------------------------------------

func _alone() -> void:
	var old: Node = OLD_TOWN.instantiate()
	add_child(old)
	await old.ready_to_play
	var start: Transform3D = old.marker("old_town_start").get("transform", Transform3D())
	var at_start: bool = old.player.global_position.distance_to(start.origin + Vector3.UP * 1.05) < 1.0
	var proxy: bool = old.get_node_or_null("city_harbour_proxy") != null
	var massing: Node = old.get_node_or_null("city_massing")
	var no_own_massing: bool = massing != null and massing.get_node_or_null("old_town") == null and massing.get_node_or_null("cathedral") != null
	_check("T1 the stand-in old town loads by itself: at its spawn, the harbour drawn by its proxy, its own massing left out, its navmesh from file",
		at_start and proxy and no_own_massing and bool(old.baker.from_file), "at spawn %s, harbour proxy %s, own massing out %s, from file %s" % [
			at_start, proxy, no_own_massing, old.baker.from_file])
	old.queue_free()
	await _frames(5)

	var harbour: Node = HARBOUR.instantiate()
	add_child(harbour)
	await harbour.ready_to_play
	var quick: bool = bool(harbour.baker.from_file) and float(harbour.load_seconds) < HARBOUR_LOAD_BEFORE
	var loaded_in: float = harbour.load_seconds
	var saved: String = harbour.navmesh_dir.path_join("harbour.scn")
	harbour.queue_free()
	await _frames(5)

	# The same file, its hash no longer the export's: the map bakes live.
	var stale_dir := "user://stale_nav"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stale_dir))
	var snap: Node = (ResourceLoader.load(saved, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	snap.set_meta(&"source_hash", "an older export")
	var packed := PackedScene.new()
	packed.pack(snap)
	ResourceSaver.save(packed, stale_dir.path_join("harbour.scn"))
	snap.free()
	var again: Node = HARBOUR.instantiate()
	again.set("navmesh_dir", stale_dir)
	add_child(again)
	await again.ready_to_play
	var live: bool = not bool(again.baker.from_file) and bool(again.baker.is_baked)
	_check("T2 the harbour loads its saved navmesh, faster than before; a stale one is baked live instead",
		quick and live, "from file %s in %.1f s (was %.1f s); stale baked live %s" % [quick, loaded_in, HARBOUR_LOAD_BEFORE, live])
	again.queue_free()
	await _frames(5)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * Engine.physics_ticks_per_second))


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
