# Combat, projectiles, and hazards

[PlayerCombat.gd](../../scripts/Combat/PlayerCombat.gd) is the player's `Combat` child. It reads the selected inventory weapon, gates actions by movement/carry/death state, advances attacks and defence, and sends presentation to HandSlot, CameraJuice, Sfx, Fx, and TimeFx. Damage receivers own their health; combat decides contacts and defence outcomes. [Movement](movement.md) documents the player's `take_damage()` and gameplay aim, and [interaction](interaction.md) documents the belt and shared attack button.

## Responsibilities

| Source | Responsibility |
| --- | --- |
| [PlayerCombat](../../scripts/Combat/PlayerCombat.gd) | Melee phases, charge, combo, parry/block, counter/clash/Mikiri, stamina, adrenaline, kick, dodge, bow, drop attack, hand poses. |
| [Weapon](../../scripts/Combat/Weapon.gd) | Weapon Resource tuning, shared armoury, imported/procedural meshes and grip metadata. |
| [ViewPoses](../../scripts/Combat/ViewPoses.gd) | Camera-space static pose tables, swept grip/blade frames, interpolation. |
| [Arrow](../../scripts/Combat/Arrow.gd) | Ray-swept gravity projectile, target damage, sticking, recovery, stray-arrow evidence. |
| [Thrown](../../scripts/Combat/Thrown.gd) | Damage rider attached to a guard-thrown rigid body; once-per-victim hit and bounce. |
| [ThrownTool](../../scripts/Combat/ThrownTool.gd) | Belt flashbomb/waterflask flight, burst, visibility/occlusion and torch dousing. |
| [Strikeable](../../scripts/Combat/Strikeable.gd) | Fixed target forwarding contact through `struck`. |
| [Hazard](../../scripts/Combat/Hazard.gd) | Overlap dispatch and horizontal directional entry-speed measurement. |
| [Fire](../../scripts/Combat/Fire.gd) | Flame hazard, guard ignition, player scorch, barrel fuse, fuel and tending. |
| [Barrel](../../scripts/Combat/Barrel.gd) | Carryable oil/powder explosive, fuse, blast attenuation, chain reactions, damage/push/effects. |
| [HangingWeight](../../scripts/Combat/HangingWeight.gd) | Cuttable rope, released rigid load, once-per-victim crushing. |
| [TrainingDummy](../../scripts/Combat/TrainingDummy.gd) | Practice receiver, optional shield, damage tally and hit/blocked signals. |

## Controls and phases

The shared action `throw` is attack (default left mouse). `block` falls back to right mouse, `kick` to F, and `dodge` to Q. Existing project bindings are retained. Combat rejects mouse-recapture/spent attack presses and resets while dead, paused, outside `LOCOMOTION`, or carrying. It can still track a drop attack while falling in locomotion.

| Phase | Behavior and transitions |
| --- | --- |
| `IDLE` | Can block, start a melee windup, draw a bow, kick, or dodge. |
| `WINDUP` | Reads recent look direction. Release proceeds to a quick strike at windup end; holding the initial press enters charging. A block press feints. |
| `CHARGING` | Charge reaches 0..1 over weapon charge time. Release starts a quick/power strike depending on full charge; block feints. |
| `STRIKE` | Sweeps blade rays and records each target once per swing. Contacts can cleave, deflect, block, parry, punish, or kill; transition to recovery. |
| `RECOVER` | Returns from the actual stopped/end frame. Buffered attacks can chain after outcome-specific windows. Block cancellation and kick/dodge entry remain constrained by recovery timing/outcome. |
| `DRAWING` | Bow draw and FOV zoom reach 0..1. Release with draw >= 0.15 and arrows fires; block lets down without firing. Returns to recovery (0.55 s after firing, 0.25 s otherwise). |
| `KICK` | Timed contact against reachable guard/body/object/door, then recovery. Cooldown/stamina apply. |
| `DODGE` | Timed horizontal shove; movement direction or backward default. Tracks direction/time for answers, then returns idle. |
| `STAGGER` | Guard break, kick, flinch, or deflection interruption disables immediate attack until its timer expires. |

