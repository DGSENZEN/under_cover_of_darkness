# The Zócalo's scenes: a district that feels alive

Date: 2026-10-10. Branch: eclipse-city. Follows the street-life plan
(docs/superpowers/plans/2026-10-10-zocalo-street-life.md, Tasks 1-7 built);
replaces how its life is laid, keeps its kits.

## Why

The street-life dresser laid life by spacing rules: a cart every 6 m on
alternating sides of 1.9 km of market lanes (312 carts), shoeshine stands every
9 m, candles and traps by seeded scatter. The user: "we want to add details that
make sense, we don't want carts everywhere, instead we want actual curiosities
happening, or at least placeholders as we keep working on it. There are trees,
there are opportunities to also add VFX ... we just need to have things to make
it feel *alive*."

Their answers: **staged + ambient** (scenes are moments that read at a glance
plus motion that needs no NPCs; real people and timed events come with the NPC
pass) and **posed mannequins** as stand-ins.

Success: a walk across the Zócalo by day and by night meets something happening
every few dozen metres where people would gather, and quiet street between; every
thing seen has a reason to be where it is (world built by its events); nothing
reads as one piece repeated by a rule.

## What stays on rules, what becomes scenes

**Stays** (the real city had these by rule): tram poles, span and trolley wires,
traffic lights, ward plates and sigil discs on poles, guard stones and cannons,
Talavera plaques and 1921 plates at corners, Company bollards at drops and plaza
corners, chain posts on canal copings, poster columns and poster clusters on
walls, ward hoardings at dark side-street ends, the Bound God, its offerings
heap and its eight ward-cage lamps, sealed hatches, claw-scored slabs under dead
lamps.

**Becomes scenes** (removed from dress_life's rules, placed only inside a
scene): carts, kiosks, shoeshine stands, curiosity stands, the monster wagon,
luchador shrines, photographers' booths, relic crates, candle drifts, marigold
petals, cage traps, payphones and the Line of the Dead booths, testimony booths,
notice boards, the seeped future's small objects (meters, bus-stop signs, dead
traffic lights stay on poles), surfacing idols' barriers and copal.

## The scene system

`tools/level/dress_scenes.py`, called from `dress()` after the rules.

**A recipe** is data: `name`, `sites` (the site kinds it accepts), `when` (day,
night, both), `zone_weight`, `spacing` (no same recipe within, default 80 m),
`story` (one line), and its parts in the scene's own frame (front = +Z, toward
the street): pieces `(piece, offset, turn)`, figures `(pose, offset, turn,
role)`, emitters `(effect, offset)`. A landmark recipe names one fixed site.

