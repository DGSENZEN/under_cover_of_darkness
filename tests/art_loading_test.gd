extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failed += 1

func _ready() -> void:
	var sound: GDScript = load("res://scripts/Audio/Sfx.gd")
	var constants := sound.get_script_constant_map()
	check(constants.has("LOOP_GAIN") and constants.has("BUS_SOULS"), "Metro sound interfaces are present alongside the current score")
	if not ResourceLoader.exists("res://scripts/UI/ArtLoadingScreen.gd"):
		check(false, "painted loading screen is available")
		get_tree().quit(1)
		return
	var script: GDScript = load("res://scripts/UI/ArtLoadingScreen.gd")
	var loader: CanvasLayer = script.new()
	add_child(loader)
	await get_tree().process_frame
	check(loader.art.texture.resource_path.ends_with("/loading.png"), "loading screen uses the supplied artwork")
	check(loader.bar.show_percentage == false and loader.spinner != null, "loading screen shows a bar and circle without text")
	loader.advance(0.7)
	loader.advance(0.2)
	check(loader.target >= 0.7, "loading progress never goes backwards")
	await get_tree().create_timer(0.15).timeout
	check(loader.bar.value > 0 and loader.spinner.angle > 0, "bar eases forward while the loading circle rotates")
	loader.queue_free()
	await get_tree().process_frame
	print("==== RESULTS ====")
	get_tree().quit(1 if failed else 0)
