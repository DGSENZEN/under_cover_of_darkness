# Main menu

Normal project startup opens `main_menu.tscn`. Its CanvasLayer sits above the
world's retro postprocess, so the supplied painted artwork stays as painted.
Controls scale together inside a centred 1600×900 design area. Design:
`docs/superpowers/specs/2026-10-25-main-menu-overhaul-design.md`.

## The screen

Look and feel: `docs/superpowers/specs/2026-10-25-menu-look-and-feel-design.md`.

**Type.** [MenuType](../../scripts/UI/MenuType.gd) loads the bundled OFL
typefaces (`assets/fonts/`, see its README):
- **Title:** "UNDER COVER / OF DARKNESS" in Poiret One deco capitals, widely
  spaced, with a gold hairline (`d9b46a` fading to clear) under it.
- **Choices:** Cormorant SC book small capitals.
- **Page text:** Cormorant Garamond.

**Words.** [MenuWord](../../scripts/UI/MenuWord.gd) buttons form one column at
x 72 from y 400, 64 design px apart: New Game, Continue, Settings, Lore, Quit.
There are no numerals, markers or captions.
- **Unselected words** sit at 50% opacity.
- **The selected word** turns white and steps 10 px right, with a soft dark
  shadow so it reads over any painting.
- **Input:** mouse hover and keyboard/controller focus go through one path,
  `MainMenu.select(index)`. Nothing is selected until the first input, and
  the first key selects New Game. Up and down move without wrapping.

**Motion.** [MenuMotion](../../scripts/UI/MenuMotion.gd): one curve
everywhere, quint easing out.
- Words answer in 0.2 s.
- Paintings bloom over 0.6 s and fade over 0.4 s.
- A pressed word dips to 0.97 scale and back over 0.12 s before its action.

**Washes.** Each of the first four words owns a
[MenuWash](../../scripts/UI/MenuWash.gd) with
[menu_wash.gdshader](../../scripts/UI/menu_wash.gdshader): its painting at
full colour in a 440×170 design-px wash, framed on the painting's face
(`MenuWash.FACE`).
- **Edges:** torn top and bottom, melting long to the left into the city and
  fraying on the right. Only the edges boil, at about 9 fps.
- **Layer:** all washes sit on one layer behind all the words, and never
  travel.
- **Changing word:** the old wash fades while the new one blooms (from 0.94
  scale and 10 px left). A third never stacks under two others: the oldest
  is cleared at once.
- **City:** it dims to 0.72 while a painting shows.

**Pages.** Continue, Settings and Lore open as book pages.
[MenuBand](../../scripts/UI/MenuBand.gd) with
[menu_page.gdshader](../../scripts/UI/menu_page.gdshader) is now only the
page's painting:
- **Painting:** an 820×560 painting at full colour, framed on its face, torn
  all round and melting longest to the left. It sits in the page area from
  design x 530 to the visible screen's right, top and bottom on any window
  shape (`MainMenu.visible_design_rect`, `MenuBand.set_screen`).
- **Words while open:** their washes fade, and the other words dim to 0.35.

[MenuPages](../../scripts/UI/MenuPages.gd) writes the page in a 560-wide
column from design (620, 270), below the title line:
- a Cormorant SC heading and a gold hairline
- Cormorant Garamond text: Lore's text, or Continue's line "No saved game
  yet. Choose New Game to begin."
- Settings' master volume (a brush-stroke slider with a pigment-dab handle)
  and the awareness-marks switch

Settings persists to `user://settings.cfg`. Back (a word) or Escape folds the
page away, and the word's own painting returns.

**Quit.** It asks "Quit?" beside it in gold italic, with Yes and No as words
over a soft scrim. No is focused. Escape or No closes it without quitting;
Yes calls `MainMenu.quit_game`, which defaults to `get_tree().quit()`.

**Known limit.** The illustrations exist only at about 575 px inside their
rims. Page paintings are enlarged about 1.4× in design px, so they look soft
above 1080p. The fix is an upscaled derived copy, which waits on the user's
approval.

**The city.** [LivingCity](../../scripts/UI/LivingCity.gd) with
[city_life.gdshader](../../scripts/UI/city_life.gdshader) never moves the
painting. Its masks, `city_masks.png`, are made by `tools/make_city_masks.py`,
which only reads `city.png`. They mark four regions:
- **R, sky:** traced above the skyline, with the moon and the spire's beam left out
- **G, lights:** detected window and street lights, plus the burning district at 0.4
- **B, open lake:** between the near buildings
- **A, haze:** the far shore and lake, behind the near buildings

What moves:
- cloud wisps drifting in the sky, stepped like paint
- lights flickering in steps, 3–9 Hz, out of step with each other, gently for the fire
- haze over the lake
- a ±0.0015 uv shiver on the reflections only
- the moon's glow breathing at 0.08 Hz

The music's layers stir them. `low` deepens the flicker, `fx` thickens and
cools the haze, and `base` lifts the moon glow.

## The music

[MenuMusic](../../scripts/Audio/MenuMusic.gd) plays the menu theme. It lives
under the tree root, `PROCESS_MODE_ALWAYS`, on the `Music` bus (created via
`Sfx._ensure_buses()` if no level made it yet). Every stem plays at once in one
`AudioStreamSynchronized` (`audio/music/menu/score.tres`), locked.

