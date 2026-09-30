extends RefCounted
class_name CampaignRoster

## Ростер богов и полоса ресурсов (валюты, мысли, страницы, портрет Мифа).
##
## Выделено из campaign_screen.gd. Состояние боя/экрана и прочие методы — через `_screen.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _screen: CampaignScreen

func _init(owner_scene: CampaignScreen) -> void:
	_screen = owner_scene

## Полоса ресурсов в нижней панели: 5 эссенций + мысли.
## Каждая пара — иконка слева, количество справа.
func _build_currency_bar(parent: Node) -> void:
	_screen._currency_amount_labels.clear()
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 22)
	parent.add_child(bar)
	for path in CampaignScreen._CURRENCY_PATHS:
		var res = load(path)
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		# Иконки эссенций обрезаны почти впритык к рисунку (без полей), а иконка мыслей —
		# нет, поэтому в общем боксе одинакового размера эссенции выглядели бы крупнее.
		# Уменьшаем именно эссенции, чтобы визуально совпадали по размеру с мыслями.
		icon.custom_minimum_size = Vector2(72, 72) if path == CampaignScreen.THOUGHTS_PATH else Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if res and res.icon:
			icon.texture = res.icon
		pair.add_child(icon)
		var amt := Label.new()
		amt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amt.add_theme_font_size_override("font_size", 20)
		if res:
			amt.text = str(CampaignState.get_currency_amount(path))
			amt.tooltip_text = res.name
		else:
			amt.text = "0"
		pair.add_child(amt)
		_screen._currency_amount_labels.append(amt)
		bar.add_child(pair)
	_add_myth_face_to_currency_bar(bar)

## Обновить отображаемые количества (вызвать после изменения amount ресурса).
func _refresh_currencies() -> void:
	for i in range(CampaignScreen._CURRENCY_PATHS.size()):
		if i >= _screen._currency_amount_labels.size():
			break
		var res = load(CampaignScreen._CURRENCY_PATHS[i])
		if res:
			_screen._currency_amount_labels[i].text = str(CampaignState.get_currency_amount(CampaignScreen._CURRENCY_PATHS[i]))
	_refresh_pages()

func _add_myth_face_to_currency_bar(parent: Node) -> void:
	var slot := Control.new()
	slot.custom_minimum_size = CampaignScreen._RosterSlot.SLOT_SIZE
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(slot)
	_screen._myth_face_slot = slot

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.12, 0.16, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg)

	var portrait := TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = CampaignScreen._RosterSlot.PORTRAIT_MARGIN
	portrait.offset_top = CampaignScreen._RosterSlot.PORTRAIT_MARGIN
	portrait.offset_right = -CampaignScreen._RosterSlot.PORTRAIT_MARGIN
	portrait.offset_bottom = -CampaignScreen._RosterSlot.PORTRAIT_MARGIN
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = load(CampaignScreen.MYTH_FACE_PATH) as Texture2D
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(portrait)

	var dialogue_button := Button.new()
	dialogue_button.anchor_left = 1.0
	dialogue_button.anchor_top = 0.0
	dialogue_button.anchor_right = 1.0
	dialogue_button.anchor_bottom = 0.0
	dialogue_button.offset_left = -CampaignScreen._RosterSlot.DIALOGUE_BUTTON_SIZE - 4.0
	dialogue_button.offset_top = 4.0
	dialogue_button.offset_right = -4.0
	dialogue_button.offset_bottom = CampaignScreen._RosterSlot.DIALOGUE_BUTTON_SIZE + 4.0
	dialogue_button.custom_minimum_size = Vector2(CampaignScreen._RosterSlot.DIALOGUE_BUTTON_SIZE, CampaignScreen._RosterSlot.DIALOGUE_BUTTON_SIZE)
	dialogue_button.text = "💬"
	dialogue_button.tooltip_text = "Диалог"
	dialogue_button.flat = true
	var transparent_button_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		dialogue_button.add_theme_stylebox_override(state, transparent_button_style)
	dialogue_button.focus_mode = Control.FOCUS_NONE
	dialogue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	dialogue_button.pressed.connect(_screen._story._on_myth_dialogue_button_pressed)
	slot.add_child(dialogue_button)

	if not CampaignState.first_battle_completed:
		var skip_button := Button.new()
		skip_button.anchor_left = 1.0
		skip_button.anchor_top = 1.0
		skip_button.anchor_right = 1.0
		skip_button.anchor_bottom = 1.0
		skip_button.offset_left = -CampaignScreen._RosterSlot.DIALOGUE_BUTTON_SIZE - 4.0
		skip_button.offset_top = -CampaignScreen._RosterSlot.DIALOGUE_BUTTON_SIZE - 4.0
		skip_button.offset_right = -4.0
		skip_button.offset_bottom = -4.0
		skip_button.custom_minimum_size = Vector2(CampaignScreen._RosterSlot.DIALOGUE_BUTTON_SIZE, CampaignScreen._RosterSlot.DIALOGUE_BUTTON_SIZE)
		skip_button.text = "⏭"
		skip_button.tooltip_text = "Пропустить стартовую миссию"
		skip_button.flat = true
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			skip_button.add_theme_stylebox_override(state, transparent_button_style)
		skip_button.focus_mode = Control.FOCUS_NONE
		skip_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		skip_button.pressed.connect(_screen._story._on_skip_first_mission_button_pressed)
		slot.add_child(skip_button)
		_screen._myth_skip_button = skip_button

