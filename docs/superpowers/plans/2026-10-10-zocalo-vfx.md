# The Zócalo's effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the first-pass billboard effects with our own rendered smoke and fire, fog volumes, tumbling petals and leaves, flapping pigeons and the caged god's breath driving the occult set pieces, in the Hellboy × Deadlock × Mexican register.

**Architecture:**
- Blender renders our own sheets and meshes headless (`tools/vfx/`: Mantaflow sims → six-way lit, stepped flipbooks; Geometry Nodes sprite sheets; a drift kit of petal and leaf meshes).
- Godot draws them with one shared effect include (`vfx_common.gdshaderinc`) on GPUParticles3D systems built from presets (`scripts/Level/Vfx.gd`), FogVolumes with fog shaders, and mesh effects. `Ambient.gd` keeps its job (nearest 40, time of day, wind) over those systems.
- One wind (`Gusts.gd`, built) and one breath (`Breath.gd`, new) drive everything.

**Tech Stack:** Blender 5.2 (bpy, Mantaflow, Geometry Nodes, Cycles), Python 3 + numpy + Pillow, Godot 4.5.1 Forward+ (GPUParticles3D, particle/fog/spatial shaders, FogVolume).

**Spec:** `docs/superpowers/specs/2026-10-10-zocalo-vfx-design.md` (approved Oct 10 2026). Techniques and sources: `docs/superpowers/refs/mexico_city/vfx_techniques.md`.

## Global Constraints

