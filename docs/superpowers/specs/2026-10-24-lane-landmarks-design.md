# The candle lane's landmarks — design

Oct 24 2026. The first of three builds that make the Metro feel lived in, in the user's order: **(1) the candle lane's
readability pass (this document)**, then (2) the Pasaje, then (3) the nearest line's south platform and track with the
way up to it. Each later build gets its own design.

## Intent

From the Pasaje, at the lane's mouth (`maps/metro`, plan x −4), the curandera's stall and the librarian's shop should
read as landmarks: the player should know *that is hers* and *that is his* before walking in. Today they do not. The
in-game views (`tests/diag_lane_landmarks.tscn`, stills in `docs/superpowers/refs/underground/landmarks/`) show the eye
going first to the blank station sign's glow, the shrine niche, the nahual and the chapel's red haze; her stall reads
as *a* stall 17 m in, her magenta neon a dot; his shop does not register at all behind the cart and the nahual.

The cause the user named: the lane is the only finished place in a greybox Metro, so everything in it is equally
detailed and nothing leads. This pass makes two things lead.

## What reads from the mouth (the constraint everything follows)

Her stall (north wall, ~17 m in) and his arch (south wall, ~19–27 m in) are seen nearly edge-on from the mouth. Flat
things on a wall vanish. What reads is what **reaches into the aisle's space**, **changes the light's colour**, or
**moves**.

## Goals

1. From the mouth view (`2_at_the_mouth`), each place shows a mark that is unmistakably its own:
   - **hers:** a line across the corridor, a hanging silhouette, a warm haze;
   - **his:** a red light that nothing else in the lane makes, and pages drifting out onto the walk.
