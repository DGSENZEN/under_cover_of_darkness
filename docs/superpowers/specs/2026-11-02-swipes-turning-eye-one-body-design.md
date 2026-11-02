# Swipes, the turning eye, and one body under attack

## Why

The user: the ánimas "have no combat variety, they just get stuck to you, they should also deal damage with swipes and rakes that don't get exclusively stuck towards you for life drain, that sort of variety adds depth to combat and characters". The evil eyes "should have some sort of projectile with a more advanced form of evil eye", and that form "should just turn worse, look more gory and grotesque". Then "consolidate having the status effects for the evil eye and the life drain work together in a way that is visually coherent and then let's try it out".

This is the roadmap's mixing step: each enemy was tested alone (`maps/hunt_gym.tscn`, `maps/anima_gym.tscn`), and now they meet.

## Goals

- Ánimas fight up close as well as latching on, so a fight with them has rhythm and distance matters.
- A wounded eye becomes a worse, more horrible eye, with a ranged attack.
- With the curse and the drain both on you, the screen reads as one body under attack.
- A mixed gym where eyes and ánimas come at you together, for the user to try.

## Non-goals

- New spells, items or loadout rules. The class trees come later.
- The torso's model and its deaths (still a stand-in; it uses a swipe as the code allows).
- Changing what the curse or the drain do to the player. Only their look joins.
- The Ward, Blink and Empower's polish round, and the other deferred minors from the Burst and Shard review.

## Anti-goals

- Faces or literal diagrams in the screen effects (the user rejected both).
- Ánimas too quick to aim at, or swipes you cannot read and step away from: "real tension" comes from thinking and moving, not from unavoidable damage.
- Effects that blind you: at the worst, three on you and six eyes, the middle of the view stays readable.
- Green fire or gore drawn solid and cheap: judge in the game, frame by frame, close up.

## Part 1: Swipes and rakes

The user's: swipes and rakes that deal damage and don't stick to you. Claude's proposal, accepted ("Yes, that's it"):

- **Choosing:** up close they mostly swipe. The leap becomes a mid-range move and rarer, so standing near gets you cut, and giving them room may get you jumped on.
- **Hands:** a short lunge and a raking swing, with a quick visible wind-up you can sidestep.
- **Faces:** a two-handed crossing rake, or a lunging snap of the jaw.
- **After a hit:** they scuttle back and circle; they do not stand and trade.
- **What it does:** hurts your life directly, drains no power, and slashes your view with the existing claw marks.
- **Answers:** a swipe's wind-up is an opening, as a tell is: a non-lead hit breaks it. A dodge avoids it. The Ward does not stop it (it stops spells and shots, not blows), and a copal line stops them reaching you as it does now.

Numbers are Claude's first guess and go in `Bestiary` by form, to be tuned in play: hands 6 damage, reach 1.7 m, wind-up 0.32 s, every 1.4 to 2.4 s; face 10, 2.0 m, 0.42 s, same; torso 14, 2.2 m, 0.6 s.

## Part 2: The eye turns worse

The user's: the same eye, turning worse, gory and grotesque, with a projectile. Claude's proposal, accepted:

- **The trigger:** a badly hurt eye turns, once, at or below half health, so the change comes from what you did to it. It cannot turn back.
- **The look:** it tears open with a visible wet burst. The lids rip back, the meat splits, more pupils push through, and it weeps gore as it flies. Modelled by editing the approved eye, not built from scratch. The model is shown to the user as a picture before the rest is built ([[models-one-by-one-supervised]]).
- **The attack:** it spits gobs of its own curse: slow enough to dodge, and they can be batted back with the whip. A hit deals damage and opens another eye of the curse (`EvilEyeCurse.deepen`, or starts it if you carry none). It still swoops and stares.
- **Animation:** the eye gets the treatment the ánimas got: real resting, wind-up and hurt poses, since the spit needs a wind-up you can read. Sprung, as `AnimaBody.gd` is.

Numbers are Claude's first guess: turned at 50% health; spit every 2.5 to 4 s from its circling range; wind-up 0.55 s; gob 9 m/s, gently aimed at where you were; 8 damage; hit radius 0.5 m; a wall or the Ward stops it. Bat back with the existing `BAT_SPEED` and `BAT_HURT`. A turned eye has no more health and no change to its weaknesses; it is worse because of what it does.

## Part 3: One body under attack

All Claude's proposal, accepted ("Yes, that's it"):