A weapon selection change clears buffered input and cancels incompatible active attacks. The attack starts when clicked, but holding through its windup creates a charge. Sideways look selects left/right cuts; downward look selects overhead; upward look selects thrust. With little look motion, a fresh attack defaults left and a chained left attack returns right. Running adds lunge, damage, and poise; backing reduces force. STYLES multiplies weapon windup/strike/reach/damage/cost/poise and declares whether a cut travels through multiple targets. Costs can drain remaining stamina; regeneration waits longer after exhaustion. Full adrenaline enables a power finisher.

Defence first checks hazards, active answers, unblockable kicks/blasts, and low sweeps. A raised melee guard must face the attack. Fresh guard timing permits parry/perfect parry; held guard absorbs missiles completely and melee partially for stamina. Thrusts are more costly and partly penetrate an ordinary block. Insufficient stamina breaks guard. A fresh matching cut/thrust can counter; active blades can clash; a recent dodge toward a thrust can Mikiri. These paths mutate resources, inform the attacker, and emit effects as well as returning filtered damage.

## Player combat APIs

The following are caller-facing contracts; source declarations and `:=` defaults remain unchanged. References typed as Node/Resource rely on the named methods/properties, rather than a narrower declared class.

| API | Contract |
| --- | --- |
| `current_weapon() -> Resource` | Resolves inventory selection through `Weapon.find`; null for missing inventory, empty selection, or unknown weapon ID. |
| `aim() -> Transform3D` | World gameplay head aim with lean, excluding cosmetic camera motion. |
| `speed_scale() -> float` | Movement multiplier from guard/charge/draw/stagger/attack/recovery; 1 when unmodified. Running windup/strike avoid ordinary slowing. |
| `filter_incoming(amount: float, from: Node) -> float` | Remaining damage; 0 means defended. `from` may be null and may expose `attack_info() -> Dictionary`. Has stamina, adrenaline, phase, attacker callback, riposte, sound, visual, and time effects. The player subtracts returned damage separately. |
| `on_hurt(amount: float, from: Node) -> void` | Post-defence feedback; may interrupt windup/charge/draw with flinch. Null source allowed; does not subtract health. |
| `on_answered(how: StringName, _by: Node) -> void` | Enemy-reported answer reward, stamina/adrenaline/riposte update, `answered(how)`; `_by` unused. |
| `is_parrying() -> bool` | Whether raised guard still has its current parry window. |
| `add_look_motion(motion: Vector2) -> void` | Additional look radians: X yaw left positive, Y pitch up positive. |
| `threat_serial() -> int` | Serial of most recently started melee blow; consumers use it to distinguish repeated threats. |
| `threat_phase() -> StringName` | `windup`, `charging`, `strike`, or empty StringName for no active melee threat. |
| `time_to_contact() -> float` | Estimated game seconds to contact during windup/strike; -1 when unknown (including charge release timing). |
| `threat_reach() -> float`, `threat_direction() -> StringName` | Styled reach in metres (0 without weapon), and current direction left/right/overhead/thrust. |
| `whiffed() -> bool`, `is_riposte() -> bool`, `blow_poise() -> float`, `is_running_blow() -> bool` | Current combat state exposed to receivers and guard reactions; whiff requires miss recovery. |
| `block_cost_near() -> float` | Largest guard_damage among fighting guards within 5 m, at least cost_block. |
| `dodged_within(seconds: float) -> bool` | Recency of a successful dodge in game seconds. |
| `drop_target() -> Node3D` | Tracked guard below or null; used to reserve the attack press. |
| `on_landed(_fall_speed: float) -> void` | Resolves an armed drop attack; fall speed parameter is unused. |
| `kick_had_momentum() -> bool` | Whether current/last kick was initiated with running momentum. |
| `arrow_count() -> int` | Count of arrows, 0 if absent; requires valid `player.inventory`. Firing decrements the entry without removing its zero-count record. |
| `reset_for_practice() -> void` | Clears active action, targets, buffers/timers/cooldowns/combo/adrenaline; restores stamina for practice. |

