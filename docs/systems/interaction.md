# Interaction, inventory, and hands

[PlayerFrob.gd](../../scripts/Interaction/PlayerFrob.gd) casts a gameplay-aim ray, finds a target, highlights it, and dispatches `frob(player)`. Inventory is data; HandSlot presents its contents in the first-person view. Interaction also owns physical carrying, tool use, locks, doors/containers, guard habit furniture, alarms, and water volumes. [Movement](movement.md) describes movement/aim/health integration; [combat](combat.md) covers shared weapon and projectile contracts.

## Responsibilities

| Source | Responsibility |
| --- | --- |
| [PlayerFrob](../../scripts/Interaction/PlayerFrob.gd) | Frob ray/highlight/prompt, dispatch, carry/set-down/throw, body shoulder, blackjack, thrown tools, key-turn and lockpick flow, impact noise. |
| [Inventory](../../scripts/Interaction/Inventory.gd) | Purse, unique key IDs, counted belt entries, selection, mutation signals. |
| [HandSlot](../../scripts/Interaction/HandSlot.gd) | Selected-item switching, off-hand job queue, key turns, purse/keyring, combat frames, trails/blood/bow string/kick, contact presentation. |
| [HandContacts](../../scripts/Interaction/HandContacts.gd) | Persistent world holds with alternating hand travel and grip weights. |
| [ViewArms](../../scripts/Interaction/ViewArms.gd) | Scaled Humanoid/ArmReach viewmodel rig solving hand and foot targets. |
| [Loot](../../scripts/Interaction/Loot.gd) | Rigid pickup of purse value. |
| [KeyItem](../../scripts/Interaction/KeyItem.gd) | Rigid pickup of key ID plus belt item. |
| [ToolItem](../../scripts/Interaction/ToolItem.gd) | Rigid pickup of counted belt item/weapon/ammunition. |
| [Door](../../scripts/Interaction/Door.gd) | Hinged panel, locking, obstruction checks, navigation layers, last-opener evidence. |
| [Chest](../../scripts/Interaction/Chest.gd) | Lockable animated lid; its collision hides contents from frob rays. |
| [Lever](../../scripts/Interaction/Lever.gd) | Cooldown action trigger and return animation. |
| [AlarmBell](../../scripts/Interaction/AlarmBell.gd) | Alarm communication/garrison escalation and toll timing. |
| [IdleSpot](../../scripts/Interaction/IdleSpot.gd) | Weakly owned habit spot with kind, facing, nearest/free/claim/release. |
| [Furnishings](../../scripts/Interaction/Furnishings.gd) | Procedural furniture, habit spots, crate stocks, and navigation exclusion metadata. |
| [Props](../../scripts/Interaction/Props.gd) | Procedural doors/chests/loot/keys/tools/weapons/crates/spikes/world blocks and direct inventory grants. |
| [WaterVolume](../../scripts/Interaction/WaterVolume.gd) | Axis-aligned water queries, contacts, splash/buoyancy, visual light/shoreline data. |

## Frob flow and inputs

Fallback actions are `frob` E, `inventory` Tab, `throw` left mouse, `belt_next` wheel down, and `belt_prev` wheel up; existing project mappings remain. Holding inventory displays purse/keyring when hands are free. The throw action is shared with combat: held objects throw, selected blackjack swings, flashbomb/waterflask launches, and selected weapons are handled by PlayerCombat. Successful noncombat use consumes the press until release. Mouse recapture suppression prevents accidental actions.

The default frob mask is 5 (physics world layer 1 + loose-body layer 3). `_find_target()` casts from `player.aim_transform()` up to frob_distance, finds a frobbable ancestor or a carryable rigid body, and supports target ownership on reachable areas. `_frobbable_owner()` returns null when no ancestor qualifies. `_set_target()` removes prior highlight and recursively overlays the new one, skipping nested child frobbables. Carrying clears the aimed target. Dead players clear highlight and pending blackjack windup.

`frob(player: Node) -> void` is the duck-typed target contract. `get_prompt(player: Node) -> String` is optional. Rigid targets can implement `can_carry() -> bool`; without it, mass <= max_carry_mass allows carrying. Pickup actors explicitly return false from can_carry. A custom can_carry overrides the mass fallback. A target can expose lock fields `locked`, `key_id`, `pickable` and `can_unlock(player)` to enter the lock workflow. These methods are not supplied by a universal base class.

