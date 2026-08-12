# -*- coding: utf-8 -*-
import sys, os
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np, cv2

S = [1620, 1760, 1900, 2040]
OFFS = -1540
STEP = 140

scen = [
    ("Циклоп (крупный)", "Enemies/Sky/Peaks/Cyclopes/Циклоп_nobg.png", True, 0),
    ("Капитан",          "Enemies/Sea/Ships/Captain/Капитан_nobg.png", False, 2),
    ("Матрос",           "Enemies/Sea/Ships/Sailor/Матрос_nobg.png",   False, 3),
]
boxes = []
for name, p, large, slot in scen:
    im = cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_UNCHANGED)
    h, w = im.shape[:2]
    tw, th = (240, 360) if large else (120, 180)
    s = min(tw / w, th / h)
    nw, nh = int(round(w * s)), int(round(h * s))
    cx = S[slot] + OFFS + (STEP // 2 if large else 0)
    x0, x1 = cx - nw // 2, cx + nw // 2
    print("%-18s tex=%dx%d -> %dx%dpx  center=%d  xrange=[%d,%d]" % (name, w, h, nw, nh, cx, x0, x1))
    boxes.append((name, x0, x1))

print()
for i in range(len(boxes) - 1):
    a, b = boxes[i], boxes[i + 1]
    gap = b[1] - a[2]
    status = "НАЕЗД!" if gap < 0 else "OK"
    print("%-14s правый=%-4d | %-12s левый=%-4d -> зазор=%dpx %s" % (a[0], a[2], b[0], b[1], gap, status))

print()
print("Слоты (canvas X): Pos1=80 Pos2=220 Pos3=360 Pos4=500  (шаг 140)")
for name, x0, x1, *_ in boxes:
    occ = ["Pos%d" % (k + 1) for k in range(4) if x0 <= S[k] + OFFS <= x1]
    print("%-18s занимает клетки: %s" % (name, occ))
