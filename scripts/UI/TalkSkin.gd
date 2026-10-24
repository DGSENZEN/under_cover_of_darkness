extends RefCounted
## What a character's talk box is painted with (the talk and quests spec,
## section 4, "Character skins"). TalkBox draws every skin the same way, by
## draft 28's layout; only these differ.
##
## The plain skin (plain(), every character without paintings) has none at
## all: its backdrop is painted from noise by talk_paint, its portrait is the
## live render of the shade's head, its marker a painted spike, its swipes in
## the plain colours.
##
## A painted skin (new(character_id), for a character with a skin) is the
## user's own paintings, as they painted them:
##   - assets/ui/talk/<character>.json (committed): the backdrop's crop, the
##     reading pool, where on the backdrop the swipes take their paint from,
##     the cursor's tip and tint, and where the spectral faces and their eyes
##     are, for the living painting;
##   - assets/ui/talk/<character>/ (kept out of git; tools/prepare_talk_art.py
##     makes it from originals/): backdrop.png, portrait.png, cursor.png.
## The paintings are loaded whole, given mipmaps, and only ever drawn smaller
## (filtered); a checkout without them gets the plain skin, quietly.
##
## The living painting (the spec's "The living painting") is the skin's too:
## dress_panel/dress_portrait/dress_swipe hand the paint shaders their
## paintings and the skin's numbers, and animate() moves them every frame:
## the faces breathe, their eyes glow in the shade's colour and follow its
## flare, dim and gutter, dust drifts, the panel shifts a touch with the mouse,
## and the portrait warms, greys and flickers.

## Where the skins are: <root><character>.json and <root><character>/.
## (Tests point it elsewhere.)
static var root := "res://assets/ui/talk/"

## The panel's painting (the whole of it: `crop` is the part shown), or null:
## painted from noise.
var backdrop: Texture2D = null
## The speaker, painted, or null: the live render.
var portrait: Texture2D = null
## The chosen swipe's marker (keyed), or null: a painted spike.
var cursor: Texture2D = null
## Where the cursor's tip is, down its height (0..1).
var cursor_tip := 0.685
## The cursor's colour, as draft 28 has it: its saturation (0.6, a little
## greyed), then its grey multiplied by `cursor_tint` and mixed in by
## cursor_tint_amount (the librarian's red; none for the curandera).
var cursor_saturation := 1.0
var cursor_tint := Color.WHITE
var cursor_tint_amount := 0.0

## The part of the backdrop the panel shows, in its UV (its painted frame
## cropped away; every skin's crop is 1802:1050).
var crop := Rect2(0, 0, 1, 1)

## The plain skin's panel shape (draft 28's backdrop crop, 1802 x 1050) and
## its portrait's (width over height).
var backdrop_aspect := 1802.0 / 1050.0
var portrait_aspect := 320.0 / 470.0

## The swipes' paint: rects of the backdrop in its (whole) UV (an unchosen
## swipe's dim flank, the chosen one's warm gold), used when there is one.
var dark_region := Rect2()
var warm_region := Rect2()
## The plain skin's swipe colours: dim purple, and the gold before its wash.
var paint_dark := Color(0.5, 0.38, 0.46)
var paint_warm := Color(0.62, 0.48, 0.26)

## The reading pool under the words: an ellipse's box in fractions of the
## panel (draft 28: x 60..940 of 1000, y -25%..92%).
var pool := Rect2(0.06, -0.25, 0.88, 1.17)
var pool_strength := 200.0 / 255.0

## The spectral faces that breathe, and their eyes that glow: rects in
## fractions of the panel (the crop).
var breathe: Array[Rect2] = []
var eyes: Array[Rect2] = []

