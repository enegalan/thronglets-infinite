#!/usr/bin/env python3
"""Fill throng dirt cells that Unity left empty (e.g. Walk_Homed) from Default/Walk."""

from __future__ import annotations

import glob
import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLS = 16
CELL = 128
WORLD = os.path.join(ROOT, "resources", "sprites", "world_iso.png")
DIRT = os.path.join(ROOT, "resources", "sprites", "world_iso_dirt.png")
CLIPS_GD = os.path.join(ROOT, "scripts", "data", "throng_clips.gd")


def _cell(sheet: Image.Image, idx: int) -> Image.Image:
    x = (idx % COLS) * CELL
    y = (idx // COLS) * CELL
    return sheet.crop((x, y, x + CELL, y + CELL)).copy()


def _put(sheet: Image.Image, idx: int, im: Image.Image) -> None:
    x = (idx % COLS) * CELL
    y = (idx // COLS) * CELL
    sheet.paste((0, 0, 0, 0), (x, y, x + CELL, y + CELL))
    sheet.alpha_composite(im, (x, y))


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
    body_sheet = Image.open(WORLD).convert("RGBA")
    dirt_sheet = Image.open(DIRT).convert("RGBA")
    if dirt_sheet.size != body_sheet.size:
        bigger = Image.new("RGBA", body_sheet.size, (0, 0, 0, 0))
        bigger.alpha_composite(dirt_sheet, (0, 0))
        dirt_sheet = bigger
    def_body = _cell(body_sheet, clips["ThrongA_Default"][0])
    def_dirt = _cell(dirt_sheet, clips["ThrongA_Default"][0])
    default_pat = _pattern(def_body, def_dirt)
    walk_start, walk_n = clips["Throng_Walk_Anim_Spritesheet"]
    filled = 0
    for name, (start, count) in sorted(clips.items()):
        if _skip(name):
            continue
        for i in range(count):
            idx = start + i
            body = _cell(body_sheet, idx)
            cur = _cell(dirt_sheet, idx)
            if cur.getbbox() is not None or body.getbbox() is None:
                continue
            if name == "Throng_Walk_Homed_Spritesheet":
                src_i = walk_start + (i % walk_n)
                src_b = _cell(body_sheet, src_i)
                src_d = _cell(dirt_sheet, src_i)
                src_f = _foot_mid(src_b)
                dst_f = _foot_mid(body)
                if src_f and dst_f and src_d.getbbox():
                    aligned = _mask_to_body(
                        _shift(src_d, dst_f[0] - src_f[0], dst_f[1] - src_f[1]),
                        body,
                    )
                    if aligned.getbbox():
                        _put(dirt_sheet, idx, aligned)
                        filled += 1
                        continue
            _put(dirt_sheet, idx, _stamp(body, default_pat))
            filled += 1
    dirt_sheet.save(DIRT)
    for path in glob.glob(os.path.join(ROOT, ".godot", "imported", "world_iso_dirt*")):
        os.remove(path)
    print("filled", filled)


if __name__ == "__main__":
    main()
