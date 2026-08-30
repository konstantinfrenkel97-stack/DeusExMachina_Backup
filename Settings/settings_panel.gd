extends Control
class_name SettingsPanel
## Общий экран настроек — вызывается и из battle_scene.gd, и из campaign_screen.gd
## (там, где раньше была заглушка "Раздел «Настройки» пока в разработке").
## Строится процедурно, как и остальные оверлеи в проекте; самодостаточен —
## достаточно SettingsPanel.new() + add_child(panel) в любом экране.
## Настоящее хранилище/применение настроек — в автозагрузке GameSettings.

signal close_requested

const LANGUAGE_OPTIONS: Array = [["ru", "Русский"], ["en", "English"], ["es", "Español"]]

var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 500

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	_apply_panel_style(panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Настройки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	_add_section_label(vbox, "Звук")
	_master_slider = _add_slider_row(vbox, "Общая громкость", GameSettings.master_volume, GameSettings.set_master_volume)
	_add_checkbox_row(vbox, "Выключить звук", GameSettings.master_muted, GameSettings.set_master_muted)
	_music_slider = _add_slider_row(vbox, "Музыка", GameSettings.music_volume, GameSettings.set_music_volume)
	_sfx_slider = _add_slider_row(vbox, "Звуковые эффекты", GameSettings.sfx_volume, GameSettings.set_sfx_volume)

	_add_section_label(vbox, "Экран")
	_add_checkbox_row(vbox, "Полноэкранный режим", GameSettings.fullscreen, GameSettings.set_fullscreen)

	_add_section_label(vbox, "Геймплей")
	_add_checkbox_row(vbox, "Подтверждать сдачу боя", GameSettings.confirm_before_surrender, GameSettings.set_confirm_before_surrender)
	_add_checkbox_row(vbox, "Боевой лог развёрнут по умолчанию", GameSettings.combat_log_expanded_default, GameSettings.set_combat_log_expanded_default)
	_add_battle_speed_row(vbox)
	_add_language_row(vbox)

	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.custom_minimum_size = Vector2(0, 48)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func(): close_requested.emit())
	vbox.add_child(close_btn)


func _apply_panel_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.12, 0.98)
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 4
	style.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", style)


func _add_section_label(vbox: VBoxContainer, text: String) -> void:
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	vbox.add_child(label)


func _add_slider_row(vbox: VBoxContainer, label_text: String, initial: float, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = roundf(initial * 100.0)
	slider.custom_minimum_size = Vector2(200, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = "%d%%" % int(slider.value)
	value_label.custom_minimum_size = Vector2(48, 0)
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float):
		value_label.text = "%d%%" % int(v)
		on_change.call(v / 100.0)
	)
	return slider


func _add_checkbox_row(vbox: VBoxContainer, label_text: String, initial: bool, on_change: Callable) -> CheckBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var check := CheckBox.new()
	check.button_pressed = initial
	row.add_child(check)

	var label := Label.new()
	label.text = label_text
	row.add_child(label)

	check.toggled.connect(func(pressed: bool): on_change.call(pressed))
	return check


func _add_battle_speed_row(vbox: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var label := Label.new()
	label.text = "Скорость боя"
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_index := 0
	for i in range(GameSettings.BATTLE_SPEED_OPTIONS.size()):
		var speed: float = GameSettings.BATTLE_SPEED_OPTIONS[i]
		option.add_item("x%s" % String.num(speed, 1).rstrip("0").rstrip("."))
		if is_equal_approx(speed, GameSettings.battle_speed):
			current_index = i
	option.selected = current_index
	option.item_selected.connect(func(index: int):
		GameSettings.set_battle_speed(GameSettings.BATTLE_SPEED_OPTIONS[index])
	)
	row.add_child(option)


func _add_language_row(vbox: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var label := Label.new()
	label.text = "Язык"
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_index := 0
	for i in range(LANGUAGE_OPTIONS.size()):
		var entry: Array = LANGUAGE_OPTIONS[i]
		option.add_item(str(entry[1]))
		if str(entry[0]) == GameSettings.language:
			current_index = i
	option.selected = current_index
	option.item_selected.connect(func(index: int):
		GameSettings.set_language(str(LANGUAGE_OPTIONS[index][0]))
	)
	row.add_child(option)


## Правый клик = закрыть, как и остальные оверлеи в проекте.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		close_requested.emit()
		accept_event()
