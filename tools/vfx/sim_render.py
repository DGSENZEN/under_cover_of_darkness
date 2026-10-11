"""Our own smoke and fire, simulated and rendered (the effects plan, Task 2;
docs/superpowers/refs/mexico_city/vfx_techniques.md): a Mantaflow gas domain
baked from parameters, then rendered orthographic with Cycles, frame by frame,
transparent:

  plume   a slow curl of copal smoke rising and breaking (32 frames)
  puff    a quick round puff of steam (16 frames)
  fire    a brazier's flames, their emission (16 frames)

The smoke is rendered six times a frame, one white light at a time (from
the right, top, back, left, bottom and front of the camera), for six-way
lighting in the game; pack_sheet.py packs the frames into sheets.

    Blender -b --factory-startup --python tools/vfx/sim_render.py -- plume|puff|fire <out dir>
"""

import math
import sys
import tempfile
from pathlib import Path

import bpy
from mathutils import Vector

# kind -> domain (half width, height), resolution, inflow frames, bake
# frames, the frames rendered (first, step, count), px, fire or not.
KINDS = {
    # Copal: a thick column from a small censer, curling and folding as it
    # rises, sampled once it stands (it loops near enough).
    "plume": {"domain": (1.5, 3.0), "res": 80, "inflow": 999, "bake": 110, "frames": (46, 2, 32), "px": 128,
              "density": 12.0, "vorticity": 0.8, "fire": False, "speed": 0.9, "radius": 0.07, "dissolve": 28,
              "temperature": 1.0},
    "puff": {"domain": (0.9, 2.4), "res": 56, "inflow": 8, "bake": 40, "frames": (2, 2, 16), "px": 128,
             "density": 14.0, "vorticity": 0.4, "fire": False, "speed": 0.5, "radius": 0.25, "dissolve": 60,
             "temperature": 1.0},
    "fire": {"domain": (0.7, 1.6), "res": 72, "inflow": 999, "bake": 60, "frames": (30, 2, 16), "px": 128,
             "density": 2.0, "vorticity": 0.5, "fire": True, "speed": 0.6, "radius": 0.18, "dissolve": 30,
             "temperature": 1.0, "samples": 96},
}
# Where each of the six lights travels (the camera looks along +Y).
LIGHTS = {"right": (-1, 0, 0), "top": (0, 0, -1), "back": (0, -1, 0), "left": (1, 0, 0), "bottom": (0, 0, 1),
          "front": (0, 1, 0)}


def _domain(kind):
    k = KINDS[kind]
    half, height = k["domain"]
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, height / 2))
    dom = bpy.context.object
    dom.scale = (half * 2, half * 2, height)
    bpy.ops.object.transform_apply(scale=True)
    mod = dom.modifiers.new("fluid", "FLUID")
    mod.fluid_type = "DOMAIN"
    ds = mod.domain_settings
    ds.domain_type = "GAS"
    ds.resolution_max = k["res"]
    ds.vorticity = k["vorticity"]
    ds.use_dissolve_smoke = True
    ds.dissolve_speed = k["dissolve"]
    # Open on every side: smoke leaves the domain, never piling up against it.
    for side in ("front", "back", "left", "right", "top", "bottom"):
        setattr(ds, "use_collision_border_" + side, False)

    ds.cache_directory = tempfile.mkdtemp(prefix="vfx_%s_" % kind)
    ds.cache_type = "ALL"
    ds.cache_frame_start = 1
    ds.cache_frame_end = k["bake"]

    if k["fire"]:
        ds.flame_vorticity = 0.6
        ds.burning_rate = 0.65
        ds.flame_smoke = 0.3

    return dom


def _flow(kind):
    k = KINDS[kind]
    bpy.ops.mesh.primitive_uv_sphere_add(radius=k["radius"], location=(0, 0, 0.3))
    src = bpy.context.object
    # (The source makes smoke; it is never seen.)
    src.hide_render = True
    mod = src.modifiers.new("fluid", "FLUID")
    mod.fluid_type = "FLOW"
    fs = mod.flow_settings
    fs.flow_type = "FIRE" if k["fire"] else "SMOKE"
    fs.flow_behavior = "INFLOW"
    fs.use_initial_velocity = True
    fs.velocity_coord = (0.0, 0.0, k["speed"])
    fs.temperature = k["temperature"]

    # The inflow stops after its frames (a puff, a curl), keyframed.
    if k["inflow"] < k["bake"]:
        fs.use_inflow = True
        fs.keyframe_insert("use_inflow", frame=k["inflow"])
        fs.use_inflow = False
        fs.keyframe_insert("use_inflow", frame=k["inflow"] + 1)

    return src


def _material(dom, kind):
    k = KINDS[kind]
    mat = bpy.data.materials.new("vfx_" + kind)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    vol = nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Density"].default_value = k["density"]
    vol.inputs["Color"].default_value = (1, 1, 1, 1)

    if k["fire"]:
        # The fire glows by its temperature, as Blender's own fire does.
        vol.inputs["Blackbody Intensity"].default_value = 1.0

    links.new(vol.outputs["Volume"], out.inputs["Volume"])
    dom.data.materials.append(mat)


def _camera(kind):
    half, height = KINDS[kind]["domain"]
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = max(height, half * 2) * 1.04
    obj = bpy.data.objects.new("cam", cam)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = (0, -10, height / 2)
    obj.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.scene.camera = obj


def _lights():
    out = {}

    for name, way in LIGHTS.items():
        data = bpy.data.lights.new(name, "SUN")
        data.energy = 4.0
        obj = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(obj)
        obj.rotation_euler = Vector(way).to_track_quat("-Z", "Y").to_euler()
        out[name] = obj

    return out


def _scene(kind):
    k = KINDS[kind]
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = k.get("samples", 24)
    scene.cycles.use_denoising = True
    scene.cycles.device = "CPU"
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = k["px"]
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.frame_start, scene.frame_end = 1, k["bake"]
    world = bpy.data.worlds.new("black")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
    scene.world = world


def bake_and_render(kind, out):
    """Bakes the kind's sim and renders its frames to `out`/<kind>_<frame>_<light>.png."""
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _scene(kind)
    dom = _domain(kind)
    _flow(kind)
    _material(dom, kind)
    _camera(kind)
    lights = _lights()

    with bpy.context.temp_override(object=dom, active_object=dom, selected_objects=[dom], scene=bpy.context.scene):
        bpy.ops.fluid.bake_all()

    first, step, count = KINDS[kind]["frames"]
    scene = bpy.context.scene

    for n in range(count):
        scene.frame_set(first + n * step)

        if KINDS[kind]["fire"]:
            for light in lights.values():
                light.hide_render = True

            scene.render.filepath = str(out / ("%s_%02d_emission.png" % (kind, n)))
            bpy.ops.render.render(write_still=True)
            continue

        for name, light in lights.items():
            for other in lights.values():
                other.hide_render = other is not light

            scene.render.filepath = str(out / ("%s_%02d_%s.png" % (kind, n, name)))
            bpy.ops.render.render(write_still=True)

    print("sim_render: %s, %d frames -> %s" % (kind, count, out))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    bake_and_render(args[0], args[1])
