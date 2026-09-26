# Climbing and Swimming: Design

**Date:** 2026-09-26
**Status:** built and tested (`tests/climb_swim_test`, L1–L2, G1–G10, W1–W5; `tests/gym_test` G8); this document awaits the user's review. Section 4.7 came from playing it: in bay 10 the guards did not follow you up the ladder.

## 1. Goal

The user asked: "Can you make it so the NPCs can climb and swim?"

Before this, a guard could only walk the navmesh. You up on a crate stack, a wall top, a tower or across a gap were out of his reach: he stood below you and taunted. There was no water in the game at all. So this adds:

- **Guards climbing:** up onto what they can reach, down off it (a hop, or from higher up, hanging from the edge and dropping), across gaps, and up and down ladders and ropes.
- **Water:** for everyone. Deep water is swum and shallow water is waded. It splashes, loose things float, and under the surface you are hard to see.
- **Swimming:** you and the guards. They go in after you, swim after you, and climb out after you.

## 2. Decisions

| Question | Decision |
|---|---|
| How a guard knows where he can climb | **Navigation links made after every bake** (`NavLinks.gd`), found by walking the edges of the baked navmesh and looking out from each, plus one per ladder or rope (`ClimbVolume`). No hand-placed links: every level with a `NavBaker` gets them (`traversal_links` turns it off). |
| How a guard crosses one | **A scripted move** (`GuardClimb.gd`) when his path reaches the link (`NavigationAgent3D.link_reached`). It is split into a few legs (up the wall, over the edge, and so on), each moving his whole body along a line, a fall or an arc. While he is on it nothing else moves him, and he neither guards nor strikes. A blow, a kick, a knockdown or fire takes him off it, and off a wall or ladder he falls. |
| What water is | **One `WaterVolume` script for everyone**: a box whose top is the surface. It answers depth questions (`deep_at`, `depth_of`, `floor_under`), makes splashes, floats loose things and holds the murk. |
| Where a guard swims | **Deep water is cut out of the land navmesh and baked as a region of its own at the surface** (`NavBaker`). That region costs more per metre (`SWIM_COST` 4), and getting in costs more again (8 m). A guard swims when the way round is a good deal longer. Shallow water stays in the land mesh: he wades it. |
| Fighting in water | **Nobody strikes afloat.** A swimming guard neither guards nor swings, and does not fetch things to throw. He swims after you and keeps his distance until you climb out. You cannot attack, or pick things up, while swimming. |
| Presentation | **Existing clips only** (Universal Animation Library): `ClimbUp_1m` for walls and ladders, `Jump` in the air, `Jump_Land` to gather and to land, `Swim_Fwd` and `Swim_Idle` in the water. No new assets. |
| The player | **A new move state, `SWIMMING`**, next to walking, climbing and hanging. Climbing out goes through the traversal pipeline you already use to mantle. |

## 3. Scope

**In scope:** guards climbing, dropping, leaping, and using ladders and ropes; water; swimming and wading for the player and the guards; floating props; splash and stroke sounds; the gym bay; tests.

**Out of scope:** guards diving under the surface; fighting in the water; breath and drowning; currents; water that is not a box; placing water in the campaign levels (a level adds a `WaterVolume` where it wants one).

## 4. What they do now

### 4.1 The ways across (`NavLinks.gd`)
After each bake, every border edge of the navmesh is walked (a look out every 0.8 m, 0.3 to 1.15 m out from it). A link is made where there is something walking cannot reach:

| Kind | What | Limits | Cost (per m, to enter) |
|---|---|---|---|
| climb | up onto a top, and back down it | 0.45 to 2.3 m above his feet | 3.0, 1.5 m |
| drop | down from higher than a climb (one way) | to 4.5 m | 1.5, 1.0 m |
| leap | across a gap to about the same height | 1.0 to 2.6 m across, at most 0.6 m up or down | 2.0, 1.5 m |
| ladder / rope | along a `ClimbVolume`, from the floor at its foot to the top it leads to | its height | 2.5, 2.0 m / 3.5, 3.0 m |
| water | off a bank into deep water, and out where the bank is low enough | out: bank at most 1.1 m over the surface; in: from as high as 6 m | 1.0, 8.0 m |

Links of one kind less than 1.4 m apart at both ends count as the same way. Anything that moves (loose props, people, moving bodies) is left out of the search. The costs mean a guard takes the stairs when they are near, and climbs when they are not.

### 4.2 Crossing (`GuardClimb.gd`)
- **Up:** hands on the edge, then a pull up and over it at 1.5 m/s. The climbing clip is driven by how far he has climbed.
- **Down:** a hop off a low edge. From higher up he turns, lowers himself to hang 1.9 m below the edge, and lets go. He falls under the guards' gravity and lands unhurt from anything a drop link allows.
- **Across:** he gathers himself, then leaps in an arc (5 m/s, 0.45 m over the higher end) and lands.
- **Ladders and ropes:** 1.4 m/s, facing the rungs, and over the top.
- **Into water:** from a bank 0.6 m over the surface or higher he jumps in and splashes. Lower banks he wades into. **Out of water:** he is hauled up the bank.
- **During the move:** in a fight he keeps watching you, but he cannot guard or strike. It is heard: 44 dB climbing, 52 dB landing.
- **Interrupted:** a blow, a kick, a knockdown or fire takes him off it. Off a wall or a ladder he falls, and the usual fall damage applies.
- **One ladder, one body:** someone on the ladder just above him (below, going down) keeps him at its foot until there is room. On the ladder he stays a body's length (1.9 m) behind whoever is ahead of him. He never climbs into you or shoves you up it. Two guards going opposite ways pass each other.

