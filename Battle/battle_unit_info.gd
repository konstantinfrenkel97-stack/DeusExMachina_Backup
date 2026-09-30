extends RefCounted
class_name BattleUnitInfo

## Информационная панель юнита при наведении, тултипы способностей, превью попадания по цели.
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

## Создаёт панель информации о юните (показывается при наведении)
func _setup_hover_info_panel():
	# Статус-строка — чисто показательный элемент: не должна перехватывать клики
	# по юнитам (иначе её полоса 16..700 x 268..300 перекрывает Area2D передних врагов).
	if _scene.status_label:
		_scene.status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# === Панель наведения на юнитов ===
	_scene._hover_info_panel = PanelContainer.new()
	_position_hover_info_panel()
	_scene._hover_info_panel.z_index = 100
	# Панель и текст НЕ перехватывают клики (mouse_filter IGNORE).
	# Иначе панель 440..1200 x 16..320 перекрывает передний ряд врагов (Йотун в Pos1
	# стоит в ~640,300) и блокирует Area2D — клик «то проходит, то нет».
	_scene._hover_info_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_scene._hover_content = HBoxContainer.new()
	_scene._hover_content.add_theme_constant_override("separation", 10)
	_scene._hover_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scene._hover_info_panel.add_child(_scene._hover_content)
	# fit_content=true заставляет RichTextLabel расти под свой текст, игнорируя
	# заданный size — при длинном описании (пассивка + стойка + бафы) панель
	# вылезала за нижний край экрана. Оборачиваем в ScrollContainer: сам лейбл
	# по-прежнему растёт под контент, но видимая область ограничена размером
	# скролл-контейнера (задаётся в _position_hover_info_panel), а всё, что не
	# влезло, доступно прокруткой, а не обрезкой за пределами экрана.
	_scene._hover_label = RichTextLabel.new()
	_scene._hover_label.bbcode_enabled = true
	_scene._hover_label.hint_underlined = false
	_scene._hover_label.scroll_following = false
	_scene._hover_label.fit_content = true
	_scene._hover_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_scene._hover_label_scroll = ScrollContainer.new()
	_scene._hover_label_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scene._hover_label_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_scene._hover_label_scroll.add_child(_scene._hover_label)
	_scene._hover_content.add_child(_scene._hover_label_scroll)
	_scene._hover_ability_grid = GridContainer.new()
	_scene._hover_ability_grid.columns = 3
	_scene._hover_ability_grid.add_theme_constant_override("h_separation", int(BattleScene.ABILITY_BUTTON_GAP))
	_scene._hover_ability_grid.add_theme_constant_override("v_separation", int(BattleScene.ABILITY_BUTTON_GAP))
	_scene._hover_ability_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_scene._hover_content.add_child(_scene._hover_ability_grid)
	_scene.get_node("BattleUI").add_child(_scene._hover_info_panel)
	_scene._hover_info_panel.hide()

