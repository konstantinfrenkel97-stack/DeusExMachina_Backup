extends RefCounted
class_name CampaignGodDetail

## Окно бога: характеристики, способности, экипировка и выбор артефактов.
##
## Выделено из campaign_screen.gd. Состояние боя/экрана и прочие методы — через `_screen.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _screen: CampaignScreen

func _init(owner_scene: CampaignScreen) -> void:
	_screen = owner_scene

func _make_god_detail_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CampaignScreen.GOD_DETAIL_BG_COLOR
	style.border_color = CampaignScreen.GOD_DETAIL_ACCENT_COLOR
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _make_god_separator() -> HSeparator:
	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = CampaignScreen.GOD_DETAIL_ACCENT_DIM_COLOR
	line.thickness = 2
	sep.add_theme_stylebox_override("separator", line)
	return sep

func _style_god_scrollbar(scroll: ScrollContainer) -> void:
	var scrollbar := scroll.get_v_scroll_bar()
	if scrollbar == null:
		return
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = CampaignScreen.GOD_DETAIL_ACCENT_DIM_COLOR
	grabber.corner_radius_top_left = 3
	grabber.corner_radius_top_right = 3
	grabber.corner_radius_bottom_left = 3
	grabber.corner_radius_bottom_right = 3
	var grabber_hover := StyleBoxFlat.new()
	grabber_hover.bg_color = CampaignScreen.GOD_DETAIL_ACCENT_COLOR
	grabber_hover.corner_radius_top_left = 3
	grabber_hover.corner_radius_top_right = 3
	grabber_hover.corner_radius_bottom_left = 3
	grabber_hover.corner_radius_bottom_right = 3
	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("grabber", grabber)
	scrollbar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	scrollbar.add_theme_stylebox_override("grabber_pressed", grabber_hover)

func _show_god_detail(god_path: String) -> void:
	_close_god_detail()
	_screen._current_god_path = god_path
	_screen._current_god_res = CampaignState.load_character_resource(god_path)
	if _screen._current_god_res == null:
		return

	var vp_size := _screen.get_viewport().get_visible_rect().size

	_screen._god_overlay = Control.new()
	_screen._god_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen._god_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Выше портретов богов (ROSTER_Z_INDEX = 80) — иначе страница персонажа рисовалась
	# бы под ними.
	_screen._god_overlay.z_index = 1000

	var dark_bg := ColorRect.new()
	dark_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_bg.color = Color(0, 0, 0, 0.75)
	# Любой клик по тёмному фону (вне панели) закрывает страницу.
	dark_bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_god_detail()
	)
	_screen._god_overlay.add_child(dark_bg)

	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE — клики мимо панели проходят сквозь к dark_bg и закрывают страницу.
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._god_overlay.add_child(center)

	var roster_top := vp_size.y - CampaignScreen.CAMPAIGN_BOTTOM_BAR_MIN_HEIGHT - CampaignScreen.ROSTER_BOTTOM_GAP - CampaignScreen._RosterSlot.SLOT_SIZE.y
	var panel_top := CampaignScreen.GOD_DETAIL_TOP_MARGIN
	var panel_bottom := maxf(panel_top + 360.0, roster_top - CampaignScreen.GOD_DETAIL_ROSTER_GAP)
	var panel_size := Vector2(vp_size.x * 0.8, panel_bottom - panel_top)
	var panel := PanelContainer.new()
	panel.position = Vector2((vp_size.x - panel_size.x) * 0.5, panel_top)
	panel.size = panel_size
	panel.custom_minimum_size = panel_size
	panel.add_theme_stylebox_override("panel", _make_god_detail_panel_style())
	# Правый клик по панели тоже закрывает страницу.
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_close_god_detail()
	)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var main_hb := HBoxContainer.new()
	main_hb.add_theme_constant_override("separation", 16)
	margin.add_child(main_hb)

	# Левая колонка: статы + умения.
	main_hb.add_child(_build_god_left_column())

	# Центральная колонка: экипировка + большой спрайт + полоски.
	var center_col := _build_god_center_column()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hb.add_child(center_col)

	_screen.add_child(_screen._god_overlay)


