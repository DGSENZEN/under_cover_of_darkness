# NPC Showcase, Part 2: Life and Voice: Design

**Date:** 2026-09-26
**Status:** design approved section by section in chat; the user asked to go straight on to the plan and the build ("looks good write the spec, then impl"). The cast sheet and sample conversations below set the voice; the full writing lives in plain-text files the user can edit.
**Branch:** `npc-showcase` (worktree `.claude/worktrees/npc-showcase`), on top of the built showcase (d1b18b7).
**Follows:** `2026-09-26-npc-showcase-design.md` (the showcase itself).

## 1. Goal

The user watched the showcase and found the guards still primitive: they repeat behaviours; there is no real dialogue, neither between several men nor idle; nothing in their movement shows their temperament or values. They asked for NPCs that feel genuinely alive, the way The Last of Us and F.E.A.R. made theirs feel, and for more behaviour "to make it prettier".

This is the first of four follow-up projects, in the user's order:
1. **Life and voice** (this document).
2. **Cinematography:** a real shot grammar for the auto-director.
3. **Sound:** footsteps from the animation's feet, an in-scene mix, new recordings (fire, torches and the rest) from the Sonniss GDC bundles the user pointed to (gamesounds.xyz mirror; royalty-free), each download approved first.
4. **Environment art:** a PS2-style Blender kit for the yard.

## 2. Decisions

| Question | Decision |
|---|---|
| How dialogue is heard | **Murmur plus subtitles.** Each line plays a murmured snippet of speech (and its emotes their own sounds: a laugh, a sigh, a cough), cut from approved Sonniss recordings, pitched per man, placed in the world; the subtitle carries the words. |
| Where animation detail comes from | **Procedural plus the clip library.** No new animation assets: a procedural expression layer (gaze, posture, breathing, weight shifts, gait) and fuller use of unused Universal Animation Library clips, layered on the upper body. |
| Tone | **Wry at rest, human in fear.** Tired working men grumbling, teasing and gossiping; after the murder: fear, names called into the dark, grief, bravado cracking, begging. |
| Extra life | **Social routines, atmosphere touches, a night that moves.** Not animals. |
| Setting | **The canal quarter's Watch yard** (High Town, behind the Steps Gate) from the Moon-Glass mission. |
| Dialogue architecture | **Authored conversations chosen by rules** (approach C): whole written exchanges with parts, conditions and cooldowns, chosen by a garrison director to fit the moment, cast from whoever is there, re-checked line by line, interruptible, with memory. |

## 3. Scope

**In scope:** the talk system and its files; the cast sheet and all the writing; the voice (murmur, emotes, breathing, heart rate, the speech ladder); pastimes with memory; the expression layer; the rig's upper-body layer; gatherings; the night rota; atmosphere touches; the fire's fuel; the showcase's Act I rebuilt; tests.

**Out of scope (later projects):** camera shot grammar; footsteps, the in-scene mix and the non-vocal recordings (fire, torches, chopping, crates); environment meshes. Voice acting or generated speech. Animals. New animation clips.

## 4. The talk system

### 4.1 Files: `data/talk/*.talk`

Plain text, one conversation per block, loaded at start by `scripts/AISystem/Talk/TalkScript.gd`. A parse error names the file and the line.

```
== dice_debt
when: at_ease, night:early|middle
cast: A = any; B = owes(A); C? = friend(A)|friend(B)
cooldown: 10m
A: You still owe me four pennies for the dice.
B: Three. I won the last throw.
A: You knocked the cup over. That's not winning, that's clumsy.
B [shrugs]: It's a kind of winning.
C [laughs]: Pay the man, Piers.
-- interrupt
A: Hush. What was that?
```

