# Player Combat Overhaul: Design

**Date:** 2026-09-26
**Status:** built and tested (`tests/blade_test`, B1–B14); this document awaits the user's review.

## 1. Goal

Make fighting a call and answer, in the manner of Dark Messiah of Might and Magic, Chivalry 2 and Sekiro: every blow asks for an answer, the right answer turns it into an opening, and the wrong one costs you. It should feel snappy, weighty, fast and difficult.

The existing system already had most of the parts: directional swings picked by how you move the view, charged power blows, combos, block, parry and riposte, block-to-feint, the dodge and the kick, stamina, guard posture with deathblows, and perilous calls (a colour on the guard's blade for what his blow asks of you). This overhaul adds the answers that were missing, stops "hit him first" beating everything, and makes weight and balance readable.

It changes rules only; animation is untouched (the HEMA animation work is separate).

## 2. Decisions

| Question | Decision |
|---|---|
| Starting point | **Build on the current rules**, not replace them. The existing suites stay green; where a rule changed on purpose, its check was updated to match (section 6). |
| Player resource | **Stamina stays** (Chivalry). It also pays for being parried, being blocked and clashing, so spamming into a guard drains you. Posture stays the guards' (Sekiro). |
| When a blow is committed | **At the guard's glint** (64% of his windup, `GuardFighter.COMMITTED`). The glint was already the rig's "committed" signal, and his feints always break off earlier (36–52%), so it never lies. |
| Where answers resolve | **At his blow's contact**, in `PlayerCombat.filter_incoming`, before a raised guard has its say. A single place decides Mikiri, counter, clash, parry or block. |
| Forward momentum | **Only the running blow** carries extra weight. A general forward bonus would have changed nearly every blow at normal movement speed (6.5 m/s). Backing away at pace weakens a blow. |

## 3. The answers

Each of his blows has a call (`GuardFighter.CALLS`, shown in the colour of his blade): cut (pale), thrust (blue), low (orange), unblockable (red), bash (gold).

| Answer | How | What it does |
|---|---|---|
| **Parry** | Block pressed within 0.25 s of the blow landing. | His posture +34 (+50 against a thrust); your riposte window opens (0.9 s). |
| **Perfect deflect** | Block pressed within 0.1 s. | ×1.5 on his posture (two perfect deflects open a swordsman); no stamina cost, and a bigger refund; the riposte winds up in 30% of the time, not 40%; a brighter ring and a longer slow-motion beat. |
| **Counter** (Chivalry and Mordhau's chamber) | Start your own blow within 0.2 s before his lands, answering its call: any cut against a cut, a thrust against a thrust. | His blow is turned as by a parry (×1.3 posture), and yours goes on into him at once as a riposte (×1.5 damage). The wrong family (a cut into his thrust) is no counter: you are hit mid-windup and lose the blow. |
| **Clash** | Your blow already in the air (the first 70% of its strike, not yet in him) when his lands, without being a counter. | Neither lands. You recover as from a blocked blow (−6 stamina); he recovers as from a raised guard (+12 posture). Hits can't be traded. |
| **Mikiri** (Sekiro) | Against a thrust: dodge toward him within 0.35 s before it lands (forward and Q). | You're on his blade: no damage, his posture +62, he reels for a long time, and your riposte window opens, quick as off a perfect deflect. Stepping into a cut is no Mikiri: it lands. |
| **Jump, dodge** | Unchanged. | Jump his sweep; dodge his great blow and his kick. |

**Committed blows.** Before his glint, a quick cut that reaches him stops his blow ("beating him to it"). After it, his blade is let go: a quick cut marks him, but his blow still lands, so you trade. A power blow still stops him. The brute's blows were already never stopped by quick cuts.

## 4. Weight

- **Running blow** (Dark Messiah, Chivalry 2's sprint attack): a blow begun at a sprint carries you in (6 m/s for 0.2 s) and does ×1.35 damage. It presses his guard as hard as a heavy blow (poise 2.5, where a quick cut is 1 and an overhead 2). A miss carries you on 0.25 s longer. Sprinting isn't cut short while it winds up.
- **Backing away:** a blow thrown moving away from him faster than a shuffle loses up to 20% of its damage, at a walk.
- **Swinging slows you:** ×0.85 of your speed while winding up, ×0.8 while cutting, ×0.9 while recovering.
- **Being parried** costs 10 stamina, being blocked 3 and a clash 6: your balance is thrown with your blade.

## 5. Readability

- **His balance over his head** (`StealthHUD.PostureMarks`): for each man fighting you within 16 m, a bar filling from the middle, amber to red, once his posture is shaken. When he's open it's replaced by a red diamond: the next blow is a deathblow. The arms master, whose balance can't go, shows none.
- **Answers are heard and felt:** a perfect deflect rings brighter, with a longer beat of slow motion. A counter and a Mikiri spark between the blades and hang the moment. A clash stops both blades with a heavy clang.
- **Squad reads:** a counter is read as a parry (+0.3), a Mikiri as a dodge and half a parry. The garrison learns that you parry, and feints and delays more.

## 6. Tuning

| Value | Setting |
|---|---|
| `perfect_window` | 0.1 s |
| `perfect_posture` | ×1.5 |
| `perfect_riposte_windup` | ×0.3 |
| `counter_window` | 0.2 s |
| `counter_posture` | ×1.3 |
| `clash_until` | 0.7 of the strike |
| `mikiri_window` | 0.35 s |
| `cost_parried` / `cost_blocked` / `cost_clash` | 10 / 3 / 6 stamina |
| `running_damage` | ×1.35 |
| `running_lunge` | 6 m/s for 0.2 s |
| `running_poise` | 2.5 |
| `running_miss_recovery` | 0.25 s |
| `backing_penalty` | 0.2 at most |
| Speed scale while swinging | windup 0.85, strike 0.8, recovery 0.9 |
| `GuardFighter.COMMITTED` | 0.64 of his windup |

Time effects for pace:
- A plain parry now takes 0.2 s of slow motion at 0.55 speed (it was 0.35 s at 0.35), so a fight with many parries stays fast.
- The longer beats are for the answers that earn them: a perfect deflect gets 0.3 s at 0.4, a counter 0.25 s at 0.45, and a Mikiri 0.4 s at 0.35.

Changed checks:
- `exchange_test`'s parry helper now raises the guard 0.2 s before the blow, so its checks keep measuring plain parries. A perfect deflect would open him after two.

## 7. Where to try it

- **Bay 2 (swordsman):** perfect deflects and counters, and committed blows after his glint.
- **Bay 3 (swordmaster):** Mikiri against her thrust, and her balance bar to a deathblow.
- **Bay 8 (arms master):** his steady beat, for practising every answer.

## 8. Known limits

- A counter doesn't check the side of a cut: any cut answers any cut.
- The clash is decided at his contact, from the phase of your blow, not from where the blades are in the air.
