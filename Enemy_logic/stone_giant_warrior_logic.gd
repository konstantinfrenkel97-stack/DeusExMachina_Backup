extends RefCounted
class_name StoneGiantWarriorLogic

## ИИ Каменного великана-воина.
## «Сила от земли» используется только если HP < 60% и позиция 4 (index 3).
## В остальных случаях — случайный выбор.

const POWER_FROM_EARTH = "сила от земли"

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	# Проверка условия для «Сила от земли»
	if monster.position_index == 3:
		var hp_ratio = float(monster.current_hp) / float(monster.max_hp)
		if hp_ratio < 0.6:
			var power = _find_ability(monster, POWER_FROM_EARTH)
			if power and _is_usable_from_position(power, monster.position_index):
				return {"ability": power, "target": monster}

	# В остальных случаях — случайный выбор
	return ArenaRandomLogic.get_decision(monster, heroes)


static func _find_ability(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name.to_lower() == ability_name:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true
