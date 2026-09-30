extends RefCounted
class_name BattleField

## Поле боя: перемещения и порядок юнитов в команде, визуалы юнитов и их позиции.
##
## Выделено из battle_scene.gd. Состояние боя/экрана и прочие методы — через `_scene.`
## (типизированная ссылка: парсер Godot проверяет каждое обращение).

var _scene: BattleScene

func _init(owner_scene: BattleScene) -> void:
	_scene = owner_scene

func _create_visual(combatant: Combatant, path: String, visuals_array: Array, index: int):
	var vis = BattleScene.COMBATANT_VISUAL.instantiate()
	_scene.get_node(path).add_child(vis)
	vis.setup(combatant)
	vis.unit_clicked.connect(_scene._targeting._on_unit_selected)
	vis.unit_hovered.connect(_scene._info._on_unit_hovered)
	vis.unit_unhovered.connect(_scene._info._on_unit_unhovered)
	visuals_array[index] = vis

func _apply_shift_effect(target: Combatant, distance: int, is_hero: bool):
	var team = _scene.heroes_team if is_hero else _scene.enemies_team
	var members = _get_living_team_members(team)
	var idx = members.find(target)
	if idx < 0:
		return
	# Леший «Ни шагу» / иммобилизация: цель с эффектом «rooted» не может двигаться
	for _rs_eff in target.active_effects:
		if Combatant._effect_get(_rs_eff, "stat", "") == "rooted":
			_scene._log_combat("🌿 %s опутан корнями и не может двигаться." % target.unit_name)
			return
	
	# Кракен и его щупальца: невозможно сдвинуть.
	if target.is_immovable():
		_scene._log_combat("🐙 %s невозможно сдвинуть." % target.unit_name)
		return

	var new_idx = clampi(idx + distance, 0, members.size() - 1)
	if new_idx == idx:
		return
	
	var unit = members[idx]
	members.remove_at(idx)
	members.insert(new_idx, unit)
	_apply_member_order_to_team(team, members)
	target.check_stance_interruption("move", target.position_index)
	# Посейдон: «Штиль» — при движении противника 70% урона
	for enemy in _scene.heroes_team + _scene.enemies_team:
		if enemy != null and enemy.current_hp > 0 and enemy != target:
			if enemy.active_stance != null and enemy.active_stance.stance_effect_type == "poseidon_calm":
				var _is_enemy_of_mover = (enemy.is_enemy != target.is_enemy)
				if _is_enemy_of_mover:
					var calm_dmg = CombatCalculator.calculate_fixed_damage(enemy, target, 0.7)
					if calm_dmg.is_hit and calm_dmg.final_damage > 0:
						_scene._unit_events._deal_damage(target, calm_dmg.final_damage, calm_dmg.is_crit)
						_scene._log_combat("  → [Штиль] %s наносит %d урона за движение %s." % [enemy.unit_name, calm_dmg.final_damage, target.unit_name])
						if target.current_hp <= 0:
							_scene._log_combat("  → %s повержен Штилем!" % target.unit_name)
							_scene._unit_events._on_unit_killed(target)
							_compact_team(_scene.heroes_team if not target.is_enemy else _scene.enemies_team)
							_scene._outcome._check_battle_end()
						break
	_scene.marks.check_on_move(target)
	# Нага воин: пассивка — при перемещении +7 удачи на 2 хода
	if target.special_effect_type == "naga_move_luck":
		target.apply_stat_change("crit", 7)
		target.active_effects.append({"stat": "crit", "value": 7, "duration": 2, "effect_id": "naga_move_luck", "source_ability": "Пассивка Нага"})
		_scene._log_combat("🐍 [Нага] %s получает +7 удачи за перемещение (2 хода)." % target.unit_name)
	# Асура: сброс «Чёрной полосы» meta, если марка истекла (проверка активных марок streak)
	var _asura_has_streak = false
	for _as_m in _scene.marks.position_marks:
		if _as_m.get("effect_type", "") == "asura_streak_debuff":
			_asura_has_streak = true
			break
	if not _asura_has_streak and target.has_meta("asura_streak_active"):
		target.remove_meta("asura_streak_active")
	_scene._passives._apply_kappa_auras()
	_sync_visual_positions()
	
	# ═══ Хуки перемещения для юнитов Глубины ═══
	_on_unit_moved(target)
	
	# ═══ Звёзды — Овен: при перемещении получает бафф каждой пройденной клетки (1 ход) ═══
	if target.special_effect_type == "aries_path_buffs" and CombatManager.selected_location_id == "stars":
		for _ar_pos in range(mini(idx, new_idx), maxi(idx, new_idx) + 1):
			_scene.locations._apply_star_cell_buff(target, _ar_pos, 1)
		_scene._log_combat("🐏 [Овен] %s получает звёздные баффы пройденных клеток." % target.unit_name)

	# ═══ Локация: Глубина — урон/лечение при смене позиции ═══
	_scene.locations._location_depths_on_move(target)

