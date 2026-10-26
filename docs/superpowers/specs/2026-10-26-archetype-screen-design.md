# Archetype screen (piece 3 of 4)

Date: 2026-10-26. Status: built; played and approved by the user.

This is part of the main menu overhaul (`2026-10-25-main-menu-overhaul-design.md`). It follows pieces 1 (look and feel) and 2 (music redesign).

## Why

After New Game, the player chooses who they are, from the user's portrait sheet (`assets/ui/archetypes/archetypes_sheet.webp`, three panels). This is the menu's peak: the music's high layer comes in here.

Each archetype has to *feel* different. Its own sound, motion and effects communicate the user's line:

- **Derivé**: "Guided by their body, their gut instinct and their fists."
- **Thaumaturge**: "Manipulates people and the occult as easily as he breathes."
- **Factotum**: "Knowledge and experience are both your weapon and your tools to traverse the world."

The names and lines are the user's words, with one typo fixed ("instinct"). They're used as written.

## Goals

- Three portraits as a triptych. The one you point at widens, wakes into full colour and runs its effects; the other two dim and narrow.
- Effects in the manner of **Deadlock's stylised effects**: bold graphic shapes that move in held, stepped frames, not smooth tweening. They are **painted with Disco Elysium's oil brush**: ragged bristle edges that boil at about 8–9 fps, like the menu's washes.
- Effects sit **behind and around** each portrait and spill past its edges. **Nothing glows or tints over the painting.**
- Fine deco detailing: stepped gold corner brackets, a double rule with a small lozenge under each name, and an emblem per archetype that's abstract but reads at a glance.
- Each archetype has its own hover sound and its own confirm sound, in the song's key and chord, on the jingle bus.

## Non-goals

- What each archetype *does* in play (skills, starting kit, talk options). This screen only records the choice; gameplay comes later in its own design.
- Higher-resolution portraits: the user has none, so the sheet is used as it is.
- The main menu's 3D set-piece.

## Anti-goals (a failure even if it works)

- Any glow, bloom, colour wash or overlay drawn over a portrait.
- Smooth, floaty "web UI" motion or soft blurred particles. The effects must look painted and stepped.
- Downloaded effect sprites or textures: we draw our own (`no-free-assets-make-our-own`).
- Procedural audio: sounds are rendered in Logic from MIDI we compose.
- Placeholder captions. The screen has **no heading** unless the user writes one. "Choose who you are" in the mockups was only a placeholder.

## What the user decided

**Layout:** the triptych, as in mockup v3 (`.superpowers/brainstorm/27138-1792977562/content/archetype-triptych-v3.html`), which the user approved ("its good").
- **Portraits:** smaller than v2. They sit centred in a row over the living city painting, dimmed further than on the main menu.
- **Under each portrait:** emblem, name (MenuType.choice), ornament, and the line (MenuType.body_italic), which unfolds only on the selected card.

**Music:** the ARCHETYPE state (base + low + high) is already built in piece 2. Confirming finishes the phrase and fades the song, like New Game today.

## The effects per archetype

All three are behind the portrait, with boiled painterly edges and stepped motion. These are my proposals for the shapes, drawn from mockup v3:

- **Derivé (body, gut, fists):**
  - licks of painted fire and ember daubs rising from the floor behind him
  - a burst of red-orange brush strokes flaring out behind the fists, on a short punch rhythm
  - glowing cracks under his feet
  - On select, the portrait does a punch-in: a small scale jolt with a held frame (the menu's press-in language, stronger).
- **Thaumaturge (people and the occult):**
  - violet smoke coiling behind him, echoing the halo in the art
  - a painted gold sigil ring with glyphs, turning slowly in steps
  - a second, dashed ring turning against it
- **Factotum (knowledge and experience):**
  - ink-blue washes bleeding out behind him
  - inked construction lines and a compass arc drawing themselves around the figure
  - a few painted pages lifting away

**Emblems** (gold line marks, the v3 designs refined):
- Derivé: four stacked knuckle arcs over a wrist bar, in a broken ring
- Thaumaturge: an eye with a slit pupil in a twelve-ray sunburst
- Factotum: an open book of two stepped planes, crossed by a compass needle

**Confirming:** the chosen card's effects surge for a beat (a bigger flare, ring or draw). The other two cards fall away into the dark. Then the loading cover opens.

The v3 mockup showed a pale rim around the dimmed cards' edges. That's a defect, not the look. In the game, every card edge fades into the dark city with no pale rim, and a native capture checks it.

## Sounds

Each archetype gets:
- a **hover** motif (about a beat), played the instant it's selected, in the chord sounding now
- a **confirm** motif (about two beats), played on the next eighth

Both play on the `MenuJingles` bus (delay + reverb), like the main menu's jingles. They're composed as MIDI by `tools/compose_menu_parts.py`, rendered dry in Logic with the user, cut by `tools/prepare_menu_score.py` into the score's `jingles` table, and played by MenuMusic with the same voice limits.

My proposals for the voices, each built from the song's own instruments so they sit inside the mix (the user picks patches in Logic):
- **Derivé:** low piano octaves with the Trip-Hop Drums' kick and snare under them: a struck, physical figure.
- **Thaumaturge:** glockenspiel over a choir swell: a high, uncanny figure that hangs.
- **Factotum:** Rhodes with a muted trumpet answer: a quick, clever jazz figure.

All notes are chord tones of the four loop chords, with two variants each, as in piece 2.

## Flow

- **New Game** on the main menu opens the archetype screen in the same scene, over the same living city.
  - The words and washes fade, and the cards rise in one at a time.
  - The music goes to ARCHETYPE.
  - The loading cover no longer opens straight from New Game.
- **Selecting:** mouse hover, or Left/Right (and A/D). The first card selected on arrival is the middle one, Thaumaturge.
- **Confirm:** a click, Enter or Space on the selected card.
  - Writes the choice to `CityState.archetype`, one of `&"derive"`, `&"thaumaturge"` or `&"factotum"`.
  - Plays the confirm sound and surge, calls `music.start_game()`, then opens the loading cover to `game_scene` as New Game does today.
  - If the scene fails to open, the archetype screen stays open with the menu's existing error message.
- **Back:** Esc (or a Back word in the menu's style, bottom left) returns to the main menu. The cards fall away, the words come back, and the music returns to BROWSING.
- **Double confirms and confirm-then-Back are ignored**, the same guards as the Quit confirm.

## Approaches for the effects

1. **Shader brushwork plus our own painted flipbooks (recommended).**
   - canvas_item shaders draw the large shapes (fire licks, smoke, rings, washes, lines), with noise-boiled bristle edges stepped at 9 fps, the same technique as `menu_wash.gdshader`.
   - Small painted things (embers, pages, glyphs) are tiny flipbook sheets that a Python tool paints from our own brush masks.
   - Cheap at runtime, and tunable live with the user.
2. **Everything as painted flipbooks.** The richest hand-made look, but every change means repainting sheets, and large sheets cost memory.
3. **GPUParticles2D with painted textures.** Smooth by nature, which works against the stepped Deadlock look. Rejected.

## Changes in the code

- **New `ArchetypeScreen` (Control):** built in code like MenuPages. It owns the three `ArchetypeCard`s, input, Back and confirm.
- **New `ArchetypeCard`:**
  - the portrait cut from the sheet at the known panel splits (0–653, 660–1334, 1341–2000), its edge fading into the dark
  - the effects layer behind it, the frame, the emblem, the name, the ornament and the line
- **New shaders** for the effects and for the cards' edge.
- **Emblems** as SVG files under `assets/ui/archetypes/`, imported as textures.
- **`MainMenu`:** New Game opens the archetype screen instead of loading. Confirming loads the game.
- **`CityState`:** `var archetype: StringName = &""`, included in what a save will write.
- **`MenuMusic`:** archetype hover and confirm jingles, with their own entries in the jingles table.
- **The sound pipeline:** new motifs and map entries.
- **Tests:**
  - a headless suite: flow, guards, the CityState write, music states, keys
  - the native preview captures each selection and confirm
  - tool tests for the new jingles

## Left to the builder

- Exact sizes, timings and colours, tuned in captures, with the triptych smaller than v2.
- Shader details and flipbook frame counts.
- The motifs' notes, within the chord-tone rule.
- The order the effects fade in on select, keeping the punch-in, held frames and stepped timing.
