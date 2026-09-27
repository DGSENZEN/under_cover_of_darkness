# A Garrison at Its Ease: Design

**Date:** 2026-09-26
**Status:** built and tested (`tests/habits_test`, H1–H18; `tests/gym_test` G1 and G9); this document awaits the user's review.

## 1. Goal

The user asked: "We need distinct idiosyncratic behaviours for the NPCs, they need idling, leaning on certain buildings, they should be able to climb stairs or ropes and chains, sit down on chairs, grab things here and there, patrol with lanterns or torches, talk to each other, that type of stuff." And then: "Get the most you can with what we have."

Before this, a guard with nothing to do stood at his post, or walked his rounds and stood at each waypoint. Now and then he folded his arms, took a pull from his flask, or talked with the man beside him (GuardLife). So this adds:

- **Places to be at ease:** chairs, benches, a table, provisions, a fire, a chopping block, crate piles, a cart, a rail, walls to lean on. Each says where a man stands or sits to use it, and which way he faces.
- **Each man his own ways:** what he does with himself, how often, and a quirk of his own, from his temperament.
- **Things in his hands:** bread, an axe, a crate, a torch or a lantern on his rounds.
- **Talk:** a man goes over to a friend for a word. The listener nods or shakes his head. Two men sat together talk where they sit.
- **Ropes and chains** up to the ledges beside them, and stairs, taken like any way across.

"What we have" meant no new assets. Every pose comes from the animation library already in the game, and every prop is built from boxes and cylinders.

## 2. Decisions

| Question | Decision |
|---|---|
| Where a man goes to be at ease | **Marked places** (`IdleSpot.gd`, group `idle_spots`): a kind, a point and a facing. One man at a time holds each, and it frees itself if he goes. `Furnishings.gd` builds the furniture with its places already on it. A level can also drop a bare `IdleSpot` anywhere. |
| Who decides what he does | **`GuardHabits.gd`**, one per guard next to GuardLife. It runs only while he is at rest and at his ease (RELAXED, nothing on his mind). Anything that stirs him ends it at once. |
| How men differ | **By temperament**, the five tags already in the game (steady, stubborn, craven, rash, sly). Each tag has its own leanings over the habits and over the fidgets. With `Temperament.rolling` on, each man's leanings are scaled by 0.5–1.5, and 60% of men get a quirk. A level can pin a man's habits (`Guard.habits`) and his quirk (`Guard.quirk`). |
| What a habit is | **A list of steps:** go there, step into place, then one or more timed poses. A pose can call something at a moment in it (take the bread) or every so often (each blow of the axe). The same small runner plays them all. |
| Lights on rounds | **`Guard.rounds_light`** ("torch" or "lantern"): lit at once, carried while he walks his rounds, dropped still burning when a fight starts, lit again 3 s after the fight ends. While his hand holds a light, his habits are only looks about and mutters. |
| Ropes, chains, stairs | **The ways across that already exist** (`NavLinks`, `GuardClimb`). Ropes and chains now link the floor at their foot to the highest ledge beside them. Stairs are walked on the navmesh. |
| Presentation | **Existing clips only** (Universal Animation Library): `Sitting_Enter`, `Sitting_Idle`, `Sitting_Talking`, `Sitting_Exit`, `Idle_FoldArms` (also tilted back as the wall lean), `Idle_Rail`, `PickUp_Table`, `Consume`, `Sword_Attack` (the overhead blow, with an axe), `Fixing_Kneeling`, `Walk_Carry`, `Idle_Torch`, `Idle_Lantern`, `Yes`, `Idle_No`, `Dance`. |

## 3. Scope

**In scope:** places and furniture; habits and fidgets by temperament and quirk; dozing; things held; lights on rounds; visits and talk; ropes and chains; keeping the navmesh off low furniture; the gym bay; tests; a visual stage.

**Out of scope:** schedules (meals, shifts, sleep in beds); men using doors, levers or chests for their own ends; carrying things between rooms beyond the two crate piles; new animation.

## 4. What they do now

### 4.1 Places (`IdleSpot.gd`, `Furnishings.gd`)
| Kind | Where | Built by |
|---|---|---|
| seat | in front of a chair, stool or bench seat (0.32 m out), facing away from its back | `chair`, `bench` (a place every 0.7 m), `table` (chairs round it facing it) |
| table | before the provisions counter, facing it | `provisions` |
| fire | 0.78 m out round a campfire, facing it | `campfire` |
| work | kneeling at a cart's wheel | `cart` |
| chop | before the chopping block, where the axe lands on the log | `chopping_block` |
| pile | before a stack of crates (group "stock"); two piles are partners | `crate_piles` |
| rail | 0.32 m back from a rail at forearm height, facing over it | `railing` |
| lean | 0.36 m out from a wall, facing away from it | `lean_spots` |

