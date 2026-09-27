extends Node3D
## Effects: blood, sparks, dust, splinters, glints, light flashes, and the
## stains they leave. One of these lives in each level, made on first use.
##
##   Fx.blood(self, point, direction, amount)    a spurt, stains where it lands
##   Fx.sparks(self, point, normal, amount)      steel on steel or on stone
##   Fx.dust(self, point, normal, amount, "wood") a puff and chips of the surface
##   Fx.glint(self, point, size, follow)         a star on a blade
##   Fx.flash(self, point, colour, energy, range, seconds)
##   Fx.stain(self, point, normal, size)         a splat on the world
##   Fx.pool(self, point, size, seconds)         a spreading pool under a body
##   Fx.spurt(bone, offset, direction, seconds)  blood pumping from a wound
##
## Everything here is cosmetic. Nothing reads it back; its lights skip the
## lightgem's probe and the guards' light arithmetic; it is drawn on its own
## render layer, which the lightgem's cameras do not see. `enabled` switches
## it all off and `gore` scales the blood (0 is none).
##
## The look is deliberately low-fi: tiny nearest-filtered sprites, hard or
## dithered edges, a few chunky shapes. Particles are simulated here, drawn as
## one MultiMesh per kind, and collide with the world by ray.

const Layers := preload("res://scripts/Visual/Layers.gd")

enum Kind {
	BLOOD,
	MIST,
	SPARK,
	DUST,
	CHIP,
	GLINT,
	STREAK,
}

enum Look {
	ROUND,
	STRETCH,
	SOLID,
}

## Particle flags.
const COLLIDE := 1
const STAIN := 2
const BOUNCE := 4
const STILL := 8
const LONG := 16

const MAX_RAYS_PER_FRAME := 160
const MAX_STAINS_PER_FRAME := 8
const DECAL_POOL := 160
const LIGHT_POOL := 4

static var enabled := true
static var gore := 1.0

static var _world: Node = null
static var _textures := {}

var _pools: Array = []
var _decals: Array[Decal] = []
var _decal_cursor := 0
var _lights: Array[OmniLight3D] = []
var _light_cursor := 0
var _flashes := {}
var _growing := {}
## Wounds still pumping: [node followed, offset and direction in its space,
## seconds left, seconds in all, to the next beat, how hard].
var _spurts: Array = []
var _query := PhysicsRayQueryParameters3D.new()
var _ray_budget := [0]
var _stains_this_frame := 0


# ---------------------------------------------------------------------------
# The API
# ---------------------------------------------------------------------------

## A spurt of blood from a wound, flying along `direction`. `amount` 1 is a
## solid sword cut; 2 is a killing blow.
static func blood(context: Node, at: Vector3, direction: Vector3, amount := 1.0) -> void:
	var world := _world_for(context)

	if world != null and gore > 0.0:
		world._blood(context, at, direction, amount * gore)


static func sparks(context: Node, at: Vector3, normal: Vector3, amount := 1.0, with_flash := true) -> void:
	var world := _world_for(context)

	if world != null:
		world._sparks(at, normal, amount, with_flash)


## `surface` picks the colour and the chips: "stone", "wood", "metal",
## "grass", "carpet" or "dirt".
static func dust(context: Node, at: Vector3, normal: Vector3, amount := 1.0, surface := "stone") -> void:
	var world := _world_for(context)

	if world != null:
		world._dust(at, normal, amount, surface)


## Chips knocked off `surface` and no dust with them: an axe biting a log.
static func chips(context: Node, at: Vector3, normal: Vector3, amount := 1.0, surface := "wood") -> void:
	var world := _world_for(context)

	if world != null:
		world._dust(at, normal, amount, surface, false)


## A star that flares and fades. With `follow`, it rides that node.
static func glint(context: Node, at: Vector3, size := 0.14, follow: Node3D = null, color := Color(1.0, 0.96, 0.85)) -> void:
	var world := _world_for(context)

	if world != null:
		world._glint(at, size, follow, color)


## A brief light: sparks, a torch knocked over, a blade meeting a blade.
static func flash(context: Node, at: Vector3, color: Color, energy := 2.0, light_range := 3.5, seconds := 0.09) -> void:
	var world := _world_for(context)

	if world != null:
		world._flash(at, color, energy, light_range, seconds)


## A faint line along a flight path (arrows).
static func streak(context: Node, at: Vector3, velocity: Vector3, life := 0.09) -> void:
	var world := _world_for(context)

	if world != null:
		world._streak(at, velocity, life)


## A drop falling off a wound: one drop, and a small stain where it lands. A
## man who is bleeding leaves a trail you can follow.
static func drip(context: Node, at: Vector3, size := 0.14) -> void:
	var world := _world_for(context)

	if world != null and gore > 0.0:
		world._drip(context, at, size)


## A splat on a surface. `kind` is "blood", "scratch" or "pool".
static func stain(context: Node, at: Vector3, normal: Vector3, size: float, kind := "blood") -> Decal:
	var world := _world_for(context)

	if world == null or (kind != "scratch" and kind != "scorch" and gore <= 0.0):
		return null

	return world._stain(at, normal, size, kind)


