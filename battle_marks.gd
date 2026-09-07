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

func place_mark(caster: Combatant, ability: AbilityResource, position_override: int = -1) -> void:
	var mark_position: int = ability.mark_position if position_override < 0 else position_override
	var mark = {
		"caster": caster,
		"team": ability.mark_target_team,
		"position": mark_position,
		"type": ability.mark_type,
		"rounds_left": ability.mark_duration if ability.mark_type == "persistent" else 1,
		"damage_percent": ability.mark_damage_percent,
		"damage_type": ability.mark_damage_type,
		"effect_type": ability.mark_effect_type,
		"effect_value": ability.mark_effect_value,
		"effect_duration": ability.mark_effect_duration,
		"majesty_gain": ability.majesty_gain,
		"icon": ability.mark_icon,
		"triggered_units_this_round": []
	}
	add_position_mark(mark)
	if not caster.is_enemy and ability.majesty_gain > 0:
		caster.modify_majesty(ability.majesty_gain)
	_scene._log_combat("%s накладывает марку на позицию %d (%s)." % [
		caster.unit_name, mark_position + 1, ability.mark_target_team
	])
	var target = get_unit_at_mark(mark)
	# Персистентная марка срабатывает сразу при размещении (но не чаще раза за раунд);
	# одноразовая (once) — только в начале следующего хода владельца.
	if target and mark["type"] == "persistent":
		apply_mark_to_unit(mark, target, true)
		mark["triggered_units_this_round"].append(target)
	_scene._update_all_visuals()


## Размещает марку, удалив предыдущие на той же позиции (команда + позиция).
## На одной позиции может висеть только одна марка — последняя наложенная.
func add_position_mark(mark: Dictionary) -> void:
	var team = mark.get("team", "")
	var pos = mark.get("position", -1)
	for i in range(position_marks.size() - 1, -1, -1):
		var m = position_marks[i]
		if m.get("team", "") == team and m.get("position", -1) == pos:
			position_marks.remove_at(i)
	position_marks.append(mark)


func get_unit_at_mark(mark: Dictionary) -> Combatant:
	var team = _scene.heroes_team if mark["team"] == "ally" else _scene.enemies_team
	var pos = mark["position"]
	if pos >= 0 and pos < team.size() and team[pos] and team[pos].current_hp > 0:
		return team[pos]
	return null


