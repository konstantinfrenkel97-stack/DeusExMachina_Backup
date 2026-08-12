extends RefCounted
class_name PegasusLogic

## Пегас: 30% применить «Кара с небес», иначе случайный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var judgment_ab := _find_by_name(monster, "Кара с небес")
	if judgment_ab != null and _is_usable_from_position(judgment_ab, monster.position_index):
		if randf() < 0.30:
			return {"ability": judgment_ab, "target": monster}
	return _random_decision(monster, heroes)


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
