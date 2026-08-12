# -*- coding: utf-8 -*-
"""
Применение результатов:
  A) 20 врагам  -> sprite_path = новый flood-fill _nobg.png (персонаж сохранён)
  B) боги (4) + Серебрянная валькирия + 2 каппы -> возврат к оригинальной картинке,
     удаление старых плохих _nobg.png (+.import). Пользователь доработает сам.
"""
import sys, os, glob, json, re
sys.stdout.reconfigure(encoding="utf-8")


def fwd(p):
    return p.replace("\\", "/")


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def write(p, s):
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)


with open("_nobg_map.json", encoding="utf-8") as f:
    m = {fwd(k): fwd(v) for k, v in json.load(f).items()}

# ---- A: назначить _nobg врагам ----
print("== A: sprite_path врагам -> flood-fill _nobg ==")
assigned = 0
for orig, nobg in m.items():
    folder = os.path.dirname(orig)
    res = "res://" + nobg
    # unit .tres = содержит unit_name
    unit_tres = None
    for tf in glob.glob(os.path.join(folder, "*.tres")):
        if re.search(r'^unit_name\s*=', read(tf), re.M):
            unit_tres = tf
            break
    if not unit_tres:
        print("  NO unit .tres:", folder)
        continue
    s = read(unit_tres)
    if re.search(r'^sprite_path\s*=', s, re.M):
        s2 = re.sub(r'^sprite_path\s*=\s*".*?"',
                    f'sprite_path = "{res}"', s, count=1, flags=re.M)
    else:
        s2 = re.sub(r'(^unit_name\s*=\s*"[^"]*")',
                    r'\1\nsprite_path = "%s"' % res, s, count=1, flags=re.M)
    if s2 != s:
        write(unit_tres, s2)
        assigned += 1
        print(f"  OK {os.path.basename(unit_tres):28} -> {os.path.basename(nobg)}")
print(f"Назначено: {assigned}\n")


# ---- B: откат богов / silver valkyrie / капп к оригиналу ----
print("== B: откат богов/валькирия/каппы -> оригинал ==")


def is_rollback_path(tf):
    fp = fwd(tf).lower()
    if fp.startswith("gods/"):
        return True
    if "silver valkerie" in fp:
        return True
    if "cappa" in fp:
        return True
    return False


restored = 0
deleted = []
for tf in glob.glob("Gods/**/*.tres", recursive=True) + glob.glob("Enemies/**/*.tres", recursive=True):
    s = read(tf)
    msp = re.search(r'^sprite_path\s*=\s*"([^"]+)"', s, re.M)
    if not msp or "_nobg" not in msp.group(1):
        continue
    if not is_rollback_path(tf):
        continue
    folder = os.path.dirname(tf)
    cand = []
    for ext in ("*.jpg", "*.jpeg", "*.png"):
        cand += [c for c in glob.glob(os.path.join(folder, ext)) if "_nobg" not in c]
    if not cand:
        print("  нет оригинала в", folder)
        continue
    orig_img = fwd(sorted(cand)[0])
    res_orig = "res://" + orig_img
    s2 = re.sub(r'^sprite_path\s*=\s*".*?"',
                f'sprite_path = "{res_orig}"', s, count=1, flags=re.M)
    write(tf, s2)
    restored += 1
    print(f"  RESTORE {os.path.basename(tf):24} -> {os.path.basename(orig_img)}")
    # удалить старый плохой _nobg.png + служебные файлы Godot
    nobg_disk = msp.group(1).replace("res://", "")
    for dpath in [nobg_disk, nobg_disk + ".import"]:
        if os.path.exists(dpath):
            try:
                os.remove(dpath)
                deleted.append(dpath)
            except Exception as e:
                print("    не удаётся", dpath, e)

print(f"Откачено: {restored}, удалено файлов: {len(deleted)}")
