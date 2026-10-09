# Painterly texturing from photo scans: a brief

**Question:** how do we make CC0 photo scans read as hand-painted but still detailed, at about 50 px/m with nearest filtering?

**Conventions:** researched 2026-10-09; nothing downloaded. Links were checked by HTTP; adobe.com/learn and godotshaders.com block scripts and were read through a fetch tool. Polycount could not be read, so it is not cited. **[ours]** marks our inference or our reading of this repo's code; everything else is sourced [n].

---

## 1. Kuwahara filters in one table

Each output pixel takes the mean of the neighbouring sub-region with the least variance: flat areas become flat paint, edges stay sharp.

| Variant | Look | Key parameters | Cost |
|---|---|---|---|
| **Classic** (4 square quadrants) | Blocky. The quadrant choice is unstable on noise and when quadrants have equal variance [2][3] | radius | Cheapest; Blender's manual calls it faster but blocky [9] |
| **Generalized** (Papari et al. 2007) | Disc split into N soft sectors, with a weighted blend instead of picking one sector. Smoother, but forms round clusters, worse when iterated [1][2] | sigma (brush size), N sectors, q (sharpness) [1] | Medium |
| **Anisotropic, AKF** (Kyprianidis, Kang, Döllner 2009) | The disc is stretched into an ellipse that follows the local structure tensor, giving strokes that flow along features. Stays coherent over several iterations [2] | Paper defaults: N=8, q=8, alpha=1 (max eccentricity 4), kernel sigma_r=3, tensor smoothing sigma=2.0. 512² ran at 12 fps on a GTX 280 [2] | Three passes: tensor, blur, filter |
| **AKF + polynomial weights** (2010) | Same look. The weights are computed in closed form, with no lookup texture [3] | zeta, eta. Acerola exposes zeroCrossing≈0.58 and zeta=2/kernelSize [5] | Within about ±18% of the texture-lookup version, depending on GPU and N [3] |
| **Multi-scale AKF** (NPAR 2011) | Adds thresholding plus a pyramid. Allows stronger abstraction and avoids artifacts in large low-contrast regions [4] (for us: plaster walls) | Pyramid levels | Propagation adds no extra overhead [4]; the pyramid adds about a third more pixels **[ours]** |

**Reference implementations:**
- **Acerola:** video [6]. Unity repo with Kuwahara, Generalized and Anisotropic versions, MIT licence [5]. His AKF defaults are kernelSize 2–20, sharpness (q) 8, hardness 8, alpha 1, passes 1–4 [5].
- **Kyprianidis:** GLSL in `gpuakf`/`polyakf` [7], **GPL-3**: read, don't copy; port the maths from the papers.
- **Godot ports (MIT):** Anisotropic [8a] and Generalized [8b]. Both are `canvas_item` screen shaders. The anisotropic port does tensor, blur and filter in one fragment. **[ours]** That means it recomputes the tensor blur for every pixel, which costs far more than Acerola's multi-pass version.
- **Blender** Kuwahara compositor node, Classic and Anisotropic [9]: Size, Uniformity, Sharpness, Eccentricity. Chain it for flatter results; for speed, downscale, filter, upscale.
- **Substance Designer 14+** has Anisotropic Kuwahara nodes [10]. Adobe's recipe [11]: Quantize Color (base: 32 colours, Lab; normal: fewer, RGB), then Kuwahara on the normal, then on the base colour with its **direction map wired from the normal's**, so both flow alike.
- **pykuwahara** [12]: classic/Gaussian only, OpenCV, GPL-3. Skip.

### Bake into the atlas, or post-process?

