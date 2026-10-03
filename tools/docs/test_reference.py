"""Regression checks for source-derived documentation, without running the game."""
import tempfile
import unittest
from pathlib import Path

from build_reference import build, parse_gd, parse_python, parse_shader, _code


class ReferenceTests(unittest.TestCase):
    def test_code_values_preserve_pipes_and_literal_backticks(self):
        self.assertEqual(_code('dict | None'), '`dict | None`')
        self.assertEqual(_code('1 | 2', table=True), '`1 \\| 2`')
        self.assertEqual(_code('"a`b"'), '``"a`b"``')

    def test_multiline_gd_contract_preserves_types_and_nested_defaults(self):
        source = '''extends RefCounted
## Returns a world position, or Vector3.ZERO when no contact exists.
func sample(
    point: Vector3,
    options := {"axes": [1, 2], "tag": "a,b#c"}
) -> Vector3:
    return point
'''
        data = parse_gd(source)
        self.assertEqual(len(data['functions']), 1)
        function = data['functions'][0]
        self.assertEqual(function['return_type'], 'Vector3')
        self.assertEqual([p['name'] for p in function['params']], ['point', 'options'])
        self.assertEqual(function['params'][0]['type'], 'Vector3')
        self.assertIn('"a,b#c"', function['params'][1]['default'])
        self.assertEqual(function['line'], 3)
        self.assertIn('Vector3.ZERO', function['docs'])

    def test_nested_class_methods_and_members_keep_their_owner(self):
        data = parse_gd('''extends RefCounted
class Result:
    extends RefCounted
    var position: Vector3
    func valid() -> bool:
        return true
func build() -> Result:
    return Result.new()
''')
        self.assertEqual([f['qualified_name'] for f in data['functions']], ['Result.valid', 'build'])
        self.assertEqual(data['properties'][0]['qualified_name'], 'Result.position')

    def test_fake_declarations_in_strings_and_comments_are_not_indexed(self):
        data = parse_gd('''extends Node
const TEXT = """
func fake() -> int:
signal fake_signal(value)
"""
# func also_fake():
func real(value = "#not a comment"):
    pass
''')
        self.assertEqual([f['name'] for f in data['functions']], ['real'])
        self.assertEqual(data['signals'], [])
        self.assertEqual(data['functions'][0]['params'][0]['default'], '"#not a comment"')
        self.assertEqual(data['functions'][0]['return_type'], 'not declared')

    def test_signals_exports_and_enums_preserve_runtime_contracts(self):
        data = parse_gd('''extends Node
signal changed(value: float, reason: StringName)
@export_range(0.0, 1.0) var energy := 0.5
enum State { IDLE, MOVING = 4 }
''')
        self.assertEqual(len(data['signals']), 1)
        self.assertEqual(len(data['properties']), 1)
        self.assertEqual(data['signals'][0]['params'][1]['type'], 'StringName')
        self.assertEqual(data['properties'][0]['default'], '0.5')
        self.assertTrue(data['properties'][0]['exported'])
        self.assertIn('MOVING = 4', data['enums'][0]['signature'])

    def test_property_accessors_do_not_export_local_variables(self):
        data = parse_gd('''extends Node
@export var locked := false:
    set(value):
        var region: Variant = null
        locked = value
var public_value: int = 3
''')
        self.assertEqual([p['name'] for p in data['properties']], ['locked', 'public_value'])

    def test_python_parameters_async_methods_and_nullable_returns(self):
        data = parse_python('''class Builder:
    async def build(self, path: str, /, *, scale: float = 1.0) -> dict | None:
        """Return export metadata or None when the input is missing."""
        return None
''')
        self.assertEqual(len(data['functions']), 1)
        f = data['functions'][0]
        self.assertEqual(f['qualified_name'], 'Builder.build')
        self.assertEqual(f['return_type'], 'dict | None')
        self.assertEqual(f['params'][2]['default'], '1.0')
        self.assertTrue(f['async'])

    def test_python_helpers_inside_control_flow_retain_function_owner(self):
        data = parse_python('''def outer():
    for item in []:
        def helper(value: int) -> int:
            return value
if True:
    def conditional() -> None:
        pass
''')
        self.assertEqual([f['qualified_name'] for f in data['functions']],
                         ['outer', 'outer.helper', 'conditional'])

    def test_shader_inputs_hints_functions_and_outputs(self):
        data = parse_shader('''shader_type spatial;
render_mode blend_mix, cull_back;
uniform sampler2D bed : filter_linear;
uniform vec3 tint = vec3(0.1, 0.2, 0.3);
// uniform float fake = 3.0;
float absorb(float depth, vec3 colour) { return depth; }
void fragment() { ALBEDO = tint; ROUGHNESS = 0.6; }
''')
        self.assertEqual([u['name'] for u in data['uniforms']], ['bed', 'tint'])
        self.assertEqual(data['uniforms'][0]['hint'], 'filter_linear')
        self.assertEqual(data['functions'][0]['params'][1]['type'], 'vec3')
        self.assertEqual(data['outputs'], ['ALBEDO', 'ROUGHNESS'])

    def test_shader_source_links_skip_leading_blank_lines(self):
        data = parse_shader('shader_type spatial;\n\n\nfloat measure(float depth) { return depth; }\n')
        self.assertEqual(data['functions'][0]['line'], 4)

    def test_shader_output_components_and_indices_are_assignments(self):
        data = parse_shader('''void vertex() {
    VERTEX.x += 0.1;
    COLOR[0] = 1.0;
    float sample = NORMAL.y;
}''')
        self.assertEqual(data['outputs'], ['COLOR', 'VERTEX'])

    def test_shader_foliage_and_viewmodel_outputs_are_included(self):
        data = parse_shader('''void vertex() { MODELVIEW_MATRIX = mat4(1.0); }
void fragment() { BACKLIGHT = vec3(0.2); }''')
        self.assertEqual(data['outputs'], ['BACKLIGHT', 'MODELVIEW_MATRIX'])

    def test_build_and_check_detect_stale_docs_with_resolvable_source_links(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'scripts').mkdir()
            source = root / 'scripts/Example.gd'
            source.write_text('extends Node\nfunc sample(value: int) -> int:\n    return value\n')
            output = root / 'docs/reference'
            self.assertEqual(build(root, output, check=False), [])
            page = output / 'gdscript/scripts/Example.md'
            self.assertTrue(page.exists())
            self.assertIn('sample', page.read_text())
            self.assertEqual(build(root, output, check=True), [])
            source.write_text(source.read_text().replace('value: int', 'value: float'))
            self.assertIn(page.resolve(), build(root, output, check=True))


if __name__ == '__main__':
    unittest.main()
