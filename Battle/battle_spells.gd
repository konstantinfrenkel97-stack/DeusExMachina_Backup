extends RefCounted
class_name BattleSpells

## Заклинания: загрузка, панель, выбор и применение, списание фантазии/лимитов.
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

func _sort_spells_for_battle_ui() -> void:
	_scene.available_spells.sort_custom(func(a: SpellResource, b: SpellResource) -> bool:
		if a.spell_name == "Ром" and b.spell_name != "Ром":
			return true
		if b.spell_name == "Ром" and a.spell_name != "Ром":
			return false
		return a.resource_path < b.resource_path
	)

func _load_spells() -> void:
	_scene.available_spells.clear()
	_collect_spells_from_dir("res://Spells")
	_sort_spells_for_battle_ui()
	_setup_spell_panel()
	_update_spell_ui()

func _collect_spells_from_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		var path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			_collect_spells_from_dir(path)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var spell := load(path) as SpellResource
			if spell != null and _is_spell_available_for_location(spell):
				_scene.available_spells.append(_apply_spell_upgrade_discount(spell))
		file_name = dir.get_next()
	dir.list_dir_end()

func _is_spell_available_for_location(spell: SpellResource) -> bool:
	var required_location := spell.required_location_id.strip_edges()
	if required_location == "" or required_location == CombatManager.selected_location_id:
		return true
	# Чарка вечного рома: позволяет использовать заклинание «Ром» в любой локации.
	for _rum_hero in _scene.heroes_team:
		if _rum_hero and _rum_hero.current_hp > 0 and _rum_hero.has_item_effect("eternal_rum_cup_anywhere"):
			return true
	return false

## Бесконечная библиотека — "Осмыслять сюжет": применяет уровень улучшения заклинания
## (стоимость + эффект целиком заменяются по SpellUpgradeData, см. Spells/spell_upgrade_data.gd).
## Дублирует ресурс перед изменением — load() возвращает общий закэшированный
## инстанс, менять его напрямую было бы накопительным багом между боями.
func _apply_spell_upgrade_discount(spell: SpellResource) -> SpellResource:
	var level := CampaignState.get_spell_upgrade_level(spell.resource_path)
	if level <= 0:
		return spell
	var data := SpellUpgradeData.get_level_data(spell.resource_path, level)
	if data.is_empty():
		return spell
	var upgraded := spell.duplicate() as SpellResource
	upgraded.fantasy_cost = int(data.get("fantasy_cost", upgraded.fantasy_cost))
	upgraded.description = str(data.get("description", upgraded.description))
	if data.has("effect_types"):
		var new_effect_types: Array[String] = []
		for e in data["effect_types"]:
			new_effect_types.append(str(e))
		upgraded.effect_types = new_effect_types
		upgraded.effect_values = (data.get("effect_values", {}) as Dictionary).duplicate()
		upgraded.effect_durations = (data.get("effect_durations", {}) as Dictionary).duplicate()
	if data.has("flat_damage"):
		upgraded.flat_damage = int(data["flat_damage"])
	upgraded.set_meta("upgrade_level", level)
	upgraded.set_meta("refund_on_kill", bool(data.get("refund_on_kill", false)))
	return upgraded

