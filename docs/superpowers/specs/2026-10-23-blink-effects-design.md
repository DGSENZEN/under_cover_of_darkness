# Blink effects, round two — design

After the Shard's redo the user said: "The Shard works. Do Blink next the same way: wind-up, rush, crack where I stood, arrival. Then show me stills and a clip." It follows the three-beat method of `2026-10-23-shard-effects-design.md` and keeps its look: obsidian, cold glint `#E6EEF5`, our own meshes and shaders, no figures. Lines marked *(Claude's call)* fill in what the request left open.

## Unchanged

- Blink is still an instant step: a tap steps, holding aims, letting go goes there.
- The reach, the ledge catch, the cost, the dodge credit and the Empower wave are the same. Only what you see and feel changes.
- The rush plays as a burst on arrival, not as travel time *(Claude's call: a delay would make Blink a worse dodge)*.

## Wind-up (holding Q to aim)

- **The landing mark:** a ring of eight black-glass flakes hovers where you will land, turning slowly and glinting, with a thin cold ring on the ground under it *(Claude's call after the first stills: the flakes alone were dots at 10 m)*. It replaces the old spray of glints. It follows the aim, onto a ledge too, and is gone when you let go or cancel.
- **The hand:** with the gun out and the left hand free, the left hand reaches out toward the mark.
- **A tap** has no wind-up: it goes at once.

## Rush (the moment you go)

- **The view stretches:** the field of view widens for an instant and springs back. The picture smears in toward the middle (a zoom blur) over about 0.15 s.
- **Flakes whip past you:** glass flakes stream from ahead of you to behind you in that moment.
- **The cold flash** at the edges of the view stays, lighter (alpha 0.55 → 0.25) *(Claude's call after the first night stills: under the smear it fogged the view)*.

## The crack where you stood

- **What hangs there:** a pane of cracked glass, the height of a man, turned toward where you went. Jagged facets bend the world each a little differently, like a broken mirror, and a cold line runs along every crack.
- **How it goes:** it hangs about 0.25 s, then falls apart, the facets dropping and turning away to nothing over 0.5 s.
- **A limit:** at most two cracks at once; a third takes the place of the oldest *(Claude's call)*.

## Arrival

- **What's added:** the ripple you arrive in stays. Dust is kicked out in a ring across the floor at your feet.
- **In the air:** with no floor under you, there's only the ripple.

## Housekeeping found on the way *(Claude's call)*

- The magic-view layer moves from canvas layer 9 to 3, as the review's minor 9 asked. The smear must not smear the HUD or the pause screen, and the pixel grid should cover it.
- The magic-view layer is hidden when nothing shows (review minor 8).

## Checks

A new headless suite, `tests/blink_fx_test`, covers:
- the mark: its eight flakes, following the aim, gone on release, none on a tap;
- the hand reaching;
- the view widening and coming back, the smear rising and falling, the flakes streaming past;
- the crack: its facets at the place you left, upright, hanging and then falling, gone in time, and the two-crack limit;
- the dust ring on the floor;
- nothing made with effects off, and everything gone afterwards.

The old mirror-shard checks in caster_test move over to the crack. Stills and clips go to the user, lit and dark.
