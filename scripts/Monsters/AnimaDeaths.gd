extends RefCounted
## How the ravenous ánimas die: each has its own last moments before it goes limp and burns,
## acted in beats, as AnimaBody.gd's poses are. Each beat, from `at` seconds, changes what it
## names and leaves the rest. A hand is told: low (on the floor, 0..1), rear (reared right up),
## flip (over on its back), up (m), roll, curl (of its fingers), open (how far they stretch),
## shake, walk (steps a second), drag (m/s at you), snap (how quickly). A face is told: nod,
## lift, back, yaw, roll, jaw, chatter, hand or hand_l/hand_r, pitch or pitch_l/pitch_r, shut
## or shut_l/shut_r, fan, inward, shake, throat, falls, drag, snap. `limp` means nothing is
## left in it, and the heat alone moves it now. `say`: a sound, how loud, how high.
## `ignites`: when its fire catches. `crumbles`: when the ash begins to fall apart.

const TABLE := {
	&"hands": [
		# A dying spider: thrown over on its back, its fingers going, slower, then drawn in.
		{"name": &"spider", "ignites": 0.4, "crumbles": 2.5, "beats": [
			{"at": 0.0, "flip": 1.0, "up": 0.2, "low": 0.5, "curl": 0.22, "shake": 1.0, "snap": 7.0, "say": [&"anima_voice", -7.0, 1.2]},
			{"at": 0.28, "up": 0.0, "low": 1.0},
			{"at": 0.75, "shake": 0.6, "curl": 0.32},
			{"at": 1.25, "shake": 0.22, "curl": 0.5, "snap": 3.0},
			{"at": 1.7, "shake": 0.0, "curl": 0.62, "snap": 1.6, "limp": true},
		]},
		# It won't stop: it drags itself on at you, falls, and tries again, weaker.
		{"name": &"crawl", "ignites": 0.5, "crumbles": 3.0, "beats": [
			{"at": 0.0, "low": 0.35, "roll": -0.3, "curl": 0.0, "shake": 0.35, "snap": 9.0, "say": [&"anima_voice", -8.0, 0.95]},
			{"at": 0.18, "walk": 2.6, "drag": 0.9, "low": 0.22, "roll": 0.0, "shake": 0.0, "snap": 5.0},
			{"at": 0.85, "walk": 0.0, "drag": 0.0, "low": 0.9, "roll": 0.28, "open": 0.8, "shake": 0.25, "snap": 6.0},
			{"at": 1.15, "walk": 1.5, "drag": 0.42, "low": 0.62, "roll": 0.12, "shake": 0.0, "snap": 4.0, "say": [&"anima_moan", -11.0, 0.7]},
			{"at": 1.6, "walk": 0.0, "drag": 0.0, "low": 1.0, "roll": 0.42, "curl": 0.0, "open": 1.3, "snap": 3.0, "limp": true},
		]},
		# Up as far as it goes, open, as if asking; it closes on nothing, and goes over.
		{"name": &"asking", "ignites": 0.35, "crumbles": 3.0, "beats": [
			{"at": 0.0, "rear": 1.0, "low": 0.0, "curl": 0.0, "open": 1.4, "shake": 0.2, "snap": 8.0, "say": [&"anima_moan", -7.0, 0.85]},
			{"at": 0.8, "shake": 0.45, "curl": 0.12},
			{"at": 1.3, "curl": 0.98, "shake": 0.14, "snap": 6.0},
			{"at": 1.75, "rear": 0.0, "low": 1.0, "roll": 0.72, "curl": 0.56, "open": 0.0, "shake": 0.0, "snap": 3.4, "limp": true},
		]},
	],
	&"face": [
		# It screams with no breath: head back, its own hands clawing at its skull, the fire
		# coming up out of its mouth; and then its hands slide off.
		{"name": &"scream", "ignites": 0.2, "crumbles": 2.6, "beats": [
			{"at": 0.0, "nod": 0.82, "lift": 0.12, "back": 0.16, "jaw": 1.0, "hand": Vector3(0.19, -0.2, 0.12), "pitch": 1.32, "shut": 0.68, "fan": 0.55, "inward": 0.8, "shake": 0.17, "throat": 1.0, "snap": 7.0, "say": [&"anima_voice", -4.0, 0.58]},
			{"at": 0.8, "shake": 0.32},
			{"at": 1.2, "falls": true, "nod": -0.42, "lift": 0.0, "back": 0.0, "jaw": 0.8, "hand": Vector3(0.37, -0.06, -0.24), "pitch": -0.1, "shut": 0.24, "fan": 1.2, "inward": 0.0, "shake": 0.0, "roll": 0.62, "snap": 3.0, "limp": true},
		]},
		# It comes on at you: thrown back by the blow, then down, hands out, dragging itself,
		# jaw snapping; and stops with one hand still stretched out for you.
		{"name": &"reach", "ignites": 0.5, "crumbles": 3.2, "beats": [
			{"at": 0.0, "nod": 0.4, "back": 0.2, "jaw": 0.7, "hand": Vector3(0.5, 0.12, 0.12), "pitch": 0.7, "shut": 0.18, "fan": 1.5, "snap": 10.0, "say": [&"anima_voice", -7.0, 0.8]},
			{"at": 0.2, "falls": true, "nod": -0.26, "back": -0.22, "jaw": 1.0, "hand": Vector3(0.22, -0.06, -0.72), "pitch": -0.1, "shut": 0.3, "drag": 1.2, "snap": 6.0},
			{"at": 0.75, "drag": 0.0, "hand_r": Vector3(0.1, -0.1, -0.8), "hand_l": Vector3(0.42, -0.1, -0.2), "shut_r": 0.08, "shut_l": 0.9, "jaw": 0.12, "snap": 7.0},
			{"at": 1.05, "drag": 0.55, "hand_r": Vector3(0.42, -0.1, -0.2), "hand_l": Vector3(0.1, -0.1, -0.78), "shut_r": 0.9, "shut_l": 0.08, "jaw": 0.9},
			{"at": 1.42, "drag": 0.0, "jaw": 0.1, "say": [&"anima_moan", -10.0, 0.62]},
			{"at": 1.78, "hand_r": Vector3(0.46, -0.08, -0.16), "hand_l": Vector3(0.14, -0.08, -0.82), "shut_r": 0.34, "shut_l": 0.05, "jaw": 0.55, "nod": -0.46, "roll": 0.22, "fan": 1.4, "back": -0.1, "snap": 2.2, "limp": true},
		]},
		# The strings cut: its hands fall first, and it hangs there a moment looking down at
		# them, its jaw trembling, before the rest of it follows.
		{"name": &"strings", "ignites": 0.6, "crumbles": 2.7, "beats": [
			{"at": 0.0, "yaw": 0.45, "nod": -0.08, "jaw": 0.12, "hand": Vector3(0.24, -0.58, -0.05), "pitch": -1.3, "shut": 0.4, "fan": 0.5, "snap": 5.5, "say": [&"anima_moan", -8.0, 0.55]},
			{"at": 0.34, "yaw": 0.0, "nod": -0.78, "jaw": 0.42, "chatter": 0.1, "snap": 2.4},
			{"at": 1.15, "falls": true, "chatter": 0.0, "jaw": 0.72, "nod": -0.4, "roll": 0.62, "hand": Vector3(0.36, -0.05, -0.25), "pitch": -0.06, "shut": 0.14, "fan": 1.2, "snap": 2.4, "limp": true},
		]},
	],
}