# ── Левая колонка ──

func _build_god_left_column() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)
	_style_god_scrollbar.call_deferred(scroll)

	var res := _screen._current_god_res

	var title := Label.new()
	title.text = res.unit_name
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	if res.is_dead:
		var dead_lbl := Label.new()
		dead_lbl.text = "☠ Мёртв"
		dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dead_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		dead_lbl.add_theme_font_size_override("font_size", 18)
		vb.add_child(dead_lbl)

	vb.add_child(_make_god_separator())

	var stats_title := Label.new()
	stats_title.text = "Характеристики"
	stats_title.add_theme_font_size_override("font_size", 18)
	vb.add_child(stats_title)

	vb.add_child(_screen._make_stat_icon_row("health", "%d" % res.max_hp))
	vb.add_child(_screen._make_stat_icon_row("attack", "%d" % res.damage))
	vb.add_child(_screen._make_stat_icon_row("armor", "%d" % res.armor))
	vb.add_child(_screen._make_stat_icon_row("initiative", "%d" % res.initiative))
	vb.add_child(_screen._make_stat_icon_row("accuracy", "%d" % res.accuracy))
	vb.add_child(_screen._make_stat_icon_row("evasion", "%d" % res.evasion))
	vb.add_child(_screen._make_stat_icon_row("luck", "%d%%" % int(res.crit_chance * 100)))

	var fade_mult := res.get_forgetting_multiplier()
	if fade_mult < 1.0:
		var penalty := Label.new()
		penalty.text = "Штраф забвения: −%d%%" % int((1.0 - fade_mult) * 100)
		penalty.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
		penalty.add_theme_font_size_override("font_size", 14)
		vb.add_child(penalty)

	vb.add_child(_make_god_separator())

	var abilities_title := Label.new()
	abilities_title.text = "Умения"
	abilities_title.add_theme_font_size_override("font_size", 18)
	vb.add_child(abilities_title)

	var abilities: Array[AbilityResource] = []
	for ability in res.active_abilities:
		if ability != null:
			abilities.append(ability)
	if res.ultimate_ability != null:
		abilities.append(res.ultimate_ability)

	if abilities.size() > 0:
		var abilities_grid := GridContainer.new()
		abilities_grid.columns = max(1, int(ceil(float(abilities.size()) / 2.0)))
		abilities_grid.add_theme_constant_override("h_separation", 8)
		abilities_grid.add_theme_constant_override("v_separation", 8)
		abilities_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for ability in abilities:
			abilities_grid.add_child(_make_ability_button(ability))
		vb.add_child(abilities_grid)

	return scroll

func _make_ability_button(ability: AbilityResource) -> Button:
	var btn: Button = CampaignScreen.STAT_ICON_TOOLTIP_BUTTON_SCRIPT.new()
	var icon := ability.get_icon_texture()
	btn.icon = icon
	btn.text = "" if icon != null else ability.name
	btn.add_theme_font_size_override("font_size", 15)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER if icon != null else HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = CampaignScreen._ABILITY_ICON_BUTTON_SIZE if icon != null else Vector2(0, 36)
	btn.size = CampaignScreen._ABILITY_ICON_BUTTON_SIZE if icon != null else btn.size
	btn.expand_icon = icon != null
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.clip_text = true
	# Тултип всплывает при наведении — так же, как в бою.
	btn.tooltip_text = _format_ability_tooltip(ability)
	btn.rich_tooltip_text = btn.tooltip_text
	return btn

