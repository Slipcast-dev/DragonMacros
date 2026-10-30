#!/usr/bin/env python3
"""Готовит ресурсы дракона из source/dragon-logo-original.png (одноцветный силуэт на белом фоне).
Нужен Pillow: pip3 install pillow. Результат (в source/): dragon-mark.png, dragon-emblem.png, icon-tile.png, status-template.png (буква M для строки меню)."""
import os
from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__)); SRC = os.path.join(HERE, "source")
RED = (200, 16, 46)

def load_alpha(size=1024):
    g = Image.open(os.path.join(SRC, "dragon-logo-original.png")).convert("L").resize((size, size), Image.LANCZOS)
    h = g.histogram(); lo = max(range(128), key=lambda i: h[i])   # цвет заливки — самое частое тёмное значение
    a = g.point(lambda v: max(0, min(255, round((255 - v) * 255 / (255 - lo)))))
    box = a.point(lambda v: 255 if v > 40 else 0).getbbox()
    a = a.crop(box)
    s = max(a.size); sq = Image.new("L", (s, s), 0); sq.paste(a, ((s - a.width) // 2, (s - a.height) // 2))
    return sq                                  # силуэт по центру квадрата, плотно по краям

def paint(alpha, size, color=None, gradient=False):
    a = alpha.resize((size, size), Image.LANCZOS)
    if gradient:
        top, bot = (222, 30, 58), (140, 8, 28)
        col = Image.new("RGB", (size, size))
        for y in range(size):
            t = y / (size - 1); col.paste(tuple(round(top[i] + (bot[i] - top[i]) * t) for i in range(3)), (0, y, size, y + 1))
    else:
        col = Image.new("RGB", (size, size), color)
    out = col.convert("RGBA"); out.putalpha(a); return out

def place(base, mark, box):
    m = mark.resize((box, box), Image.LANCZOS)
    base.alpha_composite(m, ((base.width - box) // 2, (base.height - box) // 2)); return base

def main():
    al = load_alpha()
    paint(al, 1024, RED).save(os.path.join(SRC, "dragon-mark.png"))
    # эмблема: кремовый диск с красным кольцом и драконом (для круга в шапке окна)
    S = 740; k = 4
    big = Image.new("RGBA", (S * k, S * k), (255, 250, 245, 255)); d = ImageDraw.Draw(big)
    d.ellipse([S*k*0.04, S*k*0.04, S*k*0.96, S*k*0.96], outline=RED + (255,), width=int(S*k*0.012))
    place(big, paint(al, 1024, RED), int(S * k * 0.62))
    big.resize((S, S), Image.LANCZOS).convert("RGB").save(os.path.join(SRC, "dragon-emblem.png"))
    # плитка иконки приложения: белый фон, дракон с красным градиентом
    tile = Image.new("RGBA", (1024, 1024), (255, 255, 255, 255))
    place(tile, paint(al, 1024, gradient=True), 640); tile.convert("RGB").save(os.path.join(SRC, "icon-tile.png"))
    # шаблонный значок строки меню: буква «M» (чёрная, прозрачность из альфы; macOS перекрашивает под тему)
    k = 4; st = Image.new("L", (144 * k, 144 * k), 0)
    f = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 150 * k, index=1)
    box = ImageDraw.Draw(st).textbbox((0, 0), "M", font=f)
    ImageDraw.Draw(st).text(((144 * k - (box[2] - box[0])) // 2 - box[0], (144 * k - (box[3] - box[1])) // 2 - box[1]), "M", font=f, fill=255)
    out = Image.new("RGBA", st.size, (0, 0, 0, 0)); out.putalpha(st)
    out.resize((144, 144), Image.LANCZOS).save(os.path.join(SRC, "status-template.png"))

if __name__ == "__main__": main()
