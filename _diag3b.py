# -*- coding: utf-8 -*-
"""
Проверка центрирования персонажа внутри текстуры (по альфа-каналу)
для крупных юнитов. Если бокс по альфе смещён относительно центра
изображения — арт будет визуально сдвинут в игре.
Также: перерисовывает _battle_preview.png текущими файлами с диска.
"""
import sys, os
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import cv2

SLOT_LOCAL = [1620, 1760, 1900, 2040]
STEP = 140

UNITS = [
    ("Циклоп", "Enemies/Sky/Peaks/Cyclopes/Циклоп_nobg.png", True),
    ("Йотун", "Enemies/Dungeon/Hellheim/Jotun/Йотун_nobg.png", True),
    ("Пушка", "Enemies/Sea/Ships/Cannon/ПУшка_nobg.png", True),
    ("Кирин", "Enemies/Sea/Islands/Kirin/Кирин_nobg.png", True),
    ("Капитан", "Enemies/Sea/Ships/Captain/Капитан_nobg.png", False),
    ("Матрос", "Enemies/Sea/Ships/Sailor/Матрос_nobg.png", False),
]


def alpha_bbox(p, thresh=10):
    im = cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_UNCHANGED)
    if im is None:
        return None
    h, w = im.shape[:2]
    if im.ndim == 3 and im.shape[2] == 4:
        a = im[:, :, 3]
    else:
        a = im
    ys, xs = np.where(a > thresh)
    if xs.size == 0:
        return im.shape, (0, 0, 0, 0), (0, 0)
    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())
    char_cx = (x0 + x1) / 2.0
    char_cy = (y0 + y1) / 2.0
    img_cx, img_cy = w / 2.0, h / 2.0
    return im.shape, (x0, x1, y0, y1), (char_cx - img_cx, char_cy - img_cy)


print("=" * 80)
print("ЦЕНТРИРОВАНИЕ ПЕРСОНАЖА В ТЕКСТУРЕ (сдвиг бокса-альфы от центра изображения)")
print("  Если |dx| или |dy| велики — персонаж не по центру -> арт будет смещён.")
print("=" * 80)
for name, p, is_large in UNITS:
    if not os.path.exists(p):
        print("%-10s НЕТ ФАЙЛА %s" % (name, p))
        continue
    res = alpha_bbox(p)
    if res is None:
        print("%-10s не декодируется" % name)
        continue
    shp, (x0, x1, y0, y1), (dx, dy) = res
    h, w = shp[0], shp[1]
    tw, th = (240, 360) if is_large else (120, 180)
    s = min(tw / w, th / h)
    # сдвиг в пикселях ИГРОВОГО масштаба
    gdx, gdy = dx * s, dy * s
    flag = "  <-- СДВИГ!" if (abs(gdx) > 20 or abs(gdy) > 20) else ""
    print("%-10s img=%dx%d  альфа-бокс=[%d,%d,%d,%d]  dx=%+5.1f dy=%+5.1f  "
          "в масштабе игры: %+5.1f,%+5.1f px%s"
          % (name, w, h, x0, x1, y0, y1, dx, dy, gdx, gdy, flag))
