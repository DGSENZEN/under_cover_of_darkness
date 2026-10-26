# Main Menu Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the painted-card grid with a spaced word column whose selection is a glazed, torn-edged band of painting over a still, living city, scored by the user's menu song as four live-mixed layers with chord-aware per-button jingles.

**Architecture:** `MainMenu.gd` stays the code-built CanvasLayer and owns four `MenuWord` buttons, one `MenuBand` (the selection and the open page), and a `LivingCity` background. A new `MenuMusic` node lives under the tree root (so it outlives the menu during New Game). It plays the song's stems through one `AudioStreamSynchronized`, keeps a latency-corrected musical clock (`MenuClock`, pure static functions), weights four layers per menu state, and plays jingles. A new `tools/prepare_menu_score.py` turns Logic exports plus a hand-written `map.json` into Godot clips and `score.json`.

**Tech Stack:** Godot 4.5.1 (GDScript, canvas_item shaders), Python 3 (numpy, Pillow, ffmpeg, libsndfile via the same approach as `tools/prepare_score.py`, mido for MIDI), Logic Pro driven on screen together with the user.

**Spec:** `docs/superpowers/specs/2026-10-25-main-menu-overhaul-design.md` (read it; this plan argues from it). Mockups: `.superpowers/brainstorm/27138-1792977562/content/menu-layouts.html` (layout A), `menu-selection-v2.html` (band 2b). These are local only, not in git.

## Global Constraints

- **Godot binary:** `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`.
- **Headless suites:** `"$GODOT" --headless --fixed-fps 60 --path . res://tests/<name>.tscn`. Pass means every line is `PASS` before `==== RESULTS ====`, and the exit code is 0.
- **Native captures:** `"$GODOT" --path . --script res://tests/visual/main_menu_preview.gd`. Captures go to `/private/tmp/main-menu-*.png`.
- **Design area:** 1600×900, scaled to the window (`MainMenu._layout`).
- **Choice order:** New Game, Continue, Settings, Lore.
- **Choice colours:** `ef774c`, `67c9ed`, `929fdb`, `efa25e`.
- **Title:** "UNDER COVER" / "OF DARKNESS", same serif `SystemFont` as today.
- **Your art is never edited.** Never edit `city.png` or `buttons.png`. Crops are runtime `AtlasTexture` regions. Masks are separate derived files.
- **No downloaded VFX textures.** Masks and noise are made by script or by Godot `NoiseTexture2D`.
- **No procedural audio.** Every sound comes from the user's Logic exports.
- **Jingle timing:**
  - Hover jingle: the same frame as the hover.
  - Press jingle: the next eighth-note boundary, at most one frame late.
- **Layer names:** `&"base"`, `&"low"`, `&"high"`, `&"fx"`.
- **Bus:** music plays on `Sfx.BUS_MUSIC`, falling back to `&"Master"` if that bus is missing.
- **Judging UI:** UI is judged only in the real menu scene, never over a mock backdrop.
- **Visual faults:** never call one harmless. Fix it, or name it as unfinished.
- **Song decisions:** every musical decision is approved by the user by ear before it is kept. Claude cannot hear audio.
- **Commits:** end every commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Mouse and keyboard disagree.** Keyboard focus is on New Game and the mouse then enters Lore. Expected: exactly one selection, following the most recent input, so one band and one jingle. Test in Task 1.
2. **The window resizes while a band or page is showing** (16:9 → 21:9 → 4:3). Expected: the band stays centred on its word, and the page stays in the right two-thirds. Test in Task 2.
3. **Rapid hover spam across all four words.** Expected: no jingle pile-up (voice limit) and no band lag; the band always ends on the last word. Test in Task 9.
4. **New Game is pressed twice, or another word is pressed while starting.** Expected: ignored, with one loading cover and one ending. Test in Task 10.
5. **The menu score files are missing** (before Task 6 runs, or after a broken export). Expected: the menu works silently, with no script errors, and `layer_energy` returns 0. Test in Task 8.

---

## Part 0 — Baseline

### Task 0: Commit the current menu as the baseline

The current menu, `ArtLoadingScreen` and the Metro integration are untracked on `free-run`. Without a baseline commit, the overhaul's diffs can't be reviewed.

- [ ] **Step 1:** Ask the user to approve committing the existing menu work. Show `git status --short` filtered to `main_menu.tscn scripts/UI scripts/Audio tests/*menu* tests/visual/main_menu_preview.gd assets/ui/main_menu docs/systems/main-menu.md`.
- [ ] **Step 2:** On approval, commit exactly those paths as `feat(menu): painted main menu baseline`. On refusal, stop and ask how they want to proceed. Don't work on top of untracked files.
- [ ] **Step 3:** Run `main_menu_test.tscn` and record its pass count in the task notes. It is the regression baseline.

---

## Part A — The screen

### Task 1: The word column and selection

**Files:**
- Create: `scripts/UI/MenuWord.gd` (replaces `PaintedMenuButton.gd`, which is deleted in this task along with `painted_button.gdshader`)
- Modify: `scripts/UI/MainMenu.gd`
- Test: `tests/main_menu_test.gd` (rewrite the checks that referenced `buttons`/`paint`/`music_marker`; keep the Settings/Lore/Continue checks for Task 3)

