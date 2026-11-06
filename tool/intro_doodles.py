"""Draws the doodle images of the intro screens into assets/intro/.

    python tool/intro_doodles.py

Every file name the intro uses (lib/screens/intro/intro_content.dart) gets a
hand-drawn looking pineapple doodle: thick wobbly outlines, amber and green like
the app. Run it again after changing a color or a drawing; it overwrites the files.
Replace any file with your own image whenever you like.
"""
import math
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "intro")
SS = 4  # drawn 4x larger, then scaled down, for smooth edges

INK = (43, 38, 32, 255)
AMBER = (240, 179, 35, 255)
AMBER_DARK = (214, 148, 20, 255)
AMBER_LIGHT = (255, 214, 110, 255)
GREEN = (47, 125, 79, 255)
GREEN_LIGHT = (123, 191, 106, 255)
WHITE = (255, 255, 255, 255)
CREAM = (250, 246, 236, 255)
SKY = (214, 236, 247, 255)

# card and blob backgrounds
BG_AMBER = (253, 238, 196, 255)
BG_GREEN = (223, 239, 214, 255)
BG_PEACH = (251, 225, 203, 255)
BG_CREAM = (246, 240, 226, 255)
BG_SKY = (222, 239, 248, 255)

rng = random.Random(7)  # same drawings every run


# ---------------------------------------------------------------- basics

def s(v):
    return v * SS


def w_(v):
    """A line width: whole pixels, at least 1."""
    return max(1, round(v * SS))


def pts(points):
    return [(s(x), s(y)) for x, y in points]


def new(w, h, bg=(0, 0, 0, 0)):
    return Image.new("RGBA", (s(w), s(h)), bg)


def save(img, name):
    img = img.resize((img.width // SS, img.height // SS), Image.LANCZOS)
    img.save(os.path.join(OUT, name))
    print("wrote", name)


def wobbly_ellipse(cx, cy, rx, ry, wobble=0.035, n=72):
    """Points around an ellipse with a gentle hand-drawn wobble."""
    a, b = rng.uniform(0, 6.3), rng.uniform(0, 6.3)
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        k = 1 + wobble * (math.sin(3 * t + a) * 0.6 + math.sin(5 * t + b) * 0.4)
        out.append((cx + rx * k * math.cos(t), cy + ry * k * math.sin(t)))
    return out


def shape(d, points, fill, lw):
    """A filled shape with a thick ink outline."""
    d.polygon(pts(points), fill=fill)
    d.line(pts(points + [points[0]]), fill=INK, width=w_(lw), joint="curve")


def blob(d, cx, cy, r, fill):
    d.polygon(pts(wobbly_ellipse(cx, cy, r, r * 0.92, wobble=0.07)), fill=fill)


def sparkle(d, cx, cy, r, color=INK, lw=3):
    d.line(pts([(cx, cy - r), (cx, cy + r)]), fill=color, width=w_(lw))
    d.line(pts([(cx - r, cy), (cx + r, cy)]), fill=color, width=w_(lw))
    r2 = r * 0.45
    d.line(pts([(cx - r2, cy - r2), (cx + r2, cy + r2)]), fill=color, width=w_(lw * 0.7))
    d.line(pts([(cx - r2, cy + r2), (cx + r2, cy - r2)]), fill=color, width=w_(lw * 0.7))


def dot(d, cx, cy, r, color=INK):
    d.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], fill=color)


def scatter(d, w, h, count, avoid=None, scale=1.0):
    """Little sparkles and dots around the picture."""
    for _ in range(count):
        x, y = rng.uniform(w * 0.06, w * 0.94), rng.uniform(h * 0.06, h * 0.94)
        if avoid and avoid(x, y):
            continue
        if rng.random() < 0.5:
            sparkle(d, x, y, rng.uniform(7, 12) * scale, lw=2.5 * scale)
        else:
            dot(d, x, y, rng.uniform(3, 5) * scale, color=rng.choice([INK, AMBER_DARK, GREEN]))


