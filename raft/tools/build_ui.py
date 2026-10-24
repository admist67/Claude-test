"""Builds the nautical UI kit: wooden buttons, framed panels, round buttons, slots, a
parchment plaque, toast pills and white glyphs. Run from the project root:
python3 tools/build_ui.py   (uses the ambientCG cache filled by tools/build_atlas.py)
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.expanduser("~/.cache/plot_textures")
OUT = os.path.join(ROOT, "assets", "ui")
GL = os.path.join(OUT, "glyphs")
SS = 4  # supersampling


def tex(asset, size, rotate=False, tint=None, k=0.0):
    im = Image.open(os.path.join(CACHE, asset, "%s_1K-JPG_Color.jpg" % asset)).convert("RGB")
    if rotate:
        im = im.rotate(90, expand=True)
    im = im.resize((max(size[0], 256), max(size[0], 256) * im.height // im.width)).crop((0, 0, size[0], size[1])) if im.width >= size[0] else im.resize(size)
    if im.size != size:
        im = im.resize(size)
    if tint:
        im = Image.blend(im, Image.new("RGB", size, tint), k)
    return im


def rounded_mask(size, r, inset=0):
    m = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([inset * SS, inset * SS, (size[0] - inset) * SS - 1, (size[1] - inset) * SS - 1], radius=r * SS, fill=255)
    return m.resize(size, Image.LANCZOS)


def ring_mask(size, r_out, r_in):
    m = Image.new("L", (size * SS, size * SS), 0)
    d = ImageDraw.Draw(m)
    c = size * SS / 2
    d.ellipse([c - r_out * SS, c - r_out * SS, c + r_out * SS, c + r_out * SS], fill=255)
    d.ellipse([c - r_in * SS, c - r_in * SS, c + r_in * SS, c + r_in * SS], fill=0)
    return m.resize((size, size), Image.LANCZOS)


def disc_mask(size, r):
    return ring_mask(size, r, 0)


def bevel(img, mask, light=60, dark=70, width=3):
    """Top highlight and bottom shadow inside the mask."""
    m = mask.filter(ImageFilter.GaussianBlur(width))
    up = ImageChops.subtract(mask, ImageChops.offset(m, 0, width))
    down = ImageChops.subtract(mask, ImageChops.offset(m, 0, -width))
    img = Image.composite(ImageEnhance.Brightness(img).enhance(1 + light / 100), img, up)
    img = Image.composite(ImageEnhance.Brightness(img).enhance(1 - dark / 100), img, down)
    return img


def outline(mask, w):
    grown = mask.filter(ImageFilter.MaxFilter(w * 2 + 1))
    return grown


def save(img, name):
    img.save(os.path.join(OUT, name))


def wood_button(name, bright=1.0, sat=1.0):
    size = (192, 80)
    wood = tex("Wood092", size, rotate=True, tint=(200, 140, 80), k=0.15)
    wood = ImageEnhance.Brightness(wood).enhance(bright)
    wood = ImageEnhance.Color(wood).enhance(sat)
    mask = rounded_mask(size, 16, 3)
    wood = bevel(wood, mask, 35, 45, 4)
    d = ImageDraw.Draw(wood)
    for x in (16, size[0] - 16):
        for y in (18, size[1] - 18):
            d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(60, 40, 25))
            d.ellipse([x - 2, y - 3, x + 1, y], fill=(150, 120, 90))
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    edge = outline(mask, 2)
    out.paste((40, 24, 14, 255), (0, 0), edge)
    out.paste(wood, (0, 0), mask)
    save(out, name)


def panel():
    size = (160, 160)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    outer = rounded_mask(size, 24, 1)
    inner = rounded_mask(size, 14, 17)
    wood = tex("Wood049", size, tint=(150, 100, 60), k=0.28)
    wood = bevel(wood, outer, 30, 50, 3)
    frame = ImageChops.subtract(outer, inner)
    out.paste((30, 18, 10, 255), (0, 0), outline(outer, 2))
    out.paste(wood, (0, 0), frame)
    fill = Image.new("RGBA", size, (11, 32, 42, 236))
    grad = Image.new("L", size)
    for y in range(size[1]):
        ImageDraw.Draw(grad).line([(0, y), (size[0], y)], fill=int(236 - y * 0.18))
    fill.putalpha(ImageChops.multiply(grad, inner))
    out.alpha_composite(fill)
    d = ImageDraw.Draw(out)
    d.rounded_rectangle([17, 17, size[0] - 18, size[1] - 18], radius=14, outline=(20, 12, 6, 255), width=2)
    for x in (9, size[0] - 10):
        for y in (9, size[1] - 10):
            d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(150, 112, 50, 255))
            d.ellipse([x - 3, y - 4, x + 1, y], fill=(235, 200, 120, 255))
    save(out, "panel.png")


def ring(name, hot=False):
    s = 192
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    fill = Image.new("RGBA", (s, s), (255, 236, 190, 90) if hot else (8, 26, 34, 140))
    out.paste(fill, (0, 0), disc_mask(s, 84))
    wood = tex("Wood049", (s, s), tint=(170, 115, 65), k=0.3)
    if hot:
        wood = ImageEnhance.Brightness(wood).enhance(1.35)
    rm = ring_mask(s, 94, 80)
    out.paste((25, 15, 8, 255), (0, 0), ring_mask(s, 96, 78))
    out.paste(bevel(wood, rm, 40, 40, 2), (0, 0), rm)
    d = ImageDraw.Draw(out)
    c = s / 2
    d.ellipse([c - 79, c - 79, c + 79, c + 79], outline=(240, 215, 160, 120), width=2)
    save(out, name)


def slot(name, sel=False):
    size = (112, 112)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    m = rounded_mask(size, 20, 4)
    out.paste(Image.new("RGBA", size, (255, 232, 180, 70) if sel else (8, 26, 34, 150)), (0, 0), m)
    d = ImageDraw.Draw(out)
    col = (242, 196, 107, 255) if sel else (180, 140, 90, 200)
    d.rounded_rectangle([4, 4, size[0] - 5, size[1] - 5], radius=20, outline=col, width=5 if sel else 3)
    save(out, name)


def plaque():
    size = (160, 96)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    outer = rounded_mask(size, 16, 1)
    inner = rounded_mask(size, 10, 9)
    wood = tex("Wood049", size, tint=(150, 100, 60), k=0.3)
    out.paste((30, 18, 10, 255), (0, 0), outline(outer, 2))
    out.paste(bevel(wood, outer, 30, 40, 2), (0, 0), ImageChops.subtract(outer, inner))
    paper = tex("Fabric030", size, tint=(236, 220, 180), k=0.75)
    out.paste(bevel(paper, inner, 10, 18, 3), (0, 0), inner)
    save(out, "plaque.png")


def pill():
    size = (96, 52)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    m = rounded_mask(size, 24, 2)
    out.paste(Image.new("RGBA", size, (8, 26, 34, 200)), (0, 0), m)
    ImageDraw.Draw(out).rounded_rectangle([2, 2, size[0] - 3, size[1] - 3], radius=24, outline=(242, 196, 107, 170), width=2)
    save(out, "pill.png")


# ------------------------------------------------------------------ glyphs (white, 128 px)

def glyph(name, draw_fn):
    s = 128 * SS
    im = Image.new("L", (s, s), 0)
    draw_fn(ImageDraw.Draw(im), s)
    im = im.resize((128, 128), Image.LANCZOS)
    out = Image.new("RGBA", (128, 128), (255, 255, 255, 0))
    out.putalpha(im)
    out.save(os.path.join(GL, name + ".png"))


def g_heart(d, s):
    r = s * 0.22
    d.ellipse([s * 0.14, s * 0.2, s * 0.14 + 2 * r, s * 0.2 + 2 * r], fill=255)
    d.ellipse([s * 0.86 - 2 * r, s * 0.2, s * 0.86, s * 0.2 + 2 * r], fill=255)
    d.polygon([(s * 0.15, s * 0.48), (s * 0.85, s * 0.48), (s * 0.5, s * 0.88)], fill=255)


def g_drop(d, s):
    d.ellipse([s * 0.25, s * 0.4, s * 0.75, s * 0.9], fill=255)
    d.polygon([(s * 0.27, s * 0.58), (s * 0.73, s * 0.58), (s * 0.5, s * 0.08)], fill=255)


def g_food(d, s):
    d.ellipse([s * 0.12, s * 0.1, s * 0.66, s * 0.64], fill=255)
    d.line([(s * 0.5, s * 0.5), (s * 0.8, s * 0.8)], fill=255, width=int(s * 0.1))
    for o in ((0.78, 0.86), (0.86, 0.78)):
        d.ellipse([s * o[0] - s * 0.07, s * o[1] - s * 0.07, s * o[0] + s * 0.07, s * o[1] + s * 0.07], fill=255)


def g_hand(d, s):
    d.rounded_rectangle([s * 0.26, s * 0.45, s * 0.76, s * 0.9], radius=s * 0.12, fill=255)
    for i, h in enumerate((0.2, 0.12, 0.14, 0.24)):
        x = s * (0.27 + i * 0.125)
        d.rounded_rectangle([x, s * h, x + s * 0.1, s * 0.6], radius=s * 0.05, fill=255)
    d.rounded_rectangle([s * 0.08, s * 0.48, s * 0.34, s * 0.6], radius=s * 0.06, fill=255)


def g_bag(d, s):
    d.rounded_rectangle([s * 0.18, s * 0.3, s * 0.82, s * 0.9], radius=s * 0.12, fill=255)
    d.arc([s * 0.32, s * 0.08, s * 0.68, s * 0.46], 180, 360, fill=255, width=int(s * 0.07))
    d.rectangle([s * 0.18, s * 0.5, s * 0.82, s * 0.56], fill=0)
    d.rounded_rectangle([s * 0.42, s * 0.46, s * 0.58, s * 0.62], radius=s * 0.03, fill=255)


def g_sun(d, s):
    c = s / 2
    d.ellipse([c - s * 0.2, c - s * 0.2, c + s * 0.2, c + s * 0.2], fill=255)
    for i in range(8):
        a = i * math.pi / 4
        d.line([(c + math.cos(a) * s * 0.28, c + math.sin(a) * s * 0.28), (c + math.cos(a) * s * 0.42, c + math.sin(a) * s * 0.42)], fill=255, width=int(s * 0.07))


def g_moon(d, s):
    d.ellipse([s * 0.15, s * 0.15, s * 0.85, s * 0.85], fill=255)
    d.ellipse([s * 0.35, s * 0.05, s * 0.98, s * 0.68], fill=0)


def g_flame(d, s):
    d.ellipse([s * 0.25, s * 0.42, s * 0.75, s * 0.92], fill=255)
    d.polygon([(s * 0.26, s * 0.62), (s * 0.5, s * 0.06), (s * 0.74, s * 0.62)], fill=255)
    d.ellipse([s * 0.4, s * 0.62, s * 0.6, s * 0.85], fill=0)


def g_anchor(d, s):
    w = int(s * 0.07)
    d.ellipse([s * 0.4, s * 0.06, s * 0.6, s * 0.26], outline=255, width=w)
    d.line([(s * 0.5, s * 0.25), (s * 0.5, s * 0.88)], fill=255, width=w)
    d.line([(s * 0.3, s * 0.36), (s * 0.7, s * 0.36)], fill=255, width=w)
    d.arc([s * 0.16, s * 0.4, s * 0.84, s * 0.9], 20, 160, fill=255, width=w)


def main():
    os.makedirs(GL, exist_ok=True)
    wood_button("button.png")
    wood_button("button_pressed.png", 0.78)
    wood_button("button_disabled.png", 0.6, 0.2)
    panel()
    ring("ring.png")
    ring("ring_hot.png", True)
    slot("slot.png")
    slot("slot_sel.png", True)
    plaque()
    pill()
    for n, f in (("heart", g_heart), ("drop", g_drop), ("food", g_food), ("hand", g_hand), ("bag", g_bag),
                 ("sun", g_sun), ("moon", g_moon), ("flame", g_flame), ("anchor", g_anchor)):
        glyph(n, f)
    print("ui kit ok")


if __name__ == "__main__":
    main()
