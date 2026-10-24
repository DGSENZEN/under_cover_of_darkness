# Empower effects, round two — design

After the Ward the user said: "The Ward works. Do Empower next the same way: reading the tome, the charge in the arm, and spending it. Then show me stills and a clip."

Empower is a tome spell of the nahual, the shapeshifter's beast strength. It follows the Shard, Blink and Ward notes. Its colours are umber and bone (never marigold, the dead's). Lines marked *(Claude's call)* fill in what the request left open.

## Unchanged

- What it does: read for 1.2 s; one charge waits up to 8 s; spent on a blow (kick or whip), a shot, a jump or a blink.
- Its cost, and the Empower wave where it is spent.

## Reading the tome

- **The words on the pages:** the tome's pages carry lines of the invented script (the Ward's written circle, `LibraryGlyphs`). They catch light in bone and umber, line by line, as the pages turn.
- **The words leave the page:** as each line lights, its glyphs lift off and fly to your gun hand, shrinking into it. The words go into the arm; that is the charge's cause, seen.
- **A low growl** rises under the reading *(Claude's call: the "roar" sound, low and slow)*.

## The charge in the arm

All on the gun hand, the arm always in view.

- **The skin darkens:** the hand's skin goes dusky umber.
- **Fur:** dark fur stands out of it, in a few shells of strands, on the skin only, coming out of the cuff. It replaces the faint pelt-shadow overlay, which was invisible on the arm and lay over the sleeve too.
- **Veins:** bone-white veins glow in the darkened skin and pulse with the heartbeat (the beast pulse's 70 a minute).
- **The hand twitches** with each beat, a small kick of strength.
- **The beast pulse** at the edges of the view stays.

## Spending it

- **Out of the hand:** the fur bristles out and the veins flash, then the hand goes back to itself over 0.3 s.
- **A blow (kick or whip):** three claw rakes, bone-white curved streaks, tear across where it landed, in the line of the blow, the nahual's claws behind it. A short hit-stop gives it weight.
- **A shot:** three claw rakes fly out along the shot from the muzzle. No wave ring there *(Claude's call after the first stills: at the muzzle, right before your eyes, it filled the view)*.
- **A jump or a blink:** the wave at the feet, as now, with dust thrown up.
- **The roar and the camera shake** stay.

## Effects off

- Not made: the flying words, the claws, the dust.
- Kept: the tome's written pages (part of the book) and the hand's change (part of the arms), as the circle and the old pelt were.

## Checks

A new headless suite, `tests/empower_fx_test`, covers:
- the written pages lighting line by line;
- words flying from the tome to the gun hand, and gone;
- the fur, darkening and veins on the skin only while charged, and gone after;
- the veins pulsing with the beat, and the hand's twitch;
- claws on a kick and on a shot;
- nothing with effects off, and everything gone afterwards.

The old pelt checks in caster_test carry over to the new hand (same `pelt_amount`).
