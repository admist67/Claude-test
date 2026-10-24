"""Draws icon.png (512x512): a raft on turquoise water with the orange-tipped hook.
Run from the project root: python3 tools/make_icon.py
"""
import math
import os

from PIL import Image, ImageDraw

S = 512
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
img = Image.new("RGBA", (S, S))
d = ImageDraw.Draw(img)
for y in range(S):
    k = y / S
    sky = (int(63 + 100 * k), int(155 + 70 * k), int(216 + 20 * k))
    d.line([(0, y), (S, y)], fill=sky)
# water with facets
d.rectangle([0, 250, S, S], fill=(19, 120, 145))
for i in range(9):
    x = i * 64
    d.polygon([(x, 250), (x + 64, 250), (x + 32, 300)], fill=(30, 150, 168))
    d.polygon([(x - 32, 330), (x + 32, 330), (x, 380)], fill=(16, 105, 130))
# raft (isometric planks)
cx, cy = 256, 330
wood = [(200, 154, 91), (183, 134, 76), (212, 168, 106), (169, 122, 69)]
for i in range(5):
    off = (i - 2) * 30
    pts = [(cx - 170 + off, cy - 18 + off * 0.35), (cx + 60 + off, cy - 80 + off * 0.35),
           (cx + 82 + off, cy - 58 + off * 0.35), (cx - 148 + off, cy + 4 + off * 0.35)]
    d.polygon(pts, fill=wood[i % 4], outline=(110, 75, 40))
# hook rope and head
d.line([(330, 60), (380, 120), (400, 210)], fill=(232, 214, 168), width=10, joint="curve")
d.ellipse([382, 196, 418, 232], fill=(255, 106, 61))
d.line([(400, 230), (400, 290)], fill=(220, 220, 220), width=12)
for a in (-1, 1):
    d.arc([400 - 40 + a * 22, 260, 400 + a * 22, 310], 0, 180, fill=(220, 220, 220), width=11)
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=96, fill=255)
img.putalpha(mask)
img.save(os.path.join(ROOT, "icon.png"))
print("icon.png")
