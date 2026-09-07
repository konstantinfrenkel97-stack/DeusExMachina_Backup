## ════════════════════════════════════════════════════════════════
##  BattleEffects — общая система баффов/дебаффов миссии/боя: разбор строкового
##  effect_types способности в конкретный эффект на юните (_apply_effect_to_target),
##  снятие эффектов (dispel), кража баффов, регенерация Мучителя, блокировка баффа
##  стойками «Надежды нет»/«Оставь надежду», применение баффа с пассивками-реакциями
##  (Нага монах, гном-кузнец, Дева, Близнецы).
##  Выделено из battle_scene.gd (тот же приём, что и battle_locations.gd/battle_marks.gd).
##  Вся логика перенесена 1:1; поведение боя не изменено.
##
##  battle_scene делегирует эти вызовы этому объекту через `effects.` — методы и их
##  сигнатуры оставлены как были (с ведущим "_", чтобы не путать с публичным API).
##  Функции, которые используются и ЗА пределами этого модуля (широко расшаренные
##  утилиты вроде _compute_effect_duration, _apply_shift_effect, _is_player_hero,
##  _notify_stun_applied), НЕ перенесены — они остаются на сцене и вызываются здесь
##  через `_scene.`, как и всё прочее состояние/методы сцены.
## ════════════════════════════════════════════════════════════════
extends RefCounted
class_name BattleEffects

# Ссылка на сцену боя — доступ к командам и вспомогательным методам сцены
# (_log_combat, _update_all_visuals, _compute_effect_duration, _apply_shift_effect,
#  _is_player_hero, _notify_stun_applied, _deal_damage, _on_unit_killed,
#  _compact_team, _check_battle_end, _is_fog_round и т.д.).
var _scene  # намеренно без типа — динамическая диспетчеризация как в battle_marks.gd


func _init(scene) -> void:
	_scene = scene


## Проверяет, есть ли у юнита активная метка провокации.
func _has_provocation(unit: Combatant) -> bool:
	for eff in unit.active_effects:
		if Combatant._effect_get(eff, "stat", "") == "provocation_mark":
			return true
	return false

## Проверяет, есть ли у юнита активная метка невинности.
func _has_innocence(unit: Combatant) -> bool:
	for eff in unit.active_effects:
		if Combatant._effect_get(eff, "effect_id", "") == "cupid_innocence":
			return true
	return false

func _remove_effect_id(unit: Combatant, effect_id: String) -> void:
	if unit == null:
		return
	for i in range(unit.active_effects.size() - 1, -1, -1):
		if Combatant._effect_get(unit.active_effects[i], "effect_id", "") == effect_id:
			unit.active_effects.remove_at(i)

func _has_special_on_team(team: Array, effect_type: String) -> bool:
	for unit in team:
		if unit and unit.current_hp > 0 and unit.special_effect_type == effect_type:
			return true
	return false


## Пегас: когда союзник получает бафф, случайный живой Пегас в той же команде
## получает +5 атаки (перманентно, стакается).
func _check_pegasus_ally_buff(buffed_unit: Combatant, log_lines = null):
	if buffed_unit == null:
		return
	var team = _scene.enemies_team if buffed_unit.is_enemy else _scene.heroes_team
	for pegasus in team:
		if pegasus and pegasus.current_hp > 0 and pegasus != buffed_unit and pegasus.special_effect_type == "pegasus_ally_buff":
			pegasus.apply_stat_change("damage", 5)
			pegasus.active_effects.append({"stat": "damage", "value": 5, "duration": -1, "effect_id": "pegasus_ally_buff_stack", "source_ability": "Пассивка Пегаса"})
			var _pg_line = "  → [Пегас] %s: +5 атаки (союзник получил бафф)." % pegasus.unit_name
			if log_lines != null:
				log_lines.append(_pg_line)
			else:
				_scene._log_combat(_pg_line)
			break


