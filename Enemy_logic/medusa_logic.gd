extends RefCounted
class_name MedusaLogic

## Медуза: с вероятностью 70% — «Проклятый взгляд», иначе — «Змеиный укус».

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var gaze_ab := _find_by_marker(monster, "medusa_cursed_gaze")
	var bite_ab := _find_by_marker(monster, "medusa_snake_bite")

	var chosen: AbilityResource = null
	if gaze_ab != null and bite_ab != null:
		chosen = gaze_ab if randf() < 0.70 else bite_ab
	elif gaze_ab != null:
		chosen = gaze_ab
	elif bite_ab != null:
		chosen = bite_ab

	if chosen == null:
		return _random_usable(monster, heroes)

	if not _is_usable_from_position(chosen, monster.position_index):
		return _random_usable(monster, heroes)

	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, chosen):
			return {"ability": chosen, "target": h}
	return {}


static func _find_by_marker(monster: Combatant, marker: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab != null and ab.ability_marker == marker:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true


static func _random_usable(monster: Combatant, heroes: Array) -> Dictionary:
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
