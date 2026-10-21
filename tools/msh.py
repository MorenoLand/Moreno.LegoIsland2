#!/usr/bin/env python3
"""Reader for the game's .msh meshes.

Layout (little endian):
  "VERT", n, then n vertices of 32 bytes: x y z (float), colour (u32 ARGB),
      u v u2 v2 (float)
  n normals of 3 floats
  "INDL", k, then k u16 indices (triangle list)
  "GRPL", g, then g groups of five u32 words
"""
import struct
import sys


class Mesh:
    __slots__ = ("positions", "colors", "uvs", "uvs2", "normals", "indices", "groups", "tags", "transforms", "weld")


def parse(data):
    if data[:4] != b"VERT":
        raise ValueError("not a mesh")
    n = struct.unpack_from("<I", data, 4)[0]
    pos = 8
    m = Mesh()
    m.positions, m.colors, m.uvs, m.uvs2 = [], [], [], []
    for i in range(n):
        x, y, z, c, u, v, u2, v2 = struct.unpack_from("<3fI4f", data, pos + i * 32)
        m.positions.append((x, y, z))
        m.colors.append(c)
        m.uvs.append((u, v))
        m.uvs2.append((u2, v2))
    pos += n * 32
    m.normals = [struct.unpack_from("<3f", data, pos + i * 12) for i in range(n)]
    pos += n * 12
    if data[pos:pos + 4] != b"INDL":
        raise ValueError("missing index list at %d" % pos)
    k = struct.unpack_from("<I", data, pos + 4)[0]
    pos += 8
    m.indices = list(struct.unpack_from("<%dH" % k, data, pos))
    pos += k * 2
    if data[pos:pos + 4] != b"GRPL":
        raise ValueError("missing group list at %d" % pos)
    g = struct.unpack_from("<I", data, pos + 4)[0]
    pos += 8
    m.groups = [struct.unpack_from("<5I", data, pos + i * 20) for i in range(g)]
    pos += g * 20
    m.tags, m.transforms, m.weld = [], [], b""
    while pos < len(data):
        tag = data[pos:pos + 4]
        count = struct.unpack_from("<I", data, pos + 4)[0]
        pos += 8
        if tag == b"GTOM":
            m.tags = list(struct.unpack_from("<%dI" % count, data, pos))
            pos += count * 4
        elif tag == b"MATL":
            m.transforms = [struct.unpack_from("<9f", data, pos + i * 36) for i in range(count)]
            pos += count * 36
        elif tag == b"SVWL":
            m.weld = data[pos:]
            pos = len(data)
        else:
            raise ValueError("unknown chunk %r at %d" % (tag, pos - 8))
    if pos != len(data):
        raise ValueError("%d bytes left over" % (len(data) - pos))
    return m


def main():
    sys.path.insert(0, __file__.rsplit("tools", 1)[0] + "tools")
    import bob
    import os
    folder = sys.argv[1]
    ok = bad = 0
    shapes = {}
    for base in bob.find_archives(folder):
        arc = bob.Archive(base)
        with open(base + ".bob", "rb") as f:
            for e in arc.entries:
                if not e.path.lower().endswith(".msh"):
                    continue
                try:
                    m = parse(arc.read(e, f))
                    if any(i >= len(m.positions) for i in m.indices) or len(m.indices) % 3:
                        raise ValueError("bad index")
                    ok += 1
                    key = len(m.groups)
                    shapes[key] = shapes.get(key, 0) + 1
                except Exception as ex:
                    bad += 1
                    if bad <= 10:
                        print("%s %s: %s" % (os.path.basename(base), e.path, ex))
    print("meshes ok %d bad %d; groups per mesh %s" % (ok, bad, sorted(shapes.items())))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
