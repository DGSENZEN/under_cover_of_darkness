# Night and Weather: Design

**Date:** 2026-09-27
**Status:** design approved in conversation; this document awaits the user's review.
**Program:** the first of two environment sub-projects for the NPC showcase (then the yard rebuilt in Blender: a detailed garrison, foliage, hiding places). It also builds the canal-quarter spec's section 7.5 ("Night and weather") as a reusable system, which the look-and-sound program had planned next; it is built once, here.
**Branch:** `showcase-environment` (worktree `.claude/worktrees/npc-showcase`), from main e6594b1.

## 1. Goal

The user asked for "a skybox, a moon that actually exists", then "a prettier skybox, weather, better moonlight". The other program's ask was light rain, strong rain, thunderstorms, fog, and the moon affecting the lighting. The showcase yard today has a flat dark background colour and a moon that is only a `DirectionalLight3D`.

## 2. Decisions

| Question | Decision |
|---|---|
| Order | Night and weather first; the yard rebuilt in Blender second. |
| Approach | One sky shader draws the gradient, stars, moon, halo, clouds and the Blender skyline. The moonlight reads its cloud cover from the same cloud field, so what crosses the moon dims the yard. A reusable `Night` node owns the weather. |
| Moon | A full moon about 2° across (4× real), with a soft halo and silver-edged nearby clouds; exactly where the moonlight comes from. |
| Skyline | A 360° panorama of silhouettes (town rooftops, a spire, the canal bank, hills, tree lines, a few lit windows), modelled and rendered in headless Blender; our own render, committed. |
| Weather arc in the showcase | It follows the story, act by act (section 6). F4 cycles the states for inspection. |
| Gameplay | The weather plays: a cloud over the moon darkens you (the lightgem and the guards agree), rain masks sound (drizzle +3 dB, shower +6, storm +10; every 7 dB halves reach), and a lightning flash lights you like everything else. |
| Thunder | None of the user's packs has thunder. Claude finds a CC0 recording and shows the user its source, file and size; it is downloaded only after the user says yes, then cut by `tools/prepare_sfx.py` and credited. Until then storms flash without thunder. |

## 3. The sky

A sky shader (`shader_type sky`) on the map's environment, whose background becomes the sky. Ambient light stays a flat colour, as now, and the lightgem keeps its own isolated environment, so the sky changes no lighting except through the moon (below).

Drawn from the ground up:

