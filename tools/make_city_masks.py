#!/usr/bin/env python3
"""Derive the living city's masks from the menu painting: python3 tools/make_city_masks.py [--out PATH]

Writes assets/ui/main_menu/city_masks.png (same size as city.png; city.png is only read):
  R  sky: above the skyline traced below, feathered; the moon and the spire's
     thin light stay out so nothing drifts over them.
  G  lights: small bright window and street lights (1.0), plus the burning
     district's fire at 0.4 so it flickers more gently.
  B  reflections: the open lake between the near buildings.
  A  haze: the far shore and the lake, behind the near buildings.
Requires numpy and Pillow.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
CITY = ROOT / 'assets/ui/main_menu/city.png'
OUT = ROOT / 'assets/ui/main_menu/city_masks.png'

# Skyline traced over the painting, (x, top of the city) in 0..1 image space.
SKYLINE = [
    (0.0, 0.43), (0.16, 0.43), (0.165, 0.42), (0.205, 0.42), (0.21, 0.4), (0.222, 0.4),
    (0.224, 0.34), (0.268, 0.34), (0.27, 0.44), (0.33, 0.44), (0.332, 0.3), (0.348, 0.3),
    (0.349, 0.185), (0.353, 0.185), (0.354, 0.3), (0.369, 0.3), (0.371, 0.24),
    (0.495, 0.24), (0.496, 0.0), (0.504, 0.0), (0.505, 0.24), (0.615, 0.24),
    (0.618, 0.405), (0.645, 0.405), (0.65, 0.44), (0.69, 0.44), (0.7, 0.455),
    (0.733, 0.455), (0.734, 0.295), (0.788, 0.295), (0.79, 0.46), (1.0, 0.46),
]
MOON = (0.075, 0.129, 0.03)
# Open water between the near buildings, as (x0, y0, x1, y1) boxes.
LAKE = [
    (0.0, 0.698, 0.212, 0.785),
    (0.322, 0.703, 0.612, 0.772),
    (0.442, 0.772, 0.612, 0.815),
    (0.735, 0.703, 0.798, 0.8),
]
# The near buildings, in front of the lake and its haze, as (x0, y0, x1, y1).
NEAR = [
    (0.212, 0.655, 0.322, 1.0), (0.24, 0.772, 0.44, 1.0), (0.612, 0.7, 0.735, 1.0),
    (0.798, 0.625, 0.935, 1.0), (0.08, 0.8, 0.17, 1.0),
]


def sky_mask(w, h):
    image = Image.new('L', (w, h), 0)
    draw = ImageDraw.Draw(image)
    outline = [(0, 0)] + [(x * w, y * h - 24) for x, y in SKYLINE] + [(w, 0)]
    draw.polygon(outline, fill=255)
    mx, my, r = MOON
    draw.ellipse([(mx - r) * w, my * h - r * w, (mx + r) * w, my * h + r * w], fill=0)
    return np.asarray(image.filter(ImageFilter.GaussianBlur(28))).astype(np.float32) / 255.0


def light_mask(rgb):
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    lum_img = Image.fromarray((lum * 255).astype(np.uint8))
    around = np.asarray(lum_img.filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255.0
    h = rgb.shape[0]
    rows = np.arange(h)[:, None] / h
    city = (rows > 0.3) & (rows < 0.98)
    # Points of light: much brighter than their surroundings.
    points = (lum > 0.55) & (lum - around > 0.14) & city
    # Fire: saturated orange-red, in the burning district.
    fire = (rgb[..., 0] > 0.7) & (rgb[..., 0] - rgb[..., 2] > 0.4) & (rows > 0.22) & (rows < 0.62) & ~points
    out = np.where(points, 1.0, np.where(fire, 0.4, 0.0)).astype(np.float32)
    soft = Image.fromarray((out * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    return np.maximum(np.asarray(soft).astype(np.float32) / 255.0 * 1.2, out).clip(0, 1)


def lake_mask(w, h):
    image = Image.new('L', (w, h), 0)
    draw = ImageDraw.Draw(image)
    for x0, y0, x1, y1 in LAKE:
        draw.rectangle([x0 * w, y0 * h, x1 * w, y1 * h], fill=255)
    out = np.asarray(image.filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255.0
    out[: int(h * 0.6)] = 0.0
    return out


def haze_mask(w, h):
    image = Image.new('L', (w, h), 0)
    draw = ImageDraw.Draw(image)
    draw.rectangle([0, 0.6 * h, w, 0.8 * h], fill=255)
    for x0, y0, x1, y1 in NEAR:
        draw.rectangle([x0 * w, y0 * h, x1 * w, y1 * h], fill=0)
    return np.asarray(image.filter(ImageFilter.GaussianBlur(14))).astype(np.float32) / 255.0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=OUT)
    args = parser.parse_args()
    rgb = np.asarray(Image.open(CITY).convert('RGB')).astype(np.float32) / 255.0
    h, w = rgb.shape[:2]
    masks = np.stack([sky_mask(w, h), light_mask(rgb), lake_mask(w, h), haze_mask(w, h)], axis=-1)
    Image.fromarray((masks * 255).round().astype(np.uint8), 'RGBA').save(args.out)
    print(f'wrote {args.out}')


if __name__ == '__main__':
    main()
