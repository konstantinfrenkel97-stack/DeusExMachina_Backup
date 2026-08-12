# -*- coding: utf-8 -*-
"""
Убирает папку Abilities у каждого персонажа: переносит ability .tres
(и их sidecar-файлы) в папку самого юнита, обновляет все ссылки
/Abilities/ -> / , удаляет пустые папки Abilities.
Неразрушающе по содержимому: конфликты имён выявляются и пропускаются.
"""
import sys, os, glob, shutil
sys.stdout.reconfigure(encoding="utf-8")

# 1. Найти все папки Abilities
ab_dirs = sorted(set(
    os.path.dirname(p) for p in
    glob.glob("Gods/**/Abilities/*", recursive=True) +
    glob.glob("Enemies/**/Abilities/*", recursive=True)
))
print("Abilities-папок найдено:", len(ab_dirs))

moves, collisions, not_removed = {}, [], []
for d in ab_dirs:
    parent = os.path.dirname(d)
    if not os.path.isdir(d):
        continue
    for name in os.listdir(d):
        src = os.path.join(d, name)
        if not os.path.isfile(src):
            continue  # подпапок не ждём
        dst = os.path.join(parent, name)
        if os.path.exists(dst):
            collisions.append((src, dst))
            continue
        shutil.move(src, dst)
        moves[src] = dst
    # удалить папку Abilities, если пуста
    try:
        if not os.listdir(d):
            os.rmdir(d)
        else:
            not_removed.append((d, os.listdir(d)))
    except Exception as e:
        not_removed.append((d, str(e)))

print("Перемещено файлов:", len(moves))
if collisions:
    print("!!! КОЛЛИЗИИ (пропущено):")
    for s, d2 in collisions:
        print("   ", s, "->", d2, "(цель существует)")
if not_removed:
    print("!!! НЕ удалены (не пусты):")
    for d, info in not_removed:
        print("   ", d, info)

# 2. Обновить ссылки /Abilities/ -> / во всех ресурсах
targets = set()
for pat in ("*.tres", "*.tscn", "*.cfg", "*.import", "*.remap"):
    for base in ("Gods", "Enemies"):
        targets.update(glob.glob(base + "/**/" + pat, recursive=True))
    targets.update(glob.glob(pat))
changed = []
for tp in sorted(targets):
    try:
        with open(tp, "r", encoding="utf-8") as f:
            txt = f.read()
    except Exception:
        continue
    if "/Abilities/" in txt:
        with open(tp, "w", encoding="utf-8") as f:
            f.write(txt.replace("/Abilities/", "/"))
        changed.append(tp)

print("\nОбновлено файлов (ссылки):", len(changed))
for c in changed:
    print("   ", c)

# 3. Проверка: остались ли папки Abilities?
remain = sorted(set(
    os.path.dirname(p) for p in
    glob.glob("Gods/**/Abilities/*", recursive=True) +
    glob.glob("Enemies/**/Abilities/*", recursive=True)
))
print("\nОсталось Abilities-папок:", len(remain))
print("Готово.")
