extends RefCounted
class_name NanahueLogic

## Нанауэ: если есть цель с периодическим уроном — с шансом 70% применяет «Поглотить».
## Иначе — случайная доступная способность.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var devour_ab := _find_by_name(monster, "Поглотить")
	if devour_ab != null and _is_usable_from_position(devour_ab, monster.position_index):
		# Ищем цель с периодическим уроном, по которой можно применить Поглотить.
		if randf() < 0.70:
			for h in heroes:
				if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, devour_ab) and _has_periodic(h):
					return {"ability": devour_ab, "target": h}
	# Иначе — случайная доступная способность.
	return _random_decision(monster, heroes)


static func _has_periodic(unit: Combatant) -> bool:
	for e in unit.active_effects:
		if Combatant._effect_get(e, "stat", "") == "periodic_damage":
			return true
	return false


static func _random_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if _is_usable_from_position(ab, monster.position_index):
			usable.append(ab)
	if usable.is_empty():
		return {}
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}


static func _find_by_name(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.name == ability_name:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true
