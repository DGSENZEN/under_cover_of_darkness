extends RefCounted
## The saves on disk (the save and load spec, section 1): one folder per run
## (a playthrough, begun when an archetype is confirmed), and in it the run's
## own file and its saves:
##
##   <root>/<run_id>/run.cfg       its archetype, when it began, time played
##   <root>/<run_id>/<slot>.save   a header, then the body (store_var, no objects)
##   <root>/<run_id>/<slot>.png    the save's picture
##   <root>/last_run               the run played last (Continue follows it)
##
## Quick and auto saves keep the newest QUICK_KEEP of their kind (quick_1..3,
## auto_1..3), the oldest overwritten; named saves (named_<n>) grow as the
## player makes them. A save is written to <slot>.tmp and renamed over the
## slot, so a crash mid-write leaves the old save whole. Nothing here touches
## the scene tree: write() runs on a worker thread.

const SaveMigrations := preload("res://scripts/Save/SaveMigrations.gd")

const QUICK_KEEP := 3
## The picture is kept this wide (px).
const PICTURE_WIDTH := 480
const RUN_FILE := "run.cfg"
const LAST_RUN := "last_run"

static var _root := ""


## Where the saves are kept; a test run (a scene under res://tests/) keeps its
## own, so a suite never touches the player's.
static func root() -> String:
	if _root != "":
		return _root

	for arg in OS.get_cmdline_args():
		if arg.begins_with("res://tests/") or arg.begins_with("tests/"):
			return "user://test_saves"

	return "user://saves"


static func use_root(path: String) -> void:
	_root = path


static func _run_dir(run_id: String) -> String:
	return root().path_join(run_id)


# Runs

## A new run for `archetype`; returns its id.
static func new_run(archetype: StringName) -> String:
	var stamp := Time.get_datetime_string_from_system(false, false).replace("-", "").replace(":", "").replace("T", "_")
	var id := "run_%s_%04x" % [stamp, randi() & 0xffff]

	while DirAccess.dir_exists_absolute(_run_dir(id)):
		id = "run_%s_%04x" % [stamp, randi() & 0xffff]

	DirAccess.make_dir_recursive_absolute(_run_dir(id))
	var file := ConfigFile.new()
	file.set_value("run", "archetype", String(archetype))
	file.set_value("run", "created", int(Time.get_unix_time_from_system()))
	file.set_value("run", "played", 0.0)
	file.save(_run_dir(id).path_join(RUN_FILE))
	return id


static func set_played(run_id: String, seconds: float) -> void:
	var file := ConfigFile.new()

	if file.load(_run_dir(run_id).path_join(RUN_FILE)) != OK:
		return

	file.set_value("run", "played", seconds)
	file.save(_run_dir(run_id).path_join(RUN_FILE))


## Every run, newest first (by its newest save, else when it began):
## [{id, archetype, created, played, newest}].
static func runs() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var dir := DirAccess.open(root())

	if dir == null:
		return found

	for id in dir.get_directories():
		var file := ConfigFile.new()

		if not id.begins_with("run_") or file.load(_run_dir(id).path_join(RUN_FILE)) != OK:
			continue

		var created := int(file.get_value("run", "created", 0))
		var newest := newest_save(id)
		found.append({"id": id, "archetype": StringName(str(file.get_value("run", "archetype", ""))), "created": created,
			"played": float(file.get_value("run", "played", 0.0)), "newest": int(newest.get("date", created))})

	found.sort_custom(func(a, b): return a["newest"] > b["newest"] if a["newest"] != b["newest"] else a["created"] > b["created"])
	return found


static func delete_run(run_id: String) -> void:
	_remove_tree(_run_dir(run_id))

	if last_run() == run_id:
		set_last_run("")


static func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)

	if dir == null:
		return

	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))

	for file in dir.get_files():
		dir.remove(file)

	DirAccess.remove_absolute(path)


static func last_run() -> String:
	return FileAccess.get_file_as_string(root().path_join(LAST_RUN)).strip_edges() if FileAccess.file_exists(root().path_join(LAST_RUN)) else ""


static func set_last_run(run_id: String) -> void:
	DirAccess.make_dir_recursive_absolute(root())
	var file := FileAccess.open(root().path_join(LAST_RUN), FileAccess.WRITE)

	if file != null:
		file.store_string(run_id)


# Saves

