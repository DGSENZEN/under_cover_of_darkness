# The Burst: a wave up through the floor

Short design. First of a round: the user asked for "effects to the enemies affected by our spells" and for spells that "feel better, weightier, and just generally look good and feel good". They named the Burst as the weakest. The Shard, Ward, Blink and Empower follow, each judged in the game, the same way.

## Why

Today (`scripts/Magic/ObsidianBurst.gd`) it is a wire-thin ring, a few flat needles and a one-frame flash. Everything in reach is hurt on the same frame, then flashes red and slides. Nothing shows it was hit by glass, and nothing shows the spell travelling.

## What it is

The user's pick: **glass erupting up from the floor**, and enemies thrown up and back. The rest is Claude's proposal, which the user accepted ("Yes, that's it").

1. **Wind-up (0.3 s, as now):** the casting hand rises and clenches as the circle closes; hairline cracks with dark glass under them creep across the floor round your feet.
2. **Release:** the hand slams down, with a camera thump, a brief freeze, and a deep crack and rumble. Anything on you is thrown off at once: it stays the panic button.
3. **The wave:** thick faceted obsidian spikes tear up through the floor in rings, out to 5.5 m, in about half a second. Tall near you, shorter toward the edge. Not through walls.
4. **On the enemies:** each is hit when the wave reaches it, nearest first. It is knocked up and back, tumbling, with shards of the glass stuck in it until it dies or the spell ends. Ánimas spill their sick fire and ash from the wound, not blood. Eyes crack and bleed. A kill goes into the ánima deaths already built.
5. **Aftermath:** the spikes stand a moment, then crack and collapse one by one into glinting rubble and dust. A scar stays on the floor a few seconds.

## Not changing

- Damage (35), reach (5.5 m), cost (40), cast time (0.3 s), and what is thrown off. The fights are tuned to these. The only change to play is that far enemies are hit up to half a second later.
- The spikes do not block anyone or hurt on contact. A real wall would change how fights play: a separate decision, if wanted.
- The other spells, until the Burst has been judged in the gym.

## Approaches

- **Modelled in Blender (picked):** about five thick faceted spikes and a set of broken chunks, modelled and painted, wearing the Shard's approved black glass look. The game grows them from the floor, cracks them and swaps each for its chunks. More work up front, real shapes, and it can move to a baked collapse later if the crumble disappoints.
- Built in code: fastest, but that is what made the current needles.
- Simulated shatter baked in Blender: the most convincing collapse, by far the most work, heavier with a crowd, and it only pays off in the last half second.

## Left to the builder

- The spikes get a picture for the user before the wave is built ([[models-one-by-one-supervised]]).
- Sounds come from the approved packs; anything missing goes on `docs/superpowers/refs/hunt/sounds_needed.md`.
- Spikes drawn in one or a few MultiMeshes, so a cast in a full wave stays cheap; measure it with a full wave.
- Failing checks first; judged in stills and the gym, close up.
- The torso is still a stand-in, so it reacts as the code allows until its model exists.
