# -*- coding: utf-8 -*-
"""
Удаление ОДНОТОННОГО фона — ЦВЕТОВОЙ ПОРОГ (v3).

Прозрачными становятся ВСЕ пиксели, чей цвет в пределах tol от цвета фона:
внешний фон + ЗАМКНУТЫЕ карманы (между ног, под мышками) + белая бахрома по контуру.
Персонаж сохраняется — убираются только пиксели, близкие к фону.

Цвет фона определяется по углам/рамке (НЕ захардкожен белый) => работает для ЛЮБОГО
однотонного фона. tol = чуть выше шума фона.
"""
import sys, os, glob, json
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import cv2

EXCLUDE = ["Серебрянная валькирия", "Каппа шаман", "Каппа воин"]

imgs = []
for ext in ("*.jpg", "*.jpeg", "*.png"):
    imgs += glob.glob("Enemies/**/" + ext, recursive=True)
imgs = [p for p in imgs if "Background" not in p and "_nobg" not in p]
imgs = [p for p in imgs if not any(x in p for x in EXCLUDE)]
imgs = sorted(set(imgs))
print("К обработке (враги):", len(imgs), "\n")


def read_bgr(p):
    return cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_COLOR)


def write_png(p, rgba):
    ok, buf = cv2.imencode(".png", rgba)
    if ok:
        with open(p, "wb") as fh:
            fh.write(buf.tobytes())
    return ok


def crop_alpha(rgba, thresh=10, pad=3):
    """Обрезать прозрачные поля до границ персонажа (+pad px запас).
    Центрирует персонажа в кадре и убирает пустые поля — после масштабирования
    под слот персонаж занимает максимум места и не смещён в сторону."""
    a = rgba[:, :, 3]
    ys, xs = np.where(a > thresh)
    if xs.size == 0:
        return rgba
    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())
    h, w = rgba.shape[:2]
    x0 = max(0, x0 - pad); x1 = min(w - 1, x1 + pad)
    y0 = max(0, y0 - pad); y1 = min(h - 1, y1 + pad)
    return rgba[y0:y1 + 1, x0:x1 + 1].copy()


mapping = {}
for p in imgs:
    try:
        bgr = read_bgr(p)
        if bgr is None:
            print("FAIL read:", os.path.basename(p)); continue
        h, w = bgr.shape[:2]

        # Цвет фона = медиана по рамке (не только углы — устойчивее)
        ring = np.concatenate([bgr[0, :], bgr[-1, :], bgr[:, 0], bgr[:, -1]]).reshape(-1, 3)
        bg = np.median(ring, axis=0)
        cstd = float(ring.std(axis=0).mean())
        tol = int(np.clip(round(cstd * 2) + 12, 12, 24))

        # Цветовое расстояние каждого пикселя до фона (по макс. каналу)
        d = np.max(np.abs(bgr.astype(np.int16) - bg.astype(np.int16)), axis=2)

        bg_mask = (d <= tol)                  # весь фон (внешний + карманы + halo)
        fg = (~bg_mask).astype(np.float32)

        # Лёгкое сглаживание края (антиалиасинг), без трогания массы персонажа
        alpha = np.clip(cv2.GaussianBlur(fg, (3, 3), 0) * 255.0, 0, 255).astype(np.uint8)

        rgba = cv2.cvtColor(bgr, cv2.COLOR_BGR2BGRA)
        rgba[:, :, 3] = alpha
        rgba = crop_alpha(rgba)
        out = os.path.splitext(p)[0] + "_nobg.png"
        if not write_png(out, rgba):
            print("FAIL write:", os.path.basename(p)); continue

        bg_frac = float(bg_mask.mean())
        print(f"OK  {os.path.basename(p):26} фон={bg_frac*100:5.1f}%  персонаж={(1-bg_frac)*100:5.1f}%  std={cstd:4.1f}  tol={tol}")
        mapping[p] = out
    except Exception as e:
        print("FAIL", os.path.basename(p), repr(e))

with open("_nobg_map.json", "w", encoding="utf-8") as f:
    json.dump(mapping, f, ensure_ascii=False, indent=2)
print("\nГотово:", len(mapping))