## Создание панели заклинаний в правом нижнем углу
func _setup_spell_panel():
	var ui_layer = _scene.get_node("BattleUI")
	if not ui_layer:
		return

	var spell_content := VBoxContainer.new()
	spell_content.name = "SpellPanel"
	spell_content.add_theme_constant_override("separation", int(BattleScene.ABILITY_BUTTON_GAP))

	# Заголовок: очки фантазии (иконка + значение), по аналогии со строками характеристик.
	var fantasy_row := HBoxContainer.new()
	fantasy_row.name = "FantasyRow"
	fantasy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fantasy_row.add_theme_constant_override("separation", 6)
	var fantasy_icon := TextureRect.new()
	fantasy_icon.name = "FantasyIcon"
	fantasy_icon.custom_minimum_size = Vector2(BattleScene.STAT_ICON_BBCODE_SIZE, BattleScene.STAT_ICON_BBCODE_SIZE)
	fantasy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fantasy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fantasy_icon.texture = load("res://Icons/fantasy_icon.png") as Texture2D
	fantasy_icon.tooltip_text = "Фантазия"
	fantasy_row.add_child(fantasy_icon)
	_scene._fantasy_label = Label.new()
	_scene._fantasy_label.name = "FantasyLabel"
	_scene._fantasy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fantasy_row.add_child(_scene._fantasy_label)
	spell_content.add_child(fantasy_row)

	var spell_buttons_area := HBoxContainer.new()
	spell_buttons_area.name = "SpellButtonsArea"
	spell_buttons_area.add_theme_constant_override("separation", int(BattleScene.ABILITY_BUTTON_GAP))
	spell_content.add_child(spell_buttons_area)

	var rum_column := VBoxContainer.new()
	rum_column.name = "RumColumn"
	spell_buttons_area.add_child(rum_column)

	var spell_grid := GridContainer.new()
	spell_grid.name = "SpellButtonsGrid"
	spell_grid.columns = 4
	spell_grid.add_theme_constant_override("h_separation", int(BattleScene.ABILITY_BUTTON_GAP))
	spell_grid.add_theme_constant_override("v_separation", int(BattleScene.ABILITY_BUTTON_GAP))
	spell_buttons_area.add_child(spell_grid)

	# Кнопки заклинаний: Ром отдельно слева, остальные справа в сетке 4 колонки.
	_scene._spell_buttons.clear()
	for i in range(_scene.available_spells.size()):
		var btn = Button.new()
		var spell: SpellResource = _scene.available_spells[i]
		var cost = int(spell.fantasy_cost * CombatManager.get_spell_cost_multiplier())
		_apply_spell_button_base_style(btn)
		_set_spell_button_content(btn, spell, cost, false)
		btn.tooltip_text = "%s\nСтоимость: %d фантазии\nТип цели: %s" % [spell.get_display_description(), cost, DataTables.get_target_type_name(spell.target_type)]
		btn.pressed.connect(_on_spell_clicked.bind(i))
		if spell.spell_name == "Ром":
			rum_column.add_child(btn)
		else:
			spell_grid.add_child(btn)
		_scene._spell_buttons.append(btn)
	if rum_column.get_child_count() == 0:
		rum_column.queue_free()

	# Обёртка-панель с фоном
	var panel_bg = PanelContainer.new()
	panel_bg.name = "SpellPanelBG"
	panel_bg.add_child(spell_content)
	ui_layer.add_child(panel_bg)

	# Позиционирование: Ром отдельной кнопкой слева, остальные заклинания в 2 ряда по 4.
	var spell_top := _scene._hud._get_bottom_controls_top()
	var columns := 4
	var has_rum := false
	for spell in _scene.available_spells:
		if spell.spell_name == "Ром":
			has_rum = true
			break
	var grid_count := _scene.available_spells.size() - (1 if has_rum else 0)
	var rows := int(ceil(float(maxi(grid_count, 1)) / float(columns)))
	var grid_width := BattleScene.ABILITY_ICON_BUTTON_SIZE.x * float(columns) + BattleScene.ABILITY_BUTTON_GAP * float(columns - 1)
	var rum_width := BattleScene.ABILITY_ICON_BUTTON_SIZE.x + BattleScene.ABILITY_BUTTON_GAP if has_rum else 0.0
	var panel_width := grid_width + rum_width
	var grid_height := BattleScene.ABILITY_ICON_BUTTON_SIZE.y * float(rows) + BattleScene.ABILITY_BUTTON_GAP * float(maxi(rows - 1, 0))
	var panel_height := 34.0 + BattleScene.ABILITY_BUTTON_GAP + maxf(BattleScene.ABILITY_ICON_BUTTON_SIZE.y, grid_height)
	var viewport_width := _scene.get_viewport_rect().size.x
	var panel_left := maxf(16.0, viewport_width - panel_width - 16.0)
	panel_bg.offset_left = panel_left
	panel_bg.offset_top = spell_top
	panel_bg.offset_right = panel_left + panel_width
	panel_bg.offset_bottom = spell_top + panel_height
	panel_bg.hide()

	# Привязываем _spell_panel к bg-контейнеру.
	_scene._spell_panel = panel_bg