## The living painting, how it answers the shade: per state, the eyes' glow,
## the portrait's warmth, grey and flicker. Eased toward at Shade's own pace.
const LIVING := {
	&"calm": {&"eye_glow": 0.1, &"warmth": 0.0, &"grey": 0.0, &"flicker": 0.0},
	&"flare": {&"eye_glow": 0.75, &"warmth": 1.0, &"grey": 0.0, &"flicker": 0.0},
	&"dim": {&"eye_glow": 0.04, &"warmth": 0.0, &"grey": 1.0, &"flicker": 0.0},
	&"gutter": {&"eye_glow": 0.4, &"warmth": 0.0, &"grey": 0.0, &"flicker": 1.0},
}
const LIVING_EASE := 4.0
## How far the panel's painting shifts with the mouse, at most (px at 1080p),
## and how fast it follows (per second, exponential).
const SHIFT_MOST := 3.0
const SHIFT_EASE := 3.0
## How many faces and eyes the paint shader takes.
const MOST_FACES := 4
const MOST_EYES := 6

var _now := {&"eye_glow": 0.1, &"warmth": 0.0, &"grey": 0.0, &"flicker": 0.0}
var _state: StringName = &"calm"
var _shift := Vector2.ZERO
var _panel_material: ShaderMaterial
var _portrait_material: ShaderMaterial


## The skin of `character_id`, painted if it has paintings, else plain.
func _init(character_id := "") -> void:
	if character_id != "" and exists(character_id):
		_load(character_id)


## Every character's without paintings.
static func plain():
	return new()


## The skin to talk to `character_id` in: theirs, or the plain one.
static func for_character(character_id: String):
	return new(character_id)


## Whether `character_id` has a painted skin here: its .json, and its backdrop
## and portrait made (tools/prepare_talk_art.py). Quiet when it has none.
static func exists(character_id: String) -> bool:
	if character_id == "":
		return false

	var folder := root + character_id + "/"
	return FileAccess.file_exists(root + character_id + ".json") and FileAccess.file_exists(folder + "backdrop.png") \
		and FileAccess.file_exists(folder + "portrait.png")


## The panel's width over its height (the crop's).
func panel_aspect() -> float:
	if backdrop == null:
		return backdrop_aspect

	return float(backdrop.get_width()) * crop.size.x / (float(backdrop.get_height()) * crop.size.y)


## The portrait's width over its height.
func face_aspect() -> float:
	return float(portrait.get_width()) / float(portrait.get_height()) if portrait != null else portrait_aspect


# Loading

func _load(character_id: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(root + character_id + ".json"))

	if not data is Dictionary:
		push_warning("TalkSkin: %s%s.json is not a skin; the plain box instead" % [root, character_id])
		return

	var folder := root + character_id + "/"
	backdrop = _painting(folder + "backdrop.png")
	portrait = _painting(folder + "portrait.png")

	if backdrop == null or portrait == null:
		backdrop = null
		portrait = null
		return

	var cursor_folder := root + String(data.get("cursor_from", character_id)) + "/"

	if FileAccess.file_exists(cursor_folder + "cursor.png"):
		cursor = _painting(cursor_folder + "cursor.png")

	# The original's size, which every pixel box in the .json is measured in.
	var size := _vector(data.get("size", []), Vector2(backdrop.get_width(), backdrop.get_height()))
	crop = _box(data.get("crop", []), size, Rect2(0, 0, 1, 1))
	dark_region = _box(data.get("dark_region", []), size, Rect2())
	warm_region = _box(data.get("warm_region", []), size, Rect2())
	var pool_box: Array = data.get("pool", [])

	if pool_box.size() == 4:
		pool = Rect2(pool_box[0], pool_box[1], float(pool_box[2]) - float(pool_box[0]), float(pool_box[3]) - float(pool_box[1]))

	pool_strength = float(data.get("pool_strength", pool_strength))
	cursor_tip = float(data.get("cursor_tip", cursor_tip))
	cursor_saturation = float(data.get("cursor_saturation", cursor_saturation))
	var tint: Array = data.get("cursor_tint", [])

	if tint.size() == 3:
		cursor_tint = Color8(int(tint[0]), int(tint[1]), int(tint[2]))

	cursor_tint_amount = float(data.get("cursor_tint_amount", 0.0))

	for r in data.get("breathe", []):
		breathe.append(Rect2(r[0], r[1], r[2], r[3]))

	for r in data.get("eyes", []):
		eyes.append(Rect2(r[0], r[1], r[2], r[3]))


