"""Paints the item texture sheet: fish skins, fins, eyes, shark meat, steak, plastic scraps,
dried fish and soup (4x4 cells of 256 px), used by view/food_looks.gd.

Run from the project root:  python3 tools/gen_item_tex.py
Writes assets/textures/items.png. Skins are laid out nose (left) -> tail (right),
back (top) -> belly (bottom); fins have their root on the left edge, middle height.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 256
SS = 2                      # paint at 2x, then downsample
S = CELL * SS
GRID = 4

# name -> (col, row); keep in step with FoodLooks.CELLS
CELLS = {
    "fish": (0, 0), "fish_cooked": (1, 0), "tuna": (2, 0), "tuna_cooked": (3, 0),
    "fin": (0, 1), "fin_cooked": (1, 1), "fin_tuna": (2, 1), "eyes": (3, 1),
    "flesh": (0, 2), "meat_side": (1, 2), "steak_top": (2, 2), "steak_side": (3, 2),
    "bottle": (0, 3), "crate": (1, 3), "dried": (2, 3), "soup": (3, 3),
}


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def grid():
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    return x / (S - 1), y / (S - 1)


def noise(seed, scale, octaves=4):
    """Smooth value noise in 0..1, tileable enough for small cells."""
    rnd = np.random.default_rng(seed)
    out = np.zeros((S, S), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = max(2, int(scale * (2 ** o)))
        small = rnd.random((n + 1, n + 1)).astype(np.float32)
        im = Image.fromarray((small * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)
        out += np.asarray(im, np.float32) / 255.0 * amp
        tot += amp
        amp *= 0.5
    return out / tot


def ramp(t, stops):
    """Color along t (0..1) through [(pos, hex), ...]."""
    t = np.clip(t, 0.0, 1.0)
    out = np.zeros(t.shape + (3,), np.float32)
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        m = (t >= p0) & (t <= p1)
        k = ((t - p0) / max(1e-6, p1 - p0))[..., None]
        k = k * k * (3 - 2 * k)
        out = np.where(m[..., None], hexc(c0) * (1 - k) + hexc(c1) * k, out)
    return out


def to_img(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")


def from_img(im):
    return np.asarray(im.convert("RGB"), np.float32)


def mix(a, color, mask):
    m = np.clip(mask, 0, 1)[..., None]
    return a * (1 - m) + (hexc(color) if isinstance(color, str) else color) * m


def stroke_mask(draw_fn, blur=1.5):
    m = Image.new("L", (S, S), 0)
    draw_fn(ImageDraw.Draw(m))
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur * SS))
    return np.asarray(m, np.float32) / 255.0


def scales(a, x, y, strength, size=0.035):
    """Fine overlapping scale arcs, stronger on the back."""
    m = stroke_mask(lambda d: [d.arc([cx - r, cy - r, cx + r, cy + r], 200, 340, fill=255, width=SS)
                               for r in [int(size * S)]
                               for row in range(-1, int(1 / size) + 2)
                               for col in range(-1, int(1 / size / 2) + 2)
                               for cx, cy in [(col * 2 * r + (r if row % 2 else 0), row * r)]], 0.6)
    return a * (1 - m[..., None] * strength)


def specks(a, seed, count, color, size, alpha):
    """Tiny sparse dots (salt, fat, blisters)."""
    rnd = random.Random(seed)

    def dots(d):
        for _ in range(count):
            cx, cy = rnd.uniform(0, S), rnd.uniform(0, S)
            r = rnd.uniform(0.5, 1.0) * size * SS
            d.ellipse([cx - r, cy - r * 0.7, cx + r, cy + r * 0.7], fill=255)
    return mix(a, color, stroke_mask(dots, 0.4) * alpha)


def shine(a, y, at, width, amount):
    k = np.exp(-((y - at) / width) ** 2)
    return a + (255 - a) * (k * amount)[..., None]


# ---------- fish skins ----------

def mackerel():
    x, y = grid()
    n = noise(1, 6)
    a = ramp(y + (n - 0.5) * 0.04, [(0.0, "#163f52"), (0.3, "#2b6f86"), (0.44, "#5aa3b0"),
                                    (0.52, "#c6d6da"), (0.75, "#eef3f2"), (1.0, "#f7f8f4")])
    # Tiger bars on the back, wavy, from the head to the tail.
    def bars(d):
        rnd = random.Random(3)
        for k in range(16):
            x0 = (0.24 + k * 0.047) * S
            pts = []
            for t in np.linspace(0, 1, 14):
                yy = t * 0.42 * S
                xx = x0 + math.sin(t * 7 + k) * 0.018 * S + t * 0.05 * S + rnd.uniform(-2, 2)
                pts.append((xx, yy))
            d.line(pts, fill=255, width=int(0.016 * S))
    a = mix(a, "#0a2230", stroke_mask(bars, 1.0) * np.clip((0.46 - y) * 8, 0, 1) * 0.9)
    # Head: darker top, gill cover arc, mouth.
    a = mix(a, "#0f3344", np.clip((0.22 - x) * 5, 0, 1) * np.clip((0.45 - y) * 3, 0, 1) * 0.5)
    a = mix(a, "#7f9aa2", stroke_mask(lambda d: d.arc([-0.1 * S, 0.22 * S, 0.24 * S, 0.8 * S], -70, 70, fill=255, width=int(0.012 * S)), 1.2) * 0.8)
    a = mix(a, "#2a3236", stroke_mask(lambda d: d.line([(0, 0.56 * S), (0.07 * S, 0.53 * S)], fill=255, width=int(0.012 * S)), 1.0))
    # Lateral line and a wet shine.
    a = mix(a, "#e9f2f2", stroke_mask(lambda d: d.line([(0.2 * S, 0.43 * S), (S, 0.47 * S)], fill=255, width=SS * 2), 0.8) * 0.6)
    a = shine(a, y, 0.47, 0.04, 0.2)
    a = scales(a, x, y, 0.1)
    return a * (0.92 + 0.16 * noise(2, 20, 2))[..., None]


def tuna():
    x, y = grid()
    n = noise(5, 5)
    a = ramp(y + (n - 0.5) * 0.03, [(0.0, "#0d1a33"), (0.3, "#1d3460"), (0.42, "#4d6a92"),
                                    (0.5, "#a8b6c4"), (0.7, "#dfe5ea"), (1.0, "#f2f4f4")])
    # A golden stripe along the side, and broken vertical belly lines.
    a = mix(a, "#e6b84a", stroke_mask(lambda d: d.line([(0.14 * S, 0.4 * S), (0.85 * S, 0.43 * S)], fill=255, width=int(0.03 * S)), 3.0) * 0.55)

    def belly(d):
        rnd = random.Random(8)
        for k in range(22):
            xx = (0.3 + k * 0.03) * S
            for j in range(4):
                y0 = (0.6 + j * 0.08 + rnd.uniform(-0.01, 0.01)) * S
                d.line([(xx, y0), (xx + 0.01 * S, y0 + 0.05 * S)], fill=255, width=SS * 2)
    a = mix(a, "#9aa6b2", stroke_mask(belly, 0.8) * 0.7)
    a = mix(a, "#0a1426", np.clip((0.2 - x) * 5, 0, 1) * np.clip((0.48 - y) * 3, 0, 1) * 0.5)
    a = mix(a, "#5d7084", stroke_mask(lambda d: d.arc([-0.1 * S, 0.2 * S, 0.22 * S, 0.82 * S], -70, 70, fill=255, width=int(0.012 * S)), 1.2) * 0.8)
    a = mix(a, "#20262a", stroke_mask(lambda d: d.line([(0, 0.57 * S), (0.06 * S, 0.55 * S)], fill=255, width=int(0.012 * S)), 1.0))
    a = shine(a, y, 0.47, 0.05, 0.3)
    a = scales(a, x, y, 0.08, 0.03)
    return a * (0.93 + 0.14 * noise(6, 22, 2))[..., None]


def cooked(seed, stops, char):
    """Grilled skin: browned, blistered, dark grill bars and charred edges."""
    x, y = grid()
    n = noise(seed, 7)
    a = ramp(y + (n - 0.5) * 0.12, stops)
    blist = noise(seed + 1, 18, 3)
    a = a * (0.85 + 0.3 * blist)[..., None]

    def marks(d):
        for k in range(-2, 9):
            x0 = (0.06 + k * 0.13) * S
            d.line([(x0, -0.1 * S), (x0 + 0.35 * S, 1.1 * S)], fill=255, width=int(0.045 * S))
    a = mix(a, char, stroke_mask(marks, 3.0) * 0.85)
    edge = np.clip((x - 0.86) * 7, 0, 1) + np.clip((0.05 - x) * 12, 0, 1) + np.clip((0.06 - y) * 10, 0, 1)
    a = mix(a, char, edge * 0.6 * (0.6 + 0.4 * n))
    # Cracked skin and a little oil shine.
    a = specks(a, seed + 2, 260, "#f2cf96", 1.6, 0.35)
    a = shine(a, y, 0.5, 0.04, 0.07)
    return a


# ---------- fins and eyes ----------

def fin(base, ray, tip, seed):
    x, y = grid()
    a = ramp(x, [(0.0, base), (1.0, tip)])

    def rays(d):
        for k in range(15):
            ang = -1.15 + k * (2.3 / 14)
            d.line([(0, S / 2), (S * 1.2 * math.cos(ang), S / 2 + S * 1.2 * math.sin(ang) * 0.75)], fill=255, width=SS * 2)
    a = mix(a, ray, stroke_mask(rays, 0.8) * (0.4 + 0.6 * x))
    return a * (0.94 + 0.12 * noise(seed, 12, 2))[..., None]


def eyes():
    a = np.full((S, S, 3), 200, np.float32)
    im = to_img(a)
    d = ImageDraw.Draw(im)
    h = S // 2
    specs = [  # quadrant -> rings (radius fraction, color)
        (0, 0, [(1.0, "#c9b067"), (0.82, "#e8d595"), (0.62, "#111316"), (0.18, "#ffffff")]),     # fresh fish
        (1, 0, [(1.0, "#8a7356"), (0.82, "#d9d4c8"), (0.5, "#a49a8a"), (0.0, "#000000")]),      # cooked: milky
        (0, 1, [(1.0, "#5d6f86"), (0.84, "#9fb0c4"), (0.66, "#0b0d10"), (0.18, "#ffffff")]),     # tuna
        (1, 1, [(1.0, "#151515"), (0.6, "#2a2a2a"), (0.25, "#ffffff")]),                         # bird
    ]
    for qx, qy, rings in specs:
        cx, cy = qx * h + h / 2, qy * h + h / 2
        d.rectangle([qx * h, qy * h, qx * h + h, qy * h + h], fill=rings[0][1])
        for r, c in rings[1:]:
            if r <= 0:
                continue
            rr = h * 0.48 * r
            off = (h * 0.12, -h * 0.12) if c == "#ffffff" else (0, 0)
            d.ellipse([cx - rr + off[0], cy - rr + off[1], cx + rr + off[0], cy + rr + off[1]], fill=c)
    return from_img(im.filter(ImageFilter.GaussianBlur(SS * 0.8)))


# ---------- meat ----------

def chevrons(d, step, width, amp):
    for k in range(-2, int(1 / step) + 3):
        x0 = k * step * S
        pts = [(x0 + amp * S * abs(math.sin(t * math.pi)) - amp * S * 0.5, t * S) for t in np.linspace(0, 1, 24)]
        d.line(pts, fill=255, width=width)


def flesh():
    x, y = grid()
    n = noise(11, 5)
    a = ramp(n, [(0.0, "#d98888"), (0.5, "#e8a7a0"), (1.0, "#f1c3b8")])
    a = mix(a, "#fae6e0", stroke_mask(lambda d: chevrons(d, 0.09, int(0.012 * S), 0.12), 1.0) * 0.85)
    a = mix(a, "#b04848", stroke_mask(lambda d: d.line([(0, 0.52 * S), (S, 0.48 * S)], fill=255, width=int(0.03 * S)), 4.0) * 0.45)
    a = specks(a, 12, 300, "#ffffff", 1.2, 0.3)
    return a * (0.93 + 0.12 * noise(13, 25, 2))[..., None]


def meat_side():
    """A cut side: pink flesh above, a white fat line, gray shark skin at the bottom."""
    x, y = grid()
    a = flesh()
    skin = ramp(y, [(0.0, "#7d8c99"), (0.68, "#7d8c99"), (1.0, "#4a5866")]) * (0.85 + 0.25 * noise(14, 40, 2))[..., None]
    border = 0.7 + (noise(15, 4, 2) - 0.5) * 0.06
    a = np.where((y > border)[..., None], skin, a)
    a = mix(a, "#f4ece4", np.exp(-((y - border) / 0.018) ** 2) * 0.9)
    return a


def steak_top():
    x, y = grid()
    dx, dy = x - 0.5, y - 0.5
    r = np.sqrt((dx / 0.5) ** 2 + (dy / 0.5) ** 2)
    n = noise(21, 6)
    a = ramp(r + (n - 0.5) * 0.25, [(0.0, "#cf9356"), (0.55, "#b8743e"), (0.85, "#8a4c24"), (1.0, "#5a2c12")])
    # Faint growth rings of a shark steak.
    rings = (np.sin(r * 38 + n * 4) * 0.5 + 0.5) ** 6
    a = mix(a, "#e6b47a", rings * 0.25 * (r < 0.85))

    def marks(d):
        for k in range(-3, 4):
            x0 = (0.5 + k * 0.16) * S
            d.line([(x0 - 0.3 * S, -0.05 * S), (x0 + 0.3 * S, 1.05 * S)], fill=255, width=int(0.05 * S))
    a = mix(a, "#2e150a", stroke_mask(marks, 3.5) * 0.85)

    def cross(d):
        for k in range(-3, 4):
            x0 = (0.5 + k * 0.2) * S
            d.line([(x0 + 0.3 * S, -0.05 * S), (x0 - 0.3 * S, 1.05 * S)], fill=255, width=int(0.035 * S))
    a = mix(a, "#4a2410", stroke_mask(cross, 3.5) * 0.45)
    a = specks(a, 22, 220, "#ffe0b0", 1.5, 0.45)     # glistening fat
    return a * (0.9 + 0.18 * noise(23, 30, 2))[..., None]


def steak_side():
    x, y = grid()
    n = noise(31, 8)
    a = ramp(np.abs(y - 0.5) * 2 + (n - 0.5) * 0.3, [(0.0, "#a86a3a"), (0.6, "#7a4320"), (1.0, "#3e1f0c")])
    fibres = stroke_mask(lambda d: [d.line([(0, (0.1 + k * 0.09) * S), (S, (0.12 + k * 0.09) * S)], fill=255, width=SS) for k in range(10)], 0.6)
    a = mix(a, "#c99060", fibres * 0.3)
    a = mix(a, "#5b5048", np.clip((noise(32, 6, 2) - 0.55) * 5, 0, 1) * 0.5)   # bits of skin
    return a * (0.9 + 0.2 * noise(33, 30, 2))[..., None]


# ---------- plastic ----------

def bottle():
    """A crushed PET bottle unrolled: aqua, ribbed, creased, a label, a red cap at the right."""
    x, y = grid()
    n = noise(41, 5)
    a = ramp(y, [(0.0, "#b9e3f0"), (0.5, "#8fcbe2"), (1.0, "#b9e3f0")]) * (0.95 + 0.1 * n)[..., None]
    ribs = (np.sin(x * 70) * 0.5 + 0.5) ** 3
    a = mix(a, "#e8f7fc", ribs * 0.35 * (x < 0.3))

    def creases(d):
        rnd = random.Random(42)
        for k in range(14):
            x0, y0 = rnd.uniform(0, 1) * S, rnd.uniform(0, 1) * S
            ang = rnd.uniform(-1.2, 1.2)
            ln = rnd.uniform(0.15, 0.4) * S
            d.line([(x0, y0), (x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln)], fill=255, width=SS * 3)
    cm = stroke_mask(creases, 1.0)
    a = mix(a, "#ffffff", cm * 0.7)
    a = mix(a, "#5aa0c0", np.roll(cm, SS * 4, axis=0) * 0.5)
    # The label: white band with a blue wave and a red stripe.
    band = (x > 0.36) & (x < 0.66)
    a = np.where(band[..., None], mix(a, "#f4f6f2", np.ones_like(x) * 0.95), a)
    wave = np.abs(y - (0.5 + 0.12 * np.sin((x - 0.36) * 30))) < 0.06
    a = np.where((band & wave)[..., None], hexc("#2a6fc4"), a)
    a = np.where((band & (np.abs(y - 0.22) < 0.03))[..., None], hexc("#d8352a"), a)
    a = np.where((x > 0.92)[..., None], hexc("#d23a2a") * (0.9 + 0.2 * n)[..., None], a)
    a = mix(a, "#ffffff", (np.sin(y * 40) > 0.97) * (x > 0.86) * (x < 0.92) * 0.5)
    return a


def crate():
    """A broken piece of an orange plastic crate: ribs and square holes."""
    x, y = grid()
    n = noise(51, 6)
    a = ramp(n, [(0.0, "#c94a1c"), (0.5, "#e8642c"), (1.0, "#f08a48")])
    cell = 0.2
    gx, gy = (x % cell) / cell, (y % cell) / cell
    hole = (gx > 0.18) & (gx < 0.82) & (gy > 0.18) & (gy < 0.82)
    a = np.where(hole[..., None], hexc("#3a1a0c") * (0.8 + 0.4 * n)[..., None], a)
    rim = ((gx > 0.12) & (gx < 0.18)) | ((gy > 0.12) & (gy < 0.18))
    a = mix(a, "#ffb07a", rim * (~hole) * 0.45)
    def scratch(d):
        rnd = random.Random(52)
        for _ in range(30):
            x0, y0 = rnd.uniform(0, S), rnd.uniform(0, S)
            ang, ln = rnd.uniform(0, math.pi), rnd.uniform(0.03, 0.12) * S
            d.line([(x0, y0), (x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln)], fill=255, width=SS)
    a = mix(a, "#ffd0b0", stroke_mask(scratch, 0.5) * 0.5)
    return a


# ---------- dried fish, soup ----------

def dried():
    x, y = grid()
    n = noise(61, 6)
    a = ramp(y + (n - 0.5) * 0.2, [(0.0, "#5a3a1c"), (0.35, "#8a6232"), (0.6, "#b08850"), (1.0, "#c9a066")])

    def wrinkles(d):
        rnd = random.Random(62)
        for k in range(30):
            y0 = rnd.uniform(0, 1) * S
            pts = [(t * S, y0 + math.sin(t * 9 + k) * 0.02 * S) for t in np.linspace(rnd.uniform(0, 0.3), rnd.uniform(0.6, 1), 12)]
            d.line(pts, fill=255, width=SS * 2)
    a = mix(a, "#3e2610", stroke_mask(wrinkles, 0.8) * 0.55)
    a = specks(a, 63, 700, "#f6f2e8", 1.1, 0.7)    # salt
    return a * (0.92 + 0.16 * noise(64, 25, 2))[..., None]


def soup():
    x, y = grid()
    n = noise(71, 5)
    a = ramp(n, [(0.0, "#d9a24e"), (0.5, "#e9c27a"), (1.0, "#f3d9a0")])
    im = to_img(a)
    d = ImageDraw.Draw(im)
    rnd = random.Random(72)
    for _ in range(9):          # fish chunks
        cx, cy, r = rnd.uniform(0.15, 0.85) * S, rnd.uniform(0.15, 0.85) * S, rnd.uniform(0.05, 0.09) * S
        d.ellipse([cx - r, cy - r * 0.7, cx + r, cy + r * 0.7], fill=(246, 230, 205))
        d.arc([cx - r * 0.6, cy - r * 0.4, cx + r * 0.6, cy + r * 0.4], 200, 340, fill=(220, 190, 160), width=SS * 2)
    for _ in range(40):         # herbs
        cx, cy = rnd.uniform(0.05, 0.95) * S, rnd.uniform(0.05, 0.95) * S
        d.ellipse([cx - 5 * SS, cy - 2 * SS, cx + 5 * SS, cy + 2 * SS], fill=(70, 130, 50))
    for _ in range(25):         # oil
        cx, cy, r = rnd.uniform(0, 1) * S, rnd.uniform(0, 1) * S, rnd.uniform(4, 12) * SS
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 236, 170), width=SS)
    return from_img(im.filter(ImageFilter.GaussianBlur(SS * 0.6)))


PAINT = {
    "fish": mackerel,
    "fish_cooked": lambda: cooked(81, [(0.0, "#5e3416"), (0.35, "#9a6230"), (0.6, "#c78c4c"), (1.0, "#e2b878")], "#2c1608"),
    "tuna": tuna,
    "tuna_cooked": lambda: cooked(82, [(0.0, "#4a2510"), (0.35, "#86502a"), (0.6, "#b27646"), (1.0, "#d6a670")], "#24110a"),
    "fin": lambda: fin("#8fa6b2", "#4f6874", "#c9d8de", 91),
    "fin_cooked": lambda: fin("#9a6230", "#4a2510", "#3a1c0c", 92),
    "fin_tuna": lambda: fin("#d9a52e", "#a8761a", "#f2d266", 93),
    "eyes": eyes,
    "flesh": flesh,
    "meat_side": meat_side,
    "steak_top": steak_top,
    "steak_side": steak_side,
    "bottle": bottle,
    "crate": crate,
    "dried": dried,
    "soup": soup,
}


def main():
    sheet = Image.new("RGB", (CELL * GRID, CELL * GRID), (128, 128, 128))
    for name, (cx, cy) in CELLS.items():
        im = to_img(PAINT[name]()).resize((CELL, CELL), Image.LANCZOS)
        sheet.paste(im, (cx * CELL, cy * CELL))
    out = os.path.join(ROOT, "assets", "textures", "items.png")
    sheet.save(out)
    print("items:", out)


if __name__ == "__main__":
    main()
