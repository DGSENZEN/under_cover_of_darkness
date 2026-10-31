# The astral passages: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The north stretch before the Pasaje (`pasaje_n`) becomes an astral passage in the painterly occult register:
a void with real depth behind its walls, a way of floating lit stones, drifting city fragments, presences, and a
threshold at each end. The south passage follows once the user has seen the north's stills.

**Architecture:**
- `AstralPassage` (rewritten) owns everything:
  - It hides its space's greybox mesh, keeping the collider.
  - It draws *windows* over the hidden walls, ceiling and a floor below the way. These write stencil 1 and depth.
  - The void draws only where stencil = 1, ignoring depth: a painted sky sphere, ink-drawn fragments and presences.
  - It keeps the walker on the way and fires a threshold at each crossing.
- A new Blender kit, `astral`, holds the way's stones and the fragments.

**Tech stack:** Godot 4.5.1 (spatial-shader `stencil_mode`, verified on this machine); Blender kits through
`tools/eclipse/lab.sh`; GDScript tests in `tests/metro_test.gd`, windowed views in `tests/pasaje_stills.gd`.

**Spec:** `docs/superpowers/specs/2026-10-26-astral-passages-design.md`

## Global Constraints

- **Assets:** no free VFX assets; everything drawn, modelled or shaded by us. No modelled human figures (the shades are
  the approved cut-outs).
- **Sound:** no new recorded sounds. The muffle is a low-pass on the existing `World` and `Ambience` buses.
- **Lights:** none in the passage; its shaders are unshaded.
- **The way:** at least 1.4 m wide (the player is a metre across); walkable from mouth to mouth and to the
  `cistern_lane` opening.
- **Cost:** no more than 1.25 times the candle lane's frame.
- **Review:** stills of the north passage before the south is built.

## Review Focus

1. The first-person hands and the viewmodel drawn *over* the void, never the void over them. Pinned in Task 2's
   stills, from the stairs with the hands up.
2. Looking into the passage from the Pasaje through its mouth: the void shows only within the passage, never over the
   market. Pinned by M18c's rays from the market.
3. Walking straight at the void off the way, the walker is held at the way's edge without jitter or falling.
   Pinned by M18b.
4. Crossing a threshold and stepping back at once: the warp fires once per crossing, and the muffle eases back. M18d.
5. The cistern lane's opening stays open and walkable from the way. M18b's branch.

---

### Task 1: The void (windows, sky, hidden greybox)

**Files:** rewrite `scripts/Visual/AstralPassage.gd`; create `scripts/Visual/astral_window.gdshader`,
`scripts/Visual/astral_sky.gdshader`, `scripts/Visual/astral_ink.gdshader`; delete `astral_skin.gdshader`;
modify `maps/metro.gd` (`_astral()` for the north only); `tests/metro_test.gd` (M18 rewritten as M18a–e).

**Interfaces (produced):**
- `AstralPassage.make(box: AABB, end: int, gaps: Array, who: Node3D, way: Array) -> Node3D`. `way` is an Array of
  PackedVector3Array polylines in the map's frame (the main way first, branches after).
- Members: `windows: Array[MeshInstance3D]`, `sky: MeshInstance3D`, `stones: Array[MeshInstance3D]`,
  `fragments: Array[Node3D]`, `presences: Array[Node3D]`, `thresholds: Array[MeshInstance3D]`,
  `veils: Array[MeshInstance3D]`, `motes: GPUParticles3D`, `crossings: int`, `inside: bool`.
- Shaders:
  - `astral_window`: unshaded, `stencil_mode write, compare_always, 1`, near-black.
  - `astral_sky` and `astral_ink`: `depth_test_disabled`, `stencil_mode read, compare_equal, 1`.

- [ ] Write M18a "the stretch's box gone, the void behind windows": the `pasaje_n` greybox mesh is hidden and its
  collider kept; the windows cover its walls, ceiling and floor except the gaps (to the stairs, the market, the
  cistern lane); the sky exists; no Light3D. Run; FAIL (no windows).
- [ ] Implement:
  - Windows from the space's box and gaps. The floor window sits 0.6 m under the floor, so the way's stones occlude
    it.
  - The sky: an inverted sphere of radius 45 round the passage's middle, `render_priority -10`.
    Painterly: ink, violet and teal, aurora ribbons, marigold threads, sparse stars.
  - Hide the greybox mesh.
  - Remove the first pass's skins and rings; keep the veils and motes.
- [ ] Run the Metro suite; M18a PASS, M1–M17 PASS.

### Task 2: The way and the walker held on it

**Files:** create `tools/eclipse/astral.py` (kit `astral`: `way_stone_a/b/c`); `tools/eclipse/lab.sh` KITS;
`tools/eclipse/test_kit_bpy.py` (class `Astral`); `AstralPassage.gd`; `maps/metro.gd` (`NORTH_WAY`).