## A painting at full size with its mipmaps: the imported texture's image if
## the editor has imported it, else the PNG read straight off the disk.
static func _painting(path: String) -> Texture2D:
	var image: Image = null

	if ResourceLoader.exists(path, "Texture2D"):
		var imported := load(path) as Texture2D

		if imported != null:
			image = imported.get_image()

	if image == null:
		image = Image.load_from_file(ProjectSettings.globalize_path(path))

	if image == null or image.is_empty():
		return null

	if image.is_compressed():
		image.decompress()

	if not image.has_mipmaps():
		image.generate_mipmaps()

	return ImageTexture.create_from_image(image)


static func _vector(list: Array, fallback: Vector2) -> Vector2:
	return Vector2(float(list[0]), float(list[1])) if list.size() == 2 else fallback


## A pixel box [x0, y0, x1, y1] of a picture `size` big, as a rect of its UV.
static func _box(list: Array, size: Vector2, fallback: Rect2) -> Rect2:
	if list.size() != 4:
		return fallback

	var a := Vector2(float(list[0]), float(list[1])) / size
	var b := Vector2(float(list[2]), float(list[3])) / size
	return Rect2(a, b - a)


# The paint shaders (TalkBox calls these as it builds)

## The panel's paint: the crop, and the living painting's faces and eyes in
## the shade's `colour`.
func dress_panel(material: ShaderMaterial, colour: Color) -> void:
	material.set_shader_parameter(&"crop", Vector4(crop.position.x, crop.position.y, crop.size.x, crop.size.y))

	if backdrop == null:
		return

	_panel_material = material
	material.set_shader_parameter(&"living", true)
	material.set_shader_parameter(&"dust", 1.0)
	material.set_shader_parameter(&"eye_colour", Vector3(colour.r, colour.g, colour.b))
	material.set_shader_parameter(&"breathe", _rects(breathe, MOST_FACES))
	material.set_shader_parameter(&"breathe_count", mini(breathe.size(), MOST_FACES))
	material.set_shader_parameter(&"eyes", _rects(eyes, MOST_EYES))
	material.set_shader_parameter(&"eye_count", mini(eyes.size(), MOST_EYES))
	_send()


## The portrait's paint: it warms, greys and flickers with the shade.
func dress_portrait(material: ShaderMaterial) -> void:
	if portrait == null:
		return

	_portrait_material = material
	material.set_shader_parameter(&"living", true)
	_send()


## A swipe's marker: the cursor's colour.
func dress_swipe(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"cursor_saturation", cursor_saturation)
	material.set_shader_parameter(&"cursor_tint", Vector3(cursor_tint.r, cursor_tint.g, cursor_tint.b))
	material.set_shader_parameter(&"cursor_tint_amount", cursor_tint_amount)


static func _rects(list: Array[Rect2], most: int) -> PackedVector4Array:
	var out := PackedVector4Array()

	for i in most:
		var r: Rect2 = list[i] if i < list.size() else Rect2()
		out.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))

	return out


# The living painting

## The shade shows `state` now (Shade.shade_state(): calm, flare, dim, gutter).
func cue(state: StringName) -> void:
	if LIVING.has(state):
		_state = state


## Every frame: eases toward the shade's state, and the panel toward the
## mouse (`mouse`: -1..1 across the screen each way).
func animate(delta: float, state: StringName, mouse: Vector2) -> void:
	cue(state)
	var target: Dictionary = LIVING[_state]
	var k := 1.0 - exp(-LIVING_EASE * delta)

	for key in target:
		_now[key] = lerpf(float(_now[key]), float(target[key]), k)

	var want := mouse.limit_length(1.0) * SHIFT_MOST
	_shift = _shift.lerp(want, 1.0 - exp(-SHIFT_EASE * delta))
	_send()


func _send() -> void:
	if _panel_material != null:
		_panel_material.set_shader_parameter(&"eye_glow", _now[&"eye_glow"])
		_panel_material.set_shader_parameter(&"eye_flicker", _now[&"flicker"])
		_panel_material.set_shader_parameter(&"shift", _shift)

	if _portrait_material != null:
		_portrait_material.set_shader_parameter(&"warmth", _now[&"warmth"])
		_portrait_material.set_shader_parameter(&"grey", _now[&"grey"])
		_portrait_material.set_shader_parameter(&"flicker", _now[&"flicker"])
