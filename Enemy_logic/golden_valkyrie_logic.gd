extends RefCounted
class_name GoldenValkyrieLogic

## Золотая валькирия: если нет баффа «Воин дня» — 50% применить его. Иначе случайный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var day_ab := _find_by_name(monster, "Воин дня")
	if day_ab != null and _is_usable_from_position(day_ab, monster.position_index):
		if not _has_stance_effect(monster, "warrior_of_day_stance"):
			if randf() < 0.50:
				return {"ability": day_ab, "target": monster}
	return _random_decision(monster, heroes)


static func _has_stance_effect(unit: Combatant, effect_id: String) -> bool:
	for e in unit.active_effects:
		if Combatant._effect_get(e, "effect_id", "") == effect_id:
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