- `== id` starts a block; ids are unique across all files.
- `when:` conditions, all of which must hold (section 4.3). Re-checked before **every** line; if one fails, the conversation ends with its `-- interrupt` line (if any) and is remembered as interrupted.
- `cast:` the parts. `A`, `B`, `C`, `D`; a `?` marks a part that may be empty (filled if someone fits, or later by a man who walks up: a late joiner). Each part has requirements (section 4.4). `|` is "or".
- `place:` optional: a gathering or station kind the conversation belongs to (dice, flask, story, watch_change, round, wake, fire, or a station kind); it is then only chosen there.
- `cooldown:` how long before it can be chosen again (`30s`, `10m`), or `once` (once a night). Default `5m`.
- `priority:` optional integer. The most specific fitting conversation wins (most conditions and requirements met, then priority); ties are a weighted random pick.
- A line: `PART [emotes] {variant}: text`.
  - Emotes: `laughs`, `sighs`, `nods`, `shakes`, `shrugs`, `spits`, `coughs`, `drinks`, `points:<landmark>`, `looks:<landmark|part>`, `kicks`, `whispers`, `shouts`, `murmurs`. Each drives an animation and, where it has one, a vocal sound; `whispers`/`shouts`/`murmurs` set delivery (loudness, how far it carries, the murmur's character).
  - Variants: `B {if rash}: ...` lines directly after a line are alternatives for the same turn; the first whose condition holds for that speaker is spoken, else the plain line. A condition is any requirement (temperament, state, tie) or `hurt>0.5`.
  - `{place}` in a line's text is replaced by the named place the line is about (a landmark near the thing called out: Comms' landmarks); `{A}`, `{B}`, `{dead}` by names.
- `-- interrupt` begins lines spoken if the conversation is broken (one per part at most, spoken by whoever was about to talk).

Solo remarks are conversations with one part. Call-and-answer pairs (section 4.7) are conversations whose `when:` names a squad situation.

The **cast sheet** is `data/talk/cast.talk`:

```
== cast
Mirelle: rank 4; captain; south
Osric: kin Jory
Jory: kin Osric
Piers: owes Col; friend Col
...
```

Ties: `kin`, `friend`, `rival`, `owes`; traits (free words: `sings`, `sleeps_on_watch`, `south`, `recruit`) become facts a condition or requirement can name.

### 4.2 The director: `scripts/AISystem/Talk/TalkDirector.gd`

One per garrison (made by the first guard that needs it, like Garrison and Squad; cleared with them).

- Every `CHOOSE_EVERY` s (about 2 s, staggered) it looks for **groups**: men at ease within `TALK_RANGE` of each other with line of sight, not already talking, not busy getting up or crossing. Standing, seated and at stations all count; a gathering's members are a group of their own.
- For a group it gathers facts (4.3), finds every conversation whose `when:` holds and whose parts can be cast from the group (4.4), drops those cooling down or used up, and picks one: the most specific, then weighted random, never the one just played to these men. Men who have talked least recently are preferred for parts.
- **Playback:** one speaker per group at a time. Each line lasts `0.9 + 0.055 × characters` s at a normal delivery (a whisper a little longer, a shout shorter), then a pause of 0.4–0.9 s. The speaker's emotes play (gesture, sound); listeners turn to him (gaze), and at the line's end one may nod or shake his head according to the next line's emote or his temperament. Before each line the `when:` is re-checked and the next variant chosen.
- **Interruptions:** a group member stirred (alert past suspicious, a call, the bell, a blow), a speaker gone, or a failed `when:` ends the conversation: its interrupt line if any, then everyone to what they were doing. A man walking up during a conversation with an empty optional part fitting him joins it.
- **Memory:** per conversation a last-played time (cooldown, `once`); per group of lines (all conversations sharing a tag, e.g. all `dice_*`) every member is used before any repeats; per man the lines he has spoken tonight (no man repeats a line within the night unless the line is marked `again`); per pair the topics aired (a pair does not air one topic twice).
- **Subtitles:** every spoken line is emitted as the speaker's `barked` signal (so ShowOverlay and the HUD show it, as today) with its delivery.

### 4.3 Facts: `scripts/AISystem/Talk/TalkFacts.gd`

Conditions read a flat set of facts gathered when a conversation is considered and re-read before each line:

