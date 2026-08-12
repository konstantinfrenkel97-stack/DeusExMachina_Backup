extends RefCounted
class_name MentorLogic

## Наставник: если у союзника <70% HP — с шансом 70% лечит его «Обратно в строй».
## Не выбирает Новичка целью, если есть другие союзники.
## Иначе — случайная доступная способность.

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var heal_ab := _find_by_marker(monster, "mentor_back_in_formation")
	var lesson_ab := _find_by_marker(monster, "mentor_teach_lesson")
	var punish_ab := _find_by_marker(monster, "mentor_punishment")

	# 1. Лечение раненого союзника (<70% HP), с шансом 70%.
	if heal_ab != null and _is_usable_from_position(heal_ab, monster.position_index):
		if randf() < 0.70:
			var wounded := _find_wounded_ally(allies, monster, heal_ab)
			if wounded != null:
				return {"ability": heal_ab, "target": wounded}

	# 2. «Преподать урок» — бафф случайного союзника (не Новичка при наличии других).
	if lesson_ab != null and _is_usable_from_position(lesson_ab, monster.position_index):
		var buff_target := _find_buff_ally(allies, monster, lesson_ab)
		if buff_target != null:
			return {"ability": lesson_ab, "target": buff_target}

	# 3. «Наказание» — атака по врагу.
	if punish_ab != null and _is_usable_from_position(punish_ab, monster.position_index):
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, punish_ab):
				return {"ability": punish_ab, "target": h}

	# 4. Fallback — любая доступная способность.
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if _is_usable_from_position(ab, monster.position_index):
			usable.append(ab)
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}


## Ищет раненого союзника (<70% HP). Не выбирает Новичка, если есть другие раненые.
static func _find_wounded_ally(allies: Array, monster: Combatant, ab: AbilityResource) -> Combatant:
	var candidates: Array = []
	var novice_candidates: Array = []
	for a in allies:
		if a == null or a == monster or a.current_hp <= 0:
			continue
		if not Combatant.can_be_targeted_at(a, ab):
			continue
		if float(a.current_hp) / float(a.max_hp) >= 0.70:
			continue
		if _is_novice(a):
			novice_candidates.append(a)
		else:
			candidates.append(a)
	if not candidates.is_empty():
		return candidates.pick_random()
	if not novice_candidates.is_empty():
		return novice_candidates.pick_random()
	return null


## Ищет союзника для баффа. Не выбирает Новичка, если есть другие.
static func _find_buff_ally(allies: Array, monster: Combatant, ab: AbilityResource) -> Combatant:
	var candidates: Array = []
	var novice_candidates: Array = []
	for a in allies:
		if a == null or a == monster or a.current_hp <= 0:
			continue
		if not Combatant.can_be_targeted_at(a, ab):
			continue
		if _is_novice(a):
			novice_candidates.append(a)
		else:
			candidates.append(a)
	if not candidates.is_empty():
		return candidates.pick_random()
	if not novice_candidates.is_empty():
		return novice_candidates.pick_random()
	return null


static func _is_novice(unit: Combatant) -> bool:
	return unit.special_effect_type == "novice_transformation"


static func _find_by_marker(monster: Combatant, marker: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.ability_marker == marker:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true
