# Rendering, character presentation, and HUD

The runtime targets Godot 4.5.1. Rendering combines a Retro screen grid with normal 3D lights, shadows, fog, and glow. Presentation reads gameplay state; the exceptions that also affect gameplay are physical bodies and burner lights. World weather and level construction are covered in [world.md](world.md), recorded sound in [audio.md](audio.md), and camera direction in [cinematics.md](cinematics.md).

## Ownership and frame order

[Retro](../../scripts/Visual/Retro.gd) is an autoload in `project.godot`. It watches new geometry, converts `BaseMaterial3D` texture filtering, remembers resources through weak references, and restores converted properties when disabled. Its CanvasLayer is 4. [AdrenalineView](../../scripts/Visual/AdrenalineView.gd) draws combat grading below it at layer 3; [CrispText](../../scripts/Visual/CrispText.gd) projects grouped 3D labels above the grid, and [StealthHUD](../../scripts/UI/StealthHUD.gd) draws at layer 5. Cinema transitions and showcase text add their own layers.

[Humanoid](../../scripts/Visual/Humanoid.gd) is used by GuardRig and ViewArms. Call `build()` or `dress()` before attaching equipment or adding a ragdoll. Locomotion, driven actions, and upper-body actions feed the animation tree; posture modifiers operate after animation. Ragdolls are constructed while the skeleton remains in the rest pose. Cloth runs after ragdoll posing, with ClothReset immediately before cloth and Severed after it. A hanging grip listens to `Skeleton3D.skeleton_updated` to follow the final hand transform.

Fx, FireParticles, and LightBudget keep static references to scene-owned manager nodes. Creation is lazy; particle managers build pools before deferred tree insertion so calls during scene setup have storage. Their exit handlers release scene references. These are scene helpers rather than autoloads. WaterView differs: it is a viewport child and survives scene replacement, preventing stale underwater tint on the next camera.

## Layers and resources

[Layers](../../scripts/Visual/Layers.gd) defines **render masks**, separate from physics collision masks.

| Mask | Render role / constraint |
| --- | --- |
| `WORLD = 1` | World geometry default. |
| `WORLD_ALL = (1 << 16) - 1` | Layers 1–16; world decals may paint these. |
| `GLOWING = 1 << 15` | Fixture interiors; nearby burners exclude these parts to prevent overexposure. |
| `ACTORS = 1 << 16` | Actor meshes; wounds and cinematic eye lights target them. |
| `FX = 1 << 17` | Cosmetic particles/trails/halos, omitted from lightgem capture. |
| `VIEWMODEL = 1 << 18` | First-person hands; squeezed depth allows drawing over the world. |
| `GEM_PROBE = 1 << 19` | Lightgem probe, excluded from effect lights. |
| `ALL_BUT_PROBE` | Effect-light mask; fx_light grouping also excludes gameplay LightProbe calculations. |

Materials returns cached shared resources. Mutating one affects every user; duplicate it for an individual material edit. Wardrobe/FlameFx/fixture glow instead use instance shader parameters for appearance, animation frames, and burn state. Night temporarily edits registered shared standard materials and restores their stored dry values on exit. GemEnvironment duplicates the scene Environment and strips fog, glow, AO, indirect/reflection effects, adjustment, and tonemapping so the lightgem measures light rather than atmosphere.

## Core API contracts

The standalone [sky.gdshader](../../sky.gdshader), used by [main.tscn](../../main.tscn), is also indexed in the [shader reference](../reference/shader/sky.md). Its directional-sun/cloud uniforms belong to that scene's sky setup; the integrated night system uses `NightSky` and `scripts/Night/night_sky.gdshader`.

Defaults and inferred parameter types below describe current source. Parameters using `:=` infer their type from the default; bare parameters without an annotation or inference remain dynamic. Positions are world-space unless explicitly stated; lengths are metres, animation time is seconds, and rotations are radians unless noted.

