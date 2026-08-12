extends RefCounted
class_name AquariusLogic

## Водолей: всегда использует Нескончаемый поток (атака по врагу с отбросом).

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var flow_ab := _find_by_name(monster, "Нескончаемый поток")
	if flow_ab != null and _is_usable_from_position(flow_ab, monster.position_index):
		var t = _first_valid_hero(heroes, flow_ab)
		if t:
			return {"ability": flow_ab, "target": t}

	# Fallback: любой доступный навык.
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if _is_usable_from_position(ab, monster.position_index):
			usable.append(ab)
	if usable.is_empty():
		return {}
	var ability: AbilityResource = usable.pick_random()
	var t2 = _first_valid_hero(heroes, ability)
	if t2:
		return {"ability": ability, "target": t2}
	return {}


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