## Формирует подробный текст тултипа умения (аналогично боевому _get_ability_tooltip).
func _format_ability_tooltip(ability: AbilityResource) -> String:
	var lines: Array[String] = []
	lines.append("=== %s ===" % ability.get_display_name())
	var ability_description: String = ability.get_display_description().strip_edges()
	if not DataTables.is_placeholder_description(ability_description):
		lines.append(ability_description)
		lines.append("")
	if ability.damage_modifier > 0:
		lines.append("Урон: %d%% от атаки" % int(ability.damage_modifier * 100))
		if ability.damage_type != "" and ability.damage_type != "Physical":
			lines.append("Тип урона: %s" % ability.damage_type)
	if ability.majesty_cost > 0:
		lines.append("Стоимость: %d величия" % ability.majesty_cost)
	if ability.majesty_gain > 0:
		lines.append("Величие: +%d" % ability.majesty_gain)
	if ability.target_type != "":
		lines.append("Цель: %s" % DataTables.get_target_type_name(ability.target_type))
	if ability.extra_targets_count > 0:
		lines.append("Доп. цели: +%d цель" % ability.extra_targets_count)
	if ability.effect_types.size() > 0:
		lines.append("")
		lines.append("Эффекты:")
		for effect in ability.effect_types:
			var val: int = int(ability.effect_values.get(effect, 0))
			var dur: int = int(ability.effect_durations.get(effect, 1))
			var dur_text: String = "навсегда" if dur == -1 else "%d ход." % dur
			lines.append("  • %s [%s]" % [DataTables.describe_effect(effect, val), dur_text])
	var extra_lines: Array[String] = []
	var extra_description: String = ability.get_display_extra_effect_description().strip_edges()
	if not DataTables.is_placeholder_description(extra_description):
		extra_lines.append(extra_description)
	if ability.never_miss:
		extra_lines.append("Не может промахнуться.")
	if ability.breaks_enemy_stances:
		extra_lines.append("Сбивает стойку цели.")
	if ability.is_stance:
		var stance_line: String = "Стойка"
		if ability.stance_duration_type != "":
			stance_line += " (%s)" % ability.stance_duration_type
		extra_lines.append(stance_line + ".")
		var stance_description: String = DataTables.get_stance_effect_description(ability.stance_effect_type)
		var current_text_for_stance: String = "\n".join(lines)
		if extra_lines.size() > 0:
			current_text_for_stance += "\n" + "\n".join(extra_lines)
		if DataTables.should_append_detail(current_text_for_stance, stance_description):
			extra_lines.append(stance_description)
	if ability.condition != "":
		var condition_line: String = "Срабатывает %s" % DataTables.get_condition_name(ability.condition)
		if ability.condition_effect != "":
			var cond_val: int = ability.condition_effect_value
			var cond_dur: int = ability.condition_effect_duration
			var cond_dur_text: String = "навсегда" if cond_dur == -1 else "%d ход." % cond_dur
			condition_line += ": %s [%s]" % [DataTables.describe_effect(ability.condition_effect, cond_val), cond_dur_text]
		condition_line += "."
		extra_lines.append(condition_line)
	if ability.mark_type != "":
		var mark_line: String = "Отложенная метка: %s, позиция %d, сторона: %s" % [DataTables.get_mark_type_name(ability.mark_type), ability.mark_position + 1, ability.mark_target_team]
		if ability.mark_duration > 0:
			mark_line += ", %d ход." % ability.mark_duration
		else:
			mark_line += "."
		extra_lines.append(mark_line)
		if ability.mark_damage_percent > 0:
			extra_lines.append("После метки наносит %d%% от текущей атаки." % ability.mark_damage_percent)
		if ability.mark_effect_type != "":
			var mark_dur_text: String = "навсегда" if ability.mark_effect_duration == -1 else "%d ход." % ability.mark_effect_duration
			extra_lines.append("Эффект метки: %s [%s]" % [DataTables.describe_effect(ability.mark_effect_type, ability.mark_effect_value), mark_dur_text])
	var marker_description: String = DataTables.get_ability_marker_description(ability.ability_marker)
	var current_text_for_marker: String = "\n".join(lines)
	if extra_lines.size() > 0:
		current_text_for_marker += "\n" + "\n".join(extra_lines)
	if DataTables.should_append_detail(current_text_for_marker, marker_description):
		extra_lines.append(marker_description)
	if extra_lines.size() > 0:
		lines.append("")
		lines.append("Дополнительно:")
		for extra_line in extra_lines:
			lines.append("  • %s" % extra_line)
	lines.append("")
	lines.append_array(CampaignScreen.StatIconFormatter.ability_position_lines(ability, false))
	return "\n".join(lines)

