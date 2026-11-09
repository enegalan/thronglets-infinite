#!/usr/bin/env python3
"""Pixel art for Thronglets: Infinite. Original drawings, not Netflix assets."""

import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = lambda *parts: os.path.join(ROOT, *parts)

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


def draw_thronglet(img, col, row, kind, frame):
    ox, oy = col * 16, row * 16
    bob = (0, -1, 0, 1)[frame % 4]
    body = (244, 244, 236, 255)
    pupil = (28, 18, 12, 255)
    if kind == "corpse":
        body = (168, 164, 150, 255)
        bob = 0
    rx, ry = 5.4, 6.0
    cx, cy = 8.0, 8.2 + bob
    if kind == "mitosis":
        if frame >= 2:
            ellipse(img, ox, oy, 5.0, cy, 3.3, 4.4, body)
            ellipse(img, ox, oy, 11.0, cy, 3.3, 4.4, body)
            _face(img, ox, oy, 5.0, cy - 0.8, pupil, "south")
            _face(img, ox, oy, 11.0, cy - 0.8, pupil, "south")
            outline_cell(img, ox, oy)
            return
        rx = 6.6 if frame == 1 else 5.4
    if kind == "stare":
        rx, ry = 6.3, 5.8
        cy = 8.2
    ellipse(img, ox, oy, cx, cy + 0.4, rx, ry, body)
    facing = kind if kind in ("south", "east", "west", "stare", "corpse") else "south"
    if kind == "sick":
        facing = "south"
        px(img, ox + 4, oy + 11, (92, 42, 140, 255))
        px(img, ox + 11, oy + 10, (92, 42, 140, 255))
    px(img, ox + int(cx) - 1, oy + int(cy) - 4, (255, 255, 255, 255))
    _face(img, ox, oy, cx, cy - 0.4, pupil, facing)
    outline_cell(img, ox, oy)
    for sx in range(4, 12):
        px(img, ox + sx, oy + 15, (36, 44, 28, 170))


def _face(img, ox, oy, cx, cy, pupil, facing):
    if facing == "corpse":
        for d in range(2):
            px(img, ox + int(cx) - 3 + d, oy + int(cy) + d, pupil)
            px(img, ox + int(cx) - 2 - d, oy + int(cy) + d, pupil)
            px(img, ox + int(cx) + 1 + d, oy + int(cy) + d, pupil)
            px(img, ox + int(cx) + 2 - d, oy + int(cy) + d, pupil)
        return
    shift = 2 if facing == "east" else -2 if facing == "west" else 0
    span = 3 if facing == "stare" else 2
    lx = int(cx) - span + shift
    rx = int(cx) + 1 + shift
    py = int(cy)
    px(img, ox + lx, oy + py, pupil)
    px(img, ox + lx + 1, oy + py, pupil)
    px(img, ox + rx, oy + py, pupil)
    px(img, ox + rx + 1, oy + py, pupil)
    px(img, ox + int(cx) + shift, oy + py + 3, (120, 64, 36, 255))


def make_thronglets():
    img = new(64, 96)
    facings = ("south", "north", "east", "west")
    for row, facing in enumerate(facings):
        for frame in range(4):
            draw_thronglet(img, frame, row, facing, frame)
    for frame in range(4):
        draw_thronglet(img, frame, 4, "mitosis", frame)
    draw_thronglet(img, 0, 5, "stare", 0)
    draw_thronglet(img, 1, 5, "corpse", 0)
    draw_thronglet(img, 2, 5, "sick", 0)
    draw_thronglet(img, 3, 5, "south", 0)
    img.save(OUT("resources", "sprites", "thronglet_spritesheet.png"))


def icon(index):
    img = new(16, 16)
    draw_icon(img, 0, 0, index)
    return img


def blit_icon(sheet, index, cols):
    tile = new(16, 16)
    draw_icon(tile, 0, 0, index)
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
    elif index == 1:  # ball
        box(4, 4, 8, 8, RED)
        box(7, 4, 2, 8, W)
        box(4, 7, 8, 2, W)
        p(5, 5, RED)
        p(10, 10, RED)
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


def make_atlas():
    cols = 32
    rows = 2
    sheet = new(cols * 16, rows * 16)
    for i in range(40):
        blit_icon(sheet, i, cols)
    sheet.save(OUT("resources", "structures", "structures_tileset.png"))
    icons = new(64, 16)
    for i, src in enumerate((0, 12, 13, 28)):
        tile = new(16, 16)
        draw_icon(tile, 0, 0, src)
        icons.alpha_composite(tile, (i * 16, 0))
    icons.save(OUT("resources", "ui", "ui_icons.png"))


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


