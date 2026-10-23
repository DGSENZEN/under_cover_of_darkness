# The revolver and the first spells

Brainstormed with the user on 2026-10-23. This is project 2 of the demo program (`2026-10-16-mexico-city-demo-program.md`, "Powers and magic") with the ranged half of project 3 folded in. Lines marked *(Claude's call)* were proposed by Claude and not corrected. The user said "sounds good" to the controls and the guard reactions; everything else unmarked is the user's.

## Intent

The game is no longer stealth-first: it is a **thriller-adventure immersive sim**. The Prosecutor fights with **a revolver in the right hand and magic in the left**. Melee stays but is **"mostly situational"**: it leaves the centre of fights.

The revolver should feel like **Hellboy's revolver** (the Samaritan): oversized, heavy, a hard kick, few big rounds, every shot an event. It **switches between a single shot and a shotgun**, and the shotgun fires from **a separate barrel**.

Spells come in tiers. **The more powerful the spell, the harder it is to cast, and harder means it takes more time.**

The gun and the spells drive **the gore system we have built** (ragdolls, kick knockdowns, dismemberment, bleeding, splatter), plus **gibbing**. This overturns the Oct 7 note "without gruesome combat".

## Goals

1. Three ways to hold your hands, chosen in play:
   - **revolver + tome**: tome spells and innate spells;
   - **revolver + bare casting hand**: hand spells and innate spells;
   - **revolver alone**: both hands on the gun, innate spells only.
   - Without the gun, **with an empty hand**, the Prosecutor casts innate spells ("cantrips").
   - **Innate movement spells can be cast from anywhere**: while hanging, climbing, carrying, holding the sword or in the air.
2. A revolver built after the **LeMat** (a real 1850s–1900s revolver with a nine-shot cylinder around a single-shot shotgun barrel, the barrel picked by flipping the hammer's nose), scaled up to Samaritan heft.
3. The four starting spells from the program, sorted into the user's tiers:

| Spell | School | Tier | Needs | Cast time |
|---|---|---|---|---|
| Blink | Obsidian | Innate (a cantrip; movement, so from anywhere) | No hand | Instant |
| Shard | Obsidian | Hand | The bare left hand; a magic circle forms | Short |
| Ward | Copal | Hand | The bare left hand; a magic circle forms | Short |
| Empower | Nahual | Tome | The tome open in the left hand | Long |

4. Bullets, shot, shards and empowered blows feed the existing gore path; gibbing is new.
5. The guards we already have react to a gun.

## Non-goals (this project)

- **New enemies.** The user wants creatures and spirits, and people if needed, with simpler AI unless they are human or really smart creatures, but "for now, let's just do the enemies we already have". The design must not block them (see "Later").
- Other schools (Séance, Lumen, Relic) and learning spells from practitioners.
- The semi-auto pistol and the shotgun from the user's stance list.
- Removing the sword system. It stays in the code, selectable from the belt, off the main fight loop *(Claude's call)*.

## Anti-goals

The user wasn't asked about these; they are *Claude's call*, drawn from the standing rules:

- A generic shooter: fast fire, light guns, spells used as more bullets. The kick, the slow settle and the cast times exist to stop this.
- Glowing runes for their own sake. Every strange thing has a cause in the world.
- Computed hand poses shown as final. The user rejected computed grips on Oct 17.

## Constraints

- **Standing rules:**
  - models are built one at a time under the user's supervision;
  - no free VFX assets: we make our own;
  - every strange thing has a cause;
  - never call a visual defect harmless;
  - the user writes all words;
  - CC0 or self-made assets only in the public repo.
- **Hands.**
  - Grips and stances are posed with the user in live Blender (`fp_arms_posing.blend`). The code uses stand-in poses until then.
  - Wrist rule: the hand continues the forearm, with at most about 20° of bend and never a twist. Aim the prop by moving the grip and the elbow pole.
  - The viewmodel draws at `ViewArms.VIEW_FOV` 58 with the new FP arms (`FPArms.gd`, F12).
- **Sound.** No procedural audio. The user sources gun sounds:
  - two shots, one per barrel;
  - the hammer cock;
  - the nose flip;
  - the loading-gate open and close;
  - a round dropped into a chamber;
  - a shell in the lower barrel;
  - empty clicks;
  - the shard's glass and the ward's smoke.

  Stand-ins come from the existing packs through `tools/prepare_sfx.py` until then.
- **Tests.** The suites must run headless and frame-exact under `--fixed-fps` (see the determinism notes). No unseeded random draws in anything a test checks.

## Approaches considered

- **A. Two hands as two systems.** A new `Revolver` node owns the right hand and a new `Caster` owns the left. Each keeps its own state and both deliver hits through `Guard.take_hit`. `PlayerCombat` keeps the kick and the melee.
  - Costs more new code up front.
  - It is the only option where casting while the gun settles works cleanly, and it leaves the 2,357-line `PlayerCombat.gd` alone.
- **B. Grow `PlayerCombat`.** Add `Kind.REVOLVER` next to `MELEE` and `BOW`, and add spells as more phases.
  - Gets the first shot in fastest.
  - But `PlayerCombat` is one phase machine, and two hands acting at once would mean a second parallel state bolted onto the biggest file in the project.
- **C. A throwaway feel spike first, then A.**
  - Cheap insurance on "does it feel like Hellboy".

**Chosen: A** (the user: "two hands as two systems seems like the way"). The feel is tuned in the gym once the real thing runs.

## Parts, in build order *(order: Claude's call)*

1. The two-hand frame and the revolver, on a stand-in block gun.
2. The caster and the power pool, with Blink and Shard.
3. Ward, the tome and Empower.
4. Guards reacting to guns.
5. Gibbing.

Alongside, each supervised one at a time:

- **Art A:** the revolver model.
- **Art B:** the hand poses, in live Blender: revolver one-handed, two-handed grip, bare casting hand, tome.
- **Art C:** the Obsidian and Copal circles, built in the effects lab.

### 1. The two-hand frame and the revolver

**Who owns what**

- The revolver is a belt weapon (mouse wheel) like the sword and the bow.
- While it is drawn, `Revolver` owns the right hand and `PlayerCombat` stands down, except for the kick.
- `Caster` is always on, not part of the revolver.
  - It casts innate spells in every state. Innate movement spells (Blink) work while hanging, climbing, carrying, with the sword or empty hands, and in the air.
  - Other innate spells need at least one free hand: empty hands or the gun drawn.
  - It owns the left hand, with the tome or the circle, only while the revolver is drawn. Hand and tome spells are cast from the revolver setups. *(Claude's reading of "with an empty hand (innate ones or cantrips)"; the user to confirm on review.)*
- While hanging or climbing, the revolver is holstered (both hands are on holds), and it comes back when you stand.
- Left-hand jobs that exist today (a pickup, turning a key, the purse, reading a page; `HandSlot` queues them) lower the tome or the circle, do the job, and return. A cast in progress is cancelled at no cost *(Claude's call)*.

**Controls** (approved: "sounds good")

| Input | While the revolver is drawn |
|---|---|
| Left mouse (`throw`) | Fire the selected barrel |
| Right mouse (`block`) | Cast the left hand's spell. Hand and tome spells finish while it is held; letting go early cancels the cast at no cost |
| Blink key | Blink, from any grip |
| Barrel key | Flip the hammer nose: cylinder ↔ shot barrel |
| R | Reload |
| 1 / 2 / 3 | Pick Shard, Ward or Empower. Picking a spell sets the left hand (1–2 bare hand, 3 tome) |
| Grip key | Both hands on the gun; picking a spell again lets go |
| F (`kick`) | Kick. With a guard in arm's reach in front, a pistol-whip *(Claude's call)* |

- Key choices *(Claude's call, the user to confirm on review)*:
  - **Blink on Q**, which replaces the dodge while the revolver is drawn: Blink is the gun's dodge.
  - **The barrel flip on X**, the grip on G.
- Changing grip takes about 0.4 s and blocks firing *(Claude's call)*.
- New input actions go in `project.godot` (`reload`, `blink`, `barrel`, `grip`, `spell_1..3`).

**The gun** (all numbers are starting values to tune in the gym, *Claude's call*)

- **Barrels.**
  - Cylinder: 6 big rounds. The LeMat's nine is cut to six so every shot counts.
  - Shot barrel: 1 shell.
  - Each barrel keeps its own count.
- **Bullets.**
  - Hitscan along a ray from the eye, with a small kick-driven spread for the one-handed grip.
  - Body 55, head ×2.5 (the bow's multiplier). A guard has 100 health: two to the body, one to the head.
  - New `take_hit` kind `bullet`. A raised sword does not block it, as with arrows.
  - Bullets do not go through anything.
  - Props take impulses as they do from melee.
- **Shot.**
  - 9 pellets in a cone about 8° wide, 18 each, falling off from 3 m to nothing by 12 m. New kind `shot`.
  - A point-blank shot (most pellets on one man, inside about 2 m) is handled as a `blast`. `Guard` already tears limbs off with a blast (`_torn_by_blast`); part 5 makes this the gibbing case.
- **Kick and settle.**
  - One-handed: a hard camera jolt and the barrel climbing, then a slow settle; the next shot is ready after about 0.6 s. The settle is the window to cast in.
  - Two-handed: about half the jolt, ready after about 0.35 s.
  - The shot barrel kicks harder than the cylinder.
- **Hit-stop and light.**
  - A small hit-stop on a hit through `TimeFx`.
  - The muzzle flash is a short `Fx.flash`, which also lights the player's exposure for that moment.
  - Smoke from the muzzle, made in house.
- **Reload.**
  - **Cylinder:** opening the loading gate, then one round at a time, about 0.45 s each. Firing is allowed between rounds: the reload stops, the gate snaps shut, and the shot goes.
  - **Shot barrel:** its own slower load, about 1.1 s.
  - **R reloads** whichever barrel is selected.
- **Ammunition.**
  - Carried rounds and shells are stocks, as arrows are (starting stock 24 rounds and 4 shells).
  - They are found as loot in the world.
  - There is no ammo HUD: you see the chambers when the gate opens. The existing Tab check also shows the cylinder in the hand.
- **Noise.** Every shot goes out on the SoundBus loud enough to carry across a block, so guards in range hear it. The shot barrel is louder.
- **Model.**
  - A stand-in block gun until Art A. It has the grip at the origin like the other weapon meshes, a gate, a nose and a cylinder that turns with each shot.
  - The cylinder turning, the hammer and the gate are animated in code. They are separate pieces of the model.

### 2. The caster and the power pool

**The pool**

- One shared pool of 100 *(from the program, Claude's call)*.
- It refills slowly, about 5 a second, once 2 s have passed since the last cast *(numbers: Claude's call)*.
- Costs: Blink 20, Shard 15, Ward 35, Empower 50.
- The cost is paid when the cast completes.
- The HUD shows the pool as a thin code-built arc by the crosshair, in the manner of the stamina arc. It fades out when full *(Claude's call)*.

**Cast times**

| Tier | Time | What happens |
|---|---|---|
| Innate | Instant | Fires on the press |
| Hand | About 0.4 s | The circle closes |
| Tome | About 1.2 s | The pages turn and the words are said (the user writes them) |

- A hard hit breaks a tome cast in progress: a `power`, `blast` or `crush` blow, or one doing 25 or more damage.
- A broken cast costs nothing but the time *(Claude's call)*.

**The magic circle**

- A hand spell's circle is made of its school's own matter, so it has a cause *(Claude's call)*:
  - **Obsidian:** a ring of black glass splinters that hang and turn in front of the palm;
  - **Copal:** a ring of smoke drawn by the fingers.
- It shows in the viewmodel only. Guards see the effect, not the circle.

**Blink (innate)**

- **Tap** for an instant short step, about 4 m along the way you are moving (straight ahead if still). This is the gun's dodge, so it fires on the press, as an innate spell should.
- **Hold** to aim, release to step. The aim mark is a hairline glint where you will arrive, with a range of about 10 m. Time does not slow while aiming. Right mouse cancels the aim at no cost.
- The 20 is paid on arrival *(tap/hold split: Claude's call)*.
- You vanish in a mirror-flash and reappear.
- It needs a clear line: no passing through walls, glass or people.
- If the mark is on a ledge's lip or a hold, you arrive hanging or mantling through the free-run moves (`HandContacts`), so Blink is part of climbing.
- It works in the air.

**Shard (hand)**

- After the circle, a glass shard flies straight and very fast, with arrow-style ballistics (a per-step ray, as in `Arrow.gd`).
- 40 damage, new kind `shard`: it cuts, so it bleeds, and on a limb it can sever.
- It breaks into glass dust on stone.
- It is quiet next to the gun: a hiss and a crack where it lands.

### 3. Ward, the tome and Empower

**Ward (hand)**

- After the circle, a **ring of ghostly smoke** (copal) about 2 m across rises around you. It hangs for about 4 s, moving with you *(duration and following: Claude's call)*.
- It **covers you from other spells and bullets, but not from melee**.
  - Shots and spells coming in from outside stop at the ring: guards' arrows today, enemy guns and spells later. Arrows count as bullets here *(Claude's call)*.
  - Melee blows pass, and so do men: guards walk straight through it.
  - Your own shots and spells go out freely *(Claude's call)*.
  - It does not block sight.
- It is the shape spirits will not cross later.

**The tome**

- One tome, carried open in the left hand while selected, a stand-in model until it is built with the user.
- Tome spells cast only from it.
- The bare hand's spells need the bare hand. So with the tome out, Shard and Ward are one spell-key away, and the left hand changes over during the cast.

**Empower (tome)**

- After the pages, about 8 s of beast strength for the next blow, jump or blink, as the program says.
  - The next kick or pistol-whip is ×3 and throws men bodily, as a blast does.
  - The next jump goes twice as high.
  - The next Blink goes twice as far.
- *(Claude's call, flagged for the user)*: because the revolver is now the main weapon, the next shot also counts as empowered.
  - An empowered bullet hits as a `blast`: it throws the man and may tear a limb, through the existing blast tearing. It does not gib.
  - An empowered shell gibs inside 6 m.
- **One charge** *(Claude's call)*: the first of blow, shot, jump or blink spends it. A jump spends it only if the jump key is held past 0.2 s, so a stray hop doesn't waste it. If nothing uses it within 8 s, it fades.

### 4. Guards reacting to guns

These go inside the current guard brain, with no new AI. The user approved them as a direction ("sounds good").

- **The squad reads the gun.** `Squad.read` gains `gun` next to `bow`.
  - It grows with each shot fired at or near the squad's men (a hit, or a bullet passing within the near-miss range), not from the gun merely being drawn. It decays like the other reads. *(Claude's call)*
  - It does not trigger `rush` alone. At range, gun pressure sends men to cover first.
  - `rush` follows when the player reloads, when the shot barrel is spent, or when the men are within about 8 m. So a firefight goes cover, then a rush at the reload.
- **Rushing.** Within about 8 m, a guard rushes you when you are reloading or the shot barrel is spent.
- **Melee calls with the gun drawn** *(Claude's call)*. A guard's telegraphed blows (GuardFighter CALLS) still need answers:
  - Blink counts as the "dodged" answer.
  - The Ward does not stop melee, so it is no answer to a blow.
  - The kick still interrupts.
  - Melee guards stay dangerous up close; the shotgun and Blink are the answers.
- **Cover.** At range, a guard who has been shot at moves to cover before closing. Guards cannot take cover today: their vision only measures cover.
  - Cover is new and small: a navmesh point near him that the player's eye can't see (`SightRay`), found from the existing search spots or a few sampled points.
  - He leaves it to rush when you reload.
- **Near misses.** A bullet passing within about 1.5 m makes a guard flinch and shakes his nerve (`Temperament`/morale), even if it misses.
- **Hearing.** A gunshot counts as a shout-level sound: it pulls guards from beyond the block.

### 5. Gibbing

Today a `blast` tears off up to three limbs and maybe the head. Gibbing is a body bursting:

- **When:** a point-blank shell (part 1), an empowered shell inside 6 m, an empowered kick or pistol-whip that kills. It is rare, so it lands *(Claude's call)*. An empowered bullet does not gib.
- **Gore pieces:** code-built stand-ins first. The real pieces become a fourth supervised art track (Art D), one at a time *(Claude's call)*.
- **What:**
  - the limbs and the head go as physics chunks, through `GuardRig.sever` and the ragdoll, around a torso that stays whole but opened (wound decals, gore spray). A torso split is wanted, but later (see "Later");
  - gore pieces, made in house;
  - a burst of `Fx.blood` and stains on the floor and walls around.
- **Witnesses:** the existing "cut apart in front of his friends" response applies, more strongly.
- **Budget:** chunks and stains count against the existing `Fx` limits; old chunks sleep and fade.

## Tests and the gym

- **New suites** `tests/revolver_test` and `tests/caster_test`, headless, in the house style (numbered checks). They cover:
  - each barrel's count;
  - reload interrupted by a shot;
  - grip changes blocking fire;
  - headshot ×2.5;
  - pellets falling off with range;
  - a blast at point-blank;
  - cast times per tier;
  - a hard hit breaking a tome cast;
  - pool cost paid on completion only;
  - Blink stopped by a wall;
  - Blink onto a lip ending in a hang;
  - a shard severing;
  - a ward stopping an arrow but not a blow, and the player's own shot leaving it;
  - Blink cast while hanging and with empty hands;
  - empowered effects used once;
  - guards rushing a reloading player;
  - guards taking cover after a near miss;
  - a gib producing chunks.
- **Existing suites** must stay green: combat, squad, gym, bodies, feel, fp_arms, freerun and the rest.
- **The gym.** `maps/combat_gym.tscn` gets a range bay: targets at 5, 15 and 30 m, a squad to fight, and a dummy wall for spread. The user plays it to tune the feel *(Claude's call)*.

## Later (not this project, must not be blocked)

- **Spells as data.** Spells are entries with school, tier, cost and cast time, so Séance, Lumen and Relic spells drop in, and practitioner side quests can unlock them.
- **Creatures and spirits.** They take `take_hit` the same way, with simpler brains. A spirit can choose to ignore plain bullets later (a `kind` check), which leaves room for a rule like "plain lead doesn't hurt the dead".
- **The pistol and the shotgun** from the stance list reuse `Revolver`'s frame as other right-hand weapons.
- **The torso split** (the user: "yeah for the torso split but not right now"). This is new mesh-cutting work: `Humanoid.SEVERABLE` has only the neck, arms and legs. Part 5's gibbing must leave room for it.

## Left to the builder

- **File layout.** `scripts/Combat/Revolver.gd` and `scripts/Combat/Caster.gd` (or `scripts/Magic/`), plus a small `PowerPool`, all created by the player controller as `Combat` is.
- **`take_hit` for the new kinds.** How `bullet`, `shot` and `shard` map onto stagger strength, posture and wounds inside `Guard.take_hit`. Follow how `arrow` is handled.
- **The stand-in meshes and stand-in poses**, until Art A and Art B.
- **The exact feel numbers,** tuned with the user in the gym.

## Where the gear is

- The revolver, the tome and ammo loot are placed in the combat gym only for this project, so suites that assume what is on the belt (zocalo and others) are unchanged.
- Placing them in the Zócalo and Metro comes with the content work.

*(Claude's call)*

## Branch

- The work goes on a new branch, `revolver-magic`, cut from `free-run` at its last commit, because the new FP arms live there *(Claude's call)*.
- `free-run`'s uncommitted edits and the untracked `fp_arms_posing.blend` stay where they are, for the user to commit.
- Blink-to-hang is the last step of part 2, so it builds on the climbing code once that settles.
