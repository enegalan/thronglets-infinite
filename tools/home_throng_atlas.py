#!/usr/bin/env python3
"""Home throng body cells in world_iso / dirt to a shared foot baseline."""
from __future__ import annotations

import glob
import importlib.util
import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load_make_art():
    path = os.path.join(ROOT, "tools", "make_art.py")
    spec = importlib.util.spec_from_file_location("make_art", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main() -> None:
    ma = _load_make_art()
    cols = 16
    cell = ma.CELL_W
    world = os.path.join(ROOT, "resources", "sprites", "world_iso.png")
    dirt_path = os.path.join(ROOT, "resources", "sprites", "world_iso_dirt.png")
    clips = {}
    for line in open(os.path.join(ROOT, "scripts", "data", "throng_clips.gd")):
        match = re.search(r'"([^"]+)": Vector2i\((\d+), (\d+)\)', line)
        if match:
            clips[match.group(1)] = (int(match.group(2)), int(match.group(3)))
    sheet = Image.open(world).convert("RGBA")
    dirt = (
        Image.open(dirt_path).convert("RGBA")
        if os.path.isfile(dirt_path)
        else Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    )
    if dirt.size != sheet.size:
        bigger = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
        bigger.alpha_composite(dirt, (0, 0))
        dirt = bigger
    moved = 0
    for name, (start, count) in sorted(clips.items(), key=lambda item: item[1][0]):
        if ma._throng_skip_home(name):
            continue
        bodies = []
        dirts = []
        for i in range(count):
            idx = start + i
            x = (idx % cols) * cell
            y = (idx // cols) * cell
            bodies.append(sheet.crop((x, y, x + cell, y + cell)).copy())
            dirts.append(dirt.crop((x, y, x + cell, y + cell)).copy())
        keep_air = ma._throng_preserve_air(name)
        shifts = ma._home_shift_for_cells(bodies, preserve_air=keep_air)
        home_b = ma._home_throng_cells(bodies, preserve_air=keep_air, shifts=shifts)
        home_d = ma._home_throng_cells(dirts, preserve_air=keep_air, shifts=shifts)
        if all(a.tobytes() == b.tobytes() for a, b in zip(bodies, home_b)):
            continue
        for i in range(count):
            idx = start + i
            x = (idx % cols) * cell
            y = (idx // cols) * cell
            sheet.paste((0, 0, 0, 0), (x, y, x + cell, y + cell))
            dirt.paste((0, 0, 0, 0), (x, y, x + cell, y + cell))
            sheet.alpha_composite(home_b[i], (x, y))
            dirt.alpha_composite(home_d[i], (x, y))
        moved += 1
        print("homed", name)
    sheet.save(world)
    dirt.save(dirt_path)
    for path in glob.glob(os.path.join(ROOT, ".godot", "imported", "world_iso*")):
        os.remove(path)
    print("done moved", moved)


if __name__ == "__main__":
    main()
