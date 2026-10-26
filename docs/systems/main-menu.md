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

**New Game.** Pressing New Game opens the archetype screen (below) on the
ARCHETYPE layers (base, low and high). Confirming an archetype calls
`start_game()` under its transition and the loading cover. The song plays on to the end of its current phrase. If less
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
  rendered `file` or a `cut`: from a stem (stem, start_bar, beats), or from
  rendered takes (file, start_beat, beats). `cut.file` may list several takes,
  which are summed, and a take Logic trimmed short is padded with silence.

## The archetypes

After New Game, [ArchetypeScreen](../../scripts/UI/ArchetypeScreen.gd) shows
the user's three portraits as a triptych over the dimmed city (0.55): Derivé,
Thaumaturge and Factotum, each with the user's own line. There is no heading.
- **Cards.** [ArchetypeCard](../../scripts/UI/ArchetypeCard.gd) cuts its
  panel from `assets/ui/archetypes/archetypes_sheet.webp` (columns 4–649,
  664–1330, 1345–1996). Each card has stepped gold corner brackets, its SVG
  emblem, its name, a ruled lozenge and its line. The chosen card is full size
  and full colour. The others step back to 0.84, dimmed and greyed.
  `archetype_card.gdshader` gives the portrait torn, boiling edges that sink
  into the dark at the rim. It never tints or glazes the painting.