**Interfaces:**
- Produces:
  - `class_name MenuWord extends Button`
  - `func configure(caption: String, index: int, colour: Color, font: Font) -> void`
  - `var index: int`
  - `var colour: Color`
  - `func set_selected(on: bool) -> void`
  - `signal chosen(index: int)`: emitted on mouse enter or focus enter
- Produces (`MainMenu.gd`):
  - `var words: Array[MenuWord]`
  - `var selected := -1`
  - `signal selection_changed(index: int)`
  - `func select(index: int) -> void`: the single path for mouse, keyboard and controller
- Values:
  - Words at x = 72 design px, starting y = 360, gap 64 design px between word centres. *(From the mockup: 2.4% of width plus line height. Tune by eye, but keep at least 56.)*
  - Font size 34, letter spacing via `theme_override_constants/outline_size` 0 and uppercase text.
  - Unselected alpha 0.6. Selected: alpha 1, white, +8 px x offset.
  - Tick: 4×(0.64 × height) px in `colour`.

- [ ] **Step 1: Write the failing tests** in `tests/main_menu_test.gd`:

```gdscript
check(menu.words.size() == 4 and menu.words.map(func(w): return w.text) == ["NEW GAME", "CONTINUE", "SETTINGS", "LORE"], "four words in reading order")
check(menu.words[1].position.y - menu.words[0].position.y >= 56.0, "words have room between them")
check(menu.words.all(func(w): return is_equal_approx(w.position.x, menu.words[0].position.x)), "words sit in one column")
check(menu.selected == -1, "nothing is selected before input")
await key(KEY_DOWN)
check(menu.selected == 0 and menu.words[0].has_focus(), "first key press selects New Game")
await key(KEY_DOWN)
check(menu.selected == 1, "down moves through the column")
await key(KEY_UP)
await key(KEY_UP)
check(menu.selected == 0, "up stops at the top, no wrap")
menu.words[3].mouse_entered.emit()
check(menu.selected == 3 and menu.words.filter(func(w): return w.modulate.a > 0.9).size() == 1, "mouse after keyboard: one selection, the latest")   # Review Focus 1
```

  `key(code)` pushes press/release `InputEventKey`s through `get_viewport().push_input` and awaits a frame. Copy it from `tests/visual/main_menu_preview.gd`.

- [ ] **Step 2: Run the suite and check it fails.** Expected: FAIL on "four words in reading order" (`words` missing).
- [ ] **Step 3: Implement `MenuWord` and the column in `MainMenu.gd`.**
  - Remove the 2×2 grid, `music_marker`, `PaintedMenuButton` and its shader.
  - Focus neighbours are top and bottom only.
  - Make `select()` idempotent. It deselects the others, then emits `selection_changed`.
  - Keep `_unhandled_key_input`'s "first key selects New Game" behaviour.
- [ ] **Step 4: Run the suite and check it passes.** Expected: all PASS. The Settings/Lore/Continue checks are temporarily marked `# Task 3` and skipped.
- [ ] **Step 5: Commit** as `feat(menu): word column with one selection path`.

### Task 2: The painted band

**Files:**
- Create: `scripts/UI/MenuBand.gd`, `scripts/UI/menu_band.gdshader`
- Modify: `scripts/UI/MainMenu.gd` (add the band below the words, connect `selection_changed`, dim the city)
- Test: `tests/main_menu_test.gd`

**Interfaces:**
- Consumes: `MainMenu.selection_changed(index)`, `MenuWord.colour`
- Produces:
  - `class_name MenuBand extends Control`
  - `func show_choice(index: int, word_centre_y: float) -> void`
  - `func hide_band() -> void`
  - `func set_page(on: bool) -> void`
  - `func pulse() -> void`
  - `var showing := false`
  - `var page := false`
  - `const ART_WIDTH := 780.0` (design px)
  - `static func boil_step(t: float) -> int`, which returns `floori(t * BOIL_FPS)` with `BOIL_FPS := 9.0`
  - `func band_rect() -> Rect2` (design px, current target)
- Produces (`MainMenu.gd`):
  - `var band: MenuBand`
  - `func city_dim() -> float`, which is 1.0 normally and 0.72 while `band.showing`, eased over 0.5 s
- Values:
  - **Band rect:**
    - choice mode: `Rect2(0, word_centre_y - 180, 1440, 360)`, i.e. 40% of 900 tall and 90% wide
    - page mode: `Rect2(530, 0, 1070, 900)`, the right two-thirds
  - **Motion:**
    - glide: 0.5 s ease-out (`Tween.TRANS_CUBIC`, `EASE_OUT`)
    - cross-fade: 0.6 s
    - drift: 18 s ping-pong, scale 1.04→1.08 and pan ±1.2%
  - **Glaze:** wash at 0.28 in the choice colour (`mix` in `color` blend), saturation 0.7, brightness 0.9, and a warm glow `vec3(1.0, 0.55, 0.27) * 0.18` at band uv (0.7, 0.5).
  - **Readability:** dark word end, alpha 0.88 at u=0 down to 0 at u=0.42.
  - **Art crops:** `ART_REGIONS: Array[Rect2i]` inside each illustration's painted rim in `buttons.png`. Measure them in this task by finding the rim's inner edge, and print them in the test. Vertical focus per illustration: `ART_FOCUS := [0.28, 0.42, 0.38, 0.30]`. The art area is right-aligned in the band, `ART_WIDTH` wide, and never upscaled beyond ART_WIDTH / region width.
  - **Shader:** torn edges with the noise UV offset by a hash of `boil_step(TIME)`, so the edges change in steps, never continuously. Never displace the art UVs.

