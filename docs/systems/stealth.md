# Exposure, sensing and gameplay stimuli

Stealth uses two illumination measurements and a gameplay sound bus. Player exposure combines rendered light with stance/motion; Guard vision combines exposure with range, view cone and cover. Bodies and search locations use arithmetic light estimates. Gameplay sound events carry position/loudness independently of speaker audio. [AI](ai.md) describes the resulting alert/hunt/life transitions; the [declaration reference](../reference/README.md) inventories every script API.

## Source map

| Source | Responsibility | Inputs / outputs |
| --- | --- | --- |
| [light_gem.gd](../../light_gem.gd) | `LightGem: Node3D` reads two rendered views | Viewports + Curve -> `raw_value`, calibrated `value` |
| [LightProbe.gd](../../scripts/StimuliSystem/LightProbe.gd) | Static world-point light estimate | Scene Node3D + world point + excluded RIDs -> `float` 0..1 |
| [SoundBus.gd](../../scripts/StimuliSystem/SoundBus.gd) | Static synchronous stimulus dispatch | Sound/message + masking -> listener callbacks |
| [Guard.gd](../../scripts/AISystem/Guard.gd) | Sight/hearing/body interpretation | Exposure/sight points, SoundBus events, bodies -> alert/location/state/signals |
| [SearchSpots.gd](../../scripts/AISystem/SearchSpots.gd) | Scores dark/occluded places for searching | World candidate locations + LightProbe -> search dictionary or `{}` |
| [Comms.gd](../../scripts/AISystem/Comms.gd) | Guard-to-guard message envelope | Speaker + report + location -> SoundBus message event |
| [PlayerController.gd](../../scripts/PlayerController.gd) | Exposure and body samples supplied to Guard | LightGem, stance, velocity, lean and water -> exposure/sight points |

## Rendered player light

`LightGem` exports `viewport_top: Viewport`, `viewport_bottom: Viewport`, `calibration_curve: Curve`, and `frames_between_samples = 3` (default, no explicit annotation). `raw_value`, `value` and `frame_counter` likewise have dynamic `=` declarations. Both viewports and the curve must be assigned. `_ready()` is an empty hook; sampling happens in `_process(delta: float)`, though elapsed `delta` is not used. Sampling counts process frames, not physics frames or seconds.

On every configured sample, the gem takes the larger top/bottom reading and calls `calibration_curve.sample(raw_value)`. The script does not clamp `value`; the player's `get_light_level()` clamps it to 0..1. A curve can therefore intentionally recalibrate low renderer values without changing the raw probe.

| Method | Contract |
| --- | --- |
| `sample_viewport(viewport) -> float` | Untyped viewport must implement `get_texture().get_image()`. A null image returns 0.0. Reads every pixel of a square image, ignoring alpha < 1, then returns the largest mean of its four triangular regions. |
| `classify(x, y, N) -> int` | Untyped numeric pixel coordinates and `N = width - 1`; returns triangle index 0..3 according to the two diagonals. |
| `luminance(color) -> float` | Untyped color must expose r/g/b; returns `0.299*r + 0.587*g + 0.114*b`. Alpha filtering is done by the caller. |

The implementation uses width for both loops; non-square images do not satisfy its capture contract. If all regions have no fully opaque pixels, reading is zero. A missing viewport/texture/curve is not a handled fallback. On headless DisplayServer, `_process()` returns before rendering access and keeps previous values (initially zero); it does not simulate illumination. Image reads copy GPU texture data and can be expensive, motivating sample spacing. Capture-layer/environment configuration belongs to scene/visual setup: probe views should exclude effects and viewmodels and measure lighting rather than fog/glow.

`PlayerController.get_light_level() -> float` uses a valid LightGem's clamped value or `debug_light_level` without a gem. `get_exposure() -> float` returns:

```text
clamp(light * stance * (1 + motion_exposure * moving), 0, 1)
moving = clamp(max(horizontal velocity, motion speed) / walk_speed, 0, 1.3)
```

Crouching uses `crouch_exposure`; swimming uses 0.6 above water or water clarity when underwater. `get_sight_points() -> Array` supplies world `Vector3` samples at head/chest/shins; lean shifts only the head. The player origin is its standing capsule centre, unlike the Guard's feet origin.

## Arithmetic light at arbitrary locations

