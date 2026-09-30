extends RefCounted
class_name CampaignLibrary

## Бесконечная библиотека: чтение книг и улучшение заклинаний.
##
## Выделено из campaign_screen.gd. Состояние боя/экрана и прочие методы — через `_screen.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _screen: CampaignScreen

func _init(owner_scene: CampaignScreen) -> void:
	_screen = owner_scene

## Строит стандартный оверлей Библиотеки (тёмная подложка, закрывающая клик по ней +
## центрированная панель) и возвращает пустой VBoxContainer внутри — наполнение содержимым
## делает вызывающая функция. Каждый шаг Библиотеки сам решает, что сюда положить.
func _build_library_overlay(panel_size: Vector2) -> VBoxContainer:
	_close_library_window()
	_screen._library_overlay = Control.new()
	_screen._library_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen._library_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Выше портретов богов (ROSTER_Z_INDEX = 80).
	_screen._library_overlay.z_index = 1000
	_screen.add_child(_screen._library_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_library_window()
	)
	_screen._library_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._library_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = panel_size
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)
	return vb

func _close_library_window() -> void:
	if _screen._library_overlay != null and is_instance_valid(_screen._library_overlay):
		_screen._library_overlay.queue_free()
		_screen._library_overlay = null

## Открывает Бесконечную библиотеку: выбор "Читать книги" / "Осмыслять сюжет".
## "Читать книги" — за 1000 мыслей +5 к максимальной фантазии до конца игры (можно повторно).
func _show_library_read_window() -> void:
	var vb := _build_library_overlay(CampaignScreen.ROOM_PANEL_SIZE)

	var title := Label.new()
	title.text = "Бесконечная библиотека"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	_screen._tabs._add_room_tab_bar(vb, [
		{"text": "Читать книги", "callback": _show_library_read_window},
		{"text": "Осмыслять сюжет", "callback": _show_library_spell_upgrade_window},
	], 0)

	var desc := Label.new()
	desc.text = "Каждый прочитанный том увеличивает максимальный запас фантазии на %d — навсегда." % CampaignState.LIBRARY_READ_FANTASY_BONUS
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	vb.add_child(desc)

	var progress := Label.new()
	progress.text = "Уже прочитано: +%d к максимальной фантазии" % CampaignState.library_max_fantasy_bonus
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 14)
	progress.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	vb.add_child(progress)

	var thoughts_amount := CampaignState.get_currency_amount(CampaignState.THOUGHTS_PATH)
	var cost := CampaignState.LIBRARY_READ_COST
	var can_afford := thoughts_amount >= cost

	var cost_label := Label.new()
	cost_label.text = "Стоимость: %d мыслей (есть: %d)" % [cost, thoughts_amount]
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 15)
	if not can_afford:
		cost_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	vb.add_child(cost_label)

	var read_btn := Button.new()
	read_btn.text = "Читать (%d мыслей)" % cost
	read_btn.custom_minimum_size = Vector2(0, 50)
	read_btn.add_theme_font_size_override("font_size", 18)
	read_btn.disabled = not can_afford
	if not can_afford:
		read_btn.tooltip_text = "Недостаточно мыслей"
	read_btn.pressed.connect(_do_read_library_books)
	vb.add_child(read_btn)

func _do_read_library_books() -> void:
	if not CampaignState.read_library_books():
		_show_library_read_window()
		return
	_screen._roster._refresh_currencies()
	_show_library_result(
		"Ещё один том прочитан!",
		"Максимальная фантазия увеличена на %d (итого: +%d)." % [CampaignState.LIBRARY_READ_FANTASY_BONUS, CampaignState.library_max_fantasy_bonus]
	)

