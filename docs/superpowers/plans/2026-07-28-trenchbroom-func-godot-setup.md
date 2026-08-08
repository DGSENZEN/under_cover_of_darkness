# Under Cover of Darkness TrenchBroom and FuncGodot Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install TrenchBroom on macOS and connect it to the existing Godot project under the game name `Under Cover of Darkness`.

**Architecture:** Keep FuncGodot inside the Godot project and keep machine-specific TrenchBroom data outside the project. The project-owned `.tres` resources define the FGD and game profile; generated copies are installed into TrenchBroom's macOS user-data folder, while TrenchBroom uses the Godot project root as its game path.

**Tech Stack:** Godot 4.5 project configuration, FuncGodot 2025.12, TrenchBroom 2026.1 game-config version 9, macOS arm64

## Global Constraints

- The game name is exactly `Under Cover of Darkness`.
- Keep the existing FuncGodot 2025.12 add-on installed and enabled.
- Use TrenchBroom game-config version 9.
- Use the project root <project-root> as the TrenchBroom game path.
- Prefer Valve 220 for new maps.
- Do not create a map, custom entity, gameplay feature, custom material, compile profile, or engine-launch profile.
- This folder is not a Git repository, so commit steps are intentionally omitted.

---

### Task 1: Normalize the project-owned FuncGodot configuration

**Files:**
- Modify: `project.godot`
- Modify: `my_fgd.tres`
- Modify: `trenchbroom_config.tres`
- Create: `maps/.gitkeep`
- Create: `textures/.gitkeep`

**Interfaces:**
- Consumes: the enabled plugin at `res://addons/func_godot/plugin.cfg`
- Produces: a Godot application title, FGD name, and TrenchBroom game name that all equal `Under Cover of Darkness`

- [ ] **Step 1: Verify the existing partial setup**

Run:

```bash
rg -n 'config/name|enabled=|fgd_name|game_name' project.godot my_fgd.tres trenchbroom_config.tres
find './~/Library/Application Support/TrenchBroom/games/func' -maxdepth 1 -type f -print
```

Expected: the plugin is enabled, names still contain `a_world_of_darkness_alpha` or `func`, and the accidental project-local profile contains three files.

- [ ] **Step 2: Apply the exact project names**

Set:

```ini
# project.godot
config/name="Under Cover of Darkness"
```

```ini
# my_fgd.tres
fgd_name = "Under Cover of Darkness"
```

```ini
# trenchbroom_config.tres
game_name = "Under Cover of Darkness"
```

Do not change the enabled plugin entry or the base FGD resource.

- [ ] **Step 3: Create the mapping directories**

Create empty marker files:

```text
maps/.gitkeep
textures/.gitkeep
```

- [ ] **Step 4: Verify project configuration**

Run:

```bash
rg -n 'config/name="Under Cover of Darkness"' project.godot
rg -n 'fgd_name = "Under Cover of Darkness"' my_fgd.tres
rg -n 'game_name = "Under Cover of Darkness"' trenchbroom_config.tres
test -f maps/.gitkeep
test -f textures/.gitkeep
```

Expected: every command exits successfully.

### Task 2: Install TrenchBroom and export the machine-local game profile

**Files:**
- Install: `/Applications/TrenchBroom.app`
- Create: `~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness/GameConfig.cfg`
- Create: `~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness/Under Cover of Darkness.fgd`
- Create: `~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness/icon.png`
- Create: `~/Library/Application Support/Godot/app_userdata/Under Cover of Darkness/func_godot_config.json`
- Remove: `~/Library/Application Support/TrenchBroom/games/func/GameConfig.cfg`
- Remove: `~/Library/Application Support/TrenchBroom/games/func/func.fgd`
- Remove: `~/Library/Application Support/TrenchBroom/games/func/icon.png`

**Interfaces:**
- Consumes: `trenchbroom_config.tres`, `my_fgd.tres`, the standard FuncGodot FGD resources, and the project root
- Produces: a TrenchBroom version 9 custom game profile and a FuncGodot local-machine path configuration

- [ ] **Step 1: Install the current stable official macOS release**

Run:

```bash
gh release download v2026.1 \
  --repo TrenchBroom/TrenchBroom \
  --pattern 'TrenchBroom-macOS-arm64-v2026.1-Release.zip*' \
  --dir /tmp/under-cover-of-darkness-trenchbroom-install
cd /tmp/under-cover-of-darkness-trenchbroom-install
md5 -q TrenchBroom-macOS-arm64-v2026.1-Release.zip
cat TrenchBroom-macOS-arm64-v2026.1-Release.zip.md5
ditto -x -k TrenchBroom-macOS-arm64-v2026.1-Release.zip extracted
ditto extracted/TrenchBroom.app /Applications/TrenchBroom.app
```

Expected: the computed MD5 matches the publisher-provided checksum and the
official arm64 application is installed at `/Applications/TrenchBroom.app`.

- [ ] **Step 2: Confirm the application and version**