func _refresh_pages() -> void:
	if _screen._campaign_pages_label == null or not is_instance_valid(_screen._campaign_pages_label):
		return
	_screen._campaign_pages_label.text = str(CampaignState.get_pages())


# ════════════════════════════════════════════════════════════
#  Ростер богов (2 ряда по 8 квадратов)
# ════════════════════════════════════════════════════════════

## Создаёт сетку 1×16 квадратов и подключает слоты.
func _build_god_roster(parent: Node) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_theme_constant_override("separation", 6)
	box.z_index = CampaignScreen.ROSTER_Z_INDEX
	parent.add_child(box)


	_screen._roster_grid = GridContainer.new()
	_screen._roster_grid.z_index = CampaignScreen.ROSTER_Z_INDEX
	_screen._roster_grid.columns = CampaignScreen.ROSTER_COLUMNS
	_screen._roster_grid.add_theme_constant_override("h_separation", 8)
	_screen._roster_grid.add_theme_constant_override("v_separation", 8)

	# Ряд: портреты богов + кнопка «Артефакты» справа от них.
	var roster_row := HBoxContainer.new()
	roster_row.z_index = CampaignScreen.ROSTER_Z_INDEX
	roster_row.alignment = BoxContainer.ALIGNMENT_CENTER
	roster_row.add_theme_constant_override("separation", 16)
	roster_row.add_child(_screen._roster_grid)
	var artifacts_btn := Button.new()
	artifacts_btn.text = "Артефакты"
	artifacts_btn.custom_minimum_size = Vector2(160, 64)
	artifacts_btn.add_theme_font_size_override("font_size", 18)
	artifacts_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	artifacts_btn.pressed.connect(_screen._tabs._select_tab.bind(CampaignScreen.TAB_TREASURY))
	roster_row.add_child(artifacts_btn)
	box.add_child(roster_row)

	var total := CampaignScreen.ROSTER_COLUMNS * CampaignScreen.ROSTER_ROWS
	_screen._roster_order.resize(total)
	for i in range(total):
		_screen._roster_order[i] = ""
		var slot := CampaignScreen._RosterSlot.new()
		slot.slot_index = i
		slot.god_double_clicked.connect(_screen._god_detail._show_god_detail)
		slot.god_dialogue_requested.connect(_screen._story._on_god_dialogue_requested)
		slot.swap_requested.connect(_on_roster_swap)
		_screen._roster_slots.append(slot)
		_screen._roster_grid.add_child(slot)

## Синхронизирует расположение с CampaignState.available_gods:
## убирает пропавших богов, добавляет новых в первые свободные квадраты.
func _refresh_roster() -> void:
	if _screen._roster_slots.is_empty():
		return
	var avail: Array = CampaignState.available_gods
	# Убираем богов, которых больше нет в доступных.
	for i in range(_screen._roster_order.size()):
		if _screen._roster_order[i] != "" and not avail.has(_screen._roster_order[i]):
			_screen._roster_order[i] = ""
	# Добавляем новых доступных богов в первые свободные квадраты.
	for god_path in avail:
		if god_path == "" or _screen._roster_order.has(god_path):
			continue
		var free_idx := _screen._roster_order.find("")
		if free_idx < 0:
			break
		_screen._roster_order[free_idx] = god_path
	# Перерисовываем слоты.
	for i in range(_screen._roster_slots.size()):
		if _screen._roster_slots[i]:
			_screen._roster_slots[i].set_god(_screen._roster_order[i])
	_screen._story._check_first_battle_intro_dialogue()
	_screen._map._update_tutorial_room_highlight()

## Перетаскивание портрета из одного квадрата в другой — меняем их местами.
func _on_roster_swap(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= _screen._roster_order.size():
		return
	if to_index < 0 or to_index >= _screen._roster_order.size():
		return
	var tmp: String = _screen._roster_order[from_index]
	_screen._roster_order[from_index] = _screen._roster_order[to_index]
	_screen._roster_order[to_index] = tmp
	_refresh_roster()