- **The night:** `night:early|middle|late|dawn` (NightRota), `cold`, `fire:low|burning`, `wind`.
- **The garrison:** `at_ease` (every cast member RELAXED and not afraid), `uneasy` (someone suspicious or investigating, or a noise looked into lately), `alarm`/`alarm>=N` (Garrison.alarm), `hunt` (a squad hunting), `combat`, `bell_rung`, `dead>=N`, `dead(<name>)`, `body_found`, `missing(<name>)` (Garrison.fallen), `dread>=N`, `spared`, `slain_begging`.
- **The men present:** `present(<name>)`, `asleep(<name>)`, and for a cast member (as requirements): temperament, rank, archetype (`kind`), traits, ties, state (`tired`, `hungry`, `cold`, `hurt`, `grieving`, `afraid`), station kind, `near(<landmark>)`.

### 4.4 Casting

A part's requirements: `any`, a temperament (`rash`, `craven`, `stubborn`, `sly`, `steady`), `rank>=N`, `name(<name>)`, `kind(<archetype>)`, a trait, a tie to another part (`kin(A)`, `friend(A)`, `rival(A)`, `owes(A)`), a state, `station(<kind>)`, `not(<requirement>)`. Casting tries every assignment of group members to parts (groups are small) and takes the one meeting the most requirements, preferring the quietest men. An optional part left empty is skipped in playback (its lines are not spoken) unless filled later.

### 4.5 The voice: `scripts/AISystem/GuardVoice.gd`

One per guard.

- **Heart rate:** a value from 60 (asleep) to 170 (fighting, running, terrified), easing toward a target set by his state (relaxed, uneasy, searching, combat), running, fear (Garrison dread, his resolve) and wounds, with three exhaustion steps and a per-man recovery rate (varied, section 5.3). It sets the breath rate, whether lines come out whispered or shouted when not marked, and feeds the expression layer (5.2) and the atmosphere's breath (section 7).
- **The speech ladder:** `breath < chatter < call-out < pain < death`. A higher sound stops a lower one on the same man; breathing resumes after. Chatter never talks over a call-out; a call-out ends a conversation.
- **Murmur:** a line plays a murmured speech snippet sized to the line (a random stretch of a longer walla recording, faded in and out), pitched per man (`GuardRig.voice_pitch`), louder and harsher for a shout, breathy for a whisper, placed at his head. Emotes play their own sounds (laugh, sigh, cough, spit, grunt).
- **Breathing:** at a high heart rate, audible breaths (loops per state: calm is silent, winded is heavy); the lowest rung.

The recordings are cut by `tools/prepare_sfx.py` from Sonniss files the user approves (listed during planning: file, bundle, size).

### 4.6 Solo remarks and names

- A man alone at his station or post, at ease, now and then says a remark fitting where he is and what he does (a sleeper in his sleep, the chopper cursing a knot, the lookout at his knees, a man looking up at the tower). Rare: at least `SOLO_GAP` (about 40 s) per man and one at a time within earshot.
- **Grief by name:** a man who sees a friend or kin die, or finds his body, calls his name (a `grief` conversation with `dead(<name>)` and the tie). His temperament then decides: a craven man breaks (his squad resolve falls), a rash one is enraged (the existing moods); kin grieve longest (`grieving` state for the night).
- The lookout's send ("go and look") becomes a two-line exchange; the man sent answers in his own way.

### 4.7 Call-and-answer in the fight (F.E.A.R.)

Combat talk stays chosen **after** the squad decides (Squad, Comms), and becomes pairs where a second man answers: a status check and its answer (the answer shows how hurt he is), "Anyone see him?" and a man who can naming the place, "Man down!" counts, excuse lines (a man ordered where a friend fell: "Not there! That's where Jory fell!"; a man with no way to the intruder), the last man's "I'll fetch the others!". A pair is only started when the answering man is alive, able to speak and in earshot.

## 5. Life in the body

### 5.1 Pastimes: `scripts/AISystem/GuardPastimes.gd`