func _get_living_team_members(team: Array) -> Array:
	var members: Array = []
	for u in team:
		if u and u.current_hp > 0 and not members.has(u):
			members.append(u)
	members.sort_custom(func(a, b): return a.position_index < b.position_index)
	return members

func _apply_member_order_to_team(team: Array, members: Array) -> void:
	for i in range(4):
		team[i] = null
	var pos = 0
	for i in range(members.size()):
		if pos >= 4:
			push_warning("_apply_member_order_to_team: некорректное построение — не помещается в 4 позиции, юнит отброшен.")
			break
		var m = members[i]
		m.position_index = pos
		team[pos] = m
		pos += 1
		if m.is_large and pos < 4:
			team[pos] = m  # Большой юнит занимает соседнюю позицию
			pos += 1

func _compact_team(team: Array):
	_apply_member_order_to_team(team, _get_living_team_members(team))

## Хуки перемещения для юнитов Глубины (вызывается при любом перемещении юнита).
func _on_unit_moved(target: Combatant):
	if target == null or target.current_hp <= 0:
		return
	target.moved_this_round = true
	# Русал воин: +10 удачи (крит) на 1 ход при собственном перемещении
	if target.special_effect_type == "merwarrior_move_luck":
		target.apply_stat_change("crit", 10)
		target.active_effects.append({"stat": "crit", "value": 10, "duration": 1, "effect_id": "merwarrior_move_luck", "source_ability": "Пассивка Русала"})
	# Тритон: когда враг двигается — -10 брони на 1 ход
	var _tr_team = _scene.enemies_team if not target.is_enemy else _scene.heroes_team
	for _triton in _tr_team:
		if _triton and _triton.current_hp > 0 and _triton.special_effect_type == "triton_enemy_move_armor":
			target.apply_stat_change("armor", -10)
			target.active_effects.append({"stat": "armor", "value": -10, "duration": 1, "effect_id": "triton_enemy_move_armor", "source_ability": "Пассивка Тритона"})
			break
	# Рассекающий волны: когда враг двигается — наносит ему 15% урона носителя
	for _wc_u in _tr_team:
		if _wc_u and _wc_u.current_hp > 0 and _wc_u.has_item_effect("wave_cleaver_move_punish"):
			var _wc_dmg = int(_wc_u.damage * 0.15)
			if _wc_dmg > 0 and target.current_hp > 0:
				var _wc_hp_before = target.current_hp
				target.take_damage(_wc_dmg)
				_scene._log_combat("🌊 [Рассекающий волны] %s получает %d урона за перемещение. HP: %d → %d" % [target.unit_name, _wc_dmg, _wc_hp_before, target.current_hp])
				if target.current_hp <= 0:
					_scene._log_combat("  → %s повержен!" % target.unit_name)
					target.killed_by = _wc_u
					_scene._unit_events._on_unit_killed(target)
					var _wc_team = _scene.heroes_team if target.is_enemy == false else _scene.enemies_team
					_compact_team(_wc_team)
					_scene._passives._apply_kappa_auras()
			break

## Морская ведьма: «Водоворот» — разворот позиций противников (1↔4, 2↔3), считается 4 перемещениями для локации.
func _swap_enemy_positions(caster: Combatant) -> Array[String]:
	var lines: Array[String] = []
	var team = _scene.heroes_team if caster.is_enemy else _scene.enemies_team
	var members = _get_living_team_members(team)
	if members.size() < 2:
		return lines
	var reversed_members: Array = []
	for i in range(members.size() - 1, -1, -1):
		reversed_members.append(members[i])
	_apply_member_order_to_team(team, reversed_members)
	lines.append("  → [Водоворот] Позиции противников перевёрнуты!")
	for u in reversed_members:
		if u and u.current_hp > 0:
			u.check_stance_interruption("move", u.position_index)
			_scene.marks.check_on_move(u)
	_scene._passives._apply_kappa_auras()
	_sync_visual_positions()
	for u in reversed_members:
		if u and u.current_hp > 0:
			_on_unit_moved(u)
			_scene.locations._location_depths_on_move(u)
	_update_all_visuals()
	return lines
	_sync_visual_positions()

func _update_all_visuals():
	_scene._passives._refresh_passive_auras_for_all_units()
	# Синхронизируем позиции визуалов с актуальным состоянием команд,
	# чтобы после компоновки (смерть/перемещение) визуалы перемещались вместе с логикой.
	_sync_visual_positions()
	for v in _scene.hero_visuals + _scene.enemy_visuals:
		if v:
			v.update_visuals()
	_sync_status_bar_positions()
	_scene._hud._update_marks_display()
	# Доступность способностей зависит от текущей позиции/величия — обновляем
	# кнопки активного бога при любом изменении (движение заклинанием и т.п.).
	if _scene.waiting_for_player and _scene.active_unit != null:
		_scene._hud._refresh_ability_buttons_availability(_scene.active_unit)