## Attack and receiver schemas

Incoming defence metadata is a Dictionary from the source's `attack_info()`. Optional flags are converted with `bool`, and numeric costs with `float`; omitted keys use defaults in the consumer.

| Key | Value used by PlayerCombat |
| --- | --- |
| `hazard` | bool; damage bypasses guard/answer logic, used by fire. |
| `unblockable` | bool; invokes kick response and passes damage, used by blasts/boots. |
| `low` | bool; bypasses held guard/parry (intended to be jumped). |
| `ranged` | bool; excludes melee answers and treats facing/guard cost as a missile. |
| `from_direction` | world `Vector3` toward the incoming source; projectile implementations provide reverse heading. |
| `guard_damage` | numeric stamina cost; melee defaults to cost_block, ranged to 6. |
| `heavy`, `thrust`, `blunt` | bool; feedback, costly thrust block, and cut-versus-impact feedback. |
| `call` | `StringName`, normally cut/thrust/sweep; enables enemy melee answer logic. |
| `type` | `StringName` classification such as arrow, thrown, blast, fire. |

Arrow returns `{type: &"arrow", ranged: true, guard_damage: 6.0, from_direction: -heading}`. Thrown returns `{type: &"thrown", ranged: true, blunt: true, guard_damage: 7.0, from_direction: -heading}`. Barrel returns `{type: &"blast", unblockable: true}`; Fire returns `{type: &"fire", hazard: true}`.

Melee/projectiles use receiver methods when supported: `take_hit(damage: float, attacker: Node3D, kind: StringName, point: Vector3, direction: Vector3) -> StringName`, or player `take_damage(amount: float, from: Node)`. World points/directions accompany hits. Other duck-typed responses include `strike(kind, point, direction)`, `kick(push, attacker)`, `parried(player, posture_multiplier)`, `blocked_by(player)`, `ignite(seconds)`, `light(seconds)`, and ragdoll owner resolution. Results include hit/killed/blocked/parried/none in guard receivers; TrainingDummy returns only hit/blocked. These result strings influence damage reporting and recovery, so a new receiver should follow the existing receiver contract.

## Signals

| Signal declaration | Event |
| --- | --- |
| `swung(power: bool, direction: StringName)` | Strike starts, with selected power and swing direction. |
| `landed(target: Object, result: StringName, damage: float)` | Receiver result and dealt damage for strike/drop resolution. |
| `deflected(point: Vector3)` | Blade stopped at a world surface point. |
| `kicked(target: Object)` | Kick contacts a supported receiver. |
| `fired(arrow: Node3D)` | Spawned/launched arrow after ammunition consumption. |
| `finisher_started`, `feinted`, `riposte_started`, `perfect_parry` | Action/defence events without payload. |
| `defended(result: StringName)` | parry/block/broken/counter/clash/mikiri outcome. |
| `dodged(direction: Vector3)` | World horizontal dodge direction. |
| `drop_attacked(target: Node3D)` | Drop attack resolution, including supported target paths. |
| `staggered(why: StringName)` | Cause such as broken/kicked/flinch; the emitter determines the StringName. |
| `answered(how: StringName)` | Answer reward, including mikiri and enemy-reported dodge/jump. |
| `deathblow_landed(target: Node3D)`, `punished(target: Node3D)` | Open-posture deathblow or punished recovery. |
| `countered(from: Node)`, `clashed(from: Node)` | Incoming attacker met with counter or clash. |
| `contact(kind: StringName)` | Presentation contact flesh/steel/turned/punish/deathblow. |

## Weapon resources and poses

