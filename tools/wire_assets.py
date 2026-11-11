#!/usr/bin/env python3
"""Copy unused reference media into resources and write the asset manifest."""

import json
import os
import re
import shutil
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF = os.path.join(ROOT, "references", "Assets")
RES = os.path.join(ROOT, "resources")
LOC = "/Users/egalan/Downloads/multis-unity/ExportedProject/Assets/Venice/Localizations"
ATLASES = (
    "Sprites-Structures",
    "Sprites-Props",
    "Sprites-Icons",
    "Toolbar",
    "Sprites-Maw",
    "Sprites-ConsoleUI",
    "Sprites-WoodPanel",
    "Sprites-Tooltip",
    "Sprites-UITutorial",
    "Sprites-Shareable",
    "Sprites-Pollution",
)
MEDIA = (".png", ".wav", ".ogg", ".mp4", ".m4v", ".ttf")


def rel(path):
    return os.path.relpath(path, ROOT)


def crop_unity(atlas, rect):
    from PIL import Image

    x = int(round(rect["m_X"]))
    y = int(round(rect["m_Y"]))
    w = max(1, int(round(rect["m_Width"])))
    h = max(1, int(round(rect["m_Height"])))
    top = atlas.size[1] - (y + h)
    box = (max(0, x), max(0, top), min(atlas.size[0], x + w), min(atlas.size[1], top + h))
    if box[2] <= box[0] or box[3] <= box[1]:
        return None
    return atlas.crop(box)


def atlas_png(token):
    folder = os.path.join(REF, "Texture2D")
    hits = []
    for name in os.listdir(folder):
        if token in name and name.endswith(".png") and "DirtTex" not in name:
            hits.append(os.path.join(folder, name))
    hits.sort(key=lambda path: os.path.getsize(path), reverse=True)
    return hits[0] if hits else ""


def key_of(node):
    data = node.get("Key", node)
    if "m_Data_0_" not in data:
        return None
    return (data["m_Data_0_"], data["m_Data_1_"], data["m_Data_2_"], data["m_Data_3_"])


def slice_atlases(rows):
    from PIL import Image

    sprite_dir = os.path.join(REF, "Sprite")
    sprites = []
    for name in os.listdir(sprite_dir):
        if not name.endswith(".json"):
            continue
        data = json.load(open(os.path.join(sprite_dir, name)))
        render = data.get("m_RenderDataKey", {}).get("Key")
        ident = key_of({"Key": render}) if render else None
        if ident is None:
            continue
        sprites.append((data.get("m_Name") or name[:-5], ident))
    out_root = os.path.join(RES, "src", "ref", "atlas")
    os.makedirs(out_root, exist_ok=True)
    for token in ATLASES:
        png = atlas_png(token)
        spec = os.path.join(REF, "SpriteAtlas", token + ".json")
        if not png or not os.path.isfile(spec):
            continue
        atlas = json.load(open(spec))
        rects = {}
        for item in atlas.get("m_RenderDataMap", []):
            ident = key_of(item.get("Key", {}))
            rect = item.get("Value", {}).get("m_TextureRect")
            if ident and rect and rect.get("m_Width", 0) > 1:
                rects[ident] = rect
        image = Image.open(png).convert("RGBA")
        folder = os.path.join(out_root, token)
        os.makedirs(folder, exist_ok=True)
        saved = 0
        for sprite_name, ident in sprites:
            rect = rects.get(ident)
            if not rect:
                continue
            frame = crop_unity(image, rect)
            if frame is None or frame.getbbox() is None:
                continue
            dest = os.path.join(folder, re.sub(r"[^\w.\-]+", "_", sprite_name) + ".png")
            frame.save(dest)
            rows.append(row(rel(png), rel(dest), "atlas:" + token, "enganchado"))
            saved += 1
        print("sliced", token, saved)
    _promote_panel()


def _promote_panel():
    from PIL import Image

    folder = os.path.join(RES, "src", "ref", "atlas", "Sprites-WoodPanel")
    if not os.path.isdir(folder):
        return
    best = ""
    best_area = 0
    for name in os.listdir(folder):
        if not name.endswith(".png"):
            continue
        path = os.path.join(folder, name)
        image = Image.open(path)
        area = image.size[0] * image.size[1]
        if area > best_area:
            best_area = area
            best = path
    if best:
        dest = os.path.join(RES, "ui", "wood_panel.png")
        shutil.copy2(best, dest)
        _fill_wood_panel(dest)


