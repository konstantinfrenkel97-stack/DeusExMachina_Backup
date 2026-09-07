## ════════════════════════════════════════════════════════════════
##  BattleLocations — эффекты локаций (Хельхейм, Ад, Тоннели, Звёзды, Горы,
##  Пустыня, Глубина, Остров, Топь).
##  Выделено из battle_scene.gd (рефакторинг архитектуры, тот же приём,
##  что и battle_marks.gd). Вся логика перенесена 1:1; поведение боя не изменено.
##
##  battle_scene делегирует эффекты локаций этому объекту и обращается к его
##  методам через `locations.`. Состояние читается/пишется через _scene —
##  специфичные для локаций переменные (_is_fog_round, _swamp_*,
##  _ra_sun_glory_active) намеренно остаются на самой сцене, а не здесь:
##  они используются и вне этого модуля (например, при обработке смерти
##  юнита в _on_unit_killed() сцена сама очищает _swamp_tracked_unit/_swamp_grace_unit).
## ════════════════════════════════════════════════════════════════
extends RefCounted
class_name BattleLocations

# Ссылка на сцену боя для доступа к командам и вспомогательным методам
# (_log_combat, _check_battle_end, _compact_team, _on_unit_killed,
#  _apply_buff_to_unit, _compute_effect_duration, _has_special_on_team и т.д.).
var _scene  # намеренно без типа — динамическая диспетчеризация как в battle_marks.gd


func _init(scene) -> void:
	_scene = scene


# ─── 1) ХЕЛЬХЕЙМ ─────────────────────────────────────────────
# 30% шанс туманного раунда. Сменяется фон, герои получают -20 урона на 1 раунд.
func _location_helheim():
	if CombatManager.selected_location_id != "helheim":
		if _scene._is_fog_round:
			_scene._is_fog_round = false
			_scene._swap_background("")
		return

	# Восстанавливаем фон после предыдущего туманного раунда
	if _scene._is_fog_round:
		_scene._is_fog_round = false
		_scene._swap_background("")

	# Йотун: удваивает шанс тумана, пока жив хотя бы 1 йотун
	if CombatManager.pending_helheim_skip_fog_rounds > 0:
		CombatManager.pending_helheim_skip_fog_rounds -= 1
		_scene._log_combat("[" + "Хельхейм" + "] " + "Туман не появляется в этот раунд.")
		return

	var fog_chance := 0.30
	for unit in _scene.enemies_team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == "jotun_fog":
			fog_chance = 0.60
			break

	# Бросок тумана
	var fog_roll = randf()
	if fog_roll < fog_chance:
		_scene._is_fog_round = true
		# Сменить фон на туманный
		if CombatManager.selected_fog_background != "":
			_scene._swap_background(CombatManager.selected_fog_background)
		var fog_chance_text = " (шанс %d%% — живёт Йотун!)" % int(fog_chance * 100) if fog_chance > 0.30 else ""
		_scene._log_combat("🌫 [Хельхейм] ТУМАННЫЙ РАУНД!%s Герои получают -20 к урону на этот ход." % fog_chance_text)
		_scene._set_status("🌫 ТУМАННЫЙ РАУНД! Все герои получают -20 к урону.")
		# Дебафф -20 урона на всех живых героев (не врагов)
		for hero in _scene.heroes_team:
			if hero and hero.current_hp > 0:
				hero.apply_stat_change("damage", -20)
				hero.active_effects.append({
					"stat": "damage", "value": -20, "duration": 1,
					"effect_id": "helheim_fog", "dispellable": false,
					"source_ability": "Хельхейм"
				})
		# Индиго: +25 уклонения в туманный раунд
		for enemy in _scene.enemies_team:
			if enemy and enemy.current_hp > 0 and enemy.special_effect_type == "indigo_fog_evasion":
				enemy.apply_stat_change("evasion", 25)
				enemy.active_effects.append({
					"stat": "evasion", "value": 25, "duration": 1,
					"effect_id": "indigo_fog", "source_ability": "Хельхейм"
				})
				_scene._log_combat("  → [Индиго] %s: +25 уклонения в тумане (итого %d)." % [enemy.unit_name, enemy.evasion])


