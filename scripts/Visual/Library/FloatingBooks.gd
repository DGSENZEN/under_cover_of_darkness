extends Node3D
## Books floating under the librarian's vault (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "six to ten
## drifting slowly under the vault, turning their pages; a few return to the shelves and others leave them, so the
## room never looks the same"). Eight of the live book's own parts (LiveBook, its proximity off), each hung like a tent
## from its spine with its pages toward whoever is below, fanning slowly as it goes; on nested rings round the shop at
## their own heights, so none ever meets another, each swaying and wandering a little on its own. Two of them, now
## and then, come down to a place kept empty for them on a shelf (the chronology case's, the metaphysics case's), lie
## there shut a while, and rise to their ring again. Positions in the shop's frame.

const LIVE_HINGE := Vector3(-0.012, 0.0, 0.03)
## The rings: across, along (the shop's x, z), how high, how fast round (rad/s); two books on each, opposite.
const MIDDLE := Vector3(0.0, 0.0, -2.9)
const RINGS := [[0.9, 0.7, 3.3, 0.22], [1.5, 1.1, 2.9, -0.17], [2.1, 1.5, 3.4, 0.13], [2.6, 1.9, 2.75, -0.11]]
## The places they come down to: the case, its board (from the floor), along it (m), the book's middle there.
const TRANSFERS := [["chronology", 4, -0.5], ["metaphysics", 4, 0.4]]
## Coming down: how near (in plan, m) its ring must bring it to its place first, how long aloft before it may.
const NEAR := 2.0
const ALOFT := Vector2(14.0, 30.0)
## How long the way down and up takes, the slide on and off the board, the rest there.
const DESCEND := 3.2
const SLIDE := 1.4
const REST := Vector2(10.0, 22.0)
## How far before the case's face it comes level with its board.
const FRONT := 0.32

var books: Array[LiveBook] = []
var _rings: Array[int] = []
var _phases := PackedFloat32Array()
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
## The transfer books: their index, their place, state and its clock.
var _transfer := {}


## Eight books from the live book's `meshes` in `look`; their places on `lab`'s cases.
func build(lab: Node3D, meshes: Dictionary, look: Material) -> void:
	name = "floating"
	_rng.seed = 404
	for i in 8:
		var book := LiveBook.new()
		book.name = "floating_%d" % i
		book.seed = 500 + i * 7
		add_child(book)
		book.build(meshes, look, LIVE_HINGE)
		book.set_process(false)
		book.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		books.append(book)
		_rings.append(i / 2)
		_phases.append(PI * float(i % 2) + float(i / 2) * 0.9)

	var boards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(lab.SHELF_BOARDS))
	for t in TRANSFERS.size():
		var spec: Array = TRANSFERS[t]
		var case: Node3D = lab.sections.get(spec[0])
		if case == null:
			continue
		var b: Array = boards["shelf_" + spec[0]][spec[1]]
		var rest := case.transform * Transform3D(Basis(), Vector3(float(spec[2]) - 0.12, b[2] + LIVE_HINGE.z + 0.002, (b[3] + b[4]) / 2.0))
		var front := Transform3D(rest.basis, rest.origin + case.transform.basis.z.normalized() * FRONT + Vector3(0.0, 0.06, 0.0))
		# (The outer ring's two books.)
		var k := 6 + t
		_transfer[k] = {"case": case, "top": b[2], "x": float(spec[2]), "rest": rest, "front": front, "state": &"aloft",
			"clock": 0.0, "wait": _rng.randf_range(ALOFT.x, ALOFT.y), "rest_for": 0.0, "from": Transform3D()}
	_place(0.0)


## The places kept empty for books coming down (case, board, along), for the shelf filler to keep clear.
static func kept_runs() -> Array:
	return TRANSFERS


## The books that come down to the shelves.
func transfers() -> Array:
	return _transfer.keys()


## What book `k` is doing: aloft, descending, resting, rising.
func state_of(k: int) -> StringName:
	return _transfer[k]["state"] if _transfer.has(k) else &"aloft"


func slot_of(k: int) -> Dictionary:
	return _transfer.get(k, {})


func rest_of(k: int) -> Transform3D:
	return _transfer[k]["rest"]


## Book `k` comes down now (wherever its ring has it), rests a short while and rises.
func come_home(k: int) -> void:
	var t: Dictionary = _transfer[k]
	t["state"] = &"descending"
	t["clock"] = 0.0
	t["from"] = books[k].transform
	t["rest_for"] = 3.0