**The site finder** lists real places from the plan and the rules' dressing,
each with a position, a facing and its reason: tram stops (`tram_stop` landmarks
and the overhead pass's stops), Metro mouths (`metro_entrance`), the god's ring,
the market hall doors, canal landings, church steps (cathedral, sagrario, Santo
Domingo), arcades (Portales, evangelistas), side-street mouths, plot doors, wall
feet, corners, dark spots (no lit lamp within 20 m), subsidence ≥ 0.6, sealed
hatches, claw-scored slabs.

**The director** places landmark recipes first, then fills each zone to its
density:

| Zone | One scene per |
|---|---|
| Plaza edge and god's ring | 25 m |
| Market hall and its four nearest stall blocks | 25 m |
| Madero, the Portales, Santo Domingo | 40 m |
| Side streets | 60 m |
| Market lanes beyond 90 m from the hall | none (empty street) |

Different scenes stand at least 15 m apart outside the plaza and the hall. A
scene that does not fit its site whole (any clash, plot, sunken place, the
gate) is not placed at all: never half a scene. Seeded and deterministic.

**The record**: `dressing.json` gains `scenes` (name, site, reason, at, yaw,
when, story) and `stations` (one per figure: role, pose, at, yaw, scene, when)
for the NPC pass. An F1 overlay in `maps/zocalo.gd` labels each scene with its
name and story.

## The scenes

Figures in brackets; "both" means the scene stands by day and by night unless a
night variant is named.

**Landmarks (one each, at their place)**

| Scene | Where | When | What is happening | Effects |
|---|---|---|---|---|
| god_devotion | god's ring, offerings side | both | 6-10 devotees kneeling, a warden of El Secreto swinging a censer; El Secreto made the god the Patron and the faithful keep it fed | copal smoke, petals, candles |
| god_press | god's ring, south | day | a press photographer on a crate, two reporters pointing, a gendarme; the papers never tire of it | |
| preacher | god's ring edge | day | a priest on a crate (the Calles Law silenced the churches, so he preaches outside), 5 listeners, a heckler pointing | |
| evangelistas | Santo Domingo's arcade | day | 6-8 desks with typewriters, scribes typing, clients dictating, a queue; the real letter-writers of Santo Domingo | |
| monster_wagon | market, nearest the hall | both | the wagon, its barker on a crate, a ring of 8-12 onlookers, a child held up; the ahuízotl came back with the canal | steam (a nearby atole pot) |
| market_hall | the hall's doors | day; night variant | packed stalls nose to tail, porters with baskets, shoppers, dogs; at night the carts covered and chained, a watchman asleep on a stool | steam |
| flower_row | the lane before the hall | day | 4-6 flower carts together, sellers, marigold heaps | petals |
| firewood_landing | a canal landing | day | firewood stacked on the landing, porters carrying bundles up the stair | |

**Scenes the director places (as many as fit their zones)**

| Scene | Sites | When | What is happening | Effects |
|---|---|---|---|---|
| tamale_stop | tram stops, Metro mouths | both | a tamale cart, its seller, a queue of 2-4, a dog waiting | steam |
| atole_corner | corners | night | an atole pot on a brazier, 2-3 drinking | steam, embers |
| newsboy | Metro mouths, tram stops | day | a news kiosk, a newsboy pointing, a reader | |
| shoeshine | arcades | day | a shoeshine stand, the bolero crouched, a customer reading (blank paper) | |
| organillero | plaza edge, Madero | day | a barrel organ, the organ grinder, a collector with a hat, 3 listeners | |
| pajarito_suerte | plaza edge, Madero | day | a seated fortune-teller, a canary's cage and card box, a client | |
| curandera_limpia | side-street mouths, market | both | a curandera sweeping a client with an egg and herbs, one waiting | copal smoke |
| line_of_the_dead | plaza corners, Santo Domingo | both; night séance | a seeped payphone booth, a queue holding candles, one listening at the receiver; at night a medium seated at it, mourners round | phosphor mist, candles |
| testimony | Santo Domingo, Inquisition door | day | the testimony booth, a queue, a clerk of El Secreto, relic crates sealed | |
| wake | plot doors in side streets | night | a coffin on two chairs on the pavement, candles, 4-6 mourners, a dog lying | candles, petals |
| rail_accident | the tram loop off the plaza | day | an overturned fruit cart, spilled crates, a chalk ring, a gendarme writing, onlookers | |
| brazier_watch | dark spots | night | a brazier, 3-4 men warming their hands | smoke, embers |
| warden_inspection | claw-scored slabs | night | a warden crouched with a lantern over the scores, another holding his lantern up | |
| idol_surfacing | subsidence ≥ 0.6 | day; night variant | the barrier, a sketch artist seated, a gendarme, 4-6 gawkers; at night one warden with a lantern | copal smoke |
| hatch_watch | sealed hatches | night; day variant | two wardens with lanterns, one crouched at the chains; by day a chalk ward ring and a dog sniffing | |
| cage_trap | dark corners | night; day variant | a cage trap with its chaneque, the trapper crouched, a lantern; by day the trap and a child peering | |
| pulque_delivery | plot doors in side streets | day | barrels at a door, a man rolling one, a drunk asleep against the wall | |
| curiosities | market, plaza edge | day | a curiosity stand, its seller, 2 browsers | |
| luchador_shrine | market corners | both | the shrine, 2 kneeling | candles |
| spirit_photographer | plaza edge | day | the booth, the photographer stooped at his camera, a sitter | |
| lottery | busy sites | day | a lottery kiosk, its seller holding sheets, a buyer | |
| laundry | side streets | day | lines strung wall to wall over the street, a woman with a basket | laundry sways |
| street_dogs | wall feet, quiet stretches | both | 2-3 dogs lying and sniffing | |

## Trees and the garden

The Zócalo was a planted garden from the 1860s to 1958. The plaza's four
quarters round the god's ring become the garden: gravel paths from the Metro
corners to the ring, iron edging, benches, and trees in iron guards.

| Tree | Where |
|---|---|
| Ash (fresno) | the plaza garden, a few side streets |
| Canary palm | lining the garden's paths (a Porfirian taste) |
| Laurel de la India | shading the market hall doors |
| Weeping willow | along the canal |
| Ahuehuete | one, ancient, by the dig: split and half dead where the ground sank under the surfacing idol, hung with ex-votos by the devoted |

Trunks are closed meshes; canopies are clumps of closed low-poly shells with a
self-painted leaf atlas (alpha cut-out). Canopies sway in a wind shader. About
150 trees. Trees and their guards collide.

## Effects (ambient)

All sprites drawn by us (never downloaded). Existing: flame (candle, small,
brazier), smoke, soot. New: steam, copal, ember, petal, leaf, mist.

- Steam off tamale and atole pots; brazier smoke and embers; thick white copal
  smoke at the god and the limpias; candle flames at the queues and the wakes.
- Phosphor-green mist (`#7FD36A`) creeping low from the seeped booths.
- Marigold petals drifting round the god and the wakes; leaves falling from the
  trees; dust motes in lamplight.
- Pigeons pecking on the plaza that lift and resettle when the player comes
  within 4 m (the one reactive touch).
- Laundry and awnings swaying; a few lamps stuttering; low fog on the canal at
  night.

Only emitters within about 60 m of the player run.

## The stand-ins (figures kit)

`tools/eclipse/figures_kit.py`: faceless clay-grey mannequins, about 1.7 m,
about 300 triangles each, closed shells per limb. Poses: stand, queue (hands
clasped), walk, kneel_pray, sit_kerb, sit_chair, lean_wall, push_cart,
carry_basket, point, crouch_inspect, hold_lantern, type (at a desk), dictate,
barker (arm raised), photographer (stooped), mourner (head bowed), child,
child_held (a pair), sleep_wall. Dogs: dog_sit, dog_lie, dog_sniff. One collider
per figure (a person blocks you). Plain clay grey so they never read as
finished art.

## Scene props (scene kit)

`tools/eclipse/scene_kit.py`: barrel organ, typewriter desk and stool, coffin
and two chairs, brazier, comal and clay pots, baskets, stools and crates, the
canary's cage and card box, censer, lanterns (carried and set down), chalk ring
(flush), overturned fruit cart and spilled crates, pulque barrels, a covered
cart, laundry line and cloths, ex-votos (blank picture slots), the reporters'
crate, the garden's benches, iron edging and tree guards.

Every word, picture or glyph surface is a blank `sign` slot for the user.

## Day and night

Each scene's `when` is switched by `set_day` with the lamps (KitLoader
`set_lights`): the day scenes and their stations hide at night and the night
scenes show, and back.

