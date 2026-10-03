# Maps, asset tools and verification

Practice maps instantiate the same player, guard, interaction and environment systems as playable levels. The asset pipelines author Blender scenes, validate data, export runtime assets and let Godot import them. Tests exercise runtime contracts; visual stages produce rendered evidence. The [reference index](../reference/README.md) includes every first-party map script, Godot diagnostic, shader and non-test Python tool with its full declarations.

## Dependencies and entry points

Run commands from the repository root. Runtime and suite commands need Godot 4.5; the project currently uses Forward+. `GODOT` selects the executable for shell tools. Blender pipelines use `BLENDER`; their Python code imports `bpy`, so run them through their shell wrappers or Blender rather than ordinary Python. Pure geometry/rule tests and reference generation use Python 3 without Blender. Image/audio tools additionally need the packages listed below.

```sh
godot --path . res://maps/traversal_gym.tscn
GODOT=godot bash tools/run_suites.sh tests/water_geometry_test.tscn tests/swim_polish_test.tscn
python3 tools/docs/build_reference.py --check
```

Platform-specific executable defaults live in the wrappers; use the environment overrides on another machine. Optional generated source textures, recordings and build outputs can be ignored by Git; the authoritative source/recipe and [credits](../../CREDITS.md) determine how to regenerate and redistribute them.

## Map ownership

| Source | Responsibility / integration |
| --- | --- |
| [mission.gd](../../maps/mission.gd) | The game's way through the city: holds one district's map and swaps it at a gate, the district remembered (CityState). Run `res://maps/mission.tscn`. |
| [DistrictMap.gd](../../scripts/Level/DistrictMap.gd) | The base of every district's map: its levels, the rest of the city as massing and proxies, its navmesh (saved or baked), guards and player. Options after `--`: `--vantage=<marker>`, `--fps-report=<s>`, `--bake-navmesh`. |
| [city.gd](../../maps/city.gd) | The harbour's map (extends DistrictMap): its night, weather, puddles, mist, bats and navmesh settings. |
| [old_town.gd](../../maps/old_town.gd) | The stand-in old town's map (extends DistrictMap), until plan B1 builds the district. |
| [npc_showcase.gd](../../maps/npc_showcase.gd) | Base showcase geometry/cast lifecycle, intruder spawning, navigation and shared services. |
| [garrison.gd](../../maps/garrison.gd) | Extends the NPC showcase with exported level/marker setup and garrison-specific routes/events. |
| [traversal_gym.gd](../../maps/traversal_gym.gd) | Sixteen movement stations, timed runs, collision fixtures, resetting, presets and diagnostic HUD. |
| [MovementGymFixtures.gd](../../maps/MovementGymFixtures.gd) | Builds the advanced station geometry and gate positions. |
| [MovementGymRun.gd](../../maps/MovementGymRun.gd) | Ordered checkpoints, elapsed game time and best-run records by station/preset. |
| [combat_gym.gd](../../maps/combat_gym.gd) | Practice stations using production combat, targets and stimuli. |
| [combat_arena.gd](../../maps/combat_arena.gd) | Encounter and environmental-hazard exercises. |
| [interaction_gym.gd](../../maps/interaction_gym.gd) | Production frob, tools, doors, carryable items and mechanisms. |
| [stealth_gym.gd](../../maps/stealth_gym.gd) | Production visibility/hearing and stealth practice fixtures. |
| [npc_gym.gd](../../maps/npc_gym.gd) | Isolated guard exercises and navigation fixtures. |
| [lights_gallery.gd](../../maps/lights_gallery.gd) | Fixture state, strength, door and lighting inspection controls. |
| [retro_showcase.gd](../../maps/retro_showcase.gd) | Scene exercising the shared Retro autoload. |

The `.tscn` files are runnable scenes; helper resources such as `MovementGymRun.gd` are not standalone maps. [Movement practice](../../maps/MOVEMENT_GYM.md), [combat practice](../../maps/COMBAT_PRACTICE.md) and [water/sky practice](../../maps/WATER_AND_SKY_PRACTICE.md) describe controls and inspection routes.

## Important map APIs

