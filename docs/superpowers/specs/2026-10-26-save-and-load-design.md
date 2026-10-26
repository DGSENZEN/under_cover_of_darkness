# Save and load: the design

Settled with the user on 2026-10-26. This is sub-project 1 of the progression program. The order the user agreed:

1. Save and load
2. Quests, journal and world state
3. Dialogue outcomes
4. Archetype skill trees, with rewards and power-ups

Lines marked *(Claude's call)* are Claude's proposals. The rest is the user's.

## Intent

Today the game cannot be saved: Continue on the main menu says there is no save, and death reloads the scene from scratch. Every later piece of the program (quests, consequences, dialogue outcomes, skills) is state the world has to keep. So saving comes first, and every later system writes into it.

**Saving is free:** the player saves anywhere, as often as they like. **Loading is exact:** the world comes back as it was at the moment of saving. A fight saved mid-swing resumes mid-swing. The guard is still alerted and chasing, the Ward is still up, the shard is still in the air, the body is where it fell, and the music is still in its fight layer.

## Goals

- **Save anywhere.** Quicksave and quickload, autosaves, and named saves from the pause menu.
- **Exact restore** of everything that can change in play, built in two stages:
  - **Stage 1, outcomes and memory.** This is where Continue starts working.
  - **Stage 2, the live layer.** This is where fights resume mid-action.
- **Saves grouped by playthrough (a "run").** A run starts when the archetype is confirmed after New Game. **Continue loads the newest save of the run played last.**
- **One save contract for every system**, present and future. Quests, consequences and skills (sub-projects 2 to 4) add their state through it and need no new machinery.
- **Saves survive new builds.** Each file carries a version number, and older versions are migrated forward.

## Non-goals

- Quests, the journal, consequences and skills. Those are the next sub-projects; this only gives them somewhere to write.
- Walking between the Metro and the Zócalo. Nothing links them yet. The save stores which map you are in. For when gates exist, each map's gathered state is also the per-map store (section 3, "Maps you have left").
- **The old Iberian maps** (harbour, old town; `city.tscn`, `old_town.tscn`) *(Claude's call)*. The Mexico City pivot superseded them, so they stay on `DistrictState` and their gate memory exactly as now, and can't be saved to disk. Their suites stay green untouched. `CityState.districts` is saved as it is, as opaque data, so nothing is lost if they are ever played.
- Cloud saves, platform achievements, ironman or permadeath modes, and save editing.
- Settings. These already live in `user://settings.cfg` (`GameSettings`) and are never part of a save.

## Anti-goals (a failure even if it works)

- **A load that doesn't match the save.** A guard reset to calm, a door snapping shut, a body jumping to its feet, a prop popping to a new place, the music restarting from the top.
- **Saves that break with every build.** Old saves must keep loading, or be refused with a clear message, never a crash or a half-loaded world.
- **A noticeable stutter when saving.**
- **Runs bleeding into each other.** A save always loads into its own run, with its own archetype and time played, and never rotates out another run's saves.
- **Silent gaps.** Something that changes in play but quietly isn't saved. Every node with live state is either saved or deliberately listed as not saved (see "Coverage").

## Approaches considered

| | Approach | Trade-off |
|---|---|---|
| **A (picked by the user)** | **Every system records itself, in two stages.** This extends the existing `save_state()`/`load_state()` pattern (Player, Inventory, Door, Chest, Guard, GuardBody, the pickups, Torch, JobState, PeopleState). A save manager gathers every saveable under a stable name, the map is rebuilt as usual, and each thing is set back the way it was. | The most code. In return each piece is testable on its own, and every new system adds its own state as it is built. |
| B | Snapshot the scene tree with Godot's scene packing | Little code per system. But it can't capture physics momentum, animation playback, tweens or paused coroutines, so fights would come back frozen or wrong, and saves would break whenever a scene changes. Dropped. |
| C | Record the player's inputs and replay them from a checkpoint | The background navmesh bake changes frame counts between runs (`headless-test-determinism`), so a replay drifts. Dropped. |

## What the user decided

- Saving is allowed freely.
- Loading restores exactly; a fight resumes as it was.
- Saves are grouped per playthrough, and Continue follows the run played last.
- Approach A, in two stages.
- Build on `save-load`: its own worktree, from `metro-standard` with `main-menu-overhaul` merged in, leaving the uncommitted edits alone.
- Brief cosmetic effects (under about a second) may be missing after a load.

## The design

### 1. Runs and slots *(Claude's call, played back without correction)*

- **A run** is created when the archetype screen confirms. It holds a run id, the archetype, when it was created, and its total time played. `CityState` keeps the current run id and the time played.
- **The slots in a run:**
  - **Quick:** quicksave writes here. The newest 3 are kept, and older ones rotate out.
  - **Auto:** an autosave is written on entering a map, and later on quest changes (sub-project 2 calls the same entry point). The newest 3 are kept.
  - **Named:** saves made from the Save page. Any number, overwritten only when the player chooses to.
- **Continue** loads the newest save of any kind in the last-played run. `user://saves/last_run` records which run that is, updated on every save and load.
- **Both Load pages, the main menu's and the pause menu's, list every run** *(Claude's call)*. The current run, or the last-played one, comes first and opens by default. Loading another run's save switches to that run: `CityState` takes that run's id, archetype and time played, and `last_run` follows.
- **Deleting** *(Claude's call)*. A save, or a whole run, can be deleted from the Load page, after a confirm in the pause menu's existing Yes/No language. Deleting the last-played run moves Continue to the newest remaining run. Deleting every run sets Continue back to its "no save" line.
- **On disk:**
  ```
  user://saves/<run_id>/run.cfg
  user://saves/<run_id>/<slot>.save
  user://saves/<run_id>/<slot>.png
  ```
  - `run.cfg` holds the archetype, the dates and the time played.
  - `<slot>.save` is the save itself.
  - `<slot>.png` is the save's picture.
- **A save file** is a small header (version, run id, slot kind, map path, the place's name, archetype, date, time played) followed by the body, written with `FileAccess.store_var` (no objects).
  - The header is read alone to fill the save list, so listing never parses whole bodies.
  - *(Claude's call)* Binary `store_var`, not JSON: the state is full of `Transform3D`, `Vector3`, `StringName` and packed arrays, which `store_var` keeps exactly and JSON flattens. A debug flag can also write a `var_to_str` text copy beside each save for reading and diffing.
- **Writing never corrupts.** A save is written to `<slot>.tmp` and then renamed over the slot, so a crash mid-write leaves the old save whole.

### 2. When the player can save *(Claude's call)*

- **Anywhere in play**, including mid-fight, mid-climb, mid-air and underwater.
- **Not during:**
  - a conversation
  - a loading screen or map change
  - a scripted moment. Nothing is scripted yet: the Metro ride is a later project. This builds the flag (`SaveGame.hold(reason)` / `release(reason)`) and tests it with a stand-in moment.
  - death

  A quicksave asked for then is **held, and happens the moment that ends**, with a short note on the HUD so the key doesn't seem dead. An autosave due then waits the same way.
- **Quicksave and quickload keys** are free keys picked in the plan, since F5 and F9 already open debug tools. Both can be rebound in Settings. Quickload asks nothing and loads the newest quicksave of the current run.
- **On death:** after the existing 2 s fall, a death page offers *Load latest*, *Load…* and *Main menu*, instead of `reload_current_scene()`. Its words are stand-ins for the user to write.

### 3. The save contract

Every system with state that can change in play implements:

- `save_state() -> Dictionary`: plain values only (numbers, strings, StringNames, vectors, transforms, colours, arrays and dictionaries of these). Never nodes or resources, which are named by id or path.
- `load_state(state: Dictionary) -> void`: restores that state onto a freshly built node. It must also accept old states missing newer keys, falling back to defaults.
- **Identity:**
  - A saveable node joins the group `&"saveable"`.
  - Its id is its path relative to the map's root, by default. Both playable maps build their sets in code under stable names (`candle_lane`, `pasaje`, `shade_<character>`, `Library`…), so this is stable.
  - A node whose name is not stable implements `save_id()`.
  - A duplicate or missing id is a load-time error naming both nodes, never a silent overwrite.
- **Things made during play** (shards, arrows, thrown props, casings while they fall, ragdolled bodies, guards who followed you through a gate) have no stable place in the tree, so they are recorded as `{kind, state}`.
  - A `Spawns` registry maps each `kind` to a factory that remakes it and then calls `load_state`.
  - Each such script names its kind (`save_kind()`) and joins `&"saveable_spawn"`.
- **Holders of global state** save through the same contract as autoloads or statics:
  - `CityState` (with `JobState` and `PeopleState` inside it)
  - `Music`, and the static fades in `Sfx`, `Ambience` and `Focus`
  - `TimeFx`
  - the `Ward.active` static
  - Squad's and Garrison's registries
- **Maps you have left.** When map gates exist, the map you leave keeps its gathered state (stable saveables only; spawns settle or vanish as in `DistrictState`) in `CityState.maps[map_path]`. It's applied when you come back, and saved with the rest. Until then this store is empty. Stage 1 builds and tests it with a stand-in two-map test.
- **Saving the order things happen.** `load_state` is applied in a fixed order:
  1. `CityState`
  2. the map's own state
  3. stable saveables, in tree order
  4. spawns
  5. the player
  6. global audio and time

  This way a guard's target and a shard's shooter can be resolved by id after both exist. References between saved things are always ids, resolved in a final `relink()` pass.

### 4. Saving and loading, step by step *(Claude's call)*

**Saving:**
1. Ask whether saving is allowed now (section 2). If not, hold the request.
2. In **one frame**: gather every saveable's state, every spawn's `{kind, state}`, the map path and the globals into one dictionary. Grab the picture from the viewport, without the HUD and pause layers. The pause menu already captures the paused frame for its painting, so a save made from it reuses that capture.
3. Hand the dictionary and the picture to a `WorkerThreadPool` task, which writes the `.tmp` and renames it. The game never waits on the disk.

**Loading:**
1. The loading cover (`ArtLoadingScreen.change_to`) opens the saved map as New Game does today, with a flag saying a save is pending.
2. The map builds as normal: greybox, sets, navmesh, player.
3. Once it is built, and **before the first unpaused physics frame**, the save is applied in the section 3 order. Then:
   - player interpolation and camera smoothing are reset, so nothing slides into place
   - physics bodies get back their velocities and their sleeping state
   - the cover lifts
4. Whatever the map makes on its own at start that the save already holds (a schedule's first train, spawned walkers) is overwritten by the saved state, never duplicated.

### 5. Stage 1: outcomes and memory (Continue works)

At the end of stage 1, a save restores:

- **CityState:** the run, the time played, the archetype, `districts`, `carried`, `job` and `people` (both already have `save_state`).
- **The player:** where they stand and look (transform, camera pitch), health, the inventory (purse, keys, belt, ammo, already saved), the power pool, the revolver's load, the selected spell, and what the hand holds.
- **Things in the world** that already save themselves: doors, chests, pickups, torches. They join the save contract (the group and the id), so any Mexico City map that places them saves them. Their existing `save_state` stays as it is, and `DistrictState` keeps calling it on the old maps.
- **The talk shades:** each one's resting shade state (flare, dim, gutter, calm) and its facing. What they remember is already in `PeopleState`.
- **The schedules of the playable maps** (trains, the dark train, the procession, the ánimas, the ownerless shadow, the crowds, the floating books and the rest the survey found): the time to each one's next event, and its random generator's `state`, so the next train still comes when it would have.
- **The music's** current state and intensity.
- **The pages:**
  - Continue on the main menu.
  - A Load page on the main menu: runs, newest first, and the saves inside each.
  - Save and Load pages in the pause menu, which grows from Resume, Settings, Main menu, Quit to **Resume, Save, Load, Settings, Main menu, Quit**.
  - The death page.

  All are built in the menu's existing painted language (MenuPages, MenuWord, MenuType). Their layout is shown to the user **in the game**, never as stills over a mock backdrop. Every word on them is a stand-in for the user to write.
- **Quicksave, quickload and autosave on entering a map.**

**What stage 1 doesn't restore yet:** a save made mid-action comes back settled. Guards come back searching, not mid-swing, and anything in flight is gone. That's the known limit until stage 2, and the death page and Continue work anyway.

### 6. Stage 2: the live layer (fights resume)

Stage 2 adds each system's moment-to-moment state:

- **Player:**
  - movement state and the move in progress (the move, its elapsed time, progress and windup)
  - velocity, the coyote and jump-buffer timers
  - hang, climb and rope holds, by id
  - lean, water, the death fall, the hazard cooldown
  - CameraJuice, BodyMotion and BodyPose springs
  - HandContacts' state and grips
  - PlayerFrob (what is held or shouldered by id, swing and tool windups, lockpicking, reading)
  - HandSlot (switching, lowering, circle progress, tome pages)
  - ViewArms animation playback
- **PlayerCombat:** phase and time in phase, charge, combo, stamina, adrenaline, windup and recovery, riposte and feint deadlines, the queued action, what this swing already hit.
- **Revolver:** loaded chambers, loading state and time, kick, heat, climb, owed shot, whip, smoke heat, and its game-time deadlines.
- **Caster:** what is being cast and how far along, the blink aim and its mark, `empowered_until`.
- **Spawns:**
  - Shard: velocity, life, shooter id.
  - Ward: life, front, hits, flare. A Ward up at saving is up at loading, with the same time left.
  - Arrow: velocity, stuck in what, life.
  - Thrown and ThrownTool: the body's velocity plus the rider's life and hits.
  - Casings: while they fall.
- **Guards and their stack:**
  - Guard's full state, not today's lossy one: today `load_state` turns COMBAT into SEARCHING, and stage 2 keeps it COMBAT, with target, attack in progress and timers.
  - GuardFighter, GuardRig, GuardHabits, GuardLife, GuardVoice, GuardHands, GuardRota.
  - Squad and Garrison: tactics, morale, roles, and their `_until` times, with targets by id.
  - GuardBody and Ragdoll: each bone body's transform and velocity, limpness, the time loose, the get-up timer. A body mid-fall keeps falling.
- **Animation:**
  - Every `AnimationPlayer`: its current animation and position.
  - Every `AnimationTree`: its state machine node, travel and blend parameters.
  - This applies to Humanoid (guards, shades), ViewArms and the hands.
- **Time and sound:**
  - **TimeFx:** its requests and the time left on each, so a hit-stop saved mid-way finishes, never leaving `Engine.time_scale` wrong.
  - **Music:** the playback position of each layer, so the score resumes in its bar.
  - **Ambience and Focus:** their fades.
- **The talk box** is never saved open (section 2), so there is nothing to keep beyond `PeopleState`.
- **Coroutines.** The few gameplay `await`s and fire-and-forget timers become saved deadlines, checked each frame:
  - CityState's follower delay
  - PlayerController's death delay
  - the timers in Ward, Revolver, TimeFx, Casings, MagicFx, GunFx and WaterVolume

  The rule from here on: **gameplay code never waits on an unsaved timer.**
- **Cosmetic effects shorter than about a second** (muzzle flash, sparks, blood puffs, MagicFx and GunFx bursts): **the user agreed these may be dropped on load.** They are not restored mid-effect, and are listed as such in the coverage file. Everything with gameplay meaning (smoke you hide in, a Ward, a burning fire, decals and blood left on surfaces) is restored.

**Randomness *(Claude's call)*.** "Exact" means the moment is exact: everything you can see and everything that has been decided. It doesn't mean the future replays the same dice. Seeded generators that schedule the world (trains, procession, crowds, ánimas and so on) save their `state`, so their schedule continues. The global `randi()`/`randf()` used for small choices (which footstep sound, which bark) is not recorded, so after a load the next roll may differ. Decisions already made (a guard's chosen attack, the next train's time) are saved state, so nothing visible changes.

### 7. Coverage *(Claude's call)*

To keep "silent gaps" from creeping in as the game grows, a coverage check walks the built playable maps (Metro with the candle lane, the Zócalo, and the combat arena for guards). Every node with a script must be one of:
- saveable
- a spawn kind
- listed in `data/save/stateless.txt` with a one-line reason (a static mesh builder, for example)

A new script with live state that fails this check fails the suite.

### 8. Versions

- Each save's header carries `save_version` (an int, starting at 1). The body is passed through migrations in order, `1 → 2 → …`, each a small function in `SaveMigrations.gd`.
- A save from a newer build than the one running is refused with a clear message, never half-loaded.
- *(Claude's call)* Bump the version whenever a `save_state` changes the meaning of a key. Adding a key that has a default in `load_state` needs no bump.

### 9. Testing

`tests/save_test.gd` runs headless like the other suites, and covers:

- **The round trip, generic:**
  1. Build a map.
  2. Play a scripted moment.
  3. Gather the state.
  4. Write the save, then load it into a fresh tree.
  5. Gather the state again and deep-compare, with float tolerance.

  This runs on the Metro with the candle lane, on the Zócalo, and (stage 2) on the combat arena mid-fight.
- **Each saveable** on its own: `load_state(save_state())` gives back the same `save_state()`.
- **Stage 2 scenarios.** In each, the next second after a load matches the next second of a run that never saved:
  - a guard mid-swing
  - a shard in flight
  - a Ward up
  - a body mid-fall
  - a hit-stop mid-way
  - a blink mid-cast
  - a climb mid-move

  Compared positions, states and health, within tolerance, on fixed fps.
- **Runs and slots:** quick and auto rotation keeps 3, runs never mix, Continue picks the newest save of the last run, and a corrupt `.tmp` leaves the old save whole.
- **Refusals:** saving during a conversation, a loading screen or death is held and then happens. A newer-version save is refused. A missing spawn kind or duplicate id is reported.
- **Migrations:** a stored version-1 fixture still loads after each bump.
- **The coverage check** (section 7).

All existing suites must stay green. The pages are judged by the user in the game.

## Constraints

- Godot 4.5.1 and GDScript, matching the code around them: plain-English `##` comments, the JobBook and JobState conventions, code-built UI.
- The user writes every word the player reads on the save pages and the death page. Claude builds them with stand-ins.
- Saving must not stutter: one-frame gathering, threaded write.
- No procedural audio. The pages' sounds reuse the menu's jingle system.
- **The branch must contain everything a save touches:**
  - the menus (`main-menu-overhaul`)
  - the revolver, magic, talk, Metro and candle lane (`metro-standard`)

  **The user decided:** build on a new branch `save-load`, in its own worktree, cut from `metro-standard` with `main-menu-overhaul` merged in. Only committed work goes in. The user's uncommitted edits in the main checkout are left alone, and they meet this branch when the user commits them.

## Plans *(Claude's call)*

Stage 1 gets its own plan now. Stage 2 gets its own plan after the user has played stage 1 (Continue, the pages, the death page), so their verdict can shape it.

## Left to the builder

- The exact keys for quicksave and quickload, among free keys.
- The internal shape of the save manager and the `Spawns` registry, and the order of tasks within each stage.
- How the save picture is scaled and compressed.
- The text copy debug flag's name.
- The page layouts, within the menu's painted language, tuned with the user in the game.
