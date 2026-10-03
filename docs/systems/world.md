# Exported levels, zones, and night weather

Level runtime construction has two stages: [LevelLoader](../../scripts/Level/LevelLoader.gd) creates geometry and loader-owned markers from exported files, then [LevelGameplay](../../scripts/Level/LevelGameplay.gd) builds the game objects the markers describe. Maps such as city and garrison orchestrate navigation, actors, and weather around those stages. Rendering resources are described in [rendering.md](rendering.md); weather playback is described in [audio.md](audio.md).

## Lifecycle and callers

1. Export a level into `res://assets/level/<name>/`, including `<name>.json` and optional `<sector>.glb` files.
2. Call `LevelLoader.load_level(parent: Node3D, folder: String, root_name="Level", skip_sectors: Array = []) -> Level`. The returned RefCounted record refers to newly added scene nodes; freeing the record does not free the root. A sector in `skip_sectors` is left out whole (no holder, mesh, collider, terrain, socket or marker). `LevelLoader.load_proxy(parent, folder, near := 60.0) -> Node3D` draws a district's `proxy.glb` only from `near` metres out, shadowless, with no collision.
3. Call `LevelGameplay.build_all(parent: Node3D, level) -> Dictionary` for doors, fixtures, water/climbing, routes/stations, loot, and mission places. `level` is dynamically typed and expected to expose `of()`, `marks`, and marker records.
4. Bake navigation before `LevelGameplay.guards(parent, level, route_nodes: Dictionary, station_nodes: Dictionary, scene: PackedScene) -> Dictionary`.
5. Configure Night with moon/environment and weather resources before adding it to the tree. Its child rain/audio/sky helpers start in `_ready()`. Zones and Wind can consume the resulting weather.

The loader creates one shared Zones controller for levels beneath the same map parent, preventing multiple districts from grading the same camera independently. The first night node in the tree's `night` group is the weather used by `Night.of()` and group lookups; the implementation does not perform spatial selection among multiple Nights.

## Districts as maps

The city is played one district at a time (`docs/superpowers/specs/2026-10-02-old-town-design.md`, section 3A). The registry `data/districts.json` names each district's map, levels, massing sector and whether other maps draw its proxy; the level pipeline (`tools/level/districts.py`, `rules.district_problems`) and Godot (`scripts/Level/Districts.gd`) both read it.

| Piece | What it does |
| --- | --- |
| [DistrictMap](../../scripts/Level/DistrictMap.gd) | The base of every district's map: loads its levels, the massing without its own sector (or those of districts drawn by proxy), the other districts' proxies; calls the district's `_dress()` (night, wind, life) and `_nav(baker)`; loads its navmesh from `assets/level/navmesh/<district>.scn` when the source hash matches, else bakes live (and says so); makes its guards; puts the player at `arrival`, `--vantage=<marker>` or its first spawn. Options: `--fps-report=<s>`, `--bake-navmesh` (bake, save, quit). [city.gd](../../maps/city.gd) is the harbour's, [old_town.gd](../../maps/old_town.gd) the stand-in old town's. |
| [Mission](../../maps/mission.gd) (`res://maps/mission.tscn`) | Holds the map in hand. At an exit whose `to` is a built district: what the player holds or shoulders is set down at the gate, `CityState.leave`, dark, the next map built with the player at the exit's `arrive`, up again. Exits ignore the player for 1 s after he arrives; an exit to an unbuilt district only says where it leads. |
| [CityState](../../scripts/Level/CityState.gd) (autoload) | The city's memory: each district's state as the player left it, what he carries (`PlayerController.save_state`: health, purse, keys, belt) and the watchmen following him. A man fighting the player within 30 m of the gate follows: away from his district, made again on the far side (`LevelGameplay.visitor`) a pace behind the arrival, as long after the player as his run takes. |
| [DistrictState](../../scripts/Level/DistrictState.gd) | One district's state, keyed by marker name: `capture(parent, made, guards, visitors)` and `apply(...)` over doors, chests, pickups, lamps (`save_state`/`load_state` on each), props, mechanisms, guards (up, down or away), bodies and visitors. This is the save contract: saving writes the same to disk. |

