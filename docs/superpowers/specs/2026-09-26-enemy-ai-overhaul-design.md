# Enemy AI Overhaul: Design

**Date:** 2026-09-26
**Status:** built and tested (`tests/wits_test`, W1–W35; posts and places, section 4.8: `tests/posts_test`, P1–P12; states, blades, chases and routs, section 4.9: `tests/hunt_test` H10e, H17–H22, `tests/habits_test` H28–H29, `tests/stealth_test` D1–D4); this document awaits the user's review.

## 1. Goal

Make the guards think, talk and fight like a garrison instead of a set of separate state machines. The user asked for better pathfinding, behaviour, group strategy, lookouts, use of the environment, communication between NPCs, combat skill and strategy, and picking things up. Mid-way they added: scared guards should plead for their lives, kneeling or standing, and run to their own when you walk away.

The player-combat overhaul (Might and Magic, Chivalry 2, Sekiro: call and answer, parries, ripostes) was **deferred** while this was built (the user said to focus on enemy behaviour first); it has its own design since (`2026-09-26-player-combat-overhaul-design.md`). Nothing here changes how the player fights.

A follow-up (section 4.8) came from playing it: men did not handle their places well. A watchman never came down from his tower to help or called the others; nobody picked things up and threw them when it would help them win; and some of what they did was disruptive (men standing idle in a fight, a cry of murder over every man who fell mid-fight).

## 2. Decisions

| Question | Decision |
|---|---|
| Where new behaviour lives | **Small modules beside `Guard.gd`**, one per concern, each holding its own state (`GuardNav`, `GuardLife`, `GuardHands`, `GuardMercy`), plus static helpers (`Comms`, `Dangers`). `Guard.gd` and `GuardFighter.gd` call into them instead of growing further. |
| How guards talk | **Through `SoundBus`, as sound.** A call-out is a sound event carrying a `message` (`SoundBus.emit_message`). Walls, distance and hearing decide who gets it, exactly as for any noise. Nobody knows anything by magic. |
| How things are found | **Groups and physics queries, never tree walks.** Each script joins its own group (`doors`, `hazards`, `hanging_weights`, `explosives`, `dropped_weapons`, `alarm_bells`, `stray_arrows`, `landmarks`). |
| Level memory | **`Garrison.gd` stays the one place the level remembers you:** alarm, missing posts, who is looking into what, gossip, and now mercy. |
| Presentation | **Existing clips only** (Universal Animation Library), shown through `Humanoid.show_action` from `GuardRig`. No new animation assets. |
| Pleading | **Only broken men, and not proud ones.** Pleading hangs off the squad's existing resolve (`Squad.will_of == broken`), so it follows the morale rules already there: friends, captain, wounds, dread. |

## 3. Scope

**In scope:** guard navigation, perception of things out of place, idle life, communication, squad roles, combat choices, use of the environment, picking things up and throwing them, pleading and fleeing to allies; the NPC gym showcase; tests.

**Out of scope:** the player's own combat, animation assets, level art.

## 4. What they do now

### 4.1 Getting about (`GuardNav.gd`)
- **Crowding:** men ease apart instead of stacking, and pass one another on the right in passages.
- **Detours:** walking into something the navmesh does not know about (a crate you pushed, a man coming the other way), a guard steps round it instead of stopping there.
- **Doors:** a closed door on his path is opened as he reaches it.
- **Pursuit:** he runs for where a running man will be (lead), and follows the way you went a few steps before he stops to look (scent).

### 4.2 Word between them (`Comms.gd`, `SoundBus.gd`)
- Whoever sees you calls where you are to those who cannot, by landmark ("by the well"), height ("up high") or side ("to my left"). He calls sooner when one of them is about to lose you (`Squad.may_call(urgent)`).
- Lookouts call from their post; danger calls ("Powder! Get back!") send men clear.
- Heard noises are claimed: one man goes to look, a friend covers him, and "clear" stands them down (`Garrison.look_into`).

### 4.3 Their rounds (`GuardLife.gd`)
- Men at ease talk in turn about what is on the garrison's mind (`Garrison.gossip`): the dead, the dread, your habits, the men you spared or cut down begging. Anything that stirs them ends it.
- Idles: arms folded, a pull from the flask.
- **Things out of place:** a door you left open (seen by its panel or by the gaping doorway), your arrow in a wall, a torch you put out (§4.10). He notices it, goes to it, deals with it, and searches round it; the garrison stirs.
- **A missing man:** someone who knew him looks at his post, says his name, and goes to see.
- **Lanterns:** searching the dark with the garrison roused, he lights one (and it lights him).
- **Lookouts** sweep their ground from a post, and run to ring the bell (`AlarmBell.gd`).

