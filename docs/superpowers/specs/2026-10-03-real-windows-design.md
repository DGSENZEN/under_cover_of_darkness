# Real windows, and the light through them (Oct 3 2026)

**Status: built** on branch `real-windows` (plan
docs/superpowers/plans/2026-10-03-real-windows.md, Tasks 1-10; ledger in
.superpowers/sdd). windows_test GW1-GW20 green; all 57 suites green (sound
M18 flakes only under six-at-once load). Bench: fps 101-103 (main 101.8),
p99 16.9-18.0 ms, one run 22 ms (main 16.6). Taken beyond the text below,
each for the reason given: a shaft's mouth is the beam's cross-section at
the room's (or, for a lamp, the outer) face, so records carry `outside` and
`inside`; a window's room is found 0.3 m past the room's face; a room throws
its lit lamp nearest its windows; the patch's spot stands outside the wall's
face; window shafts are softer and fainter than the chapel's (GodRays
edge_from/edge_to/fall_power; moon gain 0.05, lamp 0.03, lamp reach 4 m)
after the first night stills showed slabs; a lit window glows from within
(a small warm light for show: fx_light, not on the gem's layer); the
carrack's budget 9200; the office's ledger shelves moved off its window.

The user: "Can we make the windows of the buildings we can go in real? And
make them actually project godrays if applicable?"

Their answers (brainstorming, Oct 3 2026):

- **Scope:** the harbour now (the customs house and the carrack's great
  cabin), built as a **shared glazed-window piece** that the old town takes
  up as it is built. The old town's own walls (kit_town) are not touched
  while its session builds them; the garrison chapel keeps its hand-laid
  rays.
- **Both ways:** the moon's light shafts in where it reaches; a lit room's
  lamp throws a warm patch and a faint shaft out through its glass, and
  both go when the lamp is doused.
- **Approach A:** each glazed window is a record the exporter writes; the
  shafts and the lamplight are built at load from those records (not baked
  in Blender, not left to the volumetric fog alone).
- **Guards see through glass**, as you do.

Branch `real-windows` (worktree `.claude/worktrees/real-windows`, from main
c99b516).

## 1. What is there now

- The rooms you can go in: the customs house's hall (ground), its store
  (upstairs), the harbourmaster's office (upstairs, north-east corner), and
  the carrack's great cabin.
- Every window of theirs is a **dark slab**: a `glass_dark` card (opaque,
  #1B2029) behind the painted casement or grille, or a `glass_lit` card
  (emissive). The upper front (kit_customs._upper_front) is cut behind its
  windows; the side and back walls (_side) are one solid box with the
  window drawn on its face. From inside you see a dark plane; no moonlight
  gets in; from outside, nothing of the room shows.
- The carrack's cabin has two transom windows (glass_lit cards either side
  of the skin) and two bulkhead windows onto the waist (glass_dark): the
  same slabs.
- The moon is fixed for each district (maps/city.gd MOON_TOWARD
  (0.3, -0.57, -0.77): from the sea side, about 35 degrees up). It casts
  shadows; what stands under a roof (Layers.ROOFED) is left out of its
  shadow pass for the frame rate.
- God rays exist only in the garrison chapel (scripts/Visual/GodRays.gd +
  god_rays.gdshader), laid by hand per lancet with the room's planes given.
- Guards' sight (Guard._line_of_sight) and the stealth light probe
  (LightProbe.light_at's shadow ray) cast rays against layer 1, where every
  level collider lies: today a window's collider blocks both.
- LevelLoader makes a box **occluder** of every collider at least 3 x 4 m:
  a wall's whole collider would still cull what is behind its glass.

## 2. The window: tools/level/kit_glazing.py (new, shared)

One call makes a glazed window in a wall, for any kit:

    glazed(x, sill, width, height, face_z, thickness, shape="square",
           lead="casement", setback=0.15, inner_slot="plaster",
           reveal_slot=None) -> (shapes, cols, record)

- `shape`: "square", "round" (a round head, as the Manueline windows),
  "arched" (a pointed or segmental head, for later kits).
- **The hole** goes through the wall's whole thickness: the reveals (jambs,
  head, sill) run from the outer face to the inner face; the inner reveal
  is drawn in the room's slot (plastered, as kit_town.inner_slot), the
  outer in the wall's.
- **The glass** sits `setback` (0.12-0.2 m) behind the outer face, a card
  in the `glazing` slot, the opening's shape.
- **The leading** is a card 1 cm in front of the glass in a painted,
  alpha-cut slot: `quarries` (diamond-leaded panes, new painting, for the
  Manueline windows and the carrack), `casement` (the existing painting,
  for the plain side walls), or `grille` (the existing window_grille, for
  the hall's barred windows, drawn in front of the glass). Alpha-cut
  surfaces draw in the opaque and shadow passes, so the bars cast their
  lattice into the moonlight patch.
- **The collider** fills the opening (bodies stop: player, guards, loose
  things, arrows), surface `glass`; a glass box is never an occluder
  (geo.piece_boxes, which the manifest's `occluder` flag follows).
- **A helper for the walls round it:** `split(x0, x1, y0, y1, holes)` (a
  copy of kit_town's; kit_town keeps its own until its session adopts
  this) and `around(outline, holes, normal, slot)`, a planar outline less rectangular holes, cut into bands at the
  holes' edges and triangulated (for the carrack's curved bulkhead and
  transom faces). Wall colliders are split round each opening the same way,
  so no whole wall collider occludes the view through its glass.
- **The record**, in the piece's frame: `{"outline": [[x, y, z], ...]` (the
  glass's corners, a round head as 8 segments), `"normal": [x, y, z]` (out
  of the building), `"lead": "quarries"|"casement"|"grille"}`. A piece
  carries its records as `PIECES[name]["windows"]`.

### The glass: `glazing` slot, scripts/Visual/glazing.gdshader (new)

- Our own painting `glazing` (tools/textures/paint.py): greenish crown
  glass, faint waves and seeds, grime thicker at the edges and the foot.
  Ours, so committed (the public repo's rule is about textures.com only).
- The shader: alpha-blended (no depth prepass), so it is **left out of the
  shadow pass** and the moon goes through it; tint (0.55, 0.62, 0.56),
  alpha about 0.12 rising to 0.35 in the grime; a fresnel sheen of the
  night sky's colour at grazing angles so from outside it reads as glass,
  not a hole; low roughness for a moon glint. The painting sampled
  nearest-with-mipmaps, to sit with the retro look (Retro converts only
  BaseMaterial3D). Two-sided.
- Materials.gd: `glazing` built from the shader (as `glass_lit` is a
  special case); `quarries` a painted, cut slot like `casement`.

## 3. Sight, light and bodies through glass

- LevelLoader._colliders already makes one StaticBody3D per sector and
  surface: the `glass` body (layer 1, meta surface "glass") joins the group
  `glass`. Everything that collides with layer 1 still stops at it.
- **Guards' line of sight** (Guard._line_of_sight) and **the light probe's
  shadow ray** (LightProbe.light_at) step past glass: a ray that hits a
  body in `glass` is cast on from just beyond the hit, that body excluded,
  until it hits something else or arrives (at most 4 panes). One shared
  static helper, `scripts/StimuliSystem/SightRay.gd` `first_solid(space,
  query)`, used by both.
- So moonlight on you through a window lights your gem (the gem is
  rendered) and counts for the guards (the probe), and a guard outside sees
  you through the glass when you are lit; you see him.
- Hearing is unchanged (it travels along the navmesh).
- Glass does not break (out of scope). An arrow strikes it as stone does
  (surfaces the sound and dust do not know fall back to stone).

## 4. Rooms, and the records through export and load

- **Rooms** are box markers, ucd `room` (markers.py: a box, no props),
  laid where a building's rooms are: room_customs_hall,
  room_customs_store, room_customs_office, room_carrack_cabin. A window
  belongs to the smallest room box holding a point 0.3 m inside its
  glass (the office's box lies inside the store's), a lamp likewise.
- **export.manifest** writes `"windows"` (kit_glazing.world_windows, pure
  Python so it is tested outside Blender): each record turned into the world
  (outline and normal through the piece's position and basis, as sockets
  are), with its piece's name and sector. Rooms travel as ordinary markers.
- **LevelLoader**: `Level.windows` (the manifest's list, the skip_sectors
  filter applied like sockets) and nothing else new; `_without` filters
  "windows" too.

## 5. Moon shafts: scripts/Visual/Windows.gd (new)

Made by DistrictMap after the navmesh step (a physics frame has passed, so
rays find the level), before the guards: `Windows.build(levels, moon)`
over the district's own levels (the massing has no windows).

- **Which windows:** the moon must stand in front of the glass,
  dot(normal, -moon_dir) > 0.1, and see it: a 3 x 3 grid of rays from just
  outside the glass toward the moon (200 m, layer 1, glass skipped); a
  shaft is built only if at least 5 of the 9 reach the sky. Its brightness
  is scaled by the share that does.
- **How far it reaches:** a ray from each corner along the moon's way into
  the room (30 m at most, layer 1, glass and loose bodies skipped); each
  corner reaches its own hit, so the shaft ends where the real patch lies
  on the floor or the far wall, and a small thing one corner meets does not
  cut the others short (as an infinite plane from it would).
- **GodRays gains** (the chapel's calls unchanged):
  - `add_window(outline, uvs, reaches := [], source := Vector3.INF,
    weight := 1.0)`: each corner's own reach (else the node's planes); a
    finite `source` makes a point light's shaft, each corner swept along
    (corner - source); `weight` its brightness among the node's shafts
    (the window's share of clear sky).
  - `follow_moon := true`: false for a lamplight node, whose strength
    Windows sets.
  - `tint` exported to the shader's.
- **One GodRays node for all moon shafts** (cool tint, plain glass picture:
  the bars show in the real patch, not in the blurred shaft), `least` 0:
  heavy cloud puts an ordinary window's shaft out as it puts out its patch;
  lightning flares it (the chapel's `flare_gain`).
- **Built once** (the moon is fixed per district); `rebuild()` kept for a
  moon that moves.
- The volumetric fog (the moon's light_volumetric_fog_energy 4) adds its
  soft glow round the shafts for nothing.

### What stands under a roof, in a shaft

ROOFED dressing does not cast in moonlight. Any ROOFED MeshInstance3D
whose bounds meet a moon shaft's volume goes back to the WORLD layer (it
casts), so the moon does not shine through the store's crates. Only the few
pieces in a shaft pay for it.

## 6. Lamplight, outward

- **A room's lamps:** the light markers inside its box (office_candle,
  cabin_candle, cabin_lantern), as LevelGameplay made them (Torch /
  LightFixture: `is_lit()`, `lit_changed`).
- **For each window of a room with a lamp**, from the room's lit lamp
  nearest its windows (when it goes out, the next lit one; none lit, the
  window is dark):
  - **A warm shaft:** one GodRays node per room (`follow_moon` false, warm
    tint, a third of the moon shafts' gain), its shafts point-sourced at
    the lamp; their reach outside from rays to the ground, deck or water,
    10 m at most.
  - **A window-shaped patch:** a SpotLight3D 5 cm outside the glass, aimed
    along lamp to window middle, its angle the glass as seen from the lamp
    plus 4 degrees, range 8 m, no shadow, the window's lead painting as
    its projector (the bars show on the ground), energy starting at half
    the lamp's (tuned by eye). It is a light like any other, so the probe
    counts it: a lamplit patch outside a window is a lit place.
- **Following the lamp:** on `lit_changed` (doused by you or the wind,
  relit by a guard's round; a district's remembered state applied on
  entering) the room's shaft strength and its patches fade over 0.3 s; a
  candle's flicker is carried through (the patch's energy follows the
  lamp's light's energy each frame, scaled).

## 7. The harbour's windows

| Room | Windows | Moon shaft | Lamplight out |
|---|---|---|---|
| Customs store (upstairs) | 3 Manueline on the quay front (round, quarries); 3 casements west; 2 casements back | front strong; west glancing; back none | if a light stands there |
| Harbourmaster's office | 1 casement in the back wall | none (faces away) | its desk candle, onto the yard behind |
| Customs hall (ground) | barred: 3 west, 3 back, 2 beside the portal (grille over glass) | west, low and glancing, where the rays find sky; under the loggia none | if a light stands there |
| Carrack's great cabin | 2 in the transom; 2 in the bulkhead onto the waist (quarries) | transom, glancing | candle and lantern: over the water astern, onto the waist |

- The customs house: _upper_front's windows take kit_glazing (round,
  quarries; the wall's strips already cut, the collider split round them);
  _side draws its wall round its openings (kit_glazing.split) instead of
  one box, its windows glazed (casements over, grilles under), its
  colliders split; the portal wall's barred windows likewise. The back
  wall's yard door is cut through too: today the wall's collider runs
  across it and the door's panel sits inside the wall's box.
- The tower's flush window stays as it is (a solid body behind it, no
  room). The loading door's dark card stays (a door, not a window: for
  later).
- The carrack: the transom's inner face and the bulkhead's faces drawn
  round their windows (kit_glazing.around), the glass_lit and glass_dark
  cards gone, the windows glazed.
- After export: `level.sh navmesh harbour` and `level.sh navmesh old_town`
  (its shared edge reads the harbour's layout; the manifest's mesh hashes
  change).

## 8. For the old town (its session, later)

kit_town keeps its own split and openings until its session adopts this.
To adopt: a `glazed` opening kind (not LIVE: the collider stays whole round
it, the glass collider in the opening; drawn through the wall's whole
thickness), drawn by kit_glazing.glazed; its houses' rooms laid (or emitted
by its register) as `room` markers. Windows.gd and the manifest need
nothing more: any district with records gets shafts and lamplight.

