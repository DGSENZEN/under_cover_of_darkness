# Solid lanterns

Hanging lanterns now use one rigid body for the lamp, constrained at the hook. Wind applies a force to its weight; collisions and the existing melee/arrow impulses disturb it. Linear and angular damping let it settle. The hook locks translation and yaw while allowing a limited swing in both horizontal directions.

The chain, lamp, flame, light projector, corona and dousing area share the resulting pose. The chain is visual: individual links do not add physics bodies. Calm lamps may sleep. Wall lanterns have static collision around the lamp and remain attached to their brackets. Carried lanterns keep their existing hand motion.

Collision surrounds the actual lamp's base, panes and roof, using local bounds from its imported mesh. It does not fill the chain's empty space and does not add a visual occluder. No Blender re-export is required. Reload an already running level to build the new bodies.

Players and guards transfer their incoming normal speed when they walk into a mounted lantern. This is necessary because character sliding stops at a collision margin before the rigid-body solver receives contact. Other movement and prop collision behavior stays the same. The hanging body cannot be carried off its hook.

The solid lamp's body is excluded only from its own halo and gameplay shadow rays. Otherwise, a guard could incorrectly read the light inside the lamp as completely blocked by its shell. Guards also recognize the lamp's own shell as part of their visible target, so they can notice an extinguished fixture and relight it. World walls still block both light and sight. Existing light energy, shadow budgets and dousing rules are retained.

## Verification

`tests/lantern_physics_test.tscn` exercises solidity, impact motion, the stationary hook, light/use alignment, settling, world-space wind after rotated placement, dousing, wall mounts, gameplay light obstruction, thrown objects and walking contacts. The existing `tests/lights_test.tscn` also covers wind sway, creaking, cleanup and fixture lighting.

The rendered stage shows projected bars and illumination following the physical lamp:

```sh
Godot --log-file /tmp/lantern-stage.log --max-fps 60 --disable-vsync --path . res://tests/visual/stage_lantern_physics.tscn
```

It saves `/tmp/lantern-physics-rest.png`, `/tmp/lantern-physics-wind.png` and `/tmp/lantern-physics-impact.png`. For manual play, use `maps/lights_gallery.tscn` for wind and lighting, or a hanging lantern in the city for bumps, weapon impacts and dousing where enabled.

The final targeted run passed all 12 lantern checks and all 70 existing lighting checks. Rendered captures at rest, in wind and after an impact confirmed that the chain, lamp and projected bars move together; copies are saved in `docs/diagnostics/lantern-*.png`.

The broader 52-suite run had one assertion failure: `garrison_hunt_test` S5 timed out during the chapel battle. Its isolated rerun passed all three checks. The broader run also exposed a stale ladder-volume reference in guard climbing; checking instance validity before its type corrected that error, with a focused lifecycle regression and climbing suite both passing. The final full run contained no script errors.
