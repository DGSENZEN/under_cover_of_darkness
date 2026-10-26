# Menu look and feel (piece 1 of 4)

Date: 2026-10-25. Status: design for approval.

This is piece 1 of four, in order:
1. look and feel (this document)
2. music redesign
3. archetype screen
4. official settings and the in-game pause menu

It builds on `2026-10-25-main-menu-overhaul-design.md` and replaces that document's band selection. Approved mockup (local only): `.superpowers/brainstorm/27138-1792977562/content/menu-look-final.html`.

## Why

The user played the menu and found it janky in its motion and timing. The selection should also sit *in* the word and melt into the city instead of being a separate band across the screen. The typography should be showier and read as literary and period, true to the influences.

## Decided with the user

**Type: deco title, book chapters ("Mix 2").**
- **Title:** "UNDER COVER / OF DARKNESS" in wide deco capitals (Poiret One, letter-spacing about 0.32 em), with a gold hairline under it (`d9b46a` fading to clear). Nothing else under the title: no tagline and no captions anywhere.
- **Choices:** book small capitals (Cormorant SC 500), each led by a gold italic roman numeral (Cormorant Garamond italic): I. New Game, II. Continue, III. Settings, IV. Lore, V. Quit.
- **Unselected choices:** dim, at about 50% opacity.
- **The selected choice:**
  - turns white
  - steps about 10 design px to the right
  - its numeral turns full gold
  - a small gold diamond appears to its left
  - a soft dark shadow around the letters keeps it readable over any painting

**Selection: one wash per word.**
- **The wash:** each word has its own wash, about 512×200 design px. It holds that word's painting at full colour and brushwork, with no desaturation, darkening or dark gradient.
- **Placement:** the wash sits right around the word, starting a little left of it.
- **Edges:** torn and dry-brushed at top and bottom, fading softly on every side, most of all to the left, where it melts into the city.
- **Strength:** about 92% opacity.
- **Framing:** each painting is framed on its subject (a face) at this small size.
- **No band:** nothing crosses the rest of the screen, and nothing glides between words.

**Quit.** A real fifth choice. It asks once to confirm ("Quit? Yes / No", in the same book style), then closes the game.

## Motion and timing

This is the fix for the jank.

- **Easing:** one ease-out curve everywhere: cubic-bezier(.22, 1, .36, 1), Godot's `TRANS_QUINT` + `EASE_OUT`.
- **Hover/focus:**
  - the word's colour, step and numeral answer within 0.2 s
  - the diamond pops in over 0.3 s with a slight overshoot (`TRANS_BACK`)
  - the wash blooms over 0.6 s, from 94% scale and offset about 10 px left to full
- **Leaving a word:** its wash fades over 0.4 s while the next word's blooms, so the two overlap with no snap.
- **Press:** a 0.12 s press-in on the word (scale to 0.97 and back), then the action.
- **Brush edges:** they still "boil" in steps (about 9 fps) but only at the edges, never moving the painting itself.

## Pages

Settings, Lore and the Continue message open as book pages:
- a chapter heading in Cormorant SC
- a gold hairline
- body text in Cormorant Garamond
- the page's painting large, at full colour, melting into the city on its left and around its other edges, behind the text

The other choices dim but stay visible. Escape or Back folds the page away with the same timings.

The Settings controls keep their current behaviour here. Piece 4 replaces them with the official settings.

## Unchanged

- The living city and its masks.
- The music system and its hooks (piece 2 changes the music).
- Mouse, keyboard and controller selection through one path.
- First input selects New Game.
- New Game's loading flow.

## Approaches

- **One wash per word (chosen).** Each word owns a small shader wash that fades in and out on its own. This matches the overlapping-fade timing and removes the travelling band that read as janky. The cost is five small shader layers.
- **One moving wash (rejected).** Less rework, but it keeps the glide.

## Fonts

Poiret One, Cormorant SC and Cormorant Garamond are under the SIL Open Font License.
- **Source:** downloaded from the official Google Fonts repository (with the user's OK at build time).
- **Bundled:** under `assets/fonts/`, with their `OFL.txt` licence files.
- **Credited:** in CREDITS.md.

The system Palatino fallback stays as Godot's fallback font.

## Left to the builder

- Exact mask shapes, shadow strength, per-painting framing and the Quit confirm's layout, within the above.
- How the old `MenuBand` code is retired: its page mode may become the page painting.
- Test updates. Tests check behaviour and timings, not exact pixels. Every look is judged in native captures of the real menu.
