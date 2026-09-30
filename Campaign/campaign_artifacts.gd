extends RefCounted
class_name CampaignArtifacts

## Создание артефактов: выбор типа, выбор предмета, результат.
##
## Выделено из campaign_screen.gd. Состояние боя/экрана и прочие методы — через `_screen.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _screen: CampaignScreen

func _init(owner_scene: CampaignScreen) -> void:
	_screen = owner_scene

## Шаг 1 создания артефакта: выбор типа (Оружие / Доспехи / Безделушка), с ценой на карточке.
func _show_artifact_type_window() -> void:
	if _screen._map._tutorial_locked_room_section() != "":
		_screen._show_notification("Пока недоступно")
		return
	_screen._creation._close_creation_window()
	_screen._creation_overlay = Control.new()
	_screen._creation_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen._creation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Выше портретов богов (ROSTER_Z_INDEX = 80).
	_screen._creation_overlay.z_index = 1000
	_screen.add_child(_screen._creation_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_screen._creation._on_creation_bg_input)
	_screen._creation_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._creation_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = CampaignScreen.ROOM_PANEL_SIZE
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "Сад творения"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	_screen._tabs._add_room_tab_bar(vb, [
		{"text": "Бог", "callback": _screen._creation._show_creation_window},
		{"text": "Артефакт", "callback": _show_artifact_type_window},
	], 1)

	var type_hint := Label.new()
	type_hint.text = "Выберите тип артефакта"
	type_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_hint.add_theme_font_size_override("font_size", 16)
	vb.add_child(type_hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)

	for i in range(CampaignScreen.ARTIFACT_TYPE_NAMES.size()):
		var cost: int = CampaignScreen.ARTIFACT_TYPE_COST[i]
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", 4)
		wrap.alignment = BoxContainer.ALIGNMENT_CENTER

		var card := Button.new()
		card.custom_minimum_size = Vector2(150, 150)
		card.alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.text = CampaignScreen.ARTIFACT_TYPE_NAMES[i]
		card.add_theme_font_size_override("font_size", 16)
		var sample := load(CampaignScreen.ARTIFACT_COMMON_ITEMS[i][0]) as ItemResource
		if sample != null and sample.icon != null:
			card.icon = sample.icon
			card.expand_icon = true
			card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		# Нехватка мыслей больше не блокирует переход — сообщение покажется только
		# при попытке создать конкретный предмет.
		card.pressed.connect(_show_artifact_item_window.bind(i))
		wrap.add_child(card)

		var cost_row := _screen._make_thoughts_icon_row(cost)
		cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		wrap.add_child(cost_row)

		row.add_child(wrap)

