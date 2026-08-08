# Ring 1 Intentional Interaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reliable greybox interaction laboratory in which the player can retrieve an objective through either a pressure-plate route or a crate-and-mantle route, then return to the entrance.

**Architecture:** Keep the existing locomotion controller intact and add interaction as a separate player capability. Interactive objects own their state, receive commands through a small `InteractionTarget` component, and report facts through signals. Pure state rules receive lightweight automated tests; physics, collision, feedback, and traversal receive repeatable scene-level acceptance tests.

**Tech Stack:** Godot 4.5, GDScript 2.0, Godot scenes/resources, built-in 3D physics, FuncGodot/TrenchBroom for later level production

## Global Constraints

- Preserve `PlayerController.gd` as the owner of locomotion during Ring 1.
- Limit Ring 0 movement changes to defects that block either interaction route.
- Use a camera-centered focus detector with a default range of exactly `2.25` metres.
- Bind the remappable `interact` action to E by default.
- Bind the remappable `primary_action` action to the left mouse button by default.
- Bind the development-only `debug_overlay` action to F3 by default.
- Carry at most one prop at a time.
- Keep carried props collidable and speed-limited; drop them after persistent separation or obstruction.
- Return out-of-bounds carryable props to their authored spawn transform with zero velocity.
- Make the barrier return open when obstructed while lowering.
- Do not add inventory, keys, AI, stealth, combat, health, sanity, saving, progression, final art, final audio, or generalized logic graphs.
- Do not add a third-party testing add-on for Ring 1.
- The developer writes production code; assistance defaults to explanation, review, tests, and debugging unless implementation is explicitly requested.
- The current shell does not expose a Godot executable. Every automated test below can be run by opening `tests/ring1/run_tests.tscn` and pressing F6 in Godot 4.5. If Godot is installed at the standard macOS location, the equivalent shell command is:

```bash
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . res://tests/ring1/run_tests.tscn
```

## File Structure

### Existing files to modify

- `.gitignore` — preserve the Godot ignores and add macOS/temporary-file rules.
- `project.godot` — input actions, collision-layer names, and the Ring 1 main scene.
- `Player.tscn` — interaction ray, hold point, interactor component, and HUD instance.
- `PlayerController.gd` — unchanged unless a tested Ring 0 blocker is discovered.

### Files to create

- `levels/interaction_lab.tscn` — final Ring 1 greybox laboratory.
- `levels/interaction_lab.gd` — objective flow, debug summary, reset-sensitive level state.
- `gameplay/interaction/interaction_target.gd` — common prompt, validation, dispatch, and collider-to-target lookup.
- `gameplay/interaction/player_interactor.gd` — focus, input forwarding, reading mode, and carried-prop ownership.
- `gameplay/interaction/carryable_prop.gd` — physical pickup, carry, release, throw, and spawn reset.
- `gameplay/mechanisms/lever.gd` — reusable binary lever and `state_changed` signal.
- `gameplay/mechanisms/lamp.gd` — reusable interactable light.
- `gameplay/mechanisms/pressure_plate.gd` — eligible-body tracking and `active_changed` signal.
- `gameplay/mechanisms/sliding_barrier.gd` — explicit motion state, pressure input, permanent latch, and obstruction response.
- `gameplay/readables/readable_object.gd` — sends authored title/body text to the player interactor.
- `gameplay/objectives/objective_item.gd` — one-shot objective acquisition without a general inventory.
- `gameplay/feedback/placeholder_tone.gd` — generated prototype tones without external audio assets.
- `ui/interaction_hud.tscn` — prompt, readable panel, objective text, completion text, and debug panel.
- `ui/interaction_hud.gd` — presentation methods with no gameplay-state ownership.
- `tests/ring1/test_suite.gd` — minimal assertion and failure-reporting helper.
- `tests/ring1/run_tests.gd` — loads all Ring 1 rule tests and exits nonzero on failure.
- `tests/ring1/run_tests.tscn` — editor-runnable automated test scene.
- `tests/ring1/test_interaction_target.gd` — interaction contract tests.
- `tests/ring1/test_binary_mechanisms.gd` — lever and lamp state tests.
- `tests/ring1/test_carrying.gd` — one-prop and release-state tests.
- `tests/ring1/test_pressure_and_barrier.gd` — pressure counting, latching, and obstruction tests.
- `tests/ring1/test_objective_flow.gd` — objective state-machine tests.
- `tests/ring1/manual_acceptance.md` — exact physics and end-to-end checks.

## Shared Interfaces

Later tasks rely on these exact names and signatures:

```gdscript
# interaction_target.gd
class_name InteractionTarget
signal interaction_requested(interactor: PlayerInteractor)
func get_prompt_text() -> String
func can_interact(interactor: PlayerInteractor) -> bool
func interact(interactor: PlayerInteractor) -> bool
static func find_from(node: Node) -> InteractionTarget

# player_interactor.gd
class_name PlayerInteractor
signal prompt_changed(text: String)
signal readable_opened(title: String, body: String)
signal readable_closed
func try_pick_up(prop: CarryableProp) -> bool
func drop_carried() -> void
func throw_carried() -> void
func open_readable(title: String, body: String) -> void
func get_debug_summary() -> String

# carryable_prop.gd
class_name CarryableProp
func begin_carry(player_collision_layer: int) -> void
func drive_toward(target_position: Vector3, delta: float) -> void
func end_carry(throw_velocity: Vector3 = Vector3.ZERO) -> void
func reset_to_spawn() -> void

# mechanism signals and commands
Lever.state_changed(active: bool)
Lever.set_active(value: bool) -> void
Lamp.state_changed(active: bool)
Lamp.set_active(value: bool) -> void
PressurePlate.active_changed(active: bool)
PressurePlate.register_body(body: Node3D) -> void
PressurePlate.unregister_body(body: Node3D) -> void
SlidingBarrier.set_pressure_active(active: bool) -> void
SlidingBarrier.set_obstructed(value: bool) -> void
SlidingBarrier.latch_open() -> void
SlidingBarrier.is_open_requested() -> bool

# objective flow
ObjectiveItem.acquired(objective_id: StringName)
InteractionLab.on_objective_acquired(objective_id: StringName) -> void
InteractionLab.try_complete(body: Node3D) -> bool
```

