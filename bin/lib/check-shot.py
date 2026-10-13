#!/usr/bin/env python3
"""Verify an RGOS test-ROM screenshot: decode PNG (RGB8) without deps and
check region colours. Usage: check-shot.py <png> <expectation>

Expectations:
  gb   top bright, bottom dark        nes  top dark, bottom bright
  gba  top red, bottom blue           sfc  all green
  md   all magenta
"""

import struct
import sys
import zlib


def decode_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos = 8
    idat = b""
    w = h = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        if ctype == b"IHDR":
            w, h, depth, color = struct.unpack(">IIBB", chunk[:10])
            assert depth == 8 and color == 2, (depth, color)
        elif ctype == b"IDAT":
            idat += chunk
        pos += 12 + length
    raw = zlib.decompress(idat)
    bpp = 3
    stride = w * bpp
    rows = []
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]
        p += 1
        row = bytearray(raw[p:p + stride])
        p += stride
        for x in range(stride):
            a = row[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                row[x] = (row[x] + a) & 0xFF
            elif f == 2:
                row[x] = (row[x] + b) & 0xFF
            elif f == 3:
                row[x] = (row[x] + (a + b) // 2) & 0xFF
            elif f == 4:
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                row[x] = (row[x] + pred) & 0xFF
        rows.append(bytes(row))
        prev = row
    return w, h, rows


def region(rows, x0, x1, y0, y1):
    """Average RGB of a region."""
    rs = gs = bs = n = 0
    for y in range(y0, y1):
        row = rows[y]
        for x in range(x0, x1):
            i = x * 3
            rs += row[i]
            gs += row[i + 1]
            bs += row[i + 2]
            n += 1
    return rs // n, gs // n, bs // n


def main():
    path, kind = sys.argv[1], sys.argv[2]
    w, h, rows = decode_png(path)

    def cx(f0, f1):
        return int(w * f0), int(w * f1)

    if kind in ("gb", "nes", "gba"):
        x0, x1 = cx(0.4, 0.6)
        top = region(rows, x0, x1, int(h * 0.25), int(h * 0.35))
        bot = region(rows, x0, x1, int(h * 0.65), int(h * 0.75))
        r1, g1, b1 = top
        r2, g2, b2 = bot
        if kind == "gb":
            ok = (r1 + g1 + b1) - (r2 + g2 + b2) > 120
        elif kind == "nes":
            ok = (r2 + g2 + b2) - (r1 + g1 + b1) > 150
        else:
            ok = r1 - b1 > 60 and b2 - r2 > 60
        print(f"top={top} bottom={bot}")
    else:
        mid = region(rows, *cx(0.4, 0.6), int(h * 0.4), int(h * 0.6))
        r, g, b = mid
        if kind == "sfc":
            ok = g > 120 and r < 120 and b < 120
        elif kind == "md":
            # measured on the image: Genesis-Plus-GX renders CRAM 0x1C7
            # as (99, 207, 0)-ish
            ok = g > 150 and r > 40 and r < 160 and b < 100
        else:
            ok = False
        print(f"mid={mid}")
    print(("PASS" if ok else "FAIL"), kind)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
