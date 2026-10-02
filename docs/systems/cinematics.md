# Cinematic cameras and scripted showcases

The cinematic pipeline receives subjects and world events, chooses valid shots, and operates a camera. Showcase stories supply acts/beats and intruder cues around live guard AI; Cinema itself has no map-specific plot logic. [TimeFx](../../scripts/Visual/TimeFx.gd) provides shared slow-motion requests and real-time camera clocks; see [rendering.md](rendering.md) for pose/layer contracts and [world.md](world.md) for vantage markers.

## Camera lifecycle

[CineEditor](../../scripts/Cinema/CineEditor.gd) owns [CineOperator](../../scripts/Cinema/CineOperator.gd) and [CineScreen](../../scripts/Cinema/CineScreen.gd) children. Add the editor to the scene tree, `take_over(camera: Camera3D)`, then call `scene(intent: Dictionary)` as interest changes. Taking over subscribes to CineEvents and saves the camera's original FOV/attributes in the operator. `release()` unsubscribes, cancels cinematic slow motion, restores lens/attributes, clears/frees operator/screen, and empties current shot state. Editor tree exit also unsubscribes.

`hold(held: bool)` temporarily gives the camera to free/follow control while keeping scene intent and event subscription. It disables editor processing, cancels cinematic slow motion, clears transitions, and restores the operator's saved lens. Resuming drops pending event/reaction/talk/axial state and takes a fresh shot. Camera interpolation is disabled when attached so real-time operator transforms are drawn directly. Restoring lens/attributes does not imply restoring every camera property changed during attachment.

[CineShot](../../scripts/Cinema/CineShot.gd) calculates framing, while [CineVantage](../../scripts/Cinema/CineVantage.gd) validates physics placement. The editor selects shots respecting jump-cut angle/size, minimum age, subject visibility, foreground actors, camera crowding, motion, conversations, and pinned intent. The operator uses translation springs, bounded turn acceleration, aim dead zone/edge urgency, lens/focus easing, handheld sway, and shake. An actor-only fx_light eye lamp lifts close faces without affecting detection/lightgem readings.

Observe mode plans 15–45 s takes, often on a long lens or slow path, and favors movement/dissolve continuity. Drama plans 3–8 s shots, cuts on events, holds one side of the actor line, and uses close portraits/reactions/axial steps, wipe/letterbox/shake/slow motion. Authored constants in source remain authoritative. Overhead rescue requires open sky; frames blocked by nearby stone or a body need a new candidate rather than a fast camera whip.

## Intent, framing, and shot records

| Record | Types / meaning |
| --- | --- |
| Editor scene intent | mode StringName/String observe or drama (default observe); subjects Array of Node3D or zero-argument Callable returning subjects; pin optional Dictionary; letterbox optional bool; place optional world Vector3; transition optional StringName fade. Subjects are re-resolved periodically (1 s). |
| Pin | kind StringName, subjects Array/Callable, seconds numeric duration. Requests a held opening shot; director advances afterward. Physics/camera validity can still require safe framing. |
| Framing context | aspect float width/height (default 16/9), side world Vector3 on camera side of actor line (ZERO unrestricted), from world Vector3 vantage, place world Vector3 when empty, target Node3D for insert, toward world Vector3 for portrait partner, turn degrees, step int axial 0–2; from can reuse the position of an editor setup while recomposing its aim. |
| CineShot.frame result | kind/size StringName; position/look/subject Vector3; fov float vertical degrees; focus float metres; near_blur bool. Framing itself does not test physics. |
| Operator path extension | path PackedVector3Array of world points, at least two; operator follows its Catmull–Rom interpolation and mode speed. Invalid/short path requests degrade to cuts in editor handling. |
| Editor current/history shot | kind, size, subjects Array, cause, how, enter, at editor clock seconds, mode, real_at TimeFx seconds, framing Dictionary, context Dictionary, planned duration, offset Vector3 between framing look and subject. `current()`/`history()` return live collections. |
| Vantage marker | Marker3D in cine_vantage; optional lens metadata long/medium restricts matching. LevelLoader creates these from vantage markers. |

