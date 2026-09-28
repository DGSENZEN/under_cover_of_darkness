"""The effect sheets, made here and nowhere else (no downloaded effects):

    tools/props/props.sh flames          every sheet below
    tools/props/props.sh cookie          the hanging lantern's light cookie

  assets/vfx/flame_<sheet>.png   heat flipbooks: a strip of frames, grey,
                                 16 heat levels (0 = nothing there)
  assets/vfx/smoke.png           4 puffs, white, alpha 0 / 128 / 255
  assets/vfx/corona.png          the halo's falloff, grey, 16 levels
  assets/vfx/soot.png            a soot streak rising from a flame, black
  assets/vfx/ramps/<name>.png    64x1 colour ramps: heat -> colour

A flame is rendered, not painted. Cycles renders Blender's own 4D Noise
Texture onto a plane, three noises at once (red, green and blue), one
render a frame. The noise's fourth coordinate and one spatial coordinate
go round a circle over the loop, so the last frame runs into the first.
Numpy then shapes a teardrop of heat from them: the first two noises warp
it (more toward the tip, where flames lick), the third eats holes into its
upper half so tongues pinch off and rise, and its base stays on the fuel.
Rendered at 4x, averaged down, cut to 16 levels. The heat becomes colour in
the game (scripts/Visual/Lights/flame.gdshader) through a ramp, so a
dying or guttering flame is a ramp away.

Run headless: Blender -b --factory-startup --python flames.py -- all
"""

import math
import os
import shutil
import struct
import sys
import tempfile
import time
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
VFX = ROOT / "assets" / "vfx"
# What a sheet is written over is kept here first (gitignored, as the
# props' own backups).
BACKUP = ROOT / "assets" / "props" / "source" / "backup"
SUPERSAMPLE = 4

# sheet: frame width, height, frames, and the flame's make: half-width at the
# base (in frame heights), taper, warp, tongue bite, noise scales, how far
# round the loop circle it travels (bigger = it changes shape more), sway.
SHEETS = {
    "candle": dict(size=(8, 16), frames=5, half=0.13, taper=0.5, warp=0.05, bite=0.25, scale=(1.6, 3.0), loop=0.45, sway=0.05),
    "small": dict(size=(16, 24), frames=6, half=0.18, taper=0.55, warp=0.08, bite=0.5, scale=(2.0, 4.0), loop=0.6, sway=0.03),
    "torch": dict(size=(32, 64), frames=8, half=0.2, taper=0.55, warp=0.12, bite=0.9, scale=(2.2, 5.0), loop=0.9, sway=0.0),
    "brazier": dict(size=(64, 64), frames=10, half=0.44, taper=0.7, warp=0.18, bite=1.9, scale=(2.4, 6.5), loop=0.8, sway=0.0),
    "fire": dict(size=(64, 96), frames=12, half=0.3, taper=0.7, warp=0.17, bite=1.8, scale=(2.2, 5.5), loop=0.7, sway=0.0),
}

# ramp: (position, colour) stops; the first is the cut (transparent before it).
RAMPS = {
    "torch": [(0.12, "5A0A02"), (0.35, "C8320A"), (0.55, "FF8200"), (0.75, "FFB040"), (0.9, "FFE8A0"), (1.0, "FFFFF0")],
    "brazier": [(0.14, "4A0802"), (0.4, "B42808"), (0.6, "FF7A00"), (0.8, "FFAE3C"), (1.0, "FFF4C8")],
    "fire": [(0.12, "500902"), (0.4, "B42808"), (0.65, "FF8D0B"), (0.8, "FFAE3C"), (1.0, "FFF4C8")],
    "candle": [(0.2, "7A1E04"), (0.45, "FF8200"), (0.7, "FFB85A"), (0.9, "FFF0C0"), (1.0, "FFFFFF")],
    "lamp": [(0.2, "7A1E04"), (0.45, "FF7800"), (0.7, "FFB85A"), (0.9, "FFF0C0"), (1.0, "FFFFFF")],
    "dying": [(0.2, "3C0602"), (0.5, "8C1C04"), (0.8, "D2500A"), (1.0, "FF9A3C")],
    "gutter": [(0.2, "1E2A6E"), (0.35, "7A1E04"), (0.6, "FF7800"), (1.0, "FFE0A0")],
}


# ---------------------------------------------------------------------------
# PNG out (exact bytes: no colour management between the numbers and the file)
# ---------------------------------------------------------------------------