def make_terrain():
    blocks = (
        ((150, 164, 72, 255), (190, 196, 104, 255), (112, 128, 54, 255), (74, 58, 38, 255), (122, 96, 58, 255)),
        ((168, 132, 78, 255), (196, 164, 112, 255), (132, 100, 58, 255), (70, 52, 34, 255), (112, 84, 50, 255)),
        ((78, 150, 188, 255), (150, 198, 220, 255), (46, 108, 150, 255), (28, 64, 96, 255), (52, 102, 140, 255)),
        ((150, 148, 140, 255), (190, 188, 180, 255), (110, 108, 102, 255), (62, 60, 58, 255), (96, 94, 90, 255)),
        ((128, 116, 104, 255), (160, 148, 132, 255), (90, 80, 70, 255), (54, 48, 42, 255), (84, 74, 64, 255)),
        ((132, 64, 160, 255), (170, 110, 190, 255), (90, 36, 110, 255), (48, 28, 64, 255), (80, 48, 100, 255)),
        ((156, 112, 64, 255), (186, 142, 86, 255), (112, 78, 42, 255), (70, 48, 30, 255), (110, 76, 46, 255)),
        ((210, 204, 184, 255), (230, 226, 210, 255), (170, 162, 146, 255), (120, 112, 98, 255), (160, 150, 132, 255)),
        ((0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0)),
        ((132, 170, 70, 255), (176, 200, 104, 255), (96, 132, 52, 255), (70, 56, 36, 255), (114, 90, 54, 255)),
    )
    img = new(32 * 10, 32)
    for i, colors in enumerate(blocks):
        if i == 8:
            continue
        paint_block(img, i * 32, colors[0], colors[1], colors[2], colors[3], colors[4])
        if i == 3:
            _peak(img, i * 32, (186, 184, 176, 255), (96, 94, 90, 255))
    img.save(OUT("resources", "tiles", "terrain_tileset.png"))
    make_space()


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