Supported frame kinds are establishing, observe, roving, group, medium, close, over_shoulder, two, reaction, portrait, insert, track, axial, and overhead. Single-subject kinds frame `men[0]`; over_shoulder uses listener `men[1]`; two frames both. Insert uses context.target or the first subject. Unknown kinds fall back to medium. Head positions account for activity (lying/kneeling/standing), body size, and drawn/interpolated transforms; a null head query returns ZERO. Caller must supply suitable live Node3D subjects and a valid physics space where required.

| API | Inputs | Output / side effects / failure |
| --- | --- | --- |
| `CineEditor.scene(intent: Dictionary) -> void` | Intent schema above. | Stores a shallow intent copy, resolves subjects, updates mode/screen intent, resets event/talk state. First shot occurs immediately or after minimum current shot age; held editors defer until resume. |
| `cut_to(kind: StringName, men: Array, context={}) -> void` | Desired kind, subject Array, dynamic Dictionary context. | Filters invalid subjects and selects a safe shot; empty subjects/no camera does nothing. Single-subject requests also offer medium fallback. |
| `shot_started(shot: Dictionary)` | Live shot record. | Emitted synchronously after operator request/history append; observers should not mutate it. |
| `current() -> Dictionary`, `history() -> Array`, `screen() -> CanvasLayer` | None. | Live inspection state; current initially {}, screen may be null before attachment/after release. |
| `cine_event(kind: StringName, data: Dictionary) -> void` | CineEvents payload. | Ignores unattached/unrelated events; updates interest/pending cuts/talk. Held state suppresses shake/slow motion actions. |
| `CineShot.frame(kind: StringName, men: Array, context: Dictionary) -> Dictionary` | Kind/actors/context. | Pure framing dictionary; not a collision-valid camera transform by itself. |
| `CineShot.head_of(man: Node3D) -> Vector3`, `drawn_at(node: Node3D) -> Vector3` | Compatible actor/node. | World head position / rendered interpolated position; missing head actor -> ZERO. |
| `CineVantage.best(tree: SceneTree, men: Array, lens: StringName, side: Vector3, space: PhysicsDirectSpaceState3D) -> Vector3` | Lens long/medium/near, subjects, side constraint, world physics. | Best marked/sampled clear viewpoint; INF if no subjects/space/candidate. Does not add nodes. |
| `sees(space, at: Vector3, men: Array, bodies=true) -> bool` | Typed physics space, world origin, subjects. | All heads clear of world and optional bodies; excludes subjects' own RIDs. Freed/null actors skipped. |
| `clear(space, at: Vector3) -> bool`, `fill(space, at, look, fov, aspect, exclude) -> float`, `open(...) -> bool` | Physics and framing. | Clearance/frame stone occupancy/opening checks; collision queries, not scene mutation. |
| `CineOperator.attach(camera: Camera3D, screen: CanvasLayer) -> void` | Live camera and transition helper. | Saves lens/attributes, installs practical DOF, disables interpolation. `stand_down()` restores lens/attributes and clears shake/waiting fade. |
| `show(framing: Dictionary, how: StringName) -> void` | Framing and cut/glide/path/wipe/dissolve/fade. | Updates camera or scheduled goals; blocked glide cuts. Without camera no-op. Captured-frame transitions degrade in headless use; fade can be explicitly enabled for headless tests. |
| `follow(framing: Dictionary) -> void`, `shake(amount: float) -> void` | Updated framing / trauma addition. | Changes goals/lens without a new editor cut / raises shake envelope. |
| `fov()`, `focus_distance()`, `look_point()`, `waiting()`, `moving()`, `eye_light()` | No arguments. | Lens/focus/aim, pending fade/path status, and actor-only light inspection. |
| `CineScreen.letterbox(on: bool) -> void` | Desired bars. | Eases bars to 2.39:1 at 1.5 real seconds. bar_height()/subtitle_band() expose current pixel geometry. |
| `wipe(texture: Texture2D)`, `dissolve(texture: Texture2D)`, `fade_through(hold: float) -> void` | Captured previous image / black hold real seconds. | Runs .6 s wipe, 1.2 s dissolve, or .5 s down/up fade. Screen state can be inspected through alpha/edge/black methods. |
| `CineScreen.clear() -> void` | None. | Stops wipe/dissolve/fade and releases snapshots; **does not clear letterbox state**. |

