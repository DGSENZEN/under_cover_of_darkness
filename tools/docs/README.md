# Source reference tooling

[build_reference.py](build_reference.py) generates [docs/reference](../../docs/reference/README.md) from current first-party source. It requires only Python's standard library; Godot and Blender are not needed.

```sh
python3 tools/docs/build_reference.py
python3 tools/docs/build_reference.py --check
python3 -m unittest discover -s tools/docs -p 'test_*.py'
```

Run from any working directory. `--root PATH` selects the source repository; `--output PATH` selects the generated directory, defaulting to `ROOT/docs/reference`. A normal run writes deterministic Markdown and removes obsolete pages bearing this generator's marker. It preserves other files. A check run writes nothing, prints each stale path and exits 1; a current reference exits 0. Parse or filesystem errors are not converted into success.

## Tool APIs

| Function | Inputs | Output / effects |
| --- | --- | --- |
| `lexical_source(source: str, shader=False, mask_strings=False) -> str` | Source text; shader flag selects C-style comments instead of `#`; optional string masking. | Text with comments replaced by spaces, preserving offsets/newlines. Quoted comment markers remain literal unless strings are masked. |
| `parse_gd(source: str) -> dict` | GDScript text. | `docs`, `extends`, `class_name`, `classes`, `functions`, `properties`, `signals`, `enums`. Nested classes retain qualified owners; function/accessor-local fields are excluded. |
| `parse_python(source: str) -> dict` | Valid Python source. | AST-derived `docs`, `classes`, `functions`; functions include annotations, defaults, async status and qualified ownership. Invalid source raises `SyntaxError`. |
| `parse_shader(source: str) -> dict` | Godot shader/include text. | `shader_type`, `render_modes`, `uniforms`, `functions`, `outputs`, `includes`. Output detection records assigned built-ins, not a dependency/flow analysis. |
| `source_files(root)` | Repository `Path`. | Iterator of included source `Path` objects; does not modify files. |
| `build(root: Path, output: Path, check=False) -> list[Path]` | Repository and output paths; check flag. | In check mode, stale/missing/obsolete generated paths. In write mode, updates pages and returns `[]`. |
| `main()` | CLI arguments above. | Exit status `0` or `1`, with a generated/current/stale report. |

Function records contain `name`, `qualified_name`, `signature`, `params`, `return_type`, one-based `line`, and `docs`. Parameter records contain `name`, `type`, and `default` (`None` means no default). Python records additionally carry `async`. GDScript property records include `qualified_name`, `type`, `default`, `exported`, `line`, and `docs`; signal records contain a signature and parameters. Shader uniforms include `name`, `type`, `hint`, `default`, and `line`.

## Scope and limits

The index covers `.gd`, `.py`, `.gdshader` and `.gdshaderinc` under `scripts`, `maps` and `tools`, plus files of those types at the repository root. It excludes `test_*` source files, caches, the separate `tests` tree, vendored add-ons and imported assets. Shell command contracts live in the [development guide](../../docs/systems/development.md).

This is a static declaration index, not an engine type checker. `not declared` means no annotation exists; `inferred from default` preserves GDScript `:=` syntax without guessing an engine type. Runtime dictionary schemas, nullable returns, units and ownership belong in the [system guides](../../docs/systems/README.md). Long property initializers are shortened in tables and linked to source. Class constants and dynamically created members are not enumerated as properties. Python declarations inside control flow are listed without evaluating which branch executes; shader macros are not expanded.

The regression tests cover multiline signatures, nested defaults/classes, quoted comment markers, signals, exported properties, accessor-local variables, annotations, async methods, helpers inside control flow, nullable types, shader input/output component extraction, exact shader line links and stale-document detection.
