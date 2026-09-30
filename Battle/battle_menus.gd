extends RefCounted
class_name BattleMenus

## Меню боя: настройки, помощь, загрузка, сдача, обучающие подсказки, свёртка журнала.
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

## Первый бой игрока в его первом прохождении: показывает 3 подсказки подряд
## (инициатива, способности/ждать/пропустить, заклинания) — см.
## TutorialTexts.battle_intro_hints(). Одноразово, флаг не сбрасывается.
## Вторая часть той же обучающей последовательности (цели/линии, характеристики,
## величие) показывается позже, при первом выборе способности — см.
## _show_battle_targeting_tutorial_if_needed().
func _show_battle_intro_tutorial_if_needed() -> void:
	if not BattleScene.BATTLE_TUTORIALS_ENABLED:
		return
	if CampaignState.battle_tutorial_intro_shown:
		return
	CampaignState.battle_tutorial_intro_shown = true
	_show_blocking_tutorial_sequence(TutorialTexts.battle_intro_hints())

## Вторая часть обучающей последовательности первого боя — при первом выборе
## способности, требующей ручного выбора цели (обычная цель или позиция для
## марки): цели/линии, характеристики, величие. См. TutorialTexts.battle_targeting_hints().
func _show_battle_targeting_tutorial_if_needed() -> void:
	if not BattleScene.BATTLE_TUTORIALS_ENABLED:
		return
	if CampaignState.battle_tutorial_targeting_shown:
		return
	CampaignState.battle_tutorial_targeting_shown = true
	_show_blocking_tutorial_sequence(TutorialTexts.battle_targeting_hints())

## Первая подсказка о новой локации за дверью — ТОЛЬКО в первом бою, который
## реально проходит на такой локации (за дверью). Первый бой игрока вообще
## (First_battle) для неё не считается, даже если он почему-то пришёл с
## location_id (напр. если игрок пропустил Ад стартовую миссию кнопкой у
## портрета Мифа — см. _on_skip_first_mission_button_pressed в campaign_screen.gd
## — тогда battle_tutorial_intro_shown ещё false, и эта подсказка откладывается
## до следующего реального боя за дверью, вместо того чтобы наложиться на
## обучающую последовательность первого боя).
func _show_location_visited_hint_if_needed(location_id: String) -> void:
	if not BattleScene.BATTLE_TUTORIALS_ENABLED:
		return
	if not CampaignState.battle_tutorial_intro_shown:
		return
	if CampaignState.visited_locations.has(location_id):
		return
	CampaignState.visited_locations.append(location_id)
	_show_blocking_tutorial_hint(TutorialTexts.LOCATION_PROPERTIES_HINT, "Всё понятно")

## Обёртки над TutorialHint.present()/show_sequence(), которые держат
## _active_tutorial_hints синхронизированным — см. объявление переменной выше
## и все места, где она проверяется (ability/wait/skip/заклинания/ПКМ-отмена).
func _show_blocking_tutorial_hint(text: String, button_text: String = "Понятно") -> void:
	if not BattleScene.BATTLE_TUTORIALS_ENABLED:
		return
	_scene._adjust_tutorial_hint_count(1)
	var hint := TutorialHint.present(_scene, text, button_text)
	if hint == null:
		_scene._adjust_tutorial_hint_count(-1)
		return
	hint.dismissed.connect(func(): _scene._adjust_tutorial_hint_count(-1))

func _show_blocking_tutorial_sequence(steps: Array, final_button_text: String = "Понятно") -> void:
	if not BattleScene.BATTLE_TUTORIALS_ENABLED:
		return
	_scene._adjust_tutorial_hint_count(1)
	TutorialHint.show_sequence(_scene, steps, final_button_text, func(): _scene._adjust_tutorial_hint_count(-1))

