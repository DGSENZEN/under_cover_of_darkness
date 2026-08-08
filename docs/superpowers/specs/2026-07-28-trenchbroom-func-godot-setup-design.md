# Under Cover of Darkness: TrenchBroom and FuncGodot Setup

## Goal

Install the latest stable TrenchBroom release on macOS and connect it to the
existing Godot project through the already-installed FuncGodot 2025.12 add-on.
TrenchBroom must list the game as **Under Cover of Darkness** and use this
project as its game-data path.

## Scope

The setup includes:

- installing TrenchBroom as a normal macOS application through Homebrew;
- changing the Godot application name to `Under Cover of Darkness`;
- configuring the project FGD and TrenchBroom game resource with that name;
- exporting a TrenchBroom version 9 game profile to the macOS user-data folder;
- using the Godot project root as TrenchBroom's game path;
- creating basic `maps` and `textures` directories; and
- removing the accidental project-local `~/Library/Application Support/...`
  export generated during the earlier setup attempt.

The setup excludes level creation, custom entities, gameplay changes, custom
materials, compile profiles, and engine-launch profiles.

## Configuration

The existing `addons/func_godot` installation remains enabled. The project FGD
resource will use `Under Cover of Darkness` as its FGD name and inherit the
standard FuncGodot entity definitions. The TrenchBroom game configuration
resource will use the same display name and FGD resource.

The exported profile will live at:

`~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness`

It will contain `GameConfig.cfg`, `Under Cover of Darkness.fgd`, and the
FuncGodot icon. TrenchBroom's game path will be:

`<project-root>`

FuncGodot's machine-local settings will live at:

`~/Library/Application Support/Godot/app_userdata/Under Cover of Darkness/func_godot_config.json`

Valve 220 will remain the preferred map format because it provides predictable
texture alignment while remaining directly supported by FuncGodot.

## Verification

The setup is complete when:

1. TrenchBroom launches from `/Applications/TrenchBroom.app`.
2. Its new-map dialog lists `Under Cover of Darkness`.
3. A Valve-format map can be created for that game profile.
4. The entity browser includes FuncGodot definitions such as `worldspawn`,
   `func_geo`, and `func_detail`.
5. The game path resolves to the project root and maps can be saved under
   `maps/`.
6. The accidental project-local `~` export directory no longer exists.
