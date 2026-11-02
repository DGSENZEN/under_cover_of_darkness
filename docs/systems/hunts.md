# Hunts: monsters, weaknesses and the loadout

A hunt is prepared for, then fought (`docs/superpowers/specs/2026-11-01-hunt-combat-design.md`). You pack a few things at a safe place, and in the fight you switch between them. Each monster kind has weaknesses and resistances, and hitting a weakness pays you back in power.

Play it: `maps/hunt_gym.tscn`. Past the kit room's door the first wave comes. F5 restarts, F6 brings the next wave.

| Key | Does |
|---|---|
| Alt | Dodge with the revolver drawn (Q stays Blink) |
| Ctrl at a sprint | Slide (at a ledge, sprint + crouch still climbs down) |
| T | Switch round type: a reload |
| V | Use a prep item. The HUD offers it when it would help, and the key answers with a dry click when it can't |

## Where things live

| File | What it owns |
|---|---|
| `scripts/Monsters/Bestiary.gd` | Each kind's health, weak and resisted sources, and what a hit counts as (`source_of`) |
| `scripts/Monsters/Statuses.gd` | What lies on a bearer, and for how long. What a status does is the bearer's business |
| `scripts/Monsters/Monster.gd` | What every kind shares: `take_hit`, exposure, the power refund, saving, sleeping |
| `scripts/Monsters/FloatingEye.gd` | The first kind |
| `scripts/Combat/Rounds.gd` | Round types: pouch, source, colour, status |
| `scripts/Hunt/PrepItems.gd` | Prep items: what each cures, its use time, how many you carry |
| `scripts/Hunt/Loadout.gd` | The player's pack, what they own, restocking, using items |
| `scripts/Hunt/KitTable.gd`, `KitPiece.gd` | The table you pack at |
| `scripts/Hunt/SafePlace.gd` | Leaving locks the pack and saves; coming back, after 3 s away with nothing awake within 12 m, restores shields and restocks |
| `scripts/UI/HuntReadout.gd`, `evil_eye_view.gdshader` | The painted cylinder and the evil eye's lids |

## How a hit works

Everything that hurts calls `take_hit(damage, attacker, kind, point, direction)`, the same for monsters and guards. The revolver first sets `round_hint` on a target that has one (`Revolver._hint_round`), so a monster knows the round and a guard takes every round as a bullet.

`take_hit` returns `&"none"`, `&"killed"`, `&"weak"`, `&"resisted"` or `&"hit"`. The revolver turns that into the hit mark, the hold and the sound (`Revolver._confirm`).