- [ ] **Step 1: Write the failing tests:**

```gdscript
check(not menu.band.showing, "no band before input")
menu.select(2)
await get_tree().create_timer(0.7).timeout
var r: Rect2 = menu.band.band_rect()
var wc := menu.words[2].position.y + menu.words[2].size.y * 0.5
check(absf(r.get_center().y - wc) < 2.0 and is_equal_approx(r.size.y, 360.0), "band is centred on the selected word")
check(menu.band.material.get_shader_parameter("glaze").is_equal_approx(Color("929fdb")) and is_equal_approx(menu.band.material.get_shader_parameter("glaze_amount"), 0.28), "band is glazed in its choice's colour")
check(MenuBand.boil_step(0.0) == MenuBand.boil_step(0.1) and MenuBand.boil_step(0.0) != MenuBand.boil_step(0.12), "edges boil in steps at ~9 fps")
check(menu.band.art_scale(2) <= MenuBand.ART_WIDTH / float(MenuBand.ART_REGIONS[2].size.x) + 0.001, "art never wider than ART_WIDTH")
check(is_equal_approx(menu.city_dim(), 0.72), "city dims behind the band")
menu.select(3)
check(menu.band.material.get_shader_parameter("mix_ab") < 0.5, "art cross-fades, not re-wiped")
for size in [Vector2i(2560, 1080), Vector2i(1024, 768)]:   # Review Focus 2
    get_window().size = size
    await get_tree().process_frame
    var c := menu.band.get_global_rect().get_center().y
    var w := menu.words[3].get_global_rect().get_center().y
    check(absf(c - w) < 3.0, "band stays on its word at %s" % size)
```

  `art_scale(index) -> float` is a small public helper on `MenuBand` that returns the displayed art width divided by the region width. Add it to the Interfaces as part of this task.

- [ ] **Step 2: Run the tests and check they fail.** Expected: FAIL at "no band before input" (`band` missing).
- [ ] **Step 3: Implement `MenuBand.gd` and `menu_band.gdshader`** with the values above.
  - Uniforms: `art_a`, `art_b`, `mix_ab`, `art_rect_a`, `art_rect_b` (uv sub-rects of the atlas), `focus_a`, `focus_b`, `glaze`, `glaze_amount`, `page` (0..1), `pulse`, `noise` (`NoiseTexture2D`, seamless, generated in code).
  - The city dims through the background material's `dim` uniform. Task 4 creates that material, so until then apply `modulate` on the background `TextureRect`.
- [ ] **Step 4: Run the tests and check they pass.**
- [ ] **Step 5: Native look check.** Run the preview script. Add captures: `main-menu-band-<i>.png` for each choice, plus `main-menu-band-edge.png`, a 400×300 crop of the band's torn right end. Open them and compare with `menu-selection-v2.html` option 2b. Fix any hard edge, seam, smear of the art or banding before going on.
- [ ] **Step 6: Commit** as `feat(menu): glazed painted selection band`.

### Task 3: Pages in the band (Settings, Lore, Continue)

**Files:**
- Create: `scripts/UI/MenuPages.gd` (builds page content: Lore text, painted Settings controls, Continue line, Back word)
- Modify: `scripts/UI/MainMenu.gd` (replace `_build_panel`/`_show_panel` and the grey `PanelContainer`)
- Test: `tests/main_menu_test.gd` (re-enable the Task 1 skipped checks against the new API)

**Interfaces:**
- Consumes: `MenuBand.set_page(on)`, `MainMenu.words`
- Produces (`MainMenu.gd`):
  - `var page_open := -1`
  - `func open_page(index: int) -> void`
  - `func close_page() -> void`
  - `var pages: MenuPages`
- Produces (`MenuPages.gd`):
  - `class_name MenuPages extends Control`
  - `func show_page(index: int) -> void`
  - `var title_label: Label`
  - `var body_label: Label`
  - `var volume: HSlider` (node name "Volume")
  - `var marks: CheckButton`
  - `var back: MenuWord`
- Values:
  - **Page text area:** design rect `Rect2(600, 110, 900, 680)`, over the expanded band.
  - **Scrim:** a dark scrim behind the text where needed, about `Color(0.01, 0.02, 0.03, 0.55)` in a feathered rect.
  - **Other words:** alpha 0.35 while a page is open.
  - **Continue copy:** "No saved game yet. Choose New Game to begin."
  - **Lore:** keeps the existing `LORE` text.
  - **Settings controls:** they keep their behaviour and get theme overrides. The track is a brush-stroke `StyleBoxTexture` from a small generated `ImageTexture` (rough-edged strip, our own). The grabber is a pigment dab in the Settings colour. There must be no default-theme look.

