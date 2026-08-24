extends Button

var rich_tooltip_text: String = ""

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
const STAT_ICON_TOOLTIPS := {
	"health": "Здоровье",
	"attack": "Атака",
	"armor": "Броня",
	"initiative": "Инициатива",
	"accuracy": "Точность",
	"evasion": "Уклонение",
	"luck": "Удача",
	"glory": "Величие",
	"fantasy": "Фантазия",
}

func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(420, 0)
	label.text = _format_stat_icons(rich_tooltip_text if rich_tooltip_text != "" else for_text)
	margin.add_child(label)
	return panel

func _stat_icon_bbcode(stat_key: String) -> String:
	var path := str(STAT_ICON_PATHS.get(stat_key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return ""
	return "[img width=%d height=%d]%s[/img]" % [STAT_ICON_SIZE, STAT_ICON_SIZE, path]

func _escape_bbcode_text(text: String) -> String:
	return text.replace("[", "(").replace("]", ")")

func _format_stat_icons(text: String) -> String:
	var result := _escape_bbcode_text(text)
	var replacements := [
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
	for item in replacements:
		var word := str(item[0])
		var key := str(item[1])
		var icon := _stat_icon_bbcode(key)
		if icon != "":
			result = result.replace(word, icon)
	return result