## 9. Testing

- **Python** (`tools/level/test_glazing.py`): the hole goes through the
  whole thickness (reveal faces on both faces); the glass is in `glazing`,
  set back as asked, the leading in front of it; the collider fills the
  opening, surface glass, excluded from occlusion; no wall collider spans
  an opening; `around` leaves the holes empty and covers the rest of the
  outline exactly; the customs and carrack pieces carry their records; the
  manifest's windows are in world space (a piece moved and turned moves
  them).
- **Godot** (`tests/windows_test.tscn`; the plan numbers its checks
  GW1-GW20: a small fixture room first, then the harbour; these are what
  they cover):
  - GW1 every record loaded; the glass bodies are in `glass`, never
    occluders.
  - GW2 the store front's three windows have moon shafts; no back-wall
    window has one; every shaft's window faces the moon (dot > 0.1) and at
    least 5 of its 9 sky rays are clear.
  - GW3 each moon shaft's far end lies on a floor or wall plane (within
    0.1 m).
  - GW4 the probe reads lit in the store's moon patch and dark a metre
    beside it.
  - GW5 a guard sees a lit player through glass; not through a wall.
  - GW6 the player walking at a window stops at the glass; a thrown loose
    thing stops too.
  - GW7 the office: its candle lit, a patch and a shaft outside; doused,
    both gone within 0.5 s; relit, back.
  - GW8 the cabin's lamps throw out astern and onto the waist.
  - GW9 a cloud over the moon dims the moon shafts to nothing at full
    cover; lightning flares them.
  - GW10 a ROOFED piece in a shaft is back on WORLD; one outside is not.
  - GW11 the room a window belongs to is the one its inside point is in.
  - GW12 a district's remembered doused lamp leaves its windows dark on
    entering.
