# -*- coding: utf-8 -*-
"""
Убирает белую/бледную кайму по краю спрайтов (типичный след автоматического
удаления фона — прозрачность обрывается резко, а сам крайний пиксель/пиксели
остаются светлыми, потому что были смешаны с белым фоном).

Как это работает:
  - для каждого PNG со своим альфа-каналом ищутся "внешние" пиксели — непрозрачные,
    но соседствующие (в т.ч. по диагонали) с прозрачным пикселем;
  - если такой пиксель бледный (достаточно яркий и достаточно ненасыщенный —
    то есть близок к белому/серому, а не к цветному краю рисунка), его альфа
    обнуляется;
  - после этого проверка повторяется — так снимается несколько слоёв каймы
    подряд, но не больше --max-depth раз за файл, чтобы случайно не съесть
    по-настоящему светлую часть персонажа (белую шерсть, лёд и т.п.).

Перед любой правкой оригинал копируется в --backup-dir (по умолчанию —
D:\\dOCS\\_Godmaker_cleanup_backup\\sprite_originals, вне самого проекта, чтобы
Godot не пытался импортировать резервные копии как текстуры) с тем же
относительным путём — так его легко найти и вернуть обратно. Если бэкап уже
есть, файл не перезаписывается (значит скрипт уже разбирал этот спрайт раньше
и в бэкапе лежит ПЕРВООБРАЗНЫЙ вариант, а не результат прошлого прогона).

Запуск:
    python Tools/remove_white_borders.py --dry-run
        — ничего не меняет, только печатает отчёт: какие файлы затронуты и
          сколько пикселей у каждого снимется.

    python Tools/remove_white_borders.py
        — реально обрабатывает файлы (с бэкапом оригиналов).

    python Tools/remove_white_borders.py --root Gods --bright 200 --sat 20 --max-depth 3
        — то же самое, но только в указанной папке и с другими порогами.

После реальной правки спрайтов Godot нужно переимпортировать — открыть редактор,
либо прогнать `Godot ... --headless --path . --import`.
"""

import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image
import numpy as np
from scipy.ndimage import binary_erosion

DEFAULT_ROOTS = ["Gods", "Enemies", "Nemesis", "Main_characters"]
DEFAULT_BACKUP_DIR = r"D:\dOCS\_Godmaker_cleanup_backup\sprite_originals"
STRUCT_8 = np.ones((3, 3), dtype=bool)  # 8-связность: диагональный сосед тоже "снаружи"


def find_pale_border_mask(rgb: np.ndarray, alpha: np.ndarray, bright_thresh: int, sat_thresh: int, max_depth: int):
    """Возвращает (новая_альфа, снято_пикселей, число_проходов)."""
    alpha = alpha.copy()
    opaque = alpha > 0
    rgb32 = rgb.astype(np.int32)
    brightness = rgb32.mean(axis=2)
    saturation = rgb32.max(axis=2) - rgb32.min(axis=2)
    pale = (brightness >= bright_thresh) & (saturation <= sat_thresh)

    total_cleared = 0
    passes_done = 0
    for _ in range(max_depth):
        if not opaque.any():
            break
        eroded = binary_erosion(opaque, structure=STRUCT_8)
        border = opaque & ~eroded  # непрозрачные пиксели, касающиеся прозрачных (в т.ч. по диагонали)
        to_clear = border & pale
        n = int(to_clear.sum())
        if n == 0:
            break
        alpha[to_clear] = 0
        opaque = alpha > 0
        total_cleared += n
        passes_done += 1
    return alpha, total_cleared, passes_done