`LightProbe.light_at(asker: Node3D, point: Vector3, exclude: Array[RID] = []) -> float` requires an asker inside a SceneTree/World3D and a world-space point. It refreshes its shared cache as needed, starts with the first applicable WorldEnvironment's color ambient contribution, and accumulates visible positive/negative light energy times luminance and falloff. The result is clamped to 0..1. Missing lights/ambient yield zero; there is no separate error sentinel.

Directional lights contribute a unit-strength direction with a 200 m shadow ray. Omni and spot lights use distance/range attenuation; spot lights add a cone factor along local -Z. The arithmetic follows the intended Godot falloff but is an estimate: it excludes bounced light, does not reproduce every renderer/environment feature, and filters out invisible/nonpositive-energy lights and those in `fx_light`.

Shadow queries use collision mask 1 and exclude areas. `casts_shadow` metadata overrides `shadow_enabled`, preserving the authored shadow decision even when rendering budgets disable a shadow. Rays start 0.05 m toward the light. `occlusion_exclude` metadata adds an Array of RIDs for a fixture's own collision shell; caller `exclude` RIDs likewise prevent self-shadowing. Exclusions affect shadow rays, not which light nodes contribute.

The static cache stores scene id, light list, ambient and refresh time. A new tree connects light/environment add/remove callbacks; current-scene changes, freed cached lights, relevant tree changes or 2 s expiry trigger a rebuild. `invalidate() -> void` marks the cache stale for the **next** query; it does not itself rescan. Energy/color/transform/visibility are read during each query, while newly available environment/list entries depend on cache refresh. No headless bypass exists here: arithmetic/physics queries remain usable with an appropriate scene world.

## Guard sight and body detection

`Guard._visibility_of(target: Node3D) -> float` expects `get_exposure()` and `get_sight_points()` (Array of world Vector3). Missing target/exposure API or no visible samples produces zero. A target with the exposure method but without sight points violates the duck-typed interface. It rejects all-out-of-range targets before rays, tests horizontal/vertical view cone and line of sight per sample, then multiplies:

```text
visibility = distance_adjusted_exposure * strongest_visible_cone * visible_samples / sample_count
certain_distance = sight_min * exposure
gone_distance = sight_max * exposure
```

Within certain_distance, distance contribution is exposure; it fades to zero at gone_distance. Defaults are sight_min=12 m and sight_max=35 m. Cone checks look along logical Head -Z (or guard basis), not animated rig eyes. Default horizontal/vertical FOV is 140°/90°; periphery starts at 55% of cone extent and falls to 40% strength at the edge. `_line_of_sight(from, to, target)` excludes own/target collision RID, excludes areas, and also accepts hitting a collision child belonging to the target. Exported `sight_mask` defaults to world mask 1.

Contact within `touch_distance` (1 m) or close combat within 3 m raises visibility to at least 0.6 **after** cone/occlusion/sample checks. It does not grant sight through a wall or behind the cone. Station sleep disables vision; habit dozing still permits contact-level sight. Blindness and a dead player disable target vision. Acquire/keep thresholds are 0.02/0.01 visibility, preventing flickering sight; `_sense_vision(delta)` updates last-known position/heading and adds `visibility * vision_gain * wariness * delta` toward the combat cap. Hearing alone does not satisfy ordinary combat entry's visibility requirement.

Bodies join `bodies`; killed and unconscious bodies are both discoverable. `_sense_bodies(delta)` runs at roughly 0.15 s intervals (initially staggered per guard), checks visible/unknown Node3D bodies, view cone and clear ray to `body.global_position + UP*0.25`, then uses LightProbe with guard/body RID exclusions. Defaults require light >= 0.08 and accumulated `interval * cone` notice >= 0.5 s. Distance uses the same light-scaled sight limits. Losing cone/ray/light/range clears that body's accumulating notice. Sleep/doze clears notice; blindness prevents checks.

Discovery records known bodies, optionally grieves a named corpse, and counts the first discovery in Garrison. Nearby known pieces count as one local find. A combat guard can register a discovery without changing search or emitting the ordinary new-body event. Otherwise it records location, raises alert/wariness, emits `found_body(body: Node3D)`, starts/refreshes search and may shout subject to cooldown. Discovery does not identify the player's current location or immediately grant combat sight. Hidden/carried body visuals and darkness therefore affect detection separately from player exposure.

## Gameplay sound and masking

