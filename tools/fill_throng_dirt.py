#!/usr/bin/env python3
"""Fill throng dirt cells that Unity left empty (e.g. Walk_Homed) from Default/Walk."""

from __future__ import annotations

import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 128
CELLS = os.path.join(ROOT, "resources", "sprites", "world", "world_cells")
CELLS_DIRT = os.path.join(ROOT, "resources", "sprites", "world", "world_cells_dirt")
CLIPS_GD = os.path.join(ROOT, "scripts", "data", "throng_clips.gd")


def _path(idx: int, dirt: bool = False) -> str:
    return os.path.join(CELLS_DIRT if dirt else CELLS, "%04d.png" % idx)


def _cell(idx: int, dirt: bool = False) -> Image.Image:
    path = _path(idx, dirt)
    if os.path.isfile(path):
        return Image.open(path).convert("RGBA")
    return Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))


def _put(idx: int, im: Image.Image, dirt: bool = False) -> None:
    os.makedirs(CELLS_DIRT if dirt else CELLS, exist_ok=True)
    im.save(_path(idx, dirt))


def _foot_mid(im: Image.Image):
    box = im.getbbox()
    if not box:
        return None
    return ((box[0] + box[2]) * 0.5, float(box[3]))


def _shift(im: Image.Image, dx: float, dy: float) -> Image.Image:
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    out.alpha_composite(im, (int(round(dx)), int(round(dy))))
    return out


def _mask_to_body(dirt: Image.Image, body: Image.Image) -> Image.Image:
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    dp = dirt.load()
    bp = body.load()
    op = out.load()
    for y in range(CELL):
        for x in range(CELL):
            if dp[x, y][3] < 16 or bp[x, y][3] < 16:
                continue
            op[x, y] = dp[x, y]
    return out


def _pattern(body: Image.Image, dirt: Image.Image):
    fm = _foot_mid(body)
    if not fm:
        return []
    mid_x, foot = fm
    dp = dirt.load()
    bp = body.load()
    offs = []
    for y in range(CELL):
        for x in range(CELL):
            if dp[x, y][3] < 16 or bp[x, y][3] < 16:
                continue
            offs.append((x - mid_x, y - foot, dp[x, y]))
    return offs


def _stamp(body: Image.Image, pattern) -> Image.Image:
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    fm = _foot_mid(body)
    if not fm or not pattern:
        return out
    mid_x, foot = fm
    bp = body.load()
    op = out.load()
    for dx, dy, pix in pattern:
        x = int(round(mid_x + dx))
        y = int(round(foot + dy))
        if x < 0 or y < 0 or x >= CELL or y >= CELL:
            continue
        if bp[x, y][3] < 16:
            continue
        op[x, y] = pix
    return out


def _skip(name: str) -> bool:
    if name.startswith("Throng_Egg") or "Prop_" in name or "Outline" in name:
        return True
    if "Mitosis" in name:
        return True
    return name in (
        "ThrongA_Bones",
        "ThrongA_Dead_001",
        "ThrongA_Dead_002",
        "ThrongA_Default_Ghost",
        "ThrongA_Deflesh",
    )


def main() -> None:
    clips = {}
    for line in open(CLIPS_GD):
        match = re.search(r'"([^"]+)": Vector2i\((\d+), (\d+)\)', line)
        if match:
            clips[match.group(1)] = (int(match.group(2)), int(match.group(3)))
    def_body = _cell(clips["ThrongA_Default"][0])
    def_dirt = _cell(clips["ThrongA_Default"][0], dirt=True)
    default_pat = _pattern(def_body, def_dirt)
    walk_start, walk_n = clips["Throng_Walk_Anim_Spritesheet"]
    filled = 0
    for name, (start, count) in sorted(clips.items()):
        if _skip(name):
            continue
        for i in range(count):
            idx = start + i
            body = _cell(idx)
            cur = _cell(idx, dirt=True)
            if cur.getbbox() is not None or body.getbbox() is None:
                continue
            if name == "Throng_Walk_Homed_Spritesheet":
                src_i = walk_start + (i % walk_n)
                src_b = _cell(src_i)
                src_d = _cell(src_i, dirt=True)
                src_f = _foot_mid(src_b)
                dst_f = _foot_mid(body)
                if src_f and dst_f and src_d.getbbox():
                    aligned = _mask_to_body(
                        _shift(src_d, dst_f[0] - src_f[0], dst_f[1] - src_f[1]),
                        body,
                    )
                    if aligned.getbbox():
                        _put(idx, aligned, dirt=True)
                        filled += 1
                        continue
            _put(idx, _stamp(body, default_pat), dirt=True)
            filled += 1
    print("filled", filled)


if __name__ == "__main__":
    main()
