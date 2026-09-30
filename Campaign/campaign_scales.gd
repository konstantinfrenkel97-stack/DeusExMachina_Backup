extends RefCounted
class_name CampaignScales

## Весы: улучшение артефактов, обмен эссенций.
##
## Выделено из campaign_screen.gd. Состояние боя/экрана и прочие методы — через `_screen.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _screen: CampaignScreen

func _init(owner_scene: CampaignScreen) -> void:
	_screen = owner_scene

func _show_scales_window() -> void:
	_close_scales_window()
	_screen._scales_mode = "improve"
	_screen._scales_selected_item_path = ""
	_screen._scales_selected_essence_path = ""
	_screen._scales_picker_visible = false

	_screen._scales_overlay = Control.new()
	_screen._scales_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen._scales_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen._scales_overlay.z_index = 1300
	_screen.add_child(_screen._scales_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_scales_background_input)
	_screen._scales_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._scales_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = CampaignScreen.ROOM_PANEL_SIZE
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Весы переосмысления"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)

	var back_btn := _make_scales_button("Назад", Vector2(120, 40))
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(_close_scales_window)
	root.add_child(back_btn)

	_screen._scales_tab_row = _screen._tabs._add_room_tab_bar(root, [
		{"text": "Додумать", "callback": _set_scales_mode.bind("improve")},
		{"text": "Передумать", "callback": _set_scales_mode.bind("rethink")},
	], 0 if _screen._scales_mode == "improve" else 1)

	_screen._scales_body = VBoxContainer.new()
	_screen._scales_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen._scales_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen._scales_body.add_theme_constant_override("separation", 14)
	root.add_child(_screen._scales_body)
	_refresh_scales_window()

func _close_scales_window() -> void:
	if _screen._scales_overlay != null and is_instance_valid(_screen._scales_overlay):
		_screen._scales_overlay.queue_free()
	_screen._scales_overlay = null
	_screen._scales_body = null
	_screen._scales_tab_row = null
	_screen._scales_picker_visible = false

func _on_scales_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_scales_window()
		var viewport := _screen.get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func _set_scales_mode(mode: String) -> void:
	_screen._scales_mode = mode
	_screen._scales_picker_visible = false
	if _screen._scales_mode == "rethink" and _screen._scales_selected_essence_path == "":
		_screen._scales_selected_essence_path = str(CampaignScreen.CREATION_ESSENCES.values()[0])
	_refresh_scales_window()

func _refresh_scales_window() -> void:
	if _screen._scales_body == null or not is_instance_valid(_screen._scales_body):
		return
	if _screen._scales_tab_row != null and is_instance_valid(_screen._scales_tab_row):
		var tab_parent := _screen._scales_tab_row.get_parent()
		var tab_index := _screen._scales_tab_row.get_index()
		_screen._scales_tab_row.free()
		_screen._scales_tab_row = _screen._tabs._add_room_tab_bar(tab_parent, [
			{"text": "Додумать", "callback": _set_scales_mode.bind("improve")},
			{"text": "Передумать", "callback": _set_scales_mode.bind("rethink")},
		], 0 if _screen._scales_mode == "improve" else 1)
		tab_parent.move_child(_screen._scales_tab_row, tab_index)
	for child in _screen._scales_body.get_children():
		child.queue_free()
	if _screen._scales_mode == "rethink":
		_build_scales_rethink_tab()
	else:
		_build_scales_improve_tab()