# ─── 2) ТАРТАР ───────────────────────────────────────────────
# Боги теряют 5 величия, игрок теряет 5 маны каждый раунд.
func _location_hell():
	if CombatManager.selected_location_id != "hell":
		return
	for hero in _scene.heroes_team:
		if hero and hero.current_hp > 0:
			hero.modify_majesty(-5)
	_scene.current_fantasy = maxi(_scene.current_fantasy - 5, 0)
	_scene._log_combat("🔥 [Ад] Все боги теряют 5 величия. Игрок теряет 5 маны. Фантазия: %d/%d" % [_scene.current_fantasy, _scene.max_fantasy])


# ─── 3) ТОННЕЛИ ──────────────────────────────────────────────
# Если текущая броня выше 50%, регенерация 7% на 1 ход.
func _location_tunnels():
	if CombatManager.selected_location_id != "tunnels":
		return
	for unit in _scene.heroes_team + _scene.enemies_team:
		if unit and unit.current_hp > 0:
			if unit.armor > 50:
				unit.active_effects.append({
					"stat": "regeneration", "value": 7, "duration": 1,
					"source_ability": "Тоннели"
				})
				_scene._log_combat("🪨 [Тоннели] %s получает регенерацию 7%% (броня %d > 50)." % [unit.unit_name, unit.armor])


# ─── 4) ОБЛАКА ───────────────────────────────────────────────
# Эффект встроен в _use_ability() — после попадания по врагу (не богу) даётся +10 уклонения.

# ─── 5) ЗВЁЗДЫ ───────────────────────────────────────────────
# Враги получают бонусы по позициям: 0=+10 брони, 1=реген 10%, 2=+10% удачи, 3=+10 урона.
func _location_stars():
	if CombatManager.selected_location_id != "stars":
		return
	# Удаляем старые баффы Звёзд
	for unit in _scene.enemies_team:
		if unit == null: continue
		var i = 0
		while i < unit.active_effects.size():
			var eid = Combatant._effect_get(unit.active_effects[i], "effect_id", "")
			if eid == "stars_bonus":
				var stat = Combatant._effect_get(unit.active_effects[i], "stat", "")
				var val = Combatant._effect_get(unit.active_effects[i], "value", 0)
				if stat != "regeneration":
					unit.apply_stat_change(stat, -val)
				unit.active_effects.remove_at(i)
			else:
				i += 1
	# Накладываем новые баффы по позициям
	for i in range(_scene.enemies_team.size()):
		var unit = _scene.enemies_team[i]
		if unit == null or unit.current_hp <= 0:
			continue
		match i:
			0: # +10 брони
				_scene.effects._apply_buff_to_unit(unit, "armor", 10, -1, "stars_bonus", "Звёзды")
			1: # регенерация 10%
				unit.active_effects.append({"stat": "regeneration", "value": 10, "duration": -1, "effect_id": "stars_bonus", "source_ability": "Звёзды"})
			2: # +10% крит (удача)
				_scene.effects._apply_buff_to_unit(unit, "crit", 10, -1, "stars_bonus", "Звёзды")
			3: # +10 урона
				_scene.effects._apply_buff_to_unit(unit, "damage", 10, -1, "stars_bonus", "Звёзды")
	# ═══ Звёзды — Весы: союзники на соседних клетках получают звёздный бафф Весов ═══
	for li in range(_scene.enemies_team.size()):
		var _lib_u = _scene.enemies_team[li]
		if _lib_u == null or _lib_u.current_hp <= 0 or _lib_u.special_effect_type != "libra_adjacent_buff":
			continue
		for _adj in [li - 1, li + 1]:
			if _adj >= 0 and _adj < _scene.enemies_team.size():
				var _adj_u = _scene.enemies_team[_adj]
				if _adj_u != null and _adj_u.current_hp > 0 and _adj_u != _lib_u:
					_apply_star_cell_buff(_adj_u, li, -1)
					_scene._log_combat("⚖️ [Весы] %s делится звёздным баффом клетки %d с %s." % [_lib_u.unit_name, li + 1, _adj_u.unit_name])


