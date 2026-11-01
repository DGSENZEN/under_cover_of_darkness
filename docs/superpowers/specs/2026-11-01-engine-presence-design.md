# The Company's engine: presence

An addendum to the station's machinery (docs/superpowers/specs/2026-10-31-station-machinery-design.md, Task 5:
the engine, approved and painted Oct 31 2026). Approved direction from the user, Nov 1 2026.

## Intent

The engine moves, but outside its sound nothing gives it presence: it sits in the hall like an object in a room,
not the thing running the station. It should reach out into the hall: what it gives off (steam, heat, light, power)
should make it read as a hot, working machine feeding the station, from across the hall and up close.

## Goals

Everything it gives off keeps **one beat, its own stroke**: the four cranks (turns 0.25 a second, a quarter turn
apart) give a stroke a second, each crank's piston at the top of its travel. Whatever is seen keeps that clock, so it
reads as one working machine and its cause is plain (world built by its events).

1. **It breathes steam.** On each stroke a puff vents from that crank's cylinder head (the `Fumes` system the candles
   and the lane use). A thin, steady hot plume rises off the dome and thins out under the ceiling.
2. **Heat shimmer.** A small card over the drum and dome bends what is seen through it (screen-texture refraction):
   the coffers and pipes behind it wobble slightly.
3. **Its light breathes and spills.** The core's blue swells with the beat (once a turn, a small lift on each stroke).
   It leaves the drum's windows as soft faked shafts in the hall's haze and lays a soft pool on the floor and the
   ceiling round the engine.
4. **Its power travels.** A faint pulse runs up the tube bundles and out along the cable runs toward the signs and
   booths, on the beat. The hall's neon dips very slightly with each stroke.
5. **It strains when a train draws on the line.** While the lane's train passes, the governor runs faster, the
   warning lamps on the gauge boards flash, and a pressure valve blows off with a burst of steam. Now and then one
   blows off on its own too.
6. **Details, kept very low-key** (the user's word: only noticed up close): oil sheen and the odd drip under the
   cranks; a faint ring of scorched, sooty floor round its foot.

## Non-goals

- No new sounds (the valve's whistle and the strain can be voiced later, from the user's takes).
- No electric arcs (no tesla arcs).
- No real volumetric fog.
- No change to the engine's shape, its moving parts' motion, or the hall's own lamps.

## Anti-goals

- It must not wash the hall in blue, as the blade eyes washed the deck pink. The engine adds to the hall's light;
  the hall stays the hall's.
- The soot, oil and drips must not read as grime or a stain from across the hall.
- No effect may run on a clock of its own, drifting off the engine's beat.
- It must not judder: anything moved in `_process` has physics interpolation off (judder-physics-interpolation).

## Constraints

- Our own effects only: no downloaded VFX, sprites or particle textures (we draw, render or bake them).
- The VFX register: Hellboy × Deadlock × the Mexican, one wind and one breath; Company blue for the core.
- The station's frame cost is still open (machinery Task 8): every effect is cheap (cards, shaders, small particle
  counts), measured in the station's frame-cost views.
- New kit pieces keep the kit gate (closed solids, nothing within 3 cm, cards excluded).
- Failing checks first; in-game stills for review; nothing pushed or merged without the user's word.

## Approaches

- **A. Faked shafts (chosen by the user).** Glowing cone cards out of the drum's windows with a soft-edged additive
  shader (depth-softened against what they touch), shimmer from a refraction card. Cheap, and the light goes exactly
  where it is shaped, which keeps it off the hall. The cost: the shafts do not react to what passes through them.
- **B. Volumetric fog.** Godot's fog lit by the core's light. More physically right, but costly over the whole hall
  (its frame budget is already strained) and hard to keep from turning into a blue glow over everything. Not chosen.

## Decided

- One beat from the cranks' phase, read by everything (steam, core, shafts, pulse, neon dip). Built into the station
  machinery (`maps/metro_station_machinery.gd`, `scripts/Visual/`), tested in `tests/metro_station_test.gd`.
- New parts (valves, warning lamps, drip points) join the engine's kits (`tools/eclipse/station_engine.py`).
- The strain follows the lane's `TrainPass` when the lane is set in (`began` → `peaked` → fade), and an engine of its
  own idle otherwise.
- The neon dip is tiny and stacks with the train's own sag (metro-sound's brownout) when the branches meet.

## Left to the builder

The beat's exact curve, the shafts' and pool's strengths (judged in stills against the anti-goals), the puff sizes,
how often a valve blows off unprompted, the pulse's look on the tubes, the soot ring's radius and darkness (kept
quiet), how the pieces split into tasks.
