extends Button

var rich_tooltip_text: String = ""
## Если true, rich_tooltip_text уже валидный BBCode (собран кодом, доверенный) —
## показываем как есть, без экранирования/замены слов на иконки (иначе уже
## вставленные теги [b]/[img] превратятся в текст "(b)"/"(img...)").
var rich_tooltip_is_bbcode: bool = false

const _Formatter := preload("res://Scripts/stat_icon_formatter.gd")

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
	if rich_tooltip_is_bbcode and rich_tooltip_text != "":
		label.text = rich_tooltip_text
	else:
		label.text = _Formatter.format_text(rich_tooltip_text if rich_tooltip_text != "" else for_text)
	margin.add_child(label)
	return panel
