# Menu Look and Feel (Piece 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the main menu as approved in piece 1: a deco title, book small-caps choices, a small painterly wash per word that blooms in and fades out with no travelling band, one shared motion curve, book-style pages, and a Quit choice with a confirm.

**Architecture:**
- Fonts are bundled OFL files. A tiny `MenuMotion` helper owns the shared easing and timings.
- Each `MenuWord` owns a `MenuWash` (new: a Control with `menu_wash.gdshader`) that shows its painting at full colour and melts it into the city.
- `MenuBand` is kept only for pages. Its choice-band mode, glaze and glide are retired.
- `MainMenu` gains a fifth word (Quit) and a confirm.

**Tech Stack:** Godot 4.5.1 GDScript and canvas shaders. Python stdlib unittest for nothing new. curl for the font files.

**Spec:** `docs/superpowers/specs/2026-10-25-menu-look-and-feel-design.md` (read it). Mockup (local only): `.superpowers/brainstorm/27138-1792977562/content/menu-look-final-v2.html`.

## Global Constraints

- **Branch:** `main-menu-overhaul`. Commit only this plan's paths; `CREDITS.md`, `project.godot` and others hold the user's uncommitted edits.
- **Suites:** headless via `.superpowers/sdd/2026-10-25-main-menu-overhaul/run.sh <name>`, which fails on any SCRIPT ERROR. Native captures via `tests/visual/main_menu_preview.gd`.
- **Easing:** everything uses `Tween.TRANS_QUINT` + `Tween.EASE_OUT`.
- **Timings:**
  - word answer 0.2 s
  - wash bloom 0.6 s, from 0.94 scale and −10 px x
  - wash fade 0.4 s
  - press-in 0.12 s to 0.97 scale
- **Wash:** about 440×170 design px, opacity 0.92, full colour (no desaturation, darkening, glaze or dark gradient). Torn top and bottom, soft on every side, most on the left. Framed on each painting's face.
- **Words:** five choices, "New Game", "Continue", "Settings", "Lore", "Quit".
  - no numerals, no markers, no captions, no tagline
  - unselected alpha 0.5
  - selected: white, +10 px x, with a soft dark text shadow
- **Fonts:**
  - title: Poiret One, letter-spacing about 0.32 em, with a gold hairline `d9b46a` → clear
  - choices: Cormorant SC 500
  - page body: Cormorant Garamond
  - all bundled under `assets/fonts/` with their `OFL.txt`
- **Never call a visual fault harmless:** fix it or name it unfinished. Judge the look in native captures of the real menu.

## Review Focus

1. **Moving the selection fast with keys** (down, down, down in three frames). Expected: at most two washes visible at once (one fading, one blooming), and the last word's wash ends fully shown. Test in Task 3.
2. **A page opened while a wash is mid-bloom.** Expected: the word washes fade, and only the page painting shows. Test in Task 5.
3. **Quit confirm and Escape.** Expected: Escape closes the confirm (No), never quits. Test in Task 6.
4. **The mouse leaving all words.** Expected: the selection stays and its wash stays (no flicker to nothing). Test in Task 3.
5. **Window shapes 16:10, 21:9 and 4:3.** Expected: the word washes stay attached to their words, and the page still reaches the screen edges (as already tested). Native capture in Task 7.

---

### Task 1: Fonts

**Files:**
- Create: `assets/fonts/PoiretOne-Regular.ttf`, `CormorantSC-Medium.ttf`, `CormorantGaramond[wght].ttf`, `CormorantGaramond-Italic[wght].ttf`, the three families' `OFL.txt` (renamed `OFL-PoiretOne.txt`, `OFL-CormorantSC.txt`, `OFL-CormorantGaramond.txt`), and `assets/fonts/README.md` (sources, licence, credit)
- Create: `scripts/UI/MenuType.gd`
- Test: `tests/main_menu_test.gd`

**Interfaces:**
- Produces:
  - `class_name MenuType`
  - `static func title() -> Font`
  - `static func choice() -> Font`
  - `static func body() -> Font`
  - `static func body_italic() -> Font`
  - each returns a preloaded `FontFile` with the system serif as fallback

- [ ] **Step 1:** Download the files from `https://github.com/google/fonts/raw/main/ofl/{poiretone,cormorantsc,cormorantgaramond}/…` into `assets/fonts/`. The user approved this. Check each with `file`, which must say TrueType, and confirm each `OFL.txt` names the SIL Open Font License.
- [ ] **Step 2: Failing test:**
  ```gdscript
  check(MenuType.title().get_font_name().contains("Poiret") and MenuType.choice().get_font_name().contains("Cormorant SC") and MenuType.body().get_font_name().contains("Cormorant Garamond"), "the bundled typefaces load")
  ```