func _build_god_center_column() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)

	var res := _screen._current_god_res

	# Верхний ряд: спрайт слева, слоты экипировки справа от него.
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	vb.add_child(top_row)

	if res.sprite_path != "":
		var tex := load(res.sprite_path) as Texture2D
		if tex != null:
			var tex_rect := TextureRect.new()
			tex_rect.texture = tex
			tex_rect.custom_minimum_size = Vector2(340, 340)
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			top_row.add_child(tex_rect)

	var equip_col := VBoxContainer.new()
	equip_col.alignment = BoxContainer.ALIGNMENT_CENTER
	equip_col.add_theme_constant_override("separation", 14)
	top_row.add_child(equip_col)

	for slot_info in [
		{"type": 0, "label": "Оружие", "item": res.equipped_weapon},
		{"type": 1, "label": "Броня", "item": res.equipped_armor},
		{"type": 2, "label": "Безделушка", "item": res.equipped_trinket},
	]:
		equip_col.add_child(_make_equip_slot_entry(slot_info["type"], slot_info["label"], slot_info["item"]))

	vb.add_child(_make_god_separator())

	# Полоска здоровья.
	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = res.max_hp
	hp_bar.value = res.max_hp
	hp_bar.custom_minimum_size = Vector2(300, 26)
	hp_bar.show_percentage = false
	vb.add_child(_make_bar_with_label("HP", hp_bar, "%d / %d" % [res.max_hp, res.max_hp], Color(0.3, 0.8, 0.3)))

	# Полоска забвения.
	var fade_bar := ProgressBar.new()
	fade_bar.min_value = 0
	fade_bar.max_value = 5.0
	fade_bar.value = res.forgetting_level
	fade_bar.custom_minimum_size = Vector2(300, 26)
	fade_bar.show_percentage = false
	vb.add_child(_make_bar_with_label("Забвение", fade_bar, "%.1f / 5.0" % res.forgetting_level, Color(0.28, 0.08, 0.4)))

	# Ролевая подсказка — в свободном месте под полосками, только если задана
	# (у врагов CharacterResource.role_description всегда пусто).
	if res.role_description.strip_edges() != "":
		vb.add_child(_make_god_separator())
		var role_lbl := Label.new()
		role_lbl.text = res.role_description
		role_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role_lbl.custom_minimum_size = Vector2(300, 0)
		role_lbl.add_theme_font_size_override("font_size", 14)
		vb.add_child(role_lbl)
		if not res.priority_positions.is_empty():
			var positions: Array[String] = []
			for pos in res.priority_positions:
				positions.append(str(pos))
			var priority_lbl := Label.new()
			priority_lbl.text = "Приоритетные позиции: %s" % " / ".join(positions)
			priority_lbl.add_theme_font_size_override("font_size", 14)
			priority_lbl.add_theme_color_override("font_color", CampaignScreen.GOD_DETAIL_ACCENT_DIM_COLOR)
			vb.add_child(priority_lbl)

	return vb

## Одна ячейка экипировки: название типа НАД ячейкой, сама ячейка — только иконка предмета
## (без текста), клик открывает окно выбора артефакта поверх страницы.
func _make_equip_slot_entry(slot_type: int, slot_label: String, item: ItemResource) -> Control:
	var wrap := VBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 4)

	var type_lbl := Label.new()
	type_lbl.text = slot_label
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_font_size_override("font_size", 13)
	type_lbl.add_theme_color_override("font_color", CampaignScreen.GOD_DETAIL_ACCENT_DIM_COLOR)
	wrap.add_child(type_lbl)

	var slot_btn: Button = CampaignScreen.STAT_ICON_TOOLTIP_BUTTON_SCRIPT.new()
	slot_btn.custom_minimum_size = Vector2(86, 86)
	if item != null:
		slot_btn.tooltip_text = item.item_name
		slot_btn.rich_tooltip_text = _item_info_bbcode(item)
		slot_btn.rich_tooltip_is_bbcode = true
	else:
		slot_btn.tooltip_text = "Пусто"
	slot_btn.pressed.connect(_show_equip_picker.bind(slot_type))
	_screen._apply_tight_icon_button_style(slot_btn)
	if item != null and item.icon != null:
		slot_btn.icon = item.icon
		slot_btn.expand_icon = true
		slot_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		slot_btn.text = "+"
		slot_btn.add_theme_font_size_override("font_size", 30)

	wrap.add_child(slot_btn)
	return wrap

