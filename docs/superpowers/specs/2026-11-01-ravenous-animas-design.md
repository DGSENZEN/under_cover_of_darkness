# Ravenous ánimas: the second hunt enemy

The next monster after the floating eye, with a new item and a new spell, tested alone before any mixing. It builds on `docs/superpowers/specs/2026-11-01-hunt-combat-design.md` and the working eye slice on branch `hunt-combat`. Where this document differs from that spec's "Aggressive ánimas" section, this one wins.

"My call" marks what the user has not decided. Every number is a starting value to tune in play.

## Why

The user's roadmap: "another type of enemy, and another type of item, this will allow us to truly test each enemy in isolation and then start mixing them."

The eye is a threat at range: it curses you, so you aim, keep your distance and spend an egg. This enemy must ask for something different. It rushes you, gets on you and feeds.

In the user's words:
- "when the animas get on me, it should feel like my willpower and life getting drained away"
- "They are ravenous lost souls looking to leech off life-force now"
- "I can gun-whip them, or use the copal items or cast the ward to kick them off"
- "look more withered and aggressive, they need to feel different from what already exists"
- "We also need a spell we can create that is AoE and helps when being crowded"
- On the models: "a mix of 1 and 3, with the withered torso being dragged by it's arms or withered hands and a face, or just withered hungry hands."

## Goals

- Being latched on feels like being drained: your willpower (magic) and your life bleed away, and you can see and hear it happening.
- A crowd is dangerous, and you have real answers to it.
- Knocking one off feels physical and earned.
- The three forms read differently from each other at fight distance, and from the Metro's ánimas at a glance.
- The fight can be played and judged alone, with no eyes in it.

## Not in this round

- Mixing with eyes. That comes after the user has judged this fight alone.
- The spec's variants (beggar, tethered lurker, choir) and the copal-smoked coat.
- Revenants, spectres, skill trees.
- Any change to the Metro's ánimas (`scripts/Visual/Animas.gd`). They stay as they are.

## Must not happen

- It must not look like the Metro's begging hands with a new colour.
- No stun-lock: you can always move a little, shoot, whip and cast while one is on you.
- The drain effect must not cover your view. The curse's flesh already does that, and when the two are mixed later the player still has to see.
- No odd sawed-off topology, no open cuts or planar slices, on anything (`monsters-look-and-feel-good`). Where a body ends it ends in fire or closed form, not a cut.
- No downloaded VFX. Effects are ours, in the mesh-and-shader language the user approved on the Shard and the shot.

## Cause in the world

They are the same souls as the Metro's ánimas. Those beg for candles and prayers. These are the ones nobody lit a candle for, who have gone past begging: starved, and now drinking from the living directly. The fire that crowned them has nearly gone out. *(My call, following `world-built-by-its-events`.)*

## How to build the look: approaches

The user was offered three and chose a mix of two:

1. **Hungrier hands**, reusing `Animas.gd`. Fastest, no new model, but it would still read as the Metro's ánimas.
2. **A full withered body** on the Quaternius guards. The most physical, but it crowds the revenants' space, and human figures are where earlier models went worst.
3. **A withered torso dragged by its arms**, a new model through the eye's Blender pipeline. The strongest silhouette, the most modelling work.

**Chosen: a mix of 1 and 3, as three forms of one kind.** Each is a new model through the eye's pipeline (`tools/monsters/`, closed solids, painted light, ink lines, the world's brush sheet), none of them reusing the Metro's hand meshes.

## The three forms

All are withered: skin shrunk onto bone, hooked overlong fingers, ash-grey and liver with one sick accent. Their fire is burnt out, guttering low and dirty with only a trace of the Metro's chartreuse. Each has its own silhouette at fight distance. *(The look is my call, for the user to pick from a silhouette sheet, as with the eye's.)*

The roles below are *my call*.

| Form | What it is | How it moves | Health | Grip |
|---|---|---|---|---|
| **Hands** | Just withered hungry hands, scuttling on their fingers | Fast, low, darting; comes in numbers | 40 | Weak: drains a little |
| **Face** | Withered hands and a face: a sunken face that is mostly open mouth, two hands reaching ahead of it, nothing else | Floats at chest height, surges forward, stops to lunge | 70 | Middling |
| **Torso** | A starved torso dragged by its arms: ribs, shoulders, a sunken head; below the ribs only burnt-out fire | Slow, hand over hand, then a long telegraphed lunge across the floor | 130 | Strong: a single whip is not enough to break it |