| API | Inputs | Result and side effects / failure |
| --- | --- | --- |
| `Humanoid.build(outfit: StringName, female := false, fighting_idle: StringName=&"Sword_Idle") -> void` | Painted outfit name and body/idle selection. | Creates model, skeleton, animation tree, and posture. Requires imported character assets. |
| `Humanoid.dress(kind: StringName, seed: int, fighting_idle: StringName=&"Sword_Idle") -> bool` | Wardrobe kind, deterministic look seed. | Creates assembled appearance; false if wardrobe readiness fails so callers can use the base-body path. Initial-build operation. |
| `set_motion(velocity: Vector3, fighting: bool, delta: float) -> void` | Caller locomotion and scaled frame delta. | Chooses/blends gait, scales playback to measured stride speed, and updates fighting idle. |
| `show_action(animation: StringName, time: float, fade_in := 0.08, weight := 1.0) -> void` | Clip and caller-driven seek time; inferred float defaults. | Blends action slots at the requested time; does not own action gameplay timing. Missing clips are ignored. |
| `show_upper(animation: StringName, time: float, fade_in := 0.15, weight := 0.9) -> void` | Upper-body clip/time/weight. | Sets the filtered upper-body animation layer; `clear_upper(fade := 0.25)` releases it. |
| `play_once(animation: StringName, speed := 1.0, from := 0.0) -> void` | Clip, playback multiplier, start seconds. | Advances its own clip clock and eventually holds a terminal pose; `action_length()` returns 0 for absent clips. |
| `add_ragdoll(mass_scale := 1.0) -> Node` / `go_limp(velocity := Vector3.ZERO) -> void` | Rest-pose build / initial velocity. | Adds physical bone simulation and hands pose ownership to it. `wake()` restores animated ownership. |
| `sever(bone: StringName, velocity := Vector3.ZERO) -> RigidBody3D` | Detachable root bone and initial velocity. | Copies posed geometry into a SeveredPart, removes covered bodies, and hides the original branch; unsupported/already-cut/missing roots can return null. |
| `attach(bone: StringName, node: Node3D, offset := Transform3D.IDENTITY) -> BoneAttachment3D` | Valid built skeleton, unparented node, bone-local transform. | Adds attachment and reparents node; caller must provide a valid bone. |
| `Wardrobe.rebind(skin: Skin, source: Skeleton3D, target: Skeleton3D) -> Skin` | Source skin and source/target rest frames. | Returns a new skin in target rest space; add missing cloth bones first. |
| `Wardrobe.roll(options: Dictionary, skin_tones: Dictionary, seed: int) -> Dictionary` | JSON options/tones and private deterministic seed. | Produces look data without changing gameplay RNG; consumes eleven draws in a fixed order. |
| `Wardrobe.apply_look(mesh: GeometryInstance3D, look: Dictionary) -> void` | Appearance dictionary. | Writes dye, fade, skin, grime per mesh, preserving shared material. |
| `Materials.surface(slot: StringName) -> StandardMaterial3D` / `level_surface(slot: StringName) -> Material` | SLOTS key. | Cached shared resource; level adds world mapping, foliage, cutout, or glow behavior. Missing photos use colours; unknown standard slots return magenta/report once. |
| `Materials.photo(slot: StringName) -> Texture2D` / `picture(name: String) -> Texture2D` | Slot photo / explicit image name. | Optional photo/painted texture or null. `clear_cache()` drops cache references without replacing materials already owned by meshes. |
| `Lights.make(parent: Node, fixture: StringName, at: Vector3, yaw := 0.0, overrides := {}) -> Node3D` | Recipe name, placement, Torch/fixture overrides. | Adds a LightFixture; recipe/model failures report errors and leave available burner behavior. Placed builders own parenting; carried builders return unparented nodes. |
| `Torch.kindle(instant := false) -> void` / `put_out(how: Variant=&"snuff", instant=false, by: Node=null) -> void` | Transition style; `how` accepts an extinction mode or a Node as compatibility instigator. | Updates light/flame/reach/audio state and emits `lit_changed(lit: bool)` on applied changes; instant suppresses normal effects. Douse produces steam/cooling. |
| `Torch.lean(v: Vector3) -> void` / `set_strength(k: float) -> void` / `flare(amount=1.0) -> void` | World wind, fuel level, transient boost. | Updates visual/burner state. Actual light affects guards/gem; cosmetic flames do not. |
| `Fx.blood(context: Node, at: Vector3, direction: Vector3, amount := 1.0) -> void` | Scene context, wound direction, cut strength. | Creates cosmetic particles/stains; enabled/gore gate blood. `stain()`/`wound()` return Decal or null when unavailable. |
| `Fx.flash(context: Node, at: Vector3, color: Color, energy := 2.0, light_range := 3.5, seconds := 0.09) -> void` | Temporary light parameters. | Scene-owned light omits gem probe and gameplay light readings; fades/reuses pooled storage. |
| `FireParticles.emit(context: Node, kind: StringName, at: Vector3, count: int, wind := Vector3.ZERO, tint := Color.WHITE, size := 0.0) -> void` | ember/smoke/steam/spark, world position/wind, optional size. | Spawns up to pool capacity; detached context/unknown kind does nothing. `emitted()` counts requests before capacity rejection; negative count adds to counter but spawns none. |
| `GodRays.add_window(outline: PackedVector3Array, uvs: PackedVector2Array) -> MeshInstance3D` | Matching local polygon/UV arrays, configured direction/planes; ready material. | Adds beam mesh swept to inward-facing planes. No input validation; provide a valid polygon. Companion lights follow calm energy. |
| `GemEnvironment.setup(gem_cameras: Array[Camera3D]) -> void` / `sync() -> void` | Gem camera list / source world environment. | Assigns stripped environment copy; detached manager/empty list skip sync. Missing source uses a default Environment. |
| `WaterView.ensure(viewport: Viewport) -> void` | Non-null viewport. | Defers a single child creation, with metadata guard. Frame update finds camera-containing water and resets optics when no longer immersed. |
| `StealthHUD.setup(p_player: CharacterBody3D) -> void` | Fully configured player/components, call once. | Builds UI, connects signals, reads settings, and handles pause input. Requires player contract, not an arbitrary body. |
| `StealthHUD.hurt_from(from: Vector3) -> void` / `dazzle(amount: float) -> void` | Player-local incoming direction / fraction [0,1]. | Appends a directional damage mark / raises white overlay; tiny direction ignored. Requires initialized HUD controls. |
| `Settings.awareness_marks() -> bool` / `set_awareness_marks(on: bool) -> void` | Lazy read / desired switch. | Reads/writes `user://settings.cfg`, section hud, key awareness_marks. Missing/malformed values default true; save errors are not surfaced. |