func _apply_spell_button_base_style(button: Button) -> void:
	button.custom_minimum_size = BattleScene.ABILITY_ICON_BUTTON_SIZE
	button.size = BattleScene.ABILITY_ICON_BUTTON_SIZE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.clip_text = true

func _set_spell_button_content(button: Button, spell: SpellResource, cost: int, used: bool) -> void:
	var icon := spell.get_icon_texture()
	button.icon = icon
	if icon != null:
		button.text = ""
	elif used:
		button.text = "%s (исп.)" % spell.get_display_name()
	else:
		button.text = "%s (%d)" % [spell.get_display_name(), cost]

## Обновление состояния UI заклинаний
func _update_spell_ui():
	if not _scene._fantasy_label:
		return
	_scene._fantasy_label.text = "%d / %d" % [_scene.current_fantasy, _scene.max_fantasy]
	for i in range(_scene._spell_buttons.size()):
		if i >= _scene.available_spells.size():
			break
		var spell: SpellResource = _scene.available_spells[i]
		var btn: Button = _scene._spell_buttons[i]
		var cost = int(spell.fantasy_cost * CombatManager.get_spell_cost_multiplier())
		var not_enough: bool = _scene.current_fantasy < cost
		btn.disabled = _scene.spells_used_this_round >= _scene.max_spells_per_round or not_enough
		_set_spell_button_content(btn, spell, cost, _scene.spells_used_this_round >= _scene.max_spells_per_round)
		btn.tooltip_text = "%s\nСтоимость: %d фантазии\nТип цели: %s" % [spell.get_display_description(), cost, DataTables.get_target_type_name(spell.target_type)]

## Обработка клика по кнопке заклинания
func _on_spell_clicked(spell_index: int):
	if _scene._is_battle_paused():
		return
	if spell_index < 0 or spell_index >= _scene.available_spells.size():
		return
	var spell: SpellResource = _scene.available_spells[spell_index]

	# Сброс режима выбора цели для способности (игрок переключился на заклинание)
	_scene.waiting_for_target = false
	_scene.selected_ability = null

	if _scene.spells_used_this_round >= _scene.max_spells_per_round:
		_scene._set_status("Заклинание уже использовано максимальное число раз в этом раунде.")
		return
	var cost = int(spell.fantasy_cost * CombatManager.get_spell_cost_multiplier())
	# ═══ Замок — Рыцарь: все заклинания стоят +2 за каждого живого Рыцаря ═══
	var _knight_extra = 0
	for _ke in _scene.enemies_team:
		if _ke and _ke.current_hp > 0 and _ke.special_effect_type == "knight_spell_cost_increase":
			_knight_extra += 2
			# Стойка «Сила превыше магии»: ещё +2 дополнительно
			for _keff in _ke.active_effects:
				if Combatant._effect_get(_keff, "effect_id", "") == "knight_magic_supremacy_cost":
					_knight_extra += 2
					break
	if _knight_extra > 0:
		cost += _knight_extra
	if _scene.current_fantasy < cost:
		_scene._set_status("Недостаточно очков фантазии для %s (нужно: %d⚛)." % [spell.get_display_name(), cost])
		return

	# Self-заклинание применяется мгновенно
	if spell.target_type == "Self":
		_apply_spell_to_target(_scene.active_unit, spell)
		_deduct_spell(spell)
		_update_spell_ui()
		return

	# All_Enemies / All_Allies — применяем ко всем
	if spell.target_type == "All_Enemies" or spell.target_type == "All_Allies":
		var team = _scene.enemies_team if spell.target_type == "All_Enemies" else _scene.heroes_team
		for unit in team:
			if unit and unit.current_hp > 0:
				_apply_spell_to_target(unit, spell)
		_deduct_spell(spell)
		_update_spell_ui()
		_scene._field._update_all_visuals()
		return

	# Для одиночных целей (включая "Any") — ожидаем выбора
	_scene._waiting_for_spell_target = true
	_scene._selected_spell = spell
	_scene._set_status("Выберите цель для заклинания: %s" % spell.get_display_name())
	_scene._targeting._update_target_highlights()

