## ════════════════════════════════════════════════════════════════
##  BattleMarks — подсистема позиционных марок.
##  Выделена из battle_scene.gd (рефакторинг архитектуры).
##  Вся логика перенесена 1:1; поведение боя не изменено.
##
##  battle_scene делегирует размещение/срабатывание/тиканье марок этому
##  объекту и обращается к состоянию через marks.position_marks.
## ════════════════════════════════════════════════════════════════
extends RefCounted
class_name BattleMarks


# Позиционные марки: Array[Dictionary]
# { "caster": Combatant, "team": "enemy"/"ally", "position": int,
#   "type": "once"/"persistent", "rounds_left": int,
#   "damage_percent": float, "damage_type": "Physical"/"Pure",
#   "effect_type": String, "effect_value": int, "effect_duration": int,
#   "triggered_units_this_round": Array }  # для persistent
var position_marks: Array = []

# Ссылка на сцену боя для доступа к командам и вспомогательным методам
# (_log_combat, _on_unit_killed, _compact_team, _check_battle_end,
#  _apply_effect_to_unit, _update_all_visuals и т.д.).
var _scene  # намеренно без типа — динамическая диспетчеризация как в оригинале


func _init(scene) -> void:
	_scene = scene


# ════════════════════════════════════════════════
#  СИСТЕМА ПОЗИЦИОННЫХ МАРОК
# ════════════════════════════════════════════════

func place_mark(caster: Combatant, ability: AbilityResource) -> void:
	var mark = {
		"caster": caster,
		"team": ability.mark_target_team,
		"position": ability.mark_position,
		"type": ability.mark_type,
		"rounds_left": ability.mark_duration if ability.mark_type == "persistent" else 1,
		"damage_percent": ability.mark_damage_percent,
		"damage_type": ability.mark_damage_type,
		"effect_type": ability.mark_effect_type,
		"effect_value": ability.mark_effect_value,
		"effect_duration": ability.mark_effect_duration,
		"triggered_units_this_round": []
	}
	position_marks.append(mark)
	if not caster.is_enemy and ability.majesty_gain > 0:
		caster.modify_majesty(ability.majesty_gain)
	_scene._log_combat("%s накладывает марку на позицию %d (%s)." % [
		caster.unit_name, ability.mark_position + 1, ability.mark_target_team
	])
	var target = get_unit_at_mark(mark)
	# Персистентная марка срабатывает сразу при размещении (но не чаще раза за раунд);
	# одноразовая (once) — только в начале следующего хода владельца.
	if target and mark["type"] == "persistent":
		apply_mark_to_unit(mark, target, true)
		mark["triggered_units_this_round"].append(target)
	_scene._update_all_visuals()


func get_unit_at_mark(mark: Dictionary) -> Combatant:
	var team = _scene.heroes_team if mark["team"] == "ally" else _scene.enemies_team
	var pos = mark["position"]
	if pos >= 0 and pos < team.size() and team[pos] and team[pos].current_hp > 0:
		return team[pos]
	return null


