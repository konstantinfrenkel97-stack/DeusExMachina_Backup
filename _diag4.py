# -*- coding: utf-8 -*-
# Эмпирическая проверка: где реально окажется арт крупного врага,
# если использовать ТОТ ЖЕ масштаб-формулу, что и в combatant_visual.gd setup().
# Также проверяем свежесть .import-кеша Godot.
import os, sys
import numpy as np
import cv2

ROOT = os.path.dirname(os.path.abspath(__file__))

def read_png(p):
    arr = np.fromfile(p, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_UNCHANGED)
    return img

def alpha_bbox(img):
    if img is None:
        return None
    if img.ndim == 2:
        a = img
    else:
        a = img[:, :, 3]
    ys, xs = np.where(a > 10)
    if len(xs) == 0:
        return None
    return xs.min(), xs.max(), ys.min(), ys.max()

def godot_scale(tex_w, tex_h, target):
    return min(target[0] / tex_w, target[1] / tex_h)

# --- Циклоп (крупный) ---
cyc_png = os.path.join(ROOT, "Enemies", "Sky", "Peaks", "Cyclopes", "Циклоп_nobg.png")
cyc_imp = cyc_png + ".import"
print("=== Циклоп (крупный) ===")
img = read_png(cyc_png)
if img is None:
    print("NO IMAGE:", cyc_png); sys.exit()
h, w = img.shape[:2]
print("texture px: %dx%d" % (w, h))
bb = alpha_bbox(img)
print("alpha bbox  x:[%d..%d] y:[%d..%d]" % bb)
content_w = bb[1] - bb[0] + 1
content_center_x = (bb[0] + bb[1]) / 2.0
offset_from_tex_center = content_center_x - w / 2.0
print("content width=%d  content_center_offset_from_tex_center=%.1f px (в пикселях текстуры)" % (content_w, offset_from_tex_center))

scale = godot_scale(w, h, (240, 360))
print("godot scale = %.4f  (target 240x360)" % scale)
rendered_w = w * scale
rendered_content_w = content_w * scale
rendered_offset = offset_from_tex_center * scale
print("rendered full texture width = %.1f px" % rendered_w)
print("rendered content width = %.1f px" % rendered_content_w)
print("rendered content center offset from sprite-center = %.1f px (минус = контент сдвинут ВЛЕВО)" % rendered_offset)

# свежесть .import
if os.path.exists(cyc_imp):
    mt_png = os.path.getmtime(cyc_png)
    mt_imp = os.path.getmtime(cyc_imp)
    stale = mt_png > mt_imp
    print(".import cache: png_mtime=%.0f import_mtime=%.0f  STALE=%s" % (mt_png, mt_imp, stale))
else:
    print("NO .import file for cyclops")

# --- Сценарий [маленький @ Pos1, крупный @ Pos2+70] ---
# Координаты мира (как в battle_scene.tscn):
# EnemyPositions(-880,300); Pos1 local 1620 -> world 740; Pos2 local 1760 -> world 880.
POS1_X = 740
POS2_X = 880
LARGE_X = POS2_X + 70   # = 950 (центр между Pos2 и Pos3)

print("\n=== Раскладка [маленький@Pos1, крупный@Pos2+70] ===")
print("small center world_x = %d" % POS1_X)
print("large center world_x = %d" % LARGE_X)

# арт крупного: текстура отцентрирована (centered=true) на sprite-center = LARGE_X
# левая граница видимого контента:
large_left = LARGE_X + rendered_offset - rendered_content_w / 2.0
large_right = LARGE_X + rendered_offset + rendered_content_w / 2.0
print("large VISIBLE content spans x:[%.0f .. %.0f]" % (large_left, large_right))

# маленький: примем арт ~120px, контент по центру
SMALL_W = 120.0
small_left = POS1_X - SMALL_W / 2.0
small_right = POS1_X + SMALL_W / 2.0
print("small art spans x:[%.0f .. %.0f] (ширина ~120)" % (small_left, small_right))

gap = large_left - small_right
print("GAP (large_left - small_right) = %.1f px  -> %s" % (gap, "НАЛОЖЕНИЕ" if gap < 0 else "зазор OK"))

# --- Рендер на холст ---
canvas_w = 1400
canvas_h = 520
canvas = np.zeros((canvas_h, canvas_w, 4), dtype=np.uint8)

def place_art(canvas, img, scale, center_x, center_y):
    th, tw = img.shape[:2]
    nw = int(round(tw * scale))
    nh = int(round(th * scale))
    small = cv2.resize(img, (nw, nh), interpolation=cv2.INTER_AREA)
    # centered=true: центр текстуры -> (center_x, center_y)
    x0 = int(round(center_x - nw / 2.0))
    y0 = int(round(center_y - nh / 2.0))
    H, W = canvas.shape[:2]
    for yy in range(nh):
        cy = y0 + yy
        if cy < 0 or cy >= H:
            continue
        for xx in range(nw):
            cx = x0 + xx
            if cx < 0 or cx >= W:
                continue
            a = small[yy, xx, 3] / 255.0
            if a <= 0:
                continue
            for c in range(3):
                canvas[cy, cx, c] = int(small[yy, xx, c] * a + canvas[cy, cx, c] * (1 - a))
            canvas[cy, cx, 3] = 255

# маркеры позиций (зелёные линии)
for (px, name) in [(740, "Pos1"), (880, "Pos2"), (1020, "Pos3"), (1160, "Pos4")]:
    for yy in range(0, canvas_h):
        canvas[yy, px, 0] = 0
        canvas[yy, px, 1] = 255
        canvas[yy, px, 2] = 0
        canvas[yy, px, 3] = 255

# крупный @ LARGE_X (=950)
place_art(canvas, img, scale, LARGE_X, 330)
# маленький-заглушка @ POS1 (=740): красный прямоугольник 120x180
sx0 = int(POS1_X - 60); sy0 = int(330 - 90)
cv2.rectangle(canvas, (sx0, sy0), (sx0 + 120, sy0 + 180), (0, 0, 255, 255), 2)

out = os.path.join(ROOT, "_diag4_layout.png")
arr = cv2.imencode(".png", canvas)[1]
arr.tofile(out)
print("\nsaved render ->", out)
