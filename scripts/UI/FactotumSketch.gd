class_name FactotumSketch
extends Control
## One of Factotum's diagrams, drawn in over his study and wiped out again:
## anatomy (an eye in section, a skull, the bones of a hand, a heart, a
## ribcage) and the occult (a seal, a spirit's sigil, the planets' signs).
## Each is a set of strokes in a -1..1 square, inked in order, in held steps.
const KINDS := ["eye", "skull", "hand", "heart", "ribs", "seal", "sigil", "planets"]
## The occult ones are drawn in rubric red; the rest in pale ink.
const OCCULT := ["seal", "sigil", "planets"]

var kind := "eye"
var ink := Color.WHITE
## 0..1 of the strokes' whole length drawn.
var drawn := 0.0:
	set(value):
		drawn = value
		queue_redraw()
var _strokes: Array[PackedVector2Array] = []
var _total := 0.0

func configure(what: String, side: float, colour: Color) -> void:
	kind = what
	ink = colour
	size = Vector2(side, side)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strokes = strokes_for(what)
	_total = 0.0
	for stroke in _strokes:
		_total += _length(stroke)

func _draw() -> void:
	var left := drawn * _total
	var half := size * 0.5
	var width := maxf(size.x / 110.0, 1.0)
	for stroke in _strokes:
		if left <= 0.0:
			return
		var points := PackedVector2Array()
		points.append(half + stroke[0] * half)
		for i in range(1, stroke.size()):
			var step := stroke[i - 1].distance_to(stroke[i])
			if step >= left:
				points.append(half + stroke[i - 1].lerp(stroke[i], left / step) * half)
				left = 0.0
				break
			points.append(half + stroke[i] * half)
			left -= step
		if points.size() > 1:
			draw_polyline(points, ink, width, true)

static func _length(stroke: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, stroke.size()):
		total += stroke[i - 1].distance_to(stroke[i])
	return total

static func _arc(c: Vector2, r: Vector2, from: float, to: float, steps := 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(steps + 1):
		var a := lerpf(from, to, float(i) / steps)
		points.append(c + Vector2(cos(a), sin(a)) * r)
	return points

static func _circle(c: Vector2, r: float, steps := 32) -> PackedVector2Array:
	return _arc(c, Vector2(r, r), 0.0, TAU, steps)

static func _line(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b])

static func _poly(points: Array) -> PackedVector2Array:
	return PackedVector2Array(points)

