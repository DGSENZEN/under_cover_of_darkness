# Main menu overhaul: painted bands, living city, reactive score

Date: 2026-10-25. Status: design for approval. The 3D set-piece menu is a later, separate project.

## Intent

The title screen should feel unique and alive, like part of the game's world. Right now it's a painting with a tight 2×2 block of picture cards that don't read as menu choices. The plan:

- **The screen:** a spaced column of words whose selection is a band of painting brushed across the city.
- **The background:** your painted city stays still. Only the things that would move in that world move.
- **The music:** your own menu song plays as four live-mixed layers, like Deadlock's Hideout. Every button answers with its own short jingle that fits whatever the music is doing.

**Who it's for:** the player's first minute with the game. The song and the screen together should set up a neo-noir, occult, 1920s Mexico City thriller before the player has done anything.

## Goals

1. **Layout:** four choices in a clear column with real space between them, so they read as a menu at a glance.
2. **Selection:** a painterly band carries the selected choice's illustration. It is glazed into the city's palette, so selection, illustration and background read as one canvas.
3. **Motion:** calm, readable life in the background, never warping the painting.
4. **Settings, Lore and Continue** open in the same painted language, not a stock grey box.
5. **The song:** `hasta_los_huesos_overworld` grows from a two-track sketch into a full track. The palette is neo-noir, trip hop and occult, with Latin-jazz colour (bolero, danzón, son).
6. **Live mix:** the song plays as four layers that re-weight with what the player does on the menu.
7. **Jingles:** each choice has its own instrument and short jingle. They are always in key with the current chord and in time where timing matters.
8. **Starting the game:** the music resolves into the loading screen instead of cutting off.

## Non-goals

- The 3D set-piece menu. It comes later; this design must not block it. The band and the music system should carry over.
- A save/load system. Continue still explains that no save exists yet.
- New settings. Settings keeps master volume and awareness marks. Restyling them is in scope; adding options is not.
- Changes to the in-game combat score (`scripts/Audio/Music.gd`) beyond reusing patterns from it.
- Repainting or editing your city painting or your four illustrations.

## Anti-goals

These would make it a failure even if it technically works:

- **The painting swims, smears or warps.** This is the current `living_paint` effect, and it reads as distracting.
- **Jingles clash with the music,** or the hover sound arrives late enough to feel laggy.
- **Pastiche:** it sounds like a "Latin music" preset, or a 1990s trip-hop parody. *Chinatown* is the model: few instruments, period colour, no cliché.
- **Downloaded VFX.** Every effect texture is made by us (project rule). Sounds come from your song.
- **UI judged on a mock backdrop.** Screenshots and judgements happen in the real menu scene (project rule).

## Constraints

- **Engine:** Godot 4 project. `main_menu.tscn` is the main scene. The menu is a code-built CanvasLayer (`scripts/UI/MainMenu.gd`) laid out in a 1600×900 design area that scales to the window.
- **Art:**
  - `assets/ui/main_menu/city.png` (2944×1648).
  - `assets/ui/main_menu/buttons.png`, an atlas of four illustrations in reading order: New Game, Continue, Settings, Lore.
  - Choice colours: New Game `ef774c`, Continue `67c9ed`, Settings `929fdb`, Lore `efa25e`.
  - **No higher-resolution illustrations exist.** With rims cropped off, each illustration is only about 640–700 px wide. Settings and Lore are nearly square.