`current_prompt() -> String` returns target/carry text or `""`. `current_actions() -> Array` returns pairs `[action: StringName, label: String]`; an empty action means status (Locked, Too heavy, Picking the lock), and `[]` means no rows, including during a key turn. `is_carrying()` is true for held or shouldered objects; `is_shouldering()` is narrower. Carry/pickup requires locomotion and idle combat; the movement state check does not itself require floor contact.

`frobbed(target: Node)` reports dispatch or completed unlock, `picked_up(body: RigidBody3D)` reports carry/shoulder, and `released(body: RigidBody3D, thrown: bool)` reports release. Released body can be **null** if the held body was freed/invalidated. These signals occur synchronously in their respective handlers.

## Inventory and pickup contract

`purse` is inferred int, `keys: Array[StringName]` has unique IDs, `belt: Array[Dictionary]` stores entries, and `belt_index` is int with -1 for empty hands. Each belt entry is `{id: StringName, name: String, mesh: Mesh|null, count: int}`. Dictionary values are conventionally typed; runtime Dictionary does not enforce this schema. IDs merge even if new name/mesh differs; existing display data stays. APIs do not validate negative value/count inputs.

| Exact API | Behavior and signals |
| --- | --- |
| `add_loot(value: int) -> void` | Adds without clamping; emits loot_taken(value, purse), then changed. |
| `add_key(key_id: StringName, key_name: String, mesh: Mesh = null) -> void` | Adds unique key membership, always emits key_taken, then adds one belt entry/count. Duplicate pickup still increases belt count. |
| `has_key(key_id: StringName) -> bool`, `is_key_item(id: StringName) -> bool` | Key membership. Consuming a belt count does not remove the key ID from keys. |
| `add_belt_item(id: StringName, item_name: String, mesh: Mesh = null, count := 1) -> void` | Merge count by ID or append new entry; new entry selects itself if currently empty-handed. Emits changed; merging does not emit selection change. |
| `selected_item() -> Dictionary` | Stored entry or `{}` for no valid selection. Returns the original Dictionary, not a duplicate; direct mutations can bypass signals. |
| `select_next(step := 1) -> void` | Signed int step wraps across items plus empty hands. Empty belt is a no-op; otherwise emits selection then changed. |
| `select_by_id(id: StringName) -> bool` | Selects/emits selection+changed if found; false/no mutation if absent. |
| `holster() -> void` | Selects -1, emits empty selection and changed; no-op if already empty. |
| `count_of(id: StringName) -> int` | Count or 0 if absent. |
| `take_one(id: StringName) -> void` | Decrement; remove at <=0, holster if selected entry removed, shift selection index if an earlier entry removed. Missing ID is no-op. Emits changed for matched consumption. |

Signals are `changed`, `loot_taken(value: int, total: int)`, `key_taken(key_id: StringName)`, and `belt_selection_changed(item: Dictionary)` (empty dictionary means empty hands). Consumers that render counts should observe changed as well as selection signals. Bow consumption intentionally keeps a zero-count arrows entry; thrown tools use take_one and can remove their entry.

Loot has exported inferred-int value and String loot_name; KeyItem has `key_id: StringName` and inferred-String key_name; ToolItem has `tool_id: StringName`, inferred-String tool_name and inferred-int count. All are RigidBody3D pickups with a taken bool. `frob(player: Node)` checks taken, marks it, updates `player.inventory`, and queues deletion. They assume a valid player/inventory. Key/tool mesh comes from optional child `MeshInstance3D`; absent visual yields null. Loot goes straight to purse and cannot be carried. The first frob captures a presentation record `{kind: String, mesh: Mesh|null, from: Transform3D}` before deletion; kind is loot/key/tool, and from is world-space.

## Carrying, tools, and locks

Hand carrying preserves prior gravity scale and parent, removes player collision via mutual exceptions, sets gravity to zero, and marks the body in_hand. A capped proportional velocity moves the body toward the head-relative hold point; angular velocity is damped. The hold point has horizontal clearance from the player so looking down does not bury the object inside the capsule. Frozen/reparented bodies are released where they are; sustained distance beyond carry_break_distance for carry_break_time breaks the hold.

Set-down restores gravity/exceptions/group first. A nearby sufficiently horizontal terrain surface can receive a full-shape-tested upright placement; otherwise the body drops and impact noise is armed. Throw applies aim-direction speed scaled down for mass plus player velocity, arms impact noise, and emits release. `_fits_down(body: RigidBody3D, at: Transform3D, down: float) -> bool` sweeps each collision shape through the lowering motion; points use world transforms. `_half_height(body: RigidBody3D) -> float` approximates half-height from the first supported direct-child box/sphere/capsule/cylinder shape, ignores child transforms, and falls back to 0.25 m.