## Blood pumping out of a wound, a spurt on every beat of a heart that is
## giving out, for `seconds`. `offset` and `direction` are in the space of
## `follow` (a bone's attachment), so it rides the body as it falls.
static func spurt(follow: Node3D, offset: Vector3, direction: Vector3, seconds := 1.4, amount := 1.0) -> void:
	var world := _world_for(follow)

	if world == null or gore <= 0.0 or direction.length() < 0.001:
		return

	world._spurts.append([follow, offset, direction.normalized(), seconds, seconds, 0.0, amount * gore])


## A pool of blood that spreads under a body over `seconds`.
static func pool(context: Node, at: Vector3, size := 1.2, seconds := 6.0) -> void:
	var world := _world_for(context)

	if world == null or gore <= 0.0:
		return

	world._pool_under(context, at, size, seconds)


## A wound: a small splat painted on an actor, moving with `mesh`.
static func wound(mesh: Node3D, at: Vector3, normal: Vector3, size := 0.22) -> Decal:
	if not enabled or gore <= 0.0 or mesh == null:
		return null

	var decal := Decal.new()
	decal.name = "Wound"
	decal.set_meta(&"wound", true)
	decal.texture_albedo = texture(&"wound")
	decal.modulate = Color(0.36, 0.02, 0.02, 0.95)
	decal.size = Vector3(size, size * 1.4, size)
	decal.cull_mask = Layers.ACTORS
	decal.normal_fade = 0.2
	decal.upper_fade = 0.2
	decal.lower_fade = 0.2
	mesh.add_child(decal, true)
	decal.global_transform = Transform3D(_basis_on(normal, randf() * TAU), at)
	return decal


## How many particles of a kind are alive (tests and tuning).
static func live(kind: int) -> int:
	if _world == null or not is_instance_valid(_world):
		return 0

	return _world._pools[kind].count


## Stains currently on show.
static func stains_in_use() -> int:
	if _world == null or not is_instance_valid(_world):
		return 0

	var shown := 0

	for decal in _world._decals:
		if decal.visible:
			shown += 1

	return shown


static func lights_lit() -> int:
	if _world == null or not is_instance_valid(_world):
		return 0

	return _world._flashes.size()


static func world_node() -> Node:
	return _world if _world != null and is_instance_valid(_world) else null


## Everything gone at once.
static func clear() -> void:
	if _world == null or not is_instance_valid(_world):
		return

	for p in _world._pools:
		p.count = 0
		p.cursor = 0

	for decal in _world._decals:
		decal.visible = false

	for light in _world._lights:
		light.visible = false

	_world._flashes.clear()
	_world._growing.clear()
	_world._spurts.clear()


static func _world_for(context: Node) -> Node:
	if not enabled or context == null or not context.is_inside_tree():
		return null

	# Reuse it even while it waits to join the tree (asked for during setup).
	if _world != null and is_instance_valid(_world) and not _world.is_queued_for_deletion():
		return _world

	var tree := context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var world: Node3D = (load("res://scripts/Visual/Fx.gd") as GDScript).new()
	world.name = "Fx"

	if parent.is_node_ready():
		parent.add_child(world)
	else:
		parent.add_child.call_deferred(world)

	_world = world
	return world


# ---------------------------------------------------------------------------
# Setting up
# ---------------------------------------------------------------------------