func _process(delta: float) -> void:
	_clock += delta
	_place(delta)


func _place(delta: float) -> void:
	for k in books.size():
		var book := books[k]
		book._clock = _clock
		var aloft := _aloft(k, _clock)
		if not _transfer.has(k):
			book.transform = aloft
			book.open = _fan(k)
			book._pose()
			continue

		var t: Dictionary = _transfer[k]
		t["clock"] += delta
		match t["state"]:
			&"aloft":
				book.transform = aloft
				book.open = _fan(k)
				t["wait"] -= delta
				var gap := Vector2(aloft.origin.x - t["front"].origin.x, aloft.origin.z - t["front"].origin.z).length()
				if t["wait"] <= 0.0 and gap < NEAR:
					t["state"] = &"descending"
					t["clock"] = 0.0
					t["from"] = aloft
					t["rest_for"] = _rng.randf_range(REST.x, REST.y)
			&"descending":
				# Down to before its place, shutting, then onto the board.
				var u: float = t["clock"] / DESCEND
				if u < 1.0:
					book.transform = _between(t["from"], t["front"], smoothstep(0.0, 1.0, u))
					book.open = lerpf(_fan(k), 0.0, smoothstep(0.0, 0.8, u))
				else:
					var v := clampf((t["clock"] - DESCEND) / SLIDE, 0.0, 1.0)
					book.transform = _between(t["front"], t["rest"], smoothstep(0.0, 1.0, v))
					book.open = 0.0
					if v >= 1.0:
						t["state"] = &"resting"
						t["clock"] = 0.0
			&"resting":
				book.transform = t["rest"]
				book.open = 0.0
				# Up again once its rest is over and its ring brings its place near.
				var gap := Vector2(aloft.origin.x - t["front"].origin.x, aloft.origin.z - t["front"].origin.z).length()
				if t["clock"] >= t["rest_for"] and gap < NEAR:
					t["state"] = &"rising"
					t["clock"] = 0.0
			&"rising":
				# Off the board, then up to its ring where it is now (the ring goes on turning meanwhile).
				if t["clock"] < SLIDE:
					book.transform = _between(t["rest"], t["front"], smoothstep(0.0, 1.0, t["clock"] / SLIDE))
					book.open = 0.0
				else:
					var u := clampf((t["clock"] - SLIDE) / DESCEND, 0.0, 1.0)
					book.transform = _between(t["front"], aloft, smoothstep(0.0, 1.0, u))
					book.open = lerpf(0.0, _fan(k), smoothstep(0.2, 1.0, u))
					if u >= 1.0:
						t["state"] = &"aloft"
						t["clock"] = 0.0
						t["wait"] = _rng.randf_range(ALOFT.x, ALOFT.y)
		book._pose()


## Book `k` aloft at `time`: on its ring, wandering and bobbing a little, hung from its spine like a tent with its pages
## down, its spine along the way it goes, tilting into its turns.
func _aloft(k: int, time: float) -> Transform3D:
	var ring: Array = RINGS[_rings[k]]
	var a: float = _phases[k] + time * float(ring[3])
	var wander := 1.0 + 0.03 * sin(time * 0.37 + k * 1.3)
	var at := MIDDLE + Vector3(cos(a) * float(ring[0]) * wander, float(ring[2]) + 0.05 * sin(time * 0.8 + k), sin(a) * float(ring[1]) * wander)
	var ahead := Vector3(-sin(a) * float(ring[0]), 0.0, cos(a) * float(ring[1])).normalized() * signf(float(ring[3]))
	var yaw := atan2(ahead.x, ahead.z)
	var turn := PI * smoothstep(0.0, 1.0, _fan(k))
	# (Rolled about its spine so its halves hang evenly either side, pages down.)
	var roll := -PI / 2.0 - turn / 2.0
	var bank := 0.12 * signf(float(ring[3])) + 0.05 * sin(time * 0.6 + k)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, bank) * Basis(Vector3.BACK, roll)
	return Transform3D(basis, at)


## How open book `k`'s pages are aloft: fanning slowly, each on its own beat.
func _fan(k: int) -> float:
	return 0.5 + 0.18 * sin(_clock * (0.9 + k * 0.07) + k * 1.9)


static func _between(a: Transform3D, b: Transform3D, t: float) -> Transform3D:
	var q := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), t)
	return Transform3D(Basis(q), a.origin.lerp(b.origin, t))
