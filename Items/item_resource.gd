extends Resource
class_name ItemResource

## Предмет — экипировка для бога.
## У каждого бога 3 слота: Оружие, Броня, Безделушка (по одному каждого типа).
## Предмет даёт бонусы к статам и может иметь уникальный эффект.

# Тип предмета (определяет, в какой слот надевается).
enum ItemType {
	WEAPON,    # Оружие
	ARMOR,     # Броня
	TRINKET    # Безделушка
}

# Редкость предмета.
enum Rarity {
	COMMON,    # Обычное
	RARE,      # Редкое
	LEGENDARY, # Легендарное
	UNIQUE     # Уникальное
}

# ─── Основные поля ─────────────────────────────────────────────

# Название предмета.
@export var item_name: String = "Предмет"
# Тип предмета (Оружие / Броня / Безделушка).
@export var item_type: ItemType = ItemType.WEAPON
# Редкость предмета.
@export var rarity: Rarity = Rarity.COMMON
# Иконка для интерфейса (необязательно).
@export var icon: Texture2D = null
# Описание / дополнительный текст.
@export_multiline var description: String = ""

# ─── Бонусы к статам (0 = не меняет) ──────────────────────────

# Здоровье (HP).
@export var bonus_max_hp: int = 0
# Урон.
@export var bonus_damage: int = 0
# Броня.
@export var bonus_armor: int = 0
# Инициатива.
@export var bonus_initiative: int = 0
# Точность.
@export var bonus_accuracy: int = 0
# Уклонение.
@export var bonus_evasion: int = 0
# Удача / Шанс крита (в долях, 0.05 = +5%).
@export var bonus_crit_chance: float = 0.0
# Величие.
@export var bonus_majesty: int = 0

# ─── Уникальный эффект ─────────────────────────────────────────

# Код уникального эффекта (как special_effect_type у персонажей).
# Пусто = нет уникального эффекта, только бонусы к статам.
# Примеры кодов (можно добавлять свои):
# "lifesteal"          — лечит на % от нанесённого урона
# "thorns"             — отражает часть полученного урона
# "cleanse_on_turn"    — снимает 1 дебафф в начале хода
# "extra_action"       — +1 действие (один раз за бой)
# "regen_aura"         — союзники рядом регенерируют HP
@export var effect: String = ""


## Возвращает название типа по-русски.
func get_type_name() -> String:
	match item_type:
		ItemType.WEAPON: return "Оружие"
		ItemType.ARMOR: return "Броня"
		ItemType.TRINKET: return "Безделушка"
	return "?"

## Возвращает название редкости по-русски.
func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "Обычное"
		Rarity.RARE: return "Редкое"
		Rarity.LEGENDARY: return "Легендарное"
		Rarity.UNIQUE: return "Уникальное"
	return "?"

## Возвращает true если предмет даёт хотя бы один бонус к статам.
func has_stat_bonuses() -> bool:
	return bonus_max_hp != 0 or bonus_damage != 0 or bonus_armor != 0 \
		or bonus_initiative != 0 or bonus_accuracy != 0 or bonus_evasion != 0 \
		or bonus_crit_chance != 0.0 or bonus_majesty != 0

## Возвращает строку со списком всех бонусов (для интерфейса/отладки).
func get_bonuses_text() -> String:
	var parts: Array = []
	if bonus_max_hp != 0:
		parts.append("HP %s%d" % ["+" if bonus_max_hp > 0 else "", bonus_max_hp])
	if bonus_damage != 0:
		parts.append("Урон %s%d" % ["+" if bonus_damage > 0 else "", bonus_damage])
	if bonus_armor != 0:
		parts.append("Броня %s%d" % ["+" if bonus_armor > 0 else "", bonus_armor])
	if bonus_initiative != 0:
		parts.append("Иниц. %s%d" % ["+" if bonus_initiative > 0 else "", bonus_initiative])
	if bonus_accuracy != 0:
		parts.append("Точн. %s%d" % ["+" if bonus_accuracy > 0 else "", bonus_accuracy])
	if bonus_evasion != 0:
		parts.append("Уклон. %s%d" % ["+" if bonus_evasion > 0 else "", bonus_evasion])
	if bonus_crit_chance != 0.0:
		parts.append("Удача %s%.0f%%" % ["+" if bonus_crit_chance > 0 else "", bonus_crit_chance * 100])
	if bonus_majesty != 0:
		parts.append("Величие %s%d" % ["+" if bonus_majesty > 0 else "", bonus_majesty])
	return ", ".join(parts)