`arm_impact_noise(body: RigidBody3D) -> void` stores prior velocity. `_update_falling()` detects abrupt velocity changes so loudness uses **pre-impact** speed, emits at the body's landing point, and can hurt a guard by body mass/speed. Slow careful placements are silent. Invalid/freed bodies leave tracking. `drop_held() -> void` releases both carry styles when present.

`shoulder(body: RigidBody3D) -> void` is a no-op if already carrying, movement requires hands, or combat is active. It finishes an optional fall, freezes/hides the body, disables layer/mask, and emits picked_up; it does not use the held-object in_hand group. `put_down_body() -> void` clears shoulder ownership, searches nearby rotated placements, and falls back to a point in front if none fits; restores collision/visibility, calls lay_down when supported or unfreezes, resets interpolation, makes a body landing sound, and emits released(false). Invalid bodies stop early. Movement slows shoulder carrying and blocks sprint.

Blackjack contact occurs after windup, raycasts world+guards, and calls knock_out(player) if supported; ordinary surface misses make knock noise. Thrown tool kind IDs are flashbomb/waterflask; delayed release consumes one belt count, launches [ThrownTool](combat.md), and uses shared attack consumption. A lockpick is a reusable belt item identified by lockpick.

When a matching key exists, `_turn_key_in(lock: Node)` either immediately calls lock.frob without a compatible HandSlot or queues a key-turn job. At completion it checks lock validity, living player, and distance from original lock point before frobbing; moving away can leave it locked. `_unlocking` prevents another frob until completion. `can_pick() -> bool` checks positive lockpick count. `_pick_lock(lock: Node)` selects it and resets progress. `_update_picking(delta: float)` cancels if target changes, unlocks externally, is freed, player exceeds PICK_STILL, or hands are unavailable. After PICK_TIME, it **unlocks only**, emits frobbed, and leaves opening to a later frob. Audible clicks use game seconds. `picking() -> bool` and `pick_progress() -> float` expose active state and 0..1 progress, with 0 inactive.

## Door, chest, lever, and bell APIs

| API | Contract |
| --- | --- |
| `Door.frob(player: Node) -> void`, `Chest.frob(player: Node) -> void` | Matching key unlocks; otherwise emits rattled and returns. An unlocked frob toggles requested is_open/target angle. Requires player/inventory where lock or facing logic uses them. |
| `can_unlock(player: Node) -> bool` | False for null player or empty key_id; checks matching inventory key. `can_pick(player: Node) -> bool` delegates to optional player.frob.can_pick. pickable gates lockpick dispatch, not manual state changes. |
| Door/Chest `opened`, `closed`, `rattled` | Open/close fires when animation reaches target, not at the frob. Rattle is immediate lock failure. |
| `Door.opened_by() -> Node`, `left_open() -> bool` | Weak last opener or null. Evidence requires a door that began shut and is open without a recognized guard opener; notices are cleared upon reopening. |
| `Door.panel_centre() -> Vector3`, `facing() -> Vector3`, `doorway() -> Vector3`, `footprint() -> PackedVector3Array` | World current panel centre; closed horizontal front; closed doorway floor centre; padded closed doorway corners. Missing shape uses fallback centre/width. |
| `Door.key_layer(id: StringName) -> int`, `nav_layers() -> int` | Shared per-key navigation bit (cycles after 31 allocated bits); unlocked door uses 1. Key allocation is cached and key IDs need consistent usage. |
| `Lever.build(parent: Node, position: Vector3, yaw: float, title: String, action: Callable) -> StaticBody3D` | Attach world-positioned lever/post/sign and connect pulled to action. yaw is radians; callback takes no signal args. `frob(_player: Node)` emits pulled once per cooldown; prompt becomes empty during wait. |
| `AlarmBell.build(parent: Node, position: Vector3, yaw := 0.0) -> StaticBody3D` | Attach bell at floor position, rotate local yaw radians, reset interpolation. |
| `AlarmBell.ring(by: Node, where: Vector3) -> void` | No-op during cooldown. Start timed tolls, emit communication toward world where, raise player's garrison alarm if player exists, emit rung(by: Node). by must support weakref. Player frob calls ring(player, bell position). |
| `AlarmBell.can_ring() -> bool`, `is_tolling() -> bool`, `rope_point() -> Vector3` | Cooldown, pending toll state, and guard standing point 0.55 m along bell +Z. |