---

### Task 1: Establish the Safe Baseline and Ring 0 Laboratory Shell

**Files:**
- Modify: `.gitignore`
- Verify without changing: `.gitattributes`
- Verify without changing: `.editorconfig`
- Create: `levels/interaction_lab.tscn`
- Modify: `project.godot`
- Verify without changing: `PlayerController.gd`
- Verify without changing: `Player.tscn`

**Interfaces:**
- Consumes: the existing `Player.tscn` and its mantle-capable `PlayerController.gd`.
- Produces: input actions `interact`, `primary_action`, and `debug_overlay`; named physics layers; a runnable greybox scene with a verified mantle opening.

- [ ] **Step 1: Extend the existing version-control ignore rules**

Preserve the existing `.godot/` and `/android/` entries, then append:

```gitignore
.DS_Store
*.tmp
```

- [ ] **Step 2: Verify the repository connection and record the existing project**

Run:

```bash
git branch --show-current
git remote get-url origin
git status --short
git add -- .editorconfig .gitattributes .gitignore Player.tscn PlayerController.gd PlayerController.gd.uid addons docs icon.svg icon.svg.import main.tscn maps my_fgd.tres project.godot sky.gdshader sky.gdshader.uid textures trenchbroom_config.tres
git commit -m "chore: establish project baseline"
```

Expected: the branch is `main`, `origin` is
`https://github.com/DGSENZEN/under_cover_of_darkness.git`, and the initial commit
contains the current Godot project, add-on, textures, existing documentation,
and this plan. Do not push during this step; pushing requires a separate
explicit decision.

- [ ] **Step 3: Add exact input actions and collision-layer names**

Use Godot's Input Map to add:

```text
interact       E / physical key E
primary_action Left Mouse Button
debug_overlay  F3 / physical key F3
```

Use 3D Physics Layer Names to set:

```text
Layer 1: World
Layer 2: Player
Layer 3: Interactable
Layer 4: Trigger
```

Set the `Player.tscn` root collision layer to Player and its collision mask to
World plus Interactable. Keep `mantle_mask` on World. Do not remove or rename
the existing movement actions.

- [ ] **Step 4: Create the Ring 0 greybox shell**

Create `levels/interaction_lab.tscn` with this initial node tree:

```text
InteractionLab (Node3D)
├── WorldGeometry (Node3D)
│   ├── Floor (StaticBody3D + MeshInstance3D + CollisionShape3D)
│   ├── PerimeterWalls (Node3D containing StaticBody3D blocks)
│   ├── RestrictedRoom (Node3D containing StaticBody3D blocks)
│   └── MantleOpening (StaticBody3D blocks forming a 1.20 m high opening)
├── Player (instance of res://Player.tscn)
└── DirectionalLight3D
```

Use primitive meshes and collision shapes. The room only needs enough space to walk, jump, and test the authored opening; do not texture or decorate it.

- [ ] **Step 5: Verify the existing controller against the shell**

Run the laboratory with F6 and verify:

```text
[ ] Walk, sprint, jump, and mouse look work.
[ ] The player remains grounded on the floor.
[ ] The player cannot pass through the perimeter walls.
[ ] Holding jump while moving forward mantles the 1.20 m opening.
[ ] Escape releases the mouse.
```

Expected: all checks pass without editing `PlayerController.gd`. If one fails, record the exact reproduction before making the smallest controller fix.

- [ ] **Step 6: Make the laboratory the development main scene**

Set the project main scene to:

```ini
run/main_scene="res://levels/interaction_lab.tscn"
```

- [ ] **Step 7: Commit the verified baseline**

Run:

```bash
git add .gitignore project.godot levels/interaction_lab.tscn
git commit -m "chore: add ring one laboratory shell"
```

---

### Task 2: Build the Interaction Contract and Test Harness

**Files:**
- Create: `gameplay/interaction/interaction_target.gd`
- Create: `tests/ring1/test_suite.gd`
- Create: `tests/ring1/run_tests.gd`
- Create: `tests/ring1/run_tests.tscn`
- Create: `tests/ring1/test_interaction_target.gd`

**Interfaces:**
- Consumes: no gameplay code from earlier tasks.
- Produces: `InteractionTarget`, `Ring1TestSuite`, and an editor-runnable test scene used by every later task.

- [ ] **Step 1: Create the minimal test utility and runner**

Create `tests/ring1/test_suite.gd`:

```gdscript
class_name Ring1TestSuite
extends RefCounted

var failures := 0

func expect_true(value: bool, message: String) -> void:
	if value:
		return
	failures += 1
	push_error(message)

func expect_false(value: bool, message: String) -> void:
	expect_true(not value, message)

func expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	failures += 1
	push_error("%s — expected %s, received %s" % [message, expected, actual])
```

Create `tests/ring1/run_tests.gd`:

```gdscript
extends Node

const TEST_SCRIPTS: Array[Script] = [
	preload("res://tests/ring1/test_interaction_target.gd"),
]

func _ready() -> void:
	var suite := Ring1TestSuite.new()
	for test_script in TEST_SCRIPTS:
		test_script.run(suite, self)
	if suite.failures == 0:
		print("Ring 1 rules: PASS")
	else:
		push_error("Ring 1 rules: %d failure(s)" % suite.failures)
	get_tree().quit(suite.failures)
```