## A regular star or polygon: `points` vertices on a circle, joined every `skip`.
static func _star(c: Vector2, r: float, points: int, skip: int, turn := -PI / 2.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var k := 0
	for i in range(points + 1):
		var a := turn + float(k % points) * TAU / points
		out.append(c + Vector2(cos(a), sin(a)) * r)
		k += skip
	return out

static func strokes_for(what: String) -> Array[PackedVector2Array]:
	var s: Array[PackedVector2Array] = []
	match what:
		"eye":
			# An eye in section: the globe, the cornea's bulge, the lens, the
			# retina, the optic nerve, and leaders out to the margin.
			s.append(_circle(Vector2.ZERO, 0.62, 40))
			s.append(_arc(Vector2(-0.5, 0.0), Vector2(0.3, 0.3), PI * 0.62, PI * 1.38, 16))
			s.append(_arc(Vector2(-0.4, 0.0), Vector2(0.09, 0.26), 0.0, TAU, 20))
			s.append(_line(Vector2(-0.47, -0.3), Vector2(-0.4, -0.1)))
			s.append(_line(Vector2(-0.47, 0.3), Vector2(-0.4, 0.1)))
			s.append(_arc(Vector2.ZERO, Vector2(0.55, 0.55), -PI * 0.5, PI * 0.5, 20))
			s.append(_poly([Vector2(0.6, -0.09), Vector2(0.8, -0.11), Vector2(0.98, -0.1)]))
			s.append(_poly([Vector2(0.6, 0.09), Vector2(0.8, 0.11), Vector2(0.98, 0.1)]))
			s.append(_line(Vector2(-0.4, 0.0), Vector2(-0.2, -0.85)))
			s.append(_line(Vector2(0.5, 0.3), Vector2(0.78, 0.78)))
			s.append(_line(Vector2(-0.72, 0.1), Vector2(-0.95, 0.6)))
		"skull":
			s.append(_arc(Vector2(0.0, -0.12), Vector2(0.6, 0.68), PI, TAU, 28))
			s.append(_poly([Vector2(-0.6, -0.12), Vector2(-0.56, 0.24), Vector2(-0.44, 0.42), Vector2(-0.36, 0.72), Vector2(0.0, 0.84), Vector2(0.36, 0.72), Vector2(0.44, 0.42), Vector2(0.56, 0.24), Vector2(0.6, -0.12)]))
			s.append(_arc(Vector2(-0.24, 0.04), Vector2(0.16, 0.13), 0.0, TAU, 20))
			s.append(_arc(Vector2(0.24, 0.04), Vector2(0.16, 0.13), 0.0, TAU, 20))
			s.append(_poly([Vector2(0.0, 0.18), Vector2(-0.08, 0.37), Vector2(0.0, 0.41), Vector2(0.08, 0.37), Vector2(0.0, 0.18)]))
			s.append(_line(Vector2(-0.26, 0.56), Vector2(0.26, 0.56)))
			for i in range(7):
				var x := -0.24 + i * 0.08
				s.append(_line(Vector2(x, 0.5), Vector2(x, 0.63)))
			s.append(_poly([Vector2(-0.34, -0.62), Vector2(-0.2, -0.56), Vector2(-0.1, -0.64), Vector2(0.02, -0.57), Vector2(0.14, -0.65), Vector2(0.26, -0.58), Vector2(0.36, -0.62)]))
		"hand":
			# The bones of a hand, palm up: carpals, five rays, their joints.
			for p in [Vector2(-0.18, 0.66), Vector2(-0.06, 0.62), Vector2(0.06, 0.62), Vector2(0.18, 0.66), Vector2(-0.12, 0.76), Vector2(0.04, 0.76), Vector2(0.16, 0.76)]:
				s.append(_circle(p, 0.05, 10))
			var rays := [[Vector2(-0.24, 0.56), Vector2(-0.42, 0.06), Vector2(-0.52, -0.22), Vector2(-0.58, -0.42), Vector2(-0.62, -0.56)],
					[Vector2(-0.08, 0.54), Vector2(-0.14, -0.02), Vector2(-0.18, -0.38), Vector2(-0.2, -0.62), Vector2(-0.21, -0.8)],
					[Vector2(0.06, 0.54), Vector2(0.08, -0.04), Vector2(0.09, -0.42), Vector2(0.1, -0.68), Vector2(0.1, -0.88)],
					[Vector2(0.2, 0.56), Vector2(0.3, 0.0), Vector2(0.36, -0.32), Vector2(0.4, -0.54), Vector2(0.42, -0.7)],
					[Vector2(0.28, 0.66), Vector2(0.56, 0.36), Vector2(0.74, 0.12), Vector2(0.86, -0.06)]]
			for ray in rays:
				s.append(_poly(ray))
				for j in range(1, ray.size() - 1):
					s.append(_circle(ray[j], 0.028, 8))
		"heart":
			s.append(_poly([Vector2(0.0, 0.86), Vector2(-0.3, 0.6), Vector2(-0.55, 0.28), Vector2(-0.6, -0.04), Vector2(-0.5, -0.3), Vector2(-0.24, -0.42), Vector2(-0.02, -0.3), Vector2(0.22, -0.44), Vector2(0.5, -0.32), Vector2(0.62, 0.0), Vector2(0.52, 0.36), Vector2(0.26, 0.66), Vector2(0.0, 0.86)]))
			s.append(_arc(Vector2(0.06, -0.5), Vector2(0.24, 0.22), PI, TAU, 14))
			s.append(_line(Vector2(0.3, -0.5), Vector2(0.32, -0.26)))
			s.append(_poly([Vector2(-0.16, -0.4), Vector2(-0.2, -0.66), Vector2(-0.24, -0.88)]))
			s.append(_poly([Vector2(0.02, -0.7), Vector2(0.0, -0.9)]))
			s.append(_poly([Vector2(-0.3, -0.2), Vector2(-0.12, 0.1), Vector2(0.06, 0.42), Vector2(0.02, 0.7)]))
			s.append(_poly([Vector2(0.4, -0.18), Vector2(0.3, 0.12), Vector2(0.34, 0.4)]))
		"ribs":
			s.append(_line(Vector2(0.0, -0.9), Vector2(0.0, 0.9)))
			for i in range(9):
				var y := -0.82 + i * 0.2
				s.append(_line(Vector2(-0.05, y), Vector2(0.05, y)))
			for i in range(6):
				var y := -0.62 + i * 0.22
				var reach := 0.48 + i * 0.05
				for side in [-1.0, 1.0]:
					s.append(_poly([Vector2(0.0, y), Vector2(side * reach * 0.6, y - 0.06), Vector2(side * reach, y + 0.08), Vector2(side * reach * 0.8, y + 0.26)]))
		"seal":
			s.append(_circle(Vector2.ZERO, 0.9, 48))
			s.append(_circle(Vector2.ZERO, 0.76, 44))
			s.append(_star(Vector2.ZERO, 0.76, 3, 1))
			s.append(_star(Vector2.ZERO, 0.76, 3, 1, PI / 2.0))
			for i in range(6):
				var a := -PI / 2.0 + i * TAU / 6.0
				s.append(_circle(Vector2(cos(a), sin(a)) * 0.76, 0.06, 10))
			s.append(_circle(Vector2.ZERO, 0.14, 16))
			for i in range(24):
				var a := i * TAU / 24.0
				s.append(_line(Vector2(cos(a), sin(a)) * 0.78, Vector2(cos(a), sin(a)) * 0.88))
		"sigil":
			# A spirit's sigil: a stem, a bar, a crescent, circles at its ends.
			s.append(_circle(Vector2(0.0, 0.0), 0.11, 14))
			s.append(_line(Vector2(0.0, 0.11), Vector2(0.0, 0.82)))
			s.append(_line(Vector2(-0.4, 0.42), Vector2(0.4, 0.42)))
			s.append(_circle(Vector2(-0.46, 0.42), 0.06, 10))
			s.append(_circle(Vector2(0.46, 0.42), 0.06, 10))
			s.append(_line(Vector2(0.0, -0.11), Vector2(0.0, -0.5)))
			s.append(_arc(Vector2(0.0, -0.66), Vector2(0.3, 0.3), PI * 0.15, PI * 0.85, 14))
			s.append(_poly([Vector2(0.4, 0.42), Vector2(0.58, 0.2), Vector2(0.74, 0.28)]))
			s.append(_poly([Vector2(-0.4, 0.42), Vector2(-0.6, 0.64), Vector2(-0.48, 0.76)]))
			s.append(_line(Vector2(-0.1, 0.72), Vector2(0.1, 0.92)))
			s.append(_line(Vector2(0.1, 0.72), Vector2(-0.1, 0.92)))
		"planets":
			# The seven planets' signs round a circle, joined by a heptagram.
			s.append(_circle(Vector2.ZERO, 0.62, 40))
			s.append(_star(Vector2.ZERO, 0.62, 7, 3))
			var signs := []
			for i in range(7):
				var a := -PI / 2.0 + i * TAU / 7.0
				signs.append(Vector2(cos(a), sin(a)) * 0.84)
			s.append(_circle(signs[0], 0.08, 12))
			s.append(_circle(signs[0], 0.015, 6))
			s.append(_arc(signs[1], Vector2(0.09, 0.09), PI * 0.6, PI * 1.6, 12))
			s.append(_circle(signs[2] + Vector2(0.0, -0.04), 0.06, 10))
			s.append(_line(signs[2] + Vector2(0.0, 0.02), signs[2] + Vector2(0.0, 0.14)))
			s.append(_line(signs[2] + Vector2(-0.05, 0.08), signs[2] + Vector2(0.05, 0.08)))
			s.append(_circle(signs[3] + Vector2(-0.02, 0.03), 0.06, 10))
			s.append(_poly([signs[3] + Vector2(0.02, -0.01), signs[3] + Vector2(0.1, -0.1), signs[3] + Vector2(0.04, -0.1), signs[3] + Vector2(0.1, -0.1), signs[3] + Vector2(0.1, -0.04)]))
			s.append(_poly([signs[4] + Vector2(-0.08, -0.08), signs[4] + Vector2(-0.02, -0.02), signs[4] + Vector2(-0.08, 0.04), signs[4] + Vector2(0.08, 0.04)]))
			s.append(_line(signs[4] + Vector2(0.04, -0.1), signs[4] + Vector2(0.04, 0.12)))
			s.append(_line(signs[5] + Vector2(-0.03, -0.12), signs[5] + Vector2(-0.03, 0.06)))
			s.append(_line(signs[5] + Vector2(-0.09, -0.07), signs[5] + Vector2(0.03, -0.07)))
			s.append(_arc(signs[5] + Vector2(0.03, 0.06), Vector2(0.06, 0.06), PI, PI * 2.2, 10))
			s.append(_arc(signs[6] + Vector2(0.0, -0.06), Vector2(0.06, 0.04), 0.0, PI, 8))
			s.append(_circle(signs[6] + Vector2(0.0, 0.02), 0.05, 10))
			s.append(_line(signs[6] + Vector2(0.0, 0.07), signs[6] + Vector2(0.0, 0.16)))
	return s