class Pool:
	var kind := 0
	var look := 0
	var capacity := 0
	var count := 0
	var cursor := 0
	var gravity := 9.8
	var drag := 0.0
	## STRETCH: how many seconds of travel one streak spans.
	var stretch := 0.0
	## STRETCH: width as a fraction of size.
	var width := 1.0
	var instance: MultiMeshInstance3D
	var buffer := PackedFloat32Array()

	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	## SOLID: the tumble axis. Followers: the offset in the followed node.
	var axis := PackedVector3Array()
	var age := PackedFloat32Array()
	var life := PackedFloat32Array()
	var size := PackedFloat32Array()
	var grow := PackedFloat32Array()
	var spin := PackedFloat32Array()
	var spin_rate := PackedFloat32Array()
	var color := PackedColorArray()
	var flags := PackedInt32Array()
	var follow: Array = []

	func _init(p_kind: int, p_capacity: int, p_look: int) -> void:
		kind = p_kind
		capacity = p_capacity
		look = p_look

		pos.resize(capacity)
		vel.resize(capacity)
		axis.resize(capacity)
		age.resize(capacity)
		life.resize(capacity)
		size.resize(capacity)
		grow.resize(capacity)
		spin.resize(capacity)
		spin_rate.resize(capacity)
		color.resize(capacity)
		flags.resize(capacity)
		follow.resize(capacity)
		buffer.resize(capacity * 16)

	func add(
		p: Vector3,
		v: Vector3,
		lifetime: float,
		s: float,
		c: Color,
		f := 0,
		growth := 0.0,
		rate := 0.0,
		tumble := Vector3.UP
	) -> int:
		var i := count

		if count < capacity:
			count += 1
		else:
			# Full: the oldest slot in turn is reused.
			i = cursor
			cursor = (cursor + 1) % capacity

		pos[i] = p
		vel[i] = v
		age[i] = 0.0
		life[i] = maxf(lifetime, 0.01)
		size[i] = s
		grow[i] = growth
		spin[i] = randf() * TAU
		spin_rate[i] = rate
		color[i] = c
		flags[i] = f
		axis[i] = tumble
		follow[i] = null
		return i

	func attach(i: int, node: Node3D, offset: Vector3) -> void:
		follow[i] = node
		axis[i] = offset

	func remove(i: int) -> void:
		count -= 1

		if i != count:
			pos[i] = pos[count]
			vel[i] = vel[count]
			axis[i] = axis[count]
			age[i] = age[count]
			life[i] = life[count]
			size[i] = size[count]
			grow[i] = grow[count]
			spin[i] = spin[count]
			spin_rate[i] = spin_rate[count]
			color[i] = color[count]
			flags[i] = flags[count]
			follow[i] = follow[count]

		follow[count] = null

	## Moves everything on by dt. Returns what landed on something that it
	## stains: [kind, point, normal, speed, size].
	func step(dt: float, space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D, budget: Array) -> Array:
		var events := []
		var i := count - 1

		while i >= 0:
			age[i] += dt

			if age[i] >= life[i]:
				remove(i)
				i -= 1
				continue

			size[i] = maxf(size[i] + grow[i] * dt, 0.0)
			spin[i] += spin_rate[i] * dt
			var node = follow[i]

			if node != null:
				if is_instance_valid(node) and (node as Node3D).is_inside_tree():
					# Where the followed thing is drawn, not where physics has it.
					pos[i] = (node as Node3D).get_global_transform_interpolated() * axis[i]
				else:
					follow[i] = null

				i -= 1
				continue

			var f := flags[i]

			if f & STILL:
				i -= 1
				continue

			var v := vel[i]
			v.y -= gravity * dt

			if drag > 0.0:
				v *= 1.0 / (1.0 + drag * dt)

			var from := pos[i]
			var to := from + v * dt

			if f & COLLIDE and space != null and int(budget[0]) > 0:
				budget[0] = int(budget[0]) - 1
				query.from = from
				query.to = to
				var hit := space.intersect_ray(query)

				if not hit.is_empty():
					var point: Vector3 = hit["position"]
					var normal: Vector3 = hit["normal"]

					if f & STAIN:
						events.append([kind, point, normal, v.length(), size[i]])
						remove(i)
						i -= 1
						continue

					if f & BOUNCE and v.length() > 0.8:
						v = v.bounce(normal) * 0.38
						to = point + normal * 0.01
					else:
						# Come to rest on it.
						v = Vector3.ZERO
						to = point + normal * 0.006
						flags[i] = (f & ~COLLIDE) | STILL
						spin_rate[i] = 0.0

			pos[i] = to
			vel[i] = v
			i -= 1

		return events

	## Fills the MultiMesh: each particle faces the camera, stretches along
	## its motion, or tumbles, as its kind looks.
	func render(cam_basis: Basis, cam_pos: Vector3) -> void:
		var mm := instance.multimesh

		if count == 0:
			mm.visible_instance_count = 0
			return

		var right := cam_basis.x
		var up := cam_basis.y
		var back := cam_basis.z

		for i in range(count):
			var t := age[i] / life[i]
			var s := size[i]
			var c := color[i]

			match kind:
				Kind.BLOOD, Kind.CHIP:
					s *= 1.0 - smoothstep(0.78, 1.0, t)
				Kind.MIST:
					c.a *= pow(1.0 - t, 1.5)
				Kind.SPARK:
					var cool := smoothstep(0.0, 1.0, t)
					c = Color(c.r, lerpf(c.g, 0.32, cool), lerpf(c.b, 0.06, cool), c.a)
					var fade := pow(1.0 - t, 1.2)
					c = Color(c.r * fade, c.g * fade, c.b * fade, c.a * fade)
					s *= lerpf(1.0, 0.6, t)
				Kind.DUST:
					c.a *= pow(1.0 - t, 1.4) * minf(t * 10.0, 1.0)
				Kind.GLINT:
					s *= pow(sin(PI * t), 0.6)
					var fade := 1.0 - t * t
					c = Color(c.r * fade, c.g * fade, c.b * fade, c.a * fade)
				Kind.STREAK:
					c.a *= 1.0 - t

			var o := pos[i]
			var bx := Vector3.ZERO
			var by := Vector3.ZERO
			var bz := Vector3.ZERO

			match look:
				Look.ROUND:
					var cs := cos(spin[i])
					var sn := sin(spin[i])
					bx = (right * cs + up * sn) * s
					by = (up * cs - right * sn) * s
					bz = back * s
				Look.STRETCH:
					var v := vel[i]
					var to_cam := cam_pos - o
					var dist := to_cam.length()
					to_cam = to_cam / dist if dist > 0.0001 else back
					var along := v - to_cam * v.dot(to_cam)
					var along_len := along.length()

					if along_len < 0.001:
						along = up
					else:
						along /= along_len

					var length := s + v.length() * stretch
					var side := along.cross(to_cam)
					side = side.normalized() if side.length() > 0.0001 else right
					bx = side * s * width
					by = along * length
					bz = to_cam * s
					# The head of the streak is where the particle is.
					o -= along * length * 0.5
				Look.SOLID:
					var turn := Basis(axis[i], spin[i])
					var stretch_z := 3.0 if flags[i] & LONG else 1.0
					bx = turn.x * s
					by = turn.y * s
					bz = turn.z * s * stretch_z

			var k := i * 16
			buffer[k] = bx.x
			buffer[k + 1] = by.x
			buffer[k + 2] = bz.x
			buffer[k + 3] = o.x
			buffer[k + 4] = bx.y
			buffer[k + 5] = by.y
			buffer[k + 6] = bz.y
			buffer[k + 7] = o.y
			buffer[k + 8] = bx.z
			buffer[k + 9] = by.z
			buffer[k + 10] = bz.z
			buffer[k + 11] = o.z
			buffer[k + 12] = c.r
			buffer[k + 13] = c.g
			buffer[k + 14] = c.b
			buffer[k + 15] = c.a

		mm.buffer = buffer
		mm.visible_instance_count = count


