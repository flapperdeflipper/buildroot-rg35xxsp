#!/usr/bin/env python3
"""Generate the RGOS emulator test ROMs (no third-party content).

Every ROM is assembled here from our own bytes. Each platform shows a
distinctive test screen so a screenshot proves both "the core runs
content" and "which core rendered it":

  gb   (gambatte)        DMG: bright top half, dark bottom half + beep
                          KNOWN ISSUE: does not render on the gambatte
                          core (verified on PyBoy); generated + installed
                          but has no menu entry until fixed
  nes  (nestopia)        black top half, white bottom half + beep
  gba  (mGBA)            mode 3 bitmap: red top half, blue bottom half + beep
  sfc  (snes9x)          solid green backdrop (colour 0)
  md   (Genesis-Plus-GX) solid test colour backdrop (CRAM colour 0)

Usage: rgos-roms.py <outdir>
"""

import hashlib
import os
import sys


# ---------------------------------------------------------------------------
# Label-patching helper for relative branches (GB jr / NES BNE / 68k bra).
# ---------------------------------------------------------------------------
class Rel:
    def __init__(self):
        self.buf = bytearray()
        self.labels = {}
        self.rel = []          # (off, label, size, endian)

    def here(self):
        return len(self.buf)

    def label(self, name):
        self.labels[name] = self.here()

    def emit(self, *vals):
        for v in vals:
            self.buf.append(v & 0xFF)

    def emit_be(self, word, size=2):
        self.buf += word.to_bytes(size, "big")

    def branch(self, label, size=2, endian="little"):
        self.rel.append((len(self.buf), label, size, endian))
        self.buf += b"\x00" * size

    def finish(self):
        for off, label, size, endian in self.rel:
            target = self.labels[label]
            here = off + size
            d = target - here
            lo, hi = min(d, 128), max(d, -129)
            assert lo >= -128 and hi <= 127 if size == 1 else True, (label, d)
            if size == 2:
                assert -32768 <= d <= 32767, (label, d)
            self.buf[off:off + size] = (d & ((1 << (8 * size)) - 1)).to_bytes(
                size, endian)
        return bytes(self.buf)


# ---------------------------------------------------------------------------
# GB / DMG (gambatte)
# ---------------------------------------------------------------------------
def gen_gb():
    rom = bytearray(0x8000)
    a = Rel()
    a.emit(0xF3)                                  # di
    a.emit(0x21, 0xFE, 0xFF)                      # ld sp,$FFFE
    # The boot LCD is ON: wait for vblank, then switch it off so the
    # VRAM fills below are not dropped (writes during rendering are lost)
    a.label("vbl")
    a.emit(0xF0, 0x44, 0xFE, 0x90, 0x38)          # ldh a,(LY); cp $90; jr c
    a.branch("vbl", 1)
    a.emit(0xAF, 0xE0, 0x40)                      # LCD off
    a.emit(0x3E, 0xE4, 0xE0, 0x47)                # BGP

    def fill(hl, count, value, tag):
        a.emit(0x21, hl >> 8, hl & 0xFF)          # ld hl,nn
        a.emit(0x01, count >> 8, count & 0xFF)    # ld bc,nn
        a.label(tag)
        a.emit(0x36, value)                       # ld (hl),n
        a.emit(0x23, 0x0B, 0x78, 0xB1)            # inc hl; dec bc; or b,c
        a.emit(0x20)                              # jr nz
        a.branch(tag, 1)

    fill(0x8000, 0x0010, 0x00, "t0")
    fill(0x8010, 0x0010, 0xFF, "t1")
    fill(0x9800, 0x0400, 0x00, "m0")
    fill(0x9800 + 9 * 32, 9 * 32, 0x01, "m1")

    a.emit(0x3E, 0x91, 0xE0, 0x40)                # LCD on, BG, tiles $8000
    for reg, val in ((0x26, 0x80), (0x24, 0x77), (0x25, 0x11),
                     (0x10, 0x00), (0x11, 0x80), (0x12, 0xF3),
                     (0x13, 0x00), (0x14, 0x87)):
        a.emit(0x3E, val, 0xE0, reg)              # sound on, ch1 tone
    a.label("end")
    a.emit(0x18)                                  # jr $ (self)
    a.branch("end", 1)

    code = a.finish()
    rom[0x100:0x104] = bytes([0x00, 0xC3, 0x50, 0x01])
    rom[0x150:0x150 + len(code)] = code
    rom[0x134:0x134 + 8] = b"RGOSTEST"
    rom[0x14A] = 0x01
    rom[0x14B] = 0x33
    c = 0
    for i in range(0x134, 0x14D):
        c = (c - rom[i] - 1) & 0xFF
    rom[0x14D] = c
    s = sum(rom) - rom[0x14E] - rom[0x14F]
    rom[0x14E:0x150] = bytes([(s >> 8) & 0xFF, s & 0xFF])
    return bytes(rom)


