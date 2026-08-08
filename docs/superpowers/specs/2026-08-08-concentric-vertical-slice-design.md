# Under Cover of Darkness: Concentric Vertical Slice Design

## Purpose

Build *Under Cover of Darkness* as a survival-horror immersive sim through a
series of small, playable rings. Each ring must teach a limited set of Godot
concepts, deepen the same playable space, and reach a clear quality bar before
the project expands.

The intended game combines deliberate first-person stealth, measured combat,
environmental problem solving, psychological horror, and enemies that adapt to
evidence left by the player. The design draws inspiration from *Thief*,
*Dishonored*, *F.E.A.R.*, *Halo*, *Alien: Isolation*, *Metal Gear Solid V*, and
*Fear & Hunger* without attempting to reproduce any one game's systems.

The developer is comfortable with programming fundamentals, new to Godot, can
spend approximately 10–20 hours per week, and wants to write and understand the
production code personally.

## Current Project Context

The project currently uses Godot 4.5 and contains:

- a first-person `CharacterBody3D` controller with walking, sprinting, jumping,
  mouse look, and mantling;
- a simple test world;
- FuncGodot and TrenchBroom configuration for brush-based level authoring; and
- no existing interaction, AI, stealth, combat, puzzle, inventory, sanity, or
  persistence systems.

`PlayerController.gd` remains responsible for locomotion during the first
ring. It will only be split when a concrete new responsibility makes the
separation useful.

## Product Direction

The finished game should be short enough for a small team or solo developer to
complete, but dense enough that every room supports observation, choice, and
consequence. A smaller number of excellent, replayable levels is preferable to
a long campaign of shallow content.

The first long-term target is a replayable 10–15 minute greybox mission. The
next implementation plan, however, covers Ring 1 plus the bounded Ring 0
readiness checks required to begin it. Ring 0 does not include a general
movement rewrite. Later rings receive their own design and implementation
plans after the preceding ring passes its completion gate.

## Non-Negotiable Gameplay Principles

### Equal Agency, Unequal Consequences

Ghosting, improvisational survival, and deliberate hunting are all viable.
They consume different resources and produce different consequences rather
than representing correct and incorrect playstyles.

- Ghost play exchanges speed and certainty for safety and secrecy.
- Improvisational survival risks health, supplies, noise, and control.
- Hunting consumes preparation and tools while provoking alertness and future
  countermeasures.

Hybrid play is valid. Consequences follow the player's actions, not a selected
playstyle label.

### Human Combat

Ordinary humans are peers rather than disposable targets.

- One opponent creates a measured duel.
- Two or three opponents create a demanding but winnable mastery test.
- Four or more opponents create a crisis unless the player has exceptional
  preparation, equipment, progression, or supernatural power.

Human combat eventually uses readable intent, committed attacks, spacing,
guarding, parrying, stamina or posture, wounds, morale, and retreat. Groups
coordinate by pressuring, flanking, and calling for help without waiting in an
artificial attack queue.

### Monster Combat

Monsters are problems to study, prepare for, and exploit. Observation, terrain,
tools, behavior, and lasting wounds matter more than reducing a large health
bar. When preparation fails, the encounter becomes an ugly struggle for
survival. Monsters do not inherit human combat logic merely with larger
numbers.

### Sources of Power

Power comes from four complementary sources:

- player mastery improves execution;
- equipment enables preparation;
- progression creates specialization rather than simple numerical inflation;
  and
- supernatural abilities break ordinary rules at meaningful cost.

No single source should invalidate the other three.

### Sanity and Scars

Sanity is a trade-off axis, not a second health bar. Recoverable stability
supports reliable perception, composure, and judgment. Instability may reveal
occult truths, hidden routes, additional dangers, and supernatural
opportunities.

Major trauma can create permanent scars or traits. Every scar must change play
in mixed ways rather than act as a permanent numerical debuff. Recovery can
restore current stability but cannot erase a major scar.

### Legible Adaptation

Enemy adaptation operates at three timescales:

- within an encounter, actors communicate, investigate, flank, retreat, and
  respond to current tools;
- across a level, discovered bodies, alarms, damaged infrastructure, and
  repeated tactics alter patrols and security; and
- across the campaign, factions eventually adopt equipment and procedures in
  response to recorded player history.

Adaptation must have an observable cause, be communicated through the world,
and offer counterplay. AI may use evidence available to its faction; it may not
read private player state to manufacture difficulty.

### Environmental Puzzles

Puzzles use consistent world rules, observable clues, and tools with multiple
uses. Difficulty comes from observation and synthesis rather than arbitrary
combinations or single-use adventure-game logic.