2. Every mark has a cause in the world (the user's rule, *world built by its events*), and every face meant for words
   is left blank for the user to write.
3. The rest of the lane stops competing: the blank station sign stops being the brightest thing at the mouth, and the
   shrine niche reads quieter than her stall.

## Non-goals

- New words, sign faces, or glyphs. All are the user's.
- The Pasaje, the chapel, and the platform (later builds).
- Changing the lane's layout, its crowd, or its pockets beyond the two light changes named below.
- Sound (the user is sourcing recordings).

## Anti-goals (a failure even if it works)

- A modelled human figure of any kind (*no modelled human figures*).
- Downloaded VFX or textures; every effect is ours (*no free VFX assets*).
- Uniformly sprinkled props. These are staged marks with a cause (*scenes, not sprinkles*).
- Anything a shade or the player walks into: the walk down the lane's middle stays clear.
- Visual faults waved through (*never call visual defects harmless*).

## The pieces

All positions are in the lane's own frame (`maps/candle_lane.gd`, the bay frame: x along the lane, z across).
- **Walls:** north wall face z −2.35 (BACK_WALL), south wall z 4.55 (FAR_WALL); the vault springs at 4.0 (HEIGHT).
- **Her stall:** at the origin, its counter face at z 0, its back on the north wall.
- **His shop:** the front spans x 2.2–10.2 on the south wall; the arch's middle is x 6.2.
- **Services:** run along both walls at 2.75–3.9 m.
- **The crowd:** the shades walk the middle at z ≈ 0.2–2.6.

### Hers: the curandera

1. **Marigold garland across the walk** (kit piece `garland`). It is strung from her awning's front corner over the
   aisle to the south wall's pipe bracket opposite.
   - **Clearance (my call):** over the walk (the crowd's routes, z 0.2–2.6, and the player's capsule) it hangs no lower
     than 2.6 m. Its end at her awning may start lower, where it ties on over her counter: her front rail is at 2.35 m
     (`stall.py`'s `FRONT_H`). Any riser or tie it needs belongs to the new kit, not the finished stall. Thick ropes of cempasúchil heads, with papel picado flags hung from it whose cut patterns are
   abstract and contain no letters.
   - **Cause:** she strings it each season for the dead she prays for; it is the one line crossing the corridor before
     the chapel.
   - **Draught:** it sways on the lane's one draught.
2. **Tin milagro, a sacred heart, about 0.5 m tall** (kit piece `milagro_heart`), hung from an iron bracket that
   juts from her stall's frame toward the aisle.
   - **Clearance (my call):** anywhere over the walk its lowest point is above the player's 2 m capsule (≥ 2.1 m), and
     over her counter it stays clear of her two customers' places (x 0.65 and 1.85).
   - **Cause:** offerings left by those she healed are nailed to her frame, and this big one hangs out to be seen.
   - **Look:** pressed tin with flames at its top, catching her bulb.
   - **Motion:** it turns slowly on its hook.
3. **Copal haze** (effect, ours): her censer's thread is fed into a slow amber haze pooled under the vault over her
   pitch, lit from below by her bulb. It must read from the mouth as a warm cloud at her place, distinct from the
   candles' points of light.

### His: the librarian

4. **Red glass lantern on an iron bracket over the arch** (kit piece `red_lantern`).
   - **Placement:** the bracket juts from the south wall over the arch's middle at about 3.0 m, the lantern hanging
     clear of the arch's head. The air line (2.75 m) and the fire main (3.1 m) run across the shopfront there, so the
     bracket is routed round them, never through them.
   - **Its light:** red, his shade's red #e63833, falls on the walk and the opposite wall. It is the only red light in
     the lane; the chapel's haze at the far end is a different, deeper red-orange and must stay distinguishable.
   - **Cause:** a reading lamp of a bookseller who works by night; the red glass is old darkroom glass.
5. **The threshold dressed**: a lectern (kit piece `lectern`) just outside the arch with a chained book on it. The
   existing `ChainedBook.gd` behaviour may be reused (the cover straining against its chain), with the lectern's book
   as its own placed copy, not the desk's. Beside the arch, a book barrow (kit piece `book_barrow`): a low wooden
   handcart heaped with books.
   - **Placement:** both sit against the shopfront, clear of the walk (z ≥ 3.4) and of his doorway.
6. **Loose pages drifting out** (effect, ours).
   - **The loop:** now and then (every 8–20 s) one to three loose pages lift out of the arch on the draught, skate and
     tumble along the floor for several metres, and settle and fade.
   - **Direction (my call):** they ride the lane's one draught (`DRAUGHT`, +x, from the mouth toward the chapel), not
     against it, and are carried harder by its surges (trains, the dark spells). The lane keeps one wind, every mark
     keeps its cause, and from the mouth the movement still reads, going away down the lane. The draught itself is not
     changed.
   - **Their path (my call):** they run out into the middle of the walk, where the cart and the nahual do not hide them
     from the mouth.
   - **Readability:** they must be bright enough against the floor to catch the eye from the mouth.
   - **Words:** pages are blank or carry abstract strokes, never legible text.

### The lane as a whole

7. **The blank station sign** (`enamel_sign` under the vault at the mouth) is the brightest thing in the mouth view
   because the Pasaje's teal neon (`MOUTH_NEON`, 2.3 energy, 5.5 m) washes its blank face. Bring it down until it no
   longer leads (dim the neon's reach on the sign, or the sign's own response), keeping the mouth's teal pocket that
   the pockets build (`_pockets`) relies on.
8. **The shrine niche** (north wall near the mouth) reads quieter than her stall from the mouth: its light lowered,
   not removed.

## How it gets made (decided)

- **Approach (picked by the user):** the landmarks are their own small kit with their own painted atlas.
  - **Script:** `tools/eclipse/lane_landmarks.py` → `assets/eclipse/kit/lane_landmarks.glb`, built by the existing
    pipeline (`tools/eclipse/lab.sh`, `tools/textures/layered_atlas.py` with the underground recipes, Godot import).
  - **Atlas:** at most 2048, so a piece rebuilds in a minute or two.
  - **Placement:** `maps/candle_lane.gd` places them, as it places `candle_lane.glb`'s pieces.
- **Rejected approaches:**
  - Folding them into the 4096 candle-lane kit: every change re-bakes 10 minutes and puts the finished lane at risk.
  - Reusing existing props (the stall's marigolds, the bay's lamp): they already read as background.
- **Effects** use our existing systems:
  - the haze from `Fumes.gd` / `Vfx.gd` presets or a fog volume;
  - the pages as our own mesh effect (`MeshVfx.gd`-style, or a small script of their own).
  - No downloaded sprites.
- **Model standard** (*kit pieces built right*): solid closed meshes, no layered quads (the 3 cm gate), no shared atlas
  texels, details big enough to read, past-PS2 Metro standard with the pixel grid off, and the user's brush sheets
  visibly carrying the paint, toned painterly.
- **Review, piece by piece** (*models one by one, supervised*):
  - **Stills:** each piece goes to the user as in-game stills, from the mouth view and close, from the real map
    (`tests/diag_lane_landmarks.tscn` grows the views), never a staged backdrop.
  - **Order:** garland → milagro → lantern (with its light) → lectern and barrow → the two effects → the sign and niche
    light.
  - **Gate:** the next piece starts after the user's word on the last.

## How we know it works

- **Mouth view, windowed** (1920×1080, player FOV 75, `tests/diag_lane_landmarks.tscn`, view 2). Each check is
  measurable on the frame:
  - her garland's silhouette crosses the corridor above her stall;
  - a region of red light at his arch, distinct in hue from the chapel's haze (my call: red is a hue band around
    his #e63833, about 350°–15°; her magenta neon sits near 336°, outside it);
  - pages visibly moving across consecutive frames;
  - the station sign no longer the frame's brightest region.
- **Lane suite** (`tests/candle_lane_test.tscn`) gains checks:
  - every piece is placed, lit and clear of the walk (the crowd's routes and the player's capsule, *player capsule is
    a metre wide*);
  - the garland's lowest point is ≥ 2.6 m;
  - the lantern's light is red and is the lane's only red light;
  - pages spawn, move with the draught and settle;
  - every word face is blank.
- **Metro suite** (`tests/metro_test.tscn`): the set still fits the map (M10–M13).
- **Kit gate:** `tools/eclipse/test_kit_bpy.py` for the new kit (layered faces, slivers, budgets, atlas overlap).

## Left to the builder

- Exact sag, flag count, lantern and lectern shapes, milagro detail, haze density and page counts, within the heights
  and clearances above.
- Exact budgets per piece within the kit gate's norms.
- How the sign is dimmed, as long as the mouth's teal pocket survives.
- How the review views are framed beyond the mouth view and one close view per piece.

## Open for the user (asked in review, not blocking the plan)

- The sacred heart's exact form, once they see its first still.
- The papel picado's colours (default: the stall's marigold orange, magenta, and a Metro blue).
