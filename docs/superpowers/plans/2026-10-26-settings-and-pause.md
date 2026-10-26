# Settings and Pause Menu (Piece 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One shared Settings page (Audio, Video, Controls, Interface & comfort) behind a persistent settings store, and an in-game pause menu in the main menu's style.

**Architecture:** `GameSettings` is a static store, like `Settings.gd` today: values, `user://settings.cfg`, defaults and applying the global ones (buses, window, InputMap). It has an `events()` notifier whose `changed(key)` signal the live consumers follow: the camera juice, player, Retro and HUD. `Settings.gd` becomes a thin layer over it. `SettingsPage` is the one page UI. `PauseMenu` replaces the HUD's pause screen.

**Tech Stack:** Godot 4.5.1 GDScript, headless suites plus native captures.

**Spec:** `docs/superpowers/specs/2026-10-26-settings-and-pause-design.md`

## Global Constraints

- **Rulings on the spec:**
  - `GameSettings` is a static store, not an autoload. It loads on first access and Retro, an autoload, touches it at boot.
  - It needs no change to `project.godot`, and it works in `--script` tests where autoloads are missing.
- **Config keys:**
  - kept: `audio/master_volume`, `hud/awareness_marks`
  - new: `audio/music`, `audio/effects`, `audio/ambience`, `audio/souls`, `video/window` (0 windowed, 1 borderless, 2 fullscreen), `video/vsync`, `video/fps` (0 = unlimited), `video/brightness`, `video/fov`, `video/grid`, `controls/sensitivity`, `controls/invert`, `hud/subtitles`, `hud/subtitle_size` (0, 1, 2), `hud/crosshair`, `comfort/camera_motion`
  - key bindings: section `keys`, each value written as `key:<physical keycode>` or `mouse:<button>`
- **Ranges:**
  - volumes 0–1
  - brightness 0.5–1.5
  - fov 60–100 (default 75)
  - fps one of 30, 60, 120, 144, 0
  - grid one of 480, 360, 240, 0
  - sensitivity 0.25–3.0
  - camera motion 0–1
- **Buses:** each slider sets `bus base dB + linear_to_db(value)`, where the base is the bus's level when it was first seen. Buses created later are applied through `AudioServer.bus_layout_changed`.
  - Effects is World, WorldFar and Body; Souls is Souls; Music is Music.
- **Actions:** move_forward, move_back, move_left, move_right, jump, sprint, crouch, frob, inventory, throw, block, kick, dodge, lean_left, lean_right, belt_next, belt_prev.
- **Your uncommitted edits:** `StealthHUD.gd` and `PlayerController.gd` hold your uncommitted work. Only my hunks are staged, from the base copies in the workspace.
- **Never:** push, or commit anything outside this plan's paths.

## Review Focus

1. **A corrupt or hand-edited config** (wrong types, out of range, an unknown key name): it falls back to defaults per key, without errors. Test in Task 1.
2. **Rebinding onto a key another action uses:** the two swap, and no action is left unbound. Test in Task 1.
3. **Esc while the Settings page is open in the pause menu:** it folds the page back first; a second Esc resumes. Test in Task 4.
4. **Leaving to the main menu from the pause menu:** the tree is unpaused and the mouse is visible on the menu. Test in Task 4.
5. **The window mode in headless runs:** applying the window mode is skipped when the display is headless, so the suites don't error. Test in Task 1.

---

### Task 1: GameSettings store

**Files:**
- Create: `scripts/Settings/GameSettings.gd` (`class_name GameSettings`)
- Modify: `scripts/UI/Settings.gd`, which delegates
- Test: `tests/settings_test.gd` / `.tscn`

**Interfaces:**
- Produces:
  - `static var path`
  - `static func reload()`
  - `static func value(key: String) -> Variant`
  - `static func set_value(key: String, v: Variant) -> void`, which clamps, applies, saves and emits
  - `static func events() -> RefCounted` (signal `changed(key: String)`)
  - `const ACTIONS`
  - `static func bind(action: StringName, event: InputEvent) -> StringName`, which returns the action it swapped with, or `&""`
  - `static func reset_keys()`
  - `static func key_name(action: StringName) -> String`
  - `static func look_scale() -> float`, sensitivity times 0.002 over 0.002, so 1.0 at default