- **By eye** (the inspect-closely rule): daylight close-ups (diag_look:
  flat sun, no fog, retro off, 1080p) of every glazed window from outside
  and inside: reveals meeting the faces, glass setback, lead, sills, the
  carrack's cuts; then night stills of every moon shaft and every lamplit
  patch; each image judged at full size and its defects listed; the hole
  scan rerun.
- **Frame rate:** the bench before and after (101.8 fps, p99 16.6 ms on
  main); all suites green (56 + windows_test).

## 10. Out of scope

Breaking glass; stained glass outside the chapel; the loading door; the
garrison's windows; kit_town's adoption (its session); reflections in the
glass beyond the sky sheen.

## 11. Risks

- **Glass in the shadow pass.** Godot leaves alpha-blended surfaces out of
  it (no depth prepass); if a still shows the glass casting, the glazing
  surfaces are split into their own MeshInstance3D at load, shadows off.
- **Shadow resolution indoors.** The moon's near split decides the patch's
  sharpness; if the bars' lattice blurs away, the shafts carry the look and
  the patch stays soft.
- **Occluders.** With the walls' colliders split, fewer big boxes occlude;
  the bench says whether it costs.
- **The harbour-job branch** also edits the harbour's markers: merge
  conflicts there are expected and small (different markers).
