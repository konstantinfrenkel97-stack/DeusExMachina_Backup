extends RefCounted
class_name StoneGiantShamanLogic

## ИИ Каменного великана-шамана.
## «Каменная стена» (призыв Валуна) — приоритет, если ещё не использована в этом бою.
## В остальных случаях — случайный выбор.

const STONE_WALL = "каменная стена"

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	# Приоритет: «Каменная стена» если ещё не использована в этом бою
	if not monster.get_meta("shaman_used_stone_wall", false):
		var wall = _find_ability(monster, STONE_WALL)
		if wall and _is_usable_from_position(wall, monster.position_index):
			return {"ability": wall, "target": monster}

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
