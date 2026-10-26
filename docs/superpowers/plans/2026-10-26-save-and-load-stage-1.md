# Save and load, stage 1: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The game can be saved anywhere and loaded back, with its outcomes and memory restored. Saves are grouped by run, with quick, auto and named slots, Continue, Load and Save pages, and a death page. This is stage 1 of the design; stage 2 (the live layer) gets its own plan after the user plays this.

**Architecture:**
- A `SaveGame` autoload gathers state from every registered saveable (a stable id, then `save_state()`) plus `CityState`, the player and the globals into one body dictionary. It hands the body to `SaveFiles`, which writes it on a worker thread as `store_var(header)` + `store_var(body)`, through a `.tmp` and a rename.
- Loading goes through the existing loading cover (`ArtLoadingScreen.change_to`). The map builds as normal, then `SaveGame.apply_pending()` sets everything back before the cover lifts.
- A coverage check walks the playable maps so no live state goes unsaved without a written reason.

**Tech Stack:** Godot 4.5.1, GDScript, headless suites (`Godot --headless --fixed-fps 60 --path . res://tests/<name>.tscn`).

**Spec:** `docs/superpowers/specs/2026-10-26-save-and-load-design.md`. Read it first: section numbers below refer to it.

## Global Constraints

- **Godot binary:** `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`.
- **Where to work:** branch `save-load`, worktree `.claude/worktrees/save-load`, cut from `metro-standard` with `main-menu-overhaul` merged in. Committed work only.
  - Never touch the main checkout's uncommitted edits.
  - Never push.
  - Commit only your own paths.
- **Style:** match the surrounding code, with plain-English `##` comments in the manner of CityState, JobState and JobBook, and UI built in code.
- **Words:** every word the player reads on the pages, the death page and the HUD save notes is a stand-in. All of them live in one file, `scripts/Save/SaveWords.gd`, for the user to rewrite.
- **What a `save_state()` holds:** plain values only (numbers, String, StringName, Vector2/3, Transform3D, Color, Array, Dictionary of these). Never a Node or Resource: those are named by id.
- **Never stutter:** gather in one frame, write on `WorkerThreadPool`.
- **Settings stay apart:** `user://settings.cfg` is never part of a save.
- **Versions:** `SaveMigrations.CURRENT := 1`. A save newer than CURRENT is refused.
- **Slots:** quick keeps the newest 3 (`quick_1`..`quick_3`), auto keeps the newest 3 (`auto_1`..`auto_3`), and named saves are `named_<n>` with no limit.
- **Disk layout:** `<root>/<run_id>/run.cfg`, `<root>/<run_id>/<slot>.save`, `<root>/<run_id>/<slot>.png`, and `<root>/last_run`. The default `<root>` is `user://saves`; tests use `user://test_saves`.
- **Saving is held during:** a conversation, the loading cover, death, and any `SaveGame.hold(reason)`. The request waits, then happens.
- **Old maps:** the Iberian maps (`city.tscn`, `old_town.tscn`) stay on `DistrictState`, unchanged. Their suites must stay green.
- **Suites:** every suite green at the Task 0 baseline must stay green. Record the baseline's known failures (freerun FR50 and any others) in Task 0 and don't add to them.

## Review Focus

1. **Loading from the pause menu:** the tree is paused when Load is chosen, and the game must come back unpaused and playable, with the mouse captured. Pinned in Task 9 (`P6`).
2. **Pressing quickload twice, or during the loading cover:** only one load happens, and the second press is ignored. Pinned in Task 7 (`K5`).
3. **An unwritable or full disk:** the save fails with a HUD note, the old save stays whole, and nothing crashes. Pinned in Task 1 (`F9`) and Task 7 (`K6`).
4. **A corrupt or truncated `.save`, or a missing `.png`:** the list shows the entry as unreadable, Continue skips to the next newest readable save, and nothing crashes. Pinned in Task 1 (`F10`) and Task 9 (`P7`).
5. **The moment after a load:** no autosave fires because a map was entered by loading, and a save requested before `apply_pending` finishes is held. Pinned in Task 7 (`K7`).

---

### Task 0: The branch, the merge, the baseline