## Возвращает пути ко всем заклинаниям (для карточек улучшения) — сканирует res://Spells
## так же, как battle_scene.gd::_collect_spells_from_dir, чтобы новые файлы подхватывались сами.
func _get_all_spell_paths() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open("res://Spells")
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			result.append("res://Spells".path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

## "Осмыслять сюжет" — список заклинаний; клик открывает подробности улучшения.
func _show_library_spell_upgrade_window() -> void:
	var vb := _build_library_overlay(CampaignScreen.ROOM_PANEL_SIZE)

	var title := Label.new()
	title.text = "Бесконечная библиотека"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	_screen._tabs._add_room_tab_bar(vb, [
		{"text": "Читать книги", "callback": _show_library_read_window},
		{"text": "Осмыслять сюжет", "callback": _show_library_spell_upgrade_window},
	], 1)

	var desc := Label.new()
	desc.text = "Выберите заклинание, чтобы посмотреть, каким оно станет после улучшения."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	vb.add_child(desc)

	var center_grid := CenterContainer.new()
	center_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(center_grid)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	center_grid.add_child(grid)

	for path in _get_all_spell_paths():
		var spell := load(path) as SpellResource
		if spell == null or not SpellUpgradeData.has_upgrades(path):
			continue
		var level := CampaignState.get_spell_upgrade_level(path)
		var card := Button.new()
		card.custom_minimum_size = Vector2(150, 130)
		card.alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_theme_font_size_override("font_size", 15)
		var level_text := "\n(ур. %d/2)" % level if level > 0 else ""
		card.text = "%s%s" % [spell.spell_name, level_text]
		var icon_tex := spell.get_icon_texture()
		if icon_tex != null:
			card.icon = icon_tex
			card.expand_icon = true
			card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.pressed.connect(_show_spell_upgrade_detail.bind(path))
		grid.add_child(card)

## Возвращает {"vb": VBoxContainer, "overlay": Control} — оверлей библиотеки, но с фоном,
## по клику (любой кнопкой) возвращающим к списку заклинаний, а не закрывающим комнату целиком.
func _build_spell_detail_overlay(panel_size: Vector2) -> VBoxContainer:
	_close_library_window()
	_screen._library_overlay = Control.new()
	_screen._library_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen._library_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen._library_overlay.z_index = 1000
	_screen.add_child(_screen._library_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_show_library_spell_upgrade_window()
	)
	_screen._library_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._library_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = panel_size
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)
	return vb

