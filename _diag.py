# -*- coding: utf-8 -*-
"""
Диагностика: насколько flood-fill «съел» персонажа.
Для каждой картинки: 
  orig_fg  = доля пикселей, далёких по цвету от фона (оценка реального персонажа)
  nobg_fg  = доля непрозрачных пикселей в _nobg.png
Если orig_fg >> nobg_fg  => flood-fill пере-удалил персонажа.
"""
import sys, os, glob, json
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import cv2

with open("_nobg_map.json", encoding="utf-8") as f:
    m = json.load(f)

def read_bgr(p):
    return cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_COLOR)

def read_bgra(p):
    return cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_UNCHANGED)

print(f"{'image':28} {'orig_fg':>8} {'nobg_fg':>8} {'ratio':>6}  verdict")
print("-" * 70)
for orig, nobg in m.items():
    bgr = read_bgr(orig)
    rgba = read_bgra(nobg)
    if bgr is None or rgba is None:
        print(f"{os.path.basename(orig):28} READ FAIL"); continue
    h, w = bgr.shape[:2]
    # фон = медиана по кольцу рамки
    ring = np.concatenate([
        bgr[0, :], bgr[-1, :], bgr[:, 0], bgr[:, -1]
    ]).reshape(-1, 3)
    bg = np.median(ring, axis=0)
    # дистанция каждого пикселя до фона (по макс каналу)
    d = np.max(np.abs(bgr.astype(int) - bg.astype(int)), axis=2)
    orig_fg = float((d > 15).mean())   # персонаж ~ далёкие от фона
    # что осталось в _nobg
    if rgba.shape[2] == 4:
        alpha = rgba[:, :, 3]
    else:
        alpha = 255 * np.ones((h, w), np.uint8)
    nobg_fg = float((alpha > 128).mean())
    ratio = nobg_fg / orig_fg if orig_fg > 1e-4 else 0
    if orig_fg < 0.02:
        verdict = "персонаж и так крошечный?"
    elif ratio < 0.4:
        verdict = "<<< ПЕРЕ-УДАЛЁН"
    elif ratio < 0.75:
        verdict = "< частично съеден"
    else:
        verdict = "ок"
    print(f"{os.path.basename(orig):28} {orig_fg*100:7.1f}% {nobg_fg*100:7.1f}% {ratio*100:5.0f}%  {verdict}")
