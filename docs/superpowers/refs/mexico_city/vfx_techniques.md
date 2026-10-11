# VFX techniques: richer effects, all our own (research, Oct 10 2026)

Techniques and engine/tool docs only. Never asset packs: every sheet, flipbook
and mesh is made by us (Blender sims and renders, procedural drawing). Items
marked [judgement] are engineering calls, not a source's claim.

## Godot 4.5 particles (GPUParticles3D)

- Turbulence bends existing motion (needs gravity, velocity or an attractor);
  GPU-heavy: a few systems on screen at most. https://docs.godotengine.org/en/stable/tutorials/3d/particles/turbulence.html
- 4.2+ process material: directional_velocity, velocity_limit and
  scale_over_velocity curves, alpha/emission over life, amount_ratio (thin a
  running system: LOD, weather). https://godotengine.org/article/progress-report-state-of-particles/
- Attractors (box, sphere, vector field 3D), strength may be negative,
  directionality 1 = a directional wind. https://docs.godotengine.org/en/stable/tutorials/3d/particles/attractors.html
- Collision: heightfield following the camera (cheap "when moved"), SDF baked
  (overhangs). The system's visibility AABB must overlap the collider's.
  https://docs.godotengine.org/en/stable/tutorials/3d/particles/collision.html
- Sub-emitters (constant, at end, at collision; emit_subparticle in particle
  shaders). https://docs.godotengine.org/en/stable/tutorials/3d/particles/subemitters.html
- Trails: RibbonTrailMesh / TubeTrailMesh, width curve, "Y to velocity".
  https://docs.godotengine.org/en/stable/tutorials/3d/particles/trails.html
- Flipbooks: billboard_mode particles + particles_anim_h/v_frames, anim_speed
  > 0; INSTANCE_CUSTOM y = life phase, z = frame in spatial shaders.
- Particle shaders: start()/process(), CUSTOM, USERDATA1-6, COLLIDED,
  ATTRACTOR_FORCE. https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/particle_shader.html
- Animated instances driven by a particle shader (the fish tutorial: pigeons,
  petals). https://docs.godotengine.org/en/stable/tutorials/performance/vertex_animation/controlling_thousands_of_fish.html
- Emission from a mesh's points, normals and colours (embers from coals, mist
  from vents). https://docs.godotengine.org/en/stable/tutorials/3d/particles/complex_shapes.html
- Performance: fixed_fps + interpolate, tight visibility AABB, amount cap,
  proximity fade (soft particles).

## Our own flipbooks from Blender

- Mantaflow gas domains, 64-128 divisions a puff [judgement];
  orthographic camera, transparent film, frames tiled into 4x4 / 8x8 sheets.
  https://docs.blender.org/manual/en/latest/physics/fluid/type/domain/settings.html
- Six-way lighting: the same sim rendered under six lights, packed into two
  RGBA sheets, blended by light direction at runtime (lit smoke at night).
  https://unity.com/blog/engine-platform/realistic-smoke-with-6-way-lighting-in-vfx-graph
  Godot: our own light() function in a spatial shader [design].
- Motion-vector frame blending (Klemen Lozar) for slow hero smoke only; plain
  stepped frames suit the PS2 register. https://www.klemenlozar.com/frame-blending-with-motion-vectors/
- 64-128 px frames, 16-36 frames; greyscale density + erosion, coloured by a
  gradient map in engine (one sheet: copal, steam, fog) [judgement].
- Geometry Nodes for procedural sheets: sigils with a stroke-order gradient
  (write-on by threshold), spark streaks, ember dots.
- OpenVAT (a Blender extension: a tool) bakes animation/sims to textures for
  instanced pigeons, cloth, chains. https://extensions.blender.org/add-ons/openvat/

## Craft

- Shape, timing, colour, value; anticipation, build-up, payoff, settle
  (GDC 2017 VFX Bootcamp, Chamberlain and Keyser). https://youtu.be/-L2JvngkkWw
- Multiplied scrolling noise (Julian Love, Diablo 3, GDC 2013): tex1 * tex2 * 2,
  power-of-two UV octaves, per-particle offsets. https://jangafx.com/insights/diablo-3-vfx-experiments
- Alpha erosion: smoothstep(t, t + feather, a); painted stepped erosion maps
  for a hand-made look. https://vfxdoc.readthedocs.io/en/latest/shaders/alpha-erosion/
- Mesh VFX with scrolling, eroding noise for fire tongues, smoke stems, ward
  rings (RiME). https://simonschreibt.de/gat/stylized-vfx-in-rime/
- Heat haze: screen texture sampled at SCREEN_UV + noise (opaque only).
- Volumetric fog: FogVolume + fog shaders (DENSITY, ALBEDO, EMISSION); compact
  volumes, thick not thin, light fog energy 0 on flickering lights.
  https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html
- One wind for everything (Ghost of Tsushima). https://blog.playstation.com/2021/01/12/how-stunning-visual-effects-bring-ghost-of-tsushima-to-life/

## Per effect

- Copal: Blender plume sim, six-way lit, stepped sheet; a mesh smoke stem with
  scrolling eroding noise near the censer; a small FogVolume haze pool.
- Steam: greyscale erosion sheet, gradient map, upward velocity falling off.
- Brazier: mesh fire tongues (multiplied noise, UV distortion), embers from the
  coals' points with turbulence, ribbon trails, collision, spark sub-emitters;
  heat haze; light and flame share one noise.
- Candles: one MultiMesh of flame quads, one flickering light a cluster.
- Petals and leaves: 3D meshes as the particles' draw pass, tumbling and
  fluttering in a particle shader, settling by heightfield collision, carried
  by the wind.
- Dust motes: shown only inside a lamp's cone; the lamp's shaft from
  volumetric fog.
- Seeped mist: a FogVolume per machine with an emissive phosphor-green fog
  shader, noise scrolling away from the source, pulsing.
- Canal fog: long low FogVolumes, two-octave noise, height falloff.
- Pigeons: OpenVAT wing cycle on instances, simple steering.
- Wards hum; sigils write on; chains spark; the caged god breathes (one breath
  curve driving an attractor, the wards' glow, the lamps and the fog round the
  cage together).

## Budgets [judgement]

<= 4-6k live particles; fixed_fps 30 (15 for slow drifts); turbulence on at
most 3-4 visible systems; ~60 large alpha billboards on screen at most (prefer
meshes and FogVolumes); 6-10 compact FogVolumes; sheets 512-1024 px greyscale.