- **Weak:** scaled by the table, exposes it for 0.8 s (any hit in that time is doubled), and refunds 8 power, once per 0.25 s so a shell pays once.
- **Resisted:** scaled by the table, no hold, a dull sound.
- **Opening:** a kind can open itself (`_is_opening`; an eye's tell). Any hit then counts as weak, at three times the damage.

A shot need not be exact. `Monster.on_line` finds the monster a line passes near: a ball within 0.18 m of its edge plus 0.012 m per metre off, a pellet within 0.04 m, a Shard within 0.3 m, and nothing on the line before it. It only applies to monsters: a man takes exact hits.

## Answers to an eye

| Moment | Answer | Result |
|---|---|---|
| The tell | Any hit | Breaks the swoop, exposes it, refunds power |
| A swoop | Whip or boot | Batted back along your aim, reachable at 3.2 m (`whip_reach`); it hurts what it meets |
| Gazing | Ward | No line of sight (`_line_to`), so no gaze and no swoop; one flying in is smoked |
| Bunched | Copal round | `CopalCloud.gd`: 3.5 m of smoke for 4 s |
| Lined up | Shard | Goes through two monsters (`Shard.PIERCES`) |

The egg sends the curse back (`Loadout`, `PrepItems` `returns`, `FloatingEye.limpia`): eyes within 14 m that can see you shut for 4 s, opening them to any hit, and you are `cleansed` of gaze for 12 s.

The screen says what the evil eye is doing (`StealthHUD._show_curse`, `evil_eye_view.gdshader`), as the monster's own flesh over your sight. A stare builds on the bearer (`Statuses.stare`), and an eye tears open in a patch of meat on the side each one watching is on, veins reaching in. Cursed: the flesh closes in, the edges double, six eyes shut as it runs out, the power arc bruises and the stray is drawn round the aim. Running out, it fades quietly (`leaving`). It deepens (`EvilEyeCurse.gd`): one eye when it lands, another every 7 s while anything still hunts you (looked at within 10 s), or for every 5 s of stares added up, up to six. Each eye slows magic regen, stamina regen and pace and worsens your aim, and the flesh closes in with them. Out of every eye's sight one closes every 4 s, then it is gone. The egg dispels it in three beats. Using it, the egg comes into the left hand (`Loadout.left_frame`, `HandSlot`'s "egg" hold) and takes the curse (`gather`): the eyes turn to it, then the flesh tears away in twisting ribbons with an eye riding on each, hauled in one by one (`ribbon` in the shader), each landing with a jolt of the hand (`Loadout._land_ribbons`), and the egg stains from pale to near-black. On release (`Loadout._release`, `dispel`) the egg bursts in a small splash and the eyes around you are flung back. After: a moment's `relief`, then a dry ward-coloured line for as long as you are cleansed.

A kill holds 0.11 s and jolts the view (`Monster._die`). An eye leaves `Remains.gd` and makes others within 14 m flinch (`flinch`): 2 m further out for 3 s, and 1.5 s longer before swooping.

## Adding a monster

1. Add its row to `Bestiary.TABLE`. Add new sources to `source_of` if it needs them.
2. Write its suite first (see `tests/floating_eye_test.gd`).
3. Extend `Monster.gd` by path, set `kind` in `_init`, and return the velocity it wants from `_brain(delta)`.
4. Add it to `KINDS` in `maps/hunt_gym.gd`.
5. Pass the spec's "How monsters must look and feel" gate before showing it: closed topology, a working rig, its own silhouette, judged in a fight.

A variant is a row with changed numbers and one trick.

## Things to know

- **Spawn exception:** `Monster._ready` adds the collision exception with the player at once. A body that begins under the player and is then moved launches them, as a moving platform would (check M0).
- **The safe place looks for itself each tick** rather than using an `Area3D`: an area's word comes a tick late, and it reports you walking out when the map is freed.
- **A monster never frees itself.** Dead or asleep it hides and stays, so a save can keep it. Place them from the start and `wake()` them.
- **Off a hunt nothing changes.** The default pack is lead only, unlocked, and restocks nothing. PowerPool's refill runs as it always did.
- **Words are the user's.** Stand-ins are listed in `docs/superpowers/refs/hunt/words_needed.md`, poses in `poses_needed.md`, sounds in `sounds_needed.md`.

## Suites

`fight_move_test`, `bestiary_test`, `monster_test`, `loadout_test`, `safe_place_test`, `hunt_gym_test`, `floating_eye_test`, `hunt_loop_test`, `ammo_ui_test`.

`tests/diag_fight_moves.tscn` measures every fight move. `tests/diag_hunt_stills.tscn` takes stills of the marks from the real game, windowed.

## Telling the rounds apart

Each round reads at a glance, from `Rounds.TABLE`: its colour on the readout's chambers and the aim's dot, its own tracer (`GunFx.tracer`), and copal's thread of resin (`GunFx.trail`). On a monster, `Revolver._show_hit` draws what it did (`GunFx.impact`): a resisted hit glances, a small cold star and a spark skipping off; anything else bursts in the round's colours. A smoked eye smoulders (`EyeBody.smoulder`). Stills: `tests/diag_round_stills.tscn`; a scripted run to record: `tests/diag_hunt_video.tscn`.

## Ravenous ánimas

`scripts/Monsters/Anima.gd`, a kind of `Monster.gd` with three forms as data in `Bestiary` (hands, face, torso). Souls no one lit a candle for: they rush you, tell, and leap. A leap that lands puts one on you, up to three (`scripts/Monsters/LifeLeech.gd`, the player's `leech`): they drink your power and your life, slow you, and stop your refills, and with no power left your life goes twice as fast. Killing one gives back half of what it drank.

- **Getting them off:** a whip (one; a torso takes two), a copal round (the one it hits; its cloud only halves the drain and stops new latches), the Ward (all, and they can't enter), the obsidian burst (`scripts/Magic/ObsidianBurst.gd`, key 4; all, and hurts everything near), the copal line (`scripts/Hunt/CopalLine.gd`, all, and they can't cross), a blink (all, unhurt, and they come straight after you). Thrown off, one is stunned and exposed for 1.5 s. A dodge only makes a leap miss.
- **On screen:** `scripts/UI/life_drain_view.gdshader` (`StealthHUD._show_drain`) and `scripts/Monsters/LeechHands.gd`. Its own shader, under the curse's, with a `BackBufferCopy` between them.
- **The face (`AnimaSkull.gd`, `AnimaBody.gd`, `LeechFace.gd`):** the CC0 skull sculpt itself, dried (`tools/monsters/build_anima_face.py`). Its pose runs on springs from a table of poses, so each change overshoots and settles: `rest` hung and slack, `wake` snapping up, `rush` hauling itself along by its hands, `tell` drawn back and gaping, `leap` hands then teeth, `missed` biting on nothing and looking about. Its arms are solved from the wrist to the base of the skull in every pose. On you, the world's body hides and a viewmodel copy takes over, its mouth on your crosshair, drinking in time with the gulps; its collider rides in front of your eyes (`LifeLeech.slot_position`), so you hit it where you see it, and the drain goes into its mouth while the claw marks stay with its hand (`claws_from`). Hands and faces can rest (`Anima.rests`), and stir when you come within `notice`, when struck, when one near them wakes, or when hunger gets them up.
- **The Burst (`ObsidianBurst.gd`, `BurstWave.gd`, `BurstCracks.gd`, `burst_glass.gdshader`):** a wave of dark amethyst spikes (`assets/magic/burst_glass.glb`, built by `tools/magic/build_burst_glass.py`) tears up through the floor from where you cast, 5.5 m in 0.5 s. Cracks creep out in the wind-up, the hand slams down on release, anything on you is thrown off at once, and each enemy is hit when the wave reaches it. It is flung up and over with glass stuck in it, with no stun or exposure added. Ánimas spill fire and ash from an obsidian wound (`AnimaSpill.gd`), eyes crack. Spikes come up full of the spell (`charge`), cool, collapse to rubble, and a scar lies a few seconds. The spikes block nothing.
- **The Shard (`Shard.gd`):** the same glass as the Burst (`MagicFx.obsidian_look`, `burst_glass.gdshader`): a flaked head from `burst_glass.glb` (`Head`), hot in flight, spent where it stays. It goes through a monster with a catch (`THROUGH_STOP`), knocks it (`Anima.jolted`, no stun), stays in it, and an ánima spills fire and ash from the wound; an eye cracks. Its star on a wall is the Burst's spikes in small.
- **Their deaths (`AnimaDeaths.gd`, `AnimaBody.burn_away`, `AnimaBurn.gd`):** the monster goes out of play and gives up its body to the world, which acts one of its form's three last moments, written as beats in `AnimaDeaths.gd`. Faces: `scream` (head back, hands clawing its skull, fire from its mouth), `reach` (drags itself at you, one hand left stretched out), `strings` (hands drop first, it looks down at them). Hands: `spider` (over on its back, fingers going, then drawn in), `crawl` (keeps coming, falls, tries again), `asking` (rears up open, closes on nothing, goes over). Then it is limp, and only the heat moves it. Its fire is the game's simulated fire (`assets/vfx/fire.png`) through `anima_fire.gdshader`, additive, in hard green bands: drawn solid, this green reads as leaves. The flesh burns black from where the fire caught (`charred`, `burn_from`), goes pale and falls apart (`crumbled`), and a heap lies a few seconds with a last flame and a thread of smoke. The torso is a stand-in and just disappears until its model is made.
- **Play:** `maps/anima_gym.tscn`. The hands and the face are real models; the torso is still a stand-in. Tests: `anima_test`, `burst_spell_test`, `copal_line_test`, `anima_gym_test`; stills `diag_anima_stills`.

