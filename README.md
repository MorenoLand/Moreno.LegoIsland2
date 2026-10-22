# LEGO Island 2

> **WIP: work in progress.** Unfinished and changing daily; expect missing features and bugs.

A port of LEGO Island 2: The Brickster's Revenge (PC, 2001) to Redot / Godot. It reads the game's files from your own copy of
the game; no game data is included in this repository.

Work in progress. What runs: the start-up movies, the loading screen, the full front menu with its backdrop (options, controls,
save slots, credits), a new game or a loaded save, and the island zone with its terrain, buildings, trees and vehicles, a walk
camera and the pause menu. Nothing else of the game plays yet.

## What is here

- `tools/bob.py` lists, checks and extracts the `.bod` / `.bob` archives in the game's `_data` folder.
- `tools/msh.py` reads the `.msh` meshes (`python tools/msh.py "path/to/_data"` checks all of them).
- `scripts/core/display.gd` handles window scaling. The picture fills the window at any aspect ratio; F2 switches the 2D layer
  between stretched and the original 4:3.
- [docs/formats.md](docs/formats.md) describes what is known about the data files.

- `data/` holds small tables of ids (texture runs, mesh slots, placements) that the zone scenes use.

## Setup

Python 3.11 or newer and Redot 26.2. The tools use the standard library only.

```
python tools/bob.py "path/to/LEGO Island 2/_data" --list
```

The front menu (main menu, options, start) reads its layout from the game's own executable and picture sets. Up/Down move,
Enter or Shift selects, Esc goes back, and the mouse works.

## Running

Point the game at your install with `--root=<install folder>` after `--`, the `LI2_ROOT` environment variable, or `[data] root`
in `user://config.cfg`. The loading screen is the first thing shown. F2 switches the picture between stretched and 4:3.

```
redot --path . -- --root="path/to/LEGO Island 2"
```

## Tests

```
redot --headless --path . -s res://tests/smoke_boot.gd
```

## Controls on the island

Space jumps (not in Pepper's house). W / Up walks forward, S / Down back, A / D or Left / Right swing the camera around Pepper, Esc opens the pause menu; its Pepper's House row (the original's level-select action) loads zone 3, and from inside the house the same row returns to the island (a port convenience until the door trigger is traced). In Pepper's house, Enter next to the computer opens his computer menu (Subgames, Sounds, Movies; Movies plays the converted intro or outro clip when present in assets/fmv), and Enter at the shelf shows the shelf view, The trophies on the house shelves follow the save: none, bronze, silver or gold from each trophy's medal value. Enter at the trophy wall browses the trophies with Left / Right (each plays its own clip, or the error clip while locked, and shows its high score; Enter or Esc leaves), and walking out through the door (past z = 15) or pressing Enter by the door area returns to the island. F3 cycles island, house and the Skate Park (a port convenience for looking at the zones). Walk speed, the stick deadzone, the animation thresholds, the camera distance (12 to 28) and the height above ground follow the game.

## What moves on the island

Pepper starts where the original puts a new game. The rabbits idle, hop, run to their waypoints and dive. The twenty butterflies flutter around their homes and the ten swifts fly their flock path. Models the original hides at the start (collectible pages, loose pizzas, the skateboard, the police helicopter, the pterodactyl before the late story) are not drawn. Characters, vehicles, flocks and the story scripts are static for now.
