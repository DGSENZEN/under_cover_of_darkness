extends Node
## The save files on disk (the save and load spec, sections 1 and 8): runs,
## the slots and their rotation, writing through a .tmp, headers read alone,
## deleting, Continue's choice, unreadable and newer saves (F1-F13); a write
## that comes up short leaves the old save (F14); Continue passes over a save
## whose body is damaged (F15); saves a moment apart keep their order (F16);
## a run deleted while played comes back with its next save (F17).
##   Godot --headless --fixed-fps 60 --path . res://tests/save_files_test.tscn

const SaveFiles := preload("res://scripts/Save/SaveFiles.gd")
const SaveMigrations := preload("res://scripts/Save/SaveMigrations.gd")

const ROOT := "user://test_saves"
## A version-1 save kept in the repository: every later version must still read it.
const V1_FIXTURE := "res://tests/fixtures/save/v1.save"

var results: Array[String] = []


func _ready() -> void:
	SaveFiles.use_root(ROOT)
	_f1_new_run()
	_f2_round_trip()
	_f3_header_alone()
	_f4_quick_rotation()
	_f5_auto_rotation()
	_f6_named_grow()
	_f7_newest_first()
	_f8_delete_moves_continue()
	_f9_unwritable()
	_f10_truncated()
	_f11_newer_version()
	_f12_runs_apart()
	_f13_version_one()
	_f14_short_write()
	_f15_damaged_body()
	_f16_same_second()
	_f17_run_deleted_mid_play()
	_wipe()
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


func _header(run_id: String, slot: String, kind: StringName, date: int) -> Dictionary:
	return {"version": SaveMigrations.CURRENT, "run": run_id, "slot": slot, "kind": kind, "name": "", "map": "res://maps/metro.tscn",
		"place": "the Metro", "archetype": &"derive", "date": date, "played": 12.5}


func _picture() -> Image:
	return Image.create(960, 540, false, Image.FORMAT_RGB8)


## Writes a save of `kind` into its next slot, dated `date`.
func _save(run_id: String, kind: StringName, date: int, body := {"n": 1}) -> String:
	var slot := SaveFiles.next_slot(run_id, kind)
	SaveFiles.write(run_id, slot, _header(run_id, slot, kind, date), body, _picture())
	return slot


func _wipe() -> void:
	_remove(ProjectSettings.globalize_path(ROOT))


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)

	if dir == null:
		return

	for sub in dir.get_directories():
		_remove(path.path_join(sub))

	for file in dir.get_files():
		dir.remove(file)

	DirAccess.remove_absolute(path)


func _f1_new_run() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"derive")
	var runs := SaveFiles.runs()
	_check("F1 new run", runs.size() == 1 and runs[0]["id"] == id and runs[0]["archetype"] == &"derive" and id.begins_with("run_"),
		"%s %s" % [id, runs])


func _f2_round_trip() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"thaumaturge")
	var body := {"at": Transform3D(Basis(Vector3.UP, 0.7), Vector3(1.5, -2.25, 3.0)), &"name": [1, "two", Vector3(0.1, 0.2, 0.3), {"deep": &"x"}]}
	var slot := _save(id, &"named", 100, body)
	var back := SaveFiles.read(SaveFiles.root().path_join(id).path_join(slot + ".save"))
	_check("F2 round trip", not back.has("error") and back["body"] == body and back["header"]["slot"] == slot, str(back.get("error", "")))


func _f3_header_alone() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"derive")
	var junk := PackedByteArray()
	junk.resize(5 * 1024 * 1024)
	var slot := _save(id, &"named", 100, {"junk": junk})
	var started := Time.get_ticks_usec()
	var header := SaveFiles.read_header(SaveFiles.root().path_join(id).path_join(slot + ".save"))
	var took := (Time.get_ticks_usec() - started) / 1000.0
	_check("F3 header alone", header.get("slot") == slot and not header.has("body") and took < 50.0, "%.2f ms" % took)


