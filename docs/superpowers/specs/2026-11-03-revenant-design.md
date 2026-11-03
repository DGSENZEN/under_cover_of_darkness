# The revenant

## Why

The eye and the ánimas die once and stay dead. The revenant is the first monster you can put down and still not be rid of, so the hunt turns on what you packed before you left: fire, or nothing that ends it. It is the tank the hunt design promised (`docs/superpowers/specs/2026-11-01-hunt-combat-design.md`), and the next step after the mouth in "test each new enemy alone before mixing".

Its cause in the world: the drowned of the old lakebed, raised by the seepage ([[world-built-by-its-events]]). It stays `revenant` in code. Nothing on screen names it.

## What the user decided

**Keeping it dead.** "use a fire shell or have a brazier equipped and melee it with it to keep it dead".

**The brazier.** "with the brazier it's easier to kill, and more vulnerable". "you put the gun away, we can have the brazier be like a morning star like castlevania that allows ranged combat and close hits".

**What it does to you.** "should basically be a two touch monster, it can swipe you and rake you and deals great damage too, making it harder for yourself to heal and regen your stamina, but if it gets you with it's two touch, basically one being a grasp, the second one is a possession or just straight up getting killed". Possession is "how you die to it": there is no surviving it and fighting back.

**How it looks.** "their silhoutte reads wrong, elongated, large, undead, skin bloated from being a being that comes from the water but it isn't something that is able to rest, something vengeful and old, dangerous and aggressive".

**How it is built.** Its own rig, as the mouth has (see Approaches).

**From Claude's proposals, the user's picks:**
- It closes on you in surges: it walks heavily, then throws itself forward, and its arms keep after you through a wind-up.
- The fire shell is the finisher: little damage to one standing, and it ends one that is down.
- "More vulnerable" means a brazier hit sears it: it staggers, its wind-up breaks, and it takes double from everything for a few seconds.
- Fire shells take the round place copal uses, so you carry copal or fire. The brazier takes one of the two item places.

**On the first body, the user:** "It's a good first start, but it needs glowy eyes, some more details that make it look more of a spectre or a supernatural being not just an undead, and the texture work and shading needs to be in tune with our aesthetic work". Claude's answer, for the user to judge: it never left the lake. Its eyes burn phosphor green, the colour of the seeped; the seep lights a split down its chest and the cracks round what holds it; the water's light crawls on it and black water runs up it; its hair, roots and rags drift as if under water; and it stands in a pool of black water that isn't on the floor. Fill and rim set as the ánimas' flesh is.

## Goals

- It reads wrong from across a dark room, on shape alone.
- Going down is not the end, and you know it: the moment it drops is a decision, and it pays you for packing fire.
- Every moment in its reach is tense: a swipe hurts, a grasp marks you, and a second grasp ends you.
- You always knew: the first touch is on you, plainly felt, until you deal with it.
- The brazier feels like the heaviest thing you've swung, and taking it out is a commitment.

## Non-goals

- Variants: the chained and bursting ones come later. Bloat is now its base look, not a variant.
- Mixing it into the mixed gym's waves, until the user has played it alone.
- Severing limbs and physics ragdolls: the own rig gives them up. A hit limb can be acted, a limb can't come off in this build.
- Squad tactics: a simple brain, as the hunt design says.
- A burning status for other monsters beyond what a hit from fire already does to them.

## Anti-goals

- A corpse skin, or a sad drowned man. It is old, vengeful and coming at you.
- A modelled human figure ([[no-modelled-human-figures]]). The wrong shape is the point.
- Sawed-off topology or anything stuck on ([[monsters-look-and-feel-good]], [[connected-topology-details-make-sense]]).
- A kill out of nowhere: a second touch must never surprise you.
- A status drawn as a diagram: what it does to you is felt in your sight, not shown as ribbons or an icon that explains it, and no faces in the screen effect.
- A status ending that is literal: it dispels lowkey and clean.
- Anything on screen in words of ours. Stand-in names go on `docs/superpowers/refs/hunt/words_needed.md`.
- Archetype transitions used casually ([[archetype-effects-not-casual]]).

## How the fight goes