# ---------------------------------------------------------------------------
# NES (nestopia), mapper 0
# ---------------------------------------------------------------------------
def gen_nes():
    prg = bytearray(0x4000)
    chr_ = bytearray(0x2000)
    chr_[16:32] = b"\xFF" * 16

    a = Rel()
    a.emit(0x78, 0xD8)                            # SEI CLD
    a.emit(0xA2, 0x40, 0x8E, 0x17, 0x40)          # STX $4017 (no APU IRQ)
    for tag in ("v1", "v2"):
        a.label(tag)
        a.emit(0xAD, 0x02, 0x20, 0x10)            # LDA $2002; BPL
        a.branch(tag, 1)
    a.emit(0xA9, 0x00, 0x8D, 0x01, 0x20)          # render off

    def ppu_addr(addr):
        a.emit(0xA9, addr >> 8, 0x8D, 0x06, 0x20)
        a.emit(0xA9, addr & 0xFF, 0x8D, 0x06, 0x20)

    ppu_addr(0x3F00)
    for col in (0x0F, 0x16, 0x2A, 0x30):
        a.emit(0xA9, col, 0x8D, 0x07, 0x20)       # palette

    ppu_addr(0x2000)                              # nametable = tile 0
    a.emit(0xA9, 0x00, 0xA2, 0x04)                # A = tile, X = pages
    a.label("pg")
    a.emit(0xA0, 0x00)
    a.label("pgi")
    a.emit(0x8D, 0x07, 0x20, 0xC8, 0xD0)          # STA $2007; INY; BNE
    a.branch("pgi", 1)
    a.emit(0xCA, 0xD0)                            # DEX; BNE
    a.branch("pg", 1)

    ppu_addr(0x2000 + 15 * 32)                    # rows 15-29 = tile 1
    a.emit(0xA9, 0x01, 0xA0, 0x00)
    a.label("b1")
    a.emit(0x8D, 0x07, 0x20, 0xC8, 0xD0)
    a.branch("b1", 1)
    a.emit(0xA0, 0xE0)
    a.label("b2")
    a.emit(0x8D, 0x07, 0x20, 0xC8, 0xD0)
    a.branch("b2", 1)

    a.emit(0xA9, 0x00, 0x8D, 0x05, 0x20)          # scroll X
    a.emit(0xA9, 0x00, 0x8D, 0x05, 0x20)          # scroll Y
    a.emit(0xA9, 0x00, 0x8D, 0x00, 0x20)          # PPUCTRL
    a.emit(0xA9, 0x0E, 0x8D, 0x01, 0x20)          # PPUMASK BG on
    a.emit(0xA9, 0x01, 0x8D, 0x15, 0x40)          # pulse 1 length on
    a.emit(0xA9, 0xBE, 0x8D, 0x00, 0x40)
    a.emit(0xA9, 0x08, 0x8D, 0x01, 0x40)
    a.emit(0xA9, 0xFD, 0x8D, 0x02, 0x40)
    a.emit(0xA9, 0x08, 0x8D, 0x03, 0x40)
    # JMP to itself (idle): operand = the JMP's own PRG address
    jmp_off = len(a.buf)
    a.emit(0x4C, 0x00, 0x00)

    code = a.finish()
    code = bytearray(code)
    code[jmp_off + 1:jmp_off + 3] = (0xC000 + jmp_off).to_bytes(2, "little")
    prg[0:0 + len(code)] = code
    prg[0x3FFC:0x3FFE] = bytes([0x00, 0xC0])
    header = bytes([0x4E, 0x45, 0x53, 0x1A, 0x01, 0x01]) + b"\x00" * 10
    return bytes(header + prg + chr_)