## Data and timing

Wardrobe files live under `assets/characters/wardrobe/`. Kind recipes include `body` (male/female), `options`, `skin_tones`, cloth chains/colliders, bone specs, and metal/probe information. Head, hair, and headgear have their own JSON records. `kind_data()`/`head_data()`/`hair_data()`/`headgear_data()` return `{}` on missing/non-Dictionary data and cache results. `can_dress()` checks required GLB/PNG/mask files and usable options; missing or wrong-body pieces are filtered with warnings. The dresser chooses hair hidden by headgear after rolling.

| Record | Fields consumed by the presentation code |
| --- | --- |
| Wardrobe options | faces, tones, hair, beards: name arrays; headgear: arrays of piece-name arrays; dye: colour or colours RGB arrays, shift float, fade [min,max]; grime [min,max]; hair_colours RGB arrays. |
| Rolled look | face/tone/hair/beard StringName; headgear Array[StringName]; dye/skin/hair_colour Color; fade/grime/height float. |
| Cloth chain | bones ordered name Array; tip default .1 m, stiffness 1, drag .4, gravity 1, radius .03 m. Empty bones skip the setting. |
| Cloth collider | bone name; radius default .08 m; height default .4 m denotes straight section; runtime capsule includes two radius-sized ends. |
| Fixture recipe | sockets maps socket-name to xyz-array lists; burner maps export names to values (color string, loop/chimney audio names, vector arrays); shadow_parts lists mesh names; mount/soot and model decoration settings. `spec()` caches `{}` for missing/malformed recipe. |
| Materials SLOTS | photo name, colour Color, metallic/roughness float; optional painted, tile scalar/[x,y] metres, offset world height, cut, glow, sway [rustle,bough], shadowless. |
| SwingTrail samples | Caller pushes base/tip in node-local space; `top_level` makes that world space. lifetime is seconds, subdivisions smooth the ribbon, base_fade runs hilt 0 to tip 1. |
| HUD queries | `layout_rects()` maps visible piece names to Rect2; `prompt_texts()` returns PackedStringArray; awareness/posture queries expose live presentation arrays. Treat mutable records as inspection state. |