**Files:**
- Create: the worktree `.claude/worktrees/save-load`
- Create: `.superpowers/sdd/2026-10-26-save-and-load/progress.md`, the ledger: baseline results and rulings

- [ ] **Step 1: Create the branch and worktree.**
  ```bash
  git worktree add .claude/worktrees/save-load -b save-load metro-standard
  ```
  Run it from the main checkout's root, then work only inside the new worktree.
- [ ] **Step 2: Merge the menus in.** Run `git merge main-menu-overhaul`. Resolve conflicts by keeping both sides' features:
  - **`StealthHUD`:** keep main-menu-overhaul's `PauseMenu` and metro-standard's ammo UI, caster HUD and talk box hooks.
  - **`CityState`:** keep `archetype` and metro-standard's members.
  - **`project.godot`:** take the union of the autoloads and inputs.

  Commit the merge.
- [ ] **Step 3: Copy in the gitignored assets.** Copy what the memory files say the checkout needs into the worktree, gitignored and uncommitted: `textures/ps2` and the textures.com files. Copy them from the main checkout or from `.claude/worktrees/metro-standard`.
- [ ] **Step 4: Run the baseline.** Run every `tests/*_test.tscn` headless and record each suite's pass/fail counts in the ledger. Run long suites in the background. Expected: everything that was green on each branch alone is still green. Fix any break the merge caused before going on.
- [ ] **Step 5: Commit the ledger.**

### Task 1: SaveFiles and SaveMigrations (the disk)

**Files:**
- Create: `scripts/Save/SaveFiles.gd` (`extends RefCounted`, all static)
- Create: `scripts/Save/SaveMigrations.gd` (`extends RefCounted`, all static)
- Test: `tests/save_files_test.gd` and `.tscn`, in the style of `tests/dialogue_test.gd`: `_check(name, ok, detail)`, then RESULTS and `get_tree().quit()`