# ---------------------------------------------------------------- drawings

def leaf_points(bx, by, angle, length, width):
    """A pointed leaf from (bx, by), pointing at angle (degrees, 0 = up)."""
    a = math.radians(angle)
    ux, uy = math.sin(a), -math.cos(a)  # along the leaf
    px, py = -uy, ux  # across it
    left, right = [], []
    for i in range(9):
        t = i / 8
        half = width / 2 * math.sin(math.pi * t) ** 0.8
        cx, cy = bx + ux * length * t, by + uy * length * t
        left.append((cx + px * half, cy + py * half))
        right.append((cx - px * half, cy - py * half))
    return left + right[::-1][1:]


def pineapple(img, cx, cy, h, lw=None):
    """A pineapple standing on (cx, cy), h tall."""
    lw = lw or max(2.5, h * 0.022)
    d = ImageDraw.Draw(img)
    body_h = h * 0.58
    body_w = body_h * 0.74
    body_cy = cy - body_h / 2
    top = cy - body_h

    # crown, behind the body
    leaves = [(-58, 0.62), (58, 0.62), (-34, 0.82), (34, 0.82), (-12, 0.95), (12, 0.95), (0, 1.0)]
    for i, (angle, k) in enumerate(leaves):
        angle += rng.uniform(-5, 5)
        length = h * 0.44 * k
        color = GREEN if i % 2 == 0 else GREEN_LIGHT
        shape(d, leaf_points(cx, top + body_h * 0.08, angle, length, h * 0.1), color, lw)

    # body
    body = wobbly_ellipse(cx, body_cy, body_w / 2, body_h / 2, wobble=0.03)
    d.polygon(pts(body), fill=AMBER)

    # criss-cross skin, kept inside the body with a mask
    hatch = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hatch)
    step = body_w * 0.24
    span = body_h + body_w
    k = -span
    while k < span:
        for sign in (1, -1):
            x0, y0 = cx - span, body_cy + k + sign * span
            x1, y1 = cx + span, body_cy + k - sign * span
            hd.line(pts([(x0, y0), (x1, y1)]), fill=AMBER_DARK, width=w_(lw * 0.8))
        k += step
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(pts(body), fill=255)
    img.paste(hatch, (0, 0), Image.composite(hatch, Image.new("RGBA", img.size), mask).getchannel("A"))

    d = ImageDraw.Draw(img)
    # little seeds in the diamonds
    for row in range(-3, 4):
        for col in range(-3, 4):
            x = cx + (col + (row % 2) * 0.5) * step * 1.41 * 0.5
            y = body_cy + row * step * 0.71
            if ((x - cx) / (body_w / 2 * 0.82)) ** 2 + ((y - body_cy) / (body_h / 2 * 0.86)) ** 2 < 1:
                dot(d, x, y, lw * 0.55, INK)
    d.line(pts(body + [body[0]]), fill=INK, width=w_(lw), joint="curve")
    # shine
    d.arc([s(cx - body_w * 0.32), s(body_cy - body_h * 0.36), s(cx + body_w * 0.1), s(body_cy + body_h * 0.1)],
          200, 250, fill=WHITE, width=w_(lw * 1.1))


def slice_(d, cx, cy, r, lw=4):
    shape(d, wobbly_ellipse(cx, cy, r, r, wobble=0.02), AMBER_DARK, lw)
    shape(d, wobbly_ellipse(cx, cy, r * 0.8, r * 0.8, wobble=0.02), AMBER_LIGHT, lw * 0.6)
    for i in range(10):
        t = 2 * math.pi * i / 10
        d.line(pts([(cx + math.cos(t) * r * 0.25, cy + math.sin(t) * r * 0.25),
                    (cx + math.cos(t) * r * 0.62, cy + math.sin(t) * r * 0.62)]), fill=AMBER_DARK, width=w_(lw * 0.5))
    shape(d, wobbly_ellipse(cx, cy, r * 0.2, r * 0.2, wobble=0.02), CREAM, lw * 0.6)