Replaces GuardLife's two fidgets. A man at ease and standing (at his post, a waypoint, a pause) chooses a pastime by **dual utility**: the most pressing category first (cold → warm yourself; tired → lean or sit; idle → the rest), then a weighted random pick among the options within 80% of the best, weighted by temperament, with a memory penalty on recent picks and streaks filtered (the same pastime never twice running, not three times in five). Each has conditions, a length drawn from a range, and a per-man cooldown.

| Pastime | Needs | Shown by (library clips, upper-body where noted) |
|---|---|---|
| warm his hands | within 3 m of the fire | `Spell_Simple_Idle` (hands out, upper), facing the fire |
| squat by the fire | within 2.5 m, a free spot | `Crouch_Idle` |
| stamp his feet | cold | procedural bob and weight shifts |
| scratch | none | `Zombie_Scratch` (upper) |
| a drink | none | `Consume` (upper) |
| fold his arms | none | `Idle_FoldArms` (upper) |
| lean | a wall or rail within 1 m behind or beside | `Idle_Rail` |
| check his blade | armed | `Sword_Idle` held a moment, head down |
| sit | a bench, crate or step free | `Sitting_Enter/Idle/Exit` |
| look up at the tower | the tower in view | gaze (5.2) held, head up |
| pace | room | a few steps out and back |
| spit | none | procedural head dip + sound |
| roll his shoulders | none | procedural |

Each clip is staged and dropped if it reads wrong.

### 5.2 The expression layer: `scripts/Visual/Expression.gd`

Presentation only (the AI reads nothing from it), one per rig, driving `Posture.gd` (extended with head pitch, chest lean, shoulder raise, breath) and the gait:

- **Gaze:** a head target chosen by priority: the intruder when seen, a noise or call, the speaker in his conversation, a man walking past him within 4 m, the fire, the tower; the head leads and the chest follows a little; small darts on top (quicker and wider for sly and craven men).
- **Posture and gait by temperament:**

| | Rash | Craven | Stubborn | Sly | Steady |
|---|---|---|---|---|---|
| Posture | chest out, leaning in | hunched, shoulders up | upright, wide stance | low, loose | neutral |
| Gaze | fixes, turns sharply | glances back, darting | holds a look | sweeping | calm |
| Gait | quick, long | quick, short | measured (the captain: `Walk_Formal`) | light | even |
| Talking | big gestures | small, hands close | few, firm nods | almost none | plain |

- **Breathing:** the chest rises and falls at GuardVoice's rate. **Weight shifts** every few seconds at rest. **Wounded:** a limp and a hand to the wound. **Fear:** the hunch deepens and glances quicken with dread; grieving shoulders drop.

### 5.3 Per-man variation

Each man draws, from his look seed: walk speed ×(0.92–1.08), idle rhythm, breath rate, gesture size, gaze darts, all Gaussian around his kind's value, with slow Perlin drift over time, so no two men move in step.

### 5.4 The rig's upper-body layer

`Humanoid.gd` gains an upper-body action slot (a bone-masked blend, like the existing legs layer used by `set_leg_drive`) so gestures, nods, a drink or hands to the fire play over walking or standing without replacing the whole body.

## 6. Things done together

### 6.1 Gatherings: `scripts/AISystem/Gathering.gd`

Small authored scenes, each with parts, a place, steps, a timer and its own conversations (`place:`). A garrison-level director starts one when its men are free and near (or sends them: "Dice?" "Go on then."); anything that stirs a member ends it; they go back later.

| Gathering | Parts and place | What happens |
|---|---|---|
| Dice | 2–3, a crate by the bench | throws, groans and cheers; the dice conversations |
| The flask | 2 | a hand held out, a pull, handed back |
| A story | 1 teller, 2–3 listeners, the fire | the teller gestures, listeners react, a laugh at the end (the longest conversations) |
| The watch changes | the relief and the man at a post | a walk-over, "Anything?" / "Nothing but the cold", duties swap (NightRota) |
| The captain's round | the captain, then each man | she stops at each for a line by temperament; men straighten as she passes; the sleeper gets a boot |
| Waking the sleeper | one man and Tam | a nudge (`Push`), Tam up grumbling to take a turn |
| Feeding the fire | one man, the woodpile, the brazier | the fire burns low; he fetches a log (carried) and feeds it (`Fixing_Kneeling`); it flares |

