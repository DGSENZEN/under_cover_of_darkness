# Underground recipes (tools/textures/layered_atlas.py)

One JSON file per slot, named after the slot. Keys, in the order the layers are laid:

- `colour`: hex, the flat colour field designed for the material.
- `light`: 0-1, the top light. Up-facing texels are lighter and down-facing ones darker.
- `height_light`: 0-1, lighter toward the top of the piece.
- `wear`: 0-1, the bright worn edges on the bake's convex edges.
- `wear_colour`: hex, what a worn edge shows.
- `grime`: 0-1, the dark grime in crevices, where cavity × occlusion is high.
- `grime_colour`: hex, the colour of that grime.
- `brush`: the brush sheet's name (`brush_00` … `brush_04`, made by `tools/textures/brushes.py`).
- `brush_scale_m`: metres one brush sheet covers in the world.
- `brush_amount`: 0-1, how far the strokes move lightness (± this amount).
- `black`: 0-1, Mignola's solid black. Recesses whose cavity × occlusion is at least 1 − `black` become `#0b0a0c`. Use 0 for none.

Slots `glass` and `neon` are drawn by their own materials in game and need no recipe.
