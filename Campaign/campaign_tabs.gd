extends RefCounted
class_name CampaignTabs

## Вкладки комнат (боги / сокровищница / миссии) и их карточки, запуск миссии.
##
## Выделено из campaign_screen.gd. Состояние боя/экрана и прочие методы — через `_screen.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _screen: CampaignScreen

func _init(owner_scene: CampaignScreen) -> void:
	_screen = owner_scene

func _select_tab(tab: int) -> void:
	# Подсветка активной вкладки (disabled = нажата).
	for i in range(_screen._tab_buttons.size()):
		_screen._tab_buttons[i].disabled = (i == tab)

	# Очистка содержимого.
	for child in _screen._content_grid.get_children():
		child.queue_free()

	# Заполнение в зависимости от вкладки.
	match tab:
		CampaignScreen.TAB_GODS:
			_populate_gods()
		CampaignScreen.TAB_TREASURY:
			_populate_treasury()
		CampaignScreen.TAB_MISSIONS:
			_populate_missions()


# ════════════════════════════════════════════════════════════
#  Заполнение вкладок из CampaignState
# ════════════════════════════════════════════════════════════

func _populate_gods() -> void:
	var paths := CampaignState.available_gods
	if paths.is_empty():
		_screen._content_grid.add_child(_make_placeholder("Боги ещё не открыты"))
		return
	for path in paths:
		_screen._content_grid.add_child(_make_god_card(path))

func _populate_treasury() -> void:
	var paths := CampaignState.treasury
	if paths.is_empty():
		_screen._content_grid.add_child(_make_placeholder("Сокровищница пуста"))
		return
	# Группируем по пути — один и тот же артефакт может быть создан несколько раз
	# (см. CampaignState.add_item); показываем одну карточку с "×N" вместо N одинаковых.
	var counts: Dictionary = {}
	var order: Array[String] = []
	for path in paths:
		if not counts.has(path):
			counts[path] = 0
			order.append(path)
		counts[path] += 1
	for path in order:
		_screen._content_grid.add_child(_make_item_card(path, int(counts[path])))

func _populate_missions() -> void:
	var paths := CampaignState.available_missions
	if paths.is_empty():
		_screen._content_grid.add_child(_make_placeholder("Нет доступных миссий"))
		return
	for path in paths:
		_screen._content_grid.add_child(_make_mission_card(path))


# ════════════════════════════════════════════════════════════
#  Фабрики карточек
# ════════════════════════════════════════════════════════════

func _make_placeholder(text: String) -> Control:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	# Растягиваем на всю ширину грида.
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl

func _make_god_card(path: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 220)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var res := CampaignState.load_character_resource(path)
	var display_name := "Без имени"
	if res != null and res.unit_name != "":
		display_name = res.unit_name
	if res != null and res.is_dead:
		display_name += "\n☠ Мёртв"

	var lbl := Label.new()
	lbl.text = display_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lbl)

	# Уровень забвения (если есть).
	if res != null and res.forgetting_level > 0.0:
		var fade_lbl := Label.new()
		fade_lbl.text = "Забвение: %.1f / 5.0" % res.forgetting_level
		fade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fade_lbl.add_theme_font_size_override("font_size", 14)
		fade_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
		vb.add_child(fade_lbl)

	# Двойной клик открывает страницу бога.
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			_screen._god_detail._show_god_detail(path)
	)

	return panel

func _make_item_card(path: String, count: int = 1) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 140)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var res := load(path) as ItemResource
	var display_name := "Предмет"
	if res != null and res.item_name != "":
		display_name = res.item_name
	if count > 1:
		display_name += " ×%d" % count

	if res != null and res.icon != null:
		var icon := TextureRect.new()
		icon.texture = res.icon
		icon.custom_minimum_size = Vector2(0, 56)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vb.add_child(icon)

	var lbl := Label.new()
	lbl.text = display_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lbl)

	if res != null:
		var summary := _screen._god_detail._item_bonus_summary(res)
		if summary != "":
			var bonus_lbl := Label.new()
			bonus_lbl.text = summary
			bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bonus_lbl.add_theme_font_size_override("font_size", 12)
			bonus_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
			bonus_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(bonus_lbl)

		if res.restricted_god_path != "":
			var owner_name := res.restricted_god_path.get_file().get_basename()
			var owner_res := CampaignState.load_character_resource(res.restricted_god_path)
			if owner_res != null and owner_res.unit_name != "":
				owner_name = owner_res.unit_name
			var restrict_lbl := Label.new()
			restrict_lbl.text = "Только для: %s" % owner_name
			restrict_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			restrict_lbl.add_theme_font_size_override("font_size", 12)
			restrict_lbl.add_theme_color_override("font_color", CampaignScreen.GOD_DETAIL_ACCENT_COLOR)
			restrict_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(restrict_lbl)

	return panel

func _make_mission_card(path: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 140)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var res := load(path) as MissionResource
	var display_name := path
	if res != null and res.mission_name != "":
		display_name = res.mission_name

	var lbl := Label.new()
	lbl.text = display_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lbl)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_launch_mission_from_path(path)
	)

	return panel

func _launch_mission_from_path(path: String) -> void:
	if path.strip_edges() == "" or not ResourceLoader.exists(path):
		push_warning("Не найдена миссия: " + path)
		return
	MissionState.requested_mission_path = path
	MissionState.return_scene_path = "res://Campaign/campaign_screen.tscn"
	_screen.get_tree().change_scene_to_file("res://Missions/mission_select.tscn")

#  Навигация
# ════════════════════════════════════════════════════════════

## Открывает Сад творения: выбор "Бог" (эссенции, как раньше) / "Артефакт" (новый путь).
## Строит переключаемую в любой момент панель вкладок (обычно 2 варианта) и добавляет её
## в конец vb. tabs: Array из {"text": String, "callback": Callable}. active_index — какая
## вкладка сейчас открыта (рисуется нажатой и не реагирует на клик).
func _add_room_tab_bar(vb: VBoxContainer, tabs: Array, active_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Крафт артефактов открывается одновременно с комнатами (когда какой-то бог
	# открыл первую дверь) — до этого вкладка "Артефакт" видна, но неактивна.
	var artifacts_locked: bool = _screen._map._tutorial_locked_room_section() != ""
	for i in range(tabs.size()):
		var tab_data: Dictionary = tabs[i]
		var btn := Button.new()
		btn.text = tab_data["text"]
		btn.custom_minimum_size = Vector2(180, 40)
		btn.add_theme_font_size_override("font_size", 16)
		btn.toggle_mode = true
		if artifacts_locked and str(tab_data["text"]) == "Артефакт":
			btn.disabled = true
			btn.tooltip_text = "Станет доступно, когда откроете первую дверь"
		elif i == active_index:
			btn.button_pressed = true
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			btn.pressed.connect(tab_data["callback"])
		row.add_child(btn)
	vb.add_child(row)
	return row

## Определяет индекс текущей активной вкладки.
func _current_tab_index() -> int:
	for i in range(_screen._tab_buttons.size()):
		if _screen._tab_buttons[i].disabled:
			return i
	return CampaignScreen.TAB_GODS
