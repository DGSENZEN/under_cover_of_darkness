# Card: the Zócalo arcade bay

**Status:** approved by the user, Oct 9 2026 (style lab, Task 1).

## Source: what it should look like

One bay of a merchants' arcade on the Zócalo.

- **The Portal de Mercaderes, west side of the Zócalo:**
  - **Origin:** in 1524 the city council let owners fronting the plaza build covered arcades on city land and rent them to merchants, as shelter from the plaza's floods. The arcade has held shops of luxury goods since the 16th century. ([Wikipedia: Old Portal de Mercaderes](https://en.wikipedia.org/wiki/Old_Portal_de_Mercaderes); [CDMX tourism: el Portal de los Mercaderes](https://mexicocity.cdmx.gob.mx/venues/el-portal-de-los-mercaderes/?lang=en))
  - **The present buildings** are 19th century, refaced in the 1950s in red tezontle and grey cantera in a neo-colonial style (same sources). In our world the real **1920s tezontle revival** (the Palacio Nacional's tezontle third storey, 1926-28) reached them first. (`materials_textures_ornament.md`, section 1)
- **The Mexico City façade grammar:** a "red field with pale veins" of tezontle blocks set flush in lime mortar, with every opening framed in smooth grey chiluca. ([IUGS Geoheritage: Tezontle](https://iugs-geoheritage.org/?p=11830); [Wikipedia: Tlaxcala House](https://en.wikipedia.org/wiki/Tlaxcala_House,_Mexico_City); [Commons: Tezontle](https://commons.wikimedia.org/wiki/Category:Tezontle))
- **Weathering:** black crust in the sheltered hollows of chiluca, pale streaks under cornices, salt bloom and a darker band at the base of walls. (`materials_textures_ornament.md`, sections 1 and 7)

## Change: what the world did to it

- **One column is not stone.** In this bay the left column was replaced by a **riveted steel column** from another decade's engineering: an I-section with flanges and rivet rows, its capital an iron bracket under the arch. It is fixed to the old stone with a **brass patch plate** (the same patches as the kiosk; the Company did this too). It is the arcade's quiet anachronism.
- **The upper floor's balcony iron** is replaced by **tube rails**: plain round steel tubing with welded joints, from a future that liked tubes.
- **Everything else is the real grammar:** tezontle field, chiluca frames and cornice, lime-washed arcade ceiling on wooden beams, a shop door at the back of the arcade.
- **Sinking is not in the piece.** A leaning row is made by placement in a district, not by the kit, so bays still tile.

## Pieces (Blender object names)

| Object | What it is |
|---|---|
| `bay_column_stone` | A Tuscan chiluca column centred on the bay's left edge, 0.5 m across, base and capital included |
| `bay_column_steel` | The seeped steel column in the same place, with its patch plate. The glb carries both columns; the map shows one per bay |
| `bay_end_column` | The closing column for the right end of a run (not part of a bay; exported in the same file) |
| `bay_arch` | The semicircular arch: chiluca voussoirs and keystone |
| `bay_spandrels` | The tezontle wall between the arch and the cornice |
| `bay_cornice` | The chiluca string course over the arcade |
| `bay_upper_wall` | The upper storey's tezontle field |
| `bay_window` | The balcony window: chiluca frame, wooden shutter leaves |
| `bay_balcony` | The chiluca balcony slab |
| `bay_rails` | The tube rails |
| `bay_parapet` | The parapet with chiluca coping |
| `bay_back_wall` | The shop front at the back of the arcade: lime-washed wall, chiluca door frame |
| `bay_door` | The shop's wooden door |
| `bay_ceiling` | The arcade ceiling: lime plaster between wooden beams |
| `bay_floor` | The arcade floor: cement tile |

## Dimensions (metres)

- **Bay:** 4.5 wide (x), the column centred on x = 0. Depth under the arcade is 4.0, from the column line back to the back wall's face.
- **Arch:** column 0.5 across, so the clear span is 4.0 and the radius 2.0. The spring is at 3.25 and the crown at 5.25.
- **Ground storey:** cornice band 5.5-6.0, floor at 0. The arcade floor sits 0.25 above the street, and the column bases sit on it.
- **Upper storey:** 6.0-9.0, with a window 1.25 wide × 2.25 high, centred on the bay, its sill on the balcony at 6.0. The balcony projects 0.5, and the rails are 1.0 high.
- **Parapet:** 9.0-9.75.
- **Origin:** the column's centre at the arcade floor's front edge, at street level. Bays tile at 4.5 along +x.
- **Grid:** 0.25 m for outer bounds and joints. The arch curve is 12 segments.
- **Budget:** at most 2,500 triangles for the bay with one column. The steel column alone is at most 400.

## Slots: material regions, with the Zócalo palette colours they lean toward

| Slot | Material | Palette |
|---|---|---|
| `tezontle` | Oxblood scoria in pale lime mortar | `#3d1f1c`, `#6e2f26`, `#9a4a3a` |
| `chiluca` | Grey stone frames, arch, cornice, column | `#5a5560`, `#8a8790`, `#b9b4b0` |
| `lime` | Lime-washed back wall and ceiling | `#b9b4b0`, `#e8d8a8` |
| `steel` | The seeped column and rails | `#3a3340`, `#5a5560` |
| `iron` | The steel column's bracket capital | `#2a3b2e` |
| `brass` | The patch plate | `#7a5a24`, `#c49a40` |
| `wood_door` | The door, shutters and beams | `#3d1f1c`, `#7a5a24` |
| `tile_floor` | Matte cement tile | `#5a5560`, `#7a5a24`, `#b9b4b0` |

## Joints the joint renders must frame

1. Column base to floor
2. Capital to arch springer (stone and steel)
3. Voussoirs to spandrel
4. Keystone
5. Arch to cornice
6. Cornice to upper wall
7. Window frame to wall
8. Balcony slab to wall
9. Rails to slab
10. Parapet coping
11. Ceiling beams to the arch wall and the back wall
12. Back wall to floor
13. Door to its frame
14. Patch plate on the steel column
15. **The bay-to-bay seam** (two bays placed 4.5 apart)

## No canvas on this piece

There is no sign surface. Shop signs (rótulos) will be their own family later, painted by the user.