def leaf(d, bx, by, angle, length, lw=4, color=GREEN_LIGHT):
    p = leaf_points(bx, by, angle, length, length * 0.42)
    shape(d, p, color, lw)
    a = math.radians(angle)
    d.line(pts([(bx, by), (bx + math.sin(a) * length * 0.85, by - math.cos(a) * length * 0.85)]),
           fill=INK, width=w_(lw * 0.6))


def sun(d, cx, cy, r, lw=4):
    for i in range(10):
        t = 2 * math.pi * i / 10 + 0.2
        d.line(pts([(cx + math.cos(t) * r * 1.3, cy + math.sin(t) * r * 1.3),
                    (cx + math.cos(t) * r * 1.65, cy + math.sin(t) * r * 1.65)]), fill=INK, width=w_(lw))
    shape(d, wobbly_ellipse(cx, cy, r, r, wobble=0.03), AMBER, lw)


def phone(img, cx, cy, w, h, angle=0, screen=SKY, content=None, lw=5):
    """A phone; content(draw, x0, y0, x1, y1) draws on its screen."""
    layer = new(w + 40, h + 40)
    d = ImageDraw.Draw(layer)
    x0, y0 = 20, 20
    d.rounded_rectangle([s(x0), s(y0), s(x0 + w), s(y0 + h)], radius=s(w * 0.16), fill=WHITE, outline=INK, width=w_(lw))
    m = w * 0.08
    sx0, sy0, sx1, sy1 = x0 + m, y0 + m * 1.6, x0 + w - m, y0 + h - m * 1.6
    d.rounded_rectangle([s(sx0), s(sy0), s(sx1), s(sy1)], radius=s(w * 0.06), fill=screen, outline=INK, width=w_(lw * 0.5))
    d.line(pts([(x0 + w * 0.4, y0 + m * 0.8), (x0 + w * 0.6, y0 + m * 0.8)]), fill=INK, width=w_(lw * 0.7))
    if content:
        content(layer, d, sx0, sy0, sx1, sy1)
    if angle:
        layer = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(layer, (int(s(cx) - layer.width / 2), int(s(cy) - layer.height / 2)))


def scan_corners(d, x0, y0, x1, y1, lw=5, color=GREEN):
    k = min(x1 - x0, y1 - y0) * 0.22
    for (x, y, dx, dy) in [(x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)]:
        d.line(pts([(x, y + dy * k), (x, y), (x + dx * k, y)]), fill=color, width=w_(lw), joint="curve")


def check_badge(d, cx, cy, r, lw=5):
    shape(d, wobbly_ellipse(cx, cy, r, r, wobble=0.02), GREEN, lw)
    d.line(pts([(cx - r * 0.45, cy + r * 0.02), (cx - r * 0.1, cy + r * 0.35), (cx + r * 0.48, cy - r * 0.32)]),
           fill=WHITE, width=w_(lw * 1.6), joint="curve")


def cloud(d, cx, cy, w, lw=5, fill=WHITE):
    circles = [(-0.28, 0.08, 0.22), (0.0, -0.08, 0.3), (0.28, 0.06, 0.22), (0.0, 0.14, 0.24)]
    for dx, dy, r in circles:  # ink first, a little larger, so only the outer edge shows
        r = r * w + lw / 2
        x, y = cx + dx * w, cy + dy * w
        d.ellipse([s(x - r), s(y - r), s(x + r), s(y + r)], fill=INK)
    for dx, dy, r in circles:
        r = r * w - lw / 2
        x, y = cx + dx * w, cy + dy * w
        d.ellipse([s(x - r), s(y - r), s(x + r), s(y + r)], fill=fill)