## Обработчик наведения на юнита
func _position_hover_info_panel() -> void:
	if _scene._hover_info_panel == null:
		return
	var viewport_size := _scene.get_viewport_rect().size
	var left_block_width := BattleScene.ABILITY_ICON_BUTTON_SIZE.x * 5.0 + BattleScene.ABILITY_BUTTON_GAP * 4.0
	if _scene._ability_actions_row != null:
		left_block_width = maxf(left_block_width, _scene._ability_actions_row.size.x)
	var panel_left := 16.0 + left_block_width + 16.0
	var panel_top := _scene._hud._get_bottom_controls_top()
	var panel_right := viewport_size.x - 16.0
	if _scene._spell_panel != null:
		panel_right = minf(panel_right, _scene._spell_panel.offset_left - 16.0)
	if panel_right - panel_left < 360.0:
		panel_right = minf(viewport_size.x - 16.0, panel_left + 560.0)
	var panel_bottom := viewport_size.y - 16.0
	_scene._hover_info_panel.offset_left = panel_left
	_scene._hover_info_panel.offset_top = panel_top
	_scene._hover_info_panel.offset_right = panel_right
	_scene._hover_info_panel.offset_bottom = panel_bottom
	_scene._hover_info_panel.custom_minimum_size = Vector2(panel_right - panel_left, panel_bottom - panel_top)
	_scene._hover_info_panel.size = _scene._hover_info_panel.custom_minimum_size
	var content_width := panel_right - panel_left - 16.0
	var content_height := panel_bottom - panel_top - 12.0
	var ability_grid_width := BattleScene.HOVER_ABILITY_BUTTON_SIZE.x * 3.0 + BattleScene.ABILITY_BUTTON_GAP * 2.0
	if _scene._hover_content != null:
		_scene._hover_content.custom_minimum_size = Vector2(content_width, content_height)
		_scene._hover_content.size = _scene._hover_content.custom_minimum_size
	var hover_label_width := maxf(260.0, content_width - ability_grid_width - 10.0)
	if _scene._hover_label_scroll != null:
		_scene._hover_label_scroll.custom_minimum_size = Vector2(hover_label_width, content_height)
		_scene._hover_label_scroll.size = _scene._hover_label_scroll.custom_minimum_size
	if _scene._hover_label != null:
		_scene._hover_label.custom_minimum_size = Vector2(hover_label_width, 0.0)
	if _scene._hover_ability_grid != null:
		_scene._hover_ability_grid.custom_minimum_size = Vector2(ability_grid_width, content_height)
		_scene._hover_ability_grid.size = _scene._hover_ability_grid.custom_minimum_size

func _show_unit_info_panel(unit: Combatant) -> void:
	if _scene._hover_info_panel == null or _scene._hover_label == null or unit == null:
		return
	_position_hover_info_panel()
	_scene._hover_label.text = _get_unit_hover_text(unit)
	_rebuild_hover_ability_buttons(unit)
	_scene._hover_info_panel.show()

func _apply_hover_ability_button_style(button: Button) -> void:
	button.custom_minimum_size = BattleScene.HOVER_ABILITY_BUTTON_SIZE
	button.size = BattleScene.HOVER_ABILITY_BUTTON_SIZE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.clip_text = true

func _rebuild_hover_ability_buttons(unit: Combatant) -> void:
	if _scene._hover_ability_grid == null:
		return
	for child in _scene._hover_ability_grid.get_children():
		child.queue_free()
	var abilities: Array[AbilityResource] = []
	for ability in unit.active_abilities:
		if ability != null:
			abilities.append(ability)
	if unit.ultimate_ability != null and not abilities.has(unit.ultimate_ability):
		abilities.append(unit.ultimate_ability)
	_scene._hover_ability_grid.visible = not abilities.is_empty()
	for i in range(abilities.size()):
		var ability := abilities[i]
		var btn: Button = BattleScene.STAT_ICON_TOOLTIP_BUTTON_SCRIPT.new()
		_apply_hover_ability_button_style(btn)
		_scene._hud._set_ability_button_content(btn, ability)
		if unit.is_enemy and i < BattleScene.ENEMY_ABILITY_ICON_PATHS.size():
			var enemy_icon_path := str(BattleScene.ENEMY_ABILITY_ICON_PATHS[i])
			if ResourceLoader.exists(enemy_icon_path):
				btn.icon = load(enemy_icon_path) as Texture2D
				btn.text = ""
		btn.tooltip_text = _get_ability_tooltip(ability, unit)
		btn.rich_tooltip_text = btn.tooltip_text
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_scene._hover_ability_grid.add_child(btn)

func _clear_pinned_unit_info() -> void:
	_scene._pinned_hover_unit = null
	if _scene._hover_info_panel != null:
		_scene._hover_info_panel.hide()

## Обработчик наведения на юнит
func _on_unit_hovered(unit: Combatant):
	if _scene._pinned_hover_unit != null:
		return
	_show_unit_info_panel(unit)
	_update_ability_target_preview(unit)

