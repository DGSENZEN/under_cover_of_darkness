extends RefCounted
## Estimates world-point illumination for body detection and search scoring.
## Sums ambient and visible light falloff, with optional shadow rays and negative lights.
## Returns 0..1; ignores bounced light and lights in "fx_light". A shared light cache
## refreshes on scene/light/environment changes or after REFRESH_SECONDS.

const REFRESH_SECONDS := 2.0

static var _lights: Array = []
static var _ambient := 0.0
static var _refreshed_at := -100.0
static var _scene_id := 0
## The tree whose comings and goings of lights mark the cache stale.
static var _watching: SceneTree = null


## Returns estimated illumination in 0..1 at world-space point. asker must be a
## Node3D inside the tree/world. exclude RIDs affect shadow rays only. Refreshes the
## shared light cache and adds light occlusion_exclude metadata when present.
static func light_at(asker: Node3D, point: Vector3, exclude: Array[RID] = []) -> float:
	_refresh(asker)

	var space := asker.get_world_3d().direct_space_state
	var total := _ambient

	for light in _lights:
		if not is_instance_valid(light) or not light.is_visible_in_tree() or light.light_energy <= 0.0:
			continue

		# Sparks and other effect flashes are for show: they light no one up.
		if light.is_in_group(&"fx_light"):
			continue

		var strength := 0.0
		var toward := Vector3.ZERO
		var reach := 0.0

		if light is DirectionalLight3D:
			strength = 1.0
			toward = light.global_transform.basis.z
			reach = 200.0
		else:
			var offset: Vector3 = light.global_position - point
			var distance := offset.length()

			if light is OmniLight3D:
				if distance >= light.omni_range:
					continue

				strength = _falloff(distance, light.omni_range, light.omni_attenuation)
			elif light is SpotLight3D:
				if distance >= light.spot_range:
					continue

				strength = _falloff(distance, light.spot_range, light.spot_attenuation)
				strength *= _cone(light, -offset / maxf(distance, 0.0001))

			toward = offset / maxf(distance, 0.0001)
			reach = distance

		if strength <= 0.001:
			continue

		# In shadow? One ray from the point toward the light. A light is taken
		# as made (its "casts_shadow"), not as the shadow budget draws it.
		if light.get_meta(&"casts_shadow", light.shadow_enabled):
			var from := point + toward * 0.05
			var shadow_exclude: Array[RID] = exclude
			if light.has_meta(&"occlusion_exclude"):
				shadow_exclude = exclude.duplicate()
				shadow_exclude.append_array(light.get_meta(&"occlusion_exclude"))
			var query := PhysicsRayQueryParameters3D.create(from, point + toward * reach, 1, shadow_exclude)
			query.collide_with_areas = false

			if not space.intersect_ray(query).is_empty():
				continue

		var contribution: float = strength * light.light_energy * _luminance(light.light_color)
		total += -contribution if light.light_negative else contribution

	return clampf(total, 0.0, 1.0)


## Godot's omni and spot distance falloff.
static func _falloff(distance: float, light_range: float, decay: float) -> float:
	var nd := distance / light_range
	nd *= nd
	nd *= nd
	nd = maxf(1.0 - nd, 0.0)
	nd *= nd
	return nd * pow(maxf(distance, 0.0001), -decay)


## Godot's spot cone falloff. `direction` points from the light to the point.
static func _cone(light: SpotLight3D, direction: Vector3) -> float:
	var cone_angle := cos(deg_to_rad(light.spot_angle))
	var axis := -light.global_transform.basis.z
	var scos := maxf(direction.dot(axis), cone_angle)
	var rim := maxf(0.0001, (1.0 - scos) / maxf(1.0 - cone_angle, 0.0001))
	return 1.0 - pow(rim, light.spot_angle_attenuation)


static func _luminance(color: Color) -> float:
	return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b


## Rebuilds cache for a changed scene/light/environment or after REFRESH_SECONDS.
## Tree signals mark it stale; freed cached lights also trigger a refresh.
static func _refresh(asker: Node3D) -> void:
	var now := float(Engine.get_physics_frames()) / float(maxi(Engine.physics_ticks_per_second, 1))
	var tree := asker.get_tree()
	var scene := tree.current_scene
	var scene_id := scene.get_instance_id() if scene != null else 0

	if _watching != tree:
		_watching = tree
		tree.node_added.connect(_on_tree_changed)
		tree.node_removed.connect(_on_tree_changed)
		_refreshed_at = -100.0

	var stale := now - _refreshed_at >= REFRESH_SECONDS
	stale = stale or scene_id != _scene_id

	if not stale:
		for light in _lights:
			if not is_instance_valid(light):
				stale = true
				break

	if not stale:
		return

	_refreshed_at = now
	_scene_id = scene_id
	var root := tree.root
	_lights = root.find_children("*", "Light3D", true, false)
	_ambient = 0.0

	for node in root.find_children("*", "WorldEnvironment", true, false):
		var environment: Environment = node.environment

		if environment != null and environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR:
			_ambient = environment.ambient_light_energy * _luminance(environment.ambient_light_color)

		break


## Force the light list to be rebuilt on the next query. Call after adding
## or removing lights if two seconds is too long to wait.
static func invalidate() -> void:
	_refreshed_at = -100.0


## A node into or out of the tree: only a light or an environment makes the
## cache stale.
static func _on_tree_changed(node: Node) -> void:
	if node is Light3D or node is WorldEnvironment:
		_refreshed_at = -100.0
