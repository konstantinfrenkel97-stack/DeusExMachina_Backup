extends Control

const FIRST_DIALOGUE_PATH := "res://Dialogues/Introduction/First_dialogue.tres"
const SECOND_DIALOGUE_PATH := "res://Dialogues/Introduction/Second_intro_dialogue.tres"
const THIRD_DIALOGUE_PATH := "res://Dialogues/Introduction/Third_intro_dialogue.tres"
const CAMPAIGN_SCREEN_PATH := "res://Campaign/campaign_screen.tscn"
const BG_WORLD := "res://Background/Campaign_Background.png"
const BG_CAMPAIGN := "res://Background/Campaign_Background.png"
const BG_LIBRARY := "res://Background/Library.png"
const MENU_BG_COLOR := Color(0.008, 0.008, 0.298, 1)
const MENU_BTN_HOVER_COLOR := Color(0.05, 0.05, 0.388, 1)
const MENU_BTN_PRESSED_COLOR := Color(0.078, 0.078, 0.43, 1)

var _dialog_overlay: Control

func _ready() -> void:
	var menu = $Center/VBoxContainer
	for btn in menu.get_children():
		btn.custom_minimum_size = Vector2(300, 64)
		btn.add_theme_font_size_override("font_size", 28)
		btn.add_theme_stylebox_override("normal", _make_menu_btn_style(MENU_BG_COLOR))
		btn.add_theme_stylebox_override("hover", _make_menu_btn_style(MENU_BTN_HOVER_COLOR))
		btn.add_theme_stylebox_override("pressed", _make_menu_btn_style(MENU_BTN_PRESSED_COLOR))
		btn.add_theme_stylebox_override("focus", _make_menu_btn_style(MENU_BG_COLOR))
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		btn.add_theme_color_override("font_focus_color", Color.WHITE)
	menu.add_theme_constant_override("separation", 18)
	menu.get_node("NewGameButton").pressed.connect(_on_new_game_pressed)
	menu.get_node("LoadButton").pressed.connect(_on_load_pressed)
	menu.get_node("StartButton").pressed.connect(_on_start_button_pressed)
	menu.get_node("MissionButton").pressed.connect(_on_mission_button_pressed)
	menu.get_node("ExitButton").pressed.connect(_on_exit_button_pressed)

func _make_menu_btn_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _on_new_game_pressed() -> void:
	if DialogueManager.is_active():
		return
	CampaignState.reset_all()
	if ResourceLoader.exists(FIRST_DIALOGUE_PATH):
		if DialogueManager.dialogue_finished.is_connected(_on_first_dialogue_finished):
			DialogueManager.dialogue_finished.disconnect(_on_first_dialogue_finished)
		DialogueManager.dialogue_finished.connect(_on_first_dialogue_finished, CONNECT_ONE_SHOT)
		DialogueManager.show_dialogue_path(FIRST_DIALOGUE_PATH, BG_LIBRARY)
		return
	_open_campaign_screen()

func _on_first_dialogue_finished(_dialogue_id: String) -> void:
	call_deferred("_play_second_dialogue")

func _play_second_dialogue() -> void:
	if ResourceLoader.exists(SECOND_DIALOGUE_PATH):
		if DialogueManager.dialogue_finished.is_connected(_on_second_dialogue_finished):
			DialogueManager.dialogue_finished.disconnect(_on_second_dialogue_finished)
		DialogueManager.dialogue_finished.connect(_on_second_dialogue_finished, CONNECT_ONE_SHOT)
		DialogueManager.show_dialogue_path(SECOND_DIALOGUE_PATH, BG_WORLD)
		return
	call_deferred("_play_third_dialogue")

func _on_second_dialogue_finished(_dialogue_id: String) -> void:
	call_deferred("_play_third_dialogue")

func _play_third_dialogue() -> void:
	if ResourceLoader.exists(THIRD_DIALOGUE_PATH):
		if DialogueManager.dialogue_finished.is_connected(_on_third_dialogue_finished):
			DialogueManager.dialogue_finished.disconnect(_on_third_dialogue_finished)
		DialogueManager.dialogue_finished.connect(_on_third_dialogue_finished, CONNECT_ONE_SHOT)
		DialogueManager.show_dialogue_path(THIRD_DIALOGUE_PATH, BG_CAMPAIGN)
		return
	call_deferred("_open_campaign_screen")

func _on_third_dialogue_finished(_dialogue_id: String) -> void:
	call_deferred("_open_campaign_screen")

func _open_campaign_screen() -> void:
	get_tree().change_scene_to_file(CAMPAIGN_SCREEN_PATH)

func _on_load_pressed() -> void:
	_show_load_dialog()

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://battle_setup.tscn")

func _on_mission_button_pressed() -> void:
	MissionState.requested_mission_path = ""
	MissionState.return_scene_path = ""
	get_tree().change_scene_to_file("res://Missions/mission_select.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _show_load_dialog() -> void:
	_close_dialog()
	_dialog_overlay = Control.new()
	_dialog_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	_dialog_overlay.add_child(bg)

	var wrapper := CenterContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog_overlay.add_child(wrapper)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 400)
	wrapper.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Загрузить кампанию"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(460, 260)
	vb.add_child(scroll)

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

			row.add_child(info_btn)
			row.add_child(load_btn)
			list.add_child(row)

			var slot_name: String = slot_info["slot"]
			var do_load := func():
				var ok := SaveSystem.load_game(slot_name)
				if ok:
					_close_dialog()
					get_tree().change_scene_to_file(CAMPAIGN_SCREEN_PATH)
				else:
					push_warning("Не удалось загрузить: " + slot_name)
			load_btn.pressed.connect(do_load)
			info_btn.pressed.connect(load_btn.pressed.emit)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.pressed.connect(_close_dialog)
	vb.add_child(cancel_btn)

	add_child(_dialog_overlay)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_close_dialog()

func _close_dialog() -> void:
	if _dialog_overlay != null and is_instance_valid(_dialog_overlay):
		_dialog_overlay.queue_free()
		_dialog_overlay = null