## Everything is built at once, not on entering the tree: an effect asked
## for while a level is still being set up lands in a node that is ready for
## it, and joins the tree with it.
func _init() -> void:
	# Pooled decals and lights jump to wherever they are needed: never slide
	# them there between ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_query.collision_mask = 1
	_query.collide_with_areas = false

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var box := BoxMesh.new()
	box.size = Vector3.ONE

	_pools.resize(Kind.size())
	_pools[Kind.BLOOD] = _make_pool(Kind.BLOOD, 320, Look.STRETCH, quad, _material(texture(&"drop"), "blood"), 9.8, 0.25, 0.016, 1.0)
	_pools[Kind.MIST] = _make_pool(Kind.MIST, 64, Look.ROUND, quad, _material(texture(&"puff"), "blood_mist"), 0.3, 3.0)
	_pools[Kind.SPARK] = _make_pool(Kind.SPARK, 192, Look.STRETCH, quad, _material(texture(&"spark"), "add"), 6.5, 0.5, 0.03, 0.55)
	_pools[Kind.DUST] = _make_pool(Kind.DUST, 96, Look.ROUND, quad, _material(texture(&"puff"), "hash"), -0.12, 3.2)
	_pools[Kind.CHIP] = _make_pool(Kind.CHIP, 96, Look.SOLID, box, _material(null, "solid"), 9.8, 0.2)
	_pools[Kind.GLINT] = _make_pool(Kind.GLINT, 24, Look.ROUND, quad, _material(texture(&"star"), "add"), 0.0, 0.0)
	_pools[Kind.STREAK] = _make_pool(Kind.STREAK, 128, Look.STRETCH, quad, _material(texture(&"spark"), "faint"), 0.0, 0.0, 0.022, 0.35)

	for i in range(DECAL_POOL):
		var decal := Decal.new()
		decal.visible = false
		decal.cull_mask = Layers.WORLD_ALL
		decal.normal_fade = 0.35
		decal.upper_fade = 0.15
		decal.lower_fade = 0.15
		decal.distance_fade_enabled = true
		decal.distance_fade_begin = 30.0
		decal.distance_fade_length = 10.0
		add_child(decal)
		_decals.append(decal)

	for i in range(LIGHT_POOL):
		var light := OmniLight3D.new()
		light.visible = false
		light.shadow_enabled = false
		light.light_cull_mask = Layers.ALL_BUT_PROBE
		light.omni_attenuation = 1.4
		light.light_volumetric_fog_energy = 2.0
		light.light_specular = 0.6
		light.add_to_group(&"fx_light")
		add_child(light)
		_lights.append(light)


## Leaving the level: let go of the shared textures too (they are cheap to
## draw again), so nothing outlives the scene.
func _exit_tree() -> void:
	if _world == self:
		_world = null
		_textures.clear()


func _make_pool(
	kind: int,
	capacity: int,
	look: int,
	mesh: Mesh,
	material: Material,
	gravity: float,
	drag: float,
	stretch := 0.0,
	width := 1.0
) -> Pool:
	var p := Pool.new(kind, capacity, look)
	p.gravity = gravity
	p.drag = drag
	p.stretch = stretch
	p.width = width

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0

	var instance := MultiMeshInstance3D.new()
	instance.name = "Particles%d" % kind
	instance.multimesh = mm
	instance.material_override = material
	instance.layers = Layers.FX
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Particles are all over the level: never cull the batch on its box.
	instance.custom_aabb = AABB(Vector3(-4000, -4000, -4000), Vector3(8000, 8000, 8000))
	add_child(instance)
	p.instance = instance
	return p


