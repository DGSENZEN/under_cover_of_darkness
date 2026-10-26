extends CanvasLayer
## Root-owned transition cover: supplied art, progress bar and circle only.
## Resource progress is threaded; runtime-built maps yield through stage().
const ART := preload("res://assets/ui/main_menu/loading.png")
const Circle := preload("res://scripts/UI/LoadingCircle.gd")
var target := 0.0
var art: TextureRect
var bar: ProgressBar
var spinner: Control
var _root: Control

static func open(tree: SceneTree) -> CanvasLayer:
	var screen: CanvasLayer = (load("res://scripts/UI/ArtLoadingScreen.gd") as GDScript).new()
	screen.name = "ArtLoading"
	tree.root.add_child(screen)
	return screen

## Yield at a runtime build boundary so the cover and spinner can be drawn.
static func stage(owner: Node, fraction: float) -> void:
	var screen := owner.get_tree().root.get_node_or_null("ArtLoading")
	if screen == null:
		return
	screen.advance(fraction)
	await owner.get_tree().process_frame
	await owner.get_tree().process_frame

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(black)
	art = TextureRect.new()
	art.texture = ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(art)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 70
	bar.offset_right = -110
	bar.offset_top = -37
	bar.offset_bottom = -34
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0.8, 0.74, 0.6, 0.2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("dbb988")
	bar.add_theme_stylebox_override("background", groove)
	bar.add_theme_stylebox_override("fill", fill)
	_root.add_child(bar)
	spinner = Circle.new()
	spinner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	spinner.offset_left = -91
	spinner.offset_right = -55
	spinner.offset_top = -53
	spinner.offset_bottom = -17
	_root.add_child(spinner)

## Comes up out of the dark instead of cutting in.
func fade_in(seconds: float) -> void:
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, seconds)

func advance(fraction: float) -> void:
	target = maxf(target, clampf(fraction, 0.0, 1.0))

func _process(delta: float) -> void:
	if bar != null:
		bar.value = move_toward(bar.value, target, delta * 0.85)

## Returns an Error; on failure the old scene remains and the cover is removed.
func change_to(path: String) -> Error:
	var tree := get_tree()
	var was_paused := tree.paused
	var previous_scene := tree.current_scene.scene_file_path if tree.current_scene != null else ""
	tree.paused = true
	await tree.process_frame
	await tree.process_frame
	var error := ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if error != OK:
		tree.paused = was_paused
		queue_free()
		return error
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if not progress.is_empty():
			advance(float(progress[0]) * 0.5)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			tree.paused = was_paused
			queue_free()
			return ERR_CANT_OPEN
		await tree.process_frame
	var scene := ResourceLoader.load_threaded_get(path) as PackedScene
	advance(0.52)
	await tree.process_frame
	var city := tree.root.get_node_or_null("CityState")
	if city != null:
		city.begin()
	error = tree.change_scene_to_packed(scene)
	if error != OK:
		tree.paused = was_paused
		queue_free()
		return error
	await tree.scene_changed
	var destination := tree.current_scene
	if destination != null and "loading_complete" in destination:
		var deadline := Time.get_ticks_msec() + 60000
		while is_instance_valid(destination) and not destination.loading_complete:
			if ("loading_error" in destination and destination.loading_error != "") or Time.get_ticks_msec() >= deadline:
				if previous_scene != "":
					tree.change_scene_to_file(previous_scene)
					await tree.scene_changed
				tree.paused = was_paused
				queue_free()
				return ERR_CANT_CREATE
			await tree.process_frame
	advance(1.0)
	while bar.value < 0.999:
		await tree.process_frame
	# Warm the completed scene behind the art before revealing it.
	tree.paused = was_paused
	await tree.process_frame
	await tree.process_frame
	var fade := create_tween()
	fade.tween_property(_root, "modulate:a", 0.0, 0.45)
	await fade.finished
	queue_free()
	return OK