# Применяет звёздный бонус клетки (0=броня,1=реген,2=крит,3=урон) юниту как бафф на duration ходов.
func _apply_star_cell_buff(unit: Combatant, pos_index: int, duration: int):
	if unit == null or unit.current_hp <= 0:
		return
	var _sc_duration = _scene._compute_effect_duration(unit, unit, duration, false)
	match pos_index:
		0:
			_scene.effects._apply_buff_to_unit(unit, "armor", 10, _sc_duration, "stars_bonus", "Звёзды")
		1:
			unit.active_effects.append({"stat": "regeneration", "value": 10, "duration": _sc_duration, "effect_id": "stars_bonus", "source_ability": "Звёзды"})
		2:
			_scene.effects._apply_buff_to_unit(unit, "crit", 10, _sc_duration, "stars_bonus", "Звёзды")
		3:
			_scene.effects._apply_buff_to_unit(unit, "damage", 10, _sc_duration, "stars_bonus", "Звёзды")


# ─── 6) ГОРЫ ─────────────────────────────────────────────────
# Только флейвор текст — выводится при старте боя (в _ready).
func _location_mountains_label():
	if CombatManager.selected_location_id != "mountains":
		return
	_scene._log_combat("⛰ [Горы] Разрежённый воздух и грохот далёких обвалов — здесь правит сила, а не хитрость.")

# ─── 7) АРЕНА ────────────────────────────────────────────────
# +20% урона всем — обрабатывается через CombatManager.get_damage_multiplier().

# ─── 8) ЗАМОК ────────────────────────────────────────────────
# Заклинания x1.5 дороже, 2 за ход — обрабатывается через spell cost multiplier и max_spells_per_round.

# ─── 9) ПУСТЫНЯ ──────────────────────────────────────────────
# В начале раунда все (герои и враги) получают 5 чистого урона.
# Жрец Ра защищает всех союзников-врагов от урона локации.
func _location_desert():
	if CombatManager.selected_location_id != "desert":
		return
	# Жрец Ра: пока он жив, его союзники не получают урон от локации
	var ra_protects_enemies = _scene.effects._has_special_on_team(_scene.enemies_team, "ra_no_location_damage")
	# «Слава солнцу»: пока жив Жрец Ра со стойкой — урон Пустыни по героям удвоен
	var sun_glory = _scene._ra_sun_glory_active and ra_protects_enemies
	var hero_dmg = 10 if sun_glory else 5
	if sun_glory:
		_scene._log_combat("☀ [Пустыня] Слава солнцу: герои получают удвоенный зной (%d)." % hero_dmg)
	for hero in _scene.heroes_team:
		if hero and hero.current_hp > 0:
			var hp_before = hero.current_hp
			var actual_hero_dmg = int(min(hero_dmg, hero.current_hp - 1))
			if actual_hero_dmg > 0:
				hero.current_hp = maxi(hero.current_hp - actual_hero_dmg, 1)
				hero.damage_taken.emit(actual_hero_dmg)
			_scene._log_combat("☀ [Пустыня] %s получает %d чистого урона. HP: %d → %d" % [hero.unit_name, actual_hero_dmg, hp_before, hero.current_hp])
	if not ra_protects_enemies:
		for enemy in _scene.enemies_team:
			if enemy and enemy.current_hp > 0:
				var hp_before = enemy.current_hp
				var actual_enemy_dmg = int(min(5, enemy.current_hp - 1))
				if actual_enemy_dmg > 0:
					enemy.current_hp = maxi(enemy.current_hp - actual_enemy_dmg, 1)
					enemy.damage_taken.emit(actual_enemy_dmg)
				_scene._log_combat("☀ [Пустыня] %s получает %d чистого урона. HP: %d → %d" % [enemy.unit_name, actual_enemy_dmg, hp_before, enemy.current_hp])
	else:
		_scene._log_combat("☀ [Пустыня] Жрец Ра защищает всех союзников от зноя Пустыни.")


