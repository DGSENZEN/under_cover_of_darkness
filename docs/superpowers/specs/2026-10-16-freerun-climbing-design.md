# Free-run climbing (Assassin's Creed 2 / Unity, in first person)

Agreed with the user on 2026-10-16. This is the first project of the Mexico City demo program (`2026-10-16-mexico-city-demo-program.md`), and it replaces "traversal fixes" there. Lines marked *(Claude's call)* were proposed by Claude and accepted ("this is pretty good"); everything else is the user's.

## Intent and why

The protagonist is the **Prosecutor**, a super-powered investigator and detective, a Constantine × Ezio Auditore mix. Their job is to stop supernatural events from breaking reality's fragile peace, and doing it breaks an already flawed status quo.

An Ezio needs to own the city vertically. After the ledge fixes (commit d2cfa2b) the user named the real problem: they want **climbing like Assassin's Creed Unity and AC 2, grounded and realistic but fun**, with mantling and vaulting folded in. The current system follows a Thief rule (grab real ledges only, deliberately "not a parkour game"). That rule is retired.

## Goals

- **Camera:** stays first person throughout, like Mirror's Edge. No third-person switch, which the user called "too much".
- **Free-run:** holding a button lets the Prosecutor flow over and up whatever is ahead: vault, wall-run a few steps to a hold, climb the façade, leap hold to hold toward the steered direction, and come back down just as fluidly.
- **Façades are climbable through readable handholds:** sills, cornices, balconies, shutters, drainpipes, bracket signs, stone joints. Movement is hand to hand, with leaps up, sideways or diagonally to holds out of reach.
- **Grounded:** human climbing speed, visible weight in reaches, pulls and catches, falls that hurt.
- **Fun:** chains are fluid and forgiving. A held direction finds the next hold, and the Prosecutor never fumbles a route a player can see.

## Non-goals

- **No leap of faith**, explicitly cut by the user.
- No third-person camera.
- No stamina meter for climbing *(Claude's call)*.
- No climbing smooth walls. Without holds, there is no climb.
- The Zócalo's buildings are not part of this project. Making them climbable is the next project, one model at a time.

## Anti-goals: fail even if it works

- Motion sickness. Camera roll and bob during free-run must stay readable.
- Floaty, superhero climbing without spells. Going beyond human limits belongs to blink and empower (the magic project).
- Losing Thief-style careful play. Walking and sneaking keep today's deliberate presses.
- Holds the player can see but the Prosecutor refuses (the "moves don't trigger" feeling).
- Getting stuck, wedged or jittering on geometry.
- Visual faults of any kind. No "minor" or "harmless" geometry faults.

## Decided

### Controls *(Claude's call, accepted)*
- **Hold sprint to free-run.** While held, moving forward takes what's ahead automatically: vault fences and carts, step and mantle obstacles, run up a wall a few steps to the first hold, climb, and leap between holds toward the steered direction. Releasing sprint while climbing stops the Prosecutor on the hold they have.
- **Parkour down: sprint + crouch held.** The Prosecutor climbs down and drops hold to hold, or off a ledge into a hang and then down, with the same fluency.
- **Walking or sneaking is the careful layer.** Jump and crouch presses work as they do today (mantle, vault, hang, shimmy, corners, aimed leaps, lower, ropes, ladders, including the Oct 16 fixes). Stealth play is unchanged.

### Climbing
- **Handholds:**
  - **Kinds:** a ledge is a horizontal edge (sill, cornice, balcony rail). A pole is a vertical holdable line (drainpipe, shutter edge). A point is a single hold (bracket, stone, sign arm).
  - **Placed on purpose**, as part of each kit piece's build and review with the user *(Claude's call)*. The game does not guess holds from arbitrary geometry. Today's automatic ledge detection still works for the careful layer and anywhere a real ledge exists.
- **Moves:**
  - On a hold, steering picks the next hold in that direction.
  - Within arm's reach, the Prosecutor reaches hand over hand.
  - Beyond arm's reach but within a leap's reach, they leap: a short dynamic jump to it, with a visible catch and weight.
  - From a pole they shimmy up and down and can step off onto a ledge.
  - At the top they pull over into standing or running.
- **Wall run up:** free-running at a wall with a hold within about 2–3 m above, they run a few steps up it and catch the hold. The exact reach is for the builder to tune with the user.
- **Hands:** both hands visibly plant on holds, through the existing HandContacts state machine and IK arms. The first-person animation principles apply (Helsby GDC 2015: the head leads, anticipation off screen, held weight on catches).

### Settled by Claude after the builder review *(Claude's calls)*
- **One set of holds for both layers.** Free-run chains through placed holds and through ledges the scanner detects on its own, so no visible ledge is dead to it. The careful layer can use placed holds too: a jump press at a drainpipe grabs it, and a press at a bracket hangs from it.
- **Steering on a wall:**
  - The move keys pick the next hold, relative to the camera's view of the wall.
  - Looking at a hold and pressing jump leaps to it (today's aimed leap).
  - **Back eject:** looking away from the wall at a hold or ledge behind you (across an alley) and pressing jump leaps to it.
  - The next hold is chosen from inside a cone around the steered direction, so a held direction finds a hold the player can see.
- **Roof edges and gaps:** free-running at an edge jumps the gap only to a validated landing (a roof, a ledge, a hold) that the existing assisted-jump simulation says will be reached and survived. With no such landing, the Prosecutor stops at the edge; free-run never throws you off a drop.
- **Sprint triggers moves for everyone, as in AC.** Fleeing a guard can take you up a wall. A drawn melee weapon is sheathed automatically on a climb. Carrying a body blocks free-run, as it already blocks sprinting. Attacks from holds and drop attacks belong to the combat revamp.
- **Build order:** the moves are built and tuned on greybox in a new traversal-gym station (a test façade with every hold kind) before any kit model gets holds. Greybox is not a model, so no one-at-a-time review is needed. The hold data format then goes through the kit pipeline on the first real piece, reviewed with the user.
- **Sprint + crouch:** on open ground it behaves as today (crouching ends the sprint); there is no slide. At an edge, or while climbing, it is parkour down.

### Grounded
- Climbing speed is human.
- Falls past a height hurt or kill (existing fall damage). A roll on landing softens a medium drop *(Claude's call)*.

### Stealth
Free-running is loud and visible. Guards hear and see you on rooftops in the light, through the existing light, sound (SoundBus) and guard systems. Every free-run move carries noise like today's variants.

### What is kept
The existing traversal (scanner, planner, variants, mantle, vault, hang, shimmy, corners, leaps, ropes, ladders, BodyMotion, CameraJuice, HandContacts) stays. It is the careful layer and the base the free-run layer is built on. The 20 ledge checks, 47 traversal checks and the ledge sweep (`tests/diag_ledge_sweep.tscn`) keep passing.

## Left to the builder

- **Architecture:** how the free-run layer sits on the scanner and planner (a mode on the controller, new variants, or a separate hold-graph planner), and the handhold data format (nodes, markers in the kit pipeline `tools/eclipse/*.py` → JSON → `scripts/Level/KitLoader.gd`, and so on).
- **Numbers:** reach and leap distances, wall-run height, climbing speeds, the fall/roll thresholds. Tune them with the user in the gym.
- **Tests:** a gym station or façade test wall showing every hold kind and move, with headless tests for each move (failing test first).
- **Look:** camera roll and bob amounts during free-run, judged with the user.

## Process rules

- Each model that gets handholds (the test façade, then each Zócalo piece) is built **one at a time with the user's review** before the next.
- Every visible fault gets fixed or named as unfinished, with its task.
- The user playtests the feel in the gym before any Zócalo façade work starts.
