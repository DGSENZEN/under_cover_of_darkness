# A Garrison at Its Ease: Design

**Date:** 2026-09-26
**Status:** built and tested (`tests/habits_test`, H1–H27; `tests/gym_test` G1 and G9); this document awaits the user's review.

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
- **sit:** to the seat and in among it (the chair and table let him through as he steps into place). His blade is in its scabbard (as it is whenever he is at his ease: `2026-09-26-enemy-ai-overhaul-design.md` 4.9), and he sits 15–40 s. Then he gets up and steps back out to where he came in from. Two men sat within 3.8 m of each other talk where they sit. Heard: his clothes rustle as he sits and as he gets up, and the seat creaks as his weight comes onto it (0.95 s into sitting down).
  - **At a table** he draws the chair out 0.25 m as he steps in front of it, sits down clear of the table's edge, and draws himself and the chair in to the table (0.6 s), his knees under it. To get up he draws out again first, and pushes the chair back in as he steps away. Sitting down and getting up he leans well forward, and the table's edge would otherwise go through his thighs and hands. Each time the chair moves it scrapes the floor.
- **doze:** a dozy man sat in the dark (under 0.25 light) nods off after 6–12 s, and a man with the "dozes" quirk nods off anywhere. His head goes down. He sees nothing unless you touch him. He hears at a third of his usual reach, and he sleeps 20–45 s. A noise, a shout or a blow wakes him with a start and a word ("woken" lines), and he is up at once.
- **lean:** back against a "lean" place, or against the wall right behind his post if there is one (a ray 1.3 m back). 8–22 s, arms folded.
- **rail:** forearms on the rail, looking out and down over it, 8–22 s.
- **eat:** to the provisions: reaches for bread, takes it in the palm of his left hand, eats it there, a bite out of it with each mouthful (30% of what is left).
- **chop:** takes up an axe and splits logs, 8–16 blows, one every 1.18 s. He holds the axe as he holds his sword: the haft through his right fist, the head out of the thumb's side, the edge leading. Each blow is the guards' own overhead blow (`Sword_Attack`, as the heavy blow uses it): the axe pulled out of the log and lifted back over his head, held a breath, brought down level onto the log standing on the block, and left in it a moment. He stands 1.2 m back from the log and a little to its right, where the blow lands (a bigger man stands further back). Each blow is a wood thud with chips flying from the log, heard 18 m off (`SoundBus` "chop", 52 dB): a sound the rest of the guards hear and know.
- **tend:** down on his knees at the fire (or at a cart's wheel), working at it 10–20 s, and up again. At a fire he pushes a log in every 3.3 s (the first 1.2 s in): a burst of sparks, a crackle, and the flame flares up brighter and taller for most of a second (`Torch.flare`).
- **carry:** a crate from the fuller pile, held at his chest (with a grunt as he lifts it), walked to the other pile and set down there. Next time, back the other way.
- **visit:** over to a friend at his ease within 12 m. He stands 1.4 m off him and they talk (GuardLife), and he goes back once they are done.
- **pace:** a few steps to one side of his post, a look about, and back.
- **fidget:** where he stands: arms folded, a pull from a leather flask (upright in his left fist, its neck up at his mouth as his hand comes to it), a look about, a look up at the sky, a nod or a shake of the head, a mutter, a dance.
- **mutter:** alone and at rest, now and then (every 45–110 s, twice as often for the quirk) he says something to himself.

### 4.4 Talk, glances and greetings (GuardLife)
The talk itself is GuardLife's: lines turn and turn about, 2.6 s apart. The listener's head answers each line: an easy man (steady, craven, sly) nods 60% of the time and shakes 10%; a hard man (rash, stubborn) shakes 40% and nods 20%. His blade stays in its scabbard while he talks or listens (put away first, if he was on edge with it out). Talking, each turns his head to the other (up to 1.2 rad), stood or sat side by side at a table.
- **Glances:** a man at his ease whose head is free (stood, sat, leaning, at the rail, eating; not asleep, at work or drinking) looks round at another man going by on the move within 7 m, before him or beside him (or close behind), for 1.5–3 s, and not again for 4–10 s. It is his logical head that turns, so while he looks at a friend he is not looking for you. A lookout keeps his eyes on his ground.
- **Greetings:** a man walking at his ease who comes up on another at his ease (within 4 m, ahead of him, in sight) has a word for him ("Evening, Hendrik.", "All quiet?", by his temperament: `Temperament.MORE_LINES` "greet"). How often, by his temperament: craven 85%, steady 70%, rash 60%, sly and stubborn 45%; otherwise only a look passes between them. The other looks round at him and nods (his drawn head dipped 0.32 rad and back over 0.7 s; his eyes stay where they were), and half the time answers ("greet_back") a second later. Not the same two again for 150 s, and neither greets anyone for 15–30 s after. Not to a man he is going over to anyway (visit), nor one talking, asleep or at work.

### 4.5 Lights on rounds (`GuardHands.carry_light`)
Everything held goes through the fist, the way the sword does (`Humanoid.FIST_R`, `FIST_L`).
- **Torch:** raised in his left fist (the `Idle_Torch` clip holds it up), 2.1 energy, 7.5 m. The stick passes through his fist, with a head of pitch-soaked rag and the flame on top. His sword hand stays free for his blade.
- **Lantern:** held out in his right fist (`Idle_Lantern`), 1.5 energy, 6.5 m, his blade in its scabbard. It hangs straight down by its bail whichever way his hand turns, and swings a little as he walks and stops (`Hanging.gd`, a pendulum 0.22 m long). The lantern a searching man lights hangs the same way from his raised left fist.
- **Into a fight:** it drops, still burning. A lantern stands on its base; a torch lies on its side, the flame at one end. Every man's blade comes out (drawn at once in a fight).
- **After:** 3 s after the fight he lights it again, unless he is climbing or swimming.

### 4.6 Ropes, chains and stairs
After each bake, NavLinks looks up each rope or chain (`VerletRope`, a `ClimbVolume` with `rope` on). It finds the highest ledge within 1.3 m of the line and links the floor at its foot to the top of that ledge. A guard takes it hand over hand, as he takes a ladder. Stairs (0.3125 m risers) are within the navmesh's climb, so he walks them.

### 4.7 How he moves about it
- **The last of the way is walked.** Stepping into place (to a seat, the wall, the rail, the block, the fire, a pile) he carries on at the pace he came at and slows into it (a Hermite ease from his walking velocity, over the distance at 0.9 m/s, never under 0.35 s), and his legs are shown walking it (`GuardHabits.stepping`, which the rig adds to his velocity). Before, he stopped dead, then slid the last metre with his legs still. The ground ray ignores what he may pass through, so stepping over a chair's seat no longer lifts him onto it.
- **A turn on the spot is stepped round.** Turning faster than 0.9 rad/s where he stands, with nothing shown over his legs, his feet shuffle round (a slow walk, 0.55–0.9 m/s shown, hips turned 0.7 rad into the turn). It lasts one step at the least however short the turn, and stops once the turn is nearly done. In a fight too, between blows.
- **Asleep he breathes:** a slow breath every 4.4 s, his chest lifting (a lean back at the waist, 0.035 rad) and his head with it.

### 4.8 Stirred
Anything that stirs him (a noise, you seen, a blow, a kick, a knockdown) ends whatever he was at in that frame:
- **Seated or asleep:** up at once, in a hurry. Sat in to a table, he shoves himself and the chair back from it as he jumps up, and the chair stays out where he left it.
- **Carrying:** the crate falls.
- **Holding something:** the axe or bread is gone, and his hands are free again (his blade in its scabbard until he needs it).
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

`tests/visual/stage_life.tscn` films each habit from the side and the front, including the fire as it is stoked, the flask at his mouth, and a man nodding to another who greets him going by.

## 6. Success criteria

1. `tests/habits_test` passes all of its checks:
   - **H1:** temperaments lean their own ways, and two men of one temperament, rolled, differ.
   - **H2–H3:** he sits and gets up, and steps back out of the chair. Stirred, he is up at once.
   - **H4–H9:** he leans on the wall behind him, eats, chops (heard 18 m off), tends the fire, and carries a crate. Stirred, he lets it fall.
   - **H10–H12:** he visits a friend and they talk; an easy man nods, a hard one shakes his head; two sat at a table talk, each with his head turned to the other.
   - **H13–H14:** forearms on the rail. The dozer is blind to you in the light and woken by a noise.
   - **H15–H16:** torch and lantern rounds: up stairs, dropped into a fight, lit again after.
   - **H17:** up a rope and a chain.
   - **H18:** the navmesh keeps off low furniture.
   - **H19:** at a table, the chair drawn out to sit down and get up, tucked in once sat; stirred there, he shoves back from it.
   - **H20:** the last of the way to a seat is walked: he sets off into it at the pace he came at (at least 0.6 of it), his legs shown going halfway in, and his feet stay on the floor as he steps in among the chair.
   - **H21:** turned about where he stands, his feet shuffle round under him, and are still once he has turned.
   - **H22–H23:** he looks round at a man going by; going by a man at his ease, a word to him and a nod back, and not again straight after.
   - **H24:** a flask in his left hand for a drink, put away after; the bread bitten down to under 0.6 of itself.
   - **H25:** at the fire he stokes it: the flame flares and crackles.
   - **H26:** asleep, he breathes.
   - **H27:** heard: a rustle sitting and getting up, the seat creaking, the chair scraping each of four times, a grunt at a crate; no blade in or out (it is in its scabbard at his ease).
   - **H28:** at his ease his blade is in its scabbard; going to look into something he draws it (his hand to the hilt, a ring), and at his ease again puts it back (a slide).
   - **H29:** killed with his blade in its scabbard, it stays on him.
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
- **A turn on the spot is the walking cycle,** hips turned into it; the library has no turning clips.
- **The drink is the eating clip.** The hand comes to the mouth; it does not tip the flask back.
- **A greeting is one line and a nod,** and the answer one line; they do not stop to talk (a visit is for that).
- **Glancing at friends costs him his watch:** while his head is turned to a man going by, you are out of the middle of his view. It is short, and rare, but it is real.
