extends RefCounted
class_name CampaignMemoryWell

## Колодец памяти: снять забвение (забыть боль) / вспомнить прошлое бога.
##
## Выделено из campaign_screen.gd. Состояние боя/экрана и прочие методы — через `_screen.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _screen: CampaignScreen

func _init(owner_scene: CampaignScreen) -> void:
	_screen = owner_scene

## Колодец памяти: выбор бога из ростера + две платные (500 мыслей) операции
## над ним — полное исцеление ("Забыть боль") и снятие 1 уровня забвения
## ("Вспомнить прошлое").
func _show_memory_well_window() -> void:
	_close_memory_well_window()
	_screen._memory_well_selected_god_path = ""

	_screen._memory_well_overlay = Control.new()
	_screen._memory_well_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen._memory_well_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen._memory_well_overlay.z_index = 1300
	_screen.add_child(_screen._memory_well_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_memory_well_background_input)
	_screen._memory_well_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._memory_well_overlay.add_child(center)

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
	title.text = "Колодец памяти"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)

	var back_btn := _screen._scales._make_scales_button("Назад", Vector2(120, 40))
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(_close_memory_well_window)
	root.add_child(back_btn)

	var hint := Label.new()
	hint.text = "Выберите бога"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", CampaignScreen.GOD_DETAIL_ACCENT_DIM_COLOR)
	root.add_child(hint)

	_screen._memory_well_body = VBoxContainer.new()
	_screen._memory_well_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen._memory_well_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen._memory_well_body.add_theme_constant_override("separation", 14)
	root.add_child(_screen._memory_well_body)
	_refresh_memory_well_window()

func _close_memory_well_window() -> void:
	if _screen._memory_well_overlay != null and is_instance_valid(_screen._memory_well_overlay):
		_screen._memory_well_overlay.queue_free()
	_screen._memory_well_overlay = null
	_screen._memory_well_body = null

func _on_memory_well_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_memory_well_window()
		var viewport := _screen.get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func _refresh_memory_well_window() -> void:
	if _screen._memory_well_body == null or not is_instance_valid(_screen._memory_well_body):
		return
	for child in _screen._memory_well_body.get_children():
		child.queue_free()

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_screen._memory_well_body.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for path in CampaignState.available_gods:
		grid.add_child(_make_memory_well_god_card(str(path)))

	var info_label := Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 18)
	if _screen._memory_well_selected_god_path == "":
		info_label.text = "Бог не выбран"
	else:
		var res := CampaignState.load_character_resource(_screen._memory_well_selected_god_path)
		var cur_hp := CampaignState.get_god_current_hp(_screen._memory_well_selected_god_path)
		var max_hp := CampaignState.get_god_max_hp(_screen._memory_well_selected_god_path)
		var forgetting: float = res.forgetting_level if res != null else 0.0
		info_label.text = "%s — Здоровье: %d / %d, Забвение: %.1f / 5.0" % [
			res.unit_name if res != null else "?", cur_hp, max_hp, forgetting
		]
	_screen._memory_well_body.add_child(info_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	_screen._memory_well_body.add_child(actions)

	var forget_pain_btn := _screen._scales._make_scales_button("Забыть боль\n%d мыслей" % CampaignScreen.MEMORY_WELL_COST, Vector2(260.0, 84.0))
	var forget_pain_error := _memory_well_forget_pain_error()
	forget_pain_btn.disabled = forget_pain_error != ""
	forget_pain_btn.tooltip_text = forget_pain_error
	forget_pain_btn.pressed.connect(_memory_well_forget_pain)
	actions.add_child(forget_pain_btn)

	var remember_past_btn := _screen._scales._make_scales_button("Вспомнить прошлое\n%d мыслей" % CampaignScreen.MEMORY_WELL_COST, Vector2(260.0, 84.0))
	var remember_past_error := _memory_well_remember_past_error()
	remember_past_btn.disabled = remember_past_error != ""
	remember_past_btn.tooltip_text = remember_past_error
	remember_past_btn.pressed.connect(_memory_well_remember_past)
	actions.add_child(remember_past_btn)

## Карточка бога в сетке выбора Колодца памяти — клик выбирает бога, рамка
## подсвечивается у выбранной карточки.
func _make_memory_well_god_card(path: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var is_selected := path == _screen._memory_well_selected_god_path
	var style := StyleBoxFlat.new()
	style.bg_color = CampaignScreen.BUTTON_OPAQUE_BG_HOVER_COLOR if is_selected else CampaignScreen.BUTTON_OPAQUE_BG_COLOR
	style.border_color = CampaignScreen.GOD_DETAIL_ACCENT_COLOR if is_selected else CampaignScreen.GOD_DETAIL_ACCENT_DIM_COLOR
	style.set_border_width_all(2 if is_selected else 1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

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
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lbl)

	var hp_lbl := Label.new()
	hp_lbl.text = "HP: %d / %d" % [CampaignState.get_god_current_hp(path), CampaignState.get_god_max_hp(path)]
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(hp_lbl)

	if res != null and res.forgetting_level > 0.0:
		var fade_lbl := Label.new()
		fade_lbl.text = "Забвение: %.1f / 5.0" % res.forgetting_level
		fade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fade_lbl.add_theme_font_size_override("font_size", 13)
		fade_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
		vb.add_child(fade_lbl)

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_memory_well_god(path)
	)

	return panel

func _select_memory_well_god(path: String) -> void:
	_screen._memory_well_selected_god_path = path
	_refresh_memory_well_window()

func _memory_well_forget_pain_error() -> String:
	if _screen._memory_well_selected_god_path == "":
		return "Выберите бога"
	if CampaignState.get_god_current_hp(_screen._memory_well_selected_god_path) >= CampaignState.get_god_max_hp(_screen._memory_well_selected_god_path):
		return "Здоровье уже полное"
	if CampaignState.get_currency_amount(CampaignScreen.THOUGHTS_PATH) < CampaignScreen.MEMORY_WELL_COST:
		return "Недостаточно мыслей"
	return ""

func _memory_well_remember_past_error() -> String:
	if _screen._memory_well_selected_god_path == "":
		return "Выберите бога"
	var res := CampaignState.load_character_resource(_screen._memory_well_selected_god_path)
	if res == null or res.forgetting_level <= 0.0:
		return "Нет забвения, снимать нечего"
	if CampaignState.get_currency_amount(CampaignScreen.THOUGHTS_PATH) < CampaignScreen.MEMORY_WELL_COST:
		return "Недостаточно мыслей"
	return ""

## "Забыть боль" — полностью исцеляет выбранного бога за 500 мыслей.
func _memory_well_forget_pain() -> void:
	if _memory_well_forget_pain_error() != "":
		return
	if not CampaignState.spend_currency_amounts({CampaignScreen.THOUGHTS_PATH: CampaignScreen.MEMORY_WELL_COST}):
		return
	CampaignState.set_god_current_hp(_screen._memory_well_selected_god_path, CampaignState.get_god_max_hp(_screen._memory_well_selected_god_path))
	_screen._roster._refresh_currencies()
	_refresh_memory_well_window()

## "Вспомнить прошлое" — снимает 1 уровень забвения с выбранного бога за 500 мыслей.
func _memory_well_remember_past() -> void:
	if _memory_well_remember_past_error() != "":
		return
	if not CampaignState.spend_currency_amounts({CampaignScreen.THOUGHTS_PATH: CampaignScreen.MEMORY_WELL_COST}):
		return
	CampaignState.add_god_forgetting(_screen._memory_well_selected_god_path, -1.0)
	_screen._roster._refresh_currencies()
	_refresh_memory_well_window()