Create `tests/ring1/run_tests.tscn` with one `Node` using `run_tests.gd`.

- [ ] **Step 2: Write the failing interaction-contract tests**

Create `tests/ring1/test_interaction_target.gd`:

```gdscript
extends RefCounted

static func run(suite: Ring1TestSuite, root: Node) -> void:
	var host := Node3D.new()
	var collider := StaticBody3D.new()
	var target := InteractionTarget.new()
	target.name = "InteractionTarget"
	host.add_child(collider)
	host.add_child(target)
	root.add_child(host)

	suite.expect_equal(target.get_prompt_text(), "Use", "default verb")
	suite.expect_true(target.can_interact(null), "enabled target is usable")
	suite.expect_equal(
		InteractionTarget.find_from(collider),
		target,
		"target resolves from collider ancestry"
	)

	var requests := [0]
	target.interaction_requested.connect(func(_interactor): requests[0] += 1)
	suite.expect_true(target.interact(null), "enabled target accepts request")
	suite.expect_equal(requests[0], 1, "accepted request emits exactly once")

	target.enabled = false
	target.unavailable_reason = "Jammed"
	suite.expect_equal(target.get_prompt_text(), "Jammed", "disabled reason")
	suite.expect_false(target.interact(null), "disabled target rejects request")
	suite.expect_equal(requests[0], 1, "rejected request emits nothing")

	host.queue_free()
```

- [ ] **Step 3: Run the test and verify the intended failure**

Open `tests/ring1/run_tests.tscn` and press F6.

Expected: script parsing fails because `InteractionTarget` is not defined.

- [ ] **Step 4: Implement the minimal interaction component**

Create `gameplay/interaction/interaction_target.gd`:

```gdscript
class_name InteractionTarget
extends Node

signal interaction_requested(interactor: Node)

@export var verb := "Use"
@export var enabled := true
@export var unavailable_reason := "Unavailable"

func get_prompt_text() -> String:
	return verb if enabled else unavailable_reason

func can_interact(_interactor: Node) -> bool:
	return enabled

func interact(interactor: Node) -> bool:
	if not can_interact(interactor):
		return false
	interaction_requested.emit(interactor)
	return true

static func find_from(node: Node) -> InteractionTarget:
	var cursor := node
	while cursor != null:
		if cursor is InteractionTarget:
			return cursor as InteractionTarget
		var child := cursor.get_node_or_null("InteractionTarget")
		if child is InteractionTarget:
			return child as InteractionTarget
		cursor = cursor.get_parent()
	return null
```

Because `PlayerInteractor` is introduced in Task 3, temporarily type the signal and method parameters as `Node` while completing Task 2. Replace both with `PlayerInteractor` in Task 3.

- [ ] **Step 5: Run the contract test**

Run `tests/ring1/run_tests.tscn` with F6.

Expected: output contains `Ring 1 rules: PASS` and the scene exits with no errors.

- [ ] **Step 6: Commit the contract and test harness**

Run:

```bash
git add gameplay/interaction tests/ring1
git commit -m "feat: add interaction target contract"
```

---

### Task 3: Add Player Focus and Contextual HUD Feedback

**Files:**
- Create: `gameplay/interaction/player_interactor.gd`
- Create: `ui/interaction_hud.gd`
- Create: `ui/interaction_hud.tscn`
- Modify: `Player.tscn`
- Modify: `gameplay/interaction/interaction_target.gd`
- Modify: `levels/interaction_lab.tscn`

**Interfaces:**
- Consumes: `InteractionTarget.find_from`, `get_prompt_text`, and `interact`.
- Produces: typed `PlayerInteractor`, `prompt_changed(text)`, camera focus at 2.25 m, and HUD prompt rendering.

- [ ] **Step 1: Add a visible interaction target to the laboratory before the interactor exists**

Add this temporary object near the spawn:

```text
PromptTestBlock (StaticBody3D, layer Interactable)
├── MeshInstance3D
├── CollisionShape3D
└── InteractionTarget (script interaction_target.gd, verb = "Inspect")
```

- [ ] **Step 2: Run the laboratory and verify the missing behavior**

Expected: looking at the block shows no prompt and pressing E does nothing.

- [ ] **Step 3: Create the HUD scene**

Create `ui/interaction_hud.tscn`:

```text
InteractionHUD (CanvasLayer, script interaction_hud.gd)
└── MarginContainer
    └── VBoxContainer
        ├── PromptLabel (Label)
        ├── ObjectiveLabel (Label)
        ├── CompletionLabel (Label, hidden)
        ├── ReadablePanel (PanelContainer, hidden)
        │   └── VBoxContainer
        │       ├── ReadableTitle (Label)
        │       └── ReadableBody (Label, autowrap enabled)
        └── DebugLabel (Label, hidden)
```

Create `ui/interaction_hud.gd` with these exact presentation methods:

```gdscript
class_name InteractionHUD
extends CanvasLayer

@onready var prompt_label: Label = %PromptLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var completion_label: Label = %CompletionLabel
@onready var readable_panel: PanelContainer = %ReadablePanel
@onready var readable_title: Label = %ReadableTitle
@onready var readable_body: Label = %ReadableBody
@onready var debug_label: Label = %DebugLabel

func set_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = not text.is_empty()

func set_objective(text: String) -> void:
	objective_label.text = text

func show_completion(text: String) -> void:
	completion_label.text = text
	completion_label.visible = true

func show_readable(title: String, body: String) -> void:
	readable_title.text = title
	readable_body.text = body
	readable_panel.visible = true

func hide_readable() -> void:
	readable_panel.visible = false

func set_debug_visible(value: bool) -> void:
	debug_label.visible = value

func set_debug_text(text: String) -> void:
	debug_label.text = text
```

