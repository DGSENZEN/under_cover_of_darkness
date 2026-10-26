# Settings and the pause menu (piece 4 of 4)

Date: 2026-10-26. Status: design for approval.

Part of the main menu overhaul (`2026-10-25-main-menu-overhaul-design.md`), after pieces 1–3.

## Why

The game has no real settings. The menu's Settings page holds a master volume and the awareness marks. In play, Esc shows a plain "Paused" screen with that one switch, and a click anywhere resumes. Players need proper audio, video, controls and comfort settings, and a pause menu that belongs to the game's look.

## What the user decided

- **Settings:** four groups, Audio, Video, Controls, and Interface & comfort.
- **Pause menu:** like the main menu. The frozen game dims behind the title and the same small-caps word column: Resume, Settings, Main menu, Quit. Settings opens the same book page as on the main menu.

## Goals

- **One Settings page for both menus.** It's in the piece 1 book style: Cormorant small-caps headings, gold hairlines, brush-stroke sliders. The four groups are tabs written as small-caps words along its top.
- **Changes apply at once and persist** in `user://settings.cfg`, and are applied at start-up before any scene runs.
- **The pause menu:**
  - Esc in play opens it over the frozen game; Esc again resumes.
  - Main menu and Quit each ask first, in the Quit confirm's style.
  - It has the main menu's motion and hover jingles. The music is the level's own, paused with the game.
- **Keyboard and mouse both work everywhere:** up/down moves between rows, left/right changes a value, Enter toggles, Esc backs out.

## Non-goals

- Controller support and rebinding.
- Save slots. Continue stays as it is.
- A graphics quality preset system. Only the options below.

## The settings

**Audio.** Each is a slider, 0–100%.
- **Master:** the Master bus.
- **Music:** the Music bus, which also carries the menu song and its jingles.
- **Effects:** the World, WorldFar and Body buses.
- **Ambience:** the Ambience bus.
- **Voices and souls:** the Souls bus. If voices get their own bus later, they join this slider.

**Video.**
- **Window:** Windowed, Borderless, Fullscreen.
- **VSync:** On, Off.
- **Frame limit:** 30, 60, 120, 144, or Unlimited.
- **Brightness:** 50–150%. A gamma lift on the final image, the same in every map.
- **Field of view:** 60–100°, 75 by default. This is CameraJuice's `base_fov`.
- **Pixel grid:** 480, 360, 240, or Off. Retro's `virtual_height`, the same four steps as F6.

**Controls.**
- **Mouse sensitivity:** a slider, 25–300% of today's 0.002.
- **Invert look:** On, Off.
- **Keys:** a row for every game action, each showing its key. Select a row and the next key or mouse button pressed is bound to it. Esc cancels. A key already used by another action swaps with it. "Reset keys" restores the defaults.
  - The actions: move forward, back, left, right; jump; sprint; crouch; frob; inventory; throw; block; kick; dodge; lean left, lean right; belt next, belt previous.

**Interface and comfort.**
- **Awareness marks:** On, Off (moved from the old pages).
- **Subtitles:** On, Off.
- **Subtitle size:** Small, Medium, Large.
- **Crosshair:** On, Off.
- **Camera motion:** 0–100%. Scales head bob, landing dips, sprint field-of-view push and shake together, through CameraJuice's `intensity` and its bob.

## Approaches

1. **A `GameSettings` autoload that owns the values and applies them, with the UI as a view (recommended).**
   - It holds every value, reads and writes the config, and applies them to the buses, window, InputMap and Retro at start-up.
   - It also applies them to each player camera and HUD as they enter the tree, through groups or signals.
   - The Settings page and pause menu only read and set it. One source of truth, and tests can drive it without UI.
2. **Grow the existing `Settings.gd` static class.** That keeps the file, but static classes can't watch the tree or apply to new scenes, so every map would have to remember to apply them. Rejected.
3. **A separate settings screen per menu.** Two UIs drift apart. Rejected; the user wants the same page.

`Settings.gd`'s current API (`master_volume`, `awareness_marks`, `path`, `reload`) stays as a thin layer over the autoload's values. The existing callers and tests keep working, and the config file keeps its keys: `audio/master_volume` and `hud/awareness_marks`.

## The pause menu

- **Where it lives:** a `PauseMenu` CanvasLayer added by the HUD (StealthHUD), replacing its plain pause screen. The HUD keeps hiding its play layer while paused.
- **Opening:** Esc in play, through the player's existing `ui_cancel` handling, pauses the tree and frees the mouse.
- **What you see:**
  - the dimmed, slightly blurred frozen frame
  - the title and its hairline (top left)
  - the word column (Resume, Settings, Main menu, Quit)
  - the same washes and press-in as the main menu
- **Resume** recaptures the mouse and unpauses. A click on the game no longer resumes, because the words are there to click.
- **Settings** opens the shared Settings page; Esc folds it back.
- **Main menu** asks first. Yes leaves through the loading cover to `main_menu.tscn` and unpauses.
- **Quit** asks first. Yes quits.
- **Talking:** when a talk is in progress (TalkBox), Esc still pauses. The talk resumes as it was.

## Changes in the code

- **New:**
  - `scripts/Settings/GameSettings.gd`, an autoload: values, persistence, applying, and defaults.
  - `scripts/UI/SettingsPage.gd`, the shared page: tabs, rows, sliders, cyclers, switches and key capture, built in code like MenuPages.
  - `scripts/UI/PauseMenu.gd`.
- **Changed:**
  - `MenuPages`: the Settings page becomes `SettingsPage`.
  - `StealthHUD`: the pause screen becomes `PauseMenu`; subtitles, subtitle size and crosshair follow the settings.
  - `PlayerController`: sensitivity and invert, and Esc opens the pause menu.
  - `CameraJuice`: FOV and camera motion.
  - `Retro`: the pixel grid level, and the brightness lift on its screen pass, or on its own layer when the grid is off.
  - `project.godot`: the autoload.
- **Tests:**
  - a headless settings suite: defaults, persistence round-trip, applying to buses, window flags and InputMap, rebinding swaps, the reset
  - a pause menu suite: open, resume, confirms, back to the menu
  - the existing menu suites stay green
  - a native capture of the Settings page (each tab) and the pause menu over a level

## Left to the builder

- Row layout, spacing and the slider and cycler drawing, in the piece 1 style.
- How a brightness lift is drawn (a screen-space gamma pass).
- Key names as shown ("W", "Space", "Mouse 1").
- The order of rows within a tab.