[TimeFx](../../scripts/Visual/TimeFx.gd) owns `Engine.time_scale`: it applies `base * minimum(active request scales)`. `set_base(scale: float)` clamps .01–1. `request(tree: SceneTree, id: StringName, scale: float, real_seconds: float)` replaces the same ID; null tree/nonpositive duration does nothing. `ramp(tree, id, scale, ease_in, hold, ease_out)` uses real-time, pause-processing tweens. `cancel(id)` removes one request; `clear()` removes all requests **without changing base**. Tokens prevent old timers/tweens from removing replacements. Audio follows non-hitstop requests partially, clamped to at least .45 playback speed; base alone does not drive that pitch calculation.

`real_time() -> float` is a monotonic physics-frame/interpolation clock with epochs for physics-Hz changes. `real_since(last: float) -> float` caps elapsed time to .1 s, so hitches do not create large camera/audio/feedback jumps. Particle/flame/cloth clocks use scaled game delta. Adrenaline readiness uses supplied delta while heartbeat/jolt/hurt use real time. Pause processing depends on node process mode; a real-time calculation alone does not make a pausable node run while paused.

## Script inventory

Every script in `scripts/Visual` and `scripts/UI` belongs to this guide. Related camera/weather users are linked above.

| Script | Role / principal owner or caller |
| --- | --- |
| [AdrenalineView](../../scripts/Visual/AdrenalineView.gd) | HUD combat grading; combat_view group broadcasts jolt/cut. |
| [ArmReach](../../scripts/Visual/ArmReach.gd) | ViewArms two-bone IK, target transforms, curls, optional right-leg reach. |
| [Atmosphere](../../scripts/Visual/Atmosphere.gd) | Map air/motes, scans actors/fires/fixtures; hears SoundBus and supplies TalkFacts wind. |
| [Blowhole](../../scripts/Visual/Blowhole.gd) | LevelGameplay/map periodic spray, recorded roar, timed SoundBus masking box. |
| [Cloth](../../scripts/Visual/Cloth.gd) | Humanoid spring-bone cloth and body/floor collision primitives. |
| [ClothReset](../../scripts/Visual/ClothReset.gd) | Humanoid teleport/recovery restarts and ragdoll floor alignment. |
| [CrispText](../../scripts/Visual/CrispText.gd) | Retro 2D label overlay, world-wall occlusion, reversible layer ownership. |
| [Expression](../../scripts/Visual/Expression.gd) | GuardRig gaze/posture/gait/gesture presentation, no AI decisions. |
| [Fx](../../scripts/Visual/Fx.gd) | Combat/interaction pooled particles, decals, temporary lights, generated textures. |
| [GemEnvironment](../../scripts/Visual/GemEnvironment.gd) | PlayerController gem cameras' stripped Environment copies. |
| [GodRays](../../scripts/Visual/GodRays.gd) | Garrison window shaft meshes and synchronized glass lights. |
| [Hanging](../../scripts/Visual/Hanging.gd) | Equipment grip pendulum after skeleton posing. |
| [Humanoid](../../scripts/Visual/Humanoid.gd) | GuardRig/ViewArms model, animation, attire, physical/severed pose integration. |
| [Layers](../../scripts/Visual/Layers.gd) | Shared render-bit constants separating world, actors, FX, hands, probe. |
| [Materials](../../scripts/Visual/Materials.gd) | Shared slot resources, optional licensed-photo fallback, foliage wind. |
| [Posture](../../scripts/Visual/Posture.gd) | Humanoid skeleton pose offsets; public fields include radian gaze/hips angles. |
| [Ragdoll](../../scripts/Visual/Ragdoll.gd) | Humanoid physical bodies/joints, shove/recover, body ownership lookup. |
| [Retro](../../scripts/Visual/Retro.gd) | Autoload screen grid, filtering conversion/restoration, night environment factory. |
| [Severed](../../scripts/Visual/Severed.gd) | Final skeleton modifier shrinking removed bone branches. |
| [SeveredPart](../../scripts/Visual/SeveredPart.gd) | Humanoid cut-part rigid body, bleeding, body discovery, capped lifetime population. |
| [SwingTrail](../../scripts/Visual/SwingTrail.gd) | Blade sample ribbon, timed fade, optional viewmodel depth squeeze. |
| [TimeFx](../../scripts/Visual/TimeFx.gd) | Shared slow-motion/hitstop arbitration, real clock, audio slowdown. |
| [Torch](../../scripts/Visual/Torch.gd) | Light/fuel/flicker/extinction/reach/audio burner base. |
| [Wardrobe](../../scripts/Visual/Wardrobe.gd) | Character recipe reads, readiness checks, deterministic looks, skin rebind, shared shaders. |
| [WaterView](../../scripts/Visual/WaterView.gd) | Viewport-owned underwater optics, camera/water lookup and reset. |
| [Wildlife](../../scripts/Visual/Wildlife.gd) | Map bat/firefly builders and weather suppression. |
| [Wind](../../scripts/Visual/Wind.gd) | Per-frame Night.wind to shared foliage material uniforms. |
| [Corona](../../scripts/Visual/Lights/Corona.gd) | Torch halo renderer and occlusion/distance fades. |
| [FireParticles](../../scripts/Visual/Lights/FireParticles.gd) | Torch scene particle pools; counters/reseed for inspection. |
| [FlameFx](../../scripts/Visual/Lights/FlameFx.gd) | Torch heat flipbooks, core/shimmer, shared pass materials. |
| [Flicker](../../scripts/Visual/Lights/Flicker.gd) | Pure deterministic flicker/draft signals and spatial seed. |
| [LanternBody](../../scripts/Visual/Lights/LanternBody.gd) | Mounted LanternPhysicsBody forbids carrying; slide_character transfers character normal momentum explicitly. |
| [LightBudget](../../scripts/Visual/Lights/LightBudget.gd) | Burner register/unregister, distant shadow allocation, warning flag. |
| [LightFixture](../../scripts/Visual/Lights/LightFixture.gd) | Torch subclass recipe/model, soot/haze/chimney, chains/swing physics and draft sensing. |
| [Lights](../../scripts/Visual/Lights/Lights.gd) | Map/character fixture factories, socket alignment, delayed torch wall/floor fit. |
| [Settings](../../scripts/UI/Settings.gd) | Persistent awareness mark/tick preference, permissive bool parsing. |
| [StealthHUD](../../scripts/UI/StealthHUD.gd) | Player UI, signal bindings, pause/awareness, prompts, combat/readout drawing subclasses. |

