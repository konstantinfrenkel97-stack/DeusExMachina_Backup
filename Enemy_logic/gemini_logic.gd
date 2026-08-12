extends RefCounted
class_name GeminiLogic

## Близнецы: один раз за бой, когда HP ниже 50%, использует Разделиться.
## В остальных случаях — Танец двоих (или другая атака).

static func get_decision_with_allies(monster: Combatant, heroes: Array, allies: Array) -> Dictionary:
	var split_ab := _find_by_marker(monster, "gemini_split")

	# Разделиться — один раз за бой при HP < 50%.
	if split_ab != null and _is_usable_from_position(split_ab, monster.position_index):
		var already_split = monster.has_meta("gemini_split_used") and monster.get_meta("gemini_split_used", false)
		if not already_split and monster.current_hp < int(monster.max_hp * 0.5):
			monster.set_meta("gemini_split_used", true)
			return {"ability": split_ab, "target": monster}

	# Иначе — любая другая доступная атака.
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab == split_ab:
			continue
		if _is_usable_from_position(ab, monster.position_index):
			usable.append(ab)

	if usable.is_empty():
		if split_ab != null and _is_usable_from_position(split_ab, monster.position_index):
			return {"ability": split_ab, "target": monster}
		return {}

	var ability: AbilityResource = usable.pick_random()

	if ability.target_type == "Self":
		return {"ability": ability, "target": monster}

	var target = _first_valid_hero(heroes, ability)
	if target:
		return {"ability": ability, "target": target}
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


static func _first_valid_hero(heroes: Array, ability: AbilityResource) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			return h
	return null