Door origin is hinge foot, panel local +X, closed front -Z. It preserves closed basis to choose swing away from the opener. Every candidate rotation tests people, ragdolls/bodies, and in_hand objects **on the swing-toward side**. Loose keys/crates do not jam it, and static-wall clearance is a level-design responsibility. Navigation groups are doors and nav_ignore. Chest node is at back/top hinge with child `Lid: AnimatableBody3D`; absent Lid retries lookup, and no animation signal is emitted until it exists/moves. Chest compares the newly assigned angle, since synced body readback can lag physics.

Alarm communication schema is `{what: StringName (&"alarm"), where: Vector3, time: numeric Comms.now(), id: int (-instance ID), from: WeakRef}`. Guards receiving it use the supplied destination; repeated audible tolls are presentation rather than repeated message dispatch.

## Hand presentation and contacts

HandSlot lives below Camera3D. It draws small viewmodels on visual bit `1 << 18` (layer 19), uses z_clip_scale to keep them in front of world geometry with mutual depth order, and excludes them from lightgem capture. This render layer is unrelated to physics masks. It observes inventory and player/body movement. Shared grip constants retain mesh/hand coordinate conventions: full-size camera space +X right/+Y up/-Z forward, mesh-local blade +Y/true edge +X, hand-bone finger/thumb axes.

| API | Inputs/outputs and effects |
| --- | --- |
| `show_item(item: Dictionary) -> void` | Queue switch to item.mesh, or empty hands for absent/null mesh; previous stow audio may play immediately. |
| `receive(kind: String, mesh: Mesh, from: Transform3D) -> void` | Queue off-hand pickup job with world from. Mesh may be null. Jobs store `{kind, mesh, from, t: float}`. |
| `turn_key(mesh: Mesh, lock_point: Vector3, done: Callable) -> void` | Prioritize `{kind: "key_turn", mesh, lock: Vector3, done: Callable, t: float}`. Hurry existing pickup, preserve existing key turn; completion invokes callback and emits key_turned. Callback is responsible for actual gameplay unlock. |
| `set_checking(checking: bool) -> void`, `is_busy() -> bool` | Purse/keyring display and current off-hand activity. Queued work eventually runs through render processing. |
| `set_suppressed(suppressed: bool) -> void` | Suppress visible selected item/grip participation for carry/death/etc. |
| `set_weapon_frame(frame: Transform3D) -> void`, `weapon_frame() -> Transform3D` | Full-size camera-space combat frame, previous/current tick interpolation and latest stored frame. |
| `set_brace(amount: float) -> void`, `set_bow_draw(draw: float, arrow: Mesh) -> void` | Block brace blend and normalized bow draw/nocked arrow visual. Null arrow means none available. |
| `play_swing()`, `play_throw()`, `play_kick()`, `land(fall_speed: float)`, `jump()` | Visual action/impulse hooks, no inventory damage mutation. |
| `set_trail(on: bool, power := false, hot := false) -> void`, `impact(kind: StringName) -> void` | Blade trail and recoil. Kinds flesh/heavy/blocked/deflect/block/parry/kick/bow. Stopped blade outcomes disable trail; bow impact starts re-nocking. |
| `bloody(amount: float) -> void`, `blood_on_blade() -> float`, `show_glint() -> void` | Per-mesh-instance blood level clamped 0..1 and charge glint, no-op without blade where appropriate. |
| `grip_points() -> Array[Vector3]`, `gripping() -> float`, `grip_below(view: Transform3D) -> float` | World shown hands above 0.5 grip weight, strongest blend, contact-down angle radians; empty/zero when unavailable or suppressed. |
| `current_item_mesh() -> Mesh`, `is_item_visible() -> bool` | Stored mesh or null, and whether it is fully raised/has a mesh. Debug visibility is based on state threshold. |

HandContacts `_init(p_player: CharacterBody3D)` binds the controller. State is FREE/HANG/MANTLE/VAULT/LADDER/ROPE/CARRY. Each `Grip` holds world `at/from: Transform3D`, normalized `travel`, float `weight`, bool wanted/planted. `place(where: Transform3D)` starts from current interpolated hold if already planted, otherwise starts at target; `current() -> Transform3D` interpolates with a lifted arc. `right_busy` allows left-only mantle/vault with weapon visible; hangs/ladders/ropes lower the weapon before restoring a two-hand hold.