- **The flesh gets drained too:** as you are drained, the curse's flesh loses its blood, from rich red to pale and sick.
- **One heartbeat:** each gulp squeezes the flesh inward, the eyes flinch and their pupils jump, in time with the hands and your sight.
- **The eyes watch what is on you:** while something feeds, every eye turns toward it. They weep more as your will goes.
- **Claws tear the flesh:** a rake reaching the frame rips across it, and so do swipes. Both are damaging one surface.
- **Two accents only:** orange irises for the curse, sick green for the drain; everything else a shared muted palette.
- **One crosshair:** one mark showing both states, replacing the curse's red ring and the drain's arc when both are up.
- **The middle stays clear.**

## Part 4: The mixed gym

A new map, `maps/mixed_gym.tscn`, built on the existing gyms: waves mixing eyes and ánimas, ending with the worst case the screen has to answer. F5 restarts, F6 calls the next wave, as the others do. Tested alone is kept: the two existing gyms stay as they are.

## Constraints

- Godot 4.5.1, GDScript; failing checks first ([[failing-checks-kept]]); `--fixed-fps 60` determinism with seeded rolls where a test reads them.
- No `juice.punch` pitch for anything repeating (it walks the aim off): trauma and roll only.
- Sounds from approved packs; missing ones go on `docs/superpowers/refs/hunt/sounds_needed.md`. Effects are made by us, never downloaded.
- Words are the user's: nothing on screen is named without them.
- Stills from the real game, in both the lit room and the dark yard, inspected close up before anything is shown.
- Frame cost measured with the mixed gym's worst wave.

## Approaches

For Parts 1, 2 and 4 there is one sensible way: new states and poses on the approved bodies, and an edited eye model. For joining the screen effects:

- **Make them talk (the user's pick):** both shaders stay; each is told what the other is doing. The curse learns gulps, life drained and where the feeder is; the drain learns where the flesh sits. Keeps the approved looks, the smallest change, can still move to a merge later. Costs two full-screen passes, and each new status is wired by hand.
- Merge into one effect: cleanest and one pass, but a rewrite of two approved looks, and it buys nothing visible today.
- Reorder or tint alike: rejected. It gives no shared heartbeat and no eyes watching.

## Settled before planning

From the project as it stands:

- **A swipe's hit** uses `player.take_damage(amount, self)`, as the eye's bite does. A dodge avoids it through `combat.is_dodging()`, as `Anima._lands_on` checks for a leap. Its wind-up is an opening through `Monster._is_opening` and `Anima._is_opening_to` (any source but lead), as the tell is.
- **Who owns what:** the HUD (`StealthHUD._show_curse`, `_show_drain`) already feeds both shaders every frame, so it is where they are told about each other. No new autoload. The crosshair is `StealthHUD._crosshair`.
- **The eyes' target:** `evil_eye_view.gdshader` already takes `gazers[4]`, the sides eyes are watching from. The feeder's place comes from what `leech_hands` already says on screen (`on_screen`, `mouth_on_screen`); something behind you is taken at its side.
- **The claw marks** are `life_drain_view.gdshader`'s `claw_age` and `claws_from`. A swipe uses the same marks, not a second kind.
- **Every eye can turn**, in every map. There are no variants.

Claude's calls:

- **Ranges:** a swipe within its form's reach; a leap only beyond that reach, out to the existing `leap_reach`, and no more than once every 4 s, so it is rarer. The leap's numbers, the latch and the drain do not change.
- **The torso** gets a working swipe with its stand-in boxes lunging, in the logic checks. Its readable wind-up comes with its model (the plan's Task 12).
- **The eye model** is a real stop in the plan: its picture goes to the user, and nothing depending on the turned look is built before the verdict. Its poses are sprung on its existing parts (`EyeBody.part`). The turned form is a new model with the same part names, swapped in at the turn.
- **A batted gob** hurts whatever it meets, monsters included, as a batted eye does. It cannot hurt the eye that spat it until it has been batted.
- **The bar for frame cost:** the mixed gym's worst wave holds 60 fps on this machine (Apple M4 Pro), at 1152x648 as the user plays.
- **The bar for "the middle stays clear":** with six curse eyes and three on you, the screen effects leave the middle third of the view free of opaque flesh, eyes and claws; checked in code by what the effects report, and by eye in stills.
- **The worst case** is six curse eyes and three ánimas on you. A check and a stills tool can force it (a turned eye can be started turned, for tests only). The gym's last wave aims at it by play.

## Left to the builder

- Exact shader wiring, poses, and how a swipe's hit is resolved, within the numbers above, which are first guesses to tune.
- Whether the leap's rarity is by distance alone or by a cooldown too.
- The gob's look, in the eye's own flesh and the curse's colours, and its splat on you.
- The order of the mixed gym's waves.
- Which sounds, from what is approved.