- [ ] **Step 3:** Implement `MenuType`. Import the fonts with `--import`. Write the credit into `assets/fonts/README.md`. Add a CREDITS.md entry by staging only that hunk (`git apply --cached` with a patch of just the new lines).
- [ ] **Step 4:** Run the test (PASS), then commit as `feat(menu): bundle the menu's OFL typefaces`.

### Task 2: Typography and the calm selected word

**Files:**
- Modify: `scripts/UI/MainMenu.gd` (title, hairline, five names)
- Modify: `scripts/UI/MenuWord.gd` (Cormorant SC; remove `_tick`/`_glow`; new selected look)
- Create: `scripts/UI/MenuMotion.gd`
- Test: `tests/main_menu_test.gd` (update existing word checks to five words)

**Interfaces:**
- Produces (`MenuMotion`):
  - `class_name MenuMotion`
  - `const ANSWER := 0.2`, `BLOOM := 0.6`, `FADE := 0.4`, `PRESS := 0.12`
  - `static func tween(node: Node) -> Tween`: `create_tween()` with QUINT/OUT, parallel
- Produces (`MenuWord`):
  - `const STEP := 10.0`, `const DIM := 0.5`
  - `func set_selected(on: bool) -> void`: tweens colour, alpha and the step over `ANSWER`
  - `var step_x: float`: the current content offset

- [ ] **Step 1: Failing tests:**
  - `menu.words.size() == 5` and the texts are `["NEW GAME","CONTINUE","SETTINGS","LORE","QUIT"]` (rendered as small caps of the cased names)
  - the title Labels use `MenuType.title()`
  - a `ColorRect` named "Hairline" exists under the title
  - `words[0]` has no child named "Tick"
  - after `select(1)` plus 0.25 s: `is_equal_approx(words[1].step_x, 10.0)` and `words[1].modulate.a == 1.0`, and `words[0].modulate.a` is about 0.5
- [ ] **Step 2:** Run the tests and check they fail.
- [ ] **Step 3:** Implement.
  - MenuWord uses `MenuType.choice()` at size 38 with the text in title case; Cormorant SC renders the small caps. So text is "New Game", and the test compares `.text` with title-case strings.
  - The shadow uses `font_shadow_color` `Color(0,0,0,0.85)`, offsets (0,1), and `shadow_outline_size` 10.
  - Move the content with `_style.content_margin_left` tweened from 0 to `STEP` over `ANSWER`.
- [ ] **Step 4:** Run the tests and check they pass. Commit as `feat(menu): deco title, book choices, a calm selected word`.

### Task 3: A painterly wash per word

**Files:**
- Create: `scripts/UI/MenuWash.gd`, `scripts/UI/menu_wash.gdshader`
- Modify: `scripts/UI/MenuWord.gd` (owns a wash for indices 0–3), `scripts/UI/MainMenu.gd` (stop calling `band.show_choice`, and dim the city while any wash shows)
- Test: `tests/main_menu_test.gd` (replace the band-on-word, glaze, cross-fade and glide checks)