func _f4_quick_rotation() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"derive")

	for date in [10, 20, 30, 40]:
		_save(id, &"quick", date)

	var quick := SaveFiles.saves(id).filter(func(s): return s["kind"] == &"quick")
	var slots := quick.map(func(s): return s["slot"])
	slots.sort()
	var dates := quick.map(func(s): return s["date"])
	_check("F4 quick keeps 3", slots == ["quick_1", "quick_2", "quick_3"] and not dates.has(10) and dates.has(40), "%s %s" % [slots, dates])


func _f5_auto_rotation() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"derive")

	for date in [10, 20, 30, 40, 50]:
		_save(id, &"auto", date)

	var auto := SaveFiles.saves(id).filter(func(s): return s["kind"] == &"auto")
	var dates := auto.map(func(s): return s["date"])
	_check("F5 auto keeps 3", auto.size() == 3 and dates == [50, 40, 30], str(dates))


func _f6_named_grow() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"derive")
	var slots := []

	for date in range(1, 6):
		slots.append(_save(id, &"named", date))

	_check("F6 named grow", slots == ["named_1", "named_2", "named_3", "named_4", "named_5"] and SaveFiles.saves(id).size() == 5, str(slots))


func _f7_newest_first() -> void:
	_wipe()
	var old_run := SaveFiles.new_run(&"derive")
	var new_run := SaveFiles.new_run(&"factotum")
	_save(old_run, &"named", 500)
	_save(new_run, &"named", 100)
	_save(new_run, &"quick", 200)
	SaveFiles.set_last_run(new_run)
	var dates := SaveFiles.saves(new_run).map(func(s): return s["date"])
	var target := SaveFiles.continue_target()
	_check("F7 newest first", dates == [200, 100] and target.get("run") == new_run and target.get("date") == 200 and SaveFiles.runs()[0]["id"] == old_run,
		"%s %s" % [dates, target])


func _f8_delete_moves_continue() -> void:
	_wipe()
	var a := SaveFiles.new_run(&"derive")
	var b := SaveFiles.new_run(&"factotum")
	_save(a, &"named", 100)
	_save(b, &"named", 200)
	SaveFiles.set_last_run(b)
	SaveFiles.delete_run(b)
	var after_one := SaveFiles.continue_target()
	SaveFiles.delete_run(a)
	var after_all := SaveFiles.continue_target()
	_check("F8 delete moves continue", after_one.get("run") == a and after_all.is_empty() and SaveFiles.runs().is_empty(), "%s %s" % [after_one, after_all])


func _f9_unwritable() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"derive")
	var slot := _save(id, &"named", 100, {"first": true})
	var path := SaveFiles.root().path_join(id).path_join(slot + ".save")
	var before := FileAccess.get_file_as_bytes(path)
	# A folder where the slot's .tmp must go: the write cannot happen.
	DirAccess.make_dir_recursive_absolute(SaveFiles.root().path_join(id).path_join(slot + ".tmp"))
	var error := SaveFiles.write(id, slot, _header(id, slot, &"named", 200), {"second": true}, _picture())
	DirAccess.remove_absolute(SaveFiles.root().path_join(id).path_join(slot + ".tmp"))
	_check("F9 unwritable", error != OK and FileAccess.get_file_as_bytes(path) == before, "%s" % error)


func _f10_truncated() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"derive")
	_save(id, &"named", 100)
	var bad := _save(id, &"named", 200)
	var path := SaveFiles.root().path_join(id).path_join(bad + ".save")
	var bytes := FileAccess.get_file_as_bytes(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes.slice(0, 12))
	file.close()
	SaveFiles.set_last_run(id)
	var listed := SaveFiles.saves(id)
	var bad_entry: Array = listed.filter(func(s): return s["slot"] == bad)
	var target := SaveFiles.continue_target()
	_check("F10 truncated", listed.size() == 2 and bad_entry.size() == 1 and bad_entry[0]["readable"] == false and target.get("slot") == "named_1",
		"%s %s" % [listed, target])


