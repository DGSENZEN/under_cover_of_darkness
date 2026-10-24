# Ward effects, round two — design

After Blink's redo the user said: "Blink works. Do the Ward next the same way: wind-up, the smoke pouring out into the ring, stopped shots, and the end. Then show me stills and a clip."

It follows the method of the Shard and Blink notes (`2026-10-23-shard-effects-design.md`, `2026-10-23-blink-effects-design.md`). It keeps the Ward's approved stuff: mesh smoke in the ward colour `#CFE8F0` (the user: "use mesh smoke for the Ward"). The cause stays burning copal resin. Lines marked *(Claude's call)* fill in what the request left open.

## Unchanged

- What the Ward does: a ring 1 m round you for 4 s that stops shots and spells from outside, not blades.
- Its cost and cast time, and its twelve plumes, their look and their turning.
- The bulge and the thinning where a shot stops.

## Wind-up (the 0.4 s cast, in your view)

- **Where the circle sits:** the copal circle moves up beside the fingers, where Obsidian's now sits, because in front of the palm the hand hid it.
- **Smoke from the palm:** two curls of ward smoke rise from the middle of the circle, growing taller as the cast builds.
- **Embers in the palm:** a few embers of burning copal glow brighter in the middle. They are a deep ember red-orange, not marigold (marigold is the dead's colour) *(Claude's call)*.

## The pour (the moment it is cast)

- **Down from the hand:** a stream of smoke pours from your hand down to the floor ahead of you.
- **Round the floor:** the smoke runs along the floor both ways round the ring as a low rolling skirt, from the front to the back in about 0.35 s.
- **Up into the wall:** each plume rises where the skirt has reached it, front first, back last, instead of all twelve fading in together.
- **The skirt stays** at the foot of the wall while the Ward stands.

## Standing

- **Embers in the smoke:** a dozen embers of burning copal drift up inside it, flickering. That is the smoke's cause, seen.

## Stopped shots

- **Where it was stopped:** a bright ward-white puncture flashes, with a brief light in the ward colour.
- **Through the wall:** a ripple runs out through the smoke from that point, and the existing bulge and thinning stay.
- **What was stopped falls to the floor:**
  - a ball: flattened lead;
  - an arrow: the arrow, dead;
  - a shard: its black glass in flakes.

  Each lies a few seconds and is gone *(Claude's call: 4 s)*.
- **Who tells the Ward what it stopped:** the revolver, the arrow and the shard each pass their kind on. Today only arrows reach your Ward, because the guards don't shoot guns yet.

## The end

- **The wall sinks:** the plumes sink toward the floor as they are eaten away.
- **The smoke drains away:** it runs off across the floor in a widening ring, left where you stood, while the embers go out.

## Effects off

With Fx.enabled false, the Ward's own plumes still show (they are the spell), but none of the above is made: the hand smoke and embers, the pour, the skirt, the drifting embers, the puncture, the ripple, the dropped things, the drain.

## Checks

A new headless suite, `tests/ward_fx_test`, covers:
- the wind-up's smoke growing and its embers brightening;
- the pour stream, front plumes rising before the back ones, the skirt;
- the embers inside the ring, rising;
- a stopped ball's puncture, ripple and the flattened ball on the floor;
- an arrow falling;
- the drain left on the floor at the end;
- nothing with effects off, and everything gone afterwards.

Stills and clips go to the user, lit and dark, from your eyes and from outside.
