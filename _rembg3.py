# -*- coding: utf-8 -*-
"""
Проба rembg (AI) на 3 картинках со СЛОЖНЫМ (неоднотонным) фоном.
Сохраняет во временные *_ai.png и сравнивает с color-версией (_nobg.png):
если rembg оставляет персонажа не меньше, чем color-метод (в области персонажа),
и при этом убирает сложный фон — rembg годится.
"""
import sys, os, glob, json
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import cv2
from rembg import remove

COMPLEX = ["Адская гончая", "Циклоп", "Золотая валькирия"]
imgs = []
for ext in ("*.jpg", "*.jpeg", "*.png"):
    imgs += glob.glob("Enemies/**/" + ext, recursive=True)
imgs = [p for p in imgs if "_nobg" not in p and any(x in p for x in COMPLEX)]
imgs = sorted(set(imgs))


def read_bgr(p):
    return cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_COLOR)


def read_alpha(p):
    a = cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_UNCHANGED)
    return a[:, :, 3] if a is not None and a.shape[2] == 4 else None


print(f"Проба rembg на {len(imgs)} сложных картинках\n")
results = {}
for p in imgs:
    bgr = read_bgr(p)
    out_rgba = remove(bgr)                       # BGRA
    out_path = os.path.splitext(p)[0] + "_ai.png"
    ok, buf = cv2.imencode(".png", out_rgba)
    with open(out_path, "wb") as fh:
        fh.write(buf.tobytes())

    ai_alpha = out_rgba[:, :, 3]
    color_alpha = read_alpha(os.path.splitext(p)[0] + "_nobg.png")
    ai_fg = float((ai_alpha > 128).mean())
    color_fg = float((color_alpha > 128).mean())
    # перекрытие: сколько из того, что оставил color-метод (надёжный персонаж),
    # оставил и rembg (1.0 = rembg ничего не обрезал из персонажа)
    if color_alpha is not None:
        keep = ((ai_alpha > 128) & (color_alpha > 128)).sum()
        color_tot = (color_alpha > 128).sum()
        overlap = keep / color_tot if color_tot else 0
    else:
        overlap = -1
    name = os.path.basename(p)
    results[name] = (ai_fg, color_fg, overlap)
    verdict = "OK rembg" if overlap >= 0.90 else ("?? ест персонаж" if overlap < 0.80 else "~ частично")
    print(f"{name:24} rembg_fg={ai_fg*100:5.1f}%  color_fg={color_fg*100:5.1f}%  "
          f"overlap={overlap*100:4.0f}%  {verdict}")

print("\nЕсли overlap >=90% — rembg сохраняет персонажа и при этом убирает сложный фон.")
