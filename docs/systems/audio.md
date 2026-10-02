# Recorded sound, ambience, and adaptive score

[Sfx](../../scripts/Audio/Sfx.gd) owns recorded sound playback. Interaction/combat/movement callers request names and positions; gameplay hearing is published separately through SoundBus. Ambience, Music, and NightSound play for the listener without generating guard stimuli. Burner and blowhole gameplay noise is emitted by their own system code, not by Sfx playback.

## Files, buses, and lifecycle

| Files / metadata | Contract |
| --- | --- |
| `audio/sfx/<name>.wav` or `<name>_1.wav`, `<name>_2.wav`, … | Named effect takes, prepared/levelled by tools/prepare_sfx.py. A missing name is silent; numbered files are loaded as variations. See CREDITS.md for source licences. |
| `audio/ambience/<name>.ogg` | Level loop chosen by current scene root ambience metadata. Default interior_night; empty disables it. Examples include cave and forest_night, with rain variants where present. |
| root acoustics metadata | stone (default), cave, wood, outdoors; unknown values fall back to stone. Determines material damping/reverb character, while geometry probes determine room size/enclosure. |
| `audio/music/<layer>.ogg` | music_drone, music_pulse, music_drums, music_severe; all available loops start synchronized at the fight's start and change gain independently. |
| `audio/weather/*.wav` | NightSound rain_calm/rain_strong/wind/drip loops, plus thunder variations; missing streams are skipped. |
| `audio/ambience` burner loops | LightFixture recipe loop/chimney names search WAV then OGG; empty/missing resolves to silence. Torch distance/occlusion controls local playback. |

`Sfx.warm(context)` lazily creates a scene-owned Sfx node, configures buses/acoustics, starts background bank loading through WorkerThreadPool, and starts Ambience/Music. Ready scenes attach immediately; setup may defer child insertion. The bank is static and mutex-protected; takes can be loaded synchronously on demand before warm-up finishes. Exit requests loader stop and joins the task before releasing playback resources. Cache release hooks handle final engine shutdown.

Sfx uses bounded positional/flat player pools rather than one new Node per effect. Cursor selection reuses an idle player or replaces a pool slot. Variations avoid the last chosen take when possible; ordinary effects vary pitch and gain slightly. Musical stings preserve authored tune/level while still consuming their random pitch draw, preserving RNG sequence behavior. Recording mode logs requests even with disabled playback.

World positional sound routes to World or WorldFar by distance. Body sounds use a close, comparatively dry Body bus; musical and ambience playback use their own buses. Bus effects include a master limiter, room reverb/filters, far damping, injury low-pass, and sidechain ducking under World. Missing named buses in helper playback fall back to Master. Sfx creates/configures its bus chain as needed.

## Core API contracts

Defaults using `:=` have inferred GDScript types; bare parameters without an annotation or inference remain dynamic. The reference preserves the exact declarations. World positions/lengths are metres, gains dB, pitches multipliers, and real-time deadlines seconds.

| API | Inputs | Result, side effects, and failure |
| --- | --- | --- |
| `play(context: Node, sound: StringName, at: Vector3, volume := 0.0, pitch := 1.0, jitter := 0.04) -> void` | Live scene context, named take, world position, additional dB/pitch jitter. | Records request if enabled, then plays via scene pool with GAIN and random variation. Detached context, disabled audio, missing take -> no playback. Does not emit SoundBus. |
| `play_flat(context: Node, sound: StringName, volume := 0.0, pitch := 1.0, jitter := 0.03) -> void` | Non-positional name and scalar controls. | Same bank/pool; musical names update sting_at and suppress random gain/pitch change. Body sounds avoid world occlusion. |
| `warm(context: Node) -> void` | In-tree context. | Creates playback helper, starts background loading and ambience/score/acoustics; duplicate loading task is avoided. |
| `takes(sound: StringName) -> Array` | Name. | Cached AudioStream takes, synchronously loads absent bank entry, returns [] if no recordings. Treat returned bank collection as read-only. |
| `stream(sound: StringName) -> AudioStream` | Name. | Selects a variation, avoids immediate repeat, or null for missing recordings. |
| `step(surface: String, running := false, what := "step", mail := false) -> StringName` | Surface, gait, action step/jump/land, chainmail flag. | Pure recording-name mapping. Grass/gravel -> dirt; unknown -> stone. Metal/carpet only have plain steps; other actions/mail use stone. |
| `loudness(noise_db: float) -> float` | SoundBus-style gameplay level. | Extra playback dB = clamp((noise_db-50)*.45, -14, 6). Does not publish the noise. |
| `occlusion_at(context: Node, at: Vector3) -> float` | Live listener context and source point. | Continuous wall/corner occlusion measure from manager queries, or fallback when playback context unavailable. Callers can use this for local-loop gain/filtering. |
| `probe_room(space: PhysicsDirectSpaceState3D, origin: Vector3, exclude: Array[RID]) -> Vector2` | Valid physics space and world origin. | Twelve layer-1 rays return normalized room size/enclosure. No hits -> (1,0), representing open space. No resource/tree mutations. |
| `shape_room(shape: Vector2) -> void` | Size/enclosure each [0,1]. | Sets bus reverb/damping using current acoustic material; helper eases probe values during updates. |
| `set_acoustics(kind: String) -> void` | ACOUSTICS key. | Updates static room material, applies baseline shape; unknown -> stone. |
| `bus_for_distance(distance: float) -> StringName` | World source/listener distance. | WorldFar above FAR, otherwise World. |
| `world_cutoff_for(health: float, ringing: float) -> float` | Normalized health/ringing. | Low-pass cutoff frequency for world hearing; applies injury dulling. |
| `body_hit(amount: float) -> void` | Impact strength. | Raises global ringing envelope used by injury/hearing feedback. |
| `health_of(you: Node, dead_is_whole := true) -> float` | Compatible actor health/max_health. | Clamped fraction; null/missing fields/puppet -> 1; dead -> 1 when flag true. Denominator at least 1. |
| `silence() -> void` | None. | Stops pooled Sfx and hushes scene Music/Ambience, preserving bank; absent manager no-op. |
| `player_count() -> int` | None. | Active pool playback count (inspection); absent manager -> 0. |
| `Ambience.begin(context: Node) -> void` | Live scene context and metadata. | Adds one helper; empty/missing loop or detached context ignored. Configures OGG to loop. |
| `Ambience.dip_for(intensity: float) -> float` | Score intensity. | Smooth attenuation to FIGHT_DIP=-9 dB by intensity .6. |
| `Music.begin(context: Node) -> void` | Live scene context. | Adds one Music node; detached/duplicate ignored. Sfx.warm gates normal startup by audio availability. |
| `Music.intensity_of(hunting: int, fighting: int, close: int, health: float, hurt: bool, pressing: bool, plan: bool) -> float` | Guard counts and player pressure factors. | Pure score target [0,1]; no threat -> 0, hunting -> .12, fighting starts at .34 plus capped counts/health/pressure. |
| `Music.beat_now() -> int` | None. | music_pulse playback beat 0..3 at 130 BPM; absent/stopped/below -45 dB -> -1. Sfx heartbeat uses it. |
| `Music.hush()` / `Ambience.hush() -> void` | None. | Stops loops/releases stream references; also called on tree exit. |
| `NightSound.set_weather(rain: float, wind_speed: float, wetness: float, indoors: bool) -> void` | Fractions, world wind m/s, listener shelter. | Sets target loop dB, eased at 18 dB/s; indoors subtracts 8 dB from rain. Missing loops stay absent. |
| `NightSound.thunder(delay: float) -> void` | Seconds since flash; Night schedules first. | Plays a loaded random thunder now; longest travel is quieter. Missing takes -> no-op. |

