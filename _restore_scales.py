#!/usr/bin/env python3
"""Восстанавливает исходные scale% из _scale_update_log.txt."""
import os, re

# Читаем лог и собираем old значения
restore = {}
with open(r"d:\dOCS\test\_scale_update_log.txt", "r", encoding="utf-8") as f:
    for line in f:
        m = re.search(r'(\w+\.tres):.*old=([\d.]+)', line)
        if m:
            restore[m.group(1)] = float(m.group(2))

base = r"d:\dOCS\test\Enemies"
restored = 0
for root, dirs, files in os.walk(base):
    for fname in files:
        if fname not in restore:
            continue
        fpath = os.path.join(root, fname)
        try:
            with open(fpath, "r", encoding="utf-8") as f:
                content = f.read()
        except:
            continue
        old_scale = restore[fname]
        new_content = re.sub(r'(battle_sprite_scale_percent\s*=\s*)[\d.]+', rf'\g<1>{old_scale}', content)
        if new_content != content:
            with open(fpath, "w", encoding="utf-8") as f:
                f.write(new_content)
            restored += 1

print(f"Restored {restored} files to original values.")
