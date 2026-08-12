extends RefCounted
class_name AriesLogic

## Овен: использует любую доступную способность (Боднуть / Отскочить) из текущей позиции.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index:
			if ab.usable_from_positions[monster.position_index]:
				usable.append(ab)

	if usable.is_empty():
		return {}

	var ability: AbilityResource = usable.pick_random()

	if ability.target_type == "Self":
		return {"ability": ability, "target": monster}

	var target = _first_valid_hero(heroes, ability)
	if target:
		return {"ability": ability, "target": target}
	return {}


static func _first_valid_hero(heroes: Array, ability: AbilityResource) -> Combatant:
	for h in heroes:
		if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ability):
			return h
	return null