Run:

```bash
test -x /Applications/TrenchBroom.app/Contents/MacOS/TrenchBroom
/Applications/TrenchBroom.app/Contents/MacOS/TrenchBroom --version
```

Expected: the executable exists and reports TrenchBroom 2026.1 or a newer stable release supporting game-config version 9.

- [ ] **Step 3: Stage the deterministic profile generated by FuncGodot**

Create a temporary staging directory and copy the files already generated by
FuncGodot during the partial setup:

```bash
mkdir -p "/tmp/under-cover-of-darkness-trenchbroom"
cp "./~/Library/Application Support/TrenchBroom/games/func/GameConfig.cfg" "/tmp/under-cover-of-darkness-trenchbroom/GameConfig.cfg"
cp "./~/Library/Application Support/TrenchBroom/games/func/func.fgd" "/tmp/under-cover-of-darkness-trenchbroom/Under Cover of Darkness.fgd"
cp "./~/Library/Application Support/TrenchBroom/games/func/icon.png" "/tmp/under-cover-of-darkness-trenchbroom/icon.png"
```

Mechanically replace the profile and FGD names in the staged
`GameConfig.cfg`:

```bash
perl -pi -e 's/"name": "func"/"name": "Under Cover of Darkness"/; s/"func\\.fgd"/"Under Cover of Darkness.fgd"/' "/tmp/under-cover-of-darkness-trenchbroom/GameConfig.cfg"
```

This preserves FuncGodot's version 9 file formats, material settings, scale
`32`, and Clip/Skip/Origin face tags. The changed fields must read:

```json
"name": "Under Cover of Darkness",
"definitions": [ "Under Cover of Darkness.fgd" ]
```

- [ ] **Step 4: Install the profile into TrenchBroom user data**

Install the three generated files into:

```text
~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness/
```

Do not modify TrenchBroom's built-in application resources.

- [ ] **Step 5: Save FuncGodot's machine-local paths**

Create `func_godot_config.json` containing:

```json
{
  "FGD_OUTPUT_FOLDER": "~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness",
  "TRENCHBROOM_GAME_CONFIG_FOLDER": "~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness",
  "NETRADIANT_CUSTOM_GAMEPACKS_FOLDER": "",
  "MAP_EDITOR_GAME_PATH": "<project-root>"
}
```

Install it at:

```text
~/Library/Application Support/Godot/app_userdata/Under Cover of Darkness/func_godot_config.json
```

- [ ] **Step 6: Validate the installed profile**

Run:

```bash
python3 -m json.tool "~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness/GameConfig.cfg"
rg -n '"version": 9|"name": "Under Cover of Darkness"|"definitions": \\[ "Under Cover of Darkness.fgd" \\]' "~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness/GameConfig.cfg"
rg -n '@SolidClass.*worldspawn|@SolidClass.*func_geo|@SolidClass.*func_detail' "~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness/Under Cover of Darkness.fgd"
file "~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness/icon.png"
python3 -m json.tool "~/Library/Application Support/Godot/app_userdata/Under Cover of Darkness/func_godot_config.json"
```

Expected: both JSON files parse, all required names/entities match, and the icon is a PNG image.

- [ ] **Step 7: Remove only the accidental project-local export**

Re-list the project-root directory named `~`, confirm that its only files are
the three generated TrenchBroom profile files staged in Step 3, and then delete
that project-local `~` directory. Confirm:

```bash
test ! -e './~'
```

Expected: the command exits successfully.

### Task 3: Configure and smoke-test TrenchBroom

**Files:**
- Create: `~/Library/Application Support/TrenchBroom/Preferences.json`

**Interfaces:**
- Consumes: the installed `Under Cover of Darkness` profile and the project root
- Produces: a selectable TrenchBroom game whose asset path points at the Godot project

- [ ] **Step 1: Launch TrenchBroom**

Run:

```bash
open -a TrenchBroom
```

Expected: TrenchBroom opens without rejecting the custom game profile.

- [ ] **Step 2: Set the game path**

Create TrenchBroom's JSON preference file with the exact game preference key
defined by TrenchBroom v2026.1:

```json
{
  "Games/Under Cover of Darkness/Path": "<project-root>"
}
```

Do not add compile or engine-launch settings.

- [ ] **Step 3: Smoke-test new-map configuration without saving content**

Open the New Map dialog, select:

```text
Game: Under Cover of Darkness
Format: Valve
```

Confirm that the entity browser exposes `worldspawn`, `func_geo`, and `func_detail`. Close the unsaved map without creating or saving level content.

- [ ] **Step 4: Final filesystem verification**

Run:

```bash
test -d /Applications/TrenchBroom.app
test -f "~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness/GameConfig.cfg"
test -f "~/Library/Application Support/TrenchBroom/games/Under Cover of Darkness/Under Cover of Darkness.fgd"
test -d maps
test -d textures
test ! -e './~'
```

Expected: every command exits successfully.