- **Effects.** `archetype_fx.gdshader` paints each archetype's effects in
  oils, stepped at 9 fps. They sit on one layer behind every portrait (the
  screen's "Effects" node) and spill past the card.
  - Derivé: a burst of strokes behind his fists on a 1.6 s punch rhythm, fire
    licks with bright cores, ember daubs, and cracks beside his feet. Choosing
    him jolts the card.
  - Thaumaturge: a smoke halo and rising wisps, a gold glyph ring turning in
    steps, and a dashed lilac ring turning against it. Choosing him breathes
    the card up.
  - Factotum: ink blots, construction lines with ruler ticks, a compass arc,
    and pages lifting. The lines ink in over 1.4 s.
- **Input.** Hover or Left/Right/A/D chooses; the middle card is chosen on
  arrival. A click on the chosen card, Enter or Space confirms. Escape or Back
  returns to the menu, which comes back exactly as it was, closed pages
  included. Back and double confirms are ignored once confirming.
- **Confirm.** The chosen card surges and the others fall away (0.55 s).
  Then `CityState.archetype` is set to `&"derive"`, `&"thaumaturge"` or
  `&"factotum"`, the confirm sound is queued, `start_game()` begins, and
  [ArchetypeTransition](../../scripts/UI/ArchetypeTransition.gd) plays its
  1.3 s full-screen transition from the card. It ends in the dark, and the
  loading cover fades in over 0.35 s. `archetype_transition.gdshader` acts on
  the painting itself (the screen texture) in muted oils with a canvas grain.
  - Derivé, instinct (smooth time): three heartbeats, each sooner, as tunnel
    vision narrows onto his card. The edges blur toward him, drain and redden,
    and bloodshot veins creep in from the borders, throbbing with the beats.
    Then one blow: the painting smears and caves, dark cracks spider out along
    the hook, a few drops of blood follow, and the pieces fall turning into the dark.
  - Thaumaturge, the glamour: the city twists around his card and drains to
    violet while smoke lids close. The ritual runs in smooth time with
    anti-aliased lines: a great circle (heptagram, star-point medallions,
    sigils waking in turn, a counter-turning rune band, crawling script, studs,
    a seal at the heart), five orbiting lesser circles with turning glyphs,
    spokes, a dotted orbit, ticks, sparks and motes. Sixteen inky eyes open in
    the smoke (almond lids, fibrous bone-lilac irises, slit, bar, twin or ringed
    pupils, a window highlight), blink at their own pace and look at him. It
    ends on a gold slit.
  - Factotum, the study (held steps): the painting prints as a cyanotype, a
    few rules and a compass go in, and notes and diagrams write in and wipe out
    ([ArchetypeTransition](../../scripts/UI/ArchetypeTransition.gd)'s lists:
    sums, rites in rubric red, creature notes, signs;
    [FactotumSketch](../../scripts/UI/FactotumSketch.gd): an eye in section, a
    skull, a hand's bones, a heart, ribs, a seal, a spirit's sigil, the
    planets). Indigo watercolour then floods it into the dark. The rites and
    creature notes are stand-ins for the user to rewrite.
- **Sounds.** Buttons 5, 6 and 7 in the score (`MainMenu.ARCHETYPE_JINGLES`).
  Each archetype has a hover and a confirm motif, in every chord with two
  variants, played on the `MenuJingles` bus.
  - Composed by `tools/compose_menu_parts.py` into
    `parts/archetype_jingles.mid` and `.json`: one 8-beat slot each; hover cuts
    are 3 beats and confirm cuts 6.
  - Rendered in the Logic project, dry, on the song's own patches: Derivé on
    Studio Grand and Vintage Cinema, Thaumaturge on Toy Glockenspiel and
    Mellotron Choir, Factotum on Deluxe Classic and Sugar Hill. They are
    tracks 32, 33 and 50–53, muted in the song, exported as
    `stems_jingles/<patch>_archetype.wav`.
  - Levels in the map (`gain_db`): Derivé +6, Thaumaturge +15.8, Factotum
    +16.3, which brings every onset to about −19 dB before the bus.
  - Each archetype sound dips the song by `MenuMusic.DUCK_DB` (5 dB), which
    comes back at 5 dB/s, so they cut through the high layer.

## Settings

[GameSettings](../../scripts/Settings/GameSettings.gd) keeps every setting in
`user://settings.cfg` (the first settings' keys, `audio/master_volume` and
`hud/awareness_marks`, are kept). It's a static store, loaded on first ask;
Retro, an autoload, asks at start-up.
- **Checking.** Each setting has a default and a range (clamped) or steps
  (anything else refused). A spoilt file falls back key by key.
- **Applying.** Volumes scale each bus from its own level (Master outright);
  buses made later get theirs (Retro hooks `bus_layout_changed`). The window
  mode, VSync (not headless), frame limit and keys (InputMap) apply at once.
  The camera (field of view, camera motion), turning (sensitivity, invert),
  Retro (pixel grid, brightness pass) and the HUD (subtitles, size,
  crosshair, marks) read it and follow `events().changed`.
- **Keys.** `bind(action, event)` swaps with an action that had the key;
  `reset_keys()`; kept as `key:<code>` / `mouse:<button>`.
- **Gotchas.** Its re-read is `reread()`, never `reload()`: on a script class
  that is `Script.reload`, which recompiles the script and resets its state
  (the test path never took, and the suites wrote the player's file). Set
  the file with `use_path()`. Listen with a node's method: a lambda left on
  the static notifier crashes the engine at exit. Statics keep no
  InputEvents (the default keys are text) for the same reason.
- [Settings.gd](../../scripts/UI/Settings.gd) keeps the first calls
  (`master_volume`, `awareness_marks`, `path`, `reread`) over the store.

[SettingsPage](../../scripts/UI/SettingsPage.gd) is the book, shared by the
main menu's Settings page and the pause menu: tabs (Audio, Video, Controls,
Interface) as small-caps words, rows of brush sliders, ‹ cyclers ›, On/Off
switches and keys. Up/Down, Left/Right, Enter, Q/E; a key row waits for the
next key or mouse button, Escape cancels only the wait.

## The pause menu

[PauseMenu](../../scripts/UI/PauseMenu.gd), on the HUD's own `PauseLayer`
(layer 60, over the level, under the loading cover). Esc in play pauses the
tree; the HUD opens the menu while paused.
- The painting `assets/ui/main_menu/pause.png` (the frozen game, dimmed,
  until it exists), a veil at the left, the title, and the words Resume,
  Settings, Main menu, Quit.
- Settings opens the book; Main menu and Quit ask first ("Main menu?",
  "Quit?", No ready). Main menu leaves through the loading cover.
- Escape: cancels a key wait, then a confirm or the book, then resumes. A
  click on the painting does nothing.

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
  - the archetypes: opening on the high layer, the user's names and lines,
    effects behind every portrait, layout, keys, Back restoring the menu as it
    was, the archetype sounds, a single confirm with its transition before the
    cover, and the choice kept in CityState
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
- `tests/tools/test_make_city_masks.py`,
  `tests/tools/test_prepare_menu_score.py` and
  `tests/tools/test_archetype_jingles.py` (every slot, chord tones only, each
  archetype in its own slots) use stdlib unittest:
  `python3 -m unittest discover -s tests/tools -p '<file>'`.
- `tests/visual/main_menu_preview.gd` (native renderer) parks the pointer,
  then:
  - checks that unmasked architecture is pixel-still while the sky moves
  - captures each band, a band edge, a mid-glide frame, every page and a
    2560×1080 window to `/private/tmp/main-menu-*.png`
  - plays New Game through to the Metro
- `tests/visual/archetype_preview.gd` (native) captures each archetype
  chosen, checks their effects move, and captures each transition at seven
  points, checking that it ends in the dark (`/private/tmp/archetype-*.png`).
- `tests/settings_test.tscn` (the store, buses, keys, the hooks),
  `tests/pause_menu_test.tscn`, and the HUD's pause checks in
  `tests/interaction_test.tscn` (U7, U13).
- `tests/visual/settings_preview.gd` and `tests/visual/pause_preview.gd`
  capture the book's tabs and the pause menu over a level.
- `tests/visual/menu_showcase.gd` is a scripted tour of the whole menu for a
  showcase video, recorded with Godot's movie maker:
  `godot --path . --resolution 1600x900 --fixed-fps 30 --write-movie out.avi --script res://tests/visual/menu_showcase.gd`