def _fill_wood_panel(path):
    from PIL import Image
    from collections import deque

    image = Image.open(path).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    fill = (58, 38, 24, 255)
    queue = deque([(width // 2, height // 2)])
    seen = set()
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or x < 0 or y < 0 or x >= width or y >= height:
            continue
        seen.add((x, y))
        if pixels[x, y][3] > 16:
            continue
        pixels[x, y] = fill
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    image.save(path)


def copy_audio(rows):
    src = os.path.join(REF, "AudioClip")
    dest_dir = os.path.join(RES, "audio")
    os.makedirs(dest_dir, exist_ok=True)
    have = set(os.listdir(dest_dir))
    copied = 0
    for name in sorted(os.listdir(src)):
        if not name.endswith((".wav", ".ogg")):
            continue
        dest = os.path.join(dest_dir, name)
        status = "enganchado" if name in have else "copiado"
        if name not in have:
            shutil.copy2(os.path.join(src, name), dest)
            copied += 1
            status = "enganchado"
        rows.append(row(rel(os.path.join(src, name)), rel(dest), "Main.gd sfx_bank / _sync_music", status))
    print("audio copied", copied)


def copy_font(rows):
    fonts = [
        ("Resources", "aline_font.ttf", "aline_font.ttf"),
        ("Font", "PerfectDOSVGA437.ttf", "PerfectDOSVGA437.ttf"),
    ]
    for folder, name, dest_name in fonts:
        src = os.path.join(REF, folder, name)
        dest = os.path.join(RES, "ui", dest_name)
        if os.path.isfile(src):
            shutil.copy2(src, dest)
            rows.append(row(rel(src), rel(dest), "Main.gd _build_ui", "enganchado"))


def copy_faces(rows):
    folder = os.path.join(REF, "Texture2D")
    for name in sorted(os.listdir(folder)):
        if not name.startswith("T_Epilogue_") or not name.endswith(".png"):
            continue
        if "Thronglet" in name or "Apple" in name or "Tree" in name:
            continue
        dest = os.path.join(RES, "ui", "face_" + name[2:].replace(" ", "_"))
        shutil.copy2(os.path.join(folder, name), dest)
        rows.append(row(rel(os.path.join(folder, name)), rel(dest), "Main.gd POP_FACES", "enganchado"))


def extract_lines():
    tables = {}
    if not os.path.isdir(LOC):
        print("no localization export")
        return tables
    files = []
    root = os.path.join(LOC, "LocalizationTables")
    for dirpath, _dirs, names in os.walk(root):
        for name in names:
            if name.endswith("_StringTable_es.asset"):
                files.append(os.path.join(dirpath, name))
    files.sort()
    pattern = re.compile(r"m_Id: (\d+)\n\s+m_Localized: (.*)")
    markup = re.compile(r"<[^>]+>")
    for path in files:
        key = os.path.basename(os.path.dirname(path))
        lines = tables.setdefault(key, [])
        text = open(path, errors="ignore").read()
        for match in pattern.finditer(text):
            line = match.group(2).strip().strip('"')
            line = markup.sub("", line).replace("{Global.PlayerName}", "").strip()
            if line:
                lines.append(line)
    dest_dir = os.path.join(RES, "dialogue")
    os.makedirs(dest_dir, exist_ok=True)
    with open(os.path.join(dest_dir, "lines.json"), "w") as handle:
        json.dump({"tables": tables}, handle, ensure_ascii=False, indent=1)
    count = sum(len(lines) for lines in tables.values())
    print("dialogue tables", len(tables), "lines", count)
    return tables


def convert_videos(rows):
    sources = []
    for dirpath, _dirs, names in os.walk(REF):
        for name in names:
            if name.endswith((".mp4", ".m4v")):
                sources.append(os.path.join(dirpath, name))
    dest_dir = os.path.join(RES, "video")
    os.makedirs(dest_dir, exist_ok=True)
    for src in sorted(sources):
        base = os.path.splitext(os.path.basename(src))[0]
        dest = os.path.join(dest_dir, base + ".ogv")
        if not os.path.isfile(dest) or os.path.getsize(dest) < 1000:
            cmd = [
                "ffmpeg", "-y", "-i", src,
                "-c:v", "libtheora", "-q:v", "7",
                "-c:a", "libvorbis", "-q:a", "5",
                dest,
            ]
            print("convert", os.path.basename(src))
            subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        rows.append(row(rel(src), rel(dest), "Main.gd video", "enganchado"))


def row(source, dest, hook, status):
    return {"source": source, "dest": dest, "hook": hook, "status": status}


def main():
    rows = []
    copy_audio(rows)
    copy_font(rows)
    copy_faces(rows)
    extract_lines()
    rows.append(row(
        "Venice/Localizations/*_StringTable_es.asset",
        "resources/dialogue/lines.json",
        "LineBook.line_for",
        "enganchado" if os.path.isfile(os.path.join(RES, "dialogue", "lines.json")) else "pendiente",
    ))
    slice_atlases(rows)
    convert_videos(rows)


if __name__ == "__main__":
    main()