Numbers are Claude's first go, all in `Bestiary` under a new `&"revenant"` row, to be tuned in play. (For scale: you have 100 health in 5 shields, a ball does 55, a shell's 9 pellets 18 each, a whip 20.)

**Coming at you.** About 2.6 m tall, walking at 1.6 m/s with long heavy steps, never stopping and never fleeing. Claude's call: being hit doesn't turn it aside. Lead makes it flinch and no more.

**Surges.** Further from you than it can reach, every 4 to 7 s, it gathers for 0.5 s, a tell you can read, then throws itself forward at about 6 m/s for 0.9 s, long lurching strides, and can go straight from that into an attack. (You walk at 6.5 m/s, 4.55 aiming, 8.5 sprinting: you can get away from one, but not while you aim.) Through a wind-up its arm keeps reaching after you and it leans and steps with it, so backing away at a walk doesn't beat an attack: a dodge, a blink or a sprint does.

**What hurts it** (health 180):

| Source | Scale | Read |
|---|---|---|
| Fire (fire shell, brazier) | 1.0, neither weak nor resisted | sets it burning; the damage is in what fired it |
| Lead, copal | 0.3 | a flinch, and eleven balls to put it down: you spent your rounds finding out |
| A plain shell | 0.5 | up close, it goes down in about three |
| Whip, boot | as they are | shoves it a little, no more |
| Spells | as they are | Blink escapes it, Burst throws it, Shard hurts it |

Claude's call: it is a body, not a spirit, so the Ward and a copal line do not stop it, and copal smoke does not slow it. What held the others won't hold this. The egg does nothing for its touch.

**Going down.** When its health runs out and it isn't burning, it falls, an acted fall on its own rig. It lies there 5 s, then rises over 1.6 s, and comes on with 40% of its health. It does this as many times as you let it. Hits from anything but fire do nothing while it is down.

**Fire.** A hit from fire leaves it burning for 5 s, 8 health a second. Burning doesn't stop it coming. If its health runs out while it burns, or fire touches it while it is down or rising, it is finished: it dies for good, in fire, in one of its acted deaths, and it never rises. Finishing it pays the power refund once (`Monster._pay_back`): that is your pay for packing right. Claude's call: fire is not in the row's `weak` table, or a shell's first pellet would expose it for the rest and kill it standing. A hit from fire during its grasp's wind-up breaks the grasp, through `_is_opening_to`, with all that gets you. Nothing else but the brazier breaks a wind-up.

**Its attacks.**
- **Swipe:** one long arm, reach 2.4 m, 0.7 s wind-up, 25 damage.
- **Rake:** both arms, a wider sweep, reach 2.2 m, 1.0 s wind-up, 35 damage.
- **Grasp:** reach 3.0 m, 1.1 s wind-up, its own unmistakable tell, unlike the other two: you learn to tell them apart, because you can take a swipe but must dodge a grasp. It can be dodged or blinked away from, as a leap can.

