# First-person poses needed, for live Blender with the user

Stand-ins until posed by hand (never computed and shown as final).

| Pose | Where | Today |
|---|---|---|
| Egg limpia, left hand: passed across your sight | `Loadout.left_frame`, `HandSlot.EGG_GRIP` | Computed stand-in |
| Gun dodge: body leaning into it, gun held up | `PlayerCombat._try_dodge` | Camera lean only |
| Slide: low, off hand down to the floor | `PlayerController._try_slide` | Camera drop and roll only |
