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

## Polish: it reads as protection

After seeing the round-two Ward the user said: "I feel like you can polish the ward to feel much cooler and protective with the effect itself, it's already a good foundation just requires a bit more polish so it reads as a protective ward."

The plumes alone read as a cloud round you, not a barrier. Everything below is *(Claude's call)*.

- **The shell:** a faint shell of copal smoke, exactly the sphere that stops shots (radius 1 m about the Ward's middle), so you see the protection's real shape.
  - It is nearly clear face on and brightest where it turns away (a fresnel rim). From inside, its edge glows round the borders of your view and the middle stays clear.
  - Its smoke flows round it.
  - It fills up from the floor as the pour runs round, and fades as the wall sinks.
- **The copal ring:** a burning line of copal on the floor at the wall's foot, in ember red-orange.
  - It runs round with the skirt.
  - At the end it is left in the world as a dim ash ring for a few seconds, then gone.
- **Circling bands:** three bands of brighter smoke circle the shell at different heights, so the spell visibly runs.
- **A stopped shot strikes the shell:** it flares where it hit, and a ripple runs over the dome from there. This replaces the flat ripple ring of round two.
  - The whole shell brightens for a moment.
  - A deep thud plays under the old whoosh.
- **Inside it the world is muffled:** the world's sounds go dull, as if through smoke (a low-pass of about 2.5 kHz on the world buses, through the same filter the hurt muffle uses). The muffle eases in and out with the Ward. Your own sounds and the score are untouched.
- **Effects off:** the shell, the ring, the bands and the ash are not made. The muffle is sound, so it stays.

## The written circle

The user, on the polished Ward: "Maybe make the ward spawn a magic circle with the new magic language alphabet we did?"

That alphabet is the invented script from the Librarian's shop: forty glyphs on U+E000 on, baked into a distance-field atlas by `tools/textures/library_glyphs.py` on metro-standard. Its atlas, character map and `LibraryGlyphs.gd` are copied here byte for byte, so the two branches merge cleanly. The look below is *(Claude's call)*.

- **On the floor:** a circle written in that script, inside the burning copal ring, its glyphs (17 cm, 26 places round) flat on the floor and reading round it.
  - Words of two to seven glyphs with gaps between, always the same text for a given seed.
  - Drawn in the ward colour with a dark edge, from the atlas's distance field, so they stay sharp.
  - A thin ward-white ring inside them closes the circle.
  - The glyphs are written in round from the front as the pour runs round. They turn slowly against the wall, brighten when a shot is stopped, and fade as the wall sinks.
- **In the hand:** while the Ward is cast, a small ring of the same script turns round the copal circle in your view. The circle in your hand becomes the one on the floor.
- **From inside:** the shell and the bands are faint, so your view stays clear. Seen from outside they keep their strength.
- **Effects off:** no written circle on the floor. The ring in the hand is part of the casting circle, and shows as the circle always has.
