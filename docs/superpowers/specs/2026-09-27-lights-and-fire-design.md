# Lights and Fire: Design

**Date:** 2026-09-27
**Status:** approved by the user on 2026-09-27.
**Program:** sub-project 1 of the look and sound polish pass. Sub-project 2 is props (doors, chests, barrels, crates, furniture); sub-project 3 is night and weather (moon, rain, storms, fog, wind), built to the canal-quarter spec's section 7.5. Each gets its own spec, plan and build.

## 1. Goal

The user asked for "a look and sfx polish pass": "prettier torches, lamps, better looking doors, chests, barrels", made in Blender, with references for "prettier ps2-like effects". This sub-project covers every light source and every fire in the game.

What exists today:
- **Torches** (`scripts/Visual/Torch.gd`) are a flickering shadowed `OmniLight3D` with one 4-frame, 16×16 pixel flame billboard drawn in code (`Fx.texture(&"flame")`), plus a crackle loop.
- **The guards' lantern and torch** (`GuardHands._hang_lantern`, `GuardHands._torch`) are boxes and cylinders round a `Torch`.
- **The brazier** (`Fire.brazier`) is a cylinder bowl on a cylinder post.
- **The campfire** (`Furnishings.campfire`) is a ring of box stones round a `Torch`.
- There are no candles, oil lamps, hanging lanterns, lamp posts or hearths.

Looks and sound only. No gameplay changes: lights keep their current brightness and hazards, and guards behave as before.

## 2. Decisions

| Question | Decision |
|---|---|
| Order of the program | **Lights and fire first**, then night and weather, then props. The weather then acts on finished lights: wind in the flames, rain on braziers, lightning over them. |
| Which lights | **All four families:** torches, lanterns and lamps, candles and oil lamps, open fires (section 8). |
| Lights going out | **The look of both states, no gameplay.** Every light has a lit and an out state, with lighting, snuffing and dousing effects and sounds. Snuffing by hand, water arrows and guards relighting stay in the canal-quarter tools sub-project, which will only have to switch states. |
| Fixture textures | **The user's textures.com photos**, converted by `ps2ify.py` and kept out of git (the repository is public). Fresh clones fall back to flat colours shaded by baked vertex colours (section 6.2). |
| Base branch | **Branch from main.** npc-showcase (fuel, flare, wind lean, `Atmosphere`) has since been merged into main, so this branch starts with it; `Torch.gd` keeps its interface (section 10.3). |
| How fixtures are made | **A scripted Blender pipeline, `tools/props`,** built like the wardrobe: recipes to headless Blender to baked GLB. |
| Glow | **Thief: Deadly Shadows coronas:** a halo per fixture, constant size on screen, hidden by walls and people with a 0.15 s fade. Flame cores cross the glow threshold. |
| Flames | **Blender heat flipbooks:** looping procedural flames rendered as greyscale heat, coloured per light type by a ramp, hard alpha, layered Thief-style with a core, embers, lit smoke and soot. |
| Visual effects | **Made by us.** No downloaded free VFX of any kind. Web material is reference only. |
| Sounds | **Cut and layered from the user's packs by `tools/prepare_sfx.py`.** No procedural audio. Any gap is brought to the user, and nothing is downloaded without their approval. |

## 3. Scope

**In scope:**
- 15 fixtures in four families (section 8), their lit and out looks, and their transitions;
- the flame, corona, ember, smoke, soot and heat-haze effects;
- the `tools/props` Blender pipeline, for light fixtures only (sub-project 2 extends it to doors, chests and barrels);
- the `tools/textures/ps2ify.py` converter and the runtime material lookup, built as the canal-quarter spec's section 10 describes, so the mission reuses them;
- the sounds of every fixture;
- replacing today's torches, guard lanterns and torches, brazier and campfire everywhere they appear;
- a lights gallery map, a stager for screenshots, and a test suite.

**Out of scope:**
- the gameplay of putting lights out: snuffing, water arrows, guards relighting (the canal-quarter tools sub-project);
- the moon, clouds, rain, fog, storms and wind simulation (sub-project 3). This sub-project only takes a wind vector (`lean`);
- doors, chests, barrels, crates and furniture (sub-project 2);
- windows as light sources, and glowing window panes;
- the player carrying a light;
- the canal-quarter level itself.

## 4. Success criteria

- Every fixture in section 8 is built by `tools/props`, passes `props.sh check`, and appears in the lights gallery lit and out.
- Every flame is drawn from our own heat sheets and ramps. No texture in `assets/vfx/` came from outside the project.
- Coronas disappear behind a wall or a guard and fade back within 0.15 s.
- None of the new effects (flames, coronas, embers, smoke, haze) is visible to the lightgem's cameras. `LightProbe` readings beside a torch, brazier or campfire match today's within 10%, and the stager's lightgem readings at the same spots match main's by eye.
- A fresh clone with no photos in `textures/ps2/` loads every map with no errors and no missing-texture warnings.
- All existing suites pass, plus the new `lights_test`, run with `--fixed-fps 60`.
- The user has reviewed the stager sheets and walked the gallery, and has auditioned the sounds.

## 5. References

A research pass (references only; nothing downloaded) found these techniques. The points that shape this design, with their sources:

- **PS2 hardware:** the GS filled about 1.2 Gpixel/s with free alpha blending and depth testing, so stacked additive sprites were cheap. It had one texture per pass and no pixel shaders, so effects were layers of simple quads.
- **Thief: Deadly Shadows (Unreal Engine 2):** light classes run FlameLight → TorchLight → GenWallTorch, each light with a `CoronaSize`. UE2 coronas stay the same size on screen, are hidden by a trace, and fade in and out. The source: [UE coronas](https://beyondunrealwiki.github.io/pages/corona.html), [T3Ed tutorial](http://www.shadowdarkkeep.com/files/komagtutt3.htm).
- **Thief 1/2 (NewDark particle fire):** three groups: a red core (12 particles), orange additive puffs (40), black smoke (70). Arx Fatalis put a soot scorch on the wall above each torch, and mappers praised how much it grounded the torch ([NewDark fire](https://thief.starforge.co.uk/wiki/Tutorials:NewDark/Particle_effects_-_Bitmap_Disk_Fire)).
- **Shadow of the Colossus and ICO:** bloom by shrinking a Z-masked frame to 64×64, blending it with the previous frame and stretching it back. Smoke sprites were lit from the view and light directions, so each puff had a lit and a dark side ([making-of](https://www.froyok.fr/blog/2012-10-breakdown-shadow-of-the-colossus-pal-ps2/resources/making_of_sotc.pdf)).
- **INSIDE (Playdead):** fire drawn as a scalar heat value and mapped through a gradient ramp, so layered sprites never make dark whites or overbright reds. Glare sprites hidden by sampling depth ([talk](https://loopit.dk/rendering_inside.pdf)).
- **What reads at 360 lines:** about 257 ÷ distance pixels per metre at a 70° field of view. A 25 cm torch flame is about 32 px tall at 2 m, a 3 cm candle flame about 8 px at 1 m.
- **Flame motion:** bigger fires move slower. Buoyant flames puff at about 1.5/√D Hz (D the flame's width in metres). A single candle in still air burns steadily and flickers only when disturbed ([candle flicker](https://www.nature.com/articles/srep36145)).
- **Colour:** a candle is about 1850 K and an oil lamp about 1800 K. Blackbody sRGB: 1800 K #FF8200, 2000 K #FF8D0B, 2200 K #FF9829, 2500 K #FFA645.
- **Fire sound (Farnell, *Designing Sound*):** a low roar (about 60% of the mix), a bursty hiss above 1 kHz (about 30%), and short crackles at irregular times (about 10%). Fire sounds fake without the irregular crackle, or when the crackles fall into a pattern. Thief's ambiences were short, sparse loops, so guards stayed audible.
- **The real objects:** torches were a resinous stick wrapped in tow soaked in pitch, and rarely used indoors. Cressets were iron baskets of pitch rope on poles or walls. Lanterns were tankard-shaped with horn panes and a domed, vented roof. Tallow candles smoked; beeswax was for churches and nobles. Candlesticks were iron, pewter or brass, with a socket or a pricket spike.

## 6. Structure

### 6.1 The props pipeline (`tools/props/`)

Headless Blender 5.2, laid out like `tools/wardrobe`:

| File | Job |
|---|---|
| `props.sh` | `build`, `check`, `bake`, `export`, `preview`, `test`, `list`, each taking a fixture name or `all`. Exits non-zero when a step fails. `BLENDER` defaults to `/Applications/Blender.app/Contents/MacOS/Blender`. |
| `recipes.py` | Plain data, one entry per fixture: parts and sizes, material slot per part, triangle budget, sockets, light settings (energy, range, colour, shadows, flicker kind), sound settings, corona size. Readable by any Python, so `props.sh list` needs no Blender. |
| `common.py` | Shared helpers: fresh scene, lathe from a profile, extruded strap or bar, chain link, stone, weld, unwrap to a texel density, smooth by angle, triangle count, backups. |
| `build.py` | Recipe to `assets/props/source/<fixture>.blend`: the model, its UVs, its slots, and one empty per socket. |
| `bake.py` | Cycles bakes of ambient occlusion and grime into the vertex colour attribute exported to glTF, plus soot: darkening that rises above every flame socket. Bakes run on the GPU; the bake tests run on the CPU (the wardrobe's Metal crash lesson). |
| `check.py` | The rules of section 6.5, nothing written. |
| `export.py` | `assets/props/lights/<fixture>.glb` (materials named by slot, images not embedded) and `<fixture>.json` (sockets as transforms, slots, triangle count, recipe hash). |
| `flames.py` | Renders the VFX sheets of section 6.3. |
| `preview.py` | Workbench and EEVEE pictures of a fixture from four sides, for the user. |
| `test_build.py`, `test_check.py` | The pipeline's own tests. |

Sockets are empties named `flame`, `flame_1` … (every flame), `mount` (where it meets the wall or ceiling), `hang` (the chain's top), `grip` (a hand's hold), `corona` (the halo's centre). Backups before every write go to `assets/props/source/backup/`, which is gitignored.

### 6.2 Photos and materials (`tools/textures/`, `scripts/Visual/Materials.gd`)

Built to the canal-quarter spec's section 10.4:
- `ps2ify.py import ~/Downloads` copies the `TCom_*` files into `textures/source/`.
- `ps2ify.py build [name]` reads `tools/textures/recipes/<name>.json` (target size, colour count, crop rectangle, tint, contrast, grime, whether to multiply an AO map in). It crops or picks the tile, downscales by area, and reduces to the texture's own palette **without dithering** (the Retro screen dithers). Output goes to `textures/ps2/<name>.png`.
- `textures/source/` and `textures/ps2/` are added to `.gitignore`, with their `.import` files. Only the recipes are committed.

`Materials.gd` (static, like `Props.gd`):
- `Materials.surface(slot)` returns one shared `StandardMaterial3D` per slot.
- A slot's photo is `res://textures/ps2/<name>.png` when `ResourceLoader.exists` says so. Otherwise the material uses its flat colour, and nothing logs a warning.
- `vertex_color_use_as_albedo` is on, so the baked AO, grime and soot shade the flat colour and the photo alike.
- Filtering is nearest with mipmaps, matching the Retro autoload.
- `LightFixture` swaps each imported surface's material for `Materials.surface(<its material name>)`.

| Slot | Photo recipe (source) | Flat colour |
|---|---|---|
| `iron` | `rust_iron` (Rust0221, darkened and desaturated) | #2A2826 |
| `chain` | `chain` (MetalVarious0033, background keyed out) | #33302C |
| `wood_old` | `wood_old` (WoodPlanksOld0239) | #4A3524 |
| `bark` | `bark` (Wood_BarkOak9 albedo) | #3D2E22 |
| `stone` | `stone_rubble` (StoneOldMixedSize0057) | #5E5A55 |
| `ashlar` | `stone_ashlar` (StoneRegularWeathered0227) | #6B665F |
| `pitch` | none | #17110D |
| `brass` | none yet | #8C6A35 |
| `clay` | none yet | #8A5236 |
| `wax` | none (tallow is smooth) | #D9C9A3 |
| `horn` | none (it glows from inside) | #C8964B |
| `char` | none | #1C1714 |
| `coal` | none (emissive) | #2B1A12 |

Optional buys for the two open slots (check each preview before buying):
- `brass`: MetalBare0161 (hammered, light, tinted toward brass), or a crop of DoorsMedieval0533 (brass and copper door).
- `clay`: Plain Terracotta PBR0088 (a PBR set: multiply its AO in, per the canal-quarter rule).

### 6.3 Our visual effects (`tools/props/flames.py`, `assets/vfx/`)

Every file here is rendered or drawn by the project and committed:

| File | What | How |
|---|---|---|
| `flame_candle.png` | 5 frames of 8×16 | EEVEE render of a looping procedural flame, greyscale heat |
| `flame_small.png` | 6 frames of 16×24 (lanterns, oil lamps) | as above |
| `flame_torch.png` | 8 frames of 32×64 | as above |
| `flame_brazier.png` | 10 frames of 64×64 | as above |
| `flame_fire.png` | 12 frames of 64×96 (campfire, hearth, cresset) | as above |
| `smoke.png` | 4 puff shapes of 32×32 | noise rendered to alpha, 3 levels |
| `corona.png` | 64×64 radial falloff | drawn by the script |
| `soot.png` | 128×128 soot streak, alpha | noise rendered upward from a point |
| `cookie_lantern.png` | 512×256 panorama | Cycles equirectangular camera at the hanging lantern's flame socket, the frame blocking a white world: the lantern's own bar shadows |
| `ramps/<name>.png` | 64×1 colour ramps | written from data in `flames.py`: `candle`, `lamp`, `torch`, `brazier`, `fire`, `dying`, `gutter` |

**The looping flame:** a 4D noise flame whose fourth coordinate travels a circle over the loop, so the last frame meets the first. It shows the shape language of flame animation: tongues that stretch, pinch off, rise and die, the base pinned to the fuel. The heat pass is quantised to 16 levels. Alpha is hard: heat below the ramp's first stop is cut.

**Ramps** run from transparent through deep red and a 1800–2000 K orange (#FF8200–#FF8D0B) to a white-yellow core. `dying` is deeper red and dimmer; `gutter` flickers toward blue at the base (a starved wick).

### 6.4 The Godot side (`scripts/Visual/Lights/`)

| File | Job |
|---|---|
| `LightFixture.gd` | **Extends `Torch.gd`.** Instances a fixture's GLB, swaps its materials, reads its JSON sockets, gives the burner a flame point per flame socket, puts the corona at the `corona` socket, places the soot decal, switches the model's out-state look, and runs drafts and the fire's one-shots. |
| `FlameFx.gd` | Everything drawn at one flame socket: two flame sprites, the core, emitters for embers and smoke, and the heat haze. |
| `Corona.gd` | The halo: its quad, its occlusion rays and its fade. |
| `FireParticles.gd` | Static manager for embers and smoke: CPU simulation, one `MultiMesh` per kind under `Fx.world_node()`, like `Fx.gd`. |
| `LightBudget.gd` | Static: which shadow-casting lights actually cast shadows (section 8.2). |
| `Flicker.gd` | Pure functions: the energy multiplier for a flicker kind at a time, and a draft's shiver. |
| `Lights.gd` | Builders in the style of `Props`: `Lights.wall_torch(parent, flame_at, wall_normal)`, `Lights.torch_at(parent, flame_at)`, `Lights.candle(...)`, one per fixture. Each returns the fixture, already added and placed. |
| `flame.gdshader` | Heat sheet → ramp, hard alpha, frame selection, wind shear, strength, HDR core. |
| `corona.gdshader` | Constant screen size, additive, no fog, distance fade. |
| `smoke.gdshader` | Mix-blended puff lit from below by the fire's colour. |
| `haze.gdshader` | Screen texture offset by 1 px of scrolling noise. |
| `glow.gdshader` | A slot's surface that shines from inside (horn panes, coal beds, a cooling torch head): photo or flat colour plus flickering emission (section 8.1). |

`scripts/Visual/Torch.gd` stays and keeps its public interface. It becomes **the burner** every fixture extends: the light, its flicker, a `FlameFx` at each flame point, the corona, the lit/out state and the loop sound. A bare `Torch.new()` is a burner with no model, as today. Because every fixture is a `Torch`, the code that already holds torches (the brazier's fuel in `Fire.gd`, the campfire's idle spots, the guards' hands and their dropped-light tween of `energy`) works on fixtures unchanged (section 10.3).

## 7. Flames, glow and smoke

Everything drawn by `FlameFx` and `Corona` lives on `Layers.FX`. The lightgem's cameras exclude that layer, so no effect can change what the gem reads.

### 7.1 The flame

**Layers:**
- two flipbook sprites, one mirrored and started half a loop later, billboarded upright (fixed Y), drawn additively;
- a small core sprite (the sheet's hottest levels only), alpha-scissored, output at HDR (above the environment's 0.85 glow threshold) so it blooms.

`flame.gdshader` samples the heat sheet with nearest filtering. It picks the frame from time and the sheet's frame count, looks the heat up in the ramp, and multiplies by `strength`. It declares its own nearest filtering (the Retro autoload leaves shader materials alone).

**Wind:** a `lean` vector (world space, 0–1 strength) shears the sprite's top vertices downwind, up to `LEAN_REACH` = 0.07 m at a flame size of 0.34 m (scaled with size), and flattens it by up to 10%. Nothing drives it in this sub-project except the gallery's wind toggle; weather and npc-showcase's `Atmosphere` call it later.

**Strength:** 1 as made. `set_strength(k)` scales the flame (0.35–1.0 of its size as k goes 0–1) and the light (energy × k, range × lerp(0.55, 1, k)). Below 0.35 the ramp crossfades to `dying` and the frame rate drops by a third. `flare(amount)` brightens and heightens briefly, easing back over 0.9 s (npc-showcase's values).

**Slow motion:** flame frames, flicker, embers and smoke advance on scaled time, so `TimeFx` slows them with everything else.

### 7.2 The light and its flicker

Each fixture has one `OmniLight3D`; a candelabra or chandelier has one light for all its candles. It sits at the mean of its flame sockets plus 0.12 m up (so a flame never shadows its own light), with `light_volumetric_fog_energy` 1.4 as today. Its colour is warmer than white but whiter than the flame, so lit walls do not go monochrome: 2200 K (#FF9829) for torches and fires, 2500 K (#FFA645) for lanterns, lamps and candles.

`Flicker.gd` gives the energy multiplier. Each kind is a sum of smooth value noise at its puff rate and a slow drift at about 0.4 Hz:

| Kind | Puff rate | Swing | Other |
|---|---|---|---|
| `candle` | none | 0 | a draft: ±4% at about 10 Hz for 1 s, easing out |
| `lamp` (oil lamps, lanterns) | 4.5 Hz | ±5% | a hanging lantern also swings with its sway |
| `torch` | 5 Hz | ±12% | the light jitters 1–3 cm, so shadows shimmer |
| `cresset` | 3.5 Hz | ±12% | |
| `brazier` | 2.4 Hz | ±12% | a surge every 15–30 s: the flames grow 25% and embers burst, easing back over 1.5 s |
| `fire` (campfire, hearth) | 1.7 Hz | ±18% | a log settles every 20–40 s: a crack, an ember burst, and the flames jump 30%, easing back over 1.5 s |

Surges and settling logs change the flames, embers and sound only. The light never leaves energy × strength × (1 ± swing) × (1 + 0.6 × flare²), today's formula, so the gameplay reads what it reads today (the routines suite already holds the brazier's light to it).

The flame sprites' size follows the same value, so light and flame agree. Each fixture starts at a random phase, seeded from its position so headless runs repeat.

**Drafts:** four times a second, every candle, candelabra and chandelier looks within 1.5 m for the player or a guard moving faster than 3 m/s, and within 3 m for a `Door` in the `doors` group that emitted `opened` or `closed` since the last look. Either starts a draft.

### 7.3 The corona

One per fixture, at its `corona` socket. A candelabra or chandelier has one.

- **Look:** a quad drawn with `corona.gdshader`: sized in screen space (`corona_px` in the recipe, measured on the 360-line grid: candle 12, oil lamp 16, candelabra 20, lantern 28, chandelier 36, torch 48, cresset 60, brazier and fire 72), additive, `corona.png` tinted by the light's colour, never fogged. It fades out between 1.5× and 3× the light's range.
- **Occlusion:** while the fixture is on screen and inside the fade distance, `Corona.gd` casts up to three rays each physics tick, from the camera to the corona centre and to two points offset by a quarter of its world radius. The mask is the world layers and actors (guards' bodies). The player's own body is excluded. Visibility is the fraction of clear rays, eased at 1/0.15 s. Off screen, visibility snaps to 0, so turning round never shows a stale halo.
- **Lit and out:** the corona follows the light's current energy, so it breathes with the flicker and dies with the flame.

### 7.4 Embers and smoke

`FireParticles.gd` simulates both on the CPU and draws each kind as one `MultiMesh`, as `Fx.gd` does. Emitters register with it; nothing is simulated for a fixture farther than 30 m from the camera.

- **Embers:** quads 1–2 px wide on the 360-line grid, stretched along their velocity, additive, orange fading to red. They rise at 0.8–1.6 m/s with drag, drift with `lean`, and live 0.6–1.2 s. Rates: torch 6/s, cresset 10/s, brazier 15/s, campfire and hearth 20/s. A log settling or a `flare` bursts 12–20. Candles, oil lamps and lanterns have none.
- **Smoke:** puffs from `smoke.png`, mix-blended at 20–35% alpha. `smoke.gdshader` lights each puff's lower side with the fire's colour, fading with height (SotC's trick). They rise at 0.3–0.6 m/s, slower than the flame, grow ×2.5 and thin out over 2–3 s. Rates: torch 3/s (a thin wisp), cresset 5/s, brazier and campfire 6/s (a column), hearth 4/s going up the chimney. Candles and lamps have none while lit.

### 7.5 Soot and haze

- **Soot:** every fixture with a `mount` socket on a wall (wall torch, cresset bracket, wall lantern) places a `Decal` with `soot.png` above it on the wall. The decal is 0.5 × 0.9 m, reaching the ceiling if the ceiling is within 1.2 m of the flame (found by one ray up). It paints only the world layers (`Layers.WORLD_ALL`). Soot is also baked into the fixture's vertex colours.
- **Heat haze:** braziers, campfires and the hearth draw a quad above the flame with `haze.gdshader`: the screen texture offset by up to 1 px of noise scrolling upward. Drawn only within 15 m, on `Layers.FX`. Torches and smaller lights have none.

### 7.6 Lit and out

`LightFixture` API:
- `kindle(instant := false)` (named `kindle`, not `light`: every burner already has a `light` member, its `OmniLight3D`)
- `put_out(how := &"snuff", instant := false)`, where `how` is `&"snuff"` or `&"douse"`
- `is_lit() -> bool`
- signal `lit_changed(lit: bool)`
- `@export var lit := true`, the starting state

Every change calls `LightProbe.invalidate()`.

| Transition | Look | Sound | Light |
|---|---|---|---|
| Lighting | the flame grows from nothing over 0.5 s; a burst of 8 sparks | `ignite_torch` for torches, cressets and fires; the existing `ignite` for lanterns, candles and lamps | energy ramps from 0 over 0.5 s |
| Snuffing | the flame pinches out in 0.1 s; a smoke thread for 2–3 s | `snuff` | energy to 0 in 0.1 s |
| Dousing | the flame goes at once; a burst of steam (white smoke puffs, 0.6 s); the torch head or coal bed glows and cools over 3 s | `douse` | energy to 0 at once |

**Out state:** torch heads and cresset rope are `char` with the glow of the last 3 s gone; wicks are black; a brazier's or campfire's coal bed goes dark with 3–5 embers winking for 20 s after dousing; the hearth's logs are charred. The out state uses the same model, with the emissive regions turned off. `Torch.gd` (kept for the suites and npc-showcase) follows the same transitions.

## 8. The fixtures

### 8.1 The list

Energies and ranges start at today's values where the light already exists, so stealth balance does not move. The new lights are tuned in the gallery against the lightgem. "Tris" are `check` budgets for the whole fixture, chain included.

| Family | Fixture | Model | Energy / range / shadows | Tris |
|---|---|---|---|---|
| Torches | `wall_torch` | Wrought-iron wall plate, bent arm and ring cup (`iron`); a tapered stick (`bark`) with a head of tow bound in pitch (`pitch`) | 2.4 / 9 / yes | 300 |
| | `carried_torch` | The same stick and head, with no sconce, for guards; it keeps burning when dropped | 2.1 / 7.5 / no | 120 |
| | `cresset` | An iron basket of pitch rope; variants on a 2.4 m pole with a foot, and on a wall bracket | 2.8 / 10 / yes | 600 |
| Lanterns and lamps | `carried_lantern` | Tankard-shaped iron body, horn panes, domed vented roof, bail handle | 1.5 / 6.5 / no | 400 |
| | `hanging_lantern` | Larger version on a chain from a ceiling hook or a wall bracket; swings (`Hanging.gd`); its light carries `cookie_lantern.png` so the frame bars stripe the walls | 1.4 / 7 / yes | 500 |
| | `wall_lantern` | A box lantern on an iron bracket | 1.2 / 6 / no | 450 |
| | `lamp_post` | A timber post (`wood_old`), crook arm (`iron`), and a hanging lantern | 1.6 / 9 / yes | 700 |
| Candles and oil lamps | `candle` | A tallow stub (`wax`) with drips and pooled wax; heights 6, 10 and 16 cm | 0.35 / 2.5 / no | 60 |
| | `candlestick` | An iron pricket or a brass socket stick, with a candle | (its candle's) | 150 |
| | `candelabra` | 3 or 5 arms (`brass` or `iron`); one light | 0.9 / 4.5 / no | 450 |
| | `chandelier` | An iron hoop of 6 or 8 candles on three chains to a ring; one light | 1.6 / 8 / yes | 900 |
| | `oil_lamp` | A clay bowl lamp with a spout (`clay`), and a brass hanging variant (`brass`, `chain`) | 0.5 / 3 / no | 120 |
| Open fires | `brazier` | A tripod iron bowl with a glowing coal bed (`coal`, emissive, flickering) | 2.6 / 8 / yes | 700 |
| | `campfire` | Crossed logs (`bark`, `char`) on an ember bed in a stone ring (`stone`) | 2.2 / 7 / yes | 600 |
| | `hearth` | A stone fireplace (`ashlar`) about 1.6 m wide, with a hood and chimney breast, firedogs (`iron`) and logs; collision on its masonry | 2.6 / 9 / yes | 1,500 |

The horn panes, coal beds and a torch head's last glow shine from inside: those faces use the material slot's glowing version, drawn by `glow.gdshader` (the slot's photo or flat colour, plus emission of the light's colour × the fixture's current flicker, passed as an instance uniform). The shader declares nearest filtering itself, since the Retro autoload leaves shader materials alone.

The hanging lantern and the lamp post (whose lantern is the same model) carry `cookie_lantern.png`. The carried lantern throws no shadow, so it needs none.

### 8.2 Performance

- **Shadow budget:** `LightBudget` looks four times a second at every burner made with `shadows` on and gives `shadow_enabled` only to the 6 nearest the camera. A light may change state only while it is farther from the camera than both 12 m and its own range + 1 m, so no shadow pops up close and the light cannot be touching the player (the lightgem reads what it always read). If more than 6 shadow-casting lights sit within 12 m of one spot, that spot is over budget: `LightBudget` pushes a warning once per level, and the gallery and maps are laid out to stay under.
- **Gameplay keeps its shadows:** `LightProbe` casts a shadow ray only for lights with `shadow_enabled`, so a light the budget turned off would light a body through a wall. Every burner marks its light with meta `casts_shadow` (its `shadows` export), and `LightProbe` reads that meta instead of `shadow_enabled` when it is present.
- **Distance:** candles and oil lamps fade their light and corona out between 20 and 25 m (`distance_fade`). Embers, smoke and haze run only within 30 m (haze 15 m).
- **Fill:** at most two flame sprites and one core per flame socket; candelabra and chandelier candles draw one sprite each and no core.

## 9. Sound

All sounds are cut and layered by `tools/prepare_sfx.py` from recordings the user already has: the TomMusic pack, the NOX Essentials (CC0), the packs approved for the sound design in `~/Downloads/AUCOD Web SFX`, and the 400 Sounds Pack and the FilmCow Recorded and Designed packs (the user approved both on 2026-09-27; they carry no licence file on disk). Every source is credited in `CREDITS.md`. Levels follow the existing loudness targets (`Sfx.GAIN`).

**Loops** (3D on the World bus). Each behaves like today's torch crackle: it starts only when the camera is within reach + 1 m, at a random point in the loop, pitched 0.9–1.1 per fixture, and is muffled through walls by `Sfx.occlusion_at`, eased.

| Fixture | Loop | Level | Reach |
|---|---|---|---|
| wall torch, carried torch | `torch_loop` (exists) | −13 dB | 11 m |
| cresset | `fire_small` (NOX `Ambiance_Firecamp_Small_Loop_Mono`) | −12 dB | 12 m |
| brazier, campfire | `fire_medium` (NOX `Ambiance_Firecamp_Medium_Loop_Mono`) | −11 dB | 14 m |
| hearth | `fire_big` (NOX `Ambiance_Fire_Big_Loop_Mono`), low-passed, with a slow chimney draw from NOX `Ambiance_Wind_Calm_Loop_Stereo` cut to mono and pitched down | −14 dB | 14 m |
| candles, oil lamps, lantern flames | none | | |

**One-shots:**
- **Crackles and pops:** `crackle` (4–6 takes) and `coal_pop` (3–4 takes), cut from the crackle transients inside the NOX fire loops. Each fire plays them over its loop at irregular times: a Poisson process at 0.6/s for torches, 1/s for braziers and campfires, 0.5/s for the hearth, never on a grid.
- **`log_settle`:** a low wooden crack, with the ember burst and the flame jump of section 7.2.
- **`ignite_torch`:** a cloth whoosh (the existing `whoosh_light` family's source) layered with the attack of TomMusic's `Firebuff` or `Fireball` spells, cut short and low-passed so it reads as pitch catching rather than magic.
- **`snuff`:** a short breath puff and a thin hiss tail.
- **`douse`:** a water splash and a steam hiss.
- **`lantern_creak`:** when a hanging lantern's swing speed passes a threshold, from `creak_rope`'s source and a metal creak.
- **`bail_rattle`:** a guard's carried lantern rattles on every other footstep, quietly (−30 LUFS target).

If a source for any one-shot turns out unusable in the user's packs, that sound is listed for the user with what is missing. Nothing is synthesised or downloaded to fill it.

## 10. Wiring into the game

### 10.1 Maps

The maps that place a `Torch` today (`retro_showcase`, `stealth_gym`, `combat_gym`, `combat_arena`, `npc_gym`, `npc_showcase`) switch to `Lights.torch_at(parent, flame_at, …)` inside their own `_torch` helpers. The burner is lit at once where the old flame was; on its first physics tick (once the level's walls are in the physics space) it looks horizontally within 0.5 m of the flame for a wall. If it finds one, it builds a `wall_torch` model against it; otherwise, if there is floor within 3.2 m below, a pole `cresset` fitted to reach it; otherwise it stays a bare burner (today's look) and pushes a warning naming the spot. `retro_showcase`'s own `_bracket` model goes, since the sconce replaces it. Braziers and campfires come in through `Fire.brazier` and `Furnishings.campfire` (section 10.2). No map gains new lights, so each level's balance is unchanged.

### 10.2 Guards, brazier and campfire

- `GuardHands._hang_lantern` builds `carried_lantern`, keeping the bail, `Hanging.gd`, the grip on the fist, and `drop_lantern`'s rigid body and shapes.
- `GuardHands._torch` builds `carried_torch`, keeping its fist attachment and dropped physics.
- `Fire.brazier` builds the `brazier` fixture and keeps the `Fire` area, its hazard and its groups.
- `Furnishings.campfire` builds the `campfire` fixture and keeps its static body, idle spots and navmesh keep-off.
- Energies and ranges stay as today (section 8.1), so `GuardLife`'s lantern thresholds and `LightProbe` readings stay put.

### 10.3 `Torch.gd` and npc-showcase

`Torch.gd` keeps every export and member the suites use today: `color`, `energy`, `light_range`, `flicker`, `shadows`, `frame_rate`, `flame_size`, `light`, `flame`, `crackle`. It also gains npc-showcase's interface, with the same meaning:
- `lean(v: Vector3)`;
- `set_strength(k: float)`;
- `flare(amount := 1.0)`, easing back over 0.9 s;
- membership of the `torches` group.

`LightFixture` extends `Torch`, so it has all of them and joins `torches` too; `Fire` areas stay in `fires`. The members the suites read keep their meaning: `flame.position` moves with the wind (aliveness A19), `_flare` rises when stoked (habits H25), `crackle` and `_crackle_db` (sound M13), and the light stays within energy × strength × (1 ± flicker) (routines R2).

`Torch.flame` stays a `MeshInstance3D` (the primary flame sprite of the first flame point). Its material becomes a shader material, so the flipbook frame is read from a new `Torch.frame` (int) instead of the material's `uv1_offset`.

`Atmosphere` already makes embers for every node in `fires`. The brazier's fixture sets `embers_by_atmosphere`, and `FireParticles` skips its embers whenever an `Atmosphere` is in the scene, so no fire gets two sets.

### 10.4 The lights gallery

`maps/lights_gallery.tscn` (+ `.gd`): a dark stone hall under `Retro.night_environment`, with one bay per family and every fixture and variant in section 8.1. Debug keys:

| Key | Does |
|---|---|
| L | cycle lit → snuffed → lit → doused → lit, for every light |
| K | wind off / gentle / strong from the west (drives `lean`) |
| J | coronas on / off |
| H | `set_strength` 1 → 0.3 → 1 on every fire |

Each bay also has one guard carrying a lantern and one carrying a torch on a short patrol, a door that opens on a timer (drafts), and a pillar between two lights (corona occlusion).

## 11. Verification

### 11.1 Automated checks

**Blender** (`props.sh test`):
- `test_check.py`: every recipe builds, meets its triangle budget, has its sockets (a fixture with flames has a `corona`; wall fixtures have a `mount`), uses only known slots, and has UVs within the texel density band (64 px/m ± 50% for 128 px photos). Sabotaged copies of a recipe fail each rule.
- `test_build.py`: rebuilding a fixture gives the same recipe hash; the soot bake darkens vertices above a flame socket and not below it.

**Converter** (`python3 -m unittest tools/textures/test_ps2ify.py`): output size, palette count (at most the recipe's colours), hard alpha (only 0 and 255), crop respected, missing source reported by name.

**Godot, `tests/lights_test.tscn`** (run headless with `--fixed-fps 60`, seeded per `headless-test-determinism`). One check per line:
- every fixture builds with its light, its flame sockets and (where due) its corona;
- with `textures/ps2/` hidden (the test points `Materials` at an empty folder), every fixture loads with flat colours and no errors;
- a corona behind a wall has visibility 0 within 0.2 s and returns within 0.2 s when the wall is removed; a guard walking between reads partial and recovers;
- flames, cores, coronas, embers, smoke and haze are all on `Layers.FX`, and the gem camera's cull mask excludes them;
- `Flicker` for each kind stays within its swing, and its dominant frequency is within 20% of its puff rate;
- a candle's light is steady in still air and shivers after a nearby door opens;
- `kindle()`, `put_out(&"snuff")` and `put_out(&"douse")` change the light's energy on their timings, emit `lit_changed`, and move `LightProbe.light_at` beside the fixture;
- `LightBudget` never gives more than 6 shadows, and never switches a light within 12 m of the camera;
- under `TimeFx` slow motion, flame frames and embers advance at the slowed rate;
- a fire's loop plays only within its reach, and is quieter behind a wall;
- the guards' lantern and torch still hang from their fists and drop as rigid bodies;
- a guard pushed into the new brazier still catches fire;
- `LightProbe` readings beside a wall torch, the brazier and the campfire are within 10% of today's (values captured on main before the change);
- `Torch.gd` answers `lean`, `set_strength` and `flare`, and is in `torches`.

### 11.2 Existing suites

All 32 suites in `tests/` run with `--fixed-fps 60` and must pass. Their assertions do not change. One check reads an internal that this work replaces: retro R6 reads the flame's frame from `material_override.uv1_offset`; it switches to `Torch.frame` with the same assertion (at least 3 frames seen). The suites that hold torches (retro, smooth, sound, aliveness, habits, routines, life, stealth, combat, wits, polish, showcase) are the ones most at risk; section 10.3 keeps their interface.

### 11.3 Review by the user

- **Stager:** `tests/visual/stage_lights.tscn` (windowed) shoots every fixture lit and out at 1, 3 and 8 m, and each bay wide, through the Retro pass, into a contact sheet. It logs the frame time per bay, and the lightgem's reading for a player standing 2 m from a wall torch, the brazier and the campfire, run once on main first for comparison. The sheet goes to the user before they walk the gallery.
- **Pictures from Blender:** `props.sh preview all` sheets, for the models alone.
- **Sound:** the user auditions in the gallery and says what to swap or re-level (Claude cannot hear).

## 12. Error handling

- **A missing photo** gives the slot's flat colour, silently. A `--verbose` flag on the gallery lists which slots fell back.
- **A missing GLB or JSON** makes the builder push an error naming the fixture and return a bare `Torch` at the flame position, so a map still has its light and the gameplay holds.
- **A missing VFX sheet or ramp** is a test failure (they are committed). At runtime the flame falls back to `Fx.texture(&"flame")`, today's flame.
- **A missing sound** plays nothing (`Sfx.stream()` returns null, as now).
- **Blender:** every step backs up before writing. `props.sh` exits non-zero on a failed step and names it. Bake tests run on the CPU.
- **Over budget:** `LightBudget` warns once per level (section 8.2). `check` fails a recipe over its triangle budget.

## 13. Components

**New:**
- `tools/props/`: `props.sh`, `recipes.py`, `common.py`, `build.py`, `bake.py`, `check.py`, `export.py`, `flames.py`, `preview.py`, `test_build.py`, `test_check.py`
- `tools/textures/`: `ps2ify.py`, `test_ps2ify.py`, `recipes/*.json` (rust_iron, chain, wood_old, bark, stone_rubble, stone_ashlar)
- `assets/props/source/*.blend`, `assets/props/lights/*.glb` + `*.json`
- `assets/vfx/*.png`, `assets/vfx/ramps/*.png`
- `scripts/Visual/Lights/`: `LightFixture.gd`, `FlameFx.gd`, `Corona.gd`, `FireParticles.gd`, `LightBudget.gd`, `Flicker.gd`, `Lights.gd`, `flame.gdshader`, `corona.gdshader`, `smoke.gdshader`, `haze.gdshader`, `glow.gdshader`
- `scripts/Visual/Materials.gd`
- `maps/lights_gallery.tscn` + `.gd`
- `tests/lights_test.tscn` + `.gd`; `tests/visual/stage_lights.tscn` + `.gd`
- `audio/ambience/fire_small.ogg`, `fire_medium.ogg`, `fire_big.ogg`, `chimney.ogg`; `audio/sfx/crackle_*`, `coal_pop_*`, `log_settle_*`, `ignite_torch_*`, `snuff_*`, `douse_*`, `lantern_creak_*`, `bail_rattle_*`

**Changed:**
- `scripts/Visual/Torch.gd` (a wrapper over `FlameFx`, plus the npc-showcase interface)
- `scripts/AISystem/GuardHands.gd` (carried lantern and torch)
- `scripts/Combat/Fire.gd` (the brazier's look)
- `scripts/Interaction/Furnishings.gd` (the campfire's look)
- the six maps of section 10.1
- `tools/prepare_sfx.py`, `scripts/Audio/Sfx.gd` (new names and gains)
- `CREDITS.md`
- `.gitignore` (`textures/source/`, `textures/ps2/`, `assets/props/source/backup/`)

## 14. Risks

- **Too many lights for the frame rate.** Candles tempt density. Mitigated by one light per cluster, the shadow budget and distance fades. The gallery is the worst case, and its frame time is reported in the stager log.
- **Coronas through thin geometry.** Rays test collision, not drawn meshes: a mesh with no collider (a banner) will not hide a halo. That is acceptable; walls and guards have colliders.
- **Heat haze and the Retro pass.** A 1 px offset may read as noise on the pixel grid. It is reviewed in the stager, and can be turned off per fixture in the recipe.
- **TIFF inputs.** Some photos are 2K 16-bit TIFFs (`Wood_BarkOak9`). `ps2ify.py` converts to 8-bit before palettising; a file PIL cannot read is reported by name.
- **The npc-showcase merge.** `Torch.gd` will conflict. Section 10.3 makes the resolution "take this branch's file"; the merge must then run npc-showcase's suites (showcase, talk, stations, routines).
- **Sounds judged without ears.** Picks come from measured loudness, onset and brightness. The user's audition decides.

## 15. Rollout

1. The texture converter and `Materials.gd` (useful on its own; nothing visible changes).
2. The VFX sheets and ramps, `FlameFx`, `Flicker`, the corona and the particles, proven on the existing `Torch` (every map's torches improve at once).
3. The props pipeline and the torch family, then lanterns and lamps, candles and oil lamps, open fires.
4. Lit and out states, sounds, `LightBudget`.
5. Maps, guards, brazier and campfire switched over; the gallery; the stager; the full regression; the user's review.