## Самди «Кукла вуду»: метка НА ЮНИТЕ (не позиционная марка) — связывает цель
## с живым юнитом позади неё: 50% урона и копии дебаффов уходят связанному.
func apply_voodoo_mark(caster: Combatant, target: Combatant, rounds: int) -> void:
	if caster == null or target == null or target.current_hp <= 0:
		return
	var _v_team = _scene.enemies_team if target.is_enemy else _scene.heroes_team
	var _linked: Combatant = null
	for _linked_pos in range(target.position_index + 1, _v_team.size()):
		var _candidate = _v_team[_linked_pos]
		if _candidate != null and _candidate != target and _candidate.current_hp > 0:
			_linked = _candidate
			break
	var _vd_duration = _scene._compute_effect_duration(caster, target, maxi(1, rounds), true)
	target.active_effects.append({"stat": "voodoo_marked", "value": 0, "duration": _vd_duration, "effect_id": "voodoo_marked", "source_ability": "Кукла вуду", "linked": _linked})
	if _linked != null:
		_scene._log_combat("  [Кукла вуду] %s связан с %s: 50%% урона и дебаффы переходят связанному." % [target.unit_name, _linked.unit_name])
	else:
		_scene._log_combat("  [Кукла вуду] %s помечен (позади никого нет)." % target.unit_name)


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
		var _rm_duration = _scene._compute_effect_duration(caster, target, maxi(1, mark["rounds_left"]), true)
		target.active_effects.append({"stat": "raven_marked", "value": 0, "duration": _rm_duration, "effect_id": "raven_marked", "source_ability": "Стая воронов", "owner": caster})
		_scene._log_combat("%s %s помечен вороном: при его атаке союзник получит +15 точности." % [log_prefix, target.unit_name])
	# Самди: «Кукла вуду» — связать цель с юнитом позади (50% урона переходит на него)
	elif mark["effect_type"] == "ally_buff_evasion":
		var _rg_duration = _scene._compute_effect_duration(caster, target, mark["effect_duration"], false)
		target.apply_stat_change("evasion", mark["effect_value"])
		target.active_effects.append({"stat": "evasion", "value": mark["effect_value"], "duration": _rg_duration, "effect_id": "osiris_rays_of_glory", "source_ability": "Лучи славы"})
		# Осирис уже получает величие через обычный majesty_gain (place_mark) — сама марка даёт то же количество союзнику под ней.
		target.modify_majesty(int(mark.get("majesty_gain", 15)))
		_scene._log_combat("%s %s получает +%d уклонения и величие от Лучей славы на %d ход(ов)." % [log_prefix, target.unit_name, mark["effect_value"], _rg_duration])
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
		apply_voodoo_mark(caster, target, mark["rounds_left"])
	# Чернобог: «Ужас без конца» -10 броня/удача/уклонение, +15 атака/точность (обновление, без стэка)
	elif mark["effect_type"] == "chernobog_endless_horror":
		var _eh_id = "chernobog_endless_horror"
		var _eh_dur = _scene._compute_effect_duration(caster, target, maxi(1, mark["rounds_left"]), true)
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
	# Водяной: «Болотное царство» — копирует эффект локации (Топь) на отмеченную цель на 1 ход (обновляется, пока висит марка)
	elif mark["effect_type"] == "copy_location_effect":
		if CombatManager.selected_location_id == "swamp":
			var _bt_ut_count = 0
			for _bt_u in (_scene.enemies_team if not target.is_enemy else _scene.heroes_team):
				if _bt_u and _bt_u.current_hp > 0 and _bt_u.special_effect_type == "utoplennitsa_location_amplify":
					_bt_ut_count += 1
			var _bt_mult = 1.0 + 0.05 * _bt_ut_count
			var _bt_armor = int(round(5 * _bt_mult))
			var _bt_evasion = int(round(5 * _bt_mult))
			target.initiative = maxi(target.initiative - 1, 0)
			target.apply_stat_change("armor", -_bt_armor)
			target.apply_stat_change("evasion", -_bt_evasion)
			var _bt_duration = _scene._compute_effect_duration(caster, target, 1, true)
			target.active_effects.append({"stat": "armor", "value": -_bt_armor, "duration": _bt_duration, "effect_id": "bolotnoe_tsarstvo_mark", "source_ability": "Болотное царство"})
			target.active_effects.append({"stat": "evasion", "value": -_bt_evasion, "duration": _bt_duration, "effect_id": "bolotnoe_tsarstvo_mark", "source_ability": "Болотное царство"})
			_scene._log_combat("%s %s: болотное царство копирует эффект Топи (-1 инициатива, -%d брони, -%d уклонения)." % [log_prefix, target.unit_name, _bt_armor, _bt_evasion])
		else:
			_scene._log_combat("%s %s: болотное царство активно, но эффект локации Топь не действует здесь." % [log_prefix, target.unit_name])
	# Мумия: «Древнее проклятие» — метка на позиции, -2 урон/-2 броня до конца боя тому, кто на ней стоит
	elif mark["effect_type"] == "mummy_ancient_curse_mark":
		var _mc_id = "mummy_ancient_curse_mark"
		var _mc_already = false
		for e in target.active_effects:
			if Combatant._effect_get(e, "effect_id", "") == _mc_id:
				_mc_already = true
		if not _mc_already:
			var _mc_val = int(mark["effect_value"])
			target.apply_stat_change("damage", -_mc_val)
			target.apply_stat_change("armor", -_mc_val)
			target.active_effects.append({"stat": "damage", "value": -_mc_val, "duration": -1, "effect_id": _mc_id, "source_ability": "Древнее проклятие"})
			target.active_effects.append({"stat": "armor", "value": -_mc_val, "duration": -1, "effect_id": _mc_id, "source_ability": "Древнее проклятие"})
		_scene._log_combat("%s %s: древнее проклятие (-%d урона, -%d брони) до конца боя." % [log_prefix, target.unit_name, int(mark["effect_value"]), int(mark["effect_value"])])
	# Дуна: «Защита из корней» (безопасность — марочный вариант, если марка размещена на союзнике)
	elif mark["effect_type"] == "root_protection":
		var _rp_bonus = int(target.base_armor * 0.2)
		target.armor_modifier += _rp_bonus
		var _rp_duration = _scene._compute_effect_duration(caster, target, maxi(1, mark["rounds_left"]), false)
		target.active_effects.append({"stat": "armor", "value": _rp_bonus, "duration": _rp_duration, "effect_id": "root_protection", "source_ability": "Защита из корней"})
		target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": _rp_duration, "effect_id": "root_thorns", "source_ability": "Защита из корней"})
		_scene._log_combat("%s %s: +%d брони, шипы 40%%." % [log_prefix, target.unit_name, _rp_bonus])
	elif mark["effect_type"] != "":
		var fake_ab = AbilityResource.new()
		# effect_values/effect_durations — типизированные Dictionary[String, int],
		# поэтому заполняем через типизированные локальные словари (иначе падает присвоение).
		var _mk_vals: Dictionary[String, int] = {}
		_mk_vals[mark["effect_type"]] = int(mark["effect_value"])
		fake_ab.effect_values = _mk_vals
		var _mk_durs: Dictionary[String, int] = {}
		_mk_durs[mark["effect_type"]] = int(mark["effect_duration"])
		fake_ab.effect_durations = _mk_durs
		var note = _scene.effects._apply_effect_to_target(caster, target, mark["effect_type"], fake_ab)
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