## Обработчик ухода курсора с юнита
func _on_unit_unhovered():
	if _scene._hover_info_panel and _scene._pinned_hover_unit == null:
		_scene._hover_info_panel.hide()
	_clear_ability_target_preview()

## Предпросмотр цели способности при наведении: для ВСЕХ юнитов, которые реально
## получат эффект выбранной способности (с учётом All_Enemies/All_Allies и
## extra_targets_count — не только тот, на кого наведён курсор), показывает шанс
## попадания и (если способность наносит урон) запускает мигание той части HP-
## полоски, которая пропадёт при попадании. Намеренно игнорирует случайные эффекты
## перенаправления атаки (метка невинности/сатир/провокация) — превью показывает
## НАМЕРЕННУЮ цель игрока, а не то, что может произойти после случайного ролла.
func _update_ability_target_preview(hovered: Combatant) -> void:
	_clear_ability_target_preview()
	if not _scene.waiting_for_target or _scene.selected_ability == null or _scene.active_unit == null:
		return
	if hovered == null or hovered.current_hp <= 0:
		return
	if _scene.selected_ability.target_type == "Self" or _scene.selected_ability.target_type == "Position":
		return
	if not _scene._targeting._can_user_target_unit(_scene.active_unit, hovered, _scene.selected_ability):
		return
	var deals_damage: bool = _scene.selected_ability.damage_modifier > 0 and _scene.selected_ability.stance_effect_type != "filibuster_double_hit" and _scene.selected_ability.stance_effect_type != "bombardment_stance"
	for target_value in _resolve_preview_targets(_scene.selected_ability, _scene.active_unit, hovered):
		var target: Combatant = target_value as Combatant
		if target == null or target.current_hp <= 0:
			continue
		var enemy_side: bool = target.is_enemy != _scene.active_unit.is_enemy
		if not deals_damage and not enemy_side:
			continue
		var vis = _scene._field._find_visual_for_unit(target, _scene.hero_visuals)
		if vis == null:
			vis = _scene._field._find_visual_for_unit(target, _scene.enemy_visuals)
		if vis == null or not vis.has_method("show_target_preview"):
			continue
		var hit_chance: float = 1.0
		if not (deals_damage and _scene.active_unit.has_item_effect("baal_eye_never_miss")):
			hit_chance = CombatCalculator.get_hit_chance(_scene.active_unit.accuracy, target.evasion)
		var predicted_damage: int = 0
		if deals_damage:
			predicted_damage = CombatCalculator.preview_ability_damage(_scene.active_unit, target, _scene.selected_ability)
		vis.show_target_preview(hit_chance, predicted_damage)
		_scene._preview_active_visuals.append(vis)

func _clear_ability_target_preview() -> void:
	for vis in _scene._preview_active_visuals:
		if is_instance_valid(vis) and vis.has_method("clear_target_preview"):
			vis.clear_target_preview()
	_scene._preview_active_visuals.clear()

## Разрешение целей способности для превью — та же логика, что в _use_ability()
## (Self/All_Enemies/All_Allies/одиночная цель + extra_targets_count), но БЕЗ
## случайных эффектов перенаправления (см. комментарий у _update_ability_target_preview).
func _resolve_preview_targets(ability: AbilityResource, attacker: Combatant, defender: Combatant) -> Array:
	if ability.target_type == "All_Enemies" or ability.target_type == "All_Allies":
		return _scene._targeting._get_all_targets(ability, attacker)
	var targets: Array = [defender]
	if ability.extra_targets_count > 0:
		var team = _scene.enemies_team if defender.is_enemy else _scene.heroes_team
		for i in range(ability.extra_targets_count):
			var next_pos = defender.position_index + i + 1
			for unit in team:
				if unit and unit.position_index == next_pos and unit.current_hp > 0:
					targets.append(unit)
					break
	return targets

