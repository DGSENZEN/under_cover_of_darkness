# Code Documentation Cleanup Implementation Plan

> **For agentic workers:** Use the parallel-agent workflow for independent source directories; the coordinator integrates and verifies the documentation.

**Goal:** Document the current game systems and important input/output contracts while removing redundant source comments without changing game behavior.

**Architecture:** Authored system guides explain ownership, lifecycle, integration, units, dictionary schemas, signals and failure cases. Generated references provide current declarations and source links for every first-party runtime script, shader and tool. Inline Godot documentation stays next to important contracts; implementation comments explain constraints rather than narrating syntax.

**Tech Stack:** Godot 4.5 GDScript/shaders, Python build tools, shell entry points, Markdown.

**Spec:** The user's request in this chat: a complete code documentation cleanup covering systems, important functions, arguments, parameters, inputs, outputs and types.

## Constraints

- Preserve all pre-existing working-tree changes.
- Change comments and documentation only in existing source files. Do not add type annotations or alter executable statements as part of this task.
- Retain licensing, useful examples, physical units, failure sentinels, schema notes, lifecycle/ownership constraints and explanations of non-obvious algorithms.
- Exclude vendored add-ons, imported assets and historical design records from source cleanup.
- Separate declared types from unannotated/unknown types; do not invent contracts.

## Tasks

- [x] Gameplay: review `scripts/PlayerController.gd`, `scripts/PlayerUtils`, `scripts/Combat`, `scripts/Interaction`; create movement, combat and interaction guides.
- [x] AI and stealth: review `scripts/AISystem`, `scripts/StimuliSystem`, `light_gem.gd`; create AI and stealth guides.
- [x] Presentation and world: review `scripts/Visual`, `scripts/Night`, `scripts/Audio`, `scripts/Cinema`, `scripts/Showcase`, `scripts/UI`, `scripts/Level`; create rendering, world, audio and cinematic guides.
- [x] Coordinator: document maps, developer tools, test workflows, architecture and documentation conventions; remove mechanical banner/editor-template comments across first-party code.
- [x] Reference tooling: parse declarations deterministically, generate linked GDScript/Python/shader references, and support a stale-document check. Verify multiline signatures, nested classes, defaults, comments and dynamic types.
- [x] Integration: validate all local links and complete system/file coverage; compare existing source token streams with the pre-cleanup snapshot; run the reference checks and Godot suites. Report existing test failures explicitly.

## Review focus

- Nullable returns, empty dictionaries and boolean failure sentinels must not be presented as unconditional success.
- Player origin, guard origin, local/world transforms, units and simulation versus real time must be distinguished.
- Dynamic dictionary keys, side effects, signals and caller-owned versus retained resources must be documented from implementation.
- Inline `##` documentation must remain attached to the correct declaration; shader strings and comment markers in strings must remain unchanged.
- Generated reference links must resolve after comment line counts change.

## Verification evidence — 2026-10-02

- Ten authored system guides plus project navigation and comment/documentation conventions.
- Generated reference: 243 source files; 3,898 functions, 80 signals, 2,805 properties and 169 shader uniforms.
- Independent declaration coverage/source-line checks passed; all 8,024 local documentation links resolved.
- All 357 pre-cleanup first-party source snapshots preserved executable content. GDScript/shader comparison retained indentation and literals; Python AST comparison excluded documentation strings; shell sources remained byte-identical. 208 existing source files changed only in comments/docstrings.
- Net reduction: 2,425 source comment lines, retaining meaningful constraints, units, licenses and protocol notes.
- Reference generator: 13 tests passed; read-only stale check passed.
- Pure level pipeline: 155 tests passed.
- Full Godot run: 53 suites, 1,317 passed assertions and one failure (`garrison_hunt_test`, S5 chapel fight). An isolated rerun passed all three assertions. The full run therefore was not entirely green; no gameplay code changed during this cleanup.
- `git diff --check` passed.

Commands:

```sh
python3 tools/docs/build_reference.py --check
python3 -m unittest discover -s tools/docs -p 'test_*.py'
python3 -m unittest discover -s tools/level -p 'test_*.py'
GODOT=/tmp/ledge-godot TMPDIR=/tmp/docs-cleanup-suites bash tools/run_suites.sh
GODOT=/tmp/ledge-godot TMPDIR=/tmp/docs-cleanup-hunt-recheck bash tools/run_suites.sh tests/garrison_hunt_test.tscn
git diff --check
```

The Godot executable wrapper and snapshot verification files are session-local under `/tmp`; the source reference commands are repository tools. Runtime logs for this run are in `/tmp/docs-cleanup-suites/suites` and the isolated recheck in `/tmp/docs-cleanup-hunt-recheck/suites`.