def write_png(path, pixels, backup_dir=BACKUP):
    """8-bit PNG from a uint8 array, (h, w) grey or (h, w, 4) RGBA, top row
    first; whatever was at `path` is copied into `backup_dir` first."""
    path = Path(path)

    if path.exists():
        backup_dir = Path(backup_dir)
        backup_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, backup_dir / ("%s.%d%s" % (path.stem, time.time_ns(), path.suffix)))

    pixels = np.ascontiguousarray(pixels, dtype=np.uint8)
    height, width = pixels.shape[:2]
    colour_type = 0 if pixels.ndim == 2 else 6
    rows = b"".join(b"\x00" + pixels[y].tobytes() for y in range(height))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, colour_type, 0, 0, 0)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def quantise(values, levels):
    """0..1 floats to `levels` evenly spaced bytes (0 and 255 included)."""
    steps = levels - 1
    return (np.round(np.clip(values, 0.0, 1.0) * steps) * (255 // steps)).astype(np.uint8)


# ---------------------------------------------------------------------------
# The noise, rendered by Cycles
# ---------------------------------------------------------------------------

class NoiseStage:
    """A plane in the XZ plane (x across the frame, z up from the fuel at 0 to
    1), an orthographic camera on it, and an emission shader showing three
    4D noises as red, green and blue."""

    def __init__(self, aspect, width, height, scales):
        import bpy

        self.bpy = bpy
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene = bpy.context.scene
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = 16
        scene.cycles.use_denoising = False
        scene.cycles.max_bounces = 0
        scene.cycles.seed = 0
        scene.cycles.pixel_filter_type = "BOX"
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        scene.render.resolution_percentage = 100
        scene.render.image_settings.file_format = "OPEN_EXR"
        scene.render.image_settings.color_depth = "32"
        scene.view_settings.view_transform = "Standard"

        world = bpy.data.worlds.new("Black")
        world.color = (0.0, 0.0, 0.0)
        scene.world = world

        mesh = bpy.data.meshes.new("Plane")
        half = aspect * 0.5
        mesh.from_pydata([(-half, 0.0, 0.0), (half, 0.0, 0.0), (half, 0.0, 1.0), (-half, 0.0, 1.0)], [], [(0, 1, 2, 3)])
        plane = bpy.data.objects.new("Plane", mesh)
        scene.collection.objects.link(plane)

        material = bpy.data.materials.new("Noise")
        material.use_nodes = True
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        nodes.clear()
        coords = nodes.new("ShaderNodeTexCoord")
        self.loop = nodes.new("ShaderNodeVectorMath")
        self.loop.operation = "ADD"
        links.new(coords.outputs["Object"], self.loop.inputs[0])
        combine = nodes.new("ShaderNodeCombineColor")
        self.noises = []

        for index, (scale, detail) in enumerate([(scales[0], 3.0), (scales[0] * 1.1, 3.0), (scales[1], 4.0)]):
            noise = nodes.new("ShaderNodeTexNoise")
            noise.noise_dimensions = "4D"
            noise.inputs["Scale"].default_value = scale
            noise.inputs["Detail"].default_value = detail
            noise.inputs["Roughness"].default_value = 0.55
            noise.inputs["Distortion"].default_value = 0.6
            links.new(self.loop.outputs[0], noise.inputs["Vector"])
            links.new(noise.outputs["Fac"], combine.inputs[index])
            self.noises.append(noise)

        emission = nodes.new("ShaderNodeEmission")
        emission.inputs["Strength"].default_value = 1.0
        links.new(combine.outputs[0], emission.inputs["Color"])
        out = nodes.new("ShaderNodeOutputMaterial")
        links.new(emission.outputs[0], out.inputs["Surface"])
        plane.data.materials.append(material)

        camera_data = bpy.data.cameras.new("Camera")
        camera_data.type = "ORTHO"
        camera_data.ortho_scale = max(aspect, 1.0)
        camera = bpy.data.objects.new("Camera", camera_data)
        camera.location = (0.0, -5.0, 0.5)
        camera.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
        scene.collection.objects.link(camera)
        scene.camera = camera
        self.width = width
        self.height = height

    def render(self, angle, radius):
        """The three noises at this point round the loop: (h, w, 3), top row first."""
        bpy = self.bpy
        # Round the circle in (y, w): y is free, since the plane lies at y = 0.
        self.loop.inputs[1].default_value = (0.0, radius * math.cos(angle), 0.0)

        for index, noise in enumerate(self.noises):
            noise.inputs["W"].default_value = radius * math.sin(angle) + 7.3 * index

        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "frame.exr")
            bpy.context.scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            image = bpy.data.images.load(path, check_existing=False)
            pixels = np.array(image.pixels[:], dtype=np.float64).reshape(self.height, self.width, 4)
            bpy.data.images.remove(image)

        return pixels[::-1, :, :3]


# ---------------------------------------------------------------------------
# Flames
# ---------------------------------------------------------------------------

def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def flame_heat(noise, aspect, make, angle):
    """Heat 0..1 over one frame from its three noises (see the module's words)."""
    height, width = noise.shape[:2]
    x = ((np.arange(width) + 0.5) / width * aspect - aspect * 0.5)[None, :]
    z = (1.0 - (np.arange(height) + 0.5) / height)[:, None]
    up = np.clip(z, 0.0, 1.0)
    lick = noise[:, :, 0] - 0.5
    rise = noise[:, :, 1] - 0.5
    bite = noise[:, :, 2]

    xw = x + 2.0 * make["warp"] * lick * up ** 1.2 + make["sway"] * math.sin(angle) * up ** 1.5
    zw = z + 1.2 * make["warp"] * rise * up
    # Round at the bottom (it sits on its fuel, narrower there), widest a
    # fifth of the way up, then tapering to the tip.
    base = 0.45 + 0.55 * smoothstep(0.0, 0.22, zw)
    half = make["half"] * np.power(np.clip(1.0 - zw, 0.0, 1.0), make["taper"]) * base
    body = np.clip(1.0 - np.abs(xw) / np.maximum(half, 1e-4), 0.0, 1.0)
    heat = body ** 0.9 * (1.0 - np.clip(zw, 0.0, 1.0) ** 1.6) * 0.9
    # A small hot heart low in the flame, not a white half.
    core = 0.3 * np.exp(-((xw / (0.3 * make["half"])) ** 2 + ((zw - 0.16) / 0.12) ** 2))
    heat = heat + core * body
    heat = heat - make["bite"] * up ** 0.9 * np.clip(bite - 0.42, 0.0, 1.0) * 2.2
    heat = heat * smoothstep(-0.01, 0.07, zw)
    return np.clip(heat, 0.0, 1.0)


def make_flame(name):
    make = SHEETS[name]
    width, height = make["size"]
    aspect = width / height
    stage = NoiseStage(aspect, width * SUPERSAMPLE, height * SUPERSAMPLE, make["scale"])
    frames = []

    for index in range(make["frames"]):
        angle = 2.0 * math.pi * index / make["frames"]
        heat = flame_heat(stage.render(angle, make["loop"]), aspect, make, angle)
        # Averaged down to the frame's own pixels.
        heat = heat.reshape(height, SUPERSAMPLE, width, SUPERSAMPLE).mean(axis=(1, 3))
        frames.append(quantise(heat, 16))

    write_png(VFX / ("flame_%s.png" % name), np.concatenate(frames, axis=1))
    print("flame_%s: %d frames of %dx%d" % (name, make["frames"], width, height))


# ---------------------------------------------------------------------------
# Smoke, corona, soot, ramps
# ---------------------------------------------------------------------------

def make_smoke(seed=11):
    rng = np.random.default_rng(seed)
    side = 32
    yy, xx = np.mgrid[0:side, 0:side] / side - 0.5
    puffs = []

    for _ in range(4):
        field = np.zeros((side, side))

        for _ in range(rng.integers(3, 6)):
            cx, cy = rng.uniform(-0.18, 0.18, 2)
            radius = rng.uniform(0.12, 0.22)
            field += np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (2.0 * radius ** 2))

        field /= field.max()
        field *= 0.85 + 0.3 * rng.random((side, side))
        alpha = np.where(field > 0.62, 255, np.where(field > 0.36, 128, 0)).astype(np.uint8)
        puff = np.full((side, side, 4), 255, dtype=np.uint8)
        puff[:, :, 3] = alpha
        puffs.append(puff)

    write_png(VFX / "smoke.png", np.concatenate(puffs, axis=1))