### Event dispatch schema

[CineEvents](../../scripts/Cinema/CineEvents.gd) uses a static Array of Objects. `add_listener(listener: Object)` is duplicate-safe; listener **must** implement `cine_event(kind: StringName, data: Dictionary)` (emit does not check has_method). `remove_listener(listener)` unregisters; `clear()` drops all listeners. `emit(kind, data)` dispatches synchronously over a snapshot, pruning freed Objects. Payload is the same Dictionary for each listener. There is no global autoload and no automatic removal of a valid inactive listener.

All documented events carry `where: Vector3` in world space. Payload actor values are dynamic Node references and can later be freed; consumers validate before use.

| kind | Additional payload fields / producers |
| --- | --- |
| line | speaker Node3D, listeners Array, seconds float, delivery String whisper/murmur/shout/empty, text String; Guard speech/talk. |
| alert | man Node3D, from/to integer Guard.Alert values. |
| spotted | man Node3D, target Node3D; sight begins combat pursuit. |
| blow | attacker/victim Node3D, weight light/heavy, outcome landed/blocked/parried/killed; combat settlement. |
| death | man Node3D, killer Node reference; death/knockout presentation. |
| knife | attacker/victim Node3D; backstab cue. |
| gathering | kind StringName, men Array, state started/ended; group activity. |

## Showcase orchestration

[ShowDirector](../../scripts/Showcase/ShowDirector.gd) is a Node with PROCESS_MODE_ALWAYS so it can receive pause controls. `setup(p_map: Node3D, p_story: RefCounted)` binds dynamic story protocol: `acts() -> Array` and map-specific references resolved by the story. `run() -> void` is asynchronous, starts at clamped 1-based start_act, emits act/beat cues, and ignores a null story or already-running invocation. Leaving the tree aborts execution.

| Story record | Input contract and evaluation |
| --- | --- |
| Act | title String or zero-argument Callable; enter Callable called every act start; stage Callable called only when starting directly at a later act; beats Array or Callable resolving an Array. |
| Beat | name StringName/String; do optional Callable; until optional predicate Callable; min seconds default 0; enough seconds default INF; timeout seconds default 30; scene Dictionary emitted to the camera. |
| Completion | Each physics frame adds Engine.time_scale/physics_ticks_per_second unless paused. At min, complete if no valid until, predicate true, or enough reached. Timeout independently logs/emit beat_skipped and advances. Manual next_beat returns without timeout logging. |
| Reload state | start_act and ending are static, retained across scene reload. jump_to() clears squad/garrison memory, TimeFx requests/base, and LightProbe cache before invoking reload Callable. |

Signals are `act_started(index:int,title:String)`, `beat_started(beat_name:StringName,scene:Dictionary)`, `beat_skipped(beat_name:StringName)`, `show_ended`, `ending_chosen(ending:StringName)`, `speed_changed(scale:float)`, and `paused_changed(paused:bool)`. Maps connect these to camera/overlay/weather. Completion optionally quits after 3 real seconds (`quit_at_end`). Director exit restores normal time when it still owns the selected base speed.

Controls: 1–6 jump to act, N next beat, V cycle random/overwhelmed/victor/escape ending, R restart, Space pause, brackets cycle .25/.5/1 speed. User arguments after `--` accept `--act=N`, `--ending=...`, `--auto`, `--quit-at-end`; act bounds are clamped and unknown ending names ignored. `chosen_ending() -> StringName` settles random once per run. `set_speed(index:int)` clamps index and uses TimeFx.set_base; `toggle_pause()` mutates tree pause.

