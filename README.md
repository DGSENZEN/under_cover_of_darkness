# Under Cover of Darkness

A Godot game combining first-person traversal, melee combat and stealth. The current project targets Godot 4.5 with the Forward+ renderer; the system documentation describes the implementation in this checkout.

Start with the [systems guide](docs/systems/README.md) for ownership, important APIs, data schemas and integration. The [source API reference](docs/reference/README.md) lists declarations, parameter types, defaults, return types, signals and shader uniforms. See [documentation conventions](docs/DOCUMENTATION.md) when changing code or refreshing the reference.

## Running and testing

Open [project.godot](project.godot) in Godot. Run a specific scene with F6 in the editor, or from the repository root:

```sh
godot --path . res://maps/city.tscn
godot --path . res://maps/traversal_gym.tscn
godot --path . res://maps/combat_gym.tscn
GODOT=godot bash tools/run_suites.sh
```

`godot` must resolve to your Godot executable; the suite runner also accepts an absolute executable path through `GODOT`. Asset generation uses Blender separately. The [development guide](docs/systems/development.md) documents dependencies, build commands, test outputs and diagnostic tools.

## Practice scenes

| Scene | Purpose | Instructions |
| --- | --- | --- |
| [City](maps/city.tscn) | Integrated harbour and city systems. | [World setup](docs/systems/world.md) |
| [Movement gym](maps/traversal_gym.tscn) | Traversal, water exits, corners, moving obstacles and timed courses. | [Movement practice](maps/MOVEMENT_GYM.md) |
| [Combat gym](maps/combat_gym.tscn), [arena](maps/combat_arena.tscn) | Production fighters, defensive timing, exchanges and hazards. | [Combat practice](maps/COMBAT_PRACTICE.md) |
| [Stealth gym](maps/stealth_gym.tscn), [NPC gym](maps/npc_gym.tscn) | Exposure, hearing, guard state and pursuit exercises. | [Stealth system](docs/systems/stealth.md), [AI system](docs/systems/ai.md) |
| [Interaction gym](maps/interaction_gym.tscn) | Doors, items, carrying, tools and mechanisms. | [Interaction system](docs/systems/interaction.md) |
| [Lights gallery](maps/lights_gallery.tscn) | Fixture states and lighting inspection. | [Rendering](docs/systems/rendering.md) |
| [Garrison](maps/garrison.tscn), [NPC showcase](maps/npc_showcase.tscn) | Scripted night, cast and cinematic presentation. | [Cinematics](docs/systems/cinematics.md) |
| [Retro showcase](maps/retro_showcase.tscn) | Rendering-style controls. | [Rendering](docs/systems/rendering.md) |

[Credits and asset licenses](CREDITS.md) remain the source for attribution. Existing design records and bug investigations under `docs/` provide historical context; use the systems guides and source for current contracts.