| Function | Inputs / return | Effects and failure cases |
| --- | --- | --- |
| `city.marker(marker_name: String) -> Dictionary` | Marker ID, matching the Blender object's name. | Returns the first district's non-empty match or `{}` when absent. Treat returned data according to the level marker schema. |
| `npc_showcase.camera_home() -> Array`, `garrison.camera_home() -> Array` | No args; `[Vector3 camera_position, Vector3 look_target]` in world metres. | Query for showcase camera setup. |
| `npc_showcase.build() -> void` | No args. | Builds the scene environment/geometry setup; cast creation is a separate part of the showcase lifecycle. |
| `npc_showcase.spawn_intruder(at: Vector3, yaw := 0.0) -> CharacterBody3D` | World foot position, yaw in radians. | Creates/retains the scene intruder body; this is a scene command, not a query. |
| `garrison.pull_up_ladder() -> void` | No args. | Removes the assigned climb volume and disables its navigation links before retracting the ladder geometry. |
| `traversal_gym.select_station(index: int) -> void` | Zero-based index. | Wraps the index into the available stations and resets the player/run. |
| `traversal_gym.reset_station() -> void` | No args. | Restores player and mover state, resets timing, clears encounters/time effects. Retains best-run records and attempt counts. |
| `traversal_gym.checkpoint_reached(station: int, gate: int, body: Node3D) -> void` | Zero-based station/gate; entering body. | Ignores other bodies/stations; accepts only the selected player's next gate and refreshes the HUD. |
| `traversal_gym.add_mover(at: Vector3, size: Vector3, axis: Vector3, distance: float, speed: float) -> void` | Parent-local position/size in metres; direction vector; amplitude in metres; phase rate in radians per game-time second. | Creates an `AnimatableBody3D` blocker with visual/collision. Motion is `origin + axis * sin(time * speed) * distance`; axis is used as supplied, so normalize it for distance to equal the amplitude. |
| `MovementGymFixtures.build(gym: Node3D, index: int) -> void` | Active gym and advanced station index. | Adds station fixtures under the gym's fixture root and updates gate positions. Requires the gym's build-helper protocol. |
| `MovementGymRun.reset(index: int, count := 3, setting := "60 Hz / 1.0x") -> void` | Zero-based station, gate count, preset string. | Clears current progress/splits, restores that preset's best time and increments station attempt count. Retains historical records. |
| `MovementGymRun.tick(delta: float) -> void` | Elapsed game-time seconds. | Accumulates time only while a run is active. |
| `MovementGymRun.reach(gate: int) -> bool` | Next zero-based gate index. | `false` for wrong order or finished run. First gate starts timing; accepted gates append splits; final gate stores best time and stops timing. |
| `lights_gallery.burners() -> Array[Node3D]` | No args. | Returns nodes in the `torches` group that are descendants of this gallery, including held lights still under it. |
| `lights_gallery.cycle_lights() -> void` | No args. | Advances all returned fixtures through the gallery's lit/snuffed/doused cycle. |

## Level pipeline

[level.sh](../../tools/level/level.sh) is the public command interface. `LEVEL_SOURCE` overrides the `.blend` source directory (default `assets/level/source`); `BLENDER` and `GODOT` override executable locations.

| Command | Inputs | Outputs / status |
| --- | --- | --- |
| `tools/level/level.sh kit` | Kit recipes. | Builds `kit.blend`. |
| `tools/level/level.sh build <level> [--force]` | Layout module name under `tools/level/layouts`. | Builds `<level>.blend`; refuses a detected hand-edited source unless `--force` is explicit. |
| `tools/level/level.sh check <level> [stage]` | Existing `.blend`; stage budget. | Prints validation messages; writes no runtime export. |
| `tools/level/level.sh export <level> [stage]` | Validated source; wrapper defaults to `stage2`. | Sector GLBs and level JSON under `assets/level/<level>`, then attempts Godot import. |
| `tools/level/level.sh preview <level> [out]` | Existing source; optional output folder. | Plan and bird's-eye inspection images. |
| `tools/level/level.sh all <level>` | Layout/kit source. | Runs kit, build, export in order. |
| `tools/level/level.sh test` | Test fixtures. | Pure Python checks plus the Blender build-overwrite guard. |

Failed pipeline steps exit nonzero. Blender edit protection uses the content hash stored by the build; the shell wrapper and [edited.py](../../tools/level/edited.py) document the older-file case where no stored hash exists. Export imports may be nonfatal in the wrapper; a successful Blender export alone is not evidence that Godot imported the result successfully.

### Layout and manifest data

