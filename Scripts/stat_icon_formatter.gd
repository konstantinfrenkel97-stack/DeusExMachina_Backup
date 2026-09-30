extends RefCounted
class_name StatIconFormatter

## Общая утилита: заменяет слова характеристик ("Броня", "Здоровье", ...) в тексте на
## инлайн-иконки статов (BBCode [img]). Используется и во всплывающих Godot-тултипах
## (см. stat_icon_tooltip_button.gd), и в самодельных информационных панелях.

const STAT_ICON_SIZE := 22
const STAT_ICON_PATHS := {
	"health": "res://Icons/Stats/Health.png",
	"attack": "res://Icons/Stats/Attack.png",
	"armor": "res://Icons/Stats/Armor.png",
	"initiative": "res://Icons/Stats/Initiative.png",
	"accuracy": "res://Icons/Stats/Accuracy.png",
	"evasion": "res://Icons/Stats/Evasion.png",
	"luck": "res://Icons/Stats/Luck.png",
	"glory": "res://Icons/Stats/Glory.png",
	"fantasy": "res://Icons/fantasy_icon.png",
}

const REPLACEMENTS := [
	["All_Allies_buff_accuracy", "accuracy"],
	["all_allies_buff_accuracy", "accuracy"],
	["target_buff_accuracy", "accuracy"],
	["self_buff_accuracy", "accuracy"],
	["enemy_debuff_accuracy", "accuracy"],
	["target_debuff_accuracy", "accuracy"],
	["dispel_accuracy_debuffs", "accuracy"],
	["buff_accuracy", "accuracy"],
	["debuff_accuracy", "accuracy"],
	["All_Allies_buff_evasion", "evasion"],
	["target_buff_evasion", "evasion"],
	["self_buff_evasion", "evasion"],
	["target_debuff_evasion", "evasion"],
	["buff_evasion", "evasion"],
	["debuff_evasion", "evasion"],
	["All_Allies_buff_armor", "armor"],
	["target_buff_armor", "armor"],
	["self_buff_armor", "armor"],
	["target_debuff_armor", "armor"],
	["buff_armor", "armor"],
	["debuff_armor", "armor"],
	["All_Allies_buff_damage", "attack"],
	["target_buff_damage", "attack"],
	["self_buff_damage", "attack"],
	["target_debuff_damage", "attack"],
	["buff_damage", "attack"],
	["debuff_damage", "attack"],
	["All_Allies_buff_initiative", "initiative"],
	["target_buff_initiative", "initiative"],
	["self_buff_initiative", "initiative"],
	["buff_initiative", "initiative"],
	["debuff_initiative", "initiative"],
	["crit_chance", "luck"],
	["buff_crit", "luck"],
	["debuff_crit", "luck"],
	["max_hp", "health"],
	["Крит. шанс", "luck"],
	["Здоровье", "health"],
	["здоровья", "health"],
	["здоровью", "health"],
	["здоровье", "health"],
	["HP", "health"],
	["health", "health"],
	["Инициатива", "initiative"],
	["инициативы", "initiative"],
	["инициативе", "initiative"],
	["инициатива", "initiative"],
	["initiative", "initiative"],
	["Точность", "accuracy"],
	["точности", "accuracy"],
	["точность", "accuracy"],
	["accuracy", "accuracy"],
	["Уклонение", "evasion"],
	["уклонения", "evasion"],
	["уклонению", "evasion"],
	["уклонение", "evasion"],
	["evasion", "evasion"],
	["Величие", "glory"],
	["величия", "glory"],
	["величию", "glory"],
	["величие", "glory"],
	["glory", "glory"],
	["Броня", "armor"],
	["брони", "armor"],
	["броне", "armor"],
	["броня", "armor"],
	["armor", "armor"],
	["Атака", "attack"],
	["атаки", "attack"],
	["атаке", "attack"],
	["атака", "attack"],
	["attack", "attack"],
	["damage", "attack"],
	["Крит", "luck"],
	["криту", "luck"],
	["удачи", "luck"],
	["удаче", "luck"],
	["Удача", "luck"],
	["удача", "luck"],
	["crit", "luck"],
	["Фантазии", "fantasy"],
	["фантазии", "fantasy"],
	["Фантазия", "fantasy"],
	["фантазия", "fantasy"],
	["фантазию", "fantasy"],
	["фантазией", "fantasy"],
]

## Кружки позиций в тултипах умений. В тексте тултипа стоят токены (фигурные скобки
## переживают escape_bbcode_text), format_text() превращает их в [img].
const POSITION_ICON_SIZE := 22
const POSITION_ICON_PATHS := {
	"{pos_off}": "res://Icons/Positions/pos_off.png",
	"{pos_from}": "res://Icons/Positions/pos_from.png",
	"{pos_target}": "res://Icons/Positions/pos_target.png",
}

## 4 кружка в том порядке, в каком линии стоят на поле боя: у героев линия 1 справа
## (4 3 2 1), у врагов слева (1 2 3 4). mirrored = true для стороны героев.
static func position_dots(flags: Array, on_token: String, mirrored: bool) -> String:
	var dots: Array[String] = []
	for i in range(4):
		var active: bool = i < flags.size() and bool(flags[i])
		dots.append(on_token if active else "{pos_off}")
	if mirrored:
		dots.reverse()
	return " ".join(dots)

## Строки «Доступно с линий» / «Цель на линиях» для тултипа умения.
static func ability_position_lines(ability: AbilityResource, user_is_enemy: bool) -> Array[String]:
	var lines: Array[String] = []
	# Сторона пользователя: у героев зеркальный порядок.
	lines.append("Доступно с линий: %s" % position_dots(ability.usable_from_positions, "{pos_from}", not user_is_enemy))
	if ability.target_type != "Self" and ability.targetable_positions.has(true):
		var targets_own_side: bool = ability.target_type == "Ally" or ability.target_type == "All_Allies"
		var target_is_hero_side: bool = targets_own_side != user_is_enemy
		lines.append("Цель на линиях: %s" % position_dots(ability.targetable_positions, "{pos_target}", target_is_hero_side))
	return lines

static func stat_icon_bbcode(stat_key: String) -> String:
	var path := str(STAT_ICON_PATHS.get(stat_key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return ""
	return "[img width=%d height=%d]%s[/img]" % [STAT_ICON_SIZE, STAT_ICON_SIZE, path]

static func escape_bbcode_text(text: String) -> String:
	return text.replace("[", "(").replace("]", ")")

## Заменяет слова характеристик в тексте на инлайн-иконки (BBCode). Текст должен
## отображаться в RichTextLabel с bbcode_enabled = true.
static func format_text(text: String) -> String:
	var result := escape_bbcode_text(text)
	for token in POSITION_ICON_PATHS:
		if result.contains(token):
			result = result.replace(token, "[img width=%d height=%d]%s[/img]" % [POSITION_ICON_SIZE, POSITION_ICON_SIZE, POSITION_ICON_PATHS[token]])
	for item in REPLACEMENTS:
		var word := str(item[0])
		var key := str(item[1])
		var icon := stat_icon_bbcode(key)
		if icon != "":
			result = result.replace(word, icon)
	return result
