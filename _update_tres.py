# -*- coding: utf-8 -*-
"""
Обновляет sprite_path в .tres: оригинальная картинка -> *_nobg.png (прозрачный фон).
Трогает только те .tres, чей sprite_path совпадает с обработанной картинтой.
"""
import sys, os, glob, json, re
sys.stdout.reconfigure(encoding="utf-8")

with open("_nobg_map.json", "r", encoding="utf-8") as f:
    raw_map = json.load(f)

def norm(p):
    return p.replace("\\", "/").replace("res://", "")

# Карта: нормализованный_оригинал -> нормализованный_новый (прямые слэши)
upd = {}
for k, v in raw_map.items():
    if v:
        upd[norm(k)] = norm(v)

print("Обработанных картинок в карте:", len(upd))

tres = glob.glob("Gods/**/*.tres", recursive=True) + glob.glob("Enemies/**/*.tres", recursive=True)

pat = re.compile(r'sprite_path\s*=\s*"res://([^"]+)"')
changed = []
for tp in sorted(tres):
    with open(tp, "r", encoding="utf-8") as f:
        text = f.read()
    orig = text

    def repl(m):
        rel = norm(m.group(1))
        if rel in upd:
            return 'sprite_path = "res://%s"' % upd[rel]
        return m.group(0)

    text = pat.sub(repl, text)
    if text != orig:
        with open(tp, "w", encoding="utf-8") as f:
            f.write(text)
        changed.append(tp)
        print("ОБНОВЛЕНО:", tp)

print("\nВсего обновлено .tres:", len(changed))
