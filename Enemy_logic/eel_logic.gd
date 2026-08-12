extends RefCounted
class_name EelLogic

## Угорь:
## - Спокойные воды (is_raging=false) → с шансом 70% «Оплетание» (приоритет по цели в стойке).
## - Бурные потоки (is_raging=true) → с шансом 70% «Двойной укус».
## - Иначе — другой доступный навык.

static func get_decision_depths(monster: Combatant, heroes: Array, is_raging: bool) -> Dictionary:
	var entangle_ab := _find_by_name(monster, "Оплетание")
	var bite_ab := _find_by_name(monster, "Двойной укус")

	if not is_raging and entangle_ab != null and _is_usable_from_position(entangle_ab, monster.position_index):
		if randf() < 0.70:
			# Приоритет — цель в стойке.
			for h in heroes:
				if h and h.current_hp > 0 and h.active_stance != null and Combatant.can_be_targeted_at(h, entangle_ab):
					return {"ability": entangle_ab, "target": h}
			for h in heroes:
				if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, entangle_ab):
					return {"ability": entangle_ab, "target": h}

	if is_raging and bite_ab != null and _is_usable_from_position(bite_ab, monster.position_index):
		if randf() < 0.70:
			for h in heroes:
				if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, bite_ab):
					return {"ability": bite_ab, "target": h}

	# Fallback: любой доступный навык.
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


static func _find_by_name(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.name == ability_name:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true