Each method only updates the corresponding label or panel. It stores no puzzle or interaction state.

- [ ] **Step 4: Implement focus and interaction forwarding**

Create `gameplay/interaction/player_interactor.gd` around this state and flow:

```gdscript
class_name PlayerInteractor
extends Node

signal prompt_changed(text: String)
signal readable_opened(title: String, body: String)
signal readable_closed

@export var focus_ray: RayCast3D
@export var hold_point: Marker3D
@export var interaction_range := 2.25

var focused_target: InteractionTarget
var carried_prop: RigidBody3D
var reading_open := false

func _ready() -> void:
	focus_ray.target_position = Vector3(0.0, 0.0, -interaction_range)

func _physics_process(_delta: float) -> void:
	if reading_open:
		_set_focused_target(null)
		return
	focus_ray.force_raycast_update()
	var next_target: InteractionTarget = null
	if focus_ray.is_colliding():
		next_target = InteractionTarget.find_from(focus_ray.get_collider() as Node)
	_set_focused_target(next_target)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if reading_open:
			_close_readable()
		elif focused_target != null:
			focused_target.interact(self)

func _set_focused_target(next_target: InteractionTarget) -> void:
	if next_target == focused_target:
		return
	focused_target = next_target
	prompt_changed.emit("" if focused_target == null else focused_target.get_prompt_text())

func open_readable(title: String, body: String) -> void:
	if reading_open:
		return
	reading_open = true
	_set_focused_target(null)
	readable_opened.emit(title, body)

func _close_readable() -> void:
	if not reading_open:
		return
	reading_open = false
	readable_closed.emit()

func try_pick_up(_prop: RigidBody3D) -> bool:
	return false

func drop_carried() -> void:
	return

func throw_carried() -> void:
	return

func get_debug_summary() -> String:
	var focus_name := "none" if focused_target == null else focused_target.name
	return "Focus: %s\nRange: %.2f m\nCarry: none" % [focus_name, interaction_range]
```

The temporary `RigidBody3D` pickup signature keeps Task 3 parseable before
`CarryableProp` exists. Task 5 replaces it with the final shared interface and
replaces the safe no-op method bodies.

- [ ] **Step 5: Complete the typed interaction contract**

Change the temporary `Node` parameter types in `InteractionTarget` to `PlayerInteractor`, matching the Shared Interfaces section.

- [ ] **Step 6: Compose the player scene**

Modify `Player.tscn`:

```text
CharacterBody3D
├── CollisionShape3D
├── Neck
│   └── Camera3D
│       ├── InteractionRay (RayCast3D; bodies enabled; areas enabled)
│       └── HoldPoint (Marker3D; position 0, 0, -1.5)
├── PlayerInteractor (Node, script player_interactor.gd)
└── InteractionHUD (instance of interaction_hud.tscn)
```

Assign the ray and hold point exports. Connect `PlayerInteractor.prompt_changed` to `InteractionHUD.set_prompt`, `readable_opened` to `show_readable`, and `readable_closed` to `hide_readable`.

- [ ] **Step 7: Verify focus lifecycle manually**

Run the laboratory and check:

```text
[ ] Looking at PromptTestBlock within 2.25 m shows "Inspect".
[ ] Looking away clears it immediately.
[ ] Moving beyond 2.25 m clears it immediately.
[ ] A wall between the camera and block prevents the prompt.
[ ] Deleting the block in the remote scene tree clears the prompt without an error.
```

- [ ] **Step 8: Run the automated tests and commit**

Run `tests/ring1/run_tests.tscn` with F6. Expected: PASS.

Then run:

```bash
git add Player.tscn gameplay/interaction ui levels/interaction_lab.tscn
git commit -m "feat: add player interaction focus and prompt"
```

---

### Task 4: Add Reusable Lever and Lamp State

**Files:**
- Create: `gameplay/mechanisms/lever.gd`
- Create: `gameplay/mechanisms/lamp.gd`
- Create: `tests/ring1/test_binary_mechanisms.gd`
- Modify: `tests/ring1/run_tests.gd`
- Modify: `levels/interaction_lab.tscn`

**Interfaces:**
- Consumes: `InteractionTarget.interaction_requested`.
- Produces: `Lever.state_changed(active)`, `Lever.set_active`, `Lamp.state_changed(active)`, and `Lamp.set_active`.

- [ ] **Step 1: Write failing binary-state tests**

Create `tests/ring1/test_binary_mechanisms.gd`:

```gdscript
extends RefCounted

static func run(suite: Ring1TestSuite, _root: Node) -> void:
	var lever := Lever.new()
	var lever_events := [0]
	lever.state_changed.connect(func(_active): lever_events[0] += 1)
	lever.set_active(true)
	lever.set_active(true)
	suite.expect_true(lever.active, "lever becomes active")
	suite.expect_equal(lever_events[0], 1, "lever emits only on change")

	var lamp := Lamp.new()
	var lamp_events := [0]
	lamp.state_changed.connect(func(_active): lamp_events[0] += 1)
	lamp.set_active(false)
	lamp.set_active(true)
	suite.expect_true(lamp.active, "lamp becomes active")
	suite.expect_equal(lamp_events[0], 1, "lamp emits only on change")
```

Add its preload to `TEST_SCRIPTS` in `run_tests.gd`.

- [ ] **Step 2: Run tests and verify parsing fails**

Expected: `Lever` and `Lamp` are not defined.

