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
var _voice_slider: HSlider
var _window_size_option: OptionButton
var _window_size_row: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 500

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	_apply_panel_style(panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 300)
	vbox.add_child(tabs)

	var sound_tab := _add_tab(tabs, "Звук")
	_master_slider = _add_slider_row(sound_tab, "Общая громкость", GameSettings.master_volume, GameSettings.set_master_volume)
	_add_checkbox_row(sound_tab, "Выключить звук", GameSettings.master_muted, GameSettings.set_master_muted)
	_music_slider = _add_slider_row(sound_tab, "Музыка", GameSettings.music_volume, GameSettings.set_music_volume)
	_sfx_slider = _add_slider_row(sound_tab, "Звуковые эффекты", GameSettings.sfx_volume, GameSettings.set_sfx_volume)
	_voice_slider = _add_slider_row(sound_tab, "Голоса богов", GameSettings.voice_volume, GameSettings.set_voice_volume)

	var video_tab := _add_tab(tabs, "Графика")
	_window_size_row = _add_window_size_row(video_tab)
	_add_checkbox_row(video_tab, "Полноэкранный режим", GameSettings.fullscreen, func(pressed: bool):
		GameSettings.set_fullscreen(pressed)
		_update_window_size_row_state()
	)
	_add_checkbox_row(video_tab, "Вертикальная синхронизация", GameSettings.vsync, GameSettings.set_vsync)
	_add_max_fps_row(video_tab)
	_update_window_size_row_state()

	var game_tab := _add_tab(tabs, "Игра")
	_add_language_row(game_tab)
	_add_battle_speed_row(game_tab)
	_add_checkbox_row(game_tab, "Подтверждать сдачу боя", GameSettings.confirm_before_surrender, GameSettings.set_confirm_before_surrender)
	_add_checkbox_row(game_tab, "Боевой лог развёрнут по умолчанию", GameSettings.combat_log_expanded_default, GameSettings.set_combat_log_expanded_default)
	# Глобальная настройка: её же выключает кнопка "Убрать подсказки" в справке (кнопка "?"),
	# а здесь подсказки можно снова включить.
	_add_checkbox_row(game_tab, "Показывать обучающие подсказки", GameSettings.tutorial_hints_enabled, GameSettings.set_tutorial_hints_enabled)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)

	var reset_btn := Button.new()
	reset_btn.text = "По умолчанию"
	reset_btn.custom_minimum_size = Vector2(0, 48)
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.add_theme_font_size_override("font_size", 20)
	reset_btn.pressed.connect(_on_reset_pressed)
	buttons.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.custom_minimum_size = Vector2(0, 48)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func(): close_requested.emit())
	buttons.add_child(close_btn)


## Сбрасывает звук/экран/геймплей и перерисовывает панель с новыми значениями.
func _on_reset_pressed() -> void:
	GameSettings.reset_to_defaults()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_ready.call_deferred()


func _add_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = title
	box.add_theme_constant_override("separation", 14)
	var margin := MarginContainer.new()
	margin.name = title
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_child(box)
	tabs.add_child(margin)
	return box


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


## Размер окна (только в оконном режиме): показываются только размеры, влезающие в экран.
func _add_window_size_row(vbox: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var label := Label.new()
	label.text = "Размер окна"
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)

	_window_size_option = OptionButton.new()
	_window_size_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var available: Array[Vector2i] = GameSettings.get_available_window_sizes()
	var current_index := 0
	for i in range(available.size()):
		_window_size_option.add_item("%d × %d" % [available[i].x, available[i].y])
		_window_size_option.set_item_metadata(i, GameSettings.WINDOW_SIZES.find(available[i]))
		if GameSettings.WINDOW_SIZES.find(available[i]) == GameSettings.window_size_index:
			current_index = i
	_window_size_option.selected = current_index
	_window_size_option.item_selected.connect(func(index: int):
		GameSettings.set_window_size_index(int(_window_size_option.get_item_metadata(index)))
	)
	row.add_child(_window_size_option)
	return row


## Размер окна имеет смысл только вне полноэкранного режима.
func _update_window_size_row_state() -> void:
	if _window_size_option != null:
		_window_size_option.disabled = GameSettings.fullscreen


func _add_max_fps_row(vbox: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var label := Label.new()
	label.text = "Лимит кадров"
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_index := 0
	for i in range(GameSettings.MAX_FPS_OPTIONS.size()):
		var fps: int = GameSettings.MAX_FPS_OPTIONS[i]
		option.add_item("Без ограничения" if fps == 0 else "%d FPS" % fps)
		if fps == GameSettings.max_fps:
			current_index = i
	option.selected = current_index
	option.item_selected.connect(func(index: int):
		GameSettings.set_max_fps(GameSettings.MAX_FPS_OPTIONS[index])
	)
	row.add_child(option)


func _add_language_row(vbox: VBoxContainer) -> void:
	# Показываем только языки, для которых есть переводы (см. Localization.get_available_locales).
	var available: Array[String] = Localization.get_available_locales()
	if available.size() < 2:
		return
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
	var shown_locales: Array[String] = []
	for entry: Array in LANGUAGE_OPTIONS:
		if not available.has(str(entry[0])):
			continue
		option.add_item(str(entry[1]))
		if str(entry[0]) == GameSettings.language:
			current_index = shown_locales.size()
		shown_locales.append(str(entry[0]))
	option.selected = current_index
	option.item_selected.connect(func(index: int):
		GameSettings.set_language(shown_locales[index])
	)
	row.add_child(option)


## Правый клик = закрыть, как и остальные оверлеи в проекте.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		close_requested.emit()
		accept_event()