- [ ] **Step 1: Write the failing tests.** Port the existing Continue, Settings volume/awareness persistence and Lore checks to `open_page(i)`/`close_page()`, then add:

```gdscript
menu.open_page(3)
await get_tree().create_timer(0.7).timeout
check(menu.band.page and menu.band.band_rect() == Rect2(530, 0, 1070, 900), "Lore spreads its band over the right two-thirds")
check(menu.words[0].modulate.a < 0.4 and menu.words[0].visible, "other words dim but stay")
await key(KEY_ESCAPE)
check(menu.page_open == -1 and menu.words[3].has_focus() and not menu.band.page, "Escape folds the page back to its word")
menu.open_page(2)
check(menu.pages.volume.has_theme_stylebox_override("slider") and menu.pages.volume.has_theme_icon_override("grabber"), "settings controls are painted, not default")
check(menu.find_children("*", "PanelContainer", true, false).is_empty(), "the grey panel is gone")
```

- [ ] **Step 2: Run the tests and check they fail.**
- [ ] **Step 3: Implement `MenuPages` and the page flow.**
  - Opening a page: `band.set_page(true)`, show its content after the band's 0.5 s spread, and focus Back (Settings focuses Volume).
  - Closing a page: hide its content first, then `band.set_page(false)`, then restore focus.
  - New Game: still goes straight to the loading flow (Task 10 adds the music).
- [ ] **Step 4: Run the tests and check they pass.**
- [ ] **Step 5: Add native captures** `main-menu-page-<lore|settings|continue>.png`. Check readability of the Lore paragraphs over the painting, and adjust the scrim if any line is hard to read.
- [ ] **Step 6: Commit** as `feat(menu): settings, lore and continue open in the band`.

### Task 4: The living city

**Files:**
- Create:
  - `tools/make_city_masks.py`: reads `assets/ui/main_menu/city.png` and writes `assets/ui/main_menu/city_masks.png`
    - R = sky
    - G = individual lights (bright, small, warm or cool blobs)
    - B = lake reflections
  - `scripts/UI/city_life.gdshader`
  - `scripts/UI/LivingCity.gd`
- Delete: `scripts/UI/living_paint.gdshader`, `scripts/UI/paint_flow.gdshaderinc`, `scripts/UI/paint_flow.tres` (grep first; nothing else may use them)
- Modify: `scripts/UI/MainMenu.gd` (background becomes `LivingCity`)
- Test: `tests/main_menu_test.gd`, `tests/visual/main_menu_preview.gd`, `tests/tools/test_make_city_masks.py`

**Interfaces:**
- Produces:
  - `class_name LivingCity extends TextureRect`
  - `func set_energy(base: float, low: float, high: float, fx: float) -> void` (each 0..1). It sets shader uniforms named `base`, `low`, `high`, `fx`.
  - `var dim := 1.0`, which goes to uniform `dim`
  - `MainMenu.background: LivingCity`
- Values:
  - **Painting:** the painting's UVs are never offset. Only additive or alpha layers go over it.
  - **Clouds:** a `NoiseTexture2D` wisp layer masked by R, drifting at 0.004 uv/s, stepped-edge posterized to 4 levels.
  - **Lights:** G-masked brightness × (1 + flicker). Flicker uses a per-light hash phase from `floor(uv * 512)` and 3–9 Hz irregular steps, with amplitude 0.15 + 0.15 × low.
  - **Haze:** a low band over the lake, from y 0.62 to 0.75 of the image, noise layer drifting 0.002 uv/s, alpha 0.12 + 0.12 × fx, cooled toward blue by fx.
  - **Reflection ripple:** a horizontal offset of the B-masked overlay copy only, amplitude ≤ 0.0015 uv.
  - **Glow:** around the moon at uv (0.075, 0.129), breathing at 0.08 Hz, ±8%.

- [ ] **Step 1: Write the failing Python test** `tests/tools/test_make_city_masks.py`. It runs the tool into a temp dir and asserts:
  - the output size equals `city.png`'s size
  - R covers more than 20% of the top 25% of rows and under 2% of the bottom 25%
  - G covers 0.2–4% of pixels
  - B is zero above y = 0.6

  Run: `python3 -m pytest tests/tools/test_make_city_masks.py -v`. Expected: FAIL (no tool).
- [ ] **Step 2: Implement `make_city_masks.py`.**
  - Sky: rows above the skyline found per column by a luminance/edge threshold, then feathered.
  - Lights: local-max luminance blobs ≤ 6 px.
  - Reflections: the lake region below the waterline row band, from the existing shader's 0.69–0.98 band, refined by colour.
  - Use numpy and Pillow, and never write to `city.png`.
- [ ] **Step 3: Run the Python test and check it passes.** Then open `city_masks.png` beside `city.png` and check that the sky mask doesn't bleed onto the cathedral, the towers or the spire. Fix the thresholds until it doesn't.
- [ ] **Step 4: Add the headless checks:**