def make_corona():
    side = 64
    yy, xx = np.mgrid[0:side, 0:side]
    r = np.hypot(xx + 0.5 - side / 2, yy + 0.5 - side / 2) / (side / 2)
    # A hot heart in a faint haze (never a lit ball), gone before its edge.
    glow = 0.72 * np.exp(-(r / 0.16) ** 2) + 0.28 * np.exp(-(r / 0.42) ** 2)
    write_png(VFX / "corona.png", quantise(np.clip(glow * np.clip((1.0 - r) / 0.2, 0.0, 1.0), 0.0, 1.0), 16))


def make_soot(seed=5):
    rng = np.random.default_rng(seed)
    side = 128
    yy, xx = np.mgrid[0:side, 0:side] / side
    x = xx - 0.5
    up = 1.0 - yy  # 0 at the bottom (the flame), 1 at the top
    spread = 0.06 + 0.32 * up
    column = np.exp(-(x / spread) ** 2) * (1.0 - up ** 1.4)
    cells = rng.random((17, 17))
    blotch = np.kron(cells, np.ones((8, 8)))[:side, :side]
    alpha = np.clip(column * (0.65 + 0.5 * blotch), 0.0, 1.0)
    soot = np.zeros((side, side, 4), dtype=np.uint8)
    soot[:, :, 3] = (np.round(alpha * 7) * 36).astype(np.uint8)
    write_png(VFX / "soot.png", soot)


