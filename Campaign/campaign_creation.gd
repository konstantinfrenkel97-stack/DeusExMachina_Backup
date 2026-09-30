extends RefCounted
class_name CampaignCreation

## Создание (призыв) богов из эссенций.
##
## Выделено из campaign_screen.gd. Состояние боя/экрана и прочие методы — через `_screen.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _screen: CampaignScreen

func _init(owner_scene: CampaignScreen) -> void:
	_screen = owner_scene

## Открывает окно Сада творения: 2 слота эссенций, место спрайта бога, кнопка «Создать».
## Строка "иконка эссенции + доступное количество" для всех 5 эссенций создания —
## чтобы на странице Сада было видно, сколько чего есть, прежде чем выбирать слоты.
func _build_creation_essence_counts_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_screen._creation_essence_count_labels.clear()
	_screen._creation_essence_count_paths.clear()
	for essence_name_variant in CampaignScreen.CREATION_ESSENCES.keys():
		var essence_name := str(essence_name_variant)
		var essence_path := str(CampaignScreen.CREATION_ESSENCES[essence_name])
		var essence_res := load(essence_path)
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if essence_res != null and essence_res.icon != null:
			icon.texture = essence_res.icon
		icon.tooltip_text = essence_name
		pair.add_child(icon)
		var amt := Label.new()
		amt.text = str(CampaignState.get_currency_amount(essence_path))
		amt.add_theme_font_size_override("font_size", 16)
		amt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pair.add_child(amt)
		row.add_child(pair)
		_screen._creation_essence_count_labels.append(amt)
		_screen._creation_essence_count_paths.append(essence_path)
	return row

## Обновляет уже построенную строку количеств эссенций (после сотворения бога).
func _refresh_creation_essence_counts() -> void:
	for i in range(_screen._creation_essence_count_labels.size()):
		if not is_instance_valid(_screen._creation_essence_count_labels[i]):
			continue
		_screen._creation_essence_count_labels[i].text = str(CampaignState.get_currency_amount(_screen._creation_essence_count_paths[i]))

func _show_creation_window() -> void:
	_close_creation_window()
	_screen._creation_slots = ["", ""]
	if not CampaignState.god_creation_hint_shown:
		CampaignState.god_creation_hint_shown = true
		_screen._story._show_blocking_tutorial_hint(TutorialTexts.GOD_CREATION_HINT)
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
	bg.gui_input.connect(_on_creation_bg_input)
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
		margin.add_theme_constant_override(side, 18)
	panel.add_child(margin)

	var main_vb := VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 12)
	margin.add_child(main_vb)

	var title := Label.new()
	title.text = "Сад творения"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	main_vb.add_child(title)

	_screen._tabs._add_room_tab_bar(main_vb, [
		{"text": "Бог", "callback": _show_creation_window},
		{"text": "Артефакт", "callback": _screen._artifacts._show_artifact_type_window},
	], 0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vb.add_child(row)

	var hint := Label.new()
	hint.text = "Нажмите на квадрат, чтобы выбрать эссенцию"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	main_vb.add_child(hint)

	main_vb.add_child(_build_creation_essence_counts_row())

	# Слева: два слота эссенций.
	var slots_col := VBoxContainer.new()
	slots_col.add_theme_constant_override("separation", 16)
	slots_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_screen._creation_slot_icons.clear()
	_screen._creation_slot_hints.clear()
	for i in range(2):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(100, 100)
		slot.gui_input.connect(_on_creation_slot_input.bind(i))
		# Видимая рамка-квадрат.
		var sb := StyleBoxFlat.new()
		sb.bg_color = CampaignScreen.BUTTON_OPAQUE_BG_COLOR
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = CampaignScreen.GOD_DETAIL_ACCENT_COLOR
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		slot.add_theme_stylebox_override("panel", sb)
		var tex := TextureRect.new()
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex)
		# Знак «?» — виден, пока эссенция не выбрана.
		var qmark := Label.new()
		qmark.set_anchors_preset(Control.PRESET_FULL_RECT)
		qmark.text = "?"
		qmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		qmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qmark.add_theme_font_size_override("font_size", 36)
		slot.add_child(qmark)
		_screen._creation_slot_icons.append(tex)
		_screen._creation_slot_hints.append(qmark)
		slots_col.add_child(slot)
	row.add_child(slots_col)

	# Справа: место спрайта бога + имя + кнопка «Создать».
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 10)
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen._creation_sprite = TextureRect.new()
	_screen._creation_sprite.custom_minimum_size = Vector2(180, 240)
	_screen._creation_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_screen._creation_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right_col.add_child(_screen._creation_sprite)
	_screen._creation_name_label = Label.new()
	_screen._creation_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen._creation_name_label.add_theme_font_size_override("font_size", 22)
	right_col.add_child(_screen._creation_name_label)
	_screen._creation_create_btn = Button.new()
	_screen._creation_create_btn.text = "Создать"
	_screen._creation_create_btn.custom_minimum_size = Vector2(200, 50)
	_screen._creation_create_btn.add_theme_font_size_override("font_size", 20)
	_screen._creation_create_btn.disabled = true
	_screen._creation_create_btn.pressed.connect(_on_create_pressed)
	right_col.add_child(_screen._creation_create_btn)
	row.add_child(right_col)

	_build_creation_popup()
	_update_creation_view()

