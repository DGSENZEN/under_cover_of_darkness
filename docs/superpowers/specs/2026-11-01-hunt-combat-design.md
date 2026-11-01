# Hunts: combat with tempo, stakes and preparation

Brainstormed with the user on 2026-10-31 and 2026-11-01. This is the "combat revamp" of the demo program (`2026-10-16-mexico-city-demo-program.md`, project 3), and it builds on the revolver and the first spells (`2026-10-23-revolver-and-magic-design.md`). Lines marked *(Claude's call)* were proposed by Claude and not corrected by the user. They are open to correction. Everything unmarked is the user's.

## Intent

The user, on what is wrong with combat now: "There is no general tempo, the enemies lack any sort of incentive to have the user use their powers to win the confrontations, we need ways to have the exsecrator prepare for specific dangerous monsters, as well as doing general combat that feels polished and with stakes, right now it is not weighty, it has no real tempo."

The protagonist is **the Exsecrator** (the user's name for them; older docs say "the Prosecutor").

The target is a mix of three games:

- **Halo: Combat Evolved.** Using the right tool for the right enemy, and stakes. Each enemy is a distinct problem with a matching answer, and a mixed group makes you change answers mid-fight.
- **Prey (2017).** Weight in guns and spells. Every shot and every power costs something you feel. Tools combine.
- **The Witcher 3.** Vulnerabilities, and preparing tools before a hunt.

So: **you prepare before you go, you pack a few things, and in the fight you switch between what you packed.** In the user's words: "only your gun, and some spells, and some items to prep, so you prepare BEFOREHAND and switch up with whatever you need, bullet types, spells, wards, protective gear, etc."

Fights are **mostly against monsters**. Human enemies can join them. The monsters come in **varieties**. The first four are low-level ones:

- spectres;
- revenants;
- aggressive ánimas;
- floating eyes, based on Terraria's Demon Eyes "but more stylized on our game".

Later the bestiary grows to flying snakes, werewolves, higher vampires inspired by The Witcher, undead, demons and more.

Movement in a fight is broken: "the dodging, sliding, strafing doesn't particularly work properly". The combat UI does not fit the game. It should be "a mix of both", meaning partly on the Exsecrator's body and gun and partly painted in the talk box's style. The look is Claude's to set from the game's art direction.

## Goals

1. **Tempo and stakes in every fight.** A fight has a rhythm of pressure and release. Mistakes cost something real. Pressing forward with the right answer pays you back.
2. **Monsters that demand powers.** Every monster kind has weaknesses and resistances. Some kinds cannot be beaten well with the plain revolver at all. Each of the existing powers has a monster that needs it.
3. **Preparation before a hunt.** You pack a limited loadout at a safe place: round types, spells, prep items and one piece of protective gear. What you learn about a monster beforehand tells you what to pack.
4. **A bestiary built to grow.** Each monster is a base kind plus variants, read from data. A new monster later (a werewolf weak to silver, say) is a data entry plus its own behaviour, not new rules.
5. **Fight movement that works.** A dodge with the revolver in hand, a slide, and strafing that feels right, all measured by tests.
6. **Weight.** The gun, the casts and the hits feel heavy and deliberate.
7. **A combat UI in the game's style.** Partly on the hands and gun, partly painted. The current ammo readout and the stealth HUD's combat pieces are replaced.
8. **The four starting monsters, with variants,** in a first complete hunt that can be played from start to finish.

## Non-goals (this program)

- **Climbing and traversal.** The user wants it "smooth and easy to use", but it is its own project (the free-run climbing work). It runs separately so neither stalls the other.
- The later monsters: flying snakes, werewolves, higher vampires, undead and demons. The bestiary must not block them.
- New spell schools beyond what the four monsters need: Séance, Lumen and Relic as full schools, and learning schools from practitioners.
- Melee as the centre of fights. It stays situational, as decided on Oct 23.
- Saving the loadout and the bestiary to disk beyond what the save system's existing patterns give for free. The save program (`progression-program`) owns that. New state uses the `SAVED` field pattern so it can join in.

## Anti-goals

*(Claude's call, drawn from the user's references and standing rules)*

- **A generic shooter:** fast fire, light guns, spells used as more bullets, every monster beaten by shooting until it stops. If the plain revolver beats a hunt comfortably, the hunt has failed.
- **Stat-check monsters:** health bars that only differ in size. Each kind must ask for a different action, not more damage.
- **A menu game.** Preparation must not turn into spreadsheets. A loadout is a handful of physical things you can see on a table and on your body.
- **Magic sprinkled in.** Every monster, round and charm has a cause in the world's events. No glow for its own sake, and no tesla arcs.
- **UI staged over a mock backdrop.** UI is judged in the real game only.

## Constraints

- **Standing rules:**
  - every model is built one at a time with the user reviewing it;
  - no free VFX assets: we make our own;
  - every strange thing has a cause in the world;
  - never call a visual defect harmless;
  - the user writes all words (barks, bestiary pages, item names, labels);
  - CC0 or self-made assets only in the public repo;
  - write failing checks first;
  - first-person poses are hand-authored with the user in live Blender, never computed and shown as final;
  - reference games, never copy a frame 1:1.
- **Humanoid figures.** The user has called past figures hideous. Spectres and revenants are humanoid, so they need special care (see "The four monsters").
- **Built from `main`.** Branch `hunt-combat`, cut from `main` (6ff04d0b). The `main-menu-overhaul` checkout is about 240 commits behind and has none of the revolver or spells.
- **What exists to build on:**
  - the revolver (`scripts/Combat/Revolver.gd`): LeMat cylinder plus a one-shell shotgun barrel, kick, hit-stop, GunFx, GunWisp;
  - the spells (`scripts/Magic/`): Blink, Shard, Ward, Empower, one PowerPool;
  - the player's 5 regenerating shields;
  - the guards' deep AI: calls, posture, moods, squads, gore;
  - ragdolls and dismemberment;
  - the Metro's ánimas (`scripts/Visual/Animas.gd`): black hands reaching out of a crown of chartreuse spirit-fire, tethered to drains, with tempers, voiced from monster_04 on the Souls bus;
  - the library spectres (`library_spectres.glb`).

## Approaches

The user was offered three ways to build this and picked the second.

1. **Layer by layer.** Every shared system first (bestiary, statuses, loadout, rounds, UI, movement), monsters after. A clean foundation, but nothing is fun for a long time, and the systems are designed without a monster to test them, so they get reworked.
2. **One hunt end to end, then widen.** *(Picked.)* A part zero fixes fight movement and weight. Then one complete hunt is built (clue, packing, fight), with only as much of each system as that hunt needs. After that, each new monster or variant brings its own answer and the systems grow with it. You play the whole loop early and judge the tempo on something real. The cost is that the first systems are narrow and get widened.
3. **Feel first, monsters after.** Polish fights against the existing guards first. The core feel would be solid, but guards are no longer the main enemy, so the tempo would be tuned for the wrong fight.

The user chose 2: "yeah let's do 2 first".

## The loop

1. **Learn.** A case points at a monster. You learn its nature from clues: a witness, a retablo, a page in the Librarian's shop, the marks it left. What you learn fills its bestiary page, including its weaknesses. *(Claude's call: the bestiary is pages in the Exsecrator's letter/notebook, using the letter UI that exists.)*
2. **Pack.** At a safe place you choose your loadout. Once you leave, it is locked until you return to a safe place.
3. **Hunt.** The fight. You switch between what you packed. Monsters push you to use the right answer.
4. **After.** What was used up is gone. Bodies and remains can be taken as materials or proof *(Claude's call: proof only in this program, no crafting economy yet)*.

## Part zero: fight movement and weight

**What was found on `main` (2026-11-01):**

- The dodge lives in `PlayerCombat._try_dodge()`. It only runs with a blade or bow in hand: `if not gun and weapon != null and q_pressed`. **With the revolver drawn, the main way of fighting now, there is no free dodge.** Q becomes Blink there: a tap is a 4 m step for 20 power (`Blink.STEP`, `Caster._update_blink`), and a hold aims.
- The dodge also needs the floor, and it shoves at 7.5 m/s for 0.22 s with a 0.35 s cooldown and 20 stamina.
- **There is no slide.** Crouch is Ctrl, sprint is Shift.
- What is wrong with strafing has not been measured yet.

**What part zero does:**

1. **A measured diagnosis first.** Build a scripted harness in the manner of `diag_moves` that runs each fight move (strafe at walk and sprint, dodge in each direction, slide, strafe while aiming, dodge out of a reload or a cast) and records speeds, distances, timings, the camera, and where input is lost. "Doesn't work" becomes a list of failures with numbers. Each failure gets a failing check, then a fix.
2. **A dodge with the gun.** It works with the revolver drawn, in any direction, and is answered by monsters as a real escape. *(Claude's call: on its own key, Left Alt, with Q left as Blink; the plan may settle another free key.)* The dodge keeps the gun up and can be cancelled into a shot late in its travel. It costs stamina, not power. Blink's tapped step stays as the powered escape: it goes farther, through things a dodge can't (a grab, a swoop), and it spends the power you need for spells *(Claude's call)*.
3. **A slide.** Crouch while sprinting starts a slide that carries the sprint's speed, lowers the head, and lets you shoot from it. It ends in a crouch or, with jump, in a hop. It goes under low obstacles and swoops. Sprint + crouch held is already "parkour down" in the free-run design (`2026-10-16-freerun-climbing-design.md`), so the slide must share that input: on open floor it slides, and at a ledge it climbs down as before *(Claude's call)*.
4. **Strafing.** Fixed from the diagnosis. The target feel is quick to start and quick to stop, with the gun steady. *(Claude's call: the walk is not slowed by drawing the gun; aiming down the sights slows it.)*
5. **Weight.** Building on the kept heavier recoil (`KICK_PUNCH` 2.1, the lunge, the recoil pose) and the Helsby camera rules (`fp-animation-principles`):
   - the hammer and the reload are paced so each shot is a choice;
   - casts commit you (you cannot dodge out of a tome cast);
   - big hits on monsters land with hit-stop and a body reaction scaled to the weapon.

## Tempo and stakes

*(Claude's call throughout; the user agreed the goals but not these mechanics.)*

- **The health model stays as it is.** Health is 100 split into 5 shields (`PlayerController.shields`, `_recover`). Getting away for 6 s refills the shield you are in. That is the release half of the rhythm. A shield lost whole stays lost. That is the stake. *(Claude's call: lost shields come back only at a safe place, or with a healing prep item later.)*
- **Pressing with the right answer pays.** Hitting a monster with its weakness:
  - staggers it hard (it is "exposed", the monster version of the guards' OPEN state);
  - refunds power from the pool;
  - lets a follow-up kill or banish it cleanly.
  *(Claude's call: the refund is added on top of the PowerPool's existing slow refill, which stays as it is everywhere. No separate "hunt mode" switches the rules, so the stealth levels, guard maps and existing suites keep their balance. Monsters make power matter by demanding it, not by a global retune.)*
- **The wrong answer costs.** Shooting a resisting monster wastes scarce rounds and tells you so: a ball passing through an ánima, a revenant shrugging off a hit and walking on. You still survive it, but it costs.
- **Scarcity.** Special rounds and prep items are few, and only refilled at a safe place. Plain lead is the fallback, never the answer.
- **Short beats.** Like Halo's encounters, a hunt is a few short fights with breathing room between them, not one long fight.
- **Dying and restocking** *(Claude's call; the user was asked and did not choose, so this is the default until corrected)*:
  - Leaving the kit table saves automatically. Dying in a hunt loads that save: you are back at the table with everything you packed, and you can re-pack with what you just learned. That is the Witcher half of the loop: fail, learn, prepare differently.
  - You can walk back to a safe place mid-hunt. There lost shields come back and the table restocks you from what you own. The walk is the cost, and what you killed stays dead.
  - Within a run, anything used stays used.

## The loadout

*(Claude's call on the counts; the user agreed to the shape.)*

- **No blades or bow in a hunt** *(Claude's call, from the user's "only your gun, and some spells, and some items")*. Melee in a hunt is the pistol-whip and the kick. Severing comes from shot and Empower. The sword and bow stay in the game for other places.
- **The revolver**, always. Pouches for **two or three round types** for the cylinder, plus shells for the shotgun barrel. Switching the cylinder's round type is a reload.
- **Three spells** on keys 1–3, chosen from those you know. Blink is innate and always yours, off the three.
- **Two or three prep items.** Consumables: a ward drawn on a doorway, oil worked into the rounds, a charm, an egg for a *limpia*.
- **One piece of protective gear**, worn. It changes what hurts you: a copal-smoked coat, a mirror-backed vest.
- **Packing** happens at a safe place: a kit table you can stand at, with the loadout laid out as physical objects. *(Claude's call: the first one sits in the hunt gym; the Metro's real safe place comes with the first real hunt.)*
- **In the field:** spells on the keys, prep items on a short wheel or a single key, round types on a reload. *(The plan settles the exact inputs.)*

## The bestiary

- Each **kind** has:
  - its weaknesses and resistances (by damage source and by status);
  - its brain;
  - its body or effect;
  - its sounds;
  - its bestiary page (the user's words).
- Each **variant** changes the kind's numbers, adds or removes a weakness or resistance, and adds **one trick**.
- **Damage sources** for this program:
  - lead (plain rounds);
  - shot (the shotgun barrel);
  - copal (copal-packed rounds, copal smoke);
  - fire;
  - obsidian (Shard, the mirror);
  - blows (the pistol-whip, the kick);
  - Empower.
  Later kinds add silver and others.
- **Brains are simple** *(Claude's call, from the Oct 23 rule "simpler AI unless human or really smart")*: hunt, swarm, keep distance, use the trick, flee or regroup. The guards' squad AI stays with men and with smart monsters later (the vampires).
- **Human enemies mix in** where a story wants it, for example cultists keeping revenants. They use the existing guard AI.

## Status effects

The first set *(Claude's call)*. Ammunition, spells, prep items and monsters all apply them, and monsters are weak or strong against them:

| Status | Cause | Effect |
|---|---|---|
| **Burning** | fire shells, braziers | damage over time; revenants cannot rise while burning |
| **Bleeding** | blades, shot, the existing system | the existing bleeding, extended to monsters with blood |
| **Smoked** | copal rounds, Ward, copal smoke | spirits are slowed and weakened inside it; eyes lose you |
| **Revealed** | obsidian: Shard, the mirror-flash | a spectre can be seen and hurt for a few seconds |
| **Exposed** | a weakness hit | the monster staggers and takes a finishing blow |
| **Evil eye** (on you) | a floating eye's gaze | your aim sways and your power refills slower; an egg *limpia* cleanses it |
| **Susto** (on you) | a spectre's touch | your next cast is broken; the edges of the view darken |
| **Grabbed** (on you) | an ánima's hands | held and drained; broken by a dodge, the Ward or a copal hit |

## The four monsters

Each gets **variants** from the start. Their causes and roles are Claude's proposals, which the user accepted ("Yes!"). Variant lists are *(Claude's call)*.

### Floating eyes

- **Cause:** *mal de ojo* made flesh. Envy that got loose after the Eclipse. Curanderas cleanse it with an egg.
- **Role:** the swarm. Fast packs that swoop and bite. Their gaze puts the evil eye on you.
- **Weak to:** shot, Shard, copal smoke.
- **Shrugs off:** single rounds. They are small and erratic, so they push you to switch barrels.
- **Look:** Terraria's Demon Eye as the idea, stylised into our register (Mignola and Deadlock chunky silhouettes, painted, a physical thing with a history), not a copy.
- **Variants:**
  - a plain swooper;
  - a weeping eye that leaves a blinding trail;
  - a swollen mother eye that births small ones.

### Aggressive ánimas

- **Cause:** souls in purgatory, the same ánimas as the Metro's drains, turned hungry.
- **Role:** the grabbers. They rush from drains and grilles in threes and fours and grab, draining health and power.
- **Weak to:** Ward (stops them cold), copal rounds, copal smoke.
- **Shrugs off:** plain lead, which passes through them.
- **Look:** builds on the existing ánima look (`Animas.gd`: black hands from a crown of chartreuse spirit-fire), grown into something that can reach you.
- **Variants:**
  - a beggar turned grasping;
  - a tethered lurker that drags you toward its drain;
  - a choir that shares damage between its hands.

### Spectres

- **Cause:** the séance dead, from Madero's registries. Kin of the library spectres.
- **Role:** the ambusher. Unseen until revealed. They strike through thin walls and cause *susto*.
- **Weak to:** obsidian (Shard, a new mirror-flash reveal). Once revealed, anything hurts them.
- **Shrugs off:** everything while unseen.
- **Look:** built in the manner of the library spectres, not as a modelled human figure.
- **Variants:**
  - a mourner that wails;
  - a clerk of the registry that marks you so others find you;
  - a drowned one that walks through water.
- **Needs** one new Obsidian power to reveal them *(Claude's call: a mirror-flash spell; or Shard reveals for a moment where it passes; the spectre hunt's own design settles which)*.

### Revenants

- **Cause:** the drowned of the old lakebed, raised by the seepage.
- **Role:** the tank. Slow, tough, relentless. They stand back up unless they are finished properly.
- **Weak to:** fire, severing limbs (shot, Empower).
- **Shrugs off:** ordinary rounds, which only stagger them.
- **Look:** the user: build them on the Quaternius guard models, "but make them be effectively creative, not just a drowned corpse skin, and make sure you don't have any odd sawed off topology. Let's work with what we have and edit from there, we need our monsters to look and feel good."
  - The base stays the guard body and rig, so ragdolls, dismemberment and bleeding work from day one. The mesh is **edited**, not just reskinned.
  - The silhouette must change, with a cause in the world. *(Claude's call, for the user to react to one piece at a time:)* a hunched, wrong-shouldered stance from years under the lakebed; arms lengthened by the weight of the water; tezontle and lake-crust grown over one shoulder like a shell; milagros and ex-votos the living nailed into them to keep them down; a uniform or a Sunday suit rotted into the skin, from whoever they were.
  - See "How monsters must look and feel" for the topology rule.
- **Variants:**
  - a plain drowned one;
  - one bound in chains that cannot be severed until the chains break;
  - a bloated one that bursts into a cloud when killed.

## How monsters must look and feel

The user: "we need our monsters to look and feel good." This is a gate on every monster and variant, before it is shown:

- **No sawed-off topology.** No open cuts, no hard planar slices where a piece was chopped off a base mesh, no holes. Anything removed from a base model is closed and blended into the form. Severed limbs and stumps from the dismemberment system are capped and painted too. Check with the hole scan and with close-up renders of every joint (`inspect-geometry-closely`, `finished-means-meticulous`). Past lesson: the neck seam (`common.NECK_CUT`) and the shell clipping (`npc-models-high-quality`).
- **Rig kept working.** Mesh edits keep skin weights valid, so the existing clips, ragdolls and limb cuts still run without stretching.
- **Creative, not a texture swap.** Each kind and variant has its own silhouette, readable at fight distance, and it follows the aesthetic checklist (`aesthetic-checklist-for-models`).
- **Feel.** Movement, hit reactions, deaths and sounds are part of "good". A monster is not finished until it is judged in a fight in the gym.

## Round types, prep items and gear for the first hunts

*(Claude's call; every name is a stand-in for the user's words)*

- **Rounds:**
  - **lead**, the existing round;
  - **copal-packed rounds**, for spirits and eyes;
  - **fire shells** for the shotgun barrel, tallow and pitch, for revenants.
- **Prep items:**
  - **an egg for a limpia**, which cleanses the evil eye;
  - **a copal doorway ward**, a line ánimas cannot cross;
  - **a lamp oil flask**, thrown to set a revenant or a pool burning.
- **Gear:**
  - **a copal-smoked coat**, which weakens the ánimas' grab;
  - **a mirror-backed vest**, which shows spectres near you.

## The first hunt

- **Where:** a hunt gym first (a test map in the manner of `npc_gym`, with bays per monster and per variant, a kit table, and F-key resets). Then the first real hunt in the Metro *(Claude's call)*: a new space of its own off the existing Metro (a flooded cistern or service run) with its own hungry drains. The begging ánimas already played stay as they are. The hostile ánimas extend `Animas.gd`'s look and tethering, not its begging behaviour.
- **What:** floating eyes and aggressive ánimas, closed by a revenant. That tests the shotgun barrel, the Ward, copal and fire at once. The revenant is edited from the guard models, as the user decided.
- **The spectres** come in the next hunt, with their reveal power, so their humanoid look can be done with care.
- **The clue** for the first hunt is a stand-in readable until the user writes its words.

## The combat UI

"A mix of both": part on the Exsecrator's body and gun, part painted. The current `AmmoReadout.gd` and the stealth HUD's combat pieces are replaced. *(Claude's call on how, from the art direction: Mignola and Deadlock, the talk box's painted language, the user's paintings.)*

- **On the gun and hands:**
  - the cylinder seen at a reload or a check (the Tab check exists), with each round type's casing a different colour;
  - the shotgun barrel's state on the hammer's nose;
  - the power pool in the left hand's veins and ink;
  - evil eye, susto and grabbed shown on the hands and the view, not as icons.
- **Painted:**
  - shields as brushed ink at the frame's edge that bleeds in as you lose them;
  - prep items and the current round type as small painted marks in the talk box's paint language;
  - the bestiary page in the letter.
- **Hit feedback:** a weakness hit reads differently from a resisted one, in sound first and then in a mark.
- Judged as stills from the real game, never over a mock backdrop.

## Testing

- Each part starts with failing checks.
- Part zero has the movement diagnosis harness.
- Each monster and variant has a suite: weaknesses, resistances, statuses, trick, death.
- The hunt gym is the playground for the user's verdicts.
- Feel is judged by the user's play.
- Headless suites run under `--fixed-fps` (`headless-test-determinism`).

## Order of parts

1. **Part zero:** the movement diagnosis, the dodge with the gun, the slide, strafing, weight.
2. **The spine:** bestiary data, damage sources, statuses, the tempo rules (exposed, power refund, scarcity), the loadout and the kit table, the hunt gym.
3. **Floating eyes, plain variant,** with copal rounds and the egg. **The first playable loop:** clue, kit table, fight, in the gym. The user judges the tempo here, before anything widens.
4. **Aggressive ánimas, plain variant,** with the Ward's new role, the doorway ward and the coat.
5. **Revenants, plain variant,** with fire shells, the oil flask and severing.
6. **The first hunt,** in its Metro space, with the three plain kinds.
7. **The variants** of eyes, ánimas and revenants, one at a time.
8. **Spectres** and their variants, with the reveal power and the vest. This is the second hunt.

**The combat UI** is built through 3–6 as each piece needs it, then finished as a whole.

Art for each monster runs one model at a time with the user, beside the code, which uses stand-ins until each model is approved.

## Left to the builder

- Exact numbers: damage, health, speeds, timings, costs, counts.
- The exact keys for the dodge, the prep items and round switching, within the shape above.
- How the bestiary data is stored (a `Spells.gd`-style table or resources).
- How the monster brains are structured, as long as they stay simple and reuse navigation, SoundBus and the gore path.