- **Our own, always:** every sheet, mesh and flipbook rendered or drawn by us; nothing downloaded (no VFX packs, no third-party Blender extensions installed).
- **The register:** graphic shapes, light in two or three hard bands (Mignola), readable chunky silhouettes and colour by meaning (Deadlock), copal, cempasúchil, candle clusters, Aztec-styled glyphs of our own (Mexico).
- **Colour rule:** marigold `#F2A20C`/`#D9660A` the dead's, cyan-white `#CFE8F0` the wards', oxblood `#6E1F1A` the gods', phosphor green `#7FD36A` the seeped. Fire is warm orange-gold, never marigold-saturated.
- **Every effect has a source** in the world (a censer, a brazier, a seeped booth, the god's chains).
- **Budgets:** ≤ 4,000-6,000 live particles; ≤ 40 systems running; turbulence on ≤ 4 visible systems; ≤ ~60 large alpha sprites on screen; 6-10 compact FogVolumes active; sheets 512-1024 px, greyscale where a gradient map colours them.
- **The user's:** the sigils' real glyphs (a placeholder stroke pattern until painted), the hum's and the breath's sound.
- **Commits:** one per task (more allowed), never pushed; each ends `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Defects:** never call a visual defect harmless.

## Rulings carried in

1. **No OpenVAT.** Installing a third-party extension is out; the pigeon's wing cycle is our own: the figures kit's pigeon gets two wings whose vertices carry their hinge weight in UV2, and a pigeon shader flaps them by an instance phase (a two-pose vertex animation, no texture needed).
2. **GPU particle state is not readable from script.** Tests check each system's configuration (collision, sub-emitters, trails, attractor masks, amount ratio) headless, and what it draws in windowed render tests (pixels changed where expected).
3. **Effects stay placed by name.** The dressing's `emitters` keep their `effect` names; this plan adds `brazier` (flame, embers, smoke, haze, light) and `coals` (atole's fire ring) to the catalogue in place of the separate `smoke`/`embers` pairs, and `ward` effects are found from the ward pieces themselves (no emitters for them).
4. **The breath is the god's.** `Breath.gd` sits on the Zócalo map; everything that breathes reads it, nothing else times itself to the god.

## Review Focus

- **The plaza at night with the god, the wards, copal and candles all near:** at most 40 systems and 10 fog volumes; frame rate held (Task 8's report). Test in Task 1 (Ambient caps) and Task 4 (fog cap).
- **Switching day to night with effects running:** night-only systems stop emitting and fade (no pop), day-only ones likewise. Test in Task 1.
- **Wind at its strongest gust:** smoke and petals blow downwind but never sideways through walls faster than they fall (velocity limit). Test in Task 5 (petals' velocity limit set).
- **A deep breath while the player stands at the cage:** the sparks bounce on the plinth and never inside the player's head (sub-emitter collision on). Test in Task 7.
- **The undressed map (`--undressed`):** no effects, no errors. Test in Task 1.

---

### Task 1: Foundations

**Files:**
- Create: `scripts/Visual/vfx_common.gdshaderinc`: `flipbook_uv(uv, frame, grid)`, `erode(alpha, threshold, feather)`, `scroll_noise(tex, uv, time, speed)` (two octaves multiplied, the Diablo 3 way), `ramp(tex, t)` (gradient map), `bands(light, steps)` (two or three hard steps), `six_way(a, b, light_dir_local) -> float`.
- Create: `scripts/Visual/vfx_sprite.gdshader` (spatial, a particle's billboard): flipbook from `INSTANCE_CUSTOM.z` over `frames` (h, v), erosion over life (`INSTANCE_CUSTOM.y`), gradient-mapped colour, proximity fade, banded lighting; six-way when `sheet_b` is set.
- Create: `scripts/Level/Breath.gd`: `class_name Breath extends Node`; `const PERIOD := 7.0`, `const DEEP_EVERY := 4` (every fourth breath a deep one); `func value() -> float` (-1 exhaled .. +1 inhaled), `func deep() -> bool`, `func at(t: float) -> float`, `signal deep_exhale`.
- Create: `scripts/Level/Vfx.gd`: `class_name Vfx extends RefCounted`; `static func system(effect: String) -> Node3D` building the effect's node tree (a GPUParticles3D or a few, FogVolume, light) from `PRESETS`; `const PRESETS := {...}` one entry per effect name the dressing uses (`steam, copal, smoke, embers, mist, petals, leaves, dust, canal_fog, candles, brazier, coals`) with amount, lifetime, `fixed_fps`, process material settings, draw material.
- Modify: `scripts/Level/Ambient.gd`: each emitter's system built once (lazily, when first near) from `Vfx.system`, kept under the Ambient node; running ones `emitting = true`, the rest `emitting = false`; `amount_ratio` = 1 within 20 m, falling to 0.3 at REACH; keeps `build`, `step`, `set_day`, `running`, `ACTIVE`, `REACH`, `gusts`.
- Test: `tests/ambient_test.gd` (headless) A1-A6 kept (A4 and A6 now read the systems' configuration, Ruling 2), plus:
  - A7 every PRESET builds a node with at least one GPUParticles3D (or a FogVolume) and no errors;
  - A8 a running system 40 m off has `amount_ratio` < 0.7, one at 10 m 1.0;
  - A9 set_day(true) stops a night system emitting (`emitting == false`) without freeing it;
  - B1 Breath: `value()` over 70 s spans -1..1 with period 7 ± 0.5 s; B2 `deep()` true on every fourth breath and `deep_exhale` emitted then;
  - A10 the Zócalo built `--undressed` has no Ambient and prints no error (run as a second scene `tests/zocalo_undressed_test.tscn`).
- [ ] Tests (FAIL), implement, tests (PASS), `zocalo_test` still 32/32.
- [ ] Commit `feat(fx): effect foundations: the shared include, the breath, GPU particle presets`

### Task 2: The Blender effects pipeline

**Files:**
- Create: `tools/vfx/sim_render.py`: `bake_and_render(kind: str, out: Path, frames: int, px: int)` for `kind` in `("plume", "puff", "fire")`: a Mantaflow gas domain (64-128 divisions), an inflow shaped per kind, baked; an orthographic camera framing the domain, transparent film, Cycles at 16-32 samples; `plume` and `puff` rendered six times (one white light each from right, top, back, left, bottom, front of the camera), `fire` rendered once for emission.
- Create: `tools/vfx/pack_sheet.py`: `pack(frames: list[Path], grid: tuple[int, int]) -> Image`; `pack_six_way(frames_by_light) -> (Image, Image)` (A = right, top, back + alpha; B = left, bottom, front + emission/0); writes `assets/vfx/<name>_a.png`, `<name>_b.png` (or `<name>.png`) and `<name>.json` (`{"grid": [h, v], "frames": n, "px": p}`).
- Create: `tools/vfx/gn_sprites.py`: Geometry Nodes sheets rendered orthographic: `sparks` (4 streak frames), `sigil_strokes` (a ring-and-spokes stroke pattern with a stroke-order gradient in the red channel and coverage in alpha: write-on by threshold).
- Create: `tools/eclipse/drift_kit.py` (the kit pattern, atlas 512): `petal_a`, `petal_b` (curled cempasúchil petals, `marigold`), `leaf_ash`, `leaf_laurel` (`bark`-free, a `leaf` recipe green to brown); each a thin closed solid ≥ 1 cm, ≤ 40 triangles, its middle at the origin.
- Create: `tools/vfx/vfx.sh`: `plume|puff|fire|sparks|sigil|drift|all`.
- Test: `tools/vfx/test_vfx.py` (Python, over the written files): each sheet's size is `grid × px`, frames non-empty (alpha > 0 in each cell) and not identical, `plume_a`/`plume_b` channels distinct (six lights differ), `fire` has warm emission, `sigil_strokes` red channel spans 0..1 along the strokes; `test_kit_bpy.py::DriftKit`: closed, ≥ 1 cm thick, ≤ 40 triangles.
- [ ] Tests (FAIL), implement, render (`tools/vfx/vfx.sh all`), tests (PASS).
- [ ] A contact sheet of every sheet's frames; send to the user.
- [ ] Commit `feat(fx): our own effect sheets: plume, puff and fire sims, sparks, sigil strokes, the drift kit`

### Task 3: Smoke and fire in the game

**Files:**
- Modify: `scripts/Level/Vfx.gd` presets:
  - `copal`: the `plume` sheet, six-way lit, gradient ramp resin-white `#ECE6DA` to grey, 32 stepped frames, slow rise, turbulence on (one of the four), plus a smoke stem (a `RibbonTrailMesh`-free mesh: a tall crossed quad pair with `scroll_noise` erosion) at the source;
  - `steam`: `puff` greyscale with an erosion ramp, near-white, short;
  - `brazier`: flame tongues (three crossed quads, `vfx_flame.gdshader`: multiplied scrolling noise, UV distortion, warm ramp `#2a0a00 → #ff7a1a → #ffd27a`), the `fire` sheet behind them, embers (GPUParticles3D, ribbon trails, `GPUParticlesCollisionHeightField3D` collision, an At-Collision sub-emitter of sparks), a heat-haze quad (`vfx_haze.gdshader`, screen texture offset ≤ 0.01), an OmniLight whose energy follows the same noise as the flames' (`Vfx.flicker(t, seed)`);
  - `coals`: an emissive ring of coals under the atole pot, embers only;
  - `candles`: one MultiMesh of 5-9 flame quads round the spot (each its own phase in `INSTANCE_CUSTOM`), one OmniLight flickering by their summed phase;
  - `smoke` (chimney-grey) and `embers` kept for any old emitter.
- Modify: `tools/level/scenes_catalogue.py`: brazier_watch's `smoke`+`embers` → one `brazier` at the brazier's top; atole_corner's `embers` → `coals`.
- Create: `scripts/Visual/vfx_flame.gdshader`, `scripts/Visual/vfx_haze.gdshader`.
- Test: `tests/ambient_test.gd`:
  - A11 `brazier` builds flames, embers with `collision_mode` != disabled, a sub-emitter, `trail_enabled`, a haze quad and a light;
  - A12 the brazier light's energy and the flame shader's `flicker` uniform come from one `Vfx.flicker` value each frame;
  - A13 `candles` builds one MultiMesh with 5-9 instances and one light;
  - and a windowed `tests/vfx_test.gd` (+ `.tscn`): V1 at night a brazier's pixels change frame to frame round its top and stay still a metre aside; V2 copal's pixels over the god's offerings are pale (luminance > the ground's) by night under the lamps.