# ─── 10) ГЛУБИНА — надпись в начале раунда ────────────────────
func _location_depths_label():
	if CombatManager.selected_location_id != "depths":
		return
	if _scene.current_round % 2 == 1:
		_scene._log_combat("🌊 [Глубина] Бурные потоки — смена позиции: 20 чистого урона.")
	else:
		_scene._log_combat("🌊 [Глубина] Спокойные воды — смена позиции: восстановление 10%% HP.")

# ─── 10) ГЛУБИНА — эффект при перемещении ────────────────────
func _location_depths_on_move(target: Combatant):
	if CombatManager.selected_location_id != "depths":
		return
	if _scene.current_round % 2 == 1:
		# Нечётный: Бурные потоки — 20 чистого урона
		var _dep_eff = _apply_depths_effect_on_unit(target, 20, 0)
		for line in _dep_eff:
			_scene._log_combat(line)
		if target.current_hp <= 0 and _scene._check_battle_end():
			return
	else:
		# Чётный: Спокойные воды — восстановление 10% HP
		var _dep_heal = int(target.max_hp * 0.10)
		var _dep_eff2 = _apply_depths_effect_on_unit(target, 0, _dep_heal)
		for line in _dep_eff2:
			_scene._log_combat(line)
	_scene._update_all_visuals()

## Применяет эффект Глубины к юниту с учётом пассивок (Русалка-волшебница инвертирует урон в лечение,
## Морская ведьма удваивает эффект). raw_dmg — чистый урон, heal — лечение.
func _apply_depths_effect_on_unit(target: Combatant, raw_dmg: int, heal: int) -> Array[String]:
	var lines: Array[String] = []
	if target == null or target.current_hp <= 0:
		return lines
	var is_raging = (_scene.current_round % 2 == 1)
	var doubled = target.special_effect_type == "seawitch_double_depth"
	# Русалка-волшебница: вместо урона от Бурных потоков союзники лечатся на столько же
	if is_raging and target.special_effect_type == "mermaid_depth_heal":
		var inv_heal = raw_dmg * (2 if doubled else 1)
		var hp_b = target.current_hp
		target.apply_stat_change("hp", inv_heal)
		lines.append("🌊 [Глубина] Спокойные воды (инверсия): %s восстанавливает %d HP. HP: %d → %d" % [target.unit_name, inv_heal, hp_b, target.current_hp])
		return lines
	if is_raging:
		var dmg = raw_dmg * (2 if doubled else 1)
		var hp_b = target.current_hp
		target.take_damage(dmg)
		lines.append("🌊 [Глубина] Бурные потоки: %s получает %d чистого урона при смене позиции%s. HP: %d → %d" % [target.unit_name, dmg, " (x2)" if doubled else "", hp_b, target.current_hp])
		if target.current_hp <= 0:
			lines.append("  → %s повержен водами Глубины!" % target.unit_name)
			_scene._on_unit_killed(target)
			var team = _scene.heroes_team if not target.is_enemy else _scene.enemies_team
			_scene._compact_team(team)
	else:
		var h = heal * (2 if doubled else 1)
		var hp_b = target.current_hp
		target.apply_stat_change("hp", h)
		lines.append("🌊 [Глубина] Спокойные воды: %s восстанавливает %d HP при смене позиции%s. HP: %d → %d" % [target.unit_name, h, " (x2)" if doubled else "", hp_b, target.current_hp])
	return lines


# ─── 11) ОСТРОВ ──────────────────────────────────────────────
# Каждый ход герои получают -1 инициативу (до 0).
func _location_island():
	if CombatManager.selected_location_id != "island":
		return
	for hero in _scene.heroes_team:
		if hero and hero.current_hp > 0 and hero.initiative > 0:
			hero.initiative = maxi(hero.initiative - 1, 0)
			_scene._log_combat("🏝 [Остров] %s: инициатива снижена до %d." % [hero.unit_name, hero.initiative])

# ─── 12) КОРАБЛИ ─────────────────────────────────────────────
# Уникальное заклинание «Ром» — добавляется в _load_spells().

# ─── 13) ДЖУНГЛИ ─────────────────────────────────────────────
# Крит x3 вместо x2 — обрабатывается через CombatManager.get_crit_multiplier().