## The run's saves, newest first: each its header plus `path`, `picture` (a
## path, or "" with none) and `readable` (false for a damaged save, or one
## from a newer build: then only `slot`, `kind` and `date` are known).
static func saves(run_id: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var folder := _run_dir(run_id)
	var dir := DirAccess.open(folder)

	if dir == null:
		return found

	for file_name in dir.get_files():
		if file_name.get_extension() != "save":
			continue

		var path := folder.path_join(file_name)
		var slot := file_name.get_basename()
		var header := read_header(path)
		var entry: Dictionary
		var ok := not header.is_empty() and SaveMigrations.readable(int(header.get("version", 0)))

		if ok:
			entry = header.duplicate()
		else:
			entry = {"slot": slot, "kind": StringName(slot.get_slice("_", 0)), "date": int(FileAccess.get_modified_time(path)), "run": run_id}

		entry["path"] = path
		var picture := folder.path_join(slot + ".png")
		entry["picture"] = picture if FileAccess.file_exists(picture) else ""
		entry["readable"] = ok
		found.append(entry)

	found.sort_custom(func(a, b): return int(a["date"]) > int(b["date"]))
	return found


## The newest save of the run that can be read, or {}.
static func newest_save(run_id: String) -> Dictionary:
	for entry in saves(run_id):
		if entry["readable"]:
			return entry

	return {}


## What Continue loads: the newest save of the run played last; if it has
## none, the newest of any run; {} with none at all.
static func continue_target() -> Dictionary:
	var last := last_run()

	if last != "":
		var newest := newest_save(last)

		if not newest.is_empty():
			return newest

	for run in runs():
		var newest := newest_save(run["id"])

		if not newest.is_empty():
			return newest

	return {}


## The slot a new save of `kind` goes into: for quick and auto the first of
## the three not yet used, else the oldest of them; for named the next number.
static func next_slot(run_id: String, kind: StringName) -> String:
	var folder := _run_dir(run_id)

	if kind == &"named":
		var most := 0

		for entry in saves(run_id):
			if String(entry["slot"]).begins_with("named_"):
				most = maxi(most, int(String(entry["slot"]).trim_prefix("named_")))

		return "named_%d" % (most + 1)

	var oldest := ""
	var oldest_date := 0

	for i in range(1, QUICK_KEEP + 1):
		var slot := "%s_%d" % [kind, i]
		var path := folder.path_join(slot + ".save")

		if not FileAccess.file_exists(path):
			return slot

		var header := read_header(path)
		var date := int(header.get("date", -1)) if not header.is_empty() else -1

		if oldest == "" or date < oldest_date:
			oldest = slot
			oldest_date = date

	return oldest


## Writes a save (safe on a worker thread): the header and body to
## <slot>.tmp, renamed over <slot>.save; then the picture, and the run as the
## one played last. On an error the old save is left as it was.
static func write(run_id: String, slot: String, header: Dictionary, body: Dictionary, picture: Image) -> Error:
	var folder := _run_dir(run_id)
	var error := DirAccess.make_dir_recursive_absolute(folder)

	if error != OK:
		return error

	var tmp := folder.path_join(slot + ".tmp")
	var file := FileAccess.open(tmp, FileAccess.WRITE)

	if file == null:
		return FileAccess.get_open_error() if FileAccess.get_open_error() != OK else ERR_CANT_CREATE

	file.store_var(header)
	file.store_var(body)
	error = file.get_error()
	file.close()

	if error != OK:
		DirAccess.remove_absolute(tmp)
		return error

	error = DirAccess.rename_absolute(tmp, folder.path_join(slot + ".save"))

	if error != OK:
		DirAccess.remove_absolute(tmp)
		return error

	if picture != null and not picture.is_empty():
		var small := picture.duplicate() as Image
		small.resize(PICTURE_WIDTH, maxi(1, int(round(PICTURE_WIDTH * float(small.get_height()) / small.get_width()))), Image.INTERPOLATE_BILINEAR)
		small.save_png(folder.path_join(slot + ".png"))

	set_last_run(run_id)
	return OK


## A save's header alone ({} when it cannot be read).
static func read_header(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null or file.get_length() < 8:
		return {}

	var header: Variant = file.get_var()
	return header if header is Dictionary and (header as Dictionary).has("version") else {}


## A save: {header, body}, the body brought up to this build's version; or
## {error} when it cannot be read.
static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		return {"error": "cannot open %s" % path}

	var header: Variant = file.get_var() if file.get_length() >= 8 else null

	if not (header is Dictionary) or not (header as Dictionary).has("version"):
		return {"error": "no header in %s" % path}

	var version := int(header["version"])

	if not SaveMigrations.readable(version):
		return {"error": "%s is version %d; this build reads up to %d" % [path, version, SaveMigrations.CURRENT]}

	var body: Variant = file.get_var() if file.get_position() < file.get_length() else null

	if not (body is Dictionary):
		return {"error": "%s is damaged" % path}

	return {"header": header, "body": SaveMigrations.migrate(body, version)}


static func delete_save(run_id: String, slot: String) -> void:
	for extension in ["save", "png", "tmp"]:
		var path := _run_dir(run_id).path_join("%s.%s" % [slot, extension])

		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
