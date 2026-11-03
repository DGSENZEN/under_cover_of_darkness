# The elite mouth

## Why

The user, on the torso: "with certain cases it can absorb other hands and other skulls into it making it bigger, but that's an *elite* form of the torso enemy."

The plain mouth (`docs/superpowers/specs/2026-11-02-the-mouth-design.md`) is a conglomeration of souls that has already happened. The elite is one still eating. It turns the other enemies in a fight into its fuel, so the fight becomes a question of what to deal with first, which is what the hunts are for: "real tension", fights that take thinking.

Its cause in the world: nothing new. What made the mouth, souls no one lit a candle for clinging together, is still going on in this one ([[world-built-by-its-events]]).

## What the user decided

- **It is an elite form of the torso, not the plain torso.** The plain one does not absorb.
- **It absorbs when it is hurt.**
- **Each absorb wins back health**, so it "makes it harder to kill and rewards stopping it".
- **Each absorb makes it bigger.**
- **At three absorbs, if it grabs you, you die.**
- **Built as the same torso with an elite setting**, as the turned eye is one setting on the floating eye, with its own numbers in the Bestiary. Chosen over a new form row (about a dozen places name the torso, each could quietly miss a new name) and over a separate monster on top of it (its state machine isn't built to be extended that way).

## Goals

- You can see it coming, you can stop it, and stopping it is worth doing.
- The player's question in a fight with one becomes: the small ones first, or it?
- Three absorbs is the most frightening thing in the game so far, and fair: you always knew.
- It always looks and moves as the mouth does, only more so, and gets every later fix to the mouth.

## Non-goals

- Any change to the plain torso: its numbers, moves or look.
- Absorbing eyes, guards or anything but the ánimas' hands and faces. Nor another torso.
- A new item or spell against it.

## Anti-goals

- A health bar that resets and bores you: a fight dragged out by healing with nothing you could have done.
- Absorbing as a cutscene: the fight goes on during it, and you can act.
- A kill out of nowhere: the grab at three must never surprise you.
- Anything on screen in words of ours.
- New modelled bodies that look stuck on: what it absorbs goes in under its skin, as the fused faces are ([[connected-topology-details-make-sense]]).

## How it goes

Numbers are Claude's first go, all in `Bestiary`, to be tuned in play.

**Hungry.** With an absorb left in it (fewer than three), when its health is below two-thirds of its most, it goes hungry: at most once every 6 s, it picks the nearest hand or face not on you, within 5.5 m, that it has a clear line to. A line is clear of walls and of a copal line, and a smoked mouth can't seize, as it can't grab you: both are the game's rules already, and give you two more answers. With none, it goes on fighting as a mouth does, and tries again when one is there. Healing can take it back over two-thirds, so it stops being hungry until you hurt it again.

Claude's call: it only goes for one from crawling, circling or backing off. Holding you, gathering for a lunge or in the air, it finishes that first: it never lets go of you to feed.

**Reaching.** It stops what it is doing and hauls itself toward the one it chose, at its crawl, until that one is within 2.6 m (and 0.3 m more for each it has taken), or gives up after 6 s. The one it chose carries on, unaware, until it is seized. Then one arm shoots out, past where an arm normally goes, and seizes it.

**Dragging in.** Seized, the small one stops fighting and thrashes, and is dragged in over 1.2 s. It can be killed while this happens. This is the moment you can act.

**Stopping it.** Three ways, each worth something:
- Kill the small one, seized or not: it gets nothing, and goes on looking for another once the 6 s is up.
- Any hit on the mouth from anything but lead while it reaches or drags: all of what a hit in its lunge's tell gets you, through `_is_opening_to`: three times the damage and power back. It lets go, is stunned as when thrown off (1.5 s, exposed), and the small one drops, alive, and carries on. Claude's call: this is what "rewards stopping it" means, so feeding is its great weakness as well as its strength; its health is set with that in mind.
- Have killed them all before it gets hurt: no small ones, no absorbing.

**Taken in.** The small one goes in under the skin. It is out of play as a dead monster is (`Monster._lay_down`): no burn, no reward, and it counts as gone for the wave. The mouth wins back 30% of its most health (never above its most), gets bigger, and from then on that one is there to see: a face or hand from `mouth_sheath.glb`, by what it took, up out of its flesh, and staying.

**What each one does to it** (added at each of the three):
- 12% bigger, hit radius with it. Its height and how long its arms are with it, so it still stands on the floor and its hands still reach it.
- Swipe reach up 0.2 m and lunge reach up 0.3 m, so at three its swipe is 2.8 m and its lunge 3.9 m, and the lunge still has room to happen. Claude's call: what you learned on the plain one changes a little, as a bigger thing's would.
- Swipe damage up 20%, life drain up 25%.
- Crawl 8% slower.

## At three

**You see it.** At three, all its eyes burn, every face and hand in it stays up and straining, and its hunger never drops below where the plain one's is when gathering. Its own sound. Its lunge's tell and everything else that warns you are as they are: 2 s gathering, and you can dodge it. No words on screen.

**It grabs you, you die.** When a leap lands, you die there and then: no hold, no more control. A death of its own in `PlayerDeath`, about 2.6 s: its ribs shut on you over the first second (`LeechCage.close_in`'s `last`, held shut from then), you go down, and the quote comes as for the ánimas, your quotes as they are.

Claude's calls here, for the user to correct:
- Nothing saves you once it has you: no whip, copal, Burst or blink. A blink *before* it lands is the answer, or a hit in its tell that breaks the lunge, as with the plain one.
- Its swipe at three still only cuts. It's the grab that kills, as the user said.
- Invulnerable or not, as the game's other kills go (`player.invulnerable` holds, so the gyms' test setups behave).

## How it looks

Claude's calls:
- **From the start, you can tell it's the elite.** The dead candles on its back are lit, burning sick: it has eaten what was left for the others. It starts 8% bigger than a plain one.
- What it took stays. By three, it should look gorged, and still be recognisably the same creature, its arms still reaching the ground.
- The cage, when it has you short of three: more faces in it, one for each taken, up to the room there is, and the middle stays clear (`middle_kept_clear`).

**Its death.** The three it has are the mouth's. What it took comes out with the rest, in its fire. Nothing it leaves can hurt you.

## Settled from the project as it stands

- **The setting:** `Anima.elite := false`, set before it enters the tree, as `FloatingEye.start_turned`. The numbers are a Bestiary row: `forms.torso.elite`, with its own health and the add-ons above.
- **The state:** new `Anima` states for reaching and dragging. Its `DOING` poses in `AnimaBody.MOUTH_POSES`.
- **Waves:** a new last wave in `maps/mixed_gym.gd` and `maps/anima_gym.gd`: an elite with enough small ones round it to take three. The other waves are as they are.
- **Saves:** a monster never frees itself and a save can keep it. How many it has taken and which are saved with it, and a taken one stays gone (`Monster` keeps its `dead` state). Off a save, it looks as it did.
- **Tests:** in `tests/anima_test.gd` with the mouth's, failing first ([[failing-checks-kept]]). Windowed stills and filmed shots in the real game. `--fixed-fps 60`.
- **Frame cost:** the mixed gym's new worst wave, with three taken, holds 60 fps at 1152x648 with vsync on (`tests/diag_mixed_perf.tscn`).
- **Sounds:** stand-ins from approved packs; wanted takes on `sounds_needed.md` and `elevenlabs_prompts.md`. Effects are ours.

## Constraints

- Godot 4.5.1, GDScript. Nothing moved in `_process` where it would judder ([[judder-physics-interpolation]]).
- Everything of the plain torso's checks passes as it was.
- Stills from the real game, room and yard, every joint up close before anything is shown ([[finished-means-meticulous]]).

## Approaches

The user picked the first.

- **The same torso, with an elite setting (picked):** keeps the arms, gait, cage and deaths, and every future fix. Costs a few "if elite" branches in the mouth's code.
- A new form with its own Bestiary row: tidiest for data and matches "a variant is a row", but every place that names the torso must learn the new name.
- A separate monster on top of the torso: the plain one untouched, but the state machine would need rewiring to allow it.

## Left to the builder

- How the arm that seizes looks going past its normal reach, and how the small one thrashes, within the beats above.
- Which spots what it took comes up at.
- The poses.
- Which approved sounds stand in.
