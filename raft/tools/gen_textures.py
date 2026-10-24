"""Generates seamless procedural textures: water ripple normal map and an fbm noise
(foam breakup, clouds). Run from the project root: python3 tools/gen_textures.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures")
N = 512
rng = np.random.default_rng(21)
y, x = np.mgrid[0:N, 0:N] / N


def fourier(count, kmin, kmax, falloff):
    """Sum of random waves with integer wave numbers: tiles seamlessly."""
    h = np.zeros((N, N))
    for _ in range(count):
        kx, ky = rng.integers(-kmax, kmax + 1, 2)
        k = np.hypot(kx, ky)
        if k < kmin or k > kmax:
            continue
        h += np.sin(2 * np.pi * (kx * x + ky * y) + rng.uniform(0, 2 * np.pi)) / k ** falloff
    return h


def save_normal(h, strength, name):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.dstack([-gx, gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    img = ((n * 0.5 + 0.5) * 255).astype(np.uint8)
    Image.fromarray(img, "RGB").save(os.path.join(OUT, name))


def save_gray(h, name):
    h = (h - h.min()) / (h.max() - h.min())
    Image.fromarray((h * 255).astype(np.uint8), "L").save(os.path.join(OUT, name))


os.makedirs(OUT, exist_ok=True)
ripples = fourier(260, 2, 40, 1.1)
save_normal(ripples / np.abs(ripples).max(), 9.0, "water_normal.png")
save_gray(fourier(300, 1, 24, 1.3), "noise.png")
print("ok")
