#!/usr/bin/env python3
"""List the game archives so a web build knows what to download.

A browser cannot list a folder, so the names and sizes of the .bob archives are
written to data/archives.txt and shipped with the game. At run time the web build
fetches each .bod directory (a few hundred kB in total) over HTTP to build the
file index, then downloads whole archives into user:// on demand.

    py -3 -I tools/web_manifest.py "path/to/LEGO Island 2"
"""
import os
import sys

OUT_NAME = "archives.txt"


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    root = sys.argv[1]
    data = os.path.join(root, "_data")
    if not os.path.isdir(data):
        raise SystemExit("no _data folder in " + root)

    rows = []
    total = 0
    for name in sorted(os.listdir(data)):
        if not name.lower().endswith(".bob"):
            continue
        size = os.path.getsize(os.path.join(data, name))
        bod = os.path.join(data, name[:-4] + ".bod")
        if not os.path.exists(bod):
            print("skipping %s (no .bod)" % name)
            continue
        rows.append((name[:-4], size, os.path.getsize(bod)))
        total += size

    if len(sys.argv) > 2:
        out_dir = sys.argv[2]
    else:
        out_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, OUT_NAME)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("# archive\tbob bytes\tbod bytes\n")
        for name, size, bod in rows:
            f.write("%s\t%d\t%d\n" % (name, size, bod))
    print("wrote %s: %d archives, %.1f MB total"
          % (path, len(rows), total / 1048576.0))


if __name__ == "__main__":
    main()