extends Node3D
## The room's real light comes from its books. These lights intentionally
## illuminate the lightgem probe; transient spectre flashes use fx_light instead.

const COLOURS := {
	&"chronology": Color("e5ae48"), &"necromancy": Color("b2ea3a"),
	&"alchemy": Color("ef8b40"), &"metaphysics": Color("a486ed"), &"hunting": Color("d55b55"),
}
const NOVEL_COLOURS := [Color("73bedc"), Color("db83ba"), Color("80c8a4")]
const SECTION_ENERGY := 0.32
const BOOK_ENERGY := 0.45
## An open book's light: the page's white tinted by its colour, its reach short, shadowed (the table or lectern under
## it cuts it off; unshadowed, it printed a full coloured disc on the wall behind).
const PAGE_WHITE := Color(1.0, 0.93, 0.82)
const PAGE_TINT := 0.5
const PAGE_REACH := 1.15
const PAGE_FALLOFF := 2.6
const CAGE_ENERGY := 0.38
## How much of the cage's glow lifts the caged paper itself (the rest runs in its seams).
const CAGE_LIFT := 0.15
const BookRadiance := preload("res://scripts/Visual/Library/BookRadiance.gd")
const PAGE_RADIANCE := preload("res://scripts/Visual/Library/page_radiance.gdshader")

var section_lights := {}
var book_lights: Array[OmniLight3D] = []
var cage_light: OmniLight3D
var enabled := true
var _inspecting := false
var _clock := 0.0
var _projections: Array = []
var _page_looks: Array = []
var _cage_looks: Array[ShaderMaterial] = []
var cage_radiance: Array[Node3D] = []
var section_radiance := {}


func build(lab: Node3D) -> void:
	process_priority = 10
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_projections = lab.effects.projections
	for section: StringName in COLOURS:
		if not lab.sections.has(section):
			continue
		var shelf: MeshInstance3D = lab.sections[section]
		var light := _light("section_%s" % section, COLOURS[section], 2.0)
		light.global_position = shelf.to_global(Vector3(0.0, 1.45, 0.14))
		section_lights[section] = light
		_section_aura(lab, section, shelf)

	var novel := 0
	for i in lab.live_books.size():
		var book: LiveBook = lab.live_books[i]
		var colour: Color = COLOURS.get(book.section, COLOURS[&"metaphysics"])
		if book.kind == LiveBook.Kind.NOVEL:
			colour = NOVEL_COLOURS[novel % NOVEL_COLOURS.size()]
			novel += 1
		var light := _light("page_light_%d" % i, PAGE_WHITE.lerp(colour, PAGE_TINT), PAGE_REACH)
		light.shadow_enabled = true
		# (Falling off fast, it fades out before its reach instead of ending in a circle on the wall.)
		light.omni_attenuation = PAGE_FALLOFF
		book_lights.append(light)
		_projections[i].radiance.surface_size = _projections[i].page_extent()
		_projections[i].radiance.build(colour, float(i))
		var looks: Array = []
		for part: MeshInstance3D in book.parts:
			looks.append_array(_paper_looks(part, colour, float(i)))
		_page_looks.append(looks)

	if is_instance_valid(lab.quarantine) and not lab.quarantine.books.is_empty():
		var cage_box := AABB()
		for i in lab.quarantine.books.size():
			var book: MeshInstance3D = lab.quarantine.books[i]
			var bounds: AABB = book.global_transform * book.get_aabb()
			cage_box = bounds if i == 0 else cage_box.merge(bounds)
			_cage_looks.append_array(_paper_looks(book, COLOURS[&"necromancy"], float(i) + 20.0, true))
			if i % 3 == 0:
				# The emitting surface is the moving book itself, through its paper material.
				cage_radiance.append(book)
		cage_light = _light("cage_light", COLOURS[&"necromancy"], 1.5)
		cage_light.global_position = cage_box.get_center() + Vector3(0.0, 0.0, 0.15)
	_sync()


func set_inspection(on: bool) -> void:
	_inspecting = on
	_sync()


func _process(delta: float) -> void:
	_clock += delta
	_sync()


func _sync() -> void:
	var lit := enabled and not _inspecting
	var i := 0
	for section in section_lights:
		var light: OmniLight3D = section_lights[section]
		light.visible = lit
		light.light_energy = SECTION_ENERGY * _breath(i)
		i += 1
	for k in book_lights.size():
		var projection: Node3D = _projections[k]
		var presence: float = projection.presence if is_instance_valid(projection) else 0.0
		var light := book_lights[k]
		light.visible = lit and presence > 0.001
		light.light_energy = BOOK_ENERGY * presence if enabled else 0.0
		if is_instance_valid(projection):
			light.global_position = projection.origin_world() + Vector3.UP * 0.055
		for look: ShaderMaterial in _page_looks[k]:
			_glow(look, presence * 0.9 if lit else 0.0)
	if is_instance_valid(cage_light):
		cage_light.visible = lit
		cage_light.light_energy = CAGE_ENERGY * _breath(5)
		for look in _cage_looks:
			# (The light is in the seams between their leaves; the paper itself only faintly lifted.)
			_glow(look, 1.6 * _breath(5) if lit else 0.0, CAGE_LIFT)
	var phase := 0
	for section in section_radiance:
		var aura: Node3D = section_radiance[section]
		var at := aura.global_position
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.005, at + Vector3.UP * 0.38)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		var headroom: float = maxf(0.0, hit.position.y - at.y - 0.02) if not hit.is_empty() else 0.38
		aura.set_state(0.58 + 0.15 * _breath(phase) if lit else 0.0, headroom, _clock)
		phase += 1