**Soaked** (a new status on you; Claude's name in code). Each swipe or rake that lands: for 8 s your current shield doesn't refill and stamina comes back at 40%, as lake water in the lungs. It's felt in your sight, cold and wet at the edges, and different from the curse, which slows magic and movement. A new hit starts the 8 s again. It ends lowkey.

**The first touch.** A grasp that lands on you with no touch on you: 5 damage, and it holds you up to 1 s, then shoves you away. A whip or a brazier hit frees you sooner. From that moment **the touch is on you**, for good: cold in your sight, always, as the mouth at three is always plain. No words. It stays until the revenant that laid it dies for good, or you leave the hunt (`SafePlace`), or you die. Claude's call: only burning that one clears it, so the touch tells you who to go for. That revenant going down and getting back up doesn't clear it. You can see which it is: its eyes burn brighter than the others', from then on, across a dark room.

**The second touch.** A grasp that lands while any touch is on you, from any revenant: you die there and then, no hold and no more control. Swipes and rakes never do this, only the grasp. `player.invulnerable` holds, as the game's other kills go. Claude's call: for 1.5 s after a hold ends a grasp only shoves you, so a second revenant can't kill you the moment the first lets go.

**Possession.** A new `PlayerDeath` kind, about 3.5 s, first person, in the same director as the rest. Your hands stop being yours: the arm and gun move on their own, your body turns without you and walks a step or two, then you go down and the quote comes as for the others. Its exact poses are made with the user (see Constraints). Which quotes it draws is the user's to say (`DeathQuotes.FOR`); until they do, it draws the ánimas' as `&"mouth"` does.

## The fire shell

The finisher. A new load for the revolver's shot barrel (`&"shells"`): a fire shell, its 9 pellets counting as `&"fire"` (hit kind `&"fire"` in `Bestiary.source_of`, which exists), any that land setting a monster burning. They do 5 each, not a plain shell's 18, so at most 45 and the burn's 40 to one standing: it doesn't end a fresh revenant, and you still have to put it down. On one that is down, any pellet ends it. Same falloff as a shell. It carries few: 4 at most (`Loadout.CARRY`), 12 owned to start.

It takes the round place copal uses (`Loadout.MAX_ROUND_TYPES`: lead and one other), so a pack has copal or fire, not both, and it is laid on the kit table as a round. Plain shells still always come. Claude's call: with fire packed, the barrel loads fire shells before plain ones, with no extra key. Each reads at a glance as the rounds do: its own tracer and impact, hot and orange. Against everything else it counts as fire too: the Bestiary's rows give it what they give, with nothing new added for it.

## The brazier

An iron church censer on a chain, the swinging kind, packed with coals rather than incense, because that is what people on the old lakebed learned keeps the drowned down (Claude's call on its cause and form; the user's is a brazier that swings like a morning star). A new `Weapon` resource (`&"brazier"`, `Kind.MELEE`) through `PlayerCombat`, taken out and put away by the way a weapon is chosen now (`current_weapon()`), since that is already "the gun put away". It's packed at the kit table, in one of the two item places (`Loadout.MAX_ITEM_KINDS`), so it goes beside the egg or the copal line and leaves you copal. It isn't used through V or cycled with B. No fuel in this build: it costs that place, the time to change hands, and having no gun while it's out.

Claude's calls, as the blade is today: a spell key takes the gun back out at once (`Caster._press_key`), and a tapped Q dodges rather than blinks (`Caster._dodges_instead`); the whip needs the gun, so with the brazier out the kick key is the boot. Which hands are on it is settled in the grip session with the user.

- **Long lash:** out along your aim to about 5 m, landing where you aimed, with a clear wind-up (about 0.45 s) and an open moment while it comes back. 45 damage. As Castlevania's whip does: reach you can trust, a commitment if you miss.
- **Close hit:** a short, heavy swing, reach about 2.4 m, quicker to land, 70 damage. Claude's call: the lash is the plain attack and the close hit the heavy one, on the keys the blade uses for those.
- **Both** count as fire to a revenant: they set it burning, and one on a downed revenant finishes it.
- **Both sear it:** it staggers, any wind-up breaks, and for 3 s it takes double from everything, a new hit starting the 3 s again. That is the user's "more vulnerable": seared, a lash does 90 and a close hit 140, so a few hits put it down, and the one after finishes it. Seared shows on its flesh, hot and scored. (Claude's numbers.)
- **On others:** an ordinary blow, no weakness. You still want the gun for the eye.
- **Blocking:** it can't block (`can_block` false).

The brazier's chain and head are simulated enough to feel heavy and to lag your swing, in the first-person animation principles ([[fp-animation-principles]]). Its coals light what's near it, and it throws sparks and hot embers of our own making at each hit.

## How it looks

The user's words above are the bar. Claude's first go, for the user to react to on screen, piece by piece:

- **Too long:** long arms and long legs for its body, a long neck hung forward, shoulders wrong for each other. Standing, its hands come down past its knees.
- **Bloated:** skin swollen tight over a long frame, as from long under water, the flesh pulling and folding at the joints. Pale, cold and wet, with the dark of old lake silt in the folds, in the painterly look ([[brush-sheets-painterly-not-grime]]).
- **Old:** tezontle and lake-crust grown over one shoulder like a shell, milagros and ex-votos nailed into it by the living to keep it down, and a suit or uniform rotted into the skin, from whoever it was.
- **Vengeful:** the head low and always on you. Its eyes alone are alive.

