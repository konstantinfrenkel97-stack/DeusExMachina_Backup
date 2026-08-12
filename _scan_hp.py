# -*- coding: utf-8 -*-
# Найти все enemy .tres, у которых НЕ задано max_hp (или задано <= 0).
import os, glob, sys, re
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
ROOT = os.path.dirname(os.path.abspath(__file__))
broken = []
total = 0
for tres in glob.glob(os.path.join(ROOT, "Enemies", "**", "*.tres"), recursive=True):
    total += 1
    with open(tres, "r", encoding="utf-8") as f:
        txt = f.read()
    m = re.search(r"^max_hp\s*=\s*(-?\d+)", txt, re.M)
    # пропускаем ability/spell-ресурсы (CharacterResource определяется по наличию unit_name)
    if "unit_name" not in txt:
        continue
    uname = "?"
    mu = re.search(r'^unit_name\s*=\s*"?(.+?)"?\s*$', txt, re.M)
    if mu:
        uname = mu.group(1).strip('"')
    if not m:
        broken.append((uname, "NO max_hp", os.path.relpath(tres, ROOT)))
    else:
        val = int(m.group(1))
        if val <= 0:
            broken.append((uname, "max_hp=%d" % val, os.path.relpath(tres, ROOT)))
print("Всего enemy .tres: %d" % total)
print("Сломанных (нет/<=0 max_hp): %d" % len(broken))
for uname, why, rel in broken:
    print("  - %-22s %-14s %s" % (uname, why, rel))