Coordinates use Godot axes, metres, and row-major 3×3 basis matrices whose columns are object axes. Layout helpers take yaw/pitch/roll in **degrees**, composing YXZ rotations. Blender conversion maps `[x, y, z]` to `[x, -z, y]`. These Python values are numeric lists/tuples; they are not Godot `Vector3`/`Basis` objects.

| Record | Required fields / shape |
| --- | --- |
| Layout | `level: str`, `pieces: list[dict]`, `markers: list[dict]`, sector information; optional `tris` kit triangle counts and `terrain`. |
| Placed piece | `name: str`, `piece: str` recipe key, `sector: str`, `position: [x,y,z]`, `basis: [[...],[...],[...]]`. |
| Marker | `name: str` object ID, `ucd: str` kind, `sector: str`, `position`, `basis`, `size: [x,y,z] or None`, `props: dict`. |
| Runtime collider | `sector`, `centre: [x,y,z]`, `basis`, `size` full extents, `surface: str`; `occluder: false` is emitted for excluded proxies, otherwise omitted. |
| Runtime socket | `piece: str` placed-piece name, `kind: str`, `sector: str`, world `position`. |
| Runtime terrain | `name`, `sector`, `surface`, `occluder: bool`; the named exported mesh supplies collision. |
| Export manifest | `level`, `sectors`, `colliders`, `markers`, `sockets`, `pieces` count, `ranges` draw-distance mapping, `terrain`, `shadowless` names. |

Marker `props` are validated and defaulted by [markers.py](../../tools/level/markers.py). Its `SCHEMA` is authoritative for required/optional fields and box/point kinds; `write_json(path)` exports the schema/options for tooling. Names link guards/routes, doors/keys and mechanisms/targets. [LevelLoader](../../scripts/Level/LevelLoader.gd) consumes the manifest; see the [world guide](world.md) for its runtime outputs.

### Core tool contracts

| API | Inputs | Return / effects |
| --- | --- | --- |
| `Layout.put(...)` in [lay.py](../../tools/level/layouts/lay.py) | Recipe key, three-vector placement, degree rotations, sector/name and optional climb creation. | Appends placed pieces and optional ladder markers; returns the generated/explicit name string. Unknown recipe raises `KeyError`. |
| `read.read()` | Current Blender scene. | Level dictionary converted to Godot axes; no file export. |
| `markers.problems(marker)` | Marker dictionary above. | `list[str]` failures; `[]` passes. Does not mutate input. |
| `markers.with_defaults(marker)` | Marker dictionary. | Shallow copy with fresh `props`; explicit values override optional defaults. Other nested values remain shared. |
| `rules.problems(data, stage="stage1")` | Layout/read-back dict and `stage1`/`stage2`. | `list[str]` validation failures; `[]` passes. Per-sector triangle budgets are 60,000 / 120,000. |
| `check.check(stage="stage1")` | Open Blender level and stage. | `(data: dict, failures: list[str])`; prints failures/summary. CLI exits 1 when failures exist. |
| `export.manifest(data)` | Validated level dictionary. | JSON-ready manifest above with rounded world transforms/defaulted marker props. Does not write files. |
| `geo.rotation(yaw=0, pitch=0, roll=0)` | Degree angles. | New row-major 3×3 Godot basis. |
| `geo.Box(centre, basis, size, surface="")` | Three-vectors and basis; full extents. | Oriented box storing absolute half-extents. Copies centre, retains basis; `occluder` initially true. |
| `Box.contains(point, margin=0)` | World three-vector, metre margin. | `bool`; positive margin shrinks the box. |
| `Box.ray(origin, direction)` | World origin and unit direction vectors. | Entrance distance `float` in metres, `None` on miss, `0.0` from inside. |
| `geo.TriGrid(triangles, cell=4)` | World triangle three-vectors; positive cell size in metres. | Spatial lookup; skips vertical/degenerate xz projections. |
| `TriGrid.heights(x,z)` / `down(point,reach)` / `up(point,reach)` | World metres. | Unsorted `list[float]` heights / nearest nonnegative distance or `None` within reach. |
| `geo.piece_boxes(recipe,position,basis,which="cols")` | Recipe dict and world transform; collision `cols` or visual `boxes`. | `list[Box]`; collision exclusions retain physical collision but cannot become occluders. |
| `rules.ground_of(data)` | Layout terrain (verts/faces) or read-back terrain (tris). | `TriGrid` or `None` without triangles. |
| `rules.floor_under(boxes,point,ground=None)` | Box iterable, world point, optional terrain grid. | Distance from **0.05 m above** the point; `None` beyond `FLOOR_BELOW + 0.05`. |

