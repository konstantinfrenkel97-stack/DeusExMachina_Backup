# -*- coding: utf-8 -*-
"""
Точный рендер layout боя как в игре (без Camera2D, viewport ~1152x648).
Арт ЦЕНТРИРОВАН на слоте (как Sprite2D.centered=true в combatant_visual.tscn).
Мир-координаты:
  HeroPositions(-220,300): Pos1=400 Pos2=260 Pos3=120 Pos4=-20  (мир X)
  EnemyPositions(-880,300): Pos1=740 Pos2=880 Pos3=1020 Pos4=1160
Сценарий: враги [Циклоп(крупный), Капитан, Матрос, -], герои-заглушки.
"""
import sys, os
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import cv2

# (display, png, is_large, world_slot_x)  -- slot_x = МИРОВАЯ координата X слота
HEROES = [
    ("Герой1", None, False, 400),
    ("Герой2", None, False, 260),
    ("Герой3", None, False, 120),
    ("Герой4", None, False, -20),
]
ENEMIES = [
    ("Циклоп", "Enemies/Sky/Peaks/Cyclopes/Циклоп_nobg.png", True, 740),
    ("-",      None, False, 880),   # слот занят циклопом (2-я клетка)
    ("Капитан", "Enemies/Sea/Ships/Captain/Капитан_nobg.png", False, 1020),
    ("Матрос",  "Enemies/Sea/Ships/Sailor/Матрос_nobg.png",   False, 1160),
]

VW, VH = 1152, 648
SLOT_Y = 300
GROUND = SLOT_Y  # арт центрирован на слоте (как в игре)


def load(p):
    return cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_UNCHANGED)


def place(canvas, rgba, center_x, is_large):
    if rgba is None:
        return
    h, w = rgba.shape[:2]
    tw, th = (240, 360) if is_large else (120, 180)
    s = min(tw / w, th / h)
    nw, nh = int(round(w * s)), int(round(h * s))
    img = cv2.resize(rgba, (nw, nh), interpolation=cv2.INTER_AREA)
    x = int(center_x - nw / 2)          # ЦЕНТР арта на слоте
    y = int(GROUND - nh / 2)            # вертикально по центру слота (как Sprite2D.centered)
    bgr = img[:, :, :3]
    a = (img[:, :, 3:4].astype(np.float32) / 255.0)
    y0, y1 = max(0, y), min(VH, y + nh)
    x0, x1 = max(0, x), min(VW, x + nw)
    sy0, sy1 = y0 - y, y1 - y
    sx0, sx1 = x0 - x, x1 - x
    roi = canvas[y0:y1, x0:x1]
    canvas[y0:y1, x0:x1] = (bgr[sy0:sy1, sx0:sx1].astype(np.float32) * a[sy0:sy1, sx0:sx1]
                            + roi.astype(np.float32) * (1 - a[sy0:sy1, sx0:sx1])).astype(np.uint8)
    # рамка арта
    cv2.rectangle(canvas, (x, y), (x + nw, y + nh), (0, 200, 0) if is_large else (200, 160, 0), 1)
    # HP-бар под артом
    bw = 260 if is_large else 130
    bx = int(center_x - bw / 2)
    by = y + nh + 4
    cv2.rectangle(canvas, (bx, by), (bx + bw, by + 12), (40, 40, 40), -1)
    cv2.rectangle(canvas, (bx, by), (bx + bw, by + 12), (90, 90, 90), 1)


canvas = np.full((VH, VW, 3), 30, np.uint8)

# линия пола
cv2.line(canvas, (0, GROUND), (VW, GROUND), (90, 70, 50), 1)

# маркеры слотов врагов/героев
for label, x in [("Hero1", 400), ("Hero2", 260), ("Hero3", 120), ("Hero4", -20)]:
    if 0 <= x < VW:
        cv2.line(canvas, (x, 0), (x, VH), (50, 60, 50), 1)
        cv2.putText(canvas, label, (x - 22, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (90, 120, 90), 1)
for label, x in [("Enemy1", 740), ("Enemy2", 880), ("Enemy3", 1020), ("Enemy4", 1160)]:
    if 0 <= x < VW:
        cv2.line(canvas, (x, 0), (x, VH), (60, 50, 50), 1)
        cv2.putText(canvas, label, (x - 24, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (120, 90, 90), 1)

# герои-заглушки (квадрат)
for name, p, large, x in HEROES:
    cv2.rectangle(canvas, (x - 40, GROUND - 90), (x + 40, GROUND + 90), (60, 80, 120), -1)
    cv2.putText(canvas, name, (x - 28, GROUND), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (180, 180, 220), 1)

# враги: циклоп центрирован между Enemy1 и Enemy2 (+70), обычные — на своём слоте
for name, p, large, x in ENEMIES:
    if p is None:
        continue
    cx = x + (70 if large else 0)   # крупный сдвинут к центру 2 клеток
    rgba = load(p)
    place(canvas, rgba, cx, large)
    cv2.putText(canvas, name, (int(cx) - 24, GROUND - 110),
                cv2.FONT_HERSHEY_SIMPLEX, 0.45, (180, 220, 180) if large else (220, 200, 160), 1)

ok, buf = cv2.imencode(".png", canvas)
if ok:
    with open("_battle_preview.png", "wb") as fh:
        fh.write(buf.tobytes())
    print("Сохранено _battle_preview.png (%dx%d). Арт ЦЕНТРИРОВАН на слоте как в игре." % (VW, VH))
print()
print("Циклоп(крупный): центр между Enemy1(740) и Enemy2(880) = 810, арт 201px -> [709,911]")
print("Капитан:         слот Enemy3(1020), арт ~%dpx" % int(round(120 if False else 0)) or "?")
