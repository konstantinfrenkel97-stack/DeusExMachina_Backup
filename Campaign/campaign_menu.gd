extends RefCounted
class_name CampaignMenu

## Меню паузы кампании: продолжить, сохранить/загрузить, настройки, помощь, выход.
##
## Выделено из campaign_screen.gd. Состояние боя/экрана и прочие методы — через `_screen.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _screen: CampaignScreen

func _init(owner_scene: CampaignScreen) -> void:
	_screen = owner_scene

func _on_back_pressed() -> void:
	_screen.get_tree().change_scene_to_file("res://main_menu.tscn")


# ════════════════════════════════════════════════════════════
#  Меню (верхний левый угол)
# ════════════════════════════════════════════════════════════

func _build_menu() -> void:
	_screen._menu_button = Button.new()
	_screen._menu_button.text = "☰ Меню"
	_screen._menu_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_screen._menu_button.offset_left = 10
	_screen._menu_button.offset_top = 10
	_screen._menu_button.custom_minimum_size = Vector2(120, 44)
	_screen._menu_button.add_theme_font_size_override("font_size", 18)
	_screen._menu_button.pressed.connect(_show_menu_popup)
	_screen.add_child(_screen._menu_button)

func _show_menu_popup() -> void:
	if _screen._menu_popup != null and is_instance_valid(_screen._menu_popup):
		_screen._menu_popup.queue_free()
	_screen._menu_popup = PopupPanel.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)

	for entry in [
		{"text": "Продолжить", "action": _menu_continue},
		{"text": "Сохранить", "action": _menu_save},
		{"text": "Загрузить", "action": _menu_load},
		{"text": "Настройки", "action": _menu_settings},
		{"text": "Помощь", "action": _menu_help},
		{"text": "Выход", "action": _menu_exit},
	]:
		var btn := Button.new()
		btn.text = entry["text"]
		btn.custom_minimum_size = Vector2(200, 44)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(entry["action"])
		vb.add_child(btn)

	_screen._menu_popup.add_child(vb)
	_screen.add_child(_screen._menu_popup)
	var btn_rect := _screen._menu_button.get_global_rect()
	_screen._menu_popup.position = Vector2(btn_rect.position.x, btn_rect.position.y + btn_rect.size.y + 4)
	_screen._menu_popup.popup()

func _menu_continue() -> void:
	_hide_menu_popup()

func _menu_save() -> void:
	_hide_menu_popup()
	_show_save_dialog()

func _menu_load() -> void:
	_hide_menu_popup()
	_show_load_dialog()

func _menu_settings() -> void:
	_hide_menu_popup()
	var panel := CampaignScreen.SettingsPanel.new()
	panel.close_requested.connect(panel.queue_free)
	panel.z_index = 2500
	_screen.add_child(panel)

func _menu_help() -> void:
	_hide_menu_popup()
	_screen.help.show_topics()

func _menu_exit() -> void:
	_hide_menu_popup()
	_screen.get_tree().change_scene_to_file("res://main_menu.tscn")

func _hide_menu_popup() -> void:
	if _screen._menu_popup != null and is_instance_valid(_screen._menu_popup):
		_screen._menu_popup.hide()


# ════════════════════════════════════════════════════════════
#  Диалог сохранения
# ════════════════════════════════════════════════════════════

