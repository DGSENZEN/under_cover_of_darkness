# Sounds the hunts need

Stand-ins from the existing library until the user chooses real ones.

| Sound | Where | Today |
|---|---|---|
| A weak hit: the right answer landing | `Revolver.SOUNDS hit_weak` | `ting` high |
| A resisted hit: it barely told | `Revolver.SOUNDS hit_resisted` | `thud` low, quiet |
| The eye's tell | `FloatingEye.gd` | None yet |
| The eye's swoop, bite | `FloatingEye.gd` | `whoosh_light`, `thud` |
| The eye bursting (the wet pop) | `FloatingEye._die` | `flesh_heavy` + `coal_pop` |
| Its remains landing | `Remains.gd` | `flesh` |
| A copal cloud bursting and hanging | `CopalCloud.gd` | `whoosh_light` |
| A slide's scrape | `PlayerController._update_slide` | `cloth`, repeated |
| The evil eye settling on you, and lifting | `PlayerController._feel_statuses` | None yet |
| The egg drawing the curse in, rising | `Loadout.use_item` | `whoosh_heavy` low |
| A ribbon of the curse landing in the egg | `Loadout._land_ribbons` | `flesh` quiet, rising pitch |
| The egg's release: the crack and sting of a dispel | `Loadout._release` | `ting` + `bone_crack` |