- [ ] **Step 1: Failing tests:**
  - defaults
  - a round-trip of every key through a reload
  - clamping and validation, including a corrupt file
  - the master and music sliders reach their buses relative to the base
  - a bus created after load is applied
  - bind swaps a clash and persists; reset_keys
  - `Settings.master_volume()` and `awareness_marks()` still agree with the store
- [ ] **Step 2:** Implement.
- [ ] **Step 3:** The suite passes, and `main_menu_test` and `stealth_test` stay green.
- [ ] **Step 4:** Commit as `feat(settings): one settings store for the whole game`.

### Task 2: SettingsPage

**Files:**
- Create: `scripts/UI/SettingsPage.gd`
- Modify: `scripts/UI/MenuPages.gd`, whose Settings body becomes a SettingsPage
- Test: `tests/main_menu_test.gd`

**Behaviour:**
- **Tabs:** Audio, Video, Controls, Interface, as small-caps words; the chosen one is lit.
- **Rows:** a label on the left and a control on the right.
  - Sliders are the existing brush strokes.
  - Cyclers read "‹ value ›" and change with Left/Right or a click.
  - Switches show On / Off.
  - Key rows read "Press a key…" while capturing.
- **Navigation:** Up/Down move between rows, Tab or Q/E switch tabs, Esc folds the page.

- [ ] **Step 1: Failing tests:**
  - four tabs
  - each tab's rows and their values from the store
  - a slider and a cycler change the store
  - a key row captures the next key, and Esc cancels the capture
  - the old checks (painted controls, volume persistence) still hold
- [ ] **Step 2:** Implement.
- [ ] **Step 3:** Run the suite.
- [ ] **Step 4:** Commit as `feat(settings): the settings book page`.

### Task 3: Hooks

**Files:**
- Modify:
  - `scripts/PlayerUtils/CameraJuice.gd`: `base_fov` and `intensity` follow fov and camera motion
  - `scripts/PlayerController.gd`: look scale and invert, in the mouse block only
  - `scripts/Visual/Retro.gd`: the grid follows the setting, F6 writes it back, and a brightness pass
  - `scripts/UI/StealthHUD.gd`: subtitles on/off and size, crosshair on/off
- Test: `tests/settings_test.gd`, against a test player and HUD scene

- [ ] **Step 1: Failing tests:**
  - changing fov and camera motion updates a live CameraJuice
  - invert flips pitch
  - sensitivity scales turning
  - the grid setting sets Retro's `virtual_height`
  - brightness sets the pass's uniform
  - subtitles off hides them, and their size changes the font size
  - crosshair off hides it
- [ ] **Step 2:** Implement.
- [ ] **Step 3:** Run the suites: settings, stealth, interaction.
- [ ] **Step 4:** Commit only my hunks, as `feat(settings): the settings reach the player, camera, screen and HUD`.

### Task 4: PauseMenu

**Files:**
- Create: `scripts/UI/PauseMenu.gd`
- Modify: `scripts/UI/StealthHUD.gd`, replacing `_build_pause` and its input with the PauseMenu
- Test: a new `tests/pause_menu_test.gd`; `tests/interaction_test.gd` U7 and U13 move to the new menu

**Behaviour:**
- Esc pauses and shows the menu: the title, the words, a dim veil over the frozen frame.
- Resume unpauses and recaptures.
- Settings opens the SettingsPage; Esc folds it, then a second Esc resumes.
- Main menu asks, then on Yes unpauses and changes to `main_menu.tscn` through ArtLoading.
- Quit asks, then on Yes calls `quit_game`, which a test can replace.
- A click on the veil no longer resumes.

- [ ] **Step 1: Failing tests:** each of the above, plus Review Focus 3 and 4.
- [ ] **Step 2:** Implement.
- [ ] **Step 3:** Run the suites: pause, interaction, stealth, main menu.
- [ ] **Step 4:** Commit only my hunks, as `feat(pause): the pause menu`.

### Task 5: Captures, docs, review

- [ ] Native captures: the Settings page (each tab) and the pause menu over the Metro.
- [ ] Update `docs/systems/main-menu.md` with the settings and pause sections.
- [ ] A final review on the most capable model.
- [ ] Fix Critical and Important findings test-first, then commit.