func _f11_newer_version() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"derive")
	var header := _header(id, "named_1", &"named", 100)
	header["version"] = SaveMigrations.CURRENT + 1
	SaveFiles.write(id, "named_1", header, {"n": 1}, _picture())
	var path := SaveFiles.root().path_join(id).path_join("named_1.save")
	var listed := SaveFiles.saves(id)
	var back := SaveFiles.read(path)
	_check("F11 newer refused", listed.size() == 1 and listed[0]["readable"] == false and back.has("error") and not SaveMigrations.readable(SaveMigrations.CURRENT + 1),
		"%s" % back)


func _f12_runs_apart() -> void:
	_wipe()
	var a := SaveFiles.new_run(&"derive")
	var b := SaveFiles.new_run(&"thaumaturge")

	for date in [10, 20, 30]:
		_save(a, &"quick", date)

	for date in [40, 50, 60, 70]:
		_save(b, &"quick", date)

	var a_dates := SaveFiles.saves(a).map(func(s): return s["date"])
	_check("F12 runs apart", a_dates == [30, 20, 10] and SaveFiles.saves(b).size() == 3, str(a_dates))


func _f13_version_one() -> void:
	_wipe()
	if not FileAccess.file_exists(V1_FIXTURE):
		# Written once, by the first run of this suite, then committed.
		var file := FileAccess.open(V1_FIXTURE, FileAccess.WRITE)
		file.store_var(_header("run_fixture", "named_1", &"named", 100))
		file.store_var({"version": 1, "map": "res://maps/metro.tscn", "city": {"run": "run_fixture"}, "saveables": {"a/b": {"open": true}}})
		file.close()

	var back := SaveFiles.read(V1_FIXTURE)
	_check("F13 version 1 reads", not back.has("error") and back["header"]["version"] == 1 and back["body"]["saveables"]["a/b"]["open"] == true, str(back))


func _f14_short_write() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"derive")
	var slot := _save(id, &"named", 100, {"first": true})
	var path := SaveFiles.root().path_join(id).path_join(slot + ".save")
	var before := FileAccess.get_file_as_bytes(path)
	# The disk takes half of what was written (a full disk).
	SaveFiles.short_write_for_test = true
	var error := SaveFiles.write(id, slot, _header(id, slot, &"named", 200), {"second": PackedByteArray([1, 2, 3]).duplicate(), "pad": "x".repeat(4000)}, _picture())
	SaveFiles.short_write_for_test = false
	_check("F14 a write that comes up short leaves the old save whole", error != OK and FileAccess.get_file_as_bytes(path) == before, "%s" % error)


func _f15_damaged_body() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"derive")
	_save(id, &"named", 100, {"good": true})
	var bad := _save(id, &"named", 200, {"pad": "x".repeat(4000)})
	var path := SaveFiles.root().path_join(id).path_join(bad + ".save")
	var bytes := FileAccess.get_file_as_bytes(path)
	# The header whole, the body cut off.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes.slice(0, bytes.size() - 2000))
	file.close()
	SaveFiles.set_last_run(id)
	var target := SaveFiles.continue_target()
	_check("F15 Continue passes over a save whose body is damaged", target.get("slot") == "named_1", str(target.get("slot")))


func _f16_same_second() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"derive")

	for date in [100.1, 100.4, 100.7, 100.9]:
		_save(id, &"quick", 0, {"at": date})
		var slot: String = SaveFiles.saves(id).filter(func(s): return s["date"] == 0)[0]["slot"]
		var header := _header(id, slot, &"quick", 0)
		header["date"] = date
		SaveFiles.write(id, slot, header, {"at": date}, null)

	var dates := SaveFiles.saves(id).map(func(s): return s["date"])
	_check("F16 saves a moment apart keep their order; the oldest is the one written over", dates == [100.9, 100.7, 100.4], str(dates))


func _f17_run_deleted_mid_play() -> void:
	_wipe()
	var id := SaveFiles.new_run(&"factotum")
	_save(id, &"quick", 100)
	SaveFiles.delete_run(id)
	_save(id, &"quick", 200)
	var runs := SaveFiles.runs()
	_check("F17 a run deleted while played comes back with its next save", runs.size() == 1 and runs[0]["id"] == id and runs[0]["archetype"] == &"derive",
		str(runs))


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