## Подробности улучшения: слева — заклинание как сейчас, справа — каким станет,
## золотая стрелка между ними, под стрелкой — стоимость. Внизу «Улучшить» и «Назад».
## Также можно закрыть подробности (вернуться к списку) кликом любой кнопкой мыши по фону.
func _show_spell_upgrade_detail(path: String) -> void:
	var spell := load(path) as SpellResource
	if spell == null:
		return
	var vb := _build_spell_detail_overlay(CampaignScreen.ROOM_PANEL_SIZE)

	var title := Label.new()
	title.text = spell.spell_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vb.add_child(title)

	var current_level := CampaignState.get_spell_upgrade_level(path)
	var can_upgrade := CampaignState.can_upgrade_spell(path)

	if not can_upgrade:
		var maxed_label := Label.new()
		maxed_label.text = "Заклинание улучшено до максимума (уровень 2/2)."
		maxed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		maxed_label.add_theme_font_size_override("font_size", 16)
		vb.add_child(maxed_label)
	else:
		var next_level := current_level + 1
		var current_display := SpellUpgradeData.get_display(spell, current_level)
		var next_display := SpellUpgradeData.get_display(spell, next_level)

		var compare_row := HBoxContainer.new()
		compare_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		compare_row.add_theme_constant_override("separation", 24)
		vb.add_child(compare_row)

		var left_panel := _make_spell_stage_panel("Сейчас (ур. %d)" % current_level, spell, current_display)
		left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_panel.size_flags_stretch_ratio = 1.0
		left_panel.custom_minimum_size = Vector2(320, 220)
		compare_row.add_child(left_panel)

		var arrow_col := VBoxContainer.new()
		arrow_col.alignment = BoxContainer.ALIGNMENT_CENTER
		arrow_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		arrow_col.add_theme_constant_override("separation", 6)
		var arrow_label := Label.new()
		arrow_label.text = "➜"
		arrow_label.add_theme_font_size_override("font_size", 40)
		arrow_label.add_theme_color_override("font_color", CampaignScreen.GOD_DETAIL_ACCENT_COLOR)
		arrow_col.add_child(arrow_label)

		var cost := CampaignState.get_spell_upgrade_next_cost(path)
		var thoughts_cost: int = int(cost["thoughts"])
		var essence_path: String = str(cost["essence_path"])
		var thoughts_amount := CampaignState.get_currency_amount(CampaignState.THOUGHTS_PATH)
		var cost_label := Label.new()
		var cost_text := "%d мыслей" % thoughts_cost
		if next_level == 2:
			if essence_path != "":
				var essence_res := load(essence_path) as ItemResource
				var essence_name := essence_res.item_name if essence_res != null else "эссенция"
				cost_text += " + 1 (%s)" % essence_name
			else:
				cost_text += " + 1 эссенция (нет в наличии)"
		cost_label.text = cost_text
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override("font_size", 15)
		var affordable := thoughts_amount >= thoughts_cost and (next_level == 1 or essence_path != "")
		if not affordable:
			cost_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		arrow_col.add_child(cost_label)
		compare_row.add_child(arrow_col)

		var right_panel := _make_spell_stage_panel("Станет (ур. %d)" % next_level, spell, next_display)
		right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_panel.size_flags_stretch_ratio = 1.0
		right_panel.custom_minimum_size = Vector2(320, 220)
		compare_row.add_child(right_panel)

		var upgrade_row := CenterContainer.new()
		upgrade_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(upgrade_row)

		var upgrade_btn := Button.new()
		upgrade_btn.text = "Улучшить"
		upgrade_btn.custom_minimum_size = Vector2(220, 48)
		upgrade_btn.add_theme_font_size_override("font_size", 18)
		upgrade_btn.disabled = not affordable
		if not affordable:
			upgrade_btn.tooltip_text = "Недостаточно ресурсов для улучшения"
		upgrade_btn.pressed.connect(_do_upgrade_spell.bind(path))
		upgrade_row.add_child(upgrade_btn)

	var back_btn := Button.new()
	back_btn.text = "← Назад"
	back_btn.custom_minimum_size = Vector2(0, 36)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.pressed.connect(_show_library_spell_upgrade_window)
	vb.add_child(back_btn)

## Карточка одной стадии заклинания (текущей или следующей) для сравнения в подробностях.
func _make_spell_stage_panel(stage_title: String, spell: SpellResource, display: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 220)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)

	var stage_label := Label.new()
	stage_label.text = stage_title
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.add_theme_font_size_override("font_size", 14)
	stage_label.add_theme_color_override("font_color", CampaignScreen.GOD_DETAIL_ACCENT_DIM_COLOR)
	inner.add_child(stage_label)

	var icon_tex := spell.get_icon_texture()
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(0, 64)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		inner.add_child(icon)

	var name_label := Label.new()
	name_label.text = spell.spell_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	inner.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "Стоимость: %d фантазии" % int(display["cost"])
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 14)
	inner.add_child(cost_label)

	var desc_label := Label.new()
	desc_label.text = str(display["description"])
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 13)
	inner.add_child(desc_label)

	return panel

func _do_upgrade_spell(path: String) -> void:
	if not CampaignState.upgrade_spell(path):
		_show_spell_upgrade_detail(path)
		return
	_screen._roster._refresh_currencies()
	var spell := load(path) as SpellResource
	var spell_name := spell.spell_name if spell != null else "Заклинание"
	var new_level := CampaignState.get_spell_upgrade_level(path)
	_show_library_result(
		"Сюжет осмыслен!",
		"«%s» улучшено до уровня %d." % [spell_name, new_level]
	)

func _show_library_result(title_text: String, message: String) -> void:
	var vb := _build_library_overlay(CampaignScreen.ROOM_PANEL_SIZE)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	var msg := Label.new()
	msg.text = message
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 16)
	vb.add_child(msg)

	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.custom_minimum_size = Vector2(0, 48)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(_close_library_window)
	vb.add_child(close_btn)
