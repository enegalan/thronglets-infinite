#!/usr/bin/env python3
"""Extract Unity-only Char_Throng sheets into strips and append them to world_iso."""

from __future__ import annotations

import importlib.util
import json
import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES_DIR = os.path.join(ROOT, "resources", "sprites", "throng_anims")
REF_DIR = os.path.join(ROOT, "references", "thronglet-anims")
WORLD = os.path.join(ROOT, "resources", "sprites", "world_iso.png")
DIRT = os.path.join(ROOT, "resources", "sprites", "world_iso_dirt.png")
CLIPS_GD = os.path.join(ROOT, "scripts", "data", "throng_clips.gd")
CELL = 128
COLS = 16

# Unity prefix -> runtime clip name (Char_ dropped to match KickRock style).
EXTRA = [
    ("Char_ThrongA_PanicRun", "ThrongA_PanicRun"),
    ("Char_ThrongA_PanicRunFire", "ThrongA_PanicRunFire"),
    ("Char_ThrongA_FreakOut", "ThrongA_FreakOut"),
    ("Char_ThrongA_LiftProp", "ThrongA_LiftProp"),
    ("Char_ThrongA_LiftPropWalk", "ThrongA_LiftPropWalk"),
    ("Char_ThrongA_DropProp", "ThrongA_DropProp"),
    ("Char_ThrongA_Happy_Walk_Spritesheet", "ThrongA_Happy_Walk"),
    ("Char_ThrongA_Sad_Walk_Spritesheet", "ThrongA_Sad_Walk"),
    ("Char_ThrongA_PuppyDogEyes_Spritesheet", "ThrongA_PuppyDogEyes"),
    ("Char_ThrongA_InAwe_Spritesheet", "ThrongA_InAwe"),
    ("Char_ThrongA_Deflesh", "ThrongA_Deflesh"),
]


def _load_make_art():
    path = os.path.join(ROOT, "tools", "make_art.py")
    spec = importlib.util.spec_from_file_location("make_art", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _frames_for(make_art, prefix: str):
    # Char_* meta lives under references/; atlas under art_source (same as make_art throng pack).
    folder = os.path.join(ROOT, "references", "Assets", "Sprite")
    atlas = Image.open(
        os.path.join(
            make_art.SRC_TEX,
            "sactx-0-2048x2048-Uncompressed-Sprites-Thronglets-fc0e3430.png",
        )
    ).convert("RGBA")
    dirt_atlas = Image.open(
        os.path.join(
            make_art.SRC_TEX,
            "sactx-0-2048x2048-Uncompressed-Sprites-Thronglets-fc0e3430?_DirtTex.png",
        )
    ).convert("RGBA")
    items = []
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".json") or "_Alpha" in name:
            continue
        base = name[:-5]
        if prefix == "Char_ThrongA_Deflesh":
            if not re.match(r"Char_ThrongA_Deflesh_\d+$", base):
                continue
            order = int(base.rsplit("_", 1)[1])
        elif base.startswith(prefix + "_") and base[len(prefix) + 1 :].isdigit():
            order = int(base.rsplit("_", 1)[1])
        else:
            continue
        data = json.load(open(os.path.join(folder, name)))
        rect = data.get("m_Rect")
        if not rect:
            continue
        pivot = data.get("m_Pivot") or {}
        settings = int((data.get("m_RD") or {}).get("m_SettingsRaw") or 0)
        body = make_art._crop_unity(atlas, rect, settings)
        dirt = make_art._crop_unity(dirt_atlas, rect, settings)
        items.append(
            (
                order,
                body,
                dirt,
                (float(pivot.get("m_X", 0.5)), float(pivot.get("m_Y", 0.5))),
            )
        )
    items.sort(key=lambda row: row[0])
    return [(b, d, p) for _o, b, d, p in items]


def _strip(frames):
    bodies = [f[0].convert("RGBA") for f in frames]
    cell_w = max(img.size[0] for img in bodies)
    cell_h = max(img.size[1] for img in bodies)
    sheet = Image.new("RGBA", (cell_w * len(bodies), cell_h), (0, 0, 0, 0))
    for i, img in enumerate(bodies):
        x = i * cell_w + (cell_w - img.size[0]) // 2
        y = cell_h - img.size[1]
        sheet.alpha_composite(img, (x, y))
    return sheet, cell_w, cell_h


def _max_clip_end(text: str) -> int:
    ends = [int(s) + int(c) for s, c in re.findall(r'Vector2i\((\d+), (\d+)\)', text)]
    return max(ends) if ends else 144