func _make_bar_with_label(label_text: String, bar: ProgressBar, value_text: String, color: Color) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)

	var hb := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = value_text
	val_lbl.add_theme_font_size_override("font_size", 14)
	hb.add_child(val_lbl)
	wrapper.add_child(hb)

	bar.modulate = color
	wrapper.add_child(bar)

	return wrapper


# ── Инвентарь и экипировка ──

## Открывает окно выбора артефакта поверх страницы персонажа (не меняет саму страницу).
func _show_equip_picker(slot_type: int) -> void:
	_close_equip_picker()
	_screen._current_slot_type = slot_type

	_screen._equip_picker_overlay = Control.new()
	_screen._equip_picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen._equip_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen._equip_picker_overlay.z_index = 1200  # поверх страницы персонажа (z_index 1000)
	_screen.add_child(_screen._equip_picker_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_equip_picker()
	)
	_screen._equip_picker_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen._equip_picker_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 460)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "Выбор: %s" % CampaignScreen._EQUIP_SLOT_NAMES[slot_type]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	var unequip_btn := Button.new()
	unequip_btn.text = "Снять экипировку"
	unequip_btn.custom_minimum_size = Vector2(200, 40)
	unequip_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	unequip_btn.pressed.connect(_unequip_current_slot)
	vb.add_child(unequip_btn)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	vb.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 2.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	# Панель информации о предмете (справа), заполняется при наведении на карточку.
	_screen._equip_picker_info_panel = PanelContainer.new()
	_screen._equip_picker_info_panel.custom_minimum_size = Vector2(180, 0)
	_screen._equip_picker_info_panel.add_theme_stylebox_override("panel", _screen._make_info_panel_style())
	body.add_child(_screen._equip_picker_info_panel)
	_screen._equip_picker_info_label = RichTextLabel.new()
	_screen._equip_picker_info_label.bbcode_enabled = true
	_screen._equip_picker_info_label.fit_content = false
	_screen._equip_picker_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen._equip_picker_info_label.add_theme_font_size_override("normal_font_size", 14)
	_screen._equip_picker_info_label.add_theme_font_size_override("bold_font_size", 16)
	_screen._equip_picker_info_label.text = "[i]Наведите на артефакт, чтобы увидеть описание[/i]"
	_screen._equip_picker_info_panel.add_child(_screen._equip_picker_info_label)

	var needed_type: int = slot_type
	var found_any := false
	# Один и тот же артефакт может быть в сокровищнице несколько раз (см.
	# CampaignState.add_item) — считаем количество копий на путь, чтобы отличить
	# "есть свободная копия" от "все копии уже на ком-то надеты".
	var owned_counts: Dictionary = {}
	for item_path in CampaignState.treasury:
		owned_counts[item_path] = int(owned_counts.get(item_path, 0)) + 1

	for item_path in owned_counts.keys():
		var item := load(item_path) as ItemResource
		if item == null:
			continue
		if item.item_type != needed_type:
			continue
		if item.restricted_god_path != "" and item.restricted_god_path != _screen._current_god_path:
			continue
		# Предмет нельзя надеть на двух богов одновременно: сколько копий владеем минус
		# сколько уже надето на ДРУГИХ богов (свой же текущий слот в счёт не идёт —
		# заново выбрать то, что уже на тебе, не должно "съедать" последнюю копию).
		var available_copies: int = int(owned_counts[item_path]) - _count_item_equipped_elsewhere(item_path)
		if available_copies <= 0:
			continue
		found_any = true
		grid.add_child(_make_equip_picker_card(item, item_path))

	if not found_any:
		var empty := Label.new()
		empty.text = "Нет подходящих предметов"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 14)
		grid.add_child(empty)

