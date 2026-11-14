#!/usr/bin/env python3
"""Сборка иконок DragonMacros из Icon/source/japan-app-icon.png и status-template.png: AppIcon.icns и StatusIcon@2x.png (шаблонный значок для строки меню).
Требуется macOS: sips (масштаб). ICNS собирается напрямую из PNG; сторонние пакеты не нужны."""
import os, struct, subprocess, sys, zlib, shutil
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", ".build", "icons")

def run(*args: str) -> None:
    """Запускает инструмент; stderr сохраняется для диагностики ошибок сборки."""
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL)


# Типы элементов ICNS различают обычные и Retina-изображения одного размера.
ICON_ELEMENTS = (
    (b"ic04", 16, 1), (b"ic11", 16, 2),
    (b"ic05", 32, 1), (b"ic12", 32, 2),
    (b"ic07", 128, 1), (b"ic13", 128, 2),
    (b"ic08", 256, 1), (b"ic14", 256, 2),
    (b"ic09", 512, 1), (b"ic10", 512, 2),
)


def pack_icns(iconset: Path, destination: Path) -> None:
    """Собирает стандартный ICNS из PNG без зависимости от упаковщика iconutil.

    Крупные элементы содержат PNG, а 16/32 px — четыре плоскости ARGB.
    Перед записью проверяются сигнатура и размеры каждого обязательного файла.
    """
    chunks: list[bytes] = []
    for kind, base, scale in ICON_ELEMENTS:
        suffix = "@2x" if scale == 2 else ""
        source = iconset / f"icon_{base}x{base}{suffix}.png"
        data = source.read_bytes()
        expected = base * scale
        if (len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n"
                or data[12:16] != b"IHDR"
                or struct.unpack(">II", data[16:24]) != (expected, expected)):
            raise ValueError(f"Некорректный PNG или размер иконки: {source}")
        if kind in (b"ic04", b"ic05"):
            # Системный Icon Services ожидает ARGB для малых иконок.
            # Используем допустимые буквальные RLE-блоки (до 128 байтов).
            _, _, rows = read_png(source)
            rgba = bytearray(b"".join(rows))
            # ARGB хранит RGB с предварительным умножением на альфа-канал.
            for i in range(0, len(rgba), 4):
                alpha = rgba[i + 3]
                for channel in range(3):
                    rgba[i + channel] = (rgba[i + channel] * alpha + 127) // 255
            planes = []
            for channel in (3, 0, 1, 2):
                plane = rgba[channel::4]
                planes.extend(bytes([len(plane[i:i + 128]) - 1]) + plane[i:i + 128]
                              for i in range(0, len(plane), 128))
            data = b"ARGB" + b"".join(planes)
        chunks.append(struct.pack(">4sI", kind, len(data) + 8) + data)
    body = b"".join(chunks)
    destination.write_bytes(struct.pack(">4sI", b"icns", len(body) + 8) + body)


def read_png(path):
    """Читает PNG 8 бит (RGB или RGBA, без чересстрочности) и возвращает (w, h, строки RGBA)."""
    d = Path(path).read_bytes(); i = 8; idat = b""
    while i < len(d):
        n, t = struct.unpack(">I4s", d[i:i+8]); c = d[i+8:i+8+n]
        if t == b"IHDR": w, h, bd, ct, _, _, il = struct.unpack(">IIBBBBB", c)
        if t == b"IDAT": idat += c
        i += 12 + n
    assert bd == 8 and ct in (2, 6) and il == 0, "ожидается RGB/RGBA 8 бит без чересстрочности"
    bpp = 3 if ct == 2 else 4
    raw = zlib.decompress(idat); stride = w * bpp; rows = []; prev = bytearray(stride); p = 0
    for _ in range(h):
        f = raw[p]; line = bytearray(raw[p+1:p+1+stride]); p += 1 + stride
        for x in range(stride):
            a = line[x-bpp] if x >= bpp else 0; b = prev[x]; c = prev[x-bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif f == 4:
                pa, pb, pc = abs(b-c), abs(a-c), abs(a+b-2*c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        prev = line
        if bpp == 3:
            r = bytearray(w * 4)
            for x in range(w): r[x*4:x*4+3] = line[x*3:x*3+3]; r[x*4+3] = 255
            line = r
        rows.append(line)
    return w, h, rows

def write_png(path, w, h, rows):
    def chunk(t, c):
        return struct.pack(">I", len(c)) + t + c + struct.pack(">I", zlib.crc32(t + c) & 0xffffffff)
    body = b"".join(b"\x00" + bytes(r) for r in rows)
    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(body, 9)) + chunk(b"IEND", b""))

def render(svg, size, name):
    run("qlmanage", "-t", "-s", str(size), "-o", OUT, os.path.join(HERE, svg))
    return os.path.join(OUT, svg + ".png")

def sdf_round_rect(px, py, cx=512.0, cy=512.0, half=412.0, r=185.0):
    """Расстояние до скруглённого квадрата стандартной иконки macOS (824×824 на холсте 1024; <0 — внутри)."""
    qx = abs(px - cx) - (half - r); qy = abs(py - cy) - (half - r)
    return (max(qx, 0) ** 2 + max(qy, 0) ** 2) ** 0.5 + min(max(qx, qy), 0) - r

def scale_png(src, size, dst):
    run("sips", "-z", str(size), str(size), src, "--out", dst)

def main() -> None:
    """Масштабирует утверждённую японскую иконку, сохраняя альфа-канал плитки.

    Ресурс уже содержит форму и мягкую тень: повторное рисование белой плитки
    исказило бы утверждённый дизайн. Упаковка ICNS остаётся независимой от iconutil.
    """
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    source = os.path.join(HERE, "source", "japan-app-icon.png")
    iconset = Path(OUT) / "AppIcon.iconset"
    iconset.mkdir()
    for base in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            suffix = "@2x" if scale == 2 else ""
            scale_png(source, base * scale, str(iconset / f"icon_{base}x{base}{suffix}.png"))
    pack_icns(iconset, Path(OUT) / "AppIcon.icns")
    # Системный шаблон значка строки меню сохраняется отдельно от цветной иконки.
    status = os.path.join(HERE, "source", "status-template.png")
    scale_png(status, 36, os.path.join(OUT, "StatusIcon@2x.png"))
    scale_png(status, 18, os.path.join(OUT, "StatusIcon.png"))
    print("Готово:", OUT)


if __name__ == "__main__":
    main()
