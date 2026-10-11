# The Zócalo's effects: smoke, fire, fog, drift and the occult

Date: 2026-10-10. Branch: eclipse-city. Follows the scenes plan
(docs/superpowers/plans/2026-10-10-zocalo-scenes.md, Tasks 1-6 built), whose
Task 7 (stills, frame rate, final review) waits for this. Techniques and
sources: docs/superpowers/refs/mexico_city/vfx_techniques.md.

## Why

The first effects are billboard puffs and specks. The user: "we have the
capacity to create much more interesting particle effects, that's what Blender
and the fact Godot is a game engine is for", and "remember our aesthetic
inspirations when making the effects! We want that sort of Hellboy and Deadlock
intersection with our mexican inspirations." They chose all four groups: smoke
and fire; mist, fog and light; petals, leaves and pigeons; the occult set
pieces.

Success: standing in the plaza at night you see copal curl up lit by the
lamps, the god's breath pull the smoke and petals in and push them out, the
wards hum with it, braziers throw embers that bounce on the setts, green mist
creep from the seeped booths, petals tumble and settle; and every one of them
reads as this city, not any game.

## The register

- **Hellboy (Mignola):** heavy, graphic shapes; light in two or three hard
  bands, shadow as solid mass; the occult as physical, folkloric hardware
  (iron, wax, chain, bone), never glitter.
- **Deadlock:** readable silhouettes at a distance, chunky stylised volumes,
  colour that tells you what a thing is; muted world, saturated accents.
- **Mexico:** copal's thick white resin smoke, cempasúchil, clusters of
  candles at ofrendas, papel picado colour, volcanic stone, the dead's warmth;
  Aztec-styled glyph forms of our own invention (never copied INAH pieces).
- **The colour rule holds:** marigold amber for the dead, cyan-white `#CFE8F0`
  for the wards, oxblood `#6E1F1A` for the gods, phosphor green `#7FD36A` for
  the seeped. Fire is warm orange-gold, never marigold-saturated.
- **Every effect has a source** in the world (world built by its events):
  smoke from a censer or a brazier, mist from a seeped machine, petals from an
  offering or a wake, sparks from the god's chains.
- **Our own, always:** every sheet, mesh and flipbook is rendered or drawn by
  us (Blender sims, Geometry Nodes, procedural paint); nothing downloaded.

## Foundations

1. **One effect shader include** (`scripts/Visual/vfx_common.gdshaderinc`):
   flipbook frames from `INSTANCE_CUSTOM`, alpha erosion through a painted,
   stepped erosion map, multiplied scrolling noise, a gradient-map ramp for
   colour (one greyscale sheet serves copal, steam and fog), proximity fade,
   and banded lighting (two or three hard steps, the Mignola look) with an
   optional six-way lit path for the smoke sheets.
2. **GPU particles for the ambient.** `Ambient.gd` keeps its job (nearest 40,
   time of day, wind) but runs `GPUParticles3D` systems built from presets
   per effect, thinned by `amount_ratio` with distance, `fixed_fps` 30 (15 for
   slow drift), tight visibility boxes. FireParticles stays for torches.
3. **One wind, one breath.** `Gusts.gd` (built) drives trees, smoke drift,
   petals and fog scroll. A new `Breath.gd` is the caged god's breath: one
   curve (about 7 s, inhale and exhale, now and then a deeper one) every
   occult piece reads.
4. **The Blender effects pipeline** (`tools/vfx/`, headless):
   - `sim_render.py`: Mantaflow smoke and fire baked from parameters,
     rendered orthographic: density under six lights (six-way), emission for
     fire; frames tiled into sheets with `pack_sheet.py` (PNG + JSON).
   - `gn_sprites.py`: Geometry Nodes sheets: sparks and ember streaks, a
     stroke-order sigil pattern (write-on by threshold).
   - Petal and leaf meshes (GLB) for the drift.
   - An OpenVAT bake of the pigeon's wing cycle.

## The effects

**A. Smoke and fire**
- **Copal** (the god, the curanderas, idols, censers): a Mantaflow plume
  that breaks into curls, six-way lit, 32 stepped frames, chunky; a smoke
  stem mesh at the censer with scrolling eroding noise; a small fog pool of
  haze that catches the lamps.
