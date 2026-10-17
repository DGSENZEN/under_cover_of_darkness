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
