class_name MenuMotion
## The menu's one motion: every change eases out on the same curve, so
## nothing feels mechanical. Words answer fast; paintings bloom slower.
const ANSWER := 0.2
const BLOOM := 0.6
const FADE := 0.4
const PRESS := 0.12

## A parallel tween on the shared curve (quint, easing out).
static func tween(node: Node) -> Tween:
	return node.create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
