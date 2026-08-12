#!/usr/bin/env python3
"""Простые scale% для 3 категорий. Никаких расчётов от PNG — только проценты."""
import os, re

# Простые проценты масштаба (100% = стандартный размер слота)
K = 120   # Крупные — чуть больше стандарта
H = 100   # Человек — стандарт
S = 80    # Мелкие — меньше стандарта

CAT = {
    # === КРУПНЫЕ (is_large / боссы) — 120% ===
    "Sphinx.tres": K, "attacking_titan.tres": K, "armored_titan.tres": K,
    "Nightmare.tres": K, "cyclops.tres": K, "troll.tres": K, "Devil.tres": K,
    "Coatl.tres": K, "golem.tres": K, "Golden_Scarab.tres": K, "scorpio.tres": K,
    "stone_giant_warrior.tres": K, "stone_giant_shaman.tres": K,
    "Minotaur.tres": K, "jotun.tres": K, "leshy.tres": K, "alraune.tres": K,
    "Griffin.tres": K, "Pegasus.tres": K, "oni_sorcerer.tres": K, "unicorn.tres": K,
    "lava_boar.tres": K, "lernaean_lion.tres": K, "Tormentor.tres": K,
    "cannon.tres": K, "Eel.tres": K, "Centaur.tres": K, "Golden_Valkerie.tres": K,
    "Silver_Valkerie.tres": K, "Knight.tres": K, "libra.tres": K,
    # === ЧЕЛОВЕК (стандарт) — 100% ===
    "Wizard.tres": H, "draugr_berserk.tres": H, "Draugr_Juggernaut.tres": H,
    "Draugr_raider.tres": H, "Inquisitor.tres": H, "Hoplite.tres": H,
    "Gladiator.tres": H, "Sea_Witch.tres": H, "Merman_Warrior.tres": H,
    "Nanahue.tres": H, "Medusa.tres": H, "Mermaid_Sorceress.tres": H,
    "Succubus.tres": H, "Triton.tres": H, "Naga_Monk.tres": H, "oboroten.tres": H,
    "aquarius.tres": H, "virgo.tres": H, "Siren.tres": H, "Filibuster.tres": H,
    "sailor.tres": H, "sailor_with_barrel.tres": H, "Guardsman.tres": H,
    "Jester.tres": H, "Princess.tres": H, "Mentor.tres": H, "Mummy.tres": H,
    "Anubis_Priest.tres": H, "Immortal.tres": H, "Ra_Priest.tres": H,
    "Tormented_soul.tres": H, "Hellhound.tres": H, "vodyanoy.tres": H,
    "flower_fairy.tres": H, "thorn_fairy.tres": H, "gemini.tres": H,
    "oni_warrior.tres": H, "rakshasa.tres": H, "asura.tres": H,
    "naga_warrior.tres": H, "captain.tres": H, "aries.tres": H,
    # === МЕЛКИЕ — 80% ===
    "Novice.tres": S, "cappa_warrior.tres": S, "cappa_shaman.tres": S,
    "druid.tres": S, "banshee.tres": S, "indigo.tres": S,
    "crab_collector.tres": S, "utoplennitsa.tres": S, "kikimora.tres": S,
    "kirin.tres": S, "dwarf_shield.tres": S, "dwarf_smith.tres": S,
    "Saru.tres": S, "satyr.tres": S, "bird_knife_wings.tres": S,
    "cupid.tres": S, "kobold.tres": S,
}

base = r"d:\dOCS\test\Enemies"
updated = 0

for root, dirs, files in os.walk(base):
    for fname in files:
        if fname not in CAT:
            continue
        fpath = os.path.join(root, fname)
        try:
            with open(fpath, "r", encoding="utf-8") as f:
                content = f.read()
        except:
            continue
        new_scale = CAT[fname]
        new_content = re.sub(r'(battle_sprite_scale_percent\s*=\s*)[\d.]+', rf'\g<1>{new_scale}', content)
        if new_content != content:
            with open(fpath, "w", encoding="utf-8") as f:
                f.write(new_content)
            updated += 1

print(f"Updated {updated} files.")