**Interfaces:**
- Consumes: `MenuMotion`, `MenuBand.ART_REGIONS`
- Produces (`MenuWash`):
  - `class_name MenuWash extends Control`
  - `const SIZE := Vector2(440, 170)`
  - `const FACE := [Vector2(0.55, 0.45), Vector2(0.4, 0.5), Vector2(0.5, 0.45), Vector2(0.62, 0.35)]` (subject centre in each painting's region UV; tune by eye in captures)
  - `func configure(art: int) -> void`
  - `func bloom() -> void`, `func fade() -> void`
  - `var level := 0.0` (0..1, eased; drives the shader's `alpha` and the scale and offset)
- Produces (`MainMenu`): `func washes_showing() -> int` (washes with level > 0.02)
- Values:
  - Placement: wash rect relative to its word, `Rect2(-40, (word_h - 170) * 0.5, 440, 170)`, drawn behind the word's text (`show_behind_parent`).
  - Shader: atlas region cover-crop around `FACE`; torn top and bottom edges whose noise steps at 9 fps (reuse `MenuBand.boil_step`); radial soft mask centred right of middle with a long fade on the left; `alpha * 0.92`. No screen texture, no glaze, no darkening.

- [ ] **Step 1: Failing tests:**
  ```gdscript
  menu.select(0); await timer(0.7)
  check(menu.words[0].wash.level > 0.99 and menu.washes_showing() == 1, "the selected word's painting blooms in")
  menu.select(1); await timer(0.2)
  check(menu.words[0].wash.level > 0.05 and menu.words[1].wash.level > 0.05, "the old painting fades while the new one blooms")
  await timer(0.6)
  check(menu.words[0].wash.level < 0.01 and menu.words[1].wash.level > 0.99, "then only the new one shows")
  var at := menu.words[1].wash.get_global_rect(); menu.select(2); menu.select(1); await timer(0.7)
  check(menu.words[1].wash.get_global_rect().position.is_equal_approx(at.position), "washes never travel")   # no glide
  for k in 3: await key(KEY_DOWN)   # Review Focus 1
  check(menu.washes_showing() <= 2, "fast keys: never more than two paintings at once")
  await timer(0.7); check(menu.washes_showing() == 1, "and it settles on one")
  menu.words[menu.selected].mouse_exited.emit(); await timer(0.5)   # Review Focus 4
  check(menu.washes_showing() == 1, "leaving the words keeps the selection's painting")
  check(menu.words[4].wash == null, "Quit has no painting")
  ```
  (`timer(s)` awaits `create_timer(s).timeout`.)
- [ ] **Step 2:** Run the tests and check they fail.
- [ ] **Step 3:** Implement. Remove MenuBand's choice mode: `show_choice`, the glaze uniforms, `art_a`/`art_b` and the cross-fade. Its page mode stays for Task 5. Remove now-dead checks from the test file.
- [ ] **Step 4:** Run the tests and check they pass. Add native captures `main-menu-wash-<i>.png` and a close-up crop of each, then compare them with the mockup. Fix any hard edge or seam, or a face cropped off.
- [ ] **Step 5:** Commit as `feat(menu): a painterly wash per word`.

### Task 4: Press-in

**Files:**
- Modify: `scripts/UI/MenuWord.gd`, `scripts/UI/MainMenu.gd` (`_activate` plays the press-in, then acts)
- Test: `tests/main_menu_test.gd`

**Interfaces:**
- Produces (`MenuWord`): `func press_in() -> void`: scale to 0.97 and back over `MenuMotion.PRESS`, pivot at the text's centre

- [ ] **Step 1: Failing test:** pressing Settings gives `words[2].scale.x < 0.99` within 0.06 s and `is_equal_approx(words[2].scale.x, 1.0)` after 0.2 s, and the page opens afterwards.
- [ ] **Step 2:** Run it (FAIL), implement it, then run it again (PASS).
- [ ] **Step 3:** Commit as `feat(menu): press-in`.

### Task 5: Book pages

**Files:**
- Modify:
  - `scripts/UI/MenuPages.gd` (chapter heading in `MenuType.choice()` size 52, gold hairline under it, body in `MenuType.body()` size 24)
  - `scripts/UI/MenuBand.gd` and `menu_band.gdshader`: page mode only. The painting is at full colour, melting on its left and around the other edges, with no glaze and no darkened city behind.
  - `scripts/UI/MainMenu.gd`
- Test: `tests/main_menu_test.gd`

- [ ] **Step 1: Failing tests:**
  - with Lore open: `pages.title_label` uses `MenuType.choice()` and `pages.body_label` uses `MenuType.body()`
  - a "Hairline" ColorRect exists in the pages
  - (Review Focus 2) `open_page(3)` called 0.1 s into a wash bloom → after 0.6 s `menu.washes_showing() == 0` and `band.page`
  - Escape → the word wash for Lore returns
- [ ] **Step 2:** Run the tests and check they fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests and check they pass. Native captures `main-menu-page-*.png` (including the three window shapes) must show no hard edges.
- [ ] **Step 5:** Commit as `feat(menu): book pages`.

### Task 6: Quit

**Files:**
- Modify: `scripts/UI/MainMenu.gd` (a fifth word, a confirm in the book style with "Yes" and "No" words, `var quit_game: Callable`)
- Test: `tests/main_menu_test.gd`

**Interfaces:**
- Produces (`MainMenu`):
  - `var confirming := false`
  - `func open_quit_confirm() -> void`
  - `func close_quit_confirm() -> void`
  - `var quit_game: Callable` (default `get_tree().quit`; tests replace it)

- [ ] **Step 1: Failing tests:**
  - pressing Quit gives `confirming`, with focus on "No"
  - Escape closes it (Review Focus 3) and `quit_game` was never called; focus returns to Quit
  - pressing Quit then "Yes" calls `quit_game` once
  - MenuMusic gets no jingle for word 4 and no error
- [ ] **Step 2:** Run the tests and check they fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests and check they pass.
- [ ] **Step 5:** Commit as `feat(menu): Quit with a confirm`.

### Task 7: Docs, captures, review

- [ ] **Docs:** update `docs/systems/main-menu.md` for the new look (type, washes, motion, pages, Quit). Copy the regenerated reference pages for the new and changed scripts only.
- [ ] **Suites:** run every suite (menu, music, scene change, loading, sound, combat score, tools) and the native preview, with page and wash captures at 16:9, 16:10, 21:9 and 4:3. All must pass.
- [ ] **Review:** dispatch a fresh review of this plan's commits. Fix its Critical and Important findings test-first, and log the minors.
- [ ] **Hand-off:** launch the game for the user to judge the feel.
- [ ] **Commit** as `docs(menu): piece 1 look and feel`.