### 6.2 The night rota: `scripts/AISystem/NightRota.gd`

A garrison rota holds duties (posts, rounds, stations, the bench, bed) and the night's hour (early, middle, late, dawn: the hour runs on game time, condensed for the showcase). Needs rise over time (tired, hungry, cold) and move men: a tired man is relieved and goes to bed, a hungry one to eat, a cold one to the fire; a man on a post too long is relieved (a watch change). A handover is always a walk-over and a line. The alarm suspends the rota (duties give way to the hunt) and it resumes when the garrison is at ease again.

### 6.3 The fire: `scripts/Combat/Fire.gd`

A brazier gains fuel: it burns down over minutes, its light and flame shrinking to embers; fed a log, it flares. `fire:low` is a fact the talk and the rota read.

## 7. Atmosphere: `scripts/Visual/Atmosphere.gd`

Presentation only, sized for the PS2 look:
- **Breath** from each man's mouth on the out-breath, in time with his breathing, thicker when running, afraid or shouting.
- **Embers** off the brazier, drifting with the wind; a burst when fed, fewer as it burns low.
- **Moths** circling the torches.
- **Wind** in gusts: flames lean, embers and a few dead leaves skitter, cloth stirs (the existing cloth).
- **Wood chips** from the chopping block on each blow.
- **Crows** on the wall-walk that take off when someone runs or shouts nearby, and settle later.
Performance is measured with all of it on; moths, then leaves, are thinned first if needed.

## 8. The showcase

- **Act I** grows from about 70 s to about 2½ minutes and runs a condensed stretch of the night: talk everywhere, the captain's round, a watch change (Jory takes over the postern from Hendrik), the fire fed, dice, a story, the sleeper woken. Its beats follow whatever gathering or conversation is live; the auto-director frames it (its shot grammar is the next project).
- **Act II and after:** Jory's death is followed by Osric calling his name; fear and grief conversations; F.E.A.R. pairs in the fight.
- The overlay shows dialogue lines with the speaker's name as today, and whispers smaller.

## 9. The cast sheet

| Man | What he's like, what's on his mind | Ties and traits |
|---|---|---|
| **Mirelle**, the Watch-Captain (duelist, steady) | sharp, from the south, keeps the Moon-Glass in the tower; no patience for idlers | rank 4; captain; south; respected and resented; Aldous thinks her too young |
| **Osric**, swordsman (steady) | protective, reads his mother's letters aloud | kin Jory |
| **Jory**, at the postern (watchman, steady) | young, dreams of going south with a girl from the Drowned Lantern | kin Osric; sweetheart |
| **Brand**, the brute (rash) | once a rat-catcher in the Undertown; tells of the thing in the sewers | rival Ned (bullies him); undertown |
| **Wat**, archer on the wall (sly) | sings on his rounds, gambler, hears all the Lower Town gossip | rival Aldous; sings; gambler; suspected by Gideon |
| **Aldous**, lookout (watchman, stubborn) | thirty years in the Watch, bad knees, thinks a glass that looks at the moon unnatural | rival Wat; old_guard; knees |
| **Hendrik**, on his rounds (watchman, steady) | a sick daughter in Lower Town, the decent one | friend Ned (looks out for him); daughter |
| **Piers**, by the fire (watchman, craven) | jumpy, talks too much | owes Col; friend Col |
| **Col**, at his supper (watchman, steady) | always hungry, jovial, wins at dice | friend Piers; hungry; lucky |
| **Tam**, asleep (watchman, steady) | forever asleep on watch, talks in his sleep | sleeps_on_watch |
| **Gideon**, quartermaster (watchman, steady) | fussy, keeps the ledger, lamp oil keeps going missing | suspects Wat; ledger |
| **Ned**, carrier (watchman, craven) | the new recruit, two weeks in, eager and frightened | friend Hendrik; rival Brand; recruit |

