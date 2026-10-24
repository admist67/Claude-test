"""Builds the material atlas (4x4 cells of 512 px) from CC0 ambientCG textures.

Run from the project root:  python3 tools/build_atlas.py
Downloads into ~/.cache/plot_textures, writes assets/textures/atlas_{albedo,normal,rm}.png
and data/atlas.json (cell name -> [col, row]). rm: R = roughness, G = metalness.
"""
import io
import json
import math
import os
import random
import urllib.request
import zipfile

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.expanduser("~/.cache/plot_textures")
CELL = 512
GRID = 4

# name: (col, row, source, tint)  — source is an ambientCG id or gen:<kind>
CELLS = {
    "wood": (0, 0, "Wood049", None),
    "wood_dark": (1, 0, "Wood051", None),
    "wood_warm": (2, 0, "Wood092", None),
    "rope": (3, 0, "Rope001", None),
    "plastic": (0, 1, "Plastic010", None),
    "metal": (1, 1, "Metal021", None),
    "clay": (2, 1, "Clay005", None),
    "bricks": (3, 1, "Bricks105", None),
    "canvas": (0, 2, "Fabric030", (230, 214, 180)),
    "palm": (1, 2, "gen:palm", None),
    "white": (2, 2, "gen:white", None),
    "ash": (3, 2, "gen:ash", None),
    "scales": (0, 3, "gen:scales", None),
}


def fetch(asset):
    folder = os.path.join(CACHE, asset)
    if not os.path.isdir(folder):
        os.makedirs(folder, exist_ok=True)
        url = "https://ambientcg.com/get?file=%s_1K-JPG.zip" % asset
        data = urllib.request.urlopen(url, timeout=60).read()
        zipfile.ZipFile(io.BytesIO(data)).extractall(folder)
    return folder


def load_map(asset, kind):
    path = os.path.join(fetch(asset), "%s_1K-JPG_%s.jpg" % (asset, kind))
    if not os.path.exists(path):
        return None
    im = Image.open(path)
    if im.width != im.height:  # 2:1 strips (rope, bricks): stack to a square
        sq = Image.new(im.mode, (im.width, im.width))
        for y in range(0, im.width, im.height):
            sq.paste(im, (0, y))
        im = sq
    return im.resize((CELL, CELL), Image.LANCZOS)


def gen_palm():
    """A palm frond: stem up the middle, tapered leaflets on both sides, alpha cut-out."""
    s = CELL * 2
    im = Image.new("RGBA", (s, s), (70, 120, 45, 0))
    d = ImageDraw.Draw(im)
    rnd = random.Random(4)
    cx = s // 2
    for i in range(34):
        t = i / 33.0
        y = int(s * 0.96 - t * s * 0.92)
        length = s * 0.46 * math.sin(math.pi * (0.12 + 0.82 * t)) ** 0.8
        for side in (-1, 1):
            ang = math.radians(rnd.uniform(32, 44))
            tip = (cx + side * length * math.cos(ang) * 1.0, y - length * math.sin(ang) * 0.75)
            w = s * 0.042 * (1.0 - 0.45 * t)
            g = rnd.randint(110, 160)
            col = (rnd.randint(55, 80), g, rnd.randint(35, 55), 255)
            nx, ny = -(tip[1] - y), tip[0] - cx
            nl = math.hypot(nx, ny) or 1
            nx, ny = nx / nl * w, ny / nl * w
            d.polygon([(cx, y - w), (cx + nx, y + ny), tip, (cx - nx * 0.2, y + w)], fill=col)
            d.line([(cx, y), tip], fill=(col[0] - 20, col[1] - 30, col[2] - 15, 255), width=2)
    d.line([(cx, s), (cx, int(s * 0.04))], fill=(120, 110, 60, 255), width=int(s * 0.018))
    return im.resize((CELL, CELL), Image.LANCZOS)


def gen_scales():
    im = Image.new("RGB", (CELL, CELL), (150, 160, 170))
    d = ImageDraw.Draw(im)
    r = 22
    for row in range(-1, CELL // (r) + 2):
        for col in range(-1, CELL // (r * 2) + 2):
            x = col * r * 2 + (r if row % 2 else 0)
            y = row * r
            d.arc([x - r, y - r, x + r, y + r], 20, 160, fill=(105, 115, 128), width=3)
    return im.filter(ImageFilter.GaussianBlur(0.8))


def gen_flat(color, noise=0):
    im = Image.new("RGB", (CELL, CELL), color)
    if noise:
        px = im.load()
        rnd = random.Random(9)
        for y in range(CELL):
            for x in range(CELL):
                n = rnd.randint(-noise, noise)
                c = px[x, y]
                px[x, y] = (max(0, c[0] + n), max(0, c[1] + n), max(0, c[2] + n))
    return im


def main():
    albedo = Image.new("RGBA", (CELL * GRID, CELL * GRID), (128, 128, 128, 255))
    normal = Image.new("RGB", (CELL * GRID, CELL * GRID), (128, 128, 255))
    rm = Image.new("RGB", (CELL * GRID, CELL * GRID), (215, 0, 0))
    table = {}
    for name, (cx, cy, src, tint) in CELLS.items():
        pos = (cx * CELL, cy * CELL)
        table[name] = [cx, cy]
        if src.startswith("gen:"):
            kind = src[4:]
            if kind == "palm":
                albedo.paste(gen_palm(), pos)
                rm.paste((200, 0, 0), pos + (pos[0] + CELL, pos[1] + CELL))
            elif kind == "white":
                albedo.paste(gen_flat((235, 235, 235)).convert("RGBA"), pos)
            elif kind == "ash":
                albedo.paste(gen_flat((40, 36, 34), 14).convert("RGBA"), pos)
            elif kind == "scales":
                albedo.paste(gen_scales().convert("RGBA"), pos)
                rm.paste((90, 0, 0), pos + (pos[0] + CELL, pos[1] + CELL))
            continue
        col = load_map(src, "Color").convert("RGB")
        if tint:
            col = Image.blend(col, Image.new("RGB", col.size, tint), 0.35)
        albedo.paste(col.convert("RGBA"), pos)
        nrm = load_map(src, "NormalGL")
        if nrm:
            normal.paste(nrm.convert("RGB"), pos)
        rough = load_map(src, "Roughness")
        metal = load_map(src, "Metalness")
        r = rough.convert("L") if rough else Image.new("L", (CELL, CELL), 215)
        g = metal.convert("L") if metal else Image.new("L", (CELL, CELL), 0)
        rm.paste(Image.merge("RGB", (r, g, Image.new("L", (CELL, CELL), 0))), pos)
    out = os.path.join(ROOT, "assets", "textures")
    os.makedirs(out, exist_ok=True)
    albedo.save(os.path.join(out, "atlas_albedo.png"))
    normal.save(os.path.join(out, "atlas_normal.jpg"), quality=92)
    rm.save(os.path.join(out, "atlas_rm.jpg"), quality=92)
    with open(os.path.join(ROOT, "data", "atlas.json"), "w") as f:
        json.dump({"grid": GRID, "cells": table}, f, indent=1)
    print("atlas:", sorted(table))


if __name__ == "__main__":
    main()