## Создаёт кнопку-шестерёнку (верхний левый угол) с меню: «Настройки» и «Сдаться».
func _setup_settings_button():
	var mb = MenuButton.new()
	mb.name = "SettingsButton"
	mb.text = "⚙"
	mb.position = Vector2(8, 2)
	mb.size = Vector2(40, 30)
	mb.z_index = 200
	mb.add_theme_font_size_override("font_size", 22)
	var popup = mb.get_popup()
	popup.add_item("Настройки", 0)
	popup.add_item("Помощь", 1)
	popup.add_item("Загрузить", 3)
	popup.add_item("Сдаться", 2)
	popup.id_pressed.connect(_on_settings_menu_item)
	_scene.get_node("BattleUI").add_child(mb)

## Круглая золотая кнопка "?" внизу слева (у самого левого героя, позиция 4) —
## быстрый доступ к тем же подсказкам, что и пункт "Помощь" в меню настроек.
func _setup_help_button() -> void:
	var btn := HelpButtonFactory.create()
	btn.name = "HelpButton"
	var vp := _scene.get_viewport().get_visible_rect().size
	# Отступ снизу маленький: выше заканчивается ряд "Тактика/Пропуск хода" (~y=669 при 720).
	btn.position = Vector2(16.0, vp.y - HelpButtonFactory.DIAMETER - 4.0)
	btn.z_index = 200
	btn.pressed.connect(_show_help_topics)
	_scene.get_node("BattleUI").add_child(btn)

## Обработка пунктов меню настроек.
func _on_settings_menu_item(id: int) -> void:
	match id:
		0:
			_show_settings_panel()
		1:
			_show_help_topics()
		2:
			_surrender()
		3:
			_show_battle_load_dialog()

func _show_settings_panel() -> void:
	var panel := SettingsPanel.new()
	panel.close_requested.connect(panel.queue_free)
	panel.z_index = 1500
	_scene.get_node("BattleUI").add_child(panel)

## Загрузка сохранения прямо из боя: список слотов (как в кампании/главном меню),
## после загрузки — переход на экран кампании (в бою нет смысла обновлять UI на месте).
func _show_battle_load_dialog() -> void:
	var overlay := ColorRect.new()
	overlay.name = "BattleLoadOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.74)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1500
	_scene.get_node("BattleUI").add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 400)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Загрузить сохранение"
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
					_scene.get_tree().change_scene_to_file("res://Campaign/campaign_screen.tscn")
				else:
					push_warning("Не удалось загрузить: " + slot_name)
			load_btn.pressed.connect(do_load)
			info_btn.pressed.connect(load_btn.pressed.emit)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.pressed.connect(overlay.queue_free)
	vb.add_child(cancel_btn)

func _help_topics() -> Dictionary:
	return {
		"Кампания": "На экране кампании выбираются разделы, открываются комнаты и запускаются миссии. Правый клик закрывает текущее окно или возвращает назад.",
		"Миссии": "В миссиях выбирается отряд богов, затем проходят сцены. Варианты могут требовать конкретного бога, проверять характеристику, выдавать награды или запускать бой.",
		"Бой": "Бой идет по очереди хода. Выберите способность или заклинание, затем цель. Если нужно отменить выбор, нажмите правую кнопку мыши.",
		"Способности": "Способности богов и врагов имеют позиции применения, цель, стоимость и эффекты. Наведение на кнопку показывает подробное описание.",
		"Заклинания": "Заклинания тратят фантазию. Некоторые доступны только в отдельных локациях. Лимит применений за раунд зависит от правил боя.",
		"Эффекты": "Баффы, дебаффы, стойки и уникальные метки отображаются иконками около персонажа. Наведение на иконку показывает активные эффекты.",
		TutorialTexts.REQUIRED_GOD_HELP_TITLE: TutorialTexts.REQUIRED_GOD_HELP_TEXT,
		TutorialTexts.POSITION_PRIORITY_HELP_TITLE: TutorialTexts.POSITION_PRIORITY_HELP_TEXT,
	}

