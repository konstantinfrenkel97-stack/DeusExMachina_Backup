# -*- coding: utf-8 -*-
"""
Диагностика проблемы №3: арт крупного юнита «наезжает на первую позицию».
Читает sprite_path из .tres, грузит РЕАЛЬНЫЙ PNG (после crop_alpha),
считает геометрию как в бою и сообщает, куда попадают края арта
относительно слотов врагов.
"""
import sys, os, re
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import cv2

# Слоты врагов: локальные X внутри EnemyPositions (узел сдвинут на -880,300).
# В коде позиция = Marker2D local position: 1620,1760,1900,2040.
SLOT_LOCAL = [1620, 1760, 1900, 2040]
STEP = 140


def read_tres(path):
    d = {}
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r"\s*(\w+)\s*=\s*(.*)$", line)
            if m:
                d[m.group(1)] = m.group(2).strip()
    return d


def load_size(path):
    im = cv2.imdecode(np.fromfile(path, dtype=np.uint8), cv2.IMREAD_UNCHANGED)
    if im is None:
        return None
    return im.shape  # (h, w, c) or (h,w)


# Все враги с is_large=true (известные)
LARGE_UNITS = [
    ("Циклоп",      "Enemies/Sky/Peaks/Cyclopes/cyclops.tres",                "Enemies/Sky/Peaks/Cyclopes/Циклоп_nobg.png"),
    ("Атакующий титан", "Enemies/Sky/Peaks/Attacking_titan/attacking_titan.tres", None),
    ("Бронированный титан", "Enemies/Sky/Peaks/Armored_titan/armored_titan.tres", None),
    ("Йотун",       "Enemies/Dungeon/Hellheim/Jotun/jotun.tres",              "Enemies/Dungeon/Hellheim/Jotun/Йотун_nobg.png"),
    ("Пушка",       "Enemies/Sea/Ships/Cannon/cannon.tres",                   "Enemies/Sea/Ships/Cannon/ПУшка_nobg.png"),
    ("Кирин",       "Enemies/Sea/Islands/Kirin/kirin.tres",                   "Enemies/Sea/Islands/Kirin/Кирин_nobg.png"),
]

print("=" * 78)
print("ПРОВЕРКА is_large И РАЗМЕРЫ ТЕКСТУР")
print("=" * 78)
for name, tres, png in LARGE_UNITS:
    if not os.path.exists(tres):
        print("[!] нет .tres:", tres)
        continue
    d = read_tres(tres)
    is_large = d.get("is_large", "false")
    sp = d.get("sprite_path", "")
    # определим png: из sprite_path если есть, иначе заданный (убираем res://)
    tex_path = (sp.strip('"').replace("res://", "") if sp else png)
    print("\n%-20s is_large=%-6s sprite_path=%s" % (name, is_large, tex_path))
    if tex_path and os.path.exists(tex_path):
        shp = load_size(tex_path)
        if shp:
            h, w = shp[0], shp[1]
            tw, th = 240, 360
            s = min(tw / w, th / h)
            nw, nh = int(round(w * s)), int(round(h * s))
            print("    tex=%dx%d  -> крупный масштаб %.3f = %dx%dpx" % (w, h, s, nw, nh))
            # геометрия: крупный в слотах (0,1), центр между ними
            cx = SLOT_LOCAL[0] + STEP // 2     # Pos1 + 70 = 1690
            x0, x1 = cx - nw // 2, cx + nw // 2
            print("    при размещении в слотах Pos1+Pos2 (центр=%d): арт [%d,%d]" % (cx, x0, x1))
            print("    Pos1=%d  Pos2=%d  =>  выступ СЛЕВА за Pos1: %dpx, СПРАВА за Pos2: %dpx"
                  % (SLOT_LOCAL[0], SLOT_LOCAL[1],
                     SLOT_LOCAL[0] - x0, x1 - SLOT_LOCAL[1]))
        else:
            print("    [!] не удалось декодировать PNG")
    else:
        print("    [!] нет PNG файла (sprite_path не ведёт к _nobg.png)")

print()
print("=" * 78)
print("ПРОВЕРКА КЭША .import (source_file / был ли реимпорт после crop_alpha)")
print("=" * 78)
imp = "Enemies/Sky/Peaks/Cyclopes/Циклоп_nobg.png.import"
if os.path.exists(imp):
    with open(imp, "r", encoding="utf-8") as fh:
        txt = fh.read()
    import os as _os
    png_mtime = _os.path.getmtime("Enemies/Sky/Peaks/Cyclopes/Циклоп_nobg.png")
    imp_mtime = _os.path.getmtime(imp)
    print("png   mtime: %s" % png_mtime)
    print(".import mtime: %s  (%s)"
          % (imp_mtime, "PNG новее -> нужен реимпорт!" if png_mtime > imp_mtime else "ок"))
else:
    print("нет .import файла")
