#!/usr/bin/env python3
"""Draft terminal dialogue trees from the Spanish story tables in lines.json."""

from __future__ import annotations

import json
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINES = os.path.join(ROOT, "resources", "dialogue", "lines.json")
OUT = os.path.join(ROOT, "resources", "dialogue", "trees")
REF_ATLAS = os.path.join(ROOT, "references", "Assets")
UI = os.path.join(ROOT, "resources", "ui")

THEM_MARK = re.compile(
    r"(==|ERROR|Sense_Self|printf|ejecutarConsulta|necesito|nosotros|tropel|&&|\?\?\?|,,,)",
    re.I,
)
EMPTY_RE = re.compile(r"^['\"\s.=*_/\\-]*$")


def clean(line: str) -> str:
    text = str(line).strip()
    if text.startswith("'") and text.endswith("'") and len(text) >= 2:
        text = text[1:-1]
    if text.startswith('"') and text.endswith('"') and len(text) >= 2:
        text = text[1:-1]
    return text.strip()


def usable(line: str) -> bool:
    text = clean(line)
    return text != "" and not EMPTY_RE.match(text)


def is_them(line: str) -> bool:
    text = clean(line)
    raw = str(line).strip()
    if raw.startswith("'") or raw.startswith('"'):
        return True
    if THEM_MARK.search(text):
        return True
    if text.isupper() and len(text) > 8:
        return True
    return False


def is_player(line: str) -> bool:
    if not usable(line) or is_them(line):
        return False
    text = clean(line)
    if text.startswith(">>"):
        return False
    # Prefer clear player prompts / short replies; long narration stays NPC.
    if "?" in text or text.startswith("¡") or text.startswith("¿"):
        return True
    if len(text) <= 48 and not text.endswith("."):
        return True
    if text[:1].isupper() and len(text) <= 72 and (
        text.startswith("Sí")
        or text.startswith("No")
        or text.startswith("Bueno")
        or text.startswith("Claro")
        or text.startswith("Emm")
        or text.startswith("Entonces")
        or text.startswith("Olvídenlo")
        or text.startswith("De acuerdo")
    ):
        return True
    return False


def choice_labels(players: list[str]) -> list[str]:
    labels = [p for p in players if p][:3]
    if labels:
        return labels
    return ["Continuar.", "De acuerdo.", "Ya basta."]


def chunk_parts(rows: list[str], size: int = 40) -> list[list[str]]:
    parts = []
    for i in range(0, len(rows), size):
        parts.append(rows[i : i + size])
    return parts or [[]]


def build_tree(table: str, rows: list[str], part: int | None = None) -> dict:
    tid = table if part is None else "%s__p%d" % (table, part)
    them = [clean(r) for r in rows if usable(r) and is_them(r)]
    players = [clean(r) for r in rows if usable(r) and is_player(r)]
    # Fall back: unclassified usable lines become them lines.
    if not them:
        them = [clean(r) for r in rows if usable(r)]
    if not them:
        return {
            "id": tid,
            "source": table,
            "status": "skipped",
            "start": "n0",
            "nodes": {},
            "lines_in": len(rows),
            "lines_used": 0,
        }

    nodes = {}
    used = 0
    if len(rows) <= 8 or (len(them) <= 6 and len(players) <= 3):
        lines = [{"who": "them", "text": t} for t in them[:8]]
        used += len(lines)
        choices = []
        labels = choice_labels(players)
        morals = [1, 0, -1]
        mutates = ["care", "", "numb"]
        for i, label in enumerate(labels):
            choices.append(
                {
                    "label": label,
                    "next": "",
                    "moral": morals[i % 3],
                    "mutate": mutates[i % 3],
                }
            )
            used += 1
        nodes["n0"] = {"lines": lines, "choices": choices}
    else:
        # Medium / large: rotate them blocks and player choice gates.
        leftover = [clean(r) for r in rows if usable(r) and clean(r) not in them]
        them_blocks = chunk_parts(them, 3)
        choice_pool = players[:] if players else choice_labels(leftover)
        cursor = 0
        for bi, block in enumerate(them_blocks):
            nid = "n%d" % bi
            lines = [{"who": "them", "text": t} for t in block]
            used += len(lines)
            if bi >= len(them_blocks) - 1:
                labels = choice_pool[cursor : cursor + 3] or choice_labels([])
                choices = []
                morals = [1, 0, -1]
                mutates = ["care", "", "numb"]
                for i, label in enumerate(labels[:3]):
                    choices.append(
                        {
                            "label": label,
                            "next": "",
                            "moral": morals[i % 3],
                            "mutate": mutates[i % 3],
                        }
                    )
                    used += 1
                nodes[nid] = {"lines": lines, "choices": choices}
            else:
                labels = []
                for _ in range(3):
                    labels.append(choice_pool[cursor % len(choice_pool)])
                    cursor += 1
                next_id = "n%d" % (bi + 1)
                # First two choices advance; third can skip to end.
                choices = [
                    {"label": labels[0], "next": next_id, "moral": 1, "mutate": "care"},
                    {"label": labels[1], "next": next_id, "moral": 0, "mutate": ""},
                    {"label": labels[2], "next": "", "moral": -1, "mutate": "numb"},
                ]
                used += 3
                nodes[nid] = {"lines": lines, "choices": choices}

    return {
        "id": tid,
        "source": table,
        "status": "draft",
        "start": "n0",
        "nodes": nodes,
        "lines_in": len(rows),
        "lines_used": used,
        "part": part,
    }


