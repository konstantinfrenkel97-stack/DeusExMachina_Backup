# -*- coding: utf-8 -*-
"""Анализ однородности фона: низкий std_края => однотонный фон (flood-fill идеален),
высокий => сложный фон. Также показывает долю уже-прозрачного края."""
import sys, os, glob
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image

imgs = []
for base in ("Gods/", "Enemies/"):
    for ext in ("*.jpg", "*.jpeg", "*.png"):
        imgs += glob.glob(base + "**/" + ext, recursive=True)
imgs = [p for p in imgs if "Background" not in p and "_nobg" not in p]
imgs = sorted(set(imgs))

print(f"{'Файл':34}{'Размер':10}{'std_края':9}{'однородность':14}")
print("-" * 70)
for p in imgs:
    try:
        im = Image.open(p).convert("RGB")
        arr = np.asarray(im)
        border = np.concatenate([
            arr[0:6, :, :].reshape(-1, 3),
            arr[-6:, :, :].reshape(-1, 3),
            arr[:, 0:6, :].reshape(-1, 3),
            arr[:, -6:, :].reshape(-1, 3),
        ]).astype(int)
        std = float(border.std(axis=0).mean())
        verdict = "ОДНОТОННЫЙ" if std < 15 else ("средний" if std < 35 else "СЛОЖНЫЙ")
        print(f"{os.path.basename(p):34}{im.size[0]}x{im.size[1]:<6}{std:7.1f}   {verdict}")
    except Exception as e:
        print(f"{os.path.basename(p):34} ОШИБКА: {e}")
