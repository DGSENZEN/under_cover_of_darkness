# The astral passages: design

The user, Oct 26 2026: the two pitch-black stretches on the way to the Pasaje should feel "as if we were walking
through the astral plane towards the pasaje". The first pass (stars and nebula painted on the corridor's walls, veils,
floor rings, motes; commit 5eff13b2) "requires a lot more work". The user chose all four of these, in the painterly
occult register.

## Intent and cause

Beyond the market's wards nothing built holds back the Metro's thin dark, the same dark the north circle's rite
opened. The two unbuilt stretches, `pasaje_n` (from the market stairs to the market's north mouth, 21 m) and the
first 22 m of `pasaje_s` beyond its south mouth, are where it shows through.

To walk them is to cross the astral plane on a narrow way toward the market's light. When a stretch is built and
warded later (the south stretch), its passage recedes to what is still unwarded.

## The four parts

1. **A real void.**
   - The corridor's box disappears. Its greybox walls, ceiling and floor are hidden, and the void is drawn behind
     them with real depth.
   - Underfoot, a narrow way of floating lit stones (at least 1.4 m wide: the player is a metre across) winds from
     mouth to mouth. Between and beside the stones the floor falls away into the abyss.
   - Unseen walls at the way's edges keep the walker on it. A branch leads to the `cistern_lane` opening on the north
     passage's west side.
2. **Drifting city fragments.** Pieces of the city float out in the void at many depths, in parallax as you walk,
   turning slowly. A new kit, `astral_fragments`, holds:
   - an arch;
   - a run of stairs;
   - a doorway with its door;
   - a lamp post;
   - a chapel bell;
   - a slab of the Pasaje's tiles coming apart;
   - a market stall's frame.
3. **Presences in the dark.** Things far off that the walker can never reach. No modelled human figures (the shades
   are the city's cut-outs, already approved):
   - a vast feathered serpent's coils passing slowly through the deep;
   - eyes opening and closing in the dark, singly and in clusters;
   - a line of shades walking a way parallel to yours across the void;
   - the soot hand's maker: a giant hand drifting past.
4. **A threshold at each end.**
   - At each mouth of each passage, a membrane across the way, rippling and bending what is seen through it, ringed
     with the city's glyphs (the invented script, a stand-in for the user's).
   - Crossing it: the screen warps for a moment, and inside the passage the world's sounds go dull (a low-pass on the
     World and Ambience buses, eased in and out). No new recorded sounds; those are the user's.

## The look: painterly occult

The Hellboy × Deadlock register the Metro already has:
- **Fragments and presences:** inked shapes, nearly black, with rims of cold teal and marigold catching an unseen
  light, and the city's glyphs flickering on them.
- **The deep:** a painted sky of rich violet, teal and ink, with aurora-like ribbons and marigold threads.
- **Stars:** sparse.
- **The motes and veils:** kept from the first pass, refined to the same register.

No free VFX assets; everything is drawn, modelled or shaded by us.

## How it is built

- **The void:**
  - The passage's hidden walls, ceiling and the floor beside the way are drawn as *windows*. They write a stencil
    mark and the depth at their own plane, so nothing of the map beyond them shows.
  - Everything of the void (the painted sky, the fragments, the presences) is drawn only where a window marked
    (Godot 4.5's stencil, verified on this machine), ignoring the windows' depth, nearest drawn last.
  - So the void stays inside the passage, whatever the map has around it.
- **The way:**
  - The way's stones are ordinary solid kit pieces, painted.
  - The unseen walls are colliders only.
  - The greybox floor's collider stays under the way only.
- **The threshold's warp:** a full-screen effect timed by the crossing.
- **The muffled sound:** the buses' filter, driven by being inside the passage.
- **Cost:** within the Metro's budget, judged as the Pasaje was: the passage's frames against the candle lane's, no
  more than 1.25 times. The void's shaders are unshaded and draw no lights.

## How it is judged

- Tests:
  - the passages stand in their spaces;
  - the way is walkable from mouth to mouth (and to the cistern lane) and nowhere off it;
  - nothing of the map beyond shows through the windows (rays, as PV3);
  - the threshold fires once per crossing;
  - the sound is muffled inside and restored outside;
  - no lights;
  - the frame's cost.
- In-game stills of the north passage first: from the stairs, halfway, looking out into the void, at a threshold.
  The user's word before the south passage is built.

## Round two (the user's word, Oct 26 2026, on the north passage's stills)

"It needs to fit in overall with the art style and feel, it feels a tad jarring"; the gate "needs a bit more work to
feel astral"; the aurora "doesn't feel magical and supernatural enough"; the eyes and the serpent "require more
detail"; the buildings (the fragments) are fine; it "shouldn't feel so rough". The user chose:

- **Sky:** an eclipse in the deep, rivers of the dead, and glyph constellations.
- **Gate:** a ward-gate vortex.

### What changes

- **The colour rule** (the city's effects, [[vfx-aesthetic-and-pipeline]]): marigold for the dead, cyan-white #CFE8F0
  for wards, oxblood #6E1F1A for the gods, phosphor green #7FD36A for the seeped. The deep is ink, with the seeped
  dark's green and oxblood in its depths; the generic violet and teal go. The gate is a ward: cyan-white. The dead's
  rivers and the eyes are marigold.
- **The deep, smoothed:** soft painted gradients, not contour-stepped noise.
- **The eclipse:** a black sun far off, its corona oxblood and marigold in streamers, slowly breathing. The city's
  eclipse, seen from the other side.
- **Rivers of the dead:** slow streams of marigold lights winding through the void toward the market, one passing a
  few metres from the way.
- **Glyph constellations:** stars at the invented script's strokes, joined by faint threads, each glyph lighting in
  turn as the walker goes along the way.
- **The gate:** three rings of the invented script at different depths, turning against each other in cyan-white,
  round a swirling vortex with depth. Its rim is ragged and burning, marigold embers drift off it, and motes spiral
  in.
- **The eyes:** a fibred iris with its limbus, a veined white, a wet glint, fleshy lids that close properly, each set
  in a crack in the dark.
- **The serpent:** feathered: scales, a crest of feathers along its spine, a head with jaws, fangs and a marigold eye,
  its body undulating as it swims.
- **The way:** its stones' tops the Pasaje's own chequered tiles, torn loose; the rims softer.

## Left to the builder

The fragments' and presences' exact placement and drift, the way's winding, the sky's painting, the warp's shape,
all reviewed in stills.