## Шаг 2 создания артефакта: конкретный предмет из списка "обычных" (плюс "Случайный"),
## с отметкой уже созданных — карточки строятся в общей прокручиваемой сетке.
func _show_artifact_item_window(item_type: int) -> void:
	_screen._creation._close_creation_window()
	_screen._artifact_selected_type = item_type
	_screen._creation_overlay = Control.new()
	_screen._creation_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen._creation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Выше портретов богов (ROSTER_Z_INDEX = 80).
	_screen._creation_overlay.z_index = 1000
	_screen.add_child(_screen._creation_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_screen._creation._on_creation_bg_input)
	_screen._creation_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._creation_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = CampaignScreen.ROOM_PANEL_SIZE
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	var cost: int = CampaignScreen.ARTIFACT_TYPE_COST[item_type]
	var thoughts_amount := CampaignState.get_currency_amount(CampaignScreen.THOUGHTS_PATH)

	var title := Label.new()
	title.text = "Сад творения"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	_screen._tabs._add_room_tab_bar(vb, [
		{"text": "Бог", "callback": _screen._creation._show_creation_window},
		{"text": "Артефакт", "callback": _show_artifact_type_window},
	], 1)

	var type_label := Label.new()
	type_label.text = CampaignScreen.ARTIFACT_TYPE_NAMES[item_type]
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 20)
	vb.add_child(type_label)

	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 8)
	var cost_prefix := Label.new()
	cost_prefix.text = "Стоимость создания:"
	cost_prefix.add_theme_font_size_override("font_size", 15)
	cost_row.add_child(cost_prefix)
	cost_row.add_child(_screen._make_thoughts_icon_row(cost))
	var cost_suffix := Label.new()
	cost_suffix.text = "(есть:"
	cost_suffix.add_theme_font_size_override("font_size", 15)
	cost_row.add_child(cost_suffix)
	cost_row.add_child(_screen._make_thoughts_icon_row(thoughts_amount))
	var cost_close := Label.new()
	cost_close.text = ")"
	cost_close.add_theme_font_size_override("font_size", 15)
	cost_row.add_child(cost_close)
	if thoughts_amount < cost:
		for lbl in [cost_prefix, cost_suffix, cost_close]:
			lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	vb.add_child(cost_row)

	if _screen._artifact_create_error != "":
		var error_label := Label.new()
		error_label.text = _screen._artifact_create_error
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_label.add_theme_font_size_override("font_size", 15)
		error_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		vb.add_child(error_label)
		_screen._artifact_create_error = ""

	var back_btn := Button.new()
	back_btn.text = "← Другой тип"
	back_btn.custom_minimum_size = Vector2(120, 36)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.pressed.connect(_show_artifact_type_window)
	vb.add_child(back_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vb.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	grid.add_child(_make_artifact_pick_card("🎲 Случайный", null, ""))
	for path in CampaignScreen.ARTIFACT_COMMON_ITEMS[item_type]:
		var item := load(path) as ItemResource
		if item == null:
			continue
		grid.add_child(_make_artifact_pick_card(item.item_name, item, path))

## Строит одну кликабельную карточку выбора предмета (или "Случайный", если item == null).
func _make_artifact_pick_card(display_name: String, item: ItemResource, specific_path: String) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER

	var card := Button.new()
	card.custom_minimum_size = Vector2(150, 110)
	card.alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_theme_font_size_override("font_size", 14)
	card.text = display_name

	if item != null and item.icon != null:
		card.icon = item.icon
		card.expand_icon = true
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

	var is_random := specific_path == ""
	var already_owned := specific_path != "" and CampaignState.treasury.has(specific_path)
	# Конкретный предмет можно выбрать напрямую, только если он уже был создан раньше —
	# иначе его можно получить только через «Случайный». Нехватка мыслей саму карточку
	# больше не блокирует — сообщение об этом покажется только при попытке создать.
	var can_pick := is_random or already_owned
	if not can_pick:
		card.disabled = true
		card.tooltip_text = "Сначала получите этот предмет через «Случайный»"
	else:
		card.pressed.connect(_create_artifact.bind(_screen._artifact_selected_type, specific_path))
	wrap.add_child(card)

	if item != null:
		var bonus_lines := _screen._god_detail._item_bonus_icon_lines(item)
		if not bonus_lines.is_empty():
			var stats_label := RichTextLabel.new()
			stats_label.bbcode_enabled = true
			stats_label.fit_content = true
			stats_label.scroll_active = false
			stats_label.custom_minimum_size = Vector2(150, 0)
			stats_label.text = "  ".join(bonus_lines)
			wrap.add_child(stats_label)

	return wrap

## Определяет, какой конкретно предмет создать. specific_path != "" — игрок выбрал сам.
## specific_path == "" ("Случайный") — сначала пробуем ещё не созданный предмет этого типа,
## и только если все уже созданы — берём случайный из полного списка (может повториться).
func _pick_artifact_path(item_type: int, specific_path: String) -> String:
	if specific_path != "":
		return specific_path
	var pool: Array = CampaignScreen.ARTIFACT_COMMON_ITEMS[item_type]
	var not_created: Array = []
	for p in pool:
		if not CampaignState.treasury.has(p):
			not_created.append(p)
	if not not_created.is_empty():
		return str(not_created[randi() % not_created.size()])
	return str(pool[randi() % pool.size()])

## Списывает мысли и добавляет артефакт в сокровищницу (дубликаты разрешены).
func _create_artifact(item_type: int, specific_path: String) -> void:
	var cost: int = CampaignScreen.ARTIFACT_TYPE_COST[item_type]
	if not CampaignState.spend_currency_amounts({CampaignScreen.THOUGHTS_PATH: cost}):
		_screen._artifact_create_error = "Недостаточно ресурсов"
		_show_artifact_item_window(item_type)
		return
	var path := _pick_artifact_path(item_type, specific_path)
	CampaignState.add_item(path)
	_screen._roster._refresh_currencies()
	_show_artifact_result(path)

## Финальный экран: что именно создано, с кнопкой "Закрыть".
func _show_artifact_result(path: String) -> void:
	_screen._creation._close_creation_window()
	_screen._creation_overlay = Control.new()
	_screen._creation_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen._creation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Выше портретов богов (ROSTER_Z_INDEX = 80).
	_screen._creation_overlay.z_index = 1000
	_screen.add_child(_screen._creation_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_screen._creation._on_creation_bg_input)
	_screen._creation_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._creation_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = CampaignScreen.ROOM_PANEL_SIZE
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)

	var item := load(path) as ItemResource

	var title := Label.new()
	title.text = "Артефакт сотворён!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	if item != null and item.icon != null:
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(0, 90)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vb.add_child(icon)

	var name_label := Label.new()
	name_label.text = item.item_name if item != null else "Предмет"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	vb.add_child(name_label)

	if item != null:
		var bonus_lines := _screen._god_detail._item_bonus_icon_lines(item)
		if not bonus_lines.is_empty():
			var bonus_label := RichTextLabel.new()
			bonus_label.bbcode_enabled = true
			bonus_label.fit_content = true
			bonus_label.scroll_active = false
			bonus_label.custom_minimum_size = Vector2(CampaignScreen.ROOM_PANEL_SIZE.x - 80, 0)
			var bbcode := "  ".join(bonus_lines)
			bonus_label.text = "[center]%s[/center]" % bbcode
			vb.add_child(bonus_label)

	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.custom_minimum_size = Vector2(0, 48)
	close_btn.add_theme_font_size_override("font_size", 18)
	# Артефакт уже создан и сохранён — возвращаемся к выбору типа, а не на экран кампании.
	close_btn.pressed.connect(_show_artifact_type_window)
	vb.add_child(close_btn)