**Bake. [ours]** The reasons:
- **Pixel grid:** a screen-space filter at the 640×360 virtual grid averages across the texel edges that make the retro look. A baked filter puts the strokes inside the texels.
- **Temporal stability:** the AKF paper reports good per-frame coherence on natural video [2]. **[ours]** Nearest-sampled, minified textures under a moving camera alias, though, so a screen-space filter would flip its sector choice frame to frame and shimmer. A bake adds no shimmer beyond the texture's own mip aliasing.
- **Strokes stick to the world:** baked strokes stay on the wall. Screen-space strokes swim with the view. TF2 used no image-space techniques such as outlining [13].
- **Cost:** a bake is free at runtime. A proper screen AKF needs a three-pass CompositorEffect [17].

**Optional later experiment [ours]:** a mild AKF (kernel 2–3, N=8, one pass) as a CompositorEffect on the virtual buffer before the grid upscale, masked by depth to the far field, behind an F-key A/B toggle. Ship it only if the user prefers it in motion.

---

## 2. What studios actually did

- **TF2 (Valve, 2007)** is the closest documented match to our pipeline:
  - Early textures were watercolours painted on canvas and scanned. Later, artists took photo reference and applied a series of filters plus digital brush strokes [13].
  - Valve found these painted textures held up under magnification better than photo textures, with no photo artifacts [13].
  - Style rules: shadows go cool, not black; saturation rises at the terminator; high-frequency detail is omitted where possible [13].
- **Dishonored 2 (Arkane)** was mostly hand-painted, not painted over photos:
  - Textures were hand-painted in Photoshop, with Substance Designer for masks. A tool generated a starting base for each texture, which artists painted over [14].
  - They targeted **medium-size** detail, because too much fine detail killed the stylized look [14].
  - Dirt is deliberately uneven, noisy in places and calm in others. The art director's main goal was removing noise [14].
  - Photos were still used to capture specific frequencies, with attention to volumes and masses [15].
- **Hades (Supergiant):** environments are hand-painted 2D. Characters are 3D renders [16]. There is no photo pipeline to copy.
- **Deadlock, Arcane, WoW, Guilty Gear:** no primary source on photo-to-painted texturing was found; treat claims about them as hearsay **[ours]**. Guilty Gear Xrd's GDC talk covers cel-shaded characters, not environment textures [18].
- **Generic filters:** oil-paint filters such as GIMP Oilify [19]; Winnemöller et al.'s edge-preserving smoothing plus soft luminance quantization [20] is the same idea as quantize-then-Kuwahara.

---

## 3. Why ours looks fake, and the fixes

**[ours]**, read from `tools/textures/eclipse_atlas.py` and `scripts/Visual/painterly.gdshaderinc`:

| Symptom | Cause in our code | Fix |
|---|---|---|
| Flat, "plastic" base | The scan is tinted 0.8 toward one flat slot colour, which keeps luma but kills the scan's hue variation | Map scan luma onto a **hue-shifting ramp** (cool darks, saturation peaking at the terminator [13]); keep 20–30% of the scan's own chroma |
| Uniform noise | Light and dark dabs scattered at a fixed count per area; one global `_noise` stain | Place strokes by **structure**: along value-band edges and oriented by the AKF tensor. Make 1–2 "story" zones per piece busy and leave the rest calm [14] |
| Edges worn wrongly | Wear comes from the UV-island rim (`_rim(mask)`), which is not geometric curvature | Bake **convexity** in Blender (Bevel-node normal vs true normal; Pointiness is per-vertex, Cycles-only [21][22]). Wear only on convex edges, broken by the scan's light areas; Substance's edge wear is curvature-driven too [23] |
| Damp and grime as a clean band | Height threshold times one noise | Dirt = AO × cavity × scan-luma breakup (Substance's Dirt generator also combines AO, curvature and grunge [24]); then **gravity**: smear dirt downward in world Z under sills and ledges; a ragged damp line |
| Detail at one scale | Only micro detail (scan) plus dabs | Build **macro, meso, micro** separately (below). Medium detail carries the style [14] |
| Palette flattening | Shader mixes 50% toward the nearest of 16 colours by RGB distance | Pick the nearest colour in **Oklab** [25]. Lower `paint_mix` to about 0.2–0.3, or map only lightness and hue |
| Repetition | Tiling scans | World-aligned projection already helps. Add per-region offset or rotation [26] |

---

## 4. Recommended pipeline

All numbers are starting values **[ours]**: tune them on the lab's contact sheets. The canvas is the existing 4× supersample (about 200 px/m). The final atlas is about 50 px/m (1 texel ≈ 2 cm).

**A. Scan prep, once per scan, cached in `textures/scans/painted/`:**
1. Resample the scan to **200 px/m**. Matching world scale matters more than any kernel number.
2. Remove the baked light: divide by a Gaussian blur with sigma ≈ 0.5 m (100 px), then rescale to the mean. This is frequency separation: keep the ratio detail and discard the lighting gradient.
3. **AKF in numpy**, with polynomial weights [3], wrap-padded so the tile stays seamless:
   - Tensor from RGB (derivative sigma 1 px), smoothed with sigma **2**; **N=8, q=8, alpha=1**; iterate **twice** [2].
   - **sigma_r ≈ 6–8 px** (1.5–2 final texels, 3–4 cm strokes) **[ours]**.
   - **[ours]** Loop over the kernel's (dx, dy) offsets, vectorized over the image: about 300 offsets × 8 sectors over 1–4 Mpx, seconds to a minute in numpy, no scipy or OpenCV. Fallback: Blender's Anisotropic node, run headless [9].
4. Filter the scan's **normal map with the same tensor and weights**, then renormalize. This mirrors Adobe's shared direction map [11].
5. **Multi-scale for plaster** (large low-contrast areas): the NPAR 2011 pyramid scheme [4]; a simplified ½/¼ pyramid with upsample-blend is our shortcut **[ours]**.

**B. Per-piece atlas (`eclipse_atlas.py`):**
6. **Macro values first:** per slot, quantize the filtered scan's Oklab L into **4–5 value bands** with soft edges (about ¼ band). This sets "large shapes, simplified values".
7. **Colour:** map the bands onto the slot ramp, with shadow hue rotated about 15–25° toward blue/violet and lights warmer and less saturated [13]. Add back **30–40%** of the filtered scan's high-pass (detail = scan − blur with sigma 4 px). This is the "detail-oriented" layer.
8. **Meso:** wear from the convexity bake, dirt from AO × cavity, gravity streaks, and blocks and joints as now. Concentrate them in story zones.
9. **Strokes:** dabs 3–8 final texels long, seeded on band edges and aligned to the tensor, taking colour from the band above or below. Then one light **AKF pass (sigma_r 4 px, one iteration)** over the composite, to fuse the paint layers as Adobe's quantize-then-Kuwahara does [11].
10. Shrink 4→1 with BOX. Quantize **per slot in Oklab** (8–12 colours per slot, not 64 for the whole atlas). No dither.

**C. Readability gates (tests, at 50 px/m nearest):** smallest meaningful mark ≥ **2 texels**; value bands ≥ **6 texels** across; single-texel speckles under about 2% per slot (count size-1 connected components); contact sheet at 1×, 3× nearest and mip 1 (the shader samples `filter_nearest_mipmap`, so mip 1 is the mid-distance).

**D. Shader:** keep the world-space brush (`stroke_strength` about 0.1). Match palette colours in Oklab and lower `paint_mix`. Do not add a screen Kuwahara yet (see §1).

---

## Links

1. Papari, Petkov, Campisi, *Artistic Edge and Corner Enhancing Smoothing*, IEEE TIP 16(10), 2007. Parameters and applet: https://www.cs.rug.nl/~imaging/artisticsmoothing/java/ArtisticApplet.html
2. Kyprianidis, Kang, Döllner, *Image and Video Abstraction by Anisotropic Kuwahara Filtering*, CGF 2009. Page: https://www.kyprianidis.com/p/pg2009/ · PDF: https://www.kyprianidis.com/p/pg2009/jkyprian-pg2009.pdf · EG: https://diglib.eg.org/handle/10.2312/CGF.v28i7pp1955-1963
3. Kyprianidis et al., *AKF with Polynomial Weighting Functions*, TPCG 2010. https://www.kyprianidis.com/p/tpcg2010/ · PDF: https://www.kyprianidis.com/p/tpcg2010/jkyprian-tpcg2010.pdf
4. Kyprianidis, *Multi-scale AKF*, NPAR 2011. https://www.kyprianidis.com/p/npar2011/ · PDF: https://www.kyprianidis.com/p/npar2011/jkyprian-npar2011.pdf
5. Acerola (Garrett Gunnell), Unity Kuwahara shaders, MIT. https://github.com/GarrettGunnell/Post-Processing/tree/main/Assets/Kuwahara%20Filter
6. Acerola, "This is the Kuwahara Filter" (YouTube). https://www.youtube.com/watch?v=LDhN-JK3U9g
7. Kyprianidis GLSL, GPL-3: https://github.com/jkyprian/gpuakf · https://github.com/jkyprian/polyakf
8. Godot ports, MIT: (a) https://godotshaders.com/shader/anisotropic-kuwahara-filter/ · (b) https://godotshaders.com/shader/generalized-kuwahara/
9. Blender manual, Kuwahara node: https://docs.blender.org/manual/en/latest/compositing/types/creative/kuwahara.html
10. Substance 3D Designer 14.0 release notes: https://experienceleague.adobe.com/en/docs/substance-3d-designer/using/release-notes/version-14-0
11. Adobe, Quantize Color and Kuwahara nodes tutorial: https://www.adobe.com/learn/substance-3d-designer/web/quantize-color-kuwahara-nodes
12. pykuwahara: https://pypi.org/project/pykuwahara/
13. Mitchell, Francke, Eng, *Illustrative Rendering in Team Fortress 2*, NPAR 2007. https://www.cs.princeton.edu/courses/archive/fall07/cos597B/papers/mitchell-team-fortress.pdf · Slides: https://cdn.fastly.steamstatic.com/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2_Slides.pdf
14. Yannick Gombart (Arkane), *Asset & Material Production in Dishonored 2*, 80.lv: https://80.lv/articles/asset-material-production-in-dishonored-2 · also https://80.lv/articles/the-wall-materials-of-dishonored-2
15. Geoffrey Rosin (Arkane), *Environment Storytelling in Dishonored 2*, 80.lv: https://80.lv/articles/environment-storytelling-in-dishonored-2/
16. Supergiant developer on Hades' art (Steam): https://steamcommunity.com/app/1145360/discussions/0/1738883810796606862
17. Godot Compositor docs: https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html · Custom post-processing: https://docs.godotengine.org/en/stable/tutorials/shaders/custom_postprocessing.html
18. Motomura, *GuiltyGearXrd's Art Style*, GDC 2015: https://www.gdcvault.com/play/1022031/GuiltyGearXrd-s-Art-Style-The
19. GIMP Oilify: https://docs.gimp.org/2.10/en/gimp-filter-oilify.html
20. Winnemöller, Olsen, Gooch, *Real-Time Video Abstraction*, SIGGRAPH 2006: https://research.adobe.com/publication/real-time-video-abstraction
21. Blender Geometry node (Pointiness): https://docs.blender.org/manual/en/latest/render/shader_nodes/input/geometry.html
22. Blender Bevel node: https://docs.blender.org/manual/en/latest/render/shader_nodes/input/bevel.html
23. Substance Painter, Metal Edge Wear (curvature types): https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/effects/generators/metal-edge-wear · Mask Editor: https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/effects/generators/mask-editor
24. Substance Painter, Dirt generator: https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/effects/generators/dirt
25. Björn Ottosson, Oklab: https://bottosson.github.io/posts/oklab/
26. Inigo Quilez, texture repetition: https://iquilezles.org/articles/texturerepetition/