def make_big():
    cols, rows = 8, 3
    sheet = new(cols * 32, rows * 32)
    for index in range(20):
        tile = new(32, 32)
        draw_big(tile, index)
        sheet.alpha_composite(tile, ((index % cols) * 32, (index // cols) * 32))
    sheet.save(OUT("resources", "structures", "buildings_32.png"))


def draw_big(img, index):
    G = (52, 140, 48, 255)
    GD = (28, 96, 32, 255)
    BR = (128, 78, 40, 255)
    WALL = (214, 168, 122, 255)
    ROOF = (176, 64, 52, 255)
    ROOFD = (120, 36, 32, 255)
    WIN = (120, 176, 210, 255)
    STONE = (110, 108, 104, 255)
    PUR = (110, 48, 150, 255)
    INK = (42, 32, 28, 255)
    GOLD = (220, 170, 64, 255)
    if index in (0, 5):
        rect(img, 15, 18, 3, 7, (96, 64, 36, 255))
        ellipse(img, 0, 0, 16, 13, 12, 9, (72, 108, 46, 255), 32)
        ellipse(img, 0, 0, 16, 12, 10, 8, (138, 176, 74, 255), 32)
        px(img, 12, 10, (186, 206, 110, 255))
        if index == 5:
            px(img, 12, 10, (196, 42, 40, 255))
            px(img, 18, 8, (196, 42, 40, 255))
            px(img, 16, 14, (210, 60, 48, 255))
            px(img, 10, 14, (210, 60, 48, 255))
    elif index in (1, 2):
        ellipse(img, 0, 0, 16, 18, 10, 7, (80, 78, 74, 255), 32)
        ellipse(img, 0, 0, 16, 16, 9, 6, STONE, 32)
        px(img, 12, 14, (230, 230, 220, 255))
        if index == 2:
            px(img, 18, 15, GOLD)
            px(img, 14, 18, GOLD)
    elif index in (3, 4):
        ellipse(img, 0, 0, 16, 20, 8, 5, (70, 60, 40, 255), 32)
        rect(img, 14, 6, 4, 14, GOLD if index == 4 else (230, 210, 90, 255))
        rect(img, 12, 12, 8, 6, (255, 244, 180, 255))
    elif index == 6:
        rect(img, 6, 14, 20, 10, (236, 236, 232, 255))
        rect(img, 8, 16, 16, 6, (90, 150, 200, 255))
        rect(img, 6, 12, 4, 6, STONE)
        rect(img, 22, 12, 4, 6, STONE)
    elif index == 7:
        rect(img, 14, 14, 4, 12, GOLD)
        ellipse(img, 0, 0, 16, 12, 12, 6, ROOF, 32)
        px(img, 10, 11, GOLD)
        px(img, 20, 11, GOLD)
    elif index in (8, 9, 16):
        roof = GOLD if index == 9 else (90, 48, 40, 255) if index == 16 else ROOF
        rect(img, 6, 16, 20, 12, WALL)
        rect(img, 4, 8, 24, 12, roof)
        rect(img, 8, 6, 16, 6, ROOFD if index != 9 else (180, 130, 40, 255))
        rect(img, 8, 20, 4, 4, WIN)
        rect(img, 20, 20, 4, 4, WIN)
        rect(img, 14, 20, 4, 8, BR)
        if index == 9:
            rect(img, 22, 4, 3, 8, STONE)
    elif index in (10, 11):
        rect(img, 4, 12, 24, 16, (88, 84, 78, 255))
        rect(img, 10, 16, 12, 12, INK)
        rect(img, 6, 10, 20, 4, BR)
        px(img, 14, 20, GOLD)
        if index == 11:
            rect(img, 8, 6, 6, 6, GOLD)
    elif index in (12, 13):
        rect(img, 4, 14, 24, 14, (90, 88, 96, 255))
        rect(img, 8, 4, 6, 12, (60, 58, 66, 255))
        rect(img, 10, 8, 2, 4, PUR)
        rect(img, 18, 18, 6, 6, (80, 140, 180, 255))
        if index == 13:
            rect(img, 18, 4, 6, 12, (60, 58, 66, 255))
            rect(img, 20, 8, 2, 4, PUR)
    elif index == 14:
        rect(img, 4, 10, 24, 18, (120, 42, 48, 255))
        rect(img, 8, 14, 6, 12, ROOF)
        rect(img, 18, 14, 6, 12, ROOF)
        rect(img, 14, 16, 4, 10, GOLD)
    elif index == 15:
        rect(img, 6, 20, 20, 6, (50, 48, 46, 255))
        rect(img, 8, 12, 14, 8, STONE)
        rect(img, 16, 4, 6, 10, (70, 68, 66, 255))
    elif index == 17:
        rect(img, 12, 4, 8, 24, INK)
        rect(img, 14, 10, 4, 4, (240, 236, 220, 255))
        px(img, 15, 16, PUR)
    elif index == 18:
        rect(img, 8, 22, 16, 4, STONE)
        rect(img, 12, 12, 8, 10, (230, 214, 180, 255))
        ellipse(img, 0, 0, 16, 10, 5, 5, (230, 214, 180, 255), 32)
        px(img, 14, 9, INK)
        px(img, 18, 9, INK)
    elif index == 19:
        rect(img, 6, 18, 20, 8, (70, 40, 90, 255))
        ellipse(img, 0, 0, 16, 14, 8, 5, (150, 70, 190, 255), 32)


def make_world():
    cols, rows = 16, 6
    sheet = new(cols * 32, rows * 32)
    blobs = Image.open(OUT("resources", "sprites", "thronglet_spritesheet.png"))
    for index in range(24):
        tile = blobs.crop(( (index % 4) * 16, (index // 4) * 16, (index % 4) * 16 + 16, (index // 4) * 16 + 16))
        sheet.alpha_composite(tile, ((index % cols) * 32 + 8, (index // cols) * 32 + 16))
    for icon in range(40):
        index = 24 + icon
        tile = new(16, 16)
        draw_icon(tile, 0, 0, icon)
        sheet.alpha_composite(tile, ((index % cols) * 32 + 8, (index // cols) * 32 + 16))
    for big in range(20):
        index = 64 + big
        tile = new(32, 32)
        draw_big(tile, big)
        sheet.alpha_composite(tile, ((index % cols) * 32, (index // cols) * 32))
    sheet.save(OUT("resources", "sprites", "world_iso.png"))


def make_hud():
    ring = new(40, 40)
    for y in range(40):
        for x in range(40):
            d = ((x - 19.5) ** 2 + (y - 19.5) ** 2) ** 0.5
            if d <= 18.5:
                color = (92, 58, 28, 255) if d >= 15.0 else (244, 228, 196, 255)
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


def main():
    make_thronglets()
    make_atlas()
    make_terrain()
    make_frame()
    make_font()
    make_big()
    make_world()
    make_hud()


if __name__ == "__main__":
    main()
