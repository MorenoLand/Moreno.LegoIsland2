# Data formats

What is known about the game's files. Each section says how it was confirmed.

## Archives (`.bod` + `.bob`)

Every folder under `_data` that holds game data is a pair: `name.bod` (directory) and `name.bob` (contents). 39 pairs, 23,344
members in the retail PC release. `tools/bob.py` reads them.

### `.bod`

All integers are little endian.

| Part | Layout |
| --- | --- |
| names | NUL-terminated strings. The first is the archive's folder (`_data/menu`). |
| records | `count` records of 16 bytes: a 4 byte tag (`DIRY` or `FILE`) and three 32 bit words. |
| trailer | 16 bytes: names length, record count, 0, names length. |

Record 0 is the root `DIRY`.

- `DIRY`: entry count, index of the first entry, name offset (into the names). The entries are that many consecutive records,
  which may be `DIRY` or `FILE`.
- `FILE`: size, offset into the `.bob`, name offset.

A member's path is the chain of directory names, `/` separated, ending in the file name.

### `.bob`

The files one after another, each preceded by the four bytes `FILE`. A `FILE` record's offset points past that marker.
Checked on all 39 archives: every member has its marker, nothing overlaps, and members plus markers cover each `.bob` exactly.

## Members by extension

By first bytes, over all 39 archives (count in brackets).

| Extension | Count | Starts with | Notes |
| --- | --- | --- | --- |
| `.msh` | 10,731 | `VERT` | meshes, many `_lod0` / `_lod1` / `_lod2` |
| `.col` | 5,159 | `CBBX` | collision boxes |
| `.tga` | 4,961 | standard header | image type 2 (raw) and 10 (RLE) |
| `.str` | 676 | text tag | message scripts, per language folder |
| `.wib` | 329 | `WIBF` | textures, 256 x 256 plus a small header |
| `.txt` | 243 | text | brick set, cutscene, morph tables; tab separated |
| `.man` | 164 | `MATA` | material animation |
| `.cam` | 141 | `CAMA` | cameras |
| `.blk` | 136 | `ABLK` | animation blocks |
| `.cut` | 87 | count word | cutscene data |
| `.par` `.app` `.emi` `.mov` | ~100 each | text | particle definitions |
| `.opt` `.txl` | 60 / 32 | `TEXT` | texture options |
| `.wpt` `.way` `.wbt` | 43 / 35 / 3 | `WPTP` / text | waypoints |
| `.lgt` | 30 | `LGTL` | lights |
| `.gob` `.mtl` `.src` `.fnt` `.anm` | few | various | |

Meshes, `.wib` textures, `.cam` and the outline of `.col` are decoded; the rest are listed by what they start with.

## Textures (`.wib`)

Little endian. Checked on all 329 files.

| Part | Layout |
| --- | --- |
| `WIBF` | `n`, then `n` u32: the order the frames are shown in (an index into the frames below) |
| `WIBT` | width, height, kind, frame count |
| pixels | `frame count` x width x height x bytes per pixel, raw |

Kind 0 stores 3 bytes per pixel, kinds 1 and 2 store 4. Typical sizes are 64 x 64 with 16 frames and 128 x 128. The byte
order of the channels is not confirmed.

`.tga` files are ordinary Targa (type 2 raw, type 10 run-length). `.opt` and `.txl` hold `TEXT`, a count, then one byte
per texture; the value is 3 in nearly every file.

## Cameras (`.cam`) and collision (`.col`)

- `.cam`: 32 bytes, `CAMA`, 1, then six floats.
- `.col`: `CBBX` and seven floats (a bounding box and one more value), then either `NCOL` (36 bytes, nothing to collide with)
  or `COLP`, a count and the collision polygons. The polygon layout is not decoded.

## Brick models (`BrickMorph/*.txt`, `Bricks/brickset.txt`)

Text, tab separated. A model file has `NAME`, `MODELTYPE` (`HOUSE`, ...) and `CENTRE`, then one line per brick: group,
brick name, x y z, rotation x y z, colour name. `brickset.txt` lists every brick name with symmetry flags and an offset. The
brick meshes are in `Bricks.bob` as `lods/<name>_lodN.msh`; the zone archives also hold the same buildings already
assembled (`pizzeria_LOD1.msh` ...), modelled around the origin.

## Meshes (`.msh`)

Little endian. All 10,731 meshes parse with `tools/msh.py` with nothing left over.

| Chunk | Layout |
| --- | --- |
| `VERT` | `n`, then `n` vertices of 32 bytes: x y z (float), colour (u32), u v u2 v2 (float) |
| normals | `n` x 3 floats, straight after the vertices (no tag) |
| `INDL` | `k`, then `k` u16 indices; a triangle list, `k` is a multiple of 3 |
| `GRPL` | `g`, then `g` records of five u32: first word, index count, third word, vertex count, fifth word |
| `GTOM` | optional, `c`, then `c` u32 |
| `MATL` | optional, `c`, then `c` records of nine floats (three triples) |
| `SVWL` | optional, runs to the end of the file; vertex count, then per vertex data (not needed to draw the mesh) |

A group record is: flags, index count, first vertex, vertex count, first index. The indices of a group are relative to its
first vertex (they run from 0 to vertex count - 1). The `MATL` triples are not confirmed.

Meshes carry no texture ids. The zone code builds runs of texture ids and binds a run to each mesh;
group `i` of the mesh uses entry `i` of its run. Runs are listed in the zone loader and are not stored in the mesh.

## Texture rows

The game's `.tga` textures are stored bottom-up and the game samples them as stored, with `v = 1` at the top of a quad. An
engine that decodes TGA top-down has to flip each texture vertically before using the mesh UVs as they are.

## DirectMusic segments (menu music)

A segment (`.sgt`, RIFF `DMSG`) holds a header (`segh`: repeats, length in 768-ticks-per-quarter units), a tempo track (`tetr`), a chord track (`cord`/`crdb`: chord pattern bits, scale pattern bits, chord root, per-level masks), a style reference (`sttr` -> `.sty`) and a band track (`DMBT`: per channel patch, volume, pan, transpose, and the DLS file name). The style (`.sty`, RIFF `DMST`) holds the time signature and grid, parts (`prth` + `note`) and patterns (`ptnh` groove range, `pref` part references with the channel). A note is `grid start, variation mask, duration, time offset, music value, velocity, ...`; the music value is `octave:4 | chord position:4 | scale offset:4 | accidental:4 (signed)`.
The pitch is `octave*12 + chordTone[position] + scale steps(offset) + accidental + chord root`, plus the band transpose. Instruments come from the DLS collection (`ins` -> regions with key/velocity ranges, `wlnk` wave index, `wsmp` unity note/loop, `art1` envelope times in timecents), all PCM 16-bit mono in the menu bank.
The port renders these in `scripts/audio` with pooled `AudioStreamPlayer`s at the original tempo and loops the segment.