**Interfaces:**
- Produces, in `SaveFiles`:
  - `static func use_root(path: String) -> void`, plus `static func root() -> String` (default `user://saves`)
  - `static func new_run(archetype: StringName) -> String`: creates `<root>/<id>/run.cfg` holding `archetype`, `created` (unix int) and `played` (0.0), and returns the id `run_<YYYYMMDD_HHMMSS>_<4 hex>`
  - `static func runs() -> Array[Dictionary]`: `{id, archetype, created, played, newest}`, newest first by `newest` (the newest save's date, else `created`)
  - `static func set_played(run_id: String, seconds: float) -> void`
  - `static func saves(run_id: String) -> Array[Dictionary]`: headers newest first, each plus `path`, `picture` (a path or ""), and `readable: bool`
  - `static func next_slot(run_id: String, kind: StringName) -> String`: for `&"quick"`/`&"auto"`, a free slot `_1`..`_3`, else the oldest of the three. For `&"named"`, `named_<max+1>`.
  - `static func write(run_id: String, slot: String, header: Dictionary, body: Dictionary, picture: Image) -> Error`: thread-safe, so no SceneTree use. Writes `<slot>.tmp` and then `DirAccess.rename` over `<slot>.save`. Writes the picture as PNG, scaled to 480 px wide. Updates `last_run`.
  - `static func read_header(path: String) -> Dictionary`: {} when unreadable
  - `static func read(path: String) -> Dictionary`: `{header, body}` with the body migrated, or `{error: String}`
  - `static func delete_save(run_id: String, slot: String) -> void`, `static func delete_run(run_id: String) -> void`
  - `static func last_run() -> String` (`""` when none), `static func set_last_run(run_id: String) -> void`
  - `static func newest_save(run_id: String) -> Dictionary`: the newest readable save, or {}
  - `static func continue_target() -> Dictionary`: the newest readable save of `last_run()`. If that run has none, the newest readable save of any run. If there is none at all, {}.
- **The header's keys:**
  - `version` (int), `run` (String), `slot` (String), `kind` (StringName)
  - `name` (String), `map` (a scene path), `place` (String)
  - `archetype` (StringName), `date` (unix int), `played` (float)
- Produces, in `SaveMigrations`:
  - `const CURRENT := 1`
  - `static func migrate(body: Dictionary, from: int) -> Dictionary`: applies the steps from `from` up to CURRENT. It's an empty table now, with one documented example step in a comment.
  - `static func readable(version: int) -> bool`: `1 <= version <= CURRENT`

- [ ] **Step 1: Write the failing tests.** Each runs with `use_root("user://test_saves")`, and the folder is wiped before each check.
  - `F1`: `new_run(&"derive")` makes a run whose `runs()[0].archetype == &"derive"`.
  - `F2`: `write` then `read` round-trips a body holding a `Transform3D`, a `StringName` key and a nested `Array`, exactly (`==`).
  - `F3`: `read_header` returns the header without reading the body. A body of 5 MB of junk still gives its header back quickly.
  - `F4`: four quick writes leave exactly `quick_1..3`, and the oldest date has been replaced.
  - `F5`: the same holds for auto.
  - `F6`: named saves grow without limit (`named_1`..`named_5`).
  - `F7`: `saves()` is newest first, and `continue_target()` follows `last_run()`.
  - `F8`: `delete_run(last)` makes `continue_target()` the newest save of another run. Deleting every run makes it `{}`.
  - `F9`: a write into a read-only root (or a path whose folder can't be made) returns an error and leaves an earlier `<slot>.save` byte-identical.
  - `F10`: a truncated `.save` is listed with `readable == false`, and `continue_target()` skips it.
  - `F11`: a header with `version: CURRENT + 1` is unreadable, and `read` returns `{error}`.
  - `F12`: two runs' quick slots never rotate into each other.
- [ ] **Step 2: Run them and see them fail.** Run `Godot --headless --fixed-fps 60 --path . res://tests/save_files_test.tscn`. Expected: FAIL, because the scripts are missing.
- [ ] **Step 3: Implement SaveFiles and SaveMigrations** to the interfaces above. A `.tmp` left from a crash is ignored by `saves()` and overwritten by the next write.
- [ ] **Step 4: Run the tests.** Expected: `F1`–`F12` PASS.
- [ ] **Step 5: Commit.** Message: `feat(save): runs, slots and save files on disk`.

### Task 2: SaveGame core and CityState's state

**Files:**
- Create: `scripts/Save/SaveGame.gd` (`extends Node`), registered as the autoload `SaveGame` after `CityState` in `project.godot`
- Modify: `scripts/Level/CityState.gd`: add `run_id: String`, `played: float`, `maps: Dictionary`, and `save_state()`/`load_state()`. `begin()` leaves `run_id`, `played`, `archetype` and `maps` alone.
- Modify: `scripts/UI/ArtLoadingScreen.gd`, in `change_to()`. After the scene is built (after the `loading_complete` wait) and while the tree is still paused, if `SaveGame.pending` is set, `await SaveGame.apply_pending(destination)`. A failed apply returns `ERR_CANT_CREATE` and goes back, as a failed build does today.
- Test: `tests/save_test.gd` and `.tscn`, with a fixture scene `tests/fixtures/save/fixture_map.tscn`. The fixture holds a root, two saveable stub nodes (`tests/fixtures/save/Stub.gd`, which holds `value: int` and `pos: Vector3`) and a third stub that is freed during the test.

**Interfaces:**
- Produces, in `SaveGame`:
  - `signal saved(run_id: String, slot: String, error: Error)`, `signal loaded(run_id: String, slot: String)`, `signal save_held(reason: StringName)`
  - `func register(node: Node) -> void`: called by a saveable in `_ready`. When a registered node leaves the tree by `queue_free` while its scene stays current, its id is added to `gone`.
  - `func id_of(node: Node) -> String`: `node.save_id()` if it has one, else `str(get_tree().current_scene.get_path_to(node))`
  - `func gather() -> Dictionary`: the body, `{"version", "map", "city", "saveables": {id: state}, "gone": [id], "player": {"state", "place"}, "globals": {name: state}}`
  - `func apply(body: Dictionary) -> Array[String]`: returns the problems found (a missing id is a problem line, never a crash). Applies in the spec's section 3 order:
    1. `CityState.load_state`
    2. free the nodes in `gone`
    3. the saveables, in tree order
    4. the player (`load_state` then `load_place`)
    5. the globals

    Then it resets physics interpolation on the scene (`reset_physics_interpolation()` on every Node3D saveable and on the player).
  - `func duplicate_ids() -> Array[String]`: `"<id>: <path A> and <path B>"` for each clash. `gather()` refuses with an error while any exist.
  - `var globals: Dictionary`: `{name: Object}` of global state holders that have `save_state`/`load_state`, filled in by `register_global(name: String, holder: Object)`.
  - `var pending: Dictionary`, `var loading: bool`, `func apply_pending(scene: Node) -> Error`
  - `func hold(reason: StringName) -> void`, `func release(reason: StringName) -> void`, `func can_save() -> bool`. False when:
    - anything is held
    - `loading` is true
    - an `ArtLoadingScreen` is in the tree
    - the player is dead
    - `player.frob.talking() != null`
    - there's no player in group `&"player"`
  - `func begin_run(archetype: StringName) -> String`: sets `CityState.run_id` and `played = 0`
- Produces, in `CityState`: `save_state() -> Dictionary` holding `run`, `played`, `archetype`, `districts`, `carried`, `followers`, `job` (`job.save_state()`), `people` (`people.save_state()`) and `maps`, and `load_state(state)`, its inverse, which relinks job and people. `played` counts up in `_process` while the tree isn't paused and a run is set.

- [ ] **Step 1: Write the failing tests.**
  - `G1`: the stubs' states round-trip through `gather()` → a fresh fixture → `apply()`.
  - `G2`: the freed stub's id is in `gone`, and `apply` frees the fresh copy of it.
  - `G3`: two stubs with the same `save_id()` make `duplicate_ids()` name both, and `gather()` refuses.
  - `G4`: `CityState` round-trips: run, played, archetype, a job goal done, a people flag, a mood. After `CityState.begin()` the people state and the run survive, and the job resets.
  - `G5`: `can_save()` is false while held, while `loading`, and while the player is dead, and true after `release`.
  - `G6`: a body with an id the scene doesn't have returns one problem line and applies everything else.
  - `G7`: `ArtLoadingScreen.change_to` with `pending` set applies it before the cover lifts. The first unpaused physics frame already sees the stub's saved `pos`.
- [ ] **Step 2: Run them and see them fail.** Run `Godot --headless --fixed-fps 60 --path . res://tests/save_test.tscn`. Expected: FAIL.
- [ ] **Step 3: Implement SaveGame, the CityState state and the change_to hook.**
- [ ] **Step 4: Run the tests.** Expected: `G1`–`G7` PASS. Also run `job_test`, `dialogue_test`, `city_test` and the menu suites: all as at the baseline.
- [ ] **Step 5: Commit.** Message: `feat(save): the save manager, the city's state, loading through the cover`.

### Task 3: The player and the things that already save themselves

**Files:**
- Modify: `scripts/PlayerController.gd`:
  - `save_state()` adds `"power"` (`power.power`), `"revolver"` (`revolver.save_state()`) and `"caster"` (`caster.save_state()`), each only when that child exists.
  - New `save_place() -> Dictionary` holds `transform` (global), `look` (`neck.rotation.x`) and `velocity`.
  - New `load_place(state: Dictionary)` calls `teleport(transform)`, then sets look and velocity.
  - These ride along when going through a gate (CityState `carried`), which is wanted.
- Modify: `scripts/Combat/Revolver.gd`: `save_state()` holds `loaded` and `barrel`. `load_state()` restores them, with `loading = Load.NONE`.
- Modify: `scripts/Magic/Caster.gd`: `save_state()` holds `selected` and `loadout`. `load_state()` restores them.
- Modify: `scripts/Magic/PowerPool.gd`: `power` is restored by the player's `load_state`, clamped to `MAX`.
- Modify: `Door.gd`, `Chest.gd`, `PickupState.gd` (Loot, KeyItem and ToolItem use it), `Torch.gd`. Each calls `SaveGame.register(self)` in `_ready`, guarded with `get_node_or_null("/root/SaveGame")` so tests run without the autoload. Their `save_state` stays unchanged.
- Test: `tests/save_test.gd`, checks `G8`–`G12`.

- [ ] **Step 1: Write the failing tests.**
  - `G8`: a player saved mid-air, looking 30° down, with 3 chambers loaded, the shot barrel picked, `selected = &"ward"` and power 40, comes back with all of these the same (transform within 1 mm).
  - `G9`: a door left open at 70°, a locked chest unlocked, a taken key and an unlit torch all come back the same on a fresh build of a fixture with them in it.
  - `G10`: `city_test`'s gate checks still pass, and the player keeps power and ammo through a gate.
  - `G11`: loading the player doesn't leave the camera's interpolation sliding: the camera's global position on the first frame after the load equals the saved position.
  - `G12`: a pickup that was taken stays gone after the load (it's in `gone`).
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the tests.** Expected: `G8`–`G12` PASS, and `interaction`, `city`, `caster` and `revolver`-related suites as at the baseline.
- [ ] **Step 5: Commit.** Message: `feat(save): the player, doors, chests, pickups and torches save`.

### Task 4: The coverage check

**Files:**
- Create: `tests/save_coverage_test.gd` and `.tscn`
- Create: `data/save/stateless.txt`: lines of `res://path/Script.gd  # why it holds no live state`
- Create: `data/save/stage2.txt`: lines of `res://path/Script.gd  # what stage 2 adds`. This is the honest list of live state not yet saved.

**Interfaces:**
- Consumes: `SaveGame.register`. A node counts as saved when `SaveGame` has it registered, or when it's the player or one of the player's children, which `save_state` covers.

- [ ] **Step 1: Write the check.**
  - `V1`: build `maps/metro.tscn` (with the candle lane and the Pasaje) for 120 frames.
  - `V2`: do the same with `maps/zocalo.tscn`.
  - In both, every node with a script must be registered, or the player or its children, or have its script listed in `stateless.txt` or `stage2.txt`. Each failure prints its node path and script.
- [ ] **Step 2: Run it.** Expected: FAIL, with the list of unsaved scripts. That list is the work list for Tasks 5 and 6.
- [ ] **Step 3: Fill in the lists.**
  - **`stateless.txt`:** scripts that only build and hold nothing that changes, such as GreyboxLoader output and kit builders.
  - **`stage2.txt`:** the player's live children: PlayerCombat, HandContacts, HandSlot, PlayerFrob's held state, ViewArms and Humanoid animation, the CameraJuice/BodyMotion springs, and spells in flight. Also TimeFx, and the Sfx/Ambience/Focus fades.

  Every remaining scheduler stays failing, for Tasks 5 and 6.
- [ ] **Step 4: Commit.** Message: `test(save): coverage of the playable maps`. The check is still red, and Tasks 5 and 6 turn it green.

### Task 5: The Metro's schedules and the shades

**Files:**
- Modify: `scripts/Visual/TrainPass.gd`. Its state is `next`, `_into`, `_peaked` and `_rng.state`. On load, if `_into >= 0`, a pass in progress resumes its rumble from `_into`, with no second `began`.
- Modify: `maps/underground_lab.gd`, the `_breathe` loop: `_clock`, `next_spark`, and the sparks' rng state. `maps/candle_lane.gd` adds its own `draught_now` state if it isn't derived.
- Modify, the same way, with each one's next-event times, what it's in the middle of, and its rng `state`: `Procession.gd` (`_along`, `_next`, walking, `_gone`), `OwnerlessShadow.gd`, `Crowd.gd`, `ShadeCrowd.gd`, `Animas.gd`, `Nahual.gd`, `WatchingEyes.gd`, `Wisps.gd`, `DriftingPages.gd`, `ChainedBook.gd`, `NeonSign.gd`, `PipeSounds`, `Moths.gd`, `Sway.gd`, and the library's FloatingBooks, ShelfStir, Quarantine and BookSounds. The exact list is whatever Task 4 reports for the Metro.
- Modify: `scripts/Interaction/Shade.gd`. Its state is `_resting` and its facing (the body's yaw). It registers itself; its id is `shade_<character>` from its name.
- Modify: `scripts/Audio/Music.gd`. Its state is `intensity` and `target`. It registers through `SaveGame.register_global("music", self)` in `_ready`, and `load_state` lands the score at that intensity without a sting.
- Test: `tests/save_test.gd` `G13`–`G15`, and `save_coverage_test` `V1` turning green.

- [ ] **Step 1: Write the failing tests.**
  - `G13`, the Metro round trip:
    1. Build `maps/metro.tscn` and run 600 frames.
    2. `gather()` is A.
    3. Write and read it.
    4. Build a fresh metro and `apply`, then `gather()` is B.
    5. A equals B, deep, with float tolerance 1e-4.
  - `G14`, the next train:
    1. After the round trip, run both the original and the loaded metro 3000 frames.
    2. The first train's `began` comes on the same frame in both (fixed fps, seeded rng).
  - `G15`: a shade set to `&"dim"` and facing the player comes back dim and facing the same way.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement each script's `save_state`/`load_state` and `register` call.**
- [ ] **Step 4: Run the tests.** Expected: `G13`–`G15` PASS and `V1` PASS. `candle_lane_test`, `animas_test` and the other Metro suites stay as at the baseline.
- [ ] **Step 5: Commit.** Message: `feat(save): the Metro's schedules, the shades and the score`.

### Task 6: The Zócalo's schedules

**Files:**
- Modify: `scripts/Level/Pigeons.gd`, `Occult.gd`, `Breath.gd`, `Ambient.gd` (`_time`, `_choose`), `scripts/Visual/Gusts.gd`, and whatever else Task 4 reports for the Zócalo. Each saves its times, its current phase and its rng `state`.
- Modify: `maps/zocalo.gd`: day or night (F11), as map state.
- Test: `tests/save_test.gd` `G16`, and `V2` turning green.

- [ ] **Step 1: Write the failing test.** `G16` is the Zócalo round trip, done as in `G13`: a flock mid-flight comes back mid-flight, and A equals B.
- [ ] **Step 2: Run it and see it fail.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the tests.** Expected: `G16` and `V2` PASS. `zocalo_test`, `ambient_test` and `aliveness_test` stay as at the baseline.
- [ ] **Step 5: Commit.** Message: `feat(save): the Zócalo's schedules`.

### Task 7: Quicksave, quickload, autosave, the picture

**Files:**
- Modify: `scripts/Settings/GameSettings.gd`: add `&"quick_save"` (default F5) and `&"quick_load"` (default F9) to `ACTIONS`, so they're rebindable on the settings page.
- Modify: `maps/underground_lab.gd`: its debug F5 (the dark train) and F9 (the procession) now need Shift held, so they no longer clash with the defaults. *(Plan's call: F5 and F9 are the genre's keys, and the clash was only debug.)*
- Modify: `scripts/Save/SaveGame.gd`, adding:
  - `func request_save(kind: StringName, named := "", slot := "") -> void`:
    - If `can_save()` is false, the request is kept, `save_held` is emitted, and it's retried each frame until it's allowed.
    - Otherwise the body is gathered now.
    - Next frame: the HUD layer is hidden, the code waits for `RenderingServer.frame_post_draw`, grabs the viewport image, then shows the HUD again.
    - The body and the picture go to `WorkerThreadPool.add_task(SaveFiles.write...)`, and `saved` is emitted when done.
  - `func quickload() -> Error`: loads `SaveFiles.saves(run)`'s newest quick save. It's ignored while `loading`. If no quicksave exists, the HUD says so.
  - `func load_slot(run_id: String, slot: String) -> Error`:
    1. Reads the save and sets `pending` and `loading`.
    2. Unpauses the tree and closes the pause menu.
    3. Opens `ArtLoadingScreen` and calls `change_to(header.map)`.
    4. Sets `CityState.run_id` to that run and calls `SaveFiles.set_last_run`.
    5. On error, clears `pending` and `loading`.
  - The autosave on entering a map: after `change_to` reveals a scene in group `&"game_map"`, `request_save(&"auto")`, unless the scene was entered by a load.
  - `_unhandled_input` for `quick_save` and `quick_load`.
- Modify: `maps/metro.gd` and `maps/zocalo.gd`: `add_to_group(&"game_map")`.
- Modify: `scripts/UI/StealthHUD.gd`: the HUD notes use `show_caption(SaveWords.<x>, 1.5)` for saved, held ("saving when this ends"), nothing to load, and failed.
- Create: `scripts/Save/SaveWords.gd`: `const` stand-in strings, one per word on the pages, the death page and the notes, each with a `##` line saying what it must say.
- Test: `tests/save_test.gd` `K1`–`K7`.

- [ ] **Step 1: Write the failing tests.**
  - `K1`: `quick_save` pressed in the metro writes `quick_1` with a picture 480 px wide, and the HUD note shows.
  - `K2`: `quick_save` during a conversation (`frob.talking()` set) writes nothing until the talk ends, then writes once.
  - `K3`: entering the metro through `change_to` with a run set writes `auto_1`.
  - `K4`: `quick_load` restores the quicksave (G13's equality).
  - `K5`: `quick_load` pressed twice in one frame, and again during the cover, starts exactly one load.
  - `K6`: when `SaveFiles.write` fails (root made unwritable), the HUD shows the failure note, `saved` carries the error, and the earlier save is intact.
  - `K7`: a load into the metro writes no autosave, and a `request_save` made before `apply_pending` returns happens only after it.
  - `K8`: gathering takes under 16 ms in the metro (measured; prints the number), and the frame time on the save frame stays under 33 ms.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the tests.** Expected: `K1`–`K8` PASS, and `settings_test` (or the settings suite on the branch) still green with the two new actions.
- [ ] **Step 5: Commit.** Message: `feat(save): quicksave, quickload, autosave on arrival, the save's picture`.

### Task 8: Runs begin at New Game, Continue loads

**Files:**
- Modify: `scripts/UI/MainMenu.gd`:
  - **`_start_game`:** after setting `city.archetype`, call `SaveGame.begin_run(ArchetypeScreen.IDS[index])`.
  - **Continue (`_activate(1)`):** if `SaveFiles.continue_target()` isn't empty, call `SaveGame.load_slot(target.run, target.slot)` through the same transition guard as New Game (`_transitioning`). Otherwise open its page with `SaveWords.NO_SAVE`, which replaces `MenuPages.CONTINUE_LINE`.
  - If the load fails, open the Continue page with `SaveWords.LOAD_FAILED`.
- Test: the menu suite on the branch (`tests/main_menu_test.gd` or its equivalent), checks `M1`–`M3`

- [ ] **Step 1: Write the failing tests.**
  - `M1`: confirming an archetype creates a run with that archetype, and `CityState.run_id` is set.
  - `M2`: Continue with a save in the last run calls `load_slot` with it.
  - `M3`: Continue with no saves opens the page with `SaveWords.NO_SAVE`. A double press starts one load.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the tests.** Expected: `M1`–`M3` PASS, and the menu suites as at the baseline.
- [ ] **Step 5: Commit.** Message: `feat(save): New Game begins a run; Continue loads its newest save`.

### Task 9: The Load and Save pages

**Files:**
- Create: `scripts/UI/SavePage.gd` (`class_name SavePage`, `extends Control`), built in code in the menu's language (MenuType fonts, MenuWord rows, the band's wash), sized to `MenuPages.AREA`.
  - **The Load page:**
    - Runs are listed newest first, the current run (or else the last-played one) first and open.
    - Each run row shows its archetype's emblem (`assets/ui/archetypes/`), its time played, and its newest date.
    - An open run lists its saves, each with its picture, place, kind, date and time played. An unreadable save is shown greyed with `SaveWords.UNREADABLE`.
    - Enter or a click loads the save.
    - Delete or X deletes the selected save or run, after a Yes/No confirm in PauseMenu's confirm style.
  - **The Save page:** a `SaveWords.NEW_SAVE` row first, then the current run's named saves. Picking an existing one asks Yes/No before it's overwritten.
  - **Signals:** `load_chosen(run_id, slot)`, `save_chosen(slot)` (`""` means new), `closed`.
- Modify: `scripts/UI/MainMenu.gd`: a `Load` word after Continue. `NAMES` becomes `["New Game", "Continue", "Load", "Settings", "Lore", "Quit"]`.
  - **Colour:** it reuses Continue's colour.
  - **Illustration and jingle:** it reuses Continue's until the user gives it its own. Tell the user it needs a painting (`ask-for-textures-and-designs`).
  - Every index-based table (COLOURS, the jingles, the button atlas) shifts with it.
  - The page opens a `SavePage` in load mode.
- Modify: `scripts/UI/PauseMenu.gd`: `NAMES` becomes `["Resume", "Save", "Load", "Settings", "Main menu", "Quit"]` and `QUESTIONS` becomes `{4: "Main menu?", 5: "Quit?"}` (the questions move into SaveWords).
  - **Save:** opens a `SavePage` in save mode. Choosing a slot calls `SaveGame.request_save(&"named", "", slot)`. The picture is the frame grabbed as the pause opened.
  - **Load:** opens a `SavePage` in load mode, and `load_chosen` calls `SaveGame.load_slot`.
  - The pause menu's own colours become a 6-entry list reusing the main menu's.
- Modify: `scripts/UI/StealthHUD.gd`: when the pause is asked for, hide the HUD root, wait for `frame_post_draw`, grab the frame into `SaveGame.paused_frame: Image`, then open the pause.
- Test: `tests/save_pages_test.gd` and `.tscn`, `P1`–`P7`

- [ ] **Step 1: Write the failing tests.**
  - `P1`: the Load page with two runs lists the last-played run first and open, with its saves newest first.
  - `P2`: choosing a save emits `load_chosen` with its run and slot.
  - `P3`: deleting asks first. Yes removes the files, and No leaves them.
  - `P4`: the Save page's new row writes `named_1`, and choosing it again asks before overwriting.
  - `P5`: the pause menu shows six words, and Escape folds back from a SavePage to the words, then resumes.
  - `P6`: Load from the pause menu leaves the loaded game unpaused, with the pause menu gone and the mouse captured.
  - `P7`: a run holding a truncated save lists it greyed, and nothing errors.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the tests.** Expected: `P1`–`P7` PASS, and the pause and menu suites as at the baseline, updated only for the new words' indices.
- [ ] **Step 5: Commit.** Message: `feat(save): the Load and Save pages, in the menu and the pause`.

### Task 10: The death page

**Files:**
- Create: `scripts/UI/DeathPage.gd` (`extends Control`): three MenuWords, `SaveWords.LOAD_LATEST`, `SaveWords.LOAD`, `SaveWords.MAIN_MENU`, over the HUD's existing death dimming, in the pause menu's layout.
  - Load latest loads `SaveFiles.newest_save(run)`.
  - Load opens a `SavePage` in load mode.
  - Main menu leaves through the cover, as PauseMenu does.
  - With no save in the run, Load latest restarts the map: `reload_current_scene()`, as today.
- Modify: `scripts/PlayerController.gd` `_die()`: with `reload_on_death`, after the existing 2 s it emits `died` and leaves the reload to the HUD's DeathPage. Without a HUD (tests, gyms), it keeps today's reload.
- Modify: `scripts/UI/StealthHUD.gd`: shows the DeathPage on `player.died` after the 2 s, with the mouse visible.
- Test: `tests/save_pages_test.gd` `P8`–`P10`

- [ ] **Step 1: Write the failing tests.**
  - `P8`: dying with a save in the run shows the death page after 2 s, and Load latest loads it.
  - `P9`: dying with no save restarts the map.
  - `P10`: saving while dead is held, and the death page's Load works.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the tests.** Expected: `P8`–`P10` PASS. Any suite relying on `reload_on_death` (the stealth and combat suites) stays as at the baseline.
- [ ] **Step 5: Commit.** Message: `feat(save): the death page`.

### Task 11: The guide, the full run, the review

**Files:**
- Create: `docs/systems/saving.md`, the developer's guide:
  - the contract (`register`, `save_state`/`load_state`, `save_id`, `register_global`)
  - the order of apply
  - the rule that no gameplay code waits on an unsaved timer (stage 2 enforces it)
  - how to add a script to `stateless.txt`/`stage2.txt`
  - how to bump `SaveMigrations.CURRENT`
- Modify: `docs/systems/README.md`, to link it.

- [ ] **Step 1: Write the guide.**
- [ ] **Step 2: Run every suite headless** and compare against the Task 0 baseline in the ledger. Expected: no new failures; the new suites `save_files_test`, `save_test`, `save_coverage_test` and `save_pages_test` are all green.
- [ ] **Step 3: Request the final review.** One fresh reviewer on the most capable model checks the whole branch against the spec (superpowers:requesting-code-review). Fix its findings test-first.
- [ ] **Step 4: Commit.** Message: `docs: saving`. Don't merge the branch: the user plays it first. To play: New Game, play, quicksave, quit to the menu, Continue.