- **Illustration size in the band** *(Claude's call, since there is no hi-res source)*:
  - The illustration fills only part of the band, roughly the right half: about 750–800 design px wide, about 1.2–1.3× its native size at 1080p.
  - The band's torn, feathered edges and dark word end carry the rest of the width into the city.
  - Settings and Lore are framed on their faces, not stretched to the band's shape.
  - At 1440p and 4K the art is upscaled further and will look softer than at 1080p. This is a known, named limit, not acceptable-as-is.
  - The fix is an upscaled derived copy of the illustrations, made only if you approve it after seeing the in-game captures. The originals are never touched.
- **Audio buses** come from `Sfx.gd`. Menu music plays on `Music`. The menu has no `Music.gd` node; the combat score is not involved.
- **Loading:** `ArtLoadingScreen` handles the New Game transition and stays as is.
- **The song:** Logic Pro project `~/Music/Logic/hasta_los_huesos_overworld.logicx`.
  - D minor; project tempo 78 bpm (the window snapshot showed 74).
  - Track 1: Studio Grand piano ("Deluxe Modern"), about 16 bars.
  - Track 2: Drummer "Mixed Boom Bap" with an "NY Garage+" region of about 3 bars.
  - Track 3 is the default stereo output.
  - Claude cannot hear audio. Every musical decision is auditioned by you.
- **Existing tools:** `tools/prepare_score.py` turns Logic stems into synced Godot section clips (used for *Hasta los huesos*). Godot's `AudioStreamSynchronized` plays locked stems with per-stream volume (already used by `Music.gd`).

## Approaches considered

**How the song gets finished**
- MIDI parts written by Claude only: exact harmony, but stiff grooves.
- Logic's own players only (Drummer, Latin Percussionist, Bass Player on a Chord Track): natural feel, but slow to steer note by note.
- **Chosen: both.** Logic's players carry the grooves (drums, Latin percussion, bass). Claude writes MIDI for everything melodic and for the jingles, which need exact notes. You audition, swap instruments and keep or cut.

**Where the menu music lives**
- A menu mode inside `Music.gd`: rejected. That script is built around guards, wounds and fights, so either side's changes would risk the other.
- **Chosen: a new `MenuMusic` node.** It reuses `Music.gd`'s patterns (synced stems, a clock read from playback position, gain envelopes) with its own layer weights and the jingle player.

**Order**
- Song first, then everything else: clean, but nothing playable until the music is done.
- **Chosen: in parallel.** Build the screen and the music system first against placeholder stems bounced from the current sketch. Finish the song together in Logic meanwhile. Final stems and jingles drop in at the end.

**Background motion** (from the conversation)
- Tune the existing flow warp: rejected, because the warp itself is the problem.
- **Chosen:** keep the painting still and animate specific things that have a cause in the world. Brush edges move in a stepped, hand-painted "boil" instead of flowing.

## The screen (decided with mockups: layout A, selection 2b)

Mockups are local only (gitignored): `.superpowers/brainstorm/27138-1792977562/content/menu-layouts.html` (option A) and `menu-selection-v2.html` (option 2b).

**Layout**
- The title stays at the top left: "UNDER COVER / OF DARKNESS", the existing serif.
- Below it, the four words sit in one column, in capitals with wide letter spacing and generous gaps. In the mockup the gap is about 2.4% of the screen width.
- A dark gradient on the left keeps the words readable. It is already there as the "veil".
- The card frames from the atlas are gone. The illustrations live only inside the band.

**Unselected words** are dim, at about 60% opacity.

**The selected word:**
- turns full white
- shifts slightly right
- shows a thin vertical tick on its left in the choice's colour, with a faint glow

**The band** (the selection box), behind the selected word:
- **Shape:** a horizontal band about 40% of the screen tall, centred on the word, running from the left edge across about 90% of the width.
- **Edges:** torn, dry-brush edges with a feathered core. The far end fades out in ragged bristle streaks.
- **Contents:** the choice's illustration, placed to the right of the word so the face or figure is visible. Each illustration has its own vertical framing.
- **Glaze (2b):**
  - the illustration is slightly desaturated and darkened
  - a colour wash in the choice's colour sits at about 28%
  - a faint warm firelight glow bleeds through on the right
- **Readability:** dark by the word, opening into the painting about 40% of the way across.
- **Motion:**
  - changing selection glides the band to the new word, easing out over about 0.5 s
  - the illustrations cross-fade, so the band does not re-wipe each time
  - inside the band the illustration drifts very slowly (scale and pan over about 18 s)
- **Edge boil:** the edge shape steps to a new hand-drawn variant about 8–10 times a second, the way Arcane and Spider-Verse animate. It never flows smoothly and never warps the illustration itself.
- **The city** dims slightly (about 0.72 brightness, 0.85 saturation) while a band is showing.
- **Pressing** a word gives a short brightening pulse on the band, timed with the press jingle.

**Input**
- Keyboard and controller focus behave exactly like mouse hover.
- Up and down move through the column; Enter or Accept presses.
- Escape or Back closes an open page.
- Before any input there is no selection and no band. The first key press selects New Game. *(Builder's call: this keeps the current behaviour.)*

**Settings, Lore and Continue**
- **Opening:** pressing one makes its band spread to fill the right two-thirds of the screen. The other three words dim further but stay visible.
- **Lore:** the text is written over its painting in the menu serif, as readable paragraphs, with a scrim behind the text where needed.
- **Settings:** the master volume slider and the awareness-marks toggle are restyled as painted controls. A brush-stroke track and a pigment-dab handle are one possibility. They sit over its painting.
- **Continue:** a single short line ("No saved game yet. Choose New Game to begin." or similar) over its painting.
- **Back:** a word-styled button like the main column, or Escape, folds the band back to its word.
- **Removed:** the flat grey `PanelContainer`/`StyleBoxFlat` card is retired.

## The living city (replaces `living_paint`)

The painting is never displaced. Life comes from separate layers over it. Each element has a reason to move in this world:

- **Clouds:** slow drift of cloud wisps across the sky region. We paint them, or cut them from the painting's own sky with soft masks; we never download them.
- **City lights:** a few individual windows and the burning district flicker irregularly. Driven by a mask of bright pixels derived from the painting; per-light random phase.
- **Haze:** low, slow haze drifting over the lake. Our own painted sprites.
- **Reflections:** a gentle horizontal ripple applied only inside the lake's reflection region. Tiny amplitude.
- **Sky glow:** the moon or sky glow breathes slowly.
- **Music link:** flicker rate, haze density and glow follow the music's layer energy subtly. For example, the occult layer swelling while Lore is open thickens the haze and cools the glow.

Masks are derived from `city.png` without editing it. The builder decides the exact regions and shows you close-ups before calling it done.

## The music

### Four layers

Same roles as Deadlock's Hideout (Base, FX, Low, High; see `docs/superpowers/refs/main_menu/music_references.md`):

| Layer | Contents (target) | Character |
|---|---|---|
| **Base** | your piano (montuno-style figures in places), upright bass with a tumbao feel | always present, carries the song |
| **Low** | slow, dusty trip-hop break; Latin percussion (congas, bongos, güiro) on a cinquillo/baqueteo feel | the groove |
| **High** | the four button instruments' melodic lines: muted trumpet, nylon guitar, Rhodes or vibraphone, bells or choir | melody and colour |
| **FX** | occult layer: drones, bells, choir pads, reversed tails, vinyl/tape grit | the uncanny |

Each layer can be made of several instrument stems. Each button's instrument is its own stem inside High, so its jingle and its "lean forward" (below) come from the same part.

### How each screen weights the layers

Starting values; you tune them by ear:

| State | Base | Low | High | FX |
|---|---|---|---|---|
| Arrival (first bars) | in | out → in over ~4 bars | out | in |
| Main menu, browsing | full | full | rises with activity | low |
| Main menu, idle (~30 s no input) | low floor | fades out | out | low floor |
| Lore open | full | low | low | forward |
| Settings open | full | low | out | low |
| Continue open | as browsing | | | |
| New Game pressed | resolves (see below) | | | |

- **High is all four instruments together (your decision).** The four button instruments are written as interlocking lines that play at the same time over the piano and bass. That ensemble is what makes the layer "High". Before anything is selected, and while idle, High follows the table above.
- **The selected instrument leans forward.** While a word is selected, its instrument's stem inside High comes up a few dB. The other three keep playing underneath. Moving through the menu changes the colour of the song, not just its loudness.
- **Fades:** all weight changes are gain envelopes over 0.5–2 s, never cuts. Leaving idle brings the layers back on the next bar.

### Jingles

- **Instruments:** each choice has its own (New Game: muted trumpet; Continue: nylon or requinto guitar, a style choice since the requinto dates from 1944; Settings: Rhodes or vibraphone; Lore: bells or choir). Each jingle is cut from, or rendered with, that instrument's stem.
- **Hover/focus:** a short note or dyad that plays immediately, with no waiting for the beat (beat-waiting hovers feel laggy). It is pitched to the chord sounding at that moment.
- **Press:** a one-to-two-beat phrase that starts on the next eighth note (about 0.38 s at 78 bpm) and resolves inside the current chord.
- **Chord awareness:** the song's chord map (bar → chord), exported from Logic's Chord Track, is shipped as data. Each jingle is pre-rendered once per chord that occurs in the loop. At play time the menu picks the variant for the current chord.
- **Repetition guard:** rapid hovering cycles through two or three alternate voicings per chord. A voice limit (for example two hover voices per instrument) prevents pile-ups. *(Builder's call on exact numbers.)*

### Starting the game

When New Game is pressed (your decision: the song finishes its phrase as it fades out):
1. The press jingle plays.
2. The loading cover opens at once. Loading is never delayed for the music.
3. The song plays on to the end of its current phrase. Over that span the layers thin out (High first, then Low and FX) and the whole mix fades.
4. The phrase's own last bar is the ending: no separate cadence clip. The fade reaches silence on the phrase's final downbeat or tail.
5. If loading finishes first, the game waits for nothing. The music keeps finishing its phrase under the game's first moments, or the fade shortens so it reaches silence by the time the cover lifts. *(Builder's call; you judge it by ear.)*

No hard cut at any point.

- **Phrase boundaries** come from the finished song's structure (for example every 4 or 8 bars) and ship as data with the chord map.
- **The music must outlive the menu scene.** Starting New Game frees `main_menu.tscn`, so the menu music's player must move somewhere that survives the scene change until its fade ends: under the root, or owned by `ArtLoadingScreen`.

### Arrival

On launch, the menu opens with a build cue, a few seconds long, that lands on bar 1 of the loop. This matches Deadlock's title-to-Hideout bridge.

### The clock

- **Beat and bar positions** come from the stem player's playback position, corrected for output latency (Godot's audio-sync guidance), as `Music.gd` already does. No separate timer.
- **The loop:** a fixed number of bars, set by the finished song. It loops seamlessly with tails handled the way `prepare_score.py` handles section tails.

### Code shape

- **`MenuMusic` node**, owned by the menu scene. It holds:
  - the synced stem player
  - layer weights per menu state
  - the clock (`bar_now`, `beat_now`, `eighth_now`, `chord_now`)
  - the jingle player (hover now, press on the next eighth)
  - the New Game ending
- **Hooks:** `MainMenu.gd` tells it the state (browsing, idle, lore, settings, continue, starting) and which choice is selected. MenuMusic reports layer energy back for the visuals. The existing `music_marker` hook is replaced by this.
- **Bus:** `Music`. The master volume from Settings applies as it does today.
- **Preparation:** a sibling of `tools/prepare_score.py` (or a mode of it) turns Logic stems plus jingle renders into the menu's synced clips, jingle variants and chord map. It records hashes and levels like `score.json`. Source masters go under `assets/audio/source/` (gdignored), as for *Hasta los huesos*.

## Finishing the song in Logic

**How we work:** Claude drives Logic on screen and writes MIDI files. You listen and decide. Nothing is final until you approve it by ear.

**The steps:**
1. **Set the frame.** Confirm the tempo (78 vs 74) and the loop length with you, then lay out a Chord Track for the loop in D minor. This should be minor/diminished noir harmony that can be voiced as bolero or danzón.
2. **Grooves (Logic players).**
   - Drummer: a slow, dusty trip-hop kit, either the existing Boom Bap region extended or a different kit you choose. Use swing around 54–62%.
   - Latin Percussionist: Isabela, on a cinquillo/baqueteo feel.
   - Bass Player following the Chord Track, with a tumbao feel.
3. **Melodic parts (Claude's MIDI).**
   - montuno-style variations for your piano
   - muted-trumpet, guitar and Rhodes/vibraphone lines
   - bells and choir
   - the occult pad and drone parts
   - Claude writes each as a `.mid` file and imports it onto its own track. Instrument choice is yours.
4. **Texture.** Tape and vinyl character, reverbs and delays, using the Logic recipe in the music references doc.
5. **Jingles.** Write each button's hover and press motifs as MIDI per chord, rendered on that button's instrument track.
6. **Arrival.** Write the arrival build cue. The New Game ending needs no separate clip; it is the phrase finishing as it fades.
7. **Export stems.** Export per-instrument stems, the jingle renders, the chord map and the phrase boundaries at 48 kHz, the same way the combat score was exported.

**Placeholder stage:** until then, bounce the current sketch as two stems (piano → Base, drums → Low). Use simple placeholder jingle notes rendered from the piano, so the system can be built and tested.

## Verification

- **Headless tests:** extend `tests/main_menu_test` for:
  - the vertical column navigation, focus and hover parity, and the first-key-press behaviour
  - pages opening and closing with focus restored
  - band position following the selected word
  - menu-state changes reaching MenuMusic
- **New music test:**
  - layer weights per state
  - hover jingles fire on the same frame as the hover
  - press jingles start on the next eighth-note boundary
  - jingle variant matches `chord_now`
  - voice limit holds
  - New Game does not delay loading
  - the music's fade reaches silence at the end of the phrase it was in
  - the player survives the scene change until then
- **Native capture:** extend `tests/visual/main_menu_preview.gd`:
  - idle, each selection, a selection change mid-glide, each page, and the New Game transition
  - close-ups of band edges and city effects, so you can judge them in the real scene
- **Your ear:** every song change and the final mix are approved by listening in Logic and then in the game.

## Left to the builder

- Exact sizes, easing curves, boil frame rate (8–10 fps), mask regions and effect intensities, within the decisions above.
- The painted look of the Settings controls and the Back button.
- How masks and effect sprites are made: painted in Blender or by script, never downloaded.
- File and node names, and whether `PaintedMenuButton.gd` and `painted_button.gdshader` are rewritten or replaced. `living_paint.gdshader`'s warp is retired either way.
- The stem and jingle preparation tool's structure.

## Settled during the Logic sessions

These are data, not structure, so they don't block the plan:
- Tempo: 78 (project setting) or 74 (window snapshot).
- Final instrument per button. The proposal above is a starting point.
- Loop length and phrase length.
