## Централизованный расчёт боевых формул.
## Извлечено из battle_scene.gd для устранения дублирования кода.
## Все методы статические — не нужно инстанцировать класс.
class_name CombatCalculator


## Проверка попадания (точность vs уклонение).
static func check_hit(attacker_accuracy: int, target_evasion: int) -> bool:
	var hit_chance := clampf(float(attacker_accuracy - target_evasion) / 100.0, 0.1, 1.0)
	return randf() <= hit_chance


## Проверка критического удара.
static func check_crit(crit_chance: float) -> bool:
	return randf() <= crit_chance


## Применение процентной брони к урону.
static func apply_armor(raw_damage: int, armor_percent: int) -> int:
	if raw_damage <= 0:
		return 0
	var reduction := clampf(float(armor_percent) / 100.0, 0.0, 0.95)
	return maxi(0, int(raw_damage * (1.0 - reduction)))


## Полный расчёт урона способности по одной цели.
## Включает: проверку попадания, модификатор позиции, глобальный эффект боя, крит, броню.
## Возвращает словарь:
##   is_hit: bool, is_crit: bool, raw_damage: int, final_damage: int, hp_before: int
static func calculate_ability_damage(attacker: Combatant, target: Combatant, ability: AbilityResource) -> Dictionary:
	var hp_before := target.current_hp

	if not check_hit(attacker.accuracy, target.evasion):
		return {
			"is_hit": false, "is_crit": false,
			"raw_damage": 0, "final_damage": 0,
			"hp_before": hp_before
		}

	var base_dmg := attacker.damage * ability.damage_modifier
	# Зевс vs большой юнит: предпочитает заднюю позицию (больше урон),
	# если способность может целить в position_index + 1.
	var target_pos_for_modifier := target.position_index
	if target.is_large and attacker.special_effect_type == "zeus_position_bonus":
		var back_pos := target.position_index + 1
		if ability.targetable_positions.size() > back_pos and ability.targetable_positions[back_pos]:
			target_pos_for_modifier = back_pos
	var position_bonus := attacker.get_damage_modifier(target_pos_for_modifier)
	var total_damage := int(base_dmg * position_bonus)

	# Нанауэ: +50% урона по целям с периодическим уроном (пассивка «жажда крови»)
	if attacker.special_effect_type == "nanau_bloodlust":
		for e in target.active_effects:
			if Combatant._effect_get(e, "stat", "") == "periodic_damage":
				total_damage = int(total_damage * 1.5)
				break

	var battle_dmg_mult := CombatManager.get_damage_multiplier()
	if battle_dmg_mult != 1.0:
		total_damage = int(total_damage * battle_dmg_mult)

	var is_crit := check_crit(attacker.crit_chance)
	var crit_mult := CombatManager.get_crit_multiplier() if is_crit else 1.0
	var raw_damage := int(total_damage * crit_mult)

	var final_damage := raw_damage
	if ability.damage_type == "Physical" and not CombatManager.is_armor_ignored():
		var _eff_armor := target.armor
		if attacker.special_effect_type == "giant_armor_pierce":
			_eff_armor = int(target.armor * 0.5)
		final_damage = apply_armor(raw_damage, _eff_armor)

	return {
		"is_hit": true, "is_crit": is_crit,
		"raw_damage": raw_damage, "final_damage": final_damage,
		"hp_before": hp_before
	}


## Расчёт фиксированного удара (для пассивок: thunder_wrath, storm_marks).
## [param damage_percent] — множитель урона (0.3 = 30% от базового урона атакующего).
## Крит всегда x2 (не зависит от глобального эффекта боя).
## Возвращает словарь той же структуры, что и calculate_ability_damage.
static func calculate_fixed_damage(attacker: Combatant, target: Combatant, damage_percent: float) -> Dictionary:
	var hp_before := target.current_hp

	if not check_hit(attacker.accuracy, target.evasion):
		return {
			"is_hit": false, "is_crit": false,
			"raw_damage": 0, "final_damage": 0,
			"hp_before": hp_before
		}

	var is_crit := check_crit(attacker.crit_chance)
	var crit_mult := 2.0 if is_crit else 1.0
	var raw_damage := int(attacker.damage * damage_percent * crit_mult)
	var final_damage := apply_armor(raw_damage, target.armor)

	return {
		"is_hit": true, "is_crit": is_crit,
		"raw_damage": raw_damage, "final_damage": final_damage,
		"hp_before": hp_before
	}


## Расчёт урона способности с гарантированным попаданием (никогда не промахивается).
## Используется для способностей вроде «Точный выстрел» Кентавра.
static func calculate_forced_hit_damage(attacker: Combatant, target: Combatant, ability: AbilityResource) -> Dictionary:
	var hp_before := target.current_hp

	var base_dmg := attacker.damage * ability.damage_modifier
	var position_bonus := attacker.get_damage_modifier(target.position_index)
	var total_damage := int(base_dmg * position_bonus)

	var battle_dmg_mult := CombatManager.get_damage_multiplier()
	if battle_dmg_mult != 1.0:
		total_damage = int(total_damage * battle_dmg_mult)

	var is_crit := check_crit(attacker.crit_chance)
	var crit_mult := CombatManager.get_crit_multiplier() if is_crit else 1.0
	var raw_damage := int(total_damage * crit_mult)

	var final_damage := raw_damage
	if ability.damage_type == "Physical" and not CombatManager.is_armor_ignored():
		var _eff_armor := target.armor
		if attacker.special_effect_type == "giant_armor_pierce":
			_eff_armor = int(target.armor * 0.5)
		final_damage = apply_armor(raw_damage, _eff_armor)

	return {
		"is_hit": true, "is_crit": is_crit,
		"raw_damage": raw_damage, "final_damage": final_damage,
		"hp_before": hp_before
	}