- [ ] **Step 3: Implement explicit binary state**

Both scripts use this state pattern:

```gdscript
signal state_changed(active: bool)
@export var active := false

func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	_apply_visual_state()
	state_changed.emit(active)
```

Both `_apply_visual_state` methods begin with:

```gdscript
if not is_node_ready():
	return
```

This makes the pure state tests safe before authored child nodes exist.
`Lever` connects its `InteractionTarget.interaction_requested` signal to
`set_active(not active)` and rotates only its authored handle node. `Lamp`
connects the same way and updates its `Light3D.visible` plus an emissive
indicator mesh. Neither script searches the scene tree for consumers.

- [ ] **Step 4: Add authored test instances**

Add to the laboratory:

```text
TestLever (Node3D, script lever.gd)
├── Handle (MeshInstance3D)
├── StaticBody3D + CollisionShape3D
└── InteractionTarget (verb = "Pull")

TestLamp (Node3D, script lamp.gd)
├── Light3D
├── IndicatorMesh (MeshInstance3D)
├── StaticBody3D + CollisionShape3D
└── InteractionTarget (verb = "Toggle")
```

- [ ] **Step 5: Verify state and repeated input**

Run the lab. Pull the lever ten times and toggle the lamp ten times.

Expected: every press causes one state change, visual state always matches declared state, and no intermediate state remains.

- [ ] **Step 6: Run automated tests and commit**

Expected: `Ring 1 rules: PASS`.

```bash
git add gameplay/mechanisms tests/ring1 levels/interaction_lab.tscn
git commit -m "feat: add reusable lever and lamp"
```

---

### Task 5: Add One-Prop Physical Carrying and Throwing

**Files:**
- Create: `gameplay/interaction/carryable_prop.gd`
- Create: `tests/ring1/test_carrying.gd`
- Modify: `gameplay/interaction/player_interactor.gd`
- Modify: `tests/ring1/run_tests.gd`
- Modify: `levels/interaction_lab.tscn`

**Interfaces:**
- Consumes: the interactor hold point, `interact`, and `primary_action`.
- Produces: `CarryableProp` and working `try_pick_up`, `drop_carried`, and `throw_carried` methods.

- [ ] **Step 1: Write failing ownership and release tests**

Create `tests/ring1/test_carrying.gd`:

```gdscript
extends RefCounted

static func run(suite: Ring1TestSuite, root: Node) -> void:
	var ray := RayCast3D.new()
	var hold := Marker3D.new()
	var interactor := PlayerInteractor.new()
	interactor.focus_ray = ray
	interactor.hold_point = hold
	root.add_child(ray)
	root.add_child(hold)
	root.add_child(interactor)

	var first := CarryableProp.new()
	var second := CarryableProp.new()
	root.add_child(first)
	root.add_child(second)
	suite.expect_true(interactor.try_pick_up(first), "first prop is accepted")
	suite.expect_false(interactor.try_pick_up(second), "second prop is rejected")
	interactor.drop_carried()
	suite.expect_equal(interactor.carried_prop, null, "drop clears ownership")

	first.queue_free()
	second.queue_free()
	interactor.queue_free()
	ray.queue_free()
	hold.queue_free()
```

Add the test preload to `run_tests.gd`.

- [ ] **Step 2: Run tests and verify `CarryableProp` is missing**

Expected: parsing fails before any physics test runs.

- [ ] **Step 3: Implement carryable prop state**

Create `CarryableProp` as a `RigidBody3D` with these tunable defaults:

```gdscript
@export var carry_acceleration := 35.0
@export var maximum_carry_speed := 8.0
@export var maximum_hold_distance := 3.0
@export var throw_speed := 7.0
```

On `_ready`, store `global_transform` as the spawn transform and connect the child `InteractionTarget` to a handler that calls `interactor.try_pick_up(self)`.

Implement the core movement exactly as a speed-limited velocity target:

```gdscript
func drive_toward(target_position: Vector3, delta: float) -> void:
	var offset := target_position - global_position
	var desired := (offset * carry_acceleration).limit_length(maximum_carry_speed)
	linear_velocity = linear_velocity.move_toward(
		desired,
		carry_acceleration * delta
	)
```

`begin_carry` disables gravity, increases damping, enables continuous collision detection, and disables only the Player collision-layer bit. `end_carry` restores every saved physics value before applying optional throw velocity. `reset_to_spawn` ends carrying, restores the authored transform, and clears linear and angular velocity.

- [ ] **Step 4: Complete interactor ownership and inputs**

Change `carried_prop` from `RigidBody3D` to `CarryableProp`, change the temporary
pickup parameter to `CarryableProp`, and implement:

```gdscript
func try_pick_up(prop: CarryableProp) -> bool:
	if reading_open or carried_prop != null or prop == null:
		return false
	carried_prop = prop
	_set_focused_target(null)
	carried_prop.begin_carry(2)
	prompt_changed.emit("Drop")
	return true

func drop_carried() -> void:
	if carried_prop == null:
		return
	carried_prop.end_carry()
	carried_prop = null

func throw_carried() -> void:
	if carried_prop == null:
		return
	var direction := -focus_ray.global_basis.z
	var released := carried_prop
	carried_prop = null
	released.end_carry(direction * released.throw_speed)
```

While carrying, `_physics_process` keeps focus cleared, maintains the `Drop`
prompt, and drives the prop toward the hold point. `interact` drops instead of
targeting and `primary_action` throws. Drop the prop if its distance from the
hold point exceeds `maximum_hold_distance` for `0.20` continuous seconds.

- [ ] **Step 5: Add the authored crate and reset volume**

Add:

```text
PuzzleCrate (RigidBody3D, script carryable_prop.gd, group pressure_plate_eligible)
├── MeshInstance3D
├── CollisionShape3D
└── InteractionTarget (verb = "Carry")

PropResetVolume (Area3D, layer Trigger)
└── CollisionShape3D covering the space below/outside the laboratory
```

Connect `PropResetVolume.body_entered` so that a `CarryableProp` calls `reset_to_spawn()`.

- [ ] **Step 6: Verify physics behavior manually**

```text
[ ] E picks up the crate.
[ ] E drops it without adding throw velocity.
[ ] Left click throws it forward.
[ ] A second carryable cannot be acquired while holding the first.
[ ] The crate collides with walls, the floor, and the barrier opening.
[ ] Pulling it around a corner makes it lag or drop; it never crosses the wall.
[ ] Falling into PropResetVolume returns it to spawn at rest.
```

- [ ] **Step 7: Run automated tests and commit**

Expected: PASS.

```bash
git add gameplay/interaction tests/ring1 levels/interaction_lab.tscn
git commit -m "feat: add physical prop carrying"
```

---

### Task 6: Add the Pressure Plate and Safe Sliding Barrier

**Files:**
- Create: `gameplay/mechanisms/pressure_plate.gd`
- Create: `gameplay/mechanisms/sliding_barrier.gd`
- Create: `tests/ring1/test_pressure_and_barrier.gd`
- Modify: `tests/ring1/run_tests.gd`
- Modify: `levels/interaction_lab.tscn`

**Interfaces:**
- Consumes: bodies in `pressure_plate_eligible` or `player` groups.
- Produces: `PressurePlate.active_changed`, `SlidingBarrier.set_pressure_active`, `latch_open`, and explicit barrier motion states.

- [ ] **Step 1: Write failing pressure and barrier rule tests**

Create `tests/ring1/test_pressure_and_barrier.gd`:

```gdscript
extends RefCounted

static func run(suite: Ring1TestSuite, _root: Node) -> void:
	var plate := PressurePlate.new()
	var body_a := Node3D.new()
	var body_b := Node3D.new()
	_root.add_child(plate)
	_root.add_child(body_a)
	_root.add_child(body_b)
	body_a.add_to_group("pressure_plate_eligible")
	body_b.add_to_group("pressure_plate_eligible")
	plate.register_body(body_a)
	plate.register_body(body_b)
	suite.expect_true(plate.active, "eligible bodies activate plate")
	plate.unregister_body(body_a)
	suite.expect_true(plate.active, "one remaining body keeps plate active")
	plate.unregister_body(body_b)
	suite.expect_false(plate.active, "last body leaving deactivates plate")

	var barrier := SlidingBarrier.new()
	_root.add_child(barrier)
	barrier.set_pressure_active(true)
	suite.expect_true(barrier.is_open_requested(), "pressure requests open")
	barrier.set_pressure_active(false)
	suite.expect_false(barrier.is_open_requested(), "released pressure requests close")
	barrier.set_obstructed(true)
	suite.expect_true(barrier.is_open_requested(), "obstruction requests open")
	barrier.set_obstructed(false)
	barrier.latch_open()
	barrier.set_pressure_active(false)
	suite.expect_true(barrier.is_open_requested(), "latch remains open")

	plate.queue_free()
	body_a.queue_free()
	body_b.queue_free()
	barrier.queue_free()
```

Add it to the runner.

- [ ] **Step 2: Run tests and verify missing classes**

Expected: parsing fails for `PressurePlate` and `SlidingBarrier`.

- [ ] **Step 3: Implement stable eligible-body tracking**

`PressurePlate` extends `Area3D`, stores eligible instance IDs in a dictionary, and exposes these testable methods:

```gdscript
func register_body(body: Node3D) -> void
func unregister_body(body: Node3D) -> void
func is_body_eligible(body: Node3D) -> bool:
	return body.is_in_group("player") or body.is_in_group("pressure_plate_eligible")
```

`body_entered` calls `register_body`; `body_exited` calls `unregister_body`. Recompute `active` after every dictionary change and emit `active_changed` only when the Boolean value changes. Erase invalid instance IDs during recomputation so deleting a body cannot leave the plate active.

- [ ] **Step 4: Implement explicit barrier state and safe requests**

`SlidingBarrier` extends `AnimatableBody3D` and defines:

```gdscript
enum MotionState { CLOSED, OPENING, OPEN, CLOSING }

@export var travel := Vector3(0.0, 3.0, 0.0)
@export var speed := 2.0
var pressure_active := false
var latched_open := false
var obstructed := false
var motion_state := MotionState.CLOSED

func is_open_requested() -> bool:
	return pressure_active or latched_open or obstructed
```

Store the closed and open positions on `_ready`. In `_physics_process`, choose the requested endpoint, set `OPENING` or `CLOSING`, move with `move_toward(speed * delta)`, and change to `OPEN` or `CLOSED` only at the endpoint. `set_obstructed(true)` immediately changes the requested endpoint to open.

- [ ] **Step 5: Compose pressure, barrier, and safety volume**

Add:

```text
PressurePlate (Area3D, script pressure_plate.gd, layer Trigger)
├── MeshInstance3D
└── CollisionShape3D

SlidingBarrier (AnimatableBody3D, script sliding_barrier.gd)
├── MeshInstance3D
├── CollisionShape3D
└── SafetyVolume (Area3D, layer Trigger, covers the full closing path)
    └── CollisionShape3D
```

Connect `PressurePlate.active_changed` to `SlidingBarrier.set_pressure_active`. Connect SafetyVolume enter/exit signals to an overlap counter; call `set_obstructed(counter > 0)`. Ignore the barrier itself and accept the player plus rigid props as obstructions.