## Клик по тёмному фону — закрыть окно.
func _on_creation_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_creation_window()

## Закрывает окно Сада творения.
func _close_creation_window() -> void:
	if _screen._creation_popup != null and is_instance_valid(_screen._creation_popup):
		_screen._creation_popup.queue_free()
		_screen._creation_popup = null
	if _screen._creation_overlay != null and is_instance_valid(_screen._creation_overlay):
		_screen._creation_overlay.queue_free()
		_screen._creation_overlay = null

## Строит попап выбора эссенции (5 кнопок с текущим количеством).
func _build_creation_popup() -> void:
	if _screen._creation_popup != null and is_instance_valid(_screen._creation_popup):
		_screen._creation_popup.queue_free()
	_screen._creation_popup = PopupPanel.new()
	# Убираем общий фон/рамку попапа (из глобальной темы) — должны остаться только
	# рамки вокруг каждой отдельной иконки эссенции (см. _apply_essence_button_style).
	_screen._creation_popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_screen.add_child(_screen._creation_popup)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_screen._creation_popup.add_child(hbox)
	var essence_btn_size := Vector2(72, 72)
	for ename in CampaignScreen.CREATION_ESSENCES.keys():
		var res = load(CampaignScreen.CREATION_ESSENCES[ename])
		var btn := Button.new()
		btn.custom_minimum_size = essence_btn_size
		btn.tooltip_text = "%s — количество: %d" % [ename, CampaignState.get_currency_amount(str(CampaignScreen.CREATION_ESSENCES[ename])) if res != null else 0]
		_screen._apply_essence_button_style(btn)
		if res != null and res.icon != null:
			btn.icon = res.icon
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		else:
			btn.text = ename
		btn.pressed.connect(_on_essence_chosen.bind(ename))
		hbox.add_child(btn)

## Клик по слоту эссенции — открыть попап выбора для этого слота.
func _on_creation_slot_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_screen._creation_active_slot = slot_index
		if _screen._creation_popup != null and is_instance_valid(_screen._creation_popup):
			var slot_node = _screen._creation_slot_icons[slot_index].get_parent()
			_screen._creation_popup.position = slot_node.global_position + Vector2(slot_node.size.x + 8, 0)
			_screen._creation_popup.popup()

## Выбор эссенции в попапе.
func _on_essence_chosen(essence_name: String) -> void:
	if _screen._creation_active_slot < _screen._creation_slots.size():
		_screen._creation_slots[_screen._creation_active_slot] = essence_name
	if _screen._creation_popup != null and is_instance_valid(_screen._creation_popup):
		_screen._creation_popup.hide()
	_update_creation_view()

## Ключ рецепта: две эссенции по алфавиту через «|».
func _creation_key(a: String, b: String) -> String:
	var arr := [a, b]
	arr.sort()
	return "%s|%s" % [arr[0], arr[1]]

