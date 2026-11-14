#!/usr/bin/env python3
"""Регрессионные проверки упаковки ICNS: python3 -m unittest discover -s Icon -p 'test_*.py'."""

import struct
import tempfile
import unittest
from pathlib import Path

from make_icons import pack_icns, write_png


class IconPackagingTests(unittest.TestCase):
    """Проверяет контейнер и отказ при неполном или повреждённом наборе."""

    def test_png_elements_roundtrip(self) -> None:
        """ICNS сохраняет каждый PNG и правильные границы элементов."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            expected = {}
            for base in (16, 32, 128, 256, 512):
                for scale in (1, 2):
                    side = base * scale
                    suffix = "@2x" if scale == 2 else ""
                    png = root / f"icon_{base}x{base}{suffix}.png"
                    write_png(png, side, side, [bytes((200, 100, 50, 128)) * side] * side)
                    expected[png.name] = png.read_bytes()
            output = root / "AppIcon.icns"
            pack_icns(root, output)
            data = output.read_bytes()
            self.assertEqual(data[:4], b"icns")
            self.assertEqual(struct.unpack(">I", data[4:8])[0], len(data))
            # Независимая таблица формата: тип -> логический размер, масштаб.
            names = {
                b"ic04": "icon_16x16.png", b"ic11": "icon_16x16@2x.png",
                b"ic05": "icon_32x32.png", b"ic12": "icon_32x32@2x.png",
                b"ic07": "icon_128x128.png", b"ic13": "icon_128x128@2x.png",
                b"ic08": "icon_256x256.png", b"ic14": "icon_256x256@2x.png",
                b"ic09": "icon_512x512.png", b"ic10": "icon_512x512@2x.png",
            }
            offset = 8
            found = set()
            while offset < len(data):
                kind, length = struct.unpack(">4sI", data[offset:offset + 8])
                self.assertNotIn(kind, found)
                self.assertGreater(length, 8)
                payload = data[offset + 8:offset + length]
                if kind in (b"ic04", b"ic05"):
                    self.assertEqual(payload[:4], b"ARGB")
                    # Проверяем порядок ARGB и умножение RGB на альфу 128/255.
                    pixels = 16 * 16 if kind == b"ic04" else 32 * 32
                    packed = b"".join(
                        (b"\x7f" + bytes([value]) * 128) * (pixels // 128)
                        for value in (128, 100, 50, 25)
                    )
                    self.assertEqual(payload[4:], packed)
                else:
                    self.assertEqual(payload, expected[names[kind]])
                found.add(kind)
                offset += length
            self.assertEqual(offset, len(data))
            self.assertEqual(found, set(names))

    def test_missing_source_does_not_write_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "AppIcon.icns"
            with self.assertRaises(FileNotFoundError):
                pack_icns(root, output)
            self.assertFalse(output.exists())

    def test_invalid_png_does_not_write_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "icon_16x16.png").write_bytes(b"not a png")
            output = root / "AppIcon.icns"
            with self.assertRaises(ValueError):
                pack_icns(root, output)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