## Карточка предмета в окне выбора: только иконка на всю ячейку, наведение обновляет
## информационную панель, клик — экипирует.
func _make_equip_picker_card(item: ItemResource, item_path: String) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(92, 92)
	card.tooltip_text = item.item_name
	_screen._apply_tight_icon_button_style(card)

	if item.icon != null:
		card.icon = item.icon
		card.expand_icon = true
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		card.text = item.item_name

	card.mouse_entered.connect(_show_equip_picker_item_info.bind(item))
	card.pressed.connect(_equip_item.bind(item_path))
	return card

## Заполняет info-панель описанием предмета (наведение на карточку в окне выбора).
func _show_equip_picker_item_info(item: ItemResource) -> void:
	if _screen._equip_picker_info_label == null or not is_instance_valid(_screen._equip_picker_info_label):
		return
	_screen._equip_picker_info_label.text = _item_info_bbcode(item)

## Сколько других богов (не _current_god_path) уже держат item_path в каком-либо
## из своих трёх слотов экипировки — см. _show_equip_picker().
func _count_item_equipped_elsewhere(item_path: String) -> int:
	var count := 0
	for god_path in CampaignState.available_gods:
		if god_path == _screen._current_god_path:
			continue
		var state: Dictionary = CampaignState.get_god_state(god_path)
		var equipment: Array = state.get("equipment_paths", [])
		if equipment.has(item_path):
			count += 1
	return count

func _close_equip_picker() -> void:
	if _screen._equip_picker_overlay != null and is_instance_valid(_screen._equip_picker_overlay):
		_screen._equip_picker_overlay.queue_free()
	_screen._equip_picker_overlay = null
	_screen._equip_picker_info_panel = null
	_screen._equip_picker_info_label = null

func _item_bonus_summary(item: ItemResource) -> String:
	var parts: Array[String] = []
	if item.bonus_max_hp != 0:
		parts.append("HP %+d" % item.bonus_max_hp)
	if item.bonus_damage != 0:
		parts.append("Урон %+d" % item.bonus_damage)
	if item.bonus_armor != 0:
		parts.append("Броня %+d" % item.bonus_armor)
	if item.bonus_initiative != 0:
		parts.append("Иниц %+d" % item.bonus_initiative)
	if item.bonus_accuracy != 0:
		parts.append("Точ %+d" % item.bonus_accuracy)
	if item.bonus_evasion != 0:
		parts.append("Укл %+d" % item.bonus_evasion)
	if item.bonus_crit_chance != 0.0:
		parts.append("Крит %+d%%" % int(item.bonus_crit_chance * 100))
	if item.bonus_majesty != 0:
		parts.append("Величие %+d" % item.bonus_majesty)
	if item.fantasy_regen_per_turn != 0:
		parts.append("Фантазия %+d/ход" % item.fantasy_regen_per_turn)
	if item.majesty_regen_per_turn != 0:
		parts.append("Величие %+d/ход" % item.majesty_regen_per_turn)
	if item.hp_regen_percent != 0.0:
		parts.append("Реген %+.0f%%/ход" % item.hp_regen_percent)
	if parts.is_empty():
		return ""
	return " | ".join(parts)