### Retro Presentation, Modern Usability

PS1- and PS2-era geometry, textures, animation restraint, interface character,
and tonal ambiguity may shape the presentation. Controls, readability,
accessibility, loading, and systemic consistency should meet modern
expectations.

## Concentric Development Rings

### Ring 0: Foundation Audit

Verify the existing controller in the new laboratory, confirm scale and
collision conventions, and establish a reusable greybox test space. Movement
changes in this ring are limited to defects that block the interaction routes;
deliberate movement tuning receives a separate playtest after Ring 1.

### Ring 1: Intentional Interaction

Create a consistent focus-and-use language for doors, levers, lamps, readable
objects, physical props, pressure plates, and a simple objective. This ring is
the subject of the next implementation plan.

### Ring 2: Single-Guard Stealth

Add one human who can patrol, see, hear, become suspicious, investigate,
search, communicate state, and return to an altered routine.

### Ring 3: Measured Human Combat

Make a duel against one human readable and satisfying before introducing two-
and three-opponent coordination.

### Ring 4: Systemic Tools and Puzzles

Introduce a deliberately small inventory of multipurpose tools. Each tool must
interact with several existing systems.

### Ring 5: Monster and Sanity

Add one monster with a behavior model distinct from human AI, recoverable
instability, occult perception changes, and one prototype permanent scar.

### Ring 6: Adaptation and Mission Integration

Connect the encounters into a 10–15 minute greybox mission. Evidence, alarms,
repeated tactics, and player choices alter the level. Record campaign-relevant
events without implementing campaign countermeasures until multiple missions
exist.

## Completion Gate for Every Ring

A ring is complete only when:

- the developer can explain the responsibility and dependencies of each new
  unit;
- its behavior is readable during normal play;
- repeated play exposes no known progression-blocking defect;
- important values can be tuned without rewriting unrelated systems;
- the feature creates a meaningful decision or supports a later decision; and
- the ring's acceptance checklist passes from a clean restart.

Code running without errors is not sufficient completion.

## Architecture

The project favors small Godot scenes and components with one responsibility.
Player, enemy, mechanism, and world scripts must not depend on a single global
gameplay object.

### Responsibility Rules

- Controllers issue intent. Player input and AI request actions such as
  interact, attack, block, or move.
- Components perform capabilities. Interaction, perception, combat, wounds,
  sanity, and inventory remain independently understandable.
- Objects own their state. A door owns whether it is open, moving, blocked, or
  locked.
- Godot resources describe reusable design data such as weapon timing,
  perception profiles, tools, and scars.
- Direct calls issue commands. Signals report facts that other systems may
  observe.
- State machines represent mutually exclusive behavior such as patrolling,
  investigating, searching, fighting, and fleeing.
- A later world-event journal records meaningful consequences without becoming
  the owner of every object's live state.

### Data Flow

The standard action flow is:

1. Player input or AI creates an intent.
2. The relevant capability validates the requested action.
3. The target changes the state it owns.
4. Signals report resulting facts.
5. Interested presentation, AI, objective, audio, and persistence systems
   react.
6. Consequences important beyond the object enter the world-event journal.

Only the pieces required by the current ring are implemented. Future-facing
interfaces are kept small and are not filled with speculative functionality.

## Ring 1 Detailed Design: Intentional Interaction

### Player Experience

Ring 1 is a small greybox interaction laboratory. The player retrieves a marked
objective from behind a barrier and returns to the entrance.

The barrier has two physical solutions:

1. Carry a movable crate onto a pressure plate to raise the barrier.
2. Move the same crate below a high opening and use the existing mantle ability
   to enter from above.

Inside the restricted area, a lever permanently opens the exit. A controllable
lamp demonstrates visible world state. A readable clue teaches observation
without being required to operate the mechanism.

The two routes use the same prop for incompatible purposes, creating a simple
but meaningful choice and proving that traversal and world interaction can
combine.

### Included Capabilities

Ring 1 includes:

- a camera-centered focus detector with a default 2.25-metre range exposed for
  tuning;
- a remappable `interact` action, bound to E by default, for using targets,
  picking up props, and placing or dropping the carried prop;
- a remappable `primary_action`, bound to the left mouse button by default,
  which throws the carried prop and remains available for later combat;
- contextual text showing the available verb or why the action is unavailable;
- reusable doors, levers, lamps, and readable objects;
- carrying, placing, dropping, and throwing selected physical props;
- pressure plates that respond to actual world bodies;
- a simple objective object and completion message;
- placeholder movement, mechanism, and interaction audio; and
- placeholder animation or interpolation sufficient to communicate state.