def sync_arrows(d, cx, cy, r, lw=5, color=GREEN):
    box = [s(cx - r), s(cy - r), s(cx + r), s(cy + r)]
    d.arc(box, 200, 340, fill=color, width=w_(lw))
    d.arc(box, 20, 160, fill=color, width=w_(lw))
    for angle, turn in ((340, 1), (160, 1)):
        t = math.radians(angle)
        x, y = cx + math.cos(t) * r, cy + math.sin(t) * r
        tx, ty = -math.sin(t) * turn, math.cos(t) * turn  # along the arc
        k = r * 0.45
        d.polygon(pts([(x + tx * k * 0.6, y + ty * k * 0.6),
                       (x - tx * k * 0.2 + math.cos(t) * k * 0.5, y - ty * k * 0.2 + math.sin(t) * k * 0.5),
                       (x - tx * k * 0.2 - math.cos(t) * k * 0.5, y - ty * k * 0.2 - math.sin(t) * k * 0.5)]),
                  fill=color)


def map_pin(d, cx, cy, r, lw=5):
    points = []
    for i in range(41):
        t = math.radians(130 + 280 * i / 40)  # round top, open at the bottom (90 degrees)
        points.append((cx + math.cos(t) * r, cy - r * 0.2 + math.sin(t) * r))
    points.append((cx, cy + r * 1.55))
    shape(d, points, GREEN, lw)
    shape(d, wobbly_ellipse(cx, cy - r * 0.2, r * 0.4, r * 0.4, wobble=0.02), WHITE, lw * 0.7)


