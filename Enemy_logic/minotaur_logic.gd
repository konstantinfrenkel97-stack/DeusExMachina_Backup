extends RefCounted
class_name MinotaurLogic

## Минотавр: если ни у одного союзника нет эффекта «Устрашающего рёва» —
## с шансом 70% использует рёв. Иначе — случайная доступная способность.

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var roar_ab := _find_by_marker(monster, "minotaur_intimidating_roar")
	var gore_ab := _find_by_marker(monster, "minotaur_gore")
	var pummel_ab := _find_by_marker(monster, "minotaur_pummel")

	# 1. Рёв, если ни у одного союзника нет эффекта рёва.
	if roar_ab != null and _is_usable_from_position(roar_ab, monster.position_index):
		if not _any_ally_has_roar(allies):
			if randf() < 0.70:
				return {"ability": roar_ab, "target": monster}

	# 2. «Боднуть» — атака по передним позициям врага.
	if gore_ab != null and _is_usable_from_position(gore_ab, monster.position_index):
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, gore_ab):
				return {"ability": gore_ab, "target": h}

	# 3. «Колошматить» — атака по передним позициям врага.
	if pummel_ab != null and _is_usable_from_position(pummel_ab, monster.position_index):
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, pummel_ab):
				return {"ability": pummel_ab, "target": h}

	# 4. Рёв как fallback (если доступен).
	if roar_ab != null and _is_usable_from_position(roar_ab, monster.position_index):
		return {"ability": roar_ab, "target": monster}

	# 5. Любая доступная способность.
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


static func _any_ally_has_roar(allies: Array) -> bool:
	for a in allies:
		if a == null or a.current_hp <= 0:
			continue
		for e in a.active_effects:
			var eid = Combatant._effect_get(e, "effect_id", "")
			if eid == "minotaur_roar_buff":
				return true
	return false


static func _find_by_marker(monster: Combatant, marker: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.ability_marker == marker:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true