Weapon `id: StringName`, inferred String display name, and Kind MELEE/BOW identify the item. Melee tuning contains damage/power_damage, charge_time, reach, arc_degrees, windup/strike_time/recovery, can_block, backstab_kills, and sneak_multiplier. Bow tuning contains draw_time, min/max arrow speed/damage, and headshot_multiplier. Noise fields are swing_db/hit_db; `mesh: Mesh` can be null. Seconds, metres/m/s, degrees, and dB are explicit units; Resource values are trusted tuning rather than validated user input.

`find(weapon_id: StringName) -> Resource` lazily builds and shares sword/dagger/bow resources, or returns null for unknown IDs. `sword()/dagger()/bow() -> Resource` each build a new Resource. `model(file: StringName) -> Mesh` shares cached imported mesh or null on missing file/mesh; `forget_models()` clears imported/arrow caches but does not clear armoury. Mesh factories use procedural fallback where appropriate. Imported melee models place the grip at origin and blade along +Y; arrows point -Z, crossbow stock forward -Z. `guard_weapon_mesh(kind: StringName) -> Mesh` falls back to sword for unknown kind.

Mesh metadata consumed by hand presentation includes `hold_scale` numeric, `hold_rotation: Vector3` radians, `view_poses: StringName`, `blade_base/blade_tip: Vector3` mesh-local endpoints, `voice` pitch scale, and optional draw_sound/stow_sound names. Weapon `_assemble(parts: Array)` expects tuples `[PrimitiveMesh, Transform3D, Material]`, transforms vertices/normals, and preserves one surface/material per part.

ViewPoses `set_of(id: StringName) -> Dictionary` returns shared SWORD/DAGGER/BLACKJACK/BOW tables or generic ITEM. Static poses are Array `[grip: Vector3, blade: Vector3, edge: Vector3]` in full-size camera metres. `frame(pose: Array) -> Transform3D` orthogonalizes blade/edge; `bow_frame(pose: Array)` uses `[grip, up, shooting_direction]`. Malformed arrays/parallel direction data are not validated.

A table's `sweeps` maps direction StringNames to Dictionary `{pivot: Vector3, path: Array[Vector3], lead: Array[number], rise: Array[number], charged?: Array}`. Lead/rise each have start/middle/end values; lead is degrees, rise a direction offset. Optional charged is `[drawn_grip: Vector3, lead_degrees: number, rise: number]`. `sweep_frame(spec: Dictionary, u: float, charged := 0.0) -> Transform3D` clamps u to 0..1, uses a smooth curve along path, and blends the starting pose for charge. `blend(a: Transform3D, b: Transform3D, t: float)` and `arc(a, b, c, t)` return interpolated transforms; callers supply normalized t.

## Projectiles and environmental APIs

