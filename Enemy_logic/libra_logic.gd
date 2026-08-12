extends RefCounted
class_name LibraLogic

## Весы: если есть хотя бы один живой союзник — использует Равновесие (стойка),
## иначе — Дизбаланс (атака по одиночной цели).

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var alive_allies := 0
	for a in allies:
		if a != null and a.current_hp > 0 and a != monster:
			alive_allies += 1

	# Равновесие: стойка (target_type = Self) — приоритет, если есть союзники.
	if alive_allies > 0:
		var balance_ab := _find_by_name(monster, "Равновесие")
		if balance_ab != null and _is_usable_from_position(balance_ab, monster.position_index):
			return {"ability": balance_ab, "target": monster}

	# Иначе — Дизбаланс (атака по врагу).
	var imbalance_ab := _find_by_name(monster, "Дизбаланс")
	if imbalance_ab != null and _is_usable_from_position(imbalance_ab, monster.position_index):
		var t = _first_valid_hero(heroes, imbalance_ab)
		if t:
			return {"ability": imbalance_ab, "target": t}

	# Fallback: любой доступный навык.
	return _random_usable(monster, heroes)


static func _find_by_name(monster: Combatant, ab_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.name == ab_name:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true


static func _first_valid_hero(heroes: Array, ability: AbilityResource) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			return h
	return null


static func _random_usable(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if _is_usable_from_position(ab, monster.position_index):
			usable.append(ab)
	if usable.is_empty():
		return {}
	var ability: AbilityResource = usable.pick_random()
	if ability.target_type == "Self":
		return {"ability": ability, "target": monster}
	var t = _first_valid_hero(heroes, ability)
	if t:
		return {"ability": ability, "target": t}
	return {}