# ─── 14) САД ─────────────────────────────────────────────────
# При наложении дебаффа на союзника: +15 чистого урона.
# Эффект встроен в _apply_effect_to_target() и _apply_spell_to_target().

# ─── 15) ТОПЬ ────────────────────────────────────────────────
# Бог на первой позиции получает -1 инициативу и -5 брони (суммируется, пока стоит).
# Утопленница «Вниз»: помечает жертву — покинув позицию 1, она держит дебафф ещё N ходов,
# а вернувшись до истечения этого срока, продолжает копить стек, а не начинает заново.
func _location_swamp():
	if CombatManager.selected_location_id != "swamp":
		# Очистка при смене локации
		if _scene._swamp_tracked_unit != null:
			_remove_swamp_debuff(_scene._swamp_tracked_unit)
			_scene._swamp_tracked_unit = null
		if _scene._swamp_grace_unit != null:
			_remove_swamp_debuff(_scene._swamp_grace_unit)
			_scene._swamp_grace_unit = null
			_scene._swamp_grace_turns_left = 0
		return

	# Кто стоит на первой позиции?
	var first_hero = _scene.heroes_team[0] if _scene.heroes_team.size() > 0 and _scene.heroes_team[0] != null and _scene.heroes_team[0].current_hp > 0 else null

	# Тикаем грацию для юнита, который уже покинул позицию 1, но помечен Утопленницей
	if _scene._swamp_grace_unit != null and _scene._swamp_grace_unit != first_hero:
		if _scene._swamp_grace_unit.current_hp <= 0:
			_scene._swamp_grace_unit = null
			_scene._swamp_grace_turns_left = 0
		else:
			_scene._swamp_grace_turns_left -= 1
			if _scene._swamp_grace_turns_left <= 0:
				_scene._log_combat("🌿 [Топь] %s: время действия эффекта Топи истекло — дебафф снят." % _scene._swamp_grace_unit.unit_name)
				_remove_swamp_debuff(_scene._swamp_grace_unit)
				_scene._swamp_grace_unit = null

	if first_hero != _scene._swamp_tracked_unit:
		var _departing = _scene._swamp_tracked_unit
		if _departing != null and _departing != first_hero and _departing != _scene._swamp_grace_unit:
			var _extend_val = _get_effect_value(_departing, "utoplennitsa_swamp_extend")
			if _extend_val > 0 and _scene._swamp_grace_unit == null:
				_scene.effects._remove_effect_id(_departing, "utoplennitsa_swamp_extend")
				_scene._swamp_grace_unit = _departing
				_scene._swamp_grace_turns_left = _extend_val
				_scene._log_combat("🌿 [Топь/Утопленница] %s покидает первую позицию — дебафф Топи держится ещё %d ход(ов)." % [_departing.unit_name, _extend_val])
			else:
				_remove_swamp_debuff(_departing)
		if first_hero != null and first_hero == _scene._swamp_grace_unit:
			# Вернулся, пока действовала грация — стек не теряется, грация снимается.
			_scene._swamp_grace_unit = null
			_scene._swamp_grace_turns_left = 0
			_scene._log_combat("🌿 [Топь] %s вернулся на первую позицию до истечения — накопленный стек сохранён." % first_hero.unit_name)
		_scene._swamp_tracked_unit = first_hero
		_scene._swamp_consecutive_rounds = 0

	if first_hero == null:
		return

	# Утопленница: за каждую живую Утопленницу в команде эффект локации усиливается на 5%
	var _ut_count = 0
	for _ut_u in _scene.enemies_team:
		if _ut_u and _ut_u.current_hp > 0 and _ut_u.special_effect_type == "utoplennitsa_location_amplify":
			_ut_count += 1
	var _swamp_mult = 1.0 + 0.05 * _ut_count
	var _armor_step = int(round(5 * _swamp_mult))
	var _evasion_step = int(round(5 * _swamp_mult))

	_scene._swamp_consecutive_rounds += 1

	first_hero.initiative = maxi(first_hero.initiative - 1, 0)
	first_hero.apply_stat_change("armor", -_armor_step)
	first_hero.apply_stat_change("evasion", -_evasion_step)

	# Копим дебафф прямо на эффекте юнита (не в глобальных переменных — так стек переживает
	# уход/возврат на позицию 1 независимо от того, кто ещё сменяется на этой позиции).
	var _sd_effect = null
	for e in first_hero.active_effects:
		if Combatant._effect_get(e, "effect_id", "") == "swamp_debuff":
			_sd_effect = e
			break
	if _sd_effect == null:
		_sd_effect = {"stat": "location_debuff", "value": 0, "duration": -1, "effect_id": "swamp_debuff",
			"stacks": 0, "init_loss": 0, "armor_loss": 0, "evasion_loss": 0, "source_ability": "Топь"}
		first_hero.active_effects.append(_sd_effect)
	_sd_effect["stacks"] = int(_sd_effect.get("stacks", 0)) + 1
	_sd_effect["init_loss"] = int(_sd_effect.get("init_loss", 0)) + 1
	_sd_effect["armor_loss"] = int(_sd_effect.get("armor_loss", 0)) + _armor_step
	_sd_effect["evasion_loss"] = int(_sd_effect.get("evasion_loss", 0)) + _evasion_step

	_scene._log_combat("🌿 [Топь] %s на первой позиции: стек x%d (итого -%d инициатива, -%d брони, -%d уклонения)." % [
		first_hero.unit_name, _sd_effect["stacks"], _sd_effect["init_loss"], _sd_effect["armor_loss"], _sd_effect["evasion_loss"]
	])

	# Водяной: если противник получает эффект локации 3 хода подряд — стан
	if _scene._swamp_consecutive_rounds >= 3:
		if _scene.effects._has_special_on_team(_scene.enemies_team, "vodyanoy_location_stun"):
			var _vd_caster: Combatant = null
			for _vd_u in _scene.enemies_team:
				if _vd_u and _vd_u.current_hp > 0 and _vd_u.special_effect_type == "vodyanoy_location_stun":
					_vd_caster = _vd_u
					break
			first_hero.is_stunned = true
			var _vd_stun_duration = _scene._compute_effect_duration(_vd_caster, first_hero, 1, true)
			first_hero.active_effects.append({"stat": "stun", "value": 1, "duration": _vd_stun_duration, "source_ability": "Болотное царство (Водяной)"})
			first_hero.check_stance_interruption("stun")
			_scene._notify_stun_applied(first_hero)
			_scene._log_combat("🌿 [Водяной] %s: 3 хода подряд под эффектом Топи — оглушён!" % first_hero.unit_name)
		_scene._swamp_consecutive_rounds = 0

