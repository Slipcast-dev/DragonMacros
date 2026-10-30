#!/usr/bin/env python3
"""Готовит ресурсы дракона из source/dragon-logo-original.png (одноцветный силуэт на белом фоне).
Нужен Pillow: pip3 install pillow. Результат (в source/): dragon-mark.png, dragon-emblem.png, icon-tile.png, status-template.png (дракон в кольце для строки меню)."""
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
    # эмблема: тёплый кремовый диск (не слепящий белый) и крупный тёмно-красный дракон — чётко виден даже в 60 пикселях
    S = 1024; k = 2
    big = Image.new("RGBA", (S * k, S * k), (240, 231, 226, 255))
    place(big, paint(al, 1024, (168, 14, 38)), int(S * k * 0.76))
    big.resize((S, S), Image.LANCZOS).convert("RGB").save(os.path.join(SRC, "dragon-emblem.png"))
    # плитка иконки приложения: белый фон, дракон с красным градиентом
    tile = Image.new("RGBA", (1024, 1024), (255, 255, 255, 255))
    place(tile, paint(al, 1024, gradient=True), 640); tile.convert("RGB").save(os.path.join(SRC, "icon-tile.png"))
    # шаблонный значок строки меню: дракон в кольце (как эмблема Mortal Kombat); чёрный шаблон, прозрачность = рисунок,
    # macOS перекрашивает его под тему строки меню
    k = 4; N = 144
    ring = Image.new("L", (N * k, N * k), 0); rd = ImageDraw.Draw(ring)
    rd.ellipse([3 * k, 3 * k, (N - 3) * k - 1, (N - 3) * k - 1], fill=255)
    rd.ellipse([13 * k, 13 * k, (N - 13) * k - 1, (N - 13) * k - 1], fill=0)
    dr = al.resize((int(N * k * 0.74),) * 2, Image.LANCZOS)
    st = ring.copy(); st.paste(255, ((N * k - dr.width) // 2, (N * k - dr.height) // 2 + 2 * k), dr)
    out = Image.new("RGBA", st.size, (0, 0, 0, 0)); out.putalpha(st)
    out.resize((N, N), Image.LANCZOS).save(os.path.join(SRC, "status-template.png"))

if __name__ == "__main__": main()
