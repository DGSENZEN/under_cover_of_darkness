# Main menu

Normal project startup opens `main_menu.tscn`. Its CanvasLayer sits above the
world's retro postprocess, so the supplied painted artwork stays as painted.
Controls scale together inside a centred 1600×900 design area. Design:
`docs/superpowers/specs/2026-10-25-main-menu-overhaul-design.md`.

## The screen

The title ("UNDER COVER / OF DARKNESS") sits top left. Below it,
[MenuWord](../../scripts/UI/MenuWord.gd) buttons form one column: New Game,
Continue, Settings and Lore. They sit at x 72, 64 design px apart, in
letter-spaced capitals.

- **Unselected words** are dim (alpha 0.6).
- **The selected word** turns white, moves 8 px right and gains a thin tick
  in its colour with a faint glow. The colours are `ef774c`, `67c9ed`,
  `929fdb` and `efa25e`.
- **Input:** mouse hover and keyboard/controller focus go through one path,
  `MainMenu.select(index)`. Nothing is selected until the first input, and
  the first key selects New Game. Up and down move without wrapping.

**The band.** [MenuBand](../../scripts/UI/MenuBand.gd) with
[menu_band.gdshader](../../scripts/UI/menu_band.gdshader) is the selection:
a 360-design-px band of the chosen illustration brushed across the city
behind its word.
- **Width:** it reaches the screen's left edge, including on windows wider
  than 16:9.
- **The painting:** it covers a 640×360 box in the right half, cut around its
  subject from inside its painted rim (`ART_REGIONS`, `ART_FOCUS`).
- **Edges and behind:** the band has torn top and bottom edges. The painting
  bleeds sideways into a dark word end and into the city behind, which shows
  through the band softened, darkened and glazed in the choice's colour.
- **Glaze:** the painting is desaturated slightly, washed at 0.28 in its
  colour and lit by a warm glow on the right.
- **Motion:** only the edges move. Their noise re-rolls about 9 times a
  second (a hand-painted boil) and never displaces the illustration. The
  painting drifts slowly (18 s each way).
- **Changing choice:** the band glides 0.5 s to the new word, and the
  paintings cross-fade over 0.6 s. The city dims to 0.72 while a band shows.
- **Pressing** a word pulses the band.

**Known limit.** The illustrations exist only at about 575 px inside their
rims. The wide ones are enlarged about 1.45× in design px, roughly 1.75× at
1080p and more at 1440p and 4K, so they look soft there. The fix is an
upscaled derived copy, which waits on the user's approval.

**Pages.** Continue, Settings and Lore spread their band over the right
two-thirds (`Rect2(530, 0, 1070, 900)`). Its left side tears, and the
painting moves right with torn edges all round.
[MenuPages](../../scripts/UI/MenuPages.gd) writes the page's content in a
560-wide column over a feathered scrim:
- Lore's text
- Continue's line: "No saved game yet. Choose New Game to begin."
- Settings' master volume (a brush-stroke slider with a pigment-dab handle)
  and the awareness-marks switch (a dab, filled when on)

Settings persists to `user://settings.cfg`. The other words dim to 0.35. Back
(a word) or Escape folds the page back, and focus returns to its word. There
is no grey panel.

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

**New Game.** Pressing New Game opens the loading cover at once and calls
`start_game()`. The song plays on to the end of its current phrase. If less
than a bar is left, it plays the next phrase too. Over that span the layers
leave in order:
- high is gone at 40%
- low and fx at 75%
- base on the final bar line

The node then frees itself. If the game scene fails to open, the menu starts
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
- `tests/tools/test_make_city_masks.py` and
  `tests/tools/test_prepare_menu_score.py` use stdlib unittest:
  `python3 -m unittest discover -s tests/tools -p '<file>'`.
- `tests/visual/main_menu_preview.gd` (native renderer) parks the pointer,
  then:
  - checks that unmasked architecture is pixel-still while the sky moves
  - captures each band, a band edge, a mid-glide frame, every page and a
    2560×1080 window to `/private/tmp/main-menu-*.png`
  - plays New Game through to the Metro
