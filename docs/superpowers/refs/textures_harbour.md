# textures.com buy list: the Iberian harbour (night)

Research date: 29 Sept 2026. Read-only browsing of textures.com in the built-in browser; every item below was checked on its own item page unless it is marked *(listing only)*. No sign-in, no downloads.

## How to read this list

- **Credits** are for size **S** (about 1024 px on the long side; some seamless tiles are only 512 px at S, which is still enough for a 128–256 px target).
- A textures.com "item" is a **set of images**. Each image is bought on its own (1 credit at S). The seamless tile is almost always **Image 1**; the other images are the raw source photos. Where it matters, the table says which image to buy.
- **PBR** items sell each map separately (Albedo, Alpha, AO, and so on, 1 credit each at S 512). Their albedo is flat and unlit.
- **Badges seen:** every photo pick shows "IP-Warranty" and "Regular Photo". The PBR picks show "Special Content". None of the recommended items has a "Textures AI" badge.
- "Seamless" means seamless in X and Y (keywords `seamless seamlessx seamlessy`). "Seamless-X" means it tiles horizontally only, which suits bands.

## Buy list

| # | Need | Item | Image to buy | Credits (S) |
|---|------|------|--------------|-------------|
| 1 | Hull planks (tarred) | WoodPlanksPainted0242 | Image 1 | 1 |
| 1b | Hull planks (real ship hull) | WoodPlanksBare0437 | Image 2 (file _9) or Image 5 (_12) | 1 |
| 2 | Sailcloth | FabricPlain0138 | Image 1 | 1 |
| 3 | Rope, tiling along its length | Various0236 | Image 1 (Image 2 is its normal map) | 1 |
| 3b | Coiled rope (to mask by hand) | Various0215 | Image 1 | 1 |
| 4 | Fishing net, alpha | Thick Rope Net PBR00873 (PBR) | Albedo S + Alpha S | 2 |
| 5 | Granite quay ashlar | StoneRegularWeathered0084 | Image 1 | 1 |
| 5b | Rock-faced granite (walls, towers, gate) | StoneFacade0043 | Image 1 | 1 |
| 6 | Iron railings / rejas | **Nothing suitable.** Paint our own (see below) | – | 0 |
| 7a | Ochre plaster | PlasterPaintWorn0152 | Image 1 | 1 |
| 7b | Salmon / terracotta plaster | PlasterPaintWorn0169 | Image 1 | 1 |
| 7c | Pale blue plaster | PlasterPaintWorn0007 | Image 1 | 1 |
| 8a | Green relief azulejo | TilesRelief0010 | Image 1 | 1 |
| 8b | Polychrome azulejo + border | TilesPatterned0311 | Image 1 + Image 3 (border strip) | 2 |
| 9a | Waterline, algae band | StoneRegularWeathered0241 | Image 1 | 1 |
| 9b | Waterline, tide band (Seamless-X) | StoneRegularWeathered0163 | Image 1 | 1 |
| 10a | Terracotta floor | Rustic Antique Terracotta Pavement PBR00193 (PBR, **free**) | Albedo | 0 |
| 10b | Terracotta floor, worn hexagons | Old Hexagon Terracotta Pavement PBR0600 (PBR) | Albedo S | 1 |
| 11a | Limestone cliff, far read | Cliffs0211 | Image 1 (+ Image 2 to break the repeats, +1) | 1 |
| 11b | Limestone rock, close read | RockBlocky0085 | Image 1 | 1 |
| | **Core total (needs 1–11)** | | | **20** |
| 12 | Yesería | OrnamentsMoorishStucco0223, OrnamentsMoorishStucco0212 | Image 1 each | 2 |
| 12 | Zellige | TilesZellige0098, TilesZellige0024 | Image 1 each | 2 |
| 12 | Marble | MarbleTiles0148, FloorsCheckerboard0050 | Image 1 each | 2 |
| 12 | Gothic / Manueline | OrnamentBorder0077, OrnamentsVarious0001 | Image 1 each | 2 |
| 12 | Old brick (the closest to Roman brick) | BricksSmallOld0199 | Image 1 | 1 |
| 12 | Clipped hedge | Hedges0060 | Image 1 | 1 |
| | **Nice-to-have total** | | | **10** |
| | **Grand total** | | | **30** |

Optional extras: WoodPlanksFloors0011 (seamless ship deck from the same replica ship, 1 credit), a second Cliffs0211 variant (1), and the PBR AO maps (1 each) for multiplying grout or knot shading into the albedo.

---

## 1. Ship hull planks