## "scissor": hard-edged and lit (drops). "hash": dithered and lit (puffs).
## "add": glowing (sparks, glints). "faint": a soft unlit line. "solid": lit
## chunks.
func _material(tex: Texture2D, style: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true

	match style:
		"blood", "blood_mist":
			# Blood is translucent: lit from behind it glows red instead of
			# going black, which is how a spray against a torch looks.
			# Only a little: a drop against a torch reads as a spark, not
			# as blood, if it glows or shines.
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR if style == "blood" else BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			m.alpha_scissor_threshold = 0.5
			m.roughness = 0.5 if style == "blood" else 1.0
			m.metallic_specular = 0.3 if style == "blood" else 0.1
			m.backlight_enabled = true
			m.backlight = Color(0.26, 0.012, 0.01)
			m.emission_enabled = true
			m.emission = Color(0.035, 0.0, 0.0)
		"hash":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			m.roughness = 1.0
			m.metallic_specular = 0.1
		"add":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.disable_fog = true
		"faint":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.disable_fog = true
		"solid":
			m.roughness = 0.9

	return m


# ---------------------------------------------------------------------------
# Every frame
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	_ray_budget[0] = MAX_RAYS_PER_FRAME
	_stains_this_frame = 0

	for p in _pools:
		var events: Array = (p as Pool).step(delta, space, _query, _ray_budget)

		for e in events:
			_landed(e)

	var camera := get_viewport().get_camera_3d()

	if camera != null:
		var basis := camera.global_transform.basis.orthonormalized()
		var at := camera.global_position

		for p in _pools:
			(p as Pool).render(basis, at)

	_update_flashes(delta)
	_update_growing(delta)
	_update_spurts(delta)


## A drop of blood hit something: most leave a small stain where they land.
func _landed(event: Array) -> void:
	if int(event[0]) != Kind.BLOOD or _stains_this_frame >= MAX_STAINS_PER_FRAME:
		return

	if randf() > 0.6:
		return

	_stains_this_frame += 1
	var speed: float = event[3]
	var drop: float = event[4]
	var size := clampf(drop * 6.0 + speed * 0.03, 0.12, 0.32)
	_stain(event[1], event[2], size, "drop")


func _update_flashes(delta: float) -> void:
	for light in _flashes.keys():
		var flash: Dictionary = _flashes[light]
		flash["left"] = float(flash["left"]) - delta
		var left: float = flash["left"]

		if left <= 0.0:
			light.visible = false
			_flashes.erase(light)
			continue

		var k := left / float(flash["time"])
		light.light_energy = float(flash["peak"]) * k * k


func _update_spurts(delta: float) -> void:
	var i := _spurts.size() - 1

	while i >= 0:
		var spurt: Array = _spurts[i]
		var node = spurt[0]
		spurt[3] = float(spurt[3]) - delta

		if float(spurt[3]) <= 0.0 or not is_instance_valid(node) or not (node as Node3D).is_inside_tree():
			_spurts.remove_at(i)
			i -= 1
			continue

		spurt[5] = float(spurt[5]) - delta

		if float(spurt[5]) <= 0.0:
			# Weaker and further apart as the heart gives out.
			var left := float(spurt[3]) / float(spurt[4])
			spurt[5] = lerpf(0.42, 0.24, left)
			var xform := (node as Node3D).get_global_transform_interpolated()
			_pulse(xform * (spurt[1] as Vector3), (xform.basis * (spurt[2] as Vector3)).normalized(), float(spurt[6]) * (0.35 + 0.65 * left))

		i -= 1


## One beat of a spurting wound.
func _pulse(at: Vector3, direction: Vector3, strength: float) -> void:
	var drops: Pool = _pools[Kind.BLOOD]

	for n in range(clampi(int(round(10.0 * strength)), 2, 14)):
		var shade := randf_range(0.3, 0.42)
		drops.add(
			at + _rand_unit() * 0.012,
			_cone(direction, 0.16) * randf_range(1.3, 2.8) * (0.55 + 0.45 * strength) + Vector3.UP * 0.35,
			randf_range(1.2, 2.0),
			randf_range(0.013, 0.026),
			Color(shade, shade * 0.035, shade * 0.03),
			COLLIDE | STAIN
		)

	_pools[Kind.MIST].add(at, direction * 0.45, 0.22, 0.045, Color(0.36, 0.02, 0.016, 0.7), 0, 0.28)


func _update_growing(delta: float) -> void:
	for decal in _growing.keys():
		var grow: Dictionary = _growing[decal]

		if not decal.visible:
			_growing.erase(decal)
			continue

		grow["t"] = float(grow["t"]) + delta / float(grow["time"])
		var t := clampf(grow["t"], 0.0, 1.0)
		var eased := 1.0 - (1.0 - t) * (1.0 - t)
		var size := lerpf(float(grow["from"]), float(grow["to"]), eased)
		decal.size = Vector3(size, decal.size.y, size)

		if t >= 1.0:
			_growing.erase(decal)


# ---------------------------------------------------------------------------
# The effects
# ---------------------------------------------------------------------------

func _blood(context: Node, at: Vector3, direction: Vector3, amount: float) -> void:
	var dir := direction.normalized() if direction.length() > 0.001 else Vector3.UP
	var drops: Pool = _pools[Kind.BLOOD]
	var count := clampi(int(round(22.0 * amount)), 6, 56)
	var force := clampf(0.8 + amount * 0.3, 0.9, 1.6)

	for n in range(count):
		# Most of it goes on with the blow; some sprays back out.
		var back := randf() < 0.2
		var d := _cone(-dir if back else dir, 0.6 if back else 0.45)
		var speed := randf_range(1.6, 5.2) * force * (0.55 if back else 1.0)
		var v := d * speed + Vector3.UP * randf_range(0.4, 1.6)
		var shade := randf_range(0.32, 0.48)
		# Long enough to reach the floor from head height: a drop should land,
		# not vanish in the air.
		drops.add(
			at + _rand_unit() * 0.04,
			v,
			randf_range(1.6, 2.4),
			randf_range(0.018, 0.04) * lerpf(1.0, 1.35, clampf(amount - 1.0, 0.0, 1.0)),
			Color(shade, shade * 0.035, shade * 0.03),
			COLLIDE | STAIN
		)

	var mist: Pool = _pools[Kind.MIST]

	for n in range(clampi(int(round(4.0 * amount)), 2, 9)):
		mist.add(
			at + _rand_unit() * 0.06,
			dir * randf_range(0.4, 1.4) + _rand_unit() * 0.4,
			randf_range(0.22, 0.45),
			randf_range(0.07, 0.14),
			Color(0.4, 0.024, 0.018, 0.8),
			0,
			randf_range(0.35, 0.8)
		)

	# Whatever is behind him gets the spray.
	var space := _space(context)

	if space == null:
		return

	var reach := 1.6 + 0.6 * clampf(amount, 0.0, 2.0)
	var query := PhysicsRayQueryParameters3D.create(at, at + dir * reach, 1)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)

	if not hit.is_empty():
		var size := randf_range(0.55, 0.8) * clampf(0.7 + amount * 0.35, 0.8, 1.6)
		_stain(hit["position"], hit["normal"], size, "blood")


