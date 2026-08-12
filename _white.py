# -*- coding: utf-8 -*-
"""
Сколько РЕАЛЬНО осталось непрозрачного белого в _nobg.png?
Это отвечает на 'вижу кучу белого неудалена'.
Дополнительно: средний цвет фона (рамка) — чтобы понять, белый ли он вообще.
"""
import sys, os, glob, json
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import cv2

with open("_nobg_map.json", encoding="utf-8") as f:
    m = {p.replace("\\", "/"): n.replace("\\", "/") for p, n in json.load(f).items()}


def read_bgra(p):
    return cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_UNCHANGED)


def read_bgr(p):
    return cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_COLOR)


print(f"{'image':24} {'фон(BGR)':>9} {'прозр':>6} {'непрозр':>7} {'белый_непрозр':>13}")
print("-" * 68)
for orig, nobg in m.items():
    bgr = read_bgr(orig)
    bgra = read_bgra(nobg)
    if bgr is None or bgra is None:
        continue
    h, w = bgr.shape[:2]
    ring = np.concatenate([bgr[0, :], bgr[-1, :], bgr[:, 0], bgr[:, -1]]).reshape(-1, 3)
    bg_med = np.median(ring, axis=0).astype(int)              # B,G,R
    al = bgra[:, :, 3]
    transp = float((al < 8).mean()) * 100
    opaque = (al >= 128)
    opaque_frac = float(opaque.mean()) * 100
    # непрозрачные И белые (все каналы > 230) — это 'белое что осталось'
    rgb = bgra[:, :, :3][:, :, ::-1]                          # -> RGB
    white = (rgb[:, :, 0] > 230) & (rgb[:, :, 1] > 230) & (rgb[:, :, 2] > 230)
    white_opaque = float((white & opaque).mean()) * 100
    print(f"{os.path.basename(orig):24} {str(bg_med):>9} {transp:5.1f}% {opaque_frac:6.1f}% {white_opaque:12.1f}%")
