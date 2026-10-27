# Saving and loading

The design is [2026-10-26-save-and-load-design.md](../superpowers/specs/2026-10-26-save-and-load-design.md). This guide is for anyone adding a system: how its state gets into a save, and how it comes back.

Stage 1 (this build) restores outcomes and memory exactly: what is open, taken or down, what people remember, the player's place and kit, every schedule in the playable maps. Stage 2 adds the live layer (a fight mid-swing, spells in flight, animation). Until then, what `data/save/stage2.txt` lists comes back settled.

## The pieces

| Piece | What it does |
| --- | --- |
| `scripts/Save/SaveGame.gd` (autoload `SaveGame`) | Keeps who saves, gathers a save, applies one, holds saves while they may not happen, quicksave, quickload, the arrival autosave, runs. |
| `scripts/Save/SaveFiles.gd` | The disk: runs, slots, headers, writing through `.tmp` and a rename, deleting, Continue's choice. Safe on a worker thread. |
| `scripts/Save/SaveMigrations.gd` | `CURRENT` (the save version) and the steps that bring an older save's body up to it. |
| `scripts/Save/SaveFields.gd` | `save_state`/`load_state` for a script whose state is a few plain fields. |
| `scripts/Save/SaveWords.gd` | Every word the player reads about saving: stand-ins for the user to write. |
| `scripts/UI/SavePage.gd` | The Load and Save pages (the main menu's Load, the pause's Save and Load, the death page's Load). |
| `scripts/UI/DeathPage.gd` | Load latest, Load, Main menu, after death. |

## Making a script save

1. In `_ready`, register:

   ```gdscript
   var save := get_node_or_null("/root/SaveGame")

   if save != null:
       save.register(self)
   ```

2. Answer `save_state() -> Dictionary` and `load_state(state: Dictionary) -> void`.
   - Keep plain values only: numbers, `String`, `StringName`, vectors, `Transform3D`, `Quaternion`, `Color`, `AABB`, and arrays and dictionaries of these. Never a `Node` or a `Resource`: name it (its id, or an index into something rebuilt the same way) instead.
   - `load_state` runs on a freshly built copy (the map's own code has made it, with its seeds), before the first frame plays. Accept a state with keys missing: fall back to what the build gave.
   - For a few plain fields, use `SaveFields`:

     ```gdscript
     const SaveFields := preload("res://scripts/Save/SaveFields.gd")
     const SAVED := ["_next", "_clock", "_rng"]

     func save_state() -> Dictionary:
         return SaveFields.save(self, SAVED)

     func load_state(state: Dictionary) -> void:
         SaveFields.restore(self, state, SAVED)
     ```

     A `RandomNumberGenerator` field is kept as its `state`, so its dice carry on. A misspelt field is reported (`SaveFields.missing`; the save suite fails on any).
3. **Its id** is its path from the current scene, so its name must be its own: a name Godot makes up (`@Node3D@123`) changes every build. The coverage suite fails on one. A node whose path is not stable answers `save_id() -> String`.
4. **Taken, broken, killed:** a registered node freed with `queue_free` while its map plays on is remembered as gone, and freed again on the next build of the map.
5. **State outside the map** (an autoload, statics) registers with `SaveGame.register_global(name, holder)`.

The order a save is applied in: `CityState`, then what is gone, then the things in the map (tree order), then the player (`load_state`, then `load_place`), then the globals.

## The rules

- **Gameplay never waits on a timer that is not saved.** An `await get_tree().create_timer(...)` cannot be saved: keep the deadline as a field and check it each frame. (Stage 2 turns the few that exist into deadlines.)
- **A signal fired on a phase change** (a train's `began`, a book's `opened`) must not fire again on load: save the field that marks the phase (`_peaked`, `_was_open`).
- **Saving is held** while the player talks, is dead, the loading cover is up, or anything has called `SaveGame.hold(reason)` (until `release(reason)`): a scripted moment holds it. A request made then is kept and happens when it may.

## Coverage

`tests/save_coverage_test` builds the Metro (with the candle lane and the Pasaje) and the Zócalo and checks every node with a script. Each one must be registered (or be the player or something of his), or have its script listed:

- in `data/save/stateless.txt`, with why it holds nothing a save needs;
- in `data/save/stage2.txt`, with what stage 2 adds.

A new script with state in those maps fails the suite until it saves or is listed with a reason.

## Versions

Each save's header carries the version it was written at.

- **Bump `SaveMigrations.CURRENT`** when a `save_state` changes what one of its keys means. Add a step to `STEPS` that turns a body of the old version into the new.
- **No bump is needed** for a new key with a default in `load_state`.
- **Older saves:** `tests/fixtures/save/v1.save` must keep loading after every bump (`save_files_test` F13).
- **Newer saves:** a save from a newer build is refused, never half read.

## Runs and slots

A run begins when New Game's archetype is confirmed (`SaveGame.begin_run`). Its saves live in `user://saves/<run>/`:

- **Quick:** `quick_1..3`, the oldest written over.
- **Auto:** `auto_1..3`, written on arriving in a map of the game, not by a load.
- **Named:** `named_<n>`, from the Save page.

Continue loads the newest save of the run played last (`user://saves/last_run`). A test run keeps its saves in `user://test_saves`.

## The suites

| Suite | What it proves |
| --- | --- |
| `save_files_test` | The disk: runs, rotation, the header read alone, unwritable, truncated, newer and version-1 saves (F1-F13). |
| `save_test` | Gathering and applying; the player and the things that saved before; the Metro and Zócalo round trips; schedules carrying on (G1-G18). |
| `save_coverage_test` | Nothing unsaved without a reason; every saved thing named (V1-V4). |
| `save_keys_test` | Quicksave, quickload, the arrival autosave, held saves, a failed write, speed, the write off the main thread (K1-K8). |
| `save_menu_test` | New Game's run, Continue, the main menu's Load (M1-M4). |
| `save_pages_test` | The pages, the pause's Save and Load, a load from the pause, the death page (P1-P10). |
