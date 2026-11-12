#!/usr/bin/env python3
"""Pixel art for Thronglets: Infinite."""

import json
import os
from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = lambda *parts: os.path.join(ROOT, *parts)
# Copies of the reference art the game keeps. references/ can go away.
SRC_TEX = OUT("resources", "src", "tex")
SRC_SPRITE = OUT("resources", "src", "sprite")

TRANS = (0, 0, 0, 0)


def new(w, h):
    return Image.new("RGBA", (w, h), TRANS)


def px(img, x, y, color):
    if 0 <= x < img.size[0] and 0 <= y < img.size[1]:
        img.putpixel((int(x), int(y)), color)


def rect(img, x, y, w, h, color):
    for yy in range(h):
        for xx in range(w):
            px(img, x + xx, y + yy, color)


def ellipse(img, ox, oy, cx, cy, rx, ry, color, size=16):
    for y in range(size):
        for x in range(size):
            dx = (x + 0.5 - cx) / float(rx)
            dy = (y + 0.5 - cy) / float(ry)
            if dx * dx + dy * dy <= 1.0:
                px(img, ox + x, oy + y, color)


def outline_cell(img, ox, oy, size=16):
    dark = (92, 58, 24, 255)
    cells = []
    for y in range(size):
        for x in range(size):
            if img.getpixel((ox + x, oy + y))[3] > 0:
                cells.append((x, y))
    for x, y in cells:
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < size and 0 <= ny < size and img.getpixel((ox + nx, oy + ny))[3] == 0:
                px(img, ox + nx, oy + ny, dark)


BODY = (228, 181, 66, 255)


def _ref_crop():
    src = Image.open(os.path.join(SRC_SPRITE, "ThrongA_Default_001.png")).convert("RGBA")
    return src.crop(src.getbbox())


def _is_face_pixel(color):
    r, g, b, a = color
    if a < 200:
        return False
    if r > 240 and g > 240 and b > 240:
        return True
    if r < 20 and g < 20 and b < 20:
        return True
    return (r, g, b) == (115, 80, 26)


def _body_near(src, x, y, w, h):
    for dy, dx in ((-1, 0), (-2, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1)):
        nx, ny = x + dx, y + dy
        if 0 <= nx < w and 0 <= ny < h:
            color = src[nx, ny]
            if color[3] > 200 and not _is_face_pixel(color):
                return color
    return BODY


def _cover_face(img, redraw):
    out = img.copy()
    src = img.load()
    dst = out.load()
    w, h = img.size
    found = []
    for y in range(h):
        for x in range(w):
            if _is_face_pixel(src[x, y]):
                found.append((x, y, src[x, y]))
                dst[x, y] = _body_near(src, x, y, w, h)
    if redraw is None:
        return out
    for x, y, color in found:
        nx, ny = redraw(x, y)
        if 0 <= nx < w and 0 <= ny < h:
            dst[nx, ny] = color
    return out


def _paint_eat(img):
    out = _cover_face(img, lambda x, y: (x, y))
    dst = out.load()
    for y in range(20, 24):
        for x in range(15, 21):
            dst[x, y] = (150, 48, 28, 255)
    for y in range(21, 23):
        for x in range(16, 20):
            dst[x, y] = (70, 24, 18, 255)
    return out


def _paint_sick(img):
    out = img.copy()
    dst = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = dst[x, y]
            if a < 16 or _is_face_pixel((r, g, b, a)):
                continue
            if b > r and b > 100:
                continue
            if g < 110:
                continue
            dst[x, y] = (int(r * 0.62), min(255, int(g * 0.9) + 28), int(b * 0.55), a)
    return out


def _paint_corpse(img):
    out = img.copy()
    dst = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = dst[x, y]
            if a < 16:
                continue
            lum = int(r * 0.3 + g * 0.5 + b * 0.2)
            if b > r and b > 100:
                dst[x, y] = (int(lum * 0.7), int(lum * 0.78), int(lum * 0.95), a)
            else:
                dst[x, y] = (lum, int(lum * 0.97), int(lum * 0.9), a)
    ink = (24, 20, 18, 255)
    for d in range(6):
        dst[12 + d, 14 + d] = ink
        dst[17 - d, 14 + d] = ink
        dst[19 + d, 14 + d] = ink
        dst[24 - d, 14 + d] = ink
    return out


# World sheet cell. Main.gd WORLD_CELL must match. Sprites are bottom-centered in the cell.
CELL_W, CELL_H = 128, 128
# Small HUD/fallback glyphs in the low icon band. Big props keep Unity pixels.
PROP_SCALE = 2
# Reference only. Props pack at native size; throng draw scale carries world size.
PX_PER_UNIT = 52.0


def _place(img, bob=0):
    cell = new(CELL_W, CELL_H)
    x = (CELL_W - img.size[0]) // 2
    y = CELL_H - img.size[1] - bob
    cell.alpha_composite(img, (x, y))
    return cell


