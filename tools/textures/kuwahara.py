"""The anisotropic Kuwahara filter, in numpy: an image turned to paint. Each
texel becomes the mean of whichever of eight overlapping sectors round it is
calmest; the sectors are drawn on an ellipse that lies along the image's own
structure, so strokes follow edges and edges stay sharp while grain melts.

After Kyprianidis, Kang and Döllner, "Image and Video Abstraction by
Anisotropic Kuwahara Filtering" (Computer Graphics Forum 28(7), 2009); the
maths ported from the paper (our own code: its reference code is GPL), with
smooth cosine sectors of our own and the image wrapped at its edges so a
tiling scan stays seamless.

    anisotropic(image, radius, ...)                  the filtered image
    anisotropic(image, radius, ..., extra=normals)   and `extra` filtered with
                                                     the image's own weights

Images are float, rows x columns x channels, 0-1.
"""

import math

import numpy as np

SECTORS = 8
# How strongly the calmest sector wins (the paper's q).
SHARPNESS = 8.0
# How far the ellipse stretches along strong structure (the paper's alpha).
ALPHA = 1.0
# Smoothing of the structure tensor, in texels.
TENSOR_SIGMA = 2.0
# The sectors' widths: cos^SPREAD of the angle off each sector's axis.
SPREAD = 3.0


def _at(image, dy, dx):
    """image[y + dy, x + dx], wrapped."""
    return np.roll(image, (-dy, -dx), axis=(0, 1))


def gaussian(image, sigma):
    """A separable Gaussian blur, wrapped at the edges."""
    if sigma <= 0:
        return image

    reach = max(1, int(math.ceil(sigma * 3)))
    kernel = np.exp(-0.5 * (np.arange(-reach, reach + 1) / sigma) ** 2)
    kernel /= kernel.sum()
    out = sum(k * _at(image, 0, i - reach) for i, k in enumerate(kernel))
    return sum(k * _at(out, i - reach, 0) for i, k in enumerate(kernel))


def structure(image, sigma=TENSOR_SIGMA):
    """Per texel: the angle (radians, image space, x right and y down) along
    which the image changes least, and how strongly it is oriented (0-1)."""
    sobel_x = (_at(image, -1, 1) + 2 * _at(image, 0, 1) + _at(image, 1, 1)
               - _at(image, -1, -1) - 2 * _at(image, 0, -1) - _at(image, 1, -1)) / 8.0
    sobel_y = (_at(image, 1, -1) + 2 * _at(image, 1, 0) + _at(image, 1, 1)
               - _at(image, -1, -1) - 2 * _at(image, -1, 0) - _at(image, -1, 1)) / 8.0
    e = gaussian((sobel_x * sobel_x).sum(-1), sigma)
    f = gaussian((sobel_x * sobel_y).sum(-1), sigma)
    g = gaussian((sobel_y * sobel_y).sum(-1), sigma)
    root = np.sqrt((e - g) ** 2 + 4 * f * f)
    major, minor = (e + g + root) / 2, (e + g - root) / 2
    angle = np.arctan2(-f, major - e)
    total = major + minor
    anisotropy = np.where(total > 1e-12, (major - minor) / np.maximum(total, 1e-12), 0.0)
    return angle, anisotropy


def anisotropic(image, radius, sharpness=SHARPNESS, alpha=ALPHA, iterations=1, extra=None):
    """The image painted: see the module. With `extra` (same rows and
    columns), returns (image, extra), the extra filtered with the image's
    own sector weights and choices."""
    out, side = np.asarray(image, dtype=np.float64), None if extra is None else np.asarray(extra, dtype=np.float64)

    for _ in range(iterations):
        out, side = _once(out, radius, sharpness, alpha, side)

    return out if extra is None else (out, side)


def _once(image, radius, sharpness, alpha, extra):
    angle, anisotropy = structure(image)
    long_axis = radius * (alpha + anisotropy) / alpha
    short_axis = radius * alpha / (alpha + anisotropy)
    cos, sin = np.cos(angle), np.sin(angle)
    reach = int(math.ceil(radius * (alpha + 1) / alpha))
    axes = [2 * math.pi * k / SECTORS for k in range(SECTORS)]
    shape = image.shape[:2]
    weight = [np.zeros(shape) for _ in axes]
    mean = [np.zeros(image.shape) for _ in axes]
    square = [np.zeros(image.shape) for _ in axes]
    side = None if extra is None else [np.zeros(extra.shape) for _ in axes]

    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            # The offset in the ellipse's own frame, the ellipse a unit disc.
            u = (cos * dx + sin * dy) / long_axis
            v = (-sin * dx + cos * dy) / short_axis
            r2 = u * u + v * v
            inside = r2 <= 1.0

            if not inside.any():
                continue

            radial = np.where(inside, np.exp(-2.0 * r2), 0.0)
            theta = np.arctan2(v, u)
            neighbour = _at(image, dy, dx)
            other = None if extra is None else _at(extra, dy, dx)

            for k, axis in enumerate(axes):
                if dx == 0 and dy == 0:
                    w = radial / SECTORS            # the texel itself, shared by every sector
                else:
                    w = radial * np.maximum(0.0, np.cos(theta - axis)) ** SPREAD

                weight[k] += w
                mean[k] += w[..., None] * neighbour
                square[k] += w[..., None] * neighbour * neighbour

                if side is not None:
                    side[k] += w[..., None] * other

    spread = []

    for k in range(SECTORS):
        n = np.maximum(weight[k], 1e-12)[..., None]
        mean[k] /= n
        variance = np.maximum(square[k] / n - mean[k] ** 2, 0.0).sum(-1)
        spread.append(np.sqrt(variance))

        if side is not None:
            side[k] /= n

    # The calmest sectors win: weights (least / own) ^ q, steady in floats.
    least = np.minimum.reduce(spread)
    pick = [((least + 1e-4) / (s + 1e-4)) ** sharpness for s in spread]
    total = sum(pick)
    out = sum(p[..., None] * m for p, m in zip(pick, mean)) / total[..., None]
    out_side = None if side is None else sum(p[..., None] * s for p, s in zip(pick, side)) / total[..., None]
    return out, out_side