## Mixing state and clocks

Sfx.enabled defaults false under the headless display driver. `volume_db` is global playback gain. `recording: bool` activates `recorded: Array`, whose entries are `[name:StringName, requested_volume:float, positional:bool]`; these are pre-GAIN/pre-jitter requests, not measured output levels. `sting_at` is the latest musical request in TimeFx real time, even if there was no stream to play.

`GAIN` is an authored name -> dB table derived from target loudness minus measured recording loudness; its values should not be confused with SoundBus loudness. A caller supplies `Sfx.loudness(gameplay_db)` when it wants perceptual volume to track the noise guards hear. Distances near the listener are clamped outward by NEAR to prevent excessive arm's-length attenuation gain; far sources receive wetter/duller routing. Occlusion uses world rays plus indirect corner paths, so a straight-line wall is not always complete silence.

Music's `LAYERS` rows are `[name:StringName, starts_at:float, fully_at:float, authored_db:float]`. Intensity rises quickly and falls slowly; silence follows the end of a fight. Severe escalation stings have cooldowns and avoid overlapping HUD suspicion/combat stings through Sfx.sting_at. Ambience fades in over 2.5 real seconds and recedes under score intensity. Music injury pulse gain yields to the listener's heartbeat, rather than playing two equally loud pulses.

Sfx/Ambience/Music envelopes read TimeFx.real_time/real_since, avoiding delta/time_scale spikes when hitstop changes midframe. TimeFx lowers overall AudioServer playback speed for non-hitstop requests, partially following cinematic slow motion. Weather sound volume envelopes use scaled frame delta; scheduled thunder is also weather/game time. Real-time clocks do not override a node's pause process mode.

## Inventory and integration constraints

| Script | Owner / read inputs / output |
| --- | --- |
| [Sfx](../../scripts/Audio/Sfx.gd) | Scene helper requested by PlayerController, guards, combat, interactions, HUD, burners, and maps. Reads recordings/listener/physics/player injury; outputs pooled audio/bus effects. |
| [Ambience](../../scripts/Audio/Ambience.gd) | Started by Sfx.warm; reads scene ambience and Music intensity; outputs one listener loop. |
| [Music](../../scripts/Audio/Music.gd) | Started by Sfx.warm; reads guard/player/squad pressure and Sfx sting timing; outputs synchronized adaptive loops. |
| [NightSound](../../scripts/Night/NightSound.gd) | Night child; reads eased weather/shelter and scheduled thunder; outputs weather loops/effects only. |

These scripts declare no public signals; callers query state or request playback. Weather timing/signals belong to Night, and gameplay noise delivery belongs to SoundBus. NightSound uses its own seeded variation RNG; Sfx ordinary playback uses global random draws. A caller requiring deterministic gameplay must account for these existing sound draws rather than assuming playback is RNG-free.

Missing recordings are intentional no-ops, so a successful call does not prove a sound was audible. Texture/photo/asset fallback does not substitute synthesized audio. `_node_for()` requires an in-tree scene context and sound enabled; pure bank/name/mix utilities can run without speakers. Pool counts, recorded requests, and bus/filter values allow tests to inspect the contract without requiring audible output.