```gdscript
check(menu.background is LivingCity, "background is the living city")
check(not FileAccess.get_file_as_string("res://scripts/UI/city_life.gdshader").contains("paint_phase"), "the flow warp is retired")
```

  Add a native check in the preview script: capture two frames 2 s apart, then sample 20 pixels on the skyline and architecture (from `city_masks.png` where R, G and B are all 0). Every one must be identical. At least one sky pixel must differ.
- [ ] **Step 5: Implement `LivingCity` and `city_life.gdshader`,** and wire `dim` from `MainMenu.city_dim()`.
- [ ] **Step 6: Run the headless suite and the preview, and check both pass.** Make close-up captures of the sky, the lights and the lake, and send them to the user. This look is judged by them.
- [ ] **Step 7: Commit** as `feat(menu): still painting with living sky, lights, haze and water`.

---

## Part B — The music system (built against placeholder stems)

### Task 5: Placeholder stems from the current sketch (with the user, in Logic)

**Files:**
- Create:
  - `assets/audio/source/menu_theme/stems/piano.wav` and `drums.wav`
  - `assets/audio/source/menu_theme/map.json`
  - `assets/audio/source/menu_theme/README.md`
  - The parent `assets/audio/source/.gdignore` already exists.

- [ ] **Step 1: Ask the user to open `hasta_los_huesos_overworld.logicx`** and approve on-screen control of Logic. Request computer-use access to Logic Pro only.
- [ ] **Step 2: Agree the loop length and phrase length.** Placeholder: extend the drummer region to 16 bars to match the piano. Confirm the tempo (78 or 74) and write down the chords the piano part plays, bar by bar, read from its piano roll.
- [ ] **Step 3: Export the two tracks** as 48 kHz 24-bit WAV stems from the project start, for exactly the loop length. Use the same export settings recorded in `assets/audio/source/hasta_los_huesos/README.md`.
- [ ] **Step 4: Write `map.json`** to this schema. Later tasks rely on it exactly:

```json
{
  "bpm": 78, "beats_per_bar": 4, "bars": 16, "phrase_bars": 8,
  "chords": [{"bar": 0, "name": "Dm"}],
  "stems": [
    {"id": "piano", "file": "stems/piano.wav", "layer": "base", "button": -1, "trim_db": 0},
    {"id": "drums", "file": "stems/drums.wav", "layer": "low", "button": -1, "trim_db": 0}
  ],
  "arrival": null,
  "jingles": [
    {"button": 0, "kind": "hover", "chord": "Dm", "variant": 0, "file": null, "cut": {"stem": "piano", "start_bar": 0.0, "beats": 0.5}}
  ]
}
```

  A jingle entry has either `file` (a rendered WAV, used in Part C) or `cut` (a slice from a stem, used for the placeholders). Placeholders: one hover cut (½ beat) and one press cut (1½ beats) per button per chord, each from a piano note on that chord. `button` −1 means the stem belongs to no button.
- [ ] **Step 5: The user listens to both stems** looping in Logic and confirms they are clean. Then commit `map.json` and the README. The WAVs are large; check `.gitignore` and follow how the *Hasta los huesos* source masters were handled. If those are ignored, ignore these too and say so in the README.

### Task 6: `prepare_menu_score.py`

**Files:**
- Create:
  - `tools/prepare_menu_score.py`
  - `tests/tools/test_prepare_menu_score.py`, which uses tiny numpy-made WAV fixtures. These are test data, not game audio.
- Output:
  - `audio/music/menu/<stem id>.ogg`
  - `audio/music/menu/score.tres` (`AudioStreamSynchronized`, one looping `AudioStreamOggVorbis` per stem, in `map.json` order)
  - `audio/music/menu/jingles/b<button>_<kind>_<chord>_<variant>.ogg`
  - `audio/music/menu/arrival.ogg` (if any)
  - `audio/music/menu/score.json`: map fields plus per-stem `index`, `peak_db`, `sha256`, and per-jingle `path`

**Interfaces:**
- Produces: `score.json` with these keys:
  - `bpm`, `beats_per_bar`, `bars`, `phrase_bars`, `loop_seconds`
  - `chords` (bar → name list)
  - `stems: [{id, layer, button, index}]`
  - `jingles: {"<button>": {"hover": {"<chord>": [path, …]}, "press": {…}}}`
  - `arrival: path|null`

- [ ] **Step 1: Write the failing tests.**
  - `loop_seconds == bars * beats_per_bar * 60 / bpm`
  - Each stem's decoded length equals `round(loop_seconds * 48000)` samples, with no tail appended, so it loops seamlessly.
  - A `cut` jingle equals the source slice, with a 5 ms fade-out.
  - The jingle table groups by button, then kind, then chord.
  - Unknown layers and a missing file each raise `ValueError` with the offending id.
  - Run `python3 -m pytest tests/tools/test_prepare_menu_score.py -v` and expect FAIL.
- [ ] **Step 2: Implement.** Reuse `stereo`, `encode` and the libsndfile approach from `tools/prepare_score.py` by importing them, not by copying. Write the `.tres` the way `write_resource()` there does, with loop enabled on each Ogg.
- [ ] **Step 3: Run the tests and check they pass.** Then run the tool on the real placeholders: `python3 tools/prepare_menu_score.py`. Open Godot once headless so the new files import: `"$GODOT" --headless --path . --import`.
- [ ] **Step 4: Commit** as `feat(audio): menu score preparation tool`. Include the generated `audio/music/menu/` files.

