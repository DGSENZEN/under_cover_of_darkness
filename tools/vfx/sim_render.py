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
from mathutils import Vector, noise

# kind -> domain (half width, height), resolution (noise upres doubles
# it), inflow frames, bake frames, the frames rendered (first, step,
# count), px, fire or not; the source: a lumpy ball (radius, squashed
# to `flat` of its height, at `at` up) emitting through a cloud texture
# (`lumps`: its size, so the smoke leaves in lumps, never a ball), with a
# speed up (leaning `lean` to the side) and out along its faces
# (`burst`); buoyancy `beta`; several
# sources at `spots` (x, y) where it burns in separate places.
KINDS = {
    # Copal: a short gout of resin smoke rising slowly, curling over and
    # breaking into curls (the particles stack them into a column).
    "plume": {"domain": (1.3, 2.8), "res": 110, "inflow": 10, "bake": 56, "frames": (22, 1, 32), "px": 128,
              "density": 60.0, "vorticity": 1.2, "fire": False, "speed": 0.35, "lean": 0.22, "radius": 0.16,
              "dissolve": 90, "temperature": 1.0, "burst": 0.1, "beta": 0.6, "flat": 0.7, "at": 1.0, "lumps": 0.12},
    # Steam and smoke: a quick puff rolling outward in lobes.
    "puff": {"domain": (1.0, 2.0), "res": 64, "inflow": 5, "bake": 42, "frames": (9, 2, 16), "px": 128,
             "density": 20.0, "vorticity": 0.9, "fire": False, "speed": 0.15, "radius": 0.18, "dissolve": 70,
             "temperature": 0.6, "burst": 0.7, "beta": 0.2, "flat": 1.0, "at": 0.7, "lumps": 0.1},
    # A brazier's bed of flames: a wide flat lumpy source, its fuel burning
    # in separate tongues.
    "fire": {"domain": (0.6, 1.3), "res": 72, "inflow": 999, "bake": 60, "frames": (30, 2, 16), "px": 128,
             "density": 0.0, "vorticity": 0.6, "fire": True, "speed": 0.3, "radius": 0.07, "dissolve": 30,
             "temperature": 1.0, "samples": 96, "burst": 0.0, "beta": 1.0, "flat": 0.6, "at": 0.1, "lumps": 0.08,
             "spots": [(-0.21, 0.04), (-0.07, -0.08), (0.07, 0.07), (0.21, -0.03)]},
}
# Flame (0..1) to colour: deep red to orange to gold, never white.
FLAME_RAMP = [(0.0, (0.25, 0.03, 0.0)), (0.35, (0.9, 0.25, 0.02)), (0.7, (1.0, 0.6, 0.12)), (1.0, (1.0, 0.8, 0.35))]
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
    ds.beta = k["beta"]
    # Upres noise: curls and wisps finer than the grid.
    ds.use_noise = True
    ds.noise_scale = 2
    ds.noise_strength = 1.4
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
        ds.flame_vorticity = 0.8
        ds.burning_rate = 0.85
        # (The brazier's smoke is its own particles.)
        ds.flame_smoke = 0.0

    return dom


def _flow(kind):
    return [_source(kind, x, y, n) for n, (x, y) in enumerate(KINDS[kind].get("spots", [(0.0, 0.0)]))]


def _source(kind, x, y, n):
    k = KINDS[kind]
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=k["radius"], location=(x, y, k["at"]))
    src = bpy.context.object
    src.scale.z = k["flat"]
    # Lumpy: pushed in and out by a smooth noise over its surface.
    for v in src.data.vertices:
        v.co *= 1.0 + 0.45 * noise.noise(v.co.normalized() * 2.2 + Vector((3.1 + n, 7.4, 1.9)))

    # (The source makes smoke; it is never seen.)
    src.hide_render = True
    mod = src.modifiers.new("fluid", "FLUID")
    mod.fluid_type = "FLOW"
    fs = mod.flow_settings
    fs.flow_type = "FIRE" if k["fire"] else "SMOKE"
    fs.flow_behavior = "INFLOW"
    fs.flow_source = "MESH"
    fs.volume_density = 1.0
    fs.surface_distance = 0.05
    fs.use_initial_velocity = True
    fs.velocity_coord = (k.get("lean", 0.0), 0.0, k["speed"])
    fs.velocity_normal = k["burst"]
    fs.temperature = k["temperature"]
    # Through a cloud texture: the smoke (or fuel) leaves in lumps.
    clouds = bpy.data.textures.new("lumps", "CLOUDS")
    clouds.noise_scale = k["lumps"]
    clouds.noise_depth = 2
    clouds.contrast = 1.6
    fs.use_texture = True
    fs.noise_texture = clouds
    fs.texture_map_type = "AUTO"
    fs.texture_size = 1.0

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
        # The fire glows by its flame, through our own ramp (deep red to
        # gold): never a white-hot ball at its foot.
        flame = nodes.new("ShaderNodeAttribute")
        flame.attribute_name = "flame"
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])

        for n, (at, colour) in enumerate(FLAME_RAMP):
            e = ramp.color_ramp.elements[0] if n == 0 else ramp.color_ramp.elements.new(at)
            e.position = at
            e.color = colour + (1.0,)

        links.new(flame.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], vol.inputs["Emission Color"])
        boost = nodes.new("ShaderNodeMath")
        boost.operation = "MULTIPLY"
        # (Emission adds up through the flames' depth: much more and every
        # channel clips to white.)
        boost.inputs[1].default_value = 2.0
        links.new(flame.outputs["Fac"], boost.inputs[0])
        links.new(boost.outputs["Value"], vol.inputs["Emission Strength"])

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
