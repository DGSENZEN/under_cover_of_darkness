extends Control
## A drawn loading circle; its clock remains live while gameplay is paused.
var angle := 0.0

func _process(delta: float) -> void:
	angle += delta * 2.6
	queue_redraw()

func _draw() -> void:
	var centre := size * 0.5
	draw_arc(centre, 13, 0, TAU, 48, Color(0.85, 0.78, 0.67, 0.18), 2.0, true)
	draw_arc(centre, 13, angle, angle + TAU * 0.7, 40, Color("edcea0"), 2.5, true)