[ShowNight](../../scripts/Showcase/ShowNight.gd) supplies the five-act yard showcase. [GarrisonNight](../../scripts/Showcase/GarrisonNight.gd) inherits it with six acts and named map marks/search groups. Stories can stage guard/search state and weather as well as intruder movement; predicates depend on actual AI results, so timeout handling is part of the contract. Story `subjects(scene: Dictionary) -> Array` resolves actor names and dynamic groups; GarrisonNight additionally supports `@group:<hunt area>`. Weather act/beat dictionaries provide transition cues; `weather_act(index)`/`weather_beat(beat)` apply them through the map Night. `ending_done()`/`ending_outcome()` and kill counters expose result state.

[ShowCamera](../../scripts/Showcase/ShowCamera.gd) creates an editor in `_ready()` and has FREE/FOLLOW/DIRECTOR modes. `setup(map,story)` should happen before ready, permitting optional map.camera_home() and map.cast/roles to be used. `want(intent)` converts story names to live subjects/Callables and forwards scene intent; `fade_next()` applies fade to the next request. FREE uses WASD, Q/E height, Shift speed, right mouse look, and wheel speed; FOLLOW orbits a clicked/Tab actor with wheel range; C restores director. `following(man:Node3D)` drives name cards. Invalid follow targets are ignored; subject disappearance is handled by camera mode/last-seen logic.

[ShowOverlay](../../scripts/Showcase/ShowOverlay.gd) setup watches map.cast actors and map.roles. `watch(man:Node3D, role:String)` connects barked/alert_changed once per supplied actor; no duplicate connection guard. It shows up to three nearby in-view subtitles, actor alert/mercy glyphs, title/name cards, and toast messages. Letterbox uses the screen's subtitle band; H toggles visibility. `shown_subtitles()/shown_marks() -> Array`, `label_rects() -> Dictionary` expose presentation. Fades/camera use real time; beat timing remains game time.

## Intruder contract

[Intruder](../../scripts/Showcase/Intruder.gd) extends Guard in puppet mode with PlayerCombat-compatible fields. Intruder.tscn supplies its inherited appearance/equipment settings; writing those only in `_init()` would be overwritten by scene values. It is the showcase's player-group surrogate. `get_light_level()/get_exposure() -> float` read normalized lighting plus crouch/motion/exposure_scale; `get_sight_points() -> Array` returns world head/chest/shins and `get_aim_point() -> Vector3` chest. `armoured` floors health at .4 max until `fall() -> void`; damage and bleeding remain real above the floor.

Intruder `_physics_process(delta)` ticks combat, then runs inherited Guard processing and armour enforcement. Puppet driving first calls brain.react(delta); combat.move(delta) can consume movement, otherwise brain.drive(delta) uses navigation. [IntruderBrain](../../scripts/Showcase/IntruderBrain.gd) exposes `go_to(point:Vector3,gait:StringName)`, `hide_at(point)`, `backstab(victim:Node3D)`, `fight(tactic:StringName,target:Node3D=null)`, `flee_by(route:Array[Vector3])`, `face(point)`, `stand()`, `done() -> bool`, `activity() -> StringName`. Gaits sneak/walk/run use authored speeds; tactics trade/turtle/parry/focus/press/spare expose squad behaviors. Never deliberately cuts a kneeling mercy target. Navigation retries and stuck/barge behavior keep scripted travel progressing without replacing guard decision logic.

