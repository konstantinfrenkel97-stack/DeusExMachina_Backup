extends RefCounted
class_name SatyrLogic

## Сатир: всегда использует «Чарующую песню».

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.name == "Чарующая песня":
			if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
				return {"ability": ab, "target": monster}
	# fallback: любой доступный
	for ab in monster.active_abilities:
		if ab and ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			return {"ability": ab, "target": monster}
	return {}
