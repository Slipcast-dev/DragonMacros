#!/usr/bin/env python3
"""Рисует docs/images/banner.png (1280×400). Нужен Pillow; ресурсы — из Icon/source/ (см. prepare_logo.py)."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, "..")
W, H, K = 1280, 400, 2                      # K — суперсэмплинг
FONT = "/System/Library/Fonts/Helvetica.ttc"
def font(size, bold=False): return ImageFont.truetype(FONT, size * K, index=1 if bold else 0)

def main():
    # фон: тёмный градиент + красное свечение слева
    bg = Image.new("RGB", (W * K, H * K))
    px = ImageDraw.Draw(bg)
    c0, c1 = (43, 10, 18), (9, 3, 5)
    for x in range(W * K):
        t = x / (W * K - 1)
        px.line([(x, 0), (x, H * K)], fill=tuple(round(c0[i] + (c1[i] - c0[i]) * t) for i in range(3)))
    glow = Image.new("RGBA", (W * K, H * K), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([-200 * K, -100 * K, 650 * K, 500 * K], fill=(200, 16, 46, 120))
    bg = Image.alpha_composite(bg.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(90 * K)))
    # круг с драконом
    cx, cy, r = 250 * K, 200 * K, 170 * K
    emb = Image.open(os.path.join(HERE, "source", "dragon-emblem.png")).convert("RGBA").resize((2 * r, 2 * r), Image.LANCZOS)
    mask = Image.new("L", (2 * r, 2 * r), 0); ImageDraw.Draw(mask).ellipse([0, 0, 2 * r - 1, 2 * r - 1], fill=255)
    ring = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([cx - r - 10 * K, cy - r - 10 * K, cx + r + 10 * K, cy + r + 10 * K], fill=(255, 250, 245, 255))
    bg = Image.alpha_composite(bg, ring)
    bg.paste(emb, (cx - r, cy - r), mask)
    d = ImageDraw.Draw(bg)
    x0 = 500 * K
    d.text((x0, 88 * K), "Dragon Macros", font=font(88, True), fill=(255, 255, 255))
    # красная линия, затухающая вправо
    for i in range(460 * K):
        a = 1 - i / (460 * K)
        d.line([(x0 + i, 214 * K), (x0 + i, 218 * K)], fill=(round(9 + (229 - 9) * a), round(3 + (34 - 3) * a), round(5 + (42 - 5) * a)))
    d.text((x0, 240 * K), "Доли секунды решают всё. Макрос решает за них", font=font(27), fill=(255, 226, 228))
    d.text((x0, 286 * K), "Split seconds decide everything. A macro decides for you", font=font(24), fill=(222, 150, 158))
    d.text((x0, 340 * K), "macOS 11+  ·  INTEL  ·  APPLE SILICON  ·  SWIFT  ·  RU / EN", font=font(20), fill=(176, 108, 116))
    os.makedirs(os.path.join(ROOT, "docs", "images"), exist_ok=True)
    bg.convert("RGB").resize((W, H), Image.LANCZOS).save(os.path.join(ROOT, "docs", "images", "banner.png"), optimize=True)

if __name__ == "__main__": main()