func _build_scales_improve_tab() -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	_screen._scales_body.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260.0, 1.0)
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)

	var item_slot := _make_scales_item_slot_button()
	item_slot.pressed.connect(_toggle_scales_item_picker)
	left.add_child(item_slot)

	var item_info := Label.new()
	item_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_info.add_theme_font_size_override("font_size", 20)
	item_info.text = _scales_selected_item_summary()
	left.add_child(item_info)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	row.add_child(right)

	var cost := Label.new()
	cost.text = _scales_upgrade_cost_text()
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost.add_theme_font_size_override("font_size", 24)
	right.add_child(cost)

	if _scales_selected_item_needs_essence():
		_build_scales_essence_selector(right)

	var upgrade_btn := _make_scales_button("Улучшить", Vector2(260.0, 58.0))
	upgrade_btn.disabled = _scales_upgrade_error() != ""
	upgrade_btn.tooltip_text = _scales_upgrade_error()
	upgrade_btn.pressed.connect(_upgrade_scales_selected_item)
	right.add_child(upgrade_btn)

	if _screen._scales_picker_visible:
		_build_scales_item_picker()

func _build_scales_rethink_tab() -> void:
	var selected_label := Label.new()
	selected_label.add_theme_font_size_override("font_size", 22)
	selected_label.text = "Мысли: %d" % CampaignState.get_currency_amount(CampaignScreen.THOUGHTS_PATH)
	_screen._scales_body.add_child(selected_label)

	_build_scales_essence_selector(_screen._scales_body)

	var selected_amount := 0
	if _screen._scales_selected_essence_path != "":
		selected_amount = CampaignState.get_currency_amount(_screen._scales_selected_essence_path)
	var amount_label := Label.new()
	amount_label.add_theme_font_size_override("font_size", 22)
	amount_label.text = "Выбранной эссенции: %d" % selected_amount
	_screen._scales_body.add_child(amount_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	_screen._scales_body.add_child(actions)

	var buy_btn := _make_scales_button("Купить эссенцию\n600 мыслей", Vector2(260.0, 84.0))
	buy_btn.disabled = _screen._scales_selected_essence_path == "" or CampaignState.get_currency_amount(CampaignScreen.THOUGHTS_PATH) < CampaignScreen.SCALES_BUY_ESSENCE_COST
	buy_btn.pressed.connect(_buy_scales_essence)
	actions.add_child(buy_btn)

	var sell_btn := _make_scales_button("Продать эссенцию\n400 мыслей", Vector2(260.0, 84.0))
	sell_btn.disabled = _screen._scales_selected_essence_path == "" or selected_amount < 1
	sell_btn.pressed.connect(_sell_scales_essence)
	actions.add_child(sell_btn)

func _make_scales_item_slot_button() -> Button:
	var button := _make_scales_button("Предмет", CampaignScreen.SCALES_ITEM_SLOT_SIZE)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _screen._scales_selected_item_path != "":
		var item := load(_screen._scales_selected_item_path) as ItemResource
		if item != null:
			button.text = ""
			button.icon = item.icon
			button.tooltip_text = _scales_item_tooltip(item)
	return button

func _toggle_scales_item_picker() -> void:
	_screen._scales_picker_visible = not _screen._scales_picker_visible
	_refresh_scales_window()

func _build_scales_item_picker() -> void:
	var title := Label.new()
	title.text = "Артефакты"
	title.add_theme_font_size_override("font_size", 24)
	_screen._scales_body.add_child(title)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_scales_panel_style())
	_screen._scales_body.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1.0, 230.0)
	panel.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var paths := _unique_treasury_paths()
	if paths.is_empty():
		var empty := Label.new()
		empty.text = "Сокровищница пуста"
		empty.add_theme_font_size_override("font_size", 22)
		grid.add_child(empty)
		return
	for item_path in paths:
		grid.add_child(_make_scales_artifact_button(item_path))

func _unique_treasury_paths() -> Array[String]:
	var result: Array[String] = []
	for item_path in CampaignState.treasury:
		var clean_path := item_path.strip_edges()
		if clean_path != "" and ResourceLoader.exists(clean_path) and not result.has(clean_path):
			result.append(clean_path)
	return result

