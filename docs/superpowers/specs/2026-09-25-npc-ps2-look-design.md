# NPC PS2 Look: Design

**Date:** 2026-09-25
**Status:** design approved section by section in conversation; this document awaits the user's review.

## 1. Goal

Make the NPCs look like gritty, low-poly PS2-era medieval soldiers instead of superheroes in painted costumes. The target is Thief: Deadly Shadows and Dark Messiah of Might and Magic, but built strictly to PS2 budgets and techniques. Looks only: no rule, AI or animation changes.

Today every NPC is the same 12.5k-triangle Quaternius "superhero" body. The outfit is painted onto its skin texture (`tools/dress_characters.py`). As a result:
- every kind shares one V-shaped silhouette, and the clothes read as spandex;
- nothing hangs off anyone: no skirts, cloth, belts, pouches or scabbards;
- the boots render as pale beige blocks, because their materials are plain colours with no texture;
- the faces are cartoony, and the separate eyeball meshes glow white in the dark.

## 2. Decisions

| Question | Decision |
|---|---|
| Target look | **Gritty PS2 medieval:** real clothing volume, grimy textures with the light painted in, faces toned down and mostly under helmets, coifs or hoods. |
| Who models | **Claude, in Blender 5.2 LTS** (MCP for previews, headless scripts for builds). Every `.blend` stays in the repo, editable by hand. |
| Variety | **Fixed silhouette, varied details.** Each kind keeps one silhouette you can read in a fight. Each guard rolls face, hair or beard, helmet variant, dye fade, grime and height. |
| Approach | **One low-poly character per NPC kind, built from the Quaternius body.** The user chose it over clothes layered on today's body and over a repaint with bolt-on pieces. |
| Emphasis | The user asked to focus on really making the low-poly PS2 style: budgets and techniques are rules, not suggestions (section 5). |
| Per-vertex lighting | **Rejected.** Tested in Godot 4.5.1 Forward+: meshes lit per vertex (the `SHADING_MODE_PER_VERTEX` material or the shader's `vertex_lighting`) ignore omni-light shadows. A guard hiding behind a wall stayed lit by the torch on the other side. The PS2 shading comes from the texture instead (section 5). |

## 3. Scope

**In scope:**
- the six NPC kinds: watchman (the default guard), swordsman, duelist, brute, archer, arms master;
- their heads, hair, beards and headgear;
- swinging cloth;
- per-guard variety;
- their corpses and severed parts, which reuse the same meshes;
- the Blender pipeline that builds all of it.

**Out of scope:**
- the player's first-person arms (`ViewArms`), which keep the painted Quaternius body and `Boots_Male.glb`;
- weapons, which keep their current meshes and are not counted in the triangle budget;
- animation (the separate HEMA project), AI and combat rules;
- the environment.

## 4. Success criteria

1. In the stager sheets and the NPC gym, the NPCs read as grimy medieval soldiers. Each kind is recognisable by silhouette at 8 m at night.
2. Every NPC is within budget: at most 3,000 triangles for all worn meshes (the brute 3,500). The body atlas is 256 px, the head 128 px, with at most 64 colours per albedo.
3. No skin shows through clothes in any pose in `stage_guards`.
4. Cloth swings and settles, stays out of the legs, and behaves on ragdolls and corpses.
5. Dismemberment, ragdolls, hit flash, wounds, arrows and armour sounds all work as before.
6. `tests/wardrobe_test` (K1–K12) passes, and every existing suite still passes.

## 5. The PS2 rules

| | Rule |
|---|---|
| Triangles | At most **3,000 per NPC**, counted over every worn mesh (outfit, head, hair, beard, headgear) but not the weapon. The brute's limit is 3,500. Targets: outfit (visible body plus clothes) ~2,000, head ~400, hair, beard and headgear ~600 together. For example, a kettle hat (266), a coif (~150) and a beard (~100) come to ~520. |
| Textures | Outfit: one **256×256** albedo plus a 256×256 mask. Head: **128×128** per face and skin tone. Hair and beards share one 128×128 strand texture, tinted per guard. Each albedo is palettized to **at most 64 colours** (tuned between 32 and 128 in batch 0). No normal, roughness or metallic maps. |
| Shading | The light is **baked into the albedo**: ambient occlusion plus a soft top-down sky light, the way PS2 artists painted shading in. At runtime the shading is per pixel and diffuse only: Lambert wrap, specular off, shadows cast and received. |
| Filtering | Nearest with mipmaps, as the Retro look does everywhere. |
| Hands | **Mittens with a thumb**, ~60 triangles each. Mitten vertices take their weights from the four fingers' averaged bones, so they close on a grip. |
| Faces | **Painted:** eyes, brows, stubble and scars are all in the 128 px texture. No eyeball or eyebrow meshes. |
| Hair | Solid shells, ~100–200 triangles, with painted strands. No transparent cards. |
| Cloth | Skirts, tabards, capes, sashes and hood tails are strips on 2–3 spring bones per chain. Strips are drawn from both sides. |
| Silhouette | Chunky and slightly exaggerated where it helps you read the man in a fight (section 8). |

## 6. Blender pipeline

### 6.1 Files

```
tools/wardrobe/
  recipes.py      data: every kind's garments, fabrics, colours, chains, metal zones, options
  common.py       shared: import the Quaternius body, bone lists, weight copy, lofts, UV packing
  build.py        recipe -> source .blend (generated objects only)
  bake.py         .blend -> albedo and mask PNGs, palettized
  export.py       .blend -> GLB + JSON, with validation (section 6.7)
  wardrobe.sh     headless runner: wardrobe.sh build|bake|export <kind|heads|hair|headgear|all>

assets/characters/wardrobe/
  source/         <kind>.blend, heads.blend, hair.blend, headgear.blend, .gdignore
    backup/       copies saved before every write; git-ignored
  <kind>.glb  <kind>.png  <kind>_mask.png  <kind>.json
  heads/<face>.glb  heads/<face>.json  heads/<face>_<tone>.png
  hair/<style>.glb  hair/<style>.json  hair/hair.png
  headgear/<piece>.glb  headgear/<piece>.png  headgear/<piece>.json
```

The GLBs hold only mesh and skeleton, with no materials or images. The game builds its own material from the PNGs (section 7.3), so no texture is stored twice. Every exported part has a JSON with at least its triangle count, which the kind's export uses for the combined budget check.

In Godot, the wardrobe GLBs import with `meshes/generate_lods=false` and `meshes/ensure_tangents=false`. The meshes are already PS2-low, and automatic LODs would eat distant guards' silhouettes.

### 6.2 Recipes (`recipes.py`)

One entry per kind, pure data. It holds:
- the body (male or female) and the triangle budget;
- the garments, each with its type (shell, loft or prop), the body regions or rings it follows, length, flare, thickness and padding, fabric, colour, and whether its colour is the dye;
- the cloth chains: parent bone, bone count, and stiffness, drag, gravity and radius;
- the leg and spine colliders;
- the metal zones: the bones covered by mail or plate;
- the options each guard rolls from: faces, skin tones, hair, beards, headgear, dye range and grime range.

### 6.3 Build (`build.py`)

For each kind, in a fresh `AUCOD_<kind>` scene:

1. **Import** the Quaternius body and skeleton for the recipe's body, with the same import settings as `boots.blend`.
2. **Low-poly base:**
   - separate the head at the neck ring;
   - decimate the rest to the recipe's body budget, keeping UV seams and weights;
   - replace the fingers with a mitten and thumb lofted along the finger bones.
3. **Garments**, from three kinds of part:
   - *shells*: body regions, selected by bone weight and height, copied and pushed out along the normals by the fabric's thickness (gambeson ~3 cm, mail ~1.5 cm, leather ~1 cm, hose ~0.6 cm), plus the recipe's padding;
   - *lofts*: ring-to-ring surfaces for skirts, sleeves, turned-down boot tops, hoods and capes, built the way the boots script lofts its rings;
   - *props*: tabard panels, belt, buckle, pouches, key ring, scabbard, quiver, bracers, pauldrons.
4. **Delete the hidden body.** A body face is deleted when a ray cast outward along its normal hits a garment within that garment's thickness plus 5 mm.
5. **Weights.** Shells, lofts and props copy weights from the original full-resolution body (Data Transfer, nearest face interpolated). Each cloth chain adds bones `cloth_<chain>_<n>` under its parent bone. Strip vertices are weighted along the chain, blended with the parent near the top. Every vertex is limited to 4 influences, and weights are normalized.
6. **Join and unwrap.** Everything becomes one mesh named `Outfit`, with two surfaces: closed parts, and strips drawn from both sides. It is unwrapped into one 256 atlas with more texels on the chest and tabard and fewer on soles and insides. Left and right halves share UV space where the texture is symmetric, as PS2 artists did to save texels.
7. **Materials.** Each fabric is a procedural node group: quilted linen, wool, leather, mail, plate, fur, and skin sampled from the Quaternius texture. A shared grime group adds dirt climbing from hems and boots, darkness in creases, and wear on edges.

### 6.4 Heads, hair and headgear

**Heads** (`heads.blend`)
- The high-poly source is the Quaternius male and female heads, with their eyes and brows.
- The low-poly heads are ~400 triangles, with eye sockets closed and ears simplified.
- Face variants are lattices applied to both the high and low heads, so the bake still lines up:
  - male: young, weathered, heavy (broad jaw, broken nose), old;
  - female: sharp, soft.
- Each face is baked from high to low into 128×128, once per skin tone (light and dark, from the two Quaternius skin textures). The eyes and brows become paint. A procedural grit layer then adds stubble, eye bags, lines and scars per face.
- Each head runs from the crown to the collar line. Every outfit has a collar or mantle that covers the seam, and the seam ring's vertices match the outfit's in position and weights.

**Hair** (`hair.blend`)
- Low-poly solid shells reduced from the Quaternius styles: buzzed, parted, tied back (from Long) and buns.
- Beards: full, short and moustache.
- One shared 128×128 greyscale strand texture, tinted per guard.

**Headgear** (`headgear.blend`)
- The existing kettle hat (266 triangles) and nasal helm (144) stay rigid pieces on `Head`, with re-baked textures.
- New skinned pieces:
  - a mail coif (Head, neck, spine_03);
  - a mail curtain for the nasal helm;
  - the archer's hood, reworked from `hood.glb`, with a swinging tail chain.
- Each piece lists the hair it allows. A coif or hood hides the hair but allows a beard. A kettle hat alone allows short hair.
- Each piece has a small JSON (`headgear/<piece>.json`) holding the hair it allows, its metal bones (the coif: neck_01 and Head; the curtain: neck_01 and spine_03), and any cloth chains (the hood's tail, under Head). Its cloth bones are in its GLB.

### 6.5 Bake (`bake.py`)

- **Albedo:** Cycles on the Metal GPU bakes each kind's procedural colour with ambient occlusion (0.3 m) and a soft top-down sky light into the 256×256 albedo.
- **Mask:** a 256×256 PNG. R is the dye region, G the visible skin, B the grime.
- **Skin tones:** the multiplier from the light to the dark tone, measured from the two Quaternius skin textures, is written to the JSON so the hands can match the rolled face.
- **Palette:** a k-means pass (numpy, inside Blender) reduces each albedo to the palette size. The mask is not palettized.

### 6.6 Export (`export.py`)

- **GLB:** the `Outfit` mesh and the skeleton (game bones plus cloth bones), deform bones only, no materials.
- **JSON sidecar**, for example:

```json
{
  "kind": "watchman",
  "body": "male",
  "triangles": 2290,
  "cloth": [
    {"chain": "skirt_front", "parent": "pelvis", "bones": ["cloth_skirt_front_1", "cloth_skirt_front_2"],
     "stiffness": 0.9, "drag": 0.35, "gravity": 0.8, "radius": 0.04}
  ],
  "colliders": [{"bone": "thigh_l", "radius": 0.08, "height": 0.42}],
  "metal": [],
  "skin_tones": {"light": [1.0, 1.0, 1.0], "dark": [0.55, 0.42, 0.35]},
  "probe": [{"vertex": 812, "rest": [0.11, 1.02, 0.09], "near_body": [0.1, 1.0, 0.07]}],
  "options": {"faces": ["young", "weathered", "heavy", "old"], "tones": ["light", "dark"],
              "hair": ["buzzed", "parted"], "beards": ["none", "short", "full", "moustache"],
              "headgear": [["kettlehat", "coif"], ["coif"]],
              "dye": {"colour": [0.62, 0.52, 0.16], "shift": 0.06, "fade": [0.0, 0.4]},
              "grime": [0.2, 0.7]}
}
```

- **`probe`:** a few outfit vertices with their rest positions and the position of the body point each one covers. Check K3 uses it.
- **Export button:** each `.blend` carries an `export.py` text block that runs `tools/wardrobe/export.py` on the open file, so a hand edit can be re-exported without the headless runner.

### 6.7 Validation

The export refuses to write, and lists every failure, if:
- a mesh, or the heaviest combination of outfit, head, hair and headgear, is over budget;
- an albedo is the wrong size or has more colours than the palette allows;
- a vertex has more than 4 influences or no weight, or is weighted to a bone that is neither a game bone nor a declared cloth bone;
- any body face is left under a garment (the ray test from step 4);
- any UV is outside 0–1;
- any game bone's joint is more than 1 mm from its position in the Quaternius skeleton.

### 6.8 Safety

- `build.py` stores a hash of the objects it generated. It refuses to overwrite a `.blend` that was edited by hand since then, unless given `--force`.
- A backup is saved before every write of a `.blend` or an export.
- Blender rules from earlier sessions:
  - work only in Claude's own `AUCOD_*` scenes and files;
  - save with `copy=True` before exporting;
  - never export the Quaternius eyes or eyebrows;
  - low-poly always;
  - `.gdignore` in source folders.

## 7. The Godot side

### 7.1 Dressing

A new `scripts/Visual/Wardrobe.gd` holds static loaders and caches: outfits, heads, hair, headgear and their JSON. It also does the skin re-binding and the variety roll.

`Humanoid.dress(kind, seed)`:
1. Builds as `build(&"", female, fighting_idle)` does today: skeleton, animation tree, `Posture`. It then frees the base body, eye and brow meshes.
2. Reads `<kind>.json` and the JSON of each rolled headgear piece, and adds all their cloth bones to the skeleton.
3. Adds the outfit mesh, which becomes `body`, then the rolled head, hair or beard, and headgear. Rigid headgear goes through `attach`; skinned headgear is bound like hair.
4. Gives every worn mesh its kind's shared material and the guard's instance uniforms.
5. Makes the `Cloth` node (section 7.4).

`Humanoid.worn()` returns every worn mesh.

`build(outfit)` stays exactly as it is for `ViewArms` and the older stagers.

- **`GuardFighter.ARCHETYPES` looks** shrink to kind, scale and weapon, for example `{"kind": &"swordsman", "scale": 1.0, "weapon": &"sword"}`. Female, faces, hair and colours come from the JSON.
- **`GuardRig.setup`** calls `dress` when the kind's files exist, and otherwise falls back to the painted path (section 10).
- **`Guard`** gains `@export var look_seed := -1`, where -1 means a hash of the guard's node path.

### 7.2 Skin re-binding

The problem: Blender may export bones in different orientations from the Quaternius glTF. Each loaded skin is therefore converted to the game skeleton's own rest frames.

For bind `i` on bone `n`, with inverse bind matrix `B_i` from the GLB:

```
new_bind_i = R_game(n)⁻¹ · R_glb(n) · B_i
```

`R_x(n)` is bone `n`'s global rest transform in skeleton `x`. At rest, `R_game(n) · new_bind_i = R_glb(n) · B_i`, which is exactly Blender's skinning. In any pose, the bone's world-space movement is the same whatever its frame, so the mesh deforms identically.

Cloth bones are added with local rest `R_game(parent)⁻¹ · R_glb(bone)`. This is worked out through global transforms, so the whole chain is in game frames.

Re-bound skins are cached per file and body. The same code serves outfits, heads, hair and skinned headgear. The painted path (your arms, the old boots) is left alone: a probe showed the boots' Blender round trip already kept the frames exactly. This also removes, for meshes, the Blender round-trip risk the HEMA spec flagged.

### 7.3 Material (`scripts/Visual/wardrobe.gdshader`)

- **Render modes:** `diffuse_lambert_wrap` and `specular_disabled`. Closed surfaces cull back faces. The strips surface culls nothing and flips the normal on back faces.
- **Samplers:** albedo and mask use `filter_nearest_mipmap` and `repeat_disable`. The shader sets this itself, because the Retro autoload only converts `BaseMaterial3D`s.
- **Shared uniforms** (one material per kind and surface): albedo and mask.
- **Instance uniforms** (per guard): `dye_colour`, `dye_fade`, `skin_tone` and `grime`.
- **Fragment:**
  - where the mask's R is set, the albedo's luminance is re-tinted toward `dye_colour` and faded toward grey by `dye_fade`;
  - the G region is multiplied by `skin_tone`;
  - the B region is darkened and desaturated by `grime`.
- Heads use the same shader with an empty mask, because their skin tone is baked per texture. Hair uses it with R set everywhere, so the dye is the hair colour.
- The hit rim (`hit_rim.gdshader`) stays a separate overlay.

### 7.4 Cloth (`scripts/Visual/Cloth.gd`)

- **Base:** extends `SpringBoneSimulator3D` (Godot 4.5).
- **Settings:** one per chain in the outfit's and headgear's JSON, from its root to its end bone, with the end bone extended by the strip's last segment. Stiffness, drag, gravity and radius come from the JSON.
- **Colliders:** `SpringBoneCollisionCapsule3D`s on the thighs, calves and spine from the JSON's `colliders`, so skirts stay out of the legs.
- **Order:** Posture, then Ragdoll, then Cloth, then Severed. Severed keeps the last word. `add_ragdoll` moves the Cloth node after the ragdoll it creates.
- **Time:** it runs on the skeleton's modifier clock, so hit-stop and slow motion slow the cloth too.
- **`reset()`:** it runs by itself when the skeleton moves more than 1 m in one frame, as `VerletRope` reseeds. That covers spawns, respawns (gym bays), stager placements and teleports. `GuardBody.spawn` keeps the man where he was, so it needs no reset.

### 7.5 Variety roll

- **Generator:** a `RandomNumberGenerator` seeded by `look_seed` (or the node-path hash). Its draws come in a fixed order:
  1. face;
  2. skin tone;
  3. hair;
  4. beard;
  5. headgear set;
  6. dye shift;
  7. dye fade;
  8. grime;
  9. height, ±3%.
- **Rules:** draws follow the kind's options and each headgear's hair rules.
- **Result:** stored as `Humanoid.look`, so tests and the gym's F1 labels can show it.
- **Height is visual only.** It scales the rig, not reach, eyes, collision or ragdoll mass.

### 7.6 Fitting the existing systems

| System | Change |
|---|---|
| Hit flash | `GuardRig` lays `_overlay` over every mesh in `man.worn()`, not only `body_mesh`, and clears them all in `_exit_tree`. |
| Wounds, arrows, blade blood | None. They ride `BoneAttachment3D`s and decals on `Layers.ACTORS`. |
| Ragdoll | None. It still has 12 bodies on game bones; cloth bones are not part of it. |
| Dismemberment | One general copy rule in `Humanoid.sever`: a severed part takes every worn skinned mesh with any bind on its bones, with its materials and instance uniforms. A head takes its face, hair, beard, coif and hood (the hood's tail rides stiff on the flying head); rigid helmets go with it as they do today. A leg takes its boot and its piece of the outfit. Skirt, tabard, cape and sash chains hang from the pelvis and spine, so they stay on the body. `Severed.gd` is unchanged. |
| Armour sounds | Rigid headgear stays in `armour`. `armour_near(point)` also returns the metal mesh when the point's nearest flesh bone is in the `metal` list of the outfit's JSON or of a worn headgear piece (the coif, the mail curtain). Cloth pieces never count. |
| Corpses, severed parts | Nothing beyond the copy rule. `GuardBody` moves the same man; `SeveredPart` gets the copied meshes. |
| Stealth | None. `LightProbe` is analytic, and every worn mesh stays on `Layers.ACTORS`. |
| Your arms | None. `ViewArms` uses `build(&"player")` and `Boots_Male.glb` as before. |

## 8. The six NPCs

| Kind | Silhouette key | Wears | Colours | Cloth chains | Metal zones | Varies per guard |
|---|---|---|---|---|---|---|
| **Watchman** | Wide kettle-hat brim over a flared skirt | Kettle hat over a mail coif; quilted gambeson to mid-thigh with split skirts; the city's tabard, belted; hose; turned-down boots; pouch, key ring and scabbard | Mustard and black over tan | Skirt ×4 (2 bones each), tabard front and back (2) | none (the hat and coif are headgear) | Face, stubble or beard, coif or bare head under the kettle hat (always worn: it is his silhouette), tabard fade, grime |
| **Swordsman** | Pointed helm, broad armoured shoulders, skirt to the knee | Nasal helm with its mail curtain; mail shirt to the knee over quilted sleeves; red surcoat with the white stripe; iron pauldrons; leather gauntlets and boots | Red and white over grey steel | Surcoat front and back (3), mail skirt front and back (2, heavy and draggy) | spine_01–03, pelvis, upper arms | Face, surcoat shade and fade, grime |
| **Duelist** | Puffed shoulders, a half-cape, tall boots | Bare head, hair up; fitted doublet with slashed, puffed sleeves and a short skirt; half-cape on the left shoulder; breeches; folded thigh boots; rapier on a hanger | Crimson and gold over black | Skirt ×4 (1), half-cape ×3 (3) | none | Face (sharp or soft), buns or tied hair, doublet shade |
| **Brute** (3,500 triangles) | Huge fur shoulders, bare arms, strips at the waist | Shaved head and beard; bare arms with bracers; stiff fur mantle; studded leather jerkin over a padded gut; wide belt; hide strips; one crude iron pauldron; fur-topped boots | Browns, dark leather, iron | Hide strips ×4 (2) | upperarm_r | Face (heavy or weathered), beard, grime |
| **Archer** | Pointed hood with a short cape, a quiver on the hip | Hood whose tail swings; leather jerkin over a tunic; bracer; bolt quiver, pouch and knife; wrapped calves and soft boots | Forest green and brown | Hood tail (3), quiver (1) | none | Face under the hood, green, brown or grey dye, grime |
| **Arms master** | Lean and upright, sash tails, no armour | Grey parted hair and full grey beard; undyed quilted arming doublet; dark sash; sparring gloves; low boots | Undyed linen, dark sash | Sash tails ×2 (3), doublet skirt ×4 (1) | none | Almost nothing: he is one man, always the old face |

**Shared parts:**
- **Heads:** male young, weathered, heavy and old; female sharp and soft; each in light and dark skin.
- **Hair:** buzzed, parted, tied back, buns.
- **Beards:** full, short, moustache.
- **Headgear:** kettle hat, mail coif, nasal helm with its curtain, archer's hood.

**Faces by kind:**
- watchmen, swordsmen and archers roll any male face;
- the brute gets the heavy or weathered face;
- the arms master always has the old face;
- the duelist gets sharp or soft.

## 9. Verification

### 9.1 Automated checks

- **Export validation** (section 6.7) runs on every export.
- **`tests/wardrobe_test`**, headless, checks K1–K12:

| Check | What it proves |
|---|---|
| K1 | Every kind with wardrobe files dresses: the outfit is `body`; head, hair and headgear are present as rolled; no base Quaternius body, eye or brow mesh is left. |
| K2 | Budgets: worn-mesh triangles ≤ 3,000 (brute ≤ 3,500) for every combination; albedos are 256 px (heads 128 px) with no more colours than the palette. |
| K3 | Re-binding is exact. At rest, every `probe` vertex skins to within 1 mm of its Blender position. In a mid-swing pose, it stays within 3 cm of the body point it covers. Checked on both bodies. |
| K4 | After a sudden stop from a run, skirt tips swing at least 5 cm and settle (tip speed under 2 cm/s) within 1.5 s, with no NaN. |
| K5 | Through a kick and a lunge, no skirt joint enters a thigh or calf capsule. |
| K6 | On a limp ragdoll, a cape's tip speed never exceeds 5 m/s and falls under 5 cm/s within 2 s. |
| K7 | Sever: a head takes head, hair or beard and headgear; a leg takes its boot and outfit piece; cloth chains stay on the body; the body's outfit shrinks at the cut. |
| K8 | The hit flash covers every worn mesh. |
| K9 | Helmets and metal zones count as armour for sounds; cloth pieces and bare flesh do not. |
| K10 | The same seed always gives the same look. Four guards of a kind with different seeds are not all alike. The kind's silhouette key (its headgear or mantle class) is always present. |
| K11 | Your arms are unchanged: `ViewArms` still uses the painted path. |
| K12 | A guard teleported 20 m does not whip its cloth: tip speeds stay under 0.5 m/s for the first 5 frames after the move. |

### 9.2 Existing suites

Every existing suite still passes. Checks that look inside the old painted body (mesh names, the painted material) are updated to the wardrobe equivalents, with the reason noted in the test.

### 9.3 Visual review

- **New `tests/visual/stage_wardrobe`**, all at the Retro 360-line screen:
  - all six kinds in neutral light and at night by a torch;
  - front, three-quarter, side and back views at 2 m and 8 m;
  - four random guards per kind;
  - before/after sheets against today's look.
- **Existing stagers:** `stage_guards` (every combat pose, checked for skin through clothes), `stage_gym`, and the guard in the showcase hall (`stage_look`).
- **During modelling:** Blender preview renders, judged by eye.
- **Hand-off:** contact sheets go to the user at the end of each batch.

## 10. Error handling

- **Missing or invalid wardrobe files for a kind:** the guard falls back to today's painted outfit, or to the plain base body once those textures are deleted, with one `push_warning`. A guard always spawns.
- **An option in the JSON that points at a missing head, hair or headgear:** that option is dropped, with a warning.
- **Export:** refuses to write on any validation failure and lists them all (section 6.7).
- **Build:** refuses to overwrite a hand-edited `.blend` without `--force` (section 6.8).

## 11. Components

**New:**
- `tools/wardrobe/recipes.py`, `common.py`, `build.py`, `bake.py`, `export.py`, `wardrobe.sh`
- `assets/characters/wardrobe/**` (sources and exports)
- `scripts/Visual/Wardrobe.gd`, `scripts/Visual/Cloth.gd`, `scripts/Visual/wardrobe.gdshader`
- `tests/wardrobe_test.gd/.tscn`, `tests/visual/stage_wardrobe.gd/.tscn`

**Changed:**
- `scripts/Visual/Humanoid.gd`: `dress`, `worn`, the general sever copy rule, metal zones in `armour_near`, and cloth ordering in `add_ragdoll`.
- `scripts/AISystem/GuardRig.gd`: the dress path, and the hit flash on every worn mesh.
- `scripts/AISystem/GuardFighter.gd`: looks become kinds.
- `scripts/AISystem/Guard.gd`: `look_seed`.
- `.gitignore`: wardrobe backups.

**Retired in batch 3:**
- The painted guard outfits (`T_watchman` … `T_trainer`) stop being used by guards. They are deleted only with the user's go-ahead.
- `T_player` and `dress_characters.py` stay for your arms.

## 12. Risks

| Risk | Mitigation |
|---|---|
| Scripted modelling can look blobby or procedural. | Batch 0 proves the whole look on one kind before anything is copied. Renders are checked at every step, and every `.blend` stays hand-editable. |
| Baked procedural textures can look noisy rather than hand-painted. | Palette reduction, painted top light and edge wear, tuned in batch 0. Faces are PNGs the user can repaint in Aseprite. |
| Spring cloth can jitter under hit-stop or at low frame rates. | Stiffness and drag tuning, reset on jumps, and checks K4–K6 and K12. |
| Deleting hidden body faces can open gaps at garment edges in extreme poses. | A 5 mm margin, plus the every-pose stager. |
| Decimating the head loses the face. | The face lives in the baked texture, not the geometry. The lattice variants carry the shape. |
| The glTF round trip reorients bones. | Skin re-binding (section 7.2) makes orientation irrelevant for meshes; K3 proves it. |
| Clash with the HEMA animation project. | They share only the skeleton. This project never touches animation. |
| Blender crashes or the MCP link drops. | Backups before every write, headless scripts that rebuild everything, one file per kind. |

## 13. Rollout

There is one implementation plan per batch, and the user reviews after each.

| Batch | Contents | Review |
|---|---|---|
| **0 · Pipeline + the watchman** | `tools/wardrobe` (all five scripts and the runner); `Wardrobe.gd`, `Cloth.gd`, `wardrobe.gdshader`; `Humanoid.dress` with re-binding, sever, hit flash and armour integration; the complete watchman with the weathered face, kettle hat and coif; checks K1–K12 on him; `stage_wardrobe`. | Old vs new watchman. The PS2 rules are tuned here (palette size, texel density, grime, shading) before any other kind is built. |
| **1 · Swordsman, archer, arms master** | Male body; they reuse the watchman's parts and fabrics. Mail, the surcoat, the hood with its tail, the sash. | Lineup sheets |
| **2 · Brute and duelist** | Bare arms, fur and the 3,500 budget; the female body and the half-cape. | Lineup sheets |
| **3 · Heads and variety** | All faces and skin tones, hair and beards, helmet variants, the full roll. The painted outfits leave the guard path. | Crowd sheets |

Git: most of the project is untracked. Nothing is committed without the user's go-ahead.