### 4.4 Hands and the environment (`GuardHands.gd`, `Dangers.gd`, `Thrown.gd`)
- Knocked down, a man may lose his blade (`grip_loss` by archetype). He goes back for it or any blade near, and fights with fists and boots until he has one.
- You out of reach on a roof: he picks up something loose and throws it, lobbing it over anything in the way.
- **Lit powder:** they get clear of it and shout it. An archer **shoots the powder beside you**, or **the rope of a weight hung over you**, with a careful aim at such small marks.
- **Your back to spikes, fire or a drop:** he makes up his mind to boot you into it, closes to a kick's reach, and kicks.

### 4.5 Squad roles and tactics (`Squad.gd`)
- **Lookout** keeps his post and calls. **Intercept:** you running, one man cuts you off while another chases.
- **The watcher:** hunting in numbers, one man keeps watch from a vantage near your last sighting, even while the rest search.
- **Help:** a broken man runs to fetch the nearest man, or rings a bell if one is nearer.
- **Reads:** besides turtle, spam, kite and bow, they read parries (more feints, delayed blows, perilous ones) and dodges (tracking blows, reach, low cuts).

### 4.6 Their blows (`GuardFighter.gd`)
- Follow-ups **answer how the last blow went**: caught on your guard, the pommel, a low cut or the point; stepped out of, the thrust or the lunge; landed, another quick one. A blocked string turns straight to a guard-breaker.
- **Footwork you have to read:** a swordsman drifts in and out of the edge of your reach.

### 4.7 At your mercy (`GuardMercy.gd`)
- **Plead:** broken and caught, he throws his blade down towards you and begs. Caught means you are within 3.2 m (seen, or right on his heels within 2 m) and either coming at him (closing, or swinging) or he is too hurt to run (under 35% health). If you stand off, he runs while he can. He kneels if terrified (little nerve or badly hurt), otherwise he stands with a hand held out. He neither guards nor strikes.
- **Spared:** walk away (past 6 m, or out of his sight, for 1.2 s) and he gets up, thanks you, and runs to the nearest place he would be safe: men of his own, well away from you and not past you, the more of them the better. There he keeps them between you and him and tells them where you are; men not already hunting you come. With nobody to run to, he just runs.
- **Struck:** hit him while he begs and he cries out and runs, and he will not beg you again.
- **Heart back:** friends arriving can put heart back into him. He gets up to fight on and goes back for his blade.
- **Proud men do not beg:** nerve 0.65 or more (duelists, brutes, the arms master).
- **Consequences:** the garrison remembers. Each man you cut down begging adds dread and lowers the chance the next man begs at all (`Garrison.mercy_hope`), unless you have spared as many. The men talk about both.

### 4.8 Posts and places (follow-up)

**A man set to watch** (`Guard.lookout`: `Guard._holds_post`, `Squad._keeps_post`):
- **Watches from his post.** Word of you from his own, the bell, a noise: while he has friends within 30 m to do the walking, he looks from where he stands, turned to the place, and does not walk down to it.
- **Sends a man.** Something he saw or heard himself, he calls the nearest friend at his ease by name ("Osric! Something by the well! Go and look!") and covers him from up there; the man says so when he finds nothing, and the lookout stands easy. One man out at a time.
- **Calls them all out.** If the man he sent goes quiet (knocked senseless), he shouts it by name ("Osric's gone quiet! To arms!"): everyone who hears comes, the garrison is roused, and he keeps watching.
- **Rings the bell.** His friends fighting below and a bell within 30 m to be rung: he rings it first, whatever else he hears on the way. In a fight, a bell near comes before anything else.
- **Keeps his post in a fight** while two or more of them are at you (or, just after he has seen you, while there is anyone near to call in), calling where you are, and throwing down what is to hand on his own level.
- **Comes down** (and says so: "Hold him! I'm coming down!") when he is needed: one of them cut down in the last 20 s, their heart below 0.55, falling back or routing, you within 4 m of him, or no sight of you for 4 s from up there (he is no use to them blind). Stirred and seeing nothing of it for 3 s while they fight below, he comes down too; and fetched by a runner, he comes. Once down he stays down until the hunt is over; then he goes back up.
- In a hunt he is its eyes: he keeps watch from his post, and nobody else is sent to a vantage.

