# The Exsecrator's deaths: by the eyes, by the ánimas, by both

## Why

The user: "death animations for the playable character, being killed by either or both". Today every death is the same: the camera falls for 0.9 s, the screen fades, the words come up, and at 2 s the death page. Whatever is feeding on you is thrown off the moment you die, so the monsters that killed you let go at the moment they won. The fights now have real character (swipes, the turned eye, one body under attack). The end of the fight should be the worst moment of it.

## Goals

- A death by each kind of monster that looks like what that monster does to you.
- With both on you, one death, not two laid over each other: the same one body under attack, finished.
- It carries straight on from the fight, with no cut: the same flesh, eyes, hands and face still on screen.
- The death page still comes promptly: long enough to land, short enough to bear on the tenth death.

## Non-goals

- Deaths by guards, falls, hazards and anything else: they keep today's fall, untouched.
- Showing the Exsecrator's body from outside. The user chose first person, and the modelled body doesn't exist.
- Hand-keyed Blender clips. The poses are sprung, in the existing pose tables, with new entries added where a beat needs them (crawling off, going slack). One or two big moments could be keyed later if the poses feel thin.
- A death for the torso of its own: it is still a stand-in. Killed by its swipe, you get the swipe death.
- Changing what kills you, or when. Damage, the drain and the curse are as they are.

## Anti-goals

- Nothing on screen named or worded by Claude. No new text.
- No cut, freeze-frame or swap to a copy of the effects at the moment of death.
- Green fire or gore drawn solid and cheap: judged in the game, close up, in the lit room and the dark yard.
- A sequence you are made to sit through every time.

## The four deaths

All four are Claude's proposal, which the user has not objected to, picking first person and the live build on top of it. Times are first guesses to tune in play. The middle of the screen no longer has to stay clear: you are dying.

**The eyes (about 3 s).** Your sight sinks as your legs go. The flesh closes all the way in, slowly and beating, faster, then failing. Every eye that was open opens wide and turns on you, and more tear open than the curse ever had. A last one tears open in the very middle, looks at you, and that is the last thing you see. Then dark.

**The ánimas (about 3.5 s).** They don't let go. Their weight takes you down onto your side, the hands still on you, your sight dragged toward them. Colour drains to nothing with each gulp, slower and deeper each time. A face, if one has you, fills the view for one long last gulp; if only hands have you, they squeeze and stop. Then they lose interest: the hands slide off, and from the floor, still seeing, grey, you watch them crawl away. Your sight fails from the edges.

**Both (about 4 s).** As the ánimas' death, in the pale flesh. The flesh closes while they feed, and all its eyes watch them finish you. On the last gulp, the eyes all shut together, the heartbeat stops, and the flesh goes slack. There is no eye in the middle: they were not the ones who took you. The ánimas crawl off through the slack flesh's last gap.

**A swipe that kills (about 2 s).** Short, since it is one blow. A last rake across your view, from the side it came from, marks left open. You drop among them, and from the floor you see them lose interest. With the curse on you, its flesh is there and falls slack, without its own ending.

## Which one plays

Decided once, at the moment of dying, from what is true then:

| On you when you die | The last blow | The death |
|---|---|---|
| Curse and something feeding | any | Both |
| Something feeding, no curse | any | The ánimas |
| Nothing feeding | an eye's bite or a gob | The eyes |
| Nothing feeding | an ánima's swipe | The swipe |
| Anything else | anything else | Today's fall |

So a guard's bullet killing you while an ánima feeds is an ánima death: it was feeding when you went. A guard killing you with only the curse on you is today's fall, with the curse fading as it does now.

## Approaches

The user's pick is the first.

- **Live, with a death director (picked):** a new node on the player chooses the death and drives the camera and the effects already on screen. No cut, nothing duplicated, the world keeps running so the ánimas really can leave. The cost is that much of the code treats dead as stop, and each of those places has to ask the director instead. That is the likeliest place for bugs.
- Separate staged scene: safest for the rest of the game, but a visible cut, copies of approved looks, and a frozen world where nothing can crawl off.
- Hand-keyed in Blender: potentially the strongest single performance, much slower, and a second animation system beside the springs. Still possible later for a moment or two.

## Settled before planning

From the project as it stands:

- **`PlayerController._die`** sets `is_dead`, drops what you hold, and waits 2 s before `hud.show_death_page()`. `died` still fires at once, as saves and tallies expect. Only the wait changes: it lasts as long as the death playing.
- **The fall** is `juice.death` in `CameraJuice`. Today's fall stays as it is for other deaths. The new deaths write their own pose through the same place, since aim no longer matters.
- **What treats dead as stop, and has to change while a death plays:** `LifeLeech` throws everyone off when `player.is_dead`; `LeechHands._process` hides hands and faces; `StealthHUD._show_curse`'s `alive`, `_show_drain`'s and `_tell_each_other`'s `held`; and the HUD's fade and death words start at once. They ask the director whether the fight is still on screen, rather than each reading `is_dead`.
- **The words** "You were caught." and the page's words stay as they are. Those words were written for guards, so the user may want others for a hunt: their call, not part of this.
- **Knowing the last blow:** `take_damage(amount, from)` has it, and `drain_life` means the drain. The gob passes itself as `from`, so it needs to say whose kind it is.
- **No save change:** nothing about a death is saved. The save is loaded from the page.

Claude's calls:

- **You can skip.** After the first second, an attack press goes straight to the page. A hard hunt means many deaths, and the anti-goal forbids making you sit through each. Cost if wrong: it is easy to take out.
- **The end of a death:** the screen is already dark when it ends, so the HUD's fade finishes with it, the words come up over its last half second, and the page opens when it ends. No extra moment for the words alone, which would add about a second to every death. A skip does the same in that half second. Today's fall keeps its own timing.
- **The eyes that stare in a death are the flesh's, on screen.** The real eyes in the world drift off as they do now, and their stare marks close with them: `FloatingEye` does not change, and the whole beat lives in the curse's shader.
- **Ánimas once you are dead:** every awake ánima loses interest and crawls off, in every death, today's fall included, feeding or not. Today they go on rushing and swinging at your body, even behind the death page, which was never meant. It is the one change to today's fall; its camera, timing and words are untouched.
- **Anything that dies after you** (your Burst's wave landing late, a copal cloud burning on): a feeder that dies mid-death lets go and burns as normal, and the death goes on with what is left. If the last one goes, the death finishes on its own sight and colour.
- **Sounds** use stand-ins from what is approved. Wanted takes go on `docs/superpowers/refs/hunt/sounds_needed.md` and the ElevenLabs prompts.
- **Frame cost:** the sequences add no more than the fight they replace; measured with `tests/diag_mixed_perf`.

## Constraints

- Godot 4.5.1, GDScript. Failing checks first. `--fixed-fps 60` determinism with seeded rolls where a test reads them.
- No `juice.punch` pitch for anything repeating; the camera is not being aimed by then, but `juice` must be left clean for the reload.
- Stills from the real game, both lit room and dark yard, at each beat, inspected close up before anything is shown.
- Effects are made by us. Words are the user's.
- The checks that assert today's behaviour (thrown off on death, hands hidden at once) change on purpose, for these deaths only. Off a hunt, every existing death check still holds.

## Left to the builder

- The exact poses, camera curves and shader uniforms, within the beats above.
- How the director is told the last blow.
- The look of the last eye tearing open in the middle, and of the flesh going slack.
- Which approved sounds stand in.
