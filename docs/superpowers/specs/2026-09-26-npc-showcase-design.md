# NPC Showcase: Design

**Date:** 2026-09-26
**Status:** design approved section by section in chat; this written spec awaits the user's review. Nothing is built yet.
**Branch:** `npc-showcase` (worktree `.claude/worktrees/npc-showcase`), from main at 4d8839a.

## 1. Goal

The user asked for "a demo where we showcase all the different npc behaviours in a place": men talking to each other, patrolling and looking around, looking into chests, idling on the ground, seeing a murder and reacting to it, and fighting one enemy so their different behaviours show. All of it is seen through "a camera where we can see from a distance everything".

It is for **other people**: a demo and trailer. It should be clean, well framed and readable by someone who has never seen the debug labels, and it should play the same way every run so it can be recorded.

## 2. Decisions

| Question | Decision |
|---|---|
| Who it is for | **Others (a demo or trailer).** Clean by default, with cinematic camera work and no debug clutter. |
| Who the guards react to | **An AI intruder.** A visible hooded rogue, driven by a director. The guards run their real, unchanged AI against it; only the intruder follows a script. |
| How the scenes play out | **One escalating night in one garrison yard.** It opens calm, with every idle behaviour visible at once, then plays acts: the intruder slips in, murders a lone man, a witness raises the cry, the camp rouses and hunts, the fight breaks out. Hearing is real, so one event visibly ripples through everyone. |
| Camera | **Free camera plus an auto-director.** Fly, orbit or follow a man; one key hands the camera to a director that glides and cuts to the action. Pause, slow motion and hide-UI for recording. |
| Readability | **Subtitles, alert marks and act titles.** What men say appears near them; a small mark shows a change of state; a title card opens each act. |
| The ending | **Chosen by key:** random, overwhelmed (the intruder dies), victor (he spares the last beggar), or escape (over the roofs and into the canal). |
| How the intruder is built | **A puppet guard** (approach A): `Guard.tscn` with a `puppet` switch, driven by a director brain, with an adapter that makes it look like the player to everyone else. It reuses navigation, climbing, swimming, the rig, ragdolls, gore and the wardrobe. |
| Camp life | **Real guard behaviours**, not showcase-only puppetry: `GuardStation` nodes any level can place (sit, eat, sleep, rummage, carry, chop, lean). The canal-quarter mission can use them later. |

## 3. Scope

