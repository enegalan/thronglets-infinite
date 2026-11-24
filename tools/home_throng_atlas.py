#!/usr/bin/env python3
"""Home throng body cells in world/world_cells + world/world_cells_dirt to a shared foot baseline."""
from __future__ import annotations

import importlib.util
import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELLS = os.path.join(ROOT, "resources", "sprites", "world", "world_cells")
CELLS_DIRT = os.path.join(ROOT, "resources", "sprites", "world", "world_cells_dirt")


def _load_make_art():
    path = os.path.join(ROOT, "tools", "make_art.py")
    spec = importlib.util.spec_from_file_location("make_art", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _path(idx: int, dirt: bool = False) -> str:
    return os.path.join(CELLS_DIRT if dirt else CELLS, "%04d.png" % idx)


def _load(idx: int, cell: int, dirt: bool = False) -> Image.Image:
    path = _path(idx, dirt)
    if os.path.isfile(path):
        return Image.open(path).convert("RGBA")
    return Image.new("RGBA", (cell, cell), (0, 0, 0, 0))


def _save(idx: int, im: Image.Image, dirt: bool = False) -> None:
    os.makedirs(CELLS_DIRT if dirt else CELLS, exist_ok=True)
    im.save(_path(idx, dirt))


def main() -> None:
    ma = _load_make_art()
    cell = ma.CELL_W
    clips = {}
    for line in open(os.path.join(ROOT, "scripts", "data", "throng_clips.gd")):
        match = re.search(r'"([^"]+)": Vector2i\((\d+), (\d+)\)', line)
        if match:
            clips[match.group(1)] = (int(match.group(2)), int(match.group(3)))
    moved = 0
    for name, (start, count) in sorted(clips.items(), key=lambda item: item[1][0]):
        if ma._throng_skip_home(name):
            continue
        bodies = [_load(start + i, cell) for i in range(count)]
        dirts = [_load(start + i, cell, dirt=True) for i in range(count)]
        keep_air = ma._throng_preserve_air(name)
        shifts = ma._home_shift_for_cells(bodies, preserve_air=keep_air)
        home_b = ma._home_throng_cells(bodies, preserve_air=keep_air, shifts=shifts)
        home_d = ma._home_throng_cells(dirts, preserve_air=keep_air, shifts=shifts)
        if all(a.tobytes() == b.tobytes() for a, b in zip(bodies, home_b)):
            continue
        for i in range(count):
            _save(start + i, home_b[i])
            _save(start + i, home_d[i], dirt=True)
        moved += 1
        print("homed", name)
    print("done moved", moved)


if __name__ == "__main__":
    main()
