# Documentation conventions

Keep the contract beside the implementation and the integration explanation in the system guide. Document what a caller needs to know: valid inputs, output shape, failure values, units, coordinate space, ownership, mutations and signals. Types and defaults already present in a signature should not be repeated as a long prose inventory unless their meaning needs explanation.

## Source comments

Use GDScript `##` for concise class summaries, public API contracts and meaningful exported settings. Attach the block directly to the declaration it describes. Use ordinary `#` comments for implementation constraints: collision tolerances, shared-resource ownership, physics ordering, unusual timing, fallback choices and reasons for an algorithm. Shader comments serve the same purpose. Keep Python docstrings on modules, classes and important functions.

Remove editor templates, decorative divider walls, obsolete behavior descriptions, duplicate summaries and comments that merely narrate an obvious assignment or loop. Preserve licenses, attribution, intentional TODOs, units, protocol/schema notes, examples that clarify a contract, lint pragmas and explanations that prevent a subtle regression. Shell headers may be used to produce `--help` output; inspect callers before treating them as disposable comments.

Prefer this style:

```gdscript
## target is a world-space foot position in metres.
## Returns null when the capsule cannot fit; does not move the body.
func plan(target: Vector3) -> TraversalMove:
    ...
```

Do not add runtime type annotations or alter code merely to make the documentation appear fully typed. If a type is missing, record that honestly; describe the observed protocol or dictionary shape in the guide. Do not promise atomic success, ownership transfer or no side effects unless the implementation supports it.

## Authored guides and generated references

The [systems guide](systems/README.md) holds architecture, lifecycle, integration and runtime schemas. The [reference index](reference/README.md) is generated from current first-party declarations. It includes GDScript methods, signals, properties and enums; Python function/method signatures and docstrings; and shader functions, uniforms, render modes, includes and assigned stage outputs.

Edit source comments/docstrings and authored guides, then regenerate:

```sh
python3 tools/docs/build_reference.py
python3 tools/docs/build_reference.py --check
python3 -m unittest discover -s tools/docs -p 'test_*.py'
```

Generated pages begin with a generator marker. Do not edit them directly: regeneration replaces them. `--check` writes nothing and exits 1 when a generated page is missing, stale or obsolete. See [reference tooling](../tools/docs/README.md) for scope and parser limits.

## Change checklist

1. Update the contract when inputs, defaults, return values, keys, signals or side effects change.
2. Update the owning system guide when lifecycle, integration or ownership changes.
3. Regenerate the reference, check it, and verify local links still resolve.
4. Run relevant tests for behavior changes. For documentation-only source cleanup, compare executable content with the starting checkout, including string literals and indentation; a Git diff against an older commit can include unrelated in-progress work.

Old design documents and investigation notes under `docs/` are historical records. Keep them intact and link current guidance when needed. Vendor code, third-party licenses and imported assets retain their original documentation.
