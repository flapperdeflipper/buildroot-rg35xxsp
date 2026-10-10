#!/usr/bin/env python3
"""Generate the RGOS wallpaper: a soft diagonal gradient with a subtle glow.

Pure Python (zlib + struct), so it runs with Buildroot's host-python3.
Usage: gen-wallpaper.py <out.png> [width height]
"""

import math
import struct
import sys
import zlib


def png(path, width, height, rows):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + row for row in rows)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def main():
    out = sys.argv[1]
    width = int(sys.argv[2]) if len(sys.argv) > 2 else 1280
    height = int(sys.argv[3]) if len(sys.argv) > 3 else 960

    top_left = (24, 40, 64)       # deep blue
    bottom_right = (18, 92, 104)  # teal
    glow = (90, 150, 190)
    gx, gy = width * 0.72, height * 0.30
    radius = math.hypot(width, height) * 0.45

    rows = []
    for y in range(height):
        row = bytearray()
        for x in range(width):
            t = (x / width + y / height) / 2
            g = max(0.0, 1 - math.hypot(x - gx, y - gy) / radius) ** 2 * 0.35
            for c in range(3):
                v = top_left[c] * (1 - t) + bottom_right[c] * t
                v = v * (1 - g) + glow[c] * g
                row.append(int(v))
        rows.append(bytes(row))
    png(out, width, height, rows)


if __name__ == "__main__":
    main()