func apply_mark_to_unit(mark: Dictionary, target: Combatant, is_placement: bool = false) -> void:
	var caster: Combatant = mark["caster"]
	if caster == null or caster.current_hp <= 0:
		return
	var log_prefix = "  [Марка→%s]" % target.unit_name

	# Урон
	if mark["damage_percent"] > 0:
		var raw = int(caster.damage * mark["damage_percent"] / 100.0)
		var final_dmg = raw
		if mark["damage_type"] == "Physical":
			final_dmg = CombatCalculator.apply_armor(raw, target.armor)
		var hp_before = target.current_hp
		target.take_damage(final_dmg)
		_scene._log_combat("%s получает %d урона от марки. HP: %d → %d" % [
			target.unit_name, final_dmg, hp_before, target.current_hp
		])
		if target.current_hp <= 0:
			_scene._log_combat("  → %s повержен маркой!" % target.unit_name)
			_scene._on_unit_killed(target)
			var team = _scene.heroes_team if not target.is_enemy else _scene.enemies_team
			_scene._compact_team(team)
			if _scene._check_battle_end():
				return

	# Эффект
	if mark["effect_type"] == "seawitch_curse_dot":
		target.active_effects.append({"stat": "periodic_damage", "value": mark["effect_value"], "duration": mark["effect_duration"], "source_ability": "Глубоководное проклятие"})
		_scene._log_combat("%s %s получает периодический урон (%d) от марки проклятия на %d ходов." % [log_prefix, target.unit_name, mark["effect_value"], mark["effect_duration"]])
	elif mark["effect_type"] == "inquisitor_auto_da_fe_dot":
		# Замок — Инквизитор «Аутодафе»: при входе в меченую клетку — периодический урон
		target.active_effects.append({"stat": "periodic_damage", "value": mark["effect_value"], "duration": mark["effect_duration"], "source_ability": "Аутодафе"})
		_scene._log_combat("%s %s получает периодический урон (%d) от марки Аутодафе на %d ходов." % [log_prefix, target.unit_name, mark["effect_value"], mark["effect_duration"]])
	# Один: «Стая воронов» — после атаки меченого врага союзник-владелец получает +15 точности
	elif mark["effect_type"] == "raven_mark_accuracy":
		target.active_effects.append({"stat": "raven_marked", "value": 0, "duration": maxi(1, mark["rounds_left"]), "effect_id": "raven_marked", "source_ability": "Стая воронов", "owner": caster})
		_scene._log_combat("%s %s помечен вороном: при его атаке союзник получит +15 точности." % [log_prefix, target.unit_name])
	# Самди: «Кукла вуду» — связать цель с юнитом позади (50% урона переходит на него)
	elif mark["effect_type"] == "ally_buff_evasion":
		target.apply_stat_change("evasion", mark["effect_value"])
		target.active_effects.append({"stat": "evasion", "value": mark["effect_value"], "duration": mark["effect_duration"], "effect_id": "osiris_rays_of_glory", "source_ability": "Лучи славы"})
		_scene._log_combat("%s %s получает +%d уклонения от Лучей славы на %d ход(ов)." % [log_prefix, target.unit_name, mark["effect_value"], mark["effect_duration"]])
	# Дьявол: «Адская гильотина» — once-марка, наносит 1.0 урона + 0.5 уровней забыванья
	elif mark["effect_type"] == "devil_guillotine":
		var _dg_dmg = caster.damage
		var _dg_hp_b = target.current_hp
		target.take_damage(_dg_dmg)
		target.add_forget(0.5, "Адская гильотина")
		_scene._log_combat("%s [Адская гильотина] %s получает %d урона и 0.5 уровней забыванья. HP: %d → %d" % [log_prefix, target.unit_name, _dg_dmg, _dg_hp_b, target.current_hp])
		if target.current_hp <= 0:
			_scene._log_combat("  → %s повержен гильотиной!" % target.unit_name)
			_scene._on_unit_killed(target)
			var _dg_team = _scene.heroes_team if target.is_enemy else _scene.enemies_team
			_scene._compact_team(_dg_team)
	# Асура: «Чёрная полоса» — persistent марка, -20 удачи пока активна
	elif mark["effect_type"] == "asura_streak_debuff":
		target.apply_stat_change("crit", -mark["effect_value"])
		target.active_effects.append({"stat": "crit", "value": -mark["effect_value"], "duration": maxi(1, mark["rounds_left"]), "effect_id": "asura_streak_debuff", "source_ability": "Чёрная полоса"})
		_scene._log_combat("%s %s: чёрная полоса (-%d удачи) на %d ход(ов)." % [log_prefix, target.unit_name, mark["effect_value"], maxi(1, mark["rounds_left"])])
	elif mark["effect_type"] == "voodoo_mark":
		var _v_team = _scene.enemies_team if target.is_enemy else _scene.heroes_team
		var _behind_pos = target.position_index + 1
		var _linked = null
		if _behind_pos < _v_team.size() and _v_team[_behind_pos] != null and _v_team[_behind_pos].current_hp > 0:
			_linked = _v_team[_behind_pos]
		target.active_effects.append({"stat": "voodoo_marked", "value": 0, "duration": maxi(1, mark["rounds_left"]), "effect_id": "voodoo_marked", "source_ability": "Кукла вуду", "linked": _linked})
		if _linked != null:
			_scene._log_combat("%s %s связан куклой вуду с %s (50%% урона переходит)." % [log_prefix, target.unit_name, _linked.unit_name])
		else:
			_scene._log_combat("%s %s помечен куклой вуду (позади никого нет)." % [log_prefix, target.unit_name])
	# Чернобог: «Ужас без конца» -10 броня/удача/уклонение, +15 атака/точность (обновление, без стэка)
	elif mark["effect_type"] == "chernobog_endless_horror":
		var _eh_id = "chernobog_endless_horror"
		var _eh_dur = maxi(1, mark["rounds_left"])
		var _already = false
		for e in target.active_effects:
			if Combatant._effect_get(e, "effect_id", "") == _eh_id:
				e["duration"] = _eh_dur
				_already = true
		if not _already:
			var _eh_pack = [["armor", -10], ["crit", -10], ["evasion", -10], ["damage", 15], ["accuracy", 15]]
			for p in _eh_pack:
				target.apply_stat_change(p[0], p[1])
				target.active_effects.append({"stat": p[0], "value": p[1], "duration": _eh_dur, "effect_id": _eh_id, "source_ability": "Ужас без конца"})
		_scene._log_combat("%s %s: ужас без конца (-10 броня/удача/уклонение, +15 атака/точность) на %d ходов." % [log_prefix, target.unit_name, _eh_dur])
	# Дуна: «Защита из корней» (безопасность — марочный вариант, если марка размещена на союзнике)
	elif mark["effect_type"] == "root_protection":
		var _rp_bonus = int(target.base_armor * 0.2)
		target.armor_modifier += _rp_bonus
		target.active_effects.append({"stat": "armor", "value": _rp_bonus, "duration": maxi(1, mark["rounds_left"]), "effect_id": "root_protection", "source_ability": "Защита из корней"})
		target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": maxi(1, mark["rounds_left"]), "effect_id": "root_thorns", "source_ability": "Защита из корней"})
		_scene._log_combat("%s %s: +%d брони, шипы 40%%." % [log_prefix, target.unit_name, _rp_bonus])
	elif mark["effect_type"] != "":
		var fake_ab = AbilityResource.new()
		fake_ab.effect_values = { mark["effect_type"]: mark["effect_value"] }
		fake_ab.effect_durations = { mark["effect_type"]: mark["effect_duration"] }
		var note = _scene._apply_effect_to_target(caster, target, mark["effect_type"], fake_ab)
		if note != "":
			_scene._log_combat("%s %s" % [log_prefix, note])

	_scene._update_all_visuals()