- [ ] Tests (FAIL), implement, `level.sh zocalo`, tests (PASS); a clip (GIF) of a brazier watch and the god's copal at night; send.
- [ ] Commit `feat(fx): copal, steam, braziers and candles of our own`

### Task 4: Mist, fog and light

**Files:**
- Create: `scripts/Visual/vfx_mist.gdshader` (fog shader): density from two octaves of scrolling 3D noise moving away from `source` along the ground, falling off with height and distance, `EMISSION` phosphor green `#7FD36A` × a `pulse` uniform; `vfx_fog.gdshader`: canal fog (pale, height falloff, slow).
- Modify: `scripts/Level/Vfx.gd`: `mist` = a FogVolume box (4 × 1.2 × 4 m) with `vfx_mist` + a few ground wisps (GPUParticles3D, `puff` sheet tinted green, heightfield collision); `canal_fog` = a FogVolume box (40 × 2 × 12 m) with `vfx_fog`; `copal` adds a small haze FogVolume (ellipsoid 3 m) above its source; `dust` = motes (GPUParticles3D, unshaded, a particle shader that shows a mote only inside its lamp's cone: `cone_axis`, `cone_angle`).
- Modify: `scripts/Level/Ambient.gd`: fog volumes counted apart: at most `const FOG := 8` visible, the nearest.
- Modify: `scripts/Level/KitLoader.gd`: the lamps' lights `light_volumetric_fog_energy` 1.5 at night (shafts), the stuttering lamps 0 (no ghosting).
- Test: `tests/ambient_test.gd`: A14 `mist` builds a FogVolume whose shader is `vfx_mist` and emission colour the phosphor green; A15 with 20 fog emitters near, at most 8 FogVolumes visible, the nearest; A16 `dust`'s particle shader carries its lamp's cone. `tests/vfx_test.gd`: V3 at night the pixels round a seeped booth are greener than a metre beyond the mist; V4 a lamp's shaft brightens the fog under it (pixels under the lamp brighter than between lamps).
- [ ] Tests (FAIL), implement, tests (PASS); a clip of the seeped mist and the canal at night; send.
- [ ] Commit `feat(fx): seeped mist, canal fog, copal haze, lamp shafts and dust`

### Task 5: Petals and leaves

**Files:**
- Modify: `scripts/Level/Vfx.gd`: `petals` and `leaves` = GPUParticles3D drawing the drift kit's meshes (`petal_a`/`petal_b`, `leaf_ash`/`leaf_laurel` as two draw passes), a particle shader (`scripts/Visual/vfx_drift.gdshader`, `shader_type particles`) tumbling them on all axes and fluttering side to side as they fall (≈ 1 m/s), `velocity_limit` 3 m/s, colliding with a heightfield that follows the camera (one per map, `Vfx.heightfield(map)`), resting where they land (friction 1, lifetime 20 s fading in the last 2 s), the wind (`Gusts`) as a directional box attractor over the systems.
- Modify: `maps/zocalo.gd`: one `GPUParticlesCollisionHeightField3D` following the camera (60 × 30 × 60 m, update when moved), one wind attractor updated from `gusts.wind()`.
- Test: `tests/ambient_test.gd`: A17 `petals` draws two passes of drift-kit meshes, collision on, `velocity_limit` ≤ 3; A18 the map's wind attractor's direction and strength follow `Gusts.wind()` (headless, the map built dressed). `tests/vfx_test.gd`: V5 after 6 s petals rest on the ground under an emitter (marigold pixels in the ground band beneath it).
- [ ] Tests (FAIL), implement, tests (PASS); a clip of petals at the god and leaves in the garden in a gust; send.
- [ ] Commit `feat(fx): marigold petals and leaves that tumble, blow and settle`

### Task 6: Pigeons

**Files:**
- Modify: `tools/eclipse/figures_kit.py`: `pigeon` gains two wings (thin closed solids), each wing's vertices given a UV2 of (hinge weight 0 at the shoulder to 1 at the tip, side ±1); `test_kit_bpy.py::FiguresKit` budget for `pigeon` 48 → 90; the kit rebuilt and repainted.
- Create: `scripts/Visual/pigeon.gdshader`: the kit's painterly look (include) plus the flap: wing vertices turned about the body's long axis by `sin(TIME * rate + phase) * 0.9 * UV2.x * side`, `phase` and `flap` (0 on the ground, 1 flying) from `INSTANCE_CUSTOM`.
- Modify: `scripts/Level/Pigeons.gd`: MultiMesh `use_custom_data`; each bird's custom (phase, flap); flying flocks steer (each bird seeks its slot on the flock's wheel, separation by its own phase offset, turns smoothed), land by gliding down onto their home spots (flap 0 for the last 2 m).
- Test: `tests/ambient_test.gd` A5 kept, plus A19 flying birds' custom flap is 1 and grounded birds' 0; A20 a landing bird's height falls smoothly (no step > 0.5 m a frame) to the ground.
- [ ] Tests (FAIL), implement, tests (PASS); a clip of a flock lifting and landing; send.
- [ ] Commit `feat(fx): pigeons that flap, wheel and land`

