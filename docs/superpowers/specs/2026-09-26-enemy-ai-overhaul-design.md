# Enemy AI Overhaul: Design

**Date:** 2026-09-26
**Status:** built and tested (`tests/wits_test`, W1–W32); this document awaits the user's review.

## 1. Goal

Make the guards think, talk and fight like a garrison instead of a set of separate state machines. The user asked for better pathfinding, behaviour, group strategy, lookouts, use of the environment, communication between NPCs, combat skill and strategy, and picking things up. Mid-way they added: scared guards should plead for their lives, kneeling or standing, and run to their own when you walk away.

The player-combat overhaul (Might and Magic, Chivalry 2, Sekiro: call and answer, parries, ripostes) is **deferred**. The user said to focus on enemy behaviour and AI for now. Nothing here changes how the player fights.

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
- **Things out of place:** a door you left open (seen by its panel or by the gaping doorway), your arrow in a wall. He notices it, goes to it, deals with it, and searches round it; the garrison stirs.
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

## 5. Where to see it

The NPC gym (`maps/npc_gym.tscn`):
- **Bay 1:** a second watchman to talk and cover with, and a storeroom door to leave open.
- **Bay 9 (guardhouse):** a lookout platform with a bell; landmarks they call you by; crates to throw; powder by the gate; off-duty men in the barracks; a craven swordsman who is first to break and beg.

F1 labels show what each man is doing, including "BEGGING FOR HIS LIFE" and "safe with his own". The panel shows men spared and men cut down begging.

`tests/visual/stage_mercy.tscn` films men begging, kneeling and standing, and getting up when let go.

## 6. Success criteria

1. `tests/wits_test` passes W1–W32 (getting about, word between them, rounds, things out of place, hands and environment, blows, the hunt, mercy).
2. Every other suite passes as before. Four checks already failed before this work and are unrelated to it: `smooth_test` S4, `life_test` L17, `wardrobe_test` K6 and K12.
3. In the gym, each behaviour above can be provoked and watched.

## 7. Known limits

- Pleading poses reuse existing clips: `Fixing_Kneeling` held and rocked for kneeling, `Spell_Simple_Idle` (a hand held out) for standing. The kneeling man bows to the floor rather than looking up at you.
- A haven is found by straight-line distance; a man whose path there stalls gives that haven up for a while and tries another.
- Once sheltered, a man who does not see you for 12 s gives up the hunt and goes back to his rounds.