## То же самое, что _item_bonus_summary, но каждая характеристика — иконка стата
## (BBCode [img], безопасный фиксированный размер) вместо текстовой подписи.
## Для RichTextLabel с bbcode_enabled = true.
func _item_bonus_icon_lines(item: ItemResource) -> Array[String]:
	var lines: Array[String] = []
	var icon_stat := func(key: String, value_text: String) -> String:
		return "%s %s" % [CampaignScreen.StatIconFormatter.stat_icon_bbcode(key), value_text]
	if item.bonus_max_hp != 0:
		lines.append(icon_stat.call("health", "%+d" % item.bonus_max_hp))
	if item.bonus_damage != 0:
		lines.append(icon_stat.call("attack", "%+d" % item.bonus_damage))
	if item.bonus_armor != 0:
		lines.append(icon_stat.call("armor", "%+d" % item.bonus_armor))
	if item.bonus_initiative != 0:
		lines.append(icon_stat.call("initiative", "%+d" % item.bonus_initiative))
	if item.bonus_accuracy != 0:
		lines.append(icon_stat.call("accuracy", "%+d" % item.bonus_accuracy))
	if item.bonus_evasion != 0:
		lines.append(icon_stat.call("evasion", "%+d" % item.bonus_evasion))
	if item.bonus_crit_chance != 0.0:
		lines.append(icon_stat.call("luck", "%+d%%" % int(item.bonus_crit_chance * 100)))
	if item.bonus_majesty != 0:
		lines.append(icon_stat.call("glory", "%+d" % item.bonus_majesty))
	if item.fantasy_regen_per_turn != 0:
		lines.append(icon_stat.call("fantasy", "%+d/ход" % item.fantasy_regen_per_turn))
	if item.majesty_regen_per_turn != 0:
		lines.append(icon_stat.call("glory", "%+d/ход" % item.majesty_regen_per_turn))
	if item.hp_regen_percent != 0.0:
		lines.append(icon_stat.call("health", "%+.0f%%/ход" % item.hp_regen_percent))
	return lines

## Строит полный BBCode-текст информационной панели предмета: имя, редкость,
## ограничение по богу, характеристики иконками, эффект. Используется и во
## всплывающей панели окна выбора, и в тултипе экипированного слота.
func _item_info_bbcode(item: ItemResource) -> String:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % item.item_name)
	lines.append(item.get_rarity_name())
	if item.restricted_god_path != "":
		var owner_res := CampaignState.load_character_resource(item.restricted_god_path)
		if owner_res != null:
			lines.append("Только для: %s" % owner_res.unit_name)
	var bonus_lines := _item_bonus_icon_lines(item)
	if not bonus_lines.is_empty():
		lines.append("")
		lines.append("[b]Характеристики:[/b]")
		lines.append_array(bonus_lines)
	if item.description.strip_edges() != "":
		lines.append("")
		lines.append("[b]Эффект:[/b]")
		lines.append(item.description)
	return "\n".join(lines)

func _equip_item(item_path: String) -> void:
	var item := load(item_path) as ItemResource
	if item == null:
		return
	if item.restricted_god_path != "" and item.restricted_god_path != _screen._current_god_path:
		return
	match _screen._current_slot_type:
		0: _screen._current_god_res.equipped_weapon = item
		1: _screen._current_god_res.equipped_armor = item
		2: _screen._current_god_res.equipped_trinket = item
	CampaignState.set_god_equipment_path(_screen._current_god_path, _screen._current_slot_type, item_path)
	_close_equip_picker()
	_refresh_god_detail()

func _unequip_current_slot() -> void:
	match _screen._current_slot_type:
		0: _screen._current_god_res.equipped_weapon = null
		1: _screen._current_god_res.equipped_armor = null
		2: _screen._current_god_res.equipped_trinket = null
	CampaignState.set_god_equipment_path(_screen._current_god_path, _screen._current_slot_type, "")
	_close_equip_picker()
	_refresh_god_detail()

func _refresh_god_detail() -> void:
	if _screen._current_god_path == "":
		return
	var path := _screen._current_god_path
	_close_god_detail()
	_show_god_detail(path)

func _close_god_detail() -> void:
	_close_equip_picker()
	if _screen._god_overlay != null and is_instance_valid(_screen._god_overlay):
		_screen._god_overlay.queue_free()
		_screen._god_overlay = null
	_screen._current_god_path = ""
	_screen._current_god_res = null
	_screen._current_slot_type = -1