## Путь к богу по текущей паре эссенций (или "").
func _creation_result_god() -> String:
	if _screen._creation_slots.size() < 2 or _screen._creation_slots[0] == "" or _screen._creation_slots[1] == "":
		return ""
	return CampaignScreen.CREATION_RECIPES.get(_creation_key(_screen._creation_slots[0], _screen._creation_slots[1]), "")

## Достаточно ли эссенций для создания?
func _has_enough_essences() -> bool:
	if _screen._creation_slots.size() < 2:
		return false
	var a: String = _screen._creation_slots[0]
	var b: String = _screen._creation_slots[1]
	if not CampaignScreen.CREATION_ESSENCES.has(a) or not CampaignScreen.CREATION_ESSENCES.has(b):
		return false
	var pa := str(CampaignScreen.CREATION_ESSENCES[a])
	var pb := str(CampaignScreen.CREATION_ESSENCES[b])
	if a == b:
		return CampaignState.get_currency_amount(pa) >= 2
	return CampaignState.get_currency_amount(pa) >= 1 and CampaignState.get_currency_amount(pb) >= 1

## Обновить иконки слотов, превью бога и состояние кнопки «Создать».
func _update_creation_view() -> void:
	for i in range(_screen._creation_slot_icons.size()):
		var ename: String = _screen._creation_slots[i] if i < _screen._creation_slots.size() else ""
		var tex: Texture2D = null
		if ename != "":
			var res = load(CampaignScreen.CREATION_ESSENCES[ename])
			if res != null and res.icon != null:
				tex = res.icon
		_screen._creation_slot_icons[i].texture = tex
		if i < _screen._creation_slot_hints.size():
			_screen._creation_slot_hints[i].visible = (tex == null)
	var god_path := _creation_result_god()
	if god_path == "":
		_screen._creation_sprite.texture = null
		_screen._creation_name_label.text = ""
	else:
		var gres := CampaignState.load_character_resource(god_path)
		if gres != null:
			var t: Texture2D = null
			if gres.face_sprite != "":
				t = load(gres.face_sprite) as Texture2D
			if t == null and gres.sprite_path != "":
				t = load(gres.sprite_path) as Texture2D
			_screen._creation_sprite.texture = t
			_screen._creation_name_label.text = gres.unit_name
	_apply_create_button_state(god_path)

## Включает/выключает «Создать» и задаёт всплывающую подсказку.
func _apply_create_button_state(god_path: String) -> void:
	if god_path == "":
		_screen._creation_create_btn.disabled = true
		_screen._creation_create_btn.tooltip_text = "Выберите две эссенции"
		return
	if CampaignState.available_gods.has(god_path):
		_screen._creation_create_btn.disabled = true
		_screen._creation_create_btn.tooltip_text = "Вы уже сотворили этого бога"
		return
	if not _has_enough_essences():
		_screen._creation_create_btn.disabled = true
		_screen._creation_create_btn.tooltip_text = "Недостаточно эссенций"
		return
	_screen._creation_create_btn.disabled = false
	_screen._creation_create_btn.tooltip_text = ""

## Создать бога: вычесть по 1 эссенции каждого выбранного типа, добавить бога, обновить UI.
func _on_create_pressed() -> void:
	var god_path := _creation_result_god()
	if god_path == "" or CampaignState.available_gods.has(god_path):
		return
	if not _has_enough_essences():
		return
	var costs: Dictionary = {}
	var first_path := str(CampaignScreen.CREATION_ESSENCES[_screen._creation_slots[0]])
	var second_path := str(CampaignScreen.CREATION_ESSENCES[_screen._creation_slots[1]])
	costs[first_path] = int(costs.get(first_path, 0)) + 1
	costs[second_path] = int(costs.get(second_path, 0)) + 1
	if not CampaignState.spend_currency_amounts(costs):
		return
	CampaignState.add_god(god_path)
	CampaignState.set_god_creation_essences(god_path, [first_path, second_path])
	_build_creation_popup()
	_update_creation_view()
	_screen._roster._refresh_currencies()
	_refresh_creation_essence_counts()
	_screen._story._play_summon_dialogue_for_god(god_path)
