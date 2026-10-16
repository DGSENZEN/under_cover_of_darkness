# Mexico City demo: the program

Settled with the user on 2026-10-16. This document records the demo's intent and the order of work. Each project below gets its own short brainstorm and design when we reach it. Lines marked *(Claude's call)* were proposed by Claude and accepted, or are guesses the user has not corrected; the rest is the user's.

## Intent

The demo is an immersive sim in the line of Thief, Deus Ex and Dishonored. It uses Deadlock × Hellboy painterly art and is set in the alternate 1920s post-colonial Mexico City of `docs/superpowers/refs/mexico_city/bible.md`.

Gameplay comes first. Main objectives must be real and traversal must be ready before more art.

- **Open-ended maps** with many approaches to every quest: stealth, tools, melee, magic, talk.
- **Main objectives are concrete**: obtain a forbidden tome, fight a specific creature, talk to specific people.
- **The world is lived in.** Side quests are implicit and arise from talking to certain NPCs, or from being in certain places at certain times.
- **No quest markers, ever.** No marker over quest-givers' heads and no map pins. Goals reach the player as lines in the letter (the existing JobBook/JobState/LetterText spine).

## Structure

- **Hub:** the Zócalo.
- **Districts:** Lomas de Chapultepec, Roma and Condesa, reached by Metro.
- **Order:** perfect the Zócalo first (gameplay, Metro look, vibe, ambience), then one district at a time.
- **Main quest:** investigate a mysterious series of murders, disappearances and illnesses across the city. Ghostly familiars hint at it and give the protagonist the need to pursue it.
- **The Zócalo is done when** the main lead points the player onward to the three districts. By then the Zócalo has become a hub dense with weird little side quests, easter eggs, and encounters with mythical creatures that have their own quest lines.

## The opening (first five minutes)

The opening teaches the vibe, how to move, how to talk, how quests are given, and how to interact with the world.

1. **The Metro car.** The player arrives by Metro; the ride hides the load.
2. **The familiar.** A ghostly familiar talks to the player. This is the first conversation, and it teaches the dialogue box by using it. The familiar entices the player into the main quest, which appears as a goal in the letter.
3. **The walk out.** The player walks out through the Metro line and station and slowly discovers the Zócalo. The station spaces already exist in the Zócalo plan.

*(Claude's call)*: control begins on the moving car, and the familiar stays with the player afterwards in the manner of Dishonored's Heart.

## Talking

- **When:** walk up and use the frob key.
- **Look:** a dialogue box with the NPC's portrait, in the Persona 5 style direction but not literally big and slanted. Mockup "A" of 2026-10-16: painted portrait cut-in, dark text box with a coloured edge, bold option tags in marigold, cochineal red for special options.
- **Options depend on the type of NPC.** Mixed in are a few Disco Elysium touches: a power or sense of the player's occasionally interjects and unlocks an option.
- **Words:** the user writes all dialogue. Claude builds systems with placeholders.

*(Claude's call)*: the world keeps running behind the box.

## Magic

There are several schools, not Obsidian alone (a Hellboy and Deadlock mix). Each school is a real 1920s tradition that turned out to work, and each is tied to a faction (every strange thing has a cause in the world's events).

| School | Root in the world | Play |
|---|---|---|
| Obsidian | Tezcatlipoca's mirror, Dee's Pachuca mirror, Mictlán's obsidian wind | Seeing, reflecting, cutting |
| Copal | Curanderas, limpias, the curandero night market | Smoke wards, healing, cleansing *susto*, blinding smoke |
| Séance | Madero's real dead, séance registries, Kardecist and Theosophist salons | Ghost witnesses, spirit scouting and possession, bindings |
| Nahual | Nahualli and tonalli | Owl sight, dog scent, beast strength |
| Lumen | The Light Company's lamps are wards, and their science was stolen | Arc bolts, lamps lit or killed at range, galvanic charges |
| Relic | El Secreto's licensed confiscated relics | Consumable sacred objects; carrying them unlicensed is a crime |

**Starting spells:**
- **Blink:** Obsidian, a mirror-flash step.
- **Projectile:** Obsidian, a glass shard.
- **Ward:** Copal, smoke that blocks blows and spirits.
- **Empower:** Nahual, a few seconds of beast strength for the next blow, jump or blink.

*(Claude's call)*: one shared, slowly refilling resource. New schools are learnt from their practitioners through district side quests, and choosing which to learn is the RPG choice.

## Traversal

- The moves exist: mantle, vault, hang, shimmy, corners, leaps, climb, ropes.
- **Problems the user found:** moves that don't trigger, and getting stuck while ledge climbing and hanging.
- **Not built yet:** the Zócalo is not climbable. It has no rooftop or azotea routes, balconies, ledges or drainpipes.

## Order of projects

1. **Traversal fixes:** reliable ledge hang and climb (failing test first for every fault).
2. **A climbable Zócalo:** rooftop and azotea routes, balconies, ledges, drainpipes.
3. **Talking and quests:** the dialogue box, menus that depend on NPC type, goals created at run time from talk, place and time, a world clock, and saving to disk.
4. **Magic:** the four starting spells and the school framework.
5. **The opening:** the Metro car, the familiar, the station walk-out.
6. **The living Zócalo:** civilians with routines, staged scenes turned into people, side quests, easter eggs, creature quest lines (the user's words).
7. **The street and foliage kit:** detailed roads with Deadlock's Greenwich-line texture work crossed with the Zócalo, and a family of painterly foliage.

Then Lomas, Roma and Condesa, one at a time.

## Standing rules

- **Models are built one at a time under the user's supervision.** Each model is fixed (jitter, weird geometry, seams) before the next starts.
- Never call a visual defect harmless; closed solid kit pieces; every strange thing has a cause; no free VFX assets; ask the user for textures and new designs.