## Разбирает один effect (из AbilityResource.effect_types) и применяет его к target.
## Возвращает строку для боевого лога (или "" если эффект не сработал/не найден).
func _apply_effect_to_target(attacker: Combatant, target: Combatant, effect: String, ability: AbilityResource, is_crit: bool = false) -> String:
	var val = ability.effect_values.get(effect, 0)
	var duration = ability.effect_durations.get(effect, 1)

	# Продление длительности пассивками (Один/Нага монах — баффы; Кикимора/Самди — дебаффы) —
	# см. _compute_effect_duration, единая точка входа для всей этой логики.
	if effect.contains("debuff"):
		duration = _scene._compute_effect_duration(attacker, target, duration, true)
	elif effect.contains("buff"):
		duration = _scene._compute_effect_duration(attacker, target, duration, false)

	# Сфинкс / Чёрная маска Чернобога: иммунитет ко всем дебаффам
	if target.special_effect_type == "sphinx_debuff_immune" or target.has_item_effect("chernobog_debuff_immune"):
		if effect.contains("debuff") or effect == "stun" or effect == "periodic_damage" or effect == "dispel_buffs":
			return "%s: иммунен к дебаффам." % target.unit_name

	# Дуна: «В гармонии с природой» — союзники иммунны к дебаффам (эффект отменяется, лёгкое исцеление)
	if effect.contains("debuff") or effect == "stun" or effect == "periodic_damage" or effect == "dispel_buffs":
		for _dh_e in target.active_effects:
			if Combatant._effect_get(_dh_e, "effect_id", "") == "duna_harmony_immune":
				var _dh_heal = int(target.max_hp * 0.10)
				if _dh_heal > 0:
					target.apply_stat_change("hp", _dh_heal)
				return "%s защищён природой — дебафф отменён, восстановлено %d HP (10%%)." % [target.unit_name, _dh_heal]

	if effect.ends_with("push_forward"):
		var mover = attacker if effect.begins_with("self_") else target
		if mover.is_large and not attacker.is_large:
			return "%s — слишком велик, чтобы его сдвинуть!" % mover.unit_name
		var old_pos = mover.position_index
		_scene._apply_shift_effect(mover, -val, _scene._is_player_hero(mover))
		return "%s продвигается вперёд: линия %d → %d." % [mover.unit_name, old_pos + 1, mover.position_index + 1]
	elif effect.ends_with("push_back"):
		var mover = attacker if effect.begins_with("self_") else target
		if mover.is_large and not attacker.is_large:
			return "%s — слишком велик, чтобы его сдвинуть!" % mover.unit_name
		var old_pos = mover.position_index
		_scene._apply_shift_effect(mover, val, _scene._is_player_hero(mover))
		return "%s отталкивается назад: линия %d → %d." % [mover.unit_name, old_pos + 1, mover.position_index + 1]

	elif effect.ends_with("pull_forward") or effect.ends_with("pull_porward"):
		var mover = attacker if effect.begins_with("self_") else target
		if mover.is_large and not attacker.is_large:
			return "%s — слишком велик, чтобы его сдвинуть!" % mover.unit_name
		var old_pos = mover.position_index
		_scene._apply_shift_effect(mover, -val, _scene._is_player_hero(mover))
		return "%s притягивается вперёд: линия %d → %d." % [mover.unit_name, old_pos + 1, mover.position_index + 1]

	elif effect == "periodic_damage":
		var pd_duration = _scene._compute_effect_duration(attacker, target, duration, true)
		var dot_effect = {"stat": "periodic_damage", "value": val, "duration": pd_duration, "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name}
		target.active_effects.append(dot_effect)
		# Мучитель: пассивка — при наложении DoT союзником даёт регенерацию всем Мучителям в команде
		_apply_tormentor_regen(attacker, val, pd_duration)
		return "%s получает периодический урон (%d) на %d ход(ов)." % [target.unit_name, val, pd_duration]

	elif effect == "target_root":
		# Леший «Ни шагу»: цель не может передвигаться N ходов
		var root_duration = _scene._compute_effect_duration(attacker, target, duration, true)
		target.active_effects.append({"stat": "rooted", "value": val, "duration": root_duration, "effect_id": "rooted", "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name})
		return "%s опутан корнями и не может передвигаться %d ход(ов)." % [target.unit_name, root_duration]

	elif effect == "stun":
		target.is_stunned = true
		var stun_duration = _scene._compute_effect_duration(attacker, target, duration, true)
		var stun_effect = {"stat": "stun", "value": 1, "duration": stun_duration, "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name}
		target.active_effects.append(stun_effect)
		target.check_stance_interruption("stun")
		_scene._notify_stun_applied(target)
		return "%s оглушён на %d ход(ов)." % [target.unit_name, stun_duration]

	elif effect == "crit_stun":
		if not is_crit or target.is_stunned:
			return ""
		if target.special_effect_type == "sphinx_debuff_immune" or target.has_item_effect("chernobog_debuff_immune"):
			return "%s: иммунен к дебаффам." % target.unit_name
		target.is_stunned = true
		var cs_duration = _scene._compute_effect_duration(attacker, target, duration, true)
		target.active_effects.append({"stat": "stun", "value": 1, "duration": cs_duration, "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name})
		target.check_stance_interruption("stun")
		_scene._notify_stun_applied(target)
		return "%s оглушён критическим ударом на %d ход(ов)." % [target.unit_name, cs_duration]

	elif effect == "self_damage_hp_percent":
		var self_dmg = int(target.max_hp * val / 100.0)
		target.take_damage(self_dmg)
		return "%s получает %d урона (%d%% от макс. HP)." % [target.unit_name, self_dmg, val]
	elif effect == "self_heal_percent":
		var heal_amount = int(target.max_hp * (val / 100.0))
		target.apply_stat_change("hp", heal_amount)
		return "%s восстанавливает %d HP." % [target.unit_name, heal_amount]
	elif effect == "target_heal_percent":
		var heal_amount = int(target.max_hp * (val / 100.0))
		var _hp_before = target.current_hp
		target.apply_stat_change("hp", heal_amount)
		return "%s восстанавливает %d HP (%d → %d)." % [target.unit_name, heal_amount, _hp_before, target.current_hp]
	elif effect == "heal_flat":
		target.apply_stat_change("hp", val)
		return "%s восстанавливает %d HP." % [target.unit_name, val]
	elif effect == "dispel_buffs":
		_dispel_effects(target, "buff")
		return "С %s сняты положительные эффекты." % target.unit_name
	elif effect == "all_allies_dispel_debuffs":
		_dispel_effects(target, "debuff")
		return "С %s сняты отрицательные эффекты." % target.unit_name
	elif effect == "dispel_debuffs" or effect == "self_dispel_debuffs":
		_dispel_effects(target, "debuff")
		return "С %s сняты отрицательные эффекты." % target.unit_name
	elif effect == "cleanse_all":
		_dispel_effects(target, "all")
		return "С %s сняты все эффекты." % target.unit_name
	elif effect == "regeneration":
		var regen_duration = _scene._compute_effect_duration(attacker, target, duration, false)
		target.active_effects.append({"stat": "regeneration", "value": val, "duration": regen_duration, "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name})
		return "%s получает регенерацию (%d HP) на %d ход(ов)." % [target.unit_name, val, regen_duration]
	elif effect == "self_fog_accuracy":
		if _scene._is_fog_round:
			var fog_duration = _scene._compute_effect_duration(attacker, target, duration, false)
			target.apply_stat_change("accuracy", val)
			target.active_effects.append({"stat": "accuracy", "value": val, "duration": fog_duration, "effect_id": "self_fog_accuracy", "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name})
			return "%s: +%d точности (туманный раунд)." % [target.unit_name, val]
		return "%s: тумана нет, бонус точности не применяется." % target.unit_name
	elif effect == "self_provocation_mark":
		var prov_duration = _scene._compute_effect_duration(attacker, target, duration, false)
		target.active_effects.append({"stat": "provocation_mark", "value": 1, "duration": prov_duration, "effect_id": "provocation_mark", "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name})
		return "%s получает метку провокации на %d ход(ов)." % [target.unit_name, prov_duration]
	elif effect == "self_thor_hammer_of_lightning":
		_remove_effect_id(target, "thor_hammer_of_lightning")
		var hol_mark_duration = _scene._compute_effect_duration(attacker, target, duration, false)
		# Мьёльнир: эффект ульты длится ещё на 1 ход дольше.
		if attacker.has_item_effect("thor_mjolnir_extend_ult"):
			hol_mark_duration += 1
		target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": hol_mark_duration, "effect_id": "thor_hammer_of_lightning", "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name})
		return "%s получает метку Hammer_of_lightning на %d ход(ов)." % [target.unit_name, hol_mark_duration]

	elif effect == "self_thor_fight_me_heal":
		_remove_effect_id(target, "thor_fight_me_heal")
		var fmh_duration = _scene._compute_effect_duration(attacker, target, duration, false)
		target.active_effects.append({"stat": "trigger_marker", "value": 0, "duration": fmh_duration, "effect_id": "thor_fight_me_heal", "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name})
		return "%s будет восстанавливать 7%% здоровья при атаках по нему." % target.unit_name


	elif effect == "dispel_accuracy_debuffs":
		_dispel_stat_debuffs(target, "accuracy")
		return "С %s сняты дебаффы точности." % target.unit_name

	elif effect == "siren_to_the_bottom_bonus":
		# Обрабатывается отдельно в _use_ability через bonus damage
		return ""

	elif effect == "steal_buffs":
		return _steal_buffs_from_to(target, attacker)

	elif effect == "random_stat_buff":
		# +val к случайной характеристике (перманентно). target == self.
		var stats = ["damage", "armor", "initiative", "accuracy", "evasion", "crit"]
		var chosen_stat = stats[randi() % stats.size()]
		target.apply_stat_change(chosen_stat, val)
		target.active_effects.append({"stat": chosen_stat, "value": val, "duration": -1, "effect_id": "crab_search_treasure_%s" % chosen_stat, "source_ability": "crab_search_treasure"})
		return "%s: +%d к %s (перманентно)." % [target.unit_name, val, chosen_stat]

	elif effect == "target_extend_location_effect":
		# Утопленница «Вниз»: цель помечена — когда она покинет позицию 1, эффект Топи
		# держится на ней ещё val ходов (стек сохраняется, если она вернётся до истечения).
		_remove_effect_id(target, "utoplennitsa_swamp_extend")
		target.active_effects.append({"stat": "trigger_marker", "value": val, "duration": -1, "effect_id": "utoplennitsa_swamp_extend", "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name})
		return "%s помечен(а): эффект локации будет держаться на %d ход(ов) дольше после ухода с позиции." % [target.unit_name, val]

	elif effect == "medusa_curse_initiative":
		target.apply_stat_change("initiative", -val)
		target.active_effects.append({"stat": "initiative", "value": -val, "duration": duration, "effect_id": "medusa_curse_initiative", "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name})
		var curse_note = "%s: -%d к инициативе на %d ход(ов)." % [target.unit_name, val, duration]
		# Накопление: если суммарный дебафф инициативы <= -5 → стан
		var total_init_debuff = 0
		for e in target.active_effects:
			if Combatant._effect_get(e, "stat", "") == "initiative" and Combatant._effect_get(e, "value", 0) < 0:
				total_init_debuff += Combatant._effect_get(e, "value", 0)
		if total_init_debuff <= -5 and not target.is_stunned:
			target.is_stunned = true
			target.active_effects.append({"stat": "stun", "value": 1, "duration": 1, "source_ability": "medusa_curse_initiative"})
			target.check_stance_interruption("stun")
			_scene._notify_stun_applied(target)
			curse_note += " Суммарный дебафф инициативы достиг -5 → %s оглушён!" % target.unit_name
		return curse_note

	else:
		var stat = _extract_stat_name(effect)
		if effect.contains("debuff"):
			target.apply_stat_change(stat, -val)
			target.active_effects.append({"stat": stat, "value": -val, "duration": duration, "effect_id": effect, "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name})
			# Кукла вуду: перенести дебафф на связанного (юнита позади) меченой цели

			# ═══ Локация: Сад — при дебаффе на союзника +15 чистого урона ═══
			var garden_note = ""
			if CombatManager.selected_location_id == "garden" and not target.is_enemy and target.current_hp > 0:
				var hp_before_g = target.current_hp
				target.take_damage(15)
				garden_note = " [Сад] +15 чистого урона при дебаффе. HP: %d → %d" % [hp_before_g, target.current_hp]

			# ═══ Цветочная фея / Фея шипов: реакция на дебафф на противнике ═══
			var _ft_foe_team = _scene.enemies_team if not target.is_enemy else _scene.heroes_team
			if _has_special_on_team(_ft_foe_team, "flower_fairy_debuff_evasion"):
				for _ff_ally in _ft_foe_team:
					if _ff_ally and _ff_ally.current_hp > 0:
						_ff_ally.apply_stat_change("evasion", 3)
						_ff_ally.active_effects.append({"stat": "evasion", "value": 3, "duration": 1, "effect_id": "flower_fairy_debuff_evasion", "source_ability": "Пассивка феи лепестков"})
			if _has_special_on_team(_ft_foe_team, "thorn_fairy_debuff_damage") and target.current_hp > 0:
				var _tf_hp_b = target.current_hp
				target.take_damage(5)
				garden_note += " [Фея шипов] +5 чистого урона. HP: %d → %d" % [_tf_hp_b, target.current_hp]

			return "%s: -%d к %s на %d ход(ов).%s" % [target.unit_name, val, stat, duration, garden_note]
		elif effect.contains("buff"):
			if _block_buff_for_hopeless_stance(target):
				return ""
			target.apply_stat_change(stat, val)
			target.active_effects.append({"stat": stat, "value": val, "duration": duration, "effect_id": effect, "source_ability": ability.ability_marker if ability.ability_marker != "" else ability.name})
			_check_pegasus_ally_buff(target)
			return "%s: +%d к %s на %d ход(ов)." % [target.unit_name, val, stat, duration]

	return ""

## Извлекает имя стата из названия эффекта.
## Пример: "target_debuff_accuracy" → "accuracy", "self_buff_damage" → "damage"
func _extract_stat_name(effect: String) -> String:
	var stat = effect
	var prefixes = ["All_Enemies_", "All_Allies_", "all_allies_", "all_enemies_", "self_", "target_", "enemy_", "ally_"]
	for p in prefixes:
		if stat.begins_with(p):
			stat = stat.substr(p.length())
			break
	if stat.begins_with("buff_"):
		stat = stat.substr(5)
	elif stat.begins_with("debuff_"):
		stat = stat.substr(7)
	return stat


func _dispel_effects(target: Combatant, type: String):
	var i = 0
	while i < target.active_effects.size():
		var effect = target.active_effects[i]
		var stat_name = Combatant._effect_get(effect, "stat")
		var effect_value = Combatant._effect_get(effect, "value", 0)
		var should_remove = false

		var effect_id = Combatant._effect_get(effect, "effect_id", "")
		if Combatant._effect_get(effect, "dispellable", true) == false:
			i += 1
			continue
		if effect_id == "neverending_storm_mark":
			i += 1
			continue
		# Не снимаем локационные эффекты (swamp_debuff и helheim_fog)
		if effect_id == "swamp_debuff" or effect_id == "helheim_fog":
			i += 1
			continue
		var is_buff = effect_value > 0 and stat_name != "stun" and stat_name != "periodic_damage"

		if type == "all":
			should_remove = true
		elif type == "buff" and is_buff:
			should_remove = true
		elif type == "debuff" and !is_buff:
			should_remove = true

		if should_remove:
			if stat_name != "stun" and stat_name != "periodic_damage":
				target.apply_stat_change(stat_name, -effect_value)
			elif stat_name == "stun":
				target.is_stunned = false

			target.active_effects.remove_at(i)
		else:
			i += 1
	_scene._update_all_visuals()

## Снимает с юнита все дебаффы указанного стата (например, "accuracy").
## Используется эффектом dispel_accuracy_debuffs (способность «Мотивация» Капитана).
func _dispel_stat_debuffs(target: Combatant, stat_name: String):
	var i = 0
	while i < target.active_effects.size():
		var effect = target.active_effects[i]
		var e_stat = Combatant._effect_get(effect, "stat", "")
		var e_val = Combatant._effect_get(effect, "value", 0)
		if e_stat == stat_name and e_val < 0:
			target.apply_stat_change(e_stat, -e_val)
			target.active_effects.remove_at(i)
		else:
			i += 1
	_scene._update_all_visuals()

## Краб-коллектор: перенос всех баффов с source на dest (без изменения длительности).
func _steal_buffs_from_to(source: Combatant, dest: Combatant) -> String:
	var i = 0
	var stolen = 0
	while i < source.active_effects.size():
		var e = source.active_effects[i]
		var e_stat = Combatant._effect_get(e, "stat", "")
		var e_val = Combatant._effect_get(e, "value", 0)
		if Combatant._effect_get(e, "dispellable", true) == false:
			i += 1
			continue
		var is_buff = e_val > 0 and e_stat != "stun" and e_stat != "periodic_damage"
		if is_buff:
			# Снимаем с источника (реверс стата)
			source.apply_stat_change(e_stat, -e_val)
			source.active_effects.remove_at(i)
			# Переносим на получателя
			dest.apply_stat_change(e_stat, e_val)
			var _copy = e.duplicate()
			_copy["source_ability"] = "crab_steal"
			dest.active_effects.append(_copy)
			stolen += 1
		else:
			i += 1
	_scene._update_all_visuals()
	if stolen > 0:
		return "%s крадёт %d бафф(ов) у %s." % [dest.unit_name, stolen, source.unit_name]
	return "%s: нет баффов для кражи у %s." % [dest.unit_name, source.unit_name]


func _apply_tormentor_regen(caster: Combatant, dot_value: int, dot_duration: int) -> void:
	if caster == null or dot_value <= 0:
		return
	var team = _scene.enemies_team if caster.is_enemy else _scene.heroes_team
	for _t_u in team:
		if _t_u != null and _t_u.current_hp > 0 and _t_u.special_effect_type == "tormentor_dot_regen":
			_t_u.active_effects.append({"stat": "regeneration", "value": dot_value, "duration": dot_duration, "effect_id": "tormentor_regen", "source_ability": "Пассивка Мучителя"})
			_scene._log_combat("⛓ [Мучитель] %s получает регенерацию %d%% на %d ход(ов) за наложение DoT союзником." % [_t_u.unit_name, dot_value, dot_duration])
	return

## Чернобог «Надежды нет» / Дьявол «Оставь надежду»: если у цели в команде противников
## активна эта стойка, бафф не применяется — вместо этого цель получает урон (Дьявол
## также забирает 10 величия). Возвращает true, если бафф был заблокирован (вызывающий
## должен пропустить применение бафа). Общая точка входа для всех путей наложения
## баффа — _apply_buff_to_unit(), генерального обработчика в _apply_effect_to_target()
## и _apply_spell_to_target(); раньше проверка была только в _apply_buff_to_unit(),
## и большинство баффов (через effect_types способностей и заклинания) её не проходили.
func _block_buff_for_hopeless_stance(target: Combatant) -> bool:
	var enemy_team_of_target = _scene.heroes_team if target.is_enemy else _scene.enemies_team
	for u in enemy_team_of_target:
		if u != null and u.current_hp > 0 and u.active_stance != null:
			if u.active_stance.stance_effect_type == "chernobog_no_hope":
				var d = CombatCalculator.calculate_fixed_damage(u, target, 0.8)
				if d.is_hit:
					_scene._deal_damage(target, d.final_damage, d.is_crit)
					_scene._log_combat("  → [Надежды нет] %s не может получить бафф! Получает %d урона." % [target.unit_name, d.final_damage])
					if target.current_hp <= 0:
						_scene._log_combat("  → %s повержен эффектом «Надежды нет»!" % target.unit_name)
						_scene._on_unit_killed(target)
						_scene._compact_team(_scene.heroes_team if not target.is_enemy else _scene.enemies_team)
						_scene._check_battle_end()
				else:
					_scene._log_combat("  → [Надежды нет] %s не может получить бафф (промах)." % target.unit_name)
				return true
			elif u.active_stance.stance_effect_type == "devil_abandon_hope":
				var dd = CombatCalculator.calculate_fixed_damage(u, target, 0.15)
				if dd.is_hit:
					_scene._deal_damage(target, dd.final_damage, dd.is_crit)
				target.modify_majesty(-10)
				_scene._log_combat("  → [Оставь надежду] %s не может получить бафф! Получает %d урона, -10 величия." % [target.unit_name, dd.final_damage])
				if target.current_hp <= 0:
					_scene._log_combat("  → %s повержен эффектом «Оставь надежду»!" % target.unit_name)
					_scene._on_unit_killed(target)
					_scene._compact_team(_scene.heroes_team if not target.is_enemy else _scene.enemies_team)
					_scene._check_battle_end()
				return true
	return false

## Применяет стат и добавляет эффект, при необходимости усиливая/копируя его.
func _apply_buff_to_unit(target: Combatant, stat: String, value: int, duration: int, effect_id: String, source: String, log_arr: Array = []) -> void:
	if target == null or target.current_hp <= 0:
		return
	var is_buff = value > 0 and stat in ["accuracy", "damage", "armor", "evasion", "crit", "initiative"]
	var team = _scene.enemies_team if target.is_enemy else _scene.heroes_team
	# Нага монах: «Часть вселенной» — при получении баффа союзником, +7 удачи 1 ход + heal 7%
	if is_buff:
		for _nu_u in team:
			if _nu_u != null and _nu_u.current_hp > 0 and _nu_u != target and _nu_u.active_stance != null and _nu_u.active_stance.stance_effect_type == "naga_universe":
				target.apply_stat_change("crit", 7)
				target.active_effects.append({"stat": "crit", "value": 7, "duration": 1, "effect_id": "naga_universe", "source_ability": "Часть вселенной"})
				var _nu_heal = int(target.max_hp * 0.07)
				if _nu_heal > 0:
					target.apply_stat_change("hp", _nu_heal)
				break
		# Гном-кузнец: пассивка — при баффе союзника получает +5 брони на 2 хода
		for _ds_u in team:
			if _ds_u != null and _ds_u.current_hp > 0 and _ds_u != target and _ds_u.special_effect_type == "dwarf_smith_ally_buff":
				_ds_u.apply_stat_change("armor", 5)
				_ds_u.active_effects.append({"stat": "armor", "value": 5, "duration": 2, "effect_id": "dwarf_smith_ally_buff", "source_ability": "Пассивка гнома-кузнеца"})
	# Дуна: «В гармонии с природой» — союзники иммунны к дебаффам
	if not is_buff and value < 0:
		for eff in target.active_effects:
			if eff.get("effect_id", "") == "duna_harmony_immune":
				var _dh_heal = int(target.max_hp * 0.10)
				if _dh_heal > 0:
					target.apply_stat_change("hp", _dh_heal)
				if log_arr != null:
					log_arr.append("%s защищён природой — дебафф отменён, восстановлено %d HP (10%%)." % [target.unit_name, _dh_heal])
				return
	# Чернобог: «Надежды нет» / Дьявол: «Оставь надежду» — противники не могут получать баффы
	if is_buff:
		if _block_buff_for_hopeless_stance(target):
			return
		# Дева: +100% к изначальному баффу за каждую живую Деву в команде цели (линейно)
		var virgo_count = 0
		for u in team:
			if u and u.current_hp > 0 and u.special_effect_type == "virgo_buff_amplify":
				virgo_count += 1
		if virgo_count > 0:
			value *= (1 + virgo_count)
			if not log_arr.is_empty():
				log_arr.append("  → [Дева] Бафф %s усилен на +%d%% (x%d, итого %d)." % [target.unit_name, virgo_count * 100, 1 + virgo_count, value])
	target.apply_stat_change(stat, value)
	target.active_effects.append({"stat": stat, "value": value, "duration": duration, "effect_id": effect_id, "source_ability": source})
	if is_buff:
		# Близнецы: копия баффа на каждого живого Близнеца в команде цели
		for u in team:
			if u and u.current_hp > 0 and u != target and u.special_effect_type == "gemini_buff_copy":
				u.apply_stat_change(stat, value)
				u.active_effects.append({"stat": stat, "value": value, "duration": duration, "effect_id": effect_id + "_gemini_copy", "source_ability": source + " (копия Близнецов)"})
				if not log_arr.is_empty():
					log_arr.append("  → [Близнецы] %s получает копию: +%d %s." % [u.unit_name, value, stat])