### 4.3 Water (`WaterVolume.gd`)
- **Deep:** more than 1.3 m from the surface to the floor under it. Anyone there swims.
- **Splash:** anything dropping in faster than 2 m/s splashes. It is heard at 48 to 70 dB depending on how hard it went in (`SoundBus` "splash"), and a spray is seen (`Fx` "water").
- **Floating:** loose rigid bodies (crates, stools) are pushed up by as much of them as is under the surface, and slowed.
- **Murk:** a darker box under the surface. How much shows through it is set by `clarity`.

### 4.4 Guards in the water (`GuardWater.gd`)
- **Swimming:** he goes at 45% of his speed. He floats with his head out, lower in the water and flat on the surface while moving. A stroke is heard every 1.4 m (44 dB).
- **Wading:** he slows to 60% at waist depth, and his steps sound like water ("water" is what he stands on).
- **His path:** the swim region lies at the surface, so the point his path follows is lifted to his feet (`path_height_offset`). That keeps his steering and his "is this step safe" check honest.
- **No fighting afloat:** he does not guard, strike, or fetch a thing to throw. His footwork still keeps him at his distance.

### 4.5 You (`PlayerController.gd`, `SWIMMING`)
- **Swimming:** chest deep with nothing to stand on, you swim. You go 3 m/s, or 4.2 m/s holding sprint, the way you face. Crouch dives, jump comes up, and left alone you float up until your eyes are over the surface.
- **Climbing out:** at a bank low enough to climb, face it and jump. You climb out using the same moves as a mantle.
- **What stops working:** anything you are holding is dropped when you go in. You cannot attack, or pick things up, while swimming.
- **Wading:** shallower water is slower, and your steps are the "water" sound (louder).
- **Being seen:** afloat you are harder to see (exposure 0.6), and under the surface only as much as the water's clarity lets through.
- **Being heard:** your strokes are heard at the surface (46 dB) and hardly at all under it (30 dB).

### 4.6 The bake (`NavBaker.gd`)
The land mesh is baked with deep water cut out of it. Then a swim region is baked for each deep water, at its surface. Then the links are made. Then the navigation map is synced, so the next path asked for already uses them. Only then is `baked` emitted. In the gym (ten bays, 261 links) the whole bake takes about 1.1 s headless.

### 4.7 Following you up (a follow-up)
Playing bay 10, the user found that the guards did not follow them up the ladder. There were three causes, and each is fixed:
- **You on the ladder counted as out of reach.** His path to your feet ended on the floor under you, so he stepped back to keep you in view and taunted you for a few seconds. Now, while you climb, hang off an edge or pull yourself over one, a guard goes for where that comes out (`PlayerController.climb_goal`, `Guard.goal_of`, `ClimbVolume.ends`): the top of the ladder going up, its foot going down. So he comes up behind you, waiting his turn as in 4.2.
- **He could not look up.** His head only turned side to side, and he sees 45° up or down, so from the foot of a tower you on top were out of his sight, and he lost you. Now in a fight his eyes follow you up and down (up to about 63° from level).
- **Losing you on the ladder stranded him on the floor.** Where he last saw you was up the ladder, and standing under it counted as having got there. Then he searched the floor. Now, if he last saw you on a ladder, hanging, going over an edge or in the air, he knows where you come out for up to 3 s after he loses you, until you are on your feet again (not under water: that is hiding). And coming to where he last had you counts height: under it is not there, unless his path can take him no nearer.

## 5. Where to see it

The NPC gym (`maps/npc_gym.tscn`), **bay 10, CLIMB & SWIM**: press `-`, or walk to the corridor's north end and pull its lever. It has a block, two roofs with a 1.9 m gap between them, a 3.5 m tower with a ladder, and a pool 2.1 m deep. Two guards come after you wherever you go. F1 shows what each is doing ("climb", "ladder", "hang", "leap", "land", "swim", "tread"), and F4 freezes them so you can watch.

`tests/visual/stage_climb.tscn` films a guard mantling, on a ladder, dropping, leaping and swimming. `tests/visual/stage_gym.tscn` now ends with bay 10: the tower and the pool from the side.

## 6. Success criteria

1. `tests/climb_swim_test` passes all of its checks:
   - **L1–L2:** the ways across are found; water is swum at its surface; the way round is taken when it is short.
   - **G1–G7:** a guard climbs up after you, hops down, uses a ladder, hangs and drops unhurt, and leaps a gap. Struck on a ladder, he falls. Below a bare 3 m wall he does not try to climb it.
   - **G8–G10:** from under a tower he looks up and sees you on it. In the dark, hearing nothing, he still comes up the ladder after you, having seen you start up it. When you stop partway up the ladder he waits his turn at its foot without shoving you, and follows you up when you go on.
   - **W1–W5:** you swim, dive and climb out; wading is slower; a guard swims after you but does not strike, and climbs out after you; a crate floats.
2. `tests/gym_test` passes, G8 included: the bay 10 guards climb the ladder after you, and swim after you.
3. Every other suite passes, run as the project documents (`--fixed-fps 60`).

## 7. Known limits

- **Guards stay at the surface.** They never dive: if you are under the water they wait above you for you to come up.
- **No blows in the water**, from anyone.
- **Links are found once per bake.** A crate pushed against a wall after the bake is not a way up. A level whose geometry changes must bake again (`NavBaker.bake()`).
- **A wall over 2.3 m with no ladder is out of reach.** The guard below does what he did before: calls, throws, waits.
- **Water is an axis-aligned box.** Turning the node does not turn the water.
- **A rope is climbed like a ladder.** Guards do not swing on it.
- **Waiting under you on a ladder, he cannot strike.** Your feet more than 1.2 m above his are out of his blade's reach. He waits for you at the foot, or on the ladder a body's length behind you.
- **Wading is only slower.** A guard standing in water fights as he does on land.