def spray_bottle(d, cx, cy, h, lw=5):
    bw = h * 0.42
    d.rounded_rectangle([s(cx - bw / 2), s(cy - h * 0.15), s(cx + bw / 2), s(cy + h * 0.5)],
                        radius=s(bw * 0.25), fill=GREEN_LIGHT, outline=INK, width=w_(lw))
    d.rectangle([s(cx - bw * 0.22), s(cy - h * 0.3), s(cx + bw * 0.22), s(cy - h * 0.15)], fill=WHITE, outline=INK, width=w_(lw))
    shape(d, [(cx - bw * 0.35, cy - h * 0.3), (cx + bw * 0.35, cy - h * 0.3), (cx + bw * 0.35, cy - h * 0.45),
              (cx - bw * 0.75, cy - h * 0.45), (cx - bw * 0.75, cy - h * 0.38), (cx - bw * 0.35, cy - h * 0.38)], AMBER, lw)
    d.line(pts([(cx + bw * 0.1, cy - h * 0.3), (cx + bw * 0.3, cy - h * 0.18)]), fill=INK, width=w_(lw))
    leaf(d, cx - bw * 0.05, cy + h * 0.35, 20, h * 0.3, lw * 0.8, GREEN)
    for i in range(6):
        dot(d, cx - bw * 0.95 - (i % 3) * h * 0.06, cy - h * 0.48 + (i // 3 - 0.5) * h * 0.08 + (i % 3 - 1) * h * 0.04,
            lw * 0.6, GREEN)


def shield_leaf(d, cx, cy, r, lw=5):
    points = [(cx, cy - r), (cx + r * 0.85, cy - r * 0.62), (cx + r * 0.75, cy + r * 0.25),
              (cx, cy + r), (cx - r * 0.75, cy + r * 0.25), (cx - r * 0.85, cy - r * 0.62)]
    shape(d, points, AMBER_LIGHT, lw)
    leaf(d, cx - r * 0.2, cy + r * 0.45, 30, r * 1.0, lw * 0.8, GREEN)


def calendar(d, cx, cy, w, lw=5):
    h = w * 0.95
    x0, y0, x1, y1 = cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
    d.rounded_rectangle([s(x0), s(y0), s(x1), s(y1)], radius=s(w * 0.1), fill=WHITE, outline=INK, width=w_(lw))
    d.rounded_rectangle([s(x0), s(y0), s(x1), s(y0 + h * 0.26)], radius=s(w * 0.1), fill=AMBER, outline=INK, width=w_(lw))
    for x in (x0 + w * 0.28, x1 - w * 0.28):
        d.line(pts([(x, y0 - h * 0.08), (x, y0 + h * 0.08)]), fill=INK, width=w_(lw * 1.2))
    for row in range(3):
        for col in range(4):
            x = x0 + w * (0.17 + col * 0.22)
            y = y0 + h * (0.45 + row * 0.18)
            dot(d, x, y, lw * 0.7, INK)
            if (row, col) == (1, 2):
                d.ellipse([s(x - w * 0.1), s(y - w * 0.09), s(x + w * 0.1), s(y + w * 0.09)], outline=GREEN, width=w_(lw * 0.8))


def magnifier(img, cx, cy, r, lw=6):
    d = ImageDraw.Draw(img)
    d.line(pts([(cx + r * 0.7, cy + r * 0.7), (cx + r * 1.5, cy + r * 1.5)]), fill=INK, width=w_(lw * 2.4))
    shape(d, wobbly_ellipse(cx, cy, r, r, wobble=0.015), SKY, lw)
    leaf(d, cx - r * 0.35, cy + r * 0.4, 40, r * 1.0, lw * 0.7, GREEN_LIGHT)


def shutter(d, cx, cy, r, lw=5):
    shape(d, wobbly_ellipse(cx, cy, r, r, wobble=0.015), AMBER, lw)
    shape(d, wobbly_ellipse(cx, cy, r * 0.62, r * 0.62, wobble=0.015), WHITE, lw * 0.8)
    for i in range(6):
        t = 2 * math.pi * i / 6
        d.line(pts([(cx + math.cos(t) * r * 0.62, cy + math.sin(t) * r * 0.62),
                    (cx + math.cos(t + 1.2) * r * 0.2, cy + math.sin(t + 1.2) * r * 0.2)]), fill=INK, width=w_(lw * 0.6))


def hill(d, w, h, top, color, lw=5):
    points = [(0, h)]
    for i in range(21):
        x = w * i / 20
        points.append((x, top + math.sin(i / 20 * math.pi * 1.6 + 0.5) * h * 0.03))
    points.append((w, h))
    d.polygon(pts(points), fill=color)
    d.line(pts(points[1:-1]), fill=INK, width=w_(lw), joint="curve")


def sprout(img, cx, cy, h, lw=4):
    """A young pineapple plant: just the spiky leaves."""
    d = ImageDraw.Draw(img)
    for i, angle in enumerate((-55, 55, -28, 28, -8, 8)):
        color = GREEN if i % 2 == 0 else GREEN_LIGHT
        shape(d, leaf_points(cx, cy, angle + rng.uniform(-4, 4), h * (0.75 if abs(angle) > 40 else 1.0), h * 0.2),
              color, lw)


def notebook(d, cx, cy, w, h, lw=6):
    x0, y0, x1, y1 = cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
    d.rounded_rectangle([s(x0), s(y0), s(x1), s(y1)], radius=s(w * 0.05), fill=WHITE, outline=INK, width=w_(lw))
    for i in range(7):  # spiral rings
        y = y0 + h * (0.1 + i * 0.13)
        d.ellipse([s(x0 - w * 0.05), s(y - w * 0.025), s(x0 + w * 0.05), s(y + w * 0.025)], fill=CREAM, outline=INK, width=w_(lw * 0.6))
    for i in range(5):  # checklist
        y = y0 + h * (0.18 + i * 0.16)
        bx = x0 + w * 0.17
        b = w * 0.09
        d.rounded_rectangle([s(bx), s(y - b / 2), s(bx + b), s(y + b / 2)], radius=s(b * 0.2), fill=WHITE, outline=INK, width=w_(lw * 0.6))
        if i < 3:
            d.line(pts([(bx + b * 0.2, y), (bx + b * 0.45, y + b * 0.3), (bx + b * 0.95, y - b * 0.45)]),
                   fill=GREEN, width=w_(lw * 0.9), joint="curve")
        length = w * rng.uniform(0.38, 0.6)
        d.line(pts([(bx + b * 1.6, y), (bx + b * 1.6 + length, y)]), fill=(150, 145, 135, 255), width=w_(lw * 0.7))


# ---------------------------------------------------------------- the images

def slide1_main():
    w, h = 768, 1024
    img = new(w, h)
    d = ImageDraw.Draw(img)
    blob(d, w / 2, h / 2, w * 0.44, BG_AMBER)
    pineapple(img, w * 0.4, h * 0.8, h * 0.62)
    d = ImageDraw.Draw(img)
    scan_corners(d, w * 0.14, h * 0.2, w * 0.66, h * 0.84, lw=7)

    def screen(layer, sd, x0, y0, x1, y1):
        pineapple(layer, (x0 + x1) / 2, y1 - (y1 - y0) * 0.12, (y1 - y0) * 0.72, lw=3)
        sd = ImageDraw.Draw(layer)
        scan_corners(sd, x0 + 10, y0 + 10, x1 - 10, y1 - 10, lw=4)

    phone(img, w * 0.74, h * 0.6, 190, 340, angle=-12, content=screen, lw=6)
    d = ImageDraw.Draw(img)
    sparkle(d, w * 0.83, h * 0.22, 20, lw=4)
    sparkle(d, w * 0.12, h * 0.6, 14, lw=3)
    dot(d, w * 0.9, h * 0.35, 6, AMBER_DARK)
    save(img, "slide1_main.png")


def slide2_main():
    w, h = 768, 1024
    img = new(w, h)
    d = ImageDraw.Draw(img)
    blob(d, w / 2, h / 2, w * 0.45, BG_GREEN)
    sun(d, w * 0.72, h * 0.25, 58, lw=5)
    cloud(d, w * 0.33, h * 0.24, 190, lw=6)
    sync_arrows(d, w * 0.33, h * 0.25, 30, lw=6)
    hill(d, w, h, h * 0.58, GREEN_LIGHT, lw=6)
    # rows of young pineapple plants
    for row, (y, size) in enumerate(((h * 0.66, 70), (h * 0.76, 85), (h * 0.88, 100))):
        count = 4 + row
        for i in range(count):
            x = w * (0.12 + 0.76 * i / (count - 1)) + rng.uniform(-8, 8)
            if row == 2 and i == count // 2:
                pineapple(img, x, y + 10, size * 1.6)
            else:
                sprout(img, x, y, size * 0.6, lw=4)
    # keep it inside the round blob
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(pts(wobbly_ellipse(w / 2, h / 2, w * 0.47, h * 0.45, wobble=0.05)), fill=255)
    clipped = new(w, h)
    clipped.paste(img, (0, 0), mask)
    save(clipped, "slide2_main.png")


def slide3_main():
    w, h = 768, 1024
    img = new(w, h)
    d = ImageDraw.Draw(img)
    blob(d, w / 2, h / 2, w * 0.44, BG_PEACH)
    notebook(d, w * 0.42, h * 0.45, w * 0.52, h * 0.5, lw=6)
    pineapple(img, w * 0.73, h * 0.86, h * 0.44)
    d = ImageDraw.Draw(img)
    sparkle(d, w * 0.8, h * 0.2, 18, lw=4)
    sparkle(d, w * 0.15, h * 0.78, 13, lw=3)
    save(img, "slide3_main.png")


def icon(name, draw):
    img = new(256, 256)
    draw(img, ImageDraw.Draw(img))
    save(img, name)


def floats():
    icon("slide1_float1.png", lambda img, d: pineapple(img, 128, 236, 220, lw=6))
    icon("slide1_float2.png", lambda img, d: magnifier(img, 108, 108, 68, lw=8))
    icon("slide1_float3.png", lambda img, d: shutter(d, 128, 128, 96, lw=8))
    icon("slide1_float4.png", lambda img, d: check_badge(d, 128, 128, 96, lw=8))

    def cloud_sync(img, d):
        cloud(d, 128, 140, 210, lw=8)
        sync_arrows(d, 128, 145, 34, lw=8)

    icon("slide2_float1.png", cloud_sync)
    icon("slide2_float2.png", lambda img, d: map_pin(d, 128, 100, 72, lw=8))

    def phone_check(img, d):
        phone(img, 128, 128, 130, 220, lw=7,
              content=lambda layer, sd, x0, y0, x1, y1: check_badge(sd, (x0 + x1) / 2, (y0 + y1) / 2, 34, lw=5))

    icon("slide2_float3.png", phone_check)
    icon("slide3_float1.png", lambda img, d: spray_bottle(d, 140, 128, 200, lw=7))
    icon("slide3_float2.png", lambda img, d: sprout(img, 128, 230, 190, lw=7))
    icon("slide3_float3.png", lambda img, d: shield_leaf(d, 128, 128, 104, lw=8))
    icon("slide3_float4.png", lambda img, d: calendar(d, 128, 136, 196, lw=8))


def card(name, bg, draw):
    w, h = 480, 600
    img = new(w, h, bg)
    d = ImageDraw.Draw(img)
    draw(img, d, w, h)
    save(img, name)


def welcome_cards():
    def item1(img, d, w, h):
        scatter(d, w, h, 14, avoid=lambda x, y: abs(x - w / 2) < 150 and y > h * 0.15)
        pineapple(img, w / 2, h * 0.88, h * 0.78)

    def item2(img, d, w, h):
        sun(d, w * 0.75, h * 0.18, 42)
        hill(d, w, h, h * 0.45, GREEN_LIGHT)
        for row, (y, size) in enumerate(((h * 0.56, 55), (h * 0.7, 70), (h * 0.86, 85))):
            for i in range(3 + row):
                sprout(img, w * (0.12 + 0.76 * i / (2 + row)) + rng.uniform(-6, 6), y, size * 0.7)

    def item3(img, d, w, h):
        scatter(d, w, h, 10, avoid=lambda x, y: 0.15 * h < y < 0.85 * h)
        slice_(d, w * 0.38, h * 0.36, 110, lw=6)
        slice_(d, w * 0.66, h * 0.62, 95, lw=6)
        leaf(d, w * 0.2, h * 0.8, 30, 110, lw=5)

    def item4(img, d, w, h):
        scatter(d, w, h, 12, avoid=lambda x, y: y > h * 0.25)
        sprout(img, w / 2, h * 0.98, h * 0.75, lw=6)

    def item5(img, d, w, h):
        scatter(d, w, h, 10, avoid=lambda x, y: y > h * 0.12)
        phone(img, w * 0.6, h * 0.48, 180, 320, angle=8, lw=6,
              content=lambda layer, sd, x0, y0, x1, y1: check_badge(sd, (x0 + x1) / 2, (y0 + y1) / 2, 46, lw=6))
        pineapple(img, w * 0.3, h * 0.94, h * 0.5)

    def item6(img, d, w, h):
        spots = [(0.25, 0.42, 0.34), (0.72, 0.4, 0.3), (0.5, 0.68, 0.38), (0.2, 0.95, 0.3), (0.82, 0.95, 0.32)]
        for x, y, size in spots:
            pineapple(img, w * x, h * y, h * size, lw=4)
        d = ImageDraw.Draw(img)
        sparkle(d, w * 0.5, h * 0.12, 14, lw=3)

    card("welcome_item1.png", BG_AMBER, item1)
    card("welcome_item2.png", BG_SKY, item2)
    card("welcome_item3.png", BG_PEACH, item3)
    card("welcome_item4.png", BG_CREAM, item4)
    card("welcome_item5.png", BG_GREEN, item5)
    card("welcome_item6.png", BG_AMBER, item6)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    slide1_main()
    slide2_main()
    slide3_main()
    floats()
    welcome_cards()