Models are built one at a time and reviewed by the user before the next (`models-one-by-one-supervised`), in this order: hands, face, torso. Each is judged in the game, not in Blender renders.

## What they do

1. **They come up:** out of drains and wall grilles in the gym, with a rasping voice.
2. **They rush:** on the navmesh (the face flies over it, keeping its distance from the floor), spreading out so they arrive from more than one side.
3. **They tell you:** a short wind-up before the leap, readable at a glance. A dodge makes it miss. A hit from anything but lead breaks the leap, with the eye's opening rule: triple damage, weak, exposed, power back. Lead passes through even then. *(My call: `_is_opening` for this kind ignores lead, so aim pays but only with the right round.)*
4. **They latch:** a leap that connects puts it on you. A dodge at the right moment makes it miss. Up to **three** can be on you at once; the rest wait, circling.
5. **They feed** until knocked off or killed. They never have enough and never leave: left alone, they kill you. *(My call: a sated one that left would let a player clear a wave by doing nothing.)*
6. **Knocked off,** an ánima is thrown clear, stunned and exposed (`Monster.is_exposed`, double damage) for 1.5 s. Every answer below that frees you does this; "let go" and "thrown off" are the same thing.

## Being drained

This is the heart of the fight. While any are on you:

- **Power drains first:** 5 a second for each hands, 8 for each face, 12 for each torso. Willpower goes.
- **Life goes with it:** 1.5, 2.5 and 4 health a second. Your current shield does not refill while one is on you, and a lost shield stays lost, as now.
- **With no power left,** the life drain doubles.
- **You slow down:** pace ×0.8 with one on you, ×0.65 with two, ×0.5 with three. You can still move, shoot, whip and cast.
- **It fattens on you** *(my call)*: the more it has drunk, the brighter its fire and the fuller its withered flesh. Killing one that has fed gives back half of what it took from your power, which makes turning on it worth more than running.