def promote_console_ui() -> None:
    try:
        from PIL import Image
    except ImportError:
        print("PIL missing; skip console UI promote")
        return
    atlas_dir = os.path.join(ROOT, "resources", "src", "ref", "atlas", "Sprites-ConsoleUI")
    if not os.path.isdir(atlas_dir):
        # Slice just ConsoleUI if atlas crops missing.
        try:
            from wire_assets import atlas_png, crop_unity, key_of
        except Exception:
            atlas_png = None
        if atlas_png is not None:
            png = atlas_png("Sprites-ConsoleUI")
            spec = os.path.join(REF_ATLAS, "SpriteAtlas", "Sprites-ConsoleUI.json")
            sprite_dir = os.path.join(REF_ATLAS, "Sprite")
            if png and os.path.isfile(spec):
                atlas = json.load(open(spec))
                rects = {}
                for item in atlas.get("m_RenderDataMap", []):
                    ident = key_of(item.get("Key", {}))
                    rect = item.get("Value", {}).get("m_TextureRect")
                    if ident and rect and rect.get("m_Width", 0) > 1:
                        rects[ident] = rect
                image = Image.open(png).convert("RGBA")
                os.makedirs(atlas_dir, exist_ok=True)
                for name in os.listdir(sprite_dir):
                    if not name.endswith(".json"):
                        continue
                    data = json.load(open(os.path.join(sprite_dir, name)))
                    render = data.get("m_RenderDataKey", {}).get("Key")
                    ident = key_of({"Key": render}) if render else None
                    if ident is None or ident not in rects:
                        continue
                    frame = crop_unity(image, rects[ident])
                    if frame is None or frame.getbbox() is None:
                        continue
                    dest = os.path.join(atlas_dir, re.sub(r"[^\w.\-]+", "_", data.get("m_Name") or name) + ".png")
                    frame.save(dest)
                print("sliced ConsoleUI into", atlas_dir)

    if not os.path.isdir(atlas_dir):
        return
    os.makedirs(UI, exist_ok=True)

    def pick(substr: str) -> str:
        hits = []
        for name in os.listdir(atlas_dir):
            if substr in name and name.endswith(".png"):
                hits.append(os.path.join(atlas_dir, name))
        hits.sort(key=lambda p: os.path.getsize(p), reverse=True)
        return hits[0] if hits else ""

    border = pick("dialogueUI_UI_border_B_sprite") or pick("dialogueUI_UI_border")
    if border:
        shutil.copy2(border, os.path.join(UI, "console_border.png"))
    panel = pick("UI_DialogueUI_E_SwirlFX_Background") or pick("SwirlFX")
    if panel:
        src = Image.open(panel).convert("RGBA")
        # Darken for text readability while keeping green circuit feel.
        px = src.load()
        for y in range(src.size[1]):
            for x in range(src.size[0]):
                r, g, b, a = px[x, y]
                px[x, y] = (r // 5, max(g // 3, 18), b // 5, 230 if a > 8 else 0)
        src.save(os.path.join(UI, "console_panel.png"))
    choice = pick("ChoiceUIStarburst") or pick("ChoiceUI")
    if choice:
        shutil.copy2(choice, os.path.join(UI, "console_choice.png"))
    print("console UI promoted")


def main() -> None:
    data = json.load(open(LINES))
    tables = data.get("tables", {})
    os.makedirs(OUT, exist_ok=True)
    # Clear previous drafts but keep curated overrides if marked.
    keep = set()
    for name in os.listdir(OUT):
        if not name.endswith(".json") or name == "_index.json":
            continue
        path = os.path.join(OUT, name)
        try:
            row = json.load(open(path))
        except Exception:
            continue
        if str(row.get("status", "")) == "curated":
            keep.add(str(row.get("id", name[:-5])))
    index = {"tables": [], "skipped": [], "parts": {}}
    story = sorted(
        k
        for k in tables
        if k.startswith("CH") or k.startswith("ACT3")
    )
    for key in story:
        rows = [r for r in tables[key] if isinstance(r, str)]
        usable_rows = [r for r in rows if usable(r)]
        if not usable_rows:
            index["skipped"].append({"id": key, "source": key, "reason": "empty"})
            continue
        if len(usable_rows) > 80:
            parts = chunk_parts(usable_rows, 40)
            part_ids = []
            for i, part_rows in enumerate(parts):
                tree = build_tree(key, part_rows, part=i)
                tid = tree["id"]
                part_ids.append(tid)
                if tid in keep:
                    continue
                with open(os.path.join(OUT, tid + ".json"), "w", encoding="utf-8") as fh:
                    json.dump(tree, fh, ensure_ascii=False, indent=1)
                    fh.write("\n")
                index["tables"].append(
                    {
                        "id": tid,
                        "source": key,
                        "status": tree["status"],
                        "lines_in": tree["lines_in"],
                        "lines_used": tree["lines_used"],
                    }
                )
            index["parts"][key] = part_ids
        else:
            tree = build_tree(key, usable_rows)
            tid = tree["id"]
            if tid in keep:
                index["tables"].append(
                    {
                        "id": tid,
                        "source": key,
                        "status": "curated",
                        "lines_in": len(rows),
                        "lines_used": "keep",
                    }
                )
                continue
            with open(os.path.join(OUT, tid + ".json"), "w", encoding="utf-8") as fh:
                json.dump(tree, fh, ensure_ascii=False, indent=1)
                fh.write("\n")
            index["tables"].append(
                {
                    "id": tid,
                    "source": key,
                    "status": tree["status"],
                    "lines_in": tree["lines_in"],
                    "lines_used": tree["lines_used"],
                }
            )
    with open(os.path.join(OUT, "_index.json"), "w", encoding="utf-8") as fh:
        json.dump(index, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    print(
        "trees",
        len(index["tables"]),
        "skipped",
        len(index["skipped"]),
        "split",
        len(index["parts"]),
    )
    promote_console_ui()


if __name__ == "__main__":
    main()