func _sparks(at: Vector3, normal: Vector3, amount: float, with_flash: bool) -> void:
	var n := normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var sparks: Pool = _pools[Kind.SPARK]
	var count := clampi(int(round(18.0 * amount)), 4, 64)

	for i in range(count):
		var d := (n + _rand_unit() * 1.1).normalized()

		if d.dot(n) < 0.0:
			d = d - n * 2.0 * d.dot(n)

		sparks.add(
			at + n * 0.01,
			d * randf_range(2.5, 8.5) * clampf(0.8 + amount * 0.2, 0.9, 1.4),
			randf_range(0.16, 0.5),
			randf_range(0.009, 0.017),
			Color(1.0, randf_range(0.78, 0.96), randf_range(0.4, 0.6), 1.0),
			COLLIDE | BOUNCE
		)

	var core: Pool = _pools[Kind.GLINT]
	core.add(at + n * 0.02, Vector3.ZERO, 0.08, 0.2 * sqrt(maxf(amount, 0.1)), Color(1.0, 0.9, 0.7, 1.0), STILL, 0.0, 6.0)

	# A wisp of hot grit where the steel bit.
	var smoke: Pool = _pools[Kind.DUST]

	for i in range(clampi(int(round(1.5 * amount)), 1, 3)):
		smoke.add(
			at + n * 0.03 + _rand_unit() * 0.02,
			n * randf_range(0.15, 0.4) + Vector3.UP * 0.15 + _rand_unit() * 0.1,
			randf_range(0.45, 0.8),
			randf_range(0.035, 0.06),
			Color(0.42, 0.41, 0.4, 0.32),
			0,
			randf_range(0.18, 0.32)
		)

	if with_flash:
		_flash(at + n * 0.15, Color(1.0, 0.72, 0.42), 1.5 * sqrt(maxf(amount, 0.1)), 2.8, 0.07)


func _dust(at: Vector3, normal: Vector3, amount: float, surface: String, with_puffs := true) -> void:
	var n := normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var tone: Color
	var chip_tone: Color
	var splinters := false

	match surface:
		"wood":
			tone = Color(0.4, 0.3, 0.2, 0.55)
			chip_tone = Color(0.5, 0.36, 0.2)
			splinters = true
		"metal":
			tone = Color(0.36, 0.36, 0.38, 0.35)
			chip_tone = Color(0.45, 0.45, 0.48)
		"grass", "dirt":
			tone = Color(0.32, 0.27, 0.19, 0.55)
			chip_tone = Color(0.25, 0.22, 0.15)
		"carpet":
			tone = Color(0.35, 0.25, 0.22, 0.4)
			chip_tone = Color(0.4, 0.2, 0.18)
		"water":
			# Spray: pale, and the drops fall back in rather than bounce.
			tone = Color(0.72, 0.8, 0.84, 0.45)
			chip_tone = Color(0.66, 0.78, 0.86)
		_:
			tone = Color(0.47, 0.45, 0.42, 0.6)
			chip_tone = Color(0.55, 0.53, 0.5)

	var puffs: Pool = _pools[Kind.DUST]

	for i in range(clampi(int(round(4.0 * amount)), 1, 10) if with_puffs else 0):
		puffs.add(
			at + n * 0.05 + _rand_unit() * 0.05,
			n * randf_range(0.25, 0.9) + _rand_unit() * 0.3,
			randf_range(0.5, 0.95),
			randf_range(0.06, 0.12),
			tone,
			0,
			randf_range(0.3, 0.6)
		)

	var chips: Pool = _pools[Kind.CHIP]

	for i in range(clampi(int(round(6.0 * amount)), 0, 16)):
		var shade := randf_range(0.8, 1.15)
		chips.add(
			at + n * 0.02,
			n * randf_range(1.2, 3.2) + _rand_unit() * 1.3 + Vector3.UP * 0.8,
			randf_range(0.9, 1.5),
			randf_range(0.012, 0.028),
			Color(chip_tone.r * shade, chip_tone.g * shade, chip_tone.b * shade),
			0 if surface == "water" else COLLIDE | BOUNCE | (LONG if splinters else 0),
			0.0,
			randf_range(8.0, 22.0),
			_rand_unit().normalized()
		)


func _glint(at: Vector3, size: float, follow: Node3D, color: Color) -> void:
	var glints: Pool = _pools[Kind.GLINT]
	var i := glints.add(at, Vector3.ZERO, 0.3, size, Color(color.r, color.g, color.b, 1.0), STILL, 0.0, 2.5)

	if follow != null:
		glints.attach(i, follow, follow.global_transform.affine_inverse() * at)