# ---------------------------------------------------------------------------
# SNES LoROM (snes9x): solid green backdrop
# ---------------------------------------------------------------------------
def gen_snes():
    rom = bytearray(0x8000)
    code = bytes([
        0x78,                             # SEI
        0x18, 0xFB,                       # CLC; XCE
        0xE2, 0x20,                       # SEP #$20
        0xA9, 0x0F, 0x8D, 0x00, 0x21,     # INIDISP = $0F
        0xA9, 0x00, 0x8D, 0x21, 0x21,     # CGADD = 0
        0xA9, 0xE0, 0x8D, 0x22, 0x21,     # CGDATA = $03E0 (green)
        0xA9, 0x03, 0x8D, 0x22, 0x21,
        0x80, 0xFE,                       # BRA $
    ])
    rom[0:0 + len(code)] = code
    rom[0x7FC0:0x7FC0 + 21] = b"RGOS TEST ROM        "
    rom[0x7FD5] = 0x20                     # LoROM
    rom[0x7FD6] = 0x00
    rom[0x7FD7] = 0x07
    rom[0x7FD9] = 0x01                     # NTSC
    rom[0x7FDE:0x7FE0] = b"\xFF\xFF"
    rom[0x7FFC:0x7FFE] = bytes([0x00, 0x80])
    return bytes(rom)


# ---------------------------------------------------------------------------
# GBA (mGBA): mode 3, red top / blue bottom + PSG beep
# ---------------------------------------------------------------------------
def arm_imm(val):
    """ARM imm8 ror(2n) operand field, or assert."""
    for r in range(16):
        shift = 2 * r
        if shift == 0:
            imm = val & 0xFFFFFFFF
        else:
            imm = ((val << shift) | (val >> (32 - shift))) & 0xFFFFFFFF
        if imm <= 0xFF:
            return (r << 8) | imm
    raise AssertionError(hex(val))


def mov_imm(rd, val):
    return 0xE3A00000 | (rd << 12) | arm_imm(val)


def orr_imm(rd, rn, val):
    return 0xE3800000 | (rn << 16) | (rd << 12) | arm_imm(val)


def strh_imm(rd, rn, off):
    # P=1 U=1 W=0 L=0, halfword
    return (0xE1C00000 | (rn << 16) | (rd << 12)
            | ((off >> 4) << 8) | (0xB << 4) | (off & 0xF))


def str_imm(rd, rn, off=0):
    return 0xE5800000 | (rn << 16) | (rd << 12) | off


