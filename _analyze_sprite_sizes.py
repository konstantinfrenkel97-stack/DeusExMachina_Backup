#!/usr/bin/env python3
"""Анализ итоговых размеров спрайтов врагов: PNG высота x масштаб."""
import os, re, struct

def get_png_size(filepath):
    try:
        with open(filepath, "rb") as f:
            header = f.read(24)
            if header[:8] == b'\x89PNG\r\n\x1a\n':
                w, h = struct.unpack('>II', header[16:24])
                return w, h
    except:
        pass
    return None, None

base = r"d:\dOCS\test\Enemies"
results = []
for root, dirs, files in os.walk(base):
    for fname in files:
        if not fname.endswith(".tres"):
            continue
        fpath = os.path.join(root, fname)
        try:
            with open(fpath, "r", encoding="utf-8") as f:
                content = f.read()
        except:
            continue
        sp_match = re.search(r'sprite_path\s*=\s*"([^"]+)"', content)
        if not sp_match:
            continue
        sprite_path = sp_match.group(1)
        if not sprite_path:
            continue
        scale_match = re.search(r'battle_sprite_scale_percent\s*=\s*([\d.]+)', content)
        scale = float(scale_match.group(1)) if scale_match else 100.0
        hp_match = re.search(r'max_hp\s*=\s*(\d+)', content)
        hp = int(hp_match.group(1)) if hp_match else 0
        is_large = 'is_large = true' in content
        name_match = re.search(r'unit_name\s*=\s*"([^"]*)"', content)
        unit_name = name_match.group(1) if name_match else fname
        png_path = sprite_path.replace("res://", "")
        full_png = os.path.join(r"d:\dOCS\test", png_path)
        w, h = get_png_size(full_png)
        if w is None:
            results.append((fname, unit_name, 0, 0, scale, 0, hp, is_large))
            continue
        final_h = h * scale / 100.0
        results.append((fname, unit_name, w, h, scale, final_h, hp, is_large))

results.sort(key=lambda x: -x[5])
with open(r"d:\dOCS\test\_sprite_analysis.txt", "w", encoding="utf-8") as out:
    out.write(f"{'File':<35} {'Name':<20} {'PNG_W':<7} {'PNG_H':<7} {'Scale%':<8} {'FinalH':<8} {'HP':<5} {'Large'}\n")
    out.write("-" * 110 + "\n")
    for r in results:
        fname, name, w, h, scale, final_h, hp, large = r
        out.write(f"{fname:<35} {name:<20} {w:<7} {h:<7} {scale:<8.0f} {final_h:<8.0f} {hp:<5} {'Y' if large else ''}\n")
    out.write(f"\nTotal: {len(results)} enemies analyzed.\n")
print(f"OK: {len(results)} enemies -> _sprite_analysis.txt")