func _make_scales_artifact_button(item_path: String) -> Button:
	var item := load(item_path) as ItemResource
	var button := _make_scales_button("", CampaignScreen.SCALES_ARTIFACT_CARD_SIZE)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = _scales_item_tooltip(item)
	if item != null:
		button.icon = item.icon
	button.pressed.connect(_select_scales_item.bind(item_path))

	var owner_path := CampaignState.get_item_equipped_god_path(item_path)
	if owner_path != "":
		var owner := CampaignState.load_character_resource(owner_path)
		if owner != null and owner.face_sprite != "":
			var owner_face := load(owner.face_sprite) as Texture2D
			if owner_face != null:
				var badge := TextureRect.new()
				badge.texture = owner_face
				badge.custom_minimum_size = Vector2(42.0, 42.0)
				badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				badge.anchor_left = 0.0
				badge.anchor_top = 1.0
				badge.anchor_right = 0.0
				badge.anchor_bottom = 1.0
				badge.offset_left = 6.0
				badge.offset_top = -48.0
				badge.offset_right = 48.0
				badge.offset_bottom = -6.0
				button.add_child(badge)
	return button

func _select_scales_item(item_path: String) -> void:
	_screen._scales_selected_item_path = item_path
	_screen._scales_picker_visible = false
	_refresh_scales_window()