**Made from:** Claude's call: the mass is edited in Blender from the Quaternius base mesh, as you asked of revenants ("Let's work with what we have and edit from there"), with its proportions changed a long way and its own new rig. One closed skin. Built by a headless script in `tools/monsters/`, refusing open edges, as the others are.

**How it moves:** its own `RevenantBody`, sprung poses and solved limbs as `AnimaBody` and `AnimaMouth` are, with feet planted and hauled from step to step. Heavy, off-balance, wrong. No clips made for human proportions.

**Going down and dying:** acted on its rig. A heavy fall; and three acted deaths in fire, with character, as the others have (`AnimaDeaths`): for instance reaching for you as it burns. Its fire is the approved sheet (`assets/vfx/fire.png`), hot and orange and not the ánimas' sick green, so your fire reads as yours. Judged frame by frame ([[vfx-aesthetic-and-pipeline]]).

## Settled from the project as it stands

- **Logic:** `scripts/Monsters/Revenant.gd extends Monster`, with its own `_brain`, as `FloatingEye` and `Anima` do. `take_hit`, statuses, `SAVED`, and a monster never frees itself: dead or asleep it hides.
- **Saves:** whether it is down and for how long, what burns and sears, and the touch on you and who laid it all survive a save. A revenant dead for good stays dead.
- **Sounds:** stand-ins from approved packs; wanted takes on `sounds_needed.md` and `elevenlabs_prompts.md`. Effects are ours.
- **Words:** the fire shell's and brazier's names on the HUD and table are stand-ins, on `words_needed.md`. The user writes all words.
- **Play:** its own `maps/revenant_gym.tscn`, on `anima_gym`'s pattern: one, then two, then three. The kit table offers fire shells and, once built, the brazier.
- **Tests:** failing first ([[failing-checks-kept]]), `tests/revenant_test.gd`, `--fixed-fps 60`. Motion checks for pops from the start, as `_arms_move_well` does for the mouth. Stills and filmed shots in the real game, with the showcase's shots added.
- **Frame cost:** its gym's worst wave holds 60 fps at 1152x648 with vsync on, measured as `tests/diag_mixed_perf.tscn` does.

## Order of building and where it stops for the user

1. **The body.** Model, in pictures and then in the game, for the user's verdict before poses go on it ([[models-one-by-one-supervised]]).
2. **The revenant and the fire shell.** Moves, poses, two touches, soaked, going down, fire, deaths, possession's first go, gym. The user plays it with fire shells only, and says how it feels.
3. **The brazier.** Model, then its first-person grip posed with the user in their live Blender, then the lash and the close hit. The user plays it.

## Constraints

- Godot 4.5.1, GDScript. Nothing moved in `_process` where it would judder ([[judder-physics-interpolation]]). A body moved while hidden resets its interpolation.
- First-person arm and hand poses are authored with the user in their live Blender ([[reference-not-imitate]]): the brazier's grip and swing, and possession's hands. The solver only nudges.
- Study Castlevania for how the whip reads; never copy it frame for frame.
- Every model joint inspected close up before it's shown ([[finished-means-meticulous]]).

## Approaches

The user picked the third.

- **Its own monster on an edited guard body:** the guard's skeleton, so `Humanoid`'s ragdolls, bleeding and severing still work. Clips made for human proportions would have looked wrong on it, and its shape is held to what a human skeleton allows.
- **A guard with a monster's settings:** quickest, every guard move inherited, but it would fight like a man, and every later guard change would reach it.
- **Its own rig, as the mouth has (picked):** the most freedom for a wrong shape, and it moves like nothing else. It costs severing and ragdolls, and it is the nearest to the modelled figures the user has rejected, so the review stop on the body comes first and is real.

## Left to the builder

- Its poses, and how the three attacks read, within the beats above. The three deaths.
- Soaked's and the touch's screen effects, within the anti-goals: they must not be confused with the curse or the drain.
- How the chain and the head of the brazier are simulated.
- Which approved sounds stand in.