**WoodPlanksPainted0242** (best match): https://www.textures.com/download/wood-planks-painted-0242/77755
- Category: Wood > Planks > Painted. Regular photo, 1 image, S 1024x829, 1 credit. **Not seamless.**
- Keywords: tar, tarred, painted siding, black, dark grey.
- Why it survives 128–256 px: five or six wide, near-black tarred boards per frame, with pale split ends, bolt holes and wear. The horizontal value bands and dark seams stay readable when downsampled.
- Caveat: crop the grass strip at one edge. Horizontal planks make tiling easy: cut Y at a plank seam, and blend X once with an offset-and-clone.

**WoodPlanksBare0437** (a real ship hull): https://www.textures.com/download/wood-planks-bare-0437/36926
- Category: Wood > Planks > Bare. Regular photo, 7 images, each 1 credit at S (about 1024x650). Not seamless.
- Keywords: ship hull, pirate.
- Why it survives: flush (carvel) planks with dark caulked seams and big iron bolt heads, the true carrack read. The best frames are Image 2 (file _9) and Image 5 (_12).
- Caveat: the timber is orange varnish. Darken and desaturate it in ps2ify to make it tarred.

**Alternatives and notes:**
- **WoodPlanksPainted0243** (https://www.textures.com/download/wood-planks-painted-0243/77756) is the same tarred series, cleaner, with green algae streaks, for the hull's waterline strake. 1 image, S 1024x615, 1 credit.
- **WoodPlanksFloors0011** (https://www.textures.com/download/wood-planks-floors-0011/36907) is the seamless deck from the same replica ship (keywords: deck, ship, pirate). Image 1 seamless 1024, 1 credit. Optional, since you own WoodPlanksOld0239 and 0292.
- Rejected:
  - Seamless dark planks (WoodBurned0077, WoodPlanksDirty0101–0103): charred alligator texture turns to noise, and the boards are vertical siding.
  - WoodPlanksOverlapping0019: clinker look, too clean.
  - WoodPlanksPainted0330: dozens of thin boards.

## 2. Sailcloth / canvas

**FabricPlain0138**: https://www.textures.com/download/fabric-plain-0138/107640
- Category: Fabric > Plain Fabric. Regular photo, 1 image, S 1024x663, 1 credit. Not seamless.
- Keywords: dirty rag, brown, beige, grey.
- Why it survives: off-white cloth with large soft brown stains and creases. The stains survive as grime blotches, and the weave vanishes, which is what we want.
- Caveat: it has **no seams or patches**. Paint three or four vertical panel seams and a patch in the ps2ify step, then make it tile.
- Gap: textures.com has no sail photos. I searched sail, sailcloth, canvas, tarp, tent and patched. The canvas hits (FabricPlain0045/0055/0020) are weave macros that turn to noise.
- Alternative for tan or working sails and awnings: FabricPlain0105, a stretched brown stained canvas with one seam, https://www.textures.com/download/fabric-plain-0105/48523 *(listing only)*.

## 3. Rope

**Various0236**: https://www.textures.com/download/various-0236/29778
- Category: Various > Various. Regular photo. Image 1 is seamless, S 1024x253, 1 credit. Image 2 is its normal map; skip it.
- Keywords: rope, normalmap, tiling. Seamless in X and Y.
- Why it survives: tan twisted strands made to wrap and tile along the rope. At a 32–64 px wide strip it becomes the classic diagonal PS2 rope stripe.

**Coiled rope:** there is **no alpha-masked coil** on textures.com. I searched rope, coiled, "rope alpha" and 3D assets.
- Best source to mask by hand: **Various0215**, https://www.textures.com/download/various-0215/27300. A close-up of an old coiled hemp rope, S 1024x847, 1 credit. Big loops read at 256 px.
- Other sources:
  - Various0214 (https://www.textures.com/download/various-0214/27296): one straight beige rope on a dark background, 1024x132, not seamless.
  - OrnamentsVarious0001 (see 12): a carved stone rope coil; mask it and tint it.

## 4. Fishing net (alpha)

**Thick Rope Net PBR Material, PBR00873** (PBR): https://www.textures.com/download/thick-rope-net-pbr-material-pbr00873/145973
- Category: Fabric > Netting. Knotted diamond mesh in hemp brown, a 1 x 1 m seamless tile.
- Buy **Albedo S 512 (1 credit) + Alpha S 512 (1 credit) = 2 credits**. At this item, M 1024 is also 1 credit per map.
- Why it survives: about 10 cells per tile, with knots. At 256 px each cell is about 25 px and each strand 2–3 px, so the alpha test holds up. The albedo is unlit, but a thin dark net barely needs baked light.
- This is the only masked net on the site. The regular-photo search for "net" and "fishing" only returns camouflage netting.
- Alternative: **Thin Rope Net PBR00875**, https://www.textures.com/download/thin-rope-net-pbr-material-pbr00875/145980. A square mesh on a 30 x 30 cm tile, teal and white colour variants, Albedo + Alpha = 2 credits.

## 5. Granite blocks

**StoneRegularWeathered0084** (quays): https://www.textures.com/download/stone-regular-weathered-0084/7301
- Category: Stone > Regular Weathered. Regular photo. Image 1 is seamless, S 1024x1017, 1 credit.
- Keywords: waterline, dock, harbour wall, grey.
- Why it survives: grey dressed ashlar in about 10 courses, with a darker wet lower half. The large blocks and joints read at 128 px. It is distinct from your 0227 (pale rough blocks) and 0289 (light wall with a thin algae line).

**StoneFacade0043** (fortifications): https://www.textures.com/download/stone-facade-0043/2599
- Category: Stone > Facade Stones. Regular photo. Image 1 is seamless, S 1024x1024, 1 credit.
- Keywords: medieval, rounded, rough, grey.
- Why it survives: rock-faced (bossed) grey blocks with deep shadowed joints, the strongest value contrast in the category. Use it for the sea wall, the towers and the Sea Gate.

**Alternative:** StoneFacade0024 (https://www.textures.com/download/stone-facade-0024/72374). Paler beige rusticated big blocks, Image 1 seamless, S 1024x878, 1 credit.

## 6. Wrought-iron railings and rejas: gap

**Nothing on textures.com fits.** Searches and categories checked:
- Searches: railing, wrought iron, iron fence, balcony, balustrade, grille, window bars, gate iron, "masked iron/fence/ornament", "fence/iron isolated".
- Categories: Metal > Fences (corrugated sheets), Metal > Various (chain-link and chains), Wire Fences (PBR mesh), Ornaments > Borders (stone friezes), Moorish > Metal (brass door panels).

The only masked ironwork on the site is OrnamentsHinges0028, which you already own.

**Recommendation:** paint the railing and reja alpha ourselves: bars plus one scroll band, 64–128 px, 1-bit alpha. At this resolution a clean painted silhouette reads better than a photo cutout.

If you want a painted base or reference:
- OrnamentsVarious0408 (https://www.textures.com/download/ornaments-various-0408/123792): a wrought-iron scroll grille, Image 1 seamless, S 945x1024, 1 credit. A wire mesh sits behind the scrolls, so masking it is hard.
- OrnamentBorder0229 (https://www.textures.com/download/ornament-border-0229/68826): a cast-iron railing shot with its background *(listing only)*.
- Flat windows with bars baked in, such as WindowsHouseOld0144 and 0145, turned up in a "window bars" search *(listing only)*.

## 7. Coloured painted plaster (all Plaster > Painted Worn, regular photo, seamless)

- **Ochre: PlasterPaintWorn0152**, https://www.textures.com/download/plaster-paint-worn-0152/46811. Image 1 seamless, S 1024x1024, 1 credit. Yellow ochre with large pale patches of lost paint, which read as big shapes.
- **Salmon / terracotta: PlasterPaintWorn0169**, https://www.textures.com/download/plaster-paint-worn-0169/134822. Image 1 seamless, S 512x512, 1 credit. Salmon terracotta with big pale plaster losses and a grimy base. It has the strongest value contrast of the three.
- **Pale blue: PlasterPaintWorn0007**, https://www.textures.com/download/plaster-paint-worn-0007/90011. Image 1 seamless, S 512x512, 1 credit. A pale blue-grey wash with a scatter of dark peel spots. It reads as a clean wash, and that is the intent.

**Alternatives:**
- PlasterPaintWorn0084 (https://www.textures.com/download/plaster-paint-worn-0084/89814): an ochre wall with a dark-brown painted plinth band, Image 1 Seamless-X, 1024. Good for a ground-floor socle.
- PlasterColoured0306, dusty pink with peeling (https://www.textures.com/download/plaster-coloured-0306/56955) *(listing only, seamless)*.
- PlasterColoured0132, strong yellow ochre (https://www.textures.com/download/plaster-coloured-0132/26512) *(listing only, seamless)*.

## 8. Azulejo facade tiles (not blue)

**TilesRelief0010** (green relief): https://www.textures.com/download/tiles-relief-0010/135249
- Category: Tiles > Relief. Regular photo. Image 1 is seamless, S 512x512, 1 credit.
- Why it survives: green glazed relief tiles in an octagon-and-square pattern. A few large shapes plus variation in the glaze: the Porto house front.

**TilesPatterned0311** (polychrome): https://www.textures.com/download/tiles-patterned-0311/135342
- Category: Tiles > Patterned. Regular photo.
- Buy Image 1, a seamless 512 field of 2x2 tiles (yellow, blue and green cubes on white), 1 credit. Add Image 3, a seamless 512x128 border strip, 1 credit.
- Keywords: azulejo, geometric cubes, Portugal.
- Why it survives: three flat tones per rhombus, so it holds even at 128 px.

**Alternatives:**
- TilesRelief0005 (https://www.textures.com/download/tiles-relief-0005/135217): deep green floral relief. 18 images, several of them seamless 512 variants.
- TilesPatterned0342 (https://www.textures.com/download/tiles-patterned-0342/135731): green stencil scrolls, keywords "azulejo Portugal green", Image 1 seamless 512.

## 9. Waterline stone

**StoneRegularWeathered0241**: https://www.textures.com/download/stone-regular-weathered-0241/2539
- Regular photo. Image 1 is seamless, S 1024x354, 1 credit.
- Why it survives: a thick green algae band over black wet stone and mud. The strong horizontal bands read from far away.

**StoneRegularWeathered0163**: https://www.textures.com/download/stone-regular-weathered-0163/95018
- Regular photo. Image 1 is **Seamless-X**, S 1024x497, 1 credit.
- What it shows: yellow lichen along the top, clean blocks in the middle, a sharp tide line, and a dark wet lower half. It is exactly a band that tiles along the quay.

Both carry much more tide than your 0289, which has only a thin algae line.

Seen in listings (not seamless): StoneRegularWeathered0133 (pale blocks with a brown weed band) and 0251 (a round tower wall covered in algae).

## 10. Terracotta floor tiles

No regular-photo interior terracotta exists:
- The keyword "terracotta" returns 0 photos.
- Floors > Medieval, Regular and Hexagonal are outdoor pavers.
- FloorsCheckerboard0050 and 0051 are marble.

So these are PBR:
- **Rustic Antique Terracotta Pavement, PBR00193**, https://www.textures.com/download/rustic-antique-terracotta-pavement-pbr00193/133597. **FREE** (0 credits at every size), seamless albedo. Orange terracotta octagons with small square insets (tacos) and dark grout: big shapes, very Iberian.
- **Old Hexagon Terracotta Pavement, PBR0600**, https://www.textures.com/download/old-hexagon-terracotta-pavement-pbr0600/139489. Albedo seamless, S 512, 1 credit. Worn dusty-red hexagons with pale grout.

Caveat: the albedo is unlit. Bake the light into vertex colour, or buy the AO map (1 credit) and multiply it in for grout depth.

## 11. Cliff for the rock

**Cliffs0211**: https://www.textures.com/download/cliffs-0211/58298
- Category: Rock > Cliffs. Regular photo. Images 1–4 are all seamless, S 1024, 1 credit each.
- Why it survives: a big limestone face, beige-grey with vertical fluting and dark rain streaks. Its large value zones read from the harbour.
- Buy Image 1, and Image 2 if you want to break up the repeats.

**RockBlocky0085**: https://www.textures.com/download/rock-blocky-0085/67615
- Category: Rock > Blocky Cliffs. Regular photo. Image 1 is seamless, S 1024, 1 credit.
- What it shows: grey limestone in horizontal beds with vertical joints. Use it close up, at the foot of the rock and along paths.

**Alternative:** Cliffs0392 (https://www.textures.com/download/cliffs-0392/67984). Pale blocky limestone with a dark fracture network; Image 1 seamless, Image 2 Seamless-X.

## 12. Nice-to-haves for later districts

- **Yesería:**
  - OrnamentsMoorishStucco0223 (https://www.textures.com/download/ornaments-moorish-stucco-0223/96168): a deep-cut white lattice with big shadows. Image 1 seamless, S 1024x679, 1 credit.
  - OrnamentsMoorishStucco0212 (https://www.textures.com/download/ornaments-moorish-stucco-0212/96143): a sebka lozenge net with palmette infill, the Alhambra and Seville look. Image 1 seamless, 785x1024, 1 credit. The infill blurs but the net reads.
  - Category: Ornaments > Moorish > Stucco, 287 items.
- **Zellige:**
  - TilesZellige0098 (https://www.textures.com/download/tiles-zellige-0098/96304): a large eight-point star in ochre, blue, black and white. Image 1 seamless, 1017x1024, 1 credit.
  - TilesZellige0024 (https://www.textures.com/download/tiles-zellige-0024/96174): a lattice of diamonds in magenta, teal, blue and white. Image 1 seamless PNG, 1022x1024, 1 credit.
- **Marble:**
  - MarbleTiles0148 (https://www.textures.com/download/marble-tiles-0148/94888): weathered cream marble blocks with dark rain streaks. Image 1 Seamless-X, 1024x525, 1 credit.
  - FloorsCheckerboard0050 (https://www.textures.com/download/floors-checkerboard-0050/115317): an old church marble checker floor. Image 1 seamless, 1022x1024, 1 credit.
  - Alternative: FloorsCheckerboard0055 (https://www.textures.com/download/floors-checkerboard-0055/134924), black and cream, seamless 512.
- **Gothic / Manueline:**
  - OrnamentBorder0077 (https://www.textures.com/download/ornament-border-0077/19279): a cusped Gothic blind-arcade frieze in grey church stone. S 1024x807, 1 credit, not seamless.
  - OrnamentsVarious0001 (https://www.textures.com/download/ornaments-various-0001/3464): a carved stone rope coil on a brick wall, the Manueline rope motif. S 1024x1003, 1 credit; mask it out. The same image can serve as a coiled-rope decal base once tinted.
  - Also seen: BuildingsOrnate0049, Gothic blind tracery panels, 1 credit.
- **Old "Roman" brick:** nothing on the site is tagged Roman. The nearest is BricksSmallOld0199 (https://www.textures.com/download/bricks-small-old-0199/110121): eroded Venetian brick with deep joints and a plaster patch. S 1024x693, 1 credit, not seamless. Caveat: small bricks turn to noise at 128 px, so use it at 256 px with a large texel scale.
- **Clipped hedge:**
  - Hedges0060 (https://www.textures.com/download/hedges-0060/42279): a dense, dark, small-leaved clipped hedge that reads as myrtle or box. Image 1 seamless, S 1024, 1 credit. The leaves become mottle at 128 px, which is fine for a clipped hedge; darken the base with vertex colour.
  - Cypress-like alternative: Hedges0061, a dense yew or conifer (https://www.textures.com/download/hedges-0061/42577) *(listing only, not seamless)*.

---

## Pages opened

**Item pages:**
- Wood: WoodPlanksBare0437; WoodPlanksPainted0241, 0242, 0243, 0330; WoodBurned0077; WoodPlanksOverlapping0019; WoodPlanksFloors0011.
- Fabric and rope: FabricPlain0138; Camouflage0025; Thin Rope Net PBR00875; Thick Rope Net PBR00873; Various0236, 0214, 0215, 0108.
- Ornaments and metal: OrnamentsVarious0001, 0408; MetalVarious0044; Medieval Castle Gate PBR0231; OrnamentBorder0077; BuildingsOrnate0049; OrnamentsMoorishStucco0212, 0223.
- Stone and rock: StoneFacade0024, 0043, 0045; StoneRegularWeathered0084, 0163, 0241; Cliffs0211, 0392; RockBlocky0085.
- Plaster: PlasterPaintWorn0007, 0084, 0152, 0169.
- Tiles and floors: TilesPatterned0311, 0338, 0342; TilesRelief0005, 0010; TilesZellige0024, 0098; MarbleTiles0148; FloorsCheckerboard0050, 0051, 0055; Rustic Antique Terracotta Pavement PBR00193; Old Hexagon Terracotta Pavement PBR0600.
- Other: BricksSmallOld0199, 0207; Hedges0060.

**Categories and searches browsed:**
- Wood: Old Planks, Dirty, Painted.
- Fabric: Plain Fabric, Wrinkles > Hanging, Netting.
- Stone: Stone > Regular, Facade Stones, Regular Weathered; Brick > Blocks.
- Metal: Metal > Fences, Metal > Various, Wire Fences; Ornaments > Borders.
- Plaster: Plaster > Coloured, Painted Worn.
- Tiles: Plain Tiles, Relief, Zellige, the azulejo search.
- Ornaments > Moorish: Metal, Stucco.
- Floors: Medieval, Regular, Hexagonal.
- Rock: Blocky Cliffs, Cliffs.
- Marble: Marble > Tiles.
- Searches (for example): hedge, harbour, waterline, terracotta, gothic, rope, net, fishing, railing, wrought iron, balcony.
