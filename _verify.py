# -*- coding: utf-8 -*-
"""Финальная проверка: каждый sprite_path в .tres -> существующий файл."""
import sys, glob, os, re
sys.stdout.reconfigure(encoding="utf-8")

problems = 0
checked = 0
sp_list = []
for tf in glob.glob("Enemies/**/*.tres", recursive=True) + glob.glob("Gods/**/*.tres", recursive=True):
    with open(tf, encoding="utf-8") as f:
        s = f.read()
    m = re.search(r'^sprite_path\s*=\s*"([^"]+)"', s, re.M)
    if not m:
        continue
    sp = m.group(1)
    disk = sp.replace("res://", "")
    exists = os.path.exists(disk)
    checked += 1
    sp_list.append((tf, sp, exists))
    if not exists:
        problems += 1
        print(f"!!! НЕ СУЩЕСТВУЕТ: {tf}\n      sprite_path={sp}")

print(f"\nПроверено sprite_path: {checked}, проблем: {problems}\n")
print("Сводка по персонажам:")
for tf, sp, ex in sorted(sp_list):
    tag = "OK " if ex else "ERR"
    name = os.path.basename(tf)
    img = os.path.basename(sp)
    print(f"  {tag} {name:30} {img}")