### Explicit Exclusions

Ring 1 excludes:

- inventory and keys;
- AI, stealth, and combat;
- health, sanity, scars, and supernatural powers;
- saving and persistence;
- progression and equipment systems;
- polished art, final audio, narrative production, and campaign content; and
- generalized scripting systems intended to let designers build arbitrary
  logic graphs.

### Interaction Contract

Focused targets expose a current verb and whether the action can be performed.
The player interactor owns focus selection and input forwarding; it does not
own target state. A target validates the action again when execution is
requested because the world may have changed since the prompt appeared.

Focus feedback clears as soon as the target becomes invalid, leaves range, is
occluded, or is removed. Unavailable interactions explain a useful reason only
when that reason helps the player act; internal errors are not displayed as
gameplay messages.

Only one prop can be carried at a time. A carried prop follows a hold point in
front of the camera while remaining collidable. Its movement is speed-limited,
and persistent separation or obstruction causes it to drop rather than snap
through geometry. Pressing `interact` while carrying places or drops the prop;
pressing `primary_action` applies a tuned forward throw and releases it.

Using the marked objective sets a dedicated acquired flag, hides its world
representation, and updates the laboratory objective. This is objective state,
not a general inventory or pickup framework.

### State Ownership

- Doors own position, motion, obstruction response, and open or closed state.
- Levers own their physical position and emit their selected state.
- Lamps own whether they are lit and update light, sound, and visible feedback.
- Pressure plates own activation state derived from eligible overlapping
  bodies.
- Carryable props own their physical state while the interactor owns whether it
  is currently attempting to carry a prop.
- The objective owns whether it has been acquired; the laboratory owns whether
  completion conditions have been met.

## Failure Handling

Interactive systems fail safely:

- Invalid interaction requests cause no state change.
- Losing or removing a focused target clears the prompt immediately.
- Carried objects blocked by geometry stop, move to a safe hold position, or
  drop; they do not tunnel through geometry.
- The Ring 1 barrier returns to its open position when obstructed while
  lowering, and does not try to lower again until the obstruction clears.
- Pressure-plate state remains correct with the player, one prop, multiple
  props, and bodies entering or leaving in the same frame.
- Rapid repeated input cannot leave a mechanism between declared states.
- A carryable prop leaving the laboratory's play volume returns to its authored
  spawn transform with zero velocity.
- Restarting the scene restores the complete initial puzzle state.

A toggleable development overlay exposes the focus target, interaction range,
carried-object state, pressure-plate state, and mechanism state. Normal
gameplay feedback remains understandable without the overlay.

## Verification

Ring 1 receives a dedicated test scene and a manual acceptance checklist. The
checklist covers:

- acquiring, changing, losing, occluding, and removing focus targets;
- interacting at the limit of range;
- rapid repeated interaction;
- carrying through narrow spaces and into obstructions;
- dropping and throwing onto and away from the pressure plate;
- activating a plate with the player, one prop, and multiple props;
- obstructing the moving barrier with the player and a prop;
- restarting while carrying or while a mechanism is moving;
- completing both routes from a clean restart; and
- returning the objective to the entrance and receiving completion feedback.

Pure rules should receive automated tests when they can be isolated from scene
physics without excessive test scaffolding. Scene and physics behavior remains
verified through focused integration scenes and repeatable manual checks during
Ring 1.

## Collaboration and Learning Contract

Each feature follows this cycle:

1. Agree on observable player-facing behavior.
2. Explain the relevant Godot concepts and define the smallest useful
   interface.
3. The developer writes the implementation.
4. Review the code and test the behavior together.
5. Explain failures, alternatives, and trade-offs rather than replacing code
   silently.
6. Tune through play and record the resulting design lesson.

Default assistance consists of short exercises, pseudocode, interface sketches,
code review, testing strategy, and debugging guidance. Complete production code
is written by the assistant only when the developer explicitly requests it.

## Ring 1 Success Criteria

Ring 1 is ready for the single-guard stealth design when:

1. Both puzzle routes work reliably from a clean restart.
2. Focus and prompt feedback never remain attached to an invalid target.
3. Carrying and throwing behave safely around the laboratory's walls, barrier,
   pressure plate, and mantle route.
4. Doors and mechanisms cannot enter an undeclared or progression-blocking
   state through obstruction or repeated input.
5. Important interactions communicate success, failure, and state through
   ordinary audiovisual feedback.
6. The developer can explain the interaction data flow, state ownership,
   collision choices, and signal connections.
7. The full acceptance checklist passes in ten consecutive clean runs.
