# Shard effects, round two — design

The user, after a study of Dishonored's and Deadlock's effects: "I feel like you can make the effects much cooler, look at examples from deadlock and dishonored". Claude proposed a redo for each spell, and the user picked the Shard first: "Start with the Shard: wind-up, release, flight and impact, the way you described. Then show me stills and a clip." Lines marked *(Claude's call)* fill in what the proposal left open.

## Why

The first pass (`2026-10-23-gunplay-and-magic-polish-design.md`, part two) gave the Shard one weak beat. The circle is a ring of tiny splinters. The shard is a dark speck lost in the air. Its shatter is barely seen.

Deadlock gives every ability three beats:
- a wind-up you can watch grow in the hand;
- a chunky, hard-edged release;
- an aftermath that stays.

Its projectiles read at 30 m through a bright head and a long tapering trail. Its impacts are a star of spikes, a ring and debris.

Dishonored puts the power in the hand. The hand gestures before the cast, and the cast leaves a residue.

## What gets built

Everything is still black glass (Obsidian), our own meshes and shaders, with no downloaded assets and no figures. The cold glint is `#E6EEF5` (MagicFx.GLINT).

**The obsidian look** *(Claude's call)*
- A lit shader for black glass: the facets are near-black and glossy.
- The fresnel is stepped into hard bands, so each facet flashes a cold edge as it turns.
- That edge still reads at night.

**Wind-up** (the 0.4 s cast, in your view)
- The circle's splinters spiral in. They draw in from 9 cm to 2.5 cm across while the ring spins up, and they turn from pointing out to pointing at the middle.
- The Obsidian circle floats up beside the fingers, square to the aim, where the hand does not hide it *(Claude's call after the first stills: in front of the palm it sat behind the hand)*.
- A glass spearhead grows in the middle of the circle, leaning up and out toward the crosshair so its length shows, from a sliver to full size, and turns slowly.
- The hand draws back a little as the cast builds, and trembles more and more *(Claude's call: 1.5 mm at the end)*.

**Release** (the moment it is cast)
- The spearhead leaves the circle: the in-hand one is gone and the flying one takes over.
- A burst of black flakes is flung forward from the palm, and a refraction ring swells at the palm (the world bends through it). Both last about 0.12 s.
- The hand pushes forward and comes back.
- A brief cold light at the palm lights the room for a moment.
- The camera gets a small kick.

**Flight**
- The shard becomes a real spearhead, about 32 cm long, spinning, in the obsidian look.
- A trail follows it: a dark smear of bent light with a thin cold line down its middle.
- The trail fades from its tail over about 0.18 s, so at the shard's speed it draws a line from your hand to what it hits.
- The trail outlives the shard by that fade *(Claude's call: no more Fx.streak)*.

**Impact on the world**
- A star of glass spikes bursts out of the surface around the normal, about 7 of them, 25–55 cm long, grown in 0.05 s. *(Claude's call after the first stills: at 15–40 cm they were dots at 6 m.)*
- They stay about 3 s, then crumble into falling flakes over 0.4 s.
- A ring of black glass dust spreads on the surface.
- The existing splinters fly off, plus dust and a brief cold light.

**Impact on a man**
- The spearhead sticks in where it struck and goes where he goes. In a ragdoll, it goes with the limb.
- It stays about 6 s *(Claude's call)*.

**Unchanged**
- The Ward turning a shard aside.
- Damage and limb severing.
- The sounds.

**Effects off** (Fx.enabled false, as in tests and captures): none of this is made, as before.

## Checks

A new headless suite, `tests/shard_fx_test`, covers:
- the wind-up's growth and the splinters drawing in;
- the release burst, ring and light, and how fast they go;
- the flying spearhead's size, and the trail from the hand to the hit;
- the impact spikes: how many, their angles and how long they stay, the crumble, and the ring;
- the shard stuck in a man;
- nothing made with effects off, and everything gone afterwards.

Stills and a clip go to the user, close and far, lit and dark.