### Task 7: `MenuClock`

**Files:**
- Create: `scripts/Audio/MenuClock.gd`, `tests/menu_music_test.gd`, `tests/menu_music_test.tscn`

**Interfaces:**
- Produces: `class_name MenuClock` with these static functions:
  - `beat_seconds(bpm: float) -> float`
  - `bar_at(pos: float, bpm: float, beats_per_bar: int) -> int`
  - `next_eighth(pos: float, bpm: float) -> float`: the first eighth boundary strictly after `pos`, unless `pos` is within 0.005 s after a boundary, in which case it returns that boundary
  - `chord_at(chords: Array, bar: int, bars: int) -> String`: the last chord entry with `bar <= bar % bars`
  - `phrase_end_after(pos: float, bpm: float, beats_per_bar: int, phrase_bars: int) -> float`
  - `corrected(position: float, since_mix: float, latency: float) -> float`: `position + since_mix - latency`, clamped at ≥ 0

- [ ] **Step 1: Write the failing tests** at 78 bpm, 4/4:
  - `beat_seconds(78) ≈ 0.76923`
  - `next_eighth(0.0, 78) == 0.0`
  - `next_eighth(0.001, 78) == 0.0`
  - `next_eighth(0.01, 78) ≈ 0.38462`
  - `bar_at(3.1, 78, 4) == 1`
  - `chord_at([{bar 0 Dm},{bar 4 Gm}], 5, 16) == "Gm"`
  - `chord_at(…, 17, 16) == "Dm"`
  - `phrase_end_after(10.0, 78, 4, 8) ≈ 24.615`
  - `corrected(1.0, 0.01, 0.03) ≈ 0.98`
- [ ] **Step 2: Run the tests and check they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests and check they pass.**
- [ ] **Step 5: Commit** as `feat(audio): menu music clock`.

### Task 8: `MenuMusic`: layers, states, lean, idle, arrival

**Files:**
- Create: `scripts/Audio/MenuMusic.gd`
- Test: `tests/menu_music_test.gd`

**Interfaces:**
- Consumes: `MenuClock`, `audio/music/menu/score.json` and `score.tres`
- Produces:
  - `class_name MenuMusic extends Node`
  - `enum State { ARRIVAL, BROWSING, IDLE, LORE, SETTINGS, CONTINUE, STARTING }`
  - `const SCORE_JSON := "res://audio/music/menu/score.json"`
  - `var available := false`
  - `var state := State.ARRIVAL`
  - `var position_source: Callable`: returns loop position in seconds; the default reads the player through `MenuClock.corrected`. Tests replace it.
  - `@export var score_json_path := SCORE_JSON`
  - `var score: Dictionary`: the parsed `score.json`. Gains and chords are read from it every frame, so tests may edit `score.chords` and `score.stems[i].button` after `_ready`.
  - `func set_state(s: State) -> void`
  - `func set_selected(button: int) -> void` (−1 means none)
  - `func note_input() -> void`: resets idle and raises activity
  - `func layer_energy(layer: StringName) -> float` (0..1, current, after envelopes)
  - `func stem_gain_db(stem_id: StringName) -> float`
- Values (dB targets per layer; 0 = full):

| State | base | low | high | fx |
|---|---|---|---|---|
| ARRIVAL | 0 | −80 → 0 over the first 4 bars | −80 | 0 |
| BROWSING | 0 | 0 | lerp(−80, −3, activity) | −12 |
| IDLE | −10 | −80 | −80 | −14 |
| LORE | 0 | −12 | −14 | +0 (forward) |
| SETTINGS | 0 | −14 | −80 | −14 |
| CONTINUE | as BROWSING | | | |

- More values:
  - **Activity:** +0.35 per `note_input`, capped at 1, decaying at 0.12/s.
  - **Idle:** after 30 s without `note_input`, the state becomes IDLE. The next `note_input` returns to BROWSING on the next bar line.
  - **ARRIVAL** ends at bar 4 and becomes BROWSING.
  - **Lean:** the stem whose `button == selected` gets +4 dB, clamped at 0 dB.
  - **Envelopes:** move gains toward their targets at 24 dB/s (about 0.5–2 s for typical moves). `layer_energy` is `db_to_linear` of the layer's loudest stem.
  - **Placement:** `MenuMusic` is added to `get_tree().root`, not under the menu.
  - **Bus:** the menu runs before any level warms `Sfx`, so `_ready` first calls `Sfx._ensure_buses()`, making the `Music` bus exist. Then it picks `Sfx.BUS_MUSIC`, falling back to `&"Master"` only if the bus is still missing.