`SoundBus` extends `RefCounted` with static state; it is not an autoload and has no signals. Scripts sharing its preload share listeners, global `masking_db`, zones and debug flag. `add_listener(listener: Object)` deduplicates; the listener must implement `hear_sound(event: Dictionary)`. `remove_listener(listener)` is safe when absent. Dispatch iterates a copy, prunes freed listeners and excludes the source; callback ordering follows registered order. The same event dictionary reaches listeners, so treat it as read-only.

`range_for(db: float) -> float` returns `15 * 2^((db - 50) / 7)` metres. `emit_sound(position: Vector3, db: float, source: Object, kind: StringName, also_skip: Object = null) -> void` and `emit_message(position, db, source, kind, message: Dictionary) -> void` both ignore db <= 0. Positive original db still emits even when masking reduces effective db below zero.

| Event field | Value |
| --- | --- |
| `position` | `Vector3` sound origin in world coordinates |
| `db` | `float` original loudness, unmodified by masking |
| `range` | `float` metres computed from db minus emission-point masking |
| `source` | `Object`, which is excluded from callbacks |
| `kind` | `StringName` stimulus category (footstep, impact, shout, call, etc.) |
| `message` | Optional `Dictionary`, present for emit_message; Comms schema is in [AI](ai.md) |

`also_skip` excludes a second sound listener, used when a guard should not hear a blow against his own helmet as a distant stimulus. Message emission has no second skip argument. The bus does **not** perform distance, wall or navmesh tests: each listener interprets audibility. Debug dispatch draws an event sphere/text via DebugDraw3D, independently of audio playback.

Noise-zone API:

| Method | Inputs / effects / result |
| --- | --- |
| `add_zone(box: AABB, db: float) -> int` | Stores a world-space box and noise floor; returns increasing id. |
| `set_zone_db(id: int, db: float) -> void` | Updates known zone; unknown id is no-op. |
| `remove_zone(id: int) -> void` | Deletes zone; unknown id is no-op. |
| `clear_zones() -> void` | Clears zones; does not reset listeners/global masking/id sequence. |
| `masking_at(position: Vector3) -> float` | Maximum of global masking and containing zones; overlapping zones do not sum. |

Zones are stored internally as `id -> [AABB, db]`. Masking is evaluated where the sound is **made**, not at listener ears; there is no per-segment transmission model in this bus.

`Guard.hear_sound(event: Dictionary) -> void` first ignores incapacitated guards, routes messages separately, and computes reach from event range times hearing acuity. Habit dozing multiplies hearing by 0.35; station sleep multiplies it by 0.15. A straight-line rejection precedes `_sound_distance(position)`. That method asks the navmesh with all navigation layers (locks do not block sound), sums path segments and never reports less than straight distance. Missing/too-short paths or a final point more than 2 m short of the source use **twice** straight distance, rather than infinite range loss.

Ordinary sounds add alert according to original db, closeness and wariness, capped by `hearing_alert_cap` (85 default) without lowering an already higher alert. Very small contributions are ignored. The perceived location gains horizontal random blur proportional to sound distance. A colleague's ordinary sound is ignored; a shout can redirect to the colleague's last-known trouble location, or the colleague's own position when relaxed. Structured messages also use reach/navmesh filtering and sleeping acuity, then apply report-specific freshness/area/cover rules. Audio volume and these gameplay db values serve different consumers: audible playback alone creates no AI stimulus.

## Integration constraints and failure values

A custom detectable actor needs `get_exposure() -> float` in 0..1 and `get_sight_points() -> Array` of world Vector3; dynamic `velocity: Vector3` improves heading/pursuit, and `get_aim_point()`/`is_off_feet()` are optional integration hooks. Guards obtain their ordinary target from the `player` group. Own sight uses feet/eye coordinates, whereas player sight samples compensate for its centre origin.

Null rendered image -> gem reading zero; headless renderer -> existing gem values retained. LightProbe -> clamped numeric estimate with no null result. Invalid SoundBus listener methods are an integration error, not a silently skipped category. Navmesh sound failure -> doubled straight distance. No suitable hiding place -> `{}`; optional squad point/vantage -> `null`; unavailable internal Vector3 goals/focus -> `Vector3.INF`. These sentinels are not interchangeable, and zero illumination is valid gameplay data.

Complete declaration listings: [LightGem](../reference/gdscript/light_gem.md), [LightProbe](../reference/gdscript/scripts/StimuliSystem/LightProbe.md), [SoundBus](../reference/gdscript/scripts/StimuliSystem/SoundBus.md), and [Guard](../reference/gdscript/scripts/AISystem/Guard.md).