## 10. The writing

**Volume:** about 22 at-ease conversations; about 16 gathering scripts (dice 3, flask 2, stories 3, watch change 4, the captain's round with a line per man, waking Tam 2, feeding the fire 2); about 5 unease; about 8 fear and grief (grief by name for each tie); about 100 solo remarks; about 25 call-and-answer pairs and excuse lines.

**Voice:** short lines, mostly under twelve words; plain, period-sounding English, no modern slang; mild oaths (gods, damn, piss); wry and grumbling at rest, human and frightened after the murder; lore dropped lightly, never explained.

### 10.1 Samples

```
== tam_resting
when: at_ease, asleep(Tam)
cast: A = any; B = any
cooldown: once
A [looks:the shed]: Is Tam asleep again?
B: He's resting his eyes.
A: For three hours?
B [shrugs]: They're very tired eyes.

== wat_sings
when: at_ease, present(Wat), present(Aldous)
cast: A = name(Aldous); B = name(Wat)
cooldown: 15m
B [murmurs]: Oh, the eel-wife of the Low Bridge, she had a crooked leg...
A [shouts]: Wat! Sing that again and I'll shoot you myself.
B: You haven't got a bow, old man.
A: I'll find one.

== the_moon_glass
when: at_ease, night:early|middle
cast: A = recruit; B = friend(A)|any
cooldown: once
A [looks:the tower]: What does the captain want with a glass that looks at the moon?
B: Same thing Hollin wants with his emeralds. To have it.
A: Brand says it shows you where the dead walk.
B {if stubborn}: Brand says a lot of things. None of them sober.
B: Brand says a lot of things. Eat your supper.

== hendriks_girl
when: at_ease
cast: A = name(Hendrik); B = friend(A)
cooldown: once
B: You're quiet tonight.
A: My girl's fever's back.
B: The physick in the Lower Town...
A [sighs]: Wants silver I haven't got. She'll mend. They mend.
B [nods]: She'll mend.

== oil_gone
when: at_ease
cast: A = name(Gideon); B = name(Wat)
cooldown: 20m
A: Two flasks of lamp oil, gone. Again.
B: Rats.
A: Rats that climb shelves and pull corks?
B [shrugs]: Clever rats.

== mothers_letter
when: at_ease, night:early|middle
cast: A = name(Osric); B = kin(A)
cooldown: once
A: Mother wrote. She asks if you're eating.
B: Tell her I'm eating.
A: She asks about the girl at the Lantern.
B [laughs]: Tell her I'm eating.

== round_tam
place: round
cast: A = captain; B = name(Tam)
cooldown: once
A [kicks]: On your feet. The Moon-Glass doesn't guard itself.
B: I was listening, Captain. With my eyes shut.

== where_is_jory
when: missing(Jory)
cast: A = any; B? = any
cooldown: once
A: Jory? Jory, this isn't funny.
B [whispers]: Stay behind me.

== grief_jory_osric
when: dead(Jory), body_found
cast: A = kin(Jory); B? = any
cooldown: once
priority: 10
A [shouts]: Jory! No. No, no, no...
B: Osric, come away. He's gone.
A {if rash}: I'll open him like a sack!
A: Find him. Find him for me.

== status_check
when: combat
cast: A = rank>=2; B = hurt
cooldown: 20s
A [shouts]: {B}! Are you standing?
B {if hurt>0.6}: He's cut me! I'm still here!
B: Standing! Come on!

== not_there
when: combat, dead>=1
cast: A = rank>=2; B = craven
cooldown: 1m
A [shouts]: {B}, round his left!
B: Not there! That's where {dead} fell!

== brand_block
place: chop
cast: A = name(Brand)
cooldown: 2m
A [murmurs]: Come on, you knotted bastard.

== tam_sleeptalk
place: sleep
cast: A = name(Tam)
cooldown: 3m
A [murmurs]: No, mother... not the eels...
```

## 11. Files

| File | What |
|---|---|
| `scripts/AISystem/Talk/TalkScript.gd` (new) | the `.talk` parser |
| `scripts/AISystem/Talk/TalkDirector.gd` (new) | choosing, casting, playback, interruption, memory (one per garrison) |
| `scripts/AISystem/Talk/TalkFacts.gd` (new) | the facts |
| `data/talk/*.talk` (new) | the cast sheet, every conversation, remark and call-out |
| `scripts/AISystem/GuardVoice.gd` (new) | heart rate, the speech ladder, murmur, emotes, breathing |
| `scripts/AISystem/GuardPastimes.gd` (new) | pastimes by dual utility with memory |
| `scripts/AISystem/Gathering.gd` (new) | gatherings and their director |
| `scripts/AISystem/NightRota.gd` (new) | duties, needs, the hour |
| `scripts/Visual/Expression.gd` (new) | gaze, posture, gait, breathing, weight shifts, variation |
| `scripts/Visual/Atmosphere.gd` (new) | wind, embers, moths, leaves, crows, breath, chips |
| `scripts/Visual/Posture.gd` | head pitch, chest lean, shoulders, breath |
| `scripts/Visual/Humanoid.gd` | the upper-body action layer |
| `scripts/AISystem/GuardLife.gd` | talk handed to the director; fidgets handed to pastimes |
| `scripts/AISystem/Guard.gd`, `GuardRig.gd` | hooks for voice, pastimes, rota, expression (kept small) |
| `scripts/AISystem/Comms.gd`, `Squad.gd` | call-and-answer pairs through the talk director |
| `scripts/Combat/Fire.gd` | fuel and light |
| `maps/npc_showcase.gd`, `scripts/Showcase/ShowNight.gd` | Act I rebuilt; the cast sheet's names and ties |
| `tools/prepare_sfx.py`, `CREDITS.md` | the approved murmur, emote and breath recordings |

## 12. Testing

- **`tests/talk_test`:** the parser (good files load; a bad one reports its file and line); choosing by conditions and specificity; casting by requirements and ties; no repeat inside a cooldown, `once`, a group used up before repeats, no man repeating a line; a failed per-line re-check ends a conversation with its interrupt line; variants chosen per speaker; a late joiner takes an optional part; one speaker per group; the ladder (pain cuts chatter; breathing resumes).
- **`tests/aliveness_test`:** pastimes never twice running and never three of five; two men of one kind differ in walk speed and rhythm; a listener's head turns to the speaker; posture differs by temperament; heart rate rises in a fight and eases after; breath particles follow breathing.
- **`tests/routines_test`:** each gathering runs with its parts and ends when a member is stirred; a watch change swaps duties with a walk-over and a line; the fire burns down and is fed, and its light follows; the captain's round reaches every man; needs move men over the night.
- **`tests/showcase_test` additions:** Act I plays at least eight different conversations with none repeated, three gatherings and a watch change; after the murder Osric calls Jory's name.
- Every existing suite stays green; new suites pin seeds.
- **Looking at it:** the review sheet, short windowed clips of conversations and gatherings, a frame-rate check with the atmosphere on.

## 13. Risks

- **Writing volume and quality:** the samples set the voice; the user can edit any `.talk` file; the talk tests check every file parses and every conversation can be cast from the showcase's men.
- **Murmur recordings:** they depend on the user's approval of specific Sonniss files; until approved, lines play silently with subtitles (the system works without them).
- **Clips that read wrong:** each library clip used for a pastime or gesture is staged; any that reads wrong is dropped from the table.
- **Performance:** twelve men with voices, expression, particles and a talk director; measured, and the atmosphere thinned first.
- **Shared files:** Guard.gd, GuardRig.gd, GuardLife.gd, Squad.gd and Comms.gd are also edited by other sessions; the work stays on the branch.
