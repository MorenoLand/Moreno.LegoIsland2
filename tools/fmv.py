#!/usr/bin/env python3
"""Convert the game's MPEG-1 movies to Ogg Theora/Vorbis so the engine can play them.

    python tools/fmv.py "path/to/LEGO Island 2" [--out assets/fmv] [--ffmpeg path]

Needs ffmpeg with libtheora and libvorbis. Existing outputs are kept.
Every frame is a keyframe: streams with inter-frames came out corrupt with the
ffmpeg build this was written against, so the files are larger than usual.
"""
import argparse
import os
import shutil
import subprocess
import sys


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("install", help="game install folder (the one that contains _data)")
    ap.add_argument("--out", default="assets/fmv")
    ap.add_argument("--ffmpeg", default=shutil.which("ffmpeg") or "ffmpeg")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    src = os.path.join(args.install, "_data", "FMV")
    if not os.path.isdir(src):
        print("no FMV folder in " + src, file=sys.stderr)
        return 1
    os.makedirs(args.out, exist_ok=True)
    failed = 0
    for name in sorted(os.listdir(src)):
        if not name.lower().endswith(".mpg"):
            continue
        dest = os.path.join(args.out, os.path.splitext(name)[0].lower() + ".ogv")
        if os.path.exists(dest) and not args.force:
            print("keep " + dest)
            continue
        cmd = [args.ffmpeg, "-y", "-v", "error", "-i", os.path.join(src, name),
               "-vf", "fps=25,format=yuv420p",
               "-c:v", "libtheora", "-g", "1", "-qscale:v", "7",
               "-c:a", "libvorbis", "-q:a", "5", dest]
        print("convert " + name)
        if subprocess.call(cmd) != 0:
            failed += 1
            if os.path.exists(dest):
                os.remove(dest)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
