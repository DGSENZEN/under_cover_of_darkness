# The Underground's effects: the Deadlock way (Oct 17 2026)

The user's note on the first ánimas and the nahual's smoke: "they look like they emit smoke
quads, when their effects should be more sophisticated, if we can sort of replicate the same way
deadlock do their effects". Valve has published no breakdown of Deadlock's effects. The method
below is what the game shows on screen, together with the stylized real-time effects technique
it plainly uses.

## The method
1. **Meshes, not sprites.** An effect is real geometry with its own shape and UVs: a flame is
   a 3D teardrop, smoke is a set of tendrils, a trail is a ribbon mesh drawn along the path. It
   reads as a volume from every side, and never as a flat card that turns to face you.
2. **Noise scrolled over the mesh.** A tiling noise slides along the mesh's UVs (up a flame,
   along a trail). The noise drives the alpha and a little displacement of the vertices.
3. **Hard alpha erosion.** The noise is thresholded with a narrow edge, so the shape eats away
   in crisp tongues rather than fading soft. An effect dies by raising its erosion threshold.
4. **Colour in bands.** A bright core, a mid colour, and a dark or cool edge, each a flat band
   (Deadlock's graphic read, and Mignola's).
5. **Fresnel rims.** A brighter rim where the surface turns away gives the volume its edge.
   Nested shells (a bright core inside a softer eroding shell) give it depth.
6. **Restraint.** Few pieces, each designed. No clouds of soft dots.

## Sources
- [Simon Trümpler, stylized VFX in RiME (alpha erosion, matched fade masks)](https://simonschreibt.de/gat/stylized-vfx-in-rime/)
- [VFX Apprentice, the building blocks: textures, meshes, shaders (noise, erosion maps)](https://www.vfxapprentice.com/blog/textures-meshes-shaders-vfx-basics)
- [Real-Time VFX: Simon Trümpler's sketchbook (scrolling noise over meshes, fresnel inner glow)](https://realtimevfx.com/t/simon-trumpler-vfx-sketchbook/4177?page=11)
- [Real-Time VFX: Marina VFX, 50 weeks of stylized VFX](https://realtimevfx.com/t/marina-vfx-50-weeks-of-stylized-vfx-between-art-emotion-code/29826/3)
- [Ivan Garcia, fire shader (scrolling voronoi, polar UVs, erosion mask)](https://ivangarciafilho.artstation.com/projects/Qn93lx)

## Where it is used
- **scripts/Visual/vfx_mesh.gdshader:** the shared mesh effect (scroll, erode, bands, rim).
- **scripts/Visual/MeshVfx.gd:** builders for the shapes (a lathed flame, a ribbon trail,
  rising tendrils).
- **The ánimas** (Animas.gd), **the nahual's smoke** (Nahual.gd), **the procession** and
  **the ownerless shadow**.

## Graves (Deadlock, "Old Gods, New Blood"): the spirit look to copy (Oct 17 2026)
The user: "Look at how deadlock does it and try to copy that ... same with Graves spirits". Graves the
necromancer ([deadlock.wiki/Graves](https://deadlock.wiki/Graves)); her abilities as shown in-game
([Deadlock Abilities Showcase: Graves](https://www.youtube.com/watch?v=S2IdFYIK0es), Jar of Dead 0:51,
Grasping Hands 1:15, full cast 2:29):
- **Deadheads** (Jar of Dead): solid black skull silhouettes, each wrapped in a glowing acid-green
  (chartreuse) aura, green streaks trailing them as they dart. Black shape, luminous rim: Mignola's black lit
  from behind by spirit-fire.
- **Grasping Hands**: a line of chartreuse spirit-fire tongues erupting from a crack in the floor, pale
  spectral hands reaching up out of it.
- **Her spirits**: a bright core whipping a long ribbon trail.

The ánimas take this directly: each a black hand silhouette (real hands from the CC0 base body) with a
glowing chartreuse rim (fresnel, past white for the bloom), rising out of a tongue of chartreuse spirit-fire
at its wrist, a ribbon trail behind it.

## What Deadlock's own effect files show (Oct 17 2026)
Read from the game's decompiled particle definitions (text only: the community's deadlock-open-assets
repo, SteamDB's file list, the Source 2 particle field reference). No texture or mesh of theirs was taken.
- **Fire is shape × noise through a stepped ramp.** A soft mask multiplied by a tiling noise climbing it,
  a slow warp noise bending both, and the result looked up in a colour ramp with near-vertical steps:
  wine red, orange, amber, a cream core (never white, never black). Pushed bright so the bloom takes the core.
- **Their candle** is a ribbon of particles that hang on the wick about 0.6 s and then drift free (so it
  trails and leans), its width a teardrop over its life; with it, embers, a light and a curling smoke ribbon.
- **Smoke** is alpha-blended and lit with a little light of its own, eaten by an erosion mask whose
  distortion grows with age; thin wisps are unlit grey ribbons pushed by curl noise.
- **Edges are cut, not faded**: the alpha threshold rises over a particle's life.

## How ours take it (Oct 17 2026)
- **Candles** (Vfx.gd `candles`, vfx_candle.gdshader): a real lathed teardrop per wick, banded inside out
  (cream seed, amber, orange, wine rim) with a blue root over the wick, each band its own brightness so only
  the core blooms; its tip licked away by warped climbing noise; it breathes with its light's flicker, swims
  on its own phase, leans on the draught, gutters for the dark train. With it a glow (vfx_halo.gdshader, two
  painted rings, faded where it meets the wall) and now and then a curling thread of smoke (vfx_wisp.gdshader).
- **Vent breath** (Fumes.gd, vfx_fume.gdshader): plume tubes (MeshVfx.plume) leaving the grille and climbing
  the wall, and lumpy puffs carried by particles that swell and eat themselves away; lit in three hard bands,
  pale and cool against the warm-lit tiles, a little light of their own, warm at the foot.
- Effect shaders go on the mesh's own material slot, not material_override: the lab's form light clears
  overrides and only passes over effect shaders in the slot.