func _show_help_topics() -> void:
	_clear_help_overlay()
	_scene._help_showing_topic = false
	_scene._help_overlay = _make_help_overlay()
	var panel := _make_help_panel(_scene._help_overlay)
	var root := _make_help_root(panel)
	var title := Label.new()
	title.text = "Помощь"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)
	var topics := _help_topics()
	for topic_name in topics.keys():
		var btn := Button.new()
		btn.text = str(topic_name)
		btn.custom_minimum_size = Vector2(0, 54)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_show_help_topic.bind(str(topic_name), str(topics[topic_name])))
		root.add_child(btn)
	var disable_btn := Button.new()
	disable_btn.text = "Убрать подсказки"
	disable_btn.custom_minimum_size = Vector2(0, 54)
	disable_btn.add_theme_font_size_override("font_size", 22)
	disable_btn.pressed.connect(_confirm_disable_tutorial)
	root.add_child(disable_btn)
	var back_btn := Button.new()
	back_btn.text = "Назад"
	back_btn.custom_minimum_size = Vector2(0, 54)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(_clear_help_overlay)
	root.add_child(back_btn)

## "Убрать подсказки" — то же подтверждение, что в Campaign/campaign_help.gd
## ::_confirm_disable_tutorial() и Scripts/tutorial_hint.gd::_on_disable_pressed.
func _confirm_disable_tutorial() -> void:
	var confirm_root := ColorRect.new()
	confirm_root.color = Color(0.0, 0.0, 0.0, 0.5)
	confirm_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_root.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_root.z_index = 1600
	_scene.get_node("BattleUI").add_child(confirm_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var msg := Label.new()
	msg.text = "Отключить все обучающие подсказки? Включить их обратно можно в Настройках."
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 18)
	vb.add_child(msg)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.custom_minimum_size = Vector2(160, 46)
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.pressed.connect(func(): confirm_root.queue_free())
	row.add_child(cancel_btn)

	var yes_btn := Button.new()
	yes_btn.text = "Да, отключить"
	yes_btn.custom_minimum_size = Vector2(160, 46)
	yes_btn.add_theme_font_size_override("font_size", 16)
	yes_btn.pressed.connect(func():
		CampaignState.tutorial_disabled = true
		confirm_root.queue_free()
	)
	row.add_child(yes_btn)

func _show_help_topic(topic_title: String, topic_text: String) -> void:
	_clear_help_overlay()
	_scene._help_showing_topic = true
	_scene._help_overlay = _make_help_overlay()
	var panel := _make_help_panel(_scene._help_overlay)
	var root := _make_help_root(panel)
	var title := Label.new()
	title.text = topic_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)
	var text_label := RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = false
	text_label.scroll_active = true
	text_label.custom_minimum_size = Vector2(720, 360)
	text_label.add_theme_font_size_override("normal_font_size", 24)
	text_label.text = topic_text
	root.add_child(text_label)
	var back_btn := Button.new()
	back_btn.text = "Назад"
	back_btn.custom_minimum_size = Vector2(0, 54)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(_show_help_topics)
	root.add_child(back_btn)

func _make_help_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.name = "HelpOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.74)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000
	_scene.get_node("BattleUI").add_child(overlay)
	return overlay

func _make_help_panel(parent: Control) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 560)
	center.add_child(panel)
	return panel

