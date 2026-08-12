extends RefCounted
class_name GriffinLogic

## Грифон: 40% «Пикировать», 60% «Небесное копьё».

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var dive_ab := _find_by_name(monster, "Пикировать")
	var spear_ab := _find_by_name(monster, "Небесное копье")
	if randf() < 0.40 and dive_ab != null and _is_usable_from_position(dive_ab, monster.position_index):
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, dive_ab):
				return {"ability": dive_ab, "target": h}
	if spear_ab != null and _is_usable_from_position(spear_ab, monster.position_index):
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, spear_ab):
				return {"ability": spear_ab, "target": h}
	# Fallback: любая доступная
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if _is_usable_from_position(ab, monster.position_index):
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