**Layers.** Each stem belongs to one of four layers, `base`, `low`, `high` or
`fx`, weighted by menu state (dB targets):

| State | base | low | high | fx |
|---|---|---|---|---|
| ARRIVAL (first 4 bars) | 0 | rises from silence | out | 0 |
| BROWSING / CONTINUE | 0 | 0 | out → −3 with activity | −12 |
| IDLE (30 s untouched while browsing) | −10 | out | out | −14 |
| LORE | 0 | −12 | −14 | 0 |
| SETTINGS | 0 | −14 | out | −14 |

- **Activity** rises 0.35 per input and falls 0.12/s. Its curve is in
  amplitude, not dB.
- **The chosen word's** own instrument stem (`button` in the map) comes up
  4 dB, never above 0.
- **Idle:** leaving idle waits for the next bar line.
- **Gains** glide at 24 dB/s.
- **Feeding the visuals:** `layer_energy(layer)` reports each layer's level
  (0..1) back to the city.

[MenuClock](../../scripts/Audio/MenuClock.gd) reads musical time from the
player: its playback position, plus time since the last mix, minus output
latency.

**Jingles.** Hovering a word plays its instrument's hover jingle on that same
frame, in the chord sounding now. Pressing one plays its press jingle on the
next eighth note, at most one frame late.
- Variants rotate.
- Hovers share 2 voices and each word has 1 press voice. The oldest voice
  fades out in 30 ms to make room.
- A chord with no jingle falls back to the loop's first chord, with a warning.

**Arrival.** If the score has an arrival cue, it plays first and the loop
starts as it lands.

**New Game.** Pressing New Game opens the loading cover at once and calls
`start_game()`. The song plays on to the end of its current phrase. If less
than a bar is left, it plays the next phrase too. Over that span the layers
leave in order:
- high is gone at 40%
- low and fx at 75%
- base on the final bar line

A heard position that steps back by a hair (mix timing) is not a loop
wrap. Anything still sounding at the bar line, for example after a stall,
fades over 0.15 s. The node then frees itself. If the game scene fails to open, the menu starts
its music again and says so on a page. Leaving the menu any other way stops
the music.

With no score files (before the theme is exported), the menu is silent and
works normally.

**Preparing the score.** `tools/prepare_menu_score.py` reads
`assets/audio/source/menu_theme/map.json` plus the Logic exports it names, and
writes `audio/music/menu/`:
- seamless loops, one per stem
- `score.tres`
- `jingles/b<button>_<kind>_<chord>_<variant>.ogg`
- an optional `arrival.ogg`
- `score.json`

One common gain is applied, capped at −8 dB. `map.json` carries:
- `bpm`, `beats_per_bar`, `bars`, `phrase_bars`
- `chords` (bar → name)
- `stems` (id, file, layer, button, trim_db)
- `arrival`
- `jingles`: button, kind (hover or press), chord and variant, plus either a
  rendered `file` or a `cut` (stem, start_bar, beats) from a stem

## Loading

`ArtLoadingScreen` is a transient root-owned CanvasLayer above both scenes. It
shows `loading.png`, a bar and a drawn rotating circle, with no text.
- **First half:** the scene's own resource progress, polled with
  `ResourceLoader.load_threaded_get_status`.
- **Second half:** the Metro's runtime build reports through
  `stage(owner, fraction)`.

The tree stays paused under the cover. The Metro sets `loading_complete` only
after its candle lane and library finish. A reported error, or a 60 s timeout
on the runtime build, restores the previous scene. New Game resets CityState
and opens `maps/metro.tscn`. The player spawns in the candle lane's clear
walk, facing the curandera.

## Tests

- `tests/main_menu_test.tscn` (headless) covers:
  - the column, selection parity, band placement and glaze, and that the
    painting is never over-enlarged
  - the pages, settings persistence, Escape/Back and focus
  - the living city's wiring
  - music wiring: hover jingles, Lore stirring the haze, a single New Game,
    and recovery when the game fails to load
- `tests/menu_music_test.tscn` (headless) covers the clock, layer targets and
  glides, idle and waking, the lean, the silent fallback, jingle timing,
  chords, variants and voice limits, and the ending landing on its bar line.
  It runs against `tests/fixtures/menu_score/`: numpy tones put through the
  real tool by `tests/fixtures/make_menu_score_fixture.py`. These are test
  data, not game audio.
- `tests/menu_scene_change_test.gd` (headless, `--script`) presses New Game
  into `tests/fixtures/tiny_game.tscn`. It checks that the theme is still
  in the root, finishing its phrase, after the menu is gone, and that it
  then frees itself.
- `tests/tools/test_make_city_masks.py` and
  `tests/tools/test_prepare_menu_score.py` use stdlib unittest:
  `python3 -m unittest discover -s tests/tools -p '<file>'`.
- `tests/visual/main_menu_preview.gd` (native renderer) parks the pointer,
  then:
  - checks that unmasked architecture is pixel-still while the sky moves
  - captures each band, a band edge, a mid-glide frame, every page and a
    2560×1080 window to `/private/tmp/main-menu-*.png`
  - plays New Game through to the Metro