## Возвращает value эффекта с данным effect_id на юните (0, если такого эффекта нет).
func _get_effect_value(unit: Combatant, effect_id: String) -> int:
	if unit == null:
		return 0
	for e in unit.active_effects:
		if Combatant._effect_get(e, "effect_id", "") == effect_id:
			return int(Combatant._effect_get(e, "value", 0))
	return 0

## Снимает накопленный дебафф Топи с юнита (по данным, хранящимся прямо на эффекте).
func _remove_swamp_debuff(unit: Combatant) -> void:
	if unit == null or unit.current_hp <= 0:
		return
	for i in range(unit.active_effects.size() - 1, -1, -1):
		var e = unit.active_effects[i]
		if Combatant._effect_get(e, "effect_id", "") == "swamp_debuff":
			var _init_loss = int(e.get("init_loss", 0))
			var _armor_loss = int(e.get("armor_loss", 0))
			var _evasion_loss = int(e.get("evasion_loss", 0))
			unit.initiative += _init_loss
			unit.apply_stat_change("armor", _armor_loss)
			unit.apply_stat_change("evasion", _evasion_loss)
			unit.active_effects.remove_at(i)
			_scene._log_combat("🌿 [Топь] %s покинул первую позицию — дебаффы сняты (+%d инициатива, +%d брони, +%d уклонения)." % [
				unit.unit_name, _init_loss, _armor_loss, _evasion_loss
			])
			return