## Budgets

- Figures about 600-900, drawn as one MultiMesh per pose per 100 m cell.
- Trees about 150; emitters about 200, at most about 40 running.
- Dressed frame rate within 10% of the street-life dressing's dressed number on
  the same machine and camera (`--fps-report=40`).

## Testing

Python (`tools/level/test_dress_scenes.py`): every scene stands at a site its
recipe accepts and records its reason; no recipe repeats within its spacing;
each zone's count meets its density and the far lane ends hold no scene; no
clashes, the district gate clean; every figure writes a station; every recipe in
this spec is placed at least once; day and night variants never stand together;
the removed rule pieces are gone from the rules' output.

Godot (`tests/zocalo_test.gd`): the player cannot walk through a queue; set_day
swaps day and night scenes; pigeons lift when approached; emitters run only near
the player; the scenes' F1 labels exist.

Kits: closed solid meshes, the 3 cm layered and 1 cm sliver gates, no shared
texels, walk-tested, stills sent per kit.

## Order

1. Figures kit (stills).
2. Trees and the garden (stills).
3. Scene kit (stills).
4. Effect sprites and emitters (stills).
5. Site finder, director, recipes; the life rules removed.
6. Godot: figures and stations, day/night scenes, emitters, pigeons, wind sway,
   the F1 overlay.
7. The street-life plan's held Task 8 (district stills day and night, load and
   fps reports) over the scenes, then the final review of the whole street-life
   and scenes branch.

## Rules carried

Public repo: only CC0 or self-made textures. No downloaded VFX. The user writes
all words and paints glyphs. Never call a visual defect harmless. Commit per
task, never push.

## Open calls for the user

The blank surfaces (ex-votos, the canary's cards, typed letters, newspapers);
the mannequins' clay grey until NPCs replace them; the Bound God still a
placeholder.