- [ ] **Step 6: Connect the authored lever as a permanent latch**

Connect `TestLever.state_changed(active)` so the first `true` calls `SlidingBarrier.latch_open()`. Do not allow later lever toggles to clear the latch. Change its prompt to `Release Lock` and disable its target after successful use.

- [ ] **Step 7: Verify obstruction and repeated state changes**

```text
[ ] Player on plate opens barrier.
[ ] Crate on plate opens barrier.
[ ] Removing one of two eligible bodies keeps it open.
[ ] Removing the last body starts closing.
[ ] Player or crate in SafetyVolume makes a closing barrier reopen.
[ ] Releasing the internal lever keeps the barrier open permanently.
[ ] Rapid plate entry/exit cannot strand the barrier between states.
```

- [ ] **Step 8: Run automated tests and commit**

Expected: PASS.

```bash
git add gameplay/mechanisms tests/ring1 levels/interaction_lab.tscn
git commit -m "feat: add pressure-controlled safe barrier"
```

---

### Task 7: Add the Readable Clue and Objective Flow

**Files:**
- Create: `gameplay/readables/readable_object.gd`
- Create: `gameplay/objectives/objective_item.gd`
- Create: `levels/interaction_lab.gd`
- Create: `tests/ring1/test_objective_flow.gd`
- Modify: `gameplay/interaction/player_interactor.gd`
- Modify: `ui/interaction_hud.gd`
- Modify: `tests/ring1/run_tests.gd`
- Modify: `levels/interaction_lab.tscn`

**Interfaces:**
- Consumes: `PlayerInteractor.open_readable`, HUD presentation methods, and the `player` group.
- Produces: one-shot `ObjectiveItem.acquired`, laboratory states `SEEK_OBJECTIVE`, `RETURN_TO_EXIT`, and `COMPLETE`.

- [ ] **Step 1: Write failing objective-flow tests**

Create `tests/ring1/test_objective_flow.gd`:

```gdscript
extends RefCounted

static func run(suite: Ring1TestSuite, root: Node) -> void:
	var lab := InteractionLab.new()
	var player := Node3D.new()
	root.add_child(lab)
	root.add_child(player)
	player.add_to_group("player")
	suite.expect_equal(lab.state, InteractionLab.State.SEEK_OBJECTIVE, "initial state")
	suite.expect_false(lab.try_complete(player), "cannot exit before objective")
	lab.on_objective_acquired(&"marked_object")
	suite.expect_equal(lab.state, InteractionLab.State.RETURN_TO_EXIT, "return state")
	suite.expect_true(lab.try_complete(player), "player completes after objective")
	suite.expect_equal(lab.state, InteractionLab.State.COMPLETE, "complete state")
	suite.expect_false(lab.try_complete(player), "completion is one shot")
	lab.queue_free()
	player.queue_free()
```

Add it to the runner.

- [ ] **Step 2: Run tests and verify missing flow types**

Expected: parsing fails for `InteractionLab`.

- [ ] **Step 3: Implement readable presentation mode**

`ReadableObject` exports `title` and multiline `body`, connects its target, and calls:

```gdscript
interactor.open_readable(title, body)
```

`PlayerInteractor.open_readable` sets `reading_open`, clears the focus prompt, and emits `readable_opened`. While reading, the next `interact` or `ui_cancel` closes the panel and emits `readable_closed`; no world interaction or carry action runs on that input.

- [ ] **Step 4: Implement one-shot objective acquisition**

`ObjectiveItem` exports `objective_id: StringName = &"marked_object"`. On accepted interaction it:

```gdscript
if acquired_already:
	return
acquired_already = true
interaction_target.enabled = false
visible = false
collision_shape.disabled = true
acquired.emit(objective_id)
```

This object does not create an inventory entry.

- [ ] **Step 5: Implement the laboratory state machine**

Create `levels/interaction_lab.gd`:

```gdscript
class_name InteractionLab
extends Node3D

enum State { SEEK_OBJECTIVE, RETURN_TO_EXIT, COMPLETE }

@export var hud: InteractionHUD
var state := State.SEEK_OBJECTIVE

func on_objective_acquired(objective_id: StringName) -> void:
	if state != State.SEEK_OBJECTIVE or objective_id != &"marked_object":
		return
	state = State.RETURN_TO_EXIT
	if hud != null:
		hud.set_objective("Return to the entrance")

func try_complete(body: Node3D) -> bool:
	if state != State.RETURN_TO_EXIT or not body.is_in_group("player"):
		return false
	state = State.COMPLETE
	if hud != null:
		hud.show_completion("Interaction laboratory complete")
	return true
```

Set the initial HUD objective to `Retrieve the marked object` on `_ready`.

- [ ] **Step 6: Compose clue, objective, and exit**

Add:

```text
ReadableClue (StaticBody3D, script readable_object.gd)
├── MeshInstance3D
├── CollisionShape3D
└── InteractionTarget (verb = "Read")

MarkedObject (StaticBody3D, script objective_item.gd)
├── MeshInstance3D
├── CollisionShape3D
└── InteractionTarget (verb = "Take")

ExitVolume (Area3D, layer Trigger)
└── CollisionShape3D
```

Connect `MarkedObject.acquired` to `InteractionLab.on_objective_acquired` and `ExitVolume.body_entered` to `InteractionLab.try_complete`.

- [ ] **Step 7: Verify readable and objective behavior**

```text
[ ] E opens the clue and displays authored title/body.
[ ] E or Escape closes it without also using a world target.
[ ] Taking the marked object hides and disables it exactly once.
[ ] Entering the exit before acquisition does nothing.
[ ] Objective text changes after acquisition.
[ ] Returning to the exit displays completion exactly once.
```