## Shader inventory

Shader uniforms are the actual input contracts; instance uniforms distinguish meshes sharing a material. No shader publishes gameplay state. The water includes are also used by WaterVolume outside this folder.

| Shader / include | Inputs and rendered output |
| --- | --- |
| [adrenaline](../../scripts/Visual/adrenaline.gdshader) | Screen, ready/beat/primed/impact/hurt/hurt_side/wounded; canvas heartbeat grading, distortion and desaturation. |
| [bat](../../scripts/Visual/bat.gdshader) | Two-frame painted sheet, beats rate, instance phase; billboard black silhouette, fog disabled. |
| [blade_blood](../../scripts/Visual/blade_blood.gdshader) | Local blade endpoints, amount/wet/seed/z_clip; steel overlay constrained to blade length. |
| [foliage](../../scripts/Visual/foliage.gdshader) | Painted alpha, vertex colour, rustle/bough/wind (m/s), translucency; animated cutout foliage. |
| [god_rays](../../scripts/Visual/god_rays.gdshader) | Glass/dust/depth, strength/tint/gain/blur/soft_depth; additive shafts with scene-depth contact fade. |
| [ground_stain](../../scripts/Visual/ground_stain.gdshader) | Stain texture/strength/curve; multiplicative unlit floor card darkens lighting as well as base colour. |
| [hit_rim](../../scripts/Visual/hit_rim.gdshader) | Tint/amount; brief additive actor edge highlight via material_overlay. |
| [retro_psx](../../scripts/Visual/retro_psx.gdshader) | Albedo/UV scale, snap_lines, affine, finish/emission; optional snapped vertices and affine texture coordinates on a normally lit prop. |
| [retro_screen](../../scripts/Visual/retro_screen.gdshader) | Screen, virtual_size, levels, dither strength; four filtered taps per coarse pixel and Bayer colour quantization. |
| [trail](../../scripts/Visual/trail.gdshader) | UV.x age, UV.y hilt-to-edge, tint/strength/z_clip; fading additive blade ribbon. |
| [underwater](../../scripts/Visual/underwater.gdshader) | Screen/depth/caustics, water bounds/depth/clarity/tint, moon and clock; box-clipped optical attenuation, Snell window, and caustic shafts. |
| [wardrobe](../../scripts/Visual/wardrobe.gdshader) / [wardrobe_two_sided](../../scripts/Visual/wardrobe_two_sided.gdshader) | Closed parts / two-sided cloth; diffuse-only lit variants sharing the same appearance include. |
| [wardrobe include](../../scripts/Visual/wardrobe.gdshaderinc) | Albedo/mask/dye_base; instance dye/fade/skin/grime. Mask red=dye, green=skin, blue=dirt; retains baked shading. |
| [water](../../scripts/Visual/water.gdshader) / [water_shore](../../scripts/Visual/water_shore.gdshader) | Opaque deep-water reflection pass / shallow shoreline pass with no depth write. |
| [water surface include](../../scripts/Visual/water_surface.gdshaderinc) | Ripple/flow/rain/sky/moon, 16 world-light records, scum/weed and surveyed shore depth; shared surface shading/reflections/rings. |
| [corona](../../scripts/Visual/Lights/corona.gdshader) | Falloff/grid_lines/intensity plus instance look; additive screen-sized halo. CPU rays own occlusion; depth test/fog are disabled. |
| [flame](../../scripts/Visual/Lights/flame.gdshader) / [flame_core](../../scripts/Visual/Lights/flame_core.gdshader) | Additive shimmer / solid main/core layer; core_cut and brightness select hotter pixels. |
| [flame include](../../scripts/Visual/Lights/flame.gdshaderinc) | Heat sheet/ramp/ramp_low/frames and instance frame/shape/wind; common heat-to-colour sampling. |
| [glow](../../scripts/Visual/Lights/glow.gdshader) | Slot texture/colour, char colour, flame share, brightness/mottle; per-instance glow/char keeps fixture resources shared. |
| [haze](../../scripts/Visual/Lights/haze.gdshader) | Screen and reach; upward screen distortion over large fires, faded at card edges. |
| [smoke](../../scripts/Visual/Lights/smoke.gdshader) | Puff sheet/body, MultiMesh colour/custom data; camera-facing smoke/steam lit from the fire below. |

## Failure and extension constraints

CrispText must restore captured render layers whenever releasing a label; otherwise disabling the filter can leave 3D text invisible. Corona must test physics rather than trust depth, because its shader intentionally bypasses depth. LightBudget must preserve lights near the camera or within their illumination reach; using its render shadow state for AI would make detection change with camera distance. Fitting `torch_at()` waits two physics ticks so static world geometry is available and ignores dynamic doors/actors/other lights.

ClothReset repeats restart across frames because skeleton and simulator transforms can propagate a frame apart. Teleport/recovery callers should use Humanoid.restart_cloth() rather than letting a pose jump accumulate spring energy. Wardrobe rebind must account for rest-frame differences even when bone positions match. Shared material instance state belongs in shader instance parameters rather than global uniforms.

Asset readiness checks intentionally tolerate optional photographs, absent audio, and wardrobe fallback. Imported skeleton/animation/model structure and dictionary field shapes are generally trusted after those checks; these APIs are not validators for arbitrary assets. This documentation changes no executable behavior.