- **Skyline:** the panorama strip, sampled by azimuth between about 2° below and 12° above the horizon, its alpha cutting the silhouettes out of the sky behind. The silhouettes are near black with a faint moon-side rim. Fog pales them toward the haze colour, and a lightning flash lights them.
- **Gradient:** deep blue-black overhead to a hazy horizon glow behind the silhouettes, the glow brighter on the moon's side.
- **Stars:** hashed single-pixel stars (read on the retro 640×360 grid), a slow slight twinkle; they fade within about 15° of the moon, in the horizon haze, and behind cloud.
- **Moon:** a disc 2° across at the moon light's direction (`LIGHT0_DIRECTION`), full, its face shaded by noise (maria), with a halo falling off over about 8°. Clouds within about 6° of the moon take a silver edge.
- **Clouds:** a seamless noise field projected on a plane overhead (the view direction's xz over its height, plus an offset the wind integrates), thresholded by the state's cover and lit from the moon's side. A scripted **veil** (`Night.cover_moon(hold)`) is a soft cloud blob that drifts over the moon in about 4 s, stays over it for `hold` seconds, and drifts off in about 4 s.
- **Lightning:** a flash uniform brightens the sky, the clouds and the skyline.
- **Fog:** raises the haze and lowers the stars and the skyline's contrast.

**Clouds and light agree:** `Night` keeps the cloud field as an image on the CPU and samples it with the shader's own projection at the moon's direction (the veil included). The moon's light energy is `base × lerp(1.0, 0.15, cover_at_moon)`, and the ambient energy is `base × lerp(1.0, 0.9, cover_at_moon)`.

**Moonlight:** the yard keeps its moon direction (from the north-west, low), because its hiding places are laid out in its shadows. It is calibrated to the canal spec's numbers:

- open moonlit ground reads about 0.25–0.3 on the lightgem (standing still, seen within about 8 m);
- fully under cloud it reads about 0.05;
- building shadows sit near the ambient floor.

A test measures all three.

## 4. The weather

**States** (each value eased from the last over the seconds `Night.to(state, seconds)` is given; 0 s jumps):

| State | Cloud cover | Rain | Wind (m/s, gusts) | Fog | Sound mask |
|---|---|---|---|---|---|
| clear | 0.15 (a cloud crosses the moon every 60–90 s, dark for 15–25 s) | 0 | 1, light | base | 0 dB |
| cloudy | 0.5 | 0 | 2 | base | 0 dB |
| drizzle | 0.65 | 0.25 | 2 | base | +3 dB |
| shower | 0.8 | 0.6 | 4 | base | +6 dB |
| storm | 0.95 | 1.0 | 8, strong; lightning every 20–40 s | base | +10 dB |
| fog | 0.4 | 0 | 0.5 | 4× base, plus mist banks | 0 dB |

- **Rain:**
  - Streaks as thin quads in a box about 24 × 12 × 24 m around the camera, slanted by the wind, with about 3000 drops visible at full rain.
  - They stop at roofs and overhangs: particle collision against a heightfield that follows the camera, so no rain falls inside the store, the shed or under the gate.
  - Each drop makes a small splash where it lands.
- **Indoors:** a ray 30 m straight up from the camera. The sound uses it (indoor or outdoor rain).
- **Wetness:**
  - One value from 0 to 1. It rises toward the rain amount over about 30 s and dries at about 1/120 per second.
  - Every material the map registers with `Night`, and the shared `Materials` surfaces, darken toward 0.7 of their colour and go from 0.85 to 0.35 roughness as it rises, which gives a moonlit sheen.
  - Puddle decals at the map's marked low spots fade in with wetness. Above 0.3 wetness, a footstep in one plays a splash.
- **Wind:**
  - A direction on the ground plane, a speed, and gusts (about ±50% over 3–8 s).
  - It leans the torch flames (`Torch.lean`, every torch in the "torches" group), drives the clouds and slants the rain.
  - It has no other gameplay effect.
- **Lightning (storm only):**
  - The sky flashes, and the moon's light pulses to about 6× for 0.06 s, dips, then pulses again for 0.04 s.
  - Thunder follows after 1–4 s, quieter the longer the delay.
  - The guards read your light every tick through `LightProbe`, which already counts the moon, so a flash can give you away.
- **Fog:** the environment's volumetric fog density rises to 4× the map's base; low `FogVolume` mist banks lie over the yard's ground.
- **Sound:**
  - An `Ambience` rain layer crossfades the NOX calm and strong rain loops by the rain amount (the repo's interior rain ambience indoors).
  - A wind layer follows the wind speed (the NOX calm wind loop).
  - A drip layer plays while wetness is above 0.2 (FilmCow's dripping water).
  - Thunder, per section 2.
  - Everything is cut by `tools/prepare_sfx.py` and credited in `CREDITS.md`; no procedural audio.
- **The noise floor:** `SoundBus` gains a static masking level (dB). Every sound's reach becomes `range_for(db − masking)`, so +10 dB leaves 2^(−10/7), about 0.37, of the reach.
- **Its own dice:** `Night` rolls its cloud crossings, gusts and lightning with its own `RandomNumberGenerator`, seeded once from the world's. The weather never shifts the world's dice (as the Cinema editor's own dice, 2026-09-27).

## 5. The parts

- `scripts/Night/Night.gd`: the node a map adds beside its moon light and environment.
  - Exports: the moon light, the environment, the base energies and fog, puddle spots, the starting state.
  - API:
    - `to(state: StringName, seconds: float)`;
    - `cover_moon(hold: float)`;
    - `flash()`;
    - `cloud_cover() -> float` (at the moon, veil included);
    - `wetness`;
    - `wind: Vector3` (with gusts);
    - `masking_db`;
    - `state`.
  - It sets `SoundBus` masking, the moon and ambient energies, the fog, the wetness on registered materials, and the torches' lean.
- `scripts/Night/NightSky.gd` + `night_sky.gdshader`: the sky material, its uniforms fed by `Night`; the cloud field and its CPU sampler share one projection function (mirrored in GDScript).
- `scripts/Night/Rain.gd`: the particles, the heightfield that follows the camera, the splashes, the roof test.
- `scripts/StimuliSystem/SoundBus.gd`: `masking_db`.
- `scripts/Audio/Ambience.gd`: the rain, wind and drip layers.
- `scripts/Visual/Materials.gd`: the wetness hook for its shared surfaces.
- `tools/skyline/`: a headless Blender script (modelled on `tools/props`) that builds the silhouettes procedurally and renders `assets/sky/skyline.png` (about 4096 × 512, RGBA).
- The showcase: `maps/npc_showcase.gd` adds `Night` (and marks its puddle spots); `scripts/Showcase/ShowNight.gd` carries the weather per beat; F4 cycles the states, and the overlay names each.

## 6. The showcase night

The weather is data on the beats of `ShowNight`, changed only by `Night.to` and `Night.cover_moon`:

- **Act I, The Watch at Rest:** clear.
- **Act II, A Knife in the Dark:**
  - it opens clear;
  - as the intruder moves in ("his moment"), the veil drifts over the moon and holds through the knife (the kill in the dark);
  - drizzle begins with the witness.
- **Act III, The Cry:** shower.
- **Act IV, Steel:** it opens in a shower and goes to storm over about 30 s.
- **Act V, the ending:** the storm eases to fog over about 40 s.

Each act's first shot comes up through black, so a state set at 0 s when an act begins is hidden by the fade. The night-pacing sub-project may move any of this.

F4 cycles clear, cloudy, drizzle, shower, storm, fog, each over 2 s.

## 7. Testing

**A new `night_test` suite:**

- Cloud cover at the moon follows the field and the veil: clear, the moon's energy is at its base; covered, it is 15% of it; the veil covers it fully for its whole hold, after drifting in over about 4 s.
- The CPU sampler agrees with the shader's projection (the same function, checked at known directions).
- The lightgem reads 0.25–0.3 on open moonlit ground, about 0.05 under full cloud, and near the ambient floor in building shadow.
- Each state's masking: a sound's reach under storm is 0.37 of clear (±0.02), and a guard's hearing follows.
- A flash raises the player's exposure within 0.1 s and lets it back down; thunder is scheduled 1–4 s later.
- `to(state, seconds)` eases (no value jumps more than its share a frame), and 0 s jumps.
- The roof test: under the store's roof is indoors, the open yard is not.
- Wind leans the torches, and gusts vary it.
- F4 cycles the six states in order.
- The weather's dice are its own: a night with weather leaves the world's random sequence where it was.

**The showcase suite:** each act has its weather (the state when its first shot comes up), and the knife falls with the moon covered (cover at the moon 0.9 or more).

**By eye:** windowed stills of every state from fixed viewpoints (a stage scene), and a recorded night (`tools/record_showcase.sh`).

**Performance:** the fps report stays above 120 at 1080p with the storm on.

## 8. Out of scope

- The yard rebuilt in Blender: foliage, the detailed garrison, hiding places (the next sub-project).
- The night's pacing: the murder, the grief, the hunt.
- Saving the weather, noise zones with local masking, and wind on cloth, ropes, signs and lanterns. These are the canal spec's section 7.5 items this yard does not have; the `Night` API leaves room for them.
- A mission-clock schedule (the canal mission's rain waves and storm trigger): `Night.to` is what a clock would call.

## 9. As built (2026-09-27)

Where the build differs from the sections above, this wins:

- **Under cloud** a man reads about 0.07, not 0.05: with open moonlight at 0.28 and the ambient floor at 0.035, the spec's own dimming (the moon to 15%, the ambient to 90%) gives 0.068; 0.05 would need shadows near black (0.015), too dark to film.
- **The skyline strip** spans 2° below the horizon to 28° above (not 12°), rendered 4096 × 384: from the yard floor the walls hide everything below about 9°, and the spire reaches 25°.
- **Crossings** (clear and cloudy): one every 60–90 s from start to start, the moon dark 15–25 s (a hold of 12.7–22.7 s plus the veil's edges).
- **The weather's sounds** live in `NightSound.gd` (not `Ambience.gd`); under a roof the rain is 8 dB lower rather than switching to the interior loop.
- **The clouds drift with the wind** (the field's offset runs against it).
- **The sky** reads a clock uniform, not the engine's time, and keeps a small incremental radiance map (nothing reads it).
- **Atmosphere's motes** roll their own dice too, since the wind's strength changes how many leaves it makes.
- **Puddle footsteps:** the player's and the guards' floor reads "water" in a wet puddle.