def gen_gba():
    rom = bytearray(0x4000)
    body = []

    def emit(w_):
        body.append(w_)

    def bne_back(target_idx):
        cur = len(body)
        emit(0x1A000000 | ((target_idx - cur - 2) & 0xFFFFFF))

    emit(mov_imm(0, 0x04000000))
    emit(mov_imm(1, 0x06000000))
    emit(mov_imm(2, 0x03))
    emit(orr_imm(2, 2, 0x0400))              # DISPCNT = mode3 | BG2
    emit(str_imm(2, 0, 0))
    emit(mov_imm(3, 0x1F))                   # red
    emit(0xE1833803)                         # orr r3,r3,r3,lsl 16 (2 px)
    emit(mov_imm(4, 9600))                   # top half words
    t = len(body)
    emit(0xE4813004)                         # str r3,[r1],#4
    emit(0xE2544001)                         # subs r4,#1
    bne_back(t)
    emit(mov_imm(3, 0x1F))
    emit(0xE1A03503)                         # lsl r3,r3,#10 (blue 0x7C00)
    emit(0xE1833803)
    emit(mov_imm(4, 9600))
    t = len(body)
    emit(0xE4813004)
    emit(0xE2544001)
    bne_back(t)
    # PSG beep via the legacy channels
    emit(mov_imm(2, 0x80))
    emit(strh_imm(2, 0, 0x84))               # SOUNDCNT_X: master on
    emit(mov_imm(2, 0x77))
    emit(orr_imm(2, 2, 0x0100))
    emit(orr_imm(2, 2, 0x0200))
    emit(strh_imm(2, 0, 0x80))               # SOUNDCNT_L: vol + ch1 L/R
    emit(mov_imm(2, 0x0002))
    emit(strh_imm(2, 0, 0x82))               # SOUNDCNT_H: PSG 100%
    for off, val in ((0x60, 0x00), (0x62, 0x80), (0x64, 0xF3),
                     (0x66, 0x00), (0x68, 0x87)):
        emit(mov_imm(2, val))
        emit(strh_imm(2, 0, off))            # NR10..NR14
    emit(0xEAFFFFFE)                         # b .

    rom[0x00:0x04] = (0xEA00002E).to_bytes(4, "little")   # b 0xC0
    rom[0xA0:0xA8] = b"RGOSTEST"
    rom[0xAC:0xB0] = b"1RGO"
    chk = 0
    for i in range(0xA0, 0xBD):
        chk = (chk - rom[i] - 1) & 0xFF
    rom[0xBD] = chk
    for i, word in enumerate(body):
        rom[0xC0 + i * 4:0xC4 + i * 4] = word.to_bytes(4, "little")
    return bytes(rom)


# ---------------------------------------------------------------------------
# MD (Genesis-Plus-GX): solid magenta backdrop
# ---------------------------------------------------------------------------
def gen_md():
    rom = bytearray(0x10000)
    rom[0x000:0x004] = (0x00FF8000).to_bytes(4, "big")   # initial SSP
    rom[0x004:0x008] = (0x00000200).to_bytes(4, "big")   # reset PC
    rom[0x100:0x110] = b"SEGA MEGA DRIVE "
    rom[0x1F0:0x1F1] = b"F"

    code = bytearray()

    def move_w_imm_abs(val, addr):
        code.extend((0x33FC).to_bytes(2, "big"))
        code.extend(val.to_bytes(2, "big"))
        code.extend(addr.to_bytes(4, "big"))             # abs.l

    def move_l_imm_abs(val, addr):
        code.extend((0x23FC).to_bytes(2, "big"))
        code.extend(val.to_bytes(4, "big"))
        code.extend(addr.to_bytes(4, "big"))             # abs.l

    code.extend((0x46FC).to_bytes(2, "big"))
    code.extend((0x2700).to_bytes(2, "big"))             # ints off
    move_w_imm_abs(0x0100, 0xA11100)                     # z80 bus request
    code.extend((0x4E71).to_bytes(2, "big") * 12)        # wait
    move_w_imm_abs(0x0000, 0xA11200)                     # z80 reset on
    for reg, val in ((0x00, 0x04), (0x01, 0x74), (0x02, 0x30),
                     (0x05, 0x7C), (0x0C, 0x81), (0x0D, 0x00)):
        move_w_imm_abs(0x8000 | (reg << 8) | val, 0xC00004)
    move_l_imm_abs(0xC0000000, 0xC00004)                 # CRAM ptr = 0
    move_w_imm_abs(0x01C7, 0xC00000)                     # magenta R7B7
    code.extend((0x60FE).to_bytes(2, "big"))             # bra.s $

    rom[0x200:0x200 + len(code)] = code
    return bytes(rom)


def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    for name, data in (
        ("rgos-test.gb", gen_gb()),
        ("rgos-test.nes", gen_nes()),
        ("rgos-test.sfc", gen_snes()),
        ("rgos-test.gba", gen_gba()),
        ("rgos-test.md", gen_md()),
    ):
        path = os.path.join(outdir, name)
        with open(path, "wb") as f:
            f.write(data)
        print(f"{name:14s} {len(data):6d} bytes  sha256 "
              f"{hashlib.sha256(data).hexdigest()[:16]}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
