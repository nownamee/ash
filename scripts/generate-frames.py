#!/usr/bin/env python3
"""Генерує 9-patch текстури рамок у zombie_game_3d_v3/ui/ (потрібен Pillow)."""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "zombie_game_3d_v3", "ui")
GOLD = (242, 200, 70, 255)
GOLD_D = (140, 98, 28, 255)
WOOD = (18, 11, 7, 240)
S = 4  # supersampling


def make(name, size, border, inset, orn):
    big = size * S
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = border * S
    d.rounded_rectangle([S, S, big - S - 1, big - S - 1], radius=r, fill=WOOD, outline=(8, 4, 2, 255), width=S)
    # outer gold line, dark gap, inner thin gold line
    o = 2 * S
    d.rounded_rectangle([o, o, big - o - 1, big - o - 1], radius=r - S, outline=GOLD, width=max(S, int(1.6 * S)))
    i = int(inset * S)
    d.rounded_rectangle([i, i, big - i - 1, big - i - 1], radius=max(2, r // 2), outline=GOLD_D, width=S)
    if orn:
        c = i + 2 * S
        for (cx, cy) in [(c, c), (big - c, c), (c, big - c), (big - c, big - c)]:
            d.regular_polygon((cx, cy, 4 * S), 4, rotation=0, fill=GOLD)
            d.ellipse([cx - 1.5 * S, cy - 1.5 * S, cx + 1.5 * S, cy + 1.5 * S], fill=(90, 20, 14, 255))
        m = big // 2
        for (cx, cy) in [(m, o + S), (m, big - o - S), (o + S, m), (big - o - S, m)]:
            d.regular_polygon((cx, cy, 3 * S), 4, rotation=0, fill=GOLD)
    im = im.resize((size, size), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name))


make("frame_panel.png", 96, 10, 7, True)
make("frame_plate.png", 48, 6, 4.5, False)
make("frame_ribbon.png", 64, 8, 5.5, True)