def _patch_clips_gd(entries: list[tuple[str, int, int]], rows: int) -> None:
    text = open(CLIPS_GD).read()
    # Drop previous EXTRA entries if re-run.
    for _unity, clip in EXTRA:
        text = re.sub(r'\t"%s": Vector2i\(\d+, \d+\),\n' % re.escape(clip), "", text)
    insert = "".join('\t"%s": Vector2i(%d, %d),\n' % (n, s, c) for n, s, c in entries)
    text = re.sub(r"(const CLIPS := \{)", r"\1\n" + insert.rstrip("\n"), text, count=1)
    text = re.sub(r"const SHEET_ROWS := \d+", "const SHEET_ROWS := %d" % rows, text, count=1)
    # Extend PANIC / MOOD / TALK_REACT / walk helpers if present.
    replacements = {
        "const PANIC :=": [
            "ThrongA_ReactToKill",
            "ThrongA_FreakOut",
            "ThrongA_PanicRun",
            "ThrongA_PanicRunFire",
        ],
        "const MOOD_BORED :=": [
            "ThrongA_Bored_KickRock",
            "Throng_Grumpy_Sheet",
            "Throng_Grumpy3",
            "ThrongA_Grumpy",
            "ThrongA_PuppyDogEyes",
        ],
        "const TALK_REACT :=": [
            "ThrongA_LooktAtPlayerHappyNod_Spritesheet",
            "ThrongA_SkepticalToPlayer_Spritesheet",
            "ThrongA_AngryAtPlayer_Spritesheet",
            "ThrongA_DeepThought_Spritesheet",
            "ThrongA_ImpactfulExplanation_Spritesheet",
            "ThrongA_Shrug",
            "ThrongA_InAwe",
        ],
    }
    for header, members in replacements.items():
        block = header + " [\n" + "".join('\t\t"%s",\n' % m for m in members) + "]"
        text = re.sub(re.escape(header) + r" \[.*?\]", block, text, count=1, flags=re.S)
    open(CLIPS_GD, "w").write(text)


def main() -> None:
    make_art = _load_make_art()
    os.makedirs(RES_DIR, exist_ok=True)
    os.makedirs(REF_DIR, exist_ok=True)
    sheet = Image.open(WORLD).convert("RGBA")
    dirt_sheet = Image.open(DIRT).convert("RGBA") if os.path.isfile(DIRT) else Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    gd = open(CLIPS_GD).read()
    index = _max_clip_end(gd)
    # Skip if already packed (idempotent): if ThrongA_FreakOut present, rebuild from current end of base clips.
    if 'ThrongA_FreakOut"' in gd:
        # Remove trailing extra cells by restoring index to first EXTRA start if tagged.
        m = re.search(r'"ThrongA_PanicRun": Vector2i\((\d+),', gd)
        if m:
            index = int(m.group(1))
            # Crop sheet height to that row start for clean re-append.
            row0 = index // COLS
            sheet = sheet.crop((0, 0, sheet.size[0], max(sheet.size[1], (row0 + 1) * CELL)))
            dirt_sheet = dirt_sheet.crop((0, 0, dirt_sheet.size[0], sheet.size[1]))
    entries = []
    manifest_path = os.path.join(RES_DIR, "manifest.json")
    manifest = json.load(open(manifest_path)) if os.path.isfile(manifest_path) else {"clips": {}, "strip_dir": "res://resources/sprites/throng_anims/"}
    for unity, clip in EXTRA:
        frames = _frames_for(make_art, unity)
        if not frames:
            print("skip missing", unity)
            continue
        strip, cw, ch = _strip(frames)
        safe = clip + ".png"
        for folder in (RES_DIR, REF_DIR):
            strip.save(os.path.join(folder, safe))
        manifest["clips"][clip] = {"file": safe, "frames": len(frames), "cell_w": cw, "cell_h": ch}
        scale, anchor = make_art._throng_fit(frames)
        start = index
        for body, dirt, pivot in frames:
            need_rows = (index // COLS) + 1
            need_h = need_rows * CELL
            if sheet.size[1] < need_h:
                bigger = Image.new("RGBA", (COLS * CELL, need_h), (0, 0, 0, 0))
                bigger.alpha_composite(sheet, (0, 0))
                sheet = bigger
                bigger_d = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
                bigger_d.alpha_composite(dirt_sheet, (0, 0))
                dirt_sheet = bigger_d
            cell = make_art._unity_throng_cell(body, pivot, scale, anchor)
            dcell = make_art._unity_throng_cell(dirt, pivot, scale, anchor)
            make_art._stamp_cell(sheet, COLS, index, cell)
            make_art._stamp_cell(dirt_sheet, COLS, index, dcell)
            index += 1
        entries.append((clip, start, len(frames)))
        print("packed", clip, len(frames), "at", start)
    rows = (index + COLS - 1) // COLS
    sheet = sheet.crop((0, 0, COLS * CELL, rows * CELL))
    dirt_sheet = dirt_sheet.crop((0, 0, COLS * CELL, rows * CELL))
    sheet.save(WORLD)
    dirt_sheet.save(DIRT)
    # Drop cached .ctex so Godot reloads.
    for path in (WORLD, DIRT):
        ctex = path + ".ctex"
        if os.path.isfile(ctex):
            os.remove(ctex)
    _patch_clips_gd(entries, rows)
    with open(manifest_path, "w") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print("done rows", rows, "next index", index, "extras", len(entries))


if __name__ == "__main__":
    main()
