# -*- coding: utf-8 -*-
"""
Наглядный предпросмотр: накладываем каждый _nobg.png на серо-белую 'шахматку'.
Где альфа прозрачна — видна клетка => фон реально убран.
Результат в папке _preview/.
"""
import sys, os, glob, json
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
import cv2

with open("_nobg_map.json", encoding="utf-8") as f:
    m = {p.replace("\\", "/"): n.replace("\\", "/") for p, n in json.load(f).items()}

os.makedirs("_preview", exist_ok=True)


def read_bgra(p):
    return cv2.imdecode(np.fromfile(p, dtype=np.uint8), cv2.IMREAD_UNCHANGED)


def magenta(h, w):
    # сплошной яркий малиновый фон — где прозрачность, там будет он
    img = np.zeros((h, w, 3), np.uint8)
    img[:] = (255, 0, 255)
    return img


n = 0
for orig, nobg in m.items():
    bgra = read_bgra(nobg)
    if bgra is None or bgra.shape[2] != 4:
        continue
    h, w = bgra.shape[:2]
    bg = magenta(h, w)
    bgr = bgra[:, :, :3]
    a = bgra[:, :, 3:4].astype(float) / 255.0
    comp = (bgr.astype(float) * a + bg.astype(float) * (1 - a)).astype(np.uint8)
    out = f"_preview/{os.path.splitext(os.path.basename(orig))[0]}_preview.png"
    ok, buf = cv2.imencode(".png", comp)
    with open(out, "wb") as fh:
        fh.write(buf.tobytes())
    n += 1

# удалить временные rembg-файлы
for p in glob.glob("Enemies/**/*_ai.png", recursive=True):
    try:
        os.remove(p)
        imp = p + ".import"
        if os.path.exists(imp):
            os.remove(imp)
    except Exception:
        pass

print(f"Готово: {n} предпросмотров в папке _preview/")
print("Откройте любой _preview/*.png — где видна серо-белая клетка, там фон ПРОЗРАЧНЫЙ (убран).")