### Module responsibilities

| Modules | Role |
| --- | --- |
| `common`, `build`, `read`, `edited`, `check`, `export`, `preview` | Blender/data conversion, source protection, validation, exports and inspection. |
| `geo`, `terrain`, `rules`, `markers` | Pure geometry, terrain data, placement/traversal budgets and marker schemas. |
| `kit`, `kit_recipes`, `kit_shapes`, `kit_art` | Recipe catalog, kit construction, primitive mesh shaping and art assembly. |
| `kit_chapel`, `kit_fort`, `kit_harbour`, `kit_houses`, `kit_iberian`, `kit_massing`, `kit_nature`, `kit_planting`, `kit_props`, `kit_ships` | Architectural, natural, dressing and ship recipe families. |
| `overlap`, `shade` | Export overlap handling and shading support. Collision proxies are not always valid visual occluders. |
| `layouts/lay`, `fixture`, `garrison`, `garrison_markers`, `city_harbour`, `city_massing`, `harbour/*` | Layout composition, authored placements, markers and harbour districts. |

Full per-module function/type/default documentation is in [Python references](../reference/README.md#python-tools). Recipe collections and schema tables remain in source; avoid copying large catalogs into multiple documents.

## Props and wardrobe pipelines

| Entry point | Commands / outputs |
| --- | --- |
| [props.sh](../../tools/props/props.sh) | `build`, `check`, `bake`, `export`, `preview`, `all <fixture\|all>`, `list`, `test`; `flames [name\|all]` and `cookie` generate VFX. Sources: `assets/props/source`. Fixture exports: `assets/props/lights/<name>.glb` and matching JSON. |
| [wardrobe.sh](../../tools/wardrobe/wardrobe.sh) | `build <kind> [--force]`, `check`, `bake`, `export`, `preview`, `list`, `test`. Targets include outfit kinds, heads/hair/headgear and `all`. Sources: `assets/characters/wardrobe/source`; exported rigged parts and metadata are consumed by `Wardrobe.gd`. |

Both wrappers support `BLENDER`; preview accepts its documented `--out=...` override. Run `list` for current recipe targets. Props `all` runs build/check/bake/export; wardrobe's `all` **target** orders part families before outfit kinds for combined-budget validation. Do not confuse a target with a verb. Wardrobe builds/exports preserve backups and validate against recipe/skeleton/texture rules; read the wrapper's edit/force behavior before overwriting source work.

Props `common`, `recipes`, `build`, `check`, `bake`, `export`, `preview` and `flames` own scene conventions, fixture catalogs, construction, rules, vertex/material baking, runtime metadata, pictures and flame sheets. `export.spec(name, recipe)` returns the fixture metadata dictionary: triangle count, slots, glow/shadow parts, stretch options, sockets, burner configuration, soot/cookie flags and recipe hash. `export_fixture(name, recipe, out=common.OUT)` writes the GLB/JSON pair and returns its GLB `Path`.

Wardrobe `common`, `recipes`, `build`, `check`, `validate`, `bake`, `fabrics`, `export`, `preview` and `testkit` own rigs/budgets, part catalogs, construction, validation, cloth texture baking, runtime skin exports and fixture generation. The important validator is `validate.check(mesh, *, armature=None, reference_joints=None, cloth_bones=(), images=(), palette=..., combined_tris=None, budget=..., bare=None) -> list[str]` at runtime (unannotated in source). `[]` passes; failures carry rule IDs. `mesh`/`armature` are Blender objects; `images` contains `(path, (width,height), palettized)` tuples. `cloth_bones` permits extra weighted bones; `combined_tris` checks the heaviest outfit combination; `bare` names intended exposed body regions. The export orchestrator decides whether a failed part can be written.

## Other asset and inspection tools

| Tool | Inputs / dependencies | Outputs |
| --- | --- | --- |
| [textures/paint.py](../../tools/textures/paint.py) | Optional painting-name arguments; NumPy/Pillow. | Palette-based `textures/painted/<name>.png`; omitted names generate the catalog. |
| [textures/ps2ify.py](../../tools/textures/ps2ify.py) | `import [downloadpath]` or `build [recipe names]`; image packages and local source textures. | Derived textures from JSON recipes. Source/output asset license and ignore rules are documented in the module; do not assume source packs are redistributable. |
| [dress_characters.py](../../tools/dress_characters.py) | Character outfit painting data; NumPy/Pillow. | Outfit textures under `assets/characters/outfits`. |
| [prepare_sfx.py](../../tools/prepare_sfx.py) | Local audio packs, FFmpeg, NumPy; optional `--only`, `--fire`, `--weather`. | Slices/loops under `audio/sfx`, `audio/ambience`, `audio/music`, `audio/weather`; source credits retained. Processing uses 44,100 Hz. |
| [skyline.sh](../../tools/skyline/skyline.sh), [skyline.py](../../tools/skyline/skyline.py) | `city` or default `yard`; Blender. | Skyline images under `assets/sky`; removes its intermediate raw image. |
| [plot_motion.py](../../tools/plot_motion.py) | Folder containing `motion_old.csv` and `motion_new.csv`; Pillow. | `motion_compare.png` comparing speed, view/hand offsets, angles and footsteps. |
| [record_showcase.sh](../../tools/record_showcase.sh) | Output folder, optional ending/resolution; Godot MovieMaker and FFmpeg; `SHOWCASE_MAP` chooses scene. | Recorded MP4; intermediate AVI removed after conversion. |
| [docs/build_reference.py](../../tools/docs/build_reference.py) | Current source; Python standard library. | Linked deterministic API pages, or read-only stale check. See [tool contracts](../../tools/docs/README.md). |

## Runtime and pipeline checks

[run_suites.sh](../../tools/run_suites.sh) accepts zero or more `tests/*_test.tscn` paths. With no paths it discovers the test suites. It runs isolated headless Godot processes at fixed 60 FPS, limits concurrency and detects test failures plus script/runtime errors. `GODOT` selects the executable. Logs go under `${TMPDIR:-/tmp}/suites`; choose a fresh `TMPDIR` to keep runs separate. Expected intentional errors are maintained in [expected_errors.txt](../../tools/expected_errors.txt), not treated as arbitrary ignored failures.

```sh
GODOT=godot TMPDIR=/tmp/ucod-suites bash tools/run_suites.sh
python3 -m unittest discover -s tools/docs -p 'test_*.py'
python3 -m unittest discover -s tools/level -p 'test_*.py'
```

The pure level unit tests can run in ordinary Python. Props/wardrobe suites that import `bpy` must run via their Blender wrapper; do not infer a tool failure from invoking a Blender-only script in CPython. [test_run_suites.sh](../../tools/test_run_suites.sh) exercises the suite-runner shell contract separately. Rendered `tests/visual/stage_*.tscn` scenes use a real renderer and can save images/traces; headless logic suites cannot establish visual quality.

## Mesh and occlusion diagnostics

These scripts extend `SceneTree` and need a real rendered viewport. Run with Godot `--path . --script <path>`; headless results do not reproduce their pixel probes. They print measurements/reproduction results and save comparison PNGs, then quit. An exit of zero is process completion, not proof that a culling bug exists or was fixed.

| Diagnostic | Inputs | Outputs |
| --- | --- | --- |
| [backface_audit.gd](../../tools/diagnostics/backface_audit.gd) | Fixed ship-deck fixture. | `/tmp/deck-imported.png`, `/tmp/deck-runtime.png`, cull modes/pixel comparison. |
| [occlusion_audit.gd](../../tools/diagnostics/occlusion_audit.gd) | Fixed open-arch fixture. | `/tmp/culling-open-arch.png`, `/tmp/culling-box-arch.png`, false-occlusion comparison. |
| [crane_occlusion_audit.gd](../../tools/diagnostics/crane_occlusion_audit.gd) | Fixed crane fixture. | `/tmp/crane-open.png`, `/tmp/crane-occluded.png`, false-occlusion comparison. |
| [mesh_proxy_audit.gd](../../tools/diagnostics/mesh_proxy_audit.gd) | Piece name after `--`, default `nave_vault`; [mesh_proxy_cases.json](../../tools/diagnostics/mesh_proxy_cases.json). | `/tmp/mesh-proxy-audit/<piece>/open.png` and `proxy.png`; exits 2 for an unknown case or missing mesh. |

Use one process per mesh-proxy case because renderer occlusion updates are asynchronous. Existing [culling investigation](../mesh-culling-audit.md), [lantern notes](../lantern-physics.md) and [water-exit notes](../water-exits.md) preserve issue-specific evidence. They complement current system contracts rather than replacing them.
