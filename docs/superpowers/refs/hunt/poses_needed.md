# First-person poses needed, for live Blender with the user

Stand-ins until posed by hand (never computed and shown as final).

| Pose | Where | Today |
|---|---|---|
| Egg limpia, left hand: rolled over the chest and brow | `Loadout.use_item` | No pose: the hand just can't fire or cast for 0.8 s |
| Gun dodge: body leaning into it, gun held up | `PlayerCombat._try_dodge` | Camera lean only |
| Slide: low, off hand down to the floor | `PlayerController._try_slide` | Camera drop and roll only |