**How it feels on screen** *(my call, for the user to correct; the user judged the last screen effect by eye, so expect rounds)*:
- Its withered hands reach into the first-person view from the side it is on, and clutch: at your collar and shoulder, never over the crosshair.
- Colour bleeds out of the world from the edges in, more with each one on you, toward a cold grey. The middle of the view stays clear and readable.
- The drain has a direction: thin threads of your own warm colour pulled from the edge of the view toward whatever is holding you, so you can see where to whip.
- The power arc and the shields visibly sink, with a slow pulse.
- Sound: the world dulls, and a rasping drinking sound and a slowing heartbeat rise (`Sfx`, the Souls bus, `monster_04`'s kin).
- Knocked free: colour floods back at once. That release is the reward, and it has to feel good.

It uses a separate screen shader from the evil eye (`scripts/UI/evil_eye_view.gdshader`), built so the two can show together later.

## Getting them off

From the user: gun-whip, copal items, or the Ward. *(A dodge does not break a latch, only avoids one. My call, from the user's list leaving it out.)* The new spell does too.

| Answer | What it does |
|---|---|
| **Gun-whip** | The free one, always ready. Throws off the one you aim at, or the nearest one on you. Against a torso, the first whip loosens it and the second throws it off. Costs nothing, but only clears one at a time. |
| **Copal round** | Throws off the one it hits, and only that one. It counts as weak: exposed, and power back. |
| **Copal cloud** | The cloud bursts where the round lands, as now. Inside it they are smoked: slowed, cannot latch, and any already on you drain at half. It does not throw them off *(my call: otherwise one round frees you from all three and the whip, Ward and burst have no job)*. |
| **Doorway ward** (new item) | Laying it throws off any on you and stops the rest crossing. |
| **The Ward** | Cast, it throws off everything on you, and they cannot enter it (`Ward.covers`). Expensive, and a drained player may not have the power, which is the bind. |
| **New spell** | Throws off everything and hurts everything near. See below. |

**Blink** tears you free of everything on you for its usual 20 power, but they are not thrown, stunned or hurt, and they come straight after you. It is an escape, not an answer. *(My call.)* Mantling and climbing still work with one on you; it holds on and goes on draining.

**What each does to them** *(my call; a ball does about 50)*:

| Source | Scale | Counts as | Frees you? |
|---|---|---|---|
| Lead | 0.15 | Resisted. Seen to pass through (`GunFx.impact`, a new read beside `glance` and `burst`) | No |
| Copal | 1.0 | Weak | The one it hits |
| Shell (`shot`) | 0.5 | Resisted, so a shell is a poor answer, not the obvious one | No |
| Shard | 1.0 | Plain | No |
| Whip | as it does now | Plain. Physical, and it counts *(the user's list says so)* | The one it hits |
| Burst (`obsidian`) | 1.0 | Plain | All |

So a copal ball kills hands outright, takes two for a face and three for a torso. Killing one on you frees you from that one.

## The new spell: a crowd answer

From the user: "AoE and helps when being crowded." The rest is *my call*.

- **What it is:** an **obsidian burst**. Splinters of black glass drawn in round your hand, then flung out in a ring all round you. Obsidian rather than copal because copal already has the Ward, and it should help against any crowd, not only spirits.
- **Effect:** 35 damage to everything within **5.5 m** in line of sight (a new source, `obsidian`, so eyes take 1.5×), thrown hard outward (`blast` push), every latch broken. Stops at walls.
- **Key and cost:** key **4**, cost **40** power, hand tier, cast time **0.3 s**, the quickest non-innate cast. It can be cast with one on you, so long as you have the power. Aiming down the sights lets go of the aim, as other hand spells do.
- **Cost of it:** with drains eating your power, waiting too long means you can no longer afford your best answer. That is the tempo of the fight.
- **Look, in three beats** (what the user liked on Shard and Blink), in the Shard's approved obsidian look (`vfx_obsidian.gdshader`):
  1. Wind-up: splinters drawn in round the left hand.
  2. Release: a short hit-stop, the ring flung out across the floor at knee to chest height.
  3. Aftermath: a ring of black glass splinters stuck in the floor, fading in a few seconds.
- **Stand-in name:** `burst`. The user writes all words.

## The new item: a copal doorway ward

- **What it is:** a line of copal smoke and ash drawn on the floor, 5 m long, square to where you look, in front of you. It lasts **20 s**. *(My call on all of it.)*
- **Effect:** ánimas cannot cross it, and go round if they can. In a doorway, that seals it. Laying it throws off any on you. Eyes ignore it.
- **Use:** `use_time` 0.6 s, with the hand at the floor (a stand-in pose for `poses_needed.md`). You carry 2, by the same rules as the egg (`PrepItems`, `Loadout`, the kit table).
- **Second item key** *(my call)*: **B**, since V is the first packed item. `Loadout.use_item(index)` already takes an index.

## The ánima gym

A new map, `maps/anima_gym.tscn`, on the pattern of `maps/hunt_gym`: the same kit room and clue, a dark yard, F5 to restart, F6 for the next wave. It differs in having drains and wall grilles to spawn from, a doorway and a pinch to use the ward in, and room to be crowded in. *(A separate map rather than a mode of the hunt gym, so the eye fight stays as it is. My call.)*

Waves *(my call)*:
1. Five hands.
2. Two faces and four hands.
3. A torso, two faces and four hands.

The kit table offers lead, copal, and the doorway ward. No eggs, since no eyes.

## How monsters are made here

A new kind, `&"anima"`, with three forms as data in `Bestiary`, on `Monster.gd` as the eye is. New monsters extend by path, without `class_name`. New statuses go through `Statuses.gd`, and what they cost goes through a small node on the player, as `EvilEyeCurse.gd` does. `take_hit`'s shared contract stays.

## What success looks like

The user plays the ánima gym and says it feels like being drained, the fight is tense in a different way from the eyes, and the withered forms look good and don't read as the Metro's ánimas.

## Left to the builder

- How a latched ánima is drawn: world model parked close to the camera, viewmodel-layer hands, or both, so long as the hands read in view and the crosshair stays clear.
- Crawling movement and animation for hands and torso: procedural, as the eye's body is, or clips.
- Tuning every number above.
- File layout, within the repo's conventions.
- Sounds: use the existing packs and list what is missing in `docs/superpowers/refs/hunt/sounds_needed.md`. The user sources what is missing and writes any words.