- [ ] **Step 1: Write the failing tests** with an injected `position_source` and `_process(delta)` driven manually:
  - Each state's targets match the table.
  - In ARRIVAL, low reaches 0 dB at bar 4 (`position = 4 * 4 * beat`).
  - With no `note_input` for 30 s of simulated time, the state is IDLE. `note_input` at bar 9.5 returns to BROWSING exactly when the position crosses bar 10.
  - A placeholder score with a stem on button 2: `set_selected(2)` raises that stem by 4 dB relative to `set_selected(-1)`.
  - **Missing score** (point `SCORE_JSON` at a nonexistent path through an exported override var `score_json_path`): `available == false`, `layer_energy(&"base") == 0.0`, and every public call is a no-op with no errors. *(Review Focus 5.)*
  - On a fresh tree, the player bus is `&"Music"`, because `_ensure_buses` ran.
  - Chords for these tests: set `music.score.chords = [{"bar": 0, "name": "Dm"}, {"bar": 4, "name": "Gm"}]`. Task 9 uses the same chords.
- [ ] **Step 2: Run the tests and check they fail.**
- [ ] **Step 3: Implement.** Start the `AudioStreamSynchronized` with every stream at its ARRIVAL gain, or at −80 dB for streams that start silent, so they stay locked. If `arrival` exists, play it first on a second player and start the loop on its final downbeat. The arrival length is in `score.json`, so schedule against the clock rather than a timer.
- [ ] **Step 4: Run the tests and check they pass.**
- [ ] **Step 5: Commit** as `feat(audio): menu music layers and states`.

### Task 9: Jingles

**Files:**
- Modify: `scripts/Audio/MenuMusic.gd`
- Test: `tests/menu_music_test.gd`

**Interfaces:**
- Produces:
  - `func hover(button: int) -> void`: plays immediately
  - `func press(button: int) -> void`: scheduled for `MenuClock.next_eighth`
  - `var last_jingle := {}`: `{button, kind, chord, variant, started_at_pos}`, used by the tests
  - `const HOVER_VOICES := 2`
  - `const PRESS_VOICES := 1` (per button)
- Values:
  - **Chord:** `MenuClock.chord_at` at the play position (for a press, at its scheduled position).
  - **Variants:** rotate round-robin per button+kind+chord.
  - **Voice limit:** a pool of `AudioStreamPlayer`s on the music bus. When over the limit, the oldest voice is stopped with a 30 ms fade.
  - **Missing chord:** if a chord has no jingle, fall back to the loop's first chord, and print a warning once per chord.

- [ ] **Step 1: Write the failing tests:**
  - `hover(1)` at pos 0.2 → `last_jingle.started_at_pos == 0.2`, kind hover, chord Dm.
  - `press(0)` at pos 0.01 → not started that frame; it starts on the first frame where pos ≥ 0.38462, and `started_at_pos - 0.38462 < 1/60`.
  - A press at pos in bar 5 picks `Gm` with the test map.
  - Two consecutive hovers on the same button+chord give variants 0, then 1.
  - Hover across 0,1,2,3,0,1,2,3 in 8 frames → never more than `HOVER_VOICES` hover voices playing. *(Review Focus 3, part 1.)* In `main_menu_test`, the same spam ends with `menu.selected == 3` and the band at word 3 after 0.7 s. *(Review Focus 3, part 2.)*
- [ ] **Step 2: Run the tests and check they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests and check they pass.**
- [ ] **Step 5: Commit** as `feat(audio): chord-aware menu jingles`.

### Task 10: Wiring and the New Game ending

**Files:**
- Modify: `scripts/UI/MainMenu.gd`, `scripts/Audio/MenuMusic.gd`
- Test: `tests/main_menu_test.gd`, `tests/menu_music_test.gd`, `tests/visual/main_menu_preview.gd`

**Interfaces:**
- Consumes: everything above
- Produces:
  - `MenuMusic.start_game() -> void`
  - `signal ended`
  - `MainMenu.music: MenuMusic`
- Wiring:
  - `selection_changed` → `music.set_selected(i)` + `music.hover(i)` + `music.note_input()`
  - word pressed → `music.press(i)` + `band.pulse()`
  - `open_page` → `set_state(LORE | SETTINGS | CONTINUE)`
  - `close_page` → `set_state(BROWSING)`
  - every frame → `background.set_energy(music.layer_energy(&"base"), …low, …high, …fx)`
  - menu `_exit_tree` → `music.queue_free()` unless `music.state == STARTING`
- Ending values:
  - **Fade:** `start_game()` fades from the press to `MenuClock.phrase_end_after(press position)`. High reaches −80 dB at 40% of that span, low and fx at 75%, and base at 100%, on the phrase's final bar.
  - **Short phrase:** if less than 1 bar remains, extend to the following phrase end.
  - **After the fade:** `ended` is emitted and the node frees itself.
  - **Loading never waits.** `MainMenu._activate(0)` opens the loading cover in the same frame it calls `start_game()`. The old 0.22 s pause is removed; the press pulse is drawn by the band.

- [ ] **Step 1: Write the failing tests:**
  - `start_game()` with pos at bar 3 of 8-bar phrases → base reaches −80 dB exactly at bar 8 (± 1 frame) and `ended` fires.
  - While STARTING, `hover`, `press` and `set_state` are ignored.
  - In `main_menu_test`, pressing New Game twice in two frames → one `ArtLoadingScreen` in the root and one `start_game` call (count it with a spy subclass of `MenuMusic`). *(Review Focus 4.)*
  - After `change_scene`, the `MenuMusic` node is still in the root until `ended`.
  - `layer_energy(&"fx")` reaches `LivingCity`: the shader param `fx` is greater than 0.5 while Lore is open.