**In scope:** the showcase map; guard stations and their clips; the puppet switch; the intruder (adapter, combat read-outs and defence, brain); the director (acts, beats, staged setups, endings); the show camera; the viewer overlay; command-line flags so the whole show can run unattended (for Godot's Movie Maker mode); tests and a visual stager.

**Out of scope:** new animation assets (the Universal Animation Library clips only); new modelling (the intruder is a dye variant of the archer's outfit, and a proper rogue outfit can come through the wardrobe pipeline later); guards fighting guards; changes to how guards perceive, decide or fight; voice work; the canal-quarter mission.

## 4. The place: `maps/npc_showcase.tscn`

Built in code like the gyms (`maps/npc_showcase.gd`), on the retro look (Retro autoload, night environment with god rays, `Torch.gd`, `Fire.gd`). It is a moonlit Watch garrison yard, about 40 × 30 m. Every building is open-sided, so a camera overhead sees into all of it.

```
            outside: lean-to roofs + a canal  (the escape ending)
   ┌──────────────── wall-walk (stairs at both ends) ───────────┐
   │ [TOWER+bell]                                  [postern] ░░ │ ← dark corner:
   │  lookout                                         victim ░░ │   the murder
   │                                                            │
   │ [OPEN SHED]        (FIRE)           [STORE SHED]           │
   │  sleeper      talkers + log bench    chests, crates        │
   │  bedrolls     sitters eat/drink      quartermaster         │
   │                                                            │
   │ woodpile+block      (well)          cart ──crates──▶ store │
   │  chopper                             carrier               │
   └──────────────────────── [GATE] ────────────────────────────┘
```

- **Light:** the fire lights the middle of the yard, which is the best-lit ground and where the fight happens. Wall torches mark the gate and the tower. The dark corner behind the store shed, by the postern, is unlit: the intruder's way in and the murder.
- **Landmarks** (the `landmarks` group, which `Comms` calls places by): the fire, the well, the gate, the tower, the store, the shed, the postern.
- **Outside the wall** (for the escape ending): lean-to roofs a drop below the wall-walk, and a canal (`WaterVolume`) beyond them. `NavLinks` gives the guards their ways up, down, across and into the water.
- **Props:** chests by `Props.chest` (with lids), crates by `Props.crate` (loose, so a dropped one can be thrown), an alarm bell (`AlarmBell.gd`) on the tower.

### 4.1 The cast

Twelve guards, with names, looks and temperaments pinned (`given_name`, `look_seed`, `temperament`; `TemperamentScript.rolling = false` in this map). The fight squad lives in the camp, so the fight pulls in men the viewer has already watched at rest.

| Name | Kind | Temperament | At rest | In the story |
|---|---|---|---|---|
| Mirelle | duelist | steady | talks by the fire | the captain and squad leader; falls in the fight's *focus* beat |
| Osric | swordsman | steady | talks by the fire with her | the front man; opened and cut down in the *parry* beat |
| Brand | brute | rash | chops wood | sent to break the turtle; berserk when the captain falls |
| Wat | archer | sly | patrols the wall-walk, stops to look about | shoots from the wall in the fight |
| Aldous | watchman | stubborn | leans on the tower rail and sweeps the yard | the lookout: sends men by name, rings the bell |
| Hendrik | watchman | steady | walks the yard with a lantern | the hunt's lantern |
| Piers | watchman | craven | sits on the log bench, talking | breaks and begs in the *press* beat |
| Col | watchman | steady | sits on the log bench, eating and drinking | |
| Tam | watchman | steady | asleep on a bedroll in the shed | the late riser |
| Gideon | watchman | steady | the quartermaster: chest to chest | |
| Ned | watchman | craven | the carrier: crates from the cart to the store | the witness: cries murder, runs for the captain |
| Jory | watchman | steady | posted alone at the postern | the victim |

## 5. Camp life: guard stations

### 5.1 The node (`scripts/AISystem/GuardStation.gd`)
A `Marker3D` with a `kind`, a stand point and facing (its own transform), and optional links: the chest it serves (rummage), the pick-up and set-down points (carry), the bench it sits on. A guard gets a `station` (NodePath) or a `stations` rota (an array, visited in turn). A station holds one man at a time.

### 5.2 What he does there
While RELAXED, a man with a station walks to it and does its thing. `GuardLife` reports it as his `activity()`, and `GuardRig` maps it to clips through its existing activity table, the way arms-folded and the flask already work.

| Kind | What he does | Clips |
|---|---|---|
| sit | sits on a bench or log; talks seated when a friend at ease is near, using the existing gossip (`Garrison.gossip`) | Sitting_Enter, Sitting_Idle_Loop, Sitting_Talking_Loop, Sitting_Exit |
| eat | seated; eats and drinks every so often | Sitting_Idle_Loop, Consume |
| sleep | lies on a bedroll; hearing ×0.15 while asleep (as the gym barracks does) | LayToIdle held on its first frame; played through to get up |
| rummage | walks his rota of chests: lid up, stoops, rummages, mutters ("Where's the damned lamp oil…"), maybe takes something, lid down, next | Chest_Open, Crouch_Idle_Loop, PickUp_Table |
| carry | picks a crate off the cart, carries it to the store, sets it down, goes back | PickUp_Table, Walk_Carry_Loop |
| chop | chops at the block; now and then stops to wipe his brow | TreeChopping_Loop |
| lean | leans on a rail between sweeps (the lookout); calls from it | Idle_Rail_Loop, Idle_Rail_Call |

### 5.3 Getting up is part of the show
Anything that stirs him ends the station: alert past suspicious, a call, the bell, a cry of murder, a blow. Each kind has its proper exit before the normal alert ladder takes over:

- **Sitter:** stands with Sitting_Exit.
- **Sleeper:** scrambles up with LayToIdle, so he is the slowest to react.
- **Carrier:** drops his crate, which becomes a loose prop (and so something `Dangers.throwables_near` can offer a guard to throw).
- **Quartermaster:** lets the lid bang shut, a sound on the `SoundBus`.
- **Chopper:** keeps his axe in hand.

Back at his ease for a while (RELAXED for `STATION_RETURN` s), he goes back to his station.

Talking, patrol look-arounds (`look_around_time`), lookout sweeps and lanterns already exist and are used unchanged. Stations change nothing about how a guard perceives or fights.

## 6. The intruder

### 6.1 Body: a puppet guard
A `Guard.tscn` with a new export, `puppet := false`. When true, the guard:

- **skips** perception, the alert ladder, `GuardLife`, squads (`Squad`), garrison memory (`Garrison`), barks of his own, and anything that counts him as one of the guards;
- **stays out of** the `guards` group and **joins** the `player` group, so every guard's existing target lookup (`get_first_node_in_group(&"player")`) finds him;
- **keeps** navigation (`GuardNav`), climbing (`GuardClimb`), swimming (`GuardWater`), the rig (`GuardRig`), ragdolls and gore, and the swing clock the rig reads (`_attack`, `_phase`, `_phase_timer`);
- **gains** a crouched sneak gait (Crouch_Fwd_Loop, Crouch_Idle_Loop) in `GuardRig`;
- **wears** the archer's hooded outfit in a near-black dye (a colour variant, no new modelling), with a sword.

His own death must not reach squads or the garrison (no dread, no "for the captain"), and must not free the player group's lookups mid-frame for guards still holding him as `_target`.

### 6.2 Looking like the player: `scripts/Showcase/Intruder.gd`
A component on the puppet that answers what guards read off their target (every access in the AI is already guarded by `has_method` or `get`):

- `get_exposure()`: light at his feet and chest from `LightProbe`, times the player's crouch factor (0.85) and a motion factor (up to +35%), the same formula as `PlayerController.get_exposure`;
- `get_light_level()`, `get_sight_points()` (head, chest, shins);
- `health`, `max_health`, `velocity`, `is_dead`;
- `take_damage(amount, from)`: through his defence (6.3), then onto his own health with the plot-armour floor (6.5);
- `warn_attack(...)`: forwarded to his brain; it is the cue for his parries and dodges;
- `combat`: an `IntruderCombat` (6.3).

Anything the AI reads off the real player that a puppet cannot have (`frob`, `juice`) returns null or a neutral value; the plan lists every such access and its answer.

### 6.3 Blows both ways: `scripts/Showcase/IntruderCombat.gd`
- **His read-outs**, worked out from his own swing clock: `phase`, `blocking`, `threat_phase()`, `threat_reach()`, `threat_direction()`, `time_to_contact()`, `threat_serial()`, `is_riposte()`, `dodged_within(s)`, `blow_poise()`, `on_answered(how, by)`, `_style()`. The guards judge him exactly as they judge the player: `Squad`'s reads (turtle, spam, kite), flank timing, answers.
- **His blows land as the player's do:** `guard.take_hit(damage, intruder, kind, point, direction)` with `quick`, `power` or `backstab`, the same call `PlayerCombat._strike_target` makes. So the guards' own blocking, parrying, posture, OPEN state, deathblows, bleeding and dismemberment all run for real.
- **His defence:** `filter_incoming(amount, from)` applies what his brain chose (block, parry, dodge or nothing) and triggers the same guard-side reactions a player's defence triggers: the parry stagger and posture, `_answered` for a dodged thrust or a jumped sweep, the block's posture tick. The plan reads `PlayerCombat.filter_incoming`, `_answer_blow`, `_counter` and `_clash` and mirrors each guard-side call.

### 6.4 His brain: `scripts/Showcase/IntruderBrain.gd`
Verbs the director calls:

| Verb | Does |
|---|---|
| `go_to(point, gait)` | walks there along the navmesh: `sneak`, `walk` or `run` |
| `hide_at(point)` | goes there and crouches still |
| `backstab(guard)` | closes on him from behind and strikes with `backstab` |
| `fight(tactic, target := null)` | fights by a tactic (below) until told otherwise |
| `flee_by(route)` | runs a list of points, climbing and swimming as the links say |
| `fall()` | lifts the plot armour; he fights on until he is cut down |

Fight tactics, each chosen to draw out a behaviour of the squad:

| Tactic | How he fights | What it provokes |
|---|---|---|
| trade | a steady exchange with the front man: blocks cuts, answers thrusts, cuts back | flankers take their places; the archer shoots from the wall |
| turtle | holds his guard, barely strikes | the squad reads turtle (> 0.55), plans *break*, sends the brute as breaker |
| parry | waits and parries, ripostes | posture fills; the front man goes OPEN; a deathblow; witnesses shaken |
| focus | cuts his way to a named man | the captain falls: the brute goes berserk, morale drops, fall-back or rout |
| press | goes after wavering men | men break, flee, throw down their blades and beg |
| spare | stands off from a beggar and walks away | the spared man runs for help |

### 6.5 Plot armour and the one cheat
- His health cannot go below 30% of its maximum until the ending beat; `fall()` lifts the floor.
- **Act II only:** the director damps his exposure while he sneaks, so a stray glance cannot end the act before the murder. His route is still dark and timed against the archer's patrol. Everything from the murder on is unassisted: the guards see him with their real vision.

## 7. The director: `scripts/Showcase/ShowDirector.gd`

### 7.1 Acts and beats as data
Each act is a list of beats. A beat has:
- **do:** intruder verbs, station changes, timing nudges (for example, holding the carrier at a rota point until the intruder is in place);
- **shot:** what the auto-director should frame (8.2);
- **until:** a check on real state (a man's alert, the squad's plan or a man's place, a man OPEN, broken, begging or dead) or a length of time;
- **timeout:** if the AI does something else, the beat is skipped with a log line and the show goes on. A run never stalls.

### 7.2 The night (about 5 minutes)

| Act | What happens |
|---|---|
| **I. The Watch at Rest** (~70 s) | No intruder. A slow tour: a crane over the yard; gossip at the fire; the sitters eating; the sleeper; the quartermaster at his chests; the carrier; the chopper; the archer stopping on the wall to look about; the lookout on his rail. |
| **II. A Knife in the Dark** (~45 s) | The intruder drops over the back wall behind the store and sneaks along its shadow. He waits for the archer to pass above, then backstabs Jory at the postern. Ned's rota is timed so he rounds the store with his crate as the body falls. He drops it, cries murder, and reacts as his temperament says (craven: he runs for the captain). |
| **III. The Cry** (~50 s) | The ripple: the talkers turn, the captain draws, the sitters rise, the sleeper scrambles up, the chopper hefts his axe, the lid bangs, the bell rings. The intruder breaks sight into the dark ("Lost him!"). The hunt: lanterns lit, search spots claimed, the lookout sending men by name. |
| **IV. Steel** (~90 s) | He is found at the fire. The fight's beats in order: **trade**, **turtle**, **parry**, **focus**, **press** (6.4). |
| **V. The Ending** (~30 s) | **Overwhelmed:** `fall()`, and the squad presses and cuts him down. **Victor:** he spares Piers, who runs for help, and leaves by the gate. **Escape:** he breaks off up the wall stairs, drops to the roofs outside and into the canal; the guards climb, drop and swim after him. |

After the ending, a fade and a title; R restarts.

### 7.3 Starting mid-show
Each act has a **staged setup** that puts the world in the state it needs without playing what came before: who is dead (killed at setup by the same `take_hit` a real blow uses), the alarm and the bell, where men stand, what the garrison remembers. Jumping to act IV takes a moment. It is close to a real run-through, not identical to one.

### 7.4 The same every time
Temperaments, looks and names are pinned per man; the random seeds are fixed (`Guard.randomize_on` and its seed, as `tests/duel_test` D34 does). Each run plays out with the same beats. It is not guaranteed frame-exact under real-time rendering; under Movie Maker (7.6) every frame is a fixed physics step, so it should be.

### 7.5 Keys

| Key | Does |
|---|---|
| 1–5 | start from that act |
| N | skip to the next beat |
| E | choose the ending: random, overwhelmed, victor, escape |
| R | restart |
| Space | pause |
| `[` / `]` | slow motion: ¼, ½, 1 |
| H | hide the UI |
| C | auto-director on or off |
| Tab | follow the next man |
| F6–F8 | the retro settings, as in every scene |

### 7.6 Unattended runs
Command-line flags after `--`: `--act=N`, `--ending=overwhelmed|victor|escape`, `--auto` (auto-director on, no input needed), `--quit-at-end`. With these, Godot's Movie Maker mode renders the whole show to video at a fixed frame rate, however heavy the scene:

```
Godot --path . --write-movie showcase.avi --fixed-fps 60 --resolution 1920x1080 res://maps/npc_showcase.tscn -- --auto --ending=escape --quit-at-end
```

## 8. Camera, text and sound

### 8.1 The camera: `scripts/Showcase/ShowCamera.gd`
Three modes:
- **Free:** WASD to fly, Q/E down and up, right mouse held to look, Shift for fast, the scroll wheel for speed.
- **Follow:** click a man or Tab through the cast. The camera orbits him at a distance set with the scroll wheel, with a small name card ("Aldous, lookout").
- **Auto-director:** each beat asks for a shot, and the camera glides between shots on springs, cutting when the subject is too far to glide to. With no shot asked for, it frames whoever changed state most recently. Moving the mouse or pressing a fly key takes the camera back at once; C hands it back to the director.

| Shot | Frames |
|---|---|
| wide | a crane over the yard |
| two | two men, such as the talkers or the fight's front pair |
| close | one man's face, such as the witness |
| track | a moving man, such as the intruder sneaking |
| reveal | a pull back from one man to the whole yard |

The camera runs on real time, so it moves while the game is paused or slowed: pause on a moment and fly round it.

### 8.2 On-screen text: `scripts/Showcase/ShowOverlay.gd`
- **Subtitles** over the speaker's head: what men already say (gossip, barks, "Murder!", "Osric! By the well!"), with a short speaker name. They come from the guards' existing bark signal. In this map they replace the floating Label3D barks. At most three on screen, only for men in view, each fading after a few seconds.
- **Alert marks** over a man whose state changes, fading after 2 s: **?** suspicious, **an eye** investigating or searching, **!** he sees the intruder, **a white flag** he begs.
- **Act titles:** a period-style card as each act starts ("II. A Knife in the Dark").
- **H** hides all of it for clean footage.

### 8.3 Sound
- `Sfx` already takes its occlusion from the viewport camera, so the show is heard from wherever the camera is.
- `Music.gd` finds its "you" in the `player` group, so the adaptive score follows the intruder: tense in the hunt, the combat layers in the fight.
- Effects meant only for the real player skip the intruder: the hurt muffle and heartbeat (`Sfx`), and whatever `Retro.gd` does per player. They check for the real player rather than the group.

## 9. Files

| File | What |
|---|---|
| `scripts/AISystem/GuardStation.gd` (new) | the station node |
| `scripts/AISystem/GuardLife.gd` | station behaviour: going there, the loop, the exits, the return |
| `scripts/AISystem/GuardRig.gd` | station clips; the sneak gait |
| `scripts/AISystem/Guard.gd` | `station`, `stations`, `puppet`; the puppet's skips; kept as small as possible |
| `scripts/Showcase/Intruder.gd` (new) | looks like the player to the guards |
| `scripts/Showcase/IntruderCombat.gd` (new) | read-outs, blows, defence |
| `scripts/Showcase/IntruderBrain.gd` (new) | verbs and tactics |
| `scripts/Showcase/ShowDirector.gd` (new) | acts, beats, setups, endings, flags |
| `scripts/Showcase/ShowCamera.gd` (new) | the three camera modes and the shots |
| `scripts/Showcase/ShowOverlay.gd` (new) | subtitles, marks, titles, name cards |
| `maps/npc_showcase.gd`, `.tscn` (new) | the yard, the cast, the keys |
| `scripts/Audio/Music.gd`, `Sfx.gd`, `scripts/Visual/Retro.gd` | player-only effects skip the intruder |
| wardrobe | the archer outfit's dark dye variant |

## 10. Risks

- **Performance.** The most guards ever alive together so far is seven, and the cost is unmeasured. The plan measures twelve plus the intruder, windowed, before building the show. If it cannot hold 60 fps, the cast is trimmed in this order: Col, then Hendrik, then Gideon. Movie Maker renders at a fixed rate regardless, so recorded footage is never hurt by frame rate.
- **The puppet in `Guard.gd`.** It is 3,200 lines and assumes in places that it is a guard. Every group, squad and garrison touch needs a puppet check; the tests pin that the intruder is in none of them.
- **Beats that don't happen.** The guards decide for themselves, so a beat's condition may never come true (the brute not sent to break, nobody begging). Timeouts keep the show moving; the tests check each fight beat can come true from its staged setup.
- **Shared files.** `Guard.gd`, `GuardLife.gd` and `GuardRig.gd` are also edited by other sessions. The work stays on its branch and is merged when finished; conflicts are resolved then, not by editing main.

## 11. Testing

- **`tests/stations_test`**, per station kind: he goes there and shows the right activity; stirring him ends it with the right exit; the sleeper hears at ×0.15; the carrier's dropped crate is a loose, throwable prop; he returns once calm.
- **`tests/showcase_test`:**
  - guards find, see and fight the intruder; the Act II exposure damping is off after the murder;
  - his backstab kills; his blows go through `take_hit`, and a guard's block and parry work against them;
  - his parry staggers a guard; his read-outs match his swing clock;
  - he is in no squad and no garrison memory, and his death adds no dread; player-only effects skip him;
  - every act's staged setup reaches its expected state;
  - each fight beat's condition can come true from its setup (turtle → the squad plans *break* with the brute as breaker; focus → the captain dead and the brute berserk; press → a man begging);
  - all three endings finish headless within a time limit;
  - no SCRIPT ERROR in stderr (the stealth round's lesson: grep it even when every check passes).
- **Every existing suite stays green**, run with `--fixed-fps 60`. New suites pin their clocks and seeds (the headless-determinism rules).
- **`tests/visual/stage_showcase`** renders a still per act and per ending into a contact sheet for the user's review.
- **An early windowed performance check** with the full cast (section 10).

**Done means:** the whole show plays start to finish in a window, all three endings work, the unattended run renders under Movie Maker, and every suite passes.