- [ ] Write M18b "the way walkable mouth to mouth and to the cistern lane, and nowhere off it":
  - walk from the stairs gap to the market's mouth and along the branch to the cistern gap (as `tests/pasaje_test.gd`'s
    `_walk_path`);
  - walking at right angles off the way for 2 s, the walker ends within `HALF_WAY + 0.1` of it.
  - FAIL.
- [ ] Model the stones: irregular slabs about 1.7 × 1.3 m and 0.4 m thick, a crumbled underside, their top flat.
  Through the kit's gate.
- [ ] Place the stones along the way about every 1.1 m, turned a little, their tops flush with the floor. They draw
  with `astral_stone`: the atlas dimmed, a teal rim, glyph-cracks glowing.
- [ ] Hold the walker: in `_physics_process`, inside the box and more than 1.2 m from either end, when they are
  further than `HALF_WAY = 0.75` from the nearest point of any way polyline, set them back to that distance and drop
  their outward velocity.
- [ ] `NORTH_WAY`, in the map's frame, at floor -11:
  - the main way through (-10, 34.3), (-10, 36.5), (-8.2, 39.5), (-9.5, 43), (-11, 46.5), (-9, 50), (-8.6, 53),
    (-9, 55);
  - the branch (-9.5, 43), (-11.5, 43), (-13.9, 43).
- [ ] Suites PASS; stills from the stairs (hands up) and halfway.

### Task 3: The city's fragments

**Files:** `tools/eclipse/astral.py`: `arch`, `stairs`, `doorway`, `lamp_post`, `bell`, `tile_slab`, `stall_frame`
(each under the kit's budget); `AstralPassage.gd`.

- [ ] Write M18c "fragments float in the void, never inside the passage, and show only through its windows":
  - at least 12 fragments, each its kit piece, centred more than 3 m outside the passage's box;
  - each drawn with `astral_ink`;
  - from the market, rays through the passage's mouth hit nothing of the void.
  - FAIL.
- [ ] Model the seven fragments, through the gate.
- [ ] Place 14 fragments, seeded:
  - at depths 4–30 m beyond the walls, the ceiling and below the floor;
  - each turning slowly (0.5–3°/s) and bobbing.
  - `astral_ink`: ink with a teal and marigold Fresnel rim and glyphs flickering.

### Task 4: The presences

**Files:** `AstralPassage.gd`; create `scripts/Visual/astral_eye.gdshader`, `scripts/Visual/astral_cutout.gdshader`.

- [ ] Write M18e "the presences far off": a serpent, three eye clusters, a line of shades walking parallel to the way,
  the giant hand, each more than 8 m from the way and drawn only through the windows. FAIL.
- [ ] Implement:
  - **the serpent:** an ink tube of 30 m with crests, sliding along a slow loop 18–35 m away;
  - **the eyes:** almond quads facing the eye, a marigold iris, blinking on their own clocks;
  - **the shades:** Silhouette walk loops on a path parallel to the way, 10 m out, their quad material's shader
    swapped to `astral_cutout` (same uniforms as `shade_cutout`, stencil read), their smoke hidden;
  - **the hand:** the soot hand's cell from `pasaje_marks.png` on a 6 m quad drifting past, with `astral_cutout`.

### Task 5: The thresholds

**Files:** `AstralPassage.gd`; create `scripts/Visual/astral_membrane.gdshader`, `scripts/Visual/astral_warp.gdshader`.

- [ ] Write M18d "a threshold at each end fires once per crossing, the world's sound muffled inside":
  - walking in through the stairs gap: `crossings` up by 1, `inside`, and a low-pass on `World`/`Ambience` easing to
    900 Hz;
  - stepping back out: `crossings` up by 1 more, the cutoff back toward 20 kHz;
  - a membrane in each end gap.
  - FAIL.
- [ ] Implement:
  - **the membrane:** a quad filling each gap; `hint_screen_texture` displaced by rippling noise; the wards' circle
    cell as its glyph ring.
  - **the warp:** a CanvasLayer full-screen `astral_warp` pulse of 0.6 s on each crossing.
  - **the muffle:** an `AudioEffectLowPassFilter` added to each bus once, its cutoff tweened. No bus, no muffle.

### Task 6: Cost, stills, review

- [ ] The render check's `--pasaje` against the lane, plus three eyes in the passage: ≤ 1.25×. Over it: fewer fragment
  tris and coarser sky noise.
- [ ] Stills in the real Metro: from the stairs, halfway, looking out, at each threshold, from the market looking in;
  send them; wait for the user's word before the south passage.
- [ ] Commit per task; ledger rulings in `.superpowers/sdd/2026-10-26-astral-passages/progress.md`.