def process_file(path: Path, backup_dir: Path, project_root: Path, bright_thresh: int, sat_thresh: int,
                  max_depth: int, dry_run: bool) -> tuple:
    """Возвращает (затронут: bool, снято_пикселей: int, проходов: int) или None при ошибке чтения."""
    try:
        im = Image.open(path)
    except Exception as exc:
        print(f"  ! не удалось открыть {path}: {exc}")
        return None
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    arr = np.array(im)
    if arr.shape[2] < 4 or not (arr[:, :, 3] == 0).any():
        return (False, 0, 0)  # нет альфа-канала или нет ни одного прозрачного пикселя — нечего снимать

    new_alpha, cleared, passes = find_pale_border_mask(
        arr[:, :, :3], arr[:, :, 3], bright_thresh, sat_thresh, max_depth
    )
    if cleared == 0:
        return (False, 0, 0)

    if not dry_run:
        rel = path.relative_to(project_root)
        backup_path = backup_dir / rel
        if not backup_path.exists():
            backup_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, backup_path)
        arr[:, :, 3] = new_alpha
        Image.fromarray(arr, "RGBA").save(path)

    return (True, cleared, passes)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", action="append", default=None,
                         help="Папка (относительно корня проекта) для обработки; можно указать несколько раз. "
                              f"По умолчанию: {', '.join(DEFAULT_ROOTS)}")
    parser.add_argument("--project-root", default=".", help="Корень проекта Godot (по умолчанию — текущая папка).")
    parser.add_argument("--backup-dir", default=DEFAULT_BACKUP_DIR,
                         help=f"Куда копировать оригиналы перед правкой (по умолчанию {DEFAULT_BACKUP_DIR}).")
    parser.add_argument("--bright", type=int, default=180,
                         help="Порог яркости (среднее R,G,B, 0-255) — выше него пиксель считается 'светлым'. По умолчанию 180.")
    parser.add_argument("--sat", type=int, default=15,
                         help="Порог насыщенности (max(R,G,B)-min(R,G,B)) — ниже него пиксель считается 'бесцветным' "
                              "(белым/серым, а не окрашенным). По умолчанию 15.")
    parser.add_argument("--max-depth", type=int, default=2,
                         help="Сколько слоёв каймы снимать максимум за файл (по умолчанию 2 — безопаснее для "
                              "персонажей с по-настоящему светлыми краями).")
    parser.add_argument("--dry-run", action="store_true", help="Только отчёт, ничего не менять на диске.")
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    roots = args.root or DEFAULT_ROOTS
    backup_dir = Path(args.backup_dir)

    files = []
    for root in roots:
        files.extend(sorted((project_root / root).rglob("*.png")))
    files = [f for f in files if ".godot" not in f.parts]

    print(f"Найдено PNG-файлов для проверки: {len(files)} (папки: {', '.join(roots)})")
    if args.dry_run:
        print("Режим: ТОЛЬКО ОТЧЁТ (--dry-run), файлы не изменяются.\n")
    else:
        print(f"Оригиналы перед правкой будут сохранены в: {backup_dir}\n")

    affected = []
    errors = 0
    for f in files:
        result = process_file(f, backup_dir, project_root, args.bright, args.sat, args.max_depth, args.dry_run)
        if result is None:
            errors += 1
            continue
        touched, cleared, passes = result
        if touched:
            affected.append((f.relative_to(project_root), cleared, passes))

    affected.sort(key=lambda x: -x[1])
    print(f"{'Затронуто' if not args.dry_run else 'Будет затронуто'} файлов: {len(affected)} из {len(files)}"
          + (f"  (ошибок чтения: {errors})" if errors else ""))
    for rel, cleared, passes in affected:
        print(f"  {cleared:6d} px, {passes} проход(а)  {rel}")

    if args.dry_run:
        print("\nЭто был предпросмотр. Запустите без --dry-run, чтобы применить правки (с бэкапом оригиналов).")
    else:
        print(f"\nГотово. Резервные копии — в {backup_dir}\\<такой же относительный путь>.")
        print("Дальше: переимпортировать в Godot (открыть редактор или "
              "--headless --path . --import), чтобы игра подхватила новые спрайты.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
