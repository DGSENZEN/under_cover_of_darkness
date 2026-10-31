# The Zócalo station: platforms, track and ticket hall — design

Oct 27 2026. Build 1 of the user's three for the Metro itself, in this order, each with its own design and plan:

1. **The station** (this document): the platforms, the track, the stairs and the ticket hall, built and dressed, its
   crowd of shades.
2. **The orange car and the trains**: the car, a hero model built with the user in live Blender; trains on a
   timetable pulling in, stopping, trading crowds of shades at their doors, pulling out.
3. **Boarding and the ride**: step on, the doors close, the ride runs (the frame spec's vaults, temple shells, the
   void and its ghost stations; `docs/superpowers/specs/2026-10-09-eclipse-city-frame-design.md` §5.3) while the
   player walks the car; the route board's district levers stay dark (Lomas, Roma and Condesa are not greyboxed
   yet); the doors open back at Zócalo, on the other platform.

The user, Oct 27: the station is **"an active one, crowded, working, should feel alive"**; "we need to have things in
the main stage and foundation set and done before we move onto the other sections". On the big pieces: **"let's work
on the big kahuna models together, mostly so the details are proper and work well."**

## Intent

You arrive in the Metro on its north platform (the plan's `arrival`, x 0, z −9, floor −14), and today it is grey
blocks. The station is the Metro's first real place and its hub: the platforms where the trains will stop, the hall
above them where the Pasaje, the corridors and the exits meet. It should read as a working station of the CDMX Metro
dropped into the colonial tunnels by the Eclipse (the frame spec §5.1: nobody built it; the Light Company runs it and
its 1920s staff patch it with brass and wood), full of shades going about their day.

## Goals

1. **The shell**, built to the Metro's standard (`docs/superpowers/specs/2026-10-16-metro-underground-design.md` §4:
   past PS2 limits, no pixel grid, shape first, layered painted textures) and set into the Metro in place of the
   greybox of `hall`, `stairs_n`, `stairs_s`, `platform_n`, `platform_s`, `track` and the `siding`'s mouth:
   - **the ticket hall** (plan x −30…30, z −14…14, floor −8, 5 m high): tiled walls, its ceiling and its columns, the
     openings to `corridor_w`, `corridor_e`, the market stairs (to the Pasaje) and the two platform stairs, each the
     size the greybox gives them;
   - **the stairs** `stairs_n` and `stairs_s` (each 8 × 16 m, floor −14 to −8), as their greybox switches back;
   - **the platforms** (each 100 × 7 m, floor −14, 5.5 m high): tile walls under mosaic name tablets, the yellow edge
     line, the ceiling and its light;
   - **the track** (100 × 14 m between the platforms, its bed at −15.2): two tracks laid for the MP-68's rubber
     tyres (concrete running pads, guide bars, steel safety rails, the third rail's guard boards); a dark tunnel mouth
     for each track at both ends; at the east end, between the two, the walkers' way on to the temple tunnel kept
     open (the plan's `track_steps_n` at x 46, its steps kept); and at the west end the siding's mouth, a service
     tunnel of its own.
2. **The scenes**, each with a cause in the world (the user approved this list Oct 27):
   - *the hall:* the taquillas (ticket windows behind brass bars) with queues of shades, one of them the plan's
     `ticket_booth`, its seller a shade; the turnstile bank, half of it broken and patched in the Light Company's wood,
     its broken half fused open (the plan's `jammed_turnstiles`): the free lane everyone pushes through; under glass, the city's model of Tenochtitlan (as the real
     Zócalo station keeps one), the hall's landmark; a shrine to the Virgin in a tiled niche with candles and
     milagros; a shoeshine stand and a lottery seller by the stairs' heads; the hanging direction signs and a line
     map;
   - *the platforms:* the Light Company's wooden benches; a tamale and coffee vendor at each stairs' foot; a driver's
     relief cabin at the far end; at the west end, where the siding runs off, the tile cracked open onto a colonial
     vault, the seepage showing through and running down onto the track (the plan's `seeping_track`, the same
     cause), ward candles at its foot;
   - *the track:* the pits, the rails, the tunnel mouths.
3. **The crowd of shades**, the station alive (ShadeCrowd / Silhouette, the city cast the user approved for the
   Pasaje): waiting along the platform edges and thickest at the stairs' feet; streams up and down the stairs and
   through the turnstiles; queues at the taquillas; the vendors and the shoeshine man at work. Numbers to the
   Pasaje's density, inside the frame budget.
4. **Its light**: the station's own fittings (long fluorescent strips in the 1969 manner, with the Light Company's
   brass lamps where it has patched), under the frame budget below.
5. **Ready for the trains** (build 2): the platform edges, the track gauge and the clearances made for an MP-68 car
   at the platform (about 2.5 m wide, 3.6 m tall over its running pads), its doors along the edge.

## Non-goals

- No trains, no car, no boarding, no ride (builds 2 and 3).
- No other districts, no route board.
- The taquillas and turnstiles are dressing: nothing is bought, nothing stops you (a ticket may come with the ride,
  build 3).
- The cracked vault is looked into, not entered: lit within, no way down to the old layer yet.
- The corridors either side of the Pasaje (`pasaje_n`, `pasaje_s`) stay greybox: the astral passages there were
  shelved by the user Oct 30 (saved on the branch `astral-passages`).
- The corridors (`corridor_w`, `corridor_e` and beyond), the exits and the kiosks stay greybox; only their openings
  into the hall are finished.
- **No new sounds.** The user judged every stand-in Metro sound bad and is sourcing recordings; the station keeps the
  Metro's existing mix until those come. Nothing is presented as finished sound.
- No words: every sign face, tablet, line map and poster is the user's to write. Until then they are blank, or in the
  invented script (library_glyphs) as a stand-in.

## Anti-goals (failures even if it works)

- Props sprinkled at even spacing ("scenes, not sprinkles"): every object stands where a cause puts it.
- Modelled human figures: the people are shades.
- Faces in one plane (z-fighting), layered quads, stretched stand-in textures, anything juddering (the M20 rule: no
  interpolated visual moved in `_process`).
- A copy of the real station: inspired by the CDMX Metro, not a replica (the reference, not imitate rule).

## How it is made (the user's pick, Oct 27)

- **The shell from code** (Claude), as the Pasaje's was: kit scripts under `tools/eclipse/` built by
  `tools/eclipse/lab.sh`, checked by the kit gate (`tools/eclipse/test_kit_bpy.py`: closed solid meshes, no layered
  faces within 3 cm, budgets), painted through the layered atlas (`tools/textures/layered_atlas.py`), placed by a set
  scene `maps/station.gd` that `maps/metro.gd` sets in through `SETS` (taking the greybox spaces listed above), as it
  does the Pasaje and the candle lane. Judged by the user from in-game stills.
- **The big pieces with the user, one at a time, in the live Blender session** (the Blender MCP connection), shown in
  renders as each grows; the user may open the same file and push vertices; their edits come back through the
  workshop round trip (`tools/level/level.sh workshop` / `yours.json`). The next piece starts only when the user
  signs one off. The order:
  1. the taquillas;
  2. the turnstile bank;
  3. the model of Tenochtitlan under its glass;
  4. the Virgin's shrine;
  5. the Light Company's benches;
  6. the driver's relief cabin;
  7. the cracked colonial vault at the west end;
  8. the vendors' stands (tamales and coffee, shoeshine, lottery).
- Approaches considered: the big pieces first and the shell after (rejected: their proportions hang on the room's
  ceiling, widths and light); everything by hand in Blender with the user (rejected: spends the user's time on tile
  walls code builds as well, where repetition is code's strength).
- Textures: the shell starts on the tile the Pasaje already uses. When a surface needs a texture the kit's sheets
  cannot give well (the mosaic name tablets first; the Tenochtitlan model's paint), Claude asks the user for it when
  that piece is reached, rather than stretching a stand-in.

## Constraints

- The standing rules: the user writes all words; no textures.com files in the public repo; review media under
  `docs/superpowers/refs/` is not committed; no free VFX assets; never merge or push without the user's word; never
  call a visual defect harmless; show in-game stills of the real Metro, never a staged backdrop.
- The player capsule is a metre wide: every passage the crowd and the player use is 1.1 m clear at the least,
  reachable from the spawn.
- Frame budget: the station's frames, drawn, no more than 1.25 times the candle lane's (the `library_render_check`
  measure the Pasaje and the astral passages use).
- Headless suites stay green (metro_test, pasaje_test, candle_lane_test) and the Metro's seams stay level.

## Testing

- `tests/metro_test.gd` gains the station's checks: the set in its place with the greybox gone from its spaces only;
  walked from the arrival up the north stairs, across the hall, down to the south platform, and out of the hall to
  the market stairs, the corridors' mouths; the seams level; everything it shows inside its spaces; its crowd's
  routes inside them; no juddering (M20 covers it).
- A windowed view test (`tests/station_view_test.tscn`) for what reads from the arrival and the hall, as the Pasaje's
  does.
- The kit gate for each new kit; the frame measure.
- Stills of every scene for the user, through the player camera's field of view.

## Left to the builder

- The kits' exact split, the tile and column modules, the ceiling's construction, the fluorescent fittings' design.
- The crowd's numbers and routes within the density and budget above.
- The scenes' exact placing, within their causes.

## Claude's calls (for the user to check)

The builder's read of this design asked five things; these are Claude's answers, each the user's to overturn:

1. **The plan's landmarks fold in:** the jammed turnstiles are the bank's broken half, fused open; the seeping track
   is the cracked vault's seepage reaching the rails; the ticket booth is one of the taquillas, its seller a shade.
2. **The track's ends:** a tunnel mouth per track at both ends; the east centre opening stays the walkers' way to the
   temple tunnel; the siding a service tunnel of its own at the west.
3. **Ticketing is dressing for now** (the ride, build 3, may bring a ticket).
4. **The vault is a look-in**, no way down yet.
5. **Textures:** the Pasaje's tile for the shell; the user asked only for the mosaic tablets, when they are reached.
