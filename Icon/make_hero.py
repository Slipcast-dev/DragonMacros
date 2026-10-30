#!/usr/bin/env python3
"""Заменяет подпись «Global hotkeys for macOS» на слоган в docs/images/hero.png и social-preview.png.
Исходные картинки (без нового слогана) — Icon/source/hero-original.png и social-original.png. Нужен Pillow."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__)); SRC = os.path.join(HERE, "source"); OUT = os.path.join(HERE, "..", "docs", "images")
FONT = "/System/Library/Fonts/Helvetica.ttc"
LINES = ["Доли секунды решают всё.", "Макрос решает за них."]

def build(src, dst, k):
    im = Image.open(os.path.join(SRC, src)).convert("RGB")
    s = im.width / 1774                      # координаты заданы для hero (1774 px)
    x0, x1, y0, y1 = int(80 * s), int(755 * s), int(534 * s), int(606 * s)
    # заливка: по каждой строке плавный переход от цвета фона слева к цвету фона справа от старой подписи
    for y in range(y0, y1):
        l = im.crop((int(30 * s), y, int(70 * s), y + 1)).resize((1, 1), Image.BOX).getpixel((0, 0))
        r = im.crop((int(760 * s), y, int(790 * s), y + 1)).resize((1, 1), Image.BOX).getpixel((0, 0))
        for x in range(x0, x1):
            t = (x - x0) / (x1 - x0)
            im.putpixel((x, y), tuple(round(l[i] + (r[i] - l[i]) * t) for i in range(3)))
    d = ImageDraw.Draw(im); f = ImageFont.truetype(FONT, int(38 * s))
    for i, t in enumerate(LINES):
        d.text((int(98 * s), int((545 + 44 * i) * s)), t, font=f, fill=(244, 236, 230))
    im.save(os.path.join(OUT, dst), optimize=True)

if __name__ == "__main__":
    build("hero-original.png", "hero.png", 1); build("social-original.png", "social-preview.png", 1)