func tick() -> void:
	var i = 0
	while i < position_marks.size():
		var mark = position_marks[i]
		mark["triggered_units_this_round"] = []
		if mark["type"] == "persistent":
			mark["rounds_left"] -= 1
			if mark["rounds_left"] <= 0:
				_scene._log_combat("Марка на позиции %d истекла." % (mark["position"] + 1))
				position_marks.remove_at(i)
				continue
		i += 1


func trigger_once_for_caster(caster: Combatant) -> void:
	var i = 0
	while i < position_marks.size():
		var mark = position_marks[i]
		if mark["type"] == "once" and mark["caster"] == caster:
			var target = get_unit_at_mark(mark)
			if target:
				_scene._log_combat("⚑ Одноразовая марка срабатывает на позиции %d!" % (mark["position"] + 1))
				apply_mark_to_unit(mark, target)
			position_marks.remove_at(i)
		else:
			i += 1


func trigger_persistent_for_unit(unit: Combatant) -> void:
	for mark in position_marks:
		if mark["type"] != "persistent":
			continue
		var target_at_pos = get_unit_at_mark(mark)
		if target_at_pos != unit:
			continue
		if unit in mark["triggered_units_this_round"]:
			continue
		mark["triggered_units_this_round"].append(unit)
		_scene._log_combat("⚑ Марка на позиции %d срабатывает на %s!" % [mark["position"] + 1, unit.unit_name])
		apply_mark_to_unit(mark, unit)


func check_on_move(unit: Combatant) -> void:
	for mark in position_marks:
		if mark["type"] != "persistent":
			continue
		if get_unit_at_mark(mark) != unit:
			continue
		if unit in mark["triggered_units_this_round"]:
			continue
		mark["triggered_units_this_round"].append(unit)
		_scene._log_combat("⚑ Марка на позиции %d срабатывает на вошедшего %s!" % [mark["position"] + 1, unit.unit_name])
		apply_mark_to_unit(mark, unit)