**Places in a fight** (`GuardFighter._footwork`, `Squad._give_places`):
- A man waiting his turn goes round to his place at a walk at least (a plain watchman stood frozen where he was).
- At your side or back and you busy with another (swinging, blocking, drawing, facing away): he does not wait at the edge of reach, he steps in and punishes it, as the plan always meant.
- The man in front stays in front unless another is clearly better placed (a metre, give or take): no swapping round every moment. A man is sent to cut you off only once you have been running for half a second, and keeps at it until you have stopped for 0.8 s.

**Things thrown when it helps** (`GuardFighter._throw_worth`, `Squad.may_throw`):
- Not only for want of a blade or a way to you: a man waiting his turn while another is at you, a lookout at his post, a man you keep out of reach of (5 m, for 2 s), or one you run from, goes for something within 6 m, and throws it. A sly man is likelier to.
- One man of the squad at a time, and at most one throw in 3 s. Come at him while he has it and he drops it for his blade.
- The gym's lookout has two crates up on his platform.

**The dead** (`Guard._discover`):
- The parts of one man (a head, an arm) are one find, not three.
- A man cut down in front of his friends is no news to them: no cry of murder mid-fight, and no search begun over him.
- Shouted at most every 15 s.

**Covering a friend** no longer blinds a man: seeing you himself, he stops covering and it is his own business (`GuardLife._update_cover`).

### 4.9 States, blades, chases and routs (follow-up)

From playing it: their states mixed (a man chatting while he walked back to his post, bread and a flask seconds after a fight, a thrown stool carried about the hunt), they spoke over one another, chasers gave you up too easily and routed men did foolish things; blades were always out; and the player could not tell who was noticing him, or how fast.