func _show_save_dialog() -> void:
	_screen._close_dialog()
	_screen._dialog_overlay = _screen._make_overlay()

	var panel := _screen._make_centered_panel("Сохранить кампанию", Vector2(500, 460))

	var slots := SaveSystem.get_save_slots()
	var slot_list: VBoxContainer = null
	if not slots.is_empty():
		var existing_lbl := Label.new()
		existing_lbl.text = "Существующие сохранения (нажмите, чтобы перезаписать):"
		existing_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		existing_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		existing_lbl.add_theme_font_size_override("font_size", 14)
		panel.add_child(existing_lbl)

		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(460, 180)
		panel.add_child(scroll)

		slot_list = VBoxContainer.new()
		slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_list.add_theme_constant_override("separation", 6)
		scroll.add_child(slot_list)

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Введите название сохранения"
	name_edit.add_theme_font_size_override("font_size", 18)
	name_edit.custom_minimum_size = Vector2(360, 44)
	panel.add_child(name_edit)

	var status_label := Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(status_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)

	var save_btn := Button.new()
	save_btn.text = "Сохранить"
	save_btn.custom_minimum_size = Vector2(140, 44)
	save_btn.add_theme_font_size_override("font_size", 18)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.add_theme_font_size_override("font_size", 18)

	btn_row.add_child(save_btn)
	btn_row.add_child(cancel_btn)
	panel.add_child(btn_row)

	if slot_list != null:
		for slot_info in slots:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)

			var info_btn := Button.new()
			info_btn.text = "«%s»\n%s | Богов: %d" % [slot_info["slot"], slot_info["timestamp"], slot_info["gods_count"]]
			info_btn.add_theme_font_size_override("font_size", 14)
			info_btn.custom_minimum_size = Vector2(400, 44)
			info_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.add_child(info_btn)
			slot_list.add_child(row)

			var slot_name: String = slot_info["slot"]
			info_btn.pressed.connect(func():
				name_edit.text = slot_name
				status_label.text = "«%s» будет перезаписано при сохранении." % slot_name
				status_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
			)

	save_btn.pressed.connect(func():
		var slot := name_edit.text.strip_edges()
		if slot == "":
			status_label.text = "Введите название!"
			status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
			return
		var ok := SaveSystem.save_game(slot)
		if ok:
			_screen._close_dialog()
			_screen._show_notification("Игра сохранена")
		else:
			status_label.text = "Ошибка сохранения!"
			status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	)
	cancel_btn.pressed.connect(_screen._close_dialog)

	_screen.add_child(_screen._dialog_overlay)
	name_edit.grab_focus()


# ════════════════════════════════════════════════════════════
#  Диалог загрузки
# ════════════════════════════════════════════════════════════

func _show_load_dialog() -> void:
	_screen._close_dialog()
	_screen._dialog_overlay = _screen._make_overlay()

	var panel := _screen._make_centered_panel("Загрузить кампанию", Vector2(500, 400))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(460, 280)
	panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var slots := SaveSystem.get_save_slots()
	if slots.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Нет сохранений"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 20)
		list.add_child(empty_lbl)
	else:
		for slot_info in slots:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)

			var info_btn := Button.new()
			info_btn.text = "«%s»\n%s | Богов: %d" % [slot_info["slot"], slot_info["timestamp"], slot_info["gods_count"]]
			info_btn.add_theme_font_size_override("font_size", 16)
			info_btn.custom_minimum_size = Vector2(320, 50)
			info_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

			var load_btn := Button.new()
			load_btn.text = "Загрузить"
			load_btn.custom_minimum_size = Vector2(110, 50)
			load_btn.add_theme_font_size_override("font_size", 16)

			var del_btn := Button.new()
			del_btn.text = "✕"
			del_btn.custom_minimum_size = Vector2(40, 50)

			row.add_child(info_btn)
			row.add_child(load_btn)
			row.add_child(del_btn)
			list.add_child(row)

			var slot_name: String = slot_info["slot"]
			load_btn.pressed.connect(func():
				var ok := SaveSystem.load_game(slot_name)
				if ok:
					_screen._close_dialog()
					# Обновляем текущую вкладку.
					_screen._tabs._select_tab(_screen._tabs._current_tab_index())
				else:
					push_warning("Не удалось загрузить: " + slot_name)
			)
			info_btn.pressed.connect(load_btn.pressed.emit)
			del_btn.pressed.connect(func():
				SaveSystem.delete_save(slot_name)
				_screen._close_dialog()
				_show_load_dialog()
			)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.pressed.connect(_screen._close_dialog)
	panel.add_child(cancel_btn)

	_screen.add_child(_screen._dialog_overlay)


# ════════════════════════════════════════════════════════════
#  Вспомогательные методы для диалогов
# ════════════════════════════════════════════════════════════
