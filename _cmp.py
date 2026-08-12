# -*- coding: utf-8 -*-
"""
СРАВНЕНИЕ методов удаления фона (диагностика перед сменой подхода).
- flood: текущий border flood-fill (оставляет замкнутые белые карманы)
- color:  цветовой порог — прозрачны ВСЕ пиксели в пределах tol от цвета фона
          (убирает внешний фон + карманы + halo; персонаж сохраняется)

Показываем, сколько персонажа остаётся в каждом методе, и сколько "лишнего"
забирает color (это потенциально белые карманы ИЛИ светлые части персонажа).
"""
import sys, os, glob, json
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import cv2

with open("_nobg_map.json", encoding="utf-8") as f:
    m = {p.replace("\\", "/"): n.replace("\\", "/") for p, n in json.load(f).items()}


def read_bgr(p):
    return cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_COLOR)


print(f"{'image':26} {'orig':>6} {'flood':>6} {'color':>6} {'color ест':>9}")
print("-" * 64)
for orig in m:
    bgr = read_bgr(orig)
    if bgr is None:
        continue
    h, w = bgr.shape[:2]
    c = 12
    corners = np.concatenate([bgr[:c, :c].reshape(-1, 3), bgr[:c, -c:].reshape(-1, 3),
                              bgr[-c:, :c].reshape(-1, 3), bgr[-c:, -c:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    cstd = float(corners.std(axis=0).mean())
    tol = int(np.clip(round(cstd * 2) + 12, 12, 24))

    d = np.max(np.abs(bgr.astype(int) - bg.astype(int)), axis=2)
    orig_fg = float((d > 15).mean())            # оценка реального персонажа
    color_fg = float((d > tol).mean())          # что останется при цветовом методе
    eaten = orig_fg - color_fg                  # сколько "съест" цветовой метод
    # сколько остаётся при текущем flood (из готового _nobg)
    nobg = cv2.imdecode(np.fromfile(m[orig], dtype=np.uint8), cv2.IMREAD_UNCHANGED)
    flood_fg = float((nobg[:, :, 3] > 128).mean()) if nobg is not None else -1
    flag = "!! ест персонаж" if eaten > 0.06 else ""
    print(f"{os.path.basename(orig):26} {orig_fg*100:5.1f}% {flood_fg*100:5.1f}% {color_fg*100:5.1f}% {eaten*100:8.1f}% {flag}")