**One state at a time** (`Guard._set_state`, `GuardLife`, `GuardHabits`):
- Stirred, whatever he was saying or doing with himself ends: talk, a look he was covering for a friend (a fight shouted, the bell, a call of where you are, or a noise somewhere else take him off it), the evidence he was stooping for, a lantern (dropped into a fight). Things out of place are noticed only at his ease, or, suspicious, near what stirred him; a missing man only at his ease.
- **On edge** (`Guard.wary`: hunting you in the last 60 s, or the garrison's alarm at 0.45 or more): no sitting, eating, dancing or gossip; only pacing and a look about him; his greetings are wary ones ("Seen anything, Osric?"), and his blade stays out.
- Knocked bladeless, he goes back for a blade near (15 m) before his rounds. A thing picked up to throw is let fall when the fight ends; one let go unthrown is not picked up again for 8 s.
- **What they say:** what many would say at once ("I'm coming!", "Hm? What was that?", "Lost him!", "Probably nothing.") is said by the first man near (`Comms.may_voice`, 18 m, 2.5 s); a state's line waits a moment (0.35 s) in case he is sure of it the next instant, and goes unsaid if his state has moved on; he does not say the same sort of thing again within 8 s. "Must have been rats." only if he never saw you and the garrison is not roused; otherwise something that knows better ("He's gone. Keep your eyes open."). The hunt's watcher says so once. Where you are is called to men who would come to it (off searching, not fighting at your side who lost you a moment), and said aloud now and then, not at every call.

**Blades** (`GuardRig._update_blade`, `Guard.wants_blade`):
- At his ease his blade is **in its scabbard**: the hilt at his hip over the scabbard his outfit wears (the watchman's, the swordsman's, the arms master's; the duelist's rapier in her hanger); a maul slung across a brute's back, a crossbow upright between an archer's shoulders.
- He **draws it** looking into something, hunting or fighting you, or on edge: his hand crosses to the hilt (two-bone IK, `ArmReach.gd`, the elbow out in front), the blade comes up out of the scabbard along it with a ring (`blade_draw`), and swings free. In a fight it is out at once, his hand whipping up from the hip with it. At his ease again he **puts it away**: down into the scabbard along it, a slide (`sheath`), his hand back. Anything else his arms are busy with (a blow, a stagger, a pose), or a weapon on his back: out or away with no reach, still heard.
- Put by while his sword hand is wanted (a thing to throw, his rounds lantern, the axe, bread, a seat, arms folded, a rung, swimming).
- Killed with it in its scabbard, it stays on him; knocked down, a sheathed blade does not fly; begging, he draws it and throws it down.

**Chasing** (`Guard._trail_point`, `_do_search`, `GuardFighter._chase_point`, `Squad`):
- Lost sight of you, he keeps on the way you went a few steps at a time while you are fresh in his eye (4 s), not stood at the end of it.
- **The trail:** lost you on the move, the search starts by running on after you the way you went, as far as you could have got since (up to 18 m), each man a little to one side (not in single file); there he looks about him.
- Word or a sound of you mid-search breaks off his look and sends him to it at a run for 5 s, and he does not give up while it keeps coming. Called to a fight (a shout, a call of where you are, the bell) he runs; a noise to look into, he walks.
- The hunt's watcher keeps one watch for each place you were last seen (25 s), then searches with the rest.
- A flanker at your back strikes after a moment (1 s), busy or not; a patient man waits for his moment 7 s at most.

**Routs** (`GuardMercy`, `GuardFighter._flee`, `Squad.helper_for`):
- One man begs you at a time: with another begging within 8 m, he runs while he can (unless too hurt to).
- Running, he goes where the ground takes him away from you (seven ways looked at, never back past you within 2 m), kept a moment so he does not dither. With you on his heels (7 m) he hears you: he does not give up the flight. With nobody to run to, he makes for a bell within 35 m he can reach without going past you, and rings it; else, clear of you (18 m, 3 s unseen) he goes back to his post rather than standing about.
- A man is not sent for help to a man he would have to run past you to reach.

**Signs of being noticed** (`StealthHUD.AwarenessMarks`): over each man noticing you (45 m), a ring that fills with his alert as he makes you out (to `combat_at`: then he has you), notched where he grows suspicious and where he comes to look. Inside it an eye (its lids opening) while he looks at you, a "?" when he has only heard something or is looking for you (broken ring: hunting), a red "!" once he has you, bursting as he calls it, and the first of them to have you named under it (3 s). The ring's edge glows and a halo beats while it climbs, faster the faster he is making you out; the man nearest to having you is drawn biggest. Off the screen, his mark sits at its edge, pointing the way he is (behind you: the bottom). A man at you with his balance bar over him loses his mark once he has called it.

### 4.10 Hunting you, and the lights (follow-up)

**What the player sees and hears of being noticed** (`StealthHUD`, `Settings.gd`):
- While a man is making you out (his ring climbing), a **tick**: as often as he is quick about it (every 0.62 s slowly, 0.14 s at a rush), higher and louder the nearer he is to having you. None while nobody is climbing.
- A man noticing you from **behind a wall** (a ray from your eye to his, every 0.12 s) is marked at 42% of his mark's strength.
- The **pause screen** has a setting, "Marks over guards: shown/hidden", kept between games in `user://settings.cfg`; hidden, there are no marks and no ticks. The pause screen is now in the middle of the screen (it was mostly off its top-left corner), and a click on it resumes (the screen used to swallow the click).
- The subtitles name who is speaking ("Isolde, duelist"), as the mark over the first man to have you does.

**Searching where you could hide** (`SearchSpots.gd`, `Guard._next_search_point`, `Squad.search_spot_for`):
- The places round where he thinks you are (rings every 1.6 m out to his reach: 6 m alone, 8 m for the hunt) are weighed up: **dark** (LightProbe), **shut in** (walls or crates close round it on eight sides: a corner, between crates, an alcove; a spot by a wall is also tried a step further in, into the corner if there is one), **out of his sight** from where he stands, and **the way you were going**. And two kinds of place more: a **room** through a door near it, on the far side from where you were (he goes 2.5 m in and looks round it), and a **ledge** over it you could have climbed to (he stands back from its foot and looks up over its lip). A place he has no way to by the navmesh is passed over.
- He goes to it **looking into it** (his head and his eyes, so what he sees follows: into a corner, up at a ledge, into a room), and first thing when he gets there; then about him, the way you were going first. With a **light in his left hand** (the lantern he lit to search by, or a torch) he **holds it out** to what he is looking into (`GuardRig`, two-bone IK), and it lights it as any light does.
- A place searched, by him or by the hunt, is left alone 60 s (unless you are seen again).
- The hunt shares the ground out as before (4 m apart, leaning the way you went, the sly man cutting you off); now a man going through a **door into a room** has another hold it: back 2.2 m from it on this side, watching the doorway, his look twice as long.
- Going to a place, now and then he says so ("Check the corners.", "Up there, are you?", "Anyone in here?"); the man holding the door always ("Go in. I've got the door.").

**Trackers** (`Guard.tracker`, `Guard._tracked_trail`): the sly (guile 0.65 or more) and archers read the ground. Lost you on the run, their trail goes the way the floor goes on from where they lost you: straight on if it goes as far, else the least turn off it that does (round a corner, through a doorway), as far along it as you could have got; never a way that is a long way round. Everyone else's trail runs straight on, and now **ends at a wall** across it (it used to carry on to the floor beyond).

**The lights** (`Torch.gd`, `GuardLife`, `GuardHands.relight`, `Garrison`):
- The levels' own torches on the walls (`Torch.can_douse`: set by each map's `_torch`) can be **put out**: look at one within reach, [E] "Put out the torch": dark, a hiss (heard 30 dB, close by only) and a wisp of smoke.
- A guard at his ease (or stirred, near what stirred him) who sees a torch **dark where it should burn** (14 m; its not burning is the tell, so it takes no light to see) says so ("The torch has gone out."), goes to the floor under it, and **lights it again**: facing it, his left hand up to it (2.2 s, lit 1.5 s in); then searches about it as for anything out of place.
- One torch out is a draught (the garrison's alarm to 0.15). **A second out within 150 s** of the first is somebody at work in the dark: "Another light out? Someone's putting them out!", and the alarm to 0.45, so men searching the dark take lanterns with them. The garrison talks of it at their ease ("The torches keep going out.").

## 5. Where to see it

The NPC gym (`maps/npc_gym.tscn`):
- **Bay 1:** a second watchman to talk and cover with, and a storeroom door to leave open.
- **Bay 9 (guardhouse):** a lookout platform with a bell (and two crates up there for him to throw down); landmarks they call you by; crates to throw; powder by the gate; off-duty men in the barracks; a craven swordsman who is first to break and beg.
- **Bay 10 (climb & swim, the `-` key):** guards climbing, dropping, leaping, on ladders and swimming after you (`2026-09-26-climb-and-swim-design.md`).

F1 labels show what each man is doing, including "BEGGING FOR HIS LIFE" and "safe with his own". The panel shows men spared and men cut down begging.

`tests/visual/stage_mercy.tscn` films men begging, kneeling and standing, and getting up when let go. `tests/visual/stage_sheath.tscn` films each kind of guard with his weapon put by, drawing it and putting it away; `tests/visual/stage_detect.tscn` films the signs of being noticed (and a man behind a wall, and the pause screen); `tests/visual/stage_search.tscn` films a man searching a room with a lantern (a nook between crates, a side room through its door, a ledge, dark corners); `tests/visual/stage_lights.tscn` films a torch put out, noticed, and lit again.

In any gym, the torches on the walls can be put out.

## 6. Success criteria

1. `tests/wits_test` passes W1–W37 (getting about, word between them, rounds, things out of place, hands and environment, blows, the hunt, mercy, routs; torches put out: W36–W37), `tests/posts_test` P1–P12 (the lookout, things thrown, places, the dead), `tests/hunt_test` (chases: H17–H22; not sent past you: H10e; searching and tracking: H23–H26), `tests/habits_test` H28–H29 (blades), `tests/stealth_test` D1–D7 (signs of being noticed, the tick, a man behind a wall, the setting) and `tests/interaction_test` U7, U11, U13–U14 (the pause screen and its setting, named subtitles, a torch put out).
2. Every other suite passes, run as the project documents (`--fixed-fps 60`).
3. In the gym, each behaviour above can be provoked and watched.

## 7. Known limits

- Pleading poses reuse existing clips: `Fixing_Kneeling` held and rocked for kneeling, `Spell_Simple_Idle` (a hand held out) for standing. The kneeling man bows to the floor rather than looking up at you.
- A haven is found by straight-line distance; a man whose path there stalls gives that haven up for a while and tries another.
- Running from you, a man who neither sees nor hears you for 12 s (3 s once 18 m clear) gives up the flight and goes back to his rounds; once sheltered with his own he stays where he reached them until you come near.
- The trail is a guess along the way you were going: turn a corner out of his sight and a plain man stops at the wall (a tracker takes the corner, but only the likeliest turn of the floor, not the one you took).
- The navmesh keeps scraps of floor sealed inside tall blocks (the baker sees their faces, not that they are solid); a search place there is passed over (no way to it), but anything else that snaps a point to the navmesh can still land on one.
- A torch is lit again from the floor with a hand raised to it: one hung higher than he can reach is lit from as high as his hand goes. You can reach torches up to about 3 m (the reach you use things with, 2.2 m from your eye); a torch put out by a guard (none do yet) would not count as out of place.
- Braziers, campfires and guards' own lights cannot be put out.
- The draw is procedural (a reach and a swap, no draw clip in the library): the blade can pass close to a leg as it swings free. A maul or a crossbow comes off the back with no reach.
- A lookout judges whether he can see the fight by whether he has seen you lately, not by where the fight is: in a dark yard he comes down after a few seconds even if you step into his light a moment later.
- Things are thrown at where you will be, not round corners: no clear line to you, no throw.