func _build_scales_essence_selector(parent: VBoxContainer) -> void:
	var label := Label.new()
	label.text = "Эссенция"
	label.add_theme_font_size_override("font_size", 22)
	parent.add_child(label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	for essence_name_variant in CampaignScreen.CREATION_ESSENCES.keys():
		var essence_name := str(essence_name_variant)
		var essence_path := str(CampaignScreen.CREATION_ESSENCES[essence_name])
		var essence_res := load(essence_path)
		var button := _make_scales_button("%s: %d" % [essence_name, CampaignState.get_currency_amount(essence_path)], Vector2(150.0, 54.0))
		var is_selected := _screen._scales_selected_essence_path == essence_path
		_screen._apply_essence_button_style(button, is_selected)
		if essence_res != null and essence_res.icon:
			button.icon = essence_res.icon
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.pressed.connect(_select_scales_essence.bind(essence_path))
		row.add_child(button)

func _select_scales_essence(essence_path: String) -> void:
	_screen._scales_selected_essence_path = essence_path
	_refresh_scales_window()

func _scales_selected_item_summary() -> String:
	if _screen._scales_selected_item_path == "":
		return "Предмет не выбран"
	var item := load(_screen._scales_selected_item_path) as ItemResource
	if item == null:
		return "Предмет не загрузился"
	var text := "%s\n%s\n%s" % [item.item_name, item.get_type_name(), item.get_rarity_name()]
	var bonuses := item.get_bonuses_text()
	if bonuses != "":
		text += "\n" + bonuses
	return text

func _scales_upgrade_cost_text() -> String:
	if _screen._scales_selected_item_path == "":
		return "Выберите артефакт"
	var item := load(_screen._scales_selected_item_path) as ItemResource
	if item == null:
		return "Предмет не загрузился"
	match item.rarity:
		ItemResource.Rarity.COMMON:
			return "Стоимость улучшения: 800 мыслей"
		ItemResource.Rarity.RARE:
			return "Стоимость улучшения: 1200 мыслей и 1 выбранная эссенция"
	return "Этот артефакт пока нельзя улучшить"

func _scales_selected_item_needs_essence() -> bool:
	if _screen._scales_selected_item_path == "":
		return false
	var item := load(_screen._scales_selected_item_path) as ItemResource
	return item != null and item.rarity == ItemResource.Rarity.RARE

func _scales_upgrade_error() -> String:
	if _screen._scales_selected_item_path == "":
		return "Выберите артефакт"
	var item := load(_screen._scales_selected_item_path) as ItemResource
	if item == null:
		return "Предмет не загрузился"
	if item.rarity == ItemResource.Rarity.COMMON:
		if CampaignState.get_currency_amount(CampaignScreen.THOUGHTS_PATH) < CampaignScreen.SCALES_COMMON_TO_RARE_COST:
			return "Недостаточно мыслей"
		return ""
	if item.rarity == ItemResource.Rarity.RARE:
		if CampaignState.get_currency_amount(CampaignScreen.THOUGHTS_PATH) < CampaignScreen.SCALES_RARE_TO_EPIC_THOUGHTS_COST:
			return "Недостаточно мыслей"
		if _screen._scales_selected_essence_path == "":
			return "Выберите эссенцию"
		if CampaignState.get_currency_amount(_screen._scales_selected_essence_path) < 1:
			return "Недостаточно выбранной эссенции"
		return ""
	return "Нет доступного улучшения"

func _upgrade_scales_selected_item() -> void:
	if _scales_upgrade_error() != "":
		return
	var item := load(_screen._scales_selected_item_path) as ItemResource
	if item == null:
		return
	if item.rarity == ItemResource.Rarity.COMMON:
		if not CampaignState.spend_currency_amounts({CampaignScreen.THOUGHTS_PATH: CampaignScreen.SCALES_COMMON_TO_RARE_COST}):
			return
		item.rarity = ItemResource.Rarity.RARE
	elif item.rarity == ItemResource.Rarity.RARE:
		if not CampaignState.spend_currency_amounts({CampaignScreen.THOUGHTS_PATH: CampaignScreen.SCALES_RARE_TO_EPIC_THOUGHTS_COST, _screen._scales_selected_essence_path: 1}):
			return
		item.rarity = ItemResource.Rarity.EPIC
	ResourceSaver.save(item, _screen._scales_selected_item_path)
	_screen._roster._refresh_currencies()
	_refresh_scales_window()

func _buy_scales_essence() -> void:
	if _screen._scales_selected_essence_path == "":
		return
	if not CampaignState.spend_currency_amounts({CampaignScreen.THOUGHTS_PATH: CampaignScreen.SCALES_BUY_ESSENCE_COST}):
		return
	CampaignState.add_currency_amount(_screen._scales_selected_essence_path, 1)
	_screen._roster._refresh_currencies()
	_refresh_scales_window()

func _sell_scales_essence() -> void:
	if _screen._scales_selected_essence_path == "":
		return
	if not CampaignState.spend_currency_amounts({_screen._scales_selected_essence_path: 1}):
		return
	CampaignState.add_currency_amount(CampaignScreen.THOUGHTS_PATH, CampaignScreen.SCALES_SELL_ESSENCE_GAIN)
	_screen._roster._refresh_currencies()
	_refresh_scales_window()

func _scales_item_tooltip(item: ItemResource) -> String:
	if item == null:
		return ""
	var lines: Array[String] = [item.item_name, item.get_rarity_name(), item.get_type_name()]
	if item.description.strip_edges() != "":
		lines.append(item.description.strip_edges())
	var bonuses := item.get_bonuses_text()
	if bonuses != "":
		lines.append(bonuses)
	return "\n".join(lines)

func _make_scales_panel_style(color: Color = CampaignScreen.GOD_DETAIL_BG_COLOR) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = CampaignScreen.GOD_DETAIL_ACCENT_COLOR
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _make_scales_button(text: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_stylebox_override("normal", _make_scales_button_style(false))
	button.add_theme_stylebox_override("hover", _make_scales_button_style(true))
	button.add_theme_stylebox_override("pressed", _make_scales_button_style(true))
	button.add_theme_stylebox_override("disabled", _make_scales_button_style(false, true))
	return button

func _make_scales_button_style(highlighted: bool = false, disabled: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CampaignScreen.BUTTON_OPAQUE_BG_HOVER_COLOR if highlighted else CampaignScreen.BUTTON_OPAQUE_BG_COLOR
	style.border_color = CampaignScreen.GOD_DETAIL_ACCENT_COLOR if highlighted else CampaignScreen.GOD_DETAIL_ACCENT_DIM_COLOR
	if disabled:
		style.bg_color = CampaignScreen.BUTTON_OPAQUE_BG_DISABLED_COLOR
		style.border_color = Color(0.5, 0.45, 0.34, 0.4)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
