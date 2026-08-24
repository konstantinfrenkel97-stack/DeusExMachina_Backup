extends RefCounted
class_name StoneGiantShamanLogic

## ИИ Каменного великана-шамана.
## «Каменная стена» (призыв Валуна) — приоритет, если ещё не использована в этом бою.
## В остальных случаях — случайный выбор.

const STONE_WALL = "каменная стена"

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var wall := _find_ability(monster, STONE_WALL)

	# Приоритет: «Каменная стена» если ещё не использована в этом бою
	if wall and not monster.get_meta("shaman_used_stone_wall", false):
		if _is_usable_from_position(wall, monster.position_index):
			return {"ability": wall, "target": monster}

	# В остальных случаях — случайный выбор, но не повторная «Каменная стена»
	return ArenaRandomLogic.get_decision(monster, heroes, [], [wall] if wall else [])


static func _find_ability(monster: Combatant, ability_name: String) -> AbilityResource:
	for ab in monster.active_abilities:
		if ab and ab.name.to_lower() == ability_name:
			return ab
	return null


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true
