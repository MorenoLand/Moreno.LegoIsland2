#!/usr/bin/env python3
"""Extract the fixed tables the port keeps reading out of the game's executable.

The running game must never open the .exe (it has to work where there is no
Windows install), so everything it used to look up by address is dumped here
once, into plain text tables under data/.

    py -3 -I tools/game_tables.py "path/to/LEGO Island 2.exe"

Re-run only when the tables below change; they are constants of the original
program, not per-install data.
"""
import os
import struct
import sys

IMAGE_BASE_FALLBACK = 0x400000

MENU_ARRAY = 0x9741F8
MENU_STRIDE = 0x14
MENU_COUNT = 32
MENU_ITEM_STRIDE = 0x4C
MENU_ITEM_MAX = 24

ROW_TABLE = 0x899754
ROW_COUNT = 40
STYLE_TABLE = 0x899844
STYLE_COUNT = 8
KEYS_ROW_TABLE = 0x8997A4
KEYS_ROW_COUNT = 24

CREDITS_TABLE = 0x925048
CREDITS_STRIDE = 0x108
CREDITS_COUNT = 0xE1

ACTIONS = 0x89E190
ACTION_STRIDE = 0x30
ACTION_COUNT = 13
NAMES = 0x89E5A8

STATE_TABLE = 0x8993AC
STATE_STRIDE = 0xC
STATE_MAX = 64


class Pe:
    def __init__(self, path):
        self.data = open(path, "rb").read()
        if self.data[:2] != b"MZ":
            raise SystemExit("not a PE file: " + path)
        pe = struct.unpack_from("<I", self.data, 0x3C)[0]
        count = struct.unpack_from("<H", self.data, pe + 6)[0]
        optional = struct.unpack_from("<H", self.data, pe + 20)[0]
        self.base = struct.unpack_from("<I", self.data, pe + 24 + 28)[0] or IMAGE_BASE_FALLBACK
        at = pe + 24 + optional
        self.sections = []
        for _ in range(count):
            vsize, va, rsize, roff = struct.unpack_from("<IIII", self.data, at + 8)
            self.sections.append((self.base + va, max(vsize, rsize), roff, rsize))
            at += 40

    def offset(self, va):
        for start, size, roff, rsize in self.sections:
            if start <= va < start + size:
                rel = va - start
                if rel < rsize:
                    return roff + rel
        return -1

    def u32(self, va):
        o = self.offset(va)
        return struct.unpack_from("<I", self.data, o)[0] if o >= 0 else 0

    def s32(self, va):
        o = self.offset(va)
        return struct.unpack_from("<i", self.data, o)[0] if o >= 0 else 0

    def cstr(self, va, limit=64):
        o = self.offset(va)
        if o < 0:
            return ""
        end = o
        while end < o + limit and self.data[end] != 0:
            end += 1
        return self.data[o:end].decode("latin-1")


def clean(text):
    return text.replace("\t", " ").replace("\r", " ").replace("\n", " ").strip()


def write(path, rows, header):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\t".join(header) + "\n")
        for row in rows:
            f.write("\t".join(str(c) for c in row) + "\n")
    print("%-18s %d rows" % (os.path.basename(path), len(rows)))


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    exe = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
    pe = Pe(exe)

    write(os.path.join(out, "menu_rows.tsv"),
          [[i, pe.s32(ROW_TABLE + i * 4)] for i in range(ROW_COUNT)], ["row", "code"])

    write(os.path.join(out, "menu_styles.tsv"),
          [[i, pe.u32(STYLE_TABLE + i * 4)] for i in range(STYLE_COUNT)], ["style", "value"])

    write(os.path.join(out, "menu_keys_rows.tsv"),
          [[i, pe.s32(KEYS_ROW_TABLE + i * 4)] for i in range(KEYS_ROW_COUNT)], ["row", "code"])

    menus = []
    for i in range(MENU_COUNT):
        at = MENU_ARRAY + i * MENU_STRIDE
        count = pe.u32(at + 4)
        items_at = pe.u32(at + 8)
        if count == 0 or count > MENU_ITEM_MAX or pe.offset(items_at) < 0:
            break
        for k in range(count):
            rec = items_at + k * MENU_ITEM_STRIDE
            menus.append([i, k, pe.u32(at), count, pe.u32(at + 16), pe.u32(at + 12),
                          clean(pe.cstr(rec)), pe.s32(rec + 0x40), pe.s32(rec + 0x44),
                          pe.s32(rec + 0x48)])
    write(os.path.join(out, "menus.tsv"), menus,
          ["menu", "item", "type", "count", "style", "callback", "name",
           "item_type", "value", "flags"])

    write(os.path.join(out, "credits.tsv"),
          [[i, pe.u32(CREDITS_TABLE + i * CREDITS_STRIDE),
            clean(pe.cstr(CREDITS_TABLE + 4 + i * CREDITS_STRIDE, CREDITS_STRIDE - 4))]
           for i in range(CREDITS_COUNT)], ["index", "kind", "key"])

    write(os.path.join(out, "key_actions.tsv"),
          [[i, clean(pe.cstr(ACTIONS + i * ACTION_STRIDE, ACTION_STRIDE)),
            pe.u32(ACTIONS + i * ACTION_STRIDE + 0x20),
            pe.u32(ACTIONS + i * ACTION_STRIDE + 0x24),
            pe.u32(ACTIONS + i * ACTION_STRIDE + 0x28)] for i in range(ACTION_COUNT)],
          ["index", "name", "fixed", "value", "mask"])

    names = []
    at = NAMES
    while True:
        scan = pe.s32(at)
        if scan == -1:
            break
        names.append([scan, clean(pe.cstr(pe.u32(at + 4), 24))])
        at += 8
    write(os.path.join(out, "key_names.tsv"), names, ["scan", "text"])

    states = []
    for i in range(STATE_MAX):
        key = pe.cstr(STATE_TABLE + i * STATE_STRIDE, STATE_STRIDE)
        if not key.startswith("FSMSTATE"):
            break
        states.append([i, clean(key)])
    write(os.path.join(out, "state_keys.tsv"), states, ["index", "key"])


if __name__ == "__main__":
    main()