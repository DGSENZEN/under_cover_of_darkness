extends Control
## Small unboxed ammo readout, using the HUD's ink and brass palette.
const INK := Color(0.93, 0.88, 0.78)
const DIM := Color(0.54, 0.5, 0.43)
const BRASS := Color(1.0, 0.78, 0.36)
var player: CharacterBody3D
var font: Font


func snapshot() -> Dictionary:
	if not is_instance_valid(player) or player.is_dead or not player.combat.gun_drawn():
		return {}
	var gun: Node = player.revolver
	return {"barrel": gun.barrel, "loaded": int(gun.loaded[gun.barrel]),
		"reserve": int(player.inventory.ammo.get(&"shells" if gun.barrel == &"shot" else &"rounds", 0)),
		"capacity": 1 if gun.barrel == &"shot" else int(gun.weapon().rounds), "reloading": gun.is_reloading()}


func _draw() -> void:
	var state := snapshot()
	if state.is_empty() or font == null:
		return
	var count := str(state["loaded"])
	var color := INK if int(state["loaded"]) > 0 else Color(0.85, 0.33, 0.22)
	draw_string_outline(font, Vector2(2, 31), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 4, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(2, 31), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, color)
	draw_string(font, Vector2(35, 30), "/ %d" % state["reserve"], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, DIM)
	for i in int(state["capacity"]):
		var filled := i < int(state["loaded"])
		var mark := Rect2(3 + i * 11, 43, 6, 3)
		draw_rect(mark.grow(1), Color(0, 0, 0, 0.65))
		draw_rect(mark, BRASS if filled else DIM.darkened(0.5))
	# Two short barrel strokes; the selected one is picked out in brass.
	for i in 2:
		var active: bool = (i == 1) == (state["barrel"] == &"shot")
		draw_line(Vector2(-15, 20 + i * 8), Vector2(-6, 20 + i * 8), BRASS if active else DIM, 2.0)
	if state["reloading"]:
		draw_arc(Vector2(78, 24), 5, -PI * 0.5, PI, 12, BRASS, 1.5, true)