The navmesh is baked offline with `tools/level/level.sh navmesh <district>` after a district is exported; `NavBaker.save_baked(path, hash)` keeps its land mesh, swim and doorway regions and links (a climb's volume by its path), `load_baked(path, hash)` puts them back and re-ties water, doors and climbs by name. `NavBaker.source_hash(folders, settings)` hashes the levels' manifests and sector meshes and the baker's settings.

## Export schema

The manifest is JSON. Exported vectors are `[x,y,z]`, basis matrices are **rows**, and the loader constructs Godot Basis columns explicitly. Transforms use marker/collider world placements. `_vector()` returns ZERO for a non-Array, but short/bad numeric arrays and absent required keys are not fully validated.

| Top-level field | Type / record |
| --- | --- |
| sectors | Array of sector names; each gets a holder and, if available, an instantiated `<sector>.glb`. |
| colliders | Array of `{sector, surface, size:[x,y,z], basis:[[...],[...],[...]], centre:[x,y,z], occluder?:bool}`. Physics always uses boxes; occluder defaults true for eligible geometry. |
| ranges | Dictionary of exported node name -> visibility end distance in metres; four-metre fade margin. Blender dots in names become underscores. |
| shadowless | Array of node/piece names whose GeometryInstance3D shadows are disabled. |
| terrain | Array of `{sector, name, surface, occluder?:bool}`; a named MeshInstance3D supplies trimesh collision and optional matching mesh occlusion. |
| markers | Array of raw `{name, ucd, sector?, position:[x,y,z], basis:rows, size?:[x,y,z] or null, props?:Dictionary}`. |
| sockets | Array of `{piece, kind, sector, position}`; copied as raw data for map consumers. |

`Level` exposes root `Node3D`, name `String`, sectors `Dictionary`, markers `Array`, by_name/marks `Dictionary`, sockets `Array`, and zones `Node` or null. `Level.of(ucd: String) -> Array` filters marker records. `get_marker(marker_name: String) -> Dictionary` returns the indexed record or `{}`. Duplicate names overwrite by_name/marks entries while still existing in the full marker list.

Normalized marker records are `{name:String, ucd:String, sector:String, transform:Transform3D, size:Vector3|null, props:Dictionary}`. `marks` values are Marker3D nodes. All builder size/placement assumptions come from this schema; a marker needing a volume must provide size.

| Loader-owned ucd | Scene output |
| --- | --- |
| vantage | Marker3D in cine_vantage, optional lens metadata from props.lens. |
| hide | Marker3D in hide_spot with label metadata. |
| hunt_area | Marker3D in hunt_area with label and world-axis AABB metadata built from origin/size. Rotation is not applied to that metadata box. |
| mark / spawn | Named Marker3D in Level.marks. |
| landmark | Named mark plus landmark group/label. |
| zone | Transformed Zones box; props.grade required, fog default 1, fog_color default empty. |

## Geometry and occlusion constraints

Sector mesh material slots map to shared Materials resources; baked vertex colour remains part of the material. Slot shadowless flags can disable card shadows. Colliders are grouped by sector and surface under StaticBody3D nodes on physics layer 1 with surface metadata. A `ceiling` collider blocks bodies/sight/throws, is labelled wood for impacts, and joins `nav_ignore` so navigation does not treat its pitched underside as walkable terrain.

Box occluders only exist where the two largest collider dimensions are at least 3 and 4 metres and surface is not ceiling. An explicit `occluder:false` suppresses only occlusion; the physical barrier remains. This matters for movement barriers spanning visible openings. Terrain uses actual imported mesh geometry for collision, and only emits mesh occluders when requested. Missing terrain meshes report errors and skip those entries. Visibility ranges and shadowless names match either the geometry node or its parent after name normalization.

An empty/unreadable manifest reports an error and returns a Level with null root. Missing sector GLBs leave empty sector holders without an error. JSON is assigned directly to Dictionary and required nested keys are indexed; malformed JSON, wrong field types, and broken imported resources can fail rather than yielding a fully valid level. Maps must not assume root exists after a failed manifest load.

## Gameplay marker contracts

`build_all()` returns `{doors,lights,water,ladders,ropes,bells,decals,routes,stations,pickups,chests,props,smokes,noise_zones,mechanisms}` and also calls `mission_marks()` (void). It does not build guards. Dictionaries are name -> node; Array collections preserve creation order rather than name indexing.

| Builder -> result | Markers / props consumed and side effects |
| --- | --- |
| doors -> Dictionary | door: width 1.2, height 2.2, locked false, key empty, label door, pick true. Marker is opening centre; hinge is shifted half-width along basis.x. Gives tall panels wood_studded material. |
| lights -> Array | light: required kind; optional positive energy/range, Color string, chain. torch, brazier, candle, lantern, lamp_post, chandelier, hearth, fire build fixtures; glow/window create OmniLight3D; window_shaft creates glass-projector SpotLight3D with calm metadata and glass_shafts group. Unknown kind returns null/skips. |
| water -> Array | water size and murk .6; builds WaterVolume, sets clarity to 1-murk, and defers ripple setup. |
| ladders -> Array | ladder size and rope false; Area3D with ClimbVolume script, at marker transform. |
| ropes -> Array | rope length required, chain false; VerletRope positioned before adding so links hang from the correct origin. |
| bells -> Array | bell markers create alarm interaction at their placement. |
| decals -> Array | decal kinds/textures/size create wall decals or ground-stain cards; optional missing images can be skipped. |
| routes -> Dictionary | route plus waypoint props.route/order; creates `<route>_route` Node3D with ordered Marker3D children. |
| stations -> Dictionary | station props.kind required; optional drop_to name resolves through Level.marks and becomes a NodePath. |
| guards -> Dictionary | guard scene instantiated as CharacterBody3D; archetype/temperament/look_seed/lookout/light, comma-separated stations, optional route; watchman maps to default archetype, arms_master to trainer. Missing optional route/station references are ignored. Requires navigation ready. |
| pickups -> Dictionary | loot value required, label/special/kind (seal groups); key key_id required; tool required kind/count/label. Supported tool kinds use TOOLS; arrows build quiver contents. Unknown tool is skipped. |
| chests -> Dictionary | chest large/locked/key/label/pick; default dimensions .9×.55×.55 m, large 1.2×.7×.7 m. |
| props -> Array | prop kind/mass; crate or crate_small size/mass presets; unknown kind uses crate preset. Positive mass overrides preset. |
| smokes -> Array | smoke markers (no properties): a ChimneySmoke at each, breathing FireParticles smoke off its pots on the night's wind within 110 m of the player. |
| noise_zones -> Array | noise_zone size/db and optional period; steady entries return SoundBus IDs and register parent-exit cleanup. Positive period builds a Blowhole at box top; results mix IDs and nodes. |
| mechanisms -> Array | lever/wheel/portcullis/sluice/hoist/slider, target/state/label metadata in mechanism group. Portcullis additionally creates solid metal Grid; other entries are runtime stubs. |
| mission_marks -> void | objective requires label, optional kind steal; exit/secret create box Area3D with label/groups and mask 1|2; probe requires expect metadata. Map/objective code watches these nodes. |

`LevelGameplay.raise(node: Node3D, up: bool) -> void` immediately shifts a portcullis Grid by height minus .35 m and writes state up/down. Missing Grid is ignored. It does not animate, bind a lever, or implement other mechanism interactions.

## Atmosphere zones

[Zones](../../scripts/Level/Zones.gd) keeps transformed boxes and precomputed inverse transforms. `add_zone(zone_name: String, at: Transform3D, size: Vector3, grade: String, fog: float, fog_color: String) -> void` accepts size in metres, fog multiplier, and a colour string (empty uses grade). Unknown grade gets outside colours, while the supplied grade name is still stored. Presets are outside, indoors, chapel, cellar, and hearth.

`zone_at(point: Vector3) -> String` gives the smallest containing box name or empty; `grade_at(point) -> String` returns grade/default outside. `look() -> Dictionary` returns **live** mutable state: shadow/mid/high/fog_color Color, saturation/fog float. Treat it as read-only. Every frame it follows the active viewport camera, easing with `clamp(delta/EASE,0,1)`; EASE=1 s is an interpolation rate, not a fixed-duration tween. No camera means no update. It installs an environment colour-correction LUT and saturation; fog goes to Night.zone_fog/zone_fog_color, or directly multiplies captured base fog when no Night exists. Missing environment delays application.

## Night API and weather state

[Night](../../scripts/Night/Night.gd) extends Node3D and creates Rain/NightSound children plus a NightSky helper. It uses a shared image cloud field for both sky and CPU moon coverage; a visible cloud crossing the moon is the same density that dims its light. Separate weather/sky random generators avoid disturbing gameplay sequences after initialization; seed 0 draws its initial seed from world RNG.

| API / signal | Inputs / result / side effects |
| --- | --- |
| `to(to_state: StringName, seconds: float, after=0.0) -> void` | STATES key and game seconds. Nonpositive seconds jumps; positive after queues. Immediate changes clear queued requests. Unknown key warns/does nothing. |
| `state_changed(state: StringName)` | Emitted when the named target state changes, before an eased transition necessarily finishes. |
| `cycle() -> void` | Moves to next ORDER state over 2 game seconds. |
| `cover_moon(_hold: float) -> void` | Deprecated no-op compatibility; does not pin/teleport clouds. |
| `flash() -> void`; `flashed` | Starts lightning immediately and queues thunder 1–4 game seconds later. Chooses a sky direction/bolt seed. |
| `thundered(delay: float)` | Emitted when scheduled thunder occurs; delay is elapsed travel delay from the flash, also used for volume attenuation. |
| `cloud_cover() -> float` | Moon-disc cloud average [0,1], equal-area samples. |
| `moon_visibility() -> float` | Cloud-derived visibility of the moon; scene moon/light values are separate from the painted shader disc. |
| `moon_direction() -> Vector3` / `sky_uv(dir: Vector3) -> Vector2` | World moon direction / sky cloud projection used by density sampling. |
| `density_at(dir: Vector3) -> float` / `field_at(uv: Vector2) -> float` | Cloud density along direction / wrapped interpolated cloud-field sample. |
| `rain() -> float` / `wind() -> Vector3` / `masking_db() -> float` | Current eased rain fraction, world wind m/s, gameplay background masking dB. |
| `moon_share() -> float` | Current moon energy / clear baseline; includes lightning, can exceed 1; absent/nonpositive baseline returns 1. |
| `mist_density() -> float` | Bank density from current fog multiplier, clamped to configured mist range. |
| `indoors(point: Vector3) -> bool` | Layer-1 ray 30 m upward, no areas; false when outside tree. |
| `splashes_at(point: Vector3) -> bool` | True near configured puddle positions when wetness exceeds .3 and foot height matches. |
| `register_wet(material: BaseMaterial3D) -> void` | Keeps dry albedo/roughness in night_dry metadata, edits material as wetness changes, restores on exit. Null/duplicate ignored. |
| `of(node: Node) -> Node` | First night group node, or null for detached/no-night context. |

| STATES key | cover / rain | wind m/s | fog multiplier | masking dB / lightning |
| --- | --- | --- | --- | --- |
| clear | .15 / 0 | 1 | 1 | 0 / false |
| cloudy | .5 / 0 | 2 | 1 | 0 / false |
| drizzle | .65 / .25 | 2 | 1 | 3 / false |
| shower | .8 / .6 | 4 | 1.25 | 6 / false |
| rain | .9 / .8 | 5.5 | 1.3 | 8 / false |
| storm | .95 / 1 | 8 | 1.6 | 10 / true |
| fog | .4 / 0 | .5 | 4 | 0 / false |

Weather `_now`/`_from`/`_to` dictionaries use cover/rain/wind/fog/mask numeric values plus lightning bool; state is the target label, and wetness is accumulated separately. Zone fog multiplies level/weather fog. Wetness rises over WET_RISE=30 s and dries over WET_DRY=120 s; it darkens/smooths eligible surfaces and reveals configured puddles. Exit resets global SoundBus.masking_db to 0 and restores materials, so scene-owned Night should be removed during replacement.

NightSky `_init(environment: Environment, field: Texture2D, skyline := "")` installs a ShaderMaterial/Sky on the supplied environment; skyline has an inferred String default. `show_night(cover:float, offset:Vector2, flash:float, fog:float, clock:float)`, `show_lightning(direction:Vector3, bolt:float, seed:float)`, and `show_cirrus(amount:float)` write shader uniforms with no return value. The shared cloud Texture2D remains the authoritative density input. Skyline reads fall back to the local noise ridge; moon imagery also has a generated fallback when absent.

## Script and shader inventory

| File | Role / principal consumer |
| --- | --- |
| [LevelLoader](../../scripts/Level/LevelLoader.gd) | Export JSON/GLB, static geometry/collision/occlusion, normalized markers, Level result record. |
| [LevelGameplay](../../scripts/Level/LevelGameplay.gd) | Map builders for gameplay markers and mission/group metadata. |
| [Zones](../../scripts/Level/Zones.gd) | Shared camera atmosphere grading/fog controller. |
| [Night](../../scripts/Night/Night.gd) | Map weather transitions, cloud/light coherence, masking, wetness and lightning. |
| [NightSky](../../scripts/Night/NightSky.gd) | RefCounted sky material installed on an Environment; frame uniforms/skyline and moon image fallback. |
| [NightSound](../../scripts/Night/NightSound.gd) | Weather playback only; Night publishes gameplay mask separately. |
| [Rain](../../scripts/Night/Rain.gd) | Camera-following GPU drops, heightfield roof collision, splashes, shelter queries. |
| [night_sky shader](../../scripts/Night/night_sky.gdshader) | Sky colour/stars/cirrus, shared field cloud coverage/offset, painted moon face and skyline; lightning bolt direction/seed and fog/flash inputs. Produces sky radiance, not gameplay decisions. |

NightSky replaces environment.sky/background with a generated Sky; its helper is not a Node and is owned by Night. Rain.amount is [0,1], Rain.wind is world m/s, and `sheltered() -> bool` returns the last quarter-second roof query. Cameras absent from the viewport skip rain updates. Weather audio tolerates missing recordings, and Night tolerates absent moon/environment for partial effects; imported particle/shader assets and correct map volume placements remain prerequisites for visual fidelity.
