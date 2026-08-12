# -*- coding: utf-8 -*-
"""Фактическая проверка альфа-канала готовых _nobg.png: прозрачны ли края/углы."""
import sys, os, glob, json
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import cv2

with open("_nobg_map.json", encoding="utf-8") as f:
    m = {p.replace("\\", "/"): n.replace("\\", "/") for p, n in json.load(f).items()}


def read_alpha(p):
    a = cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_UNCHANGED)
    return a[:, :, 3] if a is not None and a.ndim == 3 and a.shape[2] == 4 else None


print(f"{'image':26} {'прозрачн':>8} {'углы=0':>6} {'край_прозр':>9}")
print("-" * 60)
for orig, nobg in m.items():
    al = read_alpha(nobg)
    if al is None:
        print(f"{os.path.basename(orig):26}  НЕТ АЛЬФА"); continue
    h, w = al.shape
    frac = float((al < 8).mean()) * 100            # % прозрачных
    # 4 угла
    corners = [al[0, 0], al[0, -1], al[-1, 0], al[-1, -1]]
    corners_transparent = sum(1 for c in corners if c < 8)
    # рамка (края) прозрачность
    ring = np.concatenate([al[0, :], al[-1, :], al[:, 0], al[:, -1]])
    ring_frac = float((ring < 8).mean()) * 100
    print(f"{os.path.basename(orig):26} {frac:7.1f}% {corners_transparent:5d}/4 {ring_frac:8.1f}%")
