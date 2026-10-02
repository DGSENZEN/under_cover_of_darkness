# Movement stress gym

Open `res://maps/traversal_gym.tscn` and run the current scene (F6 in the Godot editor), or launch:

```sh
Godot --path . res://maps/traversal_gym.tscn
```

The 16 stations have separate geometry, three ordered colored gates and quick restarts. Walk through green START, amber CHECK and blue FINISH in order. The HUD records game-time elapsed, best time for the current physics/slow-motion preset, attempts, hard landings, speed, height, current traversal and the last planner rejection. Records last for the current session. Routes are practice guides: they do not enforce how an obstacle is crossed.

| Control | Action |
| --- | --- |
| 1–9 | Select stations 1–9 |
| [ / ] | Previous / next station, including 10–16 |
| R or 0 | Restart the selected station |
| F4 | Cycle 30 / 60 / 120 physics ticks per second; restart |
| F5 | Toggle traversal probe display |
| F6 | Select the combat/stealth relay and toggle its guard |
| F8 | Toggle damage; restart. Damage is off by default. |
| F9 | Toggle half-speed practice; restart |
| F10 | Existing legacy movement feel comparison |
| Esc | Existing pause menu |

Movement/combat controls stay the same: WASD, sprint, jump, crouch, mouse look, attacks/block, Q dodge and F kick. At a ledge, strafe shimmies, jump pulls up or leaps toward the aimed ledge, and crouch drops. Fresh jump/crouch during a catch is honored when the hands settle.

| Station | Stress case |
| --- | --- |
| 01 Steps & stairs | Different step heights, risers and descending foot placement |
| 02 Mantles | Low obstacles through jump catches, crouched clearance |
| 03 Vault flow | Thin rails, successive vaults and mantle-to-vault transitions |
| 04 Hang & leap | Separated ledges, inside/outside corners and opposing faces |
| 05 Kick & upward leap | Wall kicks, upward transfers and pull-ups |
| 06 Progressive gaps | Ordinary, assisted and deliberately unreachable gaps |
| 07 Ladder, rope & chain | Attach, climb, swing, release and ledge exits |
| 08 Facade | Offset ledges, higher leaps and targeted drops |
| 09 Thin lips & seams | 10 cm lips, rising/falling seams, depth changes and stacked shelves |
| 10 Corners & angled faces | Inside/outside corners and 30°/45° face changes |
| 11 Crouched clearance | 1.25 m headroom; a lower red slot deliberately rejects traversal |
| 12 Moving obstruction | Blockers cross mantle destinations and hanging routes |
| 13 Slopes & momentum | 15°/30° ramps, downhill stairs and landings |
| 14 Water & landings | Deep-water entry, swimming, bank mantles, wet quay steps on the left, a boat rail/floor on the right, and 3/6/9 m drops |
| 15 Vertical relay | Ladder, thin shelf, higher roof and rope sequence |
| 16 Combat / stealth relay | Vaulting under pressure, cover, noisy metal, quiet carpet and an optional guard |

Restart restores health/stamina, clears combat opportunities and unfinished traversal, releases held props, resets moving blockers to the same phase and replaces the relay encounter, including corpses and dropped gear. Death automatically restarts. Physics/time settings restore when leaving the gym. The guard uses a navigation bake restricted to its station.

To reproduce a movement problem, note the station, physics setting, planner rejection and last state transition. Try the same action at 30/60/120 Hz and repeat with F9 to inspect the transition. Timing runs use simulation time; compare records within the same preset. The 6.5 m gap and too-low red ceiling intentionally exercise safe failure.

Headless regressions:

```sh
GODOT=/path/to/Godot bash tools/run_suites.sh tests/movement_gym_test.tscn tests/water_geometry_test.tscn tests/swim_polish_test.tscn tests/ledge_polish_test.tscn tests/combat_polish_test.tscn tests/stealth_polish_test.tscn
```

Rendered inspection:

```sh
Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_movement_gym.tscn -- --out=/tmp/movement-gym-shots
```
