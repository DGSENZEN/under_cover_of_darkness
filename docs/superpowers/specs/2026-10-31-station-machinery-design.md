# The station's machinery: Deadlock light and the Company's engine

Oct 31 2026. Project 1 of 3 in the Metro's new register (below). Approved direction from the conversation of Oct 31;
references are the user's Deadlock frames (listed at the end). It replaces Task 9 of the station plan
(`docs/superpowers/plans/2026-10-30-metro-station.md`, the model of Tenochtitlan, dropped by the user).

## Intent

The user likes the station as built (shell, track, taquillas, turnstile banks) but wants it far more detailed and
alive, in two registers:

- **The Light Company's machinery, Deadlock's way,** at the station's centre pieces: real neon (symbol signs too),
  crackling tesla arcs, clockwork, big brass tubes, astral energy lamps.
- **The people's occult** in the walkways where the crowd gathers (corridors, stairs, the candle lane).
- **Both at once** in the market and its alleys (the Pasaje, its side alleys and service passages).

Why it splits that way (Claude's proposal, accepted): the Company owns the official station, so its machine rules the
hall; the people's faith lives in the passages they crowd; the market is where the two meet. Every effect has a cause
in the world's events (the rule: no magic sprinkled in). The machinery is the Company's power and its wards made
visible, as its ward lamps, the turnstiles' ward eyes and tally dials already are.

## The program (three projects, in this order)

1. **This one: the machinery and the station's centre.** The station relit in Deadlock's key; the reusable neon and
   tesla effects; the first arc runs; the Company's engine at the hall's middle, built with the user; the taquillas
   and turnstiles retrofitted to it.
2. **The occult walkways:** the corridors, the stairs, the candle lane reworked (the user: "reworked in the new
   change").
3. **The market and its alleys:** the Pasaje reworked where the two registers meet; last, since it needs both.

After project 1 the station plan's remaining hero pieces (Tasks 10–14: the shrine, the benches, the relief cabin,
the cracked vault, the vendors' stands) are built in the new register; its Tasks 15–16 (the crowd, the views) fold
into whichever project owns each space. Each project gets its own design and plan.

## Goals (project 1)

1. **The station relit in Deadlock's key** (the user: "yes" to giving up the even fluorescent grid): warm amber haze
   against cold electric-blue lamps, with neon accents. Every image the user gave sets warm haze against blue
   lamps; that contrast is the goal, not any one image's colours.
2. **Real neon:** tubes that light what is around them (not emissive only), on the existing `NeonSign` / `Neon`
   system. Neon signs carry symbols, not words: Deadlock's illustrated blade signs and crowned verticals as reference
   (the saxophone, the soda bottle, the crowned "Succubus"), ours with our own symbols.
3. **Real tesla arcs:** a reusable effect: a jagged, moving ribbon of light along a run, leaping, flickering the light
   around it, throwing sparks. Two uses: an arc riding a cable run strung through space (the Broadway lane's arch, the
   cyan arc down the street), and an arc leaping between two terminals (the patron's hall).
4. **The first arc runs:** brass cable runs strung across the hall from the engine to what it powers (the turnstile
   banks, the taquillas' lamps) and down toward the platforms, arcs riding them.
5. **The Company's engine at the hall's middle** (the patron's hall image as reference): bundles of big brass tubes
   rising from a heavy base into the coffered ceiling; clusters of glowing gauge faces hung on them (our 1920s: glass
   dials and oscillograph faces showing occult diagrams, not CRTs); clockwork showing in its base; an arc leaping
   between the tube tops; a ring inlaid in the floor round it. Built with the user one piece at a time, judged in
   the new light.
6. **Astral energy lamps:** the Company's ward lamps taken further (the Atlas's purple armillary as reference): a
   glowing core in rings, glyphs drifting round it, low coloured haze at its foot. At least one on the engine; others
   where the user places them from stills.
7. **The taquillas and turnstile banks retrofitted:** fed by the cable runs, their ward eyes and dials glowing, the
   Company's blue on them; what else is decided with the user from stills.

## Non-goals

- The walkways and the market (projects 2 and 3).
- The station's other hero pieces (Tasks 10–14), built after this project.
- Any new sound: the arcs and neon stay silent until the user's sourced recordings come (the standing rule).
- Rendering cost: the user, Oct 31: "I don't mind cost, we can optimize rendering later". The station plan's light
  budget (S6c: at most 40 shadowless lights, 2 shadowed) and its frame-cost gate (1.25× the candle lane) are suspended
  for this project and become an optimisation pass later. Measure and report the frame cost; do not gate on it.
- A copy of any Deadlock frame (the reference-not-imitate rule): the shapes and light are studied, never traced.

## Anti-goals

- **Surfaces in Deadlock's smooth gradients.** The user: "make it fit our own art style for surfaces". Surfaces stay
  ours: painted atlases through the layered painter and the user's brush sheets, painterly. Only the light and the
  shape language move toward Deadlock.
- Effects with no cause: every arc runs from something that makes it to something that uses it.
- Even spacing (scenes, not sprinkles), modelled human figures, z-fighting, layered faces, judder (M20), anything
  presented as finished with a visible fault.
- Words: every sign face, dial face and the Company emblem stay blank or in a stand-in script; the user writes words.

## Constraints (unchanged from the station's spec)

- The kit standard: solid closed meshes, no layered faces within 3 cm, no shared atlas texels, budgets per piece,
  painted with the underground recipes; the user's vertex edits kept through rebuilds.
- Hero pieces with the user, one at a time, shape signed off before paint; in-game stills through the player's eye;
  the next piece waits for the user's word. Never merge or push without it.
- No free VFX assets: every arc, spark and glow texture is ours (drawn, rendered or baked).
- The station's walks: passages at least 1.1 m clear, nothing under 2.4 m over a walk (cable runs and arcs included),
  the MP-68's envelope over the tracks kept clear.
- Anything moved in `_process` (arcs, flicker, drifting glyphs) draws uninterpolated (M20).
- The approved looks' suites keep passing (the Pasaje's, the candle lane's) until their own projects rework them.

## Approaches (the user chose 1)

1. **Light first, then the engine** (chosen). Relight the station on the pieces already built, build the neon and
   tesla effects as reusable pieces, string the first arc runs; then the engine with the user, judged in its real
   light; then the retrofit. You see the mood change soonest and every model after is judged in the light it lives
   in; the cost is relighting twice if the engine later wants a different key.
2. Engine first, light after: the hero piece sooner, but judged in a light it will not keep (how the cold cast fooled
   the taquillas' first look).
3. A machine kit in a test room first: the most reusable, slowest to anything in context, and against building one
   model at a time with the user.

## Decided in the conversation

- The Tenochtitlan model is dropped; the engine takes the hall's middle.
- Neon and tesla light for real; cost is optimised later.
- Neon signs carry symbols. Claude's call: our own symbols (a marigold, an eye, a skull, a serpent, a hand) and the
  invented script (`tools/textures/library_glyphs.py`) or the ward-tongue's roots as stand-ins, all for the user to
  replace.
- Surfaces: our own painterly style.
- Light: warm haze against cold blue lamps, neon accents.
- **The engine fits inside the hall as built** (the user, Oct 31): no ceiling opened, no slab cut, the track under it
  untouched. It is a squat, heavy machine whose tube bundles run up into the coffered ceiling and on out of sight;
  details leave the rest to interpretation (the user: "we can have details to leave things towards interpretation"):
  where the tubes go, what the dials read, what the engine is doing is hinted, never shown whole.

## Claude's calls from the builder check (for the user to check)

- **Where project 1 reaches:** the hall, both platforms and the track get the new light key, the cable runs and the
  Company's machinery (the platforms are the Company's too). The station's own stairwells (`stairs_n`, `stairs_s`)
  get the new light key now, so no cold space sits between two warm ones; their occult dressing is project 2's ("the
  stairs" there means every stair people crowd, these included). Cable runs over the platforms keep 2.4 m over the
  walks and stay out of the MP-68's envelope (S4c, M24 apply).
- **Which neon signs:** the station's own signs become neon with symbols: the hanging direction signs and the
  Company's marks, plus the Company's own crowned blade signs where its power is shown (the engine, the banks). Each
  carries the Company's cause. Commercial blade signs, illustrated boards and marquees are the market's (project 3).
- **All look, no play:** the arcs do not hurt, nothing is doused or cut, the network engine → runs → pieces is visual.
  The new lights are real lights, so the lightgem and the guards' sight read them as they read any light; nothing
  more. Dimming as a train passes waits for the train (build 2).
- **The crowd and the views:** the hall's crowd stays with the station plan's crowd task, after the hero pieces; the
  engine's footprint leaves room for crowd routes round it. This project's own view check replaces SV2's look at the
  dropped vitrine with the engine.

## Left to the builder (Claude's calls, to be shown to the user in stills)

- How the warm haze is made where the Metro has one environment (the station's own fog volumes, its own grade), so
  the rest of the Metro keeps its look until its project.
- What becomes of the 1969 fluorescent fittings in the new key (dimmed, warmed, some dead, replaced by the Company's
  lamps), decided from stills.
- The arc effect's build (a regenerated ribbon mesh, its flicker light, its sparks), within the rules above.
- The engine's exact footprint at the hall's middle, clear of every walk (the stairs' heads, the market stairs, the
  lanes' approaches).
- Where the cable runs go, each from the engine to something it powers.

## References (the user's, Oct 31)

Deadlock's Times Square, Uptown, Downtown, the York stock exchange, the plaza, the patron's hall and the three-lane
update image (`cdn.deadlock.wiki`: TimesSquare_blue.jpeg, Uptown_blue.jpg, Downtown_blue.jpeg, York_stock.jpg,
Plaza.jpg, 3_lane_update.jpg); the user named the Broadway lane and the York lane. What each gives:

- The patron's hall: the engine (tube bundles to the ceiling, gauge clusters, an arc between tube tops, a floor ring).
- Broadway, Downtown: arcs riding brass cable runs strung through space.
- Times Square, Uptown, the plaza: blade signs, crowned verticals, illustrated boards, bulb-lit marquees.
- The York stock exchange: astral light (a glowing armillary held by a statue, glyphs, coloured haze at the ground).
- All of them: warm amber haze against cold blue lamps.