- [ ] **Step 2: Run the tests and check they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests and check they pass.** Then run the native preview end to end: the menu, every page, then New Game into the Metro. All existing preview checks plus the new captures must pass, and there must be no script errors in the log.
- [ ] **Step 5: Commit** as `feat(menu): music follows the menu and resolves into the game`.

### Task 11: Docs and the user's first in-game review

**Files:**
- Modify: `docs/systems/main-menu.md`, `docs/systems/audio.md`
- Regenerate: `docs/reference/gdscript/...`, using the repo's existing reference generator. Find it with `grep -rl "docs/reference" tools`.

- [ ] **Step 1: Rewrite `main-menu.md`** for the word column, band, pages, living city and MenuMusic. Add a short `audio.md` section for the menu score, `map.json` and the prep tool. Remove the `music_marker` text. Record the known limit by name: the illustrations are soft above 1080p because there is no hi-res source, and the fix (an upscaled copy) waits on the user's OK.
- [ ] **Step 2: Run every suite this plan touched,** plus `art_loading_test`, `sound_test`, `music_test` and `painterly_test`. All must pass. Report the counts.
- [ ] **Step 3: Send the user the native captures,** and ask them to play the menu themselves with the placeholder music. Collect their notes on the band, the city and the jingle feel, and fix the visual notes before Part C.
- [ ] **Step 4: Commit** as `docs(menu): overhaul docs`.

---

## Part C — Finishing the song (in Logic, with the user)

These tasks are collaborative. Each step that changes the music ends with the user listening and saying keep, change or cut. Nothing moves on without that. Claude drives Logic on screen with the user's permission each session, and writes MIDI with `tools/menu_midi.py`.

### Task 12: The frame and the MIDI tool

**Files:**
- Create: `tools/menu_midi.py` (mido; install with `python3 -m pip install --user mido`), with `tests/tools/test_menu_midi.py`

**Interfaces:**
- `write_part(path, bpm, notes: list[(start_beat, length_beats, pitch, velocity)], ppq=480)`
- `chord_tones(name: str, octave: int) -> list[int]`, for D minor harmony names such as `Dm`, `Gm7`, `A7b9`, `Bbmaj7`, `Edim`

- [ ] **Step 1: Test** that `chord_tones("Dm", 4) == [62, 65, 69]`, and that `write_part` round-trips through mido with exact ticks. Implement, then commit.
- [ ] **Step 2: In Logic, with the user:**
  - Settle the tempo and the loop length. Suggested: 32 bars, in four 8-bar phrases.
  - Lay out a Chord Track of minor and diminished noir harmony that can be voiced as bolero or danzón.
  - The user approves the progression by ear.
  - Update `map.json`'s `chords`, `bars` and `phrase_bars`.

### Task 13: Grooves (Logic players)

- [ ] **Drums:** set up Drummer as a slow, dusty trip-hop kit, swing 54–62%.
- [ ] **Percussion:** Latin Percussionist (Isabela) on a cinquillo/baqueteo feel.
- [ ] **Bass:** Bass Player following the Chord Track with a tumbao feel.
- [ ] **Approval:** each one is auditioned and approved by the user. See `docs/superpowers/refs/main_menu/music_references.md` §3 and §5.

### Task 14: Melodic parts (Claude's MIDI)

- [ ] **Piano:** montuno-style variations for the user's piano. The original stays as it is; variations go on a new track.
- [ ] **High layer:** four interlocking lines written to play together — trumpet (button 0), guitar (1), Rhodes/vibraphone (2), bells/choir (3). Each gets its own track and its own instrument, chosen by the user.
- [ ] **FX layer:** drones, choir pads and reversed tails.
- [ ] **Approval:** each part is imported, auditioned, and kept, changed or cut by the user.

### Task 15: Texture and mix

- [ ] **Texture:** tape and vinyl character, reverbs and delays, following the Logic recipe in the references doc §3.
- [ ] **Mix:** the user approves the full mix, and the four layer groups soloed one at a time.

### Task 16: Jingles and the arrival cue

- [ ] **Jingles:** write the hover motifs (½–1 beat) and press motifs (1–2 beats) for each button, for every chord in the loop, with 2–3 variants each. Render them on that button's instrument track.
- [ ] **Arrival cue:** write the build cue that lands on bar 1.
- [ ] **Approval:** the user approves the jingles in context by playing the loop and triggering them.

### Task 17: The final drop-in

- [ ] **Export:** export the per-instrument stems, the jingle renders and the arrival cue at 48 kHz, as in Task 5.
- [ ] **Map:** update `map.json`, with each stem's `layer` and `button`, and jingles moved from `cut` to `file`.
- [ ] **Regenerate:** run `prepare_menu_score.py`, then re-run all of Part B's suites.
- [ ] **Tune by ear:** the user plays the menu. Tune the Task 8 dB table and the lean amount together; record the final values in `docs/systems/audio.md`.
- [ ] **Commit** as `feat(audio): the menu theme`.