`update(delta: float) -> void` reads movement/carry and advances targets/weights; `hand(side: int) -> Transform3D`, `weight(side: int) -> float`, `wants(side: int) -> bool`, and `curl(side: int) -> float` use LEFT=0/RIGHT=1 with no out-of-range guard. `holding() -> float` is max weight. `below(view: Transform3D) -> float` measures the desired/planted holds below the view, clamped at zero if none/above. Ladder rungs use 0.3 m world-Y spacing; rope holds use metres from anchor. Geometry rays plant on actual tops, while persistent contacts travel only after slack/next-rung conditions.

ViewArms `setup(layer: int) -> void` builds rig/materials. `set_hand(side: int, target: Transform3D, weight: float, curl: float)` and `set_foot(target: Transform3D, weight: float)` take **parent small-view-space** targets, not world contacts directly. `forearm_to(side: int, wrist: Vector3) -> Vector3` returns the parent-space elbow-to-wrist direction. `hand_position(side: int) -> Vector3` reports solved hand or bone world position and requires setup. `shrink(camera_space: Transform3D) -> Transform3D` scales the origin into the small view space, preserving basis. These presentation transforms do not drive gameplay collision.

## Props, furniture, and habit spots

Props helpers `material(color: Color, metallic := 0.0) -> StandardMaterial3D`, `mesh_box(size: Vector3, color: Color) -> MeshInstance3D`, and `shape_box(size: Vector3) -> CollisionShape3D` return unattached objects. World builders attach and return their root. Arguments using `:=` are inferred; positional coordinates below are world-space except the explicit door exception. Yaw values are radians. Placement resets interpolation for moving props where required.

| Builder | Important arguments, return and origin |
| --- | --- |
| `door(parent: Node, position: Vector3, yaw := 0.0, width := 1.0, height := 2.1, locked := false, key_id: StringName = &"", door_name := "door") -> Node3D` | position is hinge foot set **parent-local before insertion**; expects identity parent or editor placement because synced doors must not teleport through collision after attachment. |
| `chest(parent: Node, position: Vector3, yaw := 0.0, size := Vector3(0.9, 0.55, 0.55), locked := false, key_id: StringName = &"", chest_name := "chest") -> Node3D` | position is floor footprint centre; actual root offset to back/top hinge. size full dimensions; hollow static body and Lid children. |
| `loot(parent: Node, position: Vector3, value: int, loot_name := "goblet") -> RigidBody3D` | Loot rigid origin at supplied position. |
| `key(parent: Node, position: Vector3, key_id: StringName, key_name := "key") -> RigidBody3D` | Key rigid origin at supplied position. |
| `tool(parent: Node, position: Vector3, tool_id: StringName, tool_name: String, color: Color, shape := "sphere", count := 1) -> RigidBody3D` | Belt-tool rigid origin; tool_mesh supports rod/box/flask and ball fallback. color is required. |
| `crate(parent: Node, position: Vector3, size := 0.5, mass := 5.0, color := Color(0.55, 0.42, 0.25)) -> RigidBody3D` | Cube centre, not floor foot; mass and side length. |
| `weapon(parent: Node, position: Vector3, weapon_id: StringName) -> RigidBody3D`, `arrows(parent: Node, position: Vector3, count := 6) -> RigidBody3D` | Belt pickups with mesh-bounds collision. weapon_id must resolve; unknown ID is not guarded. |
| `spikes(parent: Node, center: Vector3, width: float, height: float, facing: Vector3) -> Area3D` | centre of spiked face, pointing along facing; thin hazard slab in front. |
| `block(parent: Node, center: Vector3, size: Vector3, color := Color(0.5, 0.5, 0.52), surface := "") -> StaticBody3D` | Box centre/full size; optional surface metadata affects footsteps/contact effects. |
| `give_tools(player: Node, flash_bombs := 3, flasks := 3, lockpick := true) -> void`, `give_weapons(player: Node, arrows := 12) -> void`, `give_blackjack(player: Node) -> void` | Add belt entries directly; valid inventory required. No world pickup. |

Furnishings builds `chair/bench/table/provisions/chopping_block/cart/railing -> StaticBody3D`, `campfire -> Node3D`, and `crate_piles/lean_spots -> Array`. Most accept parent, world at: Vector3, and yaw: float; dimensions/spots/count/chairs/every use source defaults. `chair(..., stool := false)`, `bench(..., length := 1.8)`, and `table(..., size := Vector2(1.6, 0.8), chairs := 4)` place seats with floor-projected seat centres. `campfire(parent: Node, at: Vector3, spots := 3)` makes a tended Fire and fire spots. `crate_piles(parent: Node, from: Vector3, from_yaw: float, to: Vector3, to_yaw: float, count := 4) -> Array` returns rigid crates in stock group and two pile spots linked by metadata other. `restack(crates: Array, from: Vector3, from_yaw: float) -> void` skips invalid/nonrigid items, repositions valid ones, zeros velocity, and resets interpolation. `railing(parent, from, to, out, every := 1.6)` and `lean_spots(parent, from, to, out, every := 2.0)` use world endpoints and outward facing.

