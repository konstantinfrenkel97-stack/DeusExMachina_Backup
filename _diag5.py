# -*- coding: utf-8 -*-
# Анализ ВСЕХ крупных юнитов: где реально окажется ВИДИМЫЙ контент,
# если Area2D стоит на (950, 300) [Pos2+70], centered=true.
# Также вертикаль: где низ/верх контента, чтобы понять "ниже маленьких".
import os, glob, sys
import numpy as np
import cv2
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

ROOT = os.path.dirname(os.path.abspath(__file__))

def read_png(p):
    arr = np.fromfile(p, dtype=np.uint8)
    return cv2.imdecode(arr, cv2.IMREAD_UNCHANGED)

def alpha_bbox(img):
    a = img[:, :, 3] if img.ndim == 3 else img
    ys, xs = np.where(a > 10)
    if len(xs) == 0:
        return None
    return xs.min(), xs.max(), ys.min(), ys.max()

# Сценарий: маленький на Pos1 (world 740), арт ~120px -> правая граница 800
SMALL_RIGHT = 800.0
AREA_X = 950.0   # Pos2 + 70
AREA_Y = 300.0

print("%-22s %7s %7s %8s %8s %8s %10s %10s %8s" % (
    "unit", "texW", "texH", "cntW", "cntH", "scale",
    "cnt_left_x", "cnt_top_y", "overlap?"))
print("-" * 100)

rows = []
for tres in glob.glob(os.path.join(ROOT, "Enemies", "**", "*.tres"), recursive=True):
    with open(tres, "r", encoding="utf-8") as f:
        txt = f.read()
    if "is_large = true" not in txt:
        continue
    # имя
    uname = "?"
    spath = None
    for line in txt.splitlines():
        s = line.strip()
        if s.startswith("unit_name"):
            uname = s.split("=",1)[1].strip().strip('"')
        if s.startswith("sprite_path"):
            spath = s.split("=",1)[1].strip().strip('"').replace("res://","")
    if not spath:
        continue
    p = os.path.join(ROOT, spath)
    if not os.path.exists(p):
        print("%-22s  NO FILE %s" % (uname, spath))
        continue
    img = read_png(p)
    if img is None:
        print("%-22s  NO IMG" % uname); continue
    h, w = img.shape[:2]
    bb = alpha_bbox(img)
    if bb is None:
        print("%-22s  EMPTY ALPHA" % uname); continue
    x0,x1,y0,y1 = bb
    cnt_w = x1 - x0 + 1
    cnt_h = y1 - y0 + 1
    scale = min(240.0/w, 360.0/h)
    # смещение центра контента относительно центра текстуры (в текст. пикселях)
    cx_off = (x0 + x1)/2.0 - w/2.0
    cy_off = (y0 + y1)/2.0 - h/2.0
    # в масштабе рендера, относительно центра спрайта (=AREA_X, AREA_Y)
    cx_off_s = cx_off * scale
    cy_off_s = cy_off * scale
    cnt_left_x = AREA_X + cx_off_s - (cnt_w*scale)/2.0
    cnt_right_x = AREA_X + cx_off_s + (cnt_w*scale)/2.0
    cnt_top_y = AREA_Y + cy_off_s - (cnt_h*scale)/2.0
    cnt_bot_y = AREA_Y + cy_off_s + (cnt_h*scale)/2.0
    overlap = cnt_left_x < SMALL_RIGHT
    print("%-22s %7d %7d %8.0f %8.0f %8.3f %10.0f %10.0f %8s" % (
        uname, w, h, cnt_w, cnt_h, scale, cnt_left_x, cnt_top_y, "YES!!" if overlap else "no"))
    rows.append((uname, w, h, cnt_w, cnt_h, scale, cx_off_s, cy_off_s, cnt_left_x, cnt_right_x, cnt_top_y, cnt_bot_y))

print()
print("=== Детально (мир: Pos1=740 Pos2=880 Pos3=1020; small арт правая граница=800) ===")
for r in rows:
    uname,w,h,cnt_w,cnt_h,scale,cx_off_s,cy_off_s,cl,cr,ct,cb = r
    print("%-12s tex=%dx%d cnt=%dx%d scale=%.3f" % (uname,w,h,cnt_w,cnt_h,scale))
    print("             контент центр смещён: dx=%.1fpx dy=%.1fpx от центра спрайта" % (cx_off_s, cy_off_s))
    print("             контент X:[%.0f..%.0f]  Y:[%.0f..%.0f]  (world)" % (cl,cr,ct,cb))
    print("             малый правая граница=800 -> %s" % ("НАЛОЖЕНИЕ" if cl<800 else "зазор %.0fpx" % (cl-800)))
