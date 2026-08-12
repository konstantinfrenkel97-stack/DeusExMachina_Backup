# -*- coding: utf-8 -*-
"""
Удаление фона со всех картинок персонажей через ИИ-сегментацию (rembg / U2Net).
Результат: рядом с оригиналом создаётся *_nobg.png с прозрачным фоном.
Оригиналы не трогаются (неразрушающе).
"""
import sys, os, glob, json
sys.stdout.reconfigure(encoding="utf-8")

import numpy as np
from PIL import Image
from rembg import remove, new_session

# --- Сбор всех картинок персонажей (фоны локаций исключаем) ---
imgs = []
for ext in ("*.jpg", "*.jpeg", "*.png"):
    imgs += glob.glob("Gods/**/" + ext, recursive=True)
    imgs += glob.glob("Enemies/**/" + ext, recursive=True)
imgs = [p for p in imgs if ("\\Background\\" not in p) and ("/Background/" not in p)]
# Исключаем уже созданные _nobg.png, чтобы не обрабатывать повторно
imgs = [p for p in imgs if "_nobg" not in os.path.basename(p)]
imgs = sorted(set(imgs))

print("Найдено картинок для обработки:", len(imgs))
print("Инициализация сессии U2Net (первый запуск скачает модель ~176 МБ)...\n")
session = new_session("u2net")

mapping = {}   # исходный_путь -> новый_путь
for p in imgs:
    try:
        with open(p, "rb") as f:
            data = f.read()
        # Сегментация: на выходе PNG (RGBA) с прозрачным фоном
        out = remove(data, session=session)
        base = os.path.splitext(p)[0]
        out_path = base + "_nobg.png"
        with open(out_path, "wb") as f:
            f.write(out)

        im = Image.open(out_path)
        arr = np.asarray(im.convert("RGBA"))
        transp_frac = float((arr[:, :, 3] < 16).mean())
        mapping[p] = out_path
        print(f"OK   {os.path.basename(p):30} -> {os.path.basename(out_path):30} "
              f"{im.size[0]}x{im.size[1]}  прозр={transp_frac*100:4.1f}%")
    except Exception as e:
        print(f"FAIL {os.path.basename(p):30} {e}")

# Сохраняем карту «оригинал -> nobg» для обновления .tres
with open("_nobg_map.json", "w", encoding="utf-8") as f:
    json.dump(mapping, f, ensure_ascii=False, indent=2)

ok = sum(1 for v in mapping.values() if v)
print(f"\nГотово: обработано {ok} из {len(imgs)}.")
print("Карта путей сохранена в _nobg_map.json")