[IntruderCombat](../../scripts/Showcase/IntruderCombat.gd) exposes `swing(direction:StringName,at:Node3D=null) -> bool`, `backstab(victim) -> bool`, `guard_up(on:bool)`, `dodge(from:Vector3) -> bool`, and `filter_incoming(amount:float,from:Node) -> float`. Swing rejects outside idle/recover or when staggered/knocked, and unknown directions fall back to left. Strike contact later calls guard.take_hit, so posture/parry/bleed/sever paths remain active. Incoming defence returns remaining damage and updates riposte state. Threat readers (`threat_serial/phase/reach/direction`, `time_to_contact`, `is_riposte/is_parrying`, `dodged_within`, `blow_poise`) let guards read it like a player's combat.

Its signals are `defended(result:StringName)`, `dodged(direction:Vector3)`, `landed(target:Node3D,result:StringName)`, and `felled(target:Node3D,riposte:bool)`. Brain listens to defended; story counters observe hit/kill outcomes. Attack dictionaries/styles and mirrored `_attack/_phase/_phase_timer/_phase_length` fields are an internal GuardRig compatibility bridge, so changing names requires coordinated actor/rig updates.

## Complete script inventory

| File | Role |
| --- | --- |
| [CineEditor](../../scripts/Cinema/CineEditor.gd) | Intent/events -> candidate selection, continuity/visibility guards, shot history/signal, operator/screen lifecycle. |
| [CineEvents](../../scripts/Cinema/CineEvents.gd) | Static synchronous event listener registry and shared payload protocol. |
| [CineOperator](../../scripts/Cinema/CineOperator.gd) | Camera springs/paths/aim/lens/DOF/shake, eye light, transitions, saved attributes. |
| [CineScreen](../../scripts/Cinema/CineScreen.gd) | Letterbox and captured-frame wipe/dissolve/black fade, subtitle band; embedded canvas wipe shader clips by edge. |
| [CineShot](../../scripts/Cinema/CineShot.gd) | Pure frame geometry from actor pose/size/activity and context. |
| [CineVantage](../../scripts/Cinema/CineVantage.gd) | Marked/sampled viewpoint scoring, physics head visibility, clearance and frame-fill rejection. |
| [GarrisonNight](../../scripts/Showcase/GarrisonNight.gd) | Garrison six-act ShowNight subclass, divided hunt and marked interior/outdoor staging. |
| [Intruder](../../scripts/Showcase/Intruder.gd) | Puppet Guard, player-facing visibility/damage interface, plot-armour release. |
| [IntruderBrain](../../scripts/Showcase/IntruderBrain.gd) | Director verbs, travel/stuck recovery, tactic reactions and defence selection. |
| [IntruderCombat](../../scripts/Showcase/IntruderCombat.gd) | Combat clock/contacts/defence and GuardRig/PlayerCombat compatibility. |
| [ShowCamera](../../scripts/Showcase/ShowCamera.gd) | Free/follow/director controls and story name -> editor subject translation. |
| [ShowDirector](../../scripts/Showcase/ShowDirector.gd) | Async act/beat runner, timeout/reload/pause/speed/ending control. |
| [ShowNight](../../scripts/Showcase/ShowNight.gd) | Yard story acts, predicates, subjects, endings, kill/beat/weather state. |
| [ShowOverlay](../../scripts/Showcase/ShowOverlay.gd) | Speech/alert marks, name/title/toast controls and layout inspection. |

## Failure and integration boundaries

Physics placement matters even if a head ray is clear: rays starting inside a wall can see outward, and stone adjacent to the lens can dominate the frame. Vantage rejects occupied clearances and frame fill before scoring distant lenses. Missing subjects trigger filtering/re-resolution/rescue shots; pure framing alone is not safe camera placement. Director story Callables and map.cast/marks/roles are trusted protocols rather than validated arbitrary dictionaries.

Editor slow motion has cooldowns and a named TimeFx request; free camera control/hold/release cancels that request. Operators restore original camera lens/attributes when giving control back, and borrowed capture textures are cleared on transition completion/release. Consumers of current/history/signals must avoid mutating shared shot dictionaries. Headless transition fallbacks support geometry/timing inspection, but they do not verify rendered image fidelity.