def make_ramp(name):
    stops = [(p, np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)) for p, c in RAMPS[name]]
    ramp = np.zeros((1, 64, 4), dtype=np.uint8)

    for column in range(64):
        h = column / 63.0

        if h < stops[0][0]:
            continue

        colour = stops[-1][1]

        for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
            if p0 <= h <= p1:
                colour = c0 + (c1 - c0) * ((h - p0) / max(p1 - p0, 1e-9))
                break

        ramp[0, column, :3] = np.round(colour).astype(np.uint8)
        ramp[0, column, 3] = 255

    path = VFX / "ramps" / (name + ".png")
    write_png(path, ramp)
    # Ramps are looked up exactly: no mipmaps blurring the stops together.
    importer = path.with_suffix(".png.import")

    if not importer.exists():
        importer.write_text(RAMP_IMPORT.format(source="res://" + str(path.relative_to(ROOT))))


RAMP_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="{source}"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def main(argv):
    what = argv[0] if argv else "all"

    if what in ("all", "flames"):
        for name in SHEETS:
            make_flame(name)

    if what in ("all", "sprites"):
        make_smoke()
        make_corona()
        make_soot()

        for name in RAMPS:
            make_ramp(name)

        print("smoke, corona, soot and %d ramps" % len(RAMPS))

    if what == "cookie":
        make_cookie()


def make_cookie():
    """The hanging lantern's light cookie: what its flame sees all round it
    (an equirectangular panorama from the flame socket), the frame and roof
    black, the horn panes letting the light through."""
    import bpy

    source = ROOT / "assets" / "props" / "source" / "hanging_lantern.blend"

    if not source.exists():
        raise SystemExit("build the hanging lantern first (props.sh all hanging_lantern)")

    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene = bpy.context.scene
    flame = bpy.data.objects["socket:flame:0"].location.copy()

    for material in bpy.data.materials:
        material.use_nodes = True
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        nodes.clear()
        out = nodes.new("ShaderNodeOutputMaterial")

        if material.name.startswith("horn"):
            shader = nodes.new("ShaderNodeBsdfTransparent")
            shader.inputs["Color"].default_value = (0.75, 0.75, 0.75, 1.0)
        else:
            # Not quite black: a little light gets round the iron (bounce),
            # or the floor under a lantern would be pitch dark.
            shader = nodes.new("ShaderNodeEmission")
            shader.inputs["Strength"].default_value = 0.12

        links.new(shader.outputs[0], out.inputs["Surface"])

    for obj in scene.objects:
        if obj.type == "MESH" and obj.name.endswith("wick"):
            obj.hide_render = True

    world = bpy.data.worlds.new("White")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    scene.world = world
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 512
    scene.render.resolution_y = 256
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "OPEN_EXR"
    scene.view_settings.view_transform = "Standard"
    camera_data = bpy.data.cameras.new("Cookie")
    camera_data.type = "PANO"
    camera_data.panorama_type = "EQUIRECTANGULAR"
    camera = bpy.data.objects.new("Cookie", camera_data)
    camera.location = flame
    camera.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
    scene.collection.objects.link(camera)
    scene.camera = camera

    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "cookie.exr")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        image = bpy.data.images.load(path, check_existing=False)
        pixels = np.array(image.pixels[:], dtype=np.float64).reshape(256, 512, 4)[::-1, :, 0]

    write_png(VFX / "cookie_lantern.png", np.round(np.clip(pixels, 0.0, 1.0) * 255.0).astype(np.uint8))
    print("cookie_lantern: 512x256")


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
