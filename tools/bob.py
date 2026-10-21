#!/usr/bin/env python3
"""Reader for the game's .bod / .bob archive pairs.

A .bod is the directory: a table of NUL-terminated names, then one record per
entry, then a 16 byte trailer (names length, record count, 0, names length).
A DIRY record is (count, first entry, name); a FILE record is (size, offset,
name). Entries of a directory are a run of records starting at "first entry".
The .bob holds the files; each one is preceded by the four bytes "FILE", and
the offset in the record points past them.
"""
import argparse
import os
import struct
import sys


class Entry:
    __slots__ = ("path", "size", "offset")

    def __init__(self, path, size, offset):
        self.path = path
        self.size = size
        self.offset = offset


class Archive:
    def __init__(self, base):
        self.base = base
        with open(base + ".bod", "rb") as f:
            bod = f.read()
        names_len, count, zero, names_len2 = struct.unpack_from("<4I", bod, len(bod) - 16)
        if zero != 0 or names_len != names_len2:
            raise ValueError("%s: bad trailer" % base)
        if names_len + count * 16 + 16 != len(bod) and not self._sized(bod, names_len, count):
            raise ValueError("%s: record area does not match the trailer" % base)
        self.names = bod[:names_len]
        self.records = []
        pos = names_len
        for _ in range(count):
            tag = bod[pos:pos + 4]
            if tag == b"DIRY":
                a, b, c = struct.unpack_from("<3I", bod, pos + 4)
            elif tag == b"FILE":
                a, b, c = struct.unpack_from("<3I", bod, pos + 4)
            else:
                raise ValueError("%s: unknown record %r at %d" % (base, tag, pos))
            self.records.append((tag, a, b, c))
            pos += 16
        if pos + 16 != len(bod):
            raise ValueError("%s: %d bytes left after the records" % (base, len(bod) - pos - 16))
        self.bob_size = os.path.getsize(base + ".bob")
        self.entries = []
        if self.records:
            self._walk(0, "")

    @staticmethod
    def _sized(bod, names_len, count):
        return names_len + count * 16 + 16 == len(bod)

    def name_at(self, offset):
        end = self.names.index(b"\0", offset)
        return self.names[offset:end].decode("latin-1")

    def _walk(self, index, prefix):
        tag, a, b, c = self.records[index]
        if tag != b"DIRY":
            raise ValueError("%s: record %d is not a directory" % (self.base, index))
        here = prefix + self.name_at(c) if not prefix else prefix + "/" + self.name_at(c)
        for child in range(b, b + a):
            ctag, ca, cb, cc = self.records[child]
            if ctag == b"DIRY":
                self._walk(child, here)
            else:
                self.entries.append(Entry(here + "/" + self.name_at(cc), ca, cb))

    def read(self, entry, bob=None):
        if bob is None:
            with open(self.base + ".bob", "rb") as f:
                f.seek(entry.offset)
                return f.read(entry.size)
        bob.seek(entry.offset)
        return bob.read(entry.size)

    def check(self):
        problems = []
        with open(self.base + ".bob", "rb") as f:
            blob = f.read()
        covered = 0
        last_end = 0
        for e in sorted(self.entries, key=lambda x: x.offset):
            if e.offset < 4 or blob[e.offset - 4:e.offset] != b"FILE":
                problems.append("%s: no FILE marker before offset %d" % (e.path, e.offset))
            if e.offset + e.size > len(blob):
                problems.append("%s: runs past the end of the .bob" % e.path)
            if e.offset - 4 < last_end:
                problems.append("%s: overlaps the previous file" % e.path)
            covered += e.size + 4
            last_end = e.offset + e.size
        if covered != len(blob):
            problems.append("files cover %d of %d bytes" % (covered, len(blob)))
        return problems


def find_archives(folder):
    out = []
    for name in sorted(os.listdir(folder)):
        if name.lower().endswith(".bod") and os.path.exists(os.path.join(folder, name[:-4] + ".bob")):
            out.append(os.path.join(folder, name[:-4]))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("data", help="the game's _data folder, or one archive without extension")
    ap.add_argument("--list", action="store_true", help="print every member")
    ap.add_argument("--check", action="store_true", help="verify each archive, exit 1 on a problem")
    ap.add_argument("--extract", metavar="DIR", help="write members under DIR")
    args = ap.parse_args()
    bases = find_archives(args.data) if os.path.isdir(args.data) else [args.data]
    bad = 0
    total = 0
    for base in bases:
        arc = Archive(base)
        total += len(arc.entries)
        if args.list:
            for e in arc.entries:
                print("%s\t%d\t%d" % (e.path, e.size, e.offset))
        if args.check:
            problems = arc.check()
            print("%s: %d members, %s" % (os.path.basename(base), len(arc.entries), "ok" if not problems else "%d problems" % len(problems)))
            for p in problems[:10]:
                print("  " + p)
            bad += len(problems)
        if args.extract:
            root = os.path.abspath(args.extract)
            with open(base + ".bob", "rb") as bob:
                for e in arc.entries:
                    dest = os.path.abspath(os.path.join(root, e.path))
                    if os.path.commonpath([root, dest]) != root:
                        raise ValueError("path leaves the output folder: " + e.path)
                    os.makedirs(os.path.dirname(dest), exist_ok=True)
                    with open(dest, "wb") as out:
                        out.write(arc.read(e, bob))
    print("%d archives, %d members" % (len(bases), total), file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