| Source/API | Contract and effects |
| --- | --- |
| `Arrow.launch(from: Vector3, launch_velocity: Vector3, hit_damage: float, by: Node3D, head_multiplier: float) -> void` | Configure a fresh arrow already in the scene with world start/velocity/damage/shooter; resets interpolation. Fresh instances start unstuck. |
| `Arrow.struck(target: Object, damage: float, headshot: bool)` | Receiver/world contact; world sticking reports zero damage and false. Invalid collider may be null. |
| `Arrow.frob(player: Node) -> void` | Stuck, untaken arrow adds one arrows belt item and queues deletion. Flight returns empty prompt. Unstuck flight expires after lifetime; stuck arrows stop lifetime advancement. Moving body/door hits reparent while keeping world transform; player stray arrows join stray_arrows evidence group. |
| `Thrown.launch(item: RigidBody3D, by: Node3D, velocity: Vector3, hit_damage: float) -> Node3D` | Attaches rider, sets linear/random angular velocity, returns rider. Throws exclude owner; guard damage is 80% of base, player damage full base, heavy body may shove. Rider tracks once-per-target hits, bounces, emits impact noise, and self-frees after age/speed limits; body remains. |
| `ThrownTool.launch(from: Vector3, aim: Vector3, mesh: Mesh, by: Node3D) -> void` | Set kind flashbomb/waterflask first; aim normalized to 15 m/s plus 2.4 m/s upward. mesh may be null. Projectile raycasts along each tick and bursts once on hit or 3 s fuse. |
| `ThrownTool.flash(context: Node, at: Vector3, by: Node3D) -> void` | Effects/noise first, then line-of-sight guard/thrower dazzle within 11 m (nearby <=2 m partially blinds regardless of facing). Null thrower skips own-HUD dazzle. Missing physics world stops visibility effects. |
| `ThrownTool.splash(context: Node, at: Vector3, normal: Vector3, by: Node3D, struck: Object = null) -> void` | Glass/water sound and dousing within 1.4 m of flame, subject to terrain occlusion. Direct flame hit can override range/occlusion; no world permits distance-based dousing. |
| `Strikeable.strike(kind: StringName, point: Vector3, _direction := Vector3.ZERO) -> void` | Forwards `struck(kind: StringName, point: Vector3)` synchronously; direction unused. |
| `Hazard.into_speed(velocity: Vector3) -> float` | Horizontal speed toward -local/+world-facing normal; may be negative when leaving. Nondirectional hazards return horizontal magnitude, never vertical speed. Area polls overlaps and calls hazard_hit(self, lethal_speed) or ragdoll_hazard. Victim owns lethal/damage decision. |
| `Fire.brazier(parent: Node, position: Vector3) -> Area3D` | Attaches standing bowl/light/flame and returns flame area; position is bowl foot. Groups hazards/fires. |
| `Fire.feed(amount := 0.6) -> void`, `low() -> bool`, `burning() -> StringName`, `strength() -> float` | Adds fuel capped above at 1, restarts flare and emits fed. Negative amount is not rejected. State string low/burning; strength can exceed 1 while flaring. fuel_seconds=0 does not burn down. Scorch throttle is shared by all overlapping damage receivers. |
| `Barrel.strike(kind: StringName, _point: Vector3, _direction := Vector3.ZERO) -> void`, `light(seconds := -1.0) -> void` | Power/arrow/blast/fire starts fuse once; negative seconds chooses exported fuse. Other strikes do not light it. Groups explosives. |
| `Barrel.explode() -> void` | Once only: radius falloff, wall attenuation to 35% for nonstatic targets, damage/push, nearby barrel fuse chains, physics impulses, effects/noise, `exploded(at: Vector3)`, then deletion. Guard damage uses null attacker; player damage uses the barrel's unblockable attack metadata. |
| `HangingWeight.release(at := Vector3.ZERO) -> void` | Cut once, free rope, unfreeze load, exclude player body collision, emit released. Zero point chooses rope sound location. Falling volume crushes each victim once, emitting `crushed(victim: Node3D)`. Origin is beam; drop metres to load top. |
| `TrainingDummy.take_hit(damage: float, attacker: Node3D, kind: StringName, point: Vector3, direction: Vector3) -> StringName` | Frontal guarded quick/thrown returns blocked with 0 reported damage; otherwise tally adds damage and returns hit. Null attacker bypasses facing block; power breaks shield. `struck(result: StringName, kind: StringName, damage: float)` and guard_broken report practice events. |
| `TrainingDummy.kick(push: Vector3, _attacker: Node3D) -> void`, `is_unaware() -> bool`, `is_behind(attacker: Node3D) -> bool` | Kick rocks/breaks guard and reports zero-damage hit; unaware always true; behind requires a valid positioned attacker. Dummy remains alive. |

Projectile callbacks, blast loops, and carried throws use method checks but still assume receiver-specific fields where required. Arrow/tool travel uses continuous segment rays rather than ordinary moving-body collision. Collision masks use world=1, guards=2, loose bodies=4; torch flame reach areas have their own layer/mask handling. These are physics values, distinct from visual render layers.