## Применение эффектов заклинания к одной цели
func _apply_spell_to_target(target: Combatant, spell: SpellResource):
	# ═══ Замок — Инквизитор: иммунитет к заклинаниям ═══
	if target.special_effect_type == "inquisitor_spell_immune":
		_scene._log_combat("🛡️ %s: иммунитет к заклинаниям — «%s» рассеян!" % [target.unit_name, spell.spell_name])
		return
	var voodoo_effect_snapshot: Array = _scene._passives._snapshot_active_effects()
	# Обработка эффектов заклинания
	for effect in spell.effect_types:
		var val: int = spell.effect_values.get(effect, 0)
		var duration: int = spell.effect_durations.get(effect, 1)
		
		if effect == "restart_battle":
			_scene._log_combat("⚡ Перечитать: битва начнётся заново в тех же условиях.")
			_restart_battle_from_spell.call_deferred()
		elif effect == "periodic_damage":
			var _spell_dot_duration = _scene._abilities._compute_effect_duration(_scene.active_unit, target, duration, true)
			var _spell_dot_val = int(round(val * (1.0 + _scene.active_unit.get_periodic_damage_bonus_percent() / 100.0)))
			target.active_effects.append({"stat": "periodic_damage", "value": _spell_dot_val, "duration": _spell_dot_duration, "source_ability": spell.spell_name})
			_scene._log_combat("⚡ %s: %s получает %d периодического урона на %d ход(ов)." % [spell.spell_name, target.unit_name, _spell_dot_val, _spell_dot_duration])
		elif effect == "periodic_damage_percent":
			var _pct_dot_val = int(round(int(target.max_hp * val / 100.0) * (1.0 + _scene.active_unit.get_periodic_damage_bonus_percent() / 100.0)))
			var _pct_dot_duration = _scene._abilities._compute_effect_duration(_scene.active_unit, target, duration, true)
			if _pct_dot_val > 0:
				target.active_effects.append({"stat": "periodic_damage", "value": _pct_dot_val, "duration": _pct_dot_duration, "source_ability": spell.spell_name})
				_scene._log_combat("⚡ %s: %s получает %d периодического урона (%d%% от макс. HP) на %d ход(ов)." % [spell.spell_name, target.unit_name, _pct_dot_val, val, _pct_dot_duration])
		elif effect == "target_heal_percent":
			var _heal_amount = int(target.max_hp * val / 100.0)
			if _heal_amount > 0:
				var _heal_hp_before = target.current_hp
				target.apply_stat_change("hp", _heal_amount)
				_scene._log_combat("⚡ %s: %s восстанавливает %d HP (%d%% от макс). HP: %d → %d" % [spell.spell_name, target.unit_name, _heal_amount, val, _heal_hp_before, target.current_hp])
		elif effect == "pull_forward":
			var old_pos = target.position_index
			_scene._field._apply_shift_effect(target, -val, _scene._is_player_hero(target))
			_scene._log_combat("⚡ %s: %s притягивается вперёд (линия %d → %d)." % [spell.spell_name, target.unit_name, old_pos + 1, target.position_index + 1])
		elif effect == "push_back":
			var old_pos = target.position_index
			_scene._field._apply_shift_effect(target, val, _scene._is_player_hero(target))
			_scene._log_combat("⚡ %s: %s отталкивается назад (линия %d → %d)." % [spell.spell_name, target.unit_name, old_pos + 1, target.position_index + 1])
		elif effect.contains("buff") or effect.contains("debuff"):
			# Общий обработчик баффов/дебаффов для заклинаний
			var stat = _scene.effects._extract_stat_name(effect)
			if effect.contains("debuff"):
				var spell_debuff_duration = _scene._abilities._compute_effect_duration(_scene.active_unit, target, duration, true)
				target.apply_stat_change(stat, -val)
				target.active_effects.append({"stat": stat, "value": -val, "duration": spell_debuff_duration, "source_ability": spell.spell_name})
				# Локация: Сад — при дебаффе на союзника
				if CombatManager.selected_location_id == "garden" and not target.is_enemy and target.current_hp > 0:
					var hp_before_g = target.current_hp
					target.take_damage(15)
					_scene._log_combat("  → [Сад] +15 чистого урона при дебаффе. HP: %d → %d" % [hp_before_g, target.current_hp])
				_scene._log_combat("⚡ %s: %s: -%d к %s на %d ход(ов)." % [spell.spell_name, target.unit_name, val, stat, spell_debuff_duration])
			elif effect.contains("buff"):
				if _scene.effects._block_buff_for_hopeless_stance(target):
					return
				var spell_buff_duration = _scene._abilities._compute_effect_duration(_scene.active_unit, target, duration, false)
				target.apply_stat_change(stat, val)
				target.active_effects.append({"stat": stat, "value": val, "duration": spell_buff_duration, "source_ability": spell.spell_name})
				_scene._log_combat("⚡ %s: %s: +%d к %s на %d ход(ов)." % [spell.spell_name, target.unit_name, val, stat, spell_buff_duration])
				_scene.effects._check_pegasus_ally_buff(target)
	
	# Матрос: пассивка sailor_rum_heal — восстанавливает 10% HP при получении заклинания «Ром»
	if spell.spell_name == "Ром" and target.special_effect_type == "sailor_rum_heal":
		var heal_amount = int(target.max_hp * 0.10)
		if heal_amount > 0:
			var hp_before = target.current_hp
			target.apply_stat_change("hp", heal_amount)
			_scene._log_combat("🍺 [Матрос] %s восстанавливает %d HP от Рома! HP: %d → %d" % [
				target.unit_name, heal_amount, hp_before, target.current_hp])

	# Моргана: пассивка — при использовании заклинания на врага, наложить 10% периодического урона на 2 хода
	if target.is_enemy:
		for hero in _scene.heroes_team:
			if hero and hero.current_hp > 0 and hero.special_effect_type == "morgan_spell_periodic":
				# Жезл тьмы: удваивает урон от пассивки Морганы.
				var _mp_pct = 0.20 if hero.has_item_effect("morgan_double_passive_dot") else 0.10
				var mp_dmg = int(target.max_hp * _mp_pct)
				if mp_dmg > 0:
					var _mp_duration = _scene._abilities._compute_effect_duration(hero, target, 2, true)
					target.active_effects.append({"stat": "periodic_damage", "value": mp_dmg, "duration": _mp_duration, "source_ability": "Пассивка Морганы"})
					_scene._log_combat("🌙 [Моргана] %s получает %d периодического урона на %d хода от пассивки." % [target.unit_name, mp_dmg, _mp_duration])
				break
	
	# Прямой урон
	if spell.flat_damage > 0:
		if not _scene._is_unit_invulnerable(target):
			target.take_damage(spell.flat_damage)
			_scene._log_combat("⚡ %s: %s получает %d урона (%s)." % [spell.spell_name, target.unit_name, spell.flat_damage, spell.damage_type])
			if target.current_hp <= 0:
				_scene._log_combat("☠ %s погибает от заклинания %s!" % [target.unit_name, spell.spell_name])
				_scene._unit_events._on_unit_killed(target)
				_scene._field._compact_team(_scene.heroes_team if not target.is_enemy else _scene.enemies_team)
				if bool(spell.get_meta("refund_on_kill", false)):
					_scene._pending_spell_refund = true
					_scene._log_combat("⚡ %s: враг повержен — можно применить ещё одно заклинание в этот ход!" % spell.spell_name)
				_scene._outcome._check_battle_end()
		else:
			_scene._log_combat("⚡ %s: %s неуязвим — урон поглощён." % [spell.spell_name, target.unit_name])

	var voodoo_log: Array = []
	_scene._passives._propagate_new_voodoo_debuffs(voodoo_effect_snapshot, voodoo_log)
	for line in voodoo_log:
		_scene._log_combat(line)
	_scene._field._update_all_visuals()

