# Water and sky polish

All existing WaterVolume instances install the underwater view automatically. Moon reflections and submerged shafts follow the scene's moon direction and moving cloud coverage. Water clarity and tint control absorption; roofs block direct moon shafts. Cloud coverage comes from a persistent weather field moving with the wind. No timed veil rushes into position over the moon.

For swimming, run `res://maps/traversal_gym.tscn` and select station 14, **Water & landings**, with `[ / ]`. WASD steers; below the surface forward and reverse follow view pitch while strafe stays level. Crouch dives, jump rises, and sprint increases stroke speed. Keep jump held while surfacing and pushing into a reachable bank to mantle onto it. Release the controls to settle naturally at the surface. Push toward a reachable bank and press jump to climb out, or approach a submerged ladder. Try shallow ramps, interrupted bank approaches, sharp dive turns and pool-floor contact at 30/60/120 Hz using F4.

The existing nighttime city also uses the new optics. Look toward the moon underwater, turn away, dive deeper, and move beneath cover. The surface stays flat while its ripples and broken lamp/moon reflections move with the simulation clock.

The shoreline now follows the solid banks, including mesh terrain and islands. The bed shows through in the shallows, ripples calm near contact, and deep water retains its opaque reflections. The bank survey runs once in small batches during level startup; call `WaterVolume.refresh_shoreline()` after editing static bank geometry at runtime. Bridges and actor collision layers do not become part of the bank. The city demo has brighter fill and moonlight for readable streets while preserving its night sky.

Automated visual stages use the real renderer, capture their cases, then quit:

```sh
Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_clouds.tscn -- --out=/tmp/cloud-shots
Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_water.tscn -- --out=/tmp/water-shots
Godot --fixed-fps 60 --path . res://tests/visual/stage_water_regression.tscn -- --out=/tmp/water-regression-shots
Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_shore.tscn -- --out=/tmp/shore-shots
Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_city.tscn -- --out=/tmp/city-shots
```

The cloud stage compares CPU opacity with the production sky shader across 484 directions. The water stage captures above water, underwater moon, the same view without shafts, pool floor, roof cover, partial cloud cover and surfacing; it measures the GPU's visible shaft contribution.

The shore stage verifies shallow bed visibility and deep-water opacity, then captures the sloped bank before and after blending. The city stage captures the actual streets, harbour and waterline from fixed viewpoints.

```sh
GODOT=/path/to/Godot bash tools/run_suites.sh tests/cloud_polish_test.tscn tests/swim_polish_test.tscn tests/water_polish_test.tscn tests/night_test.tscn tests/climb_swim_test.tscn
```

Underwater optics use scene depth and a screen-space sky refraction, with a bounded eight-sample shaft pass. Roof access is sampled toward the moon at the swimmer's surface entry point; small cover edges are approximate. The view affects the world camera, leaving HUD and lightgem probes independent. First-person arms and held items draw after the world reflection pass so they do not appear in the water.
