extends RefCounted
class_name CaptainLogic

## Капитан: проверяет дебаффы меткости у союзников, применяет «Мотивация».
## «Пьяный выстрел» применяет только если на него нанесено заклинание «Ром».
## Иначе применяет другой доступный скилл.

const MOTIVATION_NAME = "Мотивация"
const DRUNK_SHOT_NAME = "Пьяный выстрел"
const PARROT_NAME = "Пытка попугаем"
const HOOK_NAME = "Удар крюком"

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var allies: Array = _get_allies(monster)
	
	# 1. Проверяем, есть ли у союзника дебафф меткости → Мотивация
	if _has_ally_accuracy_debuff(allies):
		var motivation = _find_ability(monster, MOTIVATION_NAME)
		if motivation and _is_usable(monster, motivation):
			return {"ability": motivation, "target": monster}
	
	# 2. Пьяный выстрел — только если на капитане есть эффект от «Ром»
	if _has_rum_effect(monster):
		var drunk = _find_ability(monster, DRUNK_SHOT_NAME)
		if drunk and _is_usable(monster, drunk):
			var target = _get_random_target(heroes, drunk)
			if target:
				return {"ability": drunk, "target": target}
	
	# 3. Другие доступные навыки (кроме Пьяного выстрела и Мотивации)
	var usable = _get_usable_except(monster, [DRUNK_SHOT_NAME, MOTIVATION_NAME])
	if not usable.is_empty():
		for ab in usable:
			if ab.target_type == "Self" or ab.target_type == "All_Allies":
				return {"ability": ab, "target": monster}
			var t = _get_random_target(heroes, ab)
			if t:
				return {"ability": ab, "target": t}
	
	# 4. Резерв — любой доступный навык
	var all_usable = _get_usable_abilities(monster)
	for ab in all_usable:
		if ab.target_type == "Self" or ab.target_type == "All_Allies":
			return {"ability": ab, "target": monster}
		var t = _get_random_target(heroes, ab)
		if t:
			return {"ability": ab, "target": t}
	
	return {}

static func _has_ally_accuracy_debuff(allies: Array) -> bool:
	for ally in allies:
		if ally == null or ally.current_hp <= 0:
			continue
		for eff in ally.active_effects:
			var stat = Combatant._effect_get(eff, "stat", "")
			var val = Combatant._effect_get(eff, "value", 0)
			if stat == "accuracy" and val < 0:
				return true
	return false

static func _has_rum_effect(unit: Combatant) -> bool:
	for eff in unit.active_effects:
		var src = Combatant._effect_get(eff, "source_ability", "")
		if src == "Ром":
			return true
	return false

static func _get_allies(monster: Combatant) -> Array:
	# Возвращает «союзников» — здесь мы просто возвращаем пустой массив,
	# реальный список союзников передаётся через battle_scene.
	# Капитан проверяет только себя для Ром-эффекта.
	# Для проверки дебаффов союзников ИИ нужен доступ к команде.
	# Это обрабатывается через расширенную сигнатуру get_decision.
	return []

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	# 1. Проверяем, есть ли у союзника дебафф меткости → Мотивация
	if _has_ally_accuracy_debuff(allies):
		var motivation = _find_ability(monster, MOTIVATION_NAME)
		if motivation and _is_usable(monster, motivation):
			return {"ability": motivation, "target": monster}
	
	# 2. Пьяный выстрел — только если на капитане есть эффект от «Ром»
	if _has_rum_effect(monster):
		var drunk = _find_ability(monster, DRUNK_SHOT_NAME)
		if drunk and _is_usable(monster, drunk):
			var target = _get_random_target(heroes, drunk)
			if target:
				return {"ability": drunk, "target": target}
	
	# 3. Другие доступные навыки
	var usable = _get_usable_except(monster, [DRUNK_SHOT_NAME, MOTIVATION_NAME])
	if not usable.is_empty():
		for ab in usable:
			if ab.target_type == "Self" or ab.target_type == "All_Allies":
				return {"ability": ab, "target": monster}
			var t = _get_random_target(heroes, ab)
			if t:
				return {"ability": ab, "target": t}
	
	# 4. Резерв
	var all_usable = _get_usable_abilities(monster)
	for ab in all_usable:
		if ab.target_type == "Self" or ab.target_type == "All_Allies":
			return {"ability": ab, "target": monster}
		var t = _get_random_target(heroes, ab)
		if t:
			return {"ability": ab, "target": t}
	
	return {}

static func _find_ability(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name == ability_name:
			return ab
	return null

static func _is_usable(monster: Combatant, ability: AbilityResource) -> bool:
	if ability.usable_from_positions.size() > monster.position_index:
		return ability.usable_from_positions[monster.position_index]
	return false

static func _get_usable_abilities(monster: Combatant) -> Array:
	var abilities: Array = []
	for ab in monster.active_abilities:
		if ab and _is_usable(monster, ab):
			abilities.append(ab)
	return abilities

static func _get_usable_except(monster: Combatant, excluded_names: Array) -> Array:
	var abilities: Array = []
	for ab in monster.active_abilities:
		if ab and _is_usable(monster, ab) and not ab.name in excluded_names:
			abilities.append(ab)
	return abilities

static func _get_random_target(heroes: Array, ability: AbilityResource) -> Combatant:
	var valid: Array = []
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			valid.append(h)
	return valid.pick_random() if not valid.is_empty() else null