func _make_help_root(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	return root

func _handle_help_back() -> bool:
	if _scene._help_overlay == null or not is_instance_valid(_scene._help_overlay):
		return false
	if _scene._help_showing_topic:
		_show_help_topics()
	else:
		_clear_help_overlay()
	return true

func _clear_help_overlay() -> void:
	if _scene._help_overlay != null and is_instance_valid(_scene._help_overlay):
		_scene._help_overlay.queue_free()
	_scene._help_overlay = null
	_scene._help_showing_topic = false

func _setup_combat_log_toggle_button() -> void:
	var ui_layer: Node = _scene.get_node_or_null("BattleUI")
	if ui_layer == null:
		return
	if _scene._combat_log_toggle_button == null:
		var existing: Node = _scene.get_node_or_null("BattleUI/CombatLogToggleButton")
		if existing is Button:
			_scene._combat_log_toggle_button = existing
		else:
			_scene._combat_log_toggle_button = Button.new()
			_scene._combat_log_toggle_button.name = "CombatLogToggleButton"
			ui_layer.add_child(_scene._combat_log_toggle_button)
	_scene._combat_log_toggle_button.size = Vector2(76.0, 30.0)
	_scene._combat_log_toggle_button.custom_minimum_size = _scene._combat_log_toggle_button.size
	_scene._combat_log_toggle_button.z_index = 220
	_scene._combat_log_toggle_button.focus_mode = Control.FOCUS_NONE
	_scene._combat_log_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_scene._combat_log_toggle_button.add_theme_font_size_override("font_size", 16)
	if not _scene._combat_log_toggle_button.pressed.is_connected(_on_combat_log_toggle_pressed):
		_scene._combat_log_toggle_button.pressed.connect(_on_combat_log_toggle_pressed)
	_apply_combat_log_collapsed_state()

func _on_combat_log_toggle_pressed() -> void:
	_scene._combat_log_collapsed = not _scene._combat_log_collapsed
	_apply_combat_log_collapsed_state()

func _apply_combat_log_collapsed_state() -> void:
	if _scene.combat_log_panel:
		_scene.combat_log_panel.visible = not _scene._combat_log_collapsed
	if _scene._combat_log_toggle_button:
		_scene._combat_log_toggle_button.text = "Лог +" if _scene._combat_log_collapsed else "Лог -"
		_position_combat_log_toggle_button()

func _position_combat_log_toggle_button() -> void:
	if _scene._combat_log_toggle_button == null:
		return
	if _scene._combat_log_collapsed or _scene.combat_log_panel == null:
		_scene._combat_log_toggle_button.position = Vector2(56.0, 2.0)
	else:
		var panel_height: float = _scene.combat_log_panel.size.y
		if panel_height <= 0.0:
			panel_height = 200.0
		_scene._combat_log_toggle_button.position = Vector2(_scene.combat_log_panel.position.x, _scene.combat_log_panel.position.y + panel_height + 8.0)

## Сдаться: немедленно окончить бой и вернуться в главное меню.
func _surrender() -> void:
	if GameSettings.confirm_before_surrender:
		_show_surrender_confirm()
		return
	_do_surrender()

func _do_surrender() -> void:
	_scene.battle_running = false
	_scene.waiting_for_player = false
	_scene.active_unit = null
	_scene._field._update_active_highlight()
	if CombatManager.is_mission_battle:
		_apply_surrender_forgetting()
		_scene._set_status("Поражение! Отряд сдался. Возврат в главное меню...")
		_scene._log_combat("Игрок сдался. Бой окончен.")
	else:
		_scene._log_combat("Игрок сдался. Бой окончен.")
	_scene._outcome._end_battle(false)

## Сдача — не просто побег: весь ЖИВОЙ отряд миссии получает забвение за то, что бросил
## бой (столько же, сколько получает погибший в бою герой — см. _apply_death_fading()).
## Погибших к этому моменту героев не трогаем: им уже начислит своё _apply_death_fading(),
## вызываемый следом из _end_battle() — иначе штраф удвоился бы.
func _apply_surrender_forgetting() -> void:
	for hero_value in _scene.heroes_team:
		var hero: Combatant = hero_value as Combatant
		if hero == null or hero.current_hp <= 0:
			continue
		if hero.source_resource_path == "":
			continue
		CampaignState.add_god_forgetting(hero.source_resource_path, 2.0)
		MissionState.add_hero_forgetting_gained(hero.source_resource_path, 2.0)

## Диалог подтверждения сдачи (см. GameSettings.confirm_before_surrender).
func _show_surrender_confirm() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 1500
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var label := Label.new()
	label.text = "Сдаться и завершить бой?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)

	var yes_btn := Button.new()
	yes_btn.text = "Сдаться"
	yes_btn.custom_minimum_size = Vector2(140, 44)
	yes_btn.pressed.connect(func():
		overlay.queue_free()
		_do_surrender()
	)
	buttons.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Отмена"
	no_btn.custom_minimum_size = Vector2(140, 44)
	no_btn.pressed.connect(overlay.queue_free)
	buttons.add_child(no_btn)

	_scene.get_node("BattleUI").add_child(overlay)
