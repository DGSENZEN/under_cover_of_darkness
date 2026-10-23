# Gunplay and magic: weight, aiming, and effects

Brainstormed with the user on 2026-10-23, after the revolver and magic build (`2026-10-23-revolver-and-magic-design.md`, branch `revolver-magic`). Lines marked *(Claude's call)* were proposed by Claude; the rest the user said or approved. The user approved the feel list, the controls, and the effects list as proposed ("yes", "yep it's good", "yep, looks good!"), and chose approach A.

## Intent

The user, having the build in hand: **"The gunplay needs to feel more weighty and generally more like gunplay. Not to mention, the effects need to feel better."**

So this pass does two things.
- It makes shooting feel like a heavy gun in a shooter.
- It replaces the stand-in effects of the revolver and the four spells with designed ones in the project's register: Hellboy's heavy, physical occult, with Deadlock's chunky, readable shapes and colour-coding, and every effect made of the stuff it comes from.

## Goals

### Controls (approved)

1. **Right mouse aims down the sights.**
   - The gun comes up to the eye and the view narrows a little.
   - Spread goes and the kick is steadier.
   - **Aiming is the two-handed grip.** "Both hands on the gun" from the first build becomes "aiming": G and the separate braced mode are removed. While aiming, only innate spells (Blink) work, as before.
2. **Spells are cast from their own keys, Deadlock-style.**
   - Hold 1 for Shard, 2 for Ward, 3 for Empower. Each is held while the circle closes or the pages turn; letting go early casts and spends nothing (as before).
   - Pressing the key raises the bare hand or the tome, so picking and casting are one action.
   - A spell key pressed while aiming drops the aim and casts.
   - Right mouse no longer casts.
   - Blink stays on Q, unchanged.
   - **A spell key with a blade, a bow or empty hands** draws the revolver and raises the spell's hand (or the tome); the cast begins once the gun is up, while the key is still held *(Claude's call: hand and tome spells stay with the revolver, as the first build has them, and one press still both picks and casts)*.
   - **Cancelling an aimed Blink:** a fresh right-mouse press while Q is held cancels it, and does not start raising the sights. Right mouse already held from before keeps the sights up and does not cancel *(Claude's call)*.

### Weight (approved as proposed)

3. **The kick moves your aim.**
   - Each shot throws the view (the real aim: the neck and body, not only the camera shake) up and a little to the side.
   - It recovers part of the way by itself over the settle; you pull back the rest.
4. **What you hit shows it.**
   - A ball knocks a guard back hard, and a headshot snaps his head.
   - Shots leave holes, and chips, splinters or sparks by what they hit (stone, wood, iron).
   - A hit marker on the crosshair and a hit sound you can feel; a kill reads as a kill.
5. **The gun reads as heavy.**
   - It lags behind your turns and sways as you move.
   - It is slower to draw and to put away.
   - The shot has a thick flash and smoke that hangs after it (see Effects).
6. **The reload is physical:** spent casings drop from the gate, one for each spent chamber, and tinkle on the floor.
7. **The shot's sound has a tail:** a close crack, then an echo off the surroundings, more of it indoors.
   - The layering is built now; the recordings wait on the user (`docs/superpowers/refs/revolver_sounds.md`), with stand-ins until then.

### Effects (approved as proposed)

| Piece | What it is |
|---|---|
| Cylinder shot | A short, fat, star-shaped muzzle flash in hot amber, two frames. A thick smoke puff curling off the barrel and lingering. A faint tracer. Impacts: chips and dust on stone, splinters on wood, sparks on iron. Holes left behind. |
| Shell | A wider flash, a cone of sparks, smoke that hangs in a cloud. |
| Shard (Obsidian) | The circle is real black-glass splinters that catch the light, turning and drawing in. The shard flies as a spinning splinter with a glinting edge and shatters into black glass on what it hits. |
| Blink (Obsidian) | Where you stood, a mirror-crack: a shatter of reflections that fades. You arrive with a glass ripple. |
| Ward (Copal) | Thick, slow smoke in the ward colour, cyan-white `#CFE8F0` (the project's colour rule), rolling up into a ring round you. A shot it stops puffs the smoke outward where it struck. |
| Empower (Nahual, the tome) | The pages flutter as you cast. While the charge waits: a faint pelt-shadow over the hand, and a pulse at the edges of the view. Spent, the blow lands with a heavier crack. |
| Gore pieces | Real pieces in place of the red boxes, modelled one at a time with the user (the supervised-models rule). |

## Non-goals

- New weapons (the pistol and shotgun from the stance list), new spells, new enemies.
- The final hand poses (aiming, casting, tome). They are still posed with the user in live Blender (Art B); this pass uses stand-in poses.
- The final revolver and tome models (Art A).
- The gore models themselves. They are a supervised art track run alongside; this pass leaves `Gore.gd` ready to take them (see "Gore pieces").

## Anti-goals *(Claude's call, from the user's standing rules)*

- **Generic shooter feel:** a light, fast, clicky gun.
- **Soft sprite clouds and flat cards turning to face you:** the Underground's lesson, "they look like they emit smoke quads".
- **Glows for their own sake.** Every effect is made of its stuff: powder smoke, black glass, copal smoke, beast. Never free-floating runes or auras.
- **Taking control away** (Helsby's pillars): no slow-downs or locked views from a shot. The kick moves the aim, and the player is always free to pull it back.

## Constraints

- **Standing rules:**
  - no free or downloaded effects: everything is made in house;
  - every strange thing has a cause;
  - never call a visual defect harmless;
  - the user writes all words;
  - models are built one at a time under the user's supervision.
- **The colour rule:**
  - wards are cyan-white `#CFE8F0`;
  - marigold is the dead, so not for the gun or the beast;
  - oxblood `#6E1F1A` is the gods;
  - phosphor green `#7FD36A` is the seeped.
- **Helsby's first-person rules** (`fp-animation-principles`):
  - immediate feedback;
  - no pops between actions;
  - impact carried by translation more than rotation;
  - keep the combat corridor (the band round the reticle) clear;
  - the weapon low right.
- **The viewmodel:**
  - draws at `ViewArms.VIEW_FOV` 58 on `HandSlot.VIEWMODEL_LAYER`;
  - a muzzle effect seen by the player lives on that layer at the viewmodel muzzle;
  - the world sees the light (`Fx.flash`, lights the player's exposure).
- **The Underground's effects method** (`docs/superpowers/refs/underground/vfx_method.md` on `metro-standard`):
  - meshes, not sprites;
  - noise scrolled over the mesh;
  - hard alpha erosion;
  - colour in flat bands with a bright core;
  - fresnel rims;
  - restraint.
- **Gotcha learned in the lab:** put an effect shader on the mesh's own surface slot, not `material_override` (the lab's form light clears overrides).
- **Retro screen:** effects must read on the pixel grid at 360 lines (F6–F8).
- **Tests:**
  - the suites run headless and frame-exact under `--fixed-fps 60`, with no unseeded randomness in anything checked;
  - headless runs can't see pixels, so the visual judgement is made in windowed stills and clips for the user, close and far;
  - the effects method says judge them in the game, not on a sheet.

## Approaches considered

- **A. Mesh-and-shader effects built on this branch, borrowing the Metro lab's language** *(chosen by the user)*.
  - Copy the small pieces from `metro-standard`:
    - `scripts/Visual/MeshVfx.gd` (a lathed flame, tendrils, plumes, ribbons);
    - `scripts/Visual/vfx_mesh.gdshader`;
    - `vfx_fume.gdshader`, `vfx_halo.gdshader`, `vfx_wisp.gdshader` as needed.
  - Reuse the Zócalo effect shaders already here.
  - Quick to tune in the game.
  - Smoke is shaded meshes rather than simulated.
- **B. Merge `metro-standard` into this branch first.** One effects language from the start, but 479 changed files of unrelated Metro work, on a branch another session works on.
- **C. Simulated smoke** (Mantaflow sheets through `tools/vfx`) for the muzzle, shell and Ward smoke. The richest smoke, but slow to iterate. Kept in reserve for the Ward's smoke if mesh smoke does not hold up when it fills the screen.

## The parts, as decided

### Aiming *(numbers: Claude's call, tuned in the gym)*

- **Raising and lowering.** Right mouse held raises the gun to the eye over **0.18 s**: the sights on the reticle and the gun in the middle low, clear of the corridor's centre. Let go, it lowers over 0.15 s.
- **The view.** It narrows from 75 to **62°** over the raise. The arms' own field of view is unchanged.
- **Aimed:**
  - no spread;
  - the kick at half;
  - ready again after 0.35 s (the old braced numbers);
  - walking speed ×**0.7**;
  - no sprinting.
- **While raising** (part way up), a shot uses the hip's spread and kick.
- **Blocked actions.**
  - The reload drops the aim; aiming during a reload stops the reload, as firing does.
  - Climbing and hanging put the gun away, as now.
- **The left hand** is on the gun while aimed: the support hand (stand-in until posed).
- **Spell keys.** A spell key drops the aim and starts that spell.
- **Removed:** G, and `Caster.toggle_braced`. The Caster's loadout follows the last spell key: Shard or Ward keeps the bare hand ready, Empower keeps the tome out.

### The kick moves the aim *(numbers: Claude's call)*

- **Each shot pitches the aim up:**
  - from the hip: **3.5°**, plus a sideways nudge of up to **0.8°** following a fixed pattern;
  - aimed: half that;
  - the shell: ×1.4.
- **The aim itself moves:** the neck's pitch and the body's yaw, so the next shot goes where the view went.
- **The automatic recovery:** **60 %** of the climb comes back over the settle time, eased.
- **The camera's own shake stays,** with the impact carried more in translation (a push back along the view) than rotation (Helsby).
- **Hit-stops stay, short:** 0.04 s on a body hit as now, 0.07 s on a kill, so a kill lands heavier. They are a few frames, not a slow-down; the recovery and the shove run on game time and wait through them *(Claude's call)*.

### What you hit shows it *(Claude's call where marked)*

- **A ball into a guard:**
  - a shove back of about **2.5 m/s** (more for the shell's pellets together, less for one pellet);
  - a longer stagger;
  - a headshot snaps his head back hard (the rig's hit reaction on the head);
  - a killing ball throws the body along the shot (the existing death push, strengthened for balls).
- **The crosshair:** a hit marker, using the crosshair's existing contact shapes, and a hit tick sound (a stand-in).
  - New shapes for a body hit, a headshot and a kill.
  - A kill shows briefly bolder, with a second, lower tick.
- **Bullet holes:**
  - a new kind of `Fx.stain`, a dark pocked hole with a lighter rim of broken surface;
  - in the decal pool, fading after about 30 s *(Claude's call)*;
  - by surface: a stone pock, a wood split, an iron dent.
- **Impact effects by surface:**
  - stone: chips and dust (`Fx.chips`, `Fx.dust`);
  - wood: splinters;
  - iron (meta `surface == "metal"`/"iron"): sparks (`Fx.sparks`).

### The gun's weight *(numbers: Claude's call)*

- **Lag and sway.** The gun lags behind turns: a turn rate becomes a counter-rotation of up to 4°, springing back. It sways with steps through the existing body motion. Both are less while aimed.
- **Drawing and holstering.** Drawing the revolver takes **0.45 s** and putting it away 0.35 s; the generic switch time stays for other items. No shot until it is up.
- **Sprinting** lowers it (as now), and a shot can't be taken until it is back up (0.15 s).

### The reload's casings

- **Spent casings drop:**
  - when the gate opens, one brass casing for each spent chamber falls from the gate, one at a time, 0.08 s apart;
  - small rigid bodies on a world layer, colliding with the world only;
  - a tinkle on landing (stand-in);
  - they lie 10 s and shrink away (as the Gore pieces do), at most 24 at once.
- **They are seen in the viewmodel** as they leave the gate, then in the world:
  - spawned at the viewmodel gate's world-equivalent position;
  - the first frames drawn on the viewmodel layer, then on world layers *(the builder decides how; see "Left to the builder")*.

### The sound's tail

- **The crack:** the close crack plays at once.
- **The tail:**
  - plays **0.06 s** later, quieter;
  - longer and louder in a room than in the open, using `Sfx`'s room probe and acoustics;
  - in the open, a far, thin echo.
- **Wanted recordings:** the tail joins the sound list as `gunshot_tail` and `shellshot_tail`, with stand-ins from the existing packs.

### Effects, piece by piece *(look: Claude's call, approved)*

**Base:** copy `MeshVfx.gd` and `vfx_mesh.gdshader` from `metro-standard`, with their `class_name` and imports.

**The muzzle flash.**
- *Shape:* a star of four to six flat petals and a short lathed cone (`MeshVfx.flame` laid along the barrel), in stepped bands: a cream core, amber, burnt orange at the edge.
- *Timing:* two frames, then gone.
- *Variation:* turned to one of a fixed set of rolls each shot, so no two shots look the same in a row.
- *The shell's flash:* half again as wide, with a cone of sparks along the aim (`Fx.sparks`).
- *Where:* on the viewmodel layer at the viewmodel muzzle. The world gets the light only.

**The muzzle smoke.**
- *Shape:* two or three curling tendrils (`MeshVfx.tendril`/`plume`), grey-brown powder smoke, lit in bands.
- *Movement:* they rise and drift from where the muzzle was, eroding away over about 1.2 s.
- *Where:* a world effect at the muzzle's world-equivalent spot, so you walk out of it.
- *The shell's smoke:* a larger, slower cloud of four or five plumes that hangs about 2 s.

**The tracer.** A thin ribbon (`MeshVfx.ribbon`) from the muzzle to the hit, pale hot-white fading to amber, drawn for 0.06 s. Faint.

**The Obsidian circle.**
- *Pieces:* ten to twelve thin black-glass splinters (flat, pointed prisms).
- *Material:* metallic and glossy, so they catch the light and the lamps; a sharp glint runs along them.
- *Motion:* they turn round the palm and draw in as the cast closes.
- *Where:* viewmodel layer.

**The shard in flight.**
- A long black-glass splinter, spinning on its long axis, with a glint running its edge (fresnel).
- On a hit it shatters into black glass: a burst of small splinter pieces (particles or a few tiny rigid bodies) and a crack.

**Blink.**
- *Departure:* where you stood, a mirror-crack: eight to twelve flat reflective shards (metallic, glossy, reflecting the scene) burst out in a ring at body height, hang, and fade over 0.6 s.
- *Travel:* a brief cold flash at the edges of the view, 0.1 s.
- *Arrival:* a glass ripple, an expanding sphere shell whose shader bends what is behind it (`hint_screen_texture`), 0.3 s.

**The Ward.**
- *Shape:* thick, slow copal smoke as tendrils and plumes rolling up into a ring round you, in `#CFE8F0` with a soft fresnel rim.
- *Movement:* it rises in a quarter second and sinks away in the last half second (as now), going with you.
- *A stopped shot:* the smoke bulges outward at that point. A puff of plumes and a ring distortion there, and the struck tendrils thin for a moment.

**Empower.**
- *Casting:* the tome's pages flutter, a few page meshes flipping over in the open book.
- *While charged:*
  - a pelt-shadow over the left hand and forearm: an overlay on the arms' material, a dark brown-umber fur-like noise drifting along the arm, faint;
  - a slow pulse at the edges of the view (a vignette, as the adrenaline view does), in umber, not marigold.
- *Spent:* a heavier crack (sound), a short shockwave ring at the impact or the feet (for a jump), and the pelt-shadow snaps away.

**Gore pieces.**
- `Gore.burst` takes its piece meshes from a list that can be replaced by the user's modelled pieces without code changes.
- Until then, the stand-ins get one pass: rounded, lumpy meshes with a wet sheen instead of boxes.
- The real pieces come from the supervised art track.

## Tests and the user's judgement

- **The suites change with the controls.** `revolver_test` and `caster_test` move from right mouse and G to aiming on right mouse and spell keys:
  - G and `toggle_braced` go;
  - casting presses `spell_1..3`;
  - the braced checks become aimed checks.
- **New checks:**
  - aiming: raise time, the narrowed view, no spread, half kick, ready time, walk speed;
  - a spell key drops the aim;
  - the kick moves the aim and recovers 60 %;
  - a ball shoves a guard;
  - hit markers for body, head and kill;
  - a bullet hole is left;
  - casings drop one per spent chamber and are gone in time;
  - the tail plays after the crack;
  - each effect spawns, lives its time and is cleaned up, with no leaks.
- **Headless checks can't judge looks.** The stills stage (`tests/visual/stage_revolver.tscn`) gains frames for each effect at the key moments, and short clips (frame sequences) of the shot, the shell, the shard, blink, the ward and empower, close and far, lit and dark, for the user.
- **The gym range bay** is where the user tunes the feel.

## The user's checkpoint

The user: **"Stop after the muzzle flash, smoke and impacts so I can set the look, then build the rest."**

- **First part:**
  - the controls and the weight (aiming, spell keys, the kick moving the aim, hits that show, the gun's lag and draw, casings, the sound's tail);
  - the shot's effects: the muzzle flash, the muzzle smoke, the tracer, the impacts and holes, the shell's flash, sparks and cloud.
- **Then stop.** Stills and clips go to the user, who sets the look. The same stop decides whether mesh smoke will do for the Ward, or approach C (simulated smoke) is used for it.
- **Second part,** in the look the user sets: the Obsidian circle and shard, Blink, the Ward, Empower, the gore stand-in pass.

## Which arms

This pass is for the Prosecutor's own arms (`FP_ARMS=new` / F12), which draw at `ViewArms.VIEW_FOV` 58. Their poses, the aim pose, the support hand, the muzzle at the viewmodel muzzle and the pelt-shadow are built and checked on them. The old arms keep working, but are not polished; with them the aimed view narrows the gun too *(Claude's call: the new arms are the game's arms going forward)*.

## Left to the builder

- How the casings move from the viewmodel to the world.
- How the hit marker shapes are drawn.
- The exact meshes' resolutions.
- How the ripple shader samples the screen.
- The page-flutter mesh.
- The order of the work.

## Branch

On `revolver-magic` (worktree `.claude/worktrees/revolver-magic`), after its first build. That build's final review is still owed and runs over the whole branch at the end of this pass *(Claude's call)*.