func _drip(context: Node, at: Vector3, size: float) -> void:
	var shade := randf_range(0.3, 0.42)
	_pools[Kind.BLOOD].add(at, Vector3(randf_range(-0.1, 0.1), -0.3, randf_range(-0.1, 0.1)), 1.0, randf_range(0.012, 0.02), Color(shade, shade * 0.035, shade * 0.03), COLLIDE)
	var space := _space(context)

	if space == null:
		return

	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.0, 1)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)

	if not hit.is_empty():
		_stain(hit["position"], hit["normal"], size * randf_range(0.8, 1.25), "drop")


func _streak(at: Vector3, velocity: Vector3, life: float) -> void:
	var streaks: Pool = _pools[Kind.STREAK]
	streaks.add(at, velocity, life, 0.01, Color(0.85, 0.85, 0.8, 0.3), STILL)


func _flash(at: Vector3, color: Color, energy: float, light_range: float, seconds: float) -> void:
	var light := _lights[_light_cursor]
	_light_cursor = (_light_cursor + 1) % _lights.size()
	light.light_color = color
	light.omni_range = light_range
	light.light_energy = energy
	light.visible = true

	if light.is_inside_tree():
		light.global_position = at
	else:
		light.position = at

	_flashes[light] = { "peak": energy, "left": seconds, "time": maxf(seconds, 0.01) }


func _stain(at: Vector3, normal: Vector3, size: float, kind: String) -> Decal:
	var decal := _decals[_decal_cursor]
	_decal_cursor = (_decal_cursor + 1) % _decals.size()
	_growing.erase(decal)

	match kind:
		"scratch":
			decal.texture_albedo = texture(&"scratch")
			decal.modulate = Color(0.85, 0.84, 0.8, 0.55)
		"scorch":
			decal.texture_albedo = texture(&"pool")
			decal.modulate = Color(0.03, 0.025, 0.02, 0.9)
		"pool":
			decal.texture_albedo = texture(&"pool")
			decal.modulate = Color(0.22, 0.012, 0.01, 0.96)
		"drop":
			decal.texture_albedo = texture(StringName("drops_%d" % (randi() % 2)))
			decal.modulate = Color(0.3, 0.018, 0.015, 0.95)
		_:
			decal.texture_albedo = texture(StringName("splat_%d" % (randi() % 4)))
			decal.modulate = Color(0.3, 0.018, 0.015, 0.95)

	decal.size = Vector3(size, 0.3, size)
	decal.visible = true

	var xform := Transform3D(_basis_on(normal, randf() * TAU), at)

	if decal.is_inside_tree():
		decal.global_transform = xform
	else:
		decal.transform = xform

	return decal


func _pool_under(context: Node, at: Vector3, size: float, seconds: float) -> void:
	var space := _space(context)

	if space == null:
		return

	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 1.5, 1)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)

	if hit.is_empty():
		return

	var decal := _stain(hit["position"], hit["normal"], size * 0.15, "pool")
	_growing[decal] = { "from": size * 0.15, "to": size, "t": 0.0, "time": seconds }


func _space(context: Node) -> PhysicsDirectSpaceState3D:
	if context is Node3D and (context as Node3D).is_inside_tree():
		return (context as Node3D).get_world_3d().direct_space_state

	if is_inside_tree():
		return get_world_3d().direct_space_state

	return null


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _rand_unit() -> Vector3:
	var v := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))

	while v.length_squared() > 1.0 or v.length_squared() < 0.0001:
		v = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))

	return v


static func _cone(dir: Vector3, spread: float) -> Vector3:
	return (dir + _rand_unit() * spread).normalized()


## A basis whose +Y is `normal`, spun `angle` about it. Decals project down
## their -Y, so this lays one flat on a surface.
static func _basis_on(normal: Vector3, angle: float) -> Basis:
	var y := normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var ref := Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	return Basis(x, y, z).rotated(y, angle)


# ---------------------------------------------------------------------------
# Textures: drawn once, by hand, pixel by pixel
# ---------------------------------------------------------------------------

static func texture(texture_name: StringName) -> Texture2D:
	if _textures.is_empty():
		_build_textures()

	return _textures.get(texture_name)


static func _build_textures() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	_textures[&"drop"] = _tex(_draw_drop())
	_textures[&"puff"] = _tex(_draw_puff(rng))
	_textures[&"spark"] = _tex(_draw_spark())
	_textures[&"star"] = _tex(_draw_star())
	_textures[&"flame"] = _tex(_draw_flame(rng))
	_textures[&"scratch"] = _tex(_draw_scratch(rng))
	_textures[&"pool"] = _tex(_draw_splat(rng, 64, 5, 6, 0.3, 0.08, 0))
	_textures[&"wound"] = _tex(_draw_splat(rng, 32, 3, 4, 0.2, 0.12, 3))

	for i in range(4):
		_textures[StringName("splat_%d" % i)] = _tex(_draw_splat(rng, 64, 6, 16, 0.2, 0.45, 4))

	for i in range(2):
		_textures[StringName("drops_%d" % i)] = _tex(_draw_splat(rng, 32, 2, 5, 0.22, 0.4, 0))


static func _tex(image: Image) -> ImageTexture:
	return ImageTexture.create_from_image(image)