All the furniture is static bodies on the world layer. Pieces lower than 0.7 m (a seat, a stump, the fire's ring) are also marked for the baker (group "nav_blocks"). It keeps them out of the navmesh with room round them. Otherwise it would take them for a step and send men over them.

### 4.2 Each man's ways (`GuardHabits.roll`)
| Temperament | Leans most to | Fidgets most |
|---|---|---|
| steady | sitting, the wall, a bit of everything | arms folded, a look about |
| stubborn | chopping, tending, carrying, the rail | arms folded, a look about |
| craven | visiting, the wall, sitting, eating | a look about, a drink |
| rash | chopping, pacing, carrying, visiting | a drink, arms folded |
| sly | the wall, the rail, eating | arms folded, a look about |

A quirk makes one habit or fidget three times likelier, plus a bit (sit, lean, eat, drink, mutter, pace, visit). Or it is his alone:
- **dozes:** nods off wherever he sits.
- **merry:** a few dance steps when nobody is within 10 m.

After 3 s at rest he picks something, by pull, from what can be done within his reach (`Guard.habit_range`, 10 m of his post). Then he waits 3–9 s before the next. At a waypoint of his rounds he picks only what is at hand and quick: a seat, the wall, the rail, a bite, a fidget.

### 4.3 The habits
- **sit:** to the seat and in among it (the chair and table let him through as he steps into place). His blade is put by, and he sits 15–40 s. Then he gets up and steps back out to where he came in from. Two men sat within 3.8 m of each other talk where they sit.
- **doze:** a dozy man sat in the dark (under 0.25 light) nods off after 6–12 s, and a man with the "dozes" quirk nods off anywhere. His head goes down. He sees nothing unless you touch him. He hears at a third of his usual reach, and he sleeps 20–45 s. A noise, a shout or a blow wakes him with a start and a word ("woken" lines), and he is up at once.
- **lean:** back against a "lean" place, or against the wall right behind his post if there is one (a ray 1.3 m back). 8–22 s, arms folded.
- **rail:** forearms on the rail, looking out and down over it, 8–22 s.
- **eat:** to the provisions: reaches for bread, takes it in the palm of his left hand, eats it there. Blade put by.
- **chop:** takes up an axe (blade put by) and splits logs, 8–16 blows, one every 1.18 s. He holds the axe as he holds his sword: the haft through his right fist, the head out of the thumb's side, the edge leading. Each blow is the guards' own overhead blow (`Sword_Attack`, as the heavy blow uses it): the axe pulled out of the log and lifted back over his head, held a breath, brought down level onto the log standing on the block, and left in it a moment. He stands 1.2 m back from the log and a little to its right, where the blow lands (a bigger man stands further back). Each blow is a wood thud with chips flying from the log, heard 18 m off (`SoundBus` "chop", 52 dB): a sound the rest of the guards hear and know.
- **tend:** down on his knees at the fire (or at a cart's wheel), working at it 10–20 s, and up again.
- **carry:** a crate from the fuller pile, held at his chest, walked to the other pile and set down there. Next time, back the other way.
- **visit:** over to a friend at his ease within 12 m. He stands 1.4 m off him and they talk (GuardLife), and he goes back once they are done.
- **pace:** a few steps to one side of his post, a look about, and back.
- **fidget:** where he stands: arms folded, a drink, a look about, a look up at the sky, a nod or a shake of the head, a mutter, a dance.
- **mutter:** alone and at rest, now and then (every 45–110 s, twice as often for the quirk) he says something to himself.

### 4.4 Talk (GuardLife)
The talk itself is GuardLife's: lines turn and turn about, 2.6 s apart. The listener's head answers each line: an easy man (steady, craven, sly) nods 60% of the time and shakes 10%; a hard man (rash, stubborn) shakes 40% and nods 20%. His blade is put by while he talks or listens.

### 4.5 Lights on rounds (`GuardHands.carry_light`)
Everything held goes through the fist, the way the sword does (`Humanoid.FIST_R`, `FIST_L`).
- **Torch:** raised in his left fist (the `Idle_Torch` clip holds it up), 2.1 energy, 7.5 m. The stick passes through his fist, with a head of pitch-soaked rag and the flame on top. His blade stays in his right.
- **Lantern:** held out in his right fist (`Idle_Lantern`), 1.5 energy, 6.5 m, and his blade at his belt. It hangs straight down by its bail whichever way his hand turns, and swings a little as he walks and stops (`Hanging.gd`, a pendulum 0.22 m long). The lantern a searching man lights hangs the same way from his raised left fist.
- **Into a fight:** it drops, still burning. A lantern stands on its base; a torch lies on its side, the flame at one end. A lantern man's blade comes out.
- **After:** 3 s after the fight he lights it again, unless he is climbing or swimming.

### 4.6 Ropes, chains and stairs
After each bake, NavLinks looks up each rope or chain (`VerletRope`, a `ClimbVolume` with `rope` on). It finds the highest ledge within 1.3 m of the line and links the floor at its foot to the top of that ledge. A guard takes it hand over hand, as he takes a ladder. Stairs (0.3125 m risers) are within the navmesh's climb, so he walks them.

### 4.7 Stirred
Anything that stirs him (a noise, you seen, a blow, a kick, a knockdown) ends whatever he was at in that frame:
- **Seated or asleep:** up at once, in a hurry.
- **Carrying:** the crate falls.
- **Holding something:** the axe or bread is gone, and his blade is back in his hand.
- **Spot:** freed for someone else.

The seat's furniture lets him through until he is clear of it (1 m, or 4 s).

## 5. Where to see it

The NPC gym (`maps/npc_gym.tscn`), **bay 11, GARRISON**: press `=`, or go through the door in bay 10's west wall and pull the lever. It is a courtyard at night with seven men:
- a patrol with a torch;
- a man on the walkway with a lantern, up the stairs and back, leaning on the rail;
- a man at the gate leaning on the wall;
- a woodsman splitting logs and shifting crates;
- a craven man at the mess table who eats and gossips;
- a dozer asleep on the bench in the dark;
- a sly man tending the campfire.

A rope goes up to a tower and a chain up to the walkway. F1 shows each man's temperament, quirk, and "ASLEEP".

`tests/visual/stage_life.tscn` films each habit from the side and the front.

## 6. Success criteria

1. `tests/habits_test` passes all of its checks:
   - **H1:** temperaments lean their own ways, and two men of one temperament, rolled, differ.
   - **H2–H3:** he sits and gets up, and steps back out of the chair. Stirred, he is up at once.
   - **H4–H9:** he leans on the wall behind him, eats, chops (heard 18 m off), tends the fire, and carries a crate. Stirred, he lets it fall.
   - **H10–H12:** he visits a friend and they talk; an easy man nods, a hard one shakes his head; two sat at a table talk.
   - **H13–H14:** forearms on the rail. The dozer is blind to you in the light and woken by a noise.
   - **H15–H16:** torch and lantern rounds: up stairs, dropped into a fight, lit again after.
   - **H17:** up a rope and a chain.
   - **H18:** the navmesh keeps off low furniture.
2. `tests/gym_test` passes: bay 11 starts at its ease (G1), and over 45 s its men carry a torch and a lantern and do at least five of their own things, all at their ease (G9).
3. Every other suite passes, run as the project documents (`--fixed-fps 60`).

## 7. Known limits

- **Leaning on a wall is the folded-arms idle, tilted back.** The library has no wall lean. Tending a fire and mending a wheel share the kneeling-repair clip, and eating is the drinking clip with bread in the hand.
- **The axe is swung one-handed, with a swordsman's stance.** The library has no two-handed chop (`TreeChopping` is a sideways swing at a standing tree, and did not bring an axe held in the fist down onto a block), so the woodsman uses the overhead blow, stopped where the axe bites the log.
- **Places are where furniture is.** Without any, a man only leans on the wall behind his post, paces and fidgets. A level gets the rest by building with `Furnishings` or placing `IdleSpot`s.
- **One man to a place,** and crates go between two piles only.
- **Only furniture built by `Furnishings` (or put in "nav_blocks") is kept off.** A hand-made low box is still a step to the baker.
- **A man with a light only looks about and mutters** on his rounds; he does not sit or lean until he puts it down.
- **He dozes only sitting.** Without the quirk, he dozes only when leanings are rolled (a quarter of steady and sly men, in the dark).
- **A rope is climbed like a ladder.** Nobody swings on it.