### Task 7: The occult set pieces

**Files:**
- Modify: `maps/zocalo.gd`: a `Breath` node; on it:
  - a `GPUParticlesAttractorSphere3D` at the god's mouth (≈ (0, 6.4, -0.8) over its plinth), radius 9, strength `-Breath.value() * 4` (in on the inhale), its cull mask on the copal, petals and dust systems' layer (`Vfx.BREATHED`);
  - the eight ward-cage lamps' lights and lenses (KitLoader `ward_lamps`) pulsing with the hum (`0.75 + 0.25 * sin(TIME * 2π * 1.1)`), dimming with the inhale (× `1 - 0.4 * max(value, 0)`);
  - the lamps round the god's ring within 30 m dipping on the inhale (× `1 - 0.25 * max(value, 0)`);
  - a FogVolume round the cage (4.5 × 8 × 4.5 m, pale oxblood haze) whose density swells with the inhale;
  - the god's chest swelling (`bound_god` material `swell` = 0.06 × max(value, 0) about its torso);
  - on `deep_exhale`: the chains' seals throw sparks (a one-shot GPUParticles3D at each of the four seal points from `tools/eclipse/bound_god.py`'s chain geometry, ribbon trails, collision on so they bounce on the plinth) and rust dust at the links.
- Create: `scripts/Visual/vfx_sigil.gdshader`: the `sigil_strokes` sheet, write-on by threshold over the red channel, cyan-white emission; `Vfx.sigils(kit)` puts one on each sigil disc's face (4 cm proud), its threshold driven by the hum and, near the player, drawn fully on.
- Modify: `scripts/Visual/painterly.gdshaderinc`: `uniform float swell`, `uniform vec3 swell_centre`, `uniform float swell_radius` (vertex push along the normal, falling off from the centre; 0 leaves everything as it is).
- Create: `scripts/Visual/vfx_ward_ring.gdshader`: a screen-distortion ring round a ward-cage lamp when the player is within 3 m (screen texture offset ≤ 0.006), fading with distance.
- Test: `tests/occult_test.gd` (headless, the dressed Zócalo): O1 the attractor's strength is negative on the inhale and positive on the exhale; O2 the ward lamps' energy is lower on a full inhale than a full exhale; O3 a ring lamp within 30 m dips on the inhale, one 60 m off does not; O4 the cage fog's density follows the breath; O5 a deep exhale restarts the four spark systems, and they have collision on; O6 every sigil disc has its sigil quad 4 cm proud; O7 the `bound_god` material's `swell` follows the breath.
- [ ] Tests (FAIL), implement, tests (PASS); a clip of the god breathing at night (a deep breath with sparks); send.
- [ ] Commit `feat(fx): the god breathes: wards hum, sigils write on, chains spark`

### Task 8: Clips, stills, record

**Files:**
- Modify: `tools/level/layouts/zocalo/cameras.py` as the clips need.
- Update memory: `vfx-aesthetic-and-pipeline.md`, `zocalo-district-project.md` and their MEMORY.md lines.
- [ ] A clip per group, day and night, and stills; look at every one for floating, buried, overlapping or stretched pieces and effects through walls; each fault a failing test, then a fix.
- [ ] Send the clips with the open calls (the sigils' glyphs, the hum's and the breath's sound).
- [ ] Commit `docs(fx): the effects' cameras and clips`
- [ ] Then the scenes plan's Task 7 (its stills, the load and frame-rate reports dressed against undressed, effects and all), and the final review over both plans and this one.