Furniture nav metadata `nav_blocks: Array[Dictionary]` has `{corners: PackedVector3Array (world footprint), bottom: float (world Y), height: float}` and joins nav_blocks group; bake navigation after placement. Seat spots carry `bodies: Array` of furniture bodies the habit may pass among; fire spots carry `fire: Area3D`; paired piles carry `other: Node3D`. These are duck-typed metadata, not validated resources.

IdleSpot `build(parent: Node, spot_kind: StringName, at: Vector3, yaw: float) -> Node3D` uses floor origin and -Z facing, joining idle_spots. Kinds are seat/lean/rail/table/chop/fire/work/pile. `nearest(tree: SceneTree, spot_kind: StringName, from: Vector3, reach: float, man: Node) -> Node3D` finds strictly closer than horizontal reach with <=2.5 m vertical difference; caller's own spot counts free; null if none. `holder() -> Node3D` clears expired/invalid/dead/knocked-out/out-of-tree owners or mismatched habit spot, else returns owner. `free_for(man: Node) -> bool`, `claim(man: Node) -> bool`, and `release(man: Node) -> void` enforce one weak owner; claim false when occupied and release only clears the matching owner.

## Water API and visual survey

WaterVolume expects an **unrotated axis-aligned** box with origin centre and `size: Vector3` full XYZ extents (Y is vertical depth). `build(parent: Node, centre: Vector3, box_size: Vector3) -> Area3D` attaches it, and `_ready()` creates a Shape box if absent, visual surface, shoreline survey, WaterView integration, delayed light gathering and overlap signals. Groups include water. Bake water navigation after the volume/terrain are placed.

| API | Contract |
| --- | --- |
| `at(tree: SceneTree, point: Vector3, above := 0.0) -> Area3D` | First grouped water containing point, or null; above extends upper inclusion boundary only. |
| `surface_y() -> float`, `bottom_y() -> float`, `footprint() -> PackedVector3Array` | World box surface/bottom and horizontal corners; geometry floor can be higher than box bottom. |
| `over(point: Vector3, margin := 0.0) -> bool`, `holds(point: Vector3, above := 0.0) -> bool` | Horizontal box bounds with inward margin; full vertical containment with above tolerance. |
| `depth_of(point: Vector3) -> float` | Surface Y minus point Y, negative above water. |
| `floor_under(point: Vector3, exclude: Array[RID] = []) -> float`, `deep_at(point: Vector3) -> bool` | Terrain-layer-1 downward ray from surface+0.05 m; world floor Y or bottom_y on miss. Deep if surface-to-floor > SWIM_DEPTH. |
| `splash(at: Vector3, speed: float, body: Node = null) -> void` | Projects to surface, emits speed-scaled sound/noise/spray; null source uses volume. This method always emits; entry caller applies downward SPLASH_SPEED threshold. |
| `ripple(tile := RIPPLE_TILE, stretch := RIPPLE_STRETCH, drift := CANAL_FLOW) -> void` | Surface shader settings: tile metres, anisotropic stretch, lengthwise flow m/s; no-op until material exists. |
| `moon_direction() -> Vector3`, `moon_visibility() -> float`, `moon_colour() -> Color` | Shared moon/light data for surface and submerged view, with standalone directional-light fallback. |
| `gather_lights() -> void` | Gather nearby lights for reflection columns; `_show_columns()` refreshes intensity as lights flicker/douse. |
| `refresh_shoreline() -> void` | Restart bounded-resolution static terrain survey over physics ticks after bank changes. Terrain-only rays start just above water so bridges do not become bed. |

Body overlap calls add_water_volume/remove_water_volume when present. Unfrozen rigid bodies float via mass-scaled buoyancy and linear/angular drag; invalid/frozen bodies leave the float list. Shoreline data is static, does not follow actors/camera, and updates across ticks. Concave terrain uses triangle winding to distinguish a land exit from an overhead deck because backface query normals can be flipped. Keep this geometry explanation when changing the survey.