## Списание очков фантазии и отметка использования
func _restart_battle_from_spell() -> void:
	_scene.get_tree().reload_current_scene()

func _deduct_spell(spell: SpellResource):
	_scene._info._clear_pinned_unit_info()
	_scene._hud._show_ability_banner(spell.get_display_name())
	var cost = int(spell.fantasy_cost * CombatManager.get_spell_cost_multiplier())
	_scene.current_fantasy = maxi(_scene.current_fantasy - cost, 0)
	_scene.spells_used_this_round += 1
	if _scene._pending_spell_refund:
		_scene._pending_spell_refund = false
		_scene.spells_used_this_round = maxi(0, _scene.spells_used_this_round - 1)
	_scene._log_combat("⚡ Заклинание «%s» использовано (стоимость: %d⚛). Фантазия: %d/%d." % [spell.spell_name, cost, _scene.current_fantasy, _scene.max_fantasy])
	# ═══ Экскалибур: +1 к атаке до конца боя за каждую единицу потраченной фантазии ═══
	if cost > 0:
		for _exc_hero in _scene.heroes_team:
			if _exc_hero and _exc_hero.current_hp > 0 and _exc_hero.has_item_effect("excalibur_fantasy_spent_damage"):
				_exc_hero.apply_stat_change("damage", cost)
				_scene._log_combat("⚔ [Экскалибур] %s: +%d урона (потрачена фантазия)." % [_exc_hero.unit_name, cost])
	# ═══ Маска шута: +1% удачи до конца боя за каждую единицу потраченной фантазии ═══
	if cost > 0:
		for _jm_hero in _scene.heroes_team:
			if _jm_hero and _jm_hero.current_hp > 0 and _jm_hero.has_item_effect("jesters_mask_fantasy_spent_luck"):
				_jm_hero.apply_stat_change("crit", cost)
				_scene._log_combat("🎭 [Маска шута] %s: +%d%% удачи (потрачена фантазия)." % [_jm_hero.unit_name, cost])
	# ═══ Замок — Волшебник: восстановление HP = потраченной фантазии ═══
	if _scene.active_unit and _scene.active_unit.current_hp > 0 and _scene.active_unit.special_effect_type == "wizard_fantasy_heal":
		var _wh_hp_b = _scene.active_unit.current_hp
		_scene.active_unit.apply_stat_change("hp", cost)
		_scene._log_combat("  → [Волшебник] %s восстанавливает %d HP за потраченную фантазию (%d → %d)." % [_scene.active_unit.unit_name, cost, _wh_hp_b, _scene.active_unit.current_hp])
		_scene._field._update_all_visuals()

# ══════════════════════════════════════════════════════════════
#  ЭФФЕКТЫ ЛОКАЦИЙ — вынесены в battle_locations.gd (класс BattleLocations,
#  объект `locations`, инициализируется в _ready()). Хельхейм/Ад/Тоннели/Звёзды/
#  Горы/Пустыня/Глубина/Остров/Топь — там; Облака/Арена/Замок/Корабли/Джунгли/Сад
#  без выделенной функции (комментарии-указатели остались в battle_locations.gd).
# ══════════════════════════════════════════════════════════════