- **Steam** (tamales, atole, the hall): one erosion sheet, gradient-mapped
  near-white, short and quick.
- **Braziers** (night watches, atole corners): flame-tongue meshes
  (multiplied noise, UV distortion, warm ramp) with an emissive Mantaflow fire
  sheet; embers as GPU particles from the coals with ribbon trails, bouncing
  on the setts (heightfield collision) and spitting sparks on impact; a heat
  haze quad; the flame and its light pulse from one noise.
- **Candles** (devotion, wakes, the Line of the Dead, shrines): one
  MultiMesh of flame quads a cluster, each its own phase, one flickering light
  a cluster; a wax-smoke wisp in a gust.

**B. Mist, fog and light**
- **Seeped mist**: a FogVolume per seeped booth or machine with an emissive
  phosphor-green fog shader, its noise scrolling away from the source along the
  ground, pulsing; a few ground-hugging wisps up close.
- **Canal fog** at night: long low FogVolumes along the canal, two octaves of
  slow noise, falling off with height, the lamps' halos in it.
- **Copal haze**: the fog pools above.
- **Lamp shafts and dust**: volumetric fog on at night, the lamps casting
  shafts; dust motes that show only inside a lamp's cone.

**C. Petals, leaves and pigeons**
- **Marigold petals**: small 3D petal meshes (ours) as GPU particles,
  tumbling and fluttering (a particle shader), settling on the ground
  (heightfield collision), carried by the wind; from the offerings, the wakes,
  the flower row.
- **Leaves**: the same with leaf meshes, falling from the trees in gusts.
- **Pigeons**: the wing cycle baked (OpenVAT) on instances; flocks wheel with
  simple steering and land again; the ground flock pecks (built).

**D. The occult set pieces**
- **The god breathes**: `Breath.gd` drives at once a sphere attractor at its
  mouth (inhale pulls copal, petals and dust in; exhale pushes them out), the
  wards' glow (dimming on the inhale), the lamps round the ring (dipping), the
  fog round the cage (swelling), a slight swell of its chest, a low hum.
- **Wards hum**: ward-cage lamps, sigil discs and ward plates pulse
  cyan-white with the hum (emission, a small light), a faint distortion ring
  when the player comes close.
- **Sigils write on**: a stroke-order sigil sheet thresholded so a sigil
  draws itself on and glows, with ribbon trails along its strokes and embers
  rising at its end; the placeholder pattern is ours, the real glyphs are the
  user's to paint.
- **The chains spark**: on a deep exhale the god's chains snap taut and throw
  short ribbon-trailed sparks that bounce on the plinth, with rust dust at the
  links.

## Budgets

At most 4,000-6,000 live particles; at most 40 systems running (the nearest);
turbulence on at most 4 visible systems; at most about 60 large alpha sprites
on screen; 6-10 compact FogVolumes active; sheets 512-1024 px, greyscale where
the gradient map colours them; the dressed frame rate within 10% of the scenes'
(the scenes plan's Task 7 measures both).

## Testing

- Blender pipeline (Python): sheet sizes and frame counts, alpha cut and
  looping, six-way channels distinct, meshes closed (petals and leaves as thin
  solids, ≥ 1 cm), the VAT bake's frame count.
- Godot: the shared include compiles in every material using it; `Breath`
  cycles within its period and its deep breaths come; the attractor's strength
  flips with the breath; the wards' emission follows it; Ambient's systems
  thin with distance and never more than 40 run; petals come to rest on the
  ground; embers bounce (collision) and spark (sub-emitters); fog volumes
  count within budget near the player; the frame rate report.
- Review: a clip (GIF) per group, day and night, sent to the user.

## Order

1. Foundations: the shader include, Breath, Ambient on GPU particles.
2. The Blender pipeline and the smoke and fire sheets.
3. Smoke and fire in the game (copal, steam, braziers, candles).
4. Mist, fog and light.
5. Petals and leaves.
6. Pigeons.
7. The occult set pieces.
8. Clips and stills; then the scenes plan's Task 7 and the final review.

## Open calls for the user

- The sigils' glyphs (a placeholder stroke pattern until they are painted).
- The hum and the breath's sound (the approved packs, by ear).