- [ ] **Step 8: Run automated tests and commit**

Expected: PASS.

```bash
git add gameplay/readables gameplay/objectives gameplay/interaction/player_interactor.gd ui levels tests/ring1
git commit -m "feat: add ring one objective flow"
```

---

### Task 8: Integrate Both Routes, Prototype Feedback, Debugging, and Acceptance

**Files:**
- Create: `gameplay/feedback/placeholder_tone.gd`
- Create: `tests/ring1/manual_acceptance.md`
- Modify: `levels/interaction_lab.tscn`
- Modify: `levels/interaction_lab.gd`
- Modify: `gameplay/mechanisms/lever.gd`
- Modify: `gameplay/mechanisms/lamp.gd`
- Modify: `gameplay/mechanisms/sliding_barrier.gd`
- Modify: `gameplay/interaction/player_interactor.gd`
- Modify: `ui/interaction_hud.gd`

**Interfaces:**
- Consumes: every Ring 1 capability and debug-summary method.
- Produces: the complete two-route laboratory, generated placeholder tones, toggleable F3 debug feedback, and the final ten-run acceptance record.

- [ ] **Step 1: Finish the two-route geometry**

Arrange the laboratory so:

```text
Route A: Spawn → carry crate to pressure plate → barrier opens → take objective.
Route B: Spawn → carry crate below 1.20 m opening → mantle through → take objective.
Exit: Inside lever permanently opens barrier → return to entrance.
```

The crate cannot simultaneously remain on the plate and support the mantle route. The player must be able to recover the crate from every valid location, and the reset volume must cover every invalid fall location.

- [ ] **Step 2: Add generated placeholder sound**

Create `PlaceholderTone` as `AudioStreamPlayer3D`. Its public method creates a short 16-bit mono `AudioStreamWAV` with an attack-decay envelope:

```gdscript
class_name PlaceholderTone
extends AudioStreamPlayer3D

func play_tone(frequency: float, duration: float = 0.08) -> void:
	var mix_rate := 22050
	var sample_count := int(mix_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in range(sample_count):
		var time := float(index) / mix_rate
		var envelope := 1.0 - float(index) / sample_count
		var sample := int(sin(TAU * frequency * time) * envelope * 6000.0)
		bytes.encode_s16(index * 2, sample)
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = mix_rate
	wave.stereo = false
	wave.data = bytes
	stream = wave
	play()
```

Give lever, lamp, barrier, pickup, throw, objective, and completion events distinct frequencies. These tones are diagnostic prototype feedback, not final sound design.

- [ ] **Step 3: Implement the F3 debug overlay**

`InteractionLab` toggles debug visibility on `debug_overlay` and updates the debug label with:

```text
Focus: <target name or none>
Range: 2.25 m
Carry: <prop name or none>
Plate: active|inactive (<eligible count>)
Barrier: closed|opening|open|closing
Barrier inputs: pressure=<bool> latched=<bool> obstructed=<bool>
Objective: seek|return|complete
```

Expose the values through `get_debug_summary()` methods. Do not inspect private variables from unrelated scripts or use absolute node paths.

- [ ] **Step 4: Write the exact manual acceptance checklist**

Create `tests/ring1/manual_acceptance.md` with these groups:

```markdown
# Ring 1 Manual Acceptance

## Focus
- [ ] Acquire, change, lose, occlude, and delete a focus target.
- [ ] Verify focus at 2.24 m and no focus at 2.26 m.
- [ ] Verify unavailable prompt and rejected interaction.

## Input and reading
- [ ] Press interact rapidly twenty times on lever and lamp.
- [ ] Open and close the readable with E and Escape.
- [ ] Confirm closing a readable performs no world interaction.

## Carrying
- [ ] Pick up, place, drop, and throw the crate.
- [ ] Carry into a wall and around a narrow corner.
- [ ] Exceed maximum hold distance and confirm safe drop.
- [ ] Throw out of bounds and confirm spawn reset at rest.

## Plate and barrier
- [ ] Activate with player, crate, and both together.
- [ ] Remove one of two bodies and confirm the barrier stays open.
- [ ] Obstruct closing with player and crate; confirm reopen.
- [ ] Toggle pressure rapidly and confirm declared barrier states.

## Routes and objective
- [ ] Complete pressure-plate route from a clean restart.
- [ ] Complete crate-and-mantle route from a clean restart.
- [ ] Confirm early exit does not complete.
- [ ] Confirm objective acquisition and completion occur once.

## Ten-run gate
- [ ] Complete ten consecutive clean runs, alternating routes.
```

- [ ] **Step 5: Run the complete automated suite**

Open `tests/ring1/run_tests.tscn` and press F6.

Expected: `Ring 1 rules: PASS`, no parser errors, no orphan-node warnings, and zero failure exit code when run headlessly.

- [ ] **Step 6: Run the manual checklist and record defects before fixes**

For every failed item, add a line below the item in this format before changing code:

```text
Observed: <exact behavior>
Reproduction: <minimal repeatable steps>
Expected: <requirement from this plan>
```

Fix only recorded Ring 1 failures. Re-run the affected section, then the automated suite.

- [ ] **Step 7: Pass the ten-run completion gate**

Alternate the two routes across ten clean scene restarts. If any run encounters a progression block, stale prompt, tunneling prop, undeclared barrier state, or duplicate completion, reset the consecutive-run count to zero after fixing it.

- [ ] **Step 8: Commit the completed ring**

Run:

```bash
git add gameplay levels ui tests project.godot Player.tscn
git commit -m "feat: complete intentional interaction ring"
```

Expected: working tree contains no unintended Ring 1 changes, automated tests pass, and `manual_acceptance.md` records ten consecutive successful runs.
