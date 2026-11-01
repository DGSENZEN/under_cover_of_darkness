# Fight moves as they stood (2026-11-01, before the hunts work)

Measured by `tests/diag_fight_moves.tscn` with the real player and real input, on flat ground, revolver drawn unless it says otherwise.

| Move | Measured | What it means for the player |
|---|---|---|
| Strafe start | 0.267 s to 90 % of walk (6.5 m/s) | A sidestep takes about a quarter second to get going: slow for answering a swoop |
| Strafe stop | 0.150 s to under 0.2 m/s | Fine |
| Strafe reverse | 0.367 s from held left to 90 % held right | Slow to change direction |
| Strafe + sprint | 8.50 m/s sideways, gun ready 11 of 90 ticks | **Sprint works in every direction, and it lowers the gun.** Holding Shift in a fight means you mostly can't shoot |
| Aim strafe | 4.55 m/s sideways | Fine |
| Fire while strafing | 6 shots in 6 s (the whole cylinder) | Fine at a walk |
| Gun lateral swing | 0.0007 m peak to peak over 2 s | The gun is steady in the hand while strafing |
| Shot cadence | 0.633 s at the hip, 0.367 s aimed | Each shot already carries weight |
| Full reload | 3.300 s, empty to 6 | Already a commitment |
| Q tap, gun drawn | 4.00 m, 20 power | Blink's step: the only evasion with the gun, and it spends spell power |
| Q tap, sword drawn | 1.25 m in 0.300 s | **The dodge barely moves you.** At 7.5 m/s it is hardly above the walk's 6.5 |

## Still open

- There is no slide (Task 4), and no free dodge with the gun (Task 3).
- `walk_speed` is 6.5 m/s. That is quick for something meant to feel heavy, and it is a lever for the user's verdict (Task 14), not changed here since every level is built around it.
