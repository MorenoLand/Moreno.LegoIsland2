#!/usr/bin/env python3
"""Decode the game's .tga and .wib textures and write PNG files.

.tga is plain Targa (types 2 and 10, 24 or 32 bit). .wib holds one or more
frames: "WIBF" n, n u32 frame order, "WIBT" width height kind frames, then
the frames as raw pixels (kind 0: 3 bytes per pixel, otherwise 4).
"""
import struct
import sys
import zlib


def write_png(path, width, height, rgba):
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw += rgba[y * stride:(y + 1) * stride]

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 6)))
        f.write(chunk(b"IEND", b""))


def read_tga(data):
    idlen, cmap, kind = data[0], data[1], data[2]
    if cmap != 0 or kind not in (2, 10):
        raise ValueError("unsupported targa type %d" % kind)
    width, height, bits, desc = struct.unpack_from("<HHBB", data, 12)
    if bits not in (24, 32):
        raise ValueError("unsupported depth %d" % bits)
    bpp = bits // 8
    pos = 18 + idlen
    count = width * height
    if kind == 2:
        pix = data[pos:pos + count * bpp]
    else:
        out = bytearray()
        while len(out) < count * bpp:
            head = data[pos]
            pos += 1
            n = (head & 0x7F) + 1
            if head & 0x80:
                out += data[pos:pos + bpp] * n
                pos += bpp
            else:
                out += data[pos:pos + n * bpp]
                pos += n * bpp
        pix = bytes(out[:count * bpp])
    rgba = bytearray(count * 4)
    rgba[0::4] = pix[2::bpp]
    rgba[1::4] = pix[1::bpp]
    rgba[2::4] = pix[0::bpp]
    rgba[3::4] = pix[3::bpp] if bpp == 4 else b"\xff" * count
    if not desc & 0x20:
        stride = width * 4
        rows = [rgba[y * stride:(y + 1) * stride] for y in range(height)]
        rgba = bytearray(b"".join(reversed(rows)))
    return width, height, bytes(rgba)


def read_wib(data):
    if data[:4] != b"WIBF":
        raise ValueError("not a wib")
    n = struct.unpack_from("<I", data, 4)[0]
    order = list(struct.unpack_from("<%dI" % n, data, 8))
    pos = 8 + n * 4
    if data[pos:pos + 4] != b"WIBT":
        raise ValueError("missing WIBT")
    width, height, kind, frames = struct.unpack_from("<4I", data, pos + 4)
    pos += 20
    bpp = 3 if kind == 0 else 4
    size = width * height * bpp
    out = []
    for i in range(frames):
        pix = data[pos + i * size:pos + (i + 1) * size]
        rgba = bytearray(width * height * 4)
        rgba[0::4] = pix[2::bpp]
        rgba[1::4] = pix[1::bpp]
        rgba[2::4] = pix[0::bpp]
        rgba[3::4] = pix[3::bpp] if bpp == 4 else b"\xff" * (width * height)
        out.append(bytes(rgba))
    return width, height, order, out


def main():
    if len(sys.argv) < 3:
        print("usage: images.py <file.tga|file.wib> <out.png>", file=sys.stderr)
        return 2
    data = open(sys.argv[1], "rb").read()
    if data[:4] == b"WIBF":
        w, h, order, frames = read_wib(data)
        write_png(sys.argv[2], w, h, frames[0])
    else:
        w, h, rgba = read_tga(data)
        write_png(sys.argv[2], w, h, rgba)
    return 0


if __name__ == "__main__":
    sys.exit(main())