## Формирует BBCode-текст с полной информацией о юните
func _get_unit_hover_text(unit: Combatant) -> String:
	var lines = []
	lines.append("[b]%s[/b] (линия %d)" % [unit.unit_name, unit.position_index + 1])
	lines.append("%s %d / %d" % [_scene._stat_icon_or_text("health", "HP"), unit.current_hp, unit.max_hp])
	var dmg_diff = unit.damage - unit.base_damage
	var arm_diff = unit.armor - unit.base_armor
	var acc_diff = unit.accuracy - unit.base_accuracy
	var eva_diff = unit.evasion - unit.base_evasion
	var crit_diff = unit.crit_chance - unit.base_crit_chance
	var dmg_suffix = " [color=lime](+%d)[/color]" % dmg_diff if dmg_diff > 0 else (" [color=red](%d)[/color]" % dmg_diff if dmg_diff < 0 else "")
	var arm_suffix = " [color=lime](+%d)[/color]" % arm_diff if arm_diff > 0 else (" [color=red](%d)[/color]" % arm_diff if arm_diff < 0 else "")
	var acc_suffix = " [color=lime](+%d)[/color]" % acc_diff if acc_diff > 0 else (" [color=red](%d)[/color]" % acc_diff if acc_diff < 0 else "")
	var eva_suffix = " [color=lime](+%d)[/color]" % eva_diff if eva_diff > 0 else (" [color=red](%d)[/color]" % eva_diff if eva_diff < 0 else "")
	var crit_suffix = " [color=lime](+%d%%)[/color]" % int(crit_diff * 100) if crit_diff > 0 else (" [color=red](%d%%)[/color]" % int(crit_diff * 100) if crit_diff < 0 else "")
	lines.append("%s %d%s | %s %d%s" % [_scene._stat_icon_or_text("attack", "Урон"), unit.damage, dmg_suffix, _scene._stat_icon_or_text("armor", "Броня"), unit.armor, arm_suffix])
	lines.append("%s %d%%%s | %s %d%%%s" % [_scene._stat_icon_or_text("accuracy", "Точность"), unit.accuracy, acc_suffix, _scene._stat_icon_or_text("evasion", "Уклонение"), unit.evasion, eva_suffix])
	lines.append("%s %d%%%s | %s %d" % [_scene._stat_icon_or_text("luck", "Удача"), int(unit.crit_chance * 100), crit_suffix, _scene._stat_icon_or_text("initiative", "Инициатива"), unit.initiative])
	if not unit.is_enemy:
		lines.append("%s %d / 100" % [_scene._stat_icon_or_text("glory", "Величие"), unit.current_majesty])
	var passive = DataTables.get_passive_description(unit.special_effect_type)
	if passive != "":
		lines.append("[color=cyan]%s[/color]" % passive)
	if unit.is_stunned:
		lines.append("[color=red]⚡ Оглушён[/color]")
	if unit.active_stance:
		lines.append("★ Стойка: %s" % unit.active_stance.name)
	return "\n".join(lines)

## Формирует текст тултипа для способности (обычный текст, без BBCode)
func _get_ability_tooltip(ability: AbilityResource, user: Combatant) -> String:
	var lines: Array[String] = []
	lines.append("=== %s ===" % ability.get_display_name())
	var ability_description: String = ability.get_display_description().strip_edges()
	if not DataTables.is_placeholder_description(ability_description):
		lines.append(ability_description)
		lines.append("")

	if ability.damage_modifier > 0:
		if user != null:
			var dmg: int = int(user.damage * ability.damage_modifier)
			lines.append("Урон: %d (%d%% от текущей атаки %d)" % [dmg, int(ability.damage_modifier * 100), user.damage])
		else:
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
			if effect == "target_lose_majesty" or effect == "target_push_back":
				# Мгновенный эффект — длительность не показываем.
				lines.append("  • %s" % DataTables.describe_effect(effect, val))
			else:
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

	# Кружки позиций (токены {pos_*} превращает в картинки тултип-кнопка через StatIconFormatter).
	lines.append("")
	lines.append_array(StatIconFormatter.ability_position_lines(ability, user != null and user.is_enemy))
	return "\n".join(lines)