## Подсветка HP-бара юнита, чей сейчас ход (снимает подсветку с остальных).
func _sync_status_bar_positions() -> void:
	var bar_top: float = _scene._hud._get_bottom_status_top()
	for v in _scene.hero_visuals + _scene.enemy_visuals:
		if v and v.has_method("set_status_bars_global_top"):
			v.set_status_bars_global_top(bar_top)

func _update_active_highlight():
	for v in _scene.hero_visuals + _scene.enemy_visuals:
		if v:
			v.set_active(v.data != null and v.data == _scene.active_unit)
	# Обновляем полосу очереди ходов (текущий ходящий подсвечивается).
	_scene._hud._update_turn_order_display()

func _sync_visual_positions():
	# Крупный юнит (is_large) присутствует и в team[i], и в team[i+1].
	# Чтобы не сдвигать его визуал дважды (он бы уехал на соседний слот),
	# каждый юнит помещаем один раз — на свой первичный слот.
	var placed_heroes: Dictionary = {}
	var placed_enemies: Dictionary = {}
	for i in range(4):
		if _scene.heroes_team[i]:
			var u = _scene.heroes_team[i]
			if not placed_heroes.has(u):
				placed_heroes[u] = true
				var vis = _find_visual_for_unit(u, _scene.hero_visuals)
				_move_visual_to_slot(vis, "HeroPositions/Pos" + str(i + 1))
				# Герои идут справа налево: центр между этим и следующим слотом = -70px.
				if u.is_large:
					vis.position = Vector2(-70, 0)
		if _scene.enemies_team[i]:
			var u = _scene.enemies_team[i]
			if not placed_enemies.has(u):
				placed_enemies[u] = true
				var vis = _find_visual_for_unit(u, _scene.enemy_visuals)
				_move_visual_to_slot(vis, "EnemyPositions/Pos" + str(i + 1))
				# Враги идут слева направо: центр между этим и следующим слотом = +70px.
				if u.is_large:
					vis.position = Vector2(70, 0)

func _find_visual_for_unit(unit: Combatant, visuals: Array) -> Node2D:
	for v in visuals:
		if v and v.data == unit:
			return v
	return null

## Удаляет визуал (спрайт, полоски) мёртвого юнита со сцены,
## чтобы его арт не оставался на поле и не перекрывал живых юнитов.
func _remove_visual_for_unit(unit: Combatant):
	if unit == null:
		return
	var visuals = _scene.enemy_visuals if unit.is_enemy else _scene.hero_visuals
	for i in range(visuals.size()):
		var v = visuals[i]
		if v and v.data == unit:
			# Слот освобождаем сразу (игровая логика видит место свободным немедленно),
			# а сам узел лишь плавно растворяется и убирается из сцены чуть позже —
			# чисто визуальный эффект, ни на что механическое не влияет.
			visuals[i] = null
			_fade_out_and_free_visual(v)
			return

## Растворяет спрайт погибшего юнита до полной прозрачности за 1 секунду, затем
## удаляет узел. Вызывается вместо мгновенного queue_free() в _remove_visual_for_unit.
func _fade_out_and_free_visual(visual: Node2D) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	var tween := _scene.create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 1.0)
	tween.tween_callback(visual.queue_free)

## Создаёт визуал юниту, если у него его нет (нужно при воскрешении Жрецом Анубиса).
func _ensure_visual_for_unit(unit: Combatant):
	if unit == null:
		return
	if _find_visual_for_unit(unit, _scene.hero_visuals) != null or _find_visual_for_unit(unit, _scene.enemy_visuals) != null:
		return
	var visuals = _scene.enemy_visuals if unit.is_enemy else _scene.hero_visuals
	var prefix = "EnemyPositions/Pos" if unit.is_enemy else "HeroPositions/Pos"
	for i in range(visuals.size()):
		if visuals[i] == null:
			var path = prefix + str(i + 1)
			if _scene.has_node(path):
				_create_visual(unit, path, visuals, i)
			return

func _move_visual_to_slot(visual: Node2D, path: String):
	if visual == null or not _scene.has_node(path):
		return
	var slot = _scene.get_node(path)
	if visual.get_parent() != slot:
		if visual.get_parent():
			visual.get_parent().remove_child(visual)
		slot.add_child(visual)
	visual.position = Vector2.ZERO

func _show_miss_popup(unit: Combatant) -> void:
	if unit == null:
		return
	var vis = _find_visual_for_unit(unit, _scene.hero_visuals)
	if vis == null:
		vis = _find_visual_for_unit(unit, _scene.enemy_visuals)
	if vis != null and vis.has_method("show_floating_number"):
		vis.show_floating_number(0, "miss")