def _mitosis_cell(base, frame):
    cell = new(CELL_W, CELL_H)
    y = CELL_H - base.size[1]
    if frame < 2:
        cell.alpha_composite(base, ((CELL_W - base.size[0]) // 2, y))
        return cell
    left = (CELL_W - base.size[0] * 2) // 2
    cell.alpha_composite(base, (left, y))
    cell.alpha_composite(base, (left + base.size[0], y))
    return cell


def _pose(kind):
    base = _ref_crop()
    if kind == "north":
        return _cover_face(base, None)
    if kind == "east":
        return _cover_face(base, lambda x, y: (x + 3, y))
    if kind == "west":
        return _cover_face(base, lambda x, y: (x - 3, y))
    if kind == "eat":
        return _paint_eat(base)
    if kind == "sick":
        return _paint_sick(base)
    if kind == "corpse":
        return _paint_corpse(base)
    return base


def _frame_cell(kind, frame):
    if kind == "mitosis":
        return _mitosis_cell(_ref_crop(), frame)
    bob = (0, 1, 0, 1)[frame % 4] if kind in ("south", "north", "east", "west") else 0
    return _place(_pose(kind), bob)


def make_thronglets():
    order = []
    for facing in ("south", "north", "east", "west"):
        for frame in range(4):
            order.append((facing, frame))
    for frame in range(4):
        order.append(("mitosis", frame))
    order.extend((("stare", 0), ("corpse", 0), ("sick", 0), ("eat", 0)))
    sheet = new(4 * CELL_W, 6 * CELL_H)
    view_w, view_h = 60, 35
    view = new(4 * view_w, 6 * view_h)
    for index, (kind, frame) in enumerate(order):
        cell = _frame_cell(kind, frame)
        sheet.alpha_composite(cell, ((index % 4) * CELL_W, (index // 4) * CELL_H))
        view.alpha_composite(
            cell.crop((2, CELL_H - view_h, 2 + view_w, CELL_H)),
            ((index % 4) * view_w, (index // 4) * view_h),
        )
    view.save(OUT("resources", "sprites", "thronglet_spritesheet.png"))
    sheet.save(OUT("resources", "sprites", "thronglet_32.png"))


def icon(index):
    img = new(16, 16)
    draw_icon(img, 0, 0, index)
    return img


def blit_icon(sheet, index, cols):
    tile = _ui_icon(index)
    x = (index % cols) * 16
    y = (index // cols) * 16
    sheet.alpha_composite(tile, (x, y))


def draw_icon(img, ox, oy, index):
    def p(x, y, c):
        px(img, ox + x, oy + y, c)

    def box(x, y, w, h, c):
        rect(img, ox + x, oy + y, w, h, c)

    G = (46, 130, 48, 255)
    GD = (28, 90, 36, 255)
    BR = (128, 78, 40, 255)
    BRD = (78, 46, 24, 255)
    RED = (196, 42, 48, 255)
    W = (245, 245, 248, 255)
    GY = (130, 132, 142, 255)
    GYD = (70, 72, 84, 255)
    GOLD = (240, 196, 64, 255)
    BLUE = (64, 120, 210, 255)
    BLUED = (28, 60, 130, 255)
    PUR = (150, 60, 190, 255)
    PINK = (230, 120, 160, 255)
    INK = (24, 20, 32, 255)
    CREAM = (236, 220, 180, 255)

    if index == 0:  # apple
        box(6, 3, 2, 2, GD)
        box(7, 2, 2, 2, GD)
        box(5, 5, 6, 6, RED)
        box(6, 6, 4, 4, (230, 70, 70, 255))
        p(6, 6, W)
    elif index == 1:  # beach ball
        box(4, 4, 8, 8, (214, 48, 56, 255))
        box(8, 4, 4, 8, (244, 188, 40, 255))
        box(4, 8, 4, 4, (52, 120, 220, 255))
        box(8, 8, 4, 4, W)
        p(6, 6, W)
    elif index == 2:  # tree
        box(7, 10, 2, 4, BR)
        box(4, 4, 8, 6, G)
        box(5, 3, 6, 2, G)
        box(6, 8, 4, 2, GD)
    elif index == 3:  # stump
        box(4, 8, 8, 4, BR)
        box(4, 7, 8, 2, BRD)
        p(6, 9, BRD)
        p(9, 9, BRD)
    elif index == 4:  # rock
        box(4, 6, 8, 6, GY)
        box(5, 5, 6, 2, GY)
        p(6, 7, W)
        p(10, 10, GYD)
    elif index == 5:  # ore rock
        box(4, 6, 8, 6, GY)
        box(5, 5, 6, 2, GY)
        p(6, 7, GOLD)
        p(9, 8, GOLD)
        p(7, 10, GOLD)
    elif index == 6:  # node
        box(7, 3, 2, 8, GOLD)
        box(5, 6, 6, 3, W)
        box(4, 8, 8, 4, GYD)
        p(7, 4, W)
    elif index == 7:  # super node
        box(7, 2, 2, 9, GOLD)
        box(4, 5, 8, 4, W)
        box(3, 8, 10, 4, (90, 70, 20, 255))
        p(6, 6, GOLD)
        p(9, 6, GOLD)
    elif index == 8:  # wood
        box(3, 6, 10, 5, BR)
        box(3, 6, 2, 5, BRD)
        box(11, 6, 2, 5, BRD)
        p(6, 8, BRD)
        p(8, 8, BRD)
    elif index == 9:  # bone
        box(3, 7, 10, 2, CREAM)
        box(2, 6, 3, 4, W)
        box(11, 6, 3, 4, W)
    elif index == 10:  # ore pile
        box(4, 8, 4, 4, GY)
        box(8, 6, 4, 6, GYD)
        p(6, 9, GOLD)
        p(10, 8, GOLD)
    elif index == 11:  # apple tree
        box(7, 10, 2, 4, BR)
        box(3, 3, 10, 7, G)
        p(5, 5, RED)
        p(9, 4, RED)
        p(8, 7, RED)
    elif index == 12:  # bathtub
        box(2, 7, 12, 5, W)
        box(3, 8, 10, 3, BLUE)
        box(2, 6, 2, 3, GY)
        box(12, 6, 2, 3, GY)
    elif index == 13:  # roundabout
        box(7, 6, 2, 7, GOLD)
        box(3, 3, 10, 4, RED)
        box(4, 2, 8, 2, (240, 80, 90, 255))
        p(5, 4, GOLD)
        p(10, 4, GOLD)
    elif index == 14:  # dwelling
        box(4, 8, 8, 6, CREAM)
        box(3, 5, 10, 4, RED)
        box(7, 3, 2, 3, RED)
        box(6, 10, 2, 4, BR)
        p(10, 10, BLUE)
    elif index == 15:  # fancy
        box(3, 8, 10, 6, W)
        box(2, 5, 12, 4, GOLD)
        box(6, 2, 4, 4, GOLD)
        box(6, 10, 3, 4, BRD)
        p(11, 10, BLUE)
    elif index == 16:  # mine
        box(3, 6, 10, 8, GYD)
        box(6, 8, 4, 6, INK)
        box(5, 5, 6, 2, BR)
        p(7, 10, GOLD)
    elif index == 17:  # mine II
        box(2, 5, 12, 9, GYD)
        box(6, 7, 4, 7, INK)
        box(4, 4, 8, 2, GOLD)
        p(8, 9, GOLD)
        p(4, 12, BR)
    elif index == 18:  # factory
        box(2, 7, 12, 7, GY)
        box(4, 3, 3, 5, GYD)
        box(5, 5, 1, 2, PUR)
        box(9, 9, 3, 3, BLUE)
    elif index == 19:  # factory II
        box(1, 7, 14, 7, GYD)
        box(3, 2, 3, 6, GY)
        box(8, 3, 3, 5, GY)
        box(4, 4, 1, 2, PUR)
        box(9, 5, 1, 2, PUR)
        box(11, 9, 3, 3, GOLD)
    elif index == 20:  # theatre
        box(2, 4, 12, 10, (90, 30, 40, 255))
        box(4, 6, 3, 7, RED)
        box(9, 6, 3, 7, RED)
        box(7, 8, 2, 5, GOLD)
    elif index == 21:  # cannon
        box(3, 10, 10, 3, GYD)
        box(4, 6, 8, 3, GY)
        box(8, 3, 3, 4, GY)
        p(10, 3, GOLD)
    elif index == 22:  # market
        box(2, 5, 12, 3, RED)
        box(3, 8, 10, 5, CREAM)
        box(7, 8, 2, 5, BR)
        p(5, 6, GOLD)
        p(10, 6, W)
    elif index == 23:  # flower
        p(8, 6, GOLD)
        p(7, 5, PINK)
        p(9, 5, PINK)
        p(6, 6, PINK)
        p(10, 6, PINK)
        p(7, 7, PINK)
        p(9, 7, PINK)
        box(8, 8, 1, 5, GD)
    elif index == 24:  # statue
        box(5, 11, 6, 2, GY)
        box(6, 8, 4, 3, CREAM)
        box(6, 4, 4, 4, CREAM)
        p(7, 5, INK)
        p(9, 5, INK)
    elif index == 25:  # monolith
        box(6, 2, 4, 12, INK)
        box(7, 5, 2, 2, W)
        p(7, 8, PUR)
    elif index == 26:  # tnt
        box(6, 3, 4, 10, RED)
        box(7, 1, 2, 3, GOLD)
        p(7, 6, W)
        p(8, 8, W)
    elif index == 27:  # goo
        box(3, 8, 10, 5, PUR)
        box(5, 6, 6, 3, (190, 90, 220, 255))
        p(4, 9, (90, 20, 120, 255))
    elif index == 28:  # hand
        box(5, 7, 2, 6, CREAM)
        box(8, 5, 2, 8, CREAM)
        box(11, 7, 2, 6, CREAM)
        box(3, 10, 3, 3, CREAM)
        box(4, 12, 8, 3, CREAM)
        p(6, 8, BR)
        p(9, 6, BR)
    elif index == 29:  # axe
        box(8, 2, 2, 12, BR)
        box(4, 2, 6, 5, GY)
        p(5, 3, W)
    elif index == 30:  # hammer
        box(8, 5, 2, 9, BR)
        box(4, 2, 8, 4, GY)
        p(5, 3, W)
    elif index == 31:  # sponge
        box(3, 5, 10, 7, GOLD)
        p(5, 7, BR)
        p(8, 6, BR)
        p(10, 9, BR)
    elif index == 32:  # pickaxe
        box(8, 6, 2, 8, BR)
        box(3, 4, 10, 3, GY)
        p(4, 3, GY)
        p(11, 3, GY)
    elif index == 33:  # bug
        box(6, 5, 5, 6, (40, 40, 40, 255))
        box(4, 7, 2, 3, INK)
        box(11, 7, 2, 3, INK)
        p(7, 4, RED)
        p(9, 4, RED)
    elif index == 34:  # grabber
        box(7, 2, 2, 6, GY)
        box(4, 8, 3, 2, GOLD)
        box(9, 8, 3, 2, GOLD)
        box(3, 10, 3, 2, GOLD)
        box(10, 10, 3, 2, GOLD)
    elif index == 35:  # chainsaw
        box(2, 7, 10, 3, GY)
        box(10, 5, 3, 7, GYD)
        p(3, 8, GOLD)
        p(5, 8, GOLD)
        p(7, 8, GOLD)
    elif index == 36:  # mop
        box(8, 1, 2, 8, BR)
        box(4, 9, 8, 4, BLUE)
        p(5, 10, W)
        p(9, 11, W)
    elif index == 37:  # swarm
        box(3, 4, 4, 4, INK)
        box(9, 3, 4, 4, INK)
        box(6, 8, 4, 4, INK)
        p(4, 5, RED)
        p(10, 4, RED)
        p(7, 9, RED)
    elif index == 38:  # nuke
        box(7, 2, 2, 10, GOLD)
        box(4, 6, 8, 2, GOLD)
        box(5, 4, 6, 6, (80, 200, 90, 255))
        p(7, 6, INK)
        p(8, 7, INK)
    elif index == 39:  # gem
        box(7, 2, 2, 2, (180, 255, 255, 255))
        box(5, 4, 6, 4, (80, 220, 230, 255))
        box(6, 8, 4, 3, (40, 150, 170, 255))
        box(7, 11, 2, 2, (20, 90, 110, 255))
        p(7, 5, W)
    elif index == 40:  # egg
        box(6, 3, 4, 2, W)
        box(5, 5, 6, 7, CREAM)
        box(6, 12, 4, 2, (210, 190, 150, 255))
        p(7, 7, W)
        p(9, 9, (200, 160, 100, 255))
        p(6, 10, (200, 160, 100, 255))


def make_atlas():
    cols = 32
    rows = 2
    sheet = new(cols * 16, rows * 16)
    for i in range(63):
        blit_icon(sheet, i, cols)
    sheet.save(OUT("resources", "structures", "structures_tileset.png"))
    icons = new(64, 16)
    for i, src in enumerate((0, 12, 13)):
        icons.alpha_composite(_ui_icon(src), (i * 16, 0))
    icons.alpha_composite(_fit(_ref("hand.png"), 16, 16), (48, 0))
    icons.save(OUT("resources", "ui", "ui_icons.png"))


def draw_eye(img, ox, oy):
    def p(x, y, c):
        px(img, ox + x, oy + y, c)

    def box(x, y, w, h, c):
        rect(img, ox + x, oy + y, w, h, c)

    W = (245, 245, 248, 255)
    INK = (24, 20, 32, 255)
    BLUE = (64, 120, 210, 255)
    box(4, 6, 8, 4, W)
    box(5, 5, 6, 1, W)
    box(5, 10, 6, 1, W)
    box(6, 6, 4, 4, BLUE)
    box(7, 6, 2, 4, INK)
    p(7, 6, W)


def _shade(color, light):
    return tuple(max(0, min(255, int(channel * light))) for channel in color[:3]) + (color[3],)


def paint_block(img, ox, top, light, dark, left_side, right_side):
    for y in range(32):
        for x in range(32):
            nx = (x + 0.5 - 16.0) / 16.0
            ny = (y + 0.5 - 16.0) / 8.0
            span = 1.0 - abs(nx)
            if span < 0.0:
                continue
            bottom = 16.0 + 8.0 * span
            if abs(nx) + abs(ny) <= 1.0:
                n = (x * 13 + y * 17) % 11
                color = light if n == 0 else dark if n == 4 else top
                px(img, ox + x, y, color)
            elif bottom <= y + 0.5 < bottom + 8.0:
                side = left_side if x < 16 else right_side
                if y + 0.5 > bottom + 5.0:
                    side = _shade(side, 0.75)
                px(img, ox + x, y, side)


def _tex(name):
    return Image.open(
        os.path.join(SRC_TEX, name)
    ).convert("RGBA")


def _sample_tile(img, ox, src):
    src = src.convert("RGBA")
    sw, sh = src.size
    sp = src.load()
    for y in range(32):
        for x in range(32):
            nx = (x + 0.5 - 16.0) / 16.0
            ny = (y + 0.5 - 16.0) / 8.0
            span = 1.0 - abs(nx)
            if span < 0.0:
                continue
            bottom = 16.0 + 8.0 * span
            if abs(nx) + abs(ny) <= 1.0:
                sx = min(sw - 1, max(0, int((nx + 1.0) * 0.5 * sw)))
                sy = min(sh - 1, max(0, int((ny + 1.0) * 0.5 * sh)))
                color = sp[sx, sy]
                if color[3] < 16:
                    continue
                px(img, ox + x, y, (color[0], color[1], color[2], 255))
            elif bottom <= y + 0.5 < bottom + 8.0:
                sx = min(sw - 1, max(0, int((abs(nx)) * (sw - 1))))
                color = sp[sx, sh // 2]
                shade = 0.62 if x < 16 else 0.45
                if y + 0.5 > bottom + 5.0:
                    shade *= 0.8
                px(img, ox + x, y, (int(color[0] * shade), int(color[1] * shade), int(color[2] * shade), 255))


def _opaque_fill(src):
    src = src.convert("RGBA")
    opaque = [pixel for pixel in src.getdata() if pixel[3] > 16]
    if not opaque:
        return src
    count = len(opaque)
    fill = (
        sum(pixel[0] for pixel in opaque) // count,
        sum(pixel[1] for pixel in opaque) // count,
        sum(pixel[2] for pixel in opaque) // count,
        255,
    )
    out = src.copy()
    pixels = out.load()
    for y in range(out.size[1]):
        for x in range(out.size[0]):
            if pixels[x, y][3] < 16:
                pixels[x, y] = fill
    return out


def _plank_seams(img, ox):
    seam = (72, 48, 28, 255)
    for y in range(32):
        for x in range(32):
            nx = (x + 0.5 - 16.0) / 16.0
            ny = (y + 0.5 - 16.0) / 8.0
            if abs(nx) + abs(ny) > 1.0:
                continue
            # Thin grooves between ~3 planks across the diamond top.
            across = ((nx - ny) + 2.0) * 1.5
            frac = across - int(across)
            if frac < 0.08 or frac > 0.92:
                px(img, ox + x, y, seam)


def make_terrain():
    grass = _tex("Grass_Bright.png")
    grass_dark = _tex("Grass_Darker.png")
    ground_a = _tex("16_Ground_Jellyfish_Style_1.png")
    ground_b = _tex("16_Ground_Jellyfish_Style_2.png")
    dirt = _tex("Wasteland_GroundTile_1_Center.png")
    water = _tex("TEMP_river.png")
    mountain = _tex("TEMP_Mountain_Bright.png")
    rubble = _tex("TEMP_Mountain_Darker.png")
    goo = _tex("T_PollutedTile_GroundVariant.png")
    # Bridge_*_Iso_A are full segment sprites, not terrain diamonds.
    # Sample their material into the same iso tile shape as grass/dirt.
    wood = _opaque_fill(_tex("Bridge_Wood_Iso_A.png"))
    bone = _opaque_fill(_tex("Bridge_Bones_Iso_A.png"))
    tiles = (grass, dirt, water, mountain, rubble, goo, wood, bone, None, grass_dark, ground_a, ground_b)
    img = new(32 * len(tiles), 32)
    for i, src in enumerate(tiles):
        if src is None:
            continue
        _sample_tile(img, i * 32, src)
        if i == 3:
            mid = src.getpixel((src.size[0] // 2, src.size[1] // 2))
            light = tuple(min(255, int(channel * 1.3)) for channel in mid[:3]) + (255,)
            dark = tuple(int(channel * 0.55) for channel in mid[:3]) + (255,)
            _peak(img, i * 32, light, dark)
        elif i == 6:
            _plank_seams(img, i * 32)
    extra = _river_tiles() + _wasteland_tiles()
    wide = new(32 * (len(tiles) + len(extra)), 32)
    wide.alpha_composite(img, (0, 0))
    for i, src in enumerate(extra):
        _sample_tile(wide, (len(tiles) + i) * 32, src)
    wide.save(OUT("resources", "tiles", "terrain_tileset.png"))
    make_space()


def _river_tiles():
    roles = (
        "River_Tile_Center_%d.png",
        "River_Tile_BorderTop_%d.png",
        "River_Tile_BorderBot_%d.png",
        "river_edge_left_%d.png",
        "river_edgle_right_%d.png",
        "river_corner_dark_NE_%d.png",
        "river_corner_dark_NW_%d.png",
        "river_corner_dark_flipped_%d.png",
        "river_corner_dark_%d.png",
    )
    tiles = []
    for role in roles:
        for n in range(1, 5):
            src = _tex(role % n)
            if src is None:
                raise SystemExit("missing river tile %s" % (role % n))
            tiles.append(src)
    return tiles


def _wasteland_tiles():
    tiles = []
    for n in range(2, 8):
        src = _tex("Wasteland_GroundTile_%d.png" % n)
        if src is None:
            raise SystemExit("missing wasteland tile %d" % n)
        tiles.append(src)
    return tiles


def _tufts(img, ox, seed):
    light = (210, 214, 130, 255) if seed == 10 else (96, 118, 48, 255)
    for n in range(7):
        seed = (seed * 1103515245 + 12345 + n) & 0x7FFFFFFF
        x = 6 + seed % 20
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        y = 10 + seed % 8
        px(img, ox + x, y, light)
        px(img, ox + x + 1, y, light)


def _peak(img, ox, left, right):
    for y in range(6, 16):
        reach = 1 + int((y - 6) * 0.45)
        for x in range(16 - reach, 16 + reach):
            px(img, ox + x, y, left if x < 16 else right)


def make_space():
    img = new(640, 360)
    rect(img, 0, 0, 640, 360, (5, 7, 14, 255))
    seed = 11
    for _n in range(220):
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        x = seed % 640
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        y = seed % 360
        bright = 180 + (seed % 75)
        tint = (bright, bright, bright, 255)
        if seed % 5 == 0:
            tint = (bright, bright - 30, 140, 255)
        px(img, x, y, tint)
    img.save(OUT("resources", "tiles", "space.png"))


def make_frame():
    img = new(24, 24)
    edge = (92, 58, 28, 255)
    mid = (176, 124, 68, 255)
    fill = (214, 176, 112, 255)
    rect(img, 0, 0, 24, 24, edge)
    rect(img, 3, 3, 18, 18, mid)
    rect(img, 6, 6, 12, 12, fill)
    px(img, 1, 1, (230, 196, 130, 255))
    px(img, 22, 22, (62, 36, 16, 255))
    img.save(OUT("resources", "ui", "ui_frame_9patch.png"))
    slot = new(24, 24)
    rect(slot, 0, 0, 24, 24, (86, 64, 40, 255))
    rect(slot, 2, 2, 20, 20, (232, 214, 176, 255))
    rect(slot, 4, 4, 16, 16, (244, 232, 204, 255))
    slot.save(OUT("resources", "ui", "ui_slot.png"))
    make_speech_bubble()


# Original Thronglets passive-dialogue bubble colors (Sprites-Misc speechbubble).
BUBBLE_FILL = (190, 213, 221, 255)
BUBBLE_HI = (214, 228, 232, 255)
BUBBLE_SHADE = (150, 172, 182, 255)
BUBBLE_OUT = (19, 10, 68, 255)


def _bubble_round_rect(img, x, y, w, h, fill, outline):
    for yy in range(h):
        for xx in range(w):
            if (xx, yy) in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
                continue
            px(img, x + xx, y + yy, fill)
    for xx in range(1, w - 1):
        px(img, x + xx, y, outline)
        px(img, x + xx, y + h - 1, outline)
    for yy in range(1, h - 1):
        px(img, x, y + yy, outline)
        px(img, x + w - 1, y + yy, outline)
    for cx, cy in (
        (1, 0), (0, 1), (w - 2, 0), (w - 1, 1),
        (1, h - 1), (0, h - 2), (w - 2, h - 1), (w - 1, h - 2),
    ):
        px(img, x + cx, y + cy, outline)


def make_speech_bubble():
    # Compact 9-slice matched to Sprites-Misc speechbubble (fill/outline).
    bw, bh = 24, 20
    body = new(bw, bh)
    _bubble_round_rect(body, 0, 0, bw, bh, BUBBLE_FILL, BUBBLE_OUT)
    for xx in range(2, bw - 2):
        px(body, xx, 1, BUBBLE_HI)
        px(body, xx, bh - 2, BUBBLE_SHADE)
    for yy in range(2, bh - 2):
        px(body, 1, yy, BUBBLE_HI)
        px(body, bw - 2, yy, BUBBLE_SHADE)
    body.save(OUT("resources", "ui", "speech_bubble_9patch.png"))

    tw, th = 11, 8
    tail = new(tw, th)
    rows = (
        "OOOOOOOOOOO",
        "O#########O",
        "O#########O",
        " O#######O ",
        "  O#####O  ",
        "   O###O   ",
        "    O#O    ",
        "     O     ",
    )
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "O":
                px(tail, x, y, BUBBLE_OUT)
            elif ch == "#":
                px(tail, x, y, BUBBLE_FILL)
    tail.save(OUT("resources", "ui", "speech_bubble_tail.png"))


# 5x7 glyphs. Rows are the low 5 bits, top to bottom.
GLYPHS = {
    " ": [0, 0, 0, 0, 0, 0, 0],
    "A": [14, 17, 17, 31, 17, 17, 17],
    "B": [30, 17, 17, 30, 17, 17, 30],
    "C": [14, 17, 16, 16, 16, 17, 14],
    "D": [30, 17, 17, 17, 17, 17, 30],
    "E": [31, 16, 16, 30, 16, 16, 31],
    "F": [31, 16, 16, 30, 16, 16, 16],
    "G": [14, 17, 16, 23, 17, 17, 14],
    "H": [17, 17, 17, 31, 17, 17, 17],
    "I": [14, 4, 4, 4, 4, 4, 14],
    "J": [7, 2, 2, 2, 2, 18, 12],
    "K": [17, 18, 20, 24, 20, 18, 17],
    "L": [16, 16, 16, 16, 16, 16, 31],
    "M": [17, 27, 21, 21, 17, 17, 17],
    "N": [17, 25, 21, 19, 17, 17, 17],
    "O": [14, 17, 17, 17, 17, 17, 14],
    "P": [30, 17, 17, 30, 16, 16, 16],
    "Q": [14, 17, 17, 17, 21, 18, 13],
    "R": [30, 17, 17, 30, 20, 18, 17],
    "S": [14, 17, 16, 14, 1, 17, 14],
    "T": [31, 4, 4, 4, 4, 4, 4],
    "U": [17, 17, 17, 17, 17, 17, 14],
    "V": [17, 17, 17, 17, 17, 10, 4],
    "W": [17, 17, 17, 21, 21, 27, 17],
    "X": [17, 17, 10, 4, 10, 17, 17],
    "Y": [17, 17, 10, 4, 4, 4, 4],
    "Z": [31, 1, 2, 4, 8, 16, 31],
    "0": [14, 17, 19, 21, 25, 17, 14],
    "1": [4, 12, 4, 4, 4, 4, 14],
    "2": [14, 17, 1, 6, 8, 16, 31],
    "3": [14, 17, 1, 6, 1, 17, 14],
    "4": [2, 6, 10, 18, 31, 2, 2],
    "5": [31, 16, 30, 1, 1, 17, 14],
    "6": [6, 8, 16, 30, 17, 17, 14],
    "7": [31, 1, 2, 4, 4, 4, 4],
    "8": [14, 17, 17, 14, 17, 17, 14],
    "9": [14, 17, 17, 15, 1, 2, 12],
    ".": [0, 0, 0, 0, 0, 0, 4],
    ",": [0, 0, 0, 0, 4, 4, 8],
    ":": [0, 4, 4, 0, 4, 4, 0],
    "%": [18, 18, 2, 4, 8, 9, 9],
    "#": [10, 10, 31, 10, 31, 10, 10],
    "+": [0, 4, 4, 31, 4, 4, 0],
    "-": [0, 0, 0, 31, 0, 0, 0],
    "/": [1, 2, 2, 4, 8, 8, 16],
    "?": [14, 17, 1, 2, 4, 0, 4],
    "!": [4, 4, 4, 4, 4, 0, 4],
    "(": [2, 4, 8, 8, 8, 4, 2],
    ")": [8, 4, 2, 2, 2, 4, 8],
    "'": [4, 4, 8, 0, 0, 0, 0],
}


def _with_accent(base_rows, accent):
    rows = list(base_rows)
    if accent == "acute":
        rows[0] = rows[0] | 0b00100
    elif accent == "tilde":
        rows[0] = 0b01010
    return rows


def make_font():
    glyphs = dict(GLYPHS)
    glyphs["Á"] = _with_accent(GLYPHS["A"], "acute")
    glyphs["É"] = _with_accent(GLYPHS["E"], "acute")
    glyphs["Í"] = _with_accent(GLYPHS["I"], "acute")
    glyphs["Ó"] = _with_accent(GLYPHS["O"], "acute")
    glyphs["Ú"] = _with_accent(GLYPHS["U"], "acute")
    glyphs["Ñ"] = _with_accent(GLYPHS["N"], "tilde")
    glyphs["¿"] = [4, 0, 4, 8, 16, 17, 14]
    glyphs["¡"] = [4, 0, 4, 4, 4, 4, 4]
    chars = list(glyphs.keys())
    cols = 16
    rows = (len(chars) + cols - 1) // cols
    cell_w, cell_h = 6, 8
    img = new(cols * cell_w, rows * cell_h)
    cream = (62, 36, 18, 255)
    lines = [
        "info face=\"pixel\" size=8 bold=0 italic=0 charset=\"\" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=0,0",
        "common lineHeight=8 base=7 scaleW=%d scaleH=%d pages=1 packed=0" % (img.size[0], img.size[1]),
        "page id=0 file=\"pixel_font.png\"",
        "chars count=%d" % len(chars),
    ]
    for i, ch in enumerate(chars):
        cx = (i % cols) * cell_w
        cy = (i // cols) * cell_h
        bits = glyphs[ch]
        for ry, bits_row in enumerate(bits):
            for rx in range(5):
                if bits_row & (1 << (4 - rx)):
                    px(img, cx + rx, cy + ry, cream)
        lines.append(
            "char id=%d x=%d y=%d width=5 height=7 xoffset=0 yoffset=0 xadvance=6 page=0 chnl=15"
            % (ord(ch), cx, cy)
        )
    img.save(OUT("resources", "ui", "pixel_font.png"))
    with open(OUT("resources", "ui", "pixel_font.fnt"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


# World art is cropped from resources/src and packed into the sheets.
# The monolith and the purple goo stay the painted pillar and crystal.
STRUCT = lambda name: OUT("resources", "src", "structures", name)
ITEM = lambda name: OUT("resources", "src", "items", name)
REF = lambda name: OUT("resources", "src", "ref", name)


def _open_png(path):
    img = Image.open(path).convert("RGBA")
    box = img.getbbox()
    if box:
        img = img.crop(box)
    return img


def _open_struct(name):
    return _open_png(STRUCT(name))


def _ref(name):
    return _open_png(REF(name))


def _tex_frame(name, index, fw, fh):
    img = Image.open(os.path.join(SRC_TEX, name)).convert("RGBA")
    return img.crop((index * fw, 0, (index + 1) * fw, fh))


def _fit(img, max_w, max_h, zoom=1):
    if zoom > 1:
        img = img.resize((img.size[0] * zoom, img.size[1] * zoom), Image.NEAREST)
    scale = min(float(max_w) / img.size[0], float(max_h) / img.size[1], 1.0)
    if scale < 0.999:
        img = img.resize(
            (max(1, int(round(img.size[0] * scale))), max(1, int(round(img.size[1] * scale)))),
            Image.NEAREST,
        )
    return img


def _px(img, ppu=100.0):
    # Keep Unity pixels. Draw scale (throngs) or footprint sizing carries world size.
    # Only shrink when the sprite cannot fit the world cell.
    _ = ppu
    if img.size[0] <= CELL_W and img.size[1] <= CELL_H:
        return img
    return _fit(img, CELL_W, CELL_H)


def _gray(img):
    out = img.copy()
    pix = out.load()
    for y in range(out.size[1]):
        for x in range(out.size[0]):
            r, g, b, a = pix[x, y]
            if a < 16:
                continue
            lum = int(r * 0.3 + g * 0.5 + b * 0.2)
            pix[x, y] = (lum, lum, min(255, lum + 8), a)
    return out


def _tint(img, mul):
    out = img.copy()
    pix = out.load()
    for y in range(out.size[1]):
        for x in range(out.size[0]):
            r, g, b, a = pix[x, y]
            if a < 16:
                continue
            pix[x, y] = (min(255, int(r * mul[0])), min(255, int(g * mul[1])), min(255, int(b * mul[2])), a)
    return out


def _world_sprites():
    # Keep Unity pixels for world props. Only shrink when a sprite cannot fit the cell.
    tree = _px(_ref("tree.png"), 54)
    rock = _px(_ref("rock.png"))
    ore = _px(_ref("ore_rock.png"))
    node = _px(_ref("node.png"))
    super_gem = _px(_ref("super.png"))
    apple = tree
    tub = _px(_ref("tub.png"))
    merry = _px(_ref("round.png"))
    dwell = _px(_ref("dwell.png"))
    fancy = _px(_ref("fancy.png"))
    mine = _px(_ref("mine.png"))
    mine2 = _px(_ref("mine2.png"))
    factory = _px(_ref("factory.png"))
    factory2 = _px(_ref("factory2.png"))
    theatre = _px(_ref("theatre.png"))
    cannon = _px(_ref("cannon.png"))
    market = _px(_ref("market.png"))
    monolith = _px(_ref("monolith.png"))
    statue = _px(_ref("statue.png"))
    goo = _px(_ref("goo.png"))
    bigrock = _px(_ref("bigrock.png"))
    cosmetic = _px(_ref("cosmetic.png"))
    cosmetic_bad = _px(_ref("cosmetic_bad.png"))
    ore_mega = _px(_ref("ore_mega.png"))
    ore_super = _px(_ref("ore_super.png"))
    ore_ultra = _px(_ref("ore_ultra.png"))
    wood_statue = _px(_ref("wood_statue.png"))
    fire = _px(_ref("fire.png"))
    totem = _px(_ref("totem.png"))
    curer = _px(_ref("curer.png"))
    jack = _px(_ref("jack.png"))
    superbug = _px(_ref("superbug.png"))
    theatre2 = _px(_ref("theatre2.png"))
    maw = _px(_ref("maw.png"))
    mstump = _px(_ref("mstump.png"))
    mnode = _px(_ref("mnode.png"))
    sprites = (
        tree, rock, ore, node, super_gem, apple, tub, merry, dwell, fancy,
        mine, mine2, factory, factory2, theatre, cannon, market, monolith, statue, goo,
        bigrock, cosmetic, cosmetic_bad, ore_mega, ore_super, ore_ultra,
        wood_statue, fire, totem, curer, jack, superbug, theatre2, maw, mstump, mnode,
    )
    extras = {
        3: _px(_ref("stump.png")),
        23: _px(_ref("flower.png")),
        41: _px(_ref("fx_chop.png")),
        42: _px(_ref("fx_hammer.png")),
        43: _px(_ref("fx_spark.png")),
        44: _px(_ref("fx_boom.png")),
        45: _px(_ref("fx_poof.png")),
        46: _px(_ref("fx_blood.png")),
    }
    icons = {
        2: tree, 3: extras[3], 4: rock, 5: ore, 6: node, 7: super_gem,
        11: apple, 12: tub, 13: merry, 14: dwell, 15: fancy,
        16: mine, 17: mine2, 18: factory, 19: factory2, 20: theatre,
        21: cannon, 22: market, 23: extras[23], 24: statue, 25: monolith, 27: goo,
        47: bigrock, 48: cosmetic, 49: cosmetic_bad,
        50: ore_mega, 51: ore_super, 52: ore_ultra,
        53: wood_statue, 54: fire, 55: totem, 56: curer, 57: jack,
        58: superbug, 59: theatre2, 60: maw, 61: mstump, 62: mnode,
    }
    for key in (41, 42, 43, 44, 45, 46):
        icons[key] = extras[key]
    return sprites, extras, icons


WORLD_SPRITES, WORLD_EXTRAS, WORLD_ICONS = _world_sprites()


def _item_icons():
    def load(name):
        return _open_png(ITEM(name))

    return {
        0: _ref("apple.png"),
        1: _ref("ball.png"),
        8: _ref("wood.png"),
        9: _ref("bone.png"),
        10: _ref("ore.png"),
        26: _ref("tnt.png"),
        28: _ref("hand.png"),
        29: _ref("axe.png"),
        30: _ref("hammer.png"),
        31: _ref("sponge.png"),
        32: _ref("pick.png"),
        33: _ref("bug.png"),
        35: _ref("saw.png"),
        36: _ref("mop.png"),
        37: _ref("swarm.png"),
        38: _ref("nuke.png"),
        39: _ref("gem.png"),
        40: _ref("egg.png"),
    }


ITEM_ICONS = _item_icons()


def _ui_icon(index):
    if index in ITEM_ICONS:
        return _fit(ITEM_ICONS[index], 16, 16)
    if index in WORLD_ICONS:
        return _fit(WORLD_ICONS[index], 16, 16)
    tile = new(16, 16)
    draw_icon(tile, 0, 0, index)
    return tile


def _cell_sprite(img):
    cell = new(CELL_W, CELL_H)
    x = (CELL_W - img.size[0]) // 2
    cell.alpha_composite(img, (x, CELL_H - img.size[1]))
    return cell


def make_world():
    cols, rows = 16, 9
    sheet = new(cols * CELL_W, rows * CELL_H)
    blobs = Image.open(OUT("resources", "sprites", "thronglet_32.png"))
    for index in range(24):
        tile = blobs.crop((
            (index % 4) * CELL_W,
            (index // 4) * CELL_H,
            (index % 4) * CELL_W + CELL_W,
            (index // 4) * CELL_H + CELL_H,
        ))
        # ThrongA is 0.34x0.38 world. 52px on the tree is 1.0, so the body is 18x20.
        tile = _shrink_body(tile, 18, 20)
        sheet.alpha_composite(tile, ((index % cols) * CELL_W, (index // cols) * CELL_H))
    for icon in range(63):
        index = 24 + icon
        if icon in WORLD_EXTRAS:
            tile = WORLD_EXTRAS[icon]
        elif icon in ITEM_ICONS:
            tile = _px(ITEM_ICONS[icon])
        elif icon in WORLD_ICONS:
            tile = _px(WORLD_ICONS[icon])
        else:
            tile = new(16, 16)
            draw_icon(tile, 0, 0, icon)
            tile = _px(tile.resize((16 * PROP_SCALE, 16 * PROP_SCALE), Image.NEAREST))
        sheet.alpha_composite(tile, (
            (index % cols) * CELL_W + (CELL_W - tile.size[0]) // 2,
            (index // cols) * CELL_H + CELL_H - tile.size[1],
        ))
    for big, img in enumerate(WORLD_SPRITES):
        index = 96 + big
        sheet.alpha_composite(_cell_sprite(img), ((index % cols) * CELL_W, (index // cols) * CELL_H))
    # Egg wiggle/crack/hatch and the roundabout spin. Frames 87-91 and 132-139 are free.
    for i in range(5):
        _stamp_frame(sheet, cols, 87 + i, _px(_ref("egg_%d.png" % i)))
    for i in range(8):
        _stamp_frame(sheet, cols, 132 + i, _px(_ref("round_%d.png" % i)))
    # Animated ground fire. fire.png stays the bubble glyph, not this.
    flame = Image.open(os.path.join(SRC_TEX, "T_FireSprites_Color_16x1.png")).convert("RGBA")
    for i in range(4):
        src = i * 4
        frame = flame.crop((src * 32, 0, src * 32 + 32, 32))
        _stamp_frame(sheet, cols, 140 + i, _px(frame))
    sheet = _stamp_throng_anims(sheet, cols)
    sheet.save(OUT("resources", "sprites", "world_iso.png"))
    # Drop Godot's cached .ctex so the next run picks up the new sheet.
    imported = OUT(".godot", "imported")
    if os.path.isdir(imported):
        for name in os.listdir(imported):
            if name.startswith("world_iso.png-") or name.startswith("world_iso_dirt.png-"):
                try:
                    os.remove(os.path.join(imported, name))
                except OSError:
                    pass


def _shrink_body(tile, max_w, max_h):
    box = tile.getbbox()
    if not box:
        return tile
    body = _fit(tile.crop(box), max_w, max_h)
    out = new(CELL_W, CELL_H)
    out.alpha_composite(body, ((CELL_W - body.size[0]) // 2, CELL_H - body.size[1]))
    return out


def _stamp_frame(sheet, cols, index, img):
    # Paint inside this cell only. A sprite must not leak into the next frame.
    cell = new(CELL_W, CELL_H)
    _blit(cell, img, (CELL_W - img.size[0]) // 2, CELL_H - img.size[1])
    sheet.paste(cell, ((index % cols) * CELL_W, (index // cols) * CELL_H))


def make_hud():
    # Real ThrongletCounter frame from the Unity atlas (cream ring + dark well).
    atlas_path = os.path.join(
        SRC_TEX, "sactx-0-512x256-Uncompressed-Sprites-ThrongletCounter-5537a982.png",
    )
    if not os.path.isfile(atlas_path):
        atlas_path = OUT(
            "references", "Assets", "Texture2D",
            "sactx-0-512x256-Uncompressed-Sprites-ThrongletCounter-5537a982.png",
        )
    meta_path = os.path.join(SRC_SPRITE, "ThrongletCounter.json")
    if os.path.isfile(atlas_path) and os.path.isfile(meta_path):
        atlas = Image.open(atlas_path).convert("RGBA")
        meta = json.load(open(meta_path))
        settings = int((meta.get("m_RD") or {}).get("m_SettingsRaw") or 0)
        ring = _crop_unity(atlas, meta["m_Rect"], settings)
        out = new(56, 56)
        # Native cell is ~60px; center-crop into the 56 HUD badge.
        ox = (ring.size[0] - 56) // 2
        oy = (ring.size[1] - 56) // 2
        out.alpha_composite(ring, (-ox, -oy))
        ring = out
    else:
        ring = new(56, 56)
        for y in range(56):
            for x in range(56):
                d = ((x - 27.5) ** 2 + (y - 27.5) ** 2) ** 0.5
                if d <= 26.0:
                    color = (92, 58, 28, 255) if d >= 22.0 else (232, 189, 152, 255)
                    if d < 15.0:
                        color = (75, 49, 35, 255)
                    px(ring, x, y, color)
    ring.save(OUT("resources", "ui", "ui_circle.png"))
    kit = new(32, 32)
    for y in range(32):
        for x in range(32):
            d = ((x - 15.5) ** 2 + (y - 15.5) ** 2) ** 0.5
            if d <= 15.0:
                color = (70, 48, 28, 255) if d >= 12.5 else (232, 210, 170, 255)
                px(kit, x, y, color)
    wood = (118, 74, 40, 255)
    metal = (90, 102, 114, 255)
    hole = (232, 210, 170, 255)
    rect(kit, 6, 12, 3, 12, wood)
    rect(kit, 3, 8, 9, 5, wood)
    rect(kit, 21, 12, 3, 12, metal)
    rect(kit, 18, 6, 9, 3, metal)
    rect(kit, 18, 6, 3, 7, metal)
    rect(kit, 24, 6, 3, 7, metal)
    rect(kit, 20, 8, 4, 3, hole)
    kit.save(OUT("resources", "ui", "ui_kit.png"))
    # OldOS goal banner: white outer, cyan ring, stretchable panes.
    white = (255, 255, 255, 255)
    cyan_ring = (3, 209, 255, 255)
    cyan_fill = (88, 200, 218, 255)
    grey_fill = (213, 210, 209, 255)
    goal = new(16, 16)
    rect(goal, 0, 0, 16, 16, white)
    rect(goal, 3, 3, 10, 10, cyan_ring)
    rect(goal, 4, 4, 8, 8, (0, 0, 0, 0))
    goal.save(OUT("resources", "ui", "ui_goal_frame.png"))
    tag = new(8, 8)
    rect(tag, 0, 0, 8, 8, cyan_fill)
    tag.save(OUT("resources", "ui", "ui_goal_tag.png"))
    body = new(8, 8)
    rect(body, 0, 0, 8, 8, grey_fill)
    body.save(OUT("resources", "ui", "ui_goal_body.png"))


THRONG_SKIP = (
    "ThrongletCounter",
    "ThrongletFace",
    "Thronglet1",
    "Thronglet2",
    "Throng_UI_",
    "Thronglet_Counter",
)
THRONG_BASE = 144


def _throng_key(base):
    if "_Alpha" in base:
        return None
    if base.startswith(THRONG_SKIP):
        return None
    head, tail = base.rsplit("_", 1) if "_" in base else (base, "")
    if tail.isdigit():
        return head, int(tail)
    return base, 0


def _unity_unpack(img, settings_raw):
    # Undo SpritePackingRotation from settingsRaw when the atlas cell is packed.
    if not (int(settings_raw) & 1):
        return img
    rotation = (int(settings_raw) >> 2) & 0xF
    if rotation == 1:
        return img.transpose(Image.FLIP_LEFT_RIGHT)
    if rotation == 2:
        return img.transpose(Image.FLIP_TOP_BOTTOM)
    if rotation == 3:
        return img.transpose(Image.ROTATE_180)
    if rotation == 4:
        return img.transpose(Image.ROTATE_270)
    return img


def _crop_unity(atlas, rect, settings_raw=0):
    x = int(round(rect["m_X"]))
    y = int(round(rect["m_Y"]))
    w = max(1, int(round(rect["m_Width"])))
    h = max(1, int(round(rect["m_Height"])))
    top = atlas.size[1] - (y + h)
    left = max(0, x)
    upper = max(0, top)
    right = min(atlas.size[0], x + w)
    lower = min(atlas.size[1], top + h)
    if right <= left or lower <= upper:
        return new(1, 1)
    return _unity_unpack(atlas.crop((left, upper, right, lower)), settings_raw)


def _kickrock_strip(dirt_atlas):
    # 14 registered cells. The atlas rects for the later frames include a neighbor sprite.
    path = os.path.join(SRC_TEX, "ThrongA_Bored_KickRock_Spritesheet.png")
    if not os.path.isfile(path):
        return []
    sheet = Image.open(path).convert("RGBA")
    count = 14
    fw = sheet.size[0] // count
    fh = sheet.size[1]
    meta = json.load(open(os.path.join(
        SRC_SPRITE, "Char_ThrongA_Bored_KickRock_Spritesheet_0.json",
    )))
    rect = meta["m_Rect"]
    pivot = meta.get("m_Pivot") or {}
    # Frame 0 of the strip is that rect, sitting at the cell origin.
    px = float(pivot.get("m_X", 0.5)) * float(rect["m_Width"]) / float(fw)
    py = 1.0 - (1.0 - float(pivot.get("m_Y", 0.5))) * float(rect["m_Height"]) / float(fh)
    pivot_n = (px, py)
    dirt = new(fw, fh)
    dirt_crop = _crop_unity(dirt_atlas, rect)
    if dirt_crop.size[0] <= fw and dirt_crop.size[1] <= fh:
        dirt.alpha_composite(dirt_crop, (0, 0))
    frames = []
    for i in range(count):
        frame = sheet.crop((i * fw, 0, (i + 1) * fw, fh))
        frames.append((i, "ThrongA_Bored_KickRock_%d" % i, frame, dirt.copy(), pivot_n))
    return frames


def _load_throng_clips():
    folder = SRC_SPRITE
    tex_dir = SRC_TEX
    atlas = Image.open(os.path.join(
        tex_dir, "sactx-0-2048x2048-Uncompressed-Sprites-Thronglets-fc0e3430.png",
    )).convert("RGBA")
    dirt_atlas = Image.open(os.path.join(
        tex_dir, "sactx-0-2048x2048-Uncompressed-Sprites-Thronglets-fc0e3430?_DirtTex.png",
    )).convert("RGBA")
    groups = {}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".json"):
            continue
        base = name[:-5]
        # The packed atlas rects for this clip overlap the next sprite.
        # The strip is the animation. Loaded below.
        if base.startswith("Char_ThrongA_Bored_KickRock_"):
            continue
        elif name.startswith("Throng"):
            key = _throng_key(base)
        else:
            continue
        if key is None:
            continue
        clip, order = key
        data = json.load(open(os.path.join(folder, name)))
        rect = data.get("m_Rect")
        if not rect:
            continue
        pivot = data.get("m_Pivot") or {}
        settings_raw = int((data.get("m_RD") or {}).get("m_SettingsRaw") or 0)
        groups.setdefault(clip, [])
        groups[clip].append((
            order,
            name,
            _crop_unity(atlas, rect, settings_raw),
            _crop_unity(dirt_atlas, rect, settings_raw),
            (float(pivot.get("m_X", 0.5)), float(pivot.get("m_Y", 0.5))),
        ))
    kick = _kickrock_strip(dirt_atlas)
    if kick:
        groups["ThrongA_Bored_KickRock"] = kick
    clips = {}
    for clip in sorted(groups):
        frames = [(img, dirt, pivot) for _order, _name, img, dirt, pivot in sorted(groups[clip])]
        clips[clip] = frames
    return clips


def _grow_sheet(sheet, cols, rows):
    if sheet.size[1] >= rows * CELL_H and sheet.size[0] >= cols * CELL_W:
        return sheet
    bigger = new(cols * CELL_W, rows * CELL_H)
    bigger.alpha_composite(sheet, (0, 0))
    return bigger


def _write_throng_clips(entries, rows, talk, idle):
    def strings(names):
        return ",\n".join('\t\t"%s"' % name.replace('"', "") for name in names)
    body = []
    body.append("class_name ThrongClips")
    body.append("extends Object")
    body.append("")
    body.append("const SHEET_COLS := %d" % 16)
    body.append("const SHEET_ROWS := %d" % rows)
    body.append("const BASE := %d" % THRONG_BASE)
    body.append("")
    body.append("const CLIPS := {")
    for name, start, count in entries:
        body.append('\t"%s": Vector2i(%d, %d),' % (name.replace('"', ""), start, count))
    body.append("}")
    body.append("")
    body.append("const TALK := [")
    body.append(strings(talk))
    body.append("]")
    body.append("")
    body.append("const IDLE := [")
    body.append(strings(idle))
    body.append("]")
    body.append("")
    body.append("static func has_clip(clip: String) -> bool:")
    body.append("\treturn CLIPS.has(clip)")
    body.append("")
    body.append("static func frame_at(clip: String, tick: int) -> int:")
    body.append("\tvar box: Vector2i = CLIPS.get(clip, Vector2i(20, 1))")
    body.append("\tif box.y <= 1:")
    body.append("\t\treturn box.x")
    body.append("\treturn box.x + posmod(tick, box.y)")
    body.append("")
    body.append("static func frame_along(clip: String, along: float) -> int:")
    body.append("\tvar box: Vector2i = CLIPS.get(clip, Vector2i(20, 1))")
    body.append("\tvar n := maxi(box.y, 1)")
    body.append("\treturn box.x + clampi(int(clampf(along, 0.0, 0.999) * float(n)), 0, n - 1)")
    body.append("")
    body.append("static func pick(pool: Array, index: int, time: float, hold: float) -> int:")
    body.append("\tif pool.is_empty():")
    body.append("\t\treturn 20")
    body.append("\tvar which := int(time / hold) + index")
    body.append("\tvar name := str(pool[posmod(which, pool.size())])")
    body.append("\tvar local := time - float(int(time / hold)) * hold")
    body.append("\treturn frame_at(name, int(local * 8.0))")
    body.append("")
    path = OUT("throng_clips.gd")
    with open(path, "w") as handle:
        handle.write("\n".join(body) + "\n")


def _throng_pair(frame, dirt, scale, wide):
    box = frame.getbbox()
    if not box:
        empty = new(1, 1)
        fitted = _fit(empty, 56 if wide else 24, 20)
        return fitted, fitted.copy()
    body = frame.crop(box)
    grime = dirt.crop(box) if dirt is not None else new(body.size[0], body.size[1])
    if scale < 0.999:
        size = (
            max(1, int(round(body.size[0] * scale))),
            max(1, int(round(body.size[1] * scale))),
        )
        body = body.resize(size, Image.NEAREST)
        grime = grime.resize(size, Image.NEAREST)
    target = (56 if wide else 24, 20)
    return _fit(body, target[0], target[1]), _fit(grime, target[0], target[1])


def _tex(name):
    path = os.path.join(SRC_TEX, name)
    if not os.path.isfile(path):
        return None
    return Image.open(path).convert("RGBA")


def _split_strip(img, count):
    count = max(1, int(count))
    width = img.size[0] // count
    if width < 1:
        return [img]
    frames = []
    for i in range(count):
        frames.append(img.crop((i * width, 0, (i + 1) * width, img.size[1])))
    return frames


def _stamp_loose_clips(sheet, dirt_sheet, cols, index, entries, idle):
    singles = (
        ("ThrongA_Default_Ghost", "Char_ThrongA_Default_Ghost.png"),
        ("Thronglet_Outline", "T_ThrongletOutline.png"),
        ("Throng_Outline", "T_ThrongOutline.png"),
    )
    have = set(name for name, _start, _count in entries)
    for clip, filename in singles:
        if clip in have:
            continue
        img = _tex(filename)
        if img is None:
            continue
        body, _grime = _throng_pair(img, new(img.size[0], img.size[1]), 1.0, False)
        _stamp_frame(sheet, cols, index, body)
        _stamp_frame(dirt_sheet, cols, index, new(1, 1))
        entries.append((clip, index, 1))
        if clip == "ThrongA_Default_Ghost":
            idle.append(clip)
        index += 1
    return index


def _write_asset_frames(slots):
    lines = [
        "class_name AssetFrames",
        "extends Object",
        "",
    ]
    for name, start, count in slots:
        lines.append("const %s := %d" % (name, start))
        lines.append("const %s_N := %d" % (name, count))
    lines.append("")
    lines.append("# Generated with asset_frames.gd by tools/make_art.py. Bench and AnimTune read this.")
    lines.append("const SLOTS := [")
    for name, _start, _count in slots:
        lines.append('\t["%s", %s, %s_N],' % (name, name, name))
    lines.append("]")
    lines.append("")
    lines.append("static func frame(start: int, count: int, tick: int) -> int:")
    lines.append("\tif count <= 0:")
    lines.append("\t\treturn -1")
    lines.append("\treturn start + posmod(tick, count)")
    lines.append("")
    with open(OUT("asset_frames.gd"), "w") as handle:
        handle.write("\n".join(lines) + "\n")


def _trim_frame(img):
    img = img.convert("RGBA")
    w, h = img.size
    if w < 2 or h < 2:
        return img
    corners = (
        img.getpixel((0, 0)),
        img.getpixel((w - 1, 0)),
        img.getpixel((0, h - 1)),
        img.getpixel((w - 1, h - 1)),
    )
    if all(p[3] > 240 and p[0] < 12 and p[1] < 12 and p[2] < 12 for p in corners):
        diff = ImageChops.difference(img.convert("RGB"), Image.new("RGB", img.size, (0, 0, 0))).convert("L")
        img.putalpha(diff)
    box = img.getbbox()
    if box:
        return img.crop(box)
    return img


def _sprite_cuts(filename):
    stem = filename[:-4]
    folder = SRC_SPRITE
    img = _tex(filename)
    if img is None or not os.path.isdir(folder):
        return []
    found = []
    for name in os.listdir(folder):
        if not name.endswith(".json"):
            continue
        base = name[:-5]
        if base != stem and not base.startswith(stem + "_"):
            continue
        tail = base[len(stem):].lstrip("_")
        if "_" in tail:
            continue
        if tail and not tail.isdigit():
            continue
        data = json.load(open(os.path.join(folder, name)))
        rect = data.get("m_Rect")
        if not rect or float(rect.get("m_Width", 0)) < 1:
            continue
        settings_raw = int((data.get("m_RD") or {}).get("m_SettingsRaw") or 0)
        found.append((int(tail) if tail else 0, _crop_unity(img, rect, settings_raw)))
    found.sort(key=lambda item: item[0])
    frames = [frame for _order, frame in found]
    if not frames:
        return []
    biggest = max(frame.size[0] * frame.size[1] for frame in frames)
    return [frame for frame in frames if frame.size[0] * frame.size[1] * 8 >= biggest]


def _equal_cuts(img, count):
    frames = []
    for frame in _split_strip(img, count):
        trimmed = _trim_frame(frame)
        if trimmed.getbbox():
            frames.append(trimmed)
    return frames


def _band_cuts(img):
    img = img.convert("RGBA")
    w, h = img.size
    pix = img.load()
    empty = []
    for x in range(w):
        empty.append(not any(pix[x, y][3] > 8 for y in range(h)))
    frames = []
    x = 0
    while x < w:
        if empty[x]:
            x += 1
            continue
        start = x
        hole = 0
        while x < w:
            if empty[x]:
                hole += 1
                if hole >= 6:
                    x = x - hole + 1
                    break
                x += 1
            else:
                hole = 0
                x += 1
        if x - start >= 16:
            frames.append(_trim_frame(img.crop((start, 0, x, h))))
        if x <= start:
            x = start + 1
    return frames


def _effect_frames(filename, columns):
    frames = _sprite_cuts(filename)
    if frames:
        return frames
    img = _tex(filename)
    if img is None:
        return []
    if columns == 0:
        banded = _band_cuts(img)
        if banded:
            return banded
    if columns > 1:
        return _equal_cuts(img, columns)
    return [_trim_frame(img)]


def _stamp_fx_and_biomes(sheet, cols, index):
    slots = []

    def take(name, filename, fit, columns=1, floor=0):
        nonlocal index
        frames = _effect_frames(filename, columns)
        if not frames:
            slots.append((name, 0, 0))
            return
        start = index
        for frame in frames:
            shown = _trim_frame(frame)
            long_side = max(shown.size)
            if floor and long_side < floor:
                shown = _fit(shown, fit[0], fit[1], max(1, int(round(float(floor) / long_side))))
            else:
                shown = _fit(shown, fit[0], fit[1])
            _stamp_frame(sheet, cols, index, shown)
            index += 1
        slots.append((name, start, len(frames)))

    take("BUBBLE", "FX_SoapBubbles_Spritesheet.png", (28, 28))
    take("BUBBLE_LIGHT", "FX_SoapBubblesLight_Spritesheet.png", (28, 28), 0)
    take("CLEAN", "FX_CleanSparkles_Spritesheet.png", (28, 28))
    take("SPLASH", "FX_WaterSplash_Spritesheet.png", (48, 36), 0)
    take("SMOKE", "T_PixelSmoke.png", (28, 28))
    take("AURA", "T_AuraSmoke.png", (36, 36))
    take("SPARK", "T_Spark.png", (16, 16), 1, 12)
    take("GLITCH", "Glitch_Animation_Spritesheet.png", (64, 40))
    take("TILE_GLITCH", "Tile_Glitch_Anim_Spritesheet.png", (40, 40))
    take("HAND", "Hand_PickUp_Spritesheet.png", (36, 36), 4)
    take("FIRE", "T_FireSprites_Color_16x1.png", (32, 24), 16)
    take("GLITCH_HOUSE", "Prop_Dwelling_Glitchy_Act3.png", (CELL_W, CELL_H))
    take("GLITCH_TREE", "Prop_Tree_B_Glitchy_Act3.png", (40, 48))
    take("WASTE_TREE", "Props_Wasteland_Tree_A.png", (40, 48))
    take("ANOMALY", "Map_Anomaly_Pile_Sprite.png", (44, 36))
    take("ANOMALY_RAY", "Map_AnomalyPile_Ray_Idle_Sprite.png", (40, 44))
    take("EPILOGUE", "T_Epilogue_Thronglet.png", (40, 40))
    for extra in ("T_Epilogue_Thronglet2.png", "T_Epilogue_Thronglet3.png", "T_Epilogue_Thronglet4.png", "T_Epilogue_Thronglet5.png"):
        frame = _tex(extra)
        if frame is None or not slots or slots[-1][0] != "EPILOGUE":
            continue
        shown = _fit(_trim_frame(frame), 40, 40)
        _stamp_frame(sheet, cols, index, shown)
        index += 1
        _name, start, count = slots[-1]
        slots[-1] = (_name, start, count + 1)
    take("ROTTEN_APPLE", "T_Epilogue_Apple_rot.png", (20, 20))
    suds = _fit(_ref("fx_suds.png"), 24, 24)
    _stamp_frame(sheet, cols, index, suds)
    slots.append(("SUDS", index, 1))
    index += 1
    take("GLITCH_TREE_C", "Prop_Tree_C_Glitchy_Act3.png", (40, 48))
    take("GLITCH_TREE_D", "Prop_Tree_D_Glitchy_Act3.png", (40, 48))
    take("WASTE_TREE_B", "Props_Wasteland_Tree_B.png", (40, 48))
    take("EPI_APPLE", "T_Epilogue_Apple.png", (20, 20))
    take("MOUNT_BIG", "Map_Mountain_Big.png", (112, 80))
    take("MOUNT_SMALL", "Map_Mountain_Small_A.png", (56, 48))
    take("MOUNT_GLITCH", "Map_Mountain_Big_Glitch.png", (112, 80))
    take("GRASS_PATCH", "Grass_Patch.png", (32, 20))
    take("FUMES", "T_PollutionFumes_8x1.png", (28, 24), 8, 22)
    take("FIRE_BLOB", "T_FireBlob_8x1.png", (24, 20), 8, 18)
    _write_asset_frames(slots)
    return index


def _throng_fit(frames):
    # Keep the Unity pixels. Scale a clip only when it does not fit in the cell.
    limit = float(CELL_W - 4)
    max_w = 1
    max_h = 1
    for img, _dirt, _pivot in frames:
        max_w = max(max_w, img.size[0])
        max_h = max(max_h, img.size[1])
    scale = min(1.0, limit / float(max_w), limit / float(max_h))
    anchor = 0.0
    for img, _dirt, pivot in frames:
        anchor = max(anchor, pivot[1] * img.size[1] * scale)
    return scale, min(anchor, float(CELL_H - 4))


def _unity_throng_cell(img, pivot, scale, anchor):
    cell = new(CELL_W, CELL_H)
    if img is None or img.getbbox() is None:
        return cell
    if scale < 0.999:
        img = img.resize((
            max(1, int(round(img.size[0] * scale))),
            max(1, int(round(img.size[1] * scale))),
        ), Image.NEAREST)
    width, height = img.size
    pivot_x = pivot[0] * width
    pivot_y = (1.0 - pivot[1]) * height
    _blit(cell, img, CELL_W * 0.5 - pivot_x, (CELL_H - anchor) - pivot_y)
    return cell


def _blit(base, img, x, y):
    x = int(round(x))
    y = int(round(y))
    src_x = max(0, -x)
    src_y = max(0, -y)
    dest_x = max(0, x)
    dest_y = max(0, y)
    width = min(img.size[0] - src_x, base.size[0] - dest_x)
    height = min(img.size[1] - src_y, base.size[1] - dest_y)
    if width < 1 or height < 1:
        return
    piece = img.crop((src_x, src_y, src_x + width, src_y + height))
    base.alpha_composite(piece, (dest_x, dest_y))


def _stamp_cell(sheet, cols, index, cell):
    sheet.alpha_composite(cell, ((index % cols) * CELL_W, (index // cols) * CELL_H))


def _stamp_throng_anims(sheet, cols):
    clips = _load_throng_clips()
    total = sum(len(frames) for frames in clips.values())
    rows = (THRONG_BASE + total + 160 + cols - 1) // cols
    sheet = _grow_sheet(sheet, cols, rows)
    dirt_sheet = new(sheet.size[0], sheet.size[1])
    reserved = {
        "Throng_Walk_Anim_Spritesheet",
        "Throng_WalkBack_Anim_Spritesheet",
        "ThrongA_Eat",
        "ThrongA_Pickaxe_Spritesheet",
        "Throng_FallInBath_Spritesheet",
        "ThrongA_Roundabout_SpriteSheet",
        "ThrongA_Jump_VariantA_Spritesheet",
        "ThrongA_Mitosis_Spritesheet",
        "ThrongA_Dead_001",
        "ThrongA_Dead_002",
        "ThrongA_Bones",
        "ThrongA_Sad",
    }
    entries = []
    talk = []
    idle = []
    index = THRONG_BASE
    for name in sorted(clips):
        frames = clips[name]
        start = index
        scale, anchor = _throng_fit(frames)
        for frame, dirt, pivot in frames:
            _stamp_cell(sheet, cols, index, _unity_throng_cell(frame, pivot, scale, anchor))
            _stamp_cell(dirt_sheet, cols, index, _unity_throng_cell(dirt, pivot, scale, anchor))
            index += 1
        entries.append((name, start, len(frames)))
        if "Talk" in name:
            talk.append(name)
        elif name not in reserved:
            idle.append(name)
    index = _stamp_loose_clips(sheet, dirt_sheet, cols, index, entries, idle)
    index = _stamp_fx_and_biomes(sheet, cols, index)
    rows = (index + cols - 1) // cols
    sheet = sheet.crop((0, 0, cols * CELL_W, rows * CELL_H))
    dirt_sheet = dirt_sheet.crop((0, 0, cols * CELL_W, rows * CELL_H))
    _write_throng_clips(entries, rows, talk, idle)
    dirt_sheet.save(OUT("resources", "sprites", "world_iso_dirt.png"))
    print("throng clips", len(entries), "frames", total, "rows", rows)
    return sheet


def main():
    make_thronglets()
    make_atlas()
    make_terrain()
    make_frame()
    make_font()
    make_world()
    make_hud()


if __name__ == "__main__":
    main()
