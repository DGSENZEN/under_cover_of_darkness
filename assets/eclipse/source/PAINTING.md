# Painting a kit piece's weathering

Each piece's .blend here holds four greyscale colour layers, one story each.
Open it, pick a mesh, Vertex Paint mode, and choose the layer in the mesh's
Color Attributes:

- `yours_grime`  black clean, white grimy (rising damp, soot, dirt in corners)
- `yours_blend`  black whole, white worn through to what is under it
                 (plaster to tezontle, paint to bare metal)
- `yours_tint`   mid grey neutral; darker damp and rain streaks, lighter sun-bleached
- `yours_light`  white open, black occluded (baked light)

Leave the `start_*` and `rules` layers alone: they are how the build tells
your strokes from its own. Save, then run `tools/eclipse/lab.sh <piece>`.
Your strokes are kept in tools/eclipse/yours/<piece>.npz and win over the
rules on every build; any stroke whose corner no longer exists is listed in
the build's output.