## Surface tracery on one flat book in each section, clear of the next board.
func _section_aura(lab: Node3D, section: StringName, shelf: MeshInstance3D) -> void:
	var best := INF
	var source := AABB()
	var origin := Vector3.ZERO
	var source_size := Vector2(0.2, 0.25)
	for entry: Dictionary in lab.book_layout:
		var spot: Dictionary = lab.book_spots[entry["spot"]]
		var frame: Transform3D = spot["xform"]
		if not frame.is_equal_approx(shelf.global_transform):
			continue
		if entry["pose"] not in ["stack", "lie"]:
			continue
		var box: AABB = entry["box"]
		var available: float = spot["top"] + spot["head"] - box.end.y
		if available < 0.18:
			continue
		var score := absf(box.end.y - 1.5) + absf(box.get_center().x) * 0.15
		if entry["pose"] in ["stack", "lie"]:
			score -= 0.25
		if score < best:
			best = score
			source = frame * box
			origin = frame * Vector3(box.get_center().x, box.end.y + 0.001, box.get_center().z)
			source_size = Vector2(box.size.x * 0.85, box.size.z * 0.85)
	if best == INF:
		return
	var aura := BookRadiance.new()
	aura.name = "aura_%s" % section
	add_child(aura)
	aura.global_position = origin
	aura.global_basis = shelf.global_basis.orthonormalized()
	aura.surface_size = source_size
	aura.set_meta("source_book_box", source)
	aura.build(COLOURS[section], float(section_radiance.size()) + 50.0)
	section_radiance[section] = aura


func _breath(index: int) -> float:
	return 0.86 + 0.14 * sin(_clock * (0.65 + index * 0.063) + index * 1.37)


func _light(label: String, colour: Color, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = label
	light.light_color = colour
	light.light_energy = 0.0
	light.omni_range = reach
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	add_child(light)
	return light


## Only paper gets an emission material; the leather and the shared atlas stay as authored.
func _paper_looks(part: MeshInstance3D, colour: Color, phase := 0.0, caged := false) -> Array[ShaderMaterial]:
	var looks: Array[ShaderMaterial] = []
	for i in part.mesh.get_surface_count():
		var slot := part.mesh.surface_get_material(i)
		var authored := part.get_surface_override_material(i) as ShaderMaterial
		if slot == null or slot.resource_name not in ["paper", "page_edge"] or authored == null:
			continue
		var look := authored.duplicate() as ShaderMaterial
		look.set_meta("glow_colour", colour)
		look.set_meta("ambient_amount", authored.get_shader_parameter("ambient_amount"))
		look.set_meta("ambient_sky", _uniform(authored, "ambient_sky", Color(0.4, 0.44, 0.58)))
		look.set_meta("ambient_ground", _uniform(authored, "ambient_ground", Color(0.42, 0.3, 0.24)))
		look.set_meta("rim_amount", authored.get_shader_parameter("rim_amount"))
		look.set_meta("rim_colour", _uniform(authored, "rim_colour", Color(0.62, 0.7, 0.95)))
		var tracery := ShaderMaterial.new()
		tracery.shader = PAGE_RADIANCE
		tracery.set_shader_parameter("colour", colour)
		tracery.set_shader_parameter("page_min", part.get_aabb().position)
		tracery.set_shader_parameter("page_size", part.get_aabb().size)
		tracery.set_shader_parameter("seed", phase)
		tracery.set_shader_parameter("caged", caged)
		look.set_meta("radiance_pass", tracery)
		part.set_surface_override_material(i, look)
		looks.append(look)
	return looks


func _glow(look: ShaderMaterial, amount: float, lift := 1.0) -> void:
	if is_equal_approx(float(look.get_meta("last_glow", -1.0)), amount):
		return
	look.set_meta("last_glow", amount)
	var tracery: ShaderMaterial = look.get_meta("radiance_pass")
	tracery.set_shader_parameter("amount", amount)
	look.next_pass = tracery if amount > 0.001 else null
	var colour: Color = look.get_meta("glow_colour")
	var mix_amount := minf(amount, 1.0)
	# source_color vec3 defaults are Colors on the real renderer.
	var sky: Color = look.get_meta("ambient_sky")
	var ground: Color = look.get_meta("ambient_ground")
	var rim: Color = look.get_meta("rim_colour")
	look.set_shader_parameter("ambient_sky", sky.lerp(colour, mix_amount))
	look.set_shader_parameter("ambient_ground", ground.lerp(colour, mix_amount))
	look.set_shader_parameter("ambient_amount", float(look.get_meta("ambient_amount")) + amount * lift)
	look.set_shader_parameter("rim_colour", rim.lerp(colour, mix_amount))
	look.set_shader_parameter("rim_amount", float(look.get_meta("rim_amount")) + amount * 0.18)


## The dummy headless renderer cannot read an unset uniform's shader default.
## These defaults match painterly.gdshaderinc; authored overrides still win.
func _uniform(look: ShaderMaterial, key: String, fallback: Variant) -> Variant:
	var value: Variant = look.get_shader_parameter(key)
	return fallback if value == null else value
