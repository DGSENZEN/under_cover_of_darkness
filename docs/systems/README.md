# Systems guide

These guides document the current first-party implementation. Each covers source ownership, important function inputs and outputs, units, dynamic schemas, signals, lifecycle and failure cases. The [source API reference](../reference/README.md) supplies every indexed declaration and a link to its exact source line. [Documentation conventions](../DOCUMENTATION.md) explain how to keep both layers current.

| System | Start here | Main ownership |
| --- | --- | --- |
| [Movement and traversal](movement.md) | Player state, scanning, planning, ledge hangs, climbing, swimming and camera motion. | `PlayerController`, `PlayerUtils` |
| [Combat](combat.md) | Weapons, attacks, defenses, posture, hit contracts, projectiles and hazards. | `Combat`, guard fighter integration |
| [Interaction](interaction.md) | Frob protocol, inventory, carrying, lockpicking, tools, doors and mechanisms. | `Interaction` |
| [AI](ai.md) | Guard perception/intent, navigation, combat, life, squads, rota and conversation. | `AISystem` |
| [Stealth](stealth.md) | Player visibility/noise, light measurement, sound events, hearing and investigations. | `StimuliSystem`, `light_gem`, guard perception |
| [Rendering](rendering.md) | Retro rendering, shaders, water, wetness, lighting, cloth, trails and effects. | `Visual`, night sky |
| [World](world.md) | Level manifests, marker spawning, nav baking, time, weather and environment setup. | `Level`, `Night` |
| [Audio](audio.md) | Positional effects, voice, ambience and music state. | `Audio` |
| [Cinematics and UI](cinematics.md) | Shot selection, camera operation, story events, subtitles and HUD. | `Cinema`, `Showcase`, `UI` |
| [Development](development.md) | Maps, gyms, Blender pipelines, Python tools, suites and diagnostics. | `maps`, `tools`, `tests` |

## Runtime flow

The level or practice scene creates geometry, collision, marker-driven objects and services. `PlayerController` owns player physics; its scanner measures geometry, the planner produces a validated move, and the controller plays that move. `PlayerCombat` and `PlayerFrob` use the player's stable aim/input state to resolve attacks and interactions. Cosmetic pose and view motion remain separate from those decisions.

Guards coordinate perception, intent and delegated components through `Guard`. Shared registries handle sound, investigations, squads, stations and night schedules. Gameplay transitions emit stimuli and events; audio, effects, UI and cinematic systems consume them. See the individual guides for initialization order and which shared registries a scene reset must clear.

`Retro` is the configured autoload in [project.godot](../../project.godot). Other systems are scene nodes, resources or explicitly managed static registries; do not assume every system is a singleton. Node ownership, weak references and retained resources differ by subsystem.

## Reading a contract

- **Declared type:** The GDScript/Python/shader annotation or inference syntax in source. `Variant`, `Dictionary` and unannotated parameters need the additional schemas in these guides.
- **Runtime shape:** Keys, allowed values, object protocols and nullable/failure values that callers must handle. A return of `false`, `null`, `{}` or an empty list can mean different things in different APIs.
- **Units and space:** Distances normally use metres; transforms can be world, parent-local or station-local. Angles, sound levels and elapsed time must follow each API's stated units.
- **Effects and ownership:** A query may return a live reference; a command may mutate state or emit signals even when its boolean return is false. Read the side-effect notes before treating a return value as success/failure alone.

The generated index includes internal helpers and engine callbacks for navigation. Prefer the integration entry points named in these guides when building new gameplay. Tests and visual stages are fixtures, not production APIs; vendored add-ons and generated/imported assets are outside this documentation cleanup.