static func _blank(side_x: int, side_y: int) -> Image:
	var image := Image.create_empty(side_x, side_y, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	return image


## A round drop with a wet highlight.
static func _draw_drop() -> Image:
	var image := _blank(8, 8)

	for y in range(8):
		for x in range(8):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(4, 4))

			if d <= 3.6:
				var shine := 1.0 if Vector2(x, y).distance_to(Vector2(2.5, 2.5)) < 1.2 else 0.78
				image.set_pixel(x, y, Color(shine, shine, shine, 1.0))

	return image


## A soft puff, its alpha in four hard steps.
static func _draw_puff(rng: RandomNumberGenerator) -> Image:
	var image := _blank(16, 16)

	for y in range(16):
		for x in range(16):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8)) / 8.0
			var a := pow(clampf(1.0 - d, 0.0, 1.0), 1.1) * (0.75 + 0.25 * rng.randf())
			a = floorf(a * 4.0 + 0.5) / 4.0
			image.set_pixel(x, y, Color(1, 1, 1, a))

	return image


## A streak: bright at the head (the top), dying away down the tail.
static func _draw_spark() -> Image:
	var image := _blank(4, 16)

	for y in range(16):
		for x in range(4):
			var along := 1.0 - float(y) / 15.0
			var across := 1.0 - absf(x - 1.5) / 2.0
			var a := pow(along, 1.3) * (0.35 + 0.65 * across)
			image.set_pixel(x, y, Color(1, 1, 1, a))

	return image


## A four-pointed star.
static func _draw_star() -> Image:
	var image := _blank(16, 16)

	for y in range(16):
		for x in range(16):
			var dx := absf(x + 0.5 - 8.0)
			var dy := absf(y + 0.5 - 8.0)
			var a := 0.0

			if dy < 1.0:
				a = maxf(a, 1.0 - dx / 8.0)

			if dx < 1.0:
				a = maxf(a, 1.0 - dy / 8.0)

			if dx + dy < 3.0:
				a = 1.0

			image.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))

	return image


## A torch flame, four 16x16 frames side by side: a white-yellow heart, an
## orange body and a red edge, the tip swaying from frame to frame.
static func _draw_flame(rng: RandomNumberGenerator) -> Image:
	var image := _blank(64, 16)

	for frame in range(4):
		var sway_phase := frame * PI * 0.5

		for y in range(16):
			for x in range(16):
				var u := (x + 0.5) / 16.0 - 0.5
				var v := (y + 0.5) / 16.0
				var sway := 0.09 * sin(sway_phase + v * 4.0) * (1.0 - v)
				var width := 0.44 * sin(PI * pow(v, 0.75)) * (0.92 + 0.16 * rng.randf())
				var d := absf(u - sway)

				if v < 0.12 or d > width * 0.5:
					continue

				var colour := Color(0.95, 0.34, 0.08)

				if d < width * 0.33:
					colour = Color(1.0, 0.68, 0.2)

				if d < width * 0.17 and v > 0.45:
					colour = Color(1.0, 0.95, 0.62)

				image.set_pixel(frame * 16 + x, y, colour)

	return image


## Scratches: a few bright gouges.
static func _draw_scratch(rng: RandomNumberGenerator) -> Image:
	var image := _blank(32, 32)
	var angle := rng.randf() * PI

	for line in range(4):
		var dir := Vector2(cos(angle), sin(angle)).rotated(rng.randf_range(-0.25, 0.25))
		var start := Vector2(16, 16) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)) - dir * rng.randf_range(6, 12)
		var length := rng.randf_range(10, 22)

		for s in range(int(length)):
			var p := start + dir * s
			var x := int(p.x)
			var y := int(p.y)

			if x >= 0 and x < 32 and y >= 0 and y < 32:
				image.set_pixel(x, y, Color(1, 1, 1, 0.85))

	return image


## A splat: a blob of `blobs` circles, `satellites` droplets thrown out
## around it, and `trails` runs of shrinking drops in one direction.
static func _draw_splat(
	rng: RandomNumberGenerator,
	side: int,
	blobs: int,
	satellites: int,
	blob_radius: float,
	spread: float,
	trails: int
) -> Image:
	var image := _blank(side, side)
	var center := Vector2(side, side) * 0.5
	var r := float(side) * blob_radius
	var circles := []

	for i in range(blobs):
		var offset := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * r * 0.55
		circles.append([center + offset, r * rng.randf_range(0.55, 1.0)])

	var throw := Vector2.RIGHT.rotated(rng.randf() * TAU)

	for i in range(satellites):
		var dir := (throw + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 1.2).normalized()
		var distance := r + float(side) * spread * rng.randf_range(0.2, 1.0)
		circles.append([center + dir * distance, rng.randf_range(0.8, 2.2) * float(side) / 64.0 * 1.6])

	for i in range(trails):
		var dir := (throw + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))).normalized()
		var p := center + dir * r * 0.7
		var radius := float(side) / 64.0 * 3.0

		for s in range(6):
			circles.append([p, radius])
			p += dir * radius * 1.8
			radius *= 0.8

	for y in range(side):
		for x in range(side):
			var p := Vector2(x + 0.5, y + 0.5)

			for c in circles:
				if p.distance_to(c[0]) <= float(c[1]):
					var shade := rng.randf_range(0.82, 1.0)
					image.set_pixel(x, y, Color(shade, shade, shade, 1.0))
					break

	return image
